# Sonic 1 PC Native Port — Phase 77

**Current phase:** Native Sonic 2 128×128 Chunk Mode

Phase 77 replaces the experimental Sonic 2 test levels' generated 256×256 compatibility chunks with their native 128×128 Map128 hierarchy. Emerald Hill and Simon Wai Hidden Palace now address the original 8×8 block chunks directly, including full-byte chunk IDs through `$FF`, while all Sonic 1 levels remain on the established 256×256 Map256 path.

See `PHASE77_S2_NATIVE_128_CHUNKS.md` and `PHASE77_VALIDATION_RESULTS.txt`.

---

# Sonic 1 PC Native Port — Phase 65

**Current phase:** GHZ Bridge Fidelity

Phase 65 returns to Sonic 1 mainline fidelity after the isolated Sonic 2 import proof. Object `$11` now uses the retail `Bri_Data_Align` / `Bri_Data_Y_Max` bridge-bending math instead of the early smooth approximation. All confirmed Phase 62-64 systems remain frozen. The Simon Wai prototype upload is retained for a future Hidden Palace import test.

See `PHASE65_GHZ_BRIDGE_FIDELITY.md` and `PHASE65_VALIDATION_RESULTS.txt`.

---

# Sonic 1 PC Native Port — Phase 64

**Current phase:** Experimental Sonic 2 level-import proof

Phase 64 adds an opt-in **H-key Emerald Hill Act 1** test converted mechanically from the user-supplied Sonic 2 retail disassembly. The test proves Sonic 2 final-format terrain, palette, Primary/Secondary collision indices, and 128x128 chunk data can run through the existing Sonic1PC renderer/sensor architecture. Hidden Palace terrain is not fabricated because the supplied retail disassembly does not contain its deleted core terrain files.

See `PHASE64_SONIC2_IMPORT_PROOF.md` and `PHASE64_VALIDATION_RESULTS.txt`.

---

# Sonic 1 PC Native Port — Phase 63

**Current phase:** Scrap Brain Animated Background

Phase 63 restores the original SBZ pollution/smoke `AnimateLevelGfx` routine using the retained source art and a compact periodic background texture, while preserving the confirmed Phase 62 gameplay baseline.

See `PHASE63_SBZ_ANIMATED_BACKGROUND.md` and `PHASE63_VALIDATION_RESULTS.txt`.

---

# Phase 62 — End-Sequence & Interaction Fidelity

Phase 62 builds on the accepted Phase 61 baseline. It defers giant-ring Special Stage entry until the Object $3A results card/tally has completed, restores the Monitor ReactToItem-versus-SolidObject edge behavior, and restores Object $20's ObjFloorDist angle-bit snap for Ball Hog cannonballs. The reported first-run SEGA-screen slowdown is tracked but intentionally deferred for isolated startup profiling.

# Phase 61 — Scrap Brain Zone Corrections

Phase 61 starts from the runtime-confirmed Phase 60 / Phase 59 Hotfix 1 baseline and fixes the SBZ2 teleporter wrap regression, restores Object `$1E` Ball Hog + `$20` cannonballs from source data, and completes Object `$52`'s SBZ short/red moving-platform branches including subtype `$09/$0A` fast-slide behavior. The accepted results cards, animated-GFX optimization, fades, title cards, dual-path loops, player physics, and music synthesis core are frozen. See `PHASE61_SBZ_CORRECTIONS.md` and `PHASE61_VALIDATION_RESULTS.txt`.

# Phase 60 — End-of-Act Results Card Fidelity

Phase 60 starts from the runtime-confirmed Phase 59 Hotfix 1 baseline and replaces the placeholder Godot-font result screen with Sonic 1's source Object `$3A`: seven independently moving source-art elements, live source HUD digits, source tally timing/SFX, and the special SBZ2 card move-out before Final Zone corridor progression. The music engine, MZ animation/performance work, fades, title cards, loops, and player physics are frozen. See `PHASE60_RESULTS_CARD_FIDELITY.md` and `PHASE60_VALIDATION_RESULTS.txt`.

