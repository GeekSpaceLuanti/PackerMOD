local M = {}

local function urlencode(s)
    return (tostring(s):gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

function M.release_download_url(release_info)
    local url = release_info.url
    if not url then return nil end
    if url:match("^https?://") then return url end
    return "https://content.luanti.org" .. url
end

local function default_http()
    if rawget(_G, "core") and core.get_http_api then
        return core.get_http_api()
    end
    error("contentdb: HTTP API unavailable; inject opts.http")
end

local function default_parse_json(text)
    if rawget(_G, "core") and core.parse_json then
        return core.parse_json(text)
    end
    error("contentdb: JSON parser unavailable; inject opts.parse_json")
end

function M.new(opts)
    opts = opts or {}
    local http = opts.http or default_http()
    local parse_json = opts.parse_json or default_parse_json
    local base_url = opts.base_url or (core and core.settings and core.settings:get("contentdb_url"))
        or "https://content.luanti.org"

    local function fetch_json(path)
        local res = http.fetch_sync({ url = base_url .. path, timeout = 15 })
        if not res or not res.succeeded then
            return nil, ("HTTP fetch failed (%s)"):format(res and tostring(res.code) or "no response")
        end
        local data = parse_json(res.data)
        if data == nil then
            return nil, "JSON decode failed"
        end
        return data
    end

    local self = {}

    local function fetch_async(path, callback)
        if not (core and core.handle_async) or opts.http then
            local data, err = fetch_json(path)
            callback(data, err)
            return true
        end
        return core.handle_async(function(params)
            local api = core.get_http_api()
            local response = api.fetch_sync({ url = params.url, timeout = 15 })
            if not response or not response.succeeded then
                return { error = "ContentDB HTTP " .. tostring(response and response.code or "unavailable") }
            end
            local data = core.parse_json(response.data)
            if type(data) ~= "table" then return { error = "Invalid ContentDB response" } end
            return { data = data }
        end, { url = base_url .. path }, function(result)
            if not result then callback(nil, "ContentDB unavailable")
            else callback(result.data, result.error) end
        end)
    end

    function self.search_async(query, package_type, callback)
        return fetch_async("/api/packages/?type=" .. (package_type or "mod") .. "&q=" .. urlencode(query or ""), callback)
    end

    function self.releases_async(package_id, callback)
        return fetch_async("/api/packages/" .. package_id .. "/releases/", callback)
    end

    function self.search(query, package_type)
        package_type = package_type or "mod"
        local q = urlencode(query or "")
        return fetch_json("/api/packages/?type=" .. package_type .. "&q=" .. q)
    end

    function self.get_releases(package_id)
        return fetch_json("/api/packages/" .. package_id .. "/releases/")
    end

    function self.get_release(package_id, release_id)
        return fetch_json("/api/packages/" .. package_id .. "/releases/" .. tostring(release_id) .. "/")
    end

    function self.download(url, dest_path)
        local res = http.fetch_sync({ url = url, timeout = 60 })
        if not res or not res.succeeded then
            return false, ("download failed (%s)"):format(res and tostring(res.code) or "no response")
        end
        local f, err = io.open(dest_path, "wb")
        if not f then return false, "open failed: " .. tostring(err) end
        f:write(res.data)
        f:close()
        return true
    end

    function self.resolve_release_url(package_id, release_id)
        local info, err = self.get_release(package_id, release_id)
        if not info then return nil, err end
        local url = M.release_download_url(info)
        if not url then return nil, "release missing url field" end
        return url, info
    end

    return self
end

return M
