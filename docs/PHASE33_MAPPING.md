# Phase 33 source mapping — LZ wind tunnels, water slides, poles, flapping doors, conveyors

Phase 33 is built directly from the full user-tested Phase 32 project and uses the re-supplied `s1disasm-AS(1).zip` as the authoritative source. The standing source-fidelity rule remains unchanged: known original graphics/data are retained and decoded directly; no replacement LZ artwork is invented.

## `LZWaterFeatures` execution order

Authoritative source:
- `_inc/LZWaterFeatures.asm`
- `sonic.asm` main level loop

The original runs `LZWaterFeatures` immediately before `ExecuteObjects`. Phase 33 mirrors that ordering in `main.gd`:

1. update dynamic LZ water height;
2. apply LZ wind-tunnel / water-slide features;
3. run Sonic's native tick;
4. execute level objects.

This is important because wind tunnels read the previously sampled `v_jpadhold2` state, directly reposition Sonic, set velocities/animation/status, and then Sonic's normal object routine runs afterward.

## LZ wind/current tunnels

Source rectangles from `LZWind_Data`:

| Act | Left | Top | Right | Bottom |
|---|---:|---:|---:|---:|
| LZ1 set 1 | `$A80` | `$300` | `$C10` | `$380` |
| LZ1 set 2 | `$F80` | `$100` | `$1410` | `$180` |
| LZ2 | `$460` | `$400` | `$710` | `$480` |
| LZ3 | `$A20` | `$600` | `$1610` | `$6E0` |

Native behavior now preserves the source movement rules:
- tunnel disabled while `f_wtunneldisallow` equivalent is asserted;
- hurt/death/drowning clears tunnel mode;
- direct `+4 px` X displacement before Sonic's own movement routine;
- X velocity `$400`, Y velocity `0`;
- `id_Float2` animation;
- in-air state and roll-jump lock clear;
- first 128 px of the tunnel applies a 2 px/frame vertical suction offset;
  - LZ2 pulls upward;
  - LZ1/LZ3 pull downward;
- UP moves 1 px upward while inside, with the FixBugs top clamp;
- DOWN moves 1 px downward;
- leaving an active tunnel clears tunnel mode.

The source waterfall/rush SFX cadence remains deferred because the project still lacks the original sound-driver/SFX path; no substitute sound is introduced.

## Water slides

Authoritative source: `LZWaterSlides` in `_inc/LZWaterFeatures.asm`.

Source slide chunks and forced inertia:

| Chunk | Inertia |
|---:|---:|
| `$02` | `+$A00` |
| `$07` | `-$B00` |
| `$03` | `+$A00` |
| `$4C` | `-$A00` |
| `$4B` | `-$B00` |
| `$08` | `-$C00` |
| `$04` | `+$B00` |

Phase 33:
- ignores slides while Sonic is airborne;
- forces the source inertia and facing direction while grounded on a slide chunk;
- uses Sonic's `id_Slide` frames (`$55,$57`);
- prevents normal walking acceleration/deceleration and roll drag during slide mode while still deriving velocity from the terrain angle;
- prevents initiating a roll during slide mode;
- preserves jumping;
- applies source `locktime=5` when leaving a slide.

## Object `$0B` — breakable wind-tunnel pole

Authoritative source:
- `_incObj/0B LZ Pole that Breaks.asm`
- `_maps/Pole that Breaks.asm`
- `artnem/LZ Breakable Pole.nem`

Final-game placements: **5**, all in LZ3.

Behavior retained:
- source 8×64 special collision footprint;
- the ReactToItem touch flag is latched until the tunnel carries Sonic beyond the pole's `+20 px` grab threshold, matching `obColProp` persistence;
- Sonic snaps to pole X `+20` and faces right;
- velocity/inertia stop;
- Sonic uses source `id_Hang` frames `$41,$42`;
- normal Sonic modes are bypassed through an `f_playerctrl` equivalent while raw input remains readable;
- wind tunnels are disabled while grabbed;
- UP/DOWN move Sonic at 1 px/frame between pole Y `-24` and `+12`;
- A/B/C releases;
- break delay is `subtype × 60` frames (the authored subtype `$04` = 240 frames);
- after **any** release the pole advances permanently to display-only, exactly like source routine 4; a broken pole additionally changes to source frame 1.

