-- ui_loader: ${var} と "${list | formatter}" pipe form の値解決。
-- 旧 YAML/PMLayout DSL の expand パイプライン (Phase 11) は撤去済み
-- (commit 8)。現在は PMUI (mainmenu/lib/pmui/) の parser_html がここの
-- resolve_value / resolve_path を require して再利用するための薄いモジュール。

local M = {}

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

M.resolve_value = resolve_value
M.resolve_path  = resolve_path

return M
