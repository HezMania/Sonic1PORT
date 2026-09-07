# Phase 17 source mapping

## Horizontal terrain pushing

Source: `_incObj/01 Sonic.asm`, `Sonic_WallSpeedAdjust`.

The native `_wall_speed_adjust()` now distinguishes positive clearance from zero-distance contact. A side-wall distance of zero keeps inertia at zero and preserves the pushing state while the corresponding direction is held, instead of allowing a fractional forward step before the next negative-distance correction.

## MZ pushable block

Source: `_incObj/33 MZ, LZ Pushable Blocks.asm`, especially `PushB_SolidAction_NotOnPlatform`.

Phase 17 keeps the existing one-pixel block displacement / `±$40` Sonic inertia behavior and replaces stale nonexistent wall-query calls with `GenesisCollision.find_right_wall_sensor()` / `find_left_wall_sensor()`. The MZ1 `$A20..$AA0` stomper attachment from Phase 16 remains intact.

## Debug free movement

Source: `_incObj/DebugMode.asm`, `Debug_Control` / `Debug_Move_Delay` / `Debug_Move`.

The native testing mode uses the source constants:

- `debug_movedelay = 12`
- `debug_startspeed = 15`
- movement delta `(debug_speed + 1) / 16` pixels per frame
- held input increments speed toward `$FF`, yielding a maximum 16 px/frame

Only the free-movement/testing portion is implemented. Genesis debug-object selection and placement are intentionally deferred.

## Debug collision isolation

While debug free-move is active, `resolve_platform_top`, `resolve_solid_box_contact`, `apply_hazard_hit`, `can_attack_object`, and `kill` do not perform ordinary gameplay interaction. The level clock also pauses. This is the native equivalent of objects checking `v_debuguse` before reacting to Sonic.

## Camera

`SonicCamera._debug_follow()` centers on the free-move position and clamps against the decoded foreground layout dimensions rather than current DLE boundaries. Existing ProjectSettings-derived viewport dimensions remain in use.
