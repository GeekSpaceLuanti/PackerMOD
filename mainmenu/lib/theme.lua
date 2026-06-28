-- Theme tokens for PackerMOD UI. Minecraft-inspired (dark panels, XP-green accent).
-- core-independent: pure tables + pure functions.

local M = {}

M.colors = {
    bg          = "#1A1A1A",
    bg_panel    = "#2B2B2B",
    bg_field    = "#0F0F0F",
    text        = "#FFFFFF",
    text_dim    = "#AAAAAA",
    text_muted  = "#7A7A7A",
    accent      = "#55FF55",
    accent_dim  = "#3FA63F",
    danger      = "#FF5555",
    warning     = "#FFAA00",
    border      = "#000000",
    border_lit  = "#5A5A5A",
    border_dim  = "#0A0A0A",
}

M.spacing = {
    xs = 0.1, sm = 0.2, md = 0.3, lg = 0.5, xl = 0.8,
    padding_page = 0.4,
    padding_card = 0.3,
}

M.icons = {
    size_sm = 0.5, size_md = 0.7, size_lg = 1.0,
    px_sm   = 24,  px_md   = 48,  px_lg   = 72,
}

M.button = {
    default   = { bgcolor = "#3A3A3A", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#4A4A4A", bgcolor_pressed = "#2A2A2A" },
    primary   = { bgcolor = "#3FA63F", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#55FF55", bgcolor_pressed = "#2E7A2E" },
    secondary = { bgcolor = "#3A3A3A", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#4A4A4A", bgcolor_pressed = "#2A2A2A" },
    danger    = { bgcolor = "#B33A3A", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#FF5555", bgcolor_pressed = "#7A2828" },
    ghost     = { bgcolor = "#00000000", textcolor = "#AAAAAA",
                  bgcolor_hovered = "#3A3A3A", bgcolor_pressed = "#2A2A2A" },
}

M.field = {
    default = { bgcolor = "#0F0F0F", textcolor = "#FFFFFF", border = "true" },
}

M.label = {
    default = { textcolor = "#FFFFFF" },
    dim     = { textcolor = "#AAAAAA" },
    section = { textcolor = "#55FF55" },
}

M.textlist = {
    default = { bgcolor = "#0F0F0F" },
}

-- ---- API ----

local function variants(kind)
    if kind == "button"   then return M.button end
    if kind == "field"    then return M.field end
    if kind == "label"    then return M.label end
    if kind == "textlist" then return M.textlist end
    return nil
end

-- kind: "button" | "field" | "label" | "textlist"
-- variant: variant name, nil falls back to "default"
function M.style_for(kind, variant)
    local set = variants(kind)
    if not set then return nil end
    local v = variant or "default"
    local props = set[v] or set.default
    if not props then return nil end
    return { props = props }
end

local function emit_kv(props)
    local parts = {}
    for k, v in pairs(props) do
        parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    return table.concat(parts, ";")
end

function M.emit_style(selector, props)
    if not props or not next(props) then return nil end
    return ("style[%s;%s]"):format(selector, emit_kv(props))
end

function M.emit_style_type(kind, props)
    if not props or not next(props) then return nil end
    return ("style_type[%s;%s]"):format(kind, emit_kv(props))
end

-- Prelude lines to inject at the top of the formspec when this theme is active.
-- Returned as a list of strings (caller concatenates with the rest of the form).
function M.emit_global_prelude()
    local lines = {}
    lines[#lines + 1] = ("bgcolor[%s;true]"):format(M.colors.bg)
    lines[#lines + 1] = M.emit_style_type("button",   M.button.default)
    lines[#lines + 1] = M.emit_style_type("field",    M.field.default)
    lines[#lines + 1] = M.emit_style_type("textlist", M.textlist.default)
    -- remove nils
    local out = {}
    for _, l in ipairs(lines) do if l then out[#out + 1] = l end end
    return out
end

return M
