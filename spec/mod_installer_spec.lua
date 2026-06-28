package.path = "./?.lua;" .. package.path

local mod_installer = require("mainmenu.mod_installer")

local function fake_fs()
    local existing = {}
    return {
        existing = existing,
        copies = {},
        extracts = {},
        mkdirs = {},
        exists = function(self, p) return existing[p] == true end,
        mkdir = function(self, p) table.insert(self.mkdirs, p); existing[p] = true; return true end,
        copy_dir = function(self, src, dst, keep)
            table.insert(self.copies, { src = src, dst = dst, keep = keep })
            existing[dst] = true
            return true
        end,
        extract_zip = function(self, zip, dst)
            table.insert(self.extracts, { zip = zip, dst = dst })
            existing[dst] = true
            return true
        end,
        write_file = function() return true end,
    }
end

local function fs_iface(t)
    return {
        exists = function(p) return t:exists(p) end,
        mkdir = function(p) return t:mkdir(p) end,
        copy_dir = function(s, d, k) return t:copy_dir(s, d, k) end,
        extract_zip = function(z, d) return t:extract_zip(z, d) end,
        write_file = function(p, c) return t:write_file(p, c) end,
    }
end

local function fake_client()
    return {
        resolve_calls = {},
        download_calls = {},
        resolve_release_url = function(self, package_id, release_id)
            table.insert(self.resolve_calls, { p = package_id, r = release_id })
            return "https://content.luanti.org/uploads/" .. package_id:gsub("/", "_") .. "__" .. release_id .. ".zip"
        end,
        download = function(self, url, dest)
            table.insert(self.download_calls, { url = url, dest = dest })
            return true
        end,
    }
end

local function client_iface(t)
    return {
        resolve_release_url = function(p, r) return t:resolve_release_url(p, r) end,
        download = function(u, d) return t:download(u, d) end,
    }
end

local function new_installer(fs_t, client_t)
    return mod_installer.new({
        fs = fs_iface(fs_t),
        contentdb_client = client_iface(client_t),
        cache_dir = "/user/PackerMOD/cache",
    })
end

describe("mod_installer.install_mod bundle", function()
    it("copy_dirs from pack bundled_mods to worldmods target", function()
        local fs_t = fake_fs()
        local cl = fake_client()
        local mi = new_installer(fs_t, cl)
        local ok = mi.install_mod(
            { name = "my_mod", source = "bundle", path = "bundled_mods/my_mod" },
            "/user/worlds/w1/worldmods",
            "/user/PackerMOD/packs/sample")
        assert.is_true(ok)
        assert.are.equal(1, #fs_t.copies)
        assert.are.equal("/user/PackerMOD/packs/sample/bundled_mods/my_mod", fs_t.copies[1].src)
        assert.are.equal("/user/worlds/w1/worldmods/my_mod", fs_t.copies[1].dst)
    end)
end)

describe("mod_installer.install_mod contentdb", function()
    it("resolves URL and downloads when cache misses, then extracts", function()
        local fs_t = fake_fs()
        local cl = fake_client()
        local mi = new_installer(fs_t, cl)
        local ok = mi.install_mod(
            { name = "mesecons", source = "contentdb", package = "Jeija/mesecons", release = 12345 },
            "/user/worlds/w1/worldmods", "/user/PackerMOD/packs/p")
        assert.is_true(ok)
        assert.are.equal(1, #cl.resolve_calls)
        assert.are.equal(1, #cl.download_calls)
        assert.are.equal(1, #fs_t.extracts)
        local expected_zip = "/user/PackerMOD/cache/cdb__Jeija__mesecons__12345.zip"
        assert.are.equal(expected_zip, cl.download_calls[1].dest)
        assert.are.equal(expected_zip, fs_t.extracts[1].zip)
        assert.are.equal("/user/worlds/w1/worldmods/mesecons", fs_t.extracts[1].dst)
    end)

    it("skips download when cache hits", function()
        local fs_t = fake_fs()
        fs_t.existing["/user/PackerMOD/cache/cdb__Jeija__mesecons__12345.zip"] = true
        local cl = fake_client()
        local mi = new_installer(fs_t, cl)
        local ok = mi.install_mod(
            { name = "mesecons", source = "contentdb", package = "Jeija/mesecons", release = 12345 },
            "/user/worlds/w1/worldmods", "/user/PackerMOD/packs/p")
        assert.is_true(ok)
        assert.are.equal(0, #cl.resolve_calls)
        assert.are.equal(0, #cl.download_calls)
        assert.are.equal(1, #fs_t.extracts)
    end)
end)

describe("mod_installer.install_mod url", function()
    it("downloads URL to cache when missing then extracts", function()
        local fs_t = fake_fs()
        local cl = fake_client()
        local mi = new_installer(fs_t, cl)
        local ok = mi.install_mod(
            { name = "ext", source = "url", url = "https://example.com/x.zip", sha256 = "abc" },
            "/user/worlds/w1/worldmods", "/user/PackerMOD/packs/p")
        assert.is_true(ok)
        assert.are.equal(1, #cl.download_calls)
        assert.are.equal("https://example.com/x.zip", cl.download_calls[1].url)
        assert.are.equal(1, #fs_t.extracts)
    end)
end)

describe("mod_installer.install_all", function()
    it("creates worldmods/ and installs every mod", function()
        local fs_t = fake_fs()
        fs_t.existing["/user/PackerMOD/cache/cdb__Jeija__mesecons__12345.zip"] = true
        local cl = fake_client()
        local mi = new_installer(fs_t, cl)
        local manifest = {
            mods = {
                { name = "mesecons", source = "contentdb", package = "Jeija/mesecons", release = 12345 },
                { name = "local_mod", source = "bundle", path = "bundled_mods/local_mod" },
                { name = "ext", source = "url", url = "https://example.com/e.zip" },
            },
        }
        local ok, installed = mi.install_all(manifest, "/user/worlds/w1", "/user/PackerMOD/packs/p")
        assert.is_true(ok)
        assert.are.same({ "mesecons", "local_mod", "ext" }, installed)
        assert.is_truthy(fs_t.existing["/user/worlds/w1/worldmods"])
    end)

    it("returns false with mod name on failure", function()
        local fs_t = fake_fs()
        fs_t.copy_dir = function(self, src, dst, keep)
            return false
        end
        local cl = fake_client()
        local mi = new_installer(fs_t, cl)
        local ok, err = mi.install_all(
            { mods = { { name = "broken", source = "bundle", path = "bundled_mods/broken" } } },
            "/user/worlds/w1", "/user/PackerMOD/packs/p")
        assert.is_false(ok)
        assert.is_truthy(err:find("broken"))
    end)

    it("returns true with empty list when no mods", function()
        local fs_t = fake_fs()
        local cl = fake_client()
        local mi = new_installer(fs_t, cl)
        local ok, installed = mi.install_all({}, "/user/worlds/w1", "/user/PackerMOD/packs/p")
        assert.is_true(ok)
        assert.are.same({}, installed)
    end)
end)
