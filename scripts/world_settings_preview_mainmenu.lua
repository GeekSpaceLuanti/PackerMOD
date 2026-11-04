local source = assert(core.settings:get("packermod_source_path"))
dofile(source .. "/mainmenu/init.lua")
local world = { path = packermod.user_path .. "/PackerMOD/packs/sample_1/worlds/demo", name = "demo", display_name = "サンプルワールド" }
local dlg = packermod.dialogs.dlg_settings.show_world(packermod.library.dlg(), world)
local tab = core.settings:get("packermod_initial_settings_tab")
local tabs = { physics = "physics", terrain = "terrain", hosting = "hosting" }
dlg.data.tab = tabs[tab] or "gameplay"
dlg.data.show_advanced = tab == "physics" or tab == "hosting"
local setting = core.settings:get("packermod_initial_engine_setting")
if setting and setting ~= "" then dlg.data.selected_name, dlg.data.detail = setting, true end
ui.update()
