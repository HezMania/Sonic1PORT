# Phase 5 source mapping

## Player visual-state correction

| Native code | Original source/behavior | Responsibility |
|---|---|---|
| `scripts/player/sonic_visual.gd` | `_incObj/01 Sonic.asm`, `_anim/Sonic.asm` | Treat `rolling` as the ball/jump visual state rather than treating every `in_air` state as rolling |

The physics state already distinguished a jump from simply losing floor contact. Phase 5 makes the renderer obey that distinction.

## Monitor

| Native code | Original source | Responsibility |
|---|---|---|
| `scripts/objects/monitor_object.gd` | `_incObj/26, 2E Monitors and Power-Ups.asm` | `Mon_SolidSides`, `React_Monitor`, monitor fall kick, animation |
| `assets/objects/monitor/*.png` | monitor Nemesis art + mappings | Reconstructed mapping frames with Genesis sprite-piece priority preserved |

`Ani_Monitor` is represented as the original static `0,1,2` sequence and subtype pattern `0,icon,icon,1,icon,icon,2,icon,icon`, with delay byte 1 interpreted as two ticks per listed frame.

## Dynamic GHZ1 camera boundary

| Native code | Original source | Responsibility |
|---|---|---|
| `scripts/camera/sonic_camera.gd::_dynamic_level_events_ghz1` | `_inc/DynamicLevelEvents.asm`, `DLE_GHZ1` | `$300 -> $400` lower-bound target after camera X `$1780` and gradual boundary movement |
| `SonicCamera.update` ordering | `DeformLayers` | Horizontal scroll -> vertical scroll -> DynamicLevelEvents |

The Phase 4 `MoveScreenHoriz` right sweet-zone correction remains unchanged.

## Collapsing ledge

`scripts/objects/collapsing_ledge_object.gd` maps to Object `$1A` in `_incObj/1A, 53 Collapsing Ledges and Floors.asm`:

- `Ledge_SlopeData` high-level surface profile
- seven-frame pre-collapse delay
- 25 fragment pieces
- original fragment delay table
- gravity-driven fragment fall

The generated piece PNGs come from the supplied GHZ art/mapping data rather than screenshots.

## Giant ring / special-stage request

`scripts/objects/giant_ring_object.gd` maps to:

- Object `$4B` giant ring
- the essential Object `$7C` giant-ring flash sequence

Implemented behavior includes the >=50 ring gate, six-emerald gate, four-frame ring animation, eight-frame flash, Sonic hide/transition lock, and a native `special_stage_requested` handoff. The special-stage game mode itself is not yet implemented.

## Hidden bonuses

`scripts/objects/hidden_bonus_object.gd` maps to Object `$7D`:

- 16x16 proximity trigger
- subtype score values represented as actual score points: 100, 1,000, 10,000
- 120-frame display
- suppression after the giant ring is collected

## Waterfall trigger

`scripts/objects/waterfall_trigger_object.gd` maps to Object `$49` and preserves its 64-frame pulse timing. Actual SFX playback awaits the native audio phase.

## End-of-act tally groundwork

`SonicObjectManager.begin_act_complete` and `_tick_end_tally` map to the score-side behavior of the original end-of-act sequence:

- original time-bonus bands converted to actual displayed score values
- ring bonus = rings x 100
- bonus pools counted into score

Final card rendering/timing is not yet a full port.
