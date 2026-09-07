# Phase 19 validation

This document records static/offline checks performed on the packaged Phase 19 project. A Godot 4.6.3 executable is not available in the build container, so editor/runtime behavior still requires in-engine validation.

## Targeted regression checks

- `marble_object.gd` contains an explicit `vel_x` declaration.
- No legacy calls to nonexistent `find_right_wall()`, `find_left_wall()`, or `find_ceiling()` APIs remain.
- Object `$52` uses `resolve_platform_top()` rather than full `resolve_solid_box_contact()` in its movement routine.
- The Object `$33` lava movement path feeds its integer movement delta into `move_with_supported_object()`.
- Caterkiller segment state is per-segment and includes separate X position, flip state, history position, floor map, velocity and inertia.
- MZ lava-wall frames 0-4 contain visible magma-body pixels instead of only the right-hand edge.
- MZ lavafall lower endcap starts from frame 6 rather than frame 17.
- The MZ boss creates the separate `mz_tube/00.png` child.
- Boss floor flames begin with active flame frame 0 and enter frame 2 only after their 103-frame damaging lifetime.
- The existing Godot 4.6.3 Sonic animation assignment compatibility lines are retained.
- Dynamic viewport width/height calls through `ProjectSettings` remain retained.

## Asset checks

All PNG assets in the project were decoded with Pillow during packaging. All seven animal folders contain three regenerated 64x64 frames. The reconstructed Marble lava-wall and boss-pipe assets are included under:

- `assets/objects/mz_lavawall/`
- `assets/boss/mz_tube/`

`docs/PHASE19_ASSET_FIXES.png` provides an offline visual sanity check of the reconstructed lava body, representative MZ animals, and the boss pipe.

## Package checks

The final package validation also checks:

- duplicate `class_name` declarations;
- literal `res://` file references;
- basic GDScript delimiter balance;
- retained viewport / animation compatibility lines;
- archive integrity with `unzip -t`.

### Final static counts

- GDScript files: 65
- unique `class_name` declarations: 63
- PNG assets successfully decoded: 492
- literal static `res://` references checked: 78
- static validation errors: 0

Representative non-transparent bounds also confirm that all regenerated animal frames contain visible source art and that lava-wall frames 0-4 now contain a broad body region (front frames span approximately X 64-220 on their generated canvases rather than only the old edge region).
