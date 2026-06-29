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

-- ユーザー入力をディレクトリ名として安全な文字列に正規化する。
-- 戻り値: 1文字以上の sanitized 文字列、または nil(空 / 不正)
function M.sanitize_world_name(name)
    if type(name) ~= "string" then return nil end
    -- ASCII の英数字・アンダースコア・ハイフン以外を全部 _ に
    local s = name:gsub("[^%w_%-]", "_")
    -- 連続 _ を 1個に潰す
    s = s:gsub("_+", "_")
    -- 先頭末尾の _- を削る
    s = s:gsub("^[_%-]+", ""):gsub("[_%-]+$", "")
    if s == "" then return nil end
    return s
end

function M.pack_worlds_dir(pack_id, user_data_path)
    return user_data_path .. "/PackerMOD/packs/" .. pack_id .. "/worlds"
end

function M.build_world_mt(manifest, opts)
    opts = opts or {}
    local lines = {}
    table.insert(lines, "gameid = " .. M.gameid_for(manifest.base_game))
    table.insert(lines, "backend = sqlite3")
    table.insert(lines, "player_backend = sqlite3")
    table.insert(lines, "auth_backend = sqlite3")
    table.insert(lines, "world_name = " .. (opts.world_name or manifest.name))
    -- PackerMOD 専用フィールド: Pack 一覧 → World 一覧フィルタに使う
    table.insert(lines, "packermod_pack_id = " .. manifest.id)

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
        read_file = function(path)
            local f = io.open(path, "rb")
            if not f then return nil end
            local s = f:read("*a")
            f:close()
            return s
        end,
        delete_dir = function(path)
            if rawget(_G, "core") and core.delete_dir then
                return core.delete_dir(path)
            end
            os.execute(('rm -rf "%s"'):format(path))
            return true
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

-- 物理配置: <user>/PackerMOD/packs/<pack_id>/worlds/<sanitized_world_name>/
-- opts.world_name はユーザーが入力した raw 表示名。sanitize してディレクトリ名に使い、
-- world.mt の `world_name` には raw 入力をそのまま書き込む(display 用)。
function M.create_world(manifest, user_data_path, opts)
    opts = opts or {}
    local fs = opts.fs or M._default_fs()

    local raw = opts.world_name
    local sanitized = M.sanitize_world_name(raw)
    if not sanitized then
        return false, "invalid world name: please enter at least one alphanumeric character"
    end

    local pack_id = manifest.id
    local pack_worlds = M.pack_worlds_dir(pack_id, user_data_path)
    local world_path = pack_worlds .. "/" .. sanitized

    local gameid = M.gameid_for(manifest.base_game)
    local game_path = user_data_path .. "/games/" .. gameid
    if not fs.exists(game_path) then
        return false, ("base game not installed: %s (expected at %s)"):format(gameid, game_path)
    end

    if fs.exists(world_path) then
        return false, ("world already exists in pack %s: %s"):format(pack_id, sanitized)
    end

    -- 階層を上から順に作る(Luanti の sandbox 対策。安全な親→子の順)
    fs.mkdir(user_data_path .. "/PackerMOD")
    fs.mkdir(user_data_path .. "/PackerMOD/packs")
    fs.mkdir(user_data_path .. "/PackerMOD/packs/" .. pack_id)
    fs.mkdir(pack_worlds)
    local ok, err = fs.mkdir(world_path)
    if not ok then return false, "mkdir failed: " .. tostring(err) end

    -- world.mt の world_name は raw 入力(display)。サニタイズ済みはディレクトリ名のみで使う。
    local mt_text = M.build_world_mt(manifest, { world_name = raw })
    local ok2, err2 = fs.write_file(world_path .. "/world.mt", mt_text)
    if not ok2 then return false, "write world.mt failed: " .. tostring(err2) end

    return true, {
        world_path = world_path,
        world_name = sanitized,
        display_name = raw,
        gameid = gameid,
    }
end

function M.delete_world(pack_id, sanitized_name, user_data_path, opts)
    opts = opts or {}
    local fs = opts.fs or M._default_fs()
    local world_path = M.pack_worlds_dir(pack_id, user_data_path) .. "/" .. sanitized_name
    if not fs.exists(world_path) then
        return false, "world not found: " .. world_path
    end
    local ok, err = fs.delete_dir(world_path)
    if not ok then return false, "delete failed: " .. tostring(err) end
    return true
end

-- 旧 flat 構造 (<user>/worlds/<pack_id>__<timestamp>) のワールドを削除する。
-- 互換のため UI から呼べるようにしておく。
function M.delete_legacy_world(world_dir_name, user_data_path, opts)
    opts = opts or {}
    local fs = opts.fs or M._default_fs()
    local world_path = user_data_path .. "/worlds/" .. world_dir_name
    if not fs.exists(world_path) then
        return false, "world not found: " .. world_path
    end
    local ok, err = fs.delete_dir(world_path)
    if not ok then return false, "delete failed: " .. tostring(err) end
    return true
end

return M
