# Phase 7 Source Mapping

Phase 7 continues to use the supplied `s1disasm-AS` tree as the behavioral source.

## Loop / terrain collision

### `_incObj/Sonic AnglePos.asm`

Native counterparts in `scripts/player/sonic_player.gd`:

- `Sonic_AnglePos` -> `_angle_pos()` and `_classify_surface_exact()`
- normal floor branch -> `_attach_floor()`
- `Sonic_WalkVertR` -> `_attach_right_wall()`
- `Sonic_WalkCeiling` -> `_attach_ceiling()`
- `Sonic_WalkVertL` -> `_attach_left_wall()`
- `Sonic_Angle` -> `_choose_sensor()`

Phase 7 specifically preserves the initial `$03` values of `v_anglebuffer` and `v_anglebuffer2` when a grounded sensor does not write a new terrain angle.

### `_incObj/sub FindNearestTile & FindFloor & FindWall.asm`

Native counterpart: `scripts/collision/genesis_collision.gd`.

Phase 7 adds explicit state for the shared angle buffer:

- `_floor_sample()` / `_wall_sample()` mark `angle_written` after a shape writes the original `(a4)` byte;
- `find_floor()` and `find_wall()` call `_carry_angle_buffer()` after secondary-block queries;
- a blank secondary tile therefore returns its own distance while preserving a primary angle already written to the shared buffer.

This models the side effect of `FindFloor2`/`FindWall2` using the same `a4` pointer.

### `_incObj/01 Sonic.asm`

The existing `Sonic_Loops`-style GHZ `$B5` layer/front-back state remains in `scripts/player/sonic_player.gd`. Phase 7 does not replace this with a scripted loop.

## Object `$42` — Newtron

Source: `_incObj/42 Badnik - Newtron.asm`

Native counterpart: `scripts/objects/badnik_object.gd`.

Mapped states:

- `Newt_Action_ChkDistance` -> `_newtron_check_distance()`
- `Newt_Action_WaitDrop` -> `_newtron_wait_drop()`
- `Newt_Action_Drop` -> `_newtron_drop()`
- `Newt_Action_MoveOnFloor` -> `_newtron_move_on_floor()`
- `Newt_Action_MoveInAir` -> state 5 horizontal movement
- `Newt_Action_GreenNewtron` -> `_newtron_green_fire()`
- `Newt_GreenDelete` -> persistent `request_delete(true)`

Animation timing references `_anim/Newtron.asm`.

The Newtron missile uses the common Missile mapping/art already preprocessed for Buzz Bomber and is created through:

- `SonicObjectManager.spawn_newtron_missile()`
- `BadnikProjectile.setup_newtron()`
- `BadnikProjectile._tick_newtron()`

## Object `$2B` — Chopper

Source: `_incObj/2B Badnik - Chopper.asm`

Native counterpart: `BadnikObject._tick_chopper()`.

Ported constants/behavior:

- initial `obVelY = -$700`
- per-frame `+$18`
- original-Y reset/relaunch
- `$C0` animation-height threshold
- slow/fast/still animation timing from `_anim/Chopper.asm`
