package.path = "./?.lua;" .. package.path

local pack_launcher = require("mainmenu.pack_launcher")

local function fake_world_builder(behavior)
    return {
        create_world = function(manifest, user_path, opts)
            if behavior == "fail" then return false, "world creation failed" end
            local raw = opts and opts.world_name
            local sanitized = raw or "main"
            return true, {
                world_path = user_path .. "/PackerMOD/packs/" .. manifest.id ..
                    "/worlds/" .. sanitized,
                world_name = sanitized,
                display_name = raw,
                gameid = "packerbase_0_91",
            }
        end,
        delete_world = function(pack_id, name, user_path)
            return true, { pack_id = pack_id, name = name, user_path = user_path }
        end,
        delete_legacy_world = function(name, user_path)
            return true, { name = name, user_path = user_path }
        end,
    }
end

local function fake_installer(behavior, log)
    return {
        install_all = function(manifest, world_path, pack_dir)
            table.insert(log, { manifest = manifest.id, world_path = world_path, pack_dir = pack_dir })
            if behavior == "fail" then return false, "mod install failed" end
            return true, {}
        end,
    }
end

describe("pack_launcher.launch / new_world", function()
    it("creates world then installs mods (default world_name=main)", function()
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
        assert.are.equal("/user/PackerMOD/packs/sample/worlds/main", log[1].world_path)
    end)

    it("returns false when world_builder fails", function()
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
        assert.are.equal("/user/PackerMOD/packs/p/worlds/named1", info.world_path)
    end)
end)

describe("pack_launcher.prepare_launch (symlink)", function()
    it("creates a _pm_* symlink pointing at the world path", function()
        local link_calls = {}
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
            create_symlink = function(target, link)
                link_calls[#link_calls + 1] = { target = target, link = link }
                return true
            end,
        })
        local world = { name = "main", path = "/user/PackerMOD/packs/p/worlds/main" }
        local link_name = pl.prepare_launch(world)
        assert.is_truthy(link_name)
        assert.is_truthy(link_name:sub(1, 4) == "_pm_")
        assert.are.equal(1, #link_calls)
        assert.are.equal("/user/PackerMOD/packs/p/worlds/main", link_calls[1].target)
        assert.is_truthy(link_calls[1].link:find("/user/worlds/_pm_", 1, true))
    end)

    it("returns false when symlink creation fails", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
            create_symlink = function() return false end,
        })
        local ok, err = pl.prepare_launch({ name = "x", path = "/x" })
        assert.is_false(ok)
        assert.is_truthy(err:find("symlink"))
    end)
end)

describe("pack_launcher.delete_world", function()
    it("routes subdir worlds to delete_world", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
        })
        local ok = pl.delete_world({ id = "p" }, { name = "main" })
        assert.is_true(ok)
    end)

    it("routes legacy flat worlds to delete_legacy_world", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
        })
        local ok = pl.delete_world({ id = "p" }, { name = "sample_pack__123", legacy = true })
        assert.is_true(ok)
    end)
end)

describe("pack_launcher.list_worlds / list_legacy_worlds / list_servers", function()
    it("delegates list_worlds to pack_manager with user_path", function()
        local seen = {}
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
            pack_manager = {
                list_worlds = function(pack_id, opts)
                    seen[#seen + 1] = { pack_id = pack_id, user_path = opts and opts.user_path }
                    return { { name = "w1", display_name = "W1" } }
                end,
            },
        })
        local got = pl.list_worlds({ id = "mypack" })
        assert.are.equal(1, #got)
        assert.are.equal("mypack", seen[1].pack_id)
        assert.are.equal("/user", seen[1].user_path)
    end)

    it("delegates list_legacy_worlds when available", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
            pack_manager = {
                list_worlds = function() return {} end,
                list_legacy_worlds = function() return { { name = "legacy", legacy = true } } end,
            },
        })
        local got = pl.list_legacy_worlds({ id = "x" })
        assert.are.equal(1, #got)
        assert.is_true(got[1].legacy)
    end)

    it("delegates list_servers to server_list", function()
        local pl = pack_launcher.new({
            user_path = "/user",
            world_builder = fake_world_builder("ok"),
            mod_installer = fake_installer("ok", {}),
            server_list = {
                load = function() return { { name = "S", address = "1.1.1.1", port = 30000 } } end,
            },
        })
        local got = pl.list_servers({ id = "x", path = "/p" })
        assert.are.equal(1, #got)
        assert.are.equal("S", got[1].name)
    end)
end)

describe("pack_launcher.cleanup_symlinks", function()
    it("removes only entries starting with _pm_ from <user>/worlds/", function()
        local deleted = {}
        local removed = pack_launcher.cleanup_symlinks("/user", {
            list_dir = function() return { "_pm_a", "_pm_b", "world1", "real_world" } end,
            delete_dir = function(p) deleted[#deleted + 1] = p; return true end,
        })
        assert.are.equal(2, #removed)
        assert.are.equal("/user/worlds/_pm_a", deleted[1])
        assert.are.equal("/user/worlds/_pm_b", deleted[2])
    end)
end)
