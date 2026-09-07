# Phase 24 validation report

Static validation was performed against the packaged Phase 24 project and the supplied Sonic 1 disassembly source.

## Project integrity

- GDScript files: **67**
- Named native classes: **65**
- PNG assets: **527**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Structural delimiter warnings: **0**

The Godot executable is not installed in the build environment, so the final parser/runtime validation remains the user's Godot 4.6.3 test.

## Phase 24 targeted checks

Passed:

- `GenesisLevelObject.suppress_central_despawn()` exists.
- `SYZObject` suppresses central despawn for Roller Object `$43` while secondary state 0 is waiting for activation.
- `SonicObjectManager.obj_pos_load()` honors the per-object suppress-despawn hook.
- F2 upward collision visualization recovers the logical Y coordinate from the source XOR-`$F` traversal coordinate.
- F2 leftward collision visualization recovers the logical X coordinate from the source XOR-`$F` traversal coordinate.
- SYZ Acts 1 and 2 are marked `full_gameplay_support`; SYZ3 remains pending its boss sequence.
- The three previously required Godot 4.6.3 `Sonic_Animate` declarations continue to use `=` rather than `:=`.
- Camera/object/background viewport sizing still derives from `ProjectSettings` rather than hard-coded 320×224 runtime widths.

## Source-rendered asset checks

- Yadrin frame 0: 96×96 canvas; visible bounds `(28,28)-(68,66)`.
- SYZ button raised: 64×64; visible bounds `(16,21)-(48,37)`.
- SYZ button depressed: 64×64; visible bounds `(16,27)-(48,37)`.
- SYZ Object `$18` platform: 96×64; visible bounds `(16,22)-(80,54)`, yielding the source 64×32 visual body.
- Object `$56` frame 2: exact 32×64 visual bounds.

The button export uses the source `ArtTile_Button_Main = ArtTile_Button + 4` offset, so the unused red switch-top tiles are not part of the normal SYZ raised/depressed frames.

## Spring Yard placement coverage

- SYZ1: **193** records, **18** distinct placed IDs.
- SYZ2: **230** records, **18** distinct placed IDs.
- SYZ3 REV01: **257** records, **16** distinct placed IDs.

All SYZ1/SYZ2 placed IDs route through native object classes. SYZ3 still requires the dedicated Spring Yard boss/block event before being promoted from preview support.
