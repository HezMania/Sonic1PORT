# Phase 15 validation

This package was statically validated in the build environment. The Godot executable is not installed there, so runtime behavior still requires Godot 4.6.3 testing.

Checks performed:

- all literal `res://` references point to packaged files;
- all PNG assets decode with Pillow;
- duplicate `class_name` declarations checked;
- bracket/parenthesis/brace balance checked across GDScript files;
- MZ1/MZ2/MZ3 object-placement files parsed and distinct IDs compared with native ObjectManager routes;
- MZ2 `$4C/$4E/$51` placements verified;
- MZ3 `$4C/$51/$53/$3E` placements verified;
- MZ3 boss is correctly treated as a DynamicLevelEvent spawn rather than an object-position record;
- Page Down is used for next-zone debugging; no F8 handler remains;
- `LevelCatalog.next_zone()` skips zones whose `full_gameplay_support` is false;
- ProjectSettings-driven viewport width/height changes remain present;
- Sonic_Animate Godot 4.6.3 compatibility assignments using `=` remain present;
- ZIP integrity tested after packaging.

Known fidelity boundaries:

- Object `$74` floor-fire spreading is source-driven but simplified versus the exact duplicate/fall-edge RAM routine;
- MZ lavafall composite ownership is native rather than multiple OST slots;
- full Marble `AnimateLevelGfx` cycling is still deferred;
- scanline-perfect Marble background deformation is still deferred;
- exact Caterkiller body-segment propagation remains deferred;
- GHZ loop front/back chunk/layer switching remains deferred.
