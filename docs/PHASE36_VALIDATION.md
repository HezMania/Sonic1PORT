# Phase 36 Validation — Star Light Foundation

## Environment

- Target runtime: Godot 4.6.3
- Authoritative source: user-supplied `s1disasm-AS(1).zip`
- Packaging environment: no Godot executable is installed, so final parser/runtime behavior must still be confirmed in the user's Godot 4.6.3 editor.

## Targeted Phase 36 assertions

The release validator checks:

1. SLZ is enabled through the project's playtest-routing gate.
2. Objects `$59/$5A/$5B/$5D/$5F` route to the new SLZ native object implementation.
3. Circling-platform oscillator `$22/$26` baselines match source.
4. Object `$5A` uses those oscillators and source direction/phase bits.
5. Object `$59` contains source distance/acceleration/spawner behavior.
6. Object `$5B` contains 30/60-frame activation timing and 128px travel.
7. Object `$5D` contains the source 2-second-off / 3-second-on cycle and reverse animation path.
8. Object `$5D` uses source-style integer fan-force arithmetic.
9. Object `$5F` contains source walk/wait/fuse timers.
10. Object `$5F` contains exact shrapnel speeds and `$18` gravity.
11. New SLZ object art is sourced from original Nemesis streams.
12. SLZ has a dedicated background deformation mode.
13. REV01 star/building/lower-background parallax rates are present.
14. REV01 `$C0/$3F0` scroll-table starting-band logic is present.
15. Debug UI identifies SLZ as `PLAYTEST` rather than complete.
16. Shared Object `$60` uses SLZ subtype `$02` move/no-anger behavior.
17. SLZ Orbinaut uses the source SLZ palette line.
18. Authored placement counts match for `$59/$5A/$5B/$5D/$5F/$60`.
19. All 28 SLZ Orbinauts are subtype `$02`.
20. 39 selected retained LZ/SLZ source/data files are byte-identical.
21. No duplicate `class_name` declarations.
22. No missing concrete literal `res://` resources.
23. No rough delimiter-balance warnings.
24. All PNG assets decode.
25. No new Godot-4.6-sensitive `:= ... .get(...)` inference pattern exists in Phase 36 code.

## Placement inventory

| Object | SLZ1 | SLZ2 | SLZ3 | Total |
|---|---:|---:|---:|---:|
| `$59` Elevator | 5 | 5 | 6 | 16 |
| `$5A` Circling Platform | 44 | 16 | 8 | 68 |
| `$5B` Staircase | 15 | 3 | 5 | 23 |
| `$5D` Fan | 8 | 14 | 14 | 36 |
| `$5F` Walking Bomb | 13 | 20 | 48 | 81 |
| `$60` Orbinaut | 9 | 7 | 12 | 28 |

## Whole-project result

- Phase 36 targeted assertions: **25/25 passed**
- Phase 35 regression assertions after Phase 36 changes: **20/20 passed**
- GDScript files: **81**
- Named `class_name` declarations: **78**
- PNG files: **535**
- PNG decode failures: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate named classes: **0**
- Rough delimiter warnings: **0**
- Exact checked LZ/SLZ source/data matches: **39/39**

ZIP integrity is checked after packaging.
