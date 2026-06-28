local M = {}

local function nonempty(s)
    return type(s) == "string" and s:match("^%s*(.-)%s*$") ~= ""
end

function M.build_manifest(tabdata)
    if not nonempty(tabdata.pack_id) then return false, "pack_id required" end
    if not nonempty(tabdata.pack_name) then return false, "pack_name required" end
    if not nonempty(tabdata.pack_version) then return false, "pack_version required" end
    if not nonempty(tabdata.base_id) then return false, "base_id required" end
    if not nonempty(tabdata.base_version) then return false, "base_version required" end

    local manifest = {
        schema_version = 1,
        id = tabdata.pack_id,
        name = tabdata.pack_name,
        version = tabdata.pack_version,
        base_game = {
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