# Phase 59 Hotfix 1 — MZ Animated-GFX Performance

Phase 59 animation fidelity retained; Marble Zone's 30 Hz magma refresh now updates only camera-local chunk types and groups the source animation at 16x16 block level. See `PHASE59_HOTFIX1_PERFORMANCE.md`.

# Sonic 1 Native Godot — Phase 59

Phase 59 starts from the user-confirmed Phase 58 Hotfix 1 baseline and restores the source `AnimateLevelGfx` behavior for **GHZ and MZ**: GHZ waterfall/large flower/small flower tiles plus MZ lava surface, oscillator-driven magma, and background torches. The renderer patches only animated 8x8 placements inside shared cached chunk textures instead of rebuilding the level. See `PHASE59_ANIMATED_LEVEL_GFX.md` and `PHASE59_VALIDATION_RESULTS.txt`.

## Phase 58 Hotfix 1 — Title-card priority confirmed

Phase 58 restored the reliable pre-Phase-57 fade path and added source Object `$34` level title cards. Hotfix 1 corrected the Genesis sprite/SAT overlap ordering so the level/ZONE/ACT text draws above the blue oval; runtime testing confirmed the title cards now work correctly.

## Phase 57 note

The Phase 57 framebuffer/BackBufferCopy fade experiment was rejected after runtime testing produced blank white screens. Phase 58 restored the older reliable stepped overlay fade implementation, which is the frozen fade baseline going forward.

# Sonic 1 Native Godot — Phase 57

Phase 57 restores Sonic 1's source-order **3-bit Genesis palette fades** using an explicit Godot `BackBufferCopy`, replacing Phase 51's reliable-but-uniform alpha overlay without reintroducing the earlier GL compatibility screen-copy failure. Fade timing and color equations remain source-derived; accepted Phase 56 loops and the approved audio system are frozen. See `PHASE57_PALETTE_FIDELITY.md` and `PHASE57_VALIDATION_RESULTS.txt`.

## Phase 56 — Dual Collision Paths

Phase 56 replaces Phase 55's non-working single-path loop flag with a Sonic 2-inspired **dual logical collision-path + PathSwitcher** architecture. Sonic 1's own paired Map256 chunks provide the alternate GHZ/SLZ loop surfaces; all existing Genesis floor/wall/ceiling sensors now query the player-selected Primary or Secondary path. The accepted audio system remains frozen. See `PHASE56_DUAL_COLLISION_PATHS.md` and `PHASE56_VALIDATION_RESULTS.txt`.

## Phase 55 — Loop state-machine experiment

Phase 55 reproduced the retail GHZ/SLZ `Sonic_Loops` decision state machine, including SLZ `$AA/$B4`, but runtime testing showed that changing state without exposing a complete second collision surface was insufficient. Phase 56 supersedes its `behind_loop` architecture while preserving the independent GHZ `$1F/$20` forced-roll behavior.

# Phase 54 — SFX Fidelity & Completion

Phase 54 starts from the approved Phase 53 Hotfix 3 music baseline and freezes the music core. Clean is now the startup default, **U** remains the live Clean/Authentic toggle, and GHZ Waterfall `$D0` is restored as a source-derived 44.1 kHz PCM special SFX with source-style lower priority than normal FM4 SFX. This removes the alias-prone live `$D0` renderer from normal gameplay without increasing the per-sample music workload. See `PHASE54_SFX_FIDELITY.md` and `PHASE54_VALIDATION.md`.

# Phase 53 Hotfix 3 — YM OP1 pipeline test

This test hotfix keeps Hotfix 2's unfiltered **Clean** presentation, temporarily muted waterfall SFX, and **U** mode toggle, while adding one hardware-motivated music-only correction: downstream FM algorithm routing now uses the previous OP1 sample instead of the just-computed OP1 sample. See `PHASE53_HOTFIX3.md` and `PHASE53_HOTFIX3_VALIDATION.md`.

# Phase 53 Hotfix 2 — Clean-mode reference refinement

