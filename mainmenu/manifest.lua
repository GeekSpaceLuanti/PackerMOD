local yaml
do
    local ok, lib = pcall(require, "mainmenu.yaml")
    if ok then
        yaml = lib
    else
        local src = debug.getinfo(1, "S").source
        if src:sub(1, 1) == "@" then src = src:sub(2) end
        local self_dir = src:match("(.*[/\\])") or ""
        yaml = dofile(self_dir .. "yaml.lua")
    end
end

local M = {}

M.SCHEMA_VERSION = 1

local VALID_SOURCES = { contentdb = true, bundle = true, url = true }

local function err(fmt, ...)
    return false, ("manifest: " .. fmt):format(...)
end

local function check_string(t, k, ctx)
    if type(t[k]) ~= "string" or t[k] == "" then
        return err("%s.%s must be a non-empty string", ctx, k)
    end
end

local function validate_mod(mod, idx)
    local ctx = ("mods[%d]"):format(idx)
    if type(mod) ~= "table" then return err("%s must be a map", ctx) end
    local r, e = check_string(mod, "name", ctx); if r == false then return r, e end
    if not VALID_SOURCES[mod.source] then
        return err("%s.source must be one of contentdb|bundle|url", ctx)
    end
    if mod.source == "contentdb" then
        local r1, e1 = check_string(mod, "package", ctx); if r1 == false then return r1, e1 end
        if mod.release ~= nil and type(mod.release) ~= "number" then
            return err("%s.release must be a number (ContentDB release id) when set", ctx)
        end
    elseif mod.source == "bundle" then
        local r1, e1 = check_string(mod, "path", ctx); if r1 == false then return r1, e1 end
    elseif mod.source == "url" then
        local r1, e1 = check_string(mod, "url", ctx); if r1 == false then return r1, e1 end
        if mod.sha256 ~= nil then
            local r2, e2 = check_string(mod, "sha256", ctx); if r2 == false then return r2, e2 end
        end
    end
    return true
end

function M.validate(data)
    if type(data) ~= "table" then return err("root must be a map") end
    if data.schema_version ~= M.SCHEMA_VERSION then
        return err("schema_version must be %d, got %s", M.SCHEMA_VERSION, tostring(data.schema_version))
    end
    for _, k in ipairs({ "id", "name", "version" }) do
        local r, e = check_string(data, k, "root"); if r == false then return r, e end
    end
    if not data.id:match("^[%w_%-]+$") then
        return err("id must match [A-Za-z0-9_-]+, got %q", data.id)
    end
    if type(data.base_game) ~= "table" then return err("base_game must be a map") end
    local r1, e1 = check_string(data.base_game, "id", "base_game"); if r1 == false then return r1, e1 end
    local r2, e2 = check_string(data.base_game, "version", "base_game"); if r2 == false then return r2, e2 end

    if data.mods ~= nil then
        if type(data.mods) ~= "table" then return err("mods must be a list") end
        for i, mod in ipairs(data.mods) do
            local ok, mer = validate_mod(mod, i)
            if not ok then return ok, mer end
        end
    end
    if data.settings ~= nil and type(data.settings) ~= "table" then
        return err("settings must be a map")
    end
    if data.texture_pack ~= nil then
        if type(data.texture_pack) ~= "table" then return err("texture_pack must be a map") end
        if not VALID_SOURCES[data.texture_pack.source] then
            return err("texture_pack.source must be one of contentdb|bundle|url")
        end
    end
    if data.thumbnail ~= nil and (type(data.thumbnail) ~= "string" or data.thumbnail == "") then
        return err("thumbnail must be a non-empty string when set (relative path from pack dir)")
    end
    return true
end

function M.parse(text)
    local ok, data = pcall(yaml.parse, text)
    if not ok then return false, "manifest: yaml parse error: " .. tostring(data) end
    local valid, ve = M.validate(data)
    if not valid then return false, ve end
    return true, data
end

function M.dump(data)
    local valid, ve = M.validate(data)
    if not valid then return false, ve end
    return true, yaml.dump(data)
end

return M
