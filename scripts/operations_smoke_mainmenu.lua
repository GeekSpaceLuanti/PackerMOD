-- Disposable real-engine matrix: 3 game layouts x 4 MOD sources x 2 names,
-- with create/play, reopen, MOD removal and play again for every world.
local source = assert(core.settings:get("packermod_source_path"))
core.settings:remove("packermod_expected_pack_count")
dofile(source .. "/mainmenu/init.lua")
local pm, root = packermod, packermod.user_path
assert(not gamedata.errormessage, gamedata.errormessage)
local function read(path) return pm.fs.read_file(path) end
local function write(path, text) assert(core.safe_file_write(path, text), path) end
local function mkdir(path) assert(core.create_dir(path), path) end
local function probe(path, text)
    mkdir(path)
    write(path .. "/mod.conf", "name = matrixmod\n")
    write(path .. "/init.lua", text or "core.matrix_mod_loaded = true\n")
end
local layouts = {
    { id = "matrix", installed_id = "matrix", version = "installed" },
    { id = "plain", installed_id = "plain", version = "installed" },
    { id = "downloaded", package = "Fixture/downloaded", release = 42, version = "1" },
}
local modes = { "none", "bundle", "contentdb", "url" }
local game_paths = { root .. "/games/matrix_game", root .. "/games/plain", root .. "/games/pm_downloaded_r42" }
local game_probe = [[
    core.register_on_mods_loaded(function()
        local path = core.get_worldpath()
        local expected = Settings(path .. "/world.mt"):get_bool("matrix_expect_mod", false)
        assert((core.matrix_mod_loaded == true) == expected, "MOD missing or stale")
        local stage = Settings(path .. "/world.mt"):get("matrix_stage")
        assert(core.safe_file_write(path .. "/probe-" .. stage, "yes"))
        core.after(0.1, function() core.request_shutdown("operation matrix", false, 0) end)
    end)
]]
if not read(root .. "/matrix-ready") then
    for _, path in ipairs(game_paths) do
        mkdir(path); mkdir(path .. "/mods"); mkdir(path .. "/mods/matrixprobe")
        write(path .. "/game.conf", "title = Operation matrix fixture\n")
        write(path .. "/mods/matrixprobe/mod.conf", "name = matrixprobe\n")
        write(path .. "/mods/matrixprobe/init.lua", game_probe)
    end
    -- One nested ZIP and one flat ZIP are built by the screenshot runner.
    write(root .. "/matrix-ready", "yes")
end
local count = 0
for game_index, base in ipairs(layouts) do
    for _, mode in ipairs(modes) do
        for _, name in ipairs({ "World", "日本語ワールド" }) do
            count = count + 1
            local id = "matrix_" .. count
            local pack_path = root .. "/PackerMOD/packs/" .. id
            local manifest_path = pack_path .. "/manifest.yaml"
            local world_path = pack_path .. "/worlds/" .. name
            if not read(manifest_path) then
                local m = { schema_version = 1, id = id, name = "Matrix " .. count, version = "1",
                    base_game = base, mods = {}, settings = { mg_name = "singlenode" } }
                if mode == "bundle" then
                    m.mods = { { name = "matrixmod", source = "bundle", path = "bundled_mods/matrixmod" } }
                elseif mode == "contentdb" then
                    m.mods = { { name = "matrixmod", source = mode, package = "Fixture/matrixmod", release = 1 } }
                elseif mode == "url" then
                    m.mods = { { name = "matrixmod", source = mode, url = "https://fixture.invalid/matrixmod.zip" } }
                end
                local ok, text = pm.manifest.dump(m); assert(ok, text)
                assert(pm.importer.import_from_yaml_text(text))
                assert(not pm.importer.import_from_yaml_text(text), "Duplicate Pack accepted")
                if mode == "bundle" then
                    mkdir(pack_path .. "/bundled_mods"); probe(pack_path .. "/bundled_mods/matrixmod")
                elseif mode ~= "none" then
                    local zip = pm.installer.cache_path_for(m.mods[1])
                    write(zip, assert(read(root .. (mode == "contentdb" and "/nested.zip" or "/flat.zip"))))
                end
            end
            local valid, manifest = pm.manifest.parse(assert(read(manifest_path))); assert(valid, manifest)
            local pack = { id = id, path = pack_path, manifest = manifest }
            if not read(world_path .. "/world.mt") then
                local ok, result = pm.launcher.new_world(pack, { world_name = name }); assert(ok, result)
                assert(not pm.launcher.new_world(pack, { world_name = name }), "Duplicate world accepted")
            end
            local world = { path = world_path, name = name, gameid = pm.world_builder.gameid_for(base) }
            local stage
            if not read(world_path .. "/probe-new") then stage = "new"
            elseif not read(world_path .. "/probe-reopen") then stage = "reopen"
            elseif not read(world_path .. "/probe-edited") then
                stage = "edited"
                if #(manifest.mods or {}) > 0 then assert(pm.pack_editor.remove_mod(pack, 1)) end
            end
            if stage then
                local config = Settings(world_path .. "/world.mt")
                config:set("matrix_stage", stage)
                config:set_bool("matrix_expect_mod", mode ~= "none" and stage ~= "edited")
                assert(config:write() ~= false)
                local link, err = pm.launcher.prepare_launch(world, pack); assert(link, err)
                assert(pm.launcher.begin_world_settings(world))
                local found
                for i, w in ipairs(core.get_worlds()) do
                    if pm.pack_launcher_mod.is_launch_link(w, link) then found = i end
                end
                assert(found, "Prepared world not found")
                gamedata.selected_world, gamedata.singleplayer = found, true
                core.log("action", ("PackerMOD matrix: case %d/24 game=%d source=%s name=%s stage=%s"):format(
                    count, game_index, mode, name, stage))
                core.start()
                return
            end
            assert(read(world_path .. "/map.sqlite"), "World map not preserved")
        end
    end
end
-- Also exercise persistence and deletion against real disposable files.
assert(pm.importer.import_from_path(root .. "/import.zip"))
assert(not pm.importer.import_from_path(root .. "/import.zip"), "Duplicate ZIP import accepted")
local imported = assert(pm.pack_manager.get_pack(root, "zip_import", pm.manifest))
assert(read(imported.path .. "/thumbnail.png") == "fixture")
assert(pm.launcher.new_world(imported, { world_name = "Imported" }))
assert(pm.launcher.delete_world(imported, { name = "Imported" }))
assert(pm.pack_manager.delete_pack(root, "zip_import"))
local list = pm.pack_manager.list_packs(root, pm.manifest)
assert(#list == 27, "Pack count changed")
local pack
for _, p in ipairs(list) do if p.id == "matrix_1" then pack = p end end
assert(pack)
assert(pm.pack_editor.update_meta(pack, { name = "更新したパック", description = "保存確認", version = "2" }))
assert(pm.server_list.add(pack.path, { name = "Local", address = "127.0.0.1", port = 30000 }))
assert(#pm.server_list.load(pack.path) == 1)
assert(pm.server_list.remove(pack.path, 1))
assert(#pm.server_list.load(pack.path) == 0)
assert(pm.launcher.delete_world(pack, { name = "World" }))
assert(not read(pack.path .. "/worlds/World/world.mt"))
assert(not read(root .. "/PackerMOD/launch-world.json"))
assert(not read(root .. "/PackerMOD/world-session.json"))
core.settings:set("packermod_expected_pack_count", "27")
pm.library.show(); ui.update()
core.log("action", "PackerMOD: operation matrix verified (24 cases, 72 launches)")
