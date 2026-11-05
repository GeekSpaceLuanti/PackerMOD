-- Disposable visual-test probe: derive click targets from rendered geometry.
local source=assert(core.settings:get("packermod_source_path"))
dofile(source.."/mainmenu/init.lua")
local path=assert(core.settings:get("packermod_gui_probe"))
local original=ui.update
local function probe()
    for _,dialog in pairs(ui.childlist)do
        local data=dialog.data
        local meta=data and data.gui_layout
        if not dialog.hidden and meta then
            local wi=core.get_window_info();local scale=wi.real_gui_scaling
            local ox=(wi.size.x-(meta.width+(meta.scroll and 16 or 0))*scale)/2
            local oy=(wi.size.y-meta.height*scale)/2
            local out={}
            if meta.scroll then
                out[#out+1]=table.concat({"pm_flow_scroll",math.floor(ox+(meta.width+9)*scale),math.floor(oy+meta.height*scale/2),math.floor(10*scale),math.floor(meta.height*scale),"scroll"},"\t")
            end
            local function visit(n,scroll,low,high)
                local b=n.box;if not b then return end
                local cy=b.y+b.h/2-scroll
                if n.name and n.tag~="scroll" and cy>=low and cy<=high then
                    local band=n.label and n.label~="" and (n.tag=="field" or n.tag=="dropdown") and 26 or 0
                    out[#out+1]=table.concat({n.name,math.floor(ox+(b.x+b.w/2)*scale),math.floor(oy+(cy+band/2)*scale),math.floor(b.w*scale),math.floor(b.h*scale),n.tag},"\t")
                end
                if n.tag=="scroll" and n.content_height>b.h then
                    low,high=math.max(low,b.y-scroll),math.min(high,b.y+b.h-scroll)
                    local max=math.ceil((n.content_height-b.h)/8)
                    scroll=scroll+math.max(0,math.min(max,n.value or 0))*8
                end
                for _,child in ipairs(n.children or {})do visit(child,scroll,low,high)end
            end
            visit(meta.tree,(meta.scroll and data.gui_scroll or 0)*8,0,meta.height)
            local file=assert(io.open(path,"w"));file:write(table.concat(out,"\n"));file:close()
        end
    end
end
ui.update=function(...)local result=original(...);probe();return result end
local buttons=core.button_handler
core.button_handler=function(fields)local result=buttons(fields);probe();return result end
ui.update()
