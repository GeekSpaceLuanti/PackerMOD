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

-- bgcolor を Phase 9 までの #3A3A3A から #5A5A5A に明るくした(#10)。
-- image_button(アイコン白系)が button 背景に同化していたのを、
-- contrast を上げて視認性を確保する目的。
M.button = {
    default   = { bgcolor = "#5A5A5A", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#7A7A7A", bgcolor_pressed = "#3A3A3A" },
    primary   = { bgcolor = "#3FA63F", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#55FF55", bgcolor_pressed = "#2E7A2E" },
    secondary = { bgcolor = "#5A5A5A", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#7A7A7A", bgcolor_pressed = "#3A3A3A" },
    danger    = { bgcolor = "#B33A3A", textcolor = "#FFFFFF",
                  bgcolor_hovered = "#FF5555", bgcolor_pressed = "#7A2828" },
    ghost     = { bgcolor = "#00000000", textcolor = "#AAAAAA",
                  bgcolor_hovered = "#5A5A5A", bgcolor_pressed = "#3A3A3A" },
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

-- フォント倍率(formspec_version 6 の `*<n>` 記法。基準サイズに対する乗算)
-- 全 widget を一括拡大して視認性を上げる(#18 系)。
M.font = {
    label_scale    = "*1.3",
    button_scale   = "*1.2",
    field_scale    = "*1.2",
    textlist_scale = "*1.2",
    textarea_scale = "*1.2",
}

-- Prelude lines to inject at the top of the formspec when this theme is active.
-- Returned as a list of strings (caller concatenates with the rest of the form).
function M.emit_global_prelude()
    local lines = {}
    lines[#lines + 1] = ("bgcolor[%s;true]"):format(M.colors.bg)
    lines[#lines + 1] = M.emit_style_type("button",       M.button.default)
    -- image_button is a different formspec selector and does not inherit
    -- style_type[button;...] (#10). Apply the same bg here so icon-buttons
    -- get the same visual treatment.
    lines[#lines + 1] = M.emit_style_type("image_button", M.button.default)
    lines[#lines + 1] = M.emit_style_type("field",        M.field.default)
    lines[#lines + 1] = M.emit_style_type("textlist",     M.textlist.default)
    -- フォントサイズを widget 種別ごとに拡大。style_type は同一 selector を
    -- 後で上書きすると追加プロパティとしてマージされず置き換わるので、
    -- font_size はこの最後にまとめて出す。
    lines[#lines + 1] = ("style_type[label;font_size=%s]"):format(M.font.label_scale)
    lines[#lines + 1] = ("style_type[textarea;font_size=%s]"):format(M.font.textarea_scale)
    -- button / image_button / field / textlist は既に bgcolor 等を設定済みなので
    -- font_size はマージするため再度 emit_style_type で props 含めて出す。
    local button_with_font = {}
    for k, v in pairs(M.button.default) do button_with_font[k] = v end
    button_with_font.font_size = M.font.button_scale
    lines[#lines + 1] = M.emit_style_type("button", button_with_font)
    lines[#lines + 1] = M.emit_style_type("image_button", button_with_font)
    local field_with_font = {}
    for k, v in pairs(M.field.default) do field_with_font[k] = v end
    field_with_font.font_size = M.font.field_scale
    lines[#lines + 1] = M.emit_style_type("field", field_with_font)
    local textlist_with_font = {}
    for k, v in pairs(M.textlist.default) do textlist_with_font[k] = v end
    textlist_with_font.font_size = M.font.textlist_scale
    lines[#lines + 1] = M.emit_style_type("textlist", textlist_with_font)
    -- remove nils
    local out = {}
    for _, l in ipairs(lines) do if l then out[#out + 1] = l end end
    return out
end

return M
