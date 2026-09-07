# Phase 4 validation notes

## Static/data validation performed

- Phase 4 was copied from the user's confirmed-working Godot 4.6.3 Phase 3 tree.
- The three known `Sonic_Animate` Godot 4.6.3 assignment fixes remain present.
- The right camera formula was compared directly with `MoveScreenHoriz` / `SH_MoveCameraRight` in the supplied disassembly.
- Camera boundary examples were evaluated for 143, 144, 160, 161, 168, 176 and 200 px screen-relative positions.
- The Object 37 32-ring initial velocity table was generated directly from the original `$288` spread algorithm and the ported Sonic 1 sine table.
- Signpost graphics were reconstructed from `artnem/Signpost.nem` + `_maps/Signpost.asm`; 5 frames were generated.
- Lamppost graphics from Phase 3 are reused for the now-active checkpoint implementation.
- GHZ1 object placement still contains 214 records across 20 IDs.

## Known runtime-validation limitation

The build environment used to assemble this package does not contain a Godot executable, so final parser/runtime behavior must be verified in Godot 4.6.3. Phase 4 intentionally modifies the already user-validated Phase 3 tree rather than rebuilding the foundation independently.

## Recommended first checks

1. Start GHZ1 and move slowly right: the camera should move smoothly one pixel at a time after Sonic passes the 160 px screen-relative threshold.
2. Move left and right around the dead zone to verify symmetric tracking.
3. Collect rings, touch spikes/badnik, and confirm rings scatter and Sonic enters the injury state.
4. Recollect a spilled ring after the initial no-collection window.
5. Take damage with zero rings and confirm the death/restart path.
6. Activate either lamppost, die, and confirm respawn at that lamppost with zero rings.
7. Break monitor subtypes and verify ring/life/shoes/shield/invincibility behavior.
8. Reach the signpost and verify three spin cycles followed by forced right movement.