This test hotfix keeps the waterfall SFX temporarily muted, uses **U** for live Authentic/Clean switching, and opens Clean mode fully by bypassing its synth low-pass (`alpha 1.00`). Authentic remains unchanged. See `PHASE53_HOTFIX2.md` and `PHASE53_HOTFIX2_VALIDATION.md`.

# Phase 53 — Native Audio Fidelity + Authentic/Clean Modes

Phase 53 is the final planned native-audio refinement on top of Phase 52 Hotfix 10. It preserves the source-driven Sonic 1 SMPS sequencer and optimized FM renderer, corrects the remaining PSG pitch/noise/attenuation path, raises FM envelope resolution, and adds live-selectable **Authentic** and **Clean** output modes. **U** toggles the mode without restarting the song; `project.godot` selects the startup default. See `PHASE53_AUDIO_FIDELITY.md` and `PHASE53_VALIDATION.md`.

# Phase 52 Hotfix 3 — FM/PSG Voice Fidelity
## Phase 52 Hotfix 5

Phase 52 Hotfix 5 corrects the remaining high-level SMPS note/modulation timing before the project moves to a hybrid/pre-rendered SFX fallback if necessary. It matches the source duration-first track-update order, preserves note-fill/modulation state across `smpsNoAttack`, replaces the sine/cents modulation approximation with Sonic 1's stepped triangle accumulator, and applies PSG modulation in the SN76489 divisor domain (fixing the physical direction of Jump's `$F8` modulation). The synth-only filter is slightly stronger; DAC is unchanged. See `PHASE52_HOTFIX5.md`.


This package supersedes Phase 52 Hotfix 2 after a second direct Godot-vs-ClownMDEmu recording comparison. It keeps the restored DAC percussion and hardware-channel SFX takeover, then corrects the remaining source-translation errors in the approximate FM/PSG backend: YM2612 algorithms 1–3, four independent operator envelopes, per-operator detune, the separate Sonic 1 PSG pitch table, and signed `smpsModSet` deltas. See `PHASE52_HOTFIX3.md` and `PHASE52_HOTFIX3_VALIDATION.md`.

# Phase 52 — Native SMPS Audio Foundation

Phase 52 starts from the user-tested Phase 51 Hotfix 1 tree and restores a native source-driven Sonic 1 audio path. All 19 retail music definitions and all 49 SFX definitions are mechanically compiled from the supplied `s1disasm-AS` SMPS ASM and executed on a 60 Hz Godot audio sequencer. FM-style, PSG square/noise, and original DAC sample rendering are included, with game-mode music and high-value gameplay SFX call sites wired.

The sequencing/voice/sample data are source-driven, but the Phase 52 oscillator backend is **not yet a cycle-accurate YM2612/SN76489 emulator**. See `PHASE52_MAPPING.md` for the exact boundary and `PHASE52_VALIDATION.md` for validation/results.

# Phase 51 Hotfix 1 — Continue/Fade/Special Stage Background Corrections

This package supersedes the original Phase 51 build after runtime testing. It fixes the repeating Continue hand-tap loop, replaces the unreliable screen-texture palette-fade presentation with a guaranteed 22-step full-screen overlay, and replaces the simplified Special Stage background with source-structured repeating bird/fish plus bubble/cloud planes and scanline-band scrolling. See `PHASE51_HOTFIX1.md` and `PHASE51_HOTFIX1_VALIDATION.md`.

# Phase 50 — Animation Corrections & Genesis Palette Fade Fidelity

Phase 50 starts from the user-tested Phase 49 tree. It corrects Special Stage left/right facing and the Continue-screen get-up/walk/run animation handoff, then adds source-style 3-bit Genesis channel-stepped black/white fades to the startup/title, Special Stage, Continue, and Ending presentation paths.

The full-screen fade equations were exhaustively compared against the original 68000 palette routines for all 512 Genesis RGB colors across all 22 fade positions. Partial-range CRAM-buffer emulation remains a later fidelity item.

