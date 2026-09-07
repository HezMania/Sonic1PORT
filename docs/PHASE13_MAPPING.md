# Phase 13 source mapping

## Phase 12 bug-fix correspondence

### Pushing / SolidObject
Native files:
- `scripts/player/sonic_player.gd`
- `scripts/player/sonic_visual.gd`

Relevant source concepts:
- `_incObj/sub SolidObject.asm`
- `_anim/Sonic.asm` — `SonAni_Push`

Phase 13 keeps the push flag contact-driven instead of animation-driven. The left face requires Right input; the right face requires Left input. `SonAni_Push` uses the source dynamic delay form based on `$800 - abs(inertia)`, shifted right six bits.

### Monitor attack ordering
Native files:
- `scripts/player/sonic_player.gd`
- `scripts/objects/monitor_object.gd`

Relevant source:
- `_incObj/Sonic ReactToItem.asm` — `React_Monitor`
- `_incObj/26, 2E Monitors and Power-Ups.asm`

`React_Monitor` tests `id_Roll`. Phase 13 preserves the rolling/jump attack state that existed at the beginning of the simulation frame so native terrain/object callback order cannot erase it before the monitor executes. Airborne rebound can restore the roll radii/state when necessary for stacked monitors.

### Moving platform subpixel
Native file:
- `scripts/player/sonic_player.gd` — `move_with_supported_object`

Relevant source:
- `_incObj/sub PlatformObject & SlopeObject.asm`
- `MvSonicOnPtfm` / `MvSonicOnPtfm2`

The platform adds integer displacement without clearing Sonic's horizontal 16.16 fractional position.

### Lost ring sparkle
Native file:
- `scripts/objects/ring_loss_object.gd`

Relevant source:
- Object `$37` ring-loss / Object `$25` ring sparkle behavior.

Collected lost rings switch from the physics state to frames `$04,$05,$06,$07`, six ticks each, before removal.

## Dynamic viewport changes

### `scripts/camera/sonic_camera.gd`
`VIEW_WIDTH` and `VIEW_HEIGHT` are read from:
- `display/window/size/viewport_width`
- `display/window/size/viewport_height`

### `scripts/objects/object_manager.gd`
`is_world_x_on_screen()` uses the configured viewport width instead of literal `320`.

### `scripts/render/ghz_background_renderer.gd`
The region width uses configured viewport width. The vertical source span also uses configured viewport height.

## GHZ3 DynamicLevelEvents
Native file:
- `scripts/camera/sonic_camera.gd`

Relevant source:
- `DynamicLevelEvents` GHZ3 path
- `_Constants.asm`: `boss_ghz_x=$2960`, `boss_ghz_y=$300`, `boss_ghz_end=$2AC0`

At camera X `$2960`, the native camera locks the left boundary and marks `boss_triggered`; `main.gd` then asks `SonicObjectManager` to create the boss once.

## Object $3D/$48 — GHZ boss and wrecking ball
Native file:
- `scripts/objects/ghz_boss_object.gd`

Primary source:
- `_incObj/3D, 48 Boss - GHZ Main and Wrecking Ball.asm`
- `_incObj/sub BossDefeated & BossMove.asm`
- `_incObj/15 Swinging Platforms.asm` for shared swing-style behavior
- Eggman and GHZ boss mappings/art under `_maps`, `artnem`, and animation tables.

Mapped behaviors:
- 8 boss hits;
- intro down velocity `$100`;
- make-ball movement `-$100,-$40`;
- 120-frame initial wait;
- `$40` / `$80` travel timing and `$100` / `$40` X velocities;
- direction changes;
- `$B3` explosion timer;
- recovery counter starting at `-38`;
- recovery Y acceleration `$18` / rise decrement `8`;
- escape `$400,-$40`;
- right boundary unlock +2/frame to `$2AC0`.

The wrecking chain is rendered as native child sprites. Swing position is derived from the same 8-bit sine/cosine convention used elsewhere in the port.

## Object $3E — prison/capsule
Native file:
- `scripts/objects/prison_capsule_object.gd`

Relevant source:
- Object `$3E` Prison Capsule routines
- Object `$28` animal-from-prison behavior

The GHZ3 object placement has both the body and switch records. The native switch waits for boss status, locks control/freezes time, explodes, sets boss status 2, releases staggered animals, waits for animal completion, then calls the existing act-complete tally path.

## Object $28 prison animals
Native file:
- `scripts/effects/animal_object.gd`

`setup_prison()` adds the per-animal release delay before handing the animal back to the existing GHZ rabbit/Flicky movement implementation.
