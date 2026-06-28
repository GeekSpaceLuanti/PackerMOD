local M = {}

local DIR_DELIM_LUA = package.config:sub(1, 1)

local function join(a, b)
    return a .. DIR_DELIM_LUA .. b
end

local function packs_root(user_path)
    return join(join(user_path, "PackerMOD"), "packs")
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

function M.ensure_dirs(user_path)
    local root = join(user_path, "PackerMOD")
    if core and core.create_dir then
        core.create_dir(root)
        core.create_dir(join(root, "packs"))
        core.create_dir(join(root, "cache"))
    end
end

function M.list_packs(user_path, manifest_mod)
    local list = {}
    local root = packs_root(user_path)
    local entries
    if core and core.get_dir_list then
        entries = core.get_dir_list(root, true)
    else
        entries = {}
    end
    for _, entry in ipairs(entries or {}) do
        local manifest_path = join(join(root, entry), "manifest.yaml")
        local text = read_file(manifest_path)
        if text then
            local ok, m = manifest_mod.parse(text)
            if ok then
                table.insert(list, { id = entry, manifest = m, path = join(root, entry) })
            end
        end
    end
    table.sort(list, function(a, b) return a.manifest.name < b.manifest.name end)
    return list
end

function M.get_pack(user_path, pack_id, manifest_mod)
    local path = join(packs_root(user_path), pack_id)
    local text = read_file(join(path, "manifest.yaml"))
    if not text then return nil end
    local ok, m = manifest_mod.parse(text)
    if not ok then return nil, m end
    return { id = pack_id, manifest = m, path = path }
end

function M.delete_pack(user_path, pack_id)
    local path = join(packs_root(user_path), pack_id)
    if core and core.delete_dir then
        return core.delete_dir(path)
    end
    return false
end

-- world.mt の `packermod_pack_id = <id>` を見て pack に紐づく world だけ返す。
-- 戻り値: { { index = <core.get_worlds の 1-origin index>, name, path, gameid, display_name }, ... }
function M.list_worlds(pack_id, opts)
    opts = opts or {}
    local worlds_fn = opts.get_worlds or (core and core.get_worlds)
    local read = opts.read_file or read_file
    if not worlds_fn then return {} end

    local raw = worlds_fn() or {}
    local result = {}
    for i, w in ipairs(raw) do
        local text = read(join(w.path, "world.mt"))
        if text then
            local found = text:match("packermod_pack_id%s*=%s*([%w_%-%.]+)")
            if found == pack_id then
                local display = text:match("world_name%s*=%s*([^\n\r]+)")
                table.insert(result, {
                    index = i,
                    name = w.name,
                    path = w.path,
                    gameid = w.gameid,
                    display_name = display and display:gsub("%s+$", "") or w.name,
                })
            end
        end
    end
    return result
end

return M
