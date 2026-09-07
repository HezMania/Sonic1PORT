# Phase 20 source mapping

## Pushable block — Object `$33`

Source: `_incObj/33 MZ, LZ Pushable Blocks.asm`

Native correspondence:

- `PushB_Display` current-X range behavior → `object_manager.gd` push-block current-position despawn anchor.
- `PushB_SolidAction .snapToLedge` → `marble_object.gd` `push_drop_state == 1`.
- `PushB_SolidAction .falling` → `push_drop_state == 2`.
- `pblock_lavaspeed / 8` → lava-state `vel_x`.
- `PushB_LavaPlatform` / `MvSonicOnPtfm` → fractional supported-object carry in `sonic_player.gd`.

The geyser-launched state (`obStatus` bit 1 and `-$580` Y velocity) remains deferred.

## Moving blocks — Object `$52`

Source: `_incObj/52 Moving Blocks.asm`

- `MBlock_NextWhenStoodOn` → types `$02/$04` advance only when Sonic owns platform support.
- `MBlock_Right_StopOnWall` → type `$03`.
- `MBlock_Right_FallOnWall` → type `$05`.
- `MBlock_FallingDown` → type `$06`.
- `MBlock_LeftRight` / `MBlock_UpDown` remain backed by the shared oscillator channels.
- Solidity remains `PlatformObject` (top-only), not `SolidObject`.

## Caterkiller — Object `$78`

Source: `_incObj/78 Badnik - Caterkiller.asm`

Phase 20 corrects the source half-height (`14/2 = 7`) used for the floor query. The native body keeps the source 12px spacing and delayed independent turning through a floor-aligned path history. This intentionally favors stable source-like visible behavior over the earlier approximation that could lose segments at corners.

## Lava geyser / lavafall — Objects `$4C/$4D`

Source: `_incObj/4C, 4D MZ Lava Geyser and Maker.asm` and `_anim/Lava Geyser.asm`

The falling column retains `.end` frames `$06/$07`. On pool contact, the maker now executes `.bubble1` (`0,1,0,1,4,5,4,5`, delay 2) rather than leaving the impact effect absent.

## Advancing lava wall — Object `$4E`

Source: `_incObj/4E MZ Wall of Lava.asm`

The source creates a second object at parent X `-$80` using mapping frame 4. The native `back_sprite` keeps this exact offset and is forced into the same high object layer as the leading segment.

## Marble boss — Objects `$73/$74`

Sources: `_incObj/73, 74 Boss - MZ Main and Fire.asm`, `_maps/Boss Items.asm`, `_incObj/Sonic ReactToItem.asm`, `_inc/DynamicLevelEvents.asm`.

- DLE trigger remains `$17F0`; stable locked screen is `$1800`.
- Boss bounce uses `React_BossHit`: `neg.w`, then `asr.w` for X and Y.
- Pipe mapping remains frame 4: `-8,+$14`, `2×2`, weapon tile `$D`; Phase 20 fixes only the offline canvas clipping.
- Boss fire uses a native Z layer behind the boss, corresponding to its lower visual priority relationship.
