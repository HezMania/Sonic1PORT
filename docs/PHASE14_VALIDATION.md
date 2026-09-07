# Phase 14 validation

Static/package validation performed before delivery. A Godot 4.6.3 executable is not installed in the build environment, so the user's runtime test remains authoritative.

## Package inventory

- GDScript files: 57
- unique `class_name` declarations: 55
- PNG assets: 449
- total packaged files before ZIP: 646
- duplicate `class_name` declarations found: 0
- PNG decode failures: 0
- simple bracket/delimiter structural errors: 0
- concrete literal `res://` references missing: 0

Format-string resource paths (for example `%02d.png`) are validated by their generated asset families rather than treating the format string itself as a literal file name.

## Required Godot 4.6.3 compatibility baseline

Verified retained in `scripts/player/sonic_visual.gd`:

```gdscript
var angle_work = player.angle & 0xFF
var render_flip_x = player.facing_left
var octant_modifier = (angle_work >> 4) & 6
```

Verified retained dynamic viewport baseline:

- `sonic_camera.gd` reads `display/window/size/viewport_width` and `viewport_height`;
- `object_manager.gd` uses the configured viewport width for object activation;
- `ghz_background_renderer.gd` uses configured viewport width for its region.

## Marble data validation

MZ1 source data present and connected:

- foreground layout: 26 x 6 chunks;
- background layout: 20 x 6 chunks;
- Sonic start: `(48,614)`;
- object placement records: 145;
- distinct placed object IDs: 20;
- distinct MZ1 IDs with no native class route: 0.

MZ1 IDs:

`0D, 13, 22, 25, 26, 2F, 30, 31, 32, 33, 36, 46, 4B, 52, 54, 55, 71, 78, 79, 7D`

Additional act inventory for planning:

- MZ2: 198 records / 25 IDs; currently additional unsupported families `$4C,$4E,$51`.
- MZ3: 232 records / 23 IDs; currently additional unsupported families `$4C,$51,$53` plus the MZ boss event/object path.

## Phase 13 regression checks represented in code

- collapsing ledge support release is delayed until the first fragment timer reaches zero;
- runtime Sonic bounds are supplied from current camera boundaries;
- boss screen-lock enforcement is disabled during the prison's time-frozen sequence;
- Eggman face frame remains 5 throughout the hit timer;
- grounded rightward side pushing is given priority over shallow top overlap, mirroring the left side path;
- smashable walls reject airborne contacts and require pushing + rolling + minimum speed.

## New generated art validation

The Phase 14 object contact sheet is `docs/PHASE14_MZ_OBJECTS.png`.

Generated/new runtime families include:

- MZ grass platform;
- Marble brick;
- green glass block;
- switch/button;
- push block;
- moving block;
- chained stomper;
- lava/fire ball;
- Basaran;
- Caterkiller;
- Marble animal outputs (seal/squirrel).

All packaged PNGs pass PIL image verification.

## Known runtime/fidelity risks to test

1. MZ1 chained stomper timing/crush behavior across all placed subtypes.
2. Push-block/button interaction and edge cases around sloped floor.
3. Grass fire spread on depressed/oscillating grass platforms.
4. Basaran ceiling reattachment and offscreen reload behavior.
5. Caterkiller body positioning and terrain seams; exact segment RAM propagation remains deferred.
6. MZ background vertical transition through the lower interior route.
7. Prison/capsule forced-right exit after boss defeat, since this was reported as a Phase 13 runtime failure and cannot be executed in the packaging environment.

## Deferred by design

- GHZ loop front/back layer/chunk switch;
- scanline-perfect MZ deformation;
- full `AnimateLevelGfx` cycling;
- full MZ2/3 object gameplay;
- MZ3 boss;
- audio engine.