Debug shortcuts remain `0 = Continue`, `1–8 = zones/ending`, and `9 = Special Stage 1`. See `PHASE50_MAPPING.md` and `PHASE50_VALIDATION.md`.

# Phase 49 — Special Stage Jump Fidelity & Continue Flow

Phase 49 starts from the user-tested Phase 48 tree. It corrects Special Stage wall-jump contact at rotated angles and adds the retail persistent Continue flow: 50-ring Continue awards, GAME OVER routing, the source Continue screen, countdown/mini-Sonics, Continue consumption, and same-act restart.

Debug shortcuts now include `0 = Continue screen` and retain `1–8` zone/ending warps plus `9 = Special Stage 1`. See `PHASE49_MAPPING.md` and `PHASE49_VALIDATION.md`.

# Phase 48 — Native Special Stages

Phase 48 adds all six retail Sonic 1 Special Stages as a dedicated native Godot runtime, normal giant-ring entry/return, exact fourth title attract-demo input, Special Stage block interactions, Chaos Emerald progression, results/tally flow, and debug `9 = Special Stage 1`. See `PHASE48_MAPPING.md` and `PHASE48_VALIDATION.md`.

# Sonic1PC — Startup / Title Phase 47 Hotfix 1

Phase 47 is a standalone Godot 4.6.3 project built from the user-tested Phase 46 Credits build. The supplied `s1disasm-AS` tree remains the authoritative source.

This phase restores the retail startup loop:

**SEGA → SONIC TEAM PRESENTS → Title Screen → GHZ1 / attract demos → SEGA**

It also changes the completed credits sequence to return to the SEGA screen instead of restarting directly in GHZ1.

## Hotfix 1

This package supersedes the initial Phase 47 ZIP after runtime testing. It corrects the SEGA palette reveal/timing presentation, restores `SONIC TEAM PRESENTS` frame 10 instead of `TRY AGAIN`, fixes Title Sonic mapping-piece overlap priority, reproduces Object `$0F`'s Genesis sprite-line masking so the banner covers Sonic, and corrects the source pop-up handoff at Y=94 before the 8-pixel rise steps.

## Debug zone warps

- `1` — GHZ Act 1
- `2` — MZ Act 1
- `3` — SYZ Act 1
- `4` — LZ Act 1
- `5` — SLZ Act 1
- `6` — SBZ Act 1
- `7` — Final Zone
- `8` — Good Ending

`F6/F7` act stepping remains available after a normal-zone warp.

## Phase 47 highlights

- original REV01 SEGA logo Nemesis art and Enigma mappings
- original SEGA palette data and exact source `sega.wav` PCM
- source-derived 76-frame SEGA palette-sequence timing and 30-frame post-chant wait
- SONIC TEAM PRESENTS using the source credits-font mapping
- original title emblem, big Sonic, PRESS START, TM art/mappings and animation timing
- title-specific palette and four six-frame water-cycle phases
- source-style 2 px/frame title-background camera movement through the existing GHZ deformation renderer
- Enter starts a fresh GHZ Act 1 game
- first three retail attract demos: GHZ1, MZ1, SYZ1 using the exact recorded source controller streams
- final END / TRY AGAIN now loops back to the SEGA startup screen
- all Phase 46 number-key debug warps preserved

## Deliberate Phase 47 boundary

The retail fourth attract demo is **Special Stage 1**. Native Special Stage gameplay does not exist in the project yet, so that slot safely cycles back through SEGA/title instead of loading fabricated gameplay. This makes Special Stage the natural Phase 48 target.

Original SMPS music/SFX and exact per-channel CRAM fade stepping remain separate global fidelity work. The SEGA PCM sample itself is included and played in this phase.

See `PHASE47_MAPPING.md` for source-to-Godot details and `PHASE47_VALIDATION.md` for the static/source validation inventory and runtime checklist.

## Phase 52 Hotfix 2

