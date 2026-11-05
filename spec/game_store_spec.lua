package.path = "./?.lua;" .. package.path
local store = require("mainmenu.game_store")
local wb = require("mainmenu.world_builder")

describe("installed game resolution", function()
    local previous
    before_each(function() previous = core end)
    after_each(function() _G.core = previous end)

    for _, path in ipairs({ "/user/games/minetest_game", "/usr/share/luanti/games/minetest_game",
            "C:\\Users\\Player\\games\\minetest_game" }) do
        for _, with_mod in ipairs({ false, true }) do
            it("creates Pack/world for engine ID minetest at " .. path .. " mods=" .. tostring(with_mod), function()
                _G.core = { get_games = function() return { { id = "minetest", path = path } } end }
                local existing = { [path] = true, [path .. "/game.conf"] = true, [path .. "/mods"] = true }
                local writes = {}
                local fs = { exists = function(p) return existing[p] == true end,
                    mkdir = function(p) existing[p] = true; return true end,
                    write_file = function(p, text) writes[p] = text; return true end }
                local base = store.base_game({ name = "minetest", installed_id = "minetest", title = "Minetest Game" })
                local called = false
                local game_store = store.new({ fs = fs, world_builder = wb, user_path = "/user" })
                assert.is_true(game_store.ensure(base, {}, function(ok) assert.is_true(ok); called = true end))
                assert.is_true(called)
                local manifest = { id = "p", name = "Pack", base_game = base,
                    mods = with_mod and { { name = "example" } } or {} }
                for _, name in ipairs({ "World", "日本語ワールド" }) do
                    local ok, info = wb.create_world(manifest, "/user", { fs = fs, world_name = name })
                    assert.is_true(ok, tostring(info))
                    local mt = writes[info.world_path .. "/world.mt"]
                    assert.matches("gameid = minetest\n", mt, 1, true)
                    assert.equal(with_mod, mt:find("load_mod_example = true", 1, true) ~= nil)
                    assert.is_false(wb.create_world(manifest, "/user", { fs = fs, world_name = name }))
                end
            end)
        end
    end

    it("rejects a removed or incomplete installed game without downloading", function()
        _G.core = { get_games = function() return {} end }
        local fs = { exists = function() return true end }
        local game_store = store.new({ fs = fs, world_builder = wb, user_path = "/user" })
        local base = { id = "minetest", installed_id = "minetest" }
        game_store.ensure(base, {}, function(ok, err)
            assert.is_false(ok); assert.equal("Installed game is missing", err)
        end)
        core.get_games = function() return { { id = "minetest", path = "/shared/game" } } end
        fs.exists = function(p) return p:find("game.conf", 1, true) ~= nil end
        game_store.ensure(base, {}, function(ok) assert.is_false(ok) end)
    end)

    it("keeps ContentDB releases in their versioned user directories", function()
        _G.core = { get_games = function() error("ContentDB releases must not resolve by installed ID") end }
        assert.equal("/user/games/pm_minetest_game_r42", wb.gamepath_for({
            id = "minetest_game", package = "Luanti/minetest_game", release = 42 }, "/user"))
    end)
end)
