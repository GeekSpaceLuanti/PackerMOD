local M = {}

local function pkg_cache_name(package, release)
    return "cdb__" .. package:gsub("/", "__") .. "__" .. tostring(release) .. ".zip"
end

local function url_cache_name(mod_spec)
    return "url__" .. (mod_spec.sha256 or "nohash") .. ".zip"
end

function M.new(opts)
    local fs = opts.fs
    local client = opts.contentdb_client
    local cache_dir = opts.cache_dir
    assert(fs and client and cache_dir, "mod_installer.new: fs, contentdb_client, cache_dir required")

    local self = {}

    function self.cache_path_for(mod_spec)
        if mod_spec.source == "contentdb" then
            return cache_dir .. "/" .. pkg_cache_name(mod_spec.package, mod_spec.release)
        elseif mod_spec.source == "url" then
            return cache_dir .. "/" .. url_cache_name(mod_spec)
        end
    end

    function self.install_mod(mod_spec, worldmods_dir, pack_dir)
        local target = worldmods_dir .. "/" .. mod_spec.name

        if mod_spec.source == "bundle" then
            local src = pack_dir .. "/" .. mod_spec.path
            if not fs.copy_dir(src, target, true) then
                return false, "copy_dir failed"
            end
            return true
        end

        if mod_spec.source == "contentdb" then
            local zip = self.cache_path_for(mod_spec)
            if not fs.exists(zip) then
                local url, rerr = client.resolve_release_url(mod_spec.package, mod_spec.release)
                if not url then return false, "resolve: " .. tostring(rerr) end
                local ok, derr = client.download(url, zip)
                if not ok then return false, "download: " .. tostring(derr) end
            end
            if not fs.extract_zip(zip, target) then return false, "extract failed" end
            return true
        end

        if mod_spec.source == "url" then
            local zip = self.cache_path_for(mod_spec)
            if not fs.exists(zip) then
                local ok, derr = client.download(mod_spec.url, zip)
                if not ok then return false, "download: " .. tostring(derr) end
            end
            if not fs.extract_zip(zip, target) then return false, "extract failed" end
            return true
        end

        return false, "unknown source: " .. tostring(mod_spec.source)
    end

    function self.install_all(manifest, world_path, pack_dir)
        local worldmods_dir = world_path .. "/worldmods"
        fs.mkdir(worldmods_dir)
        local installed = {}
        if not manifest.mods then return true, installed end
        for _, mod in ipairs(manifest.mods) do
            local ok, err = self.install_mod(mod, worldmods_dir, pack_dir)
            if not ok then return false, "mod " .. mod.name .. ": " .. tostring(err) end
            table.insert(installed, mod.name)
        end
        return true, installed
    end

    return self
end

return M
