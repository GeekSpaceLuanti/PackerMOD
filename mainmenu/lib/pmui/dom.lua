-- pmui.dom: HTML 風 Element ツリーのデータ型と走査ユーティリティ。
-- cascade.lua / box_model.lua / layout.lua / paint.lua はこの Element を
-- 受け渡ししながら、computed / box フィールドを段階的に埋めていく。

local M = {}

-- ---- Element ----

-- 想定フィールド:
--   tag       string             必須
--   id        string?
--   classes   { string... }
--   attrs     { [name]=value }   parser_html が解決済みの属性
--   text      string?            tag が h1/span/label/etc のときの中身
--   children  { Element... }
--   computed  { [prop]=value }   cascade 後に埋まる
--   box       { x,y,w,h, content_*, border_* }  layout 後に埋まる
--   _parent   Element?           dom.walk が設定する
function M.element(t)
    t = t or {}
    t.classes  = t.classes  or {}
    t.attrs    = t.attrs    or {}
    t.children = t.children or {}
    return t
end

function M.is_element(v)
    return type(v) == "table" and type(v.tag) == "string"
end

-- pre-order 走査。visitor(el, parent, depth) が false を返すと子を辿らない。
function M.walk(root, visitor)
    local function rec(el, parent, depth)
        el._parent = parent
        local descend = visitor(el, parent, depth)
        if descend == false then return end
        for _, child in ipairs(el.children) do
            rec(child, el, depth + 1)
        end
    end
    rec(root, nil, 0)
end

function M.find_by_id(root, id)
    local found
    M.walk(root, function(el)
        if el.id == id then found = el; return false end
    end)
    return found
end

function M.find_all(root, predicate)
    local out = {}
    M.walk(root, function(el)
        if predicate(el) then out[#out + 1] = el end
    end)
    return out
end

-- 親チェーン (近い順)。selector の子孫マッチで使う。
function M.ancestors(el)
    local out, p = {}, el._parent
    while p do out[#out + 1] = p; p = p._parent end
    return out
end

return M
