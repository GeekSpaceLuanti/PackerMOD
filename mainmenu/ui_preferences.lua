-- One GUI size controls the complete interface. Native gui_scaling scales
-- fonts; changing the logical viewport scales controls and spacing with it.
local M = {}
local presets = {
    { id = "small", title = "Small", scale = 0.75 },
    { id = "standard", title = "Standard", scale = 1 },
    { id = "large", title = "Large", scale = 1.25 },
}
local retired = { "packermod_button_scale", "packermod_gui_auto", "packermod_gui_requested", "packermod_font_requested" }
local function settings() return core and core.settings end
local function window_size()
    local info = core and core.get_window_info and core.get_window_info()
    return info and info.size
end
function M.font_base()
    local schema = packermod and packermod.engine_settings
    return tonumber(schema and schema.by_name.font_size and schema.by_name.font_size.default) or 16
end
function M.options()
    local size = window_size()
    local capacity = size and math.min(size.x / 800, size.y / 600) or 1.25
    local result = { { id = "auto", title = "Automatic" } }
    for _, preset in ipairs(presets) do
        if preset.scale <= capacity or preset.id == "small" then result[#result + 1] = preset end
    end
    return result
end
local function choice()
    local s = settings()
    local value = s and s:get("packermod_gui_size")
    if value then return value end
    -- Migrate the former controls using the GUI choice, ignoring independent
    -- button/font overrides so their ratios return to the shared baseline.
    if s and s:get("packermod_gui_auto") == "true" then return "auto" end
    local legacy = s and tonumber(s:get("packermod_gui_requested"))
    if legacy then return legacy < 0.9 and "small" or legacy < 1.1 and "standard" or "large" end
    return "auto"
end
function M.read()
    local value, options = choice(), M.options()
    for _, option in ipairs(options) do if option.id == value then return value end end
    return options[#options].id
end
function M.gui_scale()
    local value, options = M.read(), M.options()
    if value == "auto" then return window_size() and options[#options].scale or 1 end
    for _, option in ipairs(options) do if option.id == value then return option.scale end end
    return 1
end
-- Internal geometry remains at a fixed ratio. The single native GUI scale
-- supplies the physical enlargement of both text and controls.
function M.button_scale() return 1 end
function M.font_scale() return 1 end
local function apply()
    local s = settings()
    if not s then return false end
    local changed = false
    local function set(key, value, fallback)
        if (s:get(key) or fallback) ~= value then s:set(key, value); changed = true end
    end
    set("packermod_gui_size", M.read(), "auto")
    set("gui_scaling", tostring(M.gui_scale()), "1")
    set("font_size", tostring(M.font_base()), tostring(M.font_base()))
    for _, key in ipairs(retired) do
        if s:get(key) ~= nil then s:remove(key); changed = true end
    end
    return changed
end
function M.ensure_safe()
    if apply() then settings():write() end
end
function M.viewport(w, h, fixed)
    if not fixed then M.ensure_safe() end
    local scale = fixed and 1 or M.gui_scale()
    if not fixed then
        local size = window_size()
        if size and size.x > 0 then h = math.max(h, math.min(24, w * size.y / size.x)) end
    end
    w, h = math.max(math.min(w, 24), w / scale), math.max(math.min(h, 14), h / scale)
    -- max_formspec_size already includes DPI and the engine GUI scale.
    -- Clamp both axes independently; a nominal logical size can be offscreen.
    local info = not fixed and core and core.get_window_info and core.get_window_info()
    local limit = info and info.max_formspec_size
    if limit and limit.x > 0 and limit.y > 0 then
        w, h = math.min(w, math.max(1, limit.x - 0.5)), math.min(h, math.max(1, limit.y - 0.5))
    end
    return w, h
end
M.entries = {
    { name = "pm_gui_scale", type = "appearance", readable_name = "GUI size", default = "auto", native = "gui_scaling" },
}
function M.selected_index()
    for i, option in ipairs(M.options()) do if option.id == M.read() then return i end end
    return 1
end
function M.change(_, reset, input)
    local s, options = settings(), M.options()
    local selected = reset and options[1] or options[tonumber(input)]
    if not selected then return false, "Invalid GUI size" end
    local keys, old = { "packermod_gui_size", "gui_scaling", "font_size" }, {}
    for _, key in ipairs(retired) do keys[#keys + 1] = key end
    local explicit = s.to_table and s:to_table()
    for _, key in ipairs(keys) do old[key] = explicit and explicit[key] or (not explicit and s:get(key) or nil) end
    s:set("packermod_gui_size", selected.id)
    apply()
    if s:write() == false then
        for _, key in ipairs(keys) do if old[key] ~= nil then s:set(key, old[key]) else s:remove(key) end end
        return false, "Cannot write settings"
    end
    return true
end
return M
