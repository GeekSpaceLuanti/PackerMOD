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
    for kind, body in s:gmatch("(%w+)%[([^%]]*)%]") do
        if kind == "field" then
            local x, y, w, h, name = body:match("^([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]+)")
            if x then
                table.insert(elements, { kind = kind, name = name,
                    x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) })
            end
        elseif kind == "button" or kind == "image_button" or kind == "button_exit" then
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
    end
    return size, elements
end

local function label_visual(el, opts)
    local h = opts.label_h or 0.5
    local w = math.max((#(el.text or "")) * (opts.label_char_w or 0.18), 0.5)
    return el.x, el.y, w, h
end

local function rect_of(el, opts)
    if el.kind == "label" then return label_visual(el, opts) end
    return el.x, el.y, el.w, el.h
end

-- 浮動小数点誤差で「ピッタリ接している」widget 同士(LabeledIconButton の
-- image_button + 下の Label など)が誤って overlap 判定されないよう
-- 微小 epsilon を引いて余裕を持たせる。
local EPSILON = 1e-3
local function overlaps_rect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax + EPSILON < bx + bw and bx + EPSILON < ax + aw and
           ay + EPSILON < by + bh and by + EPSILON < ay + ah
end

function M.find_overlaps(elements, opts)
    opts = opts or {}
    local out = {}
    for i = 1, #elements do
        for j = i + 1, #elements do
            local a, b = elements[i], elements[j]
            local ax, ay, aw, ah = rect_of(a, opts)
            local bx, by, bw, bh = rect_of(b, opts)
            if overlaps_rect(ax, ay, aw, ah, bx, by, bw, bh) then
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
