package.path = "./?.lua;" .. package.path

local pack_launcher = require("mainmenu.pack_launcher")

local function fake_world_builder(behavior)
    return {
        last_opts = nil,
        create_world = function(manifest, user_path, opts)
            if behavior == "fail" then return false, "world creation failed" end
            local world = (opts and opts.world_name) or (manifest.id .. "__1")
            return true, {
                world_path = user_path .. "/worlds/" .. world,
                world_name = world,
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

describe("pack_launcher.new_world (named)", function()
    it("propagates opts.world_name to world_builder.create_world", function()
        local log = {}
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", log),
        })
        local pack = { id = "p", path = "/p", manifest = { id = "p" } }
        local ok, info = pl.new_world(pack, { world_name = "named1" })
        assert.is_true(ok)
        assert.are.equal("named1", info.world_name)
        assert.are.equal("/user/worlds/named1", info.world_path)
    end)
end)

describe("pack_launcher.list_worlds / list_servers", function()
    it("delegates list_worlds to pack_manager", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
            pack_manager = {
                list_worlds = function(pack_id)
                    return { { name = "w1", path = "/u/w/w1", display_name = "World 1" } }
                end,
            },
        })
        local got = pl.list_worlds({ id = "mypack" })
        assert.are.equal(1, #got)
        assert.are.equal("World 1", got[1].display_name)
    end)

    it("delegates list_servers to server_list", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
            server_list = {
                load = function(pack_path) return { { name = "S", address = "1.1.1.1", port = 30000 } } end,
            },
        })
        local got = pl.list_servers({ id = "x", path = "/packs/x" })
        assert.are.equal(1, #got)
        assert.are.equal("S", got[1].name)
    end)

    it("returns empty when dependencies are not injected", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
        })
        assert.are.equal(0, #pl.list_worlds({ id = "x" }))
        assert.are.equal(0, #pl.list_servers({ id = "x", path = "/p" }))
    end)
end)
