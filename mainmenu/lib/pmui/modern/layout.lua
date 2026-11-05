local P = (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./")
local css = dofile(P .. "style.lua")
local M = {}
local containers = { div=true, main=true, header=true, footer=true, nav=true, section=true, scroll=true }
function M.is_container(node) return containers[node.tag] end
local function text_width(text, font, measure)
    if measure then return measure(text, font) end
    local width = 0
    for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        width = width + font * (#char > 1 and 1 or (char == " " and 0.3 or 0.62))
    end
    return width
end
M.text_width = text_width
local function edges(s, available)
    available = available or 0
    local values = {}
    for part in tostring(s.padding or 0):gmatch("%S+") do values[#values+1] = css.length(part, available, s["font-size"]) end
    local t, r, b, l = values[1] or 0, values[2] or values[1] or 0, values[3] or values[1] or 0, values[4] or values[2] or values[1] or 0
    return css.length(s["padding-top"], available) or t, css.length(s["padding-right"], available) or r,
        css.length(s["padding-bottom"], available) or b, css.length(s["padding-left"], available) or l
end
local function number(s, name, available, default)
    return css.length(s[name], available or 0, s["font-size"]) or default or 0
end
local function intrinsic(node, available, measure)
    local s = node.style
    if s.display == "none" then return 0 end
    local fixed = css.length(s.width, available, s["font-size"])
    if fixed then return fixed end
    local _, r, _, l = edges(s, available)
    local value = text_width(node.text, s["font-size"], measure)
    if node.icon then value = value + number(s, "icon-size", 0, 18) + (value > 0 and 8 or 0) end
    if node.tag == "field" or node.tag == "textarea" or node.tag == "list" or node.tag=="dropdown" or node.tag=="slider" then value = 240 end
    if containers[node.tag] then
        value = 0
        for i, child in ipairs(node.children or {}) do
            local child_w = intrinsic(child, available, measure)
            if s["flex-direction"] == "row" then value = value + child_w + (i > 1 and number(s,"gap") or 0)
            else value = math.max(value, child_w) end
        end
    end
    return math.max(number(s,"min-width"), math.min(available, value + l + r))
end
local function lines(text, width, font, measure)
    local out, line = {}, ""
    for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if char == "\n" then out[#out+1], line = line, ""
        else
            if #line > 0 and text_width(line .. char, font, measure) > width + 0.1 then out[#out+1], line = line, "" end
            line = line .. char
        end
    end
    out[#out+1] = line
    return out
end
function M.compute(root, available, measure)
    local function flow(node, width, x, y)
        local s, tag = node.style, node.tag
        node.box = { x=x, y=y, w=0, h=0 }
        if s.display == "none" then return 0 end
        width = math.min(width, number(s,"max-width",width, width))
        local t, r, b, l = edges(s, width)
        local inner = math.max(1, width - r - l)
        if tag=="scroll" then inner=math.max(1,inner-16) end
        local gap, content_h = number(s,"gap"), 0
        if containers[tag] then
            local children = {}
            for _, child in ipairs(node.children or {}) do if child.style.display ~= "none" then children[#children+1] = child end end
            if s["flex-direction"] == "row" then
                local rows, row, used = {}, {}, 0
                for _, child in ipairs(children) do
                    local grow = tonumber(child.style["flex-grow"]) or 0
                    local preferred = grow > 0 and number(child.style,"min-width",inner, 80) or intrinsic(child, inner, measure)
                    preferred = math.min(inner, preferred)
                    if #row > 0 and used + gap + preferred > inner and s["flex-wrap"] ~= "nowrap" then
                        rows[#rows+1], row, used = row, {}, 0
                    end
                    row[#row+1] = { node=child, width=preferred, grow=grow }
                    used = used + preferred + (#row > 1 and gap or 0)
                end
                if #row > 0 then rows[#rows+1] = row end
                for row_index, items in ipairs(rows) do
                    local occupied, growth, row_h = gap * math.max(0,#items-1), 0, 0
                    for _, item in ipairs(items) do occupied, growth = occupied + item.width, growth + item.grow end
                    local spare = math.max(0, inner - occupied)
                    local item_gap = gap
                    if growth==0 and s["justify-content"]=="space-between" and #items>1 then item_gap=gap+spare/(#items-1) end
                    local offset = growth == 0 and (s["justify-content"] == "center" and spare / 2 or s["justify-content"] == "end" and spare or 0) or 0
                    local cursor = x + l + offset
                    for _, item in ipairs(items) do
                        local cw = item.width + (growth > 0 and spare * item.grow / growth or 0)
                        row_h = math.max(row_h, flow(item.node, cw, cursor, y+t+content_h))
                        cursor = cursor + cw + item_gap
                    end
                    for _, item in ipairs(items) do
                        local diff = row_h - item.node.box.h
                        if s["align-items"]=="stretch" then item.node.box.h=row_h end
                        local shift = s["align-items"] == "center" and diff/2 or s["align-items"] == "end" and diff or 0
                        if shift > 0 then M.translate(item.node, 0, shift) end
                    end
                    content_h = content_h + row_h + (row_index < #rows and number(s,"row-gap",0,gap) or 0)
                end
            else
                for i, child in ipairs(children) do
                    local cw = css.length(child.style.width,inner,child.style["font-size"])
                    if not cw then
                        local stretch = s["align-items"] ~= "center" and s["align-items"] ~= "end"
                        cw = stretch and (containers[child.tag] or child.tag=="field" or child.tag=="textarea" or child.tag=="list" or child.tag=="dropdown" or child.tag=="slider") and inner or intrinsic(child,inner,measure)
                    end
                    cw = math.min(inner, cw)
                    local offset = s["align-items"] == "center" and (inner-cw)/2 or s["align-items"] == "end" and inner-cw or 0
                    content_h = content_h + flow(child,cw,x+l+offset,y+t+content_h) + (i<#children and gap or 0)
                end
            end
        else
            local icon_w = node.icon and number(s,"icon-size",0,18) + (node.text and node.text~="" and 8 or 0) or 0
            node.lines = lines(node.text, math.max(1,inner-icon_w),s["font-size"],measure)
            content_h = math.max(#node.lines * s["font-size"] * (tonumber(s["line-height"]) or 1.55), node.icon and number(s,"icon-size",0,18) or 0)
            if tag=="field" or tag=="dropdown" then content_h = (node.label and node.label~="" and 26 or 0) + 42
            elseif tag=="textarea" then content_h = (node.label and node.label~="" and 26 or 0) + number(s,"height",0,120)
            elseif tag=="list" then content_h = math.max(44,math.min(6,#(node.items or {}))*34)
            elseif tag=="icon" then content_h = number(s,"icon-size",0,20) end
            if tag=="slider" then content_h=32 end
            if tag=="image" then content_h=number(s,"height",0,72) end
        end
        local height = math.max(number(s,"min-height"), content_h + t + b)
        if tag~="textarea" then height = math.max(height,number(s,"height")) end
        if containers[tag] and height > content_h+t+b and s["justify-content"] == "center" then
            for _, child in ipairs(node.children or {}) do M.translate(child,0,(height-content_h-t-b)/2) end
        end
        node.box = {x=x,y=y,w=width,h=height,padding={t,r,b,l}}
        if tag=="scroll" then
            node.content_height=height
            node.box.h=math.min(height,number(s,"max-height",0,360))
            return node.box.h
        end
        return height
    end
    return flow(root,available,0,0)
end
function M.translate(node,x,y)
    node.box.x,node.box.y=node.box.x+x,node.box.y+y
    for _, child in ipairs(node.children or {}) do if child.box then M.translate(child,x,y) end end
end
function M.validate(root)
    local errors={}
    local function check(node)
        local parent=node.box
        for i,child in ipairs(node.children or {}) do
            local b=child.box
            if b and b.w>0 and b.h>0 then
                local parent_h=node.tag=="scroll" and node.content_height or parent.h
                if b.x<parent.x-0.1 or b.y<parent.y-0.1 or b.x+b.w>parent.x+parent.w+0.1 or b.y+b.h>parent.y+parent_h+0.1 then
                    errors[#errors+1]="outside parent: "..(child.name or child.class or child.tag)
                end
                for j=1,i-1 do
                    local a=node.children[j].box
                    if a and a.w>0 and a.h>0 and b.x<a.x+a.w-0.1 and a.x<b.x+b.w-0.1 and b.y<a.y+a.h-0.1 and a.y<b.y+b.h-0.1 then
                        errors[#errors+1]="sibling overlap: "..(child.name or child.class or child.tag)
                    end
                end
                check(child)
            end
        end
    end
    check(root)
    return errors
end
return M
