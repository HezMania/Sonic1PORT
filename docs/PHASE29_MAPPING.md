# Phase 29 source mapping — Labyrinth fidelity correction

Phase 29 is built directly from the uploaded `Sonic1PC_SourceFidelity_Labyrinth_Phase28.zip` and uses the uploaded `s1disasm-AS(1).zip` as the authoritative source for the corrected LZ graphics and palettes.

## Godot 4.6.3 parser compatibility

Phase 28 introduced this local in `_initialize_lz_water()`:

```gdscript
var initial := [0x0B8, 0x328, 0x900][act - 1]
```

Godot 4.6.3 cannot infer a concrete type from that Variant-derived array access. Phase 29 uses the runtime-tested form:

```gdscript
var initial = [0x0B8, 0x328, 0x900][act - 1]
```

## LZ catalog state

The `ZONE_LZ` branch now explicitly writes:

```gdscript
d["full_gameplay_support"] = false
```

The key therefore exists for direct access, while LZ remains truthfully marked incomplete until its remaining gameplay systems and object families are finished.

## Object $56 — LZ doors

Authoritative disassembly source:

- `_incObj/56 SYZ, SLZ Floating Blocks and LZ Doors.asm`
- `_maps/Floating Blocks and Doors.asm`
- `artnem/LZ Vertical Door.nem`
- `artnem/LZ Horizontal Door.nem`

The original object selects `ArtTile_LZ_Door|Tile_Pal3`, so the native renderer uses palette line 2 (zero-based Genesis palette index 2).

### Frame 6 — small vertical door

`Map_FBlock .lzvert` contains two `2x4` tile pieces:

- upper piece at `(-8,-$20)`, local tile 0;
- lower piece at `(-8,0)`, local tile 0 with vertical flip.

The resulting source mapping occupies 16x64 pixels. Phase 29 decodes the retained original vertical-door Nemesis stream and composes those two mapping pieces exactly.

### Frame 7 — large horizontal door

`Map_FBlock .lzhoriz` contains four `4x4` pieces at X `-$40,-$20,0,$20`, all using source tile `$22` in the shared VRAM layout. `LZ Horizontal Door.nem` is a standalone stream beginning at its own local tile 0, so the native source renderer uses local tile 0 for each repeated 32x32 piece. The resulting mapping occupies 128x32 pixels.

Phase 29 no longer relies on a flattened/reconstructed door PNG for either frame.

## Object $57 — LZ spiked ball and chain

Authoritative disassembly source:

- `_incObj/57 SYZ, LZ Spiked Ball and Chain.asm`
- `_maps/Spiked Ball and Chain (LZ).asm`
- `artnem/LZ Spiked Ball & Chain.nem`

When the zone is LZ, the source changes from the SYZ art/mapping pair to `ArtTile_LZ_Spikeball_Chain` and `Map_SBall2`. That art tile has no palette bits set, so the LZ chain uses Genesis palette line 0.

The LZ mapping frames are:

- frame 0: 16x16 chain link, local tile 0;
- frame 1: 32x32 spike-ball tip, local tile 4;
- frame 2: 16x16 wall/base attachment, local tile `$14`.

The source starts LZ chain children with `col_none`; the final zero-radius child uses frame 2, while the parent is changed to frame 1 and `col_16x16|col_hurt`. Phase 29 mirrors that distinction: chain links and the base are visual only, and only the 32x32 parent tip damages Sonic. SYZ retains its existing source-specific damaging small-chain behavior.

## LZ underwater palette

Authoritative disassembly source:

- `_inc/Palette Index.asm`
- `palette/Sonic.bin`
- `palette/Labyrinth Zone.bin`
- `palette/Sonic - LZ Underwater.bin`
- `palette/Labyrinth Zone Underwater.bin`

Dry gameplay CRAM is represented by the 16-color Sonic palette plus the 48-color LZ zone palette, for 64 colors total.

`Labyrinth Zone Underwater.bin` is already a complete 128-byte / 64-color underwater palette. Its first 32 bytes are exactly the same 16 colors stored in `Sonic - LZ Underwater.bin`. This matches the source flow: the Sonic underwater line is loaded separately during early LZ setup, and the full LZ underwater palette is loaded for the water palette buffer later.

Phase 29 therefore **does not concatenate** `Sonic - LZ Underwater.bin` in front of the full underwater palette. It validates that the first 16 colors agree, then uses `Labyrinth Zone Underwater.bin` directly as the 64-color wet palette.

A screen-space palette pass applies those exact source CRAM colors below the dynamic Phase 28 waterline. This preserves the already validated background ripple and keeps the HUD on a higher CanvasLayer.

## Source-asset policy

The corrected LZ graphics/palettes are retained verbatim under `data/s1`. If one of the known original source assets is missing, the runtime source renderer reports the missing asset rather than generating replacement artwork or guessed colors.
