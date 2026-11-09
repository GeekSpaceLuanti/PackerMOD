-- SPDX-License-Identifier: LGPL-2.1-or-later
local path = core.get_modpath(core.get_current_modname())
local ui = dofile(path .. "/lib/pmui/init.lua")
local screens = dofile(path .. "/screens.lua")(ui)
packer_ui = {
	pmui = ui,
	recipe = dofile(path .. "/recipes.lua")(screens),
	receive = screens.receive,
	combined_crafting = core.settings:get_bool("packer_java_inventory", true),
}
dofile(path .. "/settings.lua")(screens)

-- Keep the upstream guide and crafting page IDs for callers using sfinv.
if packer_ui.combined_crafting then
	local guide = sfinv.pages["mtg_craftguide:craftguide"]
	sfinv.override_page("mtg_craftguide:craftguide", {
		is_in_nav = function() return false end
	})
	sfinv.override_page("sfinv:crafting", {
		get = function(_, player, context) return guide:get(player, context) end,
		on_player_receive_fields = function(_, player, context, fields)
			return guide:on_player_receive_fields(player, context, fields)
		end
	})
end
