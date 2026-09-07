# Phase 14 source mapping

Phase 14 continues the native Sonic 1/Godot port from Phase 13. This file records the principal disassembly-to-GDScript correspondences used in this phase.

## Regression corrections

| Native file | Original behavior/source | Phase 14 change |
|---|---|---|
| `scripts/objects/collapsing_ledge_object.gd` | `_incObj/1A, 53 Collapsing Ledges and Floors.asm` | Keeps parent/ledge support alive through the first `$1C` fragment delay and releases Sonic when that fragment actually drops. |
| `scripts/player/sonic_player.gd` | `Sonic_LevelBound` / `SolidObject` behavior | Runtime left/right limits now follow current camera boundaries; deliberate grounded side pushing is resolved before shallow top overlap. |
| `scripts/main.gd` | boss `f_lockscreen`, prison switch clearing screen lock | Feeds current camera limits into Sonic; drops boss-screen-lock enforcement during the time-frozen prison sequence. |
| `scripts/objects/ghz_boss_object.gd` | `_anim/Eggman.asm` `.facehit` | Keeps face frame 5 during the hit interval; visual flashing is not implemented as idle/hit frame toggling. |
| `scripts/objects/smash_wall_object.gd` | `_incObj/3C GHZ, SLZ Smashable Wall.asm`, `Smash_Solid` | Requires grounded pushing + rolling + `$480` speed before a wall can break. |

## Marble loader and level events

| Native file | Original source/data |
|---|---|
| `scripts/data/level_catalog.gd` | MZ layout/start/map/collision/palette/art definitions and `LevelSizeArray` |
| `scripts/data/ghz_level_data.gd` | generalized native art/layout loader; raw art ranges now accept optional source offsets |
| `scripts/camera/sonic_camera.gd` | `_inc/DynamicLevelEvents.asm` MZ1/MZ2/MZ3 routes |
| `scripts/render/ghz_background_renderer.gd` | MZ background layout + core `Deform_MZ` relationship |

MZ1 native files include `levels/mz1.bin`, `levels/mz1bg.bin`, `objpos/mz1 (REV01).bin`, `startpos/mz1.bin`, `map16/MZ.eni`, `map256/MZ (REV01).kos`, `collide/MZ.bin`, `palette/Marble Zone.bin`, and `artnem/8x8 - MZ.nem`.

## Marble objects

| Object | Native file | Original source |
|---|---|---|
| `$13/$14` | `lava_maker_object.gd`, `lava_ball_object.gd` | `_incObj/13, 14 MZ, SLZ Fire Balls and Maker.asm` |
| `$2F/$35` | `marble_object.gd`, `grass_fire_object.gd` | `_incObj/2F, 35 MZ Large Grassy Platforms and Burning Grass.asm` |
| `$30` | `marble_object.gd` | `_incObj/30 MZ Large Green Glass Blocks.asm` |
| `$31` | `marble_object.gd` | `_incObj/31 MZ Chained Stompers.asm` |
| `$32` | `marble_object.gd` | `_incObj/32 Button.asm` |
| `$33` | `marble_object.gd` | `_incObj/33 MZ, LZ Pushable Blocks.asm` |
| `$46` | `marble_object.gd` | `_incObj/46 MZ Bricks.asm` |
| `$52` | `marble_object.gd` | `_incObj/52 Moving Blocks.asm` |
| `$54` | `lava_tag_object.gd` | `_incObj/54 MZ Invisible Lava Tag.asm` |
| `$55` | `mz_badnik_object.gd` | `_incObj/55 Badnik - Basaran.asm` |
| `$71` | `marble_object.gd` | `_incObj/71 Invisible Solid Barriers.asm` |
| `$78` | `mz_badnik_object.gd` | `_incObj/78 Badnik - Caterkiller.asm` |

## Animals

`scripts/effects/animal_object.gd` and `object_manager.gd` now use the zone pair table from `_incObj/28, 29 Animals and Points.asm`:

- GHZ: IDs `0,5`
- LZ: IDs `2,3`
- MZ: IDs `6,3`
- SLZ: IDs `4,5`
- SYZ: IDs `4,1`
- SBZ: IDs `0,1`

Phase 14 includes native MZ mappings/art outputs for the seal and squirrel species and their source velocity/gravity classes.

## Fidelity boundaries

The MZ1 object-ID coverage is complete, but not every routine is bit-for-bit complete yet. Most notably:

- Caterkiller's body wave/terrain propagation is currently an approximation around the source timing and floor response.
- Push blocks do not yet reproduce all MZ2/MZ3 lava floating/sinking/geyser interactions.
- MZ background deformation does not yet reproduce each scanline strip rate.
- Marble dynamic tile slots are seeded with authentic initial source frames, but `AnimateLevelGfx` cycling is not yet running.
