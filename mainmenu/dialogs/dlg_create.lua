-- Three measured steps: details, ContentDB game/release, optional MODs.
local M = {}
local function T(text) return packermod.i18n.t(text) end
local function refresh() if ui and ui.update then ui.update() end end
local function package_id(game) return game.author .. "/" .. game.name end

local function request(data, start, complete)
    data.generation = (data.generation or 0) + 1
    local generation = data.generation
    data.busy = true
    local queued = start(function(result, err)
        if data.closed or generation ~= data.generation then return end
        data.busy = false
        complete(result, err)
        refresh()
    end)
    if queued == false then data.busy = false; data.status = "Search failed: worker unavailable" end
end

local function choose_release(data, index)
    data.release_selected = index
    local game = data.games[data.game_selected or 0]
    local release = data.releases[index]
    data.base_game = game and release and packermod.game_store_mod.base_game(game, release) or nil
end

local function choose_game(data, index)
    data.game_selected, data.release_selected, data.base_game = index, 1, nil
    data.releases = {}
    local game = data.games[index]
    if not game then return end
    if game.installed_id then
        data.releases = { { name = "Installed", id = 0 } }
        choose_release(data, 1)
        data.status = ""
        return
    end
    data.status = "Loading releases..."
    request(data, function(callback) return packermod.client.releases_async(package_id(game), callback) end,
        function(releases, err)
            if not releases then data.status = "Search failed: " .. tostring(err); return end
            for _, release in ipairs(releases) do
                if packermod.game_store_mod.compatible(release, core.get_version().string) then
                    data.releases[#data.releases + 1] = release
                end
            end
            choose_release(data, 1)
            data.status = #data.releases == 0 and "No compatible releases." or ""
        end)
end

local function get_formspec(data)
    data.mods, data.search_results = data.mods or {}, data.search_results or {}
    data.games, data.releases = data.games or {}, data.releases or {}
    local step = data.step or "details"
    local titles = { details = "1. Pack details", game = "2. Base game", mods = "3. Choose MODs" }
    local helps = { details = "Give your pack a name. Its ID and revision are assigned automatically.",
        game = "Choose a game and a compatible release.",
        mods = "Add MODs now, or create an empty pack and add them later." }
    local game_items, version_items = {}, {}
    for _, game in ipairs(data.games) do
        game_items[#game_items + 1] = (game.title or game.name) ..
            (game.installed_id and (" (" .. T("Installed") .. ")") or (" / " .. game.author))
    end
    for _, release in ipairs(data.releases) do
        version_items[#version_items + 1] = T(tostring(release.name or release.title or release.id))
    end
    if #version_items == 0 then version_items[1] = T("Choose a game to see its releases.") end
    local selected_game = data.games[data.game_selected or 0]
    local fs = packermod.pmui.build_formspec {
        renderer = "modern", state = data,
        html_path = packermod.mainmenu_path .. "ui" .. DIR_DELIM .. "modal_create.html.yml",
        css_path = packermod.mainmenu_path .. "ui" .. DIR_DELIM .. "themes" .. DIR_DELIM .. "synthwave.css.yml",
        ctx = {
            show_details = step == "details", show_game = step == "game", show_mods = step == "mods",
            has_previous = step ~= "details", has_next = step ~= "mods",
            step_title = T(titles[step]), step_help = T(helps[step]),
            next_label = T(step == "details" and "Next: Game" or "Next: MODs"),
            pack_name = data.pack_name or "", pack_author = data.pack_author or "",
            pack_description = data.pack_description or "", game_query = data.game_query or "",
            game_items = game_items, game_selected = data.game_selected or 0,
            version_items = version_items, release_selected = data.release_selected or 1,
            selected_game_title = selected_game and (selected_game.title or selected_game.name) or T("Choose a base game first."),
            search_query = data.search_query or "", search_results = data.search_results,
            search_selected = data.search_selected or 0, mods = data.mods, mod_selected = data.mod_selected or 0,
            status = data.status or "",
            format_search_result = function(r) return (r.title or r.name) .. " / " .. r.author end,
            format_mod_entry = function(m) return m.name end,
        }, page_w = 30, page_h = 16, texture_dir = packermod.textures_dir,
    }
    return fs
end

local function search_games(data)
    data.status = "Loading games..."
    request(data, function(cb) return packermod.client.search_async(data.game_query or "", "game", cb) end,
        function(games, err)
            if not games then data.status = "Search failed: " .. tostring(err); return end
            data.games, data.releases, data.base_game, data.game_selected = games, {}, nil, 0
            data.status = #games == 0 and "No games found." or ""
        end)
end

local function add_mod(data)
    local result = data.search_results[data.search_selected or 0]
    if not result then data.status = "Select a search result first."; return end
    data.status = "Loading releases..."
    request(data, function(cb) return packermod.client.releases_async(package_id(result), cb) end,
        function(releases, err)
            if not releases then data.status = "Search failed: " .. tostring(err); return end
            local selected
            for _, release in ipairs(releases) do
                if packermod.game_store_mod.compatible(release, core.get_version().string) then selected = release; break end
            end
            if not selected then data.status = "No compatible releases."; return end
            local mod = packermod.pack_builder.contentdb_result_to_mod(result, selected.id)
            local ok, why = packermod.pack_builder.add_mod(data, mod)
            data.status = ok and ("Added " .. mod.name) or ("Add failed: " .. tostring(why))
        end)
end

local function save(self)
    local data = self.data
    local valid, manifest = packermod.pack_builder.build_manifest(data)
    if not valid then data.status = "Save failed: " .. tostring(manifest); return end
    local serialized, dumped = packermod.manifest.dump(manifest)
    if not serialized then data.status = "Save failed: " .. tostring(dumped); return end
    local release = data.releases[data.release_selected or 0]
    if not release then data.status = "Choose a base game first."; return end
    data.status, data.busy = "Installing base game...", true
    local queued = packermod.game_store.ensure(manifest.base_game, release, function(ok, err)
        if data.closed then return end
        data.busy = false
        if not ok then data.status = "Save failed: " .. tostring(err); refresh(); return end
        local written, why = packermod.importer.import_from_yaml_text(dumped)
        if written then data.closed = true; self:delete()
        else data.status = "Save failed: " .. tostring(why) end
        refresh()
    end)
    if queued == false then data.busy = false; data.status = "Save failed: worker unavailable" end
end

local function handler(self, fields)
    if packermod.pmui and packermod.pmui.handle_fields and packermod.pmui.handle_fields(self.data, fields) then return false end
    local data = self.data
    if fields.dlg_close or fields.quit then data.closed = true; self:delete(); return true end
    for _, key in ipairs({ "pack_name", "pack_author", "pack_description", "game_query", "search_query" }) do
        if fields[key] ~= nil then data[key] = fields[key] end
    end
    if data.busy then return true end
    if fields.next_step then
        if not data.pack_name or data.pack_name:match("^%s*$") then data.status = "Enter a pack name."
        elseif data.step == "details" then data.step, data.status = "game", ""
        elseif not data.base_game then data.status = "Choose a base game first."
        else data.step, data.status = "mods", "" end
        return true
    end
    if fields.previous_step then data.step, data.status = data.step == "mods" and "game" or "details", ""; return true end
    if fields.game_search then search_games(data); return true end
    if fields.game_list then
        local event = core.explode_textlist_event(fields.game_list)
        if event.type == "CHG" or event.type == "DCL" then choose_game(data, event.index) end
        return true
    end
    if fields.game_release then choose_release(data, tonumber(fields.game_release) or 1); return true end
    for field, key in pairs({ search_results = "search_selected", mod_list = "mod_selected" }) do
        if fields[field] then
            local event = core.explode_textlist_event(fields[field])
            if event.type == "CHG" or event.type == "DCL" then data[key] = event.index end
        end
    end
    if fields.search then
        data.status = "Loading games..."
        request(data, function(cb) return packermod.client.search_async(data.search_query or "", "mod", cb) end,
            function(results, err)
                if not results then data.status = "Search failed: " .. tostring(err); return end
                data.search_results, data.search_selected, data.status = results, 0, ""
            end)
        return true
    end
    if fields.add_search then add_mod(data); return true end
    if fields.remove_mod then
        data.status = packermod.pack_builder.remove_mod(data, data.mod_selected or 0) and "Removed." or "Select a mod to remove."
        return true
    end
    if fields.export then save(self); return true end
    return false
end

function M.show(parent)
    local dlg = dialog_create("packermod_dlg_create", get_formspec, handler, packermod.ui_window_event)
    local data = dlg.data
    data.step = core.settings:get("packermod_initial_create_step") or "details"
    data.pack_id, data.pack_version = packermod.pack_builder.uuid(), "1.0.0"
    data.games, data.releases, data.mods, data.search_results = {}, {}, {}, {}
    for _, game in ipairs(core.get_games() or {}) do
        data.games[#data.games + 1] = { name = game.id, title = game.title or game.name,
            installed_id = game.id }
    end
    if #data.games > 0 then choose_game(data, 1) end
    if parent then dlg:set_parent(parent); parent:hide() end
    dlg:show()
    return dlg
end
M._internal = { handler = handler, get_formspec = get_formspec, choose_game = choose_game }
return M
