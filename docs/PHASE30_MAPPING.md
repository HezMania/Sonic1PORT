# Phase 30 source mapping — Labyrinth water gameplay / progression-door correction

Target runtime: **Godot 4.6.3**. Phase 30 is built directly on the user-tested Phase 29 project and preserves the confirmed-good REV01 LZ background ripple and underwater palette split.

## LZ routing / runtime testability

`LevelCatalog` now writes `full_gameplay_support = true` for LZ. In this project that field is also the gate used by debug-zone cycling and normal zone handoff, so leaving it false prevented LZ from being entered at all. For LZ, Phase 30 treats the flag as a **playtest/progression routing flag**, not as a claim that every Labyrinth object family or the Act 3 boss is complete.

## LZ1 switch-5 progression door — Object $56

Source placement records in `objpos/lz1 (REV01).bin`:

- switch: `$10D0,$5F8`, Object `$32`, subtype `$85`;
- door: `$1118,$5A0`, Object `$56`, subtype `$E5`.

Relevant source:

- `_incObj/56 SYZ, SLZ Floating Blocks and LZ Doors.asm`
- `_inc/LZWaterFeatures.asm` (`DynWater_LZ1`)

The normal switch bit opens the door at 2 px/frame. Once fully open, the source door remains in its open/close-wait routine and closes only when the alternate bit-7 switch state is asserted. `DynWater_LZ1` writes `$80` to switch 5 after the tunnel camera threshold `$1080`.

The native camera relationship can reach `$1080` while Sonic is still left of the authored `$1118` door. Phase 29 therefore could assert the close bit immediately after the switch opened it. Phase 30 keeps the source `$1080` water event but asserts switch-5 bit 7 only after `player.pixel_x() >= $1118`. The door can therefore open, allow passage, and close behind Sonic rather than in front of him.

## Object $1B — LZ water surface

Source:

- `_incObj/1B LZ Water Surface.asm`
- `_maps/Water Surface.asm`
- `artnem/LZ Water Surface.nem`

Native behavior:

- follows the dynamic `water_surface_y`;
- X wraps to `screen_x & $FFE0`;
- alternates an additional `$20` X offset every frame;
- cycles source frames 0,1,2 with the source 8-tick cadence;
- uses the exact three-piece normal mappings at local X `-$60,-$20,+$20` and Y `-3`;
- source tile bases are 0, 8, then tile 0 X-flipped;
- uses LZ palette line 2 (`Tile_Pal3`).

The original 320px view uses two objects at source X `$60` and `$120`. Wider native viewports continue the same `$C0` spacing dynamically rather than hard-coding only two strips.

## Object $08 — water splash

Source:

- `_incObj/08 LZ Water Splash.asm`
- `_anim/Water Splash.asm`
- `_maps/Water Splash.asm`
- `artnem/LZ Water & Splashes.nem`

The three source mapping frames are rendered from the exact Nemesis stream. A splash follows the current water surface at Sonic's X and advances every five ticks. Sonic creates it on water entry/exit only when the post-transition Y velocity is non-zero, matching `Sonic_Water`.

## Object $64 — air bubble makers / inhalable bubbles

Source:

- `_incObj/64 LZ Air Bubbles.asm`
- `_anim/Bubbles.asm`
- `_maps/Bubbles.asm`
- `artnem/LZ Bubbles & Countdown.nem`

Phase 30 routes placement ID `$64` to a native LZ bubble object. The supplied placement banks contain 16 makers in LZ1, 15 in LZ2, and 21 in LZ3.

Implemented source behavior includes:

- high-bit subtypes are floor bubble makers; low 7 bits are the large-bubble frequency base;
- random groups of 1–6 bubbles use the original `Bub_BblTypes` sequence;
- the source 1/4 large-bubble chance and final-bubble fallback are retained;
- group delays are 0–31 frames and inter-group delays 128–255 frames;
- maker frames `$13,$14,$15` animate at the source cadence;
- small/medium/large form sequences use the original mapping frames;
- floating speed is `-$88` and X wobble uses REV01 `Drown_WobbleData`;
- only a fully formed large bubble becomes inhalable;
- the source Sonic range test is retained (±16 X, bubble Y through Y+16);
- collecting a large bubble restores 30 seconds of air, zeros movement/inertia, enters the Get-Air pose for 35 frames, clears jump/push/roll-jump state and unrolls Sonic when necessary;
- the large bubble uses the source 6,7,8 burst sequence.

## Object $0A — drowning countdown foundation

Source:

- `_incObj/0A LZ Drowning Countdown.asm`
- `_anim/Drowning Countdown.asm`
- `_maps/Bubbles.asm`
- `artnem/LZ Bubbles & Countdown.nem`
- `_incObj/sub ResumeMusic.asm`

Phase 30 adds the source 30-second air state. The controller begins on water entry, decrements once per 60 frames, produces the normal mouth-bubble groups, and begins number bubbles once the source air threshold is reached.

Countdown number behavior follows the source ordering more closely:

- the 7-frame appear sequence forms in place (delay byte 5 = six ticks per frame);
- after appearing, the number rises/wobbles for the source 28-frame `drown_numtime`;
- it becomes screen-fixed for 15 frames;
- it then uses the source blank/full flashing cadence (delay byte 7).

At negative air, Sonic enters the source drowning state: movement/inertia are cleared, object interaction is disabled, the camera is frozen like `f_nobgscroll`, extra bubbles are emitted more rapidly, Sonic sinks with `+$10` Y velocity per frame, and after 120 frames transitions directly to death while retaining the downward drowning velocity.

The source warning/drowning **audio cues are not added in Phase 30**, because the current native project does not yet expose the original sound-driver/SFX path. Gameplay timing and visual state are implemented without fabricating replacement audio.

## Source-asset policy

The new Phase 30 art streams are copied byte-for-byte from the user-supplied `s1disasm-AS(1).zip`:

- `artnem/LZ Water Surface.nem`
- `artnem/LZ Water & Splashes.nem`
- `artnem/LZ Bubbles & Countdown.nem`

No replacement water, splash, bubble, or countdown art is drawn by the native project.

## Still deferred after Phase 30

LZ is available for progression testing, but remaining source families include major pieces such as the pole/flap door, harpoon, Jaws, Burrobot, Orbinaut, LZ blocks/corks, gargoyle/fireballs, conveyors, waterfalls, water slides/wind tunnels, and the LZ3 boss/event path. Those should be completed in subsequent LZ phases rather than approximated.
