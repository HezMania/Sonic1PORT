# Phase 41 Validation — Scrap Brain Foundation

Static/source validation was run against the full Phase 41 project tree and the user-supplied `s1disasm-AS` archive.

## Result

**68 / 68 targeted Phase 41 assertions passed.**

Project inventory:

- **85 GDScript files**
- **82 named `class_name` declarations**
- **535 PNG files**
- **0 PNG decode failures**
- **0 duplicate named classes**
- **0 missing concrete literal `res://` resources**
- **0 `:= ... .get()` inference hazards**
- **0 rough delimiter warnings**

## Source-art equality

All five newly retained Phase 41 Nemesis streams are byte-for-byte identical to the supplied disassembly:

- `SBZ Junction Wheel.nem` — 668 bytes
- `SBZ Running Disc.nem` — 83 bytes
- `SBZ Trapdoor.nem` — 477 bytes
- `SBZ Spinning Platform.nem` — 816 bytes
- `SBZ Pizza Cutter.nem` — 515 bytes

No fallback/reconstructed SBZ art path was introduced.

A further 12 SBZ terrain/palette/layout files already retained by the project were also byte-for-byte checked against the re-supplied disassembly (`8x8 - SBZ.nem`, both Act 1/2 palettes, both foreground/background layouts, SBZ 16x16/256x256 mappings, collision, and both object-position sets). Together with the five new object-art streams, **17 / 17 selected Phase 41 SBZ source/data files are byte-identical**.

## Mapping validation

The generated `SBZSourceMaps` tables were parsed back and compared piece-for-piece with the supplied source mapping files. All comparisons passed:

- Rotating Junction — 17 frames
- Running Disc — 1 frame
- Trapdoor — 3 frames
- SBZ Spinning Platforms — 5 frames
- Saws and Pizza Cutters — 4 frames

Each piece comparison includes X/Y position, tile width/height, tile index, X/Y flip, palette offset, and priority flag.

## Authored placement validation

The project object-position binaries were decoded and checked for the newly routed families:

| Object | SBZ1 | SBZ2 |
|---|---:|---:|
| `$66` Rotating Junction | 2 | 0 |
| `$67` Running Disc | 0 | 8 |
| `$68` Conveyor | 0 | 20 |
| `$69` Trapdoor/Spinner | 25 | 31 |
| `$6A` Saw/Pizza Cutter | 3 | 11 |

Total newly native-routed authored records: **100**.

Additional checks confirmed:

- the two `$66` junction switch subtypes are `0` and `2`
- all eight final-game `$67` running discs use subtype `$40`

## Behavior assertions

Static assertions cover:

- `$66` exact 16-entry player-position table, 8-frame rotation timing, switch-edge direction reversal, entrance/release frames, and retained `$800` exit inertia
- `$67` source trigger/radius sizes, clockwise/counterclockwise inertia clamps, and `sticktoconvex` behavior
- `$68` source widths, signed speeds, vertical activation band, and grounded-only push
- `$69` ×60 / ×6 timers, synchronization mask, 17-step spinner sequence, and frame-0-only solidity
- `$6A` oscillator channels, speeding-saw trigger distances, `$600` velocity, and 48×48 hurt region
- SBZ1/2 catalog routing and playtest labeling
- REV01 SBZ1/2 background deformation rates
- SBZ1 `$1880/$2000` lower-boundary steps and SBZ2 `$1800` boundary change

## Phase 40 wrapping regression

Direct comparison with the pristine user-tested Phase 40 ZIP confirmed:

- `scripts/data/ghz_level_data.gd` remains byte-for-byte unchanged
- `scripts/render/ghz_renderer.gd` remains byte-for-byte unchanged
- `SonicPlayer.wrap_vertical_0x800()` remains textually unchanged
- `SonicCamera._vertical_wrap_enabled()` remains textually unchanged

The only Phase 41 additions to `sonic_player.gd` concern SBZ running-disc `sticktoconvex`; the only camera additions are the new SBZ dynamic-event paths.

## Runtime limitation

A Godot executable is not available in the packaging environment. Source equality, mappings, placement data, resources, structural checks, and regression isolation were validated here; the user's Godot 4.6.3 runtime remains authoritative for parser and gameplay behavior.
