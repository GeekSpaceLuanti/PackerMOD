describe("pack deletion", function()
    local saved_core, saved_pm, saved_dialog, modal, deleted, parent
    before_each(function()
        saved_core, saved_pm, saved_dialog = _G.core, _G.packermod, _G.dialog_create
        deleted = {}
        _G.core = { delete_dir = function(path) deleted[#deleted + 1] = path; return true end }
        _G.packermod = { user_path = "/user", pack_manager = dofile("mainmenu/pack_manager.lua") }
        _G.dialog_create = function(_, render, handler)
            modal = { data = {}, render = render, handler = handler,
                set_parent = function() end, show = function() end,
                delete = function(self) self.closed = true end }
            return modal
        end
        parent = { data = { view = "detail", selected_pack_id = "demo", packs = {} }, hide = function() end }
        dofile("mainmenu/dialogs/dlg_pack_delete.lua").show(parent, { id = "demo", manifest = { name = "Demo" } })
    end)
    after_each(function()
        _G.core, _G.packermod, _G.dialog_create = saved_core, saved_pm, saved_dialog
    end)
    it("does nothing before confirmation and when cancelled", function()
        assert.equal(0, #deleted)
        modal.handler(modal, { dlg_close = true, confirm_delete = true })
        assert.equal(0, #deleted)
        assert.equal("detail", parent.data.view)
    end)
    it("deletes only the selected pack and returns to a fresh library", function()
        modal.handler(modal, { confirm_delete = true })
        assert.same({ "/user/PackerMOD/packs/demo" }, deleted)
        assert.equal("grid", parent.data.view)
        assert.is_nil(parent.data.selected_pack_id)
        assert.is_nil(parent.data.packs)
        assert.is_true(modal.closed)
    end)
    it("keeps confirmation open on failure", function()
        core.delete_dir = function() return false end
        modal.handler(modal, { confirm_delete = true })
        assert.is_nil(modal.closed)
        assert.equal("detail", parent.data.view)
        assert.matches("Delete failed", modal.data.status)
    end)
    it("rejects paths outside the selected pack", function()
        for _, id in ipairs({ "", ".", "..", "../other", "a/b", "a\\b", "C:other" }) do
            assert.is_false(packermod.pack_manager.delete_pack("/user", id))
        end
        assert.equal(0, #deleted)
    end)
end)
