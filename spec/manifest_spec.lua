package.path = "./?.lua;" .. package.path

local manifest = require("mainmenu.manifest")

local function read_fixture(name)
    local f = assert(io.open("test_fixtures/" .. name, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

describe("manifest.parse", function()
    it("parses the sample fixture", function()
        local ok, m = manifest.parse(read_fixture("sample_pack.yaml"))
        assert.is_true(ok)
        assert.are.equal("sample_pack", m.id)
        assert.are.equal("Sample Pack", m.name)
        assert.are.equal("packerbase", m.base_game.id)
        assert.are.equal("0.91", m.base_game.version)
        assert.are.equal(3, #m.mods)
        assert.are.equal("mesecons", m.mods[1].name)
        assert.are.equal(12345, m.mods[1].release)
        assert.are.equal("bundle", m.mods[2].source)
        assert.are.equal("https://example.com/mod.zip", m.mods[3].url)
        assert.are.equal("v7", m.settings.mg_name)
    end)

    it("rejects missing required fields", function()
        local ok, e = manifest.parse("schema_version: 1\nid: foo\n")
        assert.is_false(ok)
        assert.is_truthy(e:find("name"))
    end)

    it("rejects unknown mod source", function()
        local yaml = table.concat({
            "schema_version: 1",
            "id: p",
            "name: P",
            'version: "1"',
            "base_game:",
            "  id: packerbase",
            '  version: "0.91"',
            "mods:",
            "  - name: a",
            "    source: ftp",
            "",
        }, "\n")
        local ok, e = manifest.parse(yaml)
        assert.is_false(ok)
        assert.is_truthy(e:find("source"))
    end)

    it("rejects bad id chars", function()
        local yaml = table.concat({
            "schema_version: 1",
            'id: "bad id!"',
            "name: P",
            'version: "1"',
            "base_game:",
            "  id: packerbase",
            '  version: "0.91"',
            "",
        }, "\n")
        local ok, e = manifest.parse(yaml)
        assert.is_false(ok)
        assert.is_truthy(e:find("id"))
    end)

    it("rejects wrong schema_version", function()
        local ok, e = manifest.parse("schema_version: 99\nid: p\nname: P\nversion: \"1\"\nbase_game:\n  id: x\n  version: \"1\"\n")
        assert.is_false(ok)
        assert.is_truthy(e:find("schema_version"))
    end)
end)

describe("manifest.dump", function()
    it("round-trips the sample fixture", function()
        local ok, m = manifest.parse(read_fixture("sample_pack.yaml"))
        assert.is_true(ok)
        local dok, dumped = manifest.dump(m)
        assert.is_true(dok)
        local ok2, m2 = manifest.parse(dumped)
        assert.is_true(ok2, m2)
        assert.are.same(m, m2)
    end)
end)
