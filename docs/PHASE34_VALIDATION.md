# Phase 34 Validation — Labyrinth Pre-Boss Fidelity

## Environment

- Target runtime: Godot 4.6.3
- Authoritative source: user-supplied `s1disasm-AS(1).zip`
- Packaging environment: no Godot executable is installed, so final parser/runtime behavior must still be confirmed in the user's Godot 4.6.3 editor.

## Targeted implementation assertions

The release validation checks:

1. LZ2 horizontal spring branch does not set Sonic airborne.
2. LZ1 Object `$56` switch-3 door supplies the pre-switch wind blocker.
3. Object `$60` is routed to the native Orbinaut class.
4. Orbinaut uses the exact-source texture helper.
5. LZ1 Object `$52` subtype 7 remains hidden until switch 2 and converts to type 4.
6. Runtime level data supports foreground chunk replacement.
7. Foreground renderer supports rebuilding one mutated chunk.
8. LZ3 switch `$F` changes row 2 / column 6 to chunk `$07`.
9. Object `$65` hidden splash priority reads that exact layout cell.
10. All 28 retained checked LZ source/data binaries are byte-identical to the supplied disassembly.
11. No duplicate `class_name` declarations.
12. No missing concrete literal `res://` resources.
13. No rough delimiter-balance warnings.
14. Authored Orbinaut counts decode to 1/4/1 across LZ1/LZ2/LZ3.
15. Authored LZ Object `$52` secret raft counts decode to 1/0/0.

## Authoritative object-position spot checks

- LZ2 spring: `$05F8,$01F0`, Object `$41`, subtype `$10`, X-flipped.
- LZ1 wind door: `$0B08,$02E0`, Object `$56`, subtype `$E3`.
- LZ1 secret raft: `$09C0,$0108`, Object `$52`, subtype `$07`.
- Orbinaut placements: 1 in LZ1, 4 in LZ2, 1 in LZ3.

Object-position object IDs are masked with `$7F` during validation because the raw high bit can carry render/remember state; therefore an Orbinaut record can contain raw `$E0` while its object ID is `$60`.

## Exact retained source/data checks

The release compares 28 project files byte-for-byte to the supplied disassembly:

- LZ vertical/horizontal doors
- LZ spiked ball & chain
- LZ water surface
- LZ water & splashes
- LZ bubbles & countdown
- LZ Harpoon
- Enemy Jaws
- Enemy Burrobot
- LZ rising platform
- LZ cork
- LZ 32×32 block
- LZ Gargoyle & fireball
- LZ breakable pole
- LZ flapping door
- LZ wheel
- six LZ conveyor platform placement binaries
- dry and underwater conveyor palette-cycle binaries
- Labyrinth Zone underwater palette
- Sonic LZ underwater palette
- Enemy Orbinaut
- LZ 32×16 block

No fallback/reconstructed art is included for these systems.

## Whole-project static checks

Final release tree is checked for:

- GDScript/class counts
- duplicate named classes
- PNG decode failures
- missing literal `res://` resources
- rough `()`, `[]`, `{}` delimiter mismatches
- ZIP integrity

See the final validation summary in the release response for exact counts/results.

## Final static release result

- Targeted assertions: **15/15 passed**
- GDScript files: **79**
- Named `class_name` declarations: **76**
- PNG files: **535**
- PNG decode failures: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate named classes: **0**
- Rough delimiter warnings: **0**
- Exact checked LZ source/data matches: **28/28**
- Orbinaut authored placement counts: **1 / 4 / 1**
- Secret LZ raft authored placement counts: **1 / 0 / 0**

ZIP integrity is checked after packaging.
