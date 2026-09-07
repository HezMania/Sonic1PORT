# Phase 10 source mapping

## Solid object response

### Springs — Object $41
Source: `_incObj/41 Springs.asm`

The source calls `SolidObject` in all three active orientations before checking the spring-specific contact condition:

- `Spring_Up`: full 32x16 body, bounce only from the top.
- `Spring_LR`: full 16x28 body, bounce only from the active horizontal face.
- `Spring_Down`: full 32x16 body, bounce only from below.

`SonicPlayer.resolve_solid_box_contact()` now returns the resolved side (`TOP/BOTTOM/LEFT/RIGHT`) instead of forcing object code to infer the contact from position after collision resolution.

### Spikes — Object $36
Source: `_incObj/36 Spikes.asm`

Phase 10 uses the source `Spikes_Config` widths and distinguishes the point face from the harmless solid backside:

- sideways unflipped: point left
- sideways X-flipped: point right
- upright unflipped: point up
- upright Y-flipped: point down

The collision remains solid regardless of whether the contacted face deals damage.

## Buzz Bomber missile — Objects $22/$23
Source: `_incObj/22, 23 Badnik - Buzz Bomber and Missile.asm`

`Buzz_Action_Fire` copies `obStatus(a0)` directly into the missile. In the native badnik implementation, positive-X Buzz movement corresponds to a flipped parent sprite, so the missile must use `flip_h = horizontal_velocity > 0` as well. Phase 9 had the polarity reversed.

## HUD — Object $21
Sources:

- `_incObj/21 HUD.asm`
- `_maps/HUD.asm`
- `_inc/HUD Update.asm`
- `artnem/HUD.nem`
- `artunc/HUD Numbers.unc`
- `artnem/HUD - Life Counter Icon.nem`
- `artunc/Lives Counter Numbers.unc`

Native screen positions correspond to Map_HUD after removing the Genesis `$80` screen-coordinate bias:

- SCORE: `(16, 8)`
- TIME: `(16, 24)`
- RINGS: `(16, 40)`
- lives: `(16, 200)`

The original palette-line-1 red label forms are generated as separate PNG resources and selected using the `v_framebyte` bit-3/eight-frame flashing cadence.

## Time Over
Source: `_inc/HUD Update.asm`, `TimeOver`

The source compares the timer bytes against `9:59:59`, stops time, calls `KillSonic`, and sets `f_timeover`. At 60 Hz this corresponds to 35,999 elapsed ticks from zero.

## Game/Time Over — Object $39
Sources:

- `_incObj/39 Game Over.asm`
- `_maps/Game Over.asm`
- `artnem/Game Over.nem`

Translated values:

- left card start origin: `-48`
- right card start origin: `368`
- common target origin: `160`
- movement: `16 px/frame`
- joined wait: `12 * 60` frames
