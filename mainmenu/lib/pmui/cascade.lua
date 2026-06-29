-- pmui.cascade: stylesheet を DOM ツリーに適用し、各 Element の computed プロパティを埋める。
-- selector match + specificity + var()/calc() の解決 + media query 切替を扱う。
--
-- 公開 API:
--   M.compute(root, sheet, opts)
--     opts = { page_w = number, page_h = number, hover = { [id]=true, ... } }
--     各 el.computed = { [prop_name] = resolved_value } を埋める
--   M.match(el, selector) -> bool   (テスト用)
--   M.resolve_value(val_ast, vars) -> resolved_value

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
local stylesheet = dofile(SELF_DIR .. "stylesheet.lua")
local dom        = dofile(SELF_DIR .. "dom.lua")

local M = {}

-- ---- selector matching ----

local function simple_matches(el, sim, state)
    if sim.tag and sim.tag ~= "*" and sim.tag ~= el.tag then return false end
    if sim.id and sim.id ~= el.id then return false end
    for _, cls in ipairs(sim.classes) do
        local found = false
        for _, c in ipairs(el.classes) do
            if c == cls then found = true; break end
        end
        if not found then return false end
    end
    if sim.pseudo then
        -- state.hover_ids: id でホバー判定
        if sim.pseudo == "hover" then
            if not (state.hover_ids and el.id and state.hover_ids[el.id]) then return false end
        elseif sim.pseudo == "active" then
            if not (state.active_ids and el.id and state.active_ids[el.id]) then return false end
        elseif sim.pseudo == "disabled" then
            if not el.attrs.disabled then return false end
        else
            return false
        end
    end
    return true
end

function M.match(el, sel, state)
    state = state or {}
    local n = #sel.simples
    if n == 0 then return false end
    -- 末尾の simple は el にマッチしなければならない
    if not simple_matches(el, sel.simples[n], state) then return false end
    -- 残りを右から左へ、combinators を辿りつつ親チェーンとマッチさせる
    local cur = el
    for i = n - 1, 1, -1 do
        local combinator = sel.combinators[i]
        local sim = sel.simples[i]
        if combinator == ">" then
            local p = cur._parent
            if not p or not simple_matches(p, sim, state) then return false end
            cur = p
        else  -- " " 子孫
            local p = cur._parent
            local matched = false
            while p do
                if simple_matches(p, sim, state) then
                    cur = p
                    matched = true
                    break
                end
                p = p._parent
            end
            if not matched then return false end
        end
    end
    return true
end

-- ---- value resolution ----

