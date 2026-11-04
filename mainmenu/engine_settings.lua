-- Schema-driven editor for the installed engine's own settingtypes.txt.
-- No duplicate defaults or native dialog dependency: Luanti remains the source
-- of types, bounds, choices, help and stored values.
local M = {}
local TYPES = { bool = true, int = true, float = true, enum = true, string = true,
    key = true, path = true, filepath = true, flags = true, v3f = true,
    noise_params_2d = true, noise_params_3d = true }

local function finite(value)
    local number = tonumber(value)
    if number and number == number and number > -math.huge and number < math.huge then return number end
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function flags(value, possible)
    local allowed, out, seen = {}, {}, {}
    for _, name in ipairs(possible or {}) do allowed[name] = true; allowed["no" .. name] = true end
    for name in tostring(value):gmatch("[^,%s]+") do
        if not allowed[name] then return nil, "Unknown flag: " .. name end
        if not seen[name] then out[#out + 1] = name; seen[name] = true end
    end
    return table.concat(out, ",")
end

function M.validate(entry, value)
    if entry.noise_params or entry.type:match("^noise_params_") then
        if type(value) ~= "table" then return nil, "Invalid noise parameters" end
        local result = { spread = {} }
        for _, key in ipairs({ "offset", "scale", "seed", "octaves", "persistence", "lacunarity" }) do
            result[key] = finite(value[key])
            if not result[key] then return nil, "Invalid number: " .. key end
        end
        for _, axis in ipairs({ "x", "y", "z" }) do
            result.spread[axis] = finite(value.spread and value.spread[axis])
            if not result.spread[axis] or result.spread[axis] <= 0 then return nil, "Spread must be positive" end
        end
        if result.seed % 1 ~= 0 or result.octaves % 1 ~= 0 or result.octaves < 1 then
            return nil, "Seed and octaves must be integers; octaves must be positive"
        end
        local valid, err = flags(value.flags or "", entry.flags or { "defaults", "eased", "absvalue" })
        if not valid then return nil, err end
        result.flags = valid
        return result
    end
    value = tostring(value or "")
    if value:find("[\r\n%z]") then return nil, "A setting must be a single line" end
    if entry.type == "int" or entry.type == "float" then
        local number = finite(value)
        if not number or (entry.type == "int" and number % 1 ~= 0) then return nil, "Invalid number" end
        if entry.min and number < entry.min then return nil, "Minimum: " .. entry.min end
        if entry.max and number > entry.max then return nil, "Maximum: " .. entry.max end
        return tostring(number)
    elseif entry.type == "bool" then
        if value ~= "true" and value ~= "false" then return nil, "Choose enabled or disabled" end
    elseif entry.type == "enum" then
        for _, option in ipairs(entry.values or {}) do if option == value then return value end end
        return nil, "Choose an available value"
    elseif entry.type == "flags" then
        return flags(value, entry.possible)
    elseif entry.type == "key" then
        for key in value:gmatch("[^|]+") do
            if not key:match("^[%w_%-]+$") then return nil, "Invalid key binding" end
        end
    elseif entry.type == "v3f" then
        local x, y, z = value:gsub("[()]", ""):match("^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
        x, y, z = finite(x), finite(y), finite(z)
        if not x or not y or not z then return nil, "Enter three numbers" end
        return ("(%s, %s, %s)"):format(x, y, z)
    end
    return value
end

function M.new(definitions, settings)
    local self = { entries = {}, by_name = {}, categories = {} }
    local stack, known = {}, {}
    for _, source in ipairs(definitions) do
        if source.type == "category" then
            local level = (source.level or 0) + 1
            for i = #stack, level, -1 do stack[i] = nil end
            stack[level] = source.name
        elseif TYPES[source.type] then
            local entry = copy(source)
            entry.category_parts = copy(stack)
            entry.category = table.concat(stack, " / ")
            self.entries[#self.entries + 1] = entry
            self.by_name[entry.name] = entry
            if not known[entry.category] then
                known[entry.category] = true
                self.categories[#self.categories + 1] = { name = entry.category, parts = copy(stack) }
            end
        end
    end

    function self.filter(query, category, translate)
        translate = translate or function(text) return text end
        query = (query or ""):lower()
        local result = {}
        for _, entry in ipairs(self.entries) do
            local category_parts = {}
            for _, part in ipairs(entry.category_parts) do category_parts[#category_parts + 1] = translate(part) end
            local text = table.concat({ entry.name, translate(entry.readable_name or entry.name),
                translate(entry.comment or ""), table.concat(category_parts, " / ") }, " "):lower()
            if (not category or category == "" or entry.category == category)
                    and (query == "" or text:find(query, 1, true)) then result[#result + 1] = entry end
        end
        return result
    end
    function self.read(entry)
        if entry.noise_params then return copy(settings:get_np_group(entry.name) or entry.default_table) end
        local value = settings:get(entry.name)
        if value == nil then return entry.default or "" end
        return value
    end
    local function store(entry, value)
        if entry.noise_params then return settings:set_np_group(entry.name, value) end
        return settings:set(entry.name, value)
    end
    local function commit(entry, value, reset)
        if self.by_name[entry.name] ~= entry then return false, "Unknown setting" end
        local had_value = settings:has(entry.name)
        local original = self.read(entry)
        local changed, err = pcall(function()
            if reset then settings:remove(entry.name) else store(entry, value) end
            if settings:write() == false then error("Cannot write settings") end
        end)
        if not changed then
            if had_value then store(entry, original) else settings:remove(entry.name) end
            return false, tostring(err):find("Cannot write settings", 1, true) and "Cannot write settings" or tostring(err)
        end
        return true
    end
    function self.apply(entry, input)
        local value, err = M.validate(entry, input)
        if value == nil then return false, err end
        return commit(entry, value, false)
    end
    function self.reset(entry) return commit(entry, nil, true) end
    return self
end

function M.load()
    if not rawget(_G, "settingtypes") then
        dofile(core.get_builtin_path() .. "common" .. DIR_DELIM .. "settings" .. DIR_DELIM .. "settingtypes.lua")
    end
    return M.new(settingtypes.parse_config_file(false, false), core.settings)
end
return M
