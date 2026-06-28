-- Settings dialog (Phase 11). Library 左下の [Settings] ボタンから開く。
-- 旧 tabs/tab_settings.lua のロジックを dialog 形式に移植。

local M = {}

local function get_formspec(data)
    local ctx = {
        user_path      = packermod.user_path,
        version        = PACKERMOD_VERSION,
        luanti_version = (core.get_version and core.get_version().string) or "?",
        status         = data.status or "",
        icon_path      = function(n) return packermod.icons.path(n, "md") end,
    }
    return packermod.ui_loader.build_tab_formspec(
        packermod.ui_loader.ui_yaml_path("modal_settings"),
        ctx,
        { version = 6, theme = packermod.theme }
    )
end

local function handler(self, fields)
    local data = self.data
    if fields.dlg_close or fields.quit then
        self:delete()
        return true
    end
    if fields.open_luanti_settings then
        data.status = "Luanti core settings dialog: planned."
        return true
    end
    return false
end

function M.show(parent)
    local dlg = dialog_create("packermod_dlg_settings", get_formspec, handler, nil)
    if parent then
        dlg:set_parent(parent)
        parent:hide()
    end
    dlg:show()
end

return M