Phase 52 Hotfix 2 corrects the remaining first-pass native-audio performance/mix issues. SFX now take over fixed FM/PSG hardware slots instead of being added as unlimited extra synth channels, rapid ring sounds no longer stack FM instances, the original Phase 52 DAC gain is restored, and the FM/PSG renderer uses interpolated lookup synthesis plus a light synth-only low-pass to reduce the harsh high-frequency character observed in the Godot capture. See `PHASE52_HOTFIX2.md` and `PHASE52_HOTFIX2_VALIDATION.md`.

## Phase 52 Hotfix 4

Phase 52 Hotfix 4 addresses the Hotfix 3 performance regression while retaining its source-correct FM/PSG fixes. Independent FM operator envelopes now advance on a bounded 240 Hz clock instead of once per 22.05 kHz output sample, and feedback/modulation/render amplitudes are cached outside the sample loop. See `PHASE52_HOTFIX4.md` and `PHASE52_HOTFIX4_VALIDATION.md`.
## Phase 52 Hotfix 6

Phase 52 Hotfix 6 is a music-only FM fidelity pass. It preserves the runtime-confirmed Hotfix 5 Jump/Skid/DAC/SFX path while moving music FM notes to the source `FMFrequencies` F-number/block table, applying per-operator YM rate scaling, replacing the arbitrary music D2/RR timing with YM-shaped attenuation rates, using the hardware detune lookup, and summing/saturating parallel carriers rather than averaging them. The user-provided PCM SFX archive is retained only as a fallback and is not activated in this build. See `PHASE52_HOTFIX6.md` and `PHASE52_HOTFIX6_VALIDATION.md`.


## Phase 52 Hotfix 7

Hotfix 7 corrects the remaining music FM voice-operator ordering mismatch and makes normal level music initialization deterministic.

The source `smpsVc*` voice macros are not stored in the same operator order expected by the runtime YM algorithm. Music now reverses the macro operator arrays before applying multiplier, detune, TL and envelope/rate fields to the four hardware algorithm operators. Track volume is also applied to carrier TL, as the Sonic 1 driver does, instead of as a final channel gain.

Normal level loads explicitly restart music and reset software-only audio-render phase/filter state, addressing the report that a zone could sound different depending on the previously loaded level.

The runtime-confirmed Jump/Skid SFX path and original DAC drums are intentionally unchanged. `Sonic1SFX.zip` remains an unused fallback archive.

## Phase 52 Hotfix 8

Hotfix 8 moves gameplay SFX to the user-supplied pre-rendered PCM bank while keeping all music source-driven from the original SMPS data. The 48 `$A0–$CF` WAVs are loaded on demand and reuse a fixed six-player pool; their original SMPS hardware-slot masks still suppress the corresponding music channels while the effect plays. `$D0` Waterfall remains the live-source fallback because it is not present in the supplied archive.

The music renderer receives one more hardware-domain fidelity pass without adding envelope CPU cost: operator-to-operator phase modulation now uses the YM2612's 14-bit-output/10-bit-phase relationship, OP1 feedback uses the corresponding hardware-scaled depth, and FM panning is hard left/right rather than synthetic crossfeed. Hotfix 7's deterministic level-music initialization, operator order, carrier TL volume handling, source F-number table, rate scaling, detune, DAC path, and bounded 240 Hz envelope clock are retained.

See `PHASE52_HOTFIX8.md` and `PHASE52_HOTFIX8_VALIDATION.md`.

## Phase 52 Hotfix 9

Hotfix 9 is a performance-only optimization of the Hotfix 8 source-driven music renderer. It keeps the existing SMPS/FM/DAC/PCM-SFX behavior while flattening the 22.05 kHz GDScript FM hot loop: 16K direct sine lookup, cached modulation-adjusted oscillator steps, inlined four-operator routing, and integer FM/PSG/DAC render dispatch. See `PHASE52_HOTFIX9.md` and `PHASE52_HOTFIX9_VALIDATION.md`.


## Phase 52 Hotfix 10

