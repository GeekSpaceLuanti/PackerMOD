-- formspec 文字列を tolerant にパースして AABB rectangles を取り出し、
-- overlap / out-of-bounds を検出する spec ヘルパ。layout_spec / library_spec
-- 両方から使う(両方の dofile-only 環境で動くよう、require は使わない)。

local M = {}

function M.escape_min(s)
    s = tostring(s or "")
    return (s:gsub("([\\%[%]%;,$])", "\\%1"))
end

function M.parse_formspec(s)
    local size = { w = 0, h = 0 }
    local elements = {}
    local sw, sh = s:match("size%[([%d.]+),([%d.]+)%]")
    if sw then size.w, size.h = tonumber(sw), tonumber(sh) end
    local offset, parents, scrollbar_values = { x = 0, y = 0 }, {}, {}
    for kind, body in s:gmatch("([%w_]+)%[([^%]]*)%]") do
        local before = #elements
        if kind == "scrollbar" then
            local name, value = body:match(";vertical;([^;]+);([%d.]+)$")
            if name then scrollbar_values[name] = tonumber(value) end
        end
        if kind == "scroll_container" then
            local x, y, w, h, name, factor = body:match("^([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]+);vertical;([%d.]+)")
            if x then
                parents[#parents + 1] = offset
                local ax, ay = offset.x + tonumber(x), offset.y + tonumber(y)
                offset = { x = ax, y = ay - (scrollbar_values[name] or 0) * tonumber(factor),
                    clip = { x = ax, y = ay, w = tonumber(w), h = tonumber(h) } }
            end
        elseif kind == "scroll_container_end" then
            offset = table.remove(parents) or { x = 0, y = 0 }
        end
        if kind == "field" then
            local x, y, w, h, name = body:match("^([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]+)")
            if x then
                table.insert(elements, { kind = kind, name = name,
                    x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) })
            end
        elseif kind == "button" or kind == "image_button" or kind == "button_exit" or kind == "button_key" or kind == "dropdown" then
            local x, y, w, h, name = body:match("^([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]+)")
            if x then
                table.insert(elements, { kind = "button", name = name,
                    x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) })
            end
        elseif kind == "textlist" or kind == "textarea" or kind == "image"
                or kind == "tableoptions" or kind == "table" then
            local x, y, w, h = body:match("^([%d.]+),([%d.]+);([%d.]+),([%d.]+)")
            if x then
                table.insert(elements, { kind = kind,
                    x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) })
            end
        elseif kind == "label" then
            local x, y, text = body:match("^([%d.]+),([%d.]+);(.*)$")
            if x then
                table.insert(elements, { kind = kind, text = text or "",
                    x = tonumber(x), y = tonumber(y), w = 0, h = 0 })
            end
        end
        for i = before + 1, #elements do
            elements[i].x, elements[i].y = elements[i].x + offset.x, elements[i].y + offset.y
            elements[i].clip = offset.clip
        end
    end
    return size, elements
end

-- 不可視 inline tag は表示文字数に含めないため除去。
--   - Luanti の ESC color sequence: \27(c@#XXXXXX)
--   - 旧 inline tag: <style color=...>...</style> や <color=...>...</color>
local function visible_text(s)
    s = s or ""
    s = s:gsub("\27%(c@[^)]*%)", "")
    s = s:gsub("<style[^>]*>", ""):gsub("</style>", "")
    s = s:gsub("<color[^>]*>", ""):gsub("</color>", "")
    return s
end

-- formspec v6 の label は「y = テキスト第 1 行の垂直中心」(lua_api.md)。
-- 実機の描画位置に合わせて上端 y を h/2 分だけ上に補正した AABB を返す。
local function label_visual(el, opts)
    -- default は LabeledIconButton の label band h (layout.lua) と一致させる。
    local h = opts.label_h or 0.45
    local w = math.max((#visible_text(el.text)) * (opts.label_char_w or 0.18), 0.5)
    return el.x, el.y - h / 2, w, h
end

local function rect_of(el, opts)
    local x, y, w, h = el.x, el.y, el.w, el.h
    if el.kind == "label" then x, y, w, h = label_visual(el, opts) end
    if el.clip then
        local c = el.clip
        local right, bottom = math.min(x + w, c.x + c.w), math.min(y + h, c.y + c.h)
        x, y = math.min(math.max(x, c.x), c.x + c.w), math.min(math.max(y, c.y), c.y + c.h)
        w, h = math.max(0, right - x), math.max(0, bottom - y)
    end
    return x, y, w, h
end

-- 浮動小数点誤差で「ピッタリ接している」widget 同士 (隣接するカード/ボタンなど) が
-- 誤って overlap 判定されないよう微小 epsilon を引いて余裕を持たせる。
local EPSILON = 1e-3
local function overlaps_rect(ax, ay, aw, ah, bx, by, bw, bh)
    if aw <= EPSILON or ah <= EPSILON or bw <= EPSILON or bh <= EPSILON then return false end
    return ax + EPSILON < bx + bw and bx + EPSILON < ax + aw and
           ay + EPSILON < by + bh and by + EPSILON < ay + ah
end

-- inner の AABB が outer の AABB に (誤差込みで) 完全に収まるか。
local function contains_rect(ox, oy, ow, oh, ix, iy, iw, ih)
    return ix + EPSILON >= ox and iy + EPSILON >= oy and
           ix + iw <= ox + ow + EPSILON and iy + ih <= oy + oh + EPSILON
end

-- composite icon-button (Phase 4) はボタン枠 (image_button, fg=blank) の中に
-- アイコン image[] を意図的に重ねる。ボタンに完全内包された image は overlay なので
-- overlap 扱いしない (別ボタンにはみ出す image は内包されないので依然検知される)。
local function is_composite_icon_overlay(a, b, opts)
    local btn, img
    if a.kind == "button" and b.kind == "image" then btn, img = a, b
    elseif b.kind == "button" and a.kind == "image" then btn, img = b, a
    else return false end
    local bx, by, bw, bh = rect_of(btn, opts)
    local ix, iy, iw, ih = rect_of(img, opts)
    return contains_rect(bx, by, bw, bh, ix, iy, iw, ih)
end

function M.find_overlaps(elements, opts)
    opts = opts or {}
    local out = {}
    for i = 1, #elements do
        for j = i + 1, #elements do
            local a, b = elements[i], elements[j]
            local ax, ay, aw, ah = rect_of(a, opts)
            local bx, by, bw, bh = rect_of(b, opts)
            if overlaps_rect(ax, ay, aw, ah, bx, by, bw, bh)
                and not is_composite_icon_overlay(a, b, opts) then
                table.insert(out, { a = a, b = b })
            end
        end
    end
    return out
end

function M.fits_in_size(elements, size, opts)
    opts = opts or {}
    for _, el in ipairs(elements) do
        local x, y, w, h = rect_of(el, opts)
        if x < 0 or y < 0 or x + w > size.w + 1e-6 or y + h > size.h + 1e-6 then
            return false, el
        end
    end
    return true
end

function M.describe_el(e)
    return ("%s[%s] @(%.2f,%.2f %.2fx%.2f)"):format(
        e.kind, e.name or e.text or "?", e.x, e.y, e.w or 0, e.h or 0)
end

function M.format_overlaps(overlaps)
    local lines = {}
    for _, p in ipairs(overlaps) do
        table.insert(lines, "  " .. M.describe_el(p.a) .. " vs " .. M.describe_el(p.b))
    end
    return "unexpected overlaps:\n" .. table.concat(lines, "\n")
end

return M
