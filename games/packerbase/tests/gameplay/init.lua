-- SPDX-License-Identifier: LGPL-2.1-or-later
local baseline = core.settings:get_bool("packer_test_baseline", false)
local player, last_sample, start_time
local floor_y = 0.5
local mode
local measured_gravity
local horizontal_trials = baseline and {"forward", "fast"}
	or {"forward", "backward", "left", "right", "diagonal", "fast"}
local trial_index, movement_started, release_position

local function start_horizontal(index)
	mode = nil
	trial_index = index
	local trial = horizontal_trials[index]
	player:set_pos({x = 0, y = floor_y, z = trial == "fast" and -8 or 0})
	player:set_look_horizontal(0)
	core.after(0.35, function()
		if not trial then
			player:set_pos({x = 2, y = 10.5, z = 0})
			mode = "fall"
			return
		end
		movement_started, release_position = nil, nil
		mode = "horizontal_move"
		core.log("action", "PackerMOD horizontal " .. trial .. " ready")
	end)
end

local function sample_horizontal(pos)
	local trial = horizontal_trials[trial_index]
	local controls = player:get_player_control()
	local moving = controls.up or controls.down or controls.left or controls.right
	local vel = player:get_velocity()
	local speed = math.sqrt(vel.x ^ 2 + vel.z ^ 2)
	if mode == "horizontal_move" then
		if not moving then return end
		local now = core.get_us_time()
		movement_started = movement_started or now
		local target = trial == "fast" and (baseline and 20 or 5.6121) or 4.317
		assert(speed <= target + 0.16, trial .. " exceeded its speed limit")
		if speed < target - 0.05 then return end
		if not baseline then assert(now - movement_started < 450000, "slow acceleration: " .. trial) end
		core.log("action", ("PackerMOD horizontal %s speed %.3f, ramp %.3f s")
			:format(trial, speed, (now - movement_started) / 1e6))
		mode = "horizontal_release"
	elseif not moving then
		release_position = release_position or pos
		if trial ~= "fast" and speed > 0.05 then return end
		local coast = math.sqrt((pos.x - release_position.x) ^ 2 + (pos.z - release_position.z) ^ 2)
		if trial ~= "fast" and not baseline then
			assert(coast < 0.8, "unexpected glide: " .. trial)
		end
		core.log("action", ("PackerMOD horizontal %s passed, coast %.3f"):format(trial, coast))
		start_horizontal(trial_index + 1)
	end
end

local function spawn_drop(position, stack)
	local object = assert(core.add_item(position, stack))
	object:set_velocity(vector.zero())
	object:set_acceleration(vector.zero())
	return object
end

local function check_pickup()
	local inventory = player:get_inventory()
	local stone = ItemStack("default:stone")
	local stack_max = stone:get_stack_max()
	local position = player:get_pos()
	inventory:set_list("main", {})
	local drop_position = vector.offset(position, 0.5, 0.25, 0)
	local dropped = spawn_drop(drop_position, "default:stone 3")
	core.after(0.2, function()
		assert(dropped:get_pos(), "drop picked up before delay")
		assert(inventory:is_empty("main"), "inventory changed before delay")
	end)
	core.after(0.9, function()
		assert(not dropped:get_pos(), "nearby item was not picked up")
		assert(inventory:get_stack("main", 1):get_count() == 3)
		local wood = ItemStack("default:wood")
		wood:set_count(wood:get_stack_max())
		for i = 1, inventory:get_size("main") do inventory:set_stack("main", i, wood) end
		stone:set_count(stack_max - 1)
		inventory:set_stack("main", 1, stone)
		local partial = spawn_drop(drop_position, "default:stone 5")
		core.after(0.9, function()
			assert(inventory:get_stack("main", 1):get_count() == stack_max)
			local entity = assert(partial:get_luaentity(), "leftover item was removed")
			assert(ItemStack(entity.itemstring):get_count() == 4, "wrong leftover count")
			inventory:set_stack("main", 2, "")
			entity:on_punch(player)
			assert(inventory:get_stack("main", 2):get_count() == 4)
			assert(not partial:get_pos(), "manual pickup did not remove the leftover")
			core.after(0.3, function()
				assert(inventory:get_stack("main", 2):get_count() == 4, "leftover picked up twice")
				core.log("action", "PackerMOD gameplay pickup passed: delay, partial capacity, manual coexistence")
				player:set_pos({x = 0, y = 5.5, z = 0})
				player:set_look_horizontal(0)
				core.after(0.5, function()
					mode = "edge"
					core.log("action", "PackerMOD gameplay edge ready")
				end)
			end)
		end)
	end)
