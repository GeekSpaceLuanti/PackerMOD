package.path = "./?.lua;" .. package.path
local pages = require("mainmenu.settings_pages")
local editor = require("mainmenu.engine_settings")
local helpers = require("spec.support.formspec_helpers")
describe("Player settings pages", function()
    local old_core, old_packermod, old_ui, data, values, writes
    before_each(function()
        old_core, old_packermod, old_ui = core, packermod, ui
        values, writes = { packermod_gui_size = "standard" }, 0
        local settings = {
            get = function(_, k) return values[k] end,
            has = function(_, k) return values[k] ~= nil end,
            set = function(_, k, v) values[k] = v end,
            remove = function(_, k) values[k] = nil end,
            write = function() writes = writes + 1; return true end,
        }
        _G.core = { settings = settings, get_version = function() return { string = "5.16.1" } end,
            explode_scrollbar_event = function(s) return { value = tonumber(s:match(":(%d+)$")) } end }
        _G.packermod = { layout = require("mainmenu.lib.layout"), i18n = dofile("mainmenu/i18n.lua") }
        local definitions = {
            { type = "category", name = "Audio", level = 0 },
            { type = "float", name = "sound_volume", default = "0.8", min = 0, max = 1 },
            { type = "float", name = "sound_volume_unfocused", default = "0.3", min = 0, max = 1 },
            { type = "bool", name = "mute_sound", default = "false" },
            { type = "category", name = "Controls", level = 0 },
            { type = "key", name = "keymap_forward", default = "KEY_KEY_W|KEY_UP" },
            { type = "category", name = "Advanced", level = 0 },
            { type = "enum", name = "mode", default = "a", values = { "a", "b", "c" } },
        }
        for i = 1, 30 do definitions[#definitions + 1] = { type = "string", name = "extra_" .. i, default = "" } end
        data = { backend = editor.new(definitions, settings), tab = "audio", drafts = {} }
    end)
    after_each(function() _G.core, _G.packermod, _G.ui = old_core, old_packermod, old_ui end)
    local function build() return pages.build(data, function(s) return s end) end
    local function handle(fields) return pages.handle(data, fields, function(s) return s end) end
    it("changes a slider immediately and ignores unchanged slider fields when toggling", function()
        build()
        handle({ settings_row_1 = "CHG:420" })
        assert.equal("0.42", values.sound_volume)
        handle({ settings_row_1 = "VAL:420", settings_row_2 = "VAL:300", settings_row_3 = "true" })
        assert.equal("true", values.mute_sound)
        assert.equal(2, writes)
    end)
    it("changes the primary binding without losing alternate bindings", function()
        data.tab = "keymap"; build()
        handle({ settings_row_1 = "KEY_KEY_Z" })
        assert.equal("KEY_KEY_Z|KEY_UP", values.keymap_forward)
    end)
    it("defers redraw during a drag and cancels it when the dialog closes", function()
        local pending, now, redraws = {}, 0, 0
        core.get_us_time = function() return now end
        core.handle_async = function(_, _, callback) pending[#pending + 1] = callback end
        _G.ui = { update = function() redraws = redraws + 1 end }
        build()
        assert.is_false(handle({ settings_row_1 = "CHG:200" }))
        now = 100000
        assert.is_false(handle({ settings_row_1 = "CHG:300" }))
        assert.equal(1, #pending)
        table.remove(pending, 1)()
        assert.equal(0, redraws)
        now = 400000
        table.remove(pending, 1)()
        assert.equal(1, redraws)
        assert.is_false(handle({ settings_row_1 = "CHG:400" }))
        data.closed, now = true, 800000
        table.remove(pending, 1)()
        assert.equal(1, redraws)
        assert.is_false(data.slider_refresh_pending)
    end)
    it("opens details without writing and retains the active tab", function()
        build(); handle({ settings_edit_1 = "true", settings_row_1 = "VAL:800" })
        assert.equal("sound_volume", data.selected_name)
        assert.is_true(data.detail)
        assert.equal("audio", data.tab)
        assert.equal(0, writes)
    end)
    it("searches every setting and cycles enumerated values", function()
        handle({ settings_show_developer = "true" })
        handle({ settings_search = "true", settings_query = "mode" }); build()
        assert.equal(1, #data.home_entries)
        handle({ settings_row_1 = "true" }); assert.equal("b", values.mode)
        handle({ settings_row_1 = "true" }); assert.equal("c", values.mode)
        handle({ settings_row_1 = "true" }); assert.equal("a", values.mode)
        handle({ settings_tab_controls = "true" })
        assert.equal("", data.home_query)
        assert.equal("controls", data.tab)
    end)
    it("uses scrolling for the entire group and keeps its position after editing", function()
        data.show_developer, data.tab = true, "advanced"
        local fs = build()
        assert.equal(31, #data.row_entries)
        assert.is_truthy(fs:find("scroll_container[", 1, true))
        assert.is_nil(fs:find("settings_next", 1, true))
        assert.is_false(handle({ settings_list_scroll = "CHG:45" }))
        handle({ settings_row_1 = "true", settings_list_scroll = "VAL:45" })
        assert.equal(45, data.list_scroll)
        handle({ settings_tab_audio = "true" })
        assert.equal(0, data.list_scroll)
    end)
    it("hides complex settings from tabs and search until explicitly enabled", function()
        handle({ settings_search = "true", settings_query = "mode" }); build()
        assert.equal(0, #data.row_entries)
        for _, tab in ipairs(pages.tabs_for(data)) do assert.is_not.equal("advanced", tab.id) end
        handle({ settings_show_developer = "true" })
        handle({ settings_search = "true", settings_query = "mode" }); build()
        assert.equal(1, #data.row_entries)
        handle({ settings_show_developer = "true" })
        build()
        assert.is_false(data.show_developer)
        assert.equal("", data.home_query)
    end)
    it("resets only the selected item and clears its staged value", function()
        build(); values.sound_volume, values.mute_sound = "0.42", "true"
        data.drafts.sound_volume = "0.7"
        handle({ settings_reset_1 = "true", settings_row_1 = "VAL:420" })
        assert.is_nil(values.sound_volume)
        assert.is_nil(data.drafts.sound_volume)
        assert.equal("true", values.mute_sound)
        assert.equal("Restored default value.", data.status)
    end)
    it("uses one GUI dropdown and restores all proportions with Auto", function()
        data.tab = "general"; build()
        local appearances = 0
        for _, entry in ipairs(data.row_entries) do if entry.type == "appearance" then appearances = appearances + 1 end end
        assert.equal(1, appearances)
        handle({ settings_row_2 = "4" })
        assert.equal("large", values.packermod_gui_size)
        assert.equal("1.25", values.gui_scaling)
        assert.is_nil(values.packermod_button_scale)
        assert.is_nil(values.font_size)
        handle({ settings_reset_2 = "true" })
        assert.equal("auto", values.packermod_gui_size)
    end)
    it("saves visibility switches independently and rolls back a failed write", function()
        handle({ settings_show_advanced = "true" })
        handle({ settings_show_developer = "true" })
        assert.equal("true", values.packermod_show_advanced)
        assert.equal("true", values.packermod_show_developer)
        handle({ settings_show_advanced = "true" })
        assert.equal("false", values.packermod_show_advanced)
        assert.equal("true", values.packermod_show_developer)
        core.settings.write = function() return false end
        handle({ settings_show_developer = "true" })
        assert.is_true(data.show_developer)
        assert.equal("true", values.packermod_show_developer)
    end)
    it("ignores unchanged language dropdown values submitted with other controls", function()
        data.tab = "general"; build()
        local selected = packermod.i18n.language() == "en" and "2" or "1"
        handle({ settings_row_1 = selected, settings_row_2 = "4" })
        assert.equal("1.25", values.gui_scaling)
        handle({ settings_row_1 = selected, settings_reset_3 = "true" })
        assert.is_nil(values.packermod_button_scale)
    end)
    it("removes unsafe choices after resizing and migrates old independent scales", function()
        local prefs = require("mainmenu.ui_preferences")
        values.packermod_gui_size, values.gui_scaling, values.font_size, values.packermod_button_scale = "large", "42", "72", "1.5"
        core.get_window_info = function() return { size = { x = 800, y = 600 } } end
        local w, h = prefs.viewport(30, 16)
        assert.is_true(w >= 24 and h >= 14)
        assert.equal(3, #prefs.options())
        assert.equal("standard", prefs.read())
        assert.equal("1", values.gui_scaling)
        assert.equal("16", values.font_size)
        assert.is_nil(values.packermod_button_scale)
        assert.is_false(prefs.change(prefs.entries[1], false, "4"))
        data.tab = "general"
        local size, elements = helpers.parse_formspec(build())
        assert.is_true(helpers.fits_in_size(elements, size))
        prefs.change(prefs.entries[1], true)
        core.get_window_info = function() return { size = { x = 1280, y = 800 } } end
        prefs.viewport(30, 16)
        assert.equal("auto", prefs.read())
        assert.equal("1.25", values.gui_scaling)
    end)
    it("rolls back the complete GUI choice when saving fails", function()
        build()
        core.settings.write = function() return false end
        handle({ settings_row_2 = "4" })
        assert.equal("standard", values.packermod_gui_size)
        assert.is_nil(values.gui_scaling)
    end)
    it("does not let an unchanged size dropdown swallow another setting action", function()
        data.tab = "general"; build()
        values.sound_volume = "0.42"
        local index
        for i, entry in ipairs(data.row_entries) do if entry.name == "sound_volume" then index = i end end
        handle({ settings_row_2 = "3", ["settings_reset_" .. index] = "true" })
        assert.is_nil(values.sound_volume)
    end)
    it("fits all tabs in both landscape and portrait without overlapping controls", function()
        for _, choice in ipairs({ "auto", "small", "standard", "large" }) do
        values.packermod_gui_size = choice
        for _, window in ipairs({ { x = 1280, y = 800 }, { x = 1024, y = 768 }, { x = 1280, y = 1400 } }) do
            core.get_window_info = function() return { size = window } end
            for _, tab in ipairs(pages.tabs) do
                data.tab, data.home_query, data.home_category, data.show_advanced, data.show_developer = tab.id, "", 1, true, true
                local size, elements = helpers.parse_formspec(build())
                assert.is_true(helpers.fits_in_size(elements, size))
                assert.same({},dofile("mainmenu/lib/pmui/modern/layout.lua").validate(data.gui_layout.tree))
            end
        end
        end
    end)
end)