local function eval_calc_expr(expr, vars, opts)
    -- 簡易 evaluator: 数字 / var(--x) / + - * / / ( )。
    -- shunting-yard で AST 化してから再帰評価する。
    local tokens = {}
    local i = 1
    while i <= #expr do
        local c = expr:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == "(" or c == ")" or c == "+" or c == "-" or c == "*" or c == "/" then
            tokens[#tokens + 1] = c
            i = i + 1
        elseif c == "v" and expr:sub(i, i + 3) == "var(" then
            local j = expr:find("%)", i + 4)
            if not j then error("calc: unclosed var()") end
            local name = expr:sub(i + 4, j - 1):match("^%s*(%S+)%s*$")
            tokens[#tokens + 1] = { kind = "var", name = name }
            i = j + 1
        else
            local j = i
            while j <= #expr and expr:sub(j, j):match("[%d%.]") do j = j + 1 end
            if j == i then error("calc: unexpected char '" .. c .. "' in '" .. expr .. "'") end
            tokens[#tokens + 1] = tonumber(expr:sub(i, j - 1))
            i = j
        end
    end

    local function precedence(op) return (op == "+" or op == "-") and 1 or 2 end
    local out, ops = {}, {}
    for _, tok in ipairs(tokens) do
        if type(tok) == "number" or type(tok) == "table" then
            out[#out + 1] = tok
        elseif tok == "(" then
            ops[#ops + 1] = tok
        elseif tok == ")" then
            while #ops > 0 and ops[#ops] ~= "(" do
                out[#out + 1] = ops[#ops]; ops[#ops] = nil
            end
            ops[#ops] = nil  -- pop "("
        else  -- + - * /
            while #ops > 0 and ops[#ops] ~= "(" and precedence(ops[#ops]) >= precedence(tok) do
                out[#out + 1] = ops[#ops]; ops[#ops] = nil
            end
            ops[#ops + 1] = tok
        end
    end
    while #ops > 0 do out[#out + 1] = ops[#ops]; ops[#ops] = nil end

    local stack = {}
    for _, tok in ipairs(out) do
        if type(tok) == "number" then
            stack[#stack + 1] = tok
        elseif type(tok) == "table" then
            local v = vars[tok.name]
            if not v then error("calc: unknown var " .. tok.name) end
            stack[#stack + 1] = M.resolve_value(v, vars, opts)
        else
            local b, a = stack[#stack], stack[#stack - 1]
            stack[#stack] = nil; stack[#stack] = nil
            if     tok == "+" then stack[#stack + 1] = a + b
            elseif tok == "-" then stack[#stack + 1] = a - b
            elseif tok == "*" then stack[#stack + 1] = a * b
            elseif tok == "/" then stack[#stack + 1] = a / b
            end
        end
    end
    return stack[1]
end

-- ValueAST → 値. literal はそのまま、var は再帰解決、calc は数値評価
function M.resolve_value(ast, vars, opts)
    if type(ast) ~= "table" then return ast end
    if ast.type == "literal" then return ast.value end
    if ast.type == "url" then return { _url = ast.value } end
    if ast.type == "var" then
        local v = vars[ast.name]
        if not v then return nil end
        return M.resolve_value(v, vars, opts)
    end
    if ast.type == "calc" then
        return eval_calc_expr(ast.expr, vars, opts)
    end
    return ast
end

-- ---- media query ----

local function media_matches(query, opts)
    if not opts or not opts.page_w then return false end
    if query.type == "min-width" then return opts.page_w >= query.value end
    if query.type == "max-width" then return opts.page_w <= query.value end
    return false
end

-- ---- cascade ----

local function apply_rule(el, rule, state, source_order)
    for _, sel in ipairs(rule.selectors) do
        if M.match(el, sel, state) then
            local spec = stylesheet.specificity(sel)
            for prop, ast in pairs(rule.declarations) do
                local current = el.computed[prop]
                local key = { spec = spec, order = source_order }
                if (not current) or
                   stylesheet.compare_specificity(current._spec, spec) or
                   (current._spec.a == spec.a and current._spec.b == spec.b and
                    current._spec.c == spec.c and current._order <= source_order) then
                    el.computed[prop] = {
                        _ast = ast, _spec = spec, _order = source_order,
                    }
                end
            end
            return  -- 同じ rule の他 selector は試さない (どれか1つでマッチすれば適用)
        end
    end
end

function M.compute(root, sheet, opts)
    opts = opts or {}
    local state = {
        hover_ids  = opts.hover_ids or {},
        active_ids = opts.active_ids or {},
    }

    -- 1. 全 element に computed = {} を初期化 + _parent をリンク
    dom.walk(root, function(el)
        el.computed = {}
    end)

    -- 2. ルールを順次適用 (通常 → media マッチしたものを後で上書き)
    local order = 0
    local function apply_all(rules)
        for _, rule in ipairs(rules) do
            order = order + 1
            dom.walk(root, function(el)
                apply_rule(el, rule, state, order)
            end)
        end
    end
    apply_all(sheet.rules)
    for _, m in ipairs(sheet.media) do
        if media_matches(m.query, opts) then apply_all(m.rules) end
    end

    -- 3. AST → 値に解決 (var/calc を実値に)
    dom.walk(root, function(el)
        local resolved = {}
        for prop, entry in pairs(el.computed) do
            resolved[prop] = M.resolve_value(entry._ast, sheet.vars, opts)
        end
        el.computed = resolved
    end)
end

return M
