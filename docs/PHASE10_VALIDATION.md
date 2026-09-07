# Phase 10 validation notes

Static validation performed in the build environment:

- Phase 9 project copied as the base; all prior player, badnik, effects, camera, and collision scripts retained.
- Godot 4.6.3 `Sonic_Animate` compatibility declarations remain `=` rather than `:=` for `angle_work`, `render_flip_x`, and `octant_modifier`.
- 36 Phase 10 UI PNGs generated from the supplied Sonic 1 disassembly assets.
- HUD source assets decode to 24 HUD tiles; life-counter Nemesis art decodes to 12 tiles; GAME/TIME OVER art decodes to 34 tiles.
- Buzz/Newtron projectile X flip now matches the parent-status convention (`horizontal_velocity > 0`).
- Springs and spikes call the new side-reporting solid-box bridge, so side/back collisions are resolved even when no bounce/damage is triggered.
- TIME OVER threshold is 35,999 60-Hz ticks (`9:59:59`).
- Debug F5 starts the clock 120 ticks before that threshold for quick runtime testing.
- Remaining GHZ loop layer/chunk switching is intentionally unchanged.

The environment used to package the project does not contain a Godot executable, so the final parser/runtime validation must still be performed in Godot 4.6.3.
