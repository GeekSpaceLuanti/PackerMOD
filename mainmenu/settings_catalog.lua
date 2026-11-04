local M = {}
function M.is_world(e)
    return e.context == "server" or e.context == "world_creation" or e.name == "creative_mode" or e.name == "enable_damage"
end
function M.is_mapgen(e) return (e.category_parts or {})[1] == "Mapgen" end
local sets = {}
local function names(group, text)
    for name in text:gmatch("%S+") do sets[name] = group end
end
names("Movement", "keymap_forward keymap_backward keymap_left keymap_right keymap_jump keymap_sneak keymap_aux1 keymap_freemove keymap_fastmove keymap_noclip keymap_pitchmove keymap_autoforward")
names("Actions", "keymap_dig keymap_place keymap_inventory keymap_drop keymap_zoom")
names("Chat and commands", "keymap_chat keymap_cmd keymap_cmd_local keymap_console keymap_toggle_chat")
names("Camera and HUD", "keymap_camera_yaw_left keymap_camera_yaw_right keymap_camera_pitch_up keymap_camera_pitch_down keymap_camera_mode keymap_cinematic keymap_minimap keymap_toggle_hud keymap_toggle_fog keymap_rangeselect keymap_increase_viewing_range_min keymap_decrease_viewing_range_min")
function M.section(e)
    local p, n = e.category_parts or {}, e.name
    if M.is_world(e) then
        if M.is_mapgen(e) then return "terrain", p[2] or "Terrain basics" end
        if n:match("^movement_") then return "physics", "Physics" end
        if n == "creative_mode" or n == "enable_damage" or p[2] == "Server Gameplay" then return "gameplay", "Gameplay" end
        return "hosting", p[3] or p[2] or "Server"
    end
    if e.type == "key" then
        if n:match("^keymap_slot") or n:match("^keymap_hotbar") then return "keymap", "Hotbar" end
        if sets[n] then return "keymap", sets[n] end
        if n:match("debug") or n:match("profiler") or n:match("quicktune") or n:match("block_bounds") or n:match("update_camera") then
            return "keymap", "Debug keys"
        end
        return "keymap", "System keys"
    end
    if p[1] == "Controls" then
        if p[2] == "Touchscreen" then return "controls", "Touchscreen" end
        if n:match("hotbar") then return "controls", "Hotbar" end
        if n == "keyboard_camera_smoothing" or n == "keyboard_camera_speed" then return "controls", "Camera and HUD" end
        if p[2] == "Keyboard and Mouse" then return "controls", "Mouse" end
        return "controls", "Movement behavior"
    end
    if p[2] == "Gamepads" then return "controls", "Gamepad" end
    if p[1] == "Audio" or p[2] == "Audio" or p[3] == "Sound" then return "audio", (p[1] == "Audio" or p[2] == "Audio") and "Volume and mute" or "Sound device" end
    if p[2] == "User Interfaces" then return "interface", p[3] or "Language" end
    if p[3] == "Font" then return "interface", "Fonts" end
    if p[1] == "Graphics and Audio" or p[3] == "Graphics" or p[3] == "Lighting" then
        if p[2] == "Effects" then return "graphics", "Effects" end
        local leaf = p[3]
        if leaf == "Screen" or leaf == "FPS" or leaf == "Screenshots" or leaf == "Lighting" then return "graphics", leaf end
        if leaf == "Camera" or leaf == "Bobbing" or leaf == "3D" or leaf == "Damage" then return "graphics", "Camera" end
        if leaf == "Fog" or leaf == "Clouds" or leaf == "Node and Entity Highlighting" then return "graphics", "World appearance" end
        return "graphics", "Rendering"
    end
    if p[1] == "Client and Server" or p[3] == "Networking" or p[3] == "cURL" then return "network", p[3] or "Connection" end
    return "advanced", p[3] or p[2] or "Other"
end
function M.level(e)
    local p = e.category_parts or {}
    local section, group = M.section(e)
    if section == "advanced" or group == "Debug keys" or p[2] == "Developer Options" or p[3] == "Client Debugging" then return "developer" end
    if e.type == "flags" or e.type == "v3f" or e.noise_params or (e.type or ""):match("^noise_params_") then return "advanced" end
    if e.name == "creative_mode" or e.name == "enable_damage" or e.name == "time_speed"
        or e.name == "mg_name" or e.name == "fixed_map_seed" or e.name == "water_level" or e.name == "mg_flags" then return "basic" end
    if p[1] == "Advanced" or p[1] == "Client and Server" or p[1] == "Mapgen"
        or group == "Sound device" or group == "Fonts" or group == "Content Repository" then return "advanced" end
    return "basic"
end
function M.visible(e, data)
    local level = M.level(e)
    return level == "basic" or (level == "advanced" and data.show_advanced) or (level == "developer" and data.show_developer)
end
function M.scope(backend, world)
    local out = { entries = {}, by_name = {}, categories = {} }
    local known = {}
    for _, entry in ipairs(backend.entries) do
        if M.is_world(entry) == world then
            out.entries[#out.entries + 1], out.by_name[entry.name] = entry, entry
            if not known[entry.category] then
                known[entry.category] = true
                out.categories[#out.categories + 1] = { name = entry.category, parts = entry.category_parts }
            end
        end
    end
    for _, method in ipairs({ "read", "apply", "reset" }) do
        out[method] = function(entry, ...)
            if out.by_name[entry.name] ~= entry then return false, "Unknown setting" end
            return backend[method](entry, ...)
        end
    end
    function out.filter(query, category, translate)
        local result = {}
        for _, entry in ipairs(backend.filter(query, category, translate)) do
            if out.by_name[entry.name] then result[#result + 1] = entry end
        end
        return result
    end
    return out
end
return M
