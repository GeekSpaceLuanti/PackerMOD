-- Strict markup subset; bindings are substituted after parsing, never as HTML.
local M={}
local tags={div=true,main=true,header=true,footer=true,nav=true,section=true,p=true,h1=true,h2=true,h3=true,button=true,icon=true,field=true,textarea=true,list=true}
local attrs={id=true,class=true,name=true,icon=true,label=true,value=true}
for _,tag in ipairs({"dropdown","slider","key-button","toggle","scroll","image","status"})do tags[tag]=true end
attrs.variant=true;attrs.src=true
local function decode(s) return (s:gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"'):gsub("&apos;","'"):gsub("&amp;","&")) end
function M.parse(source,context)
    context=context or {}
    local stack,root={},nil
    local function bound(s) return (decode(s):gsub("%${([%w_]+)}",function(k)return tostring(context[k] or "")end)) end
    local function add_text(s)
        s=s:match("^%s*(.-)%s*$")
        if s=="" then return end
        local parent=assert(stack[#stack],"PMUI: text outside root")
        if parent.tag=="button" or parent.tag=="p" or parent.tag:match("^h%d$") or parent.tag=="textarea" then parent.text=(parent.text or "")..bound(s)
        else parent.children[#parent.children+1]={tag="p",text=bound(s),children={}} end
    end
    local pos=1
    while true do
        local first,last,token=source:find("<([^>]+)>",pos)
        if not first then add_text(source:sub(pos));break end
        add_text(source:sub(pos,first-1));pos=last+1
        if token:sub(1,1)=="/" then
            local closing=token:match("^/%s*([%w%-]+)%s*$")
            assert(stack[#stack] and stack[#stack].tag==closing,"PMUI: mismatched closing tag")
            stack[#stack]=nil
        else
            local tag=token:match("^([%w%-]+)")
            assert(tags[tag],"PMUI: unsupported HTML tag "..tostring(tag))
            local node={tag=tag,children={}}
            local rest=token:sub(#tag+1):gsub("/%s*$","")
            for name,value in rest:gmatch('([%w_%-]+)%s*=%s*"([^"]*)"') do
                assert(attrs[name],"PMUI: unsupported HTML attribute "..name)
                node[name]=bound(value)
            end
            local residue=rest:gsub('[%w_%-]+%s*=%s*"[^"]*"',""):gsub("%s","")
            assert(residue=="","PMUI: attributes require double quotes")
            if stack[#stack] then table.insert(stack[#stack].children,node) else assert(not root,"PMUI: one HTML root required");root=node end
            if token:sub(-1)~="/" then stack[#stack+1]=node end
        end
    end
    assert(#stack==0,"PMUI: unclosed HTML tag")
    return assert(root,"PMUI: empty HTML")
end
return M
