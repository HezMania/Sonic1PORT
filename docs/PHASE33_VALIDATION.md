# Phase 33 validation report

Phase 33 was built from the full user-tested Phase 32 project and checked against the re-supplied authoritative `s1disasm-AS(1).zip`. A Godot executable is not installed in the packaging environment, so final runtime/parser validation remains the user's Godot 4.6.3 editor.

## New progression coverage

Phase 33 adds native source-driven coverage for:
- `LZWindTunnels` — all four LZ tunnel rectangles;
- `LZWaterSlides` — all seven source slide chunk IDs/speeds;
- Object `$0B` — five LZ3 breakable poles;
- Object `$0C` — two flapping doors;
- Object `$63` — 36 ordinary authored records plus 53 source-data moving platforms.

Placement scan of the packaged final-game objpos files:

| Object | LZ1 | LZ2 | LZ3 | Total |
|---|---:|---:|---:|---:|
| `$0B` pole | 0 | 0 | 5 | 5 |
| `$0C` flap door | 0 | 1 | 1 | 2 |
| `$63` normal records | 13 | 10 | 13 | 36 |

Custom conveyor platform files contain `8,8,8,8,12,9` entries = **53** moving platforms.

## Exact source verification

**26 / 26** checked retained LZ source/data files compare byte-for-byte with the re-supplied disassembly.

This includes the 13 previously checked LZ Nemesis streams, the two underwater palette binaries, and Phase 33's new exact files:
- `LZ Breakable Pole.nem`
- `LZ Flapping Door.nem`
- `LZ Wheel.nem`
- six `objpos/platforms/lz*.bin` files
- dry and underwater LZ conveyor palette-cycle binaries.

No replacement graphics or guessed conveyor path data were added.

## Targeted behavior assertions

All **16 / 16** Phase 33 assertions passed:
1. `LZWaterFeatures` executes after dynamic-water update and before Sonic's tick.
2. All four source LZ wind rectangles are present.
3. Tunnel direct `+4 px` movement and `$400` X velocity are present.
4. LZ2 reverses the 2 px suction vertically.
5. All seven source water-slide chunks and forced inertia values are present.
6. Slide exit applies `locktime=5`.
7. Slide mode bypasses normal walk acceleration and roll drag/roll initiation.
8. Pole break timing is subtype × 60.
9. Pole collision touch latches and any release permanently advances to display-only.
10. Flap period is subtype × 60 and the closed/left-of-door blocker rule is present.
11. Switch `$E` performs one-time conveyor reversal.
12. Wheel animation updates every fourth level frame.
13. The exact six conveyor platform binaries are loaded.
14. Exact-source pole/flap/conveyor art functions are present.
15. Sonic uses source Float2/Hang/Slide frame sequences.
16. Object IDs `$0B/$0C/$63` route to the Phase 33 native progression class.

## Package-integrity checks

- GDScript files: **78**
- Named native classes: **75**
- PNG assets: **535**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough structural delimiter warnings: **0**
- Exact checked source/data files: **26 / 26**
- Targeted Phase 33 assertions: **16 / 16**

## Runtime checklist for Godot 4.6.3

1. Enter each LZ wind/current tunnel. Sonic should be carried right with the Float2 animation and allow one-pixel UP/DOWN steering.
2. In LZ2, verify the initial 128 px suction pulls upward; LZ1/LZ3 should pull downward.
3. Test the LZ2 and LZ3 flapping doors: a fully closed door should both block Sonic and disable the tunnel until it opens/passes.
4. In LZ3, catch each breakable pole from the tunnel. Sonic should hang to its right, climb within the source limits, release on jump, and never re-grab that same pole after releasing. Waiting 240 frames should break the authored subtype-4 pole.
5. Ride all seven water-slide chunk types. Direction/speed should match the terrain and movement input should not fight the forced slide; jumping should remain possible.
6. Ride conveyor platforms through corners and verify smooth carrying. Press switch `$E`; platforms and decorative wheels should reverse and stay reversed.
7. Pay special attention to the wide LZ3 conveyor groups because they exercise the longest source target loops/fractional component speeds.
8. Confirm all previously validated Phase 29–32 water palette/ripple, drowning, enemies, blocks, Gargoyle and waterfall behavior remains unchanged.

The original conveyor palette cycling and water/door/rush SFX are intentionally not claimed as implemented in this phase.
