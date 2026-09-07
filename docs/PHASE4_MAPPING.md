# Phase 4 source mapping

## Camera correction

| Native code | Original source | Responsibility |
|---|---|---|
| `scripts/camera/sonic_camera.gd::_scroll_horiz` | `_inc/ScrollHoriz & ScrollVertical.asm` | Correct `MoveScreenHoriz` right sweet-zone subtraction and 16 px cap |

## Player damage / death

| Native code | Original source | Responsibility |
|---|---|---|
| `SonicPlayer.apply_hazard_hit` | `_incObj/Sonic ReactToItem.asm` `React_ChkHurt`, `HurtSonic` | shield/ring/zero-ring decision and knockback |
| `SonicPlayer._mode_hurt` | `_incObj/01 Sonic.asm` `Sonic_Hurt`, `Sonic_HurtStop` | hurt motion/gravity/landing |
| `SonicPlayer.kill`, `_mode_dead` | `KillSonic`, `Sonic_Death` | death state and launch |
| `main.gd::_restart_after_death` | `Sonic_HandleDeath` | below-camera death completion / restart |
| `sonic_visual.gd` | `_anim/Sonic.asm` | `fr_Injury=$55`, `fr_Death=$4D`, flashing |

## Ring loss

`scripts/objects/ring_loss_object.gd` maps to Object `$37` in `_incObj/25, 37 Rings.asm`.

The embedded 32 velocity pairs are the exact initial values produced by the original `rloss_spread=$288`, `CalcSine`, angle fanning, mirrored X pairs, and second lower-speed ring tier.

## Monitor power-ups

`SonicPlayer.grant_power_up` maps to the reward checks in `_incObj/26, 2E Monitors and Power-Ups.asm`:

- subtype 1: Eggman damage (`FixBugs` behavior)
- subtype 2: extra life
- subtype 3: speed shoes
- subtype 4: shield
- subtype 5: invincibility
- subtype 6: +10 rings

## Badnik reaction

`badnik_object.gd` now uses the gameplay side of `React_Enemy` / `React_BadnikHit` from `_incObj/Sonic ReactToItem.asm`: attack-vs-hurt decision, badnik score chain and vertical bounce/slow response.

Individual Crabmeat/Buzz/Chopper/Motobug/Newtron AI routines are still only partially ported from their own object files.

## Lamppost

`scripts/objects/lamppost_object.gd` maps to `_incObj/79 Lamppost.asm`:

- `Lamp_Blue` interaction range
- ordered subtype/checkpoint selection
- `Lamp_Twirl` visual orbit
- position subset of `Lamp_StoreInfo` / `Lamp_LoadInfo`

## Signpost

`scripts/objects/signpost_object.gd` maps to `_incObj/0D Signpost.asm` and `_anim/Signpost.asm`:

- `Sign_Touch`
- 3-cycle `Sign_Spin`
- Sonic sign frame
- grounded forced-right behavior from `Sign_SonicRun`
- GHZ1 completion boundary exposure

Full `GotThroughAct` bonus/tally UI is pending.
