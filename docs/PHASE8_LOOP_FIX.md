# Phase 8 loop collision correction

## What Phase 7 fixed
Phase 7 restored the grounded `$03` angle-buffer preload and `FindFloor2`/`FindWall2` angle-buffer carry behavior.

## Remaining mismatch
The native player then used the same `_choose_sensor()` behavior for both grounded `Sonic_Angle` and airborne `Sonic_FindSmaller`.

That is not what the original does.

### Grounded `Sonic_Angle`
If the selected angle has bit 0 set, the original reads Sonic's previous `obAngle`, adds `$20`, and masks with `$C0`. This preserves the current surface quadrant across blank seams.

### Airborne `Sonic_FindSmaller`
If the selected angle has bit 0 set, the original copies `d2` into the returned angle. `d2` was explicitly initialized to the cardinal direction of the collision query: floor `$00`, left wall `$40`, ceiling `$80`, right wall `$C0`.

Phase 7 incorrectly used Sonic's previous loop angle in both cases. If Sonic detached briefly near the exit and then touched ordinary floor, he could re-land with a wall/ceiling angle. That explains the tilted post-loop fall and temporary floor penetration reported in runtime testing.

## Phase 8 implementation
- `_choose_ground_sensor(d0_result, d1_result)` models `Sonic_Angle`.
- `_choose_air_sensor(d0_result, d1_result, snap_angle)` models `Sonic_FindSmaller`.
- Airborne full-size floor/ceiling queries no longer request the grounded `$03` preload.
- Wall/floor sensor pairs now preserve the original `d1`-wins-on-equal-distance rule.

No scripted loop trajectory, forced velocity, or loop-specific position correction has been added.
