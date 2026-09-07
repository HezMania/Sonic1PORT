# Phase 6 validation notes

Target runtime: **Godot 4.6.3**.

The build environment used to package this project does not contain the Godot executable, so runtime behavior must still be confirmed in the user's Godot 4.6.3 editor. The following static/data checks were performed before packaging.

## Reported-issue checks

1. **Rock/platform support**
   - `SonicPlayer` now tracks a persistent object-standing state.
   - `_angle_pos()` exits through object support before terrain sensing, mirroring the original platform-standing early return.
   - jumping/springs/hurt/side collision clear support.

2. **Monitor top break**
   - monitor collision now computes player and monitor edges instead of center-distance `dy <= 24`.
   - attacking overlap is processed before solid-top resolution.

3. **Loop transition**
   - odd/sentinel sensor angles use Sonic's previous angle for the 90-degree snap, matching `Sonic_Angle`.
   - GHZ `$B5` loop state logic remains enabled.

4. **Moto Bug / Crabmeat ledges**
   - both use Genesis collision queries rather than blindly snapping only at their current center.
   - Crabmeat probes 16 pixels ahead.
   - stop thresholds are `< -8` and `>= 12`.

5. **Buzz Bomber**
   - wait, flight, proximity, fire, cooldown, reverse states are represented.
   - missile has a 15-frame flare delay and parent cancellation.

## Compatibility fixes retained

`sonic_visual.gd` still contains:

```gdscript
var angle_work = player.angle & 0xFF
var render_flip_x = player.facing_left
var octant_modifier = (angle_work >> 4) & 6
```

These remain ordinary `=` declarations as required by the tested Godot 4.6.3 project.

## Recommended first runtime tests

- Stand still on top of a purple rock for several seconds; Sonic should remain in a stable standing state (`obj:true`) rather than alternating into AIR/ball frames.
- Run off either edge of the rock; `obj:` should return false and Sonic should fall upright unless he was already rolling.
- Jump/roll onto a monitor from above; it should break instead of becoming a platform.
- Stand on a monitor without attacking; it should support Sonic normally.
- Run through the GHZ loop at useful speed with F2 enabled; watch `angle` pass through wall/ceiling quadrants and `loop:` toggle without a forced quadrant snap.
- Observe the first Moto Bug at X `$340`; it should reverse rather than drive over a large floor discontinuity.
- Observe Crabmeat movement near an edge and wait long enough for the alternating fire cycle.
- Approach Buzz Bombers to within roughly 96 pixels and verify hover/flight/fire/missile behavior.
