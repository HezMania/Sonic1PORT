# Phase 43 Validation — Scrap Brain Transition / SBZ3 Bridge

Static/source validation was run against the full Phase 43 project tree, the pristine user-tested Phase 42 project, and the supplied `s1disasm-AS` archive.

## Result

**101 / 101 targeted Phase 43 assertions passed.**

Project inventory:

- **87 GDScript files**
- **84 named `class_name` declarations**
- **535 PNG files**
- **0 PNG decode failures**
- **0 duplicate named classes**
- **0 missing concrete literal `res://` resources**
- **0 direct `:= dictionary.get()` inference hazards**
- **0 typed-array ternary assignments matching the Phase 41 parser failure**
- **0 rough delimiter-balance warnings**

## Phase 42 reported corrections

Static checks confirm:

- Object `$6D` flamethrowers use the foreground-above render priority in SBZ.
- Object `$6F` spin-conveyor children only resolve standing collision in the stationary/non-spinning animation state and clear support while spinning.
- Object `$53` has an SBZ-specific exact-source art path using `SBZ Collapsing Floor.nem` instead of the MZ fallback.
- The SBZ collapsing-floor helper reproduces the source PLC's second four-tile load at `+4` by duplicating the decompressed stream before applying `Map_CFlo`.
- Object `$15` uses the dedicated SBZ spikeball/chain/anchor art path and bypasses standable platform logic.

The six authored SBZ1 `$6F` spawners remain present with subtypes `$80-$85`. SBZ2 contains the expected 10 Object `$53` collapsing-floor records and 12 Object `$15` swinging spikeball records.

## Source-art/data equality

The five newly retained Phase 43 Nemesis streams are byte-for-byte identical to the supplied disassembly:

- `Switch.nem`
- `SYZ Large Spikeball.nem`
- `Boss - Eggman in SBZ2 & FZ.nem`
- `LZ Blocks.nem`
- `SBZ Collapsing Floor.nem`

The hidden SBZ3 source data were also compared byte-for-byte:

- `levels/sbz3.bin`
- `objpos/sbz3.bin`
- `startpos/sbz3.bin`
- `palette/SBZ Act 3.bin`

The project SBZ1/SBZ2/SBZ3 object-position binaries checked by this phase also remain byte-identical to the supplied source versions.

## Mapping validation

Direct mapping comparisons passed:

- Scrap Eggman — first 5 cutscene frames, piece-for-piece against `_maps/Eggman - Scrap Brain 2.asm`
- False Floor — all 5 frames, piece-for-piece against `_maps/SBZ Eggman's Crumbling Floor.asm`
- Stomper/Door — all generated source frames retained exactly; frame 4 is used by the SBZ3 ancient lift

Piece equality includes X/Y offset, tile width/height, local tile index, X/Y flip, palette flag, and priority flag.

## SBZ2 transition assertions

Static assertions cover:

- post-result-card right-boundary expansion to `$2100` at 2 pixels/frame;
- DLE `$1E00` late-state entry;
- Object `$83` trigger at `$1EB0`;
- Object `$82` trigger at `$1F60`;
- left-boundary following until `$2050`;
- False Floor `($2000..$2100,$5D0)` geometry and eight child blocks;
- `$0E` 8-bit break accumulator behavior;
- shrinking right-hand solid region;
- source fragment gravity `$38`;
- Scrap Eggman start `($2160,$5A4)` and switch `($2130,$5BC)`;
- 180-frame laugh wait and 15-frame pre-jump delay;
- X/Y launch velocities `-$FC / -$3C0`, gravity `+$24`, switch threshold `$595`, and landing `$59B`;
- SBZ2 lower-boundary continuation requires Sonic X `>= $2000` and routes to hidden LZ4 rather than Final Zone directly.

## Hidden SBZ3 validation

The exact source `objpos/sbz3.bin` decodes to **195 authored records**.

The two Object `$6B` ancient-lift records are exactly:

- X `$0980`, Y `$0140`, subtype `$40`
- X `$0A80`, Y `$00C0`, subtype `$CB`

Assertions also cover:

- dedicated `sbz3.bin` layout/object/start/palette routing;
- LZ mappings/collision reuse;
- right boundary `$20BF`, bottom `$720`;
- water `$228` -> `$4C8` at camera X `$F00`;
- wind region `$C80,$600 .. $13D0,$680`;
- ancient-lift singleton gate;
- 1 px/frame left and 0.5 px/frame down motion toward X `$980`;
- source `LZ Blocks.nem` use for the lift;
- DLE_SBZ3 exit at camera X `>= $D00` and Sonic Y `< $18`;
- exit reload into Final Zone `(SBZ, act 3)`.

## Regression isolation

Direct byte comparison with the pristine tested Phase 42 ZIP confirms these stabilized files remain unchanged:

- `scripts/data/ghz_level_data.gd`
- `scripts/render/ghz_renderer.gd`
- `scripts/player/sonic_player.gd`
- `scripts/objects/sbz_native_object.gd`

The Phase 41 `$69` `Array[int]` fix is therefore preserved exactly in Phase 43.

## Runtime limitation

A Godot executable is not available in the packaging environment. Static/source validation cannot prove runtime collision feel, draw ordering, scene timing, or parser behavior in the user's Godot installation. Godot 4.6.3 runtime testing remains authoritative.

Recommended Phase 43 runtime focus:

1. Recheck the four Phase 42 carry-forward bugs: flame priority, spin-conveyor non-solidity while spinning, SBZ collapsing-floor graphics, and SBZ spikeball/chain graphics/behavior.
2. Finish SBZ2 normally and verify the results tally completes before the camera begins opening farther right.
3. Walk into the late corridor and verify FalseFloor loads before Scrap Eggman, Eggman laughs/jumps/presses the switch, and the floor breaks left-to-right while its remaining right side stays solid.
4. Fall through the floor and confirm the game loads the flooded SBZ3 corridor rather than Final Zone immediately or treating the fall as a normal death.
5. In SBZ3, verify water height behavior, the wind tunnel, and the switch-driven ancient lift.
6. Reach the top exit and confirm it transitions into Final Zone.
7. Do not treat the absence of the actual Final Zone boss encounter as a Phase 43 regression; that encounter is intentionally the next major source-fidelity phase.
