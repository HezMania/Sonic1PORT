# Phase 41 Mapping — Scrap Brain Foundation

Phase 41 begins native Scrap Brain Zone gameplay from the user-tested Phase 40 wrapping build. The supplied `s1disasm-AS` tree remains the authoritative source. No known original SBZ graphics were reconstructed or replaced.

## Zone routing and deformation

### Scrap Brain Acts 1–2

The level catalog now marks SBZ Acts 1 and 2 as `SBZ PLAYTEST` and assigns:

- `background_mode = "sbz"`
- `dynamic_events = "sbz1"` / `"sbz2"`
- `full_gameplay_support = true` as the project's level-routing gate

This flag enables playtesting; it does **not** mean every Scrap Brain object or the Final Zone sequence is complete.

### REV01 `Deform_SBZ`

Act 1 reproduces the source 32-band background scroll table:

- four cloud bands: foreground X × `16/64`, `15/64`, `14/64`, `13/64`
- ten distant brown-building bands: foreground X × `1/4`
- seven upper black-building bands: foreground X × `3/8`
- eleven lower black-building bands: foreground X × `1/2`
- background vertical position: foreground Y × `1/8`

Act 2 uses the source plain deformation:

- background X: foreground X × `1/4`
- background Y: foreground Y × `1/8`

All strip widths continue to use the configured ProjectSettings viewport width rather than a hard-coded 320-pixel runtime width.

## Dynamic level events

### `DLE_SBZ1`

The source lower-boundary targets are implemented:

- before camera X `$1880`: `$720`
- from `$1880`: `$620`
- from `$2000`: `$2A0`

### `DLE_SBZ2`

The normal traversal boundary change is implemented:

- before camera X `$1800`: `$800`
- from `$1800`: `boss_sbz2_y = $510`

The later `$1EB0` FalseFloor event and `$1F60` ScrapEggman cutscene are deliberately deferred to the dedicated SBZ2/Final Zone transition phase.

## Object `$66` — Rotating Junction

Source: `_incObj/66 SBZ Rotating Junction.asm`, `_maps/Rotating Junction.asm`, `artnem/SBZ Junction Wheel.nem`.

Implemented:

- 16 exact rotation frames plus the source circular overlay frame
- one frame step every 8 game frames
- default clockwise direction
- subtype-selected switch reversal, edge-triggered once per button press
- source left/right entrance-gap tests (`$E` from left, `7` from right)
- player control lock and Roll pose/state while captured
- source `$800` inertia used for the roll animation
- exact 16-entry Sonic position table
- half-way first-frame snap used by `Jun_ChgPos`
- source exits at frame `4` or `7`, excluding the entrance frame
- downward exit `$800` Y velocity; right exit also `$800` X velocity
- original overlay renders above the rotating gap sprite

Authored placements: **2 in SBZ1, 0 in SBZ2**. Switch subtypes are `0` and `2`.

## Object `$67` — Running Disc / Gear Controller

Source: `_incObj/67 SBZ Running Disc.asm`, `_maps/Running Disc.asm`, `artnem/SBZ Running Disc.nem`.

The visible gear itself remains level terrain, matching the original. The native object controls Sonic and renders only the small moving spot.

Implemented:

- source large-gear radius `$18` and trigger radius `$48`
- prototype-compatible lower-nibble small-gear values `$10/$38`
- placement-flip-derived starting phase
- signed upper-nibble rotation speed
- grounded square-range attachment
- minimum/maximum clockwise speed `$400..$F00`
- equivalent negative counterclockwise clamp
- source `sticktoconvex` behavior so normal 14-pixel convex-detach rules do not eject Sonic from the running gear
- orbiting spot position from source sine/cosine radius math

Authored placements: **0 in SBZ1, 8 in SBZ2**. All final-game placements use subtype `$40`.

## Object `$68` — Conveyor Belt Region

Source: `_incObj/68 SBZ Conveyor Belt.asm`.

The object is intentionally invisible because belt graphics are part of terrain.

Implemented:

