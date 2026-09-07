# Phase 34 Mapping — Labyrinth Pre-Boss Fidelity

Phase 34 is built directly on the user-tested Phase 33 project and uses the re-supplied `s1disasm-AS(1).zip` as the authoritative Sonic 1 source.

## 1. LZ2 sideways spring correction

Reported runtime position: approximately `(1529,496)`.

Authoritative object-position record:

- X: `$05F8` (1528)
- Y: `$01F0` (496)
- Object: `$41` Spring
- Subtype: `$10`
- X-flipped

Source routine: `_incObj/41 Springs.asm`, horizontal `Spring_LR` path.

The horizontal source path writes Sonic's X velocity and inertia, changes horizontal orientation, and clears pushing. Unlike the vertical spring paths it does **not** set Sonic's airborne status. The native shared spring helper previously set `in_air = true` for every spring direction, causing this LZ2 spring to throw Sonic away from the terrain.

Phase 34 gives horizontal springs an early return after their X-only response, preserving Sonic's existing grounded/airborne state.

## 2. LZ1 first wind/current door correction

Authoritative LZ1 door record:

- X: `$0B08`
- Y: `$02E0`
- Object: `$56`
- Subtype: `$E3`
- Switch index: 3

Source routine: `_incObj/56 SYZ, SLZ Floating Blocks and LZ Doors.asm`, `FBlock_LZSmallDoor_Open`.

This specific LZ1 door has source-only coupling to `f_wtunneldisallow`: while Sonic is still left of the door and switch 3 has not been pressed, the wind/current must be disabled. Once switch 3 is pressed, the blocker clears and the tunnel can carry Sonic through the opening door.

Phase 33 had implemented wind blockers for Object `$0C` flapping doors and poles, but not this special Object `$56` case. Phase 34 adds that missing blocker using its own keyed contribution so it composes with the existing tunnel blockers.

## 3. Object `$60` — Orbinaut

Authoritative sources:

- `_incObj/60 Badnik - Orbinaut.asm`
- `_maps/Orbinaut.asm`
- `_anim/Orbinaut.asm`
- `artnem/Enemy Orbinaut.nem`

Authored LZ placements:

- LZ1: 1
- LZ2: 4
- LZ3: 1
- Total: 6

Implemented source behavior:

- Parent uses the source 16×16 badnik collision class.
- Four spikeballs begin at angles `$00/$40/$80/$C0`.
- Orbit radius is 16 pixels (`CalcSine >> 4`).
- Orbit direction reverses for X-flipped placements.
- LZ subtype 0 begins in the Sonic-proximity check routine.
- Anger trigger uses the source 160-pixel X and 80-pixel Y windows.
- Source anger animation cadence is retained.
- While the angry parent frame is active, an attached ball at angle `$40` fires.
- Fired ball horizontal speed is `$200` magnitude in the source-facing direction.
- After all four balls have fired, the parent moves horizontally at `$40` magnitude.
- Attached balls are removed with the parent; already-fired balls can outlive it until leaving the active screen range.

Art is decoded directly from `Enemy Orbinaut.nem` using the source mappings. No replacement graphics are generated.

## 4. Object `$52` — LZ1 secret raft

Authoritative sources:

- `_incObj/52 Moving Blocks.asm`
- `_maps/Moving Blocks (LZ).asm`
- `artnem/LZ 32x16 Block.nem`

Final LZ placement:

- X: `$09C0`
- Y: `$0108`
- Object: `$52`
- Subtype: `$07`

Source behavior implemented:

1. Type 7 remains hidden and non-solid until switch 2 is pressed.
2. Switch 2 converts it to type 4 and returns for that frame.
3. Type 4 waits until Sonic actually stands on it.
4. It becomes type 5 and moves right at exactly 1 px/frame.
5. On reaching a wall it becomes type 6 and falls with `$18` gravity.
6. It lands and becomes stationary/top-solid.

The LZ-specific source size (32×16 visual with 7-pixel half-height) is used instead of the Marble Zone block dimensions.

## 5. LZ3 runtime foreground mutation

Authoritative source: `_inc/DynamicLevelEvents.asm`, `DLE_LZ3`.

When switch `$F` is pressed, the original changes foreground layout row 2 / column 6 to chunk `$07`. Phase 34 adds a runtime chunk mutation path that updates both:

- the level layout/collision data; and
- the already-instantiated foreground chunk sprites.

The shipped `levels/lz3.bin` already contains `$4B` at row 2 / column 6, so the earlier LZ water-feature `$4B` write is naturally a no-op until the later dynamic event replaces it with `$07`.

Object `$65` subtype `$A9` now checks this exact runtime layout cell. Its hidden splash remains at low priority before the mutation and becomes high-priority after chunk `$07` appears, matching `WFall_Priority`.

The source rumble/SFX call associated with this event remains deferred because the native project still does not have the original sound-driver/SFX path.

## 6. Source-asset policy

Phase 34 continues the project rule that known original Sonic art is never reconstructed when a source asset exists. The new Phase 34 art streams retained in the project are exact copies of:

- `artnem/Enemy Orbinaut.nem`
- `artnem/LZ 32x16 Block.nem`

They are validated byte-for-byte against the user-supplied disassembly along with all LZ source/data streams retained from Phases 29–33.
