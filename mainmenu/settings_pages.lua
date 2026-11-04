-- Player-facing settings pages. The engine schema remains the source of values
-- and validation; common settings are deliberately grouped for everyday use.
local M = {}
local catalog = dofile((debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./") .. "settings_catalog.lua")
local preferences = dofile((debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./") .. "ui_preferences.lua")
M.tabs = {
    { id = "general", title = "General", hint = "Frequently used settings", names = {
        "fov", "viewing_range", "sound_volume", "fullscreen", "autojump" } },
    { id = "controls", title = "Controls", hint = "Mouse, touch and movement behavior" },
    { id = "keymap", title = "Keymap", hint = "All key bindings" },
    { id = "graphics", title = "Video", hint = "Display, performance and effects" },
    { id = "audio", title = "Audio", hint = "Volume and mute" },
    { id = "interface", title = "Interface", hint = "Text, menus and HUD" },
    { id = "network", title = "Network", hint = "Connection and content downloads", level = "advanced" },
    { id = "advanced", title = "Developer", hint = "Debugging and engine internals", level = "developer" },
}
M.world_tabs = {
    { id = "gameplay", title = "Gameplay", hint = "Rules for this world only" },
    { id = "physics", title = "Physics", hint = "Player movement and gravity", level = "advanced" },
    { id = "terrain", title = "Terrain generation", hint = "Terrain is locked after first play." },
    { id = "hosting", title = "Hosting", hint = "Server settings for this world only", level = "advanced" },
}
function M.tabs_for(data)
    local result = {}
    for _, tab in ipairs(data.world and M.world_tabs or M.tabs) do
        if not tab.level or (tab.level == "advanced" and data.show_advanced) or (tab.level == "developer" and data.show_developer) then result[#result + 1] = tab end
    end
    return result
end
local ranges = {
    viewing_range = { 20, 1000, 10 }, fps_max = { 20, 240, 5 },
    gui_scaling = { 0.5, 3, 0.05 }, hud_scaling = { 0.5, 3, 0.05 },
    mouse_sensitivity = { 0.05, 1, 0.01 },
}
local function T(text, ...) return packermod.i18n.t(text, ...) end
local function refresh_after_drag(data)
    if not core.handle_async or not core.get_us_time then return end
    data.slider_changed_at = core.get_us_time()
    if data.slider_refresh_pending then return end
    data.slider_refresh_pending = true
    -- The mainmenu API has no timer or mouse-release callback. Keep one tiny
    -- async job in flight as a frame heartbeat, never blocking or busy-waiting.
    -- Rebuilding a formspec during CHG destroys the native scrollbar capture.
    local function poll()
        core.handle_async(function() return true end, {}, function()
            if data.closed then data.slider_refresh_pending = false; return end
            if core.get_us_time() - data.slider_changed_at < 250000 then poll(); return end
            data.slider_refresh_pending = false
            ui.update()
        end)
    end
    poll()
end
function M.range(entry)
    local range = ranges[entry.name]
    if range then return range[1], range[2], range[3] end
    if (entry.type == "int" or entry.type == "float") and entry.min and entry.max and entry.max > entry.min then
        return entry.min, entry.max, entry.type == "int" and 1 or (entry.max - entry.min) / 100
    end
end
function M.collect(data, translate)
    data.groups = {}
    if data.home_query and data.home_query ~= "" then
        local results = {}
        for _, entry in ipairs(data.backend.filter(data.home_query, nil, translate)) do
            if catalog.visible(entry, data) and entry.name ~= "gui_scaling" and entry.name ~= "font_size" then results[#results + 1] = entry end
        end
        if not data.world then
            local query = data.home_query:lower()
            for _, entry in ipairs(preferences.entries) do
                if (T(entry.readable_name) .. " " .. entry.name .. " " .. entry.native):lower():find(query, 1, true) then results[#results + 1] = entry end
            end
        end
        return results, T("Search results")
    end
    local tabs = M.tabs_for(data)
    local tab = tabs[1]
    for _, candidate in ipairs(tabs) do if candidate.id == data.tab then tab = candidate end end
    data.tab = tab.id
    local entries = {}
    if tab.id == "general" then
        entries[1] = { name = "packermod_language", type = "app_language", readable_name = "Display language" }
        for _, e in ipairs(preferences.entries) do entries[#entries + 1] = e end
        for _, name in ipairs(tab.names) do if data.backend.by_name[name] then entries[#entries + 1] = data.backend.by_name[name] end end
        return entries, T(tab.title)
    end
    local grouped, order = {}, {}
    if tab.id == "interface" and not data.world then
        grouped.Appearance, order[1] = preferences.entries, "Appearance"
    end
    for _, entry in ipairs(data.backend.entries) do
        local section, group = catalog.section(entry)
        local active_terrain = true
        if data.world and section == "terrain" and group:match("^Mapgen ") and data.backend.by_name.mg_name then
            active_terrain = group:gsub("^Mapgen ", ""):lower():gsub("%s", "") == data.backend.read(data.backend.by_name.mg_name)
        end
        if section == tab.id and active_terrain and catalog.visible(entry, data) and entry.name ~= "gui_scaling" and entry.name ~= "font_size" then
            if not grouped[group] then grouped[group] = {}; order[#order + 1] = group end
            grouped[group][#grouped[group] + 1] = entry
        end
    end
    if tab.id == "controls" or tab.id == "keymap" then
        local rank = {}; for i, name in ipairs({ "Mouse", "Movement", "Movement behavior", "Actions", "Hotbar", "Chat and commands", "Camera and HUD", "System keys", "Touchscreen", "Gamepad", "Debug keys" }) do rank[name] = i end
        table.sort(order, function(a,b) return (rank[a] or 99) < (rank[b] or 99) end)
    end
    data.group_by_tab = data.group_by_tab or {}
    local group = data.group_by_tab[tab.id]
    if not grouped[group] then group = order[1] end
    data.group_by_tab[tab.id], data.groups = group, order
    entries = grouped[group] or {}
    return entries, T(tab.title)
end
local function geometry()
    return preferences.viewport(30, 16)
end
function M.build(data, translate)
    local L = packermod.layout
    local width, height = geometry()
    local card_h = math.min(height - 1.6, 17.4)
    local compact = width < 25
    local entries, title = M.collect(data, translate)
    data.home_entries = entries
    local styles = {
        "bgcolor[#13171D;both;#13171D]",
        "style_type[button,button_key;border=false;bgcolor=#2B333E;textcolor=#EDF2F7;font_size=*1]",
        "style_type[field;textcolor=#EDF2F7;font_size=*1]",
        "style_type[button:hovered;bgcolor=#3B4857]",
        "style[dlg_close;bgcolor=#408F7A;textcolor=#FFFFFF]",
    }
    local tooltips = {}
    local function label(text, opts)
        opts = opts or {}; opts.text = "\27(c@" .. (opts.color or "#EDF2F7") .. ")" .. text
        return L.Label(opts)
    end
    local function button(name, text, w, color)
        if color then styles[#styles + 1] = "style[" .. name .. ";bgcolor=" .. color .. "]" end
        return L.Button { name = name, label = text, w = w, h = 0.9, bgcolor = color or "#303B48" }
    end
    local nav = L.VBox { w = not compact and 4.6 or nil, spacing = 0.22 }
    data.visible_tabs = M.tabs_for(data)
    if compact then
        local names, selected = {}, 1
        for i,tab in ipairs(data.visible_tabs) do names[i] = T(tab.title); if tab.id == data.tab then selected = i end end
        nav[#nav + 1] = L.Dropdown { name = "settings_tab_select", items = names, selected = selected, h = 0.8 }
    else
        local tabs = L.VBox { spacing = 0.22 }
        for _, tab in ipairs(data.visible_tabs) do
            tabs[#tabs + 1] = button("settings_tab_" .. tab.id, T(tab.title), 4.1,
                tab.id == data.tab and not (data.home_query and data.home_query ~= "") and "#357B6B" or "#242D38")
        end
        nav[#nav + 1] = L.Scroll { name = "settings_nav_scroll", value = data.nav_scroll or 0, flex = 1, h = 6, tabs }
    end
    local gates = compact and L.HBox { spacing = 0.2 } or L.VBox { spacing = 0.2 }
    for _, gate in ipairs({ { "advanced", "Expert" }, { "developer", "Developer options" } }) do
        gates[#gates + 1] = button("settings_show_" .. gate[1], T(gate[2]) .. " " .. T(data["show_" .. gate[1]] and "ON" or "OFF"), compact and nil or 4.6,
            data["show_" .. gate[1]] and "#357B6B" or "#303B48")
        if compact then gates[#gates].flex = 1 end
    end
    nav[#nav + 1] = gates
    local panel = L.VBox { flex = 1, spacing = 0.28 }
    local tab = M.tabs_for(data)[1]
    for _, candidate in ipairs(M.tabs_for(data)) do if candidate.id == data.tab then tab = candidate end end
    if not compact then panel[#panel + 1] = label(title, { h = 0.7, font_size = "*1.25" }) end
    local hint = tab.id == "terrain" and not data.backend.initialized and "Configure terrain before first play." or tab.hint
    if not compact then
        panel[#panel + 1] = label(data.home_query ~= "" and data.home_query and T("%d settings", #entries) or T(hint),
            { h = 0.5, color = "#98A5B3" })
    end
    if #data.groups > 1 and compact then
        local items, selected = {}, 1
        for i,name in ipairs(data.groups) do items[i] = translate(name); if name == data.group_by_tab[data.tab] then selected = i end end
        panel[#panel + 1] = L.Dropdown { name = "settings_group_select", items = items, selected = selected, h = 0.8 }
    elseif #data.groups > 1 then
        for first = 1, #data.groups, 4 do
            local group_row = L.HBox { spacing = 0.15 }
            for i = first, math.min(#data.groups, first + 3) do
                local name = data.groups[i]
                local b = button("settings_group_" .. i, translate(name), nil, data.group_by_tab[data.tab] == name and "#357B6B" or "#303B48")
                b.flex = 1
                group_row[#group_row + 1] = b
            end
            for i = #group_row + 1, 4 do group_row[#group_row + 1] = L.Spacer { flex = 1 } end
            panel[#panel + 1] = group_row
        end
    end
    local rows = L.VBox { spacing = 0.13 }
    data.row_entries, data.row_modes = {}, {}
    for i = 1, #entries do
        local entry = entries[i]
        local index = #data.row_entries + 1
        data.row_entries[index] = entry
        local name = "settings_row_" .. index
        local value = entry.type == "app_language" and packermod.i18n.language()
            or entry.type == "appearance" and preferences.read(entry) or data.backend.read(entry)
        local row = L.HBox { h = math.max(1.3, 0.9 * preferences.button_scale() + 0.3, 0.8 * preferences.font_scale() + 0.3), padding = 0.1, spacing = 0.2, align = "center", bgcolor = "#202832" }
        local title = (entry.type == "app_language" or entry.type == "appearance") and T(entry.readable_name)
            or translate(entry.readable_name or entry.name)
        if entry.type == "key" and value == "" then title = title .. " (" .. T("Unassigned") .. ")" end
        row[#row + 1] = label(title, { h = 0.8, flex = 1, ellipsize = true })
        local control
        local min, max = M.range(entry)
        if entry.readonly then
            data.row_modes[index] = "detail"
            control = button(name, T("View"), 6.1)
        elseif entry.type == "app_language" then
            control = L.Dropdown { name = name, items = { "日本語", "English" }, selected = value == "en" and 2 or 1, w = 6.1, h = 0.9 }
        elseif entry.type == "appearance" then
            local items = {}
            for _, option in ipairs(preferences.options()) do items[#items + 1] = T(option.title) end
            control = L.Dropdown { name = name, items = items, selected = preferences.selected_index(), w = 6.1, h = 0.9 }
        elseif entry.type == "bool" then
            control = button(name, value == "true" and T("ON") or T("OFF"), 6.1,
                value == "true" and "#357B6B" or "#303B48")
        elseif entry.type == "enum" then
            control = button(name, (value == "" and T("Automatic") or T(tostring(value))) .. "  >", 6.1)
        elseif entry.type == "key" then
            local key = tostring(value):match("[^|]+") or ""
            control = L.KeyButton { name = name, label = key, w = 6.1, h = 0.9, bgcolor = "#303B48" }
        elseif min and tonumber(value) and tonumber(value) >= min and tonumber(value) <= max then
            data.row_modes[index] = "slider"
            local numeric = tonumber(value)
            control = L.HBox { w = 6.1, spacing = 0.25, align = "center",
                L.Slider { name = name, value = math.floor((numeric - min) / (max - min) * 1000 + 0.5), flex = 1, h = 0.55 },
                label(entry.name:match("^sound_volume") and ("%d%%"):format(math.floor(numeric * 100 + 0.5))
                    or (math.abs(numeric) >= 1000000 and ("%.1g"):format(numeric) or ("%.3f"):format(numeric):gsub("0+$", ""):gsub("%.$", "")), { w = 2.2, h = 0.6 }),
            }
        else
            data.row_modes[index] = "detail"
            local caption = type(value) == "string" and #value <= 22 and (value == "" and T("Not set") or value) or T("Edit...")
            control = button(name, caption .. "  >", 6.1)
        end
        row[#row + 1] = control
        row[#row + 1] = (entry.type == "app_language" or entry.type == "appearance") and L.Spacer { w = 0.95 }
            or button("settings_edit_" .. index, "...", 0.95)
        row[#row + 1] = button((entry.readonly and "settings_locked_" or "settings_reset_") .. index, T("Reset"), 1.65, entry.readonly and "#242D38" or nil)
        tooltips[#tooltips + 1] = "tooltip[settings_reset_" .. index .. ";" .. L.fs_escape(T("Restore default")) .. "]"
        local help = translate(entry.comment or "")
        if entry.type ~= "app_language" then
            tooltips[#tooltips + 1] = "tooltip[settings_edit_" .. index .. ";" .. L.fs_escape(title .. (help ~= "" and "\n\n" .. help or "")) .. "]"
        end
        rows[#rows + 1] = row
    end
    if #entries == 0 then rows[#rows + 1] = label(T("No matching settings")) end
    panel[#panel + 1] = L.Scroll { name = "settings_list_scroll", value = data.list_scroll or 0, flex = 1, h = 6, rows }
    if not compact then panel[#panel + 1] = label(T("%d settings", #entries), { h = 0.5, color = "#98A5B3" }) end
    local search = L.HBox { spacing = 0.3, align = "center",
        label(data.world and T("Edit world") or T("Settings"), { h = 0.9, font_size = "*1.6" }), L.Spacer { flex = 1 },
        L.Field { name = "settings_query", default = data.home_query or "", w = 5.5, h = 0.8,
            close_on_enter = false, bgcolor = "#242D38" },
        button("settings_search", T("Search"), 2.2), button("settings_clear", T("Clear"), 2.2),
    }
    local status = data.status and data.status ~= "" and packermod.i18n.message(data.status)
        or (data.world and T("Only this world: %s", data.world.display_name or data.world.name) or T("Changes are saved automatically."))
    local body = compact and L.VBox { flex = 1, spacing = 0.35, nav, panel } or L.HBox { flex = 1, spacing = 0.7, nav, panel }
    local footer = L.HBox { spacing = 0.4, align = "center" }
    if not compact then footer[#footer + 1] = label(status, { flex = 1, h = 0.8, ellipsize = true, color = "#98A5B3" })
    elseif data.status and data.status ~= "" then
        footer[#footer + 1] = label(packermod.i18n.message(data.status), { flex = 1, h = 0.8, ellipsize = true, color = "#98A5B3" })
    else footer[#footer + 1] = L.Spacer { flex = 1 } end
    footer[#footer + 1] = button("dlg_close", T("Done"), 3.0, "#357B6B")
    tooltips[#tooltips + 1] = "tooltip[dlg_close;" .. L.fs_escape(status) .. "]"
    local card = L.VBox { w = math.min(28.4, width - 1.6), h = card_h, padding = 0.7, spacing = 0.5, bgcolor = "#1B222B",
        search,
        body,
        footer,
    }
    local root = L.VBox { spacing = 0, L.Spacer { flex = 1 },
        L.HBox { L.Spacer { flex = 1 }, card, L.Spacer { flex = 1 } }, L.Spacer { flex = 1 } }
    return L.build_formspec(root, { w = width, h = height, prepend = styles, append = tooltips })
end
function M.handle(data, fields, translate)
    if tostring(fields.settings_nav_scroll):match("^CHG:") then
        data.nav_scroll = core.explode_scrollbar_event(fields.settings_nav_scroll).value; return false
    end
    if fields.settings_list_scroll then
        data.list_scroll = core.explode_scrollbar_event(fields.settings_list_scroll).value or data.list_scroll
        local changed = false
        for name, value in pairs(fields) do
            if name:match("^settings_row_") and tostring(value):match("^CHG:") then changed = true end
            if name:match("^settings_reset_") or name:match("^settings_edit_") then changed = true end
        end
        if not changed then
            local action = false
            for name in pairs(fields) do
                if name:match("^settings_tab_") or name:match("^settings_group_") or name:match("^settings_show_")
                    or name == "settings_search" or name == "settings_clear" then action = true end
            end
            -- VAL is sent with every form; only a scrollbar CHG is exclusive.
            if tostring(fields.settings_list_scroll):match("^CHG:") and not action then return false end
        end
    end
    for _, gate in ipairs({ "advanced", "developer" }) do
        if fields["settings_show_" .. gate] then
            local key = "packermod_show_" .. gate
            local enabled = not data["show_" .. gate]
            local old = core.settings:get(key)
            core.settings:set(key, tostring(enabled))
            if core.settings:write() == false then
                if old then core.settings:set(key, old) else core.settings:remove(key) end
                data.status = "Save failed: Cannot write settings"; return true
            end
            data["show_" .. gate] = enabled
            data.list_scroll, data.home_query, data.status = 0, "", ""; return true
        end
    end
    if fields.settings_tab_select then
        local tab = (data.visible_tabs or {})[tonumber(fields.settings_tab_select)]
        if tab and tab.id ~= data.tab then data.tab, data.list_scroll, data.home_query, data.status = tab.id, 0, "", ""; return true end
    end
    if fields.settings_group_select then
        local group = (data.groups or {})[tonumber(fields.settings_group_select)]
        if group and group ~= data.group_by_tab[data.tab] then data.group_by_tab[data.tab], data.list_scroll = group, 0; return true end
    end
    for _, tab in ipairs(M.tabs_for(data)) do
        if fields["settings_tab_" .. tab.id] then
            data.tab, data.list_scroll, data.home_query, data.status = tab.id, 0, "", ""
            return true
        end
    end
    for i, name in ipairs(data.groups or {}) do
        if fields["settings_group_" .. i] then
            data.group_by_tab[data.tab], data.list_scroll, data.status = name, 0, ""; return true
        end
    end
    if fields.settings_search or fields.key_enter_field == "settings_query" or fields.settings_clear then
        data.home_query = fields.settings_clear and "" or fields.settings_query or ""
        data.list_scroll, data.status = 0, ""; return true
    end
    for index, entry in ipairs(data.row_entries or {}) do
        local input = fields["settings_row_" .. index]
        if data.row_modes and data.row_modes[index] == "slider" and not tostring(input):match("^CHG:") then input = nil end
        local reset = fields["settings_reset_" .. index]
        if entry.type == "app_language" and input and not reset then
            local lang = tonumber(input) == 2 and "en" or "ja"
            if lang == packermod.i18n.language() then input = nil end
        end
        if entry.type == "appearance" and input and tonumber(input) == preferences.selected_index() and not reset then input = nil end
        if input or fields["settings_edit_" .. index] or reset then
            if entry.type == "app_language" then
                local language = reset and "ja" or (tonumber(input) == 2 and "en" or "ja")
                if not reset and language == packermod.i18n.language() then input = nil
                else
                    packermod.i18n.set(language)
                    data.status = "Language saved."; return true
                end
            end
            if entry.type == "appearance" then
                local ok, err = preferences.change(entry, reset, input)
                data.status = ok and (reset and "Restored default value." or "Saved.") or "Save failed: " .. tostring(err)
                return true
            end
            if reset then
                local ok, err = data.backend.reset(entry)
                if ok and data.drafts then data.drafts[entry.name] = nil end
                data.status = ok and "Restored default value." or "Save failed: " .. tostring(err)
                return true
            end
            local min, max, step = M.range(entry)
            local value = data.backend.read(entry)
            if fields["settings_edit_" .. index] or (data.row_modes and data.row_modes[index] == "detail")
                    or not (entry.type == "bool" or entry.type == "enum" or entry.type == "key" or min) then
                data.selected_name, data.detail, data.scroll, data.status = entry.name, true, 0, ""
                return true
            elseif entry.type == "bool" then value = value == "true" and "false" or "true"
            elseif entry.type == "enum" then
                local current = 0
                for i, option in ipairs(entry.values) do if option == value then current = i end end
                value = entry.values[current % #entry.values + 1]
            elseif entry.type == "key" then
                local rest = tostring(value):match("|(.+)$")
                value = input .. (rest and "|" .. rest or "")
            elseif min then
                if not tostring(input):match("^CHG:") then return true end
                local event = core.explode_scrollbar_event(input)
                local n = min + math.max(0, math.min(1000, event.value)) / 1000 * (max - min)
                n = min + math.floor((n - min) / step + 0.5) * step
                value = tostring(math.max(min, math.min(max, n)))
            end
            local ok, err = data.backend.apply(entry, value)
            if ok and data.drafts then data.drafts[entry.name] = nil end
            data.status = ok and "Saved." or "Save failed: " .. tostring(err)
            if ok and data.row_modes and data.row_modes[index] == "slider" then
                refresh_after_drag(data)
                return false
            end
            return true
        end
    end
    return true
end
return M
