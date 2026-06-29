-- pmui.layout: DOM (box まで計算済み) → PMLayout (lib/layout.lua) widget tree への変換。
-- 既存 PMLayout の VBox/HBox/Label/Button/Image/Spacer をそのまま使い、measure と
-- formspec 出力は PMLayout に任せる。grid だけは PMUI 側で N 個ごとの行に分割してから VBox に詰める。

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
local dom = dofile(SELF_DIR .. "dom.lua")

local M = {}

local CONTAINER_TAGS = {
    page = true, div = true, header = true, footer = true, section = true,
    nav  = true, card = true, grid = true, main = true,
}
local LABEL_TAGS = {
    h1 = true, h2 = true, h3 = true, span = true, p = true, label = true,
}

local function get_pmlayout()
    if rawget(_G, "packermod") and packermod.layout then return packermod.layout end
    return dofile("mainmenu/lib/layout.lua")
end

-- icon name → 絶対パス。
-- 以下の場合は「既に解決済み」とみなして raw を返す:
--   - path separator (/ or \) を含む (= 絶対 or 相対パス)
--   - .png / .jpg などの拡張子で終わる (= ファイル名指定)
-- それ以外 (例: "plus", "sliders") は ctx.icon_path() で size 付きアイコンに解決する。
local function icon_path(ctx, name)
    if not name or name == "" then return name end
    if name:find("/", 1, true) or name:find("\\", 1, true) then return name end
    if name:lower():find("%.png$") or name:lower():find("%.jpg$") then return name end
    if ctx and type(ctx.icon_path) == "function" then return ctx.icon_path(name) end
    return name
end

local build

local function build_children(el, ctx)
    local out = {}
    for _, c in ipairs(el.children) do
        local w = build(c, ctx)
        if w then out[#out + 1] = w end
    end
    return out
end

local function build_container(L, el, ctx)
    local box = el.box
    local children = build_children(el, ctx)

    -- display: grid を N 個ごとの行に分割
    if box.display == "grid" and box.grid_columns and box.grid_columns > 0 then
        local cols = box.grid_columns
        local rows = {}
        for i = 1, #children, cols do
            local row = L.HBox { spacing = box.gap, align = "stretch" }
            for j = i, math.min(i + cols - 1, #children) do
                row[#row + 1] = children[j]
            end
            rows[#rows + 1] = row
        end
        local g = L.VBox {
            spacing = box.gap, padding = box.padding,
            w = box.w, h = box.h, flex = box.flex,
            align = "stretch",
            bgcolor = box.bg,
        }
        for _, r in ipairs(rows) do g[#g + 1] = r end
        return g
    end

    local is_row = box.flex_direction == "row"
    local W = is_row and L.HBox or L.VBox
    local node = W {
        spacing = box.gap, padding = box.padding,
        align = box.align,
        w = box.w, h = box.h, flex = box.flex,
        bgcolor = box.bg,
    }
    if box.justify == "end" then
        node[#node + 1] = L.Spacer { flex = 1 }
    elseif box.justify == "center" then
        node[#node + 1] = L.Spacer { flex = 1 }
    end
    for _, c in ipairs(children) do node[#node + 1] = c end
    if box.justify == "center" then
        node[#node + 1] = L.Spacer { flex = 1 }
    end
    return node
end

build = function(el, ctx)
    if not el then return nil end
    local L = get_pmlayout()
    local box = el.box or {}

    if CONTAINER_TAGS[el.tag] then
        return build_container(L, el, ctx)
    end
    if LABEL_TAGS[el.tag] then
        return L.Label {
            name = el.id,
            text = el.text or "",
            w    = box.w, h = box.h,
        }
    end
    if el.tag == "button" then
        return L.Button {
            name  = el.attrs.name or el.id,
            label = el.attrs.label or el.text or "",
            w = box.w, h = box.h, flex = box.flex,
        }
    end
    if el.tag == "icon-button" then
        local tex = icon_path(ctx, el.attrs.icon)
        return L.LabeledIconButton {
            name    = el.attrs.name or el.id,
            texture = tex,
            label   = el.attrs.label or "",
            w = box.w, h = box.h, flex = box.flex,
        }
    end
    if el.tag == "img" then
        return L.Image {
            texture = el.attrs.src,
            w = box.w, h = box.h, flex = box.flex,
        }
    end
    if el.tag == "spacer" then
        return L.Spacer { flex = box.flex, w = box.w, h = box.h }
    end
    if el.tag == "field" then
        return L.Field {
            name = el.attrs.name or el.id,
            label = el.attrs.label,
            default = el.attrs.default,
            w = box.w, h = box.h,
        }
    end
    -- 未対応タグは Spacer 0 (footprint なし) で安全に握りつぶす
    return L.Spacer { w = 0, h = 0 }
end

function M.flow(root, ctx)
    return build(root, ctx or {})
end

return M
