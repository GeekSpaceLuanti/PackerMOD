package.path = "./?.lua;" .. package.path

local manifest_mod = require("mainmenu.manifest")
local wb = require("mainmenu.world_builder")

local function read_fixture(name)
    local f = assert(io.open("test_fixtures/" .. name, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

local function fake_fs(initial_paths)
    local existing = {}
    for _, p in ipairs(initial_paths or {}) do existing[p] = true end
    local writes = {}
    local mkdirs = {}
    return {
        existing = existing,
        writes = writes,
        mkdirs = mkdirs,
        mkdir = function(self, path)
            table.insert(self.mkdirs, path)
            self.existing[path] = true
            return true
        end,
        write_file = function(self, path, content)
            self.writes[path] = content
            return true
        end,
        exists = function(self, path)
            return self.existing[path] == true
        end,
    }
end

local function fs_iface(t)
    return {
        mkdir = function(p) return t:mkdir(p) end,
        write_file = function(p, c) return t:write_file(p, c) end,
        exists = function(p) return t:exists(p) end,
    }
end

describe("world_builder.gameid_for", function()
    it("encodes version safely", function()
        assert.are.equal("packerbase_0_91", wb.gameid_for({ id = "packerbase", version = "0.91" }))
        assert.are.equal("packerbase_1_2_3", wb.gameid_for({ id = "packerbase", version = "1.2.3" }))
    end)
end)

describe("world_builder.build_world_mt", function()
    it("includes gameid, load_mod_*, settings, sorted", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local mt = wb.build_world_mt(m)
        assert.is_truthy(mt:find("gameid = packerbase_0_91", 1, true))
        assert.is_truthy(mt:find("load_mod_mesecons = true", 1, true))
        assert.is_truthy(mt:find("load_mod_my_custom_mod = true", 1, true))
        assert.is_truthy(mt:find("load_mod_external_mod = true", 1, true))
        assert.is_truthy(mt:find("enable_damage = true", 1, true))
        assert.is_truthy(mt:find("creative_mode = false", 1, true))
        assert.is_truthy(mt:find("mg_name = v7", 1, true))
    end)

    it("works with no mods and no settings", function()
        local m = {
            id = "empty", name = "Empty", version = "1.0.0", schema_version = 1,
            base_game = { id = "packerbase", version = "0.91" },
        }
        local mt = wb.build_world_mt(m)
        assert.is_truthy(mt:find("gameid = packerbase_0_91", 1, true))
        assert.is_nil(mt:find("load_mod_"))
    end)

    it("embeds packermod_pack_id for Pack→World filtering", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local mt = wb.build_world_mt(m)
        assert.is_truthy(mt:find("packermod_pack_id = sample_pack", 1, true))
    end)

    it("uses opts.world_name as world_name when given", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local mt = wb.build_world_mt(m, { world_name = "MyCustomName" })
        assert.is_truthy(mt:find("world_name = MyCustomName", 1, true))
    end)
end)

describe("world_builder._default_fs.mkdir under Luanti sandbox", function()
    local saved_core
    before_each(function() saved_core = rawget(_G, "core") end)
    after_each(function() rawset(_G, "core", saved_core) end)

    it("does not attempt to create_dir on ancestors outside the user sandbox", function()
        local called = {}
        rawset(_G, "core", {
            create_dir = function(p)
                table.insert(called, p)
                if not p:find("^/home/bacon/%.minetest") then
                    error("Mod security: Blocked attempted write to " .. p)
                end
                return true
            end,
        })
        local fs = wb._default_fs()
        local ok, err = pcall(fs.mkdir, "/home/bacon/.minetest/worlds/foo")
        assert.is_true(ok, "mkdir bubbled sandbox error: " .. tostring(err))
        for _, p in ipairs(called) do
            assert.is_truthy(p:find("^/home/bacon/%.minetest"),
                "create_dir called outside sandbox: " .. p)
        end
    end)
end)

describe("world_builder.sanitize_world_name", function()
    it("keeps alphanumerics and underscores/hyphens", function()
        assert.are.equal("my_world-1", wb.sanitize_world_name("my_world-1"))
    end)
    it("replaces other characters with underscore", function()
        assert.are.equal("my_world", wb.sanitize_world_name("my world"))
        assert.are.equal("hello_world", wb.sanitize_world_name("hello/world"))
        assert.are.equal("foo_bar_baz", wb.sanitize_world_name("foo.bar+baz"))
    end)
    it("collapses leading/trailing separators", function()
        assert.are.equal("foo", wb.sanitize_world_name("  foo  "))
        assert.are.equal("foo", wb.sanitize_world_name("__foo__"))
    end)
    it("returns nil for empty or all-junk input", function()
        assert.is_nil(wb.sanitize_world_name(""))
        assert.is_nil(wb.sanitize_world_name("   "))
        assert.is_nil(wb.sanitize_world_name("///"))
        assert.is_nil(wb.sanitize_world_name(nil))
    end)
    it("preserves multi-byte input by replacing each non-ascii byte", function()
        -- 日本語などは _ に潰れる(ascii safe)
        local out = wb.sanitize_world_name("テスト_world")
        assert.is_truthy(out)
        assert.is_truthy(out:find("world", 1, true))
    end)
end)

describe("world_builder.create_world (subdir layout)", function()
    it("creates world under PackerMOD/packs/<pack>/worlds/<name>/ when base game exists", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local t = fake_fs({ "/user/games/packerbase_0_91" })
        local ok, info = wb.create_world(m, "/user",
            { fs = fs_iface(t), world_name = "my_first_world" })
        assert.is_true(ok)
        assert.are.equal("my_first_world", info.world_name)
        assert.are.equal("/user/PackerMOD/packs/sample_pack/worlds/my_first_world", info.world_path)
        assert.are.equal("packerbase_0_91", info.gameid)
        assert.is_truthy(t.writes["/user/PackerMOD/packs/sample_pack/worlds/my_first_world/world.mt"])
    end)

    it("sanitizes user-provided world_name and uses raw as display in world.mt", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local t = fake_fs({ "/user/games/packerbase_0_91" })
        local ok, info = wb.create_world(m, "/user",
            { fs = fs_iface(t), world_name = "My First!" })
        assert.is_true(ok)
        assert.are.equal("My_First", info.world_name)
        local mt = t.writes["/user/PackerMOD/packs/sample_pack/worlds/My_First/world.mt"]
        assert.is_truthy(mt)
        -- world.mt の `world_name` は raw 入力(display)
        assert.is_truthy(mt:find("world_name = My First!", 1, true))
    end)

    it("fails when base game is missing", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local t = fake_fs({})
        local ok, err = wb.create_world(m, "/user",
            { fs = fs_iface(t), world_name = "main" })
        assert.is_false(ok)
        assert.is_truthy(err:find("base game"))
    end)

    it("fails when an empty/invalid world_name is given", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local t = fake_fs({ "/user/games/packerbase_0_91" })
        local ok, err = wb.create_world(m, "/user", { fs = fs_iface(t), world_name = "" })
        assert.is_false(ok)
        assert.is_truthy(err:find("world name"))
    end)

    it("rejects duplicate world in the same pack", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local t = fake_fs({
            "/user/games/packerbase_0_91",
            "/user/PackerMOD/packs/sample_pack/worlds/main",
        })
        local ok, err = wb.create_world(m, "/user",
            { fs = fs_iface(t), world_name = "main" })
        assert.is_false(ok)
        assert.is_truthy(err:find("already exists"))
        assert.is_truthy(err:find("sample_pack"))
    end)

    it("allows the same world name across different packs", function()
        local _, m1 = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local m2 = {
            id = "another_pack", name = "Another", version = "1.0.0", schema_version = 1,
            base_game = { id = "packerbase", version = "0.91" },
        }
        local t = fake_fs({
            "/user/games/packerbase_0_91",
            "/user/PackerMOD/packs/sample_pack/worlds/main",
        })
        local ok = wb.create_world(m2, "/user", { fs = fs_iface(t), world_name = "main" })
        assert.is_true(ok)
        assert.is_truthy(t.writes["/user/PackerMOD/packs/another_pack/worlds/main/world.mt"])
    end)
end)

describe("world_builder.delete_world", function()
    it("deletes <user>/PackerMOD/packs/<pack>/worlds/<world>/", function()
        local deleted = {}
        local fs = {
            mkdir = function() return true end,
            write_file = function() return true end,
            exists = function(p) return p == "/user/PackerMOD/packs/sample/worlds/main" end,
            delete_dir = function(p) deleted[#deleted + 1] = p; return true end,
        }
        local ok = wb.delete_world("sample", "main", "/user", { fs = fs })
        assert.is_true(ok)
        assert.are.equal("/user/PackerMOD/packs/sample/worlds/main", deleted[1])
    end)

    it("returns false when the target is missing", function()
        local fs = {
            mkdir = function() return true end,
            write_file = function() return true end,
            exists = function() return false end,
            delete_dir = function() return true end,
        }
        local ok, err = wb.delete_world("sample", "missing", "/user", { fs = fs })
        assert.is_false(ok)
        assert.is_truthy(err:find("not found"))
    end)
end)

describe("world_builder.delete_legacy_world", function()
    it("deletes <user>/worlds/<flat_dir>/ for legacy flat layout", function()
        local deleted = {}
        local fs = {
            mkdir = function() return true end,
            write_file = function() return true end,
            exists = function(p) return p == "/user/worlds/sample_pack__1782641958" end,
            delete_dir = function(p) deleted[#deleted + 1] = p; return true end,
        }
        local ok = wb.delete_legacy_world("sample_pack__1782641958", "/user", { fs = fs })
        assert.is_true(ok)
        assert.are.equal("/user/worlds/sample_pack__1782641958", deleted[1])
    end)
end)
