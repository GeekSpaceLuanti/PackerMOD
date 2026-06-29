-- pmui.parser_html: YAML を読んで pmui.dom Element ツリーに変換する。
-- DSL の特殊機能:
--   - tag/id/class/text/attrs/children フィールド
--   - for: { each: <name>, in: <list_ref> }  リスト要素ごとに children を複製
--   - when: <truthy expr>                     falsy なら element を返さない
--   - 値内の "${path.to.var}" は ctx から解決(ui_loader.resolve_value を再利用)

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
local dom = dofile(SELF_DIR .. "dom.lua")

local M = {}

local function get_yaml()
    if rawget(_G, "packermod") and packermod.yaml then return packermod.yaml end
    -- spec / repo の相対パスで動くフォールバック
    local ok, mod = pcall(dofile, "mainmenu/yaml.lua")
    if ok then return mod end
    error("pmui.parser_html: yaml.lua not found")
end

-- ui_loader.lua の resolve_value をそのまま使う。プランの通り「require して再利用」。
local function get_resolver()
    if rawget(_G, "packermod") and packermod.ui_loader and packermod.ui_loader.resolve_value then
        return packermod.ui_loader.resolve_value
    end
    -- ui_loader が公開してない場合のフォールバック: ローカル実装
    local function resolve_path(ctx, path)
        local cur = ctx
        for part in path:gmatch("[^.]+") do
            if type(cur) ~= "table" then return nil end
            cur = cur[part]
        end
        return cur
    end
    return function(v, ctx)
        if type(v) ~= "string" then return v end
        local name = v:match("^%$%{%s*([%w_.]+)%s*%}$")
        if name then return resolve_path(ctx, name) end
        return (v:gsub("%$%{%s*([%w_.]+)%s*%}", function(k)
            local x = resolve_path(ctx, k)
            return x == nil and "" or tostring(x)
        end))
    end
end

-- ctx を上書きせず子スコープを作る (for ループの each 変数注入用)。
local function child_ctx(parent_ctx, kv)
    local out = {}
    for k, v in pairs(parent_ctx) do out[k] = v end
    for k, v in pairs(kv) do out[k] = v end
    return out
end

local function classes_from(value)
    if value == nil then return {} end
    if type(value) == "table" then return value end
    -- "a b c" → {"a", "b", "c"}
    local out = {}
    for w in tostring(value):gmatch("%S+") do out[#out + 1] = w end
    return out
end

local expand

local function expand_children(list, ctx, resolve)
    if not list then return {} end
    local out = {}
    for _, child in ipairs(list) do
        local nodes = expand(child, ctx, resolve)
        if type(nodes) == "table" and nodes[1] and dom.is_element(nodes[1]) then
            -- nodes は Element の配列 (for: 展開時)
            for _, n in ipairs(nodes) do out[#out + 1] = n end
        elseif dom.is_element(nodes) then
            out[#out + 1] = nodes
        end
        -- nil は無視 (when: false)
    end
    return out
end

expand = function(node, ctx, resolve)
    if type(node) ~= "table" then return nil end

    -- when: 条件
    if node.when ~= nil then
        local cond = resolve(node.when, ctx)
        if not cond then return nil end
    end

    -- for: ループ → Element の配列を返す
    if node["for"] then
        local each_name = node["for"].each
        local list_ref  = node["for"]["in"]
        local list = resolve("${" .. list_ref .. "}", ctx)
        if type(list) ~= "table" then return nil end
        local out = {}
        -- ループ本体: for を取り除いたコピーを毎回 expand
        local body = {}
        for k, v in pairs(node) do
            if k ~= "for" then body[k] = v end
        end
        for _, item in ipairs(list) do
            local cctx = child_ctx(ctx, { [each_name] = item })
            local el = expand(body, cctx, resolve)
            if el then out[#out + 1] = el end
        end
        return out
    end

    if not node.tag then return nil end

    -- 属性解決
    local resolved_attrs = {}
    if node.attrs then
        for k, v in pairs(node.attrs) do
            resolved_attrs[k] = resolve(v, ctx)
        end
    end

    local el = dom.element {
        tag      = node.tag,
        id       = node.id,
        classes  = classes_from(node["class"]),
        text     = node.text ~= nil and resolve(node.text, ctx) or nil,
        attrs    = resolved_attrs,
        children = expand_children(node.children, ctx, resolve),
    }
    return el
end

function M.parse(yaml_text, ctx)
    ctx = ctx or {}
    local yaml = get_yaml()
    local data = yaml.parse(yaml_text)
    local root = data and data.root or data
    if not root then error("pmui.parser_html: missing root") end
    local resolve = get_resolver()
    local el = expand(root, ctx, resolve)
    if not dom.is_element(el) then
        error("pmui.parser_html: root did not produce an element")
    end
    return el
end

-- ファイルからロード (path は repo root 相対 or 絶対)。
function M.load(path, ctx)
    local f, err = io.open(path, "r")
    if not f then error("pmui.parser_html: cannot open " .. tostring(path) .. ": " .. tostring(err)) end
    local text = f:read("*a"); f:close()
    return M.parse(text, ctx)
end

return M
