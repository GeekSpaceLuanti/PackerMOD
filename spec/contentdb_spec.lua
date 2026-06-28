package.path = "./?.lua;" .. package.path

local contentdb_mod = require("mainmenu.contentdb")

local function fake_http(handler)
    return {
        fetch_sync = function(_, req)
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
