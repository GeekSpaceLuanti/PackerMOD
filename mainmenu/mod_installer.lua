local M = {}

local function pkg_cache_name(package, release)
    return "cdb__" .. package:gsub("/", "__") .. "__" .. tostring(release) .. ".zip"
end

local function url_cache_name(mod_spec)
    -- Different URL-only MODs must never share the same cached archive.
    local key = mod_spec.sha256
    if not key then
        if rawget(_G, "core") and core.sha256 then key = core.sha256(mod_spec.url)
        else key = mod_spec.url:gsub(".", function(c) return ("%02x"):format(c:byte()) end) end
    end
    return "url__" .. key .. ".zip"
end

function M.new(opts)
    local fs = opts.fs
    local client = opts.contentdb_client
    local cache_dir = opts.cache_dir
    assert(fs and client and cache_dir, "mod_installer.new: fs, contentdb_client, cache_dir required")

    local self = {}

    local function extract(zip, target)
        -- ContentDB/GitHub archives normally contain one enclosing directory.
        -- Extract beside the destination, then publish the actual MOD root.
        if not fs.list_dir then return fs.extract_zip(zip, target) end
        local stage = target .. ".installing"
        if fs.exists(stage) then return false, "MOD installation already in progress" end
        if not fs.mkdir(stage) then return false, "Cannot stage MOD" end
        if not fs.extract_zip(zip, stage) then
            fs.delete_dir(stage); return false, "extract failed"
        end
        local root = stage
        local function is_mod(path)
            return fs.exists(path .. "/init.lua") or fs.exists(path .. "/modpack.conf")
                or fs.exists(path .. "/modpack.txt")
        end
        if not is_mod(root) then
            local dirs = fs.list_dir(root)
            if #dirs == 1 then root = root .. "/" .. dirs[1] end
        end
        if not is_mod(root) then fs.delete_dir(stage); return false, "Invalid MOD archive" end
        if fs.exists(target) then fs.delete_dir(stage); return false, "MOD destination already exists" end
        local ok, err = fs.rename(root, target)
        if root ~= stage or not ok then fs.delete_dir(stage) end
        return ok and true or false, err
    end

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
            return extract(zip, target)
        end

        if mod_spec.source == "url" then
            local zip = self.cache_path_for(mod_spec)
            if not fs.exists(zip) then
                local ok, derr = client.download(mod_spec.url, zip)
                if not ok then return false, "download: " .. tostring(derr) end
            end
            return extract(zip, target)
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
