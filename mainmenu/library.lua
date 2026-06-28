-- Library: 単一画面のメイン UI(Phase 8)。
-- 左に Pack 一覧、右に選択中 Pack の詳細(Worlds / Multi / Mods / Info のサブナビ)。
-- 旧 4 タブ(tabs/tab_*.lua + ui/tab_*.yml)は Phase 11 でモーダル化するまで残置。

local M = {}

local function get_packs()
    return packermod.pack_manager.list_packs(packermod.user_path, packermod.manifest)
end

local function format_pack_label(p)
    -- 左パネルが狭い(w=4.5)ので簡潔に。詳細(version, base, mod count)は
    -- 右パネルで出すので重複させない。
    return tostring(p.manifest.name)
end

local function format_world_label(w)
    return tostring(w.display_name or w.name)
end

local SUBTABS = { "worlds", "multi", "mods", "info" }

local function subtab_variant(current, target)
    return (current == target) and "primary" or "secondary"
end

local function clamp_selection(idx, count)
    if count == 0 then return 1 end
    if not idx or idx < 1 then return 1 end
    if idx > count then return count end
    return idx
end

local function get_formspec(tabdata)
    local packs = get_packs()
    tabdata.packs = packs
    tabdata.selected_pack = clamp_selection(tabdata.selected_pack, #packs)
    local pack = packs[tabdata.selected_pack]

    local worlds = {}
    if pack then
        worlds = packermod.launcher.list_worlds(pack)
    end
    tabdata.worlds = worlds
    tabdata.selected_world = clamp_selection(tabdata.selected_world, #worlds)

    local subtab = tabdata.subtab or "worlds"
    tabdata.subtab = subtab

    local ctx = {
        packs = packs,
        selected_pack = tabdata.selected_pack,
        has_pack = pack ~= nil,
        no_pack = pack == nil,

        pack_name = pack and pack.manifest.name or "",
        pack_version = pack and pack.manifest.version or "",
        pack_base = pack and
            (pack.manifest.base_game.id .. "/" .. pack.manifest.base_game.version) or "",
        pack_mods_count = pack and (pack.manifest.mods and #pack.manifest.mods or 0) or 0,
        pack_description = pack and (pack.manifest.description or "") or "",

        variant_worlds = subtab_variant(subtab, "worlds"),
        variant_multi  = subtab_variant(subtab, "multi"),
        variant_mods   = subtab_variant(subtab, "mods"),
        variant_info   = subtab_variant(subtab, "info"),

        show_worlds = (subtab == "worlds") and pack ~= nil,
        show_multi  = (subtab == "multi")  and pack ~= nil,
        show_mods   = (subtab == "mods")   and pack ~= nil,
        show_info   = (subtab == "info")   and pack ~= nil,

        worlds = worlds,
        has_world = #worlds > 0,
        no_world = #worlds == 0,
        selected_world = tabdata.selected_world,

        format_pack_label = format_pack_label,
        format_world_label = format_world_label,
        icon_path = function(n) return packermod.icons.path(n, "md") end,
    }

    return packermod.ui_loader.build_tab_formspec(
        packermod.ui_loader.ui_yaml_path("library"),
        ctx,
        { version = 6, theme = packermod.theme }
    )
end

local function find_world_index_by_path(path)
    local worlds = core.get_worlds() or {}
    for i, w in ipairs(worlds) do
        if w.path == path then return i end
    end
    return nil
end

local function launch_existing(world)
    gamedata.selected_world = world.index
    gamedata.singleplayer = true
    core.settings:set("menu_last_game", world.gameid)
    core.start()
end

local function launch_new(pack)
    local ok, info = packermod.launcher.new_world(pack)
    if not ok then
        gamedata.errormessage = info
        return
    end
    local idx = find_world_index_by_path(info.world_path)
    if not idx then
        gamedata.errormessage = "Could not locate new world: " .. info.world_path
        return
    end
    gamedata.selected_world = idx
    gamedata.singleplayer = true
    core.settings:set("menu_last_game", info.gameid)
    core.start()
end

local function button_handler(self, fields)
    local tabdata = self.data

    if fields.packlist then
        local e = core.explode_textlist_event(fields.packlist)
        if e.type == "CHG" then
            tabdata.selected_pack = e.index
            tabdata.selected_world = 1
        end
        return true
    end

    for _, sub in ipairs(SUBTABS) do
        if fields["subtab_" .. sub] then
            tabdata.subtab = sub
            return true
        end
    end

    if fields.worldlist then
        local e = core.explode_textlist_event(fields.worldlist)
        if e.type == "CHG" then
            tabdata.selected_world = e.index
        end
        return true
    end

    local pack = tabdata.packs and tabdata.packs[tabdata.selected_pack]

    if fields.play_world and pack then
        local world = tabdata.worlds and tabdata.worlds[tabdata.selected_world]
        if world then launch_existing(world) end
        return true
    end

    if fields.new_world and pack then
        launch_new(pack)
        return true
    end

    -- Import / Create / Settings は Phase 11 でモーダル化するまで no-op
    if fields.btn_import or fields.btn_create or fields.btn_settings then
        return true
    end

    return false
end

function M.show()
    local dlg = dialog_create("packermod_library", get_formspec, button_handler, nil)
    -- Dev hook: jump to a specific subtab on startup, used by
    -- scripts/screenshot_mainmenu.sh to capture each subtab without xdotool
    -- click sequences.
    local initial = core.settings and core.settings:get("packermod_initial_subtab")
    if initial and initial ~= "" then
        dlg.data.subtab = initial
    end
    dlg:show()
    ui.set_default("packermod_library")
end

-- ハーネス用エクスポート(spec から呼ぶ)
M._internal = {
    format_pack_label = format_pack_label,
    format_world_label = format_world_label,
    subtab_variant = subtab_variant,
    clamp_selection = clamp_selection,
    SUBTABS = SUBTABS,
}

return M
