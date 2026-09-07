# Phase 3 validation notes

Generation-time checks performed on this package:

- Phase 1 decompression/data files and Phase 2 Sonic files are retained.
- The user-confirmed Godot 4.6.3 `Sonic_Animate` assignment changes are present.
- `objpos/ghz1.bin` parses to 214 records before the `$FFFF` terminator.
- The records are sorted by X as required by camera-window object loading.
- 20 distinct GHZ1 object IDs are represented in the placement file.
- The manager exposes 96 native level-object slots.
- GHZ1 camera constants match the supplied `LevelSizeArray` entry.
- Object sprites were regenerated after correcting Genesis `Tile_Pal2/3/4` to palette indices 1/2/3.
- The reconstructed GHZ background is a native PNG and is sampled with nearest filtering.
- All `res://` file paths referenced by `load()` / `ResourceLoader.exists()` in the Phase 3 scripts were checked against the package where they are static literal paths.
- All 186 PNG assets in the package (Sonic, GHZ background, and Phase 3 object frames) decode successfully.
- The initial GHZ1 camera resolves to top-left `(0, 768)` from Sonic's `(80, 944)` start; the initial object window contains the first ring group and the ring monitor.
- Every object class referenced by the Phase 3 manager has a corresponding registered `class_name` script.
- ZIP integrity is checked after packaging.

## Runtime note

The generation environment does not contain a Godot executable, so the final project still requires an editor/runtime test in Godot 4.6.3. Phase 2 was already confirmed by the user in that version; Phase 3 was built directly from that working tree and retains the reported compatibility correction.
