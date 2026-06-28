package.path = "./?.lua;" .. package.path

local editor = require("mainmenu.pack_editor")
local manifest_mod = require("mainmenu.manifest")

local function make_pack(opts)
    opts = opts or {}
    return {
        id = "p",
        path = "/packs/p",
        manifest = {
            schema_version = 1,
            id = "p",
            name = "P",
            version = "1.0.0",
            base_game = { id = "packerbase", version = "0.91" },
            mods = opts.mods,
            description = opts.description,
        },
    }
end

local function fake_writer()
    local writes = {}
    return writes, function(path, text)
        writes[path] = text
        return true
    end
end

local function opts_with(writer)
    return { manifest_mod = manifest_mod, write_file = writer }
end

describe("pack_editor.add_mod", function()
    it("appends mod and writes manifest.yaml", function()
        local pack = make_pack()
        local writes, w = fake_writer()
        local ok = editor.add_mod(pack,
            { name = "m1", source = "contentdb", package = "a/m1", release = 1 },
            opts_with(w))
        assert.is_true(ok)
        assert.are.equal(1, #pack.manifest.mods)
        assert.is_truthy(writes["/packs/p/manifest.yaml"])
    end)

    it("rejects duplicate mod name", function()
        local pack = make_pack({ mods = { { name = "m1", source = "contentdb", package = "a/m1" } } })
        local _, w = fake_writer()
        local ok, err = editor.add_mod(pack,
            { name = "m1", source = "contentdb", package = "x/m1" },
            opts_with(w))
        assert.is_false(ok)
        assert.is_truthy(err:find("duplicate"))
    end)
end)

describe("pack_editor.remove_mod", function()
    it("removes by index and writes manifest.yaml", function()
        local pack = make_pack({ mods = {
            { name = "m1", source = "contentdb", package = "a/m1" },
            { name = "m2", source = "contentdb", package = "a/m2" },
        } })
        local writes, w = fake_writer()
        local ok = editor.remove_mod(pack, 1, opts_with(w))
        assert.is_true(ok)
        assert.are.equal(1, #pack.manifest.mods)
        assert.are.equal("m2", pack.manifest.mods[1].name)
        assert.is_truthy(writes["/packs/p/manifest.yaml"])
    end)

    it("returns false on out-of-range index", function()
        local pack = make_pack()
        local _, w = fake_writer()
        local ok, err = editor.remove_mod(pack, 99, opts_with(w))
        assert.is_false(ok)
        assert.is_truthy(err:find("out of range"))
    end)
end)

describe("pack_editor.update_meta", function()
    it("updates name / version / description", function()
        local pack = make_pack()
        local writes, w = fake_writer()
        editor.update_meta(pack,
            { name = "P2", version = "2.0.0", description = "hello" },
            opts_with(w))
        assert.are.equal("P2", pack.manifest.name)
        assert.are.equal("2.0.0", pack.manifest.version)
        assert.are.equal("hello", pack.manifest.description)
        assert.is_truthy(writes["/packs/p/manifest.yaml"])
    end)

    it("ignores empty name/version (required fields) but clears description", function()
        local pack = make_pack({ description = "had" })
        local _, w = fake_writer()
        editor.update_meta(pack,
            { name = "", version = "", description = "" },
            opts_with(w))
        assert.are.equal("P", pack.manifest.name)
        assert.are.equal("1.0.0", pack.manifest.version)
        assert.is_nil(pack.manifest.description)
    end)
end)

describe("pack_editor.contentdb_result_to_mod", function()
    it("maps result to manifest mod entry", function()
        local mod = editor.contentdb_result_to_mod(
            { author = "rubenwardy", name = "mesecons", title = "Mesecons" }, 42)
        assert.are.equal("mesecons", mod.name)
        assert.are.equal("contentdb", mod.source)
        assert.are.equal("rubenwardy/mesecons", mod.package)
        assert.are.equal(42, mod.release)
    end)
end)
