local function get_packs()
    return packermod.pack_manager.list_packs(packermod.user_path, packermod.manifest)
end

local function format_pack_label(p)
    local m = p.manifest
    return core.formspec_escape(
        ("%s   [%s]   base=%s/%s   mods=%d"):format(
            m.name, m.version, m.base_game.id, m.base_game.version,
            m.mods and #m.mods or 0))
end

local function get_formspec(tabview, name, tabdata)
    local packs = get_packs()
    tabdata.packs = packs

    local list_items = {}
    for _, p in ipairs(packs) do
        table.insert(list_items, format_pack_label(p))
    end

    local selected = tabdata.selected or 1
    local has_selection = #packs > 0

    local fs = {
        "formspec_version[6]",
        "size[15.5,7.1]",
        "label[0.5,0.5;Installed Packs]",
        "textlist[0.5,0.9;14.5,4.8;packlist;" .. table.concat(list_items, ",") .. ";" .. selected .. "]",
    }

    if has_selection then
        local p = packs[selected]
        local description = p.manifest.description or ""
        table.insert(fs, "label[0.5,5.9;" .. core.formspec_escape(description:sub(1, 200)) .. "]")
        table.insert(fs, "button[11.5,6.2;3.5,0.8;play;Play]")
    else
        table.insert(fs, "label[0.5,5.9;No packs installed. Use the Import tab to add one.]")
    end

    table.insert(fs, "button[0.5,6.2;3.5,0.8;refresh;Refresh]")

    return table.concat(fs, "")
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
