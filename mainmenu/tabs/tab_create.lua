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

local function get_formspec(tabview, name, tabdata)
    tabdata.pack_version  = tabdata.pack_version  or "0.1.0"
    tabdata.base_id       = tabdata.base_id       or "packerbase"
    tabdata.base_version  = tabdata.base_version  or "0.91"
    tabdata.mods          = tabdata.mods          or {}
    tabdata.search_results = tabdata.search_results or {}

    local ctx = {
        pack_id           = tabdata.pack_id,
        pack_name         = tabdata.pack_name,
        pack_version      = tabdata.pack_version,
        pack_author       = tabdata.pack_author,
        pack_description  = tabdata.pack_description,
        base_id           = tabdata.base_id,
        base_version      = tabdata.base_version,
        search_query      = tabdata.search_query,
        search_release    = tabdata.search_release,
        search_results    = tabdata.search_results,
        search_selected   = tabdata.search_selected,
        mods              = tabdata.mods,
        mod_selected      = tabdata.mod_selected,
        status            = tabdata.status or "",
        format_search_result = format_search_result,
        format_mod_entry     = format_mod_entry,
        icon_path = function(n) return packermod.icons.path(n, "md") end,
    }

    return packermod.ui_loader.build_tab_formspec(
        packermod.ui_loader.tab_yaml_path("create"),
        ctx,
        {
            w = PACKERMOD_TAB_W, h = PACKERMOD_TAB_H, version = 6,
            theme = packermod.theme,
        }
    )
end

local function handle_search(tabdata, fields)
    local q = tabdata.search_query or ""
    if q == "" then
        tabdata.status = "Enter a search query first."
        return
    end
    local results, err = packermod.client.search(q)
    if not results then
        tabdata.status = "Search failed: " .. tostring(err)
        return
    end
    tabdata.search_results = results
    tabdata.search_selected = 0
    tabdata.status = ("Found %d results."):format(#results)
end

local function handle_add_search(tabdata)
    local idx = tabdata.search_selected or 0
    local r = tabdata.search_results and tabdata.search_results[idx]
    if not r then
        tabdata.status = "Select a search result first."
        return
    end
    local release_id = tonumber(tabdata.search_release)
    if not release_id then
        tabdata.status = "Enter the ContentDB release id to pin (numeric)."
        return
    end
    local mod_spec = packermod.pack_builder.contentdb_result_to_mod(r, release_id)
    local ok, err = packermod.pack_builder.add_mod(tabdata, mod_spec)
    tabdata.status = ok and ("Added " .. mod_spec.name) or ("Add failed: " .. err)
end

local function handle_remove(tabdata)
    if not packermod.pack_builder.remove_mod(tabdata, tabdata.mod_selected or 0) then
        tabdata.status = "Select a mod to remove."
    else
        tabdata.status = "Removed."
    end
end

local function handle_export(tabdata)
    local ok, manifest = packermod.pack_builder.build_manifest(tabdata)
    if not ok then
        tabdata.status = "Cannot export: " .. manifest
        return
    end
    local dok, dumped = packermod.manifest.dump(manifest)
    if not dok then
        tabdata.status = "Cannot serialize: " .. dumped
        return
    end
    local ok2, id_or_err = packermod.importer.import_from_yaml_text(dumped)
    tabdata.status = ok2
        and ("Saved pack: " .. tostring(id_or_err) .. " (open Packs tab)")
        or ("Save failed: " .. tostring(id_or_err))
end

local FIELDS = {
    "pack_id", "pack_name", "pack_version", "pack_description", "pack_author",
    "base_id", "base_version", "search_query", "search_release",
}

local function button_handler(tabview, fields, name, tabdata)
    for _, k in ipairs(FIELDS) do
        if fields[k] ~= nil then tabdata[k] = fields[k] end
    end
    if fields.search_results then
        local ev = core.explode_textlist_event(fields.search_results)
        if ev.type == "CHG" or ev.type == "DCL" then tabdata.search_selected = ev.index end
    end
    if fields.mod_list then
        local ev = core.explode_textlist_event(fields.mod_list)
        if ev.type == "CHG" or ev.type == "DCL" then tabdata.mod_selected = ev.index end
    end
    if fields.search     then handle_search(tabdata, fields); return true end
    if fields.add_search then handle_add_search(tabdata);     return true end
    if fields.remove_mod then handle_remove(tabdata);         return true end
    if fields.export     then handle_export(tabdata);         return true end
    return false
end

return {
    name = "create",
    caption = function() return "Create" end,
    cbf_formspec = get_formspec,
    cbf_button_handler = button_handler,
}
