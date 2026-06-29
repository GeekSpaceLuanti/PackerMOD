-- Library: マイクラ風ハイブリッド UI。
--   view = "grid"   : Pack を 3 列カード grid で表示(サムネ + 名前 + base game)
--   view = "detail" : Pack 詳細(Worlds / Multi / Mods / Info の subtab)
-- グリッドはアイテム数が動的なので library.lua 内で直接 layout API で構築する。
-- 詳細画面は ui/library.yml を使う。

local M = {}

local function get_packs()
    return packermod.pack_manager.list_packs(packermod.user_path, packermod.manifest)
end

local function format_world_label(w)
    local label = tostring(w.display_name or w.name)
    if w.legacy then label = "[legacy] " .. label end
    return label
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

-- 「button name 互換」になる pack id 用 slug。formspec の名前に英数字以外を入れない。
local function pack_button_name(pack_id)
    return "pack_select_" .. (tostring(pack_id):gsub("[^%w_]", "_"))
end

local function default_thumbnail_texture()
    -- 絶対パスで返す(Luanti mainmenu は name 解決できないため)
    local base = "packermod_default_pack_thumbnail.png"
    if packermod and packermod.textures_dir then
        return packermod.textures_dir .. base
    end
    return base
end

-- thumbnail 表示用 texture を決める。pack manifest の thumbnail フィールドが
-- あればそれを pack ディレクトリからの相対パスとして解決し、無ければデフォルト。
-- ※ Luanti formspec image[] はテクスチャ名 or 絶対パスを受け付ける。
local function resolve_thumbnail(pack)
    local m = pack and pack.manifest
    if m and m.thumbnail and m.thumbnail ~= "" then
        return pack.path .. "/" .. m.thumbnail
    end
    return default_thumbnail_texture()
end

-- ----- grid 画面 -----

