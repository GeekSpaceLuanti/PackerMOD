local function get_formspec(tabview, name, tabdata)
    local fs = {
        "formspec_version[6]",
        "size[15.5,7.1]",
        "label[0.5,0.5;PackerMOD Settings]",
        "label[0.5,1.4;User data path: " .. core.formspec_escape(packermod.user_path) .. "]",
        "label[0.5,2.0;PackerMOD version: " .. core.formspec_escape(PACKERMOD_VERSION) .. "]",
        "label[0.5,2.6;Luanti version: " .. core.formspec_escape(core.get_version().string) .. "]",
        "button[12,6.2;3,0.8;open_luanti_settings;Open Luanti settings]",
    }
    return table.concat(fs, "")
end

local function button_handler(tabview, fields, name, tabdata)
    if fields.open_luanti_settings then
        tabdata.status = "Luanti core settings dialog: planned."
        return true
    end
    return false
end

return {
    name = "settings",
    caption = function() return "Settings" end,
    cbf_formspec = get_formspec,
    cbf_button_handler = button_handler,
}
