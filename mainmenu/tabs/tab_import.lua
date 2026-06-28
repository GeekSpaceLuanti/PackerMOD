local function get_formspec(tabview, name, tabdata)
    local status = tabdata.status or ""
    local fs = {
        "formspec_version[6]",
        "size[15.5,7.1]",
        "label[0.5,0.5;Import a Pack]",
        "label[0.5,1.0;Paste an http(s) URL or a local path to a .zip / manifest.yaml]",
        "field[0.5,1.6;12.5,0.8;source;Source;" .. core.formspec_escape(tabdata.source or "") .. "]",
        "field_close_on_enter[source;false]",
        "button[13.1,1.6;1.9,0.8;import;Import]",
        "label[0.5,3.0;" .. core.formspec_escape(status) .. "]",
    }
    return table.concat(fs, "")
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
