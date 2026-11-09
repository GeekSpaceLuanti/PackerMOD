-- SPDX-License-Identifier: LGPL-2.1-or-later
local path = core.get_modpath(core.get_current_modname())
local ui = dofile(path .. "/lib/pmui/init.lua")
local screens = dofile(path .. "/screens.lua")(ui)
packer_ui = {
	pmui = ui,
	recipe = dofile(path .. "/recipes.lua")(screens),
	receive = screens.receive
}
dofile(path .. "/settings.lua")(screens)
