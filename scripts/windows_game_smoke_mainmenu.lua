-- Run against the deployed menu and real installed Minetest Game, with all
-- Pack/world changes confined to an engine-approved temporary directory.
local source = assert(core.settings:get("packermod_source_path"))
local root = core.get_user_path()
assert(core.settings:get_bool("packermod_disposable_test"), "Disposable profile required")
dofile(source .. "/mainmenu/init.lua")
local pm = packermod
assert(not gamedata.errormessage, gamedata.errormessage)
local pack = pm.pack_manager.list_packs(root, pm.manifest)[1]
if not pack then
    local dlg = pm.dialogs.dlg_create.show(pm.library.dlg())
    local selected
    for i, game in ipairs(dlg.data.games) do if game.installed_id == "minetest" then selected = i end end
    assert(selected, "Real installed Minetest Game not found")
    local handle = pm.dialogs.dlg_create._internal.handler
    assert(handle(dlg, { pack_name = "Minetest Game 動作検証", next_step = true }))
    assert(handle(dlg, { game_list = "CHG:" .. selected }))
    assert(handle(dlg, { next_step = true }))
    assert(handle(dlg, { export = true }))
    assert(dlg.data.closed, dlg.data.status)
    pack = assert(pm.pack_manager.list_packs(root, pm.manifest)[1])
    local mod_path = pack.path .. "/bundled_mods/probe"
    assert(core.create_dir(pack.path .. "/bundled_mods")); assert(core.create_dir(mod_path))
    assert(core.safe_file_write(mod_path .. "/mod.conf", "name = windowsprobe\n"))
    assert(core.safe_file_write(mod_path .. "/init.lua", [[
        core.register_on_mods_loaded(function()
            assert(core.registered_nodes["default:stone"], "Minetest Game not loaded")
            local path = core.get_worldpath()
            local pass = Settings(path .. "/world.mt"):get("windows_pass")
            assert(core.safe_file_write(path .. "/windows-ok-" .. pass, "yes"))
            core.after(0.5, function() core.request_shutdown("Windows smoke test", false, 0) end)
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
    assert(not pm.fs.exists(root .. "/PackerMOD/launch-world.json"))
    assert(not pm.fs.exists(root .. "/PackerMOD/world-session.json"))
    pm.library.show(); ui.update()
    core.log("action", "PackerMOD: Windows Minetest Game create and two launches verified")
    core.close()
end
