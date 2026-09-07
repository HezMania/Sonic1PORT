# Phase 22 source mapping

Phase 22 begins native Spring Yard Zone support while preserving the Phase 21 Marble systems.

## Caterkiller retention fix

The REV01 turn path remains based on `_incObj/78 Badnik - Caterkiller.asm`: `$80` floor-history reversal markers, low-word `obSubpixelX` negation, delayed per-segment reversal, and independent segment facing. A native child-sprite separation guard prevents a delayed marker from visually losing a body link while leaving the segment's own flip/history state intact. The verified body-hit breakup remains unchanged.

## Spring Yard Act 1

- `LevelCatalog`: SYZ1 promoted to `full_gameplay_support`; original SYZ layout/background/palette/map/collision/start/object data.
- `Deform_SYZ`: first-pass native background plane uses the original slow-background concept and 3/16 vertical relationship. Scanline-perfect horizontal bands remain a later fidelity pass.
- Object `$12`: spinning search light (`_incObj/12 SYZ Search Light.asm`).
- Object `$18`: SYZ platform graphics plus switch-driven type `$x7 -> $x8` one-second delay and 2 px/frame rise to `$200` above origin.
- Object `$32`: shared Button object, with MZ-only bit-7 push-block special case preserved.
- Object `$43`: Roller fall/trigger/roll/unfold/re-roll foundation from `_incObj/43 Badnik - Roller.asm`.
- Object `$47`: bumper radial `$700` rebound and 10-point response.
- Object `$50`: Yadrin fall, walk, floor/wall/ledge detection and 60-frame turn wait.
- Object `$56`: SYZ floating block mappings and oscillation subtypes `$0-$4` with full solidity/carrying.
- Object `$57`: spinning small spike-ball chain using subtype radius/count/signed angular speed.
- Object `$58`: stationary/horizontal/vertical/circling giant spike-ball types.

## Deferred from SYZ

Acts 2/3 remain loader previews. Their additional dynamic events, Act 3 tunnel/boss behavior, and complete scanline deformation/palette cycling are future phases.
