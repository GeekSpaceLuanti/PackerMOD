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
    local status = tabdata.status or ""

    local search_items = {}
    for _, r in ipairs(tabdata.search_results) do
        search_items[#search_items + 1] = format_search_result(r)
    end
    local mod_items = {}
    for _, m in ipairs(tabdata.mods) do
        mod_items[#mod_items + 1] = format_mod_entry(m)
    end

    local L = packermod.layout
    local root = L.VBox{
        spacing = 0.2, padding = 0.3,

        -- Row 1: pack identity
        L.HBox{
            L.Field{name="pack_id",      label="Pack id", w=3.5, default=tabdata.pack_id},
            L.Field{name="pack_name",    label="Name",    w=5.0, default=tabdata.pack_name},
            L.Field{name="pack_version", label="Version", w=2.5, default=tabdata.pack_version},
            L.Field{name="pack_author",  label="Author",  w=3.3, default=tabdata.pack_author},
        },

        -- Row 2: base game + description
        L.HBox{
            L.Field{name="base_id",          label="Base id",     w=3.5, default=tabdata.base_id},
            L.Field{name="base_version",     label="Base ver",    w=2.0, default=tabdata.base_version},
            L.Field{name="pack_description", label="Description", w=9.0, default=tabdata.pack_description},
        },

        -- Row 3: split into left (search) and right (mod list) columns
        L.HBox{
            spacing = 0.2,

            -- Left column: ContentDB search + status
            L.VBox{
                L.Label{text="ContentDB search"},
                L.HBox{
                    L.Field{name="search_query",   label="Query",   w=4.8, default=tabdata.search_query},
                    L.Field{name="search_release", label="Release", w=1.4, default=tabdata.search_release},
                    L.Button{name="search",     label="Search", w=1.2},
                    L.Button{name="add_search", label="Add",    w=1.0},
                },
                L.TextList{name="search_results", items=search_items,
                    selected=tabdata.search_selected, w=9.0, h=2.4},
                L.Label{text=status},
            },

            -- Right column: current mods + action buttons
            L.VBox{
                L.Label{text="Current mods"},
                L.TextList{name="mod_list", items=mod_items,
                    selected=tabdata.mod_selected, w=5.7, h=3.1},
                L.HBox{
                    L.Button{name="remove_mod", label="Remove",          w=2.0},
                    L.Button{name="export",     label="Export manifest", w=3.5},
                },
            },
        },
    }

    return L.build_formspec(root, { w = PACKERMOD_TAB_W, h = PACKERMOD_TAB_H, version = 6 })
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
