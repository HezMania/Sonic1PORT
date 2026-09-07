# Phase 42 Mapping — Scrap Brain Progression Objects

Phase 42 continues native Scrap Brain Zone gameplay from the user-tested Phase 41 foundation. The supplied `s1disasm-AS` tree remains the authoritative source. The Phase 41 `$66-$6A` implementation is retained, the reported typed-array parser failure in Object `$69` is corrected, and the remaining normal SBZ Acts 1-2 object family `$6B-$72` is now routed natively.

The SBZ2 FalseFloor / Scrap Eggman transition, SBZ3/LZ4 ancient-lift transition behavior, and Final Zone remain deliberately separate later phases rather than being approximated here.

## Phase 41 parser correction

`scripts/objects/sbz_native_object.gd` no longer assigns a ternary-produced generic `Array` directly to `Array[int]` in the trapdoor animation path. Phase 42 initializes the typed array explicitly and replaces it only in the reverse-animation branch, preserving the exact `0,1,2` / `2,1,0` sequences without the Godot 4.6.3 assignment error reported after Phase 41 testing.

## Object `$6B` — Stomper / Sliding Door

Source: `_incObj/6B SBZ Stomper and Sliding Door.asm`, `_maps/SBZ Stomper and Door.asm`, `artnem/SBZ Stomper.nem`, `artnem/SBZ Large Horizontal Door.nem`.

Implemented for SBZ Acts 1-2:

- source `Sto_Var` dimensions and movement limits for entries 0-3
- horizontal sliding door: 128-pixel travel at 2 px/frame, 180-frame hold, then 2 px/frame retract
- X-flipped source reversal/offset for the horizontal door
- switch-controlled high-bit subtypes using the low subtype nibble as the switch index
- stomper fast downward travel at 8 px/frame and slow 1 px/frame return
- source 60-frame top delay for the stomper
- continuously moving 64/96-pixel vertical variants at 8 px/frame with 60-frame endpoint waits
- source X-flip-driven vertical inversion
- all-side solidity and player carry while the object moves
- exact original Stomper and Large Horizontal Door Nemesis streams
- source-map tile bias for the standalone door stream (`$46F-$2C0=$1AF`)

The `Sto_Var` entry 4 ancient lift is part of the SBZ3/LZ4 transition and is intentionally deferred with that transition. It has no authored SBZ1/SBZ2 playtest placement requiring approximation in this phase.

Authored placements: **11 in SBZ1, 6 in SBZ2**.

## Object `$6C` — Vanishing Platform

Source: `_incObj/6C SBZ Vanishing Platforms.asm`, `_anim/SBZ Vanishing Platforms.asm`, `_maps/SBZ Vanishing Platforms.asm`, `artnem/SBZ Vanishing Block.nem`.

Implemented:

- low-nibble source cycle length: `(n+1)*$80`
- source synchronization span/mask and upper-nibble phase offset
- 8-frame-per-image animation cadence (`delay 7`)
- exact vanish sequence `0,1,2,3` and appear sequence `3,2,1,0`
- source hold behavior on terminal frames
- source `btst #1,obFrame` solidity: frames 0/1 top-solid, frames 2/3 non-solid
- player support is cleared when the platform becomes non-solid
- exact original Vanishing Block Nemesis stream and source mappings

Authored placements: **48 in SBZ1, 16 in SBZ2**.

## Object `$6D` — Flamethrower

Source: `_incObj/6D SBZ Flamethrower.asm`, `_anim/Flamethrower.asm`, `_maps/Flamethrower.asm`, `artnem/SBZ Flaming Pipe.nem`.

Implemented:

- source firing duration from upper subtype nibble (`upper * 2` frames)
- source pause duration from lower subtype nibble (`lower << 5` frames)
- normal pipe animation and Y-flipped valve animation paths
- expansion cadence `delay 3` with source two-frame tail loop
- immediate retraction sequence and terminal hold
- hurt state only on source frame `$0A` for pipes or `$15` for Y-flipped valves
- source-equivalent 24×48 hurt region
- exact original Flaming Pipe Nemesis stream and all 22 mapping frames

All authored SBZ1/SBZ2 flamethrowers use subtype `$43`.

Authored placements: **23 in SBZ1, 19 in SBZ2**.

## Object `$6E` — Electrocuter

Source: `_incObj/6E SBZ Electrocuter.asm`, `_anim/Electrocuter.asm`, `_maps/Electrocuter.asm`, `artnem/SBZ Electrocuter.nem`.

Implemented:

- source discharge mask `subtype*16-1`
- frame-counter synchronized activation
- exact discharge animation `1,1,1,2,3,3,4,4,4,5,5,5,0`
- damage only on source frame 4
- source-equivalent 144×16 hurt region
- exact original Electrocuter Nemesis stream and all six mapping frames

Authored subtype frequencies are preserved: SBZ1 uses `$08`; SBZ2 uses `$02`, `$04`, and `$08`.

Authored placements: **17 in SBZ1, 35 in SBZ2**.

## Object `$6F` — Spin Platform Conveyor

Source: `_incObj/6F SBZ Spin Platform Conveyor.asm`, `_anim/SBZ Spinning Platforms.asm`, and `objpos/platforms/sbz1pf1.bin` through `sbz1pf6.bin`.

The normal SBZ1 object-position stream contains six high-bit group spawners (`$80-$85`). Phase 42 now loads the six original custom platform-position streams directly and instantiates their eight child platforms per group.

