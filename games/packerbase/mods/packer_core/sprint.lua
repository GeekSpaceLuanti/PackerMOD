-- SPDX-License-Identifier: LGPL-2.1-or-later
if not core.settings:get_bool("packer_sprint", true) then return end

local sprint = {}
local speed_multiplier = 1.3
local interval = 0.05
local elapsed = 0

local function in_liquid_or_climbing(position)
    for _, height in ipairs({0.1, 0.8}) do
        local node = core.get_node_or_nil(vector.offset(position, 0, height, 0))
        local def = node and core.registered_nodes[node.name]
        if not def or def.climbable or (def.liquidtype and def.liquidtype ~= "none") then
            return true
        end
    end
    return false
end

local function update(player)
    local name = player:get_player_name()
    local controls = player:get_player_control()
    local position = player:get_pos()
    local wants_sprint = controls.aux1 and controls.up and not controls.down and not controls.sneak
        and player:get_hp() > 0 and position and not player:get_attach()
        and not in_liquid_or_climbing(position)
    local state = sprint[name]
    if not wants_sprint then
        if state and player:get_physics_override().speed_walk == state.applied then
            player:set_physics_override({speed_walk = state.previous})
        end
        sprint[name] = nil
        return
    end
    if state then return end

    local speed = player:get_physics_override().speed_walk
    if type(speed) ~= "number" then return end -- older Luanti lacks the walk-only factor
    player:set_physics_override({speed_walk = speed * speed_multiplier})
    -- Read back the engine's float. If a MOD changes this factor while Ctrl
    -- is held, leave its value intact until the next sprint starts.
    sprint[name] = {previous = speed, applied = player:get_physics_override().speed_walk}
end

core.register_globalstep(function(dtime)
    elapsed = elapsed + dtime
    if elapsed < interval then return end
    elapsed = elapsed % interval
    for _, player in ipairs(core.get_connected_players()) do update(player) end
end)

core.register_on_leaveplayer(function(player)
    sprint[player:get_player_name()] = nil
end)
