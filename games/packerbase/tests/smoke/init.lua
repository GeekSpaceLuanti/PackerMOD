-- SPDX-License-Identifier: LGPL-2.1-or-later
assert(packer_core.api_version == 1)
assert(core.registered_nodes["default:stone"])
local ready = false
packer_core.on("ready", function() ready = true end)
core.register_on_mods_loaded(function()
	assert(ready, "ready event not delivered")
	local expected = assert(tonumber(core.settings:get("packer_smoke_expected")))
	local state = packer_core.open_data("smoke", 1, {[1] = function(d) d.count = 0; return d end})
	local value = state.read()
	assert(value.count == expected - 1, "ModStorage was not persisted")
	local pos = {x = 0, y = 0, z = 0}
	core.after(0, function()
	core.emerge_area(pos, pos, function(_, _, remaining)
		if remaining ~= 0 then return end
		core.after(0, function()
			if expected == 1 then
				core.set_node(pos, {name = "default:stone"})
				core.get_meta(pos):set_string("packer_smoke", "saved")
			else
				assert(core.get_node(pos).name == "default:stone", "map node was not persisted")
				assert(core.get_meta(pos):get_string("packer_smoke") == "saved", "map metadata was not persisted")
			end
			value.count = expected; state.write(value)
			core.log("action", "PackerMOD Base smoke pass " .. expected)
			core.request_shutdown("smoke complete", false, 0)
		end)
	end)
	end)
end)
