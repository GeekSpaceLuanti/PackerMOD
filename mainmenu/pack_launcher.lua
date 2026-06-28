local M = {}

function M.new(opts)
    local user_path = assert(opts.user_path, "pack_launcher.new: user_path required")
    local world_builder = assert(opts.world_builder, "pack_launcher.new: world_builder required")
    local mod_installer = assert(opts.mod_installer, "pack_launcher.new: mod_installer required")

    local self = {}

    function self.launch(pack)
        local ok, info = world_builder.create_world(pack.manifest, user_path)
        if not ok then return false, info end
        local mok, merr = mod_installer.install_all(pack.manifest, info.world_path, pack.path)
        if not mok then return false, merr end
        return true, info
    end

    return self
end

return M
