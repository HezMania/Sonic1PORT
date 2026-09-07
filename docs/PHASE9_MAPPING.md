# Phase 9 source mapping

## Explosion
Native: `scripts/effects/explosion_effect.gd`

Source:
- `_incObj/27, 3F Explosions.asm` — `ExplosionItem`, `ExItem_Main`, `ExItem_Animate`
- `_maps/Explosions.asm`
- `artnem/Explosion.nem`

Ported behavior: five gray frames, eight-frame duration per mapping, no collision. Enemy and monitor spawn semantics are selected by the object manager.

## GHZ animals
Native: `scripts/effects/animal_object.gd`

Source:
- `_incObj/28, 29 Animals and Points.asm`
- `_maps/Animals 1.asm`
- `_maps/Animals 2.asm`
- `artnem/Animal Rabbit.nem`
- `artnem/Animal Flicky.nem`

GHZ `Anml_VarIndex` is `0,5`. Rabbit uses `-$200/-$400`; Flicky uses `-$300/-$400`. Initial Y launch is `-$400`. Rabbit follows `Anml_NormalGravity`; Flicky follows `Anml_SlowGravity`.

## Points popup
Native: `scripts/effects/points_object.gd`

Source:
- Object `$29` `Points`, `Poi_Main`, `Poi_Slower`
- `_maps/Points.asm`
- `artnem/Points.nem`

Ported behavior: `-$300` initial Y velocity, `+$18` per frame, delete once velocity is non-negative.

## Random animal choice
Native: `SonicObjectManager._next_ghz_animal_id()`

Source: `_incObj/sub RandomNumber.asm`, followed by the GHZ `Anml_VarIndex` parity lookup.

## Shield and invincibility
Native: `scripts/effects/sonic_effects.gd`

Source:
- `_incObj/38 Shield and Invincibility.asm`
- `_anim/Shield and Invincibility.asm`
- `_maps/Shield and Invincibility.asm`
- `artnem/Shield.nem`
- `artnem/Invincibility Stars.nem`

Ported behavior: shield visibility rules, shield animation, four separate star trails, staggered history offsets, and six-position lag jitter.

## End-of-act card / tally
Native: `scripts/ui/end_card_ui.gd`, `SonicObjectManager.begin_act_complete()`, `_tick_end_tally()`

Source: `_incObj/3A Got Through Card.asm`

Ported behavior: `$10` px/frame slide-in, original target positions, 3-second pre-tally wait, 100-point-per-frame time/ring countdown, and 3-second post-tally wait. The Phase 9 visuals use native text rather than the original title-card tile artwork.
