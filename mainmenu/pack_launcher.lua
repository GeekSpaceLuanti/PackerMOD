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

-- <user>/worlds/_pm_<random> を作って、それを Luanti に「見える world」として認識させる。
-- 戻り値: link 名 (例 "_pm_1782695620_3a7f") または false, err
local function create_launch_symlink(user_path, target_world_path, create_symlink_fn)
    local create = create_symlink_fn or default_create_symlink
    local link_name = string.format("_pm_%d_%04x", os.time(), math.random(0, 0xFFFF))
    local link_path = user_path .. "/worlds/" .. link_name
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
        local mok, merr = mod_installer.install_all(pack.manifest, info.world_path, pack.path)
        if not mok then return false, merr end
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
    function self.prepare_launch(world)
        return create_launch_symlink(user_path, world.path, create_symlink)
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
        if core and core.delete_dir then return core.delete_dir(p) end
        if is_windows() then
            os.execute(('cmd /c rmdir %q'):format(p:gsub("/", "\\")))
        else
            -- ln -s で作った symlink なら rm で消える(リンク先は無事)
            os.execute(('rm -f %q'):format(p))
        end
        return true
    end

    local worlds_dir = user_path .. "/worlds"
    local entries = list_dir(worlds_dir) or {}
    local removed = {}
    for _, name in ipairs(entries) do
        if name:sub(1, 4) == "_pm_" then
            delete_dir(worlds_dir .. "/" .. name)
            removed[#removed + 1] = name
        end
    end
    return removed
end

return M
