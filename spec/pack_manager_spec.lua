package.path = "./?.lua;" .. package.path

local pm = require("mainmenu.pack_manager")

local function fake_world(name, path, gameid)
    return { name = name, path = path, gameid = gameid }
end

describe("pack_manager.list_worlds (subdir layout)", function()
    it("returns worlds found under PackerMOD/packs/<id>/worlds/", function()
        local files = {
            ["/user/PackerMOD/packs/mypack/worlds/alpha/world.mt"] =
                "gameid = base_1\nworld_name = Alpha World\n",
            ["/user/PackerMOD/packs/mypack/worlds/beta/world.mt"] =
                "gameid = base_1\nworld_name = Beta\n",
        }
        local got = pm.list_worlds("mypack", {
            user_path = "/user",
            list_dir = function(p)
                if p == "/user/PackerMOD/packs/mypack/worlds" then return { "alpha", "beta" } end
                return nil
            end,
            read_file = function(p) return files[p] end,
        })
        assert.are.equal(2, #got)
        -- ソート順: Alpha World < Beta
        assert.are.equal("alpha", got[1].name)
        assert.are.equal("Alpha World", got[1].display_name)
        assert.are.equal("/user/PackerMOD/packs/mypack/worlds/alpha", got[1].path)
        assert.are.equal("beta", got[2].name)
        assert.are.equal("Beta", got[2].display_name)
    end)

    it("returns empty when worlds dir is empty", function()
        local got = pm.list_worlds("mypack", {
            user_path = "/user",
            list_dir = function() return {} end,
            read_file = function() return nil end,
        })
        assert.are.equal(0, #got)
    end)

    it("skips entries without world.mt", function()
        local got = pm.list_worlds("mypack", {
            user_path = "/user",
            list_dir = function() return { "broken" } end,
            read_file = function() return nil end,
        })
        assert.are.equal(0, #got)
    end)

    it("falls back to dir name when world.mt has no world_name line", function()
        local got = pm.list_worlds("mypack", {
            user_path = "/user",
            list_dir = function() return { "named_dir" } end,
            read_file = function() return "gameid = base_1\n" end,
        })
        assert.are.equal(1, #got)
        assert.are.equal("named_dir", got[1].display_name)
    end)
end)

describe("pack_manager.list_legacy_worlds", function()
    -- core.get_worlds の `name` は world.mt の world_name(display)で、
    -- ディレクトリ名ではない。fake_world はその挙動を模擬する。
    it("returns flat-layout worlds whose world.mt has matching packermod_pack_id", function()
        local files = {
            ["/w/sample_pack__1782641958/world.mt"] =
                "gameid = base_1\npackermod_pack_id = sample_pack\nworld_name = Sample\n",
            ["/w/other__123/world.mt"] =
                "gameid = base_1\npackermod_pack_id = other\nworld_name = Other\n",
        }
        local got = pm.list_legacy_worlds("sample_pack", {
            get_worlds = function()
                return {
                    fake_world("Sample",  "/w/sample_pack__1782641958", "base_1"),
                    fake_world("Other",   "/w/other__123", "base_1"),
                }
            end,
            read_file = function(p) return files[p] end,
        })
        assert.are.equal(1, #got)
        -- legacy.name はディレクトリ名(削除対象として扱える)
        assert.are.equal("sample_pack__1782641958", got[1].name)
        assert.are.equal("Sample", got[1].display_name)
        assert.is_true(got[1].legacy)
    end)

    it("ignores active _pm_* symlinks (dir name based)", function()
        local got = pm.list_legacy_worlds("sample_pack", {
            get_worlds = function()
                return { fake_world("X", "/w/_pm_test", "base_1") }
            end,
            read_file = function()
                return "packermod_pack_id = sample_pack\nworld_name = X\n"
            end,
        })
        assert.are.equal(0, #got)
    end)

    it("detects legacy world by <pack_id>__ prefix even if world.mt lacks packermod_pack_id", function()
        local got = pm.list_legacy_worlds("sample_pack", {
            get_worlds = function()
                -- display name は "Sample Pack"(world.mt の world_name)
                -- ディレクトリ名は path 末尾 "sample_pack__1782641958"
                return { fake_world("Sample Pack", "/w/sample_pack__1782641958", "base_1") }
            end,
            -- 旧 world.mt は packermod_pack_id 行が無い
            read_file = function() return "gameid = base_1\nworld_name = Sample Pack\n" end,
        })
        assert.are.equal(1, #got)
        assert.are.equal("sample_pack__1782641958", got[1].name)
        assert.are.equal("Sample Pack", got[1].display_name)
        assert.is_true(got[1].legacy)
    end)
end)

describe("pack_manager.get_thumbnail_path", function()
    it("returns the pack's thumbnail.png when it exists", function()
        local pack = { id = "p", path = "/user/PackerMOD/packs/p" }
        local got = pm.get_thumbnail_path(pack, {
            exists = function(p) return p == "/user/PackerMOD/packs/p/thumbnail.png" end,
            default_path = "/default.png",
        })
        assert.are.equal("/user/PackerMOD/packs/p/thumbnail.png", got)
    end)

    it("falls back to default when thumbnail.png is missing", function()
        local pack = { id = "p", path = "/user/PackerMOD/packs/p" }
        local got = pm.get_thumbnail_path(pack, {
            exists = function() return false end,
            default_path = "/default.png",
        })
        assert.are.equal("/default.png", got)
    end)
end)
