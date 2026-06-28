package.path = "./?.lua;" .. package.path

local manifest_mod = require("mainmenu.manifest")
local pack_builder = require("mainmenu.pack_builder")

describe("pack_builder.build_manifest", function()
    it("composes a valid manifest from tabdata", function()
        local tabdata = {
            pack_id = "my_pack", pack_name = "My Pack", pack_version = "1.0.0",
            pack_description = "hello", pack_author = "bacon",
            base_id = "packerbase", base_version = "0.91",
            mods = {
                { name = "mesecons", source = "contentdb", package = "Jeija/mesecons", release = 12345 },
            },
            settings = { enable_damage = true },
        }
        local ok, m = pack_builder.build_manifest(tabdata)
        assert.is_true(ok, m)
        assert.are.equal("my_pack", m.id)
        assert.are.equal(1, m.schema_version)
        assert.are.equal("packerbase", m.base_game.id)
        assert.are.equal(1, #m.mods)
        local _, parsed = manifest_mod.parse(select(2, manifest_mod.dump(m)))
        assert.are.equal("my_pack", parsed.id)
    end)

    it("fails when required fields are missing", function()
        local ok, err = pack_builder.build_manifest({ pack_id = "", pack_name = "x", pack_version = "1" })
        assert.is_false(ok)
        assert.is_truthy(err)
    end)
end)

describe("pack_builder.add_mod", function()
    it("appends a mod to tabdata.mods", function()
        local tabdata = {}
        pack_builder.add_mod(tabdata, { name = "a", source = "contentdb", package = "Z/a", release = 1 })
        assert.are.equal(1, #tabdata.mods)
        assert.are.equal("a", tabdata.mods[1].name)
    end)

    it("rejects duplicate names", function()
        local tabdata = { mods = { { name = "a", source = "contentdb", package = "Z/a", release = 1 } } }
        local ok, err = pack_builder.add_mod(tabdata, { name = "a", source = "contentdb", package = "Z/a", release = 2 })
        assert.is_false(ok)
        assert.is_truthy(err:find("duplicate"))
    end)
end)

describe("pack_builder.remove_mod", function()
    it("removes by 1-based index", function()
        local tabdata = { mods = { { name = "a" }, { name = "b" }, { name = "c" } } }
        pack_builder.remove_mod(tabdata, 2)
        assert.are.equal(2, #tabdata.mods)
        assert.are.equal("a", tabdata.mods[1].name)
        assert.are.equal("c", tabdata.mods[2].name)
    end)

    it("noop on out of range", function()
        local tabdata = { mods = { { name = "a" } } }
        pack_builder.remove_mod(tabdata, 5)
        assert.are.equal(1, #tabdata.mods)
    end)
end)

describe("pack_builder.contentdb_result_to_mod", function()
    it("maps a ContentDB package + release id to mod spec", function()
        local m = pack_builder.contentdb_result_to_mod(
            { author = "Jeija", name = "mesecons" }, 12345)
        assert.are.same({
            name = "mesecons",
            source = "contentdb",
            package = "Jeija/mesecons",
            release = 12345,
        }, m)
    end)
end)
