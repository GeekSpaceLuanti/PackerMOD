local function get_formspec(tabview, name, tabdata)
    local ctx = {
        source    = tabdata.source or "",
        status    = tabdata.status or "",
        icon_path = function(n) return packermod.icons.path(n, "md") end,
    }
    return packermod.ui_loader.build_tab_formspec(
        packermod.ui_loader.tab_yaml_path("import"),
        ctx,
        {
            w = PACKERMOD_TAB_W, h = PACKERMOD_TAB_H, version = 6,
            theme = packermod.theme,
        }
    )
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
