package.path = "./?.lua;" .. package.path

local pack_launcher = require("mainmenu.pack_launcher")

local function fake_world_builder(behavior)
    return {
        create_world = function(manifest, user_path)
            if behavior == "fail" then return false, "world creation failed" end
            return true, {
                world_path = user_path .. "/worlds/" .. manifest.id .. "__1",
                world_name = manifest.id .. "__1",
                gameid = "packerbase_0_91",
            }
        end,
    }
end

local function fake_installer(behavior, log)
    return {
        install_all = function(manifest, world_path, pack_dir)
            table.insert(log, { manifest = manifest.id, world_path = world_path, pack_dir = pack_dir })
            if behavior == "fail" then return false, "mod install failed" end
            return true, manifest.mods and { manifest.mods[1] and manifest.mods[1].name or nil } or {}
        end,
    }
end

describe("pack_launcher.launch", function()
    it("creates world then installs mods", function()
        local log = {}
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", log),
        })
        local pack = {
            id = "sample",
            path = "/user/PackerMOD/packs/sample",
            manifest = { id = "sample", mods = { { name = "m" } } },
        }
        local ok, info = pl.launch(pack)
        assert.is_true(ok)
        assert.are.equal("packerbase_0_91", info.gameid)
        assert.are.equal(1, #log)
        assert.are.equal("/user/worlds/sample__1", log[1].world_path)
        assert.are.equal("/user/PackerMOD/packs/sample", log[1].pack_dir)
    end)

    it("returns false when world_builder fails (no mod install)", function()
        local log = {}
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("fail"),
            mod_installer = fake_installer("ok", log),
        })
        local ok, err = pl.launch({ id = "x", path = "/p", manifest = { id = "x" } })
        assert.is_false(ok)
        assert.is_truthy(err:find("world creation"))
        assert.are.equal(0, #log)
    end)

    it("returns false when mod installer fails", function()
        local log = {}
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("fail", log),
        })
        local ok, err = pl.launch({ id = "x", path = "/p", manifest = { id = "x", mods = { { name = "m" } } } })
        assert.is_false(ok)
        assert.is_truthy(err:find("mod install"))
    end)
end)
