local M = {}

local DIR_DELIM_LUA = package.config:sub(1, 1)

local function is_windows()
    return DIR_DELIM_LUA == "\\"
end

-- Lua の os.execute は OS の sh/cmd を叩く。シェル escape のため引数は %q で囲む。
-- Linux/macOS: `ln -s target link` でシンボリックリンク
-- Windows:     `cmd /c mklink /J link target` で junction(管理者権限不要)
local function default_create_symlink(target, link)
    local cmd
    if is_windows() then
        -- mklink は backslash パスを期待する
        local link_win = link:gsub("/", "\\")
        local target_win = target:gsub("/", "\\")
        cmd = ('cmd /c mklink /J %q %q'):format(link_win, target_win)
    else
        cmd = ('ln -s %q %q'):format(target, link)
    end
    local ok = os.execute(cmd)
    return ok == true or ok == 0
end

M.is_windows = is_windows
M.create_symlink = default_create_symlink

local function file_exists(path)
    local f = io.open(path, "rb"); if f then f:close(); return true end
    return false
end
local function normalized(path)
    path = path:gsub("\\", "/")
    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            if #parts == 0 then return "" end
            table.remove(parts)
        elseif part ~= "." then parts[#parts + 1] = part end
    end
    return (path:sub(1, 1) == "/" and "/" or "") .. table.concat(parts, "/")
end
local function valid_launch_paths(user_path, source, target)
    local root = normalized(user_path)
    source, target = normalized(source), normalized(target)
    local relative = source:sub(#root + 2)
    return source:sub(1, #root + 1) == root .. "/"
        and (relative:match("^PackerMOD/packs/[^/]+/worlds/[^/]+$") or relative:match("^worlds/[^/]+$")) ~= nil
        and target:sub(1, #root + 12) == root .. "/worlds/_pm_"
        and not target:sub(#root + 13):find("/", 1, true)
end
-- Mainmenu sandbox removes os.execute. Use an atomic directory rename in that
-- environment, with a durable journal so the pack regains its world on return
-- or after a crash. No world data is copied, overwritten or deleted.
function M.recover_launch(user_path)
    local journal = user_path .. "/PackerMOD/launch-world.json"
    local f = io.open(journal, "rb")
    if not f then return true end
    local record = core.parse_json(f:read("*a")); f:close()
    if type(record) ~= "table" or type(record.source) ~= "string" or type(record.target) ~= "string" then return false, "Invalid world launch recovery file" end
    if not valid_launch_paths(user_path, record.source, record.target) then
        return false, "Invalid world launch recovery paths"
    end
    local at_source, at_target = file_exists(record.source .. "/world.mt"), file_exists(record.target .. "/world.mt")
    if at_source and at_target then return false, "World recovery conflict; both locations exist" end
    if not at_source and not at_target then return false, "World recovery source is missing" end
    if at_target then
        local ok, err = os.rename(record.target, record.source)
        if not ok then return false, err end
    end
    if not os.remove(journal) then return false, "Cannot clear world launch recovery file" end
    return true
end

function M.is_launch_link(world, link_name)
    return (world.path or ""):match("([^/\\]+)[/\\]*$") == link_name
end

-- <user>/worlds/_pm_<random> を作って、それを Luanti に「見える world」として認識させる。
-- 戻り値: link 名 (例 "_pm_1782695620_3a7f") または false, err
local function create_launch_symlink(user_path, target_world_path, create_symlink_fn)
    local create = create_symlink_fn or default_create_symlink
    local link_name = string.format("_pm_%d_%04x", os.time(), math.random(0, 0xFFFF))
    local link_path = user_path .. "/worlds/" .. link_name
    if not create_symlink_fn and not os.execute then
        local ok, err = M.recover_launch(user_path)
        if not ok then return false, err end
        if not core.create_dir(user_path .. "/worlds") then return false, "Cannot create launch directory" end
        if not valid_launch_paths(user_path, target_world_path, link_path) then return false, "Invalid world launch paths" end
        for _, name in ipairs(core.get_dir_list(user_path .. "/worlds", true)) do
            if name == link_name then return false, "Launch destination exists" end
        end
        if file_exists(link_path .. "/world.mt") then return false, "Launch destination exists" end
        local journal = user_path .. "/PackerMOD/launch-world.json"
        if not core.safe_file_write(journal, core.write_json({ source = target_world_path, target = link_path })) then return false, "Cannot save launch recovery file" end
        local moved, move_error = os.rename(target_world_path, link_path)
        if not moved then os.remove(journal); return false, move_error end
        -- The editor/session must follow the temporary path until the menu
        -- restores the world. Callers keep the same world object.
        return link_name, link_path
    end
    local ok = create(target_world_path, link_path)
    if not ok then return false, "failed to create launch symlink: " .. link_path end
    return link_name, link_path
end

function M.new(opts)
    local user_path = assert(opts.user_path, "pack_launcher.new: user_path required")
    local world_builder = assert(opts.world_builder, "pack_launcher.new: world_builder required")
    local mod_installer = assert(opts.mod_installer, "pack_launcher.new: mod_installer required")
    local pack_manager = opts.pack_manager
    local server_list = opts.server_list
    local create_symlink = opts.create_symlink

    local self = {}

    function self.new_world(pack, world_opts)
        world_opts = world_opts or {}
        local ok, info = world_builder.create_world(pack.manifest, user_path, {
            world_name = world_opts.world_name,
        })
        if not ok then return false, info end
        local function rollback(reason)
            local removed, err = world_builder.delete_world(pack.manifest.id, info.world_name, user_path)
            return false, tostring(reason) .. (removed and "" or ("; cannot remove incomplete world: " .. tostring(err)))
        end
        local mok, merr = mod_installer.install_all(pack.manifest, info.world_path, pack.path)
        if not mok then return rollback(merr) end
        if opts.world_sync then
            local saved, err = opts.world_sync.record(pack, info.world_path)
            if not saved then return rollback("cannot save Pack state: " .. tostring(err)) end
        end
        return true, info
    end

    -- 後方互換: 旧 `launch(pack)` (auto-name) は廃止。明示名が必須。
    -- 既存テストとの互換のため world_name 既定値 "main" を当てる。
    function self.launch(pack)
        return self.new_world(pack, { world_name = "main" })
    end

    function self.list_worlds(pack)
        if not pack_manager then return {} end
        return pack_manager.list_worlds(pack.id, { user_path = user_path })
    end

    function self.list_legacy_worlds(pack)
        if not pack_manager or not pack_manager.list_legacy_worlds then return {} end
        return pack_manager.list_legacy_worlds(pack.id)
    end

    function self.list_servers(pack)
        if not server_list then return {} end
        return server_list.load(pack.path)
    end

    -- 既存 world (subdir または legacy flat) をプレイするための launch path を作る。
    -- 戻り値: link_name (string)、または false, err
    function self.prepare_launch(world, pack)
        if opts.world_sync and pack then
            local ok, err = opts.world_sync.sync(pack, world)
            if not ok then return false, err end
        end
        if opts.prepare_world_settings then
            local ok, err = opts.prepare_world_settings(world)
            if not ok then return false, err or "Cannot prepare world settings" end
        end
        local name, path = create_launch_symlink(user_path, world.path, create_symlink)
        if name and not create_symlink and not os.execute then world.path = path end
        return name, path
    end
    function self.begin_world_settings(world)
        if opts.begin_world_settings then
            local ok, err = opts.begin_world_settings(world)
            if not ok then self.cancel_launch(); return false, err end
        end
        return true
    end
    function self.cancel_launch()
        if opts.cancel_world_settings then
            local ok, err = opts.cancel_world_settings()
            if not ok then return false, err end
        end
        return M.recover_launch(user_path)
    end

    -- world を物理削除する。subdir は delete_world、legacy flat は delete_legacy_world に振り分け。
    function self.delete_world(pack, world)
        if world.legacy then
            return world_builder.delete_legacy_world(world.name, user_path)
        end
        return world_builder.delete_world(pack.id, world.name, user_path)
    end

    return self
end

-- 起動毎に残った _pm_* シンボリックリンクを掃除する。
-- ln -s / mklink /J 経由なので、リンクを消してもリンク先(本物の world)には影響しない。
function M.cleanup_symlinks(user_path, opts)
    opts = opts or {}
    local list_dir = opts.list_dir or function(p)
        if core and core.get_dir_list then return core.get_dir_list(p, true) end
        return nil
    end
    local delete_dir = opts.delete_dir or function(p)
        -- Never recursively delete an unrecognized launch directory: it may
        -- contain a recoverable world. remove() only unlinks or removes empties.
        return os.remove(p)
    end

    local worlds_dir = user_path .. "/worlds"
    local entries = list_dir(worlds_dir) or {}
    local removed = {}
    for _, name in ipairs(entries) do
        if name:sub(1, 4) == "_pm_" then
            if delete_dir(worlds_dir .. "/" .. name) then removed[#removed + 1] = name end
        end
    end
    return removed
end

return M
