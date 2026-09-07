# Phase 36 Mapping — Star Light Foundation

## Base and scope

- Base: user-tested **Phase 35 Labyrinth Boss** project.
- Runtime target: Godot 4.6.3.
- Authoritative source: user-supplied `s1disasm-AS(1).zip`.
- Phase objective: begin native SLZ gameplay without changing the Labyrinth systems already confirmed working.

## SLZ level routing / background

`LevelCatalog` now assigns SLZ:

- `background_layout = levels/slzbg.bin`
- `palette = palette/Star Light Zone.bin`
- `artnem/8x8 - SLZ.nem` at level tile 0
- `background_mode = slz`
- `dynamic_events = slz1/slz2/slz3`
- `full_gameplay_support = true` as the project's playtest-routing gate

The debug display explicitly says **SLZ PLAYTEST** because Act 3's boss and several object families remain later work.

### REV01 `Deform_SLZ`

The new renderer reproduces the source background structure:

- BG Y follows foreground camera Y at **1/2 speed**.
- Horizontal scroll is consumed in **16-pixel bands**.
- Scroll-table starting entry follows `((bg_y-$C0)&$3F0)/16`.
- First 28 bands interpolate the stars from 1.0x foreground X toward 5/32x.
- Next 5 bands use 3/16x for distant black buildings.
- Next 5 bands use 1/4x for nearer buildings.
- Remaining lower bands use 1/2x.

The background plane itself is decoded from the original SLZ level art/chunk/block/background-layout data already present in the project.

## Object `$59` — SLZ elevators

Source: `_incObj/59 SLZ Elevators.asm`, `_maps/SLZ Elevators.asm`.

Implemented:

- 80-pixel-wide source platform mapping from level-art tile `$41`, palette line 2;
- all 15 `Elev_Var2` entries;
- source action types: stand-to-start, rise, descend, rise-right, descend-left, spawner platform;
- acceleration `+$10` to maximum `$800`, then `-$10` after half-distance;
- source total distances from `$80` through `$1A0` and the spawned `$180` platform;
- subtype `$8x` invisible spawners and spawned subtype `$0E` platforms;
- Sonic support/carry and release at the spawned platform's peak.

Authored placements: **5 / 5 / 6** in SLZ1/2/3.

## Object `$5A` — circling platforms

Source: `_incObj/5A SLZ Circling Platform.asm`, `_maps/SLZ Circling Platform.asm`, `_inc/Oscillatory Routines.asm`.

Implemented:

- source 48x16 mapping from level-art tile `$51`, palette line 2;
- oscillator `$22` baseline `$0080/$0000`;
- oscillator `$26` baseline `$50F0/$011E` with downward initial direction;
- bit 0 = 180-degree phase shift;
- bit 1 = 90-degree phase shift;
- bit 2 = clockwise direction;
- moving-platform support/carry.

Authored placements: **44 / 16 / 8**.

## Object `$5B` — staircases

Source: `_incObj/5B SLZ Staircase.asm`, `_maps/Staircase.asm`.

Implemented:

- four 32x32 source blocks from level-art tile `$21`, palette line 2;
- X-flip reverses the Y-offset table assignment;
- subtype 0 waits 30 frames after Sonic stands on it;
- subtype 2 waits/wobbles 60 frames after an underside hit;
- downward offsets follow `D`, `3D/4`, `D/2`, `D/4` until 128 pixels;
- source parent-before-child update ordering and full solid contacts.

Authored placements: **15 / 3 / 5**.

## Object `$5D` — fans

Source: `_incObj/5D SLZ Fan.asm`, `_maps/Fan.asm`, `artnem/SLZ Fan.nem`.

Implemented:

- all five source mappings from the original Nemesis stream;
- palette line 2 (`Tile_Pal3`);
- subtype bit 1 always-on behavior;
- ordinary fan initial OFF interval of 2 seconds followed by ON interval of 3 seconds;
- active animation advances every frame;
- subtype bit 0 uses the source reverse frame base and reverses final blow direction;
- source X/Y range checks and 16-bit integer force arithmetic are translated directly.

Authored placements: **8 / 14 / 14**.

## Object `$5F` — Walking Bomb

Source: `_incObj/5F Badnik - Walking Bomb.asm`, `_anim/Bomb Enemy.asm`, `_maps/Bomb Enemy.asm`, `artnem/Enemy Bomb.nem`.

Implemented:

- source body/fuse/shrapnel graphics and animations;
- walking speed `$10` in 8.8 fixed units;
- walk timer `(25*60)+36-1 = 1535`;
- wait timer `(3*60)-1 = 179`;
- fuse proximity `<96` pixels on both axes;
- fuse timer `(2*60)+24-1 = 143`;
- body damaging badnik collision;
- four source shrapnel velocities:
  - `-$200,-$300`
  - `-$100,-$200`
  - `+$200,-$300`
  - `+$100,-$200`
- shrapnel gravity `+$18` and damaging collision.

Authored placements: **13 / 20 / 48**.

## Shared Object `$60` — SLZ Orbinaut behavior

All **28** SLZ Orbinaut records use subtype `$02` (9 / 7 / 12).

The source copies subtype into the base routine, so subtype `$02` skips `Orb_CheckSonic` and starts in `Orb_DisplayAndMove`. Phase 36 therefore:

- moves SLZ Orbinauts immediately at source speed `$40`;
- keeps all four spikeballs orbiting;
- does not enter LZ's angry/firing sequence;
- uses the original `Enemy Orbinaut.nem` stream with SLZ palette line 1;
- leaves the previously tested LZ subtype `$00` behavior unchanged.

## Exact retained SLZ source/data

Newly checked SLZ files include:

- `artnem/8x8 - SLZ.nem`
- `artnem/SLZ Fan.nem`
- `artnem/Enemy Bomb.nem`
- `palette/Star Light Zone.bin`
- `palette/Cycle - SLZ.bin`
- `levels/slzbg.bin`
- `objpos/slz1.bin`
- `objpos/slz2.bin`
- `objpos/slz3.bin`

These are checked together with the prior 30 retained LZ/boss binaries for **39/39 byte-identical files**.
