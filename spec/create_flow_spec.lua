package.path = "./?.lua;" .. package.path
local builder = require("mainmenu.pack_builder")
local store = require("mainmenu.game_store")
local manifest = require("mainmenu.manifest")

describe("ContentDB Pack creation flow", function()
    local previous, create, dialog, requests, saved, setting_values
    before_each(function()
        previous = { core = core, packermod = packermod, ui = ui,
            dialog_create = dialog_create, DIR_DELIM = DIR_DELIM,
            create_settings_dlg = create_settings_dlg }
        setting_values = {}
        _G.DIR_DELIM = "/"
        _G.core = {
            settings = { get = function(_, key) return setting_values[key] end,
                set = function(_, key, value) setting_values[key] = value end,
                write = function() setting_values.written = true end },
            get_version = function() return { string = "5.16.1" } end,
            get_games = function() return {} end,
            explode_textlist_event = function(text)
                return { type = text:match("^(%w+):"), index = tonumber(text:match(":(%d+)$")) }
            end,
        }
        _G.ui = { update = function() end }
        requests, saved = {}, {}
        _G.dialog_create = function(_, _, handler)
            return { data = {}, show = function() end, hide = function(self) self.hidden = true end,
                set_parent = function(self, parent) self.parent = parent end,
                delete = function(self) self.deleted = true end, handler = handler }
        end
        _G.packermod = {
            pack_builder = builder, game_store_mod = store,
            i18n = dofile("mainmenu/i18n.lua"),
            mainmenu_path = "mainmenu/", manifest = manifest,
            client = {
                search_async = function(query, kind, callback)
                    requests[#requests + 1] = { query = query, kind = kind, callback = callback }; return true
                end,
                releases_async = function(id, callback)
                    requests[#requests + 1] = { package = id, callback = callback }; return true
                end,
            },
            game_store = { ensure = function(base, release, callback)
                saved.base, saved.release, saved.callback = base, release, callback; return true
            end },
            importer = { import_from_yaml_text = function(text) saved.text = text; return true end },
        }
        create = dofile("mainmenu/dialogs/dlg_create.lua")
        dialog = create.show()
    end)
    after_each(function()
        for _, key in ipairs({ "core", "packermod", "ui", "dialog_create", "DIR_DELIM", "create_settings_dlg" }) do
            _G[key] = previous[key]
        end
    end)

    local function select_game(dialog, requests)
        dialog.handler(dialog, { pack_name = "新しいパック", next_step = true })
        dialog.handler(dialog, { game_query = "example", game_search = true })
        requests[#requests].callback({ { author = "Author", name = "example", title = "Example Game" } })
        dialog.handler(dialog, { game_list = "CHG:1" })
        requests[#requests].callback({
            { id = 30, name = "future", min_minetest_version = { name = "5.18" } },
            { id = 20, name = "2.0", url = "https://example.test/2.zip" },
            { id = 10, name = "1.0", url = "https://example.test/1.zip" },
        })
        dialog.handler(dialog, { game_release = "2" })
    end

    it("generates UUID/revision once and ignores user-supplied internal identifiers", function()
        local id = dialog.data.pack_id
        assert.is_truthy(id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"))
        dialog.handler(dialog, { pack_name = "Pack", pack_id = "override", pack_version = "99", next_step = true })
        dialog.handler(dialog, { previous_step = true })
        assert.equal(id, dialog.data.pack_id)
        assert.equal("1.0.0", dialog.data.pack_version)
    end)

    it("maps a release dropdown index to its release id and installs before saving", function()
        select_game(dialog, requests)
        assert.equal("game", requests[1].kind)
        assert.equal("Author/example", requests[2].package)
        assert.equal(2, #dialog.data.releases)
        assert.equal(10, dialog.data.base_game.release)
        dialog.handler(dialog, { next_step = true })
        dialog.handler(dialog, { export = true })
        assert.equal(10, saved.release.id)
        assert.is_nil(saved.text)
        saved.callback(true)
        local ok, pack = manifest.parse(saved.text)
        assert.is_true(ok)
        assert.equal("1.0", pack.base_game.version)
        assert.equal("Author/example", pack.base_game.package)
        assert.equal(10, pack.base_game.release)
        assert.is_true(dialog.deleted)
    end)

    it("does not save a Pack when the game download fails", function()
        select_game(dialog, requests)
        dialog.handler(dialog, { next_step = true })
        dialog.handler(dialog, { export = true })
        saved.callback(false, "network error")
        assert.is_nil(saved.text)
        assert.is_false(dialog.data.busy)
        assert.is_truthy(dialog.data.status:find("network error", 1, true))
    end)

    it("creates from an installed normalized engine ID without a release download", function()
        core.get_games = function() return { { id = "minetest", title = "Minetest Game", path = "/games/minetest_game" } } end
        dialog = create.show()
        dialog.handler(dialog, { pack_name = "Installed", next_step = true })
        assert.equal("minetest", dialog.data.base_game.installed_id)
        dialog.handler(dialog, { next_step = true })
        dialog.handler(dialog, { export = true })
        assert.equal(0, #requests)
        saved.callback(true)
        local ok, pack = manifest.parse(saved.text)
        assert.is_true(ok)
        assert.equal("minetest", pack.base_game.installed_id)
    end)

    it("requires a name and game, and keeps values when navigating backwards", function()
        dialog.handler(dialog, { pack_name = "  ", next_step = true })
        assert.equal("details", dialog.data.step)
        dialog.handler(dialog, { pack_name = "Named", pack_description = "説明", next_step = true })
        assert.equal("game", dialog.data.step)
        dialog.handler(dialog, { next_step = true })
        assert.equal("game", dialog.data.step)
        select_game(dialog, requests)
        dialog.handler(dialog, { next_step = true })
        assert.equal("mods", dialog.data.step)
        dialog.handler(dialog, { previous_step = true })
        assert.equal(10, dialog.data.base_game.release)
        dialog.handler(dialog, { previous_step = true })
        assert.equal("説明", dialog.data.pack_description)
    end)

    it("handles MOD search, compatible release, duplicate, remove and empty selection", function()
        select_game(dialog, requests)
        dialog.handler(dialog, { next_step = true })
        dialog.handler(dialog, { add_search = true })
        assert.equal(0, #dialog.data.mods)
        dialog.handler(dialog, { search_query = "probe", search = true })
        requests[#requests].callback({ { name = "probe", author = "Fixture" } })
        dialog.handler(dialog, { search_results = "CHG:1" })
        for _ = 1, 2 do
            dialog.handler(dialog, { add_search = true })
            requests[#requests].callback({ { id = 99, min_minetest_version = { name = "9.0" } }, { id = 10 } })
        end
        assert.equal(1, #dialog.data.mods)
        assert.equal(10, dialog.data.mods[1].release)
        dialog.handler(dialog, { mod_list = "CHG:1" })
        dialog.handler(dialog, { remove_mod = true })
        assert.equal(0, #dialog.data.mods)
        dialog.handler(dialog, { remove_mod = true })
        assert.equal(0, #dialog.data.mods)
    end)

    for _, failure in ipairs({ "search", "releases", "worker", "save" }) do
        it("retains the open dialog after " .. failure .. " failure", function()
            if failure == "search" then
                dialog.handler(dialog, { game_search = true })
                requests[#requests].callback(nil, "offline")
            elseif failure == "worker" then
                packermod.client.search_async = function() return false end
                dialog.handler(dialog, { game_search = true })
            elseif failure == "releases" then
                dialog.data.games = { { author = "Fixture", name = "game" } }
                dialog.handler(dialog, { game_list = "CHG:1" })
                requests[#requests].callback(nil, "offline")
            else
                select_game(dialog, requests)
                dialog.handler(dialog, { next_step = true })
                packermod.importer.import_from_yaml_text = function() return false, "disk full" end
                dialog.handler(dialog, { export = true }); saved.callback(true)
            end
            assert.is_false(dialog.data.busy)
            assert.is_nil(dialog.deleted)
            assert.is_truthy(dialog.data.status:find("failed", 1, true))
        end)
    end

    it("ignores a search response after the dialog was closed", function()
        dialog.handler(dialog, { game_search = true })
        dialog.handler(dialog, { dlg_close = true })
        requests[1].callback({ { name = "unexpected" } })
        assert.equal(0, #dialog.data.games)
    end)

    it("defaults to Japanese and persists an immediate English UI switch", function()
        local i18n = packermod.i18n
        assert.equal("設定", i18n.t("Settings"))
        assert.is_true(i18n.set("en"))
        assert.equal("Settings", i18n.t("Settings"))
        assert.equal("en", setting_values.language)
        assert.is_true(setting_values.written)
    end)

    it("keeps engine settings in the same dialog when the language control is submitted", function()
        packermod.engine_settings = require("mainmenu.engine_settings").new({
            { name = "font_size", type = "int", default = "16" },
        }, core.settings)
        local called = false
        _G.create_settings_dlg = function() called = true end
        local settings = dofile("mainmenu/dialogs/dlg_settings.lua").show()
        settings.handler(settings, { ui_language = "1", open_luanti_settings = true })
        assert.is_false(called)
        assert.is_nil(settings.hidden)
        assert.equal("font_size", settings.data.selected_name)
    end)
end)

describe("base game release compatibility", function()
    it("keeps two ContentDB releases in separate engine game directories", function()
        local world_builder = require("mainmenu.world_builder")
        local game = { author = "Author", name = "example", title = "Game" }
        local first = store.base_game(game, { id = 10, name = "1.0" })
        local second = store.base_game(game, { id = 11, name = "1.0" })
        assert.are_not.equal(world_builder.gameid_for(first), world_builder.gameid_for(second))
    end)

    it("treats engine patch versions as the same supported release family", function()
        assert.is_true(store.compatible({ max_minetest_version = { name = "5.16" } }, "5.16.1"))
        assert.is_false(store.compatible({ min_minetest_version = { name = "5.17" } }, "5.16.1"))
    end)
end)
