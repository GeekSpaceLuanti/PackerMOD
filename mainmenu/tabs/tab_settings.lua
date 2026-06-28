local function get_formspec(tabview, name, tabdata)
    local L = packermod.layout
    local INNER_W = PACKERMOD_TAB_W - 0.6
    local root = L.VBox{
        spacing = 0.3, padding = 0.5,
        L.Label{text="PackerMOD Settings", w=INNER_W},
        L.Label{text="User data path: " .. packermod.user_path, w=INNER_W},
        L.Label{text="PackerMOD version: " .. PACKERMOD_VERSION, w=INNER_W},
        L.Label{text="Luanti version: " .. core.get_version().string, w=INNER_W},
        L.Spacer{w=INNER_W, h=PACKERMOD_TAB_H - 6.0},
        L.HBox{
            L.Spacer{w=INNER_W - 3.0 - 0.2, h=0.8},
            L.Button{name="open_luanti_settings", label="Open Luanti settings", w=3.0, h=0.8},
        },
    }
    return L.build_formspec(root, { w = PACKERMOD_TAB_W, h = PACKERMOD_TAB_H, version = 6 })
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