## Object `$0C` — flapping wind-tunnel door

Authoritative source:
- `_incObj/0C LZ Flapping Door.asm`
- `_anim/Flapping Door.asm`
- `_maps/Flapping Door.asm`
- `artnem/LZ Flapping Door.nem`

Final-game placements: **2** — one in LZ2 and one in LZ3.

Behavior retained:
- period `subtype × 60` frames; authored subtype `$02` = 120 frames;
- initial zero timer underflow toggles the door immediately, as in source;
- source opening/closing frame sequences `0→1→2` / `2→1→0` with delay byte 3;
- only fully closed frame 0 blocks;
- only blocks when Sonic is still left of the door;
- closed door asserts the shared wind-tunnel-disallow equivalent;
- closed collision uses the source 16×64 door footprint through native SolidObject handling.

The door SFX remains deferred with the native SFX driver.

## Object `$63` — LZ conveyor system

Authoritative source:
- `_incObj/63 LZ Conveyor.asm`
- `_maps/LZ Conveyor.asm`
- `artnem/LZ Wheel.nem`
- `objpos/platforms/lz1pf1.bin`
- `objpos/platforms/lz1pf2.bin`
- `objpos/platforms/lz2pf1.bin`
- `objpos/platforms/lz2pf2.bin`
- `objpos/platforms/lz3pf1.bin`
- `objpos/platforms/lz3pf2.bin`

Corrected source inventory:
- normal authored Object `$63` records: **36** (`13 / 10 / 13` across LZ1/LZ2/LZ3);
- moving platforms spawned from the six custom data files: **53** (`8+8+8+8+12+9`).

### Wheels

Subtype `$7F` is a decorative wheel:
- four source 32×32 frames at local tiles `$00/$10/$20/$30`;
- source palette line 0;
- frame advances every fourth level frame;
- direction reverses when global conveyor reversal is active;
- rendered above the normal conveyor platforms/Sonic like source priority 1.

### Moving platforms

High-bit placement subtypes `$80-$85` load groups 0–5 from the exact custom platform binaries. The platform mapping is the original local tile `$40`, 32×16, palette line 2.

Each platform:
- uses its subtype high nibble/group and low-nibble initial target index;
- follows the exact source corner coordinate tables;
- keeps the major axis at 1 px/frame and computes the minor component from signed distance ratio;
- is top-solid at 32 px wide / 16 px tall;
- carries Sonic with fractional displacement;
- reverses once when switch `$E` is pressed;
- immediately selects the prior target on reversal;
- new groups spawned after global reversal initialize reversed;
- decorative wheels follow the same global reversal flag.

### Exact target groups

The six target loops in Phase 33 are transcribed directly from `LCon_Data`, including the LZ3 wide group and all source wrap/reversal ordering.

## Exact source data retained

Phase 33 adds and byte-verifies:
- `LZ Breakable Pole.nem`
- `LZ Flapping Door.nem`
- `LZ Wheel.nem`
- all six `objpos/platforms/lz*.bin` conveyor files
- `Cycle - LZ Conveyor Belt.bin`
- `Cycle - LZ Conveyor Belt Underwater.bin`

The two conveyor palette-cycle binaries are retained exactly for the later dynamic-CRAM renderer pass. The current native level renderer still uses prebuilt palette-colored terrain, so Phase 33 does **not** pretend the source conveyor palette cycling has been implemented.

## Still deferred

Major remaining Labyrinth work after Phase 33 includes:
- Object `$60` Orbinaut;
- remaining special barrier/object families;
- exact dynamic conveyor CRAM palette cycling in the native renderer;
- the LZ3 foreground-layout mutation/hidden splash priority transition;
- Object `$77` Labyrinth boss and end sequence;
- original SFX/music-driver integration for water rush, doors, drowning warnings and related sounds.
