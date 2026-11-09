-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Copyright (C) 2026 PackerMOD contributors
if not core.settings:get_bool("packer_auto_pickup", true) then return end

local interval = 0.1
local pickup_delay = 0.5
local radius = 1.4

local function unobstructed(origin, destination)
	for hit in core.raycast(origin, destination, false, false) do
		local node = core.get_node(hit.under)
		local def = core.registered_nodes[node.name]
		if not def or def.walkable then return false end
	end
	return true
end

local function pick_up_nearby(player, position)
	local origin = vector.offset(position, 0, 0.7, 0)
	for _, object in ipairs(core.get_objects_inside_radius(origin, radius)) do
		local item_position = object:get_pos()
		if item_position then
			local entity = object:get_luaentity()
			if entity and entity.name == "__builtin:item" and entity.itemstring ~= ""
					and type(entity.age) == "number" and entity.age >= pickup_delay
					and not entity.force_out and not object:get_attach()
					and type(entity.on_punch) == "function" and unobstructed(origin, item_position) then
				-- Use the item entity's normal pickup path, including on_pickup hooks
				-- and leftover stacks. Lua callbacks run in order, so a later player
				-- sees only what remains after this player or a manual punch.
				entity:on_punch(player, 0, {damage_groups = {}}, vector.direction(origin, item_position), 0)
			end
		end
	end
end

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < interval then return end
	-- Do not replay scans after server lag.
	elapsed = elapsed % interval
	for _, player in ipairs(core.get_connected_players()) do
		local position = player:get_pos()
		if position and player:get_hp() > 0 and core.check_player_privs(player, {interact = true}) then
			pick_up_nearby(player, position)
		end
	end
end)
