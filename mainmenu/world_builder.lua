local M = {}

local function fmt_setting_value(v)
    if v == nil then return "" end
    if v == true then return "true" end
    if v == false then return "false" end
    return tostring(v)
end

function M.gameid_for(base_game)
    local id, ver = base_game.id, base_game.version
    return id .. "_" .. (ver:gsub("[^%w]", "_"))
end

function M.world_name(pack_id, timestamp)
    return pack_id .. "__" .. tostring(timestamp)
end

function M.build_world_mt(manifest)
    local lines = {}
    table.insert(lines, "gameid = " .. M.gameid_for(manifest.base_game))
    table.insert(lines, "backend = sqlite3")
    table.insert(lines, "player_backend = sqlite3")
    table.insert(lines, "auth_backend = sqlite3")
    table.insert(lines, "world_name = " .. manifest.name)

    if manifest.mods then
        local names = {}
        for _, mod in ipairs(manifest.mods) do
            table.insert(names, mod.name)
        end
        table.sort(names)
        for _, name in ipairs(names) do
            table.insert(lines, "load_mod_" .. name .. " = true")
        end
    end

    if manifest.settings then
        local keys = {}
        for k in pairs(manifest.settings) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            table.insert(lines, k .. " = " .. fmt_setting_value(manifest.settings[k]))
        end
    end

    return table.concat(lines, "\n") .. "\n"
end

function M._default_fs()
    return {
        mkdir = function(path)
            if rawget(_G, "core") and core.create_dir then
                core.create_dir(path)
                return true
            end
            os.execute('mkdir -p "' .. path .. '"')
            return true
        end,
        write_file = function(path, content)
            local f, err = io.open(path, "w")
            if not f then return false, err end
            f:write(content)
            f:close()
            return true
        end,
        exists = function(path)
            local f = io.open(path, "r")
            if f then f:close(); return true end
            return (rawget(_G, "core") and core.get_dir_list and core.get_dir_list(path, nil)) ~= nil
        end,
        copy_dir = function(src, dst, keep)
            if rawget(_G, "core") and core.copy_dir then
                return core.copy_dir(src, dst, keep)
            end
            os.execute(('cp -r "%s" "%s"'):format(src, dst))
            return true
        end,
        extract_zip = function(zip, dst)
            if rawget(_G, "core") and core.extract_zip then
                return core.extract_zip(zip, dst)
            end
            return false
        end,
    }
end

function M.create_world(manifest, user_data_path, opts)
    opts = opts or {}
    local fs = opts.fs or M._default_fs()
    local timestamp = opts.timestamp or os.time()
    local world = M.world_name(manifest.id, timestamp)
    local world_path = user_data_path .. "/worlds/" .. world

    local gameid = M.gameid_for(manifest.base_game)
    local game_path = user_data_path .. "/games/" .. gameid
    if not fs.exists(game_path) then
        return false, ("base game not installed: %s (expected at %s)"):format(gameid, game_path)
    end

    fs.mkdir(user_data_path .. "/worlds")
    local ok, err = fs.mkdir(world_path)
    if not ok then return false, "mkdir failed: " .. tostring(err) end

    local ok2, err2 = fs.write_file(world_path .. "/world.mt", M.build_world_mt(manifest))
    if not ok2 then return false, "write world.mt failed: " .. tostring(err2) end

    return true, { world_path = world_path, world_name = world, gameid = gameid }
end

return M
