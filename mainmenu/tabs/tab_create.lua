local function get_formspec(tabview, name, tabdata)
    local fs = {
        "formspec_version[6]",
        "size[15.5,7.1]",
        "label[0.5,0.5;Create a new Pack]",
        "field[0.5,1.2;6,0.8;pack_id;Pack id (a-z0-9_-);" .. core.formspec_escape(tabdata.pack_id or "") .. "]",
        "field[6.7,1.2;8.3,0.8;pack_name;Display name;" .. core.formspec_escape(tabdata.pack_name or "") .. "]",
        "field[0.5,2.4;6,0.8;pack_version;Version;" .. core.formspec_escape(tabdata.pack_version or "0.1.0") .. "]",
        "field[6.7,2.4;8.3,0.8;base_version;Base game version;" .. core.formspec_escape(tabdata.base_version or "0.91") .. "]",
        "button[12,6.2;3,0.8;export;Export manifest]",
        "label[0.5,3.6;Mod selection and ContentDB picker land in the next milestone.]",
    }
    return table.concat(fs, "")
end

local function button_handler(tabview, fields, name, tabdata)
    for k, v in pairs(fields) do
        if k:match("^pack_") or k == "base_version" then tabdata[k] = v end
    end
    if fields.export then
        tabdata.status = "Export not implemented yet."
        return true
    end
    return false
end

return {
    name = "create",
    caption = function() return "Create" end,
    cbf_formspec = get_formspec,
    cbf_button_handler = button_handler,
}
