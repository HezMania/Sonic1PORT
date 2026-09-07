# Phase 21 validation report

## Package structure

- 65 GDScript files
- 63 unique `class_name` declarations
- 493 PNG assets
- No duplicate native class names detected
- All PNG assets successfully decode
- All concrete literal `res://` resource references resolve. Format-string paths such as `%02d.png` were validated by their generated asset families rather than treated as literal filenames.

## Regression checks

### MZ collapsing floor

- Normal and fragment support use `spawn_y - 8`, matching `PlatformObject`'s source 8-pixel platform height.
- 16×16 fragment Sprite2D centers use Y `0/16`, corresponding to source mapping top-left Y `-8/+8`.
- Existing per-fragment shuffled/swipe delays remain intact.

### Object $33 push block

- Push-block floor sensors use the source 15-pixel half-height.
- All affected `FindFloor` calls use 16-pixel tile stride; the erroneous 24-pixel stride is gone.
- Ledge snap retains ±`$400` X speed and 16-pixel X alignment before the fall state.
- Lava riding retains fractional `$80` carry.
- Manual pushing retains the user-validated slower native cadence.

### Caterkiller

- Head plus three body links retain independent X/facing state.
- All four links use 16-byte floor-map propagation.
- Body segment counters initialize to 4/8/12.
- Segment velocity is derived from previous-link velocity plus previous-link inertia.
- `$80` ledge markers propagate through the chain instead of flipping the whole badnik simultaneously.
- Middle body segment receives the animated body mapping while the outer two retain the base body frame.
- Body collision starts four-piece fragmentation with source X launch speeds `-$200,-$180,+$180,+$200` and Y `-$400`.

### Lavafall impact

- Pool bubble uses absolute z-index 110 so it draws in front of high-priority lava terrain while the falling lava column remains behind the pool surface.

### Marble boss

- `React_BossHit` negate/halve operation remains present.
- Native same-frame clipped `vel_x` can fall back to Sonic inertia.
- Side contacts separate Sonic just outside the 48×48 boss hitbox and clear stale ground inertia before the airborne rebound.

## Compatibility checks

The Godot 4.6.3 compatibility declarations remain:

```gdscript
var angle_work = player.angle & 0xFF
var render_flip_x = player.facing_left
var octant_modifier = (angle_work >> 4) & 6
```

Dynamic viewport sizing remains based on `ProjectSettings.get_setting("display/window/size/viewport_width")` / `viewport_height` in the previously requested camera/object/background paths.

No stale calls to nonexistent `.find_right_wall()`, `.find_left_wall()`, or `.find_ceiling()` remain.

## Static syntax/integrity checks

- Bracket/parenthesis/brace balance passed across all GDScript files.
- Block-indentation sanity check passed for all colon-delimited GDScript blocks.
- ZIP integrity is checked after packaging.

Godot itself is not installed in the artifact environment, so Godot 4.6.3 runtime behavior remains the authoritative parser/gameplay validation.
