# Phase 25 source mapping — Spring Yard runtime corrections

## Object $50 — Yadrin special collision

Sources:
- `_incObj/50 Yadrin.asm`
- `_incObj/sub ReactToItem.asm`

Yadrin initializes `obColType` to `$CC`. `$CC` is not the ordinary enemy response: `React_Special` performs a Yadrin-specific test before deciding whether to fall back to `React_Enemy`.

Native Phase 25 mapping:
- overall object reaction size follows collision table entry `$0C`: half-width 20, half-height 16;
- Sonic's reaction rectangle follows the source's 16-pixel reaction width and current height minus 3 pixels;
- shallow top penetration (`< 8` pixels) enters the special Yadrin test;
- the hazardous horizontal strip is 24 pixels wide and shifts with Yadrin's current facing/status bit 0;
- contact in that strip calls the hazard path even when Sonic is rolling/jumping;
- other valid rolling/jumping contacts fall back to normal badnik destruction.

This replaces Phase 24's `_react_standard_badnik(p, 20, 17)` call for Yadrin.

## Object $43 — Roller lifetime

Source:
- `_incObj/43 Roller.asm`

`Roll_RollChk` activates only when Sonic is at least `$100` pixels to Roller's right. While waiting, the stack adjustment skips the rest of `Roll_Action`. Once active, `Roll_Action` uses Roller's current X and the aligned `(v_screenposx-$80)` value, deleting only when the resulting block distance is greater than `$280`.

Native Phase 25 mapping:
- generic `SonicObjectManager` despawn is suppressed for Object `$43` for its entire lifetime;
- `_roller_source_out_of_range()` uses current Roller X:
  - `roller_block = current_x & $FF80`
  - `screen_block = (screen_x-$80) & $FF80`
  - delete when `roller_block-screen_block > $280`;
- the activation frame still skips this tail, matching the source's early return behavior.

## Object $56 — high-bit switch doors

Source:
- `_incObj/56 Floating Blocks and Doors.asm`

`FBlock_Main` interprets a high-bit subtype specially:
- preserve low nibble as `fb_type` (switch index);
- replace the active type with `$05`;
- frame 7 uses type `$0C` and forces `fb_height=$80`.

Type `$05`:
- waits for bit 0 of the selected switch;
- latches activation;
- subtracts 2 from `fb_height` per frame;
- places Y at `origY +/- fb_height`;
- reaches its authored coordinate when `fb_height` becomes zero.

For the reported door placement, subtype `$A0` selects frame 2 and switch 0. Frame 2 has a 32-pixel collision half-height, so its initial `fb_height` is 64. The authored `(3824,579)` center therefore begins at `(3824,643)` when not flipped.

Phase 25 also represents the frame-7 horizontal `$0C` form so high-bit Object `$56` records no longer collapse into a generic stationary block path.

## Object $56 subtype $37 — REV01 moving block

Source:
- `_incObj/56 Floating Blocks and Doors.asm`, type `$07` and REV01 setup/delete checks.

Placement pair in `syz3 (REV01).bin`:
- moving source: `(0x1BB8, 1353)` = `(7096,1353)`, subtype `$37`;
- destination marker: `(0x1F38, 1353)` = `(7992,1353)`, subtype `$37`.

Native Phase 25 mapping:
- source record waits for switch `$F`;
- activation latches once;
- X advances by exactly 1 pixel per frame;
- travel counter ends at `$380` = 896 pixels;
- `7096 + 896 = 7992`, exactly matching the destination record;
- a manager-level `syz_obj56_complete` flag mirrors the source `f_obj56` byte;
- the destination marker is deleted before completion and becomes a stationary type-0 block only after completion;
- generic central despawn is suppressed while the source `$37` block is actively travelling.

## Scope retained from Phase 24

- Source-rendered Yadrin/button/platform/floating-block art remains unchanged.
- F2 negative-direction collision-sensor visualization remains unchanged.
- Dynamic viewport width/height continues to come from `ProjectSettings`.
- SYZ1/SYZ2 support flags remain unchanged.
- SYZ3 boss/event implementation remains deferred.
