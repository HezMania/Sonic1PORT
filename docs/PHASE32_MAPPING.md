# Phase 32 source mapping — underwater HurtSonic / LZ blocks / Gargoyle / waterfalls

Phase 32 is built directly from the full Phase 31 project and checked against the re-supplied `s1disasm-AS(1).zip`. The standing project rule remains in force: when the original game has a known source asset, the native port uses that asset rather than inventing or redrawing it.

## Underwater damage knockback

Authoritative source:
- `_incObj/Sonic ReactToItem.asm` — `HurtSonic`
- `_incObj/01 Sonic.asm` — `Sonic_Hurt`

The source initializes normal hurt knockback to:
- Y velocity `-$400`
- X velocity `-$200`

If `obStatus` bit 6 says Sonic is underwater, `HurtSonic` immediately replaces those values with:
- Y velocity `-$200`
- X velocity `-$100`

The source `Sonic_Hurt` routine then applies `$10` gravity underwater instead of the dry `gravity-$08 = $30` hurt gravity. Phase 31 already had the `$10` underwater hurt gravity, but still launched Sonic with the dry `-$400/-$200` velocities. Phase 32 corrects the launch itself.

## Object `$61` — Labyrinth multi-variant blocks

Authoritative source:
- `_incObj/61 LZ Blocks.asm`
- `_maps/LZ Blocks.asm`
- `artnem/LZ Horizontal Door.nem`
- `artnem/LZ Rising Platform.nem`
- `artnem/LZ Cork.nem`
- `artnem/LZ 32x32 Block.nem`
- `_Constants.asm`
- `_inc/Pattern Load Cues.asm`

The source object uses `ArtTile_LZ_Blocks = $3E6` as its base VRAM tile. Its mapping offsets deliberately reach other PLC-loaded LZ art banks through 16-bit VDP attribute addition:

| Frame | Mapping tile | Effective source tile | Source asset | Native size |
|---|---:|---:|---|---:|
| 0 sink block | `$000` | `$3E6` | `LZ Horizontal Door.nem` | 32×32 |
| 1 rising platform | `$069/$075` | `$44F/$45B` | `LZ Rising Platform.nem` | 64×24 |
| 2 cork | `$11A` | `$500` | `LZ Cork.nem` | 32×32 |
| 3 stationary block | `$5FA` plus mapping flags | `$1E0` after 16-bit attribute addition | `LZ 32x32 Block.nem` | 32×32 |

For the frame-3 mapping, the source mapping attribute word is `$FDFA`; adding the object's `$43E6` base produces `$41E0` after 16-bit wrap. That resolves to tile `$1E0` on palette line 2 with the mapping's temporary flags cancelled by the same arithmetic. Phase 32 renders the resulting source appearance rather than applying the raw mapping flags a second time.

Final-game LZ placements use only four subtype families:
- `$01`: 32×32 block; wait 30 frames after Sonic stands on it, then sink.
- `$13`: 64×24 platform; wait 30 frames after Sonic stands on it, then rise.
- `$27`: 32×32 cork; follow `v_waterpos1` at no more than 2 px/frame and respect floor/ceiling collision.
- `$30`: stationary 32×32 solid block.

The source's small standing nudge for delayed sink/rise blocks is preserved using the original `$04` nudge increment and `$400` sine force.

Placement coverage:
- LZ1: 21 Object `$61` records
- LZ2: 3
- LZ3: 19
- Total: **43**

## Object `$62` — Gargoyle and fireball

Authoritative source:
- `_incObj/62 LZ Gargoyle.asm`
- `_maps/Gargoyle.asm`
- `artnem/LZ Gargoyle & Fireball.nem`

The head uses source palette line 2 and the exact three-piece mapping. Spit delays use the source table:
`30, 60, 90, 120, 150, 180, 210, 240` frames.

The spawned fireball:
- starts 8 px below the gargoyle origin;
- uses the source fireball palette line 0 rather than the head's palette line;
- moves at `$200` 8.8 speed (2 px/frame);
- moves right when the object's X-flip/status bit is set and left otherwise;
- alternates mapping frames 2/3 every 8 frames;
- uses the source 8×8 hurt region;
- deletes when its forward wall probe penetrates terrain.

Placement coverage:
- LZ1: 2
- LZ2: 2
- LZ3: 5
- Total: **9**

## Object `$65` — waterfalls and splashes

Authoritative source:
- `_incObj/65 LZ Waterfalls.asm`
- `_maps/Waterfalls.asm`
- `_anim/Waterfalls.asm`
- `artnem/LZ Water & Splashes.nem`

All 12 source mapping frames are rendered from the original stream. Static subtypes select frames 0–8 directly. Splash frame 9 animates `9 -> 10 -> 11` with source delay 5 (six displayed ticks per frame) and loops.

Special source variants retained:
- subtype `$49`: animated splash follows the dynamic water surface at `water_surface_y - 16`.
- subtype `$A9`: the source clears its high-priority tile bit until the LZ3 water-slide layout mutation changes the foreground chunk. That layout mutation is still deferred, so Phase 32 deliberately leaves `$A9` on the low plane rather than inventing the missing trigger.
- subtype bit 7 otherwise maps to the source high-priority sprite/tile relationship.

Placement coverage:
- LZ1: 8
- LZ2: 17
- LZ3: 35
- Total: **60**

## Phase 32 authored-placement coverage

| Object family | LZ1 | LZ2 | LZ3 | Total |
|---|---:|---:|---:|---:|
| `$61` LZ blocks | 21 | 3 | 19 | 43 |
| `$62` Gargoyle | 2 | 2 | 5 | 9 |
| `$65` waterfalls | 8 | 17 | 35 | 60 |
| **Newly native in Phase 32** | **31** | **22** | **59** | **112** |

## Still deferred

Phase 32 does not approximate the remaining LZ systems. Major remaining work includes Object `$0B` breakable pole, `$0C` flapping door, `$60` Orbinaut, `$63` conveyor groups, the LZ wind tunnels and water slides, the LZ3 foreground-layout mutation, remaining special barriers/objects, and Object `$77` Labyrinth boss sequence.
