-- Two real game sessions: world A's rules must never leak into world B or the
-- next mainmenu. All files belong to the disposable screenshot profile.
local source = assert(core.settings:get("packermod_source_path"))
local config = assert(core.settings:get("packermod_smoke_config"))
dofile(source .. "/mainmenu/init.lua")
gamedata.errormessage = nil
local root = packermod.user_path
local schema = packermod.get_engine_schema()
local a = { path = root .. "/PackerMOD/packs/sample_1/worlds/demo", name = "demo", display_name = "検証ワールド A" }
local b = { path = root .. "/PackerMOD/packs/sample_1/worlds/other", name = "other", display_name = "検証ワールド B" }
local function read(path) local f = io.open(path, "rb"); if not f then return end; local s=f:read("*a"); f:close(); return s end
local function write(path,text) assert(core.safe_file_write(path,text)) end
local baseline_path = root .. "/baseline.json"
local baseline = read(baseline_path)
if not baseline then
    baseline = core.write_json(Settings(config):to_table())
    write(baseline_path, baseline)
end
local original = core.parse_json(baseline)
for _, name in ipairs({ "creative_mode", "enable_damage", "time_speed", "movement_gravity" }) do
    assert(Settings(config):get(name) == original[name], "Global override leaked: " .. name)
end
for _, entry in ipairs(schema.entries) do
    if packermod.settings_catalog.is_world(entry) then
        assert(Settings(config):get(entry.name) == original[entry.name], "Global setting not recovered: " .. entry.name)
    end
end
local wa = packermod.world_settings_mod.open(a, schema)
if not read(a.path .. "/probe-ok") then
    core.create_dir(b.path)
    write(b.path .. "/world.mt", "gameid = packerbase_0_91\nworld_name = Other\n")
    local wb = packermod.world_settings_mod.open(b, schema)
    assert(wa.apply(wa.by_name.creative_mode, "true"))
    assert(wa.apply(wa.by_name.time_speed, "120"))
    assert(wa.apply(wa.by_name.movement_gravity, "4.2"))
    assert(wb.read(wb.by_name.creative_mode) == "false")
    assert(wb.read(wb.by_name.time_speed) == "72")
    assert(wb.read(wb.by_name.movement_gravity) == "9.81")
    assert(wa.apply(wa.by_name.mg_name, "singlenode"))
    assert(wa.apply(wa.by_name.fixed_map_seed, "12345"))
    assert(wa.apply(wa.by_name.water_level, "7"))
    assert(wb.apply(wb.by_name.mg_name, "singlenode"))
    assert(wb.apply(wb.by_name.fixed_map_seed, "54321"))
    assert(wb.apply(wb.by_name.water_level, "1"))
    for _, name in ipairs({ "creative_mode", "time_speed", "movement_gravity", "mg_name", "fixed_map_seed", "water_level" }) do
        assert(Settings(config):get(name) == original[name], "World editor wrote a global setting")
    end
    local mod = root .. "/games/packerbase_0_91/mods/worldprobe"
    core.create_dir(mod)
    write(mod .. "/mod.conf", "name = worldprobe\n")
    write(mod .. "/init.lua", [[
        local path = core.get_worldpath()
        local a = core.settings:get("time_speed") == "120"
        assert(core.settings:get("time_speed") == (a and "120" or "72"), "Time leaked across worlds")
        assert(math.abs(tonumber(core.settings:get("movement_gravity")) - (a and 4.2 or 9.81)) < 0.0001, "Gravity leaked")
        assert(core.is_creative_enabled("") == a, "Creative cache not initialized from world settings")
        assert(core.get_mapgen_setting("water_level") == (a and "7" or "1"), "Mapgen settings not loaded")
        assert(core.get_mapgen_setting("seed") == (a and "12345" or "54321"), "Seed not loaded")
        core.register_on_mods_loaded(function()
            core.safe_file_write(path .. "/probe-ok", "yes")
            core.after(0.5, function() core.request_shutdown("world isolation test", false, 0) end)
        end)
    ]])
end
if read(a.path .. "/probe-ok") then
    local before = read(a.path .. "/map_meta.txt")
    wa = packermod.world_settings_mod.open(a, schema)
    assert(wa.initialized and wa.by_name.mg_name.readonly)
    assert(not wa.apply(wa.by_name.mg_name, "v7"))
    assert(read(a.path .. "/map_meta.txt") == before, "Initialized terrain modified")
end
local world
if not read(a.path .. "/probe-ok") then world = a
elseif not read(b.path .. "/probe-ok") then world = b end
if world then
    local link, err = packermod.launcher.prepare_launch(world)
    assert(link, err)
    local found
    for i,w in ipairs(core.get_worlds()) do if packermod.pack_launcher_mod.is_launch_link(w, link) then found=i end end
    assert(found, "Launch world missing")
    assert(packermod.launcher.begin_world_settings(world))
    -- Simulate the engine saving transient values, then verify recovery on return.
    assert(core.settings:write() ~= false)
    gamedata.selected_world, gamedata.singleplayer = found, true
    core.start()
else
    assert(not read(root .. "/PackerMOD/world-session.json"), "Session journal not cleared")
    local dlg = packermod.dialogs.dlg_settings.show_world(packermod.library.dlg(), a)
    assert(dlg.data.backend.by_name.time_speed)
    assert(not packermod.engine_settings.by_name.time_speed, "World settings visible globally")
    ui.update()
    core.log("action", "PackerMOD: world isolation verified")
end
