# Phase 25 validation report

Phase 25 was statically validated against the packaged Phase 24 project and the Sonic 1 disassembly source. Godot is not installed in the packaging environment, so final parser/runtime behavior still requires the user's Godot 4.6.3 play-test.

## Targeted source/placement assertions

- Yadrin Object `$50` source collision type is `$CC` and now routes through a dedicated native special response rather than the generic badnik-only path.
- `$CC` source table entry uses 20×16 half extents.
- Yadrin's source special path tests shallow top penetration below 8 pixels and a facing-dependent 24-pixel horizontal strip before falling back to normal enemy behavior.
- Roller activation threshold remains Sonic X >= Roller X + `$100`.
- Roller generic central despawn is suppressed for all Roller states; its active range check uses current X and a `$280` aligned-screen threshold.
- Object `$56` subtype `$A0` maps to switch-driven type `$05`, frame 2, switch 0.
- The `(3824,579)` `$A0` record starts at Y 643 (`579 + 64`) and moves toward Y 579 at 2 pixels/frame after activation.
- Object `$56` subtype `$37` at X `$1BB8` waits on switch `$F` and moves 1 pixel/frame for `$380` pixels.
- `$1BB8 + $380 = $1F38` (`7096 + 896 = 7992`), matching the second `$37` placement record.
- The second `$37` placement is inactive before `syz_obj56_complete` and becomes stationary after completion.

## Regression/static package checks

Static package results:
- GDScript files: **67**
- named native classes: **65**
- PNG assets: **527**
- failed PNG decodes: **0**
- missing concrete literal `res://` resources: **0**
- duplicate `class_name` declarations: **0**
- targeted Phase 25 assertions: **PASS**

The Phase 25 packaging validation checks:
- all GDScript delimiter pairs are structurally balanced;
- no duplicate `class_name` declarations exist;
- all concrete literal `res://` references resolve;
- all packaged PNG files decode successfully;
- the Phase 25 source markers for Yadrin `$CC`, Roller current-X range handling, Object `$56` type 5, switch `$F`, and `$380` travel are present;
- ProjectSettings-driven viewport width usage remains present in the camera/object/background runtime paths;
- the previously required Godot 4.6.3 `Sonic_Animate` local declarations remain in their tested `=` form.

## Required runtime confirmation

1. Top/spike attack on Yadrin hurts Sonic and leaves Yadrin intact.
2. Non-spike attack on Yadrin still destroys it.
3. The `$A0` door near the reported area is visible at its correct offset and opens when switch 0 is pressed.
4. The first Act 1 Roller activates and pursues during a normal forward run without requiring backtracking.
5. The `$37` moving block begins after switch `$F`, moves at 1 px/frame, and reaches the destination area.
6. No regression to SYZ ordinary oscillator blocks, buttons, bumpers, spike chains, or prior Marble fixes.
