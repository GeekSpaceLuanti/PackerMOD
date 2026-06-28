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
        for k, v in pairs(defaults) do
            if t[k] == nil then t[k] = v end
        end
        return t
    end
end

-- ---- widget constructors ----

M.VBox     = class("VBox",     { spacing = 0.2, padding = 0, align = "start" })
M.HBox     = class("HBox",     { spacing = 0.2, padding = 0, align = "start" })
M.Stack    = class("Stack",    {})
M.Label    = class("Label",    {})                 -- {text=, [w], [h]}
M.Field    = class("Field",    { w = 3, h = 0.7 }) -- {name=, [label], [default], [close_on_enter]}
M.Button   = class("Button",   { w = 2, h = 0.7 }) -- {name=, label=}
M.TextList = class("TextList", {})                 -- {name=, items={}, [selected], [transparent], w=, h=}
M.Image    = class("Image",    {})                 -- {texture=, w=, h=}
M.Box      = class("Box",      {})                 -- {color=, w=, h=}
M.Spacer   = class("Spacer",   {})                 -- {[w], [h]}
M.Raw      = class("Raw",      {})                 -- {text=}: arbitrary snippet, zero footprint

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
    end
    w.w = w.w or 0
    w.h = w.h or 0
end

-- ---- layout: top-down absolute positions ----

local function layout(w, x, y, parent_cross)
    w._x, w._y = x, y
    local k = w._kind
    if k == "VBox" then
        local cx = x + w.padding
        local cy = y + w.padding
        local inner = (parent_cross or w.w) - 2 * w.padding
        for i, child in ipairs(w) do
            local child_x = cx
            if w.align == "center" then
                child_x = cx + (inner - child.w) / 2
            elseif w.align == "end" then
                child_x = cx + (inner - child.w)
            end
            layout(child, child_x, cy, child.w)
            cy = cy + child.h
            if i < #w then cy = cy + w.spacing end
        end
    elseif k == "HBox" then
        local cx = x + w.padding
        local cy = y + w.padding
        local inner = (parent_cross or w.h) - 2 * w.padding
        for i, child in ipairs(w) do
            local child_y = cy
            if w.align == "center" then
                child_y = cy + (inner - child.h) / 2
            elseif w.align == "end" then
                child_y = cy + (inner - child.h)
            end
            layout(child, cx, child_y, child.h)
            cx = cx + child.w
            if i < #w then cx = cx + w.spacing end
        end
    elseif k == "Stack" then
        for _, child in ipairs(w) do
            layout(child, x + (child.x or 0), y + (child.y or 0), child.w)
        end
    end
end

-- ---- render: leaf widgets to formspec elements ----

local function render(w, out)
    out = out or {}
    local k = w._kind
    if k == "VBox" or k == "HBox" or k == "Stack" then
        for _, child in ipairs(w) do render(child, out) end
    elseif k == "Label" then
        out[#out + 1] = ("label[%s,%s;%s]"):format(fnum(w._x), fnum(w._y), fs_escape(w.text))
    elseif k == "Field" then
        out[#out + 1] = ("field[%s,%s;%s,%s;%s;%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h),
            w.name, fs_escape(w.label or ""), fs_escape(w.default))
        if w.close_on_enter ~= nil then
            out[#out + 1] = ("field_close_on_enter[%s;%s]"):format(w.name, tostring(w.close_on_enter))
        end
    elseif k == "Button" then
        out[#out + 1] = ("button[%s,%s;%s,%s;%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h), w.name, fs_escape(w.label))
    elseif k == "TextList" then
        local items = {}
        for _, item in ipairs(w.items or {}) do
            items[#items + 1] = fs_escape(item)
        end
        out[#out + 1] = ("textlist[%s,%s;%s,%s;%s;%s;%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h),
            w.name, table.concat(items, ","),
            tostring(w.selected or 0), tostring(w.transparent or false))
    elseif k == "Image" then
        out[#out + 1] = ("image[%s,%s;%s,%s;%s]"):format(
            fnum(w._x), fnum(w._y), fnum(w.w), fnum(w.h), w.texture)
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
    layout(root, opts.x or 0, opts.y or 0, root.w)
end

function M.build_formspec(root, opts)
    opts = opts or {}
    compute(root, opts)
    local parts = {
        ("formspec_version[%s]"):format(opts.version or 6),
        ("size[%s,%s]"):format(fnum(root.w), fnum(root.h)),
    }
    for _, line in ipairs(opts.prepend or {}) do parts[#parts + 1] = line end
    render(root, parts)
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
