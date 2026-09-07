# Phase 42 Validation — Scrap Brain Progression Objects

Static/source validation was run against the full Phase 42 project tree, the pristine Phase 41 baseline, and the supplied `s1disasm-AS` archive.

## Result

**50 / 50 targeted Phase 42 assertions passed.**

Project inventory after Phase 42:

- **86 GDScript files**
- **83 named `class_name` declarations**
- **535 PNG files**
- **0 PNG decode failures**
- **0 duplicate named classes**
- **0 missing concrete literal `res://` resources**
- **0 `:= ... .get()` inference hazards**
- **0 typed-array ternary assignments matching the Phase 41 failure pattern**
- **0 rough delimiter warnings**

## Phase 41 reported parser issue

The Object `$69` trapdoor sequence in `scripts/objects/sbz_native_object.gd` now uses an explicit `Array[int]` initialization followed by a normal branch for the reverse sequence. This removes the generic-`Array` ternary assignment that Godot 4.6.3 rejected in the tested Phase 41 build.

## Source-art equality

All six newly retained Phase 42 Nemesis streams are byte-for-byte identical to the supplied disassembly:

- `SBZ Stomper.nem` — 413 bytes
- `SBZ Large Horizontal Door.nem` — 252 bytes
- `SBZ Vanishing Block.nem` — 253 bytes
- `SBZ Flaming Pipe.nem` — 395 bytes
- `SBZ Electrocuter.nem` — 384 bytes
- `SBZ Crushing Girder.nem` — 277 bytes

No reconstructed replacement object art was introduced for these families.

## Custom spin-conveyor data equality

All six source platform-position streams are byte-for-byte identical to the supplied disassembly:

- `sbz1pf1.bin` — 50 bytes
- `sbz1pf2.bin` — 50 bytes
- `sbz1pf3.bin` — 50 bytes
- `sbz1pf4.bin` — 50 bytes
- `sbz1pf5.bin` — 50 bytes
- `sbz1pf6.bin` — 56 bytes

Their source count words decode to eight active child records apiece. The extra bytes at the end of `sbz1pf6.bin` are retained exactly and are not read beyond the source count.

## Mapping validation

The newly generated `SBZSourceMaps` tables were parsed back and compared piece-for-piece against the supplied mapping ASM. All comparisons passed:

- Stomper / Door — 5 frames, 42 pieces
- Vanishing Platform — 4 frames, 3 pieces
- Flamethrower — 22 frames, 82 pieces
- Electrocuter — 6 frames, 24 pieces
- Girder — 1 frame, 12 pieces

Each generated piece comparison includes X/Y position, tile width/height, tile index, X/Y flip, palette offset, and priority flag.

## Authored placement validation

The original SBZ object-position binaries decode to:

| Object | SBZ1 | SBZ2 |
|---|---:|---:|
| `$6B` Stomper / Door | 11 | 6 |
| `$6C` Vanishing Platform | 48 | 16 |
| `$6D` Flamethrower | 23 | 19 |
| `$6E` Electrocuter | 17 | 35 |
| `$6F` Spin Conveyor Spawner | 6 | 0 |
| `$70` Girder | 12 | 0 |
| `$71` Invisible Barrier | 50 | 4 |
| `$72` Teleporter | 0 | 8 |

Newly routed Phase 42 families excluding the already-native `$71`: **201 authored records**. Including `$71`, the `$6B-$72` family represents **255 SBZ1/SBZ2 records**.

Additional subtype assertions passed:

- every `$6D` record in both acts uses subtype `$43`
- SBZ1 `$6E` records use `$08`; SBZ2 uses `$02/$04/$08`
- the six SBZ1 `$6F` spawners are exactly `$80-$85`
- the eight SBZ2 `$72` records are exactly subtypes `0-7`
- each custom `$6F` platform stream contains eight counted records whose upper subtype nibble matches its group

## Behavior assertions

Static source-driven assertions cover:

- `$6B` switch routing, door travel/retraction, 180-frame hold, stomper 8-pixel down / 1-pixel return, 60-frame delays, and source movement limits
- `$6C` source synchronization mask/offset, `$7F` phase interval, animation order, and frames-0/1-only solidity
- `$6D` subtype-derived fire/pause timers, normal/Y-flipped hurt frames, expansion/retraction animation behavior
- `$6E` source frame-count mask, exact discharge sequence, and frame-4-only damage
- `$6F` source custom-stream spawning, target paths, movement ratios, exact 17-step spin/flip cycle, and frame-0-only solidity
- `$70` exact four movement vectors/durations and 7-frame direction-change delay
- `$71` continued shared native barrier routing
- `$72` 50-ring subtype-7 gate, exact target tables, `$1000` max-axis velocity, high-byte-equivalent travel timing, active-travel despawn suppression, and `$800` vertical-wrap exit

## Regression isolation

Direct byte comparison with the pristine Phase 41 project confirmed these stabilized systems are unchanged:

- `scripts/data/ghz_level_data.gd`
- `scripts/render/ghz_renderer.gd`
- `scripts/player/sonic_player.gd`
- `scripts/camera/sonic_camera.gd`

The Phase 42 modifications are limited to the new source assets/data, new progression object implementation, native object routing/art mapping support, the Phase 41 `$69` typed-array correction, and Phase 42 documentation/README metadata.

## Runtime limitation

A Godot executable is not available in the packaging environment. Source equality, mappings, authored placements, resource paths, structural checks, image decoding, source-behavior assertions, and regression isolation were validated statically. The user's Godot 4.6.3 runtime remains authoritative for parser acceptance, collision feel, animation presentation, and full gameplay behavior.

Recommended runtime focus:

1. Confirm the former `sbz_native_object.gd` line-283 `Array[int]` error is gone.
2. SBZ1: exercise doors/stompers, vanishing platforms, flamethrowers, electrocuters, all six moving spin-conveyor groups, and girders.
3. SBZ2: exercise the same applicable families plus all eight tube teleporter subtypes, especially subtype 6's vertical-wrap route and subtype 7's 50-ring gate.
4. Recheck Phase 41 `$66-$6A` objects for regressions.
5. Do not treat the later FalseFloor/Eggman transition as a Phase 42 regression; it remains intentionally deferred.
