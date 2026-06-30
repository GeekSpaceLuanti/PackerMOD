-- Delete World 確認 modal。subdir / legacy flat 両方に対応。

local M = {}

local function get_formspec(data)
    local world = data.world or {}
    local display = world.display_name or world.name or "?"
    if world.legacy then display = "[legacy] " .. display end
    local ctx = {
        pack_name     = data.pack_name or "",
        world_display = display,
        status        = data.status or "",
        icon_path     = function(n) return packermod.icons.path(n, "md") end,
    }
    if os.getenv("PACKERMOD_LEGACY_MODALS") then
        return packermod.ui_loader.build_tab_formspec(
            packermod.ui_loader.ui_yaml_path("modal_world_delete"),
            ctx,
            { version = 6, theme = packermod.theme }
        )
    end
    local DD = DIR_DELIM or "/"
    local mm = packermod.mainmenu_path or ("mainmenu" .. DD)
    return packermod.pmui.build_formspec {
        html_path = mm .. "ui" .. DD .. "modal_world_delete.html.yml",
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
    if fields.confirm_delete then
        local ok, err = packermod.launcher.delete_world(data.pack, data.world)
        if not ok then
            data.status = "Delete failed: " .. tostring(err)
            return true
        end
        self:delete()
        return true
    end
    return false
end

function M.show(parent, pack, world)
    local dlg = dialog_create("packermod_dlg_world_delete", get_formspec, handler, nil)
    dlg.data.pack = pack
    dlg.data.pack_name = pack and pack.manifest and pack.manifest.name or ""
    dlg.data.world = world
    dlg.data.status = ""
    if parent then
        dlg:set_parent(parent)
        parent:hide()
    end
    dlg:show()
end

return M
