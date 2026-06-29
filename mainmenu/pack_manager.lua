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

local function parse_world_mt(text)
    if not text then return nil end
    local gameid = text:match("gameid%s*=%s*([%w_%-%.]+)")
    local display = text:match("world_name%s*=%s*([^\n\r]+)")
    if display then display = display:gsub("%s+$", "") end
    return { gameid = gameid, display_name = display }
end

-- <user>/PackerMOD/packs/<pack_id>/worlds/ 配下を独自 walk して world 一覧を返す。
-- Luanti の core.get_worlds() は flat 構造しか返さないので使わない。
-- 戻り値: { { name (sanitized = dir 名), path, gameid, display_name }, ... }
function M.list_worlds(pack_id, opts)
    opts = opts or {}
    local user_path = opts.user_path or (packermod and packermod.user_path)
    if not user_path then return {} end
    local read = opts.read_file or read_file
    local list_dir = opts.list_dir or function(p)
        if core and core.get_dir_list then return core.get_dir_list(p, true) end
        return nil
    end

    local worlds_dir = join(join(join(join(user_path, "PackerMOD"), "packs"), pack_id), "worlds")
    local entries = list_dir(worlds_dir) or {}
    local result = {}
    for _, name in ipairs(entries) do
        local world_path = join(worlds_dir, name)
        local text = read(join(world_path, "world.mt"))
        local meta = parse_world_mt(text)
        if meta then
            table.insert(result, {
                name = name,
                path = world_path,
                gameid = meta.gameid,
                display_name = meta.display_name or name,
            })
        end
    end
    table.sort(result, function(a, b) return (a.display_name or a.name) < (b.display_name or b.name) end)
    return result
end

-- 旧 flat 配置 (<user>/worlds/<pack_id>__<timestamp>/) を検出する。
-- 注意: core.get_worlds() の各 entry の `name` は world.mt の `world_name`
-- (display name) であってディレクトリ名ではない。ディレクトリ名は path の
-- 末尾セグメントから抽出する。
-- 認識条件は以下のいずれか:
--   (a) ディレクトリ名が <pack_id>__ プレフィックスで始まる
--       (旧 create_world の命名規則。world.mt が古くて packermod_pack_id 未記入でも検出)
--   (b) world.mt の packermod_pack_id がこの pack と一致
-- 戻り値: { { name (dir 名), path, gameid, display_name, legacy = true }, ... }
function M.list_legacy_worlds(pack_id, opts)
    opts = opts or {}
    local worlds_fn = opts.get_worlds or (core and core.get_worlds)
    local read = opts.read_file or read_file
    if not worlds_fn then return {} end

    local prefix = pack_id .. "__"
    local raw = worlds_fn() or {}
    local result = {}
    for _, w in ipairs(raw) do
        local dir_name = w.path and w.path:match("([^/\\]+)$") or w.name
        -- 起動時の symlink (_pm_*) は legacy と区別するため除外
        if not (dir_name and dir_name:sub(1, 4) == "_pm_") then
            local name_match = dir_name and dir_name:sub(1, #prefix) == prefix
            local text = read(join(w.path, "world.mt"))
            local display = nil
            local id_match = false
            if text then
                local found = text:match("packermod_pack_id%s*=%s*([%w_%-%.]+)")
                id_match = (found == pack_id)
                display = text:match("world_name%s*=%s*([^\n\r]+)")
            end
            if name_match or id_match then
                table.insert(result, {
                    name = dir_name or w.name,
                    path = w.path,
                    gameid = w.gameid,
                    display_name = (display and display:gsub("%s+$", "")) or w.name or dir_name,
                    legacy = true,
                })
            end
        end
    end
    return result
end

-- Pack のサムネ画像パスを返す。pack ディレクトリ直下に thumbnail.png があればそれ、
-- なければデフォルト画像を返す。表示側は image[] で読めるパスとして使う。
function M.get_thumbnail_path(pack, opts)
    opts = opts or {}
    local exists = opts.exists or function(p)
        local f = io.open(p, "r")
        if f then f:close(); return true end
        return false
    end
    if pack and pack.path then
        local candidate = join(pack.path, "thumbnail.png")
        if exists(candidate) then return candidate end
    end
    return opts.default_path
end

return M
