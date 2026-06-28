package.path = "./?.lua;" .. package.path

local pm = require("mainmenu.pack_manager")

local function fake_world(name, path, gameid)
    return { name = name, path = path, gameid = gameid }
end

describe("pack_manager.list_worlds", function()
    it("returns only worlds whose world.mt has matching packermod_pack_id", function()
        local files = {
            ["/w/a/world.mt"] = "gameid = base_1\npackermod_pack_id = mypack\nworld_name = Alpha\n",
            ["/w/b/world.mt"] = "gameid = base_1\npackermod_pack_id = otherpack\nworld_name = Beta\n",
            ["/w/c/world.mt"] = "gameid = base_1\npackermod_pack_id = mypack\nworld_name = Gamma\n",
        }
        local worlds = {
            fake_world("a", "/w/a", "base_1"),
            fake_world("b", "/w/b", "base_1"),
            fake_world("c", "/w/c", "base_1"),
        }
        local got = pm.list_worlds("mypack", {
            get_worlds = function() return worlds end,
            read_file = function(p) return files[p] end,
        })
        assert.are.equal(2, #got)
        assert.are.equal(1, got[1].index)
        assert.are.equal("Alpha", got[1].display_name)
        assert.are.equal(3, got[2].index)
        assert.are.equal("Gamma", got[2].display_name)
    end)

    it("returns empty when no worlds match", function()
        local got = pm.list_worlds("nope", {
            get_worlds = function() return { fake_world("a", "/w/a", "base_1") } end,
            read_file = function() return "gameid = base_1\npackermod_pack_id = other\n" end,
        })
        assert.are.equal(0, #got)
    end)

    it("falls back to world.name when world.mt has no world_name line", function()
        local got = pm.list_worlds("mypack", {
            get_worlds = function() return { fake_world("rawname", "/w/x", "base_1") } end,
            read_file = function() return "packermod_pack_id = mypack\n" end,
        })
        assert.are.equal(1, #got)
        assert.are.equal("rawname", got[1].display_name)
    end)

    it("ignores worlds with no readable world.mt (e.g. legacy non-PackerMOD)", function()
        local got = pm.list_worlds("mypack", {
            get_worlds = function() return { fake_world("a", "/w/a", "base_1") } end,
            read_file = function() return nil end,
        })
        assert.are.equal(0, #got)
    end)
end)
