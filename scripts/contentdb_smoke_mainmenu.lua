-- Optional live integration test. Runs only with disposable screenshot data.
local source = assert(core.settings:get("packermod_source_path"))
dofile(source .. "/mainmenu/init.lua")
local client = packermod.client
client.search_async("minetest", "game", function(games, err)
    assert(games, err)
    local game
    for _, candidate in ipairs(games) do
        if candidate.name == "minetest_game" then game = candidate end
    end
    assert(game, "Minetest Game not returned by ContentDB")
    client.releases_async(game.author .. "/" .. game.name, function(releases, why)
        assert(releases, why)
        local release
        for _, candidate in ipairs(releases) do
            if packermod.game_store_mod.compatible(candidate, core.get_version().string) then release = candidate; break end
        end
        assert(release, "No compatible release")
        local base = packermod.game_store_mod.base_game(game, release)
        local data = { pack_name = "ContentDB integration", base_game = base }
        local valid, manifest = packermod.pack_builder.build_manifest(data)
        assert(valid, manifest)
        packermod.game_store.ensure(base, release, function(ok, install_error)
            assert(ok, install_error)
            local target = packermod.user_path .. "/games/" .. packermod.world_builder.gameid_for(base)
            assert(packermod.fs.exists(target .. "/game.conf"))
            assert(packermod.fs.exists(target .. "/mods"))
            local serialized, text = packermod.manifest.dump(manifest)
            assert(serialized, text)
            local saved, saved_error = packermod.importer.import_from_yaml_text(text)
            assert(saved, saved_error)
            ui.update()
            core.log("action", "PackerMOD: live ContentDB verified")
        end)
    end)
end)
