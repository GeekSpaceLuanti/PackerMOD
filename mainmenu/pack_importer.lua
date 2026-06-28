local M = {}

function M.new(opts)
    local fs = assert(opts.fs, "pack_importer.new: fs required")
    local user_path = assert(opts.user_path, "pack_importer.new: user_path required")
    local manifest_mod = assert(opts.manifest, "pack_importer.new: manifest required")
    local client = assert(opts.contentdb_client, "pack_importer.new: contentdb_client required")

    local function packs_root() return user_path .. "/PackerMOD/packs" end
    local function cache_root() return user_path .. "/PackerMOD/cache" end
    local function temp_dir() return cache_root() .. "/_import_temp" end

    local self = {}

    function self.import_from_yaml_text(text)
        local ok, m = manifest_mod.parse(text)
        if not ok then return false, m end
        local target = packs_root() .. "/" .. m.id
        fs.mkdir(packs_root())
        fs.mkdir(target)
        fs.write_file(target .. "/manifest.yaml", text)
        return true, m.id
    end

    function self.import_from_zip(zip_path)
        local temp = temp_dir()
        fs.delete_dir(temp)
        fs.mkdir(temp)
        if not fs.extract_zip(zip_path, temp) then
            fs.delete_dir(temp)
            return false, "extract failed"
        end
        local mtext = fs.read_file(temp .. "/manifest.yaml")
        if not mtext then
            fs.delete_dir(temp)
            return false, "manifest.yaml not found at zip root"
        end
        local ok, m = manifest_mod.parse(mtext)
        if not ok then
            fs.delete_dir(temp)
            return false, m
        end
        local target = packs_root() .. "/" .. m.id
        fs.mkdir(packs_root())
        fs.delete_dir(target)
        if not fs.copy_dir(temp, target, false) then
            return false, "copy_dir to packs/ failed"
        end
        return true, m.id
    end

    function self.import_from_path(path)
        if path:match("%.zip$") then return self.import_from_zip(path) end
        if path:match("%.ya?ml$") then
            local text = fs.read_file(path)
            if not text then return false, "cannot read " .. path end
            return self.import_from_yaml_text(text)
        end
        return false, "unsupported file type: " .. path
    end

    function self.import_from_url(url)
        local is_zip = url:match("%.zip$") ~= nil
        local dest = cache_root() .. (is_zip and "/_import_url.zip" or "/_import_url.yaml")
        fs.mkdir(cache_root())
        local ok, err = client.download(url, dest)
        if not ok then return false, err end
        return self.import_from_path(dest)
    end

    function self.import(source)
        if source:match("^https?://") then return self.import_from_url(source) end
        return self.import_from_path(source)
    end

    return self
end

return M
