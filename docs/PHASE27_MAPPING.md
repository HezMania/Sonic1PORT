# Phase 27 source mapping — Spring Yard Act 3 boss completion

Phase 27 is based directly on Phase 26. It completes the Spring Yard Act 3 dynamic boss sequence and repairs the two missing Labyrinth Object `$56` door render frames without expanding Labyrinth gameplay scope.

## SYZ3 dynamic event

Sources:
- `_inc/DynamicLevelEvents.asm` — `DLE_SYZ3`
- `_Constants.asm` — `boss_syz_x`, `boss_syz_y`, `boss_syz_end`

Native mapping:
- camera X `$2AC0`: request the ten Object `$76` arena blocks;
- camera X `$2C00`: tighten the bottom boundary toward `$4CC`, lock the left side of the arena, and request Object `$75`;
- boss right-boundary escape target: `$2D40`;
- the manager expands that boundary by 2 pixels per frame only during Eggman's escape routine.

## Object `$76` — Spring Yard boss blocks

Sources:
- `_incObj/75, 76 Boss - SYZ Main and Blocks.asm`
- `_maps/SYZ Boss Blocks.asm`
- `artnem/8x8 - SYZ.nem`
- `palette/Spring Yard Zone.bin`

The event creates ten 32x32 blocks:
- first center: `$2C10,$582`;
- X spacing: `$20`;
- indices/subtypes: 0 through 9.

The Phase 27 block PNGs are rendered directly from the packaged SYZ Nemesis level art and Spring Yard palette. The source renderer was cross-checked byte-for-byte at the pixel level against the already source-rendered Phase 26 Object `$56` frame 0 before generating the boss-block family.

When Eggman grabs a block, Sonic's standing support is released and the block follows the boss at +44 Y. The break command creates four 16x16 source-mapped fragments with launch values:
- top-left: X `-$180`, Y `-$200`;
- top-right: X `+$180`, Y `-$200`;
- bottom-left: X `-$100`, Y `-$100`;
- bottom-right: X `+$100`, Y `-$100`.

## Object `$75` — Spring Yard Eggman

Sources:
- `_incObj/75, 76 Boss - SYZ Main and Blocks.asm`
- `_maps/Eggman.asm`
- `_maps/Boss Items.asm`
- `_anim/Eggman.asm`

Native source correspondence:
- initial position: `$2DB0,$4DA` (`boss_syz_x+$1B0`, `boss_syz_y+$E`);
- 48x48 boss reaction body;
- 8 hits;
- entrance X velocity `-$100`;
- patrol X velocity `$140` between `$2C08` and `$2D38`;
- Sonic's current 32-pixel arena-block index controls which block Eggman targets;
- attack center positions start at `$2C10` and advance by `$20`;
- descend velocity `$180` to Y `$556` (`boss_syz_y+$8A`);
- with a valid block, wait 50 ticks, lift at `-$800`, and rise 24 pixels above the normal rest height;
- without a valid block, lift immediately at `-$400`;
- lifted-block hold timer: 45 ticks; empty attack timer: 8 ticks;
- block break occurs at timer 0; the spike is re-enabled after the source-style post-break delay;
- the standard boss reaction negates/halves Sonic's impact velocity and applies the existing native separation bridge used by the completed Marble boss;
- after hit 8, Eggman runs the 180-tick explosion sequence, recovery, then escapes at X `$400`, Y `-$40` while unlocking the arena toward `$2D40`.

### Spike child

The source Boss Items mapping uses the dedicated Boss-Weapons PLC for the 16x32 spike child. Phase 26 did not package the standalone `Boss - Weapons.nem` source file, so Phase 27 implements the source extension/retraction, collision timing, dimensions and child placement with a native 16x32 reconstructed texture. This is a visual-fidelity exception, not a gameplay placeholder.

## Labyrinth Object `$56` doors

Sources:
- `_incObj/56 SYZ, SLZ Floating Blocks and LZ Doors.asm`
- `_maps/Floating Blocks and Doors.asm`
- `_inc/Pattern Load Cues.asm`
- `artnem/LZ Vertical Door.nem`
- `artnem/LZ Horizontal Door.nem`

Phase 26 had no `syz_fblock/06.png` or `07.png`, even though the shared Object `$56` mapping selects those frames in Labyrinth. That is why the door logic could exist while its artwork appeared missing/incorrect.

Phase 27 now packages:
- frame 6: 16x64 vertical-door texture;
- frame 7: 128x32 horizontal-door texture.

The original LZ doors use separate Nemesis PLC art rather than the normal packaged LZ level-art bank. Those standalone PLC binaries were not present in the Phase 26 project, so the new frame 6/7 textures are source-sized native reconstructions using the supplied Labyrinth palette. Their movement, collision sizes, mapping dimensions and switch behavior remain source-driven. Replacing only these two textures with exact decompressions later will not require another gameplay rewrite.

## Progression state

With the dedicated SYZ3 event, boss blocks and Object `$75` in place, all three Spring Yard acts are now marked `full_gameplay_support`. Normal progression can continue from SYZ3 into the current Labyrinth work.
