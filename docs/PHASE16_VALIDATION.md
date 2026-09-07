# Phase 16 validation

This build was statically validated in the packaging environment. Godot itself is not installed there, so the final runtime/parser validation remains a Godot 4.6.3 test.

Checks performed:

- project/resource ZIP integrity;
- every PNG under `assets/` decoded with Pillow;
- all literal `res://...` paths referenced by GDScript/TSCN resolve;
- duplicate `class_name` scan;
- bracket/parenthesis/brace balance for GDScript;
- stale `manager.collision.find_ceiling(...)` call scan (none remain);
- retained Godot 4.6.3 `Sonic_Animate` local declarations using `=`;
- retained ProjectSettings-based viewport width/height changes;
- MZ1 push block/stomper X range `$A20..$AA0` is represented in the native bridge;
- switch-glass initial distance is 144 and switch index uses the upper subtype nibble;
- the exact reconstructed stomper spike strip is 88x32 pixels;
- regular death restart timer is 60 simulation ticks and clears after restart.

High-priority runtime tests:

1. Die normally and verify the approximately one-second pause after Sonic falls below the view before reload.
2. Walk across the hill-shaped moving grass platforms and verify the surface no longer produces a quick artificial rise/drop.
3. Push/jump around the small Object `$52` moving blocks to verify side and underside solidity.
4. Stand on a burnable grass platform and verify it depresses downward before fire spreads.
5. Exercise ceiling-bound Basaran/lava-ball behavior and verify there is no `find_ceiling` invalid-call error.
6. In MZ1, push the block across the first spiked stomper and onto the button; the block should ride the stomper instead of falling through it.
7. Inspect the spiked stomper art; five long downward spikes should now align directly beneath the block.
8. In MZ2/MZ3, approach a subtype-4 green glass pillar before pressing its matching button; it should begin 144 pixels above its authored destination and only descend after activation.
9. Observe Caterkiller on slopes; its segments should track terrain more plausibly, though exact source fragmentation remains deferred.
