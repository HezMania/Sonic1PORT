# Phase 7 GHZ Loop Collision Fix

## Runtime symptom

The GHZ loop correctly changed the front/back collision state, but near the upper arc Sonic could suddenly lose the expected surface direction, have horizontal motion redirected, and be thrown back down the loop.

## Root cause 1 — missing `$03` angle-buffer sentinel

The original `Sonic_AnglePos` starts every terrain attachment pass with:

```asm
moveq   #3,d0
move.b  d0,(v_anglebuffer).w
move.b  d0,(v_anglebuffer2).w
```

The odd low bit is significant. If a sensor never resolves a collision angle, `Sonic_Angle` detects bit 0 and snaps from Sonic's previous surface angle:

```asm
move.b  obAngle(a0),d2
addi.b  #$20,d2
andi.b  #$C0,d2
```

Returning `$00` for a blank sensor incorrectly means "flat floor" rather than "no new angle was written."

## Root cause 2 — FindFloor2/FindWall2 share the first angle buffer

`FindFloor` writes `(a4)` as soon as it resolves a nonzero collision shape. It can then branch to `.isblank`, `.negfloor`, or `.maxfloor` and call `FindFloor2` on the neighboring tile. `a4` is unchanged.

If the second tile is blank, `FindFloor2` calculates a new distance but **does not overwrite `(a4)`**. The original first tile's angle remains valid.

The previous native implementation returned the second lookup as an entirely new result, so a blank neighbor discarded the valid first angle. This is particularly damaging on curved 16×16 seams in the loop.

Phase 7 adds an `angle_written` flag to native collision results. When an adjacent lookup supplies the distance but not a new angle, `_carry_angle_buffer()` preserves the first tile's angle exactly like the shared 68000 angle-buffer pointer.

The same correction is applied to `FindWall`/`FindWall2` because the loop changes sensor orientation as Sonic moves from floor to wall to ceiling.

## What has not been done

There is no hard-coded loop trajectory, velocity override, invisible path, or forced angle sequence. Sonic still traverses the loop through the general-purpose native ports of:

- `Sonic_AnglePos`
- `Sonic_Angle`
- `FindFloor` / `FindFloor2`
- `FindWall` / `FindWall2`
- `Sonic_Loops`
- the normal inertia-to-X/Y angle conversion

This keeps the fix applicable to other curved terrain later in the game.
