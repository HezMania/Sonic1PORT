# Phase 7 Validation Notes

## Static package validation

The Phase 7 tree was checked for:

- missing literal `res://` resource references;
- unmatched basic GDScript brackets/parentheses/braces;
- presence of the three Godot 4.6.3 `Sonic_Animate` `=` compatibility lines;
- presence of Phase 7 angle-buffer carry logic;
- Newtron and Chopper dedicated state routines;
- Newtron missile creation path;
- PNG asset readability and expected object frame sets;
- ZIP integrity after packaging.

The project contains 37 GDScript files and 266 PNG assets.

## GHZ1 placement data

`objpos/ghz1.bin` contains 214 placement records plus the `$FFFF` terminator.

Relevant Phase 7 objects in GHZ1:

- Object `$42` Newtron: **10** placements
- Object `$2B` Chopper: **5** placements

Both blue (`subtype 0`) and green (`subtype 1`) Newtron placements are present in GHZ1.

## Collision fidelity check

The Phase 7 collision result now distinguishes:

1. distance returned by a tile/neighbor query;
2. whether the original angle buffer was actually written;
3. the angle value that remains in that shared buffer.

This is necessary because a blank `FindFloor2`/`FindWall2` result can legitimately provide a distance while leaving the primary collision angle untouched.

## Runtime validation still required

No Godot executable is installed in the build environment, so Godot 4.6.3 runtime testing remains authoritative.

Recommended first checks:

1. Enter the main GHZ loop at normal running speed and watch `angle:$XX` plus `loop:true/false`.
2. Verify Sonic stays attached through the upper-left/ceiling seams instead of being kicked backward.
3. Approach an Object `$42` blue Newtron: it should appear, fall, land, then move horizontally.
4. Reach a green Newtron later in GHZ1: it should appear/fire once rather than drop.
5. Observe a Chopper over water: it should repeatedly leap and return to its spawn height.

If the loop still fails, F2 sensor debug plus the HUD angle/velocity readout should isolate the remaining transition without adding a loop-specific movement hack.
