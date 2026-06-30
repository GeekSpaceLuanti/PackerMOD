-- Create dialog (Phase 11). Library 左下の [Create] ボタンから開く。
-- 旧 tabs/tab_create.lua のロジックを dialog 形式に移植。新規 Pack を
-- 一から組み立てて Export(= packermod.importer.import_from_yaml_text)
-- する流れは無変更。

local M = {}

local function format_search_result(r)
    return ("%s/%s — %s"):format(r.author or "?", r.name or "?", r.title or r.short_description or "")
end

local function format_mod_entry(m)
    if m.source == "contentdb" then
        return ("%s   [contentdb %s @%s]"):format(m.name, m.package, tostring(m.release or "?"))
    elseif m.source == "bundle" then
        return ("%s   [bundle %s]"):format(m.name, m.path or "?")
    elseif m.source == "url" then
        return ("%s   [url]"):format(m.name)
    end
    return m.name
end

local function get_formspec(data)
    data.pack_version  = data.pack_version  or "0.1.0"
    data.base_id       = data.base_id       or "packerbase"
    data.base_version  = data.base_version  or "0.91"
    data.mods          = data.mods          or {}
    data.search_results = data.search_results or {}

    local ctx = {
        pack_id           = data.pack_id,
        pack_name         = data.pack_name,
        pack_version      = data.pack_version,
        pack_author       = data.pack_author,
        pack_description  = data.pack_description,
        base_id           = data.base_id,
        base_version      = data.base_version,
        search_query      = data.search_query,
        search_release    = data.search_release,
        search_results    = data.search_results,
        search_selected   = data.search_selected,
        mods              = data.mods,
        mod_selected      = data.mod_selected,
        status            = data.status or "",
        format_search_result = format_search_result,
        format_mod_entry     = format_mod_entry,
        icon_path = function(n) return packermod.icons.path(n, "md") end,
    }
    local DD = DIR_DELIM or "/"
    local mm = packermod.mainmenu_path or ("mainmenu" .. DD)
    return packermod.pmui.build_formspec {
        html_path = mm .. "ui" .. DD .. "modal_create.html.yml",
        css_path  = mm .. "ui" .. DD .. "themes" .. DD .. "synthwave.css.yml",
        ctx       = ctx,
        page_w = 30.0, page_h = 16.0,
        texture_dir = packermod.textures_dir,
    }
end

local FIELDS = {
    "pack_id", "pack_name", "pack_version", "pack_description", "pack_author",
    "base_id", "base_version", "search_query", "search_release",
}

local function handle_search(data)
    local q = data.search_query or ""
    if q == "" then data.status = "Enter a search query first."; return end
    local results, err = packermod.client.search(q)
    if not results then data.status = "Search failed: " .. tostring(err); return end
    data.search_results = results
    data.search_selected = 0
    data.status = ("Found %d results."):format(#results)
end

local function handle_add_search(data)
    local idx = data.search_selected or 0
    local r = data.search_results and data.search_results[idx]
    if not r then data.status = "Select a search result first."; return end
    local release_id = tonumber(data.search_release)
    if not release_id then
        data.status = "Enter the ContentDB release id to pin (numeric)."
        return
    end
    local mod_spec = packermod.pack_builder.contentdb_result_to_mod(r, release_id)
    local ok, err = packermod.pack_builder.add_mod(data, mod_spec)
    data.status = ok and ("Added " .. mod_spec.name) or ("Add failed: " .. err)
end

local function handle_remove(data)
    if not packermod.pack_builder.remove_mod(data, data.mod_selected or 0) then
        data.status = "Select a mod to remove."
    else
        data.status = "Removed."
    end
end

local function handle_export(data)
    local ok, manifest = packermod.pack_builder.build_manifest(data)
    if not ok then data.status = "Cannot export: " .. manifest; return end
    local dok, dumped = packermod.manifest.dump(manifest)
    if not dok then data.status = "Cannot serialize: " .. dumped; return end
    local ok2, id_or_err = packermod.importer.import_from_yaml_text(dumped)
    data.status = ok2
        and ("Saved pack: " .. tostring(id_or_err))
        or ("Save failed: " .. tostring(id_or_err))
end

local function handler(self, fields)
    local data = self.data
    if fields.dlg_close or fields.quit then self:delete(); return true end

    for _, k in ipairs(FIELDS) do
        if fields[k] ~= nil then data[k] = fields[k] end
    end
    if fields.search_results then
        local ev = core.explode_textlist_event(fields.search_results)
        if ev.type == "CHG" or ev.type == "DCL" then data.search_selected = ev.index end
    end
    if fields.mod_list then
        local ev = core.explode_textlist_event(fields.mod_list)
        if ev.type == "CHG" or ev.type == "DCL" then data.mod_selected = ev.index end
    end
    if fields.search     then handle_search(data);     return true end
    if fields.add_search then handle_add_search(data); return true end
    if fields.remove_mod then handle_remove(data);     return true end
    if fields.export     then handle_export(data);     return true end
    return false
end

function M.show(parent)
    local dlg = dialog_create("packermod_dlg_create", get_formspec, handler, nil)
    if parent then
        dlg:set_parent(parent)
        parent:hide()
    end
    dlg:show()
end

return M
