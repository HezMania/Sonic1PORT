# Phase 43 Mapping — Scrap Brain Transition / SBZ3 Bridge

Phase 43 is built directly from the user-tested Phase 42 Scrap Brain progression tree. The supplied `s1disasm-AS` archive remains the authoritative source. This phase completes the late SBZ2 post-tally transition into the hidden flooded Scrap Brain corridor (internal `LZ act 4` / “SBZ3”) and carries four small Phase 42 runtime corrections forward.

## Phase 42 carry-forward corrections

### Object `$6D` — Flamethrower priority

Source: `_incObj/6D SBZ Flamethrower.asm`, `_maps/SBZ Flamethrower.asm`.

The source flamethrower is a priority sprite. The native object is now rendered above the foreground pipe/terrain layer so the upward flame is visible in front of the pipe rather than disappearing behind it. Animation and hurt timing are otherwise unchanged from Phase 42.

### Object `$6F` — Spin-conveyor solidity while spinning

Source: `_incObj/6F SBZ Spin Platform Conveyors.asm`, `_anim/SBZ Spinning Platforms.asm`.

The six authored SBZ1 conveyor groups still use their exact source custom platform-position streams and the Phase 42 motion paths. Runtime collision is now restricted to the stationary/non-spinning state; a platform clears Sonic's object support for the entire spinning animation. This is a targeted correction from the Phase 42 playtest so visibly spinning faces can no longer behave as solid standing surfaces.

### Object `$53` — SBZ collapsing-floor art

Source: `_incObj/1A, 53 Collapsing Ledges and Floors.asm`, `_maps/Collapsing Floors.asm`, `artnem/SBZ Collapsing Floor.nem`.

The shared collapsing-floor implementation now branches by zone:

- MZ retains its tested MZ assets.
- SLZ retains the Phase 40 SLZ source-art branch.
- SBZ now uses the exact `SBZ Collapsing Floor.nem` stream and the shared `Map_CFlo` SBZ frames instead of falling through to MZ art.

A source VRAM detail is reproduced explicitly: the SBZ floor Nemesis stream contains four tiles, and the original SBZ PLC loads that same stream again at `ArtTile_SBZ_Collapsing_Floor+4`. The Godot source-art helper therefore duplicates the decompressed four-tile stream before applying the eight-tile `Map_CFlo` composition.

### Object `$15` — SBZ swinging spiked ball

Source: `_incObj/15 Swinging Platforms.asm`, `_maps/Big Spiked Ball.asm`, `artnem/SYZ Large Spikeball.nem`.

SBZ now takes its dedicated source branch instead of the GHZ platform branch:

- exact `Map_BBall` ball / chain / anchor composition
- original `SYZ Large Spikeball.nem` stream used by SBZ
- source SBZ palette handling for the ball, gray chain, and anchor
- 48×48 SBZ active/display dimensions
- hurt-object behavior
- no platform standing/carry behavior, matching routine `$C`

Normal GHZ/MZ/SLZ swinging-platform behavior remains separate.

## SBZ2 post-tally continuation

A critical source-order detail is preserved in Phase 43: the late Eggman/floor scene happens **after** the ordinary act-clear tally.

Source: `_incObj/3A Got Through Card.asm`.

For SBZ2 only, when the results tally completes:

1. normal immediate `LevelOrder` progression is suppressed;
2. Sonic control is released;
3. level time remains stopped;
4. the right camera boundary expands by exactly 2 pixels/frame from `$1E40` toward `boss_sbz2_x+$B0 = $2100`.

The source changes to Final Zone music here as well. Original sound-driver music/SFX remain deferred, so Phase 43 implements the gameplay/camera state but does not substitute an approximate music-driver path.

## `DLE_SBZ2` late states

Source: `_inc/DynamicLevelEvents.asm`.

The existing Phase 41 lower-boundary behavior is retained, then the late states continue:

- camera X `$1E00`: enter the late block-event state;
- camera X `$1EB0` (`boss_sbz2_x-$1A0`): spawn Object `$83` False Floor;
- camera X `$1F60` (`boss_sbz2_x-$F0`): spawn Object `$82` Scrap Eggman and lock horizontal progression;
- until camera X `$2050`: the left camera boundary follows the screen position.

These thresholds become reachable naturally only after the post-tally right-boundary expansion described above.

## Object `$83` — False Floor

Source: `_incObj/82, 83 SBZ Eggman Cutscene and Crumbling Floor.asm`, `_maps/SBZ Eggman's Crumbling Floor.asm`.

Implemented:

- controller span `$2000..$2100` at Y `$5D0`;
- eight 32×32 floor blocks centered at `$2010..$20F0`;
- exact five mapping frames from the supplied source;
- source `SBZ Vanishing Block.nem` art stream and SBZ palette line;
- full floor solidity before Eggman signals `GO`;
- source 8-bit break accumulator subtracting `$0E`, producing the original staggered left-to-right break cadence;
- remaining right-hand portion stays solid as left blocks disappear;
- four source fragment offsets and initial Y velocities per broken block;
- source-style `$38` gravity for fragments;
- object-support detachment when the supported portion disappears.

