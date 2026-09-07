# Phase 23 source mapping — Spring Yard fidelity

## Object $47 — Bumper

Source:
- `_incObj/47 SYZ Bumper.asm`
- `_anim/Bumper.asm`
- `_maps/Bumper.asm`
- `artnem/SYZ Bumper.nem`

Native changes:
- Collision now models `col_16x16_alt|col_special` as an 8-pixel half-extent rectangle expanded by Sonic's current radii rather than a radial approximation.
- Bounce remains based on `CalcAngle`/`CalcSine` and `$700` force.
- `obStatus` rolling bit is deliberately retained. The source clears airborne roll-jump, pushing and jumping flags but does not clear rolling.
- Hit animation follows `1,2,1,2` at four ticks per frame before returning to idle.
- Sprite is rendered above Sonic, matching source priority 1 versus Sonic priority 2.

## Object $43 — Roller

Source:
- `_incObj/43 Badnik - Roller.asm`
- `_anim/Roller.asm`
- `_maps/Roller.asm`
- `artnem/Enemy Roller.nem`

Native changes:
- Initial fall remains invisible.
- After floor contact, the waiting state still skips rendering until Sonic is at least `$100` pixels to the right, matching `Roll_Action_FromLeft`.
- Rolling animation uses source frames `3,4,2`.
- Roller art was regenerated from the original Nemesis/mapping pair.

## Object $56 — Floating blocks

Source:
- `_incObj/56 SYZ, SLZ Floating Blocks and LZ Doors.asm`
- `_maps/Floating Blocks and Doors.asm`
- `artnem/8x8 - SYZ.nem`

Source collision half-sizes retained:
- frame 0: 16×16 => 32×32
- frame 1: 32×32 => 64×64
- frame 2: 16×32 => 32×64
- frame 3: 32×26 => 64×52 collision
- frame 4: 16×39 => 32×78 collision

The source mapping artwork was regenerated from the actual SYZ level-art tile bank with `Tile_Pal3` (palette line 2). Visual mappings for frames 3/4 naturally extend slightly beyond their collision heights.

Movement remains source-driven:
- type 1: `(v_oscillate+$A)` horizontal, nominal `$40` span
- type 2: `(v_oscillate+$1E)` horizontal, nominal `$80` span
- type 3: `(v_oscillate+$A)` vertical, nominal `$40` span
- type 4: `(v_oscillate+$1E)` vertical, nominal `$80` span

## Object $57 — SYZ spike-ball chain

Source:
- `_incObj/57 SYZ, LZ Spiked Ball and Chain.asm`
- `_maps/Spiked Ball and Chain (SYZ).asm`
- `artnem/SYZ Small Spikeball.nem`

The important correction is the original `obAngle` word side effect. `sball_speed` is a signed word added to `obAngle`; `move.b obAngle,d0` then reads the high byte on 68000. Phase 22 treated the low byte as the visible angle. Phase 23 stores a 16-bit angle accumulator, adds the signed speed, and uses `(angle_word >> 8) & $FF` for `CalcSine`.

Each child keeps its source radius and independently receives sine/cosine-derived X/Y coordinates around the original anchor.

## Object $58 — giant spike ball

Source:
- `_incObj/58 SYZ Big Spiked Ball.asm`
- `_maps/Big Spiked Ball.asm`
- `artnem/SYZ Large Spikeball.nem`

Corrections:
- Runtime artwork uses only `.ball`, the single mapping used by the SYZ object.
- Circular subtype `$x3` uses the same high-byte visible-angle behavior as Object $57.
- `$x1` and `$x2` retain `(v_oscillate+$E)` movement.

## Button artwork

Source:
- `_maps/Button.asm`
- `artnem/Switch.nem`

The shared native Button class is unchanged behaviorally in this pass, but its three source mapping frames were regenerated to correct SYZ rendering.

## OscillateNumDo

Source:
- `_inc/Oscillatory Routines.asm`

The native down-phase midpoint comparison now retains the down state while the public high byte equals the midpoint and changes direction only once below it, matching the source branch behavior. This affects the shared `$A`, `$E`, and `$1E` channels used throughout SYZ.

## Player physics

Source:
- `_incObj/01 Sonic.asm`

Phase 23 deliberately retains:
- `son_maxspeed = $600`
- `son_jumpspeed = $680`

A source/native audit confirmed `_speed_to_pos()` performs one X update and one Y update. No non-source speed boost was added merely to compensate for the previously incorrect SYZ objects.
