# Phase 29 validation report

Phase 29 was built directly from the user-uploaded `Sonic1PC_SourceFidelity_Labyrinth_Phase28.zip`. The user-uploaded `s1disasm-AS(1).zip` was used as the authoritative source for corrected LZ object art/mappings and underwater palette data. The Phase 28 water-height logic and already validated REV01 background ripple were preserved.

Godot itself is not installed in the packaging environment, so final parser/runtime validation remains Godot 4.6.3.

## Reported runtime issues addressed

1. `object_manager.gd` Phase 28 line 343 no longer uses `:=` for the Variant-derived `initial` value; it uses `=`.
2. The LZ level-catalog branch explicitly contains `d["full_gameplay_support"] = false`.
3. Object `$56` LZ doors no longer use the incorrect flattened mapping assumption. Runtime composition follows the original vertical and horizontal mapping pieces.
4. Object `$57` branches by zone and uses the original LZ chain/link/tip/base art instead of SYZ graphics in Labyrinth.
5. The exact LZ underwater CRAM palette is applied below the dynamic waterline while the HUD remains above the palette layer.

## Exact source-asset verification

The following retained project files compare byte-for-byte with the uploaded disassembly:

- `artnem/LZ Vertical Door.nem` — 161 bytes — SHA-256 `70af1b28015f1a04287c1b6384cf5dad2fd2aa27c4ddc63e80bdf0ec4f013993`
- `artnem/LZ Horizontal Door.nem` — 338 bytes — SHA-256 `8bdcc84e27d72b6ee774b76b43e9448421b47cbd7c33880f4b10e338764fdd18`
- `artnem/LZ Spiked Ball & Chain.nem` — 384 bytes — SHA-256 `84c49092c3fc9e8021eb934c3996e89e35e06d4e4b7abea6effbd4e6e51fb71f`
- `palette/Labyrinth Zone Underwater.bin` — 128 bytes — SHA-256 `4e90fa50d2cac1d6b038902cf3abe2d6e68efd29d5d7f1691beeedee946639ca`
- `palette/Sonic - LZ Underwater.bin` — 32 bytes — SHA-256 `4b36b60bad7def59a5df7810ab10f5db5c58c0aad1ef81c9ad2ee0e450924c91`

The first 32 bytes of `Labyrinth Zone Underwater.bin` exactly match `Sonic - LZ Underwater.bin`. The Phase 29 palette path validates this relationship and then uses the 128-byte LZ underwater file directly as the complete 64-color wet palette.

## Static package checks

- GDScript files: **71**
- Named native classes: **68**
- PNG assets: **535**
- Failed PNG signature checks: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough `()`, `[]`, `{}` delimiter warnings: **0**
- Phase 29 targeted assertions: **PASS**
- ProjectSettings-driven viewport width remains present in `object_manager.gd`.
- The underwater palette controller obtains viewport height from ProjectSettings rather than hard-coding 224.

## Runtime test checklist

1. Open the project in Godot 4.6.3 and confirm parsing proceeds past `_initialize_lz_water()` with no type-inference error.
2. Enter LZ and confirm the existing Phase 28 background ripple still behaves exactly as before.
3. Inspect small vertical Object `$56` doors: the lower 16x32 half should be the source piece vertically flipped, producing the original in-game door appearance.
4. Inspect large horizontal Object `$56` doors: all four 32x32 mapped pieces should appear in the original arrangement.
5. Inspect Object `$57`: LZ should show its own chain links, large 32x32 tip, and distinct wall/base piece instead of the SYZ spike-ball art. Only the large tip should hurt Sonic.
6. Cross the waterline and verify the level/Sonic colors below it switch to the original underwater palette while the HUD remains dry.
7. Verify the dynamic water height and background ripple continue to track each other as the LZ water state changes.

LZ intentionally remains `full_gameplay_support = false` until the remaining LZ gameplay systems and object families are completed.
