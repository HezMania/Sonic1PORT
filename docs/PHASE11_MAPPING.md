# Phase 11 source mapping

## Level selection / loading

Native files:
- `scripts/data/level_catalog.gd`
- `scripts/data/ghz_level_data.gd`
- `scripts/data/genesis_palette.gd`
- `scripts/main.gd`

Original disassembly references:
- `_inc/LevelHeaders.asm`
- `_inc/LevelSizeArray.asm`
- `_inc/LevelSizeLoad & BgScrollSpeed.asm` / `StartLocArray`
- `_inc/LevelLayoutLoad.asm`
- `_inc/LevelOrder.asm`
- `sonic.asm` / `Level_Index`
- `sonic.asm` / `ObjPos_Index`

The catalog replaces Phase 10's GHZ1 resource assumptions with per-zone/per-act metadata. The loader still uses the native Nemesis, Enigma and Kosinski decoders built in earlier phases.

## Green Hill dynamic events

Native:
- `scripts/camera/sonic_camera.gd`

Original:
- `_inc/DynamicLevelEvents.asm`
  - `DLE_GHZ1`
  - `DLE_GHZ2`
  - `DLE_GHZ3_Main`
  - `DLE_GHZ3_Boss` boundary route

The Phase 11 camera follows the three GHZ lower-boundary paths. `DLE_GHZ3_Boss` object spawn/music/lock completion is intentionally incomplete because the GHZ boss object has not been ported yet.

## Level progression

Native:
- `LevelCatalog.next_level()`
- `main.gd` tally-finished handoff

Original:
- `_inc/LevelOrder.asm`
- `_incObj/3A Got Through Card.asm`

GHZ1 -> GHZ2 -> GHZ3 -> MZ1 is represented. Broader normal zone order is registered for future work. The special SBZ2 -> flooded SBZ3/LZ4 -> Final Zone transition remains a dedicated future event because the original does not use an ordinary three-act handoff there.

## Fix: solid contact / vertical springs

Native:
- `SonicPlayer.resolve_solid_box_contact()`
- `SpringObject.tick()`

Fresh collisions now resolve a nearest face before calling the object's active response. Platform-top maintenance is used only if the player is already supported by that exact placement record. This prevents a side overlap from being misidentified as top contact on a vertical spring.

## Fix: Look Up

Native:
- `scripts/player/sonic_visual.gd`

Original:
- `_anim/Sonic.asm` / `SonAni_LookUp`

Uses mapping frame `$05` while grounded, near stationary and Up is held.

## Fix: collapsing ledge support

Native:
- `CollapsingLedgeObject._fragmentate()`
- `SonicPlayer.clear_object_support_for()`

The collapsing placement now clears its exact support-record relationship and explicitly returns Sonic to AIR when the supporting ledge disappears.

## Fix: Moto Bug initial direction

Native:
- `BadnikObject._init_motobug()`

Original:
- `_incObj/40 Badnik - Moto Bug.asm`

The original initial status toggle means a normal placement's first drive is leftward. Native initialization is arranged so the existing first ledge/action toggle produces that same result.

## Fix: ring sparkle

Native:
- `scripts/objects/ring_group_object.gd`

Original:
- `_incObj/25,37 Rings.asm`
- `_anim/Rings.asm` / `Ani_Ring`

Collected rings enter frames `$04,$05,$06,$07` with delay 5 (six ticks per visible frame) before deletion.

## Fix: skidding

Native:
- `SonicPlayer._move_left()` / `_move_right()`
- `SonicVisual._update_skid()`

Original:
- `_incObj/01 Sonic.asm` / `Sonic_MoveLeft`, `Sonic_MoveRight`
- `_anim/Sonic.asm` / `SonAni_Stop`

The skid condition uses the original `$400` high-speed threshold. Braking still uses the existing `$80` Sonic deceleration constant, while frames `$37,$38` animate at the Stop animation delay.
