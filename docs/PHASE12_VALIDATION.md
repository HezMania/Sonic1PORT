# Phase 12 validation

## Static package checks

- Godot scripts: 49
- PNG assets: 356
- PNG decode failures: 0
- Missing literal `res://` references: 0
- Duplicate `class_name` declarations: 0
- Basic delimiter/balance errors: 0

The known Godot 4.6.3 compatibility declarations remain present in `sonic_visual.gd`:

```gdscript
var angle_work = player.angle & 0xFF
var render_flip_x = player.facing_left
var octant_modifier = (angle_work >> 4) & 6
```

## Green Hill placement coverage

| act | placement records | unsupported placed IDs |
|---|---:|---|
| GHZ1 | 214 | none |
| GHZ2 | 244 | none |
| GHZ3 | 286 | `$3E` prison/capsule |

Object `$3E` is deliberately paired with the future GHZ3 boss/end sequence because its switch uses boss-status state and triggers the animal-release completion flow.

## New asset reconstruction

All new images were generated from the supplied disassembly assets/mappings:

- GHZ swinging platform: 3 frames (block, chain, anchor)
- GHZ smashable wall: 3 complete wall frames
- GHZ smash fragment art: 3 tile-group frames
- GHZ spiked pole helix: 8 rotation frames

See `PHASE12_OBJECTS.png` for a nearest-neighbor inspection sheet.

## Behavior checks performed outside Godot

- Shared `$1A` oscillator output traverses the intended 0..$80 range and repeats continuously.
- Object `$18` subtype calculations produce horizontal/vertical displacement rather than fixed placement coordinates.
- GHZ2's four subtype `$0A` large platforms are routed through the half-range vertical path.
- GHZ3's four Object `$17` records use subtype `$10`, producing 16 spike instances per helix.
- Horizontal spring placement polarity was checked against GHZ2/GHZ3 data: the placed sideways springs are X-flipped, so their active contact is the object's left face and their launch velocity is leftward.
- Death collision guards are present in both the platform-top and full-solid native bridges.
- Camera update exits before horizontal/vertical tracking while `player.dead`.

## Runtime limitation

The packaging environment does not contain a Godot executable, so the project could not be parsed/executed by Godot here. The previous phases were validated by the user in Godot 4.6.3; this build intentionally retains that API/style baseline.
