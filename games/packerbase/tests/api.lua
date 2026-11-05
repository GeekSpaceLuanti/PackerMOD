-- SPDX-License-Identifier: LGPL-2.1-or-later
local factory = dofile(arg[1] .. "/mods/packer_core/api.lua")
local function clone(value)
	if type(value) ~= "table" then return value end
	local out = {}; for k, v in pairs(value) do out[k] = clone(v) end; return out
end
local serials, serial = {}, 0
local engine = {
	settings = {get_bool = function() return true end},
	serialize = function(value) serial = serial + 1; serials[tostring(serial)] = clone(value); return tostring(serial) end,
	deserialize = function(value) return clone(serials[value]) end,
	get_us_time = (function() local t = 0; return function() t = t + 10; return t end end)(),
}
local values = {}
local storage = {get_string = function(_, k) return values[k] or "" end,
	set_string = function(_, k, v) values[k] = v end}
local api = factory(engine, storage)
local order = {}
api.on("test", function(value) order[#order + 1] = value end)
api.on("test", function(value) order[#order + 1] = value + 1 end)
api.emit("test", 4)
assert(order[1] == 4 and order[2] == 5)
local data = api.open_data("test_mod", 1, {[1] = function(d) d.count = 7; return d end})
assert(data.read().count == 7)
local copy = data.read(); copy.count = 99
assert(data.read().count == 7, "read leaked a mutable stored reference")
local before = values["data:test_mod"]
assert(not pcall(api.open_data, "test_mod", 3, {[2] = function(d) d.count = 8; return d end}))
assert(values["data:test_mod"] == before, "partial migration overwrote old data")
local upgraded = api.open_data("test_mod", 2, {[2] = function(d) d.count = d.count + 1; return d end})
assert(upgraded.read().count == 8)
assert(not pcall(data.write, {}), "stale schema handle wrote newer data")
assert(not pcall(api.open_data, "test_mod", 1), "downgrade accepted")
assert(not pcall(api.open_data, "../invalid", 1), "invalid namespace accepted")
local a, b, c = api.measure("returns", function() return 1, nil, 3 end)
assert(a == 1 and b == nil and c == 3)
assert(not pcall(api.measure, "failure", function() error("expected") end))
assert(api.profile_snapshot().returns.calls == 1)
assert(api.profile_snapshot().failure.calls == 1)
local snap = api.profile_snapshot(); snap.returns.calls = 42
assert(api.profile_snapshot().returns.calls == 1)
local disabled = factory(setmetatable({settings = {get_bool = function() return false end}}, {__index = engine}), storage)
assert(disabled.measure("off", function() return 9 end) == 9)
assert(next(disabled.profile_snapshot()) == nil)
print("PackerMOD Base API tests passed")
