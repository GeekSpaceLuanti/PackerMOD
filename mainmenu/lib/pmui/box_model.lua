-- pmui.box_model: cascade 後の computed プロパティを Element.box にまとめる。
-- 役割は「数値・色などを layout/paint が使いやすい形に整理する」だけで、
-- 配置計算自体は layout.lua に任せる。

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
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
        color          = c.color,
        border_color   = c["border-color"],
        font_size      = c["font-size"],
        text_align     = c["text-align"],
    }
end

function M.compute_all(root)
    dom.walk(root, function(el) M.compute(el) end)
end

return M
