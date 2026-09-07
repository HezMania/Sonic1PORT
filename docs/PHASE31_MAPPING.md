# Phase 31 source mapping — Labyrinth render priority / Harpoon / Jaws / Burrobot

Phase 31 is built directly on the full Phase 30 project. The re-supplied `s1disasm-AS(1).zip` remains the authoritative source. No known LZ graphics are redrawn or substituted.

## Rendering corrections from Phase 30 play-test

### Object $1B — LZ water surface

Source:
- `_incObj/1B LZ Water Surface.asm`
- `_maps/Water Surface.asm`
- `artnem/LZ Water Surface.nem`

`Surf_Main` sets:

```asm
move.w #ArtTile_LZ_Water_Surface|Tile_Pal3|Tile_Prio,obGfx(a0)
```

Phase 30 placed the surface below the native high-priority Plane A layer. Phase 31 maps the source `Tile_Prio` state to a high sprite layer (`z_index = 130`), above the renderer's high-priority terrain layer (`z = 100`). The original interlace/camera wrapping and 8-frame animation from Phase 30 are unchanged.

### Sonic during drowning

Source:
- `_incObj/0A LZ Drowning Countdown.asm`

When air expires, the source performs:

```asm
bset #7,obGfx(a0)
```

This makes Sonic's sprite high priority before the two-second sinking state. Phase 31 adds a `sprite_high_priority` latch to `SonicPlayer`: drowning sets it, `finish_drowning_death()` preserves it, and normal respawn/non-drowning death clears it. `refresh_visual()` maps that latch to native z 120, above high-priority terrain.

### Countdown number orientation/palette

Source:
- `_maps/Bubbles.asm`
- `artnem/LZ Bubbles & Countdown.nem`

Phase 30 interpreted the last `spritePiece` arguments on the full number mappings as if the `1` were a vertical-flip flag. In the source macro order the relevant tail is **x-flip, y-flip, palette, priority**. For example:

```asm
spritePiece -8,-$C,2,3,$44,0,0,1,0
```

Therefore the full 0/5/4/3/2/1 frames are unflipped and use palette line 1. Phase 31 renders source tiles `$44,$4A,$50,$56,$5C,$62` as unflipped 2×3-tile sprites with palette line 1. They remain source high-priority number bubbles (`z = 125`).

## Object $16 — LZ Harpoon

Source:
- `_incObj/16 LZ Harpoon.asm`
- `_anim/Harpoon.asm`
- `_maps/Harpoon.asm`
- `artnem/LZ Harpoon.nem`

Native implementation:
- subtype 0 begins the horizontal animation; subtype 2 begins the vertical animation;
- source animation delay 3 means four ticks per animation frame;
- horizontal extend: frames `1,2`; retract: `1,0`;
- vertical extend: frames `4,5`; retract: `4,3`;
- wait timer remains 60 with the source zero-inclusive countdown (61 object ticks before switching direction);
- placement X/Y flip flags mirror the complete mapped object;
- exact source hurt hitboxes are represented from `React_Sizes`:
  - frame 0: 16×8;
  - frame 1: 48×8;
  - frame 2: 80×8;
  - frame 3: 8×16;
  - frame 4: 8×48;
  - frame 5: 8×80.

The six mapped frames are decoded at runtime from the retained original `LZ Harpoon.nem` stream. No PNG approximation is used.

## Object $2C — Jaws

Source:
- `_incObj/2C Badnik - Jaws.asm`
- `_anim/Jaws.asm`
- `_maps/Jaws.asm`
- `artnem/Enemy Jaws.nem`

Native implementation:
- source collision: `col_32x24|col_badnik` (16×12 half-extents);
- REV01/FixBugs active display width: `48/2`;
- initial X speed: `-$40`, negated when placement/status bit 0 is set;
- turn delay: `(subtype << 6) - 1` frames;
- direction and render flip toggle together on each turn;
- animation delay 7, frames `0,1,2,3`;
- frames 2/3 retain the source per-piece Y flip on the tail rather than flipping the whole sprite;
- ordinary Sonic 1 badnik hit/hurt response is used.

Jaws art is decoded from the exact `Enemy Jaws.nem` source using `Tile_Pal2` / palette line 1.

## Object $2D — Burrobot

Source:
- `_incObj/2D Badnik - Burrobot.asm`
- `_anim/Burrobot.asm`
- `_maps/Burrobot.asm`
- `artnem/Enemy Burrobot.nem`

Native secondary-state mapping:
- state 3 — `Burro_Action_ChkSonic`;
- state 2 — `Burro_Action_Jump`;
- state 1 — `Burro_Action_Move`;
- state 0 — `Burro_Action_TurnAround`.

Source values retained:
- collision: `col_24x36|col_badnik` (12×18 half-extents);
- trigger horizontal distance: 96 px;
- Sonic must be above Burrobot and no more than 128 px above;
- launch Y speed: `-$400`;
- launch/walk X speed: `$80` toward current facing;
- airborne gravity: `+$18` per tick;
- movement timer: 255;
- turn wait: 59;
- forward ledge probe: 12 px;
- ledge threshold: floor distance `>= $0C`;
- ledge/floor alignment alternates every frame;
- the source `v_vblank_byte` bit-2 50/50 branch is represented with the object's continuously incrementing frame counter, independent of the gameplay time counter;
- animation delay 3 with source frame sequences `0,6`, `0,1`, `2,3`, and `4`.

All seven mapped Burrobot frames are decoded from `Enemy Burrobot.nem` at runtime.

## Placement coverage

From the packaged REV01 LZ object-position data:

| Object | LZ1 | LZ2 | LZ3 | Total |
|---|---:|---:|---:|---:|
| `$16` Harpoon | 8 | 6 | 14 | 28 |
| `$2C` Jaws | 8 | 7 | 7 | 22 |
| `$2D` Burrobot | 21 | 4 | 25 | 50 |
| **Total newly native in Phase 31** | **37** | **17** | **46** | **100** |

## Deferred LZ systems

Phase 31 deliberately does not approximate remaining source systems. The main remaining families include Object `$0B` pole, `$0C` flap door, `$60` Orbinaut, `$61` LZ blocks, `$62` Gargoyle, `$63` conveyors, `$65` waterfalls, water slides/wind tunnels, the LZ3 layout mutation, and the Object `$77` Labyrinth boss sequence.
