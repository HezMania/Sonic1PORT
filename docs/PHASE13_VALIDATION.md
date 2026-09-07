# Phase 13 validation notes

This artifact was statically and data-validated in the packaging environment. A Godot executable is not available there, so Godot 4.6.3 runtime execution remains the definitive validation step.

## Checked

- Phase 13 is based on the Phase 12 multi-act project rather than a parallel/rebuilt project.
- GHZ1/2/3 catalog data and object placement files remain packaged.
- All Phase 12 native GHZ object classes remain present.
- GHZ3 Object `$3E` now maps to `PrisonCapsuleObject` rather than the placeholder class.
- GHZ3 boss trigger uses `boss_ghz_x=$2960`.
- boss initial world position uses `$2A60,$280`.
- boss starts at 8 hits.
- boss right-boundary target is `$2AC0`.
- boss/capsule PNG resources are generated and loadable as PNG files.
- all literal `res://` references resolve inside the project tree.
- generated PNG files across the project decode successfully.
- user-requested viewport ProjectSettings substitutions are present.
- Sonic_Animate Godot 4.6.3 compatibility locals continue to use `=` rather than `:=` for `angle_work`, `render_flip_x`, and `octant_modifier`.
- pushing state is set from both solid faces and is conditioned on the corresponding held direction.
- push animation cadence uses `(0x800 - abs(inertia)) >> 6`.
- moving-platform carry no longer clears horizontal subpixel.
- monitor break path calls the airborne attack-state preservation helper.
- lost-ring collection enters the sparkle timer instead of hiding the ring immediately.
- archive integrity passes after packaging.

## Runtime tests recommended

1. Push a rock/monitor from both sides, then release the direction while still touching it.
2. Observe one full four-frame push cycle at zero/low inertia; it should be much slower than Phase 12.
3. Break an upper monitor and rebound directly into/onto a second monitor.
4. Start moving right from rest while riding a horizontally/vertically moving platform; compare with starting left.
5. Lose rings, recollect several, and verify the four-frame sparkle.
6. Change the project viewport width and confirm camera center, object active range, and GHZ background strip width follow it.
7. Enter GHZ3's boss area at camera X `$2960`; verify the camera locks and Eggman appears.
8. Hit Eggman eight times and verify explosions/recovery/escape.
9. Follow the newly unlocked right boundary to the capsule, press the switch, observe animal release, and verify the act tally begins after the released animals clear.

## Known deferred behavior

- GHZ loop front/back layer/chunk switching.
- Audio/music/SFX.
- Non-GHZ zone-specific gameplay beyond the existing preview-level data loader.

## Package inventory at validation

- 51 GDScript files
- 49 `class_name` declarations
- 383 PNG assets
- 0 failed PNG decodes
- 0 missing literal `res://` references
- GHZ object placements retained: Act 1 = 214, Act 2 = 244, Act 3 = 286
- GHZ3 capsule placements: 2 (`$3E` subtype 1 at `$2B60,$37D`; subtype 0 at `$2B60,$3A2`)