Hotfix 10 is the final narrow source-driven music correction after Hotfix 9 eliminated the gameplay slowdown. It fixes `smpsAlterNote`/`cfDetune` as an assignment instead of an accumulated delta, applies music detune/modulation to the complete packed YM frequency word, corrects the music operator-detune phase-step basis, and permanently folds in the reported Godot 4.6.3 `:=` parser compatibility edits in `main.gd` and `special_stage_art.gd`. Hotfix 9's fast FM renderer, PCM SFX and DAC paths are preserved. See `PHASE52_HOTFIX10.md` and `PHASE52_HOTFIX10_VALIDATION.md`.

## Phase 58 — Presentation Recovery + Level Title Cards

- Phase 57 framebuffer fade experiment rolled back to the stable stepped overlay path after the GL compatibility white-screen regression.
- Added source-rendered Object $34 level title cards from `Title Cards.nem`, Sonic palette, retail mappings, `Card_ConData`, and original move/hold speeds.
- Level begins are blocked during card ingress/fade, then gameplay starts while the card holds and exits.
- Phase 56 dual-path loops and the approved native audio stack are unchanged.

## Phase 58 Hotfix 1
- Corrected Object $34 title-card overlap priority so the level-name / ZONE / ACT text renders in front of the blue oval, matching the Mega Drive sprite ordering.
- No fade, gameplay, collision, or audio changes.

## Phase 66 — GHZ Edge Wall + SEGA Cold-Start Performance

- Object `$44` now uses its original dedicated `EdgeWall_SolidWall` collision semantics. Sonic's centre is tested directly against the source 38×80 envelope instead of expanding the wall by Sonic's horizontal radius, fixing the early pushing/visible gap at GHZ fake walls.
- The first SEGA screen no longer builds 77 full 320×224 RGBA textures during its palette cycle. A static palette-index image is built once and a 64-color CRAM texture is updated per VBlank, preserving all 77 visual states while removing the cold-cache per-frame compositor cost.
- Phase 65 bridge fidelity, Phase 64 Sonic 2 EHZ proof, Phase 63 SBZ smoke, Phase 62 interaction fixes, title/results cards, fades, loops and audio remain unchanged.

See `PHASE66_EDGE_WALL_STARTUP.md` and `PHASE66_VALIDATION_RESULTS.txt`.

## Phase 67 — Special Stage Results Fidelity
Replaces the temporary Special Stage result labels with source-authored Objects $7E/$7F using the original title/HUD/Continue/result-emerald art and Special Stage Results palette. Restores independent card motion, exact ring-bonus waits/tally sounds, Got Through music, optional Continue mini-Sonic animation, exit SFX, and the original v_emldlist-style emerald color order/flashing display. See `PHASE67_SPECIAL_STAGE_RESULTS.md`.

## Phase 68 — Retail placed-object completion

Object `$2A` (SBZ small automatic vertical door) is now source-driven using the original Nemesis art, nine mapping frames, side-sensitive 64px trigger logic and closed-door SolidObject dimensions. This closes the last explicit-dispatch gap among object IDs that actually appear in the shipped Sonic 1 top-level level placement binaries. See `PHASE68_PLACED_OBJECT_COMPLETION.md` and `PHASE68_VALIDATION_RESULTS.txt`.

## Phase 69 - MZ Push-Block Geysers + Input Map Controls

Restores the dynamically spawned MZ2/MZ3 lava geysers that Object $33 creates
at its source hard-coded lava-route positions and the `-$580` block launch
behavior. Also adopts the user-supplied ProjectSettings Input Map as the
standing controller interface: Z=A, X=B, Space=C, Enter=Start, F10=Debug, while
retaining the supplied joypad bindings. Only the `[input]` section was carried
from the user's edited Phase 68 archive; editor-generated changes were omitted.

## Phase 70 - MZ geyser visual fidelity

Phase 70 keeps the confirmed Phase 69 geyser physics and Input Map unchanged,
but restores Object $4D subtype $00's actual `.bubble4` moving-top frames
($11/$12) and the Object $4C Tile_Prio foreground relationship. The rising
lava column now renders behind the bubbling crest/surface graphics instead of
using the subtype-$01 lavafall end cap.

