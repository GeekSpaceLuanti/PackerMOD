-- Live UI integration: real search -> result selection -> release dropdown.
local source = assert(core.settings:get("packermod_source_path"))
dofile(source .. "/mainmenu/init.lua")
local create = packermod.dialogs.dlg_create
local dlg = create.show(packermod.library.dlg())
local data = dlg.data
local search = packermod.client.search_async
local releases = packermod.client.releases_async
packermod.client.releases_async = function(id, callback)
    return releases(id, function(items, err)
        assert(items, err)
        callback(items, err)
        assert(#data.releases > 0, "No releases displayed")
        assert(data.base_game and data.base_game.release, "No release selected")
        ui.update()
        core.log("action", "PackerMOD: ContentDB catalog ready")
    end)
end
packermod.client.search_async = function(query, kind, callback)
    return search(query, kind, function(items, err)
        assert(items, err)
        callback(items, err)
        local index
        for i, game in ipairs(data.games) do if game.name == "minetest_game" then index = i end end
        assert(index, "Game not found in results")
        create._internal.handler(dlg, { game_list = "CHG:" .. index })
        ui.update()
    end)
end
create._internal.handler(dlg, { pack_name = "ContentDBテスト", next_step = true })
create._internal.handler(dlg, { game_query = "minetest", game_search = true })
ui.update()
