local M = {}

function M.uuid(bytes)
    local random_class = rawget(_G, "SecureRandom")
    if not bytes and random_class then bytes = random_class():next_bytes(16) end
    if not bytes then
        local out = {}
        for i = 1, 16 do out[i] = string.char(math.random(0, 255)) end
        bytes = table.concat(out)
    end
    assert(#bytes == 16, "UUID needs 16 random bytes")
    local b = { bytes:byte(1, 16) }
    b[7], b[9] = b[7] % 16 + 64, b[9] % 64 + 128
    return ("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x"):format(unpack(b))
end

local function nonempty(s)
    return type(s) == "string" and s:match("^%s*(.-)%s*$") ~= ""
end

function M.build_manifest(tabdata)
    if not nonempty(tabdata.pack_id) then tabdata.pack_id = M.uuid() end
    if not nonempty(tabdata.pack_name) then return false, "pack_name required" end
    if not nonempty(tabdata.pack_version) then tabdata.pack_version = "1.0.0" end
    if tabdata.base_game then
        tabdata.base_id, tabdata.base_version = tabdata.base_game.id, tabdata.base_game.version
    end
    if not nonempty(tabdata.base_id) then return false, "base_id required" end
    if not nonempty(tabdata.base_version) then return false, "base_version required" end

    local manifest = {
        schema_version = 1,
        id = tabdata.pack_id,
        name = tabdata.pack_name,
        version = tabdata.pack_version,
        base_game = tabdata.base_game or {
            id = tabdata.base_id,
            version = tabdata.base_version,
        },
    }
    if nonempty(tabdata.pack_description) then manifest.description = tabdata.pack_description end
    if nonempty(tabdata.pack_author) then manifest.author = tabdata.pack_author end
    if tabdata.mods and #tabdata.mods > 0 then manifest.mods = tabdata.mods end
    if tabdata.settings and next(tabdata.settings) ~= nil then manifest.settings = tabdata.settings end
    return true, manifest
end

function M.add_mod(tabdata, mod_spec)
    tabdata.mods = tabdata.mods or {}
    for _, existing in ipairs(tabdata.mods) do
        if existing.name == mod_spec.name then
            return false, "duplicate mod name: " .. mod_spec.name
        end
    end
    table.insert(tabdata.mods, mod_spec)
    return true
end

function M.remove_mod(tabdata, index)
    if not tabdata.mods or index < 1 or index > #tabdata.mods then return false end
    table.remove(tabdata.mods, index)
    return true
end

function M.contentdb_result_to_mod(result, release_id)
    return {
        name = result.name,
        source = "contentdb",
        package = result.author .. "/" .. result.name,
        release = release_id,
    }
end

return M
