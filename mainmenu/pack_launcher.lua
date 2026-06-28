local M = {}

function M.new(opts)
    local user_path = assert(opts.user_path, "pack_launcher.new: user_path required")
    local world_builder = assert(opts.world_builder, "pack_launcher.new: world_builder required")
    local mod_installer = assert(opts.mod_installer, "pack_launcher.new: mod_installer required")
    local pack_manager = opts.pack_manager
    local server_list = opts.server_list

    local self = {}

    function self.new_world(pack, world_opts)
        world_opts = world_opts or {}
        local ok, info = world_builder.create_world(pack.manifest, user_path, {
            world_name = world_opts.world_name,
            display_name = world_opts.display_name,
        })
        if not ok then return false, info end
        local mok, merr = mod_installer.install_all(pack.manifest, info.world_path, pack.path)
        if not mok then return false, merr end
        return true, info
    end

    -- 後方互換: 旧 `launch(pack)` は新規 World を auto-name で作って起動するのと同義
    function self.launch(pack)
        return self.new_world(pack)
    end

    function self.list_worlds(pack)
        if not pack_manager then return {} end
        return pack_manager.list_worlds(pack.id)
    end

    function self.list_servers(pack)
        if not server_list then return {} end
        return server_list.load(pack.path)
    end

    return self
end

return M