## Phase 71 — MZ Background Deformation Fidelity
Restores REV01 `Deform_MZ` 16-pixel H-scroll bands: five source cloud gradients,
1/4-speed mountains, 1/2-speed bushes/buildings, and 3/4-speed dungeon interior,
with the original Y=512 / camera-Y=456 band-selection behavior. MZ animated
background chunk textures remain live, and the Sonic 2 proof path is unchanged.

## Phase 72 — Retail Level Select + Live Palette Cycles

Restores the REV01 US title-screen Up/Down/Left/Right level-select cheat and the
21-row source Level Select/Sound Test menu (hold A and press Start after the
Ring SFX). Adds the retail gameplay `PaletteCycle.asm` routines for GHZ, LZ,
SLZ, SYZ and SBZ/FZ, including live object palette refreshes and a compact
palette-indexed GHZ background path. MZ correctly remains without a retail
palette cycle. The Phase 69 Input Map and all confirmed Phase 70/71 gameplay
systems remain intact. See `PHASE72_LEVEL_SELECT_PALETTE_CYCLES.md`.

## Phase 72 Hotfix 1 — Palette Performance + Title Recovery

Phase 72's source palette-cycle timing/data is retained, but cycling-zone terrain now keeps Genesis palette indices and updates tiny 64-entry palette textures instead of repeatedly rebuilding/uploading RGBA terrain. This specifically removes the heavy LZ palette-cycle path. The title screen also clears the gameplay palette-index shader before applying its finished RGBA background frames, fixing the Phase 72 title-background corruption. See `PHASE72_HOTFIX1_PALETTE_PERFORMANCE_TITLE.md`.

## Phase 73 — Ending Emerald History Fidelity

The bad-ending TRY AGAIN screen now uses the actual collected Chaos Emerald color history retained since Phase 67. Missing emeralds are selected exactly like Object `$8C` / `TCha_LoadEmeralds` instead of using the old first-N-color placeholder. The juggle orbit also now uses the original `CalcSine` integer path at radius `$1C` instead of floating-point sin/cos. Phase 72 Hotfix 1 palette performance, Level Select, and the Phase 69 Input Map are unchanged.

## Phase 74 — Moving Solid Stability + Title Timing

Restores the title background's source dummy-player `$0050` seed so scrolling begins on retail title tick 42 instead of the previous tick-81 approximation. Direct `PlatformObject`/`ExitPlatform` support now uses Sonic's center X with an exclusive right edge, moving-object support must be reaffirmed during each object pass, and integer object carry/collision corrections preserve Sonic's 16.16 subpixel words instead of zeroing them. The Phase 72 Hotfix 1 palette renderer and Phase 69 Input Map remain unchanged. See `PHASE74_MOVING_SOLID_STABILITY_TITLE_TIMING.md`.

## Phase 74 Hotfix 1 — Moving Platform Exit Order

Corrects the remaining moving-platform detach/floating regression by matching the
source `Sonic_AnglePos -> ExitPlatform -> platform move -> MvSonicOnPtfm` ownership
order. Sonic no longer gets an extra radius-expanded support test inside
`Sonic_AnglePos`; jump retains the platform bit until the object's later exit
routine; and an exited owner cannot re-capture Sonic in the same object pass.
Only `scripts/player/sonic_player.gd` changes at runtime. See
`PHASE74_HOTFIX1_MOVING_PLATFORM_EXIT_ORDER.md`.

## Phase 75 — Player Motion + Idle Fidelity

Restores Sonic's retail `SonAni_Wait` sequence after 4.8 seconds of idle time,
removes the non-source +/-`$C00` rolling-inertia clamp that reduced downhill
S-pipe momentum, and separates 16.16 physics position from Genesis integer-word
sprite display position to eliminate visible subpixel creep while pushing. The
Phase 74 Hotfix 1 platform-exit fix, Phase 72 Hotfix 1 palette renderer, and
Phase 69 Input Map are unchanged. See `PHASE75_PLAYER_MOTION_IDLE_FIDELITY.md`.
