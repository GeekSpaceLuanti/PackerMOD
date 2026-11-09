-- SPDX-License-Identifier: LGPL-2.1-or-later
return function(ui)
	local page = "packer_ui:settings"
	local function get(player, context)
		local node, label, button = ui.node, ui.label, ui.button
		local function text(key, ...)
			return ui.translate(player, ui.S(key, ...))
		end
		local high_contrast = player:get_meta():get_int(ui.contrast_key) == 1
		local pickup = core.settings:get_bool("packer_auto_pickup", true)
		local fields = {
			node("section", "panel", {
				label("h2", text("Interface")),
				label("p", text("Recipe book and game settings colors.")),
				node("div", "row", {
					button("packer_color_normal", text("Stone"), not high_contrast),
					button("packer_color_contrast", text("High contrast"), high_contrast)
				})
			}),
			node("section", "panel", {
				label("h2", text("World rules")),
				label("p", text("Automatic item pickup: @1", ui.S(pickup and "On" or "Off"))),
				label("p", text("Base gravity: @1", core.settings:get("movement_gravity") or "—")),
				label("p", text("Jump speed: @1", core.settings:get("movement_speed_jump") or "—")),
				label("p", text("Crouch speed: @1", core.settings:get("movement_speed_crouch") or "—")),
				label("p", text("World rules are set by the host."), "muted")
			}),
			label("p", text("Use Luanti's pause menu for graphics, sound, and controls."), "muted")
		}
		return ui.render(player, context, text("Settings"), fields, 640, context.packer_settings_scroll)
	end
	sfinv.register_page(page, {
		title = ui.S("Settings"),
		get = function(_, player, context) return get(player, context) end,
		on_player_receive_fields = function(_, player, context, fields)
			if ui.receive(player, context, fields) then return true end
			if fields.pm_flow_scroll then
				context.packer_settings_scroll = tonumber(fields.pm_flow_scroll:match("^[A-Z]+:(%d+)$"))
			end
			if fields.packer_color_normal or fields.packer_color_contrast then
				player:get_meta():set_int(ui.contrast_key, fields.packer_color_contrast and 1 or 0)
				sfinv.set_player_inventory_formspec(player, context)
				return true
			end
		end
	})
end
