-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Apply client bindings before Luanti opens a world. Related keys move
-- together so a stock Luanti action does not occupy a Java binding.
local M = {}

local groups = {
    { keymap_inventory = "SYSTEM_SCANCODE_8", keymap_aux1 = "SYSTEM_SCANCODE_224" }, -- E, Left Ctrl
    { keymap_screenshot = "SYSTEM_SCANCODE_59", keymap_toggle_chat = "" }, -- F2
    { keymap_toggle_debug = "SYSTEM_SCANCODE_60", keymap_toggle_fog = "",
        keymap_camera_mode = "SYSTEM_SCANCODE_62" }, -- F3, F5
}

function M.apply_defaults(settings, key_description)
    local existing = settings:to_table()
    local added = {}
    local function key_id(key)
        return key_description and key_description(key) or key
    end
    for _, group in ipairs(groups) do
        local reserved = {}
        local function reserve(bindings)
            for key in (bindings or ""):gmatch("[^|]+") do
                reserved[key_id(key)] = true
            end
        end
        for name, value in pairs(existing) do
            if name:match("^keymap_") and type(value) == "string" then reserve(value) end
        end
        local available = true
        for name, key in pairs(group) do
            if existing[name] == nil and key ~= "" and reserved[key_id(key)] then
                available = false
                break
            end
        end
        if available then
            for name, value in pairs(group) do
                if existing[name] == nil then
                    settings:set(name, value)
                    existing[name], added[name] = value, true
                end
            end
        end
    end
    if next(added) and settings:write() == false then
        for name in pairs(added) do settings:remove(name) end
        return false
    end
    return true
end

return M
