-- PMUI 2: portable, CSS-pixel based formspec UI. No PackerMOD globals.
local P = (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./")
local styles, layout = dofile(P.."style.lua"), dofile(P.."layout.lua")
local M = { version = "2.0.0" }
M.parse_html=dofile(P.."html.lua").parse
function M.el(tag, attributes, children)
    local node = {tag=tag, children=children or {}}
    for key,value in pairs(attributes or {}) do node[key]=value end
    if node.variant then
        assert(({primary=true,danger=true,quiet=true,normal=true})[node.variant],"PMUI: unsupported variant")
        node.class=(node.class or "").." "..node.variant
    end
    if tag=="toggle" then node.text=node.text or (node.checked and "ON" or "OFF");if node.checked then node.class=(node.class or "").." primary" end end
    return node
end
M.components=dofile(P.."components.lua")(M.el)
M.default_css=dofile(P.."theme.lua")
local function clone(value)
    if type(value)~="table" then return value end
    local out={}; for key,item in pairs(value) do if key~="parent" then out[key]=clone(item) end end
    return out
end
local function esc(value) return (tostring(value or ""):gsub("([\\%[%]%;,$])","\\%1")) end
local function f(value) return ("%.4f"):format(value):gsub("0+$",""):gsub("%.$","") end
local function radii(value)
    local radius=tonumber(value) or tonumber(tostring(value):match("[%d.]+")) or 0
    if radius<=0 then return 0 end
    return radius<=8 and 8 or radius<=12 and 12 or radius<=16 and 16 or 24
end
function M.new(host)
    host=host or {}
    local defaults=clone(host.defaults or {})
    local instance={}
    function instance:configure(tag,properties)
        assert(({button=true,field=true,textarea=true,dropdown=true,slider=true,["key-button"]=true,toggle=true})[tag],"PMUI: unsupported control type")
        local entries={};for k,v in pairs(properties)do entries[#entries+1]=k..":"..tostring(v)..";" end
        styles.parse(tag.." {"..table.concat(entries).."}")
        defaults[tag]=clone(properties)
        return self
    end
    function instance:render(options)
        local wi=options.window or (host.get_window_info and host.get_window_info()) or {
            size={x=1024,y=768},max_formspec_size={x=19.2,y=14.4},real_gui_scaling=1 }
        assert(wi.size and wi.size.x>0 and wi.size.y>0,"PMUI: valid window size required")
        local scale=math.max(0.25,wi.real_gui_scaling or 1)
        local max=assert(wi.max_formspec_size,"PMUI: host must supply max_formspec_size")
        assert(max.x>0 and max.y>0,"PMUI: positive max_formspec_size required")
        local unit_px=math.max(wi.size.x/max.x,wi.size.y/max.y)
        local u=scale/unit_px
        local available_w=math.max(1,(max.x-0.5)/u)
        local available_h=math.max(1,(max.y-0.5)/u)
        local width=math.min(options.max_width or 1120,available_w)
        local root=clone(options.tree or M.parse_html(assert(options.html,"PMUI: tree or html required"),options.context))
        local configured={}
        for tag,properties in pairs(defaults)do
            local entries={};for key,value in pairs(properties)do entries[#entries+1]=key..":"..tostring(value)..";" end
            configured[#configured+1]=tag.." {"..table.concat(entries).."}"
        end
        local sheet=styles.parse((options.theme==false and "" or M.default_css)..table.concat(configured)..(options.css or ""))
        styles.apply(root,sheet,width,defaults)
        local root_width=math.min(width,styles.length(root.style.width,width,root.style["font-size"]) or width,
            styles.length(root.style["max-width"],width,root.style["font-size"]) or width)
        if root_width<width then width=root_width;styles.apply(root,sheet,width,defaults) end
        local natural_h=layout.compute(root,width,host.measure_text)
        local scroll=natural_h>available_h
        if scroll then
            width=width-16
            styles.apply(root,sheet,width,defaults)
            natural_h=layout.compute(root,width,host.measure_text)
        end
        local height=math.min(natural_h,available_h)
        local out={"formspec_version[6]","size["..f((width+(scroll and 16 or 0))*u)..","..f(height*u).."]","padding[0,0]",
            "bgcolor["..(options.backdrop or "#101418")..";both;"..(options.backdrop or "#101418").."]"}
        local asset=host.texture or function(name,color) return "pmui_"..name..".png"..(color and "^[multiply:"..color or "") end
        local function tex(name,color) return asset(name,color) end
        local function rect(kind,x,y,w,h,tail)
            out[#out+1]=kind.."["..f(x*u)..","..f(y*u)..";"..f(w*u)..","..f(h*u)..";"..tail.."]"
        end
        local function surface(box,s)
            local radius=radii(s["border-radius"])
            local border=styles.length(s["border-width"],0) or 0
            if s.background and s.background~="transparent" then
                if radius>0 then rect("image",box.x,box.y,box.w,box.h,esc(tex("round_"..radius,s.background))..";"..(radius+2))
                else rect("box",box.x,box.y,box.w,box.h,s.background) end
            end
            if border>0 and s["border-color"] then
                if radius>0 then rect("image",box.x,box.y,box.w,box.h,esc(tex("outline_"..radius,s["border-color"]))..";"..(radius+2))
                else
                    rect("box",box.x,box.y,box.w,border,s["border-color"]);rect("box",box.x,box.y+box.h-border,box.w,border,s["border-color"])
                    rect("box",box.x,box.y,border,box.h,s["border-color"]);rect("box",box.x+box.w-border,box.y,border,box.h,s["border-color"])
                end
            end
            local bottom=styles.length(s["border-bottom-width"],0) or 0
            if bottom>0 then rect("box",box.x,box.y+box.h-bottom,box.w,bottom,s["border-bottom-color"] or s["border-color"] or s.color) end
        end
        local function text(value,x,y,font,color,bold)
            out[#out+1]="style_type[label;font_size="..f(font)..";font="..(bold and "bold" or "normal").."]"
            out[#out+1]="label["..f(x*u)..","..f(y*u)..";"..esc("\27(c@"..color..")"..value).."]"
        end
        local function paint(node,offset_x,offset_y)
            offset_x,offset_y=offset_x or 0,offset_y or 0
            local s,tag=node.style,node.tag
            local b={};for k,v in pairs(node.box or {})do b[k]=v end
            b.x,b.y=(b.x or 0)+offset_x,(b.y or 0)+offset_y
            if not b or s.display=="none" then return end
            if tag~="field" and tag~="textarea" and tag~="dropdown" then surface(b,s) end
            local font=s["font-size"]
            local bold=s["font-weight"]=="bold" or tonumber(s["font-weight"]) and tonumber(s["font-weight"])>=600
            local t,r,bottom,l=unpack(b.padding)
            local x,y=b.x+l,b.y+t
            local name=node.name or node.id or ""
            assert(name=="" or name:match("^[%w_:%.%-]+$"),"PMUI: invalid control name")
            if layout.is_container(node) then
                if tag=="scroll" and node.content_height>b.h then
                    local maximum=math.max(1,math.ceil((node.content_height-b.h)/8))
                    out[#out+1]="scrollbaroptions[min=0;max="..maximum..";smallstep=3;largestep=12;thumbsize="..math.max(1,math.floor(maximum*b.h/node.content_height)).."]"
                    rect("scrollbar",b.x+b.w-12,b.y,10,b.h,"vertical;"..name..";"..math.max(0,math.min(maximum,node.value or 0)))
                    rect("scroll_container",b.x,b.y,b.w-16,b.h,name..";vertical;"..f(8*u))
                    for _,child in ipairs(node.children)do paint(child,-node.box.x,-node.box.y)end
                    out[#out+1]="scroll_container_end[]"
                else
                    if node.name and tag~="scroll" then
                        out[#out+1]="style["..name..";border=false;bgimg="..esc(asset("transparent")).."]"
                        rect("button",b.x,b.y,b.w,b.h,name..";")
                    end
                    for _,child in ipairs(node.children)do paint(child,offset_x,offset_y)end
                end
                return
            end
            if tag=="image" then rect("image",x,y,b.w-l-r,b.h-t-bottom,esc(node.src));return end
            if tag=="item-button" then
                out[#out+1]="style["..esc(name)..";border=false;bgimg="..esc(asset("transparent"))..";padding=2]"
                out[#out+1]="style["..esc(name)..":hovered;bgimg="..esc(tex("round_8",node.hover or "#64826F"))..";bgimg_middle=0]"
                rect("item_image_button",x,y,b.w-l-r,b.h-t-bottom,esc(node.item)..";"..esc(name)..";"..esc(node.text))
                if node.tooltip then
                    out[#out+1]="tooltip["..esc(name)..";"..esc(node.tooltip).."]"
                end
                return
            end
            if tag=="field" or tag=="textarea" or tag=="dropdown" then
                local label_h=node.label and node.label~="" and 26 or 0
                if label_h>0 then text(node.label,x,y+font*0.7,font,s.color,bold) end
                local control={x=x,y=y+label_h,w=b.w-l-r,h=b.h-t-bottom-label_h}
                surface(control,{background=s.background or node.vars["--input"] or "#151B20",["border-radius"]=s["border-radius"] or 8,
                    ["border-width"]=s["border-width"] or 1,["border-color"]=s["border-color"] or node.vars["--border"] or "#35403C"})
                out[#out+1]="style["..name..";border=false;textcolor="..s.color..";font_size="..f(font).."]"
                if tag=="dropdown" then
                    local items={};for _,item in ipairs(node.items or {})do items[#items+1]=esc(item)end
                    rect("dropdown",control.x,control.y,control.w,control.h,name..";"..table.concat(items,",")..";"..(node.selected or 1)..";true")
                else rect(tag,control.x+10,control.y+(tag=="textarea" and 8 or 0),control.w-20,control.h-(tag=="textarea" and 16 or 0),name..";;"..esc(node.value)) end
                if tag=="field" then out[#out+1]="field_close_on_enter["..name..";false]" end
                return
            elseif tag=="slider" then
                out[#out+1]="scrollbaroptions[min=0;max=1000;smallstep=10;largestep=100;thumbsize=100;arrows=hide]"
                rect("scrollbar",b.x,b.y+(b.h-24)/2,b.w,24,"horizontal;"..name..";"..math.max(0,math.min(1000,tonumber(node.value) or 0)))
                return
            elseif tag=="list" then
                local items={};for _,item in ipairs(node.items or {}) do items[#items+1]=esc(item) end
                out[#out+1]="style["..name..";font_size="..f(font)..";textcolor="..s.color.."]"
                rect("textlist",x,y,b.w-l-r,b.h-t-bottom,name..";"..table.concat(items,",")..";"..(node.selected or 1)..";true")
                return
            elseif tag=="button" or tag=="key-button" or tag=="toggle" then
                out[#out+1]="style["..name..";border=false;bgimg="..esc(asset("transparent"))..";bgimg_middle=0;sound=]"
                local hover=node.hover or (s.background~="transparent" and s.background) or "#2A3A33"
                out[#out+1]="style["..name..":hovered;bgimg="..esc(tex("round_8",hover))..";bgimg_middle=10]"
                if tag=="key-button" then
                    out[#out+1]="style["..name..";font_size="..f(font)..";textcolor="..s.color.."]"
                    rect("button_key",b.x,b.y,b.w,b.h,name..";"..esc(node.text));return
                end
                rect("button",b.x,b.y,b.w,b.h,name..";")
            end
            local icon_size=styles.length(s["icon-size"],0,font) or 18
            local icon_width=node.icon and icon_size+(node.text and node.text~="" and 8 or 0) or 0
            if tag=="icon" then icon_width=icon_size end
            local line_height=font*(tonumber(s["line-height"]) or 1.55)
            local content_height=math.max(#(node.lines or {})*line_height,node.icon and icon_size or 0)
            if tag=="button" or tag=="icon" or tag=="toggle" then y=b.y+(b.h-content_height)/2 end
            local line_w=layout.text_width(node.text or "",font,host.measure_text)+icon_width
            if s["text-align"]=="center" then x=b.x+(b.w-line_w)/2
            elseif s["text-align"]=="right" then x=b.x+b.w-r-line_w end
            if node.icon then
                rect("image",x,y+(content_height-icon_size)/2,icon_size,icon_size,esc(tex("icon_"..node.icon,s.color)))
                x=x+icon_width
            end
            if tag~="icon" then
                for i,line in ipairs(node.lines or {}) do
                    local lx=x
                    if s["text-align"]=="center" and not node.icon then lx=b.x+(b.w-layout.text_width(line,font,host.measure_text))/2 end
                    if s["text-align"]=="right" and not node.icon then lx=b.x+b.w-r-layout.text_width(line,font,host.measure_text) end
                    text(line,lx,y+(i-1)*line_height+line_height/2,font,s.color,bold)
                end
            end
        end
        if scroll then
            local maximum=math.max(1,math.ceil((natural_h-height)/8))
            local value=math.max(0,math.min(maximum,options.scroll or 0))
            out[#out+1]="scrollbaroptions[min=0;max="..maximum..";smallstep=3;largestep=12;thumbsize="..math.max(1,math.floor(maximum*height/natural_h)).."]"
            rect("scrollbar",width+4,0,10,height,"vertical;pm_flow_scroll;"..value)
            rect("scroll_container",0,0,width,height,"pm_flow_scroll;vertical;"..f(8*u))
        end
        paint(root)
        if scroll then out[#out+1]="scroll_container_end[]" end
        return table.concat(out,""),{tree=root,width=width,height=height,content_height=natural_h,scroll=scroll,unit_per_px=u}
    end
    return instance
end
M.styles, M.layout = styles,layout
-- When installed as a normal Luanti mod, expose its public API.
if rawget(_G,"core") and core.get_current_modname and core.get_current_modname()=="pmui" then _G.pmui=M end
return M
