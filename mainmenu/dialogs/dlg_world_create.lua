-- New World modal: 名前を入力して Create & Play で起動する。
-- show(parent, pack) で開く。pack はクロージャで保持。

local M = {}

local function get_formspec(data)
    local ctx = {
        pack_name  = data.pack_name or "",
        world_name = data.world_name or "",
        status     = data.status or "",
        icon_path  = function(n) return packermod.icons.path(n, "md") end,
    }
    return packermod.ui_loader.build_tab_formspec(
        packermod.ui_loader.ui_yaml_path("modal_world_create"),
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
    if fields.world_name ~= nil then data.world_name = fields.world_name end
    if fields.confirm_create then
        local pack = data.pack
        local raw = (data.world_name or ""):match("^%s*(.-)%s*$")
        if raw == "" then
            data.status = "Enter a world name first."
            return true
        end
        local ok, info = packermod.launcher.new_world(pack, { world_name = raw })
        if not ok then
            data.status = "Create failed: " .. tostring(info)
            return true
        end
        -- 作成成功 → modal を閉じてから起動する。
        -- 起動は親 library 画面の launch_existing と同じ流れ:
        --   prepare_launch → core.start
        self:delete()
        local link_name, err = packermod.launcher.prepare_launch({
            path = info.world_path, name = info.world_name,
        })
        if not link_name then
            gamedata.errormessage = "Could not prepare launch: " .. tostring(err)
            return true
        end
        local worlds = core.get_worlds() or {}
        for i, w in ipairs(worlds) do
            if w.name == link_name then
                gamedata.selected_world = i
                gamedata.singleplayer = true
                core.settings:set("menu_last_game", info.gameid)
                core.start()
                return true
            end
        end
        gamedata.errormessage = "Could not locate launch link: " .. link_name
        return true
    end
    return false
end

function M.show(parent, pack)
    local dlg = dialog_create("packermod_dlg_world_create", get_formspec, handler, nil)
    dlg.data.pack = pack
    dlg.data.pack_name = pack and pack.manifest and pack.manifest.name or ""
    dlg.data.world_name = ""
    dlg.data.status = ""
    if parent then
        dlg:set_parent(parent)
        parent:hide()
    end
    dlg:show()
end

return M
