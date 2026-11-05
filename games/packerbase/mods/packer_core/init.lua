-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Copyright (C) 2026 PackerMOD contributors
local path = core.get_modpath(core.get_current_modname())
packer_core = dofile(path .. "/api.lua")(core, core.get_mod_storage())
dofile(path .. "/inventory.lua")
core.register_on_mods_loaded(function()
	packer_core.emit("ready", packer_core)
	core.log("action", "PackerMOD Base " .. packer_core.version .. " ready (API " .. packer_core.api_version .. ")")
end)
