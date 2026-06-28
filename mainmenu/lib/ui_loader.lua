-- ui_loader: YAML / Lua-table semantic DSL → PMLayout tree.
--
-- Tags: page, card, section, actions, row, col, field, label, text, button,
--       icon-button, icon, list, spacer, status.
-- Variables: "${name}" full match returns ctx.name; partial match interpolates.
-- Pipe form: "${list | formatter}" maps ctx.list through ctx.formatter.
-- Conditional: child node with `when: ${cond}` is skipped when cond is falsy.

local M = {}

local function get_layout()
    if rawget(_G, "packermod") and packermod.layout then
        return packermod.layout
    end
    error("ui_loader: packermod.layout is required (load layout.lua first)")
end

local function get_yaml()
    if rawget(_G, "packermod") and packermod.yaml then
        return packermod.yaml
    end
    return dofile("mainmenu/yaml.lua")
end

-- ---- value resolution ----

local function resolve_path(ctx, path)
    local cur = ctx
    for part in path:gmatch("[^.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end

local function resolve_value(v, ctx)
    if type(v) ~= "string" then return v end
    -- "${list | fmt}" full match
    local list_name, fmt_name = v:match("^%$%{%s*([%w_.]+)%s*|%s*([%w_.]+)%s*%}$")
    if list_name then
        local list = resolve_path(ctx, list_name)
        local fmt  = resolve_path(ctx, fmt_name)
        if type(list) == "table" and type(fmt) == "function" then
            local out = {}
            for i, x in ipairs(list) do out[i] = fmt(x) end
            return out
        end
        return list
    end
    -- "${name}" full match: return raw value (preserves type)
    local name = v:match("^%$%{%s*([%w_.]+)%s*%}$")
    if name then
        return resolve_path(ctx, name)
    end
    -- partial substitution: interpolate as string
    return (v:gsub("%$%{%s*([%w_.]+)%s*%}", function(k)
        local x = resolve_path(ctx, k)
        if x == nil then return "" end
        return tostring(x)
    end))
end

local function resolve_props(body, ctx, except)
    except = except or {}
    local skip = {}
    for _, k in ipairs(except) do skip[k] = true end
    local out = {}
    for k, v in pairs(body) do
        if not skip[k] then
            out[k] = resolve_value(v, ctx)
        end
    end
    return out
end

-- ---- expansion ----

local expand
local handlers = {}

local function expand_children(list, ctx, theme)
    if not list then return {} end
    local out = {}
    for _, child in ipairs(list) do
        local node = expand(child, ctx, theme)
        if node ~= nil then out[#out + 1] = node end
    end
    return out
end

-- attach children list as numeric indices on a PMLayout widget table
local function attach(node, children)
    for i, c in ipairs(children) do node[i] = c end
    return node
end

expand = function(node, ctx, theme)
    if type(node) ~= "table" then return nil end
    -- find single tag key
    local tag, body
    for k, v in pairs(node) do tag, body = k, v; break end
    if not tag then return nil end
    -- scalar shortcut: { status = "..." } → treat as { text = "..." }
    if type(body) ~= "table" then
        body = { text = body }
    end
    -- when: condition
    if body.when ~= nil then
        local cond = resolve_value(body.when, ctx)
        if not cond then return nil end
    end
    local h = handlers[tag]
    if not h then
        error("ui_loader: unknown tag: " .. tostring(tag))
    end
    return h(body, ctx, theme)
end

handlers.page = function(body, ctx, theme)
    local L = get_layout()
    local children = expand_children(body.children, ctx, theme)
    local node = L.VBox{
        bgcolor = theme.colors.bg,
        padding = theme.spacing.padding_page,
        spacing = theme.spacing.md,
    }
    if body.size then
        node.w = body.size.w
        node.h = body.size.h
    end
    return attach(node, children)
end

handlers.card = function(body, ctx, theme)
    local L = get_layout()
    local children = expand_children(body.children, ctx, theme)
    local node = L.VBox{
        bgcolor = theme.colors.bg_panel,
        padding = theme.spacing.padding_card,
        spacing = theme.spacing.sm,
        flex    = body.flex,
    }
    return attach(node, children)
end

handlers.section = function(body, ctx, theme)
    local L = get_layout()
    local kids = expand_children(body.children, ctx, theme)
    local out = L.VBox{ spacing = theme.spacing.sm, flex = body.flex }
    if body.title then
        out[#out + 1] = L.Label{
            text  = resolve_value(body.title, ctx),
            name  = "section_" .. tostring(body.title):gsub("%W", "_"):lower(),
            style = "section",
        }
    end
    for _, c in ipairs(kids) do out[#out + 1] = c end
    return out
end

handlers.actions = function(body, ctx, theme)
    local L = get_layout()
    local kids = expand_children(body.children, ctx, theme)
    local out = L.HBox{ spacing = theme.spacing.md }
    out[#out + 1] = L.Spacer{ flex = 1 }
    for _, c in ipairs(kids) do out[#out + 1] = c end
    return out
end

handlers.row = function(body, ctx, theme)
    local L = get_layout()
    local kids = expand_children(body.children, ctx, theme)
    local node = L.HBox{
        spacing = body.spacing and theme.spacing[body.spacing] or theme.spacing.md,
        flex    = body.flex,
        h       = body.h,
    }
    return attach(node, kids)
end

handlers.col = function(body, ctx, theme)
    local L = get_layout()
    local kids = expand_children(body.children, ctx, theme)
    local node = L.VBox{
        spacing = body.spacing and theme.spacing[body.spacing] or theme.spacing.sm,
        flex    = body.flex,
        w       = body.w,
    }
    return attach(node, kids)
end

handlers.label = function(body, ctx, theme)
    local L = get_layout()
    local props = resolve_props(body, ctx)
    return L.Label{
        name  = props.name,
        text  = props.text or "",
        w     = props.w, h = props.h,
        style = props.style,
    }
end

handlers.text = function(body, ctx, theme)
    -- text is a multi-line label; for now emit a single Label with embedded \n
    local L = get_layout()
    local props = resolve_props(body, ctx)
    local s = props.text or ""
    if type(s) == "table" then s = table.concat(s, "\n") end
    return L.Label{ text = s, style = props.style }
end

handlers.status = function(body, ctx, theme)
    local L = get_layout()
    local props = resolve_props(body, ctx)
    return L.Label{
        text = props.text or "",
        style = "dim",
    }
end

handlers.field = function(body, ctx, theme)
    local L = get_layout()
    local props = resolve_props(body, ctx)
    return L.Field{
        name           = props.name,
        label          = props.label,
        default        = props.default,
        close_on_enter = props.close_on_enter,
        w              = props.w, h = props.h,
        flex           = props.flex,
        style          = props.style,
    }
end

handlers.textarea = function(body, ctx, theme)
    local L = get_layout()
    local props = resolve_props(body, ctx)
    return L.TextArea{
        name    = props.name,
        label   = props.label,
        default = props.default,
        w       = props.w, h = props.h,
        flex    = props.flex,
        style   = props.style,
    }
end

handlers.button = function(body, ctx, theme)
    local L = get_layout()
    local props = resolve_props(body, ctx)
    return L.Button{
        name  = props.name,
        label = props.label,
        w     = props.w, h = props.h,
        flex  = props.flex,
        style = props.variant or props.style,
    }
end

handlers["icon-button"] = function(body, ctx, theme)
    local L = get_layout()
    local props = resolve_props(body, ctx, { "icon" })
    local icon_name = body.icon
    local resolver = ctx.icon_path
    local tex = (type(resolver) == "function") and resolver(icon_name) or icon_name
    return L.IconButton{
        name    = props.name,
        texture = tex,
        label   = props.label or "",
        w       = props.w, h = props.h,
        flex    = props.flex,
    }
end

handlers.icon = function(body, ctx, theme)
    local L = get_layout()
    local size = body.size or "md"
    local sz = theme.icons["size_" .. size] or theme.icons.size_md
    local resolver = ctx.icon_path
    local tex = (type(resolver) == "function") and resolver(body.name) or body.name
    return L.Icon{ texture = tex, w = sz, h = sz }
end

handlers.list = function(body, ctx, theme)
    local L = get_layout()
    local props = resolve_props(body, ctx)
    return L.TextList{
        name        = props.name,
        items       = props.items or {},
        selected    = props.selected,
        transparent = props.transparent,
        w           = props.w, h = props.h,
        flex        = props.flex,
    }
end

handlers.spacer = function(body, ctx, theme)
    local L = get_layout()
    return L.Spacer{ flex = body.flex, w = body.w, h = body.h }
end

-- ---- public API ----

function M.expand(node, ctx, theme)
    return expand(node, ctx or {}, theme)
end

function M.load(opts)
    opts = opts or {}
    local content = opts.content
    if not content and opts.yaml_path then
        local f = io.open(opts.yaml_path, "r")
        if not f then error("ui_loader: cannot read " .. opts.yaml_path) end
        content = f:read("*a")
        f:close()
    end
    if not content then error("ui_loader: load() needs content or yaml_path") end
    local yaml = get_yaml()
    local tree = yaml.parse(content)
    return expand(tree, opts.ctx or {}, opts.theme)
end

function M.build_tab_formspec(yaml_path, ctx, build_opts)
    local L = get_layout()
    local root = M.load({ yaml_path = yaml_path, ctx = ctx, theme = build_opts and build_opts.theme })
    return L.build_formspec(root, build_opts or {})
end

-- Resolve mainmenu/ui/<filename>.yml. Phase 8+ Library + modal dialogs use this.
function M.ui_yaml_path(filename)
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    local dir = src:match("(.*[/\\])") or ("." .. (rawget(_G, "DIR_DELIM") or "/"))
    local sep = (rawget(_G, "DIR_DELIM") or "/")
    return dir .. ".." .. sep .. "ui" .. sep .. filename .. ".yml"
end

return M
