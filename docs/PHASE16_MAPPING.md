# Phase 16 source mapping — Marble Zone fidelity / playability

Phase 16 stays on Marble Zone instead of moving to Spring Yard. It is a regression/fidelity pass over the Phase 15 MZ1-3 implementation.

## Sonic death restart delay

Source: `_incObj/01 Sonic.asm`, `Sonic_HandleDeath` / `Sonic_ResetLevel`.

After Sonic falls 0x100 pixels below the camera, the source deducts a life and writes 60 to `restartime`. Routine 8 then waits for that counter before setting the level restart flag. The native port now mirrors that one-second (60 simulation tick) pause for ordinary deaths. TIME OVER / GAME OVER keep their separate card path.

## Object $2F — Large Grassy Platforms

Source: `_incObj/2F, 35 MZ Large Grassy Platforms and Burning Grass.asm`.

Phase 16 corrections:

- `SolidObject_Heightmap` / `SlopeObject_AssumeStoodOn` indexes the height map after shifting the horizontal offset right one bit. Each height byte spans two horizontal pixels. The previous native code consumed one height byte per pixel, making the small hill rise/fall too quickly.
- The collision half-width includes `sonic_solid_width` (11 pixels), as in the source.
- The shaped top is retained, while sides/underside use native solid-box contact so the object is not a top-only platform.
- Burnable subtype `$x5` now **adds** its sine nudge to `lgrass_origY`. The Phase 15 sign was reversed, causing Sonic's weight to lift the platform instead of depressing it.
- Fire begins on the source half-depression threshold (`nudge == $20`).

## Object $30 — Large Green Glass Blocks

Source: `_incObj/30 MZ Large Green Glass Blocks.asm`.

Subtype 4 now implements the source switch state:

- `glass_distanceY = 144` at initialization;
- the pillar begins at `originY - 144`;
- switch ID comes from the upper subtype nibble;
- the first switch press latches `glass_switch_flag`;
- the pillar descends at 2 pixels/frame until `glass_distanceY == 0`;
- the shine retains its separate oscillator motion.

This fixes switch pillars appearing at their already-activated destination before the button is used.

## Object $31 / $33 — Chained Stomper and MZ1 Push Block

Sources:

- `_incObj/31 MZ Chained Stompers.asm`
- `_incObj/33 MZ, LZ Pushable Blocks.asm`

The original game contains a hard-coded MZ1 coupling. While the block X coordinate is `$A20 <= X < $AA1`, the block Y is forced to `v_obj31ypos - $1C`, so it rides on the spiked stomper instead of falling through it. Phase 16 restores that relationship. When the switch is pressed while the block is riding the stomper, upward travel stops at extension `$10`, preventing the block from being crushed into the ceiling.

The stomper spike child is also rebuilt from its original mapping: five `1x4` tile pieces at X `-$2C, -$18, -4, $10, $24`, Y `-$10`, attached at relative Y `$1C`. The generic half-scale spike sprites used previously are removed.

## Object $52 — Marble Moving Blocks

Source: `_incObj/52 Moving Blocks.asm` plus the shared native SolidObject bridge.

The moving blocks continue using their source oscillator paths and platform carrying, but Phase 16 resolves them as complete solid boxes rather than top-only platforms. This is intentionally stricter than the old native approximation so Sonic cannot pass through the sides/underside of the small lava-section blocks.

## Ceiling collision API correction

The native collision API exposes `find_ceiling_sensor()`, not `find_ceiling()`. Two stale calls are corrected:

- Basaran return-to-ceiling logic (`mz_badnik_object.gd`)
- Lava ball ceiling-attachment subtype (`lava_ball_object.gd`)

Both now call `GenesisCollision.find_ceiling_sensor(...)`.

## Caterkiller refinement

Source: `_incObj/78 Badnik - Caterkiller.asm`.

The full original Caterkiller uses four OST entries and propagates a 16-byte floor-height history from head to segment. Phase 16 does not claim a byte-perfect replacement yet, but improves the native version in three concrete ways:

- fixes the movement-phase off-by-one so the active phase has 16 native movement updates;
- each of the three body sprites samples terrain at its own 12-pixel-spaced X position instead of floating on a purely visual sine wave;
- body segments have their own harmful contact checks, matching their `col_special` role rather than treating only the head as collidable.

Exact per-segment RAM propagation and the source fragmentation/bouncing routine remain a later Caterkiller fidelity task.
