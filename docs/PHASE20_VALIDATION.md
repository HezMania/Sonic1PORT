# Phase 20 validation

Static validation was performed against the Phase 20 package before archiving.

## Package checks

- 65 GDScript files.
- 63 unique `class_name` declarations; no duplicates.
- 493 PNG assets; all decode successfully.
- All literal `res://` resource references resolve.
- No stale calls to `find_right_wall()`, `find_left_wall()`, or `find_ceiling()` remain.
- Rough delimiter checks found no unmatched `()`, `[]`, or `{}` in GDScript sources.
- The MZ boss pipe export is now 96×96 with an unclipped 16×16 mapped piece.

## Targeted Phase 20 assertions

- Push blocks use current moved X for centralized out-of-range handling.
- Push-block lava carrying has a fractional 16.16 player bridge.
- Push blocks have distinct grounded / ledge-snap / falling states.
- Object `$52` handles stand-triggered subtype `$02/$04` transitions.
- Caterkiller floor probes use the source 7-pixel half-height.
- Caterkiller body segments follow independent 12/24/36px delayed path positions.
- MZ3 boss lock settles to screen X `$1800`.
- Boss fire is placed behind the boss (`z_index 45` vs boss `46`).
- Falling lava has a restored pool `.bubble1` impact sequence.

## Placement data retained

- MZ1: 145 placement records / 20 distinct IDs.
- MZ2: 198 placement records / 25 distinct IDs.
- MZ3: 232 placement records / 23 distinct IDs.

Godot itself is not installed in the packaging environment, so the user's Godot 4.6.3 runtime remains the authoritative behavioral/parser test.
