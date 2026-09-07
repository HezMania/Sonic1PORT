# Phase 2 source mapping

This file records the main correspondence between the supplied 68000 disassembly and the native Godot player implementation.

## `scripts/player/sonic_player.gd`

| Native function/system | Primary disassembly source |
|---|---|
| `_mode_normal()` | `Sonic_MdNormal` |
| `_mode_roll()` | `Sonic_MdRoll` |
| `_mode_air()` | `Sonic_MdJump` / `Sonic_MdJump2` |
| `_ground_move()` | `Sonic_Move` / `Sonic_CheckDpadLetGo` |
| `_move_left()` | `Sonic_MoveLeft` |
| `_move_right()` | `Sonic_MoveRight` |
| `_angle_speed()` | `Sonic_AngleSpeed` |
| `_wall_speed_adjust()` | `Sonic_WallSpeedAdjust` |
| `_calc_room_ahead()` | `Sonic_CalcRoomAhead` |
| `_try_roll()` / `_start_roll()` | `Sonic_Roll` |
| `_roll_speed()` | `Sonic_RollSpeed`, `Sonic_RollLeft`, `Sonic_RollRight`, `Sonic_AngledRollSpeed` |
| `_try_jump()` | `Sonic_Jump` |
| `_jump_height()` | `Sonic_JumpHeight` |
| `_jump_direction()` | `Sonic_JumpDirection`, `Sonic_AirDrag` |
| `_object_fall()` | `ObjectFall` |
| `_speed_to_pos()` | `SpeedToPos` |
| `_jump_angle()` | `Sonic_JumpAngle` |
| `_slope_resist_walk()` | `Sonic_SlopeResistWalk` |
| `_slope_resist_roll()` | `Sonic_SlopeResistRoll` |
| `_slope_repel()` | `Sonic_SlopeRepel` |
| `_angle_pos()` and `_attach_*()` | `Sonic_AnglePos`, `Sonic_WalkVertL`, `Sonic_WalkVertR`, `Sonic_WalkCeiling` |
| `_air_collision()` and directional branches | `Sonic_Floor`, `Sonic_FloorDown/Left/Up/Right` |
| `_find_floor_full()` | `Sonic_FindFloor` |
| `_find_ceiling_full()` | `Sonic_FindCeiling` |
| `_find_right_wall_full()` | `Sonic_FindWallRight` |
| `_find_left_wall_full()` | `Sonic_FindWallLeft` |
| `_reset_on_floor()` | `Sonic_ResetOnFloor` |
| `_classify_surface_exact()` | signed-byte quadrant branching in `Sonic_AnglePos` / `Sonic_CalcRoomAhead` |
| `_update_loop_state()` | GHZ portions of `Sonic_Loops` / `LoopChunkNums` |

## `scripts/player/genesis_math.gd`

- `SINE` is the original `Sine_Data` lookup table used by `CalcSine`.
- `ANGLE` is the original `Angle_Data` lookup table used by `CalcAngle`.
- `calc_angle()` retains the original quadrant and ratio-table method rather than calling `atan2()`.
- `s8()`/`s16()` are used where the original code depends on signed byte/word wrap semantics.

## `scripts/player/sonic_visual.gd`

The runtime visual controller is intentionally small, but its input art is original data from the supplied disassembly:

- `_maps/Sonic.asm`
- `_maps/Sonic - Dynamic Gfx Script.asm`
- `artunc/Sonic.unc`
- `palette/Sonic.bin`
- `_anim/Sonic.asm` was used as the frame-sequence reference.

The generated PNGs are development-time/native assets; no Genesis DPLC execution is required at runtime.

## `scripts/render/ghz_renderer.gd`

Phase 1 flattened the foreground into one chunk texture. Phase 2 splits each generated chunk into:

- low-priority VDP pattern pixels (`z_index = 0`)
- high-priority VDP pattern pixels (`z_index = 100`)

Sonic sits at `z_index = 50`. This preserves the pattern word priority bit and is a more faithful basis for GHZ loop foreground/background sprite interaction.

## Intentional Phase 2 boundaries

This is not yet a claim of instruction-for-instruction equivalence. In particular:

1. The native player uses the original data scales, constants, lookup tables and collision algorithms, but it is structured as readable GDScript rather than simulated 68000 registers/stack flow.
2. The disassembly is configured with `FixBugs = 0`. Most ordinary gameplay behavior follows that baseline, but Phase 2 does not yet guarantee every historical collision/roll-jump bug is reproduced.
3. Object-platform state (`obStatus` bit 3 / `standonobject`) is not implemented until the object engine exists.
4. SBZ `sticktoconvex`, LZ slide/water behavior, object reaction and damage modes are intentionally deferred.
5. The camera is temporary; the player's simulation does not depend on that temporary camera smoothing.
