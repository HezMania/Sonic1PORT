# Phase 21 source mapping

## Object $53 — MZ collapsing floor

Source: `_incObj/1A, 53 Collapsing Ledges and Floors.asm`, `_maps/Collapsing Floors.asm`.

- `PlatformObject` assumes an 8-pixel platform half-height (`obY-8`).
- Fragment frame pieces use mapping top-left Y values `-8` and `+8`; native 16×16 Sprite2D centers are therefore `0` and `16`.
- Per-fragment delay tables remain `CollapseData_8x2_Shuffle/Swipe` equivalents.

## Object $33 — pushable block

Source: `_incObj/33 MZ, LZ Pushable Blocks.asm`, `_incObj/sub ObjFloorDist.asm`.

- `obHeight = 30/2 = 15` is used for floor probing.
- `FindFloor` tile stride remains `$10` / 16 pixels.
- Ledge state 6 keeps ±`$400` X speed until `(X & $C)==0`, then snaps `X &= $FFF0`, remembers lava speed, clears X velocity, and enters fall state 4.
- Manual native push cadence retains the empirically validated half-rate one-pixel step from Phase 18.

## Object $78 — Caterkiller

Source: `_incObj/78 Badnik - Caterkiller.asm`, `_incObj/Sonic ReactToItem.asm`.

- Head floor-map position starts at 0; body counters start at 4, 8, `$C`.
- Body speed is copied as `parent obVelX + parent obInertia`.
- Each link owns its own 16-byte floor map and forwards `$80` turn markers.
- The middle body segment corresponds to `Cat_BodySeg2` and runs the offset body animation; the outer two run `Cat_BodySeg1` and retain the base body frame.
- `React_CaterkillerBody` sets the fragmentation flag before applying hurt.
- Fragment X speeds are `-$200,-$180,+$180,+$200`; every piece launches at `-$400` Y and bounces on terrain.

## Object $4D — lavafall impact

Source: `_incObj/4C, 4D MZ Lava Geyser Maker and Lava Geyser.asm` / source bubble animation already ported in Phase 20.

- Bubble/impact is foreground relative to the pool surface; native child is now absolute z=110 while the column remains at its lower layer.

## Object $73 — Marble boss hit response

Source: `_incObj/Sonic ReactToItem.asm` `React_BossHit`.

- Native velocity response remains `neg.w` then `asr.w` for X and Y.
- Ground inertia is used only as a fallback when native same-frame object contact has already clipped `vel_x` to zero.
- A minimal side-axis separation compensates for the native overlapping-box model; the source boss collision disables itself during the hit interval, while the native boss uses `flash_timer` for the same no-repeat interval.
