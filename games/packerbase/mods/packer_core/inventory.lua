-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Copyright (C) 2026 PackerMOD contributors
local enabled = core.settings:get_bool("packer_java_inventory", true)
local original = sfinv.make_formspec
function sfinv.make_formspec(player, context, content, show_inv, size)
	local count = player:get_inventory():get_size("main")
	if not show_inv or (not enabled and count <= 32) or size then
		return original(player, context, content, show_inv, size)
	end
	-- Keep upstream pages and navigation. Only the common player inventory
	-- changes: main storage above, nine-slot hotbar below, matching Java order.
	-- A mod that explicitly supplies a size retains full control of its page.
	local rows = math.max(3, math.ceil((count - 9) / 9))
	local hotbar_y = 5.35 + rows
	return "size[9," .. (hotbar_y + 1.05) .. "]" .. sfinv.get_nav_fs(player, context,
		context.nav_titles, context.nav_idx) .. content ..
		"list[current_player;main;0,5.2;9," .. rows .. ";9]" ..
		"list[current_player;main;0," .. hotbar_y .. ";9,1;]"
end
core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	if enabled then
		-- Never shrink a larger inventory installed by another mod.
		if inv:get_size("main") < 36 then inv:set_size("main", 36) end
		player:hud_set_hotbar_itemcount(9)
	end
	if sfinv.enabled then sfinv.set_player_inventory_formspec(player) end
end)
