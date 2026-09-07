# Phase 3 source mapping

This file records where Phase 3 behavior comes from in the supplied Sonic 1 disassembly.

## Camera

| Native file | Disassembly source | Ported responsibility |
|---|---|---|
| `scripts/camera/sonic_camera.gd` | `_inc/ScrollHoriz & ScrollVertical.asm` | foreground camera tracking and per-frame shift |
| `scripts/camera/sonic_camera.gd` | `_inc/LevelSizeLoad & BgScrollSpeed.asm` | GHZ1 limits and initial framing |
| `scripts/render/ghz_background_renderer.gd` | `_inc/DeformLayers (REV01).asm` | GHZ parallax/cloud/water bands |

GHZ1 uses camera boundaries left `$0000`, right `$24BF`, top `$0000`, bottom `$0300`. The initial Y camera coordinate is Sonic Y minus 96 pixels and is then clamped to those boundaries.

## Object loading/execution

| Native file | Disassembly source | Ported responsibility |
|---|---|---|
| `scripts/objects/object_manager.gd` | `_inc/ObjPosLoad.asm` | six-byte placement records, camera-window spawning, state persistence |
| `scripts/objects/object_manager.gd` | `_inc/ExecuteObjects.asm` | explicit 96 placement slots and slot-order ticking (child-ring/log slot pressure pending) |
| `scripts/objects/genesis_level_object.gd` | `_Variables.asm` / OST definitions | common object fields and native Node bridge |

The six-byte GHZ1 records are interpreted as:

```text
word X
word Y + X/Y flip flags
byte object ID + remember flag
byte subtype
```

## Objects

| ID | Native class | Primary ASM source | Phase 3 status |
|---:|---|---|---|
| `$11` | `BridgeObject` | `_incObj/11 GHZ Bridge.asm` | log layout/platform + initial bend |
| `$18` | `BasicPlatformObject` | `_incObj/18 Platforms.asm` | static GHZ platform collision |
| `$1C` | `SceneryObject` | `_incObj/1C GHZ, SYZ Scenery.asm` | GHZ bridge-stump scenery |
| `$1F` | `BadnikObject` | `_incObj/1F Badnik - Crabmeat.asm` | sprite/animation/basic contact |
| `$22` | `BadnikObject` | `_incObj/22, 23 Badnik - Buzz Bomber and Missile.asm` | sprite/animation/basic contact |
| `$25` | `RingGroupObject` | `_incObj/25, 37 Rings.asm` | group layout/collection/persistence |
| `$26` | `MonitorObject` | `_incObj/26, 2E Monitors and Power-Ups.asm` | solidity/break state/icon visuals |
| `$2B` | `BadnikObject` | `_incObj/2B Badnik - Chopper.asm` | sprite/animation/basic contact |
| `$36` | `SpikesObject` | `_incObj/36 Spikes.asm` | mapped shape/hazard groundwork |
| `$3B` | `PurpleRockObject` | `_incObj/3B GHZ Purple Rock.asm` | original sprite + solid-box groundwork |
| `$40` | `BadnikObject` | `_incObj/40 Badnik - Moto Bug.asm` | sprite/basic movement/contact |
| `$41` | `SpringObject` | `_incObj/41 Springs.asm` | orientation/power/bounce groundwork |
| `$42` | `BadnikObject` | `_incObj/42 Badnik - Newtron.asm` | sprite/animation/basic contact |
| `$44` | `EdgeWallObject` | `_incObj/44 GHZ Edge Walls.asm` | mapped frame + solid/cosmetic subtype behavior |
| `$79` | `StaticSpriteObject` | `_incObj/79 Lamppost.asm` | original sprite only |

## Asset reconstruction

The Phase 3 object PNGs are build-time reconstructions from the disassembly's Nemesis art and mapping files. They are not screenshots or emulator captures. Genesis palette-line constants are interpreted as bit fields:

```text
Tile_Pal2 = palette index 1
Tile_Pal3 = palette index 2
Tile_Pal4 = palette index 3
```

The native GHZ background texture is similarly assembled from the original background layout, chunks, blocks, tile art and palette. Runtime scrolling then samples that native texture in deformation bands.
