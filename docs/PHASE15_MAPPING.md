# Phase 15 source mapping

## Debug level navigation

`LevelCatalog.next_zone()` replaces raw enum incrementing with Sonic 1 progression order. `main.gd` uses `KEY_PAGEDOWN` because Godot Editor reserves F8 for **Stop Running Project**.

## Object `$4C/$4D` — MZ lava geyser/lavafall

Source: `_incObj/4C, 4D MZ Lava Geyser and Maker.asm`

Native:
- `scripts/objects/mz_geyser_object.gd`
- `scripts/objects/mz_geyser_column.gd`
- decoded mappings in `assets/objects/mz_geyser/`

Preserved values include the 120-frame maker interval, `$170` Sonic activation range, lavafall `$250` initial Y offset, `$18` gravity, and the source short/medium/long column mapping families.

## Object `$4E` — advancing lava wall

Source: `_incObj/4E MZ Wall of Lava.asm`

Native: `scripts/objects/mz_lava_wall_object.gd`

Preserved major values:
- 192 px X activation range;
- 96 px Y activation range;
- `$180` move speed;
- `$6A0` hard stop;
- solid + hurt behavior;
- no range deletion while actively moving.

## Object `$51` — smashable green block

Source: `_incObj/51 MZ Smashable Green Block.asm`

Native: `scripts/objects/mz_smash_block_object.gd`

The native routine captures Sonic's pre-SolidObject attack state, breaks only from a top landing while rolling/jumping, forces rolling/airborne state, rebounds at `-$300`, and uses the source four-fragment speed table:

- `-$200,-$200`
- `-$100,-$100`
- `$200,-$200`
- `$100,-$100`

## Object `$53` — collapsing MZ floor

Source: `_incObj/1A, 53 Collapsing Ledges and Floors.asm`

Native: `scripts/objects/mz_collapse_floor_object.gd`

Subtype 1 selects `CollapseData_8x2_Shuffle`:
`$16,$1E,$1A,$12,$06,$0E,$0A,$02`.

The parent waits the original seven-frame contact delay before fragmentation. Native fragments own their own countdown/fall state while platform support remains tied to the fragment under Sonic.

## Object `$73` — Marble Zone boss

Source: `_incObj/73, 74 Boss - MZ Main and Fire.asm`

Native: `scripts/objects/mz_boss_object.gd`

Source constants represented:
- `boss_mz_x = $1800`
- `boss_mz_y = $210`
- `boss_mz_end = $1960`
- left/right swoop bounds `$1830/$1910`
- target Y `$22C`
- lava pool Y `$2E8`
- 8 hits
- swoop X `$200`, initial swoop Y `$100`, per-frame `-4` Y change
- recovery/escape state family
- escape `$500,-$40`

## Object `$74` — boss fire

Native: `scripts/objects/mz_boss_fire_object.gd`

Represents the source 30-frame drop telegraph, `$18` falling acceleration, floor impact, `$A0`-style horizontal spreading concept, temporary floor flames, and hurt collision.

## MZ3 DynamicLevelEvents

Source: `_inc/DynamicLevelEvents.asm`, `DLE_MZ3_Boss` / `DLE_MZ3_End`.

Native: `scripts/camera/sonic_camera.gd` plus `scripts/main.gd`.

- target bottom begins `$720`;
- switches to boss Y `$210` from camera X `$1560`;
- boss trigger at camera X `$17F0`;
- left boundary locks to current camera position;
- screen remains horizontally locked during the fight;
- post-defeat right boundary expands through the boss controller toward `$1960`.
