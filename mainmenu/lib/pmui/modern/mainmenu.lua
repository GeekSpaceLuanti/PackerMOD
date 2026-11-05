-- Mainmenu adapter. Runtime and components remain independent of PackerMOD.
local P=(debug.getinfo(1,"S").source:sub(2):match("(.*[/\\])") or "./")
local M={}
local last_window
function M.host(defaults)
    return {defaults=defaults,
        get_window_info=function()
            if rawget(_G,"core") and core.get_window_info then
                local wi=core.get_window_info()
                if wi and wi.size and not wi.max_formspec_size then
                    local scale=wi.real_gui_scaling or (core.settings and tonumber(core.settings:get("gui_scaling"))) or 1
                    wi={size=wi.size,real_gui_scaling=scale,max_formspec_size={x=wi.size.x/(53.33*scale),y=wi.size.y/(53.33*scale)}}
                end
                if wi and wi.size and wi.size.x>0 and wi.size.y>0 and wi.max_formspec_size and wi.max_formspec_size.x>0 and wi.max_formspec_size.y>0 then
                    last_window=wi;return wi
                end
                if last_window then return last_window end
            end
            return {size={x=1024,y=768},max_formspec_size={x=19.2,y=14.4},real_gui_scaling=1}
        end,
        texture=function(name,color)return P.."textures/pmui_"..name..(color and "_"..color:gsub("#","") or "")..".png"end}
end
return M