The native transient-object order differs from the 68000 OST iteration order, so Phase 43 explicitly preserves the source one-frame ordering on the frame Eggman writes `GO`.

## Object `$82` — Scrap Eggman

Source: `_incObj/82, 83 SBZ Eggman Cutscene and Crumbling Floor.asm`, `_anim/Eggman - Scrap Brain 2.asm`, `_maps/Eggman - Scrap Brain 2.asm`.

Implemented source sequence:

- starts at `($2160,$5A4)`;
- creates the floor switch at `($2130,$5BC)`;
- waits for Sonic to approach from the left within `$80` pixels;
- 180-frame laugh wait;
- jump preparation and 15-frame delay;
- launch velocity X `-$FC`, Y `-$3C0` in source 8.8 units;
- gravity `+$24`;
- horizontal stop at X `$2132`;
- presses the switch while descending at Y `$595`;
- lands at Y `$59B`;
- signals the False Floor to begin breaking after landing;
- exact stand/laugh/jump source mapping frames used by this cutscene.

## SBZ2 bottom-boundary transition

Source: `_incObj/01 Sonic.asm` (`Sonic_LevelBound`).

The original game does **not** transition directly from SBZ2 to Final Zone when Sonic falls through Eggman's floor. If Sonic crosses the lower boundary on the right side of X `$2000`, the game sets the level ID to internal `id_LZ_act4` and restarts the level.

Phase 43 reproduces that special branch. Falling below the boundary elsewhere still uses the normal death path.

## Internal LZ Act 4 — flooded “SBZ3” corridor

The hidden level is now represented explicitly in `LevelCatalog` as `(ZONE_LZ, act 4)` while remaining outside normal public Labyrinth progression.

Exact supplied source data used:

- `levels/sbz3.bin`
- `objpos/sbz3.bin`
- `startpos/sbz3.bin`
- `palette/SBZ Act 3.bin`
- LZ 16×16 / 256×256 mappings and LZ collision
- `artnem/8x8 - LZ.nem` for terrain

Source bounds:

- left `$0000`
- right `$20BF`
- top `$0000`
- bottom `$0720`

The dedicated source object-position stream contains **195 authored records**.

### SBZ3 water

Source: `_inc/LZWaterFeatures.asm`.

- initial/target water Y `$228`;
- at camera X `$F00`, target becomes `$4C8`;
- the existing native one-pixel-per-frame water approach and surface oscillation continue to be used.

### SBZ3 wind tunnel

The internal act's source tunnel region is enabled:

- left `$C80`
- top `$600`
- right `$13D0`
- bottom `$680`

It reuses the already-native LZ wind-tunnel movement path.

## Object `$6B` — ancient SBZ3 lift

Source: `_incObj/6B SBZ Stomper and Sliding Door.asm`, `_maps/SBZ Stomper and Door.asm`.

The fifth `Sto_Var` entry, which is only relevant to internal LZ4/SBZ3, is now enabled there.

Authored source records:

- `($0980,$0140)`, subtype `$40`
- `($0A80,$00C0)`, subtype `$CB`

The source `v_obj6B` singleton behavior is reproduced so only the currently relevant lift record survives. Subtype `$CB` waits on switch `$B`, then moves left 1 pixel/frame and down 0.5 pixel/frame until it reaches `($0980,$0140)`.

The lift uses `Map_Stomp` frame 4 and the exact `LZ Blocks.nem` stream loaded at the source `$1F0` tile range; it does not incorrectly sample the normal LZ terrain Nemesis stream.

## SBZ3 exit to Final Zone

Source: `DLE_SBZ3`.

When:

- camera X is at least `$D00`, and
- Sonic rises above Y `$18`,

Phase 43 restarts into the real Final Zone level ID `(ZONE_SBZ, act 3)`.

This completes the source bridge **to** Final Zone. The Final Zone boss/event sequence itself is intentionally not approximated in this phase.

## Newly retained exact source streams

Phase 43 adds byte-identical copies of:

- `Boss - Eggman in SBZ2 & FZ.nem`
- `Switch.nem`
- `SBZ Collapsing Floor.nem`
- `SYZ Large Spikeball.nem`
- `LZ Blocks.nem`

The existing dedicated SBZ3 layout/object/start/palette data were also verified byte-for-byte against the supplied disassembly.

## Deferred

- Final Zone `DLE_FZ` encounter progression
- Object `$85` Final Zone boss and its associated `$84/$86` families/event pieces
- source Final Zone defeat/ending handoff
- original sound-driver music/SFX, including the post-SBZ2 Final Zone music change
- exact animated CRAM palette cycling
