local function get_formspec(tabview, name, tabdata)
    local status = tabdata.status or ""
    local fs = {
        "formspec_version[6]",
        "size[15.5,7.1]",
        "label[0.5,0.5;Import a Pack]",
        "label[0.5,1.0;Paste a manifest URL or a path to a local .zip / manifest.yaml]",
        "field[0.5,1.6;13,0.8;source;Source;" .. core.formspec_escape(tabdata.source or "") .. "]",
        "button[13.6,1.6;1.4,0.8;import;Import]",
        "label[0.5,3.0;" .. core.formspec_escape(status) .. "]",
    }
    return table.concat(fs, "")
end

local function button_handler(tabview, fields, name, tabdata)
    if fields.source then tabdata.source = fields.source end
    if fields.import then
        tabdata.status = "Import not implemented yet (planned for next milestone)."
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
