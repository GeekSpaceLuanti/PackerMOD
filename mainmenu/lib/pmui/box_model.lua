-- pmui.box_model: cascade 後の computed プロパティを Element.box にまとめる。
-- 役割は「数値・色などを layout/paint が使いやすい形に整理する」だけで、
-- 配置計算自体は layout.lua に任せる。

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./")
local dom = dofile(SELF_DIR .. "dom.lua")
local units = dofile(SELF_DIR .. "units.lua")

local M = {}

local function nz(v, default)
    if v == nil then return default end
    return v
end

-- url AST が混じってる場合 _url を取り出す
local function url_value(v)
    if type(v) == "table" and v._url then return v._url end
    return nil
end

-- 長さ値を formspec unit へ解決する。
--   * number / 数値文字列  → そのまま formspec unit (レガシー資産)
--   * "Npx"               → design px。unit へは px_to_units (unit_px 非依存)
-- snap=true の場合は変換後に整数 device px へスナップ (border など細線の crisp 化)。
local function len(v, unit_px, snap)
    if v == nil then return nil end
    local px = units.parse_px(v)
    if px ~= nil then
        local u = units.px_to_units(px)
        if snap and unit_px then u = units.snap_units(u, unit_px) end
        return u
    end
    return tonumber(v)
end

local function len0(v, unit_px, snap) return len(v, unit_px, snap) or 0 end

-- font-size を「hypertext size= へ渡す絶対 px 値」に解決する。
-- hypertext の size= は絶対 px のみ (label[] と違い *k 構文が無い) なので、
-- 全形式を絶対 px 数値へ寄せる。
--   * "Npx"   → design px を unit_px で実 font px へ (font_px = N * unit_px/REF)。
--               window で比例スケールする (responsive)。
--   * "*k"    → k * REF_FONT_PX の絶対 px (= 旧 style[] の *k 挙動 k×既定16 と一致)。
--               unit に追従しない。未リベース画面 (detail/modal) の見た目を保つための
--               過渡措置で、Phase 6 で px 化すれば responsive になる。
--   * number  → design px 扱い (px と同義、responsive)。
local REF_FONT_PX = 16  -- Luanti 既定 font_size (Phase 0 実測)
local function font_size(v, unit_px)
    if v == nil then return nil end
    local px = units.parse_px(v)
    if px ~= nil then
        return units.font_px(px, unit_px or units.REF_UNIT_PX)
    end
    if type(v) == "string" then
        local mult = v:match("^%s*%*([%d%.]+)%s*$")
        if mult then
            return math.floor(tonumber(mult) * REF_FONT_PX + 0.5)
        end
    end
    local n = tonumber(v)
    if n then return units.font_px(n, unit_px or units.REF_UNIT_PX) end
    return nil
end

-- opts.unit_px: エンジンが使う実 unit_px (px→font 換算 + snap に使う)。
function M.compute(el, opts)
    opts = opts or {}
    local unit_px = opts.unit_px
    local c = el.computed or {}
    el.box = {
        -- layout
        padding        = len0(c.padding, unit_px),
        margin         = len0(c.margin,  unit_px),
        gap            = len0(c.gap,     unit_px),
        border_width   = len0(c["border-width"], unit_px, true),
        -- side-only border は 4 辺 border とは独立。両方指定するとき
        -- 4 辺が先に box[] で描かれ、side-only が上書きする形になる。
        border_top_width    = len0(c["border-top-width"],    unit_px, true),
        border_bottom_width = len0(c["border-bottom-width"], unit_px, true),
        border_left_width   = len0(c["border-left-width"],   unit_px, true),
        border_right_width  = len0(c["border-right-width"],  unit_px, true),
        flex           = tonumber(c.flex),
        w              = len(c.w, unit_px),
        h              = len(c.h, unit_px),
        flex_direction = c["flex-direction"] or "column",
        justify        = c.justify or "start",
        align          = c.align   or "stretch",
        display        = c.display,
        grid_columns   = c["grid-columns"],  -- "auto" or number (layout 側で解釈)
        -- paint
        bg             = c.bg or c["background-color"],
        bg_image       = url_value(c["bg-image"]),
        bg_image_hover = url_value(c["bg-image-hover"]),
        bg_image_middle = tonumber(c["bg-image-middle"]),
        color          = c.color,
        border_color   = c["border-color"],
        border_top_color    = c["border-top-color"]    or c["border-color"],
        border_bottom_color = c["border-bottom-color"] or c["border-color"],
        border_left_color   = c["border-left-color"]   or c["border-color"],
        border_right_color  = c["border-right-color"]  or c["border-color"],
        font_size      = font_size(c["font-size"], unit_px),
        text_align     = c["text-align"],
        text_transform = c["text-transform"],
    }
end

function M.compute_all(root, opts)
    dom.walk(root, function(el) M.compute(el, opts) end)
end

return M
