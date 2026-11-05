local M = {}

function M.normalize_path(path)
    path = path:gsub("\\", "/")
    local prefix = path:sub(1, 2) == "//" and "//" or (path:sub(1, 1) == "/" and "/" or "")
    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." and #parts > 0 and parts[#parts] ~= ".." and not parts[#parts]:match("^%a:$") then
            table.remove(parts)
        elseif part ~= "." then parts[#parts + 1] = part end
    end
    return prefix .. table.concat(parts, "/")
end

local function fmt_setting_value(v)
    if v == nil then return "" end
    if v == true then return "true" end
    if v == false then return "false" end
    return tostring(v)
end

function M.gameid_for(base_game)
    if base_game.installed_id then return base_game.installed_id end
    if base_game.package and base_game.release then
        return "pm_" .. base_game.id .. "_r" .. tostring(base_game.release)
    end
    local id, ver = base_game.id, base_game.version
    return id .. "_" .. (ver:gsub("[^%w]", "_"))
end

-- Engine IDs are not directory names: minetest_game is exposed as minetest,
-- and installed games may also live in a shared/system game directory.
function M.gamepath_for(base_game, user_data_path)
    local id = M.gameid_for(base_game)
    if base_game.installed_id and rawget(_G, "core") and core.get_games then
        for _, game in ipairs(core.get_games() or {}) do
            if game.id == id and type(game.path) == "string" then return game.path end
        end
        return nil
    end
    return user_data_path .. "/games/" .. id
end

-- ユーザー入力をディレクトリ名として安全な文字列に正規化する。
-- 戻り値: 1文字以上の sanitized 文字列、または nil(空 / 不正)
function M.sanitize_world_name(name)
    if type(name) ~= "string" then return nil end
    -- Retain UTF-8 names; replace ASCII path separators and punctuation.
    if name:find("[%c]") then return nil end
    local s = name:gsub("[^%w_%-\128-\255]", "_")
    -- 連続 _ を 1個に潰す
    s = s:gsub("_+", "_")
    -- 先頭末尾の _- を削る
    s = s:gsub("^[_%-]+", ""):gsub("[_%-]+$", "")
    if s == "" then return nil end
    -- These names cannot be created as directories on Windows.
    if s:upper():match("^(CON)$") or s:upper():match("^(PRN)$")
            or s:upper():match("^(AUX)$") or s:upper():match("^(NUL)$")
            or s:upper():match("^COM[1-9]$") or s:upper():match("^LPT[1-9]$") then
        s = "_" .. s
    end
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
    table.insert(lines, "mod_storage_backend = sqlite3")
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
                return core.create_dir(path)
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
            if rawget(_G, "core") and core.get_dir_list then
                local clean = path:gsub("[/\\]+$", "")
                local parent, name = clean:match("^(.*)[/\\]([^/\\]+)$")
                if parent then
                    for _, entry in ipairs(core.get_dir_list(parent, true) or {}) do
                        if entry == name then return true end
                    end
                end
            end
            return false
        end,
        rename = function(src, dst) return os.rename(src, dst) end,
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
        list_dir = function(path)
            return core.get_dir_list(path, true) or {}
        end,
        extract_zip = function(zip, dst)
            if rawget(_G, "core") and core.extract_zip then
                -- Portable engines return user paths ending in bin/.. . The
                -- extractor compares a normalized entry to its destination.
                return core.extract_zip(M.normalize_path(zip), M.normalize_path(dst))
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
    local game_path = M.gamepath_for(manifest.base_game, user_data_path)
    if not game_path or not fs.exists(game_path) then
        return false, ("base game not installed: %s"):format(gameid)
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
    if not ok2 then
        local removed = fs.delete_dir(world_path)
        return false, "write world.mt failed: " .. tostring(err2)
            .. (removed and "" or "; cannot remove incomplete world")
    end

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
