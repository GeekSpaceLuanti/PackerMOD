local function get_formspec(tabview, name, tabdata)
    local ctx = {
        user_path      = packermod.user_path,
        version        = PACKERMOD_VERSION,
        luanti_version = core.get_version().string,
        icon_path      = function(n) return packermod.icons.path(n, "md") end,
    }
    return packermod.ui_loader.build_tab_formspec(
        packermod.ui_loader.tab_yaml_path("settings"),
        ctx,
        { version = 6, theme = packermod.theme }
    )
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
