# Phase 5 validation notes

## Static/data validation performed

- Phase 5 was built from the Phase 4 tree that was runtime-tested in Godot 4.6.3.
- The three known `Sonic_Animate` ordinary-assignment compatibility lines are retained exactly.
- The Phase 4 rightward camera dead-zone correction remains in `_scroll_horiz`.
- GHZ1 `objpos/ghz1.bin` still parses to **214 placement records**.
- The placement file contains **20 distinct object IDs**: `$0D,$11,$18,$1A,$1C,$1F,$22,$25,$26,$2B,$36,$3B,$40,$41,$42,$44,$49,$4B,$79,$7D`.
- All 20 GHZ1 placement IDs now have an explicit match in `SonicObjectManager._make_object_for_id`.
- Monitor assets contain 12 PNGs and all 12 have distinct file hashes after correcting mapping-piece compositing.
- Collapsing-ledge assets contain the complete 25-piece left and 25-piece right sets.
- Giant-ring assets contain 4 ring frames and 8 flash frames.
- Hidden-bonus assets contain 4 frames.
- Every literal `res://` resource path found in scripts/scene/project files resolves to a file in the package.
- Every custom class instantiated with `.new()` has a corresponding `class_name` script.
- The GHZ1 dynamic camera code uses camera X `$1780`, initial bottom `$300`, lower target `$400`, 2 px normal movement and 8 px airborne accelerated movement.

Some generated ledge fragment files are intentionally visually identical because different mapping pieces can reference identical tile content; completeness is validated by piece count rather than requiring unique hashes.

## Runtime-validation limitation

The artifact build environment does not contain a Godot executable or GDScript linter. Final parser/runtime behavior therefore still needs to be checked in Godot 4.6.3.

## Recommended first runtime checks

1. Run straight off a ledge without jumping: Sonic should remain upright rather than becoming a ball.
2. Break/stand beside several monitor subtypes: icons should visibly animate and Sonic should be blocked by the left/right sides.
3. Jump into a monitor from below and verify the upward response.
4. Progress past camera X `$1780` and watch the HUD `bottom:` values ease from `$300` toward `$400`.
5. Trigger a collapsing ledge and verify the seven-frame delay followed by fragment breakup.
6. Reach the end with >=50 rings, enter the giant ring, and verify the flash reaches `SPECIAL STAGE REQUESTED`.
7. Finish without the giant ring and verify hidden bonuses / time+ring bonus score groundwork.
