# Phase 26 validation report

Phase 26 was statically validated against the Phase 25 package and the supplied Sonic 1 data. Runtime validation still requires Godot 4.6.3 because the Godot executable is not installed in the build environment.

## Targeted source checks

- SYZ vertical source rate remains `$30/$100 = 3/16`.
- SYZ REV01 horizontal buffer is represented as 8 cloud + 5 mountain + 6 building + 14 bush rows = **33** 16-pixel entries.
- SYZ uses `levels/syzbg (REV01).bin`; decoded background dimensions are 28×2 chunks = **7168×512 pixels**.
- The native SYZ renderer uses a repeatable source-plane texture and visible 16-pixel strips rather than moving the entire background at one X rate.
- LZ now selects `background_mode = "lz"` and uses the REV01 base `$80/$100` = **1/2 X / 1/2 Y** parallax.
- LZ underwater ripple remains explicitly deferred until native water height/drowning state exists.
- LZ remains excluded from `full_gameplay_support`; no unsupported object family is being represented as complete.

## LZ placement scan

- LZ1 REV01: **189** records / **22** distinct IDs.
- LZ2: **138** records / **21** distinct IDs.
- LZ3 REV01: **245** records / **21** distinct IDs.

## Runtime test checklist

1. Load SYZ1/2/3 and move horizontally through areas where sky, mountain/building and lower bush layers are simultaneously visible. The layers should no longer travel as one rigid background plane.
2. Move vertically in SYZ. Background Y should continue to move much more slowly than foreground Y (3/16 source relationship), without seams between 16-pixel bands.
3. Enter a Labyrinth preview through the existing level/debug selection path. Its background should now render from the supplied LZ layout/art and move at half camera X/Y rather than remaining unhandled.
4. Do not treat LZ water behavior as complete in this phase: ripple, underwater physics, drowning and LZ-specific objects are the next implementation work.

Static package-integrity results are recorded in the root README/package build notes.

## Package integrity

- GDScript files: **67**
- Named native classes: **65**
- PNG assets: **527**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough structural delimiter warnings: **0**

Godot itself is not installed in the packaging environment, so the user's Godot 4.6.3 runtime remains the final parser/behavioral validation.
