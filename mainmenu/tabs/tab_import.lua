local function get_formspec(tabview, name, tabdata)
    local status = tabdata.status or ""
    local L = packermod.layout
    local INNER_W = PACKERMOD_TAB_W - 0.6  -- 14.9
    local FIELD_W = INNER_W - 1.9 - 0.2    -- leave space for Import button
    local root = L.VBox{
        spacing = 0.2, padding = 0.3,
        L.Label{text="Import a Pack"},
        L.Label{text="Paste an http(s) URL or a local path to a .zip / manifest.yaml"},
        L.HBox{
            L.Field{name="source", label="Source", w=FIELD_W, h=0.8, default=tabdata.source,
                    close_on_enter=false},
            L.Button{name="import", label="Import", w=1.9, h=0.8},
        },
        L.Label{text=status, w=INNER_W},
    }
    return L.build_formspec(root, { w = PACKERMOD_TAB_W, h = PACKERMOD_TAB_H, version = 6 })
end

local function button_handler(tabview, fields, name, tabdata)
    if fields.source then tabdata.source = fields.source end
    if fields.import then
        local src = (tabdata.source or ""):match("^%s*(.-)%s*$")
        if src == "" then
            tabdata.status = "Enter a URL or local path first."
            return true
        end
        local ok, id_or_err = packermod.importer.import(src)
        if ok then
            tabdata.status = "Imported pack: " .. tostring(id_or_err) ..
                "\nSwitch to the Packs tab to play."
            tabdata.source = ""
        else
            tabdata.status = "Import failed: " .. tostring(id_or_err)
        end
        return true
    end
    return false
end

return {
    name = "import",
    caption = function() return "Import" end,
    cbf_formspec = get_formspec,
    cbf_button_handler = button_handler,
}
