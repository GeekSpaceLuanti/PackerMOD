-- PMLayout: minimal declarative formspec layout for Luanti.
--
-- Goals:
--   * No `core` dependency at load time (uses core.formspec_escape if present)
--   * Works in mainmenu and in-game alike (this file only produces a formspec
--     string; the caller wires it up to the host's event API)
--   * Single file, ~250 lines, drop-in copy for other mods
--
-- Usage:
--   local L = dofile(modpath .. "/lib/layout.lua")
--   local root = L.VBox{
--       spacing = 0.2, padding = 0.3,
--       L.HBox{ L.Field{name="id", label="Id", w=3.5}, L.Field{name="name", label="Name", w=5.2} },
--       L.Label{text="Search"},
--       L.HBox{ L.Field{name="q", w=5.5}, L.Button{name="go", label="Search", w=1.5} },
--   }
--   local fs = L.build_formspec(root, { w = 15.5, h = 7.1, version = 6 })

local M = {}

-- ---- helpers ----

local function fs_escape(s)
    s = tostring(s or "")
    if rawget(_G, "core") and core.formspec_escape then
        return core.formspec_escape(s)
    end
    return (s:gsub("([\\%[%]%;,$])", "\\%1"))
end

-- Format coordinates so 1.1 + 0.7 doesn't render as "1.7999999...".
local function fnum(x)
    return ("%g"):format(math.floor(x * 10000 + 0.5) / 10000)
end

local function class(kind, defaults)
    defaults = defaults or {}
    return function(t)
        t = t or {}
        t._kind = kind
        -- Remember whether the caller pinned the cross-axis sizes so default
        -- stretch can leave them alone.
        if t.w ~= nil then t._user_w = true end
        if t.h ~= nil then t._user_h = true end
        for k, v in pairs(defaults) do
            if t[k] == nil then t[k] = v end
        end
        return t
    end
end

-- Widgets that fill the cross axis when the parent has align="stretch".
-- Discrete leaf widgets (Button, Field, Label, Image, Box) keep their natural
-- size; fluid widgets stretch.
local STRETCHABLE_KINDS = {
    VBox = true, HBox = true, Stack = true, Spacer = true, TextList = true,
}

-- ---- widget constructors ----

M.VBox     = class("VBox",     { spacing = 0.2, padding = 0, align = "stretch" })
M.HBox     = class("HBox",     { spacing = 0.2, padding = 0, align = "stretch" })
M.Stack    = class("Stack",    {})
M.Label    = class("Label",    {})                 -- {text=, [w], [h]}
-- The label band Luanti prints above a `field` box. v6 has no declared height
-- for it; ~0.4 units matches the rendered text + gap.
M.FIELD_LABEL_H = 0.4
M.Field    = class("Field",    { w = 3, h = 0.7 }) -- {name=, [label], [default], [close_on_enter]}
M.TextArea = class("TextArea", { w = 4, h = 2.0 }) -- {name=, [label], [default]}
M.Button   = class("Button",   { w = 2, h = 0.7 }) -- {name=, label=}
M.TextList = class("TextList", {})                 -- {name=, items={}, [selected], [transparent], w=, h=}
M.Image    = class("Image",    {})                 -- {texture=, w=, h=}
M.Box      = class("Box",      {})                 -- {color=, w=, h=}
M.Spacer   = class("Spacer",   {})                 -- {[w], [h]}
M.Raw      = class("Raw",      {})                 -- {text=}: arbitrary snippet, zero footprint
M.Icon       = class("Icon",       { w = 0.7, h = 0.7 }) -- {texture=, w=, h=}
M.IconButton = class("IconButton", { w = 0.9, h = 0.9 }) -- {name=, texture=, label="", w=, h=}

-- LabeledIconButton: image_button + 下に Label(別 widget)で構成し、
-- Luanti formspec の image_button label が画像中央に重なる問題(#21)を回避する。
-- label="" の場合は IconButton 1つだけ返す(画面1 のサムネカード等)。
-- name は image_button 側に付くのでクリックイベントは従来通り発火する。
--
-- 画像部分は正方形(w = img_h)に固定し、左右に Spacer を入れて中央寄せする。
-- これは Luanti image_button が画像をボタン領域に縦横独立に拡大する仕様で、
-- 横長ボタンだと正方形アイコンが横に潰れて見える(#21 派生)のを回避するため。
function M.LabeledIconButton(t)
    local label = t.label or ""
    if label == "" then
        return M.IconButton{ name = t.name, texture = t.texture, w = t.w, h = t.h, flex = t.flex }
    end
    local label_band_h = 0.45
    local btn_h = t.h or 0.9
    local img_h = math.max(0.4, btn_h - label_band_h)
    -- btn_w が未指定なら親が決める(IconButton の natural w = h で扱う)
    local btn_w = t.w or img_h
    local img_w = math.min(btn_w, img_h)  -- 画像は正方形に
    return M.VBox{
        spacing = 0,
        w = btn_w, h = btn_h, flex = t.flex,
        align = "stretch",
        M.HBox{
            spacing = 0, w = btn_w, h = img_h,
            M.Spacer{ flex = 1 },
            M.IconButton{ name = t.name, texture = t.texture, label = "",
                          w = img_w, h = img_h },
            M.Spacer{ flex = 1 },
        },
        M.HBox{
            spacing = 0, w = btn_w, h = label_band_h,
            M.Spacer{ flex = 1 },
            M.Label{ text = label, h = label_band_h },
            M.Spacer{ flex = 1 },
        },
    }
end

-- ---- measure: bottom-up natural size ----

local function measure(w)
    local k = w._kind
    if k == "VBox" or k == "HBox" then
        local main, cross, n = 0, 0, 0
        for _, child in ipairs(w) do
            measure(child)
            n = n + 1
            if k == "VBox" then
                main  = main + (child.h or 0)
                cross = math.max(cross, child.w or 0)
            else
                main  = main + (child.w or 0)
                cross = math.max(cross, child.h or 0)
            end
        end
        if n > 1 then main = main + w.spacing * (n - 1) end
        if k == "VBox" then
            w.h = w.h or (main  + 2 * w.padding)
            w.w = w.w or (cross + 2 * w.padding)
        else
            w.w = w.w or (main  + 2 * w.padding)
            w.h = w.h or (cross + 2 * w.padding)
        end
    elseif k == "Stack" then
        local ww, hh = 0, 0
        for _, child in ipairs(w) do
            measure(child)
            ww = math.max(ww, (child.x or 0) + (child.w or 0))
            hh = math.max(hh, (child.y or 0) + (child.h or 0))
        end
        w.w = w.w or ww
        w.h = w.h or hh
    elseif k == "Label" then
        -- v6 labels declare no size; reserve a realistic visual footprint
        -- so neighbouring widgets don't overlap.
        w.h = w.h or 0.5
        if not w.w then
            local txt = tostring(w.text or "")
            w.w = math.max(#txt * 0.18, 0.5)
        end
    elseif k == "Field" then
        -- formspec v6: the `label` text is printed ABOVE the box (lua_api.md
        -- "top left above the field"). The caller's `h` is the box height;
        -- the effective footprint is box + label band so the row above
        -- doesn't get clipped by the next row's label band.
        local has_label = w.label ~= nil and w.label ~= ""
        w._label_h = has_label and M.FIELD_LABEL_H or 0
        w._box_h   = w.h or 0.7
        w.h = w._box_h + w._label_h
    elseif k == "TextArea" then
        -- formspec textarea[X,Y;W,H;name;label;default]: label is also printed
        -- ABOVE the box in v6, so reserve the same band as Field.
        local has_label = w.label ~= nil and w.label ~= ""
        w._label_h = has_label and M.FIELD_LABEL_H or 0
        w._box_h   = w.h or 2.0
        w.h = w._box_h + w._label_h
    end
    w.w = w.w or 0
    w.h = w.h or 0
end

-- ---- layout: top-down absolute positions, flex distribution ----
--
-- Containers fill the available rectangle the parent gives them. Along the
-- main axis (Y for VBox, X for HBox), any space left over after summing
-- children's natural sizes is split among children with `flex` > 0 in proportion
-- to their flex weights. Along the cross axis, children keep their natural size
-- and are placed by `align` (start/center/end), except for `align="stretch"`
-- which sizes each child to the inner cross extent.

local function layout(w, x, y, avail_w, avail_h)
    w._x, w._y = x, y
    if avail_w then w.w = avail_w end
    if avail_h then w.h = avail_h end

    local k = w._kind
    if k == "VBox" or k == "HBox" then
        local inner_w = w.w - 2 * w.padding
        local inner_h = w.h - 2 * w.padding
        local main_avail  = (k == "VBox") and inner_h or inner_w
        local cross_avail = (k == "VBox") and inner_w or inner_h

        local n = #w
        local natural_main, total_flex = 0, 0
        for _, child in ipairs(w) do
            natural_main = natural_main + ((k == "VBox") and child.h or child.w)
            total_flex   = total_flex   + (child.flex or 0)
        end
        if n > 1 then natural_main = natural_main + w.spacing * (n - 1) end
        local extra = math.max(0, main_avail - natural_main)

        local cx = x + w.padding
        local cy = y + w.padding
        for i, child in ipairs(w) do
            local base = (k == "VBox") and child.h or child.w
            local grow = (total_flex > 0) and (extra * (child.flex or 0) / total_flex) or 0
            local main_size = base + grow
            local cross_size = (k == "VBox") and child.w or child.h

            local cross_axis_flag = (k == "VBox") and "_user_w" or "_user_h"
            local stretchable = STRETCHABLE_KINDS[child._kind] and not child[cross_axis_flag]
            local off = 0
            if w.align == "stretch" and stretchable then
                cross_size = cross_avail
            elseif w.align == "center" then
                off = (cross_avail - cross_size) / 2
            elseif w.align == "end" then
                off = cross_avail - cross_size
            end

            if k == "VBox" then
                layout(child, cx + off, cy, cross_size, main_size)
                cy = cy + main_size
                if i < n then cy = cy + w.spacing end
            else
                layout(child, cx, cy + off, main_size, cross_size)
                cx = cx + main_size
                if i < n then cx = cx + w.spacing end
            end
        end
    elseif k == "Stack" then
        for _, child in ipairs(w) do
            layout(child, x + (child.x or 0), y + (child.y or 0), child.w, child.h)
        end
    end
end

-- ---- render: leaf widgets to formspec elements ----

local KIND_TO_THEME_KIND = {
    Button = "button", Field = "field", TextArea = "field",
    Label = "label", TextList = "textlist",
}

local function maybe_emit_style(w, out, theme)
    if not theme or not w.style then return end
    local tk = KIND_TO_THEME_KIND[w._kind]
    if not tk then return end
    local s = theme.style_for(tk, w.style)
    if not s or not s.props then return end
    local sel = w.name
    if not sel or sel == "" then return end
    local line = theme.emit_style(sel, s.props)
    if line then out[#out + 1] = line end
end

local function render(w, out, theme)
    out = out or {}
    local k = w._kind
    if k == "VBox" or k == "HBox" or k == "Stack" then
        if w.bgcolor then
            out[#out + 1] = ("box[%s,%s;%s,%s;%s]"):format(
                fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h), w.bgcolor)
        end
        for _, child in ipairs(w) do render(child, out, theme) end
    elseif k == "Label" then
        maybe_emit_style(w, out, theme)
        out[#out + 1] = ("label[%s,%s;%s]"):format(fnum(w._x), fnum(w._y), fs_escape(w.text))
    elseif k == "Field" then
        maybe_emit_style(w, out, theme)
        -- The reserved label band sits at the top; the actual box lives below.
        local box_y = w._y + (w._label_h or 0)
        local box_h = w._box_h or w.h
        out[#out + 1] = ("field[%s,%s;%s,%s;%s;%s;%s]"):format(
            fnum(w._x), fnum(box_y), fnum(w.w), fnum(box_h),
            w.name, fs_escape(w.label or ""), fs_escape(w.default))
        if w.close_on_enter ~= nil then
            out[#out + 1] = ("field_close_on_enter[%s;%s]"):format(w.name, tostring(w.close_on_enter))
        end
    elseif k == "TextArea" then
        maybe_emit_style(w, out, theme)
        local box_y = w._y + (w._label_h or 0)
        local box_h = w._box_h or w.h
        out[#out + 1] = ("textarea[%s,%s;%s,%s;%s;%s;%s]"):format(
            fnum(w._x), fnum(box_y), fnum(w.w), fnum(box_h),
            w.name, fs_escape(w.label or ""), fs_escape(w.default or ""))
    elseif k == "Button" then
        maybe_emit_style(w, out, theme)
        out[#out + 1] = ("button[%s,%s;%s,%s;%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h), w.name, fs_escape(w.label))
    elseif k == "TextList" then
        maybe_emit_style(w, out, theme)
        local items = {}
        for _, item in ipairs(w.items or {}) do
            items[#items + 1] = fs_escape(item)
        end
        out[#out + 1] = ("textlist[%s,%s;%s,%s;%s;%s;%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h),
            w.name, table.concat(items, ","),
            tostring(w.selected or 0), tostring(w.transparent or false))
    elseif k == "Image" or k == "Icon" then
        out[#out + 1] = ("image[%s,%s;%s,%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h), w.texture)
    elseif k == "IconButton" then
        out[#out + 1] = ("image_button[%s,%s;%s,%s;%s;%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h),
            w.texture, w.name, fs_escape(w.label or ""))
    elseif k == "Box" then
        out[#out + 1] = ("box[%s,%s;%s,%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h), w.color)
    elseif k == "Raw" then
        out[#out + 1] = w.text or ""
    end
    return out
end

-- ---- public API ----

local function compute(root, opts)
    measure(root)
    if opts.w then root.w = opts.w end
    if opts.h then root.h = opts.h end
    layout(root, opts.x or 0, opts.y or 0, root.w, root.h)
end

function M.build_formspec(root, opts)
    opts = opts or {}
    compute(root, opts)
    local parts = {
        ("formspec_version[%s]"):format(opts.version or 6),
        ("size[%s,%s]"):format(fnum(root.w), fnum(root.h)),
    }
    if opts.theme and opts.theme.emit_global_prelude then
        for _, line in ipairs(opts.theme.emit_global_prelude()) do
            parts[#parts + 1] = line
        end
    end
    for _, line in ipairs(opts.prepend or {}) do parts[#parts + 1] = line end
    render(root, parts, opts.theme)
    for _, line in ipairs(opts.append or {}) do parts[#parts + 1] = line end
    return table.concat(parts, "")
end

function M.iter_elements(root, opts)
    compute(root, opts or {})
    local list = {}
    local function walk(w)
        local k = w._kind
        if k == "VBox" or k == "HBox" or k == "Stack" then
            for _, child in ipairs(w) do walk(child) end
        elseif k ~= "Spacer" and k ~= "Raw" then
            list[#list + 1] = { kind = k, name = w.name, text = w.text,
                x = w._x, y = w._y, w = w.w, h = w.h }
        end
    end
    walk(root)
    return list
end

return M
