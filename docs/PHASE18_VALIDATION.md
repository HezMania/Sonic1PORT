# Phase 18 validation

Phase 18 was statically validated against the packaged project and the supplied Sonic 1 disassembly. The build environment does not contain a Godot 4.6.3 executable, so an editor/runtime launch remains the definitive behavioral test.

## Package checks

- 65 GDScript files scanned.
- 63 unique `class_name` declarations; no duplicates found.
- 481 PNG files decoded successfully; zero failed image decodes.
- 75 literal `res://` references checked; zero missing resources.
- No calls remain to the obsolete/nonexistent `find_right_wall()`, `find_left_wall()`, or `find_ceiling()` methods.
- Basic parentheses/brackets/braces structural scan found no unbalanced GDScript delimiters.

## Regression checks

- The Godot 4.6.3 Sonic animation compatibility declarations remain `=` assignments rather than inferred `:=` declarations.
- Dynamic viewport width/height access through `ProjectSettings` remains present in camera/object/background code.
- Moving spike subtype handling contains both vertical and horizontal branches, 32-pixel travel, and 60-frame endpoint delays.
- MZ falling bricks test the supporting block ID against the `$16A` lava range before entering the wobble state.
- Push blocks contain the native on-lava state and one-eighth inherited horizontal speed path.
- Collapsing-floor fragments validate their stored Sprite2D instance before casting/use, and delay countdown is separate from falling.
- Marble boss recovery clamps against `BOSS_Y+$60` and clears vertical velocity.
- Marble boss fire advances each spread front by `$A0` and stores 103-frame stationary flames.
- Caterkiller initial attachment accepts a zero-distance floor result and its unflipped body segments trail behind the head.

## Fire-art validation

The regenerated `lava_ball/00.png` through `05.png` frames use four non-transparent source colors:

- dark red `(145,0,0)`
- red `(255,0,0)`
- yellow `(255,255,0)`
- white `(255,255,255)`

This matches the intended Sonic palette entries used by the decoded Fireballs art and removes the prior blue/gray corruption.

## Recommended runtime test order

1. MZ1 push the green block off the chained stomper and onto the special button; confirm the button remains depressed and the stomper raises.
2. Compare a moving spike subtype `$x1` and `$x2` against a static `$x0` spike.
3. Let an Object `$46` falling brick land on an ordinary block: it should stop. Let the equivalent brick land on lava: it should wobble.
4. Trigger an Object `$53` floor and watch the eight pieces crumble/fall on their individual delays; stand over different columns to confirm support lasts until the local fragment falls.
5. Smash a green Object `$51` block and verify four visible fragments appear.
6. Use F10 to reach directional Marble fireballs and verify a wall/floor/ceiling hit transitions to an impact frame and then deletes the projectile.
7. Push a block into lava; verify it travels slowly across the lava, stops at a wall, and sinks.
8. Inspect Caterkiller again. Phase 18 improves its initial grounding/body direction and slope trail, but it is still not a bit-exact four-OST recreation.
9. Test the MZ3 boss defeat: Eggman should stop falling at the recovery floor near Y `$270`, rise, and escape; dropped fire should spread much more slowly with the corrected graphics.
