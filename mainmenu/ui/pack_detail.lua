-- Product composition only. Geometry, components and painting belong to PMUI.
local P=(debug.getinfo(1,"S").source:sub(2):match("(.*[/\\])") or "./")
local gui=dofile(P.."../lib/pmui/modern/init.lua")
local M={}
local file=assert(io.open(P.."pack_detail.css","r"));local css=file:read("*a");file:close()
function M.render(c,host,t)
    t=t or function(s)return s end
    local el=gui.el
    local function text(value,class) return gui.components.text(value,{class=class}) end
    local function icon(name,class) return el("icon",{icon=name,class=class or "icon"}) end
    local function button(name,label,symbol,class) return gui.components.button(name,t(label),{icon=symbol,class="button "..(class or "")}) end
    local function row(children,class) return el("div",{class="row "..(class or "")},children) end
    local function field(name,label,value,class,tag) return el(tag or "field",{name=name,label=t(label),value=value,class=class or "field"}) end
    local function list(name,items,selected) return el("list",{name=name,items=items,selected=selected,class="list"}) end
    local function labels(items,fn)local out={};for _,v in ipairs(items)do out[#out+1]=fn(v)end;return out end
    local tabs, selected={},nil
    for _,tab in ipairs({{"worlds","Worlds","globe"},{"multi","Multiplayer","users"},{"mods","Mods","puzzle"},{"info","Info","info"}}) do
        local active=c["show_"..tab[1]]
        if active then selected=tab[1] end
        tabs[#tabs+1]={id=tab[1],name="subtab_"..tab[1],label=t(tab[2]),icon=tab[3],
            count=tab[1]=="worlds" and #c.worlds or tab[1]=="mods" and c.pack_mods_count or nil}
    end
    local content={}
    if c.show_worlds then
        content[#content+1]=row({el("div",{class="grow heading"},{text(t("Worlds"),"section-title"),text(t("Manage the worlds in this pack"),"muted")}),text(#c.worlds.." "..t("Worlds"),"muted")},"section-head")
        if c.no_world then
            content[#content+1]=gui.components.empty{icon="sprout",title=t("Create your first world"),
                description=t("No worlds yet.").."\n"..t("Create a new world to start playing."),
                action=button("new_world","New World","plus","primary")}
        else
            for i,w in ipairs(c.worlds) do
                content[#content+1]=row({el("div",{class="world-icon"},{icon("globe")}),
                    button("world_choose_"..i,c.format_world_label(w),nil,"world-name"),
                    button("world_play_"..i,"Play","play","primary")},"world-row panel "..(i==c.selected_world and "world-selected" or ""))
            end
            content[#content+1]=row({button("edit_world","Edit world",nil),button("delete_world","Delete","trash","danger")},"actions")
        end
        content[#content+1]=row({icon("folder"),text(t("Worlds are saved separately for each pack."),"muted")},"storage-note")
    elseif c.show_multi then
        content[#content+1]=text(t("Multiplayer"),"section-title")
        if c.has_server then content[#content+1]=list("serverlist",labels(c.servers,c.format_server_label),c.selected_server)
        else content[#content+1]=text(t("No servers yet. Fill the form below and press Add."),"muted") end
        content[#content+1]=row({field("server_name","Name",c.form_server_name,"field grow"),field("server_address","Address",c.form_server_address,"field grow"),field("server_port","Port",c.form_server_port,"port")},"form-row")
        local actions={button("server_add","Add","plus","primary")}
        if c.has_server then actions[#actions+1]=button("server_remove","Remove","trash","danger");actions[#actions+1]=button("server_connect","Connect","play","primary") end
        content[#content+1]=row(actions,"actions")
    elseif c.show_mods then
        content[#content+1]=text(t("Mods"),"section-title")
        content[#content+1]=row({field("search_query","Search ContentDB",c.search_query,"field grow"),field("search_release","Release",c.search_release,"port"),button("do_search","Search","search")},"form-row")
        if c.mod_status~="" then content[#content+1]=text(t(c.mod_status),"muted") end
        local current={text(t("Current"),"section-title")}
        if c.has_pack_mods then current[#current+1]=list("mod_list",labels(c.pack_mods,c.format_mod_entry),c.selected_mod)
        else current[#current+1]=text(t("No additional mods in this pack."),"muted") end
        if c.has_mod then current[#current+1]=button("mod_remove","Remove","trash","danger") end
        local results={text(t("Search results"),"section-title")}
        if c.has_search_results then results[#results+1]=list("search_results",labels(c.search_results,c.format_search_result),c.selected_search)
        else results[#results+1]=text(t("Search ContentDB to find mods."),"muted") end
        if c.has_search_result then results[#results+1]=button("mod_add","Add","plus","primary") end
        content[#content+1]=row({el("section",{class="mod-column panel grow"},current),el("section",{class="mod-column panel grow"},results)},"columns")
    else
        content[#content+1]=text(t("Info"),"section-title")
        content[#content+1]=el("section",{class="info-form panel"},{field("info_name","Name",c.pack_name),
            text("v"..c.pack_version.."  ·  "..c.pack_base.."  ·  "..c.pack_mods_count.." MOD","muted"),
            field("info_description","Description",c.pack_description,"description","textarea"),
            row({button("info_save","Save Changes","save","primary")},"actions")})
        if c.info_status~="" then content[#content+1]=text(t(c.info_status),"muted") end
        content[#content+1]=row({el("div",{class="grow"},{text(t("Delete Pack"),"subheading"),text(t("Deleting this pack also deletes its worlds."),"muted")}),button("delete_pack","Delete Pack","trash","danger")},"danger-zone")
    end
    local hero={el("div",{class="pack-icon panel"},{icon("box")}),el("div",{class="grow pack-heading"},{text("PACK LIBRARY","eyebrow"),text(c.pack_name,"pack-title"),
        row({text("v"..c.pack_version,"badge"),text(c.pack_base,"muted"),text("·","muted"),text(c.pack_mods_count.." MOD","muted")},"meta")})}
    if c.has_world and c.show_worlds then hero[#hero+1]=button("new_world","New World","plus","primary") end
    local tree=el("div",{class="app"},{row({el("div",{class="brand-icon"},{icon("box")}),text("PackerMOD","brand"),text(t("Library"),"brand-label")},"appbar"),
        el("main",{class="main"},{button("btn_back","Back to Library","back","link"),row(hero,"hero"),gui.components.tabs(tabs,selected),el("section",{class="content"},content)})})
    return gui.new(host):render{tree=tree,css=css,max_width=1040,scroll=c.layout_scroll,backdrop="#101418"}
end
return M
