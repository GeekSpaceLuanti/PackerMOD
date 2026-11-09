-- Disposable live ContentDB search in the regular create/edit UI.
local source = assert(core.settings:get("packermod_source_path"))
dofile(source .. "/mainmenu/init.lua")
assert(core.sha256 or core.sha1, "Engine has no cache hash function")
local library = packermod.library.dlg()
local create = core.settings:get("packermod_initial_create_step") == "mods"
local dialog = create and packermod.dialogs.dlg_create.show(library) or library
local prefetch = packermod.mod_catalog.prefetch
local verified
packermod.mod_catalog.prefetch = function(results, page, refresh)
    assert(#results > 0, "No MODs in live search")
    return prefetch(results, page, function()
        refresh()
        if verified then return end
        local cards = packermod.mod_catalog.view(results, page, 1)
        for _, card in ipairs(cards) do
            if card.loaded then
                local spec = assert(dialog:get_formspec())
                assert(spec:find(core.formspec_escape(card.image), 1, true), "Thumbnail missing in formspec")
                assert(spec:find("mod_result_1", 1, true), "Result card missing in formspec")
                assert(spec:find(create and "add_search" or "mod_add", 1, true), "Selected result details missing")
                verified = true
                if #results > 1 then
                    core.button_handler({ mod_result_2 = true })
                    assert((create and dialog.data.search_selected or dialog.data.selected_search) == 2,
                        "Result card selection did not change")
                    core.button_handler({ mod_result_1 = true })
                end
                core.log("action", "PackerMOD: live MOD thumbnail verified")
                return
            end
        end
    end)
end
dialog:handle_buttons(create and { search_query = "mesecons", search = true }
    or { search_query = "mesecons", do_search = true })
ui.update()