- lower subtype nibble zero: 256-pixel region / 128-pixel half-width
- nonzero lower nibble: 112-pixel region / 56-pixel half-width
- signed upper subtype nibble converted directly to pixels/frame (`$20=+2`, `$E0=-2`, `$40=+4`)
- source vertical activation band from 48 pixels above the object up to its Y coordinate
- only pushes grounded Sonic

Authored placements: **0 in SBZ1, 20 in SBZ2**.

## Object `$69` — Trapdoors and Spinning Platforms

Source: `_incObj/69 SBZ Spinning Platforms and Trapdoors.asm`, `_anim/SBZ Spinning Platforms.asm`, `_maps/Trapdoor.asm`, `_maps/SBZ Spinning Platforms.asm`, `artnem/SBZ Trapdoor.nem`, `artnem/SBZ Spinning Platform.nem`.

### Trapdoors — subtype `< $80`

- exact three source mapping frames
- low subtype nibble × 60-frame open/close period
- animation delay 3
- open sequence `0,1,2` and close sequence `2,1,0`, staying on the final frame
- only fully closed frame 0 is solid
- source collision dimensions: 128×24
- Sonic is detached when the door opens beneath him

### Spinning platforms — subtype `>= $80`

- exact five source mapping frames
- low subtype nibble × 6 initial/reset spin timer
- exact source synchronization mask `(((subtype & $70)+$10)<<2)-1`
- exact 17-step spin/flip sequence
- delay 1 animation timing
- only frame 0 is solid
- source collision dimensions: 32×14
- Sonic is detached as soon as the platform begins showing a nonzero spin frame

Authored placements: **25 in SBZ1, 31 in SBZ2**.

## Object `$6A` — Saws and Pizza Cutters

Source: `_incObj/6A SBZ Saws and Pizza Cutters.asm`, `_maps/Saws and Pizza Cutters.asm`, `artnem/SBZ Pizza Cutter.nem`.

Implemented source subtypes:

- `0`: stationary pizza cutter
- `1`: horizontal oscillator using the source `$0E` oscillator channel
- `2`: vertical oscillator using the source `$06` channel
- `3`: hidden speeding saw triggered when Sonic is 192px to its right
- `4`: hidden speeding saw triggered when Sonic is 224px to its left

Other behavior:

- source X-flipped oscillator reversals/offsets
- pizza-cutter 3-frame animation cadence
- speeding saw frames 2/3
- `$600` 8.8 horizontal speeding-saw velocity
- source ±128-pixel vertical trigger window
- 48×48 hurt collision equivalent

Authored placements: **3 in SBZ1, 11 in SBZ2**.

## Exact source art retained

The following Phase 41 files are copied directly from the supplied disassembly and used at runtime:

- `SBZ Junction Wheel.nem`
- `SBZ Running Disc.nem`
- `SBZ Trapdoor.nem`
- `SBZ Spinning Platform.nem`
- `SBZ Pizza Cutter.nem`

`SBZSourceMaps` was generated from the corresponding original `_maps/*.asm` files. Validation compares every generated mapping piece back to those source files.

## Phase 40 regression preservation

The user-confirmed LZ3 wrapping remains intact. In particular:

- `ghz_level_data.gd` is byte-for-byte unchanged from Phase 40.
- foreground `ghz_renderer.gd` is byte-for-byte unchanged from Phase 40.
- `SonicPlayer.wrap_vertical_0x800()` is unchanged.
- `SonicCamera._vertical_wrap_enabled()` is unchanged.

SBZ2 itself also uses the original `top=-$100 / bottom=$800` level-size sentinel, so the existing generic Phase 40 wrap support naturally applies there as intended by the Sonic 1 source.

## Deferred

The following remain later source-fidelity phases rather than approximations:

- Objects `$6B–$72` and other remaining SBZ-specific families
- SBZ2 FalseFloor / Eggman cutscene and transition
- Final Zone boss/event sequence
- original sound-driver music/SFX
- exact animated CRAM palette cycling
