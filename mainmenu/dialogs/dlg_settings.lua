-- All engine settings stay inside the PackerMOD dialog and layout system.
local M = {}
local pages = dofile((debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./") .. "../settings_pages.lua")
local function T(text, ...) return packermod.i18n.t(text, ...) end
local function engine_text(text)
    if packermod.i18n.language() == "en" then return text end
    local translated = packermod.i18n.t(text)
    if translated ~= text then return translated end
    return core.gettext and core.gettext(text) or text
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local out = {}; for key, item in pairs(value) do out[key] = clone(item) end; return out
end
local function selected(data) return data.backend.by_name[data.selected_name or ""] end
local function draft(data, entry)
    local value = data.drafts[entry.name]
    return value ~= nil and value or data.backend.read(entry)
end
local function choices(entry)
    if entry.type == "bool" then return { "true", "false" } end
    return entry.values or {}
end
local function split_keys(value)
    local result = {}
    for key in tostring(value):gmatch("[^|]+") do result[#result + 1] = key end
    return result
end
local function refresh_list(data)
    local category = data.backend.categories[(data.category_index or 1) - 1]
    data.visible = data.backend.filter(data.query or "", category and category.name, engine_text)
    data.selected_index = 0
    for i, entry in ipairs(data.visible) do
        if entry.name == data.selected_name then data.selected_index = i; break end
    end
    if data.selected_index == 0 then
        data.selected_index = #data.visible > 0 and 1 or 0
        data.selected_name = data.visible[1] and data.visible[1].name
    end
end
local function capture(data, fields)
    local entry = selected(data)
    if not entry then return end
    local value = clone(draft(data, entry))
    if entry.noise_params then
        for _, key in ipairs({ "offset", "scale", "seed", "octaves", "persistence", "lacunarity", "flags" }) do
            if fields["noise_" .. key] ~= nil then value[key] = fields["noise_" .. key] end
        end
        for _, axis in ipairs({ "x", "y", "z" }) do
            if fields["noise_spread_" .. axis] ~= nil then value.spread[axis] = fields["noise_spread_" .. axis] end
        end
    elseif entry.type == "v3f" and fields.engine_x and fields.engine_y and fields.engine_z then
        value = ("(%s, %s, %s)"):format(fields.engine_x, fields.engine_y, fields.engine_z)
    elseif (entry.type == "bool" or entry.type == "enum") and fields.engine_choice then
        value = choices(entry)[tonumber(fields.engine_choice)] or value
    elseif fields.engine_value ~= nil then value = fields.engine_value end
    data.drafts[entry.name] = value
end

local function get_formspec(data)
    if not data.detail then return pages.build(data, engine_text) end
    local entry = selected(data)
    local value = entry and draft(data, entry) or ""
    local kind = entry and entry.type or ""
    local category_items = { T("All engine settings") }
    for _, category in ipairs(data.backend.categories) do
        local parts = {}; for _, part in ipairs(category.parts) do parts[#parts + 1] = engine_text(part) end
        category_items[#category_items + 1] = table.concat(parts, " / ")
    end
    local setting_items = {}
    for _, item in ipairs(data.visible) do setting_items[#setting_items + 1] = engine_text(item.readable_name or item.name) end
    local options, choice_index = {}, 1
    if entry then
        for i, option in ipairs(choices(entry)) do
            options[i] = kind == "bool" and T(option == "true" and "Enabled" or "Disabled")
                or (option == "" and T("Automatic") or option)
            if option == tostring(value) then choice_index = i end
        end
    end
    local bounds = {}
    if entry and entry.min then bounds[#bounds + 1] = T("Minimum: %s", tostring(entry.min)) end
    if entry and entry.max then bounds[#bounds + 1] = T("Maximum: %s", tostring(entry.max)) end
    if kind == "flags" then bounds[#bounds + 1] = T("Available flags: %s", table.concat(entry.possible or {}, ", ")) end
    local keys = kind == "key" and split_keys(value) or {}
    local key_items = {}
    for i, key in ipairs(keys) do key_items[i] = core.get_key_description and core.get_key_description(key) or key end
    local vector = { "0", "0", "0" }
    if kind == "v3f" then
        local x, y, z = tostring(value):gsub("[()]", ""):match("^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
        vector = { x or "0", y or "0", z or "0" }
    end
    local noise_rows = {}
    if entry and entry.noise_params then
        local fields = {
            { "offset", "Offset", value.offset }, { "scale", "Scale", value.scale },
            { "spread_x", "Spread X", value.spread.x }, { "spread_y", "Spread Y", value.spread.y },
            { "spread_z", "Spread Z", value.spread.z }, { "seed", "Seed", value.seed },
            { "octaves", "Octaves", value.octaves }, { "persistence", "Persistence", value.persistence },
            { "lacunarity", "Lacunarity", value.lacunarity },
        }
        for i = 1, #fields, 5 do
            local row = { fields = {} }
            for j = i, math.min(i + 4, #fields) do
                row.fields[#row.fields + 1] = { name = "noise_" .. fields[j][1],
                    label = T(fields[j][2]), value = tostring(fields[j][3]) }
            end
            noise_rows[#noise_rows + 1] = row
        end
    end
    local ctx = {
        settings_title = data.world and T("Edit world") or T("PackerMOD Settings"),
        show_language = not data.world,
        footer_note = data.world and T("Only this world: %s", data.world.display_name or data.world.name)
            or T("Some engine settings take effect after restart or when a new world is created."),
        languages = { "日本語", "English" }, language_index = packermod.i18n.language() == "en" and 2 or 1,
        category_items = category_items, category_index = data.category_index or 1,
        query = data.query or "", setting_items = setting_items, setting_index = data.selected_index,
        result_count = T("%d settings", #data.visible),
        setting_title = entry and engine_text(entry.readable_name or entry.name) or T("No matching settings"),
        setting_name = entry and entry.name or "", help_text = entry and engine_text(entry.comment or "") or "",
        has_help = entry and entry.comment and entry.comment ~= "", has_bounds = #bounds > 0,
        bounds_text = table.concat(bounds, " / "), status = data.status or "",
        has_setting = entry ~= nil and not entry.readonly,
        readonly_value = entry and entry.readonly and (type(value) == "table" and T("Terrain is locked after first play.") or tostring(value)) or "",
        is_readonly = entry and entry.readonly,
        show_choice = entry and not entry.readonly and (kind == "bool" or kind == "enum"), choice_items = options, choice_index = choice_index,
        show_scalar = entry and not entry.readonly and kind ~= "bool" and kind ~= "enum" and kind ~= "v3f" and kind ~= "key" and not entry.noise_params,
        show_vector = kind == "v3f" and not entry.readonly, vector_x = vector[1], vector_y = vector[2], vector_z = vector[3],
        show_keys = kind == "key" and not entry.readonly, key_items = key_items, key_index = data.key_selected or 0,
        binding_key = keys[data.key_selected or 0] or keys[1] or "",
        show_noise = entry and entry.noise_params and not entry.readonly, noise_rows = noise_rows,
        noise_flags = entry and entry.noise_params and (value.flags or "") or "",
        value = type(value) == "string" and value or "", show_browse = entry and not entry.readonly and (kind == "path" or kind == "filepath"),
        scroll_value = data.scroll or 0,
    }
    return packermod.pmui.build_formspec {
        html_path = packermod.mainmenu_path .. "ui" .. DIR_DELIM .. "modal_settings.html.yml",
        css_path = packermod.mainmenu_path .. "ui" .. DIR_DELIM .. "themes" .. DIR_DELIM .. "synthwave.css.yml",
        ctx = ctx, page_w = 30, page_h = 16, texture_dir = packermod.textures_dir,
    }
end

local function handler(self, fields)
    local data = self.data
    if fields.settings_back or (fields.quit and data.detail) then data.detail = false; data.status = ""; return true end
    if fields.dlg_close or fields.quit then data.closed = true; self:delete(); return true end
    if not data.detail then return pages.handle(data, fields, engine_text) end
    capture(data, fields)
    if fields.engine_scroll then
        data.scroll = core.explode_scrollbar_event(fields.engine_scroll).value or data.scroll
        return true
    end
    if fields.ui_language then
        local language = tonumber(fields.ui_language) == 2 and "en" or "ja"
        if language ~= packermod.i18n.language() then
            packermod.i18n.set(language); data.status = "Language saved."; refresh_list(data)
        end
    end
    if fields.engine_category and tonumber(fields.engine_category) ~= data.category_index then
        data.category_index = tonumber(fields.engine_category) or 1
        data.status = ""; refresh_list(data); return true
    end
    if fields.engine_query ~= nil then data.query = fields.engine_query end
    if fields.engine_search or fields.key_enter_field == "engine_query" or fields.engine_clear then
        if fields.engine_clear then data.query = "" end
        data.status = ""; refresh_list(data); return true
    end
    if fields.engine_list then
        local event = core.explode_textlist_event(fields.engine_list)
        if (event.type == "CHG" or event.type == "DCL") and data.visible[event.index] then
            data.selected_index, data.selected_name = event.index, data.visible[event.index].name
            data.key_selected, data.status = 0, ""
            data.scroll = 0
        end
        return true
    end
    local entry = selected(data)
    if not entry then return true end
    if fields.engine_keys then
        local event = core.explode_textlist_event(fields.engine_keys)
        if event.type == "CHG" then data.key_selected = event.index end
        return true
    end
    if fields.engine_bind or fields.engine_unbind then
        local keys = split_keys(draft(data, entry))
        local index = data.key_selected or 0
        if fields.engine_bind then
            index = index > 0 and math.min(index, #keys + 1) or #keys + 1
            keys[index] = fields.engine_bind
        elseif index > 0 and index <= #keys then table.remove(keys, index) end
        data.drafts[entry.name] = table.concat(keys, "|")
        data.key_selected = math.min(index, #keys)
        return true
    end
    if fields.engine_browse and (entry.type == "path" or entry.type == "filepath") then
        core.show_path_select_dialog("packermod_engine_path", T("Choose a path"), entry.type == "filepath")
        return true
    end
    if fields.packermod_engine_path_accepted then
        data.drafts[entry.name] = fields.packermod_engine_path_accepted; return true
    end
    if fields.engine_apply or fields.engine_reset then
        local ok, err
        if fields.engine_reset then ok, err = data.backend.reset(entry)
        else ok, err = data.backend.apply(entry, draft(data, entry)) end
        if ok then
            data.drafts[entry.name] = nil
            data.status = fields.engine_reset and "Restored default value." or "Saved."
        else data.status = "Save failed: " .. tostring(err) end
        return true
    end
    return true
end

function M.show(parent)
    if not packermod.engine_settings then
        local schema = packermod.get_engine_schema and packermod.get_engine_schema() or packermod.engine_settings_mod.load()
        packermod.engine_settings = packermod.settings_catalog.scope(schema, false)
    end
    local dlg = dialog_create("packermod_dlg_settings", get_formspec, handler, packermod.ui_window_event)
    dlg.data.backend, dlg.data.drafts = packermod.engine_settings, {}
    dlg.data.category_index = 1
    dlg.data.tab = core.settings:get("packermod_initial_settings_tab") or "general"
    dlg.data.show_advanced = (core.settings:get("packermod_show_advanced") or core.settings:get("packermod_initial_show_expert")) == "true"
    dlg.data.show_developer = (core.settings:get("packermod_show_developer") or core.settings:get("packermod_initial_show_developer")) == "true"
    local group = core.settings:get("packermod_initial_settings_group")
    if group and group ~= "" then dlg.data.group_by_tab = { [dlg.data.tab] = group } end
    local initial = core.settings:get("packermod_initial_engine_setting")
    dlg.data.detail = initial ~= nil and initial ~= ""
    dlg.data.selected_name = core.settings:get("packermod_initial_engine_setting") or "font_size"
    refresh_list(dlg.data)
    if parent then dlg:set_parent(parent); parent:hide() end
    dlg:show()
    return dlg
end
function M.show_world(parent, world)
    local dlg = M.show(parent)
    dlg.data.backend = packermod.world_settings_mod.open(world, packermod.get_engine_schema())
    dlg.data.world, dlg.data.tab, dlg.data.detail = world, "gameplay", false
    dlg.data.category_index, dlg.data.selected_name = 1, "creative_mode"
    refresh_list(dlg.data)
    return dlg
end
-- Compatibility for older screenshot hooks; this no longer opens a native UI.
function M.open_native(dialog) return dialog end
M._internal = { handler = handler, get_formspec = get_formspec, refresh_list = refresh_list, pages = pages }
return M
