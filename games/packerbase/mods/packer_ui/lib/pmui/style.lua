-- A deliberately small CSS dialect. Unsupported declarations fail loudly.
local M = {}
local supported = {}
supported["max-height"]=true
for name in ("display flex-direction flex-wrap flex-grow gap row-gap padding padding-top padding-right padding-bottom padding-left width height min-width max-width min-height align-items justify-content background color border-color border-width border-radius border-bottom-width border-bottom-color font-size font-weight line-height text-align icon-size"):gmatch("%S+") do supported[name] = true end
local function trim(s) return s:match("^%s*(.-)%s*$") end
function M.parse(css)
    if type(css) == "table" then return css end
    local rules = {}
    css = (css or ""):gsub("/%*.-%*/", "")
    local function parse(text, maximum)
        local pos = 1
        while true do
            local start, brace, selector = text:find("([^{}]+){", pos)
            if not start then break end
            local level, last = 1, brace + 1
            while level > 0 and last <= #text do
                local c = text:sub(last, last)
                if c == "{" then level = level + 1 elseif c == "}" then level = level - 1 end
                last = last + 1
            end
            assert(level == 0, "PMUI: unclosed CSS block")
            selector = trim(selector)
            local body = text:sub(brace + 1, last - 2)
            if selector:match("^@media") then
                local bound = assert(tonumber(selector:match("max%-width:%s*(%d+)px")), "PMUI: only @media (max-width: Npx) is supported")
                parse(body, math.min(maximum or math.huge, bound))
            else
                local declarations = {}
                for name, value in body:gmatch("([%w%-]+)%s*:%s*([^;]+)") do
                    assert(supported[name] or name:sub(1, 2) == "--", "PMUI: unsupported CSS property " .. name)
                    declarations[name] = trim(value)
                end
                for sel in selector:gmatch("[^,]+") do
                    assert(trim(sel)==":root" or not sel:find("[>+~%[%]:]"),"PMUI: unsupported CSS selector "..sel)
                    local _, ids = sel:gsub("#", "")
                    local _, classes = sel:gsub("[.:]", "")
                    rules[#rules + 1] = { selector = trim(sel), style = declarations, max_width = maximum,
                        priority = ids * 100 + classes * 10 + (sel:match("^%a") and 1 or 0) }
                end
            end
            pos = last
        end
    end
    parse(css)
    return rules
end
local function simple(node, selector)
    if selector == ":root" then return not node.parent end
    local tag = selector:match("^([%w_%-]+)")
    if tag and tag ~= node.tag then return false end
    local id = selector:match("#([%w_%-]+)")
    if id and id ~= node.id then return false end
    for class in selector:gmatch("%.([%w_%-]+)") do
        if not (" " .. (node.class or "") .. " "):find(" " .. class .. " ", 1, true) then return false end
    end
    return true
end
local function matches(node, selector)
    local parts = {}
    for part in selector:gmatch("%S+") do parts[#parts + 1] = part end
    if not simple(node, parts[#parts]) then return false end
    for i = #parts - 1, 1, -1 do
        node = node.parent
        while node and not simple(node, parts[i]) do node = node.parent end
        if not node then return false end
    end
    return true
end
function M.apply(root, rules, width, defaults)
    local function walk(node, parent)
        if node.variant and not (" "..(node.class or "").." "):find(" "..node.variant.." ",1,true) then node.class=(node.class or "").." "..node.variant end
        node.parent = parent
        local inherited = parent and parent.style or {}
        local s, ranks = { color = inherited.color or "#EAF1ED", ["font-size"] = inherited["font-size"] or 16,
            ["font-weight"] = inherited["font-weight"] or "normal", ["line-height"] = inherited["line-height"] or 1.55,
            ["text-align"] = inherited["text-align"] }, {}
        local vars = {}
        for k, v in pairs(parent and parent.vars or {}) do vars[k] = v end
        for i, rule in ipairs(rules) do
            if (not rule.max_width or width <= rule.max_width) and matches(node, rule.selector) then
                local rank = (rule.priority or 0) * 10000 + i
                for name, value in pairs(rule.style) do
                    if not ranks[name] or rank >= ranks[name] then s[name], ranks[name] = value, rank end
                end
            end
        end
        local configured=defaults and (defaults[node.tag] or ((node.tag=="key-button" or node.tag=="toggle") and defaults.button)) or {}
        local role=(" "..(node.class or "").." ")
        local colored=role:find(" primary ",1,true) or role:find(" danger ",1,true) or role:find(" quiet ",1,true)
        for k,v in pairs(configured)do if not (colored and (k=="background" or k=="color")) then s[k]=v end end
        for k, v in pairs(node.inline or {}) do s[k] = v end
        for key,value in pairs(node.inline or {}) do assert(supported[key] or key:sub(1,2)=="--","PMUI: unsupported inline property "..key) end
        for k, v in pairs(s) do if k:sub(1,2) == "--" then vars[k] = v end end
        for k, v in pairs(s) do
            if type(v) == "string" then
                for _ = 1, 8 do
                    if not v:find("var(", 1, true) then break end
                    v = v:gsub("var%((%-%-[%w%-]+)%)", function(key) return assert(vars[key], "PMUI: undefined " .. key) end)
                end
                s[k] = v
                assert(not v:find("var(",1,true),"PMUI: cyclic CSS variable "..k)
            end
        end
        local font = tostring(s["font-size"])
        s["font-size"] = (tonumber(font:match("[%d.]+")) or 16) * (font:find("em",1,true) and (inherited["font-size"] or 16) or 1)
        assert(tonumber(s["line-height"]),"PMUI: line-height must be a unitless multiplier")
        local enums={display={block=true,flex=true,none=true},["flex-direction"]={row=true,column=true},
            ["flex-wrap"]={wrap=true,nowrap=true},["align-items"]={start=true,center=true,["end"]=true,stretch=true},
            ["justify-content"]={start=true,center=true,["end"]=true,["space-between"]=true},["text-align"]={left=true,center=true,right=true}}
        for key,values in pairs(enums) do
            if s[key]=="flex-start" then s[key]="start" elseif s[key]=="flex-end" then s[key]="end" end
            assert(s[key]==nil or values[s[key]],"PMUI: unsupported "..key.." value "..tostring(s[key]))
        end
        node.style, node.vars = s, vars
        for _, child in ipairs(node.children or {}) do walk(child, node) end
    end
    walk(root)
end
function M.length(value, available, font)
    if value == nil or value == "auto" then return nil end
    if type(value) == "number" then return value end
    local number = tonumber(value:match("^([%d.%-]+)"))
    assert(number, "PMUI: invalid dimension " .. tostring(value))
    if value:find("%%") then return available * number / 100 end
    if value:find("em", 1, true) then return (font or 16) * number end
    return number
end
return M
