# Phase 27 validation report

Static validation was performed against the packaged Phase 27 project. Godot is not installed in the build environment, so Godot 4.6.3 runtime execution remains the authoritative gameplay/parser validation.

## Project integrity

- GDScript files: **69**
- Named native classes: **67**
- PNG assets: **535**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough structural delimiter warnings: **0**

## Phase 27 targeted assertions

Passed static/data checks:
- SYZ3 pre-boss block trigger exists at camera X `$2AC0`.
- SYZ3 boss trigger exists at camera X `$2C00`.
- The boss event creates **10** Object `$76` blocks.
- Block centers begin at `$2C10,$582` with `$20` X spacing.
- Object `$75` starts with **8 hits**.
- Boss patrol bounds, attack centers, descend target, lift velocities and escape end `$2D40` are represented in the native state machine.
- The arena right boundary remains `$2C00` until Eggman's escape expands it toward `$2D40`.
- SYZ3 is promoted to `full_gameplay_support`.
- Source-generated SYZ boss block whole frame is exactly **32x32**.
- LZ shared Object `$56` frame 6 now exists at **16x64**.
- LZ shared Object `$56` frame 7 now exists at **128x32**.
- The generated boss-block renderer was pixel-validated against Phase 26's existing source-rendered Object `$56` frame 0.

## Visual-fidelity boundary

The source Boss-Weapons spike art and the two LZ door art sets are separate Nemesis PLC resources and were not packaged in the Phase 26 source tree. Phase 27 therefore uses source-sized native reconstructions for those three visual resources while retaining their source gameplay dimensions/routines. The SYZ boss arena blocks themselves are rendered directly from the packaged original SYZ level art.

## Runtime test checklist

1. Enter SYZ3 normally and approach camera X `$2AC0`; verify the ten 32x32 arena blocks are present before the boss arrives.
2. Reach `$2C00`; verify the arena locks and the bottom boundary settles near `$4CC`.
3. Verify Eggman enters from the right and patrols above the ten blocks.
4. Stand on different intact blocks and confirm Eggman targets Sonic's current 32-pixel block column.
5. Confirm the spike descends, Eggman grabs/lifts the selected intact block, shakes it, breaks it into four fragments, retracts the spike and resumes patrol.
6. Stand beneath a column whose block has already been destroyed and verify Eggman can perform the empty-block attack without deadlocking.
7. Hit Eggman eight times; verify boss rebound, hit flashing, explosion period, recovery and rightward escape.
8. Verify the camera/right boundary opens toward `$2D40` during escape and the act-end path remains reachable.
9. In Labyrinth, inspect both Object `$56` door forms and confirm the vertical/horizontal frames are now visible and maintain their existing switch/collision behavior.
