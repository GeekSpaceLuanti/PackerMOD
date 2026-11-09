-- Compatibility adapters retain control names and data; presentation is typed.
local P=(debug.getinfo(1,"S").source:sub(2):match("(.*[/\\])") or "./")
local ui=dofile(P.."init.lua")
local M={}
local icons={package="box",cube="box",["settings-2"]="settings"}
local function icon(name)
    if not name or name=="" then return nil end
    return icons[name] or name
end
local function children_without_spacers(node, key)
    local out={}
    for _,child in ipairs(node[key] or node)do if child.tag~="spacer" and child._kind~="Spacer" then out[#out+1]=child end end
    return out
end
local function unwrap(node,key)
    while true do
        local children=children_without_spacers(node,key)
        if #children~=1 then return node end
        local child=children[1]
        if key=="children" then
            if node.tag=="card" then return node end
            if not ({page=true,div=true,header=true,section=true})[node.tag] then return node end
        elseif node.bgcolor then return node end
        if not child.children and not child[1] then return node end
        node=child
    end
end
function M.dom(source)
    local function convert(old)
        local tag,a,box=old.tag,old.attrs or {},old.box or {}
        local classes=table.concat(old.classes or {}," ")
        if tag=="spacer" or classes:find("placeholder",1,true) then return nil end
        if (tag=="status" or tag=="span" or tag=="p" or tag=="paragraph") and (old.text or "")=="" then return nil end
        local attrs={id=old.id,name=a.name,text=old.text,label=a.label,value=a.value or a.default,selected=a.selected,items=a.items,variant=a.variant,checked=a.checked,inline={}}
        local class="ui-stack"
        if tag=="icon-button" or tag=="button" or tag=="key-button" or tag=="toggle" then
            attrs.text=a.label or old.text or ""
            if a.icon and (a.icon:find("/",1,true) or a.icon:find("\\",1,true) or a.icon:match("%.png$")) then
                tag="image";attrs.src=a.icon;attrs.name=nil;attrs._click_name=a.name
            else attrs.icon=icon(a.icon);tag=(tag=="key-button" or tag=="toggle") and tag or "button" end
            class=""
            if classes:find("primary",1,true) or box.bg=="#59D9AD" then attrs.variant="primary" end
            if classes:find("danger",1,true) then attrs.variant="danger" end
        elseif tag=="field" or tag=="textarea" or tag=="dropdown" or tag=="list" then
            if tag=="field" or tag=="textarea" then attrs.value=a.default end
            class=""
            if tag=="textarea" then attrs.inline.height=100 end
            if tag=="field" or tag=="dropdown" then attrs.inline["flex-grow"]=1;attrs.inline["min-width"]=140 end
            if classes:find("narrow",1,true) then attrs.inline.width=140;attrs.inline["flex-grow"]=0 end
        elseif tag=="scroll" then
            class="ui-stack";attrs.value=tonumber(a.value) or 0
        elseif tag=="img" then
            tag="image";attrs.src=a.src;class=""
            attrs.inline.width=tonumber(a.width);attrs.inline.height=tonumber(a.height)
        elseif tag=="paragraph" or tag=="span" or tag=="label" then tag="p";class=""
        elseif tag=="status" then class=""
        elseif tag:match("^h%d$") then class=""
        else
            if tag=="page" or tag=="card" then tag="section" end
            if box.flex_direction=="row" then class="row" end
            if box.display=="grid" then class="ui-grid" end
            if old.tag=="card" then class="panel ui-tile" end
            if a.panel then class=class.." ui-row-panel" end
            if classes:find("actions",1,true) or classes:find("action-bar",1,true) or classes:find("pagination",1,true) then class="ui-actions" end
            if classes:find("col",1,true) or classes:find("settings-editor",1,true) then class=class.." ui-column" end
        end
        if box.flex and box.flex>0 and tag~="button" and tag~="scroll" then attrs.inline["flex-grow"]=1;attrs.inline["min-width"]=140 end
        if classes:find("dim",1,true) or classes:find("meta",1,true) or classes:find("help",1,true) or classes:find("subtitle",1,true) then class=class.." muted" end
        if tag=="h2" and classes:find("title",1,true) then tag="h1" end
        attrs.class=class
        local children={}
        for _,child in ipairs(old.children or {})do local n=convert(child);if n then children[#children+1]=n end end
        local result=ui.el(tag,attrs,children)
        if old.tag=="card" then
            for _,child in ipairs(children)do if child._click_name then result.name=child._click_name;child._click_name=nil end end
        end
        return result
    end
    local original=unwrap(source,"children")
    local root=convert(original)
    root.class="app ui-dialog"
    root.preferred_width=original.box and original.box.w and original.box.w*32
    return root
end
function M.widgets(source)
    local function convert(w)
        if w._kind=="Spacer" or w._kind=="Raw" then return nil end
        local kind=w._kind
        local attrs={name=w.name,text=w.text or w.label,label=w.label,value=w.default or w.value,selected=w.selected,items=w.items,variant=w.variant,checked=w.checked,inline={}}
        local tag=({Label="p",Button="button",KeyButton="key-button",Field="field",TextArea="textarea",Dropdown="dropdown",Slider="slider",TextList="list",Image="image",Icon="image",Scroll="scroll"})[kind]
        if w.gui_type then tag=w.gui_type end
        if not tag then tag="div";attrs.class=kind=="HBox" and "row" or "ui-stack" end
        if tag=="p" then
            local value=(w.text or ""):gsub("\27%([^)]*%)","")
            if value=="" then return nil end
            attrs.text=value
            if (w.text or ""):find("#98A5B3",1,true) then attrs.class="muted" end
            local factor=tonumber(tostring(w.font_size or ""):match("%*([%d.]+)"))
            if factor and factor>=1.4 then tag="h1" elseif factor and factor>=1.15 then tag="h2" end
        end
        if w.bgcolor and tag=="div" then attrs.class=(attrs.class or "").." ui-row-panel" end
        if w.bgcolor=="#357B6B" or w.bgcolor=="#408F7A" then attrs.variant="primary" end
        if tag=="field" or tag=="textarea" then attrs.label=w.label or "" end
        if tag=="textarea" then attrs.inline.height=100 end
        if tag=="scroll" then attrs.value=w.value or 0 end
        if tag=="image" then attrs.src=w.texture end
        if w.flex and w.flex>0 then attrs.inline["flex-grow"]=1;attrs.inline["min-width"]=tag=="slider" and 80 or 120 end
        if w.w and w.w>0 and not w.flex and tag~="button" and tag~="key-button" and tag~="p" then attrs.inline.width=w.w*32 end
        local children={}
        for _,child in ipairs(w)do local n=convert(child);if n then children[#children+1]=n end end
        return ui.el(tag,attrs,children)
    end
    local root=convert(unwrap(source))
    root.class="app ui-dialog"
    root.inline.width=nil
    return root
end
return M
