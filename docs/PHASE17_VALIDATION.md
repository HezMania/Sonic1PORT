# Phase 17 validation

Static validation performed on the packaged Godot 4.6.3 project:

- 65 GDScript files present.
- 480 PNG assets opened and verified successfully.
- 63 `class_name` declarations found with no duplicate class names.
- 76 literal `res://` resource references checked; none are missing.
- No remaining calls to nonexistent `.find_right_wall(...)`, `.find_left_wall(...)`, or `.find_ceiling(...)` APIs were found.
- The requested ProjectSettings-derived viewport width/height changes remain present in `sonic_camera.gd`, `object_manager.gd`, and `ghz_background_renderer.gd`.
- The Godot 4.6.3-safe Sonic animation declarations remain `var angle_work = ...`, `var render_flip_x = ...`, and `var octant_modifier = ...`.
- Phase 17 adds F10 free-move handling, pauses the level clock while active, bypasses ordinary solid/hazard/death interaction, and uses full-layout camera following.

A Godot executable is not available in the packaging environment, so runtime/parser validation in Godot 4.6.3 remains the authoritative final test.