Implemented:

- exact six original custom source-data files, including their source count words
- original four-corner target paths for all six conveyor groups
- source target index from the lower subtype nibble
- source group selection from the upper subtype nibble of custom platform records
- `LCon_ChangeDir`-equivalent one-pixel major-axis movement with proportional minor-axis motion
- source initial still/spin selection around target indices 0/2
- exact 17-step spin/flip animation sequence, looping through source `afEnd`
- frame-0-only all-side solidity
- player detachment while nonzero spinning frames are displayed
- reuse of the exact Phase 41 `SBZ Spinning Platform.nem` source stream

Authored group spawners: **6 in SBZ1, 0 in SBZ2**. Each group source file contains **8 moving platforms**.

## Object `$70` — Crushing Girder

Source: `_incObj/70 SBZ Girder Block.asm`, `_maps/Girder Block.asm`, `artnem/SBZ Crushing Girder.nem`.

Implemented source movement cycle:

1. right at `+$100` 8.8 for 96 frames
2. down at `+$100` 8.8 for 48 frames
3. up-left at `-$100,-$40` 8.8 for 96 frames
4. up at `-$100` 8.8 for 24 frames

Each direction change preserves the source 7-frame delay. The 192×48 girder remains all-side solid and carries Sonic while moving. Its exact original Crushing Girder Nemesis stream and source mapping are retained.

Authored placements: **12 in SBZ1, 0 in SBZ2**.

## Object `$71` — Invisible Solid Barrier

Source: `_incObj/71 Invisible Solid Barriers.asm`.

Object `$71` was already handled by the project's shared native invisible-barrier implementation in `MarbleObject`, alongside the other zones that use the same Sonic 1 barrier family. Phase 42 deliberately retains that existing route instead of creating a duplicate implementation.

The shared path preserves subtype-derived width/height and all-side solid collision while remaining invisible.

Authored placements: **50 in SBZ1, 4 in SBZ2**.

## Object `$72` — SBZ2 Tube Teleporter

Source: `_incObj/72 SBZ Teleporter.asm`.

Implemented:

- exact one-sided 16-pixel entrance test, including source X-flipped offset behavior
- source ±32-pixel vertical entrance band
- ignores entry while debug/control override is active
- subtype 7 requires at least 50 rings, without deducting rings
- source control lock, Roll state, `$800` inertia, zero initial velocity, and entrance snap
- 64-tick sine pre-bump (`angle += 2` until `$80`)
- exact source target tables for subtypes 0-7
- max-axis tube speed `$1000` in 8.8 with proportional minor-axis velocity
- source travel duration semantics: the assembly stores a word quotient and decrements its big-endian high byte, equivalent to `floor(max_axis_distance/16)` movement ticks before target snap
- no central object despawn during active tube travel
- source final vertical `$800` wrap and `$200` downward release velocity

Subtype 6 includes the original negative-Y target chain used with SBZ2 vertical wrapping. All eight final-game subtype values `0-7` are represented once in SBZ2.

Authored placements: **0 in SBZ1, 8 in SBZ2**.

## Original source data retained in Phase 42

New byte-identical source streams added in this phase:

- `SBZ Stomper.nem`
- `SBZ Large Horizontal Door.nem`
- `SBZ Vanishing Block.nem`
- `SBZ Flaming Pipe.nem`
- `SBZ Electrocuter.nem`
- `SBZ Crushing Girder.nem`
- `objpos/platforms/sbz1pf1.bin` through `sbz1pf6.bin`

`SBZSourceMaps` now also contains generated source-piece tables for Stomper/Door, Vanishing Platform, Flamethrower, Electrocuter, and Girder mappings. The Phase 41 mapping tables remain intact.

## Authored placement coverage

Newly routed Phase 42 object records (excluding the already-native shared `$71` barrier):

| Object | SBZ1 | SBZ2 | Total |
|---|---:|---:|---:|
| `$6B` Stomper / Door | 11 | 6 | 17 |
| `$6C` Vanishing Platform | 48 | 16 | 64 |
| `$6D` Flamethrower | 23 | 19 | 42 |
| `$6E` Electrocuter | 17 | 35 | 52 |
| `$6F` Spin Conveyor Spawner | 6 | 0 | 6 |
| `$70` Girder | 12 | 0 | 12 |
| `$72` Teleporter | 0 | 8 | 8 |
| **Total newly routed** | **117** | **84** | **201** |

Including the 54 already-native `$71` barriers, the normal `$6B-$72` SBZ1/SBZ2 placement family accounts for **255 authored records**.

## Regression preservation

Phase 42 is isolated from the previously stabilized level systems. In particular, the following files remain byte-for-byte identical to Phase 41:

- `scripts/data/ghz_level_data.gd`
- `scripts/render/ghz_renderer.gd`
- `scripts/player/sonic_player.gd`
- `scripts/camera/sonic_camera.gd`

Phase 41 Objects `$66-$6A` remain routed through `SBZNativeObject`; only the reported typed-array construction in `$69` was corrected.

## Still deferred

- SBZ2 `$1EB0` FalseFloor event
- SBZ2 `$1F60` Scrap Eggman cutscene / SBZ3 transition
- `$6B` ancient-lift transition behavior tied to SBZ3/LZ4 level patterns
- Final Zone boss/event sequence
- original sound-driver music/SFX
- exact animated CRAM palette cycling
