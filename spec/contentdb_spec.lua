package.path = "./?.lua;" .. package.path

local contentdb_mod = require("mainmenu.contentdb")

local function fake_http(handler)
    return {
        fetch_sync = function(req)
            return handler(req)
        end,
    }
end

local function identity_json(x) return x end

describe("contentdb.search", function()
    it("builds query path with type=mod and q=", function()
        local seen
        local client = contentdb_mod.new({
            http = fake_http(function(req)
                seen = req
                return { succeeded = true, code = 200, data = { { author = "Jeija", name = "mesecons" } } }
            end),
            parse_json = identity_json,
            base_url = "https://example.test",
        })
        local r, err = client.search("mesecons")
        assert.is_nil(err)
        assert.are.equal("https://example.test/api/packages/?type=mod&q=mesecons", seen.url)
        assert.are.equal("Jeija", r[1].author)
    end)

    it("escapes spaces in query", function()
        local seen
        local client = contentdb_mod.new({
            http = fake_http(function(req)
                seen = req
                return { succeeded = true, code = 200, data = {} }
            end),
            parse_json = identity_json,
        })
        client.search("two words")
        assert.is_truthy(seen.url:find("q=two%%20words", 1) or seen.url:find("q=two+words", 1))
    end)

    it("surfaces HTTP failure", function()
        local client = contentdb_mod.new({
            http = fake_http(function() return { succeeded = false, code = 502 } end),
            parse_json = identity_json,
        })
        local r, err = client.search("x")
        assert.is_nil(r)
        assert.is_truthy(err:find("502") or err:find("HTTP"))
    end)
end)

describe("contentdb.get_releases", function()
    it("hits /api/packages/<id>/releases/", function()
        local seen
        local client = contentdb_mod.new({
            http = fake_http(function(req)
                seen = req
                return { succeeded = true, code = 200, data = { { id = 12345, title = "1.0" } } }
            end),
            parse_json = identity_json,
        })
        local r = client.get_releases("Jeija/mesecons")
        assert.is_truthy(seen.url:find("/api/packages/Jeija/mesecons/releases/", 1, true))
        assert.are.equal(12345, r[1].id)
    end)
end)

describe("contentdb.download", function()
    it("writes response body to destination path", function()
        local tmp = os.tmpname()
        local client = contentdb_mod.new({
            http = fake_http(function() return { succeeded = true, code = 200, data = "ZIP_BYTES" } end),
            parse_json = identity_json,
        })
        local ok = client.download("https://example.test/file.zip", tmp)
        assert.is_true(ok)
        local f = io.open(tmp, "rb"); local got = f:read("*a"); f:close()
        os.remove(tmp)
        assert.are.equal("ZIP_BYTES", got)
    end)

    it("returns false on http failure without writing", function()
        local tmp = os.tmpname()
        os.remove(tmp)
        local client = contentdb_mod.new({
            http = fake_http(function() return { succeeded = false, code = 404 } end),
            parse_json = identity_json,
        })
        local ok, err = client.download("https://example.test/x", tmp)
        assert.is_false(ok)
        assert.is_truthy(err)
        local exists = io.open(tmp, "r")
        assert.is_nil(exists)
    end)
end)

describe("ContentDB thumbnails", function()
    local previous_core, previous_packermod, previous_delimiter
    local jobs
    before_each(function()
        previous_core, previous_packermod, previous_delimiter = core, packermod, DIR_DELIM
        jobs = {}
        _G.core = {
            settings = { get = function() return "https://mirror.example:8443" end },
            sha1 = function(url) return url:gsub("[^%w]", "_") end,
            create_dir = function() return true end,
            get_us_time = function() return 1 end,
            handle_async = function(_, params) jobs[#jobs + 1] = params end,
        }
        _G.packermod = { user_path = "missing-thumbnail-fixture", textures_dir = "/textures/" }
        _G.DIR_DELIM = "/"
    end)
    after_each(function()
        _G.core, _G.packermod, _G.DIR_DELIM = previous_core, previous_packermod, previous_delimiter
    end)

    it("downloads only visible thumbnails from the configured and official origins", function()
        local catalog = dofile("mainmenu/mod_catalog.lua")
        local results = {
            { thumbnail = "https://content.luanti.org/thumbnails/1/target.jpg.png" },
            { thumbnail = "https://127.0.0.1/private.jpg" },
            { thumbnail = "/thumbnails/example.jpg" },
            { thumbnail = "https://content.luanti.org/thumbnails/1/next.png" },
        }
        catalog.prefetch(results, 1, function() end)
        catalog.prefetch(results, 1, function() end)
        assert.equal(2, #jobs)
        assert.equal(results[1].thumbnail, jobs[1].url)
        assert.equal("https://mirror.example:8443/thumbnails/example.jpg", jobs[2].url)
        assert.matches("packermod_default_pack_thumbnail.png", catalog.view(results, 1)[2].image, 1, true)
        catalog.prefetch(results, 2, function() end)
        assert.equal(3, #jobs)
        assert.equal(results[4].thumbnail, jobs[3].url)
    end)
end)

describe("contentdb release_download_url", function()
    it("returns absolute URL when release info has url field (absolute)", function()
        assert.are.equal(
            "https://content.luanti.org/uploads/foo.zip",
            contentdb_mod.release_download_url({ url = "https://content.luanti.org/uploads/foo.zip" }))
    end)
    it("returns absolute URL when release info has url field (relative)", function()
        assert.are.equal(
            "https://content.luanti.org/uploads/foo.zip",
            contentdb_mod.release_download_url({ url = "/uploads/foo.zip" }))
    end)
end)
