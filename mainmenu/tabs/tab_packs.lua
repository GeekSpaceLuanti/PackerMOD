local function get_packs()
    return packermod.pack_manager.list_packs(packermod.user_path, packermod.manifest)
end

local function format_pack_label(p)
    local m = p.manifest
    return ("%s   [%s]   base=%s/%s   mods=%d"):format(
        m.name, m.version, m.base_game.id, m.base_game.version,
        m.mods and #m.mods or 0)
end

local function get_formspec(tabview, name, tabdata)
    local packs = get_packs()
    tabdata.packs = packs

    local selected = tabdata.selected or 1
    local has_selection = #packs > 0
    local description
    if has_selection then
        description = (packs[selected].manifest.description or ""):sub(1, 200)
    else
        description = "No packs installed. Use the Import tab to add one."
    end

    local ctx = {
        packs = packs,
        selected = selected,
        has_selection = has_selection,
        description = description,
        format_pack_label = format_pack_label,
        icon_path = function(n) return packermod.icons.path(n, "md") end,
    }

    return packermod.ui_loader.build_tab_formspec(
        packermod.ui_loader.tab_yaml_path("packs"),
        ctx,
        {
            w = PACKERMOD_TAB_W, h = PACKERMOD_TAB_H, version = 6,
            theme = packermod.theme,
        }
    )
end

local function button_handler(tabview, fields, name, tabdata)
    if fields.packlist then
        local event = core.explode_textlist_event(fields.packlist)
        if event.type == "CHG" then
            tabdata.selected = event.index
            return true
        end
    end
    if fields.refresh then
        return true
    end
    if fields.play and tabdata.packs and tabdata.selected then
        local pack = tabdata.packs[tabdata.selected]
        if not pack then return true end
        local ok, info_or_err = packermod.launcher.launch(pack)
        if not ok then
            gamedata.errormessage = info_or_err
            return true
        end
        local worlds = core.get_worlds()
        local idx
        for i, w in ipairs(worlds) do
            if w.path == info_or_err.world_path then idx = i; break end
        end
        if not idx then
            gamedata.errormessage = "Could not locate new world in worldlist: " .. info_or_err.world_path
            return true
        end
        gamedata.selected_world = idx
        gamedata.singleplayer = true
        core.settings:set("menu_last_game", info_or_err.gameid)
        core.start()
        return true
    end
    return false
end

return {
    name = "packs",
    caption = function() return "Packs" end,
    cbf_formspec = get_formspec,
    cbf_button_handler = button_handler,
}
