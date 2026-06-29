-- pmui.paint: DOM (box まで計算済み) → formspec 文字列。
-- 内部で layout.flow を呼んで PMLayout の widget tree を作り、PMLayout の
-- build_formspec に背景画像と style[] 等の prelude を載せて出力する。

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
local dom    = dofile(SELF_DIR .. "dom.lua")
local layout = dofile(SELF_DIR .. "layout.lua")

local M = {}

local function get_pmlayout()
    if rawget(_G, "packermod") and packermod.layout then return packermod.layout end
    return dofile("mainmenu/lib/layout.lua")
end

local function fnum(x) return ("%g"):format(math.floor(x * 10000 + 0.5) / 10000) end

local function name_of(el)
    if el.attrs and el.attrs.name then return el.attrs.name end
    return el.id
end

-- container タグの判定リスト (layout.lua と同じ集合を保持。
-- 変更時は 2 ファイル更新する規約)。
local CONTAINER_TAGS = {
    page = true, div = true, header = true, footer = true, section = true,
    nav  = true, card = true, grid = true, main = true,
}
local LABEL_TAGS = {
    h1 = true, h2 = true, h3 = true, span = true, p = true, label = true,
}
local function is_container_tag(tag) return CONTAINER_TAGS[tag] == true end
local function is_label_tag(tag)     return LABEL_TAGS[tag] == true end

-- el.box の paint プロパティを style[<name>;k=v;...] にエンコード。
-- icon-button は formspec の image_button だが、name selector の style[] は
-- image_button にも button にも効くため selector を分けなくて済む。
-- Label tag (h1/h2/span/p/label) は text 側に <style color> を埋めるので
-- ここでは textcolor を出さない (二重指定回避)。
local function build_style_props(el)
    local box = el.box or {}
    local props = {}
    if box.color and not is_label_tag(el.tag) then
        props[#props + 1] = "textcolor=" .. tostring(box.color)
    end
    if box.font_size  then props[#props + 1] = "font_size=" .. tostring(box.font_size) end
    -- bg は container だと layout 側で bgcolor → box[] になるが、leaf widget
    -- (button/field) は style[name;bgcolor=...] が必要。
    if box.bg and not is_container_tag(el.tag) then
        props[#props + 1] = "bgcolor=" .. tostring(box.bg)
    end
    return props
end

local function emit_per_element_styles(root)
    local out = {}
    dom.walk(root, function(el)
        local nm = name_of(el)
        if not nm then return end
        local props = build_style_props(el)
        if #props == 0 then return end
        out[#out + 1] = "style[" .. nm .. ";" .. table.concat(props, ";") .. "]"
    end)
    return out
end

local function emit_background(root, page_w, page_h, texture_dir)
    if not root.box or not root.box.bg_image then return nil end
    local img = root.box.bg_image
    -- Luanti のメインメニュー formspec は textures/base/pack/ しか name 解決
    -- できないため、texture_dir を prefix して絶対パスにする (path separator が
    -- 既に含まれる値は解決済みとみなしてそのまま使う)。
    if texture_dir and not (img:find("/", 1, true) or img:find("\\", 1, true)) then
        img = texture_dir .. img
    end
    return ("background[%s,%s;%s,%s;%s;false;0]"):format(
        fnum(0), fnum(0), fnum(page_w), fnum(page_h), img)
end

-- border_width / border_color が指定された container を 4 辺の box[] で囲む。
-- widget の _x, _y, w, h は PMLayout の compute 後に確定する。
local function border_boxes(x, y, w, h, bw, color)
    return {
        ("box[%s,%s;%s,%s;%s]"):format(fnum(x),      fnum(y),        fnum(w),  fnum(bw), color),
        ("box[%s,%s;%s,%s;%s]"):format(fnum(x),      fnum(y + h - bw), fnum(w),  fnum(bw), color),
        ("box[%s,%s;%s,%s;%s]"):format(fnum(x),      fnum(y),        fnum(bw), fnum(h),  color),
        ("box[%s,%s;%s,%s;%s]"):format(fnum(x + w - bw), fnum(y),    fnum(bw), fnum(h),  color),
    }
end

local function emit_borders(root, L, page_w, page_h, widget_tree)
    -- iter_elements が内部で compute を呼ぶ副作用で widget._x, _y が確定する。
    L.iter_elements(widget_tree, { w = page_w, h = page_h })
    local out = {}
    dom.walk(root, function(el)
        local box = el.box
        if not box or not box.border_width or box.border_width <= 0 then return end
        if not box.border_color or not el._widget then return end
        local w = el._widget
        if w._x == nil then return end
        for _, line in ipairs(border_boxes(w._x, w._y, w.w, w.h, box.border_width, box.border_color)) do
            out[#out + 1] = line
        end
    end)
    return out
end

function M.render(root, opts)
    opts = opts or {}
    local page_w = opts.page_w or root.box and root.box.w or 13.0
    local page_h = opts.page_h or root.box and root.box.h or 8.5

    local widget_tree = layout.flow(root, opts.ctx)
    local L = get_pmlayout()

    local prepend = {}
    local bg = emit_background(root, page_w, page_h, opts.texture_dir)
    if bg then prepend[#prepend + 1] = bg end
    for _, line in ipairs(emit_per_element_styles(root)) do
        prepend[#prepend + 1] = line
    end

    -- bgcolor: page の box.bg があれば formspec の bgcolor[] (全体背景色)
    if root.box and root.box.bg then
        table.insert(prepend, 1, "bgcolor[" .. tostring(root.box.bg) .. ";true]")
    end

    -- border は widget の _x, _y が確定してから出すので append で末尾に
    local append = emit_borders(root, L, page_w, page_h, widget_tree)

    return L.build_formspec(widget_tree, {
        w = page_w, h = page_h,
        prepend = prepend,
        append = append,
    })
end

return M
