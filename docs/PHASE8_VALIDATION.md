# Phase 8 validation

Static checks performed before packaging:

- 38 GDScript files present.
- 274 PNG assets decode successfully.
- 8 monitor power-up icon textures generated.
- all literal `res://` references resolve.
- legacy `_choose_sensor()` calls are gone from `sonic_player.gd`.
- separate grounded `_choose_ground_sensor()` and airborne `_choose_air_sensor()` paths are present.
- airborne floor queries do not request the grounded `$03` sentinel.
- the three runtime-tested Godot 4.6.3 `Sonic_Animate` `=` declarations remain unchanged.
- ZIP archive passes `unzip -t` integrity testing.

A Godot executable is not available in the build environment, so runtime behavior—particularly full-loop traversal—still requires the user's Godot 4.6.3 test.
