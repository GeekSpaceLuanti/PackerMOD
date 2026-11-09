# PackerMOD Base foundation

Version 0.1.0, extension API major 1. Requires Luanti 5.8 or newer (the
integrated PackerMOD menu has its own newer engine requirement).

All original Minetest Game mods remain enabled and retain their names and
APIs. Third-party mods can depend on `packer_core` in `mod.conf` and use:

```lua
assert(packer_core.api_version == 1)
packer_core.on("ready", function() -- after all mods have loaded
    core.log("action", "My extension is ready")
end)
local state = packer_core.open_data("my_extension", 1, {
    [1] = function(data) data.visits = 0; return data end,
})
local value = state.read()
value.visits = value.visits + 1
state.write(value)
```

Namespaces must match `[a-z][a-z0-9_]*` and should be the owning mod's name.
Every schema step needs a migration, including initialization from zero.
Missing/failed migrations or newer saves fail without overwriting the old
record. Migrations must not perform outside writes; they return a table.
This API does not migrate engine maps, node names, player inventories, or
other mods' storage. Data must be Luanti-serializable and owned by trusted
game/mod code. `state.read()` returns a fresh copy; `write()` persists it.

Extensions can emit their own namespaced events (`mymod:event`). Callback
order is registration order and callback errors propagate. The built-in
`ready` event happens once; listeners must register during mod loading.

Set `packer_profile = true` before startup to enable
`packer_core.measure("mymod:task", function(...) ... end, ...)`; inspect a copy
of call counts/total/max microseconds using `packer_core.profile_snapshot()`.
Only wrapped work is measured, not engine rendering or every mod. Use
Luanti's `profiler.load` and `/profiler` for broader server diagnostics.

## Java Edition direction

The default player inventory has 36 slots: three rows of nine above
a nine-slot hotbar, including on the built-in creative page. Set
`packer_java_inventory = false` to keep the upstream layout for new worlds.
Existing inventories are never shrunk; already-expanded saves keep the
nine-column display so items are not hidden by reverting the setting.
Third-party inventory replacement mods control their own UI. Original
chest/furnace/bones forms remain unchanged; their player section shows the
first 32 slots, and the last four remain accessible in personal inventory.
Bones drop overflow items normally if its 32-slot storage is full.
Dry-land falling, jumping and crouching use tuned Luanti settings. On
Luanti 5.16+, a player using the original step mode steps up only while
grounded. Set `packer_rigid_step_up = false` to use the original step mode.
`packer_auto_pickup = false` disables nearby item pickup. See
`GAMEPLAY.md` for the comparison, tuning values and testing procedure.

## Development and verification

Run `bash scripts/test_base_game.sh` from the repository root under WSL.
The script runs pure API tests and starts/restarts a disposable headless
world with a separate smoke-test mod. It never converts an existing world.
Pinned upstream and change provenance: `UPSTREAM.md`. Upstream feature
documentation remains in `README.md` and `game_api.txt`.
