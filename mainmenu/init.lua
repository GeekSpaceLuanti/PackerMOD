PACKERMOD_VERSION = "0.1.0"
PACKERMOD_TAB_W = 15.5
-- Bumped from 7.1 to 8.0 so labelled fields (which reserve a 0.4-unit label
-- band each) have enough room without crushing the result/mod text lists.
PACKERMOD_TAB_H = 8.0

MAIN_TAB_W = PACKERMOD_TAB_W
MAIN_TAB_H = PACKERMOD_TAB_H
TABHEADER_H = 0.85
GAMEBAR_H = 1.25
GAMEBAR_OFFSET_DESKTOP = 0.375
GAMEBAR_OFFSET_TOUCH = 0.15

local function script_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("(.*[/\\])") or ("." .. DIR_DELIM)
end

local self_path = script_dir()
local basepath = core.get_builtin_path()

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

local user_path = core.get_user_path()
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
    fs = fs,
    client = client,
    installer = installer,
    launcher = launcher,
    importer = importer,
}

-- ui_loader is loaded after the packermod table so it can read packermod.layout.
packermod.ui_loader = dofile(self_path .. "lib" .. DIR_DELIM .. "ui_loader.lua")

-- Phase 8+: Library 単一画面。旧 tab_*.lua は Phase 11 でモーダル化するまで残置。
local library = dofile(self_path .. "library.lua")
packermod.library = library

local function init()
    if core.is_debug_build then
        core.set_topleft_text("PackerMOD " .. PACKERMOD_VERSION)
    end

    pack_manager.ensure_dirs(packermod.user_path)

    library.show()
    ui.update()

    core.sound_play("main_menu", true)
end

init()
