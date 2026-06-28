-- icons: name → texture filename resolver for PackerMOD icons.
-- Textures live in textures/packermod_icon_<name>_<size>.png and are produced
-- by scripts/build_icons.sh from vendor/pixelarticons (MIT).

local M = {}

-- Vendored Pixelarticons names actually present on disk.
M.vendored = {
    "play", "reload", "download", "search", "plus", "trash", "save",
    "settings-2", "folder", "cloud", "package", "box",
}

-- Friendlier aliases so YAML can use intuitive names even when the upstream
-- library uses a different filename. Keep this tiny — prefer the upstream name.
M.alias = {
    sliders = "settings-2",
    cube    = "box",
}

local SIZES = { sm = true, md = true, lg = true }

function M.resolve(name)
    if not name or name == "" then return nil end
    return M.alias[name] or name
end

function M.path(name, size)
    local resolved = M.resolve(name)
    if not resolved then return "blank.png" end
    if not SIZES[size or "md"] then size = "md" end
    return ("packermod_icon_%s_%s.png"):format(resolved, size or "md")
end

function M.names()
    local out = {}
    for _, n in ipairs(M.vendored) do out[#out + 1] = n end
    for k in pairs(M.alias) do out[#out + 1] = k end
    return out
end

return M
