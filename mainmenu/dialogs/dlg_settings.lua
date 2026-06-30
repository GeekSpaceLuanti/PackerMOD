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
    local DD = DIR_DELIM or "/"
    local mm = packermod.mainmenu_path or ("mainmenu" .. DD)
    return packermod.pmui.build_formspec {
        html_path = mm .. "ui" .. DD .. "modal_settings.html.yml",
        css_path  = mm .. "ui" .. DD .. "themes" .. DD .. "synthwave.css.yml",
        ctx       = ctx,
        page_w = 30.0, page_h = 16.0,
        texture_dir = packermod.textures_dir,
    }
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
