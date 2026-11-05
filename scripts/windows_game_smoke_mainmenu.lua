-- Run against the deployed menu and a real installed game, with all
-- Pack/world changes confined to an engine-approved temporary directory.
local source = assert(core.settings:get("packermod_source_path"))
local root = core.get_user_path()
local game_id = core.settings:get("packermod_test_game") or "minetest"
assert(core.settings:get_bool("packermod_disposable_test"), "Disposable profile required")
dofile(source .. "/mainmenu/init.lua")
local pm = packermod
assert(not gamedata.errormessage, gamedata.errormessage)
local pack = pm.pack_manager.list_packs(root, pm.manifest)[1]
if not pack then
    local starter = core.settings:get("packermod_test_starter_zip")
    if starter and starter ~= "" then
        local imported, err = pm.importer.import_from_zip(starter)
        assert(imported, err)
    else
        local dlg = pm.dialogs.dlg_create.show(pm.library.dlg())
        local selected
        for i, game in ipairs(dlg.data.games) do if game.installed_id == game_id then selected = i end end
        assert(selected, "Installed game not found: " .. game_id)
        local handle = pm.dialogs.dlg_create._internal.handler
        assert(handle(dlg, { pack_name = game_id .. " 動作検証", next_step = true }))
        assert(handle(dlg, { game_list = "CHG:" .. selected }))
        assert(handle(dlg, { next_step = true }))
        assert(handle(dlg, { export = true }))
        assert(dlg.data.closed, dlg.data.status)
    end
    pack = assert(pm.pack_manager.list_packs(root, pm.manifest)[1])
    local mod_path = pack.path .. "/bundled_mods/probe"
    assert(core.create_dir(pack.path .. "/bundled_mods")); assert(core.create_dir(mod_path))
    assert(core.safe_file_write(mod_path .. "/mod.conf", "name = windowsprobe\noptional_depends = packer_core\n"))
    assert(core.safe_file_write(mod_path .. "/init.lua", [[
        local storage = core.get_mod_storage()
        local api_ready = false
        if core.get_modpath("packer_core") then
            local state = packer_core.open_data("windowsprobe", 1, {
                [1] = function(data) data.starts = 0; return data end,
            })
            packer_core.on("ready", function()
                local data = state.read()
                data.starts = data.starts + 1
                state.write(data)
                local expected = tonumber(Settings(core.get_worldpath() .. "/world.mt"):get("windows_pass"))
                assert(data.starts == expected, "Base API data did not persist across launches")
                api_ready = true
            end)
        end
        core.register_on_joinplayer(function(player)
            if not core.get_modpath("packer_core") then return end
            core.after(0, function()
                assert(player:get_inventory():get_size("main") == 36, "Expected 36 inventory slots")
                assert(player:hud_get_hotbar_itemcount() == 9, "Expected 9 hotbar slots")
                local path = core.get_worldpath()
                local pass = Settings(path .. "/world.mt"):get("windows_pass")
                assert(core.safe_file_write(path .. "/windows-inventory-" .. pass, "yes"))
                core.after(0.5, function() core.request_shutdown("Windows smoke test", false, 0) end)
            end)
        end)
        core.register_on_mods_loaded(function()
            assert(core.registered_nodes["default:stone"], "Minetest Game not loaded")
            local path = core.get_worldpath()
            if core.get_modpath("packer_core") then
                assert(type(packer_core) == "table", "PackerMOD Base API missing")
                assert(packer_core.api_version == 1, "Unsupported PackerMOD Base API")
                assert(api_ready, "Base ready event was not delivered")
                local launches = storage:get_int("launches") + 1
                local expected = tonumber(Settings(path .. "/world.mt"):get("windows_pass"))
                assert(launches == expected, "MOD storage did not persist across launches")
                storage:set_int("launches", launches)
            end
            local pass = Settings(path .. "/world.mt"):get("windows_pass")
            assert(core.safe_file_write(path .. "/windows-ok-" .. pass, "yes"))
            if not core.get_modpath("packer_core") then
                core.after(0.5, function() core.request_shutdown("Windows smoke test", false, 0) end)
            end
        end)
    ]]))
    assert(pm.pack_editor.add_mod(pack, { name = "windowsprobe", source = "bundle", path = "bundled_mods/probe" }))
    local ok, err = pm.launcher.new_world(pack, { world_name = "日本語ワールド" }); assert(ok, err)
end
local world = assert(pm.launcher.list_worlds(pack)[1])
local pass = not pm.fs.exists(world.path .. "/windows-ok-1") and "1"
    or (not pm.fs.exists(world.path .. "/windows-ok-2") and "2" or nil)
if pass then
    local config = Settings(world.path .. "/world.mt")
    config:set("windows_pass", pass); assert(config:write() ~= false)
    local link, err = pm.launcher.prepare_launch(world, pack); assert(link, err)
    assert(pm.launcher.begin_world_settings(world))
    local found
    for i, w in ipairs(core.get_worlds()) do if pm.pack_launcher_mod.is_launch_link(w, link) then found = i end end
    assert(found, "Windows launch directory missing")
    gamedata.selected_world, gamedata.singleplayer = found, true
    core.start()
else
    if game_id == "packerbase" then
        for i = 1, 2 do
            assert(pm.fs.exists(world.path .. "/windows-inventory-" .. i), "Base inventory was not verified")
        end
    end
    assert(not pm.fs.exists(root .. "/PackerMOD/launch-world.json"))
    assert(not pm.fs.exists(root .. "/PackerMOD/world-session.json"))
    pm.library.show(); ui.update()
    core.log("action", "PackerMOD: Windows game " .. game_id .. " create and two launches verified")
    core.close()
end
