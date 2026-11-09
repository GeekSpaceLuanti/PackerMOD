-- Shared ContentDB result pages for creating and editing packs.
local M = { page_size = 3 }
local thumbnails = {}
local official_origin = "https://content.luanti.org"

local function download(params)
    local http = core.get_http_api()
    if not http then return false end
    local response = http.fetch_sync({ url = params.url, timeout = 5 })
    local image = response and response.succeeded and response.data
    if type(image) ~= "string" or #image > 2 * 1024 * 1024 then return false end
    if image:sub(1, 8) ~= "\137PNG\r\n\26\n" and image:sub(1, 3) ~= "\255\216\255" then
        return false
    end
    local temporary = params.path .. ".download-" .. params.nonce
    local file = io.open(temporary, "wb")
    if not file then return false end
    local wrote = file:write(image)
    local closed = file:close()
    if wrote and closed and os.rename(temporary, params.path) then return true end
    os.remove(temporary)
    return false
end

local function thumbnail_location(result)
    local url = result.thumbnail
    if type(url) ~= "string" or #url > 2048 then return end
    local function origin(value)
        return (value .. "/"):match("^(https://[%w%.%-]+:?%d*)/")
    end
    local configured = origin(core.settings:get("contentdb_url") or official_origin)
    if url:sub(1, 1) == "/" and url:sub(2, 2) ~= "/" then
        if not configured then return end
        url = configured .. url
    end
    local host = origin(url)
    if not host or (host:lower() ~= official_origin and (not configured or host:lower() ~= configured:lower())) then return end
    if host:lower() == official_origin and not url:sub(#host + 1):match("^/thumbnails/") then return end
    local hash = core.sha256 or core.sha1
    if not hash then return end
    local directory = packermod.user_path .. DIR_DELIM .. "PackerMOD" .. DIR_DELIM .. "cache" .. DIR_DELIM .. "thumbnails"
    local extension = url:match("^[^?]+"):lower():match("(%.[a-z]+)$")
    return url, directory .. DIR_DELIM .. hash(url) .. (extension == ".png" and ".png" or ".jpg"), directory
end

function M.page_count(results)
    return math.max(1, math.ceil(#results / M.page_size))
end

function M.change_page(results, page, fields)
    local delta = fields.mod_page_next and 1 or -1
    return math.min(M.page_count(results), math.max(1, (page or 1) + delta))
end

function M.view(results, page, selected)
    local cards = {}
    local first = ((page or 1) - 1) * M.page_size + 1
    for index = first, math.min(first + M.page_size - 1, #results) do
        local result = results[index]
        local title = result.title or result.name or ""
        local author = result.author or ""
        local fallback = packermod.textures_dir and packermod.textures_dir .. "packermod_default_pack_thumbnail.png" or ""
        local thumb = thumbnails[result.thumbnail]
        cards[#cards + 1] = {
            title = title, author = author,
            image = thumb and thumb.path or fallback, loaded = thumb and thumb.path ~= nil,
            selected = index == selected, button = "mod_result_" .. index,
        }
    end
    return cards
end

function M.selection(results, fields)
    for name in pairs(fields) do
        local index = tonumber(name:match("^mod_result_(%d+)$"))
        if index and results[index] then return index end
    end
end

function M.prefetch(results, page, refresh)
    if not (core and core.handle_async) then return end
    local first = ((page or 1) - 1) * M.page_size + 1
    for index = first, math.min(first + M.page_size - 1, #results) do
        local result = results[index]
        local key = result.thumbnail
        if type(key) == "string" and not thumbnails[key] then
            local url, path, directory = thumbnail_location(result)
            if url then
                local state = {}
                thumbnails[key] = state -- deduplicate requests, including failures until restart
                local file = io.open(path, "rb")
                if file then
                    local header = file:read(8) or ""
                    file:close()
                    if header == "\137PNG\r\n\26\n" or header:sub(1, 3) == "\255\216\255" then state.path = path
                    else os.remove(path) end
                end
                if not state.path and core.create_dir(directory) then
                    core.handle_async(download, { url = url, path = path, nonce = tostring(core.get_us_time()) }, function(ok)
                        if ok then state.path = path; refresh() end
                    end)
                end
            end
        end
    end
end

return M
