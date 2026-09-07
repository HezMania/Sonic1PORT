# Phase 31 validation report

Phase 31 was built from the user-tested Phase 30 project and checked against the re-supplied authoritative `s1disasm-AS(1).zip`. Runtime validation still requires Godot 4.6.3 because a Godot executable is not installed in the packaging environment.

## Reported rendering fixes

- LZ water-surface sprites now render as source high-priority sprites above high-priority Plane A terrain.
- Drowning/countdown number mappings no longer misread palette line 1 as a Y-flip flag; source frames 0/5/4/3/2/1 render upright.
- Sonic now latches the source high-priority sprite state while drowning and through the drowning-death transition, preventing him from disappearing behind foreground terrain.

## New LZ object families

Phase 31 adds source-driven implementations for:

- Object `$16` — LZ Harpoon
- Object `$2C` — Jaws
- Object `$2D` — Burrobot

Decoded placement counts:

| Object | LZ1 | LZ2 | LZ3 | Total |
|---|---:|---:|---:|---:|
| `$16` Harpoon | 8 | 6 | 14 | 28 |
| `$2C` Jaws | 8 | 7 | 7 | 22 |
| `$2D` Burrobot | 21 | 4 | 25 | 50 |
| **Total** | **37** | **17** | **46** | **100** |

## Exact source-asset verification

The following retained source files compare byte-for-byte with the re-supplied disassembly:

1. `artnem/LZ Vertical Door.nem`
2. `artnem/LZ Horizontal Door.nem`
3. `artnem/LZ Spiked Ball & Chain.nem`
4. `palette/Labyrinth Zone Underwater.bin`
5. `palette/Sonic - LZ Underwater.bin`
6. `artnem/LZ Water Surface.nem`
7. `artnem/LZ Water & Splashes.nem`
8. `artnem/LZ Bubbles & Countdown.nem`
9. `artnem/LZ Harpoon.nem`
10. `artnem/Enemy Jaws.nem`
11. `artnem/Enemy Burrobot.nem`

No replacement or reconstructed art was introduced for these objects.

## Static package checks

- GDScript files: **76**
- Named native classes: **73**
- PNG assets: **535**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough structural delimiter warnings: **0**
- Targeted Phase 31 assertions: **14 / 14 passed**

## Runtime test checklist

1. In LZ, verify the animated water surface remains visible when it overlaps foreground terrain.
2. Remain underwater until countdown digits appear; confirm 5/4/3/2/1 are upright and readable.
3. Drown near foreground terrain; Sonic should remain visible above the terrain through the sinking/death sequence.
4. Test horizontal and vertical Object `$16` harpoons, including flipped placements and their extension/retraction timing.
5. Test Jaws in all three acts; verify patrol direction, turn timing and animation.
6. Test Burrobots approaching from above/below their trigger regions; verify drilling wait, jump toward Sonic, gravity, walking/turning and ledge handling.
7. Re-test Phase 30 water palette, ripple, air bubbles, large-bubble Get-Air sequence and the LZ1 switch-5 progression door for regressions.

Godot 4.6.3 runtime/parser validation remains the final check because Godot is not available in this packaging environment.
