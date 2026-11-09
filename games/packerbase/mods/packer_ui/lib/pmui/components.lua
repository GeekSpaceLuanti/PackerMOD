return function(el)
    local M={}
    local function attributes(base,extra)
        for k,v in pairs(extra or {})do base[k]=v end
        return base
    end
    function M.text(value,extra)return el("p",attributes({text=value},extra))end
    function M.button(name,label,extra)return el("button",attributes({name=name,text=label,class="button"},extra))end
    function M.panel(children,extra)return el("section",attributes({class="panel"},extra),children)end
    function M.row(children,extra)return el("div",attributes({class="row"},extra),children)end
    function M.field(name,label,value,extra)return el("field",attributes({name=name,label=label,value=value},extra))end
    function M.dropdown(name,items,selected,extra)return el("dropdown",attributes({name=name,items=items,selected=selected},extra))end
    function M.slider(name,value,extra)return el("slider",attributes({name=name,value=value},extra))end
    function M.key_button(name,value,extra)return el("key-button",attributes({name=name,text=value},extra))end
    function M.toggle(name,checked,extra)return el("toggle",attributes({name=name,checked=checked},extra))end
    function M.tabs(items,selected)
        local tabs={}
        for _,item in ipairs(items)do
            local active=item.id==selected
            local children={M.button(item.name or item.id,item.label,{icon=item.icon,class="button tab "..(active and "active" or "")})}
            if item.count~=nil then children[#children+1]=M.text(tostring(item.count),{class="count"})end
            tabs[#tabs+1]=M.row(children,{class="row tab-group "..(active and "selected" or "")})
        end
        return el("nav",{class="row tabs"},tabs)
    end
    function M.empty(options)
        local children={el("div",{class="empty-icon"},{el("icon",{icon=options.icon or "box",class="icon"})}),
            M.text(options.title,{class="empty-title"}),M.text(options.description,{class="muted center"})}
        if options.action then children[#children+1]=options.action end
        return M.panel(children,{class="empty panel"})
    end
    return M
end
