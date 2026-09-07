# Phase 18 source mapping

## Object $32 — Marble button

Source: `_incObj/32 Button.asm`

`But_MZBlock` checks the special MZ1 push block against the button's 32x16 detection region. The native object manager keeps that model and adds a small vertical tolerance for integer/platform alignment differences in the Godot representation.

## Object $33 — Pushable block

Source: `_incObj/33 MZ, LZ Pushable Blocks.asm`

Relevant source behaviors represented in Phase 18:

- `PushB_SolidAction` — directional pushing and wall checks.
- MZ1 `$A20..$AA0` hard-coded chained-stomper relationship.
- ledge-fall speed remembered as `+/-$400`.
- `PushB_OnLava` — one-eighth inherited X speed (`+/-$80`), wall stop, then slow lava sinking.
- lava identification through the raw 16x16 mapping range `$16A+`.

The Godot 4.6.3 runtime push cadence is deliberately gated to every other 60 Hz tick because the previous direct one-pixel native update was observed to move the block faster than the reference behavior in this port.

## Object $36 — Spikes

Source: `_incObj/36 Spikes.asm`

`Spikes_Move` / `Spikes_WaitAndMove`:

- lower subtype `$0`: static;
- lower subtype `$1`: move up/down;
- lower subtype `$2`: move left/right;
- position delta changes by `8*$100` per movement update;
- range is 0..32 pixels;
- each end waits 60 frames.

The existing backside-damage handling remains intact.

## Object $46 — Marble bricks

Source: `_incObj/46 MZ Bricks.asm`

After a falling brick contacts the floor, the source reads the supporting 16x16 block ID. Only IDs `$16A` and above enter the lava wobble/bobbing routine. Phase 18 restores this gate; ordinary block-on-block/terrain landings remain stationary.

## Object $53 — Collapsing floor

Source: `_incObj/1A, 53 Collapsing Ledges and Floors.asm`

Phase 18 uses the eight-piece 4x2 fragment layout and the per-piece delay arrays already present in the port. The important correction is that delay countdown and falling are separate phases: a fragment stays visible/solid while its delay is nonzero and starts falling only after its own delay expires.

The native fragment dictionary validates the stored sprite instance before casting it, preventing access to an already queued/freed Sprite2D.

## Object $51 — Smashable green block

Source: the Marble smash-block object/mappings in the supplied disassembly.

The generated 96x96 frame has a centered visible 32x32 block. Phase 18 fragment regions crop the real `(32,32)-(64,64)` area into four 16x16 pieces instead of cropping transparent upper-left canvas space.

## Objects $13/$14 — Marble fireballs

Sources:

- `_incObj/13, 14 MZ, SLZ Fire Balls and Maker.asm`
- `_anim/Fireballs.asm`
- `_maps/Fireballs.asm`
- `artnem/Fireballs.nem`

The six runtime PNG frames are regenerated from the original Nemesis tiles and mapping pieces with the intended red/dark-red/yellow/white Sonic palette entries. Surface-impact projectiles now enter a short collision/impact state and delete afterward.

## Object $74 — Marble boss fire

Source: `_incObj/73, 74 Boss - MZ Main and Fire.asm`

After the 30-frame pre-drop period and floor impact, the fire spreads left and right at `+/-$A0` in 8.8 fixed point. A stationary flame is deposited whenever a moving front crosses a 16-pixel boundary; stationary flame lifetime is 103 frames.

## Object $73 — Marble boss recovery

Source: `_incObj/73, 74 Boss - MZ Main and Fire.asm`, `BMZ_Recover`.

During the negative recovery timer Eggman falls only until Y `$270` (`boss_mz_y+$60`). At the boundary the native port clamps Y and clears vertical velocity before beginning the source-style upward recovery interval.

## Object $78 — Caterkiller

Source: `_incObj/78 Badnik - Caterkiller.asm`

Phase 18 preserves the native approximation but corrects initial zero-distance floor attachment, body direction, and delayed floor-history contouring. Exact separate OST body-segment propagation and destruction remains deferred.
