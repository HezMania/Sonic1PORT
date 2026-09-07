# Phase 19 source mapping

## Object $33 — MZ/LZ Pushable Block

Source: `_incObj/33 MZ, LZ Pushable Blocks.asm`

Phase 19 keeps the existing `PushB_OnLava` translation and restores its platform-carry implication: a player already standing on the block is translated by the block's integer X/Y delta before normal solid response is evaluated. The undeclared native `vel_x` field used by the lava state is now explicitly present.

The original geyser-maker behavior that sets the block's Y velocity to `-$580` is intentionally not completed in this phase.

## Object $52 — Moving Blocks

Source: `_incObj/52 Moving Blocks.asm`

The source dispatches through `PlatformObject`, not `SolidObject`. Phase 19 therefore uses `resolve_platform_top()` after applying the platform delta. This makes the horizontally oscillating wall blocks top-solid only.

## Object $78 — Caterkiller

Source: `_incObj/78 Badnik - Caterkiller.asm`

Important translated fields/behaviors:

- `cat_waittime` -> native wait/movement timer;
- `cat_mode` bit 4 -> mouth / undulation half;
- `cat_floormap` -> 16-entry floor-history arrays;
- `cat_segmentpos` -> per-object history read/write position;
- `obVelX = -$C0` and `obInertia = +/-$40` source motion;
- `$80` floor-history sentinel for a ledge / steep transition;
- three independent segment positions linked parent-to-child rather than a common head flip;
- original 128-byte `Ani_Cat` table used for head/body frame selection.

Full `Cat_FragmentateBody` object-slot fragmentation remains deferred.

## Object $28 — Animals

Source: `_incObj/28, 29 Animals and Points.asm`, `_maps/Animals 1.asm`, `_maps/Animals 2.asm`, `_maps/Animals 3.asm`, and the corresponding `artnem/Animal *.nem` streams.

All seven animal frame sets were regenerated from the original 4bpp art + mappings. Runtime species selection and speeds remain source driven through the existing zone table.

## Object $4E — MZ Wall of Lava

Source: `_incObj/4E MZ Wall of Lava.asm`, `_maps/Wall of Lava.asm`, `artnem/MZ Lava.nem`, and the MZ animated-magma graphics slot.

The mapping combines edge art from `MZ Lava.nem` with tile indices belonging to the animated magma range. Phase 19 reconstructs both layers in the pre-rendered native frames, including mapping frame 4 used by the rear child.

## Object $4D — MZ Lava Geyser / Lavafall

Source: `_incObj/4C, 4D MZ Lava Geyser and Maker.asm`, `_anim/Lava Geyser.asm`, `_maps/Lava Geyser.asm`.

For subtype 1 lavafall, both top and bottom end objects use animation `.end` (mapping frames 6/7). Mapping frame `$11` is not an attached lower cap; Phase 19 removes that incorrect use and retires the lower end child when it reaches the lava pool.

## Objects $73/$74 — Marble boss / boss fire

Source: `_incObj/73, 74 Boss - MZ Main and Fire.asm`, `_maps/Boss Items.asm`, `artnem/Boss - Weapons.nem`, and the shared Fireballs animation/mappings.

- Boss routine 8 is represented by a separate pipe/nozzle child generated from `Map_BossItems` frame 4.
- `BossFire_GenericTimer = 103` remains the active floor-flame lifetime.
- Active floor flames use `Ani_Fire`'s vertical sequence. The terminal vertical-collision frame is selected only when that lifetime expires, then the sprite shifts upward 4 px before deletion.
