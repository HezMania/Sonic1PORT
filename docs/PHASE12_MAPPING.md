# Phase 12 source mapping

## Sonic/player-state fixes

### Pushing
Source: `_incObj/sub SolidObject.asm` and `_anim/Sonic.asm`

`Solid_AlignToSide` sets Sonic's pushing status while grounded. `id_Push` maps to `SonAni_Push`, which uses frames `$45,$46,$47,$48`.

Native mapping:
- `SonicPlayer.pushing`
- `SonicVisual.PUSH_SEQUENCE`
- visual mode 8

### Death collision exclusion
Source: `_incObj/sub SolidObject.asm`

`Solid_Collision` rejects Sonic when `obRoutine >= 6`. Native `resolve_platform_top()` and `resolve_solid_box_contact()` now return no collision when `dead`.

### Spring pose
Source: `_incObj/41 Springs.asm` and `_anim/Sonic.asm`

`Spring_Up` assigns `id_Spring`. `SonAni_Spring` holds `fr_Spring ($40)` for 48 ticks then changes to walk. `Spring_LR` instead uses walk/roll behavior, and `Spring_Down` does not assign `id_Spring`.

## Object $18 — Basic Platform
Source: `_incObj/18 Platforms.asm`

Implemented native mappings:

| subtype | source routine | native behavior |
|---|---|---|
| 0 | Plat_Stationary | stationary |
| 1 | Plat_RightLeft | horizontal oscillator |
| 2 | Plat_DownUp | vertical oscillator |
| 3 | Plat_FallAfterStand | 30-frame delay |
| 4 | Plat_FallingDown | gravity fall + delayed detach |
| 5 | Plat_LeftRight | reverse horizontal oscillator |
| 6 | Plat_UpDown | reverse vertical oscillator |
| A | Plat_DownUp_LargeGHZ2 | half-range vertical |
| B/C | slow vertical routines | shared slow oscillator |

`SonicPlayer.move_with_supported_object()` is the native bridge for `MvSonicOnPtfm/MvSonicOnPtfm2`.

## Oscillation
Source: `_inc/Oscillatory Routines.asm`

Phase 12 adds shared `$1A` and `$0E` oscillation state to `SonicObjectManager`. Objects read these channels rather than each running an unrelated timer. Oscillation is paused during Sonic's death routine, matching the source `OscillateNumDo` guard.

## Object $15 — Swinging Platform
Source:
- `_incObj/15 Swinging Platforms.asm`
- `_maps/Swinging Platforms (GHZ).asm`
- `artnem/GHZ Swinging Platform.nem`

Native implementation preserves:
- subtype low-nibble chain length
- 16px link-radius spacing
- parent radius = links*16 + 8
- shared `$1A` swing angle
- X-flip swing reversal
- `CalcSine`/cosine positioning
- 48px platform width / 16px height footprint
- moving-platform carry

Child links are Sprite2D children rather than separate 64-byte OST slots.

## Object $3C — Smashable Wall
Source:
- `_incObj/3C GHZ, SLZ Smashable Wall.asm`
- `_maps/Smashable Walls.asm`
- `artnem/GHZ Breakable Wall.nem`

Native implementation preserves:
- 32x64 solid body
- left/middle/right subtype art
- must be rolling
- minimum impact speed `$480`
- saved pre-SolidObject X speed
- +/-4px seamless breakout correction
- eight fragments
- original `Smash_FragSpd1/2` velocity tables
- double gravity `$70`
- persistent destroyed placement state

## Object $17 — Spiked Pole Helix
Source:
- `_incObj/17 GHZ Spiked Pole Helix.asm`
- `_maps/Spiked Pole Helix.asm`
- `artnem/GHZ Spiked Log.nem`
- `SynchroAnimate / Sync1`

Native implementation preserves:
- subtype = spike count
- 16px spacing
- per-spike base frame offset modulo 8
- synchronized backwards 8-frame rotation at 12 ticks/frame
- damage only while frame 0 points straight upward

## Deferred Object $3E
`_incObj/3E Prison Capsule.asm` remains deferred because its switch/body state depends on the GHZ3 boss-status and end-of-act sequence. It is the remaining placed GHZ3 gameplay object after Phase 12.
