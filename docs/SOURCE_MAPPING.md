# Disassembly → Godot foundation mapping

This file records which original routines/data the current native implementation corresponds to. It is intended to keep later gameplay ports traceable to the supplied disassembly.

| Native file | Original source/data represented |
|---|---|
| `scripts/compression/nemesis.gd` | `_inc/Decompression/Nemesis Decompression.asm` |
| `scripts/compression/enigma.gd` | `_inc/Decompression/Enigma Decompression.asm` |
| `scripts/compression/kosinski.gd` | `_inc/Decompression/Kosinski Decompression.asm` |
| `scripts/data/ghz_level_data.gd` | `LevelDataLoad`, `LevelLayoutLoad`, GHZ art/map/layout/palette/collision data |
| `scripts/render/ghz_renderer.gd` | Native replacement for the VDP-facing level drawing path; preserves block/tile flips and palette lines |
| `scripts/collision/genesis_collision.gd` | `FindNearestTile`, `FindFloor`, `FindFloor2`, `FindWall`, `FindWall2` |
| `scripts/collision/collision_debug.gd` | Native diagnostic only; no original-game equivalent |

## Important representation choices

- Rendering uses the visual block ID (`word & $3FF`), matching the level drawing routine.
- Collision lookup retains the original collision-facing block ID (`word & $7FF`), matching `FindFloor`/`FindWall`.
- Chunk ID 0 remains blank. Layout IDs are converted from 1-based IDs to zero-based chunk-buffer offsets only at lookup time.
- The high bit on layout chunk IDs is preserved for the GHZ loop special case. When an object is marked behind a loop, chunk `$28` can resolve to `$51`, matching `FindNearestTile`.
- Terrain collision remains data-driven. No Godot physics body or TileMap collision is substituted for the original height-map queries.

## Next gameplay source files

The next phase should port these onto `GenesisCollision` while preserving integer/fixed-point behavior:

1. `_incObj/01 Sonic.asm`
2. `_incObj/Sonic Collision.asm`
3. `_incObj/Sonic AnglePos.asm`
4. `_incObj/sub ObjectFall & SpeedToPos.asm`
5. `_incObj/sub ObjFloorDist.asm`

After Sonic can move through GHZ1, camera/deformation and the object manager can be layered on top.
