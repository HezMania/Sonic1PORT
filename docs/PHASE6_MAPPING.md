# Phase 6 source mapping

## Solid object support

Native files:

- `scripts/player/sonic_player.gd`
- `scripts/objects/monitor_object.gd`
- `scripts/objects/purple_rock_object.gd` (uses the shared bridge unchanged)

Primary disassembly references:

- `_incObj/sub SolidObject.asm`
  - `SolidObject`
  - `Solid_ChkCollision`
  - `Solid_TopBottom`
  - `MvSonicOnPtfm` relationship
- `_incObj/Sonic AnglePos.asm`
  - early return while Sonic is standing on an object (`obStatus` bit 3)

Native equivalents introduced in Phase 6:

- `standing_on_object`
- `support_left/right/top`
- `_validate_object_support()`
- `_set_object_support()`
- `clear_object_support()`
- updated `resolve_platform_top()` / `resolve_solid_box()`

## Monitor top-break behavior

Native file: `scripts/objects/monitor_object.gd`

Reference: `_incObj/26, 2E Monitors and Power-Ups.asm`

Relevant original paths:

- `Mon_Solid`
- `Mon_SolidSides`
- ReactToItem monitor break transition to `Mon_BreakOpen`

Phase 6 checks Sonic's actual player/monitor hitbox overlap before converting top contact into a standing relationship, allowing the rolling/jump-ball state to break the monitor from above.

## Loop transition correction

Native file: `scripts/player/sonic_player.gd`

References:

- `_incObj/Sonic AnglePos.asm` -> `Sonic_Angle`
- `_incObj/01 Sonic.asm` -> `Sonic_Loops`
- `_incObj/sub FindNearestTile & FindFloor & FindWall.asm`

The key Phase 6 change is the odd/sentinel collision-angle case: the snap value is now `(previous_angle + $20) & $C0`, matching `Sonic_Angle`, rather than using the active sensor branch's nominal quadrant.

## Moto Bug `$40`

Native file: `scripts/objects/badnik_object.gd`

Reference: `_incObj/40 Badnik - Moto Bug.asm`

Mapped routines:

- `Moto_Action_Ledge`
- `Moto_Action_Drive`
- `ObjFloorDist` threshold checks `-8` and `$C`
- `$100` drive velocity
- 60-frame ledge wait
- `Ani_Moto` stand/drive sequence

Deferred: smoke particle sub-object.

## Crabmeat `$1F`

Native files:

- `scripts/objects/badnik_object.gd`
- `scripts/objects/badnik_projectile.gd`

Reference: `_incObj/1F Badnik - Crabmeat.asm`

Mapped routines:

- `Crab_Action_WaitFire`
- `Crab_Action_Scuttle`
- 16px `ObjFloorDist2` look-ahead
- `Crab_Action_Fire`
- `Crab_BallMain`
- `Crab_BallMove`
- slope classification foundation from `Crab_SetAni`

Velocity/timing values retained:

- scuttle X `$80`
- scuttle timer `128-1`
- wait/fire timer `60-1`
- ball X `±$100`
- ball Y `-$400`
- normal `$38` gravity

## Buzz Bomber `$22` and missile `$23`

Native files:

- `scripts/objects/badnik_object.gd`
- `scripts/objects/badnik_projectile.gd`

Reference: `_incObj/22, 23 Badnik - Buzz Bomber and Missile.asm`

Mapped Buzz states:

- `Buzz_Action_Wait`
- `Buzz_Action_Move`
- `Buzz_Action_Fire`
- 96px Sonic proximity check
- 128-frame flight
- 30-frame pre-fire pause
- 60-frame fire/cooldown
- `$400` flight velocity

Mapped missile behavior:

- 15-frame pre-activation flare delay
- corrected horizontal launch offset of `$18-4` = 20 pixels
- X velocity `±$200`
- Y velocity `$200`
- parent-cancellation behavior
- `Ani_Missile` flare and missile frame timing foundation
