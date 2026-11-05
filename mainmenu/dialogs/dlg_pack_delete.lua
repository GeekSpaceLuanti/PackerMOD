local M = {}

local function get_formspec(data)
    local mm = packermod.mainmenu_path
    local fs = packermod.pmui.build_formspec {
        renderer = "modern", state = data,
        html_path = mm .. "ui/modal_pack_delete.html.yml",
        css_path = mm .. "ui/themes/synthwave.css.yml",
        ctx = {
            pack_name = data.pack.manifest.name or data.pack.id,
            status = data.status or "",
            icon_path = function(n) return packermod.icons.path(n, "md") end,
        },
        page_w = 30, page_h = 16,
        texture_dir = packermod.textures_dir,
    }
    return fs
end

local function handler(self, fields)
    if packermod.pmui and packermod.pmui.handle_fields and packermod.pmui.handle_fields(self.data, fields) then return false end
    if fields.dlg_close or fields.quit then
        self:delete()
        return true
    end
    if fields.confirm_delete then
        local ok, err = packermod.pack_manager.delete_pack(packermod.user_path, self.data.pack.id)
        if not ok then
            self.data.status = "Delete failed: " .. tostring(err or "Cannot delete pack")
            return true
        end
        local parent = self.data.library
        if parent then
            parent.data.view = "grid"
            parent.data.gui_scroll=0
            parent.data.selected_pack_id = nil
            parent.data.packs = nil
            parent.data.worlds = nil
        end
        self:delete()
        return true
    end
    return false
end

function M.show(parent, pack)
    if not pack then return end
    local dlg = dialog_create("packermod_dlg_pack_delete", get_formspec, handler, packermod.ui_window_event)
    dlg.data.pack = pack
    dlg.data.library = parent
    if parent then
        dlg:set_parent(parent)
        parent:hide()
    end
    dlg:show()
    return dlg
end

return M
