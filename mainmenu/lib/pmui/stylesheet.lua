-- pmui.stylesheet: Selector / ValueAST / Stylesheet のデータ型とパーサ。
-- parser_css.lua が YAML を読んでここの parse_selector / parse_value を呼ぶ。

local M = {}

-- ---- Selector ----

-- Selector = { simples={SimpleSelector...}, combinators={" "|">"...} }
-- SimpleSelector = { tag=?, id=?, classes={...}, pseudo=? }
-- combinators[i] は simples[i] と simples[i+1] の間の関係

local function parse_simple(s)
    local sim = { classes = {} }
    -- :pseudo を末尾から剥がす
    local body, pseudo = s:match("^(.-):([%w%-]+)$")
    if body then
        sim.pseudo = pseudo
        s = body
    end
    -- 残りを字句解析: tag / .class / #id を順に抽出
    local i = 1
    while i <= #s do
        local c = s:sub(i, i)
        if c == "." then
            local j = s:find("[.#]", i + 1) or (#s + 1)
            sim.classes[#sim.classes + 1] = s:sub(i + 1, j - 1)
            i = j
        elseif c == "#" then
            local j = s:find("[.#]", i + 1) or (#s + 1)
            sim.id = s:sub(i + 1, j - 1)
            i = j
        else
            local j = s:find("[.#:]", i + 1) or (#s + 1)
            sim.tag = s:sub(i, j - 1)
            i = j
        end
    end
    return sim
end

function M.parse_selector(text)
    -- "a > b c" → simples=[a,b,c], combinators=[">", " "]
    -- ' > ' の周りの空白は子コンビネータとしてまとめる。
    local norm = text:gsub("%s*>%s*", "\0>\0"):gsub("[ \t]+", "\0 \0")
    local tokens, ops = {}, {}
    local buf = {}
    for i = 1, #norm do
        local c = norm:sub(i, i)
        if c == "\0" then
            if #buf > 0 then tokens[#tokens + 1] = table.concat(buf); buf = {} end
        elseif c == ">" or c == " " then
            -- op をひとつ前の simple と次の simple の境界として保留
            ops[#ops + 1] = c
        else
            buf[#buf + 1] = c
        end
    end
    if #buf > 0 then tokens[#tokens + 1] = table.concat(buf) end
    -- ops は simples 間の数 (= #tokens - 1) になるよう trim
    while #ops > #tokens - 1 do table.remove(ops) end

    local simples = {}
    for _, t in ipairs(tokens) do simples[#simples + 1] = parse_simple(t) end
    return { simples = simples, combinators = ops }
end

function M.specificity(sel)
    -- CSS の (a,b,c): a=id 数, b=class+疑似, c=tag 数
    local a, b, c = 0, 0, 0
    for _, sim in ipairs(sel.simples) do
        if sim.id then a = a + 1 end
        b = b + #sim.classes
        if sim.pseudo then b = b + 1 end
        if sim.tag then c = c + 1 end
    end
    return { a = a, b = b, c = c }
end

function M.compare_specificity(x, y)
    if x.a ~= y.a then return x.a < y.a end
    if x.b ~= y.b then return x.b < y.b end
    return x.c < y.c
end

-- ---- Value AST ----

-- ValueAST = { type = literal | var | calc | url | string, ... }

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function parse_url(text)
    local inside = text:match("^url%((.-)%)$")
    if not inside then return nil end
    inside = trim(inside)
    -- 引用符を剥がす
    inside = inside:match("^[\"'](.*)[\"']$") or inside
    return { type = "url", value = inside }
end

local function parse_var(text)
    local name = text:match("^var%(%s*(%-%-[%w%-_]+)%s*%)$")
    if name then return { type = "var", name = name } end
end

-- calc は再帰的に式を持つので、後段で再パース。ここでは raw を保持する。
local function parse_calc(text)
    local inside = text:match("^calc%((.+)%)$")
    if inside then return { type = "calc", expr = trim(inside) } end
end

function M.parse_value(text)
    if type(text) == "number" then
        return { type = "literal", value = text }
    end
    if type(text) ~= "string" then
        return { type = "literal", value = text }
    end
    local s = trim(text)
    return parse_url(s)
        or parse_var(s)
        or parse_calc(s)
        or { type = "literal", value = s }
end

-- ---- Stylesheet ----

-- Stylesheet = {
--     vars  = { [name] = ValueAST },
--     rules = { Rule... },
--     media = { MediaBlock... },
-- }
-- Rule = { selectors = { Selector... }, declarations = { [prop] = ValueAST } }
-- MediaBlock = { query = { type=, value= }, rules = { Rule... } }

function M.new()
    return { vars = {}, rules = {}, media = {} }
end

return M
