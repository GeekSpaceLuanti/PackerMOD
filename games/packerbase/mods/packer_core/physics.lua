-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Copyright (C) 2026 PackerMOD contributors
if not core.settings:get_bool("packer_rigid_step_up", true) then return end

core.register_on_joinplayer(function(player)
	-- Lua exposes this property only in Luanti 5.16+. Preserve any other
	-- step-up mode already selected by a mod and let later mods override it.
	if player:get_properties().step_up_mode == "legacy" then
		player:set_properties({step_up_mode = "rigid"})
	end
end)
