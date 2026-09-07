# Phase 24 source mapping — Spring Yard fidelity

## Yadrin — Object $50

Sources:
- `_incObj/50 Badnik - Yadrin.asm`
- `_anim/Yadrin.asm`
- `_maps/Yadrin.asm`
- `artnem/Enemy Yadrin.nem`

`Yad_Main` sets `ArtTile_Yadrin|Tile_Pal2`, so the native export decodes the source art on palette line 1. The eight-frame walk sequence remains `0,3,1,4,0,3,2,5`.

## Button — Object $32

Sources:
- `_incObj/32 Button.asm`
- `_maps/Button.asm`
- `artnem/Switch.nem`
- `_Constants.asm`

The critical source constant is:

`ArtTile_Button_Main = ArtTile_Button + 4`

The first four tiles of the common switch art are an unused red-top set. SYZ/LZ/SBZ begin four tiles later. Frame 0 is `.up`; frame 1 is `.down`. Phase 24 applies the +4 tile base when generating the native button images.

## Basic SYZ platform — Object $18

Sources:
- `_incObj/18 Platforms.asm`
- `_maps/Platforms (SYZ).asm`
- `artnem/8x8 - SYZ.nem`

The SYZ mapping is three pieces using level-art tiles `$49`, `$51`, and `$55`, with `Tile_Pal3`. The regenerated sprite is the 64-pixel-wide platform used by Object $18, including the platform near the user-reported `(2928,849)` region.

## Floating blocks — Object $56

Sources:
- `_incObj/56 SYZ, SLZ Floating Blocks and LZ Doors.asm`
- `_maps/Floating Blocks and Doors.asm`
- `artnem/8x8 - SYZ.nem`

All five SYZ frames are source-rendered again in Phase 24. Source collision half-sizes remain:
- frame 0: 16×16 (32×32 full)
- frame 1: 32×32 (64×64 full)
- frame 2: 16×32 (32×64 full)
- frame 3: 32×26
- frame 4: 16×39

## Roller — Object $43

Source:
- `_incObj/43 Badnik - Roller.asm`

`Roll_Action_FromLeft` uses `addq.l #4,sp` to skip returning through `Roll_Action`; therefore neither sprite display nor `RememberState` runs while Roller waits for Sonic to move more than `$100` pixels to its right. Phase 24 mirrors that unusual lifetime rule through `GenesisLevelObject.suppress_central_despawn()`.

## Sonic sensor visualization

Sources:
- `_incObj/Sonic Collision.asm`
- `_incObj/Sonic AnglePos.asm`
- native `sonic_player.gd` collision wrappers

Negative-direction collision calls use an XOR-`$F` coordinate before `FindFloor`/`FindWall`. This is required for the source collision traversal but is not the physical sensor origin. Phase 24 changes only F2 visualization:
- upward sensor display Y = queried Y XOR `$F`
- leftward sensor display X = queried X XOR `$F`

The collision query inputs and returned distances/angles are unchanged.

## SYZ Act 2

SYZ2 has 230 placement records. Its distinct placed IDs are covered by existing native classes; the only additional level-specific camera behavior is the already-ported late-route `_dle_syz2()` boundary transition. Phase 24 therefore promotes Acts 1 and 2 to `full_gameplay_support`; Act 3 remains pending the Spring Yard boss sequence.
