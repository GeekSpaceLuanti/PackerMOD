PACKERMOD_VERSION = "0.1.0"

-- Phase 12 以前は PACKERMOD_TAB_W/H / MAIN_TAB_W/H / TABHEADER_H /
-- GAMEBAR_* を global に持っていたが、tabview を撤廃したので削除。
-- library.yml / modal_*.yml が画面サイズを hard-coded で持つ。

local function script_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("(.*[/\\])") or ("." .. DIR_DELIM)
end

local self_path = script_dir()
local basepath = core.get_builtin_path()

-- Luanti のメインメニューは formspec の image[…] の name を
-- <share>/textures/base/pack/<name>.png でしか解決しない(read-only)。
-- PackerMOD は同梱テクスチャを <install>/PackerMOD/textures/ に配置し、
-- formspec へは絶対パスで渡すことで上記制限を回避する。
-- install/install.sh が <repo>/textures を <user>/PackerMOD/textures に
-- 配置している前提。
-- self_path = ".../PackerMOD/mainmenu/" から親を直接構築する。
-- ".." を挟むと Windows の Irrlicht が正規化せず open 失敗するため。
local parent_dir = self_path:match("^(.*[/\\])[^/\\]+[/\\]$")
                       or (self_path .. ".." .. DIR_DELIM)
local textures_dir = parent_dir .. "textures" .. DIR_DELIM

defaulttexturedir = core.get_texturepath_share() .. DIR_DELIM .. "base" ..
                    DIR_DELIM .. "pack" .. DIR_DELIM

dofile(basepath .. "common" .. DIR_DELIM .. "menu.lua")
dofile(basepath .. "common" .. DIR_DELIM .. "filterlist.lua")
dofile(basepath .. "fstk" .. DIR_DELIM .. "dialog.lua")
dofile(basepath .. "fstk" .. DIR_DELIM .. "tabview.lua")
dofile(basepath .. "fstk" .. DIR_DELIM .. "ui.lua")

package.path = self_path .. "?.lua;" .. package.path

local yaml = dofile(self_path .. "yaml.lua")
local manifest_mod = dofile(self_path .. "manifest.lua")
local world_builder = dofile(self_path .. "world_builder.lua")
local pack_manager = dofile(self_path .. "pack_manager.lua")
local contentdb_mod = dofile(self_path .. "contentdb.lua")
local mod_installer = dofile(self_path .. "mod_installer.lua")
local pack_launcher = dofile(self_path .. "pack_launcher.lua")
local server_list = dofile(self_path .. "server_list.lua")
local pack_importer = dofile(self_path .. "pack_importer.lua")
local pack_builder = dofile(self_path .. "pack_builder.lua")
local pack_editor = dofile(self_path .. "pack_editor.lua")
local layout = dofile(self_path .. "lib" .. DIR_DELIM .. "layout.lua")
local theme = dofile(self_path .. "lib" .. DIR_DELIM .. "theme.lua")
local icons = dofile(self_path .. "lib" .. DIR_DELIM .. "icons.lua")

-- Dev/test hook: packermod_fixture_root = <dir> で user_path を差し替え、
-- 決定論的な pack 集合 (0 個の empty state / N 個の grid) でデザイン検証する。
-- fixture は <dir>/PackerMOD/packs/<id>/manifest.yaml を持つ。通常起動では未設定。
local user_path = core.get_user_path()
local fixture_root = core.settings and core.settings:get("packermod_fixture_root")
if fixture_root and fixture_root ~= "" then
    user_path = fixture_root
end
local fs = world_builder._default_fs()
local client = contentdb_mod.new()
local installer = mod_installer.new({
    fs = fs,
    contentdb_client = client,
    cache_dir = user_path .. DIR_DELIM .. "PackerMOD" .. DIR_DELIM .. "cache",
})
local launcher = pack_launcher.new({
    user_path = user_path,
    world_builder = world_builder,
    mod_installer = installer,
    pack_manager = pack_manager,
    server_list = server_list,
})
local importer = pack_importer.new({
    fs = fs,
    user_path = user_path,
    manifest = manifest_mod,
    contentdb_client = client,
})
packermod = {
    yaml = yaml,
    manifest = manifest_mod,
    world_builder = world_builder,
    pack_manager = pack_manager,
    contentdb_mod = contentdb_mod,
    mod_installer_mod = mod_installer,
    pack_launcher_mod = pack_launcher,
    server_list = server_list,
    pack_editor = pack_editor,
    pack_importer_mod = pack_importer,
    pack_builder = pack_builder,
    layout = layout,
    theme = theme,
    icons = icons,
    user_path = user_path,
    textures_dir = textures_dir,
    fs = fs,
    client = client,
    installer = installer,
    launcher = launcher,
    importer = importer,
}

-- ui_loader is loaded after the packermod table so it can read packermod.layout.
packermod.ui_loader = dofile(self_path .. "lib" .. DIR_DELIM .. "ui_loader.lua")

-- PMUI: HTML/CSS 風 UI ライブラリ。画面1 (Pack Library) で使用。
packermod.mainmenu_path = self_path
packermod.pmui = dofile(self_path .. "lib" .. DIR_DELIM .. "pmui" .. DIR_DELIM .. "init.lua")
-- アクティブテーマ。default thumbnail などテーマ依存アセットの命名規則で参照される。
-- 切り替えは将来 packermod.active_theme = <name> で済むよう、ここで一箇所に集約する。
packermod.active_theme = "synthwave"

-- Phase 8+: Library 単一画面。
local library = dofile(self_path .. "library.lua")
packermod.library = library

-- Phase 11: Import / Create / Settings は Library 左下のボタンから
-- 開く modal dialog として実装。dialogs/ 配下に分離。
packermod.dialogs = {
    dlg_import        = dofile(self_path .. "dialogs" .. DIR_DELIM .. "dlg_import.lua"),
    dlg_create        = dofile(self_path .. "dialogs" .. DIR_DELIM .. "dlg_create.lua"),
    dlg_settings      = dofile(self_path .. "dialogs" .. DIR_DELIM .. "dlg_settings.lua"),
    dlg_world_create  = dofile(self_path .. "dialogs" .. DIR_DELIM .. "dlg_world_create.lua"),
    dlg_world_delete  = dofile(self_path .. "dialogs" .. DIR_DELIM .. "dlg_world_delete.lua"),
}

local function init()
    pack_manager.ensure_dirs(packermod.user_path)

    -- 前回プレイで作った起動用 symlink (worlds/_pm_*) を掃除する。
    -- ln -s / mklink /J で作っているのでリンク先(本物の world)は無事。
    pack_launcher.cleanup_symlinks(packermod.user_path)

    -- Dev hook: packermod_dev_screen = <lua ファイルの絶対パス> で実験用画面を
    -- 起動する (エンジン挙動の実測・検証用)。packermod_initial_subtab と同系統。
    local dev_screen = core.settings and core.settings:get("packermod_dev_screen")
    if dev_screen and dev_screen ~= "" then
        dofile(dev_screen).show()
    else
        library.show()
    end
    ui.update()

    core.sound_play("main_menu", true)
end

init()