local function build_grid_formspec(tabdata)
    local L = packermod.layout
    local theme = packermod.theme
    local packs = get_packs()
    tabdata.packs = packs

    -- レイアウト定数(13×8.5 の page、padding 0.4 → 内側 12.2 × 7.7)
    local cols = 3
    local card_w = 3.8
    local card_h = 4.2
    local thumb_size = 3.2
    local card_pad = 0.2

    local rows = {}
    local i = 1
    while i <= #packs or (#packs == 0 and i == 1) do
        local row = L.HBox{ spacing = 0.3 }
        for _ = 1, cols do
            local pack = packs[i]
            if pack then
                local card = L.VBox{
                    spacing = 0.1, padding = card_pad,
                    bgcolor = theme.colors.bg_panel,
                    w = card_w, h = card_h,
                    L.IconButton{
                        name = pack_button_name(pack.id),
                        texture = resolve_thumbnail(pack),
                        label = "",
                        w = thumb_size, h = thumb_size,
                    },
                    L.Label{
                        text = pack.manifest.name or pack.id,
                        style = "section",
                    },
                    L.Label{
                        text = (pack.manifest.base_game.id or "?") .. " " ..
                               (pack.manifest.base_game.version or "?"),
                        style = "dim",
                    },
                }
                row[#row + 1] = card
            else
                row[#row + 1] = L.Spacer{ w = card_w, h = card_h }
            end
            i = i + 1
        end
        rows[#rows + 1] = row
        if #packs == 0 then break end
    end

    local actions = L.HBox{ spacing = 0.3,
        L.Spacer{ flex = 1 },
        L.LabeledIconButton{
            name = "btn_import",
            texture = packermod.icons.path("download", "md"),
            label = "Import", w = 1.8, h = 1.4,
        },
        L.LabeledIconButton{
            name = "btn_create",
            texture = packermod.icons.path("plus", "md"),
            label = "Create", w = 1.8, h = 1.4,
        },
        L.LabeledIconButton{
            name = "btn_settings",
            texture = packermod.icons.path("sliders", "md"),
            label = "Settings", w = 1.8, h = 1.4,
        },
    }

    local root = L.VBox{
        bgcolor = theme.colors.bg,
        padding = 0.4, spacing = 0.4,
        w = 13.0, h = 8.5,
    }
    -- ヘッダー
    root[#root + 1] = L.Label{ text = "PackerMOD — Pack Library", style = "section" }
    if #packs == 0 then
        root[#root + 1] = L.Label{
            text = "No packs yet. Use Import or Create below to add one.",
            style = "dim",
        }
    end
    for _, r in ipairs(rows) do root[#root + 1] = r end
    root[#root + 1] = L.Spacer{ flex = 1 }
    root[#root + 1] = actions

    return L.build_formspec(root, { version = 6, theme = theme })
end

-- ----- detail 画面 -----

local function build_detail_formspec(tabdata)
    local packs = tabdata.packs or get_packs()
    local pack
    for _, p in ipairs(packs) do
        if p.id == tabdata.selected_pack_id then pack = p; break end
    end
    if not pack then
        -- 選択中 Pack が無効 → grid に戻す
        tabdata.view = "grid"
        return build_grid_formspec(tabdata)
    end

    local subdir_worlds = packermod.launcher.list_worlds(pack)
    local legacy_worlds = packermod.launcher.list_legacy_worlds(pack)
    local worlds = {}
    for _, w in ipairs(subdir_worlds) do worlds[#worlds + 1] = w end
    for _, w in ipairs(legacy_worlds) do worlds[#worlds + 1] = w end
    tabdata.worlds = worlds

    local servers = packermod.launcher.list_servers(pack)
    tabdata.servers = servers

    tabdata.selected_world  = clamp_selection(tabdata.selected_world, #worlds)
    tabdata.selected_server = clamp_selection(tabdata.selected_server, #servers)

    local subtab = tabdata.subtab or "worlds"
    tabdata.subtab = subtab

    local form = tabdata.form_server or {}
    local mods_state = tabdata.mods_state or {}
    local info_state = tabdata.info_state or {}

    local pack_mods = pack.manifest.mods or {}
    tabdata.selected_mod = clamp_selection(tabdata.selected_mod, #pack_mods)

    local search_results = mods_state.results or {}
    tabdata.selected_search = clamp_selection(tabdata.selected_search, #search_results)

    local ctx = {
        pack_name = pack.manifest.name or "",
        pack_version = pack.manifest.version or "",
        pack_base = (pack.manifest.base_game.id or "?") .. "/" ..
                    (pack.manifest.base_game.version or "?"),
        pack_mods_count = #pack_mods,
        pack_description = pack.manifest.description or "",

        variant_worlds = subtab_variant(subtab, "worlds"),
        variant_multi  = subtab_variant(subtab, "multi"),
        variant_mods   = subtab_variant(subtab, "mods"),
        variant_info   = subtab_variant(subtab, "info"),

        show_worlds = (subtab == "worlds"),
        show_multi  = (subtab == "multi"),
        show_mods   = (subtab == "mods"),
        show_info   = (subtab == "info"),

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

-- ----- formspec ディスパッチ -----

local function get_formspec(tabdata)
    tabdata.view = tabdata.view or "grid"
    if tabdata.view == "detail" then
        return build_detail_formspec(tabdata)
    end
    return build_grid_formspec(tabdata)
end

-- ----- launch ヘルパ(symlink trick 経由) -----

local function start_with_link(link_name, gameid)
    local worlds = core.get_worlds() or {}
    for i, w in ipairs(worlds) do
        if w.name == link_name then
            gamedata.selected_world = i
            gamedata.singleplayer = true
            if gameid then core.settings:set("menu_last_game", gameid) end
            core.start()
            return true
        end
    end
    return false
end

local function launch_existing(world)
    local link_name, err = packermod.launcher.prepare_launch(world)
    if not link_name then
        gamedata.errormessage = "Could not prepare launch: " .. tostring(err)
        return
    end
    if not start_with_link(link_name, world.gameid) then
        gamedata.errormessage = "Could not locate launch link: " .. link_name
    end
end

local function launch_new(pack, world_name)
    local ok, info = packermod.launcher.new_world(pack, { world_name = world_name })
    if not ok then
        gamedata.errormessage = info
        return
    end
    -- 作成した世界を symlink 経由で起動
    local world = { path = info.world_path, name = info.world_name, gameid = info.gameid }
    launch_existing(world)
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

-- ----- button handler -----

local function find_pack_by_button(fields, packs)
    for k in pairs(fields) do
        if k:sub(1, #"pack_select_") == "pack_select_" then
            local slug = k:sub(#"pack_select_" + 1)
            for _, p in ipairs(packs or {}) do
                if pack_button_name(p.id) == k then return p end
                if p.id == slug then return p end
            end
        end
    end
    return nil
end

local function button_handler(self, fields)
    local tabdata = self.data
    tabdata.view = tabdata.view or "grid"

    -- ---- グリッド画面 ----
    if tabdata.view == "grid" then
        local picked = find_pack_by_button(fields, tabdata.packs)
        if picked then
            tabdata.view = "detail"
            tabdata.selected_pack_id = picked.id
            tabdata.subtab = "worlds"
            tabdata.selected_world = 1
            return true
        end
        if fields.btn_import then
            packermod.dialogs.dlg_import.show(M._dlg)
            return true
        end
        if fields.btn_create then
            packermod.dialogs.dlg_create.show(M._dlg)
            return true
        end
        if fields.btn_settings then
            packermod.dialogs.dlg_settings.show(M._dlg)
            return true
        end
        return false
    end

    -- ---- 詳細画面 ----

    if fields.btn_back then
        tabdata.view = "grid"
        tabdata.selected_pack_id = nil
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

    local packs = tabdata.packs or get_packs()
    local pack
    for _, p in ipairs(packs) do
        if p.id == tabdata.selected_pack_id then pack = p; break end
    end

    if fields.play_world and pack then
        local world = tabdata.worlds and tabdata.worlds[tabdata.selected_world]
        if world then launch_existing(world) end
        return true
    end

    if fields.new_world and pack then
        if packermod.dialogs and packermod.dialogs.dlg_world_create then
            packermod.dialogs.dlg_world_create.show(M._dlg, pack)
        end
        return true
    end

    if fields.delete_world and pack then
        local world = tabdata.worlds and tabdata.worlds[tabdata.selected_world]
        if world and packermod.dialogs and packermod.dialogs.dlg_world_delete then
            packermod.dialogs.dlg_world_delete.show(M._dlg, pack, world)
        end
        return true
    end

    -- ---- Multiplayer ----

    if fields.serverlist then
        local e = core.explode_textlist_event(fields.serverlist)
        if e.type == "CHG" then tabdata.selected_server = e.index end
        return true
    end

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

    -- ---- Mods ----

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

    -- ---- Info ----

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

    return false
end

function M.show()
    local dlg = dialog_create("packermod_library", get_formspec, button_handler, nil)
    M._dlg = dlg
    -- Dev hook: 直接 detail / subtab を開く
    local initial = core.settings and core.settings:get("packermod_initial_subtab")
    if initial and initial ~= "" then
        dlg.data.subtab = initial
        local packs = get_packs()
        if #packs > 0 then
            dlg.data.view = "detail"
            dlg.data.selected_pack_id = packs[1].id
            dlg.data.packs = packs
        end
    end
    dlg:show()
    ui.set_default("packermod_library")

    local modal = core.settings and core.settings:get("packermod_initial_modal")
    if modal and modal ~= "" and packermod.dialogs then
        local d = packermod.dialogs["dlg_" .. modal]
        if d then d.show(dlg) end
    end
end

function M.dlg()
    return M._dlg
end

M._internal = {
    format_world_label = format_world_label,
    format_server_label = format_server_label,
    format_mod_entry = format_mod_entry,
    format_search_result = format_search_result,
    build_server_from_form = build_server_from_form,
    subtab_variant = subtab_variant,
    clamp_selection = clamp_selection,
    pack_button_name = pack_button_name,
    resolve_thumbnail = resolve_thumbnail,
    SUBTABS = SUBTABS,
    -- 単体テスト用に内部関数も export
    build_grid_formspec = build_grid_formspec,
    build_detail_formspec = build_detail_formspec,
}

return M
