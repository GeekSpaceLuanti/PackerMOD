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

-- mockup ビューポート (1024x600, density/scaling 1) の unit_px。design px ⇄ units の
-- 参照値。IconBtnComposite の render で M._unit_px が無い (レガシー呼び出し) ときの
-- physical px 換算フォールバックに使う。pmui/units.lua の REF_UNIT_PX と一致させる。
local REF_UNIT_PX = 0.5555 * 96

-- ---- helpers ----

local function fs_escape(s)
    s = tostring(s or "")
    if rawget(_G, "core") and core.formspec_escape then
        return core.formspec_escape(s)
    end
    return (s:gsub("([\\%[%]%;,$])", "\\%1"))
end

-- hypertext[] の text 用エスケープ。hypertext は `<` をタグ開始、`\` を実体参照に
-- 使うのでそれらを escape する。formspec 特殊文字 (`[` `]` `;` `,`) の escape は
-- build_formspec 全体で別途 fs_escape が担うが、hypertext text は formspec の
-- 1 フィールドなので `]` だけは追加で潰す (テキスト中の `]` が要素を閉じないよう)。
local function ht_escape(s)
    s = tostring(s or "")
    if rawget(_G, "core") and core.hypertext_escape then
        s = core.hypertext_escape(s)
    else
        s = s:gsub("\\", "\\\\"):gsub("<", "\\<")
    end
    return (s:gsub("]", "\\]"))
end

-- Format coordinates so 1.1 + 0.7 doesn't render as "1.7999999...".
local function fnum(x)
    return ("%g"):format(math.floor(x * 10000 + 0.5) / 10000)
end

-- padding は scalar (対称) か {t,r,b,l} テーブル (per-side)。4 辺の値を返す。
local function pad_trbl(w)
    local p = w.padding or 0
    if type(p) == "table" then
        return p.t or 0, p.r or 0, p.b or 0, p.l or 0
    end
    return p, p, p, p
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
-- Label も stretch 対象にする: hypertext は box 内で halign/valign 整列するので、
-- 親 (align=stretch) の cross 軸幅いっぱいに広げても左寄せテキストの見た目は不変。
-- 逆に center/right 整列や空状態の中央寄せは「full 幅 + halign」で初めて効く。
local STRETCHABLE_KINDS = {
    VBox = true, HBox = true, Stack = true, Spacer = true, TextList = true,
    Label = true,
}

-- ---- widget constructors ----

M.VBox     = class("VBox",     { spacing = 0.2, padding = 0, align = "stretch" })
M.HBox     = class("HBox",     { spacing = 0.2, padding = 0, align = "stretch" })
M.Stack    = class("Stack",    {})
-- Label は hypertext[] で描画する。フィールド:
--   text     プレーンテキスト (ht_escape され <global> でラップされる)
--   markup   整形済み hypertext markup (指定時は text の代わり。escape しない)
--   color    テキスト色 (<global color=>)
--   font_px  絶対フォント px (<global size=>)。hypertext の size= は px 単位
--   halign   left|center|right (<global halign=>)
--   valign   top|middle|bottom (<global valign=>、既定 middle で 1 行を縦中央に)
--   transform "uppercase" なら text を大文字化
--   w, h     ボックス寸法
M.Label    = class("Label",    {})
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

-- LabeledIconButton: 枠 (9-slice bgimg) がアイコン+ラベル全体を包む単一 composite。
-- 旧実装は image_button (アイコンのみ) の下に別 Label を積んでいたため、枠がアイコン
-- だけを囲みラベルが枠外に落ちていた (#2 密着 / #5 意匠 / #8 右端不揃いの根因)。
--
-- Phase 4 の構成 (Phase 0 で全プリミティブを実測):
--   1. full-box image_button (bgimg=枠 9-slice, fg=blank, ネイティブ label)。クリック/
--      hover は枠全域。ラベルは content_offset(px) で下帯へ寄せる (エンジンが水平中央に
--      置くので #1 の幅推定ズレが原理的に無い)。
--   2. image[] でアイコンを上部へ重ねる (image[] はクリックを下のボタンへ透過)。
--   3. box[] で divider を重ねる (box[] も透過)。
-- ラベル帯の意匠 (色/罫線) は theme (.action-btn label-color/label-divider-*) から供給し、
-- ここは構造 (帯高を font から導出・アイコン正方形・divider 位置) だけを持つ。
--
-- label="" の場合は枠飾りの要らないサムネ用途なので IconButton 1つを返す。
function M.LabeledIconButton(t)
    local label = t.label or ""
    if label == "" then
        return M.IconButton{ name = t.name, texture = t.texture, w = t.w, h = t.h, flex = t.flex }
    end
    return {
        _kind = "IconBtnComposite",
        _user_w = t.w ~= nil or nil, _user_h = t.h ~= nil or nil,
        name = t.name, texture = t.texture, label = label,
        w = t.w, h = t.h, flex = t.flex,
        label_color = t.label_color, label_font_px = t.label_font_px,
        label_transform = t.label_transform,
        divider_color = t.divider_color, divider_width = t.divider_width,
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
        local pt, pr, pb, pl = pad_trbl(w)
        if k == "VBox" then
            w.h = w.h or (main  + pt + pb)
            w.w = w.w or (cross + pl + pr)
        else
            w.w = w.w or (main  + pl + pr)
            w.h = w.h or (cross + pt + pb)
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
        -- hypertext には自然幅が無いので footprint を予約する。
        -- 高さ: font_px から行高を導出 (1 行 ≈ font_px * 1.3)。unit_px 未指定なら
        -- 従来の 0.5u を使う。
        local unit_px = M._unit_px
        if not w.h then
            if w.font_px and unit_px then
                w.h = math.max(0.5, (w.font_px * 1.3) / unit_px)
            else
                w.h = 0.5
            end
        end
        if not w.w then
            local txt = tostring(w.text or "")
            local n = #txt
            if w.font_px and unit_px then
                -- 既定プロポーショナルフォントの平均字幅 ≈ 0.5em。
                -- 中央寄せの精度は「ブロック幅の半分ズレ = テキスト中心ズレ」なので
                -- この推定で ±数 px に収まる (旧 #txt*0.18 は font 非連動で大きくズレた)。
                w.w = math.max((n * 0.5 * w.font_px) / unit_px, 0.5)
            else
                w.w = math.max(n * 0.18, 0.5)
            end
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
    elseif k == "IconBtnComposite" then
        -- leaf: 枠寸法は theme (.action-btn w/h) から来る。未指定なら正方形の既定。
        w.w = w.w or 0.9
        w.h = w.h or 0.9
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
        local pt, pr, pb, pl = pad_trbl(w)
        local inner_w = w.w - (pl + pr)
        local inner_h = w.h - (pt + pb)
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

        local cx = x + pl
        local cy = y + pt
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
        -- hypertext[X,Y;W,H;name;text]。<global> でテキスト全体の色/サイズ/整列を指定。
        -- label[] と違いエンジンが box 内で halign/valign を処理するので、文字幅推定の
        -- 誤差が中央/右寄せ位置に響かない (issue #21/#24 の中心ズレを機構的に解消)。
        local g = { "<global",
                    "halign=" .. (w.halign or "left"),
                    "valign=" .. (w.valign or "middle"),
                    "margin=0" }
        if w.color   then g[#g + 1] = "color=" .. tostring(w.color) end
        if w.font_px then g[#g + 1] = "size=" .. tostring(w.font_px) end
        local body
        if w.markup then
            body = w.markup  -- 整形済み (2 色タイトル等)。escape しない
        else
            local txt = tostring(w.text or "")
            if w.transform == "uppercase" then txt = txt:upper() end
            body = ht_escape(txt)
        end
        out[#out + 1] = ("hypertext[%s,%s;%s,%s;;%s>%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w or 0.5), fnum(w.h or 0.5),
            table.concat(g, " "), body)
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
        -- mainmenu では絶対パスを渡す (menu_lua_api.md) ので path 中の
        -- `[` `]` `;` `,` `\` を fs_escape する必要がある (特に Windows の DIR_DELIM=\ 対策)。
        out[#out + 1] = ("image[%s,%s;%s,%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h), fs_escape(w.texture))
    elseif k == "IconButton" then
        out[#out + 1] = ("image_button[%s,%s;%s,%s;%s;%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h),
            fs_escape(w.texture), w.name, fs_escape(w.label or ""))
    elseif k == "IconBtnComposite" then
        -- 枠 = ボタン box 全体。bgimg(枠)/hover は paint.lua が style[name;bgimg=...] で
        -- 供給するので、ここでは fg=blank の image_button 本体 + content_offset で下帯へ
        -- 寄せたネイティブ label + アイコン image[] + divider box[] を重ねる。
        -- style[] は要素より前に出す必要があるので image_button の直前に emit する。
        local up = M._unit_px or REF_UNIT_PX
        local x, y, bw, bh = w._x, w._y, w.w, w.h
        local fpx = w.label_font_px or 16
        -- 帯高・ギャップは font から導出 (px ハードコードを避ける)。band_h は label 行高、
        -- gap は要素間の呼吸。label_font_px は物理 px なので /up で units 化する。
        local band_h = (fpx * 1.5) / up
        local gap    = (fpx * 0.35) / up
        local pad    = gap
        local div_th = (w.divider_width and w.divider_width > 0) and w.divider_width or (1 / up)
        local band_top   = bh - band_h
        local div_y      = band_top - gap - div_th
        local icon_top   = pad
        local icon_region = div_y - gap - icon_top
        local icon_sz    = math.max(0.1, math.min(icon_region, bw - 2 * pad))
        -- content_offset(px): ネイティブラベルの自然中心 (= ボタン中心) を帯中心へ下げる。
        local coff_px = ((bh - band_h) / 2) * up
        local sp = { "style[", w.name, ";content_offset=0,", ("%g"):format(coff_px) }
        if w.label_color   then sp[#sp + 1] = ";textcolor=" .. tostring(w.label_color) end
        if w.label_font_px then sp[#sp + 1] = ";font_size=" .. tostring(math.floor(fpx + 0.5)) end
        sp[#sp + 1] = "]"
        out[#out + 1] = table.concat(sp)
        local lab = tostring(w.label or "")
        if w.label_transform == "uppercase" then lab = lab:upper() end
        out[#out + 1] = ("image_button[%s,%s;%s,%s;blank.png;%s;%s]"):format(
            fnum(x), fnum(y), fnum(bw), fnum(bh), w.name, fs_escape(lab))
        if w.texture and w.texture ~= "" then
            local ix = x + (bw - icon_sz) / 2
            local iy = y + icon_top + math.max(0, (icon_region - icon_sz) / 2)
            out[#out + 1] = ("image[%s,%s;%s,%s;%s]"):format(
                fnum(ix), fnum(iy), fnum(icon_sz), fnum(icon_sz), fs_escape(w.texture))
        end
        if w.divider_color then
            out[#out + 1] = ("box[%s,%s;%s,%s;%s]"):format(
                fnum(x + pad), fnum(y + div_y), fnum(bw - 2 * pad), fnum(div_th), w.divider_color)
        end
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
    -- Label の font 連動 measure (行高・字幅推定) に使う unit_px。measure は
    -- 木を再帰する純関数なので module 一時変数で渡す (opts をスレッドするより軽い)。
    M._unit_px = opts.unit_px
    measure(root)
    if opts.w then root.w = opts.w end
    if opts.h then root.h = opts.h end
    layout(root, opts.x or 0, opts.y or 0, root.w, root.h)
    -- M._unit_px は render でも使う (IconBtnComposite の content_offset/帯高の px 換算)
    -- ため compute では消さない。build_formspec が描画後に消す。次回 compute が先頭で
    -- 上書きするので呼び出し間の残留は無害。
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
    M._unit_px = nil
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
