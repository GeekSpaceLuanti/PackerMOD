# Java Edition movement and item pickup

Compared against the [Minecraft Java Edition 26.1 server binary](https://piston-data.mojang.com/v1/objects/3872a7f07a1a595e651aef8b058dfc2bb3772f46/server.jar)
listed in the [official launcher version manifest](https://piston-meta.mojang.com/mc/game/version_manifest_v2.json).
The download matched Mojang's SHA-1. Java bytecode was inspected locally
for the constants and movement order below.

| Behavior | Java Edition 26.1 | Luanti 5.16.1 in PackerMOD Base |
| --- | --- | --- |
| Dry-land falling | `LivingEntity.travelInAir` applies gravity 0.08 and multiplies vertical velocity by 0.98 every 50 ms after movement. | The client applies twice `movement_gravity`. The game setting rises from 9.81 to 14, giving effective acceleration 28 blocks/s². |
| Fall from 1 to 9 blocks of displacement | About 0.538 s with interpolation between 20 Hz simulation ticks from rest. | Constant-acceleration estimate 0.535 s, down from 0.639 s with the old default. |
| Dry-land jump | Default vertical impulse 0.42 blocks/tick, giving an apex around 1.25 blocks. | Jump speed 8.6 blocks/s with the tuned gravity, giving an estimated 1.32-block apex rather than 1.08 at Luanti defaults. Substep size changes the measured apex slightly. |
| Ledges | `Player.maybeBackOffFromEdge` reduces crouched movement in 0.05-block increments when the player's proposed position loses support. | Crouch target 1.295 blocks/s, approximately 30% of the 4.317 walking speed. Luanti's crouch collision tests and corrections continue to run locally. `step_up_mode = rigid` removes the legacy upward jolt against a ledge while airborne. |
| Dropped items | `ItemEntity.setDefaultPickUpDelay` waits 10 ticks before player contact can collect the item. | Nearby items become eligible after 0.5 s. The scan runs about every 0.1 s and uses a 1.4-block radius around the lower body. |

Luanti sources: [default settings](https://github.com/luanti-org/luanti/blob/5.16.1/src/defaultsettings.cpp),
[client gravity and fall damage](https://github.com/luanti-org/luanti/blob/5.16.1/src/client/clientenvironment.cpp),
[local movement and crouch collision](https://github.com/luanti-org/luanti/blob/5.16.1/src/client/localplayer.cpp),
[step-up object property](https://github.com/luanti-org/luanti/blob/5.16.1/doc/lua_api.md#object-properties),
and [item entity pickup](https://github.com/luanti-org/luanti/blob/5.16.1/builtin/game/item_entity.lua).

The tuned gravity is a fit for short falls. Java's per-tick drag limits
speed over long falls, while Luanti accelerates by a constant amount.
Luanti still calculates fall damage from impact speed and steps up based
on its own collision rules. The higher gravity affects other Luanti
systems that read `movement_gravity`, including dropped item physics.
World and Luanti settings can override the defaults. Use values `9.81`,
`6.5`, and `1.35` for the old gravity, jump, and crouch settings.
The rigid step rule needs a 5.16+ client, is applied once on join to
players with legacy mode, and can be disabled independently with
`packer_rigid_step_up = false`.

PackerMOD supplies Java Edition defaults for unassigned client bindings:
E for inventory, left Ctrl for Aux1, F2 for screenshots, F3 for debug,
and F5 for perspective. Existing bindings take priority. Ctrl + forward
in PackerMOD Base increases walking speed by 30% on dry land and releases
the multiplier when the player stops sprinting. The game setting
`packer_sprint = false` disables this behavior. Luanti keeps its own
item-drop modifiers and debug behavior, and has no vanilla middle-click
pick-block binding in this version.

Automatic pickup uses Luanti's item entity pickup callback, so MOD
pickup hooks and partial inventory space are honored. The usual manual
punch remains available, including during the automatic pickup delay.
The scan skips dead players and players without interact privilege, and
standard walkable nodes obstruct pickup. `packer_auto_pickup = false`
turns off scanning.

Run `bash scripts/test_base_game_gameplay.sh` under WSL. The Xvfb test
compares old and tuned gravity with client position and velocity updates.
It checks the 0.5-second item delay, partial pickup, manual pickup of the
remainder, crouching on then stepping off a one-block platform, and
restoration of the walking speed after releasing Ctrl.
