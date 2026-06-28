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

local function format_server_label(s)
    local addr = s.address or ""
    if s.port and s.port ~= 30000 then
        addr = addr .. ":" .. tostring(s.port)
    end
    if s.name and s.name ~= "" then
        return ("%s   (%s)"):format(s.name, addr)
    end
    return addr
end

local function format_mod_entry(m)
    if m.source == "contentdb" then
        return ("%s   [contentdb %s @%s]"):format(m.name, m.package, tostring(m.release or "?"))
    elseif m.source == "bundle" then
        return ("%s   [bundle %s]"):format(m.name, m.path or "?")
    elseif m.source == "url" then
        return ("%s   [url]"):format(m.name)
    end
    return m.name
end

local function format_search_result(r)
    return ("%s/%s — %s"):format(r.author or "?", r.name or "?", r.title or r.short_description or "")
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
    local servers = {}
    if pack then
        worlds = packermod.launcher.list_worlds(pack)
        servers = packermod.launcher.list_servers(pack)
    end
    tabdata.worlds = worlds
    tabdata.servers = servers
    tabdata.selected_world = clamp_selection(tabdata.selected_world, #worlds)
    tabdata.selected_server = clamp_selection(tabdata.selected_server, #servers)

    local subtab = tabdata.subtab or "worlds"
    tabdata.subtab = subtab

    local form = tabdata.form_server or {}
    local mods_state = tabdata.mods_state or {}
    local info_state = tabdata.info_state or {}

    local pack_mods = pack and (pack.manifest.mods or {}) or {}
    tabdata.selected_mod = clamp_selection(tabdata.selected_mod, #pack_mods)

    local search_results = mods_state.results or {}
    tabdata.selected_search = clamp_selection(tabdata.selected_search, #search_results)

    local ctx = {
        packs = packs,
        selected_pack = tabdata.selected_pack,
        has_pack = pack ~= nil,
        no_pack = pack == nil,

        pack_name = pack and pack.manifest.name or "",
        pack_version = pack and pack.manifest.version or "",
        pack_base = pack and
            (pack.manifest.base_game.id .. "/" .. pack.manifest.base_game.version) or "",
        pack_mods_count = #pack_mods,
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

        servers = servers,
        has_server = #servers > 0,
        no_server = #servers == 0,
        selected_server = tabdata.selected_server,
        form_server_name = form.name or "",
        form_server_address = form.address or "",
        form_server_port = form.port or "",

        pack_mods = pack_mods,
        has_mod = #pack_mods > 0 and (tabdata.selected_mod or 0) > 0,
        selected_mod = tabdata.selected_mod,
        search_query = mods_state.query or "",
        search_release = mods_state.release or "",
        search_results = search_results,
        selected_search = tabdata.selected_search,
        has_search_result = #search_results > 0 and (tabdata.selected_search or 0) > 0,
        mod_status = mods_state.status or "",

        info_status = info_state.status or "",

        format_pack_label = format_pack_label,
        format_world_label = format_world_label,
        format_server_label = format_server_label,
        format_mod_entry = format_mod_entry,
        format_search_result = format_search_result,
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

local function launch_server(server)
    gamedata.singleplayer = false
    gamedata.address = server.address
    gamedata.port = tonumber(server.port) or 30000
    gamedata.playername = core.settings:get("name") or "Player"
    gamedata.password = ""
    gamedata.selected_world = 0
    core.start()
end

-- form 入力を server_list の形に整形(空文字列は省く)。失敗時 nil + err。
local function build_server_from_form(form)
    local addr = (form.address or ""):match("^%s*(.-)%s*$")
    if addr == "" then return nil, "Address is required" end
    local port = tonumber(form.port)
    if form.port and form.port ~= "" and not port then
        return nil, "Port must be a number"
    end
    return {
        name = (form.name or ""):match("^%s*(.-)%s*$"),
        address = addr,
        port = port or 30000,
        description = "",
    }
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

    -- ---- Multiplayer サブタブ ----

    if fields.serverlist then
        local e = core.explode_textlist_event(fields.serverlist)
        if e.type == "CHG" then
            tabdata.selected_server = e.index
        end
        return true
    end

    -- 入力中の form 値は serverlist 選択など毎に formspec 再描画で消えないよう保持する
    tabdata.form_server = tabdata.form_server or {}
    if fields.server_name    ~= nil then tabdata.form_server.name = fields.server_name end
    if fields.server_address ~= nil then tabdata.form_server.address = fields.server_address end
    if fields.server_port    ~= nil then tabdata.form_server.port = fields.server_port end

    if fields.server_add and pack then
        local entry, err = build_server_from_form(tabdata.form_server)
        if not entry then
            gamedata.errormessage = err
            return true
        end
        local ok, add_err = packermod.server_list.add(pack.path, entry)
        if not ok then
            gamedata.errormessage = add_err or "Failed to save server"
        else
            tabdata.form_server = {}
        end
        return true
    end

    if fields.server_remove and pack then
        local idx = tabdata.selected_server
        if idx and idx > 0 then
            packermod.server_list.remove(pack.path, idx)
            tabdata.selected_server = 1
        end
        return true
    end

    if fields.server_connect and pack then
        local server = tabdata.servers and tabdata.servers[tabdata.selected_server]
        if server then launch_server(server) end
        return true
    end

    -- ---- Mods サブタブ ----

    tabdata.mods_state = tabdata.mods_state or {}
    local mods_state = tabdata.mods_state

    if fields.mod_list then
        local e = core.explode_textlist_event(fields.mod_list)
        if e.type == "CHG" or e.type == "DCL" then tabdata.selected_mod = e.index end
        return true
    end
    if fields.search_results then
        local e = core.explode_textlist_event(fields.search_results)
        if e.type == "CHG" or e.type == "DCL" then tabdata.selected_search = e.index end
        return true
    end
    if fields.search_query ~= nil then mods_state.query = fields.search_query end
    if fields.search_release ~= nil then mods_state.release = fields.search_release end

    if fields.do_search and pack then
        local q = mods_state.query or ""
        if q == "" then
            mods_state.status = "Enter a query first."
        else
            local results, err = packermod.client.search(q)
            if not results then
                mods_state.status = "Search failed: " .. tostring(err)
                mods_state.results = {}
            else
                mods_state.results = results
                mods_state.status = ("Found %d results."):format(#results)
                tabdata.selected_search = 1
            end
        end
        return true
    end

    if fields.mod_add and pack then
        local r = mods_state.results and mods_state.results[tabdata.selected_search or 0]
        if not r then
            mods_state.status = "Select a search result first."
            return true
        end
        local release_id = tonumber(mods_state.release)
        if not release_id then
            mods_state.status = "Enter the ContentDB release id (numeric)."
            return true
        end
        local mod_spec = packermod.pack_editor.contentdb_result_to_mod(r, release_id)
        local ok, err = packermod.pack_editor.add_mod(pack, mod_spec)
        mods_state.status = ok and ("Added " .. mod_spec.name) or ("Add failed: " .. tostring(err))
        return true
    end

    if fields.mod_remove and pack then
        local idx = tabdata.selected_mod or 0
        if idx < 1 then
            mods_state.status = "Select a mod to remove."
            return true
        end
        local ok, err = packermod.pack_editor.remove_mod(pack, idx)
        mods_state.status = ok and "Removed." or ("Remove failed: " .. tostring(err))
        if ok then tabdata.selected_mod = 1 end
        return true
    end

    -- ---- Info サブタブ ----

    tabdata.info_state = tabdata.info_state or {}

    if fields.info_save and pack then
        local ok, err = packermod.pack_editor.update_meta(pack, {
            name = fields.info_name,
            version = fields.info_version,
            description = fields.info_description,
        })
        tabdata.info_state.status = ok and "Saved." or ("Save failed: " .. tostring(err))
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
    format_server_label = format_server_label,
    format_mod_entry = format_mod_entry,
    format_search_result = format_search_result,
    build_server_from_form = build_server_from_form,
    subtab_variant = subtab_variant,
    clamp_selection = clamp_selection,
    SUBTABS = SUBTABS,
}

return M
