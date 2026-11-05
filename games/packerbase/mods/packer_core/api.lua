-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Copyright (C) 2026 PackerMOD contributors
-- Factory kept separate so migration failures can be tested without a server.
return function(engine, storage)
	local api = {version = "0.1.0", api_version = 1}
	local listeners, timings = {}, {}
	local profiling = engine.settings:get_bool("packer_profile", false)
	local function identifier(value)
		assert(type(value) == "string" and value:match("^[a-z][a-z0-9_]*$"), "invalid namespace")
		return value
	end
	-- Events are synchronous and ordered. Errors propagate; they are not hidden.
	function api.on(event, callback)
		assert(type(event) == "string" and type(callback) == "function", "invalid listener")
		listeners[event] = listeners[event] or {}
		table.insert(listeners[event], callback)
	end
	function api.emit(event, ...)
		local callbacks = listeners[event] or {}
		-- Snapshot count: listeners added during emission run on the next emission.
		for i = 1, #callbacks do callbacks[i](...) end
	end
	-- One serialized record per namespace makes schema/data updates atomic at
	-- the ModStorage record level. It is not a transaction across namespaces.
	function api.open_data(namespace, version, migrations)
		identifier(namespace)
		assert(type(version) == "number" and version >= 1 and version % 1 == 0, "invalid schema")
		local key = "data:" .. namespace
		local raw = storage:get_string(key)
		local record = raw ~= "" and engine.deserialize(raw) or {schema = 0, data = {}}
		assert(type(record) == "table" and type(record.schema) == "number"
			and record.schema >= 0 and record.schema % 1 == 0
			and type(record.data) == "table", "invalid saved data: " .. namespace)
		assert(record.schema <= version, "save requires newer schema: " .. namespace)
		while record.schema < version do
			local next_version = record.schema + 1
			local migrate = migrations and migrations[next_version]
			assert(type(migrate) == "function", "missing migration: " .. namespace .. "/" .. next_version)
			local data = migrate(record.data)
			assert(type(data) == "table", "migration must return a table")
			record = {schema = next_version, data = data}
		end
		-- No write occurs until every migration succeeds.
		storage:set_string(key, engine.serialize(record))
		return {
			read = function() return engine.deserialize(storage:get_string(key)).data end,
			write = function(data)
				assert(type(data) == "table", "data must be a table")
				local current = engine.deserialize(storage:get_string(key))
				assert(current.schema == version, "schema changed; reopen data")
				storage:set_string(key, engine.serialize({schema = version, data = data}))
			end,
		}
	end
	-- Opt-in timing of explicitly wrapped work; no per-step background callback.
	-- Return values (including nil) and exceptions are preserved.
	function api.measure(name, callback, ...)
		if not profiling then return callback(...) end
		local start = engine.get_us_time()
		local function pack(...) return {n = select("#", ...), ...} end
		local values = pack(pcall(callback, ...))
		local elapsed = engine.get_us_time() - start
		local entry = timings[name] or {calls = 0, total_us = 0, max_us = 0}
		entry.calls, entry.total_us = entry.calls + 1, entry.total_us + elapsed
		entry.max_us = math.max(entry.max_us, elapsed)
		timings[name] = entry
		if not values[1] then error(values[2], 0) end
		return unpack(values, 2, values.n)
	end
	function api.profile_snapshot()
		local copy = {}
		for name, entry in pairs(timings) do
			copy[name] = {calls = entry.calls, total_us = entry.total_us, max_us = entry.max_us}
		end
		return copy
	end
	return api
end
