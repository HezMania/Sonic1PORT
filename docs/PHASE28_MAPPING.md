# Phase 28 source mapping — source-art fidelity / SYZ boss correction / LZ water foundation

Phase 28 is based directly on Phase 27. Its first purpose is to remove the visual approximations identified during runtime testing. Its second purpose is to continue Labyrinth Zone with the original water-height and underwater-movement systems rather than advancing with placeholder behavior.

## Project-wide source-art rule

The supplied `s1disasm-AS.zip` is available again and is now the authoritative art/source input. Phase 28 adopts the standing rule recorded in `SOURCE_ASSET_POLICY.md`: when the original game has a known source asset, the native port does not invent or redraw it.

## Object `$75` — Spring Yard boss hover correction

Source:
- `_incObj/75, 76 Boss - SYZ Main and Blocks.asm`
- common `BossMove`

The source hover path is:

1. `CalcSine` using `BossSpringYard_SineCounter`;
2. signed arithmetic shift right by 2;
3. write the result to `obVelY` (8.8 velocity);
4. `BossMove` integrates that velocity into the internal 16.16 `obBossY` position;
5. copy the resulting integer boss position to render Y.

Phase 27 incorrectly treated the sine result after `/4` as a direct pixel render offset. With the source sine table that can add about -64..+64 pixels directly to Y. Phase 28 removes `bob_offset`, writes the sine value to `vel_y`, and lets `_move()` perform the same 8.8 -> 16.16 integration used elsewhere in the native boss code.

A one-cycle static simulation using the packaged `GenesisMath.SINE` table produces an integrated vertical span of about 10.26 pixels instead of the roughly 128-pixel direct-offset span of the Phase 27 translation.

## SYZ boss spike — exact source graphic

Sources:
- `artnem/Boss - Weapons.nem`
- `_maps/Boss Items.asm`, frame `.spike` / boss-item frame 5
- `_incObj/75, 76 Boss - SYZ Main and Blocks.asm`
- Spring Yard/Eggman palette line `Tile_Pal2`

Phase 28 packages the original 745-byte `Boss - Weapons.nem` stream verbatim at:

`data/s1/artnem/Boss - Weapons.nem`

The native spike PNG is regenerated from that stream and the source mapping, yielding the original 16x32 composite. The child now starts at Eggman's own Y and applies only the source `generic_timer >> 2` extension offset; the extra native `+12` base-Y offset from Phase 27 is removed.

The source spike collision uses an 8-pixel horizontal radius and 12-pixel height, and Phase 28 uses those values for the native hazard overlap.

## Labyrinth Object `$56` doors — exact source graphics

Sources:
- `artnem/LZ Vertical Door.nem`
- `artnem/LZ Horizontal Door.nem`
- `_maps/Floating Blocks and Doors.asm`
- `_incObj/56 SYZ, SLZ Floating Blocks and LZ Doors.asm`
- `Tile_Pal3`

Original streams are now retained verbatim in the native data tree:

- `LZ Vertical Door.nem` — 161 bytes
- `LZ Horizontal Door.nem` — 338 bytes

Source-derived runtime frames replace the Phase 27 approximations:

- frame 6 / vertical door: 16x64;
- frame 7 / horizontal door: 128x32.

The existing switch-driven opening behavior is retained. Phase 28 additionally represents the source alternate/bit-7 switch state separately from ordinary bit-0 button presses. This lets the hard-coded LZ1 dynamic-water event set switch 5's alternate flag and close the relevant already-opened small door through source type `$06` instead of conflating bit 7 with a normal switch press.

## Labyrinth dynamic water foundation

Source:
- `_inc/LZWaterFeatures.asm`
- `_incObj/01 Sonic.asm` / `Sonic_Water`
- `_inc/DeformLayers (REV01).asm` / `Deform_LZ`
- `_incObj/0A LZ Drowning Countdown.asm` / `Drown_WobbleData`

### Initial water heights

The native manager initializes the three playable LZ acts from the source `WaterHeight` table:

- LZ1: `$0B8`
- LZ2: `$328`
- LZ3: `$900`

### Dynamic target water

Phase 28 ports the REV01 hard-coded target-water state machines for LZ1, LZ2 and LZ3. The internal water height moves one pixel per frame toward the target. The visible water position is then:

`water_surface_y = water_actual_y + (oscillate_02 >> 1)`

matching `v_waterpos1 = v_waterpos2 + ((v_oscillate+2) / 2)`.

The LZ1 `$1080` event also writes the alternate/close state for switch 5. LZ3's switch 8 event is represented. The LZ3 row-2/column-6 foreground layout byte mutation remains deferred to a dedicated mutable-layout pass rather than being approximated.

### Sonic underwater movement

When Sonic crosses below the true LZ water surface, the native player now applies the source transition values:

- top speed `$600 -> $300`;
- acceleration `$0C -> $06`;
- deceleration `$80 -> $40`;
- entry X velocity divided by 2;
- entry Y velocity divided by 4;
- underwater jump impulse `$380` instead of `$680`;
- jump-release cap `-$200` instead of `-$400`;
- ordinary airborne gravity `$10` instead of `$38`.

On leaving the water, surface movement constants are restored, Y velocity is doubled, and very fast upward exits are capped at `-$1000`.

REV01 hurt-state behavior is preserved: normal `Sonic_Water` transition handling is not newly forced during the hurt routine, while an already-underwater hurt state uses the source reduced gravity.

### REV01 LZ background ripple

Phase 26 introduced the 1/2 X / 1/2 Y LZ background plane. Phase 28 now uses the true dynamic waterline and the REV01 `Drown_WobbleData` table for the background half of the per-scanline underwater horizontal ripple. The ripple phase advances by `$80` in the source 16-bit accumulator each frame, making its high byte advance every other frame.

The foreground half of `Lz_Scroll_Data`, underwater palette/HBlank split, drowning/countdown bubbles, wind tunnels/water slides and remaining LZ object families are deliberately not faked. They remain explicit later Labyrinth work.

## Progression status

Spring Yard remains fully supported and Phase 27 boss progression is retained. Labyrinth is still not marked `full_gameplay_support`: Phase 28 materially advances its water foundation, but drowning/bubbles and the remaining LZ-specific gameplay families are still incomplete.
