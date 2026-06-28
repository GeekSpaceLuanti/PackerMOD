-- Pack ごとのお気に入りマルチプレイサーバー一覧。
-- <pack_root>/servers.yaml に配列で保存される(マイクラ式:Pack 紐付けは UI 分類のみ、
-- 接続時のサーバー側 Mod 要件適合は Luanti のハンドシェイクが処理する)。

local M = {}

local DIR_DELIM_LUA = package.config:sub(1, 1)

local function join(a, b)
    return a .. DIR_DELIM_LUA .. b
end

local function file_path(pack_path)
    return join(pack_path, "servers.yaml")
end

local function default_read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function default_write(path, text)
    local f, err = io.open(path, "w")
    if not f then return false, err end
    f:write(text)
    f:close()
    return true
end

local function deps(opts)
    opts = opts or {}
    return {
        yaml = opts.yaml or require("mainmenu.yaml"),
        read = opts.read_file or default_read,
        write = opts.write_file or default_write,
    }
end

local function clean(server)
    return {
        name = server.name or "",
        address = server.address or "",
        port = tonumber(server.port) or 30000,
        description = server.description or "",
    }
end

function M.load(pack_path, opts)
    local d = deps(opts)
    local text = d.read(file_path(pack_path))
    if not text or text == "" then return {} end
    local ok, parsed = pcall(d.yaml.parse, text)
    if not ok or type(parsed) ~= "table" then return {} end
    -- 旧形式: top-level array。新形式想定: { servers: [...] } も受け入れる。
    local arr = parsed.servers or parsed
    if type(arr) ~= "table" then return {} end
    local result = {}
    for _, s in ipairs(arr) do
        if type(s) == "table" then
            table.insert(result, clean(s))
        end
    end
    return result
end

function M.save(pack_path, list, opts)
    local d = deps(opts)
    local cleaned = {}
    for _, s in ipairs(list or {}) do
        table.insert(cleaned, clean(s))
    end
    return d.write(file_path(pack_path), d.yaml.dump({ servers = cleaned }))
end

function M.add(pack_path, server, opts)
    local list = M.load(pack_path, opts)
    table.insert(list, clean(server))
    local ok, err = M.save(pack_path, list, opts)
    if not ok then return false, err end
    return true, #list
end

function M.remove(pack_path, index, opts)
    local list = M.load(pack_path, opts)
    if index < 1 or index > #list then return false, "index out of range" end
    table.remove(list, index)
    return M.save(pack_path, list, opts)
end

function M.update(pack_path, index, server, opts)
    local list = M.load(pack_path, opts)
    if index < 1 or index > #list then return false, "index out of range" end
    list[index] = clean(server)
    return M.save(pack_path, list, opts)
end

return M
