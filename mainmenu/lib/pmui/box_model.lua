-- pmui.box_model: cascade 後の computed プロパティを Element.box にまとめる。
-- 役割は「数値・色などを layout/paint が使いやすい形に整理する」だけで、
-- 配置計算自体は layout.lua に任せる。

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./")
local dom = dofile(SELF_DIR .. "dom.lua")

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

function M.compute(el)
    local c = el.computed or {}
    el.box = {
        -- layout
        padding        = tonumber(nz(c.padding, 0)) or 0,
        margin         = tonumber(nz(c.margin,  0)) or 0,
        gap            = tonumber(nz(c.gap,     0)) or 0,
        border_width   = tonumber(nz(c["border-width"], 0)) or 0,
        -- side-only border は 4 辺 border とは独立。両方指定するとき
        -- 4 辺が先に box[] で描かれ、side-only が上書きする形になる。
        border_top_width    = tonumber(nz(c["border-top-width"],    0)) or 0,
        border_bottom_width = tonumber(nz(c["border-bottom-width"], 0)) or 0,
        border_left_width   = tonumber(nz(c["border-left-width"],   0)) or 0,
        border_right_width  = tonumber(nz(c["border-right-width"],  0)) or 0,
        flex           = tonumber(c.flex),
        w              = tonumber(c.w),
        h              = tonumber(c.h),
        flex_direction = c["flex-direction"] or "column",
        justify        = c.justify or "start",
        align          = c.align   or "stretch",
        display        = c.display,
        grid_columns   = tonumber(c["grid-columns"]),
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
        font_size      = c["font-size"],
        text_align     = c["text-align"],
    }
end

function M.compute_all(root)
    dom.walk(root, function(el) M.compute(el) end)
end

return M
