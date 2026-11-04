-- World files own persistent values. A recoverable launch overlay supplies
-- server settings to Luanti, whose menu API has no per-server Settings layer.
local here = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local catalog = dofile(here .. "settings_catalog.lua")
local editor = dofile(here .. "engine_settings.lua")
local M = {}
local function exists(path) local f = io.open(path, "rb"); if f then f:close(); return true end; return false end
local function read(path) local f = io.open(path, "rb"); if not f then return end; local s = f:read("*a"); f:close(); return s end
local function copy(t) if type(t) ~= "table" then return t end; local o = {}; for k,v in pairs(t) do o[k] = copy(v) end; return o end
local function serialize(values, indent)
    indent = indent or ""
    local keys, lines = {}, {}
    for k in pairs(values) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = values[k]
        if type(v) == "table" then
            lines[#lines + 1] = indent .. k .. " = {\n" .. serialize(v, indent .. "\t") .. indent .. "}\n"
        else lines[#lines + 1] = indent .. k .. " = " .. tostring(v) .. "\n" end
    end
    return table.concat(lines)
end
function M.open(world, schema)
    assert(world.path and exists(world.path .. "/world.mt"), "World not found")
    local mt = Settings(world.path .. "/world.mt")
    local terrain = Settings(world.path .. "/packermod-mapgen.conf")
    local meta = Settings(world.path .. "/map_meta.txt")
    local initialized = exists(world.path .. "/env_meta.txt") or exists(world.path .. "/map.sqlite")
    local definitions = {
        { type = "category", name = "Gameplay", level = 0 },
        { type = "bool", name = "creative_mode", readable_name = "Creative Mode", default = "false", context = "server" },
        { type = "bool", name = "enable_damage", readable_name = "Enable Damage", default = "true", context = "server" },
    }
    local entries = {}
    for _, entry in ipairs(schema.entries) do
        if catalog.is_world(entry) then
            local e = copy(entry)
            e.readonly = initialized and (catalog.is_mapgen(e) or e.context == "world_creation")
            definitions[#definitions + 1] = { type = "category", name = entry.category, level = 0 }
            definitions[#definitions + 1] = e
            entries[e.name] = e
        end
    end
    -- Preserve original hierarchy after new() has built its registries.
    local function target(name)
        return entries[name] and catalog.is_mapgen(entries[name]) and terrain or mt
    end
    local store = {}
    function store:get(name)
        if target(name) == terrain then
            local alias = name == "fixed_map_seed" and "seed" or name
            if initialized then return meta:get(alias) or terrain:get(name) end
            return terrain:get(name) or meta:get(alias) or mt:get(name)
        end
        return mt:get(name)
    end
    function store:get_np_group(name)
        if initialized then return meta:get_np_group(name) or terrain:get_np_group(name) end
        return terrain:get_np_group(name) or meta:get_np_group(name) or mt:get_np_group(name)
    end
    function store:has(name) return target(name):has(name) end
    function store:set(name, value) self.changed = target(name); self.changed:set(name, value) end
    function store:set_np_group(name, value) self.changed = terrain; terrain:set_np_group(name, value) end
    function store:remove(name) self.changed = target(name); self.changed:remove(name) end
    function store:write() return self.changed and self.changed:write() end
    local backend = editor.new(definitions, store)
    for _, e in ipairs(backend.entries) do
        if entries[e.name] then e.category, e.category_parts = entries[e.name].category, entries[e.name].category_parts end
    end
    -- Categories for the shared editor are derived from the restored hierarchy.
    local scoped = catalog.scope(backend, true)
    local apply, reset = scoped.apply, scoped.reset
    function scoped.apply(e, value) if e.readonly then return false, "Terrain is locked after first play." end; return apply(e, value) end
    function scoped.reset(e) if e.readonly then return false, "Terrain is locked after first play." end; return reset(e) end
    scoped.world, scoped.initialized = world, initialized
    function scoped.prepare_terrain()
        if initialized then return true end
        local values = meta:to_table()
        for _, e in ipairs(scoped.entries) do
            if catalog.is_mapgen(e) then
                local key = e.name == "fixed_map_seed" and "seed" or e.name
                if e.noise_params then
                    local np = scoped.read(e)
                    values[key] = copy(np)
                    values[key].spread = ("(%s, %s, %s)"):format(np.spread.x, np.spread.y, np.spread.z)
                else values[key] = scoped.read(e) end
            end
        end
        return core.safe_file_write(world.path .. "/map_meta.txt", serialize(values) .. "[end_of_params]\n")
    end
    return scoped
end
function M.session(opts)
    local settings, path = opts.settings, opts.journal_path
    local write = opts.write or core.safe_file_write
    local read_file, remove = opts.read or read, opts.remove or os.remove
    local encode, decode = opts.encode or core.write_json, opts.decode or core.parse_json
    local self = {}
    function self.recover()
        local text = read_file(path)
        if not text then return true end
        local state = decode(text)
        if type(state) ~= "table" or state.version ~= 1 or type(state.values) ~= "table" then return false, "Invalid world session recovery file" end
        for name, saved in pairs(state.values) do
            if type(name) ~= "string" or not name:match("^[%w_%.%-]+$") or type(saved) ~= "table"
                or type(saved.present) ~= "boolean" or (saved.present and type(saved.value) ~= "string") then
                return false, "Invalid world session recovery file"
            end
        end
        for name, saved in pairs(state.values) do
            if saved.present then settings:set(name, saved.value) else settings:remove(name) end
        end
        if settings:write() == false then return false, "Cannot restore global settings" end
        if not remove(path) then return false, "Cannot clear world session recovery file" end
        return true
    end
    function self.begin(backend)
        local ok, err = self.recover(); if not ok then return false, err end
        local values, overrides = {}, {}
        local own = settings.to_table and settings:to_table()
        for _, e in ipairs(backend.entries) do
            if not catalog.is_mapgen(e) then
                local present = own and own[e.name] ~= nil or (not own and settings:has(e.name)) or false
                values[e.name] = { present = present, value = present and settings:get(e.name) or nil }
                overrides[e.name] = backend.read(e)
            end
        end
        if not write(path, encode({ version = 1, values = values })) then return false, "Cannot save world session recovery file" end
        local applied, apply_error = pcall(function()
            for name, value in pairs(overrides) do settings:set(name, value) end
        end)
        if not applied then self.recover(); return false, tostring(apply_error) end
        return true
    end
    return self
end
return M
