-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Copyright (C) 2026 PackerMOD contributors
local enabled = core.settings:get_bool("packer_java_inventory", true)

if enabled and core.features.hotbar_hud_element then
	core.hud_replace_builtin("hotbar", {
		type = "hotbar", position = {x = 0.5, y = 1}, direction = 0,
		alignment = {x = 0, y = -1}, offset = {x = 0, y = -20},
	})
	local single_row_y, double_row_y = -104, -152
	local status_names = { ["packer_core:health"] = true, ["packer_core:breath"] = true }
	local function place_status(name, texture, count, x)
		core.hud_replace_builtin(name, {
			type = "statbar", position = {x = 0.5, y = 1}, direction = 0,
			name = "packer_core:" .. name,
			text = texture .. ".png", text2 = texture .. "_gone.png",
			number = count, item = count, size = {x = 16, y = 16},
			offset = {x = x, y = single_row_y},
		})
	end
	place_status("health", "heart", core.PLAYER_MAX_HP_DEFAULT, -172)
	place_status("breath", "bubble", core.PLAYER_MAX_BREATH_DEFAULT * 2, 12)

	-- The client decides when the native hotbar wraps. Window and HUD scale
	-- are reported to the server, so keep these two owned elements clear of
	-- the second row as the window changes. Builtin HP/breath updates remain active.
	local elapsed = 0
	core.register_globalstep(function(dtime)
		if not core.get_player_window_information then return end
		elapsed = elapsed + dtime
		if elapsed < 0.25 then return end
		elapsed = 0
		local max_width = tonumber(core.settings:get("hud_hotbar_max_width")) or 1
		for _, player in ipairs(core.get_connected_players()) do
			local window = core.get_player_window_information(player:get_player_name())
			local width = window and window.size and tonumber(window.size.x)
			local scale = window and tonumber(window.real_hud_scaling)
			if width and width > 0 and scale and scale > 0 and scale < math.huge then
				local slot_pitch = 56 * scale
				local wraps = slot_pitch * player:hud_get_hotbar_itemcount() > max_width * width
				local target_y = wraps and double_row_y or single_row_y
				for id, hud in pairs(player:hud_get_all()) do
					if status_names[hud.name] and hud.offset.y ~= target_y then
						player:hud_change(id, "offset", {x = hud.offset.x, y = target_y})
					end
				end
			end
		end
	end)
end

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
		-- Let Luanti paint each slot using the same rectangle as its item.
		-- A baked strip is stretched across both row widths when the bar wraps.
		player:hud_set_hotbar_image("")
		-- A 64px frame with 4 transparent pixels on each side matches the
		-- native 48px item, 4px slot padding and 8px selection expansion.
		player:hud_set_hotbar_selected_image("packer_hotbar_selected.png")
	end
	if sfinv.enabled then sfinv.set_player_inventory_formspec(player) end
end)
