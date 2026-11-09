local source = assert(core.settings:get("packermod_source_path"))
dofile(source .. "/mainmenu/init.lua")
local library = packermod.library.dlg()
local original = core.event_handler
core.event_handler = function(event)
    local was_detail = library.data.view == "detail"
    original(event)
    if event ~= "MenuQuit" then return end
    assert(ui.childlist[ui.default] == library, "ESC deleted the default Library")
    assert(library.data.view == "grid", "ESC did not return to the Library")
    core.log("action", was_detail and "PackerMOD: ESC returned to Library" or "PackerMOD: ESC closed Library")
end
