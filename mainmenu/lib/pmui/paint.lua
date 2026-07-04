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
local BUTTON_TAGS = {
    button = true, ["icon-button"] = true,
}
local function is_container_tag(tag) return CONTAINER_TAGS[tag] == true end
local function is_label_tag(tag)     return LABEL_TAGS[tag] == true end
local function is_button_tag(tag)    return BUTTON_TAGS[tag] == true end

-- mainmenu の formspec は絶対パス texture を要求する (menu_lua_api.md)。
-- root の bg-image と同じルールで texture_dir を prepend する。
local function resolve_texture(img, texture_dir)
    if not img then return nil end
    if texture_dir and not (img:find("/", 1, true) or img:find("\\", 1, true)) then
        return texture_dir .. img
    end
    return img
end

-- el.box の paint プロパティを style[<name>;k=v;...] にエンコード。
-- icon-button は formspec の image_button だが、name selector の style[] は
-- image_button にも button にも効くため selector を分けなくて済む。
-- Label tag (h1/h2/span/p/label) は text 側に <style color> を埋めるので
-- ここでは textcolor を出さない (二重指定回避)。
local function build_style_props(el, texture_dir)
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
    -- bg-image は button 系 leaf の 9-slice 枠として使う (formspec の
    -- style bgimg + bgimg_middle + border=false)。middle 未指定なら 8 を default。
    if box.bg_image and is_button_tag(el.tag) then
        local img = resolve_texture(box.bg_image, texture_dir)
        props[#props + 1] = "bgimg=" .. img
        props[#props + 1] = "bgimg_middle=" .. tostring(box.bg_image_middle or 8)
        props[#props + 1] = "border=false"
    end
    return props
end

-- hover 版の style を別出しする (style[name:hovered;...])。
local function build_hover_props(el, texture_dir)
    local box = el.box or {}
    local props = {}
    if box.bg_image_hover and is_button_tag(el.tag) then
        local img = resolve_texture(box.bg_image_hover, texture_dir)
        props[#props + 1] = "bgimg=" .. img
        props[#props + 1] = "bgimg_middle=" .. tostring(box.bg_image_middle or 8)
        props[#props + 1] = "border=false"
    end
    return props
end

local function emit_per_element_styles(root, texture_dir)
    local out = {}
    dom.walk(root, function(el)
        local nm = name_of(el)
        if not nm then return end
        local props = build_style_props(el, texture_dir)
        if #props > 0 then
            out[#out + 1] = "style[" .. nm .. ";" .. table.concat(props, ";") .. "]"
        end
        local hprops = build_hover_props(el, texture_dir)
        if #hprops > 0 then
            out[#out + 1] = "style[" .. nm .. ":hovered;" .. table.concat(hprops, ";") .. "]"
        end
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
    -- auto_clip = true: formspec の枠外まで背景を拡大し、Luanti メインメニューの
    -- 雲アニメーション/青空背景を覆い隠す。これで PackerMOD の世界観が画面全体に広がる。
    return ("background[%s,%s;%s,%s;%s;true;0]"):format(
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

local function side_border_boxes(x, y, w, h, box)
    local out = {}
    if box.border_top_width > 0 and box.border_top_color then
        out[#out + 1] = ("box[%s,%s;%s,%s;%s]"):format(
            fnum(x), fnum(y), fnum(w), fnum(box.border_top_width), box.border_top_color)
    end
    if box.border_bottom_width > 0 and box.border_bottom_color then
        out[#out + 1] = ("box[%s,%s;%s,%s;%s]"):format(
            fnum(x), fnum(y + h - box.border_bottom_width), fnum(w),
            fnum(box.border_bottom_width), box.border_bottom_color)
    end
    if box.border_left_width > 0 and box.border_left_color then
        out[#out + 1] = ("box[%s,%s;%s,%s;%s]"):format(
            fnum(x), fnum(y), fnum(box.border_left_width), fnum(h), box.border_left_color)
    end
    if box.border_right_width > 0 and box.border_right_color then
        out[#out + 1] = ("box[%s,%s;%s,%s;%s]"):format(
            fnum(x + w - box.border_right_width), fnum(y),
            fnum(box.border_right_width), fnum(h), box.border_right_color)
    end
    return out
end

-- container の bg-image と 4 辺/個別 border を一気に発行する。iter_elements は
-- 1 回だけ呼ぶ (2 回以上呼ぶと flex 再分配が不安定になり field/list の h が
-- 変わってしまう回帰があったため)。
local function emit_container_decor(root, L, page_w, page_h, widget_tree, texture_dir)
    L.iter_elements(widget_tree, { w = page_w, h = page_h })
    local bg9, borders = {}, {}
    dom.walk(root, function(el)
        local box = el.box
        if not box or not el._widget then return end
        local w = el._widget
        if w._x == nil then return end

        -- container の 9-slice 背景 (root は emit_background で全画面塗るので除外)。
        if el ~= root and box.bg_image and is_container_tag(el.tag) then
            local img = resolve_texture(box.bg_image, texture_dir)
            bg9[#bg9 + 1] = ("background9[%s,%s;%s,%s;%s;false;%s]"):format(
                fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h),
                img, tostring(box.bg_image_middle or 8))
        end

        -- 4 辺 border (border-width + border-color)。
        if box.border_width and box.border_width > 0 and box.border_color then
            for _, line in ipairs(border_boxes(w._x, w._y, w.w, w.h, box.border_width, box.border_color)) do
                borders[#borders + 1] = line
            end
        end
        -- 個別 border (border-top-width 等)。
        for _, line in ipairs(side_border_boxes(w._x, w._y, w.w, w.h, box)) do
            borders[#borders + 1] = line
        end
    end)
    -- bg9 が先、borders が後 (枠が bg の上に重なる)。
    local out = {}
    for _, l in ipairs(bg9)     do out[#out + 1] = l end
    for _, l in ipairs(borders) do out[#out + 1] = l end
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
    for _, line in ipairs(emit_per_element_styles(root, opts.texture_dir)) do
        prepend[#prepend + 1] = line
    end

    -- bgcolor: page の box.bg があれば formspec の bgcolor[].
    -- fullscreen=both + fbgcolor で formspec の枠外 (= Luanti のメインメニュー雲/
    -- 青空アニメーション) も同じ色で塗りつぶす。これで画面全体に PackerMOD の
    -- 世界観が広がり、Luanti デフォルト背景に邪魔されない。
    if root.box and root.box.bg then
        local c = tostring(root.box.bg)
        table.insert(prepend, 1, "bgcolor[" .. c .. ";both;" .. c .. "]")
    end

    -- background9 と border は widget の _x, _y が確定してから出すので append で末尾に。
    local append = emit_container_decor(root, L, page_w, page_h, widget_tree, opts.texture_dir)

    return L.build_formspec(widget_tree, {
        w = page_w, h = page_h,
        prepend = prepend,
        append = append,
    })
end

return M
