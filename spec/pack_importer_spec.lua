package.path = "./?.lua;" .. package.path

local manifest_mod = require("mainmenu.manifest")
local pack_importer = require("mainmenu.pack_importer")

local SAMPLE_YAML = table.concat({
    "schema_version: 1",
    "id: imported_pack",
    "name: Imported Pack",
    'version: "1.0.0"',
    "base_game:",
    "  id: packerbase",
    '  version: "0.91"',
    "",
}, "\n")

local BAD_YAML = table.concat({
    "schema_version: 1",
    "name: Missing id",
    'version: "1.0.0"',
    "base_game:",
    "  id: packerbase",
    '  version: "0.91"',
    "",
}, "\n")

local function fake_fs(initial_files)
    local files = {}
    for k, v in pairs(initial_files or {}) do files[k] = v end
    local existing = {}
    for k in pairs(files) do existing[k] = true end
    return {
        files = files,
        existing = existing,
        deleted = {},
        mkdirs = {},
        copies = {},
        downloads = {},
        extracts = {},

        read_file = function(self, path) return self.files[path] end,
        write_file = function(self, path, content)
            self.files[path] = content
            self.existing[path] = true
            return true
        end,
        mkdir = function(self, path)
            table.insert(self.mkdirs, path)
            self.existing[path] = true
            return true
        end,
        delete_dir = function(self, path)
            table.insert(self.deleted, path)
            self.existing[path] = nil
            return true
        end,
        copy_dir = function(self, src, dst, keep)
            table.insert(self.copies, { src = src, dst = dst, keep = keep })
            self.existing[dst] = true
            return true
        end,
        extract_zip = function(self, zip, dst)
            table.insert(self.extracts, { zip = zip, dst = dst })
            self.existing[dst] = true
            local marker = self.files["__zip:" .. zip]
            if marker then
                self.files[dst .. "/manifest.yaml"] = marker
            end
            return true
        end,
        exists = function(self, path) return self.existing[path] == true end,
    }
end

local function fs_iface(t)
    return {
        read_file = function(p) return t:read_file(p) end,
        write_file = function(p, c) return t:write_file(p, c) end,
        mkdir = function(p) return t:mkdir(p) end,
        delete_dir = function(p) return t:delete_dir(p) end,
        copy_dir = function(s, d, k) return t:copy_dir(s, d, k) end,
        extract_zip = function(z, d) return t:extract_zip(z, d) end,
        exists = function(p) return t:exists(p) end,
    }
end

local function fake_client()
    return {
        downloads = {},
        download = function(self, url, dest)
            table.insert(self.downloads, { url = url, dest = dest })
            return true
        end,
    }
end

local function client_iface(t, fake_fs_t, payload_for_url)
    return {
        download = function(url, dest)
            local r = t:download(url, dest)
            if payload_for_url and payload_for_url[url] then
                fake_fs_t.files[dest] = payload_for_url[url]
                fake_fs_t.existing[dest] = true
            end
            return r
        end,
    }
end

local function new_importer(fs_t, client_t, opts)
    opts = opts or {}
    return pack_importer.new({
        fs = fs_iface(fs_t),
        user_path = "/user",
        manifest = manifest_mod,
        contentdb_client = client_iface(client_t, fs_t, opts.url_payloads),
    })
end

describe("pack_importer.import_from_path yaml", function()
    it("writes manifest.yaml under packs/<id>/", function()
        local fs_t = fake_fs({ ["/tmp/my.yaml"] = SAMPLE_YAML })
        local cl = fake_client()
        local pi = new_importer(fs_t, cl)
        local ok, id = pi.import_from_path("/tmp/my.yaml")
        assert.is_true(ok)
        assert.are.equal("imported_pack", id)
        assert.are.equal(SAMPLE_YAML, fs_t.files["/user/PackerMOD/packs/imported_pack/manifest.yaml"])
    end)

    it("rejects invalid manifest without writing", function()
        local fs_t = fake_fs({ ["/tmp/bad.yaml"] = BAD_YAML })
        local cl = fake_client()
        local pi = new_importer(fs_t, cl)
        local ok, err = pi.import_from_path("/tmp/bad.yaml")
        assert.is_false(ok)
        assert.is_truthy(err)
        for path in pairs(fs_t.files) do
            assert.is_falsy(path:find("^/user/PackerMOD/packs/"), "wrote to packs/: " .. path)
        end
    end)
end)

describe("pack_importer.import_from_path zip", function()
    it("extracts to temp, validates, copies to packs/<id>/", function()
        local fs_t = fake_fs({
            ["/tmp/x.zip"] = "ZIP_BYTES",
            ["__zip:/tmp/x.zip"] = SAMPLE_YAML,
        })
        local cl = fake_client()
        local pi = new_importer(fs_t, cl)
        local ok, id = pi.import_from_path("/tmp/x.zip")
        assert.is_true(ok)
        assert.are.equal("imported_pack", id)
        assert.are.equal(1, #fs_t.extracts)
        local copied_to = nil
        for _, c in ipairs(fs_t.copies) do
            if c.dst == "/user/PackerMOD/packs/imported_pack" then copied_to = c end
        end
        assert.is_truthy(copied_to, "must copy to packs/<id>/")
    end)

    it("does not pollute packs/ on validation failure", function()
        local fs_t = fake_fs({
            ["/tmp/bad.zip"] = "ZIP",
            ["__zip:/tmp/bad.zip"] = BAD_YAML,
        })
        local cl = fake_client()
        local pi = new_importer(fs_t, cl)
        local ok, err = pi.import_from_path("/tmp/bad.zip")
        assert.is_false(ok)
        assert.is_truthy(err)
        for _, c in ipairs(fs_t.copies) do
            assert.is_falsy(c.dst:find("^/user/PackerMOD/packs/"), "copied to packs/: " .. c.dst)
        end
    end)
end)

describe("pack_importer.import_from_url", function()
    it("downloads then dispatches by extension", function()
        local fs_t = fake_fs({})
        local cl = fake_client()
        local pi = new_importer(fs_t, cl, {
            url_payloads = { ["https://example.com/p.yaml"] = SAMPLE_YAML },
        })
        local ok, id = pi.import_from_url("https://example.com/p.yaml")
        assert.is_true(ok)
        assert.are.equal("imported_pack", id)
        assert.are.equal(1, #cl.downloads)
    end)
end)
