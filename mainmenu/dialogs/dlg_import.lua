-- Import dialog (Phase 11). Library 左下の [Import] ボタンから開く。
-- 旧 tabs/tab_import.lua のロジックを dialog 形式に移植。

local M = {}

local function get_formspec(data)
    local ctx = {
        source    = data.source or "",
        status    = data.status or "",
        icon_path = function(n) return packermod.icons.path(n, "md") end,
    }
    local DD = DIR_DELIM or "/"
    local mm = packermod.mainmenu_path or ("mainmenu" .. DD)
    local fs = packermod.pmui.build_formspec {
        renderer = "modern", state = data,
        html_path = mm .. "ui" .. DD .. "modal_import.html.yml",
        css_path  = mm .. "ui" .. DD .. "themes" .. DD .. "synthwave.css.yml",
        ctx       = ctx,
        page_w = 30.0, page_h = 16.0,
        texture_dir = packermod.textures_dir,
    }
    return fs
end

local function handler(self, fields)
    if packermod.pmui and packermod.pmui.handle_fields and packermod.pmui.handle_fields(self.data, fields) then return false end
    local data = self.data
    if fields.dlg_close or fields.quit then
        self:delete()
        return true
    end
    if fields.source ~= nil then data.source = fields.source end
    if fields.import then
        local src = (data.source or ""):match("^%s*(.-)%s*$")
        if src == "" then
            data.status = "Enter a URL or local path first."
            return true
        end
        local ok, id_or_err = packermod.importer.import(src)
        if ok then
            data.status = "Imported pack: " .. tostring(id_or_err)
            data.source = ""
        else
            data.status = "Import failed: " .. tostring(id_or_err)
        end
        return true
    end
    return false
end

function M.show(parent)
    local dlg = dialog_create("packermod_dlg_import", get_formspec, handler, packermod.ui_window_event)
    if parent then
        dlg:set_parent(parent)
        parent:hide()
    end
    dlg:show()
end

return M