end

core.register_on_joinplayer(function(joined)
	player = joined
	local name = player:get_player_name()
	local privileges = core.get_player_privs(name)
	privileges.fast = true
	core.set_player_privs(name, privileges)
	assert(player:get_properties().step_up_mode == (baseline and "legacy" or "rigid"))
	core.after(0.5, function()
		player:set_armor_groups({immortal = 1})
		local floor = {}
		for x = -12, 12 do
			for z = -21, 21 do floor[#floor + 1] = {x = x, y = 0, z = z} end
		end
		core.bulk_set_node(floor, {name = "default:stone"})
		core.set_node({x = 0, y = 5, z = 0}, {name = "default:stone"})
		start_horizontal(1)
	end)
end)

local function crossing_time(current, previous, level)
	return previous.time + (current.time - previous.time) * (previous.y - level) / (previous.y - current.y)
end

core.register_globalstep(function()
	if not mode then return end
	local pos = player:get_pos()
	if mode == "horizontal_move" or mode == "horizontal_release" then
		sample_horizontal(pos)
	elseif mode == "fall" then
		local sample = {y = pos.y, time = core.get_us_time() / 1e6, vy = player:get_velocity().y}
		if last_sample and last_sample.y <= 10.6 then
			if last_sample.y >= 9.5 and sample.y < 9.5 then start_time = crossing_time(sample, last_sample, 9.5) end
			if start_time and last_sample.y > 6.5 and sample.y <= 6.5 then
				-- Interpolate v² between client position packets. For constant
				-- acceleration its slope against distance is twice gravity.
				local fraction = (last_sample.y - 6.5) / (last_sample.y - sample.y)
				measured_gravity = (last_sample.vy ^ 2 + fraction * (sample.vy ^ 2 - last_sample.vy ^ 2)) / 8
			end
			if start_time and last_sample.y >= 1.5 and sample.y < 1.5 then
				local duration = crossing_time(sample, last_sample, 1.5) - start_time
				core.log("action", ("PackerMOD gameplay fall: %.3f s (1-9 blocks)"):format(duration))
				assert(measured_gravity, "missing fall velocity sample")
				local target = baseline and 19.62 or 28
				core.log("action", ("PackerMOD gameplay gravity: %.2f blocks/s² (target %.2f)"):format(measured_gravity, target))
				assert(math.abs(measured_gravity - target) < 2.5, "unexpected effective gravity")
				core.log("action", "PackerMOD gameplay fall passed")
				mode = nil
				if not baseline then core.after(0.4, check_pickup) end
			end
		end
		last_sample = sample
	elseif mode == "edge" then
		if pos.z > 0.72 then
			assert(math.abs(pos.y - 5.5) < 0.08, "crouching did not hold player on edge")
			assert(pos.z < 0.83, "player overshot crouched edge")
			mode = "step_off"
			core.log("action", ("PackerMOD gameplay crouched edge at z=%.3f"):format(pos.z))
		end
	elseif mode == "step_off" and pos.y < 5 then
		mode = nil
		assert(pos.y >= floor_y)
		core.log("action", "PackerMOD gameplay edge passed: stepping off after releasing crouch")
		player:set_pos({x = 0, y = floor_y, z = -2})
		player:set_physics_override({speed_walk = 0.8})
		core.after(0.4, function()
			mode = "sprint"
			core.log("action", "PackerMOD gameplay sprint ready")
		end)
	elseif mode == "sprint" and math.abs(player:get_physics_override().speed_walk - 1.04) < 0.001 then
		mode = "sprint_release"
		core.log("action", "PackerMOD gameplay sprint active: Ctrl+W applied 1.3×")
	elseif mode == "sprint_release" and not player:get_player_control().aux1
			and math.abs(player:get_physics_override().speed_walk - 0.8) < 0.001 then
		mode = nil
		core.log("action", "PackerMOD gameplay sprint passed: original speed restored")
	end
end)
