# Phase 32 validation report

Phase 32 was built from the full user-tested Phase 31 project and checked against the re-supplied authoritative `s1disasm-AS(1).zip`. Runtime validation still requires Godot 4.6.3 because a Godot executable is not installed in the packaging environment.

## Reported bug correction

The Phase 31 hurt path used dry `HurtSonic` launch velocities even when `underwater == true`. The disassembly explicitly replaces the dry `-$400` Y / `-$200` X launch with `-$200` Y / `-$100` X underwater. Phase 32 now does the same. The existing source-style `$10` underwater hurt gravity remains unchanged.

Targeted checks passed for:
- underwater hurt Y `-$200`;
- underwater hurt X `-$100`;
- underwater hurt gravity `$10`.

## New native object coverage

Phase 32 routes the following placement IDs to `LZNativeObject`:
- `$61` Labyrinth multi-variant blocks;
- `$62` Gargoyle / fireball;
- `$65` waterfalls / splashes.

Placement scan of the packaged final-game object-position files:

| Object | LZ1 | LZ2 | LZ3 | Total |
|---|---:|---:|---:|---:|
| `$61` | 21 | 3 | 19 | 43 |
| `$62` | 2 | 2 | 5 | 9 |
| `$65` | 8 | 17 | 35 | 60 |
| **Total** | **31** | **22** | **59** | **112** |

## Exact source-art verification

The following retained Nemesis streams compare byte-for-byte with the re-supplied disassembly:

1. `LZ Vertical Door.nem`
2. `LZ Horizontal Door.nem`
3. `LZ Spiked Ball & Chain.nem`
4. `LZ Water Surface.nem`
5. `LZ Water & Splashes.nem`
6. `LZ Bubbles & Countdown.nem`
7. `LZ Harpoon.nem`
8. `Enemy Jaws.nem`
9. `Enemy Burrobot.nem`
10. `LZ Rising Platform.nem`
11. `LZ Cork.nem`
12. `LZ 32x32 Block.nem`
13. `LZ Gargoyle & Fireball.nem`

The retained `Labyrinth Zone Underwater.bin` and `Sonic - LZ Underwater.bin` palettes also remain byte-identical to the authoritative source.

No fallback or hand-drawn art was introduced.

## Targeted source/behavior assertions

All **13 / 13** Phase 32 assertions passed:
- underwater hurt launch Y;
- underwater hurt launch X;
- underwater hurt gravity;
- `$61/$62/$65` routing;
- 30-frame block wait;
- 2 px/frame cork water-follow cap;
- Gargoyle `$200` fireball velocity;
- left/right fireball wall probes;
- subtype `$49` waterfall waterline following;
- source splash animation loop;
- exact LZ block art-bank references;
- exact Gargoyle art reference;
- exact waterfall art reference.

## Package-integrity checks

- GDScript files: **77**
- Named native classes: **74**
- PNG assets: **535**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough structural delimiter warnings: **0**
- Exact checked Nemesis streams: **13 / 13**
- Targeted Phase 32 assertions: **13 / 13**

## Runtime checklist for Godot 4.6.3

1. Take damage while fully underwater. Sonic's initial recoil should now be visibly about half the dry launch in both axes and should no longer shoot excessively upward/away.
2. Test subtype `$01` LZ blocks: after Sonic stands on one for about half a second, it should begin sinking.
3. Test subtype `$13` rising platforms: after the same delay, they should begin rising and carry Sonic with them.
4. Check subtype `$27` corks against a changing water level; they should follow the actual swaying water surface at at most 2 px/frame.
5. Check stationary subtype `$30` blocks for correct exact source art and solidity.
6. Observe Gargoyles in all three acts. Fireballs should launch at the authored interval/direction, animate, hurt Sonic, and disappear on wall impact.
7. Inspect waterfall/splash placements. `$49` should stay attached to the dynamic water surface. `$A9` is intentionally not promoted until the still-deferred LZ3 layout mutation is implemented.

Godot itself is not present in the packaging environment, so editor/runtime behavior remains the user's final validation step.
