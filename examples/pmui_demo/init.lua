-- Install alongside the standalone pmui mod. No PackerMOD dependency.
local states={}
local html=[[
<section class="app">
  <header class="header"><icon icon="box"/><h1>PMUI</h1><p>Standalone MOD example</p></header>
  <main class="body">
    <h2>A portable GUI for your MOD</h2>
    <p>CSS-sized text, rounded surfaces and responsive layout.</p>
    <section class="panel">
      <field name="world_name" label="World name" value="${name}"/>
      <p>${status}</p>
      <nav class="actions"><button name="save" icon="save">Save</button><button name="close">Close</button></nav>
    </section>
  </main>
</section>]]
local css=[[
:root { --green: #A0DFBB; --input: #151B20; --border: #333E39; }
.app { background: #151A1F; border-radius: 24px; border-width: 1px; border-color: var(--border); }
.header { flex-direction: row; align-items: center; gap: 16px; padding: 24px; background: #1D2429; border-radius: 24px; }
.header icon { width: 24px; icon-size: 24px; color: var(--green); }
h1 { font-size: 24px; font-weight: bold; }
h2 { font-size: 22px; font-weight: bold; }
.body { padding: 24px; gap: 20px; }
.panel { padding: 24px; gap: 16px; background: #1D2429; border-width: 1px; border-color: var(--border); border-radius: 16px; }
.actions { flex-direction: row; flex-wrap: wrap; gap: 12px; justify-content: end; }
button { padding: 10px 16px; min-height: 44px; background: var(--green); color: #102A1D; border-radius: 8px; }
@media (max-width: 500px) { .header { padding: 16px; } .body { padding: 16px; } }
]]
local function show(player)
    local name=player:get_player_name()
    local state=states[name] or {name="My world",status="Changes are local to this demonstration.",scroll=0}
    states[name]=state
    local wi=core.get_player_window_information(name)
    if not wi then return false end
    state.active=true
    state.window_key=wi.size.x..":"..wi.size.y..":"..wi.real_gui_scaling
    local fs=pmui.new():render{html=html,context=state,css=css,window=wi,max_width=800,scroll=state.scroll}
    core.show_formspec(name,"pmui_demo:main",fs)
    return true
end
core.register_chatcommand("pmui_demo",{description="Open the standalone PMUI demonstration",func=function(name)
    return show(assert(core.get_player_by_name(name))),""
end})
core.register_on_player_receive_fields(function(player,formname,fields)
    if formname~="pmui_demo:main" then return false end
    local state=states[player:get_player_name()]
    if not state then return true end
    if fields.world_name then state.name=fields.world_name end
    if fields.pm_flow_scroll then state.scroll=tonumber(fields.pm_flow_scroll:match("%a+:(%d+)")) or state.scroll end
    if fields.quit or fields.close then state.active=false;core.close_formspec(player:get_player_name(),formname);return true end
    if fields.save then state.status="Saved: "..state.name;show(player) end
    return true
end)
core.register_on_leaveplayer(function(player)states[player:get_player_name()]=nil end)
local elapsed=0
core.register_globalstep(function(dt)
    elapsed=elapsed+dt;if elapsed<0.5 then return end;elapsed=0
    for name,state in pairs(states) do
        if state.active then
            local wi=core.get_player_window_information(name)
            local key=wi and (wi.size.x..":"..wi.size.y..":"..wi.real_gui_scaling)
            if key and key~=state.window_key then
                local player=core.get_player_by_name(name);if player then show(player) end
            end
        end
    end
end)
pmui_demo={show=show}
