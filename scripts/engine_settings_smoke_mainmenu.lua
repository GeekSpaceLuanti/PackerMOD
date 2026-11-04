-- Exercise the real Settings API only inside the screenshot runner's temporary profile.
local source = assert(core.settings:get("packermod_source_path"))
local config = assert(core.settings:get("packermod_smoke_config"))
dofile(source .. "/mainmenu/init.lua")
local controller = packermod.dialogs.dlg_settings
local dlg = controller.show(packermod.library.dlg())
local handler = controller._internal.handler
local data = dlg.data
data.backend = packermod.get_engine_schema()
local function select(name)
    assert(data.backend.by_name[name], name)
    data.detail = true
    data.selected_name = name
    controller._internal.refresh_list(data)
end
local function apply(name, fields, expected)
    select(name)
    fields.engine_apply = true
    handler(dlg, fields)
    assert(data.status == "Saved.", name .. ": " .. tostring(data.status))
    if expected then assert(Settings(config):get(name) == expected, name .. " not persisted") end
end
apply("sound_volume", { engine_value = "0.42" }, "0.42")
handler(dlg, { engine_value = "2", engine_apply = true })
assert(data.status:match("^Save failed:"))
assert(core.settings:get("sound_volume") == "0.42")
handler(dlg, { engine_reset = true })
assert(not Settings(config):has("sound_volume"))
apply("autojump", { engine_choice = "2" }, "false")
apply("video_driver", { engine_choice = "2" }, "opengl")
apply("mgfractal_scale", { engine_x = "100", engine_y = "200", engine_z = "300" }, "(100, 200, 300)")
apply("mg_flags", { engine_value = "caves,nobiomes" }, "caves,nobiomes")
select("keymap_forward")
handler(dlg, { engine_bind = "KEY_UP" })
assert(not Settings(config):has("keymap_forward"), "Binding saved before Apply")
handler(dlg, { engine_apply = true })
assert(Settings(config):get("keymap_forward"):find("KEY_UP", 1, true))
apply("mg_biome_np_heat", { noise_offset = "12", noise_spread_x = "500" })
assert(Settings(config):get_np_group("mg_biome_np_heat").offset == 12)
assert(Settings(config):get_np_group("mg_biome_np_heat").spread.x == 500)
select("screenshot_path")
handler(dlg, { packermod_engine_path_accepted = "/tmp/packermod-smoke" })
assert(not Settings(config):has("screenshot_path"), "Path saved before Apply")
handler(dlg, { engine_apply = true })
assert(Settings(config):get("screenshot_path") == "/tmp/packermod-smoke")
for _, name in ipairs({ "autojump", "video_driver", "mgfractal_scale", "mg_flags", "keymap_forward", "mg_biome_np_heat", "screenshot_path" }) do
    select(name)
    handler(dlg, { engine_reset = true })
    assert(not Settings(config):has(name), name .. " not reset")
end
handler(dlg, { engine_query = "font_size", engine_search = true })
assert(#data.visible > 0 and #data.visible < #data.backend.entries, "Search did not filter settings")
select("font_size")
assert(data.selected_index > 0, "Search omitted matching setting")
handler(dlg, { engine_value = "22" })
handler(dlg, { engine_clear = true })
select("sound_volume")
select("font_size")
assert(data.drafts.font_size == "22", "Draft lost after selecting another setting")
assert(core.settings:get("font_size") == "16", "Draft saved without Apply")
data.drafts.font_size = nil
-- Exercise the player-facing tabs and direct controls, including full forms
-- containing unchanged scrollbar values alongside the clicked button.
local function home(tab)
    data.backend = packermod.engine_settings
    data.group_by_tab = { keymap = "Movement" }
    data.detail, data.tab, data.home_query = false, tab, ""
    controller._internal.get_formspec(data)
end
home("audio")
handler(dlg, { settings_row_1 = "CHG:420" })
assert(Settings(config):get("sound_volume") == "0.42")
handler(dlg, { settings_row_1 = "VAL:420", settings_row_2 = "VAL:300", settings_row_3 = "true" })
assert(Settings(config):get("mute_sound") == "true", "Unchanged slider blocked the toggle")
handler(dlg, { settings_edit_1 = "true", settings_row_1 = "VAL:420" })
assert(data.detail and data.selected_name == "sound_volume")
handler(dlg, { settings_back = "true" })
assert(not data.detail and data.tab == "audio")
assert(data.backend.reset(data.backend.by_name.sound_volume))
assert(data.backend.reset(data.backend.by_name.mute_sound))
home("keymap")
local key_index
for i, entry in ipairs(data.row_entries) do if entry.name == "keymap_forward" then key_index = i end end
assert(key_index)
handler(dlg, { ["settings_row_" .. key_index] = "KEY_UP" })
assert(Settings(config):get("keymap_forward") == "KEY_UP")
assert(data.backend.reset(data.backend.by_name.keymap_forward))
home("general")
assert(core.settings:get("packermod_source_path") == source, "Unrelated settings changed")
ui.update()
core.log("action", "PackerMOD: engine settings verified")
