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

describe("world_builder.create_world", function()
    it("creates world directory and writes world.mt when base game exists", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local t = fake_fs({ "/user/games/packerbase_0_91" })
        local ok, info = wb.create_world(m, "/user", { fs = fs_iface(t), timestamp = 1234567 })
        assert.is_true(ok)
        assert.are.equal("sample_pack__1234567", info.world_name)
        assert.are.equal("/user/worlds/sample_pack__1234567", info.world_path)
        assert.are.equal("packerbase_0_91", info.gameid)
        assert.is_truthy(t.writes["/user/worlds/sample_pack__1234567/world.mt"])
    end)

    it("fails when base game is missing", function()
        local _, m = manifest_mod.parse(read_fixture("sample_pack.yaml"))
        local t = fake_fs({})
        local ok, err = wb.create_world(m, "/user", { fs = fs_iface(t) })
        assert.is_false(ok)
        assert.is_truthy(err:find("base game"))
    end)
end)
