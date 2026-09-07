# Phase 30 validation report

Target runtime: **Godot 4.6.3**.

The packaging environment does not contain the Godot executable, so final parser/runtime behavior must still be confirmed in the user's Godot 4.6.3 editor. Static/source validation is performed before packaging.

## Reported issue checks

1. **LZ routing gate**
   - `LevelCatalog` explicitly sets LZ `full_gameplay_support = true` so normal/debug routing can enter Labyrinth.
   - Debug text labels this state `LZ PLAYTEST` to avoid implying that all LZ-specific objects are complete.

2. **LZ1 door near the reported `(4393,1516)` area**
   - source switch record `$10D0,$5F8` subtype `$85` and door `$1118,$5A0` subtype `$E5` were verified in `lz1 (REV01).bin`;
   - the `$1080` dynamic-water threshold still changes the source water target;
   - switch-5 bit 7 is now withheld until Sonic crosses X `$1118`, preventing premature close while approaching the door.

3. **Phase 29 water fidelity retained**
   - REV01 background ripple code is not replaced;
   - exact underwater palette split remains active;
   - existing exact LZ door and spike-chain source assets remain retained.

## Phase 30 source checks

- Object `$1B` water surface uses source art/mapping, `$20` frame interlace, `$FFE0` camera wrap, and source frame cadence.
- Object `$08` splash uses exact three source mappings and five-tick animation cadence.
- Object `$64` is routed natively; placement counts are LZ1=16, LZ2=15, LZ3=21.
- Bubble maker sequence matches `Bub_BblTypes` and source delay ranges.
- Large bubble collection uses the source range and 35-frame Get-Air control lock.
- Air state begins at 30 seconds and decrements every 60 frames.
- Countdown-number appear/rise/screen-fixed/flash stages follow the source routine ordering.
- Drowning freezes camera/object interaction and changes to death after 120 sink frames while preserving downward velocity.

## Exact source binary checks

The project copies are required to compare byte-for-byte against the user-supplied disassembly for:

- `LZ Water Surface.nem`
- `LZ Water & Splashes.nem`
- `LZ Bubbles & Countdown.nem`
- `LZ Vertical Door.nem`
- `LZ Horizontal Door.nem`
- `LZ Spiked Ball & Chain.nem`
- `Labyrinth Zone Underwater.bin`
- `Sonic - LZ Underwater.bin`

## Runtime test checklist

1. Enter LZ through the normal/debug level route without manually editing the catalog flag.
2. In LZ1, press switch 5 near `$10D0,$5F8`. The `$1118,$5A0` vertical door should open and stay open while Sonic crosses it, then close behind him.
3. Verify the water surface sits on the moving dynamic waterline and visibly uses the alternating/interlaced source pattern.
4. Enter/leave water with non-zero Y velocity and check the source splash animation.
5. Observe placed bubble makers. They should emit varied small/medium groups and periodically a large inhalable bubble.
6. Collect a large bubble: Sonic should stop, use the Get-Air frame for about 35 frames, and reset the air timer.
7. Remain underwater: countdown numbers should begin late in the 30-second air period; after air expires, Sonic should enter the drowning pose, sink for about two seconds with a frozen camera, then die.
8. F4 debug info shows the native air value beside the water-state values.

## Known Phase 30 boundary

The original warning ding, drowning music, bubble collection SFX and splash SFX are not yet connected because the native project does not currently expose the original sound-driver/SFX path. No substitute sounds are fabricated.

## Static package-integrity results

- GDScript files: **75**
- Named native classes: **72**
- PNG assets: **535**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough structural delimiter warnings: **0**
- LZ Object `$64` placement counts: **16 / 15 / 21** for LZ1/LZ2/LZ3
- Source Nemesis tile counts verified from headers: water surface **16**, water/splash **144**, bubbles/countdown **116**; every Phase 30 mapping tile range stays within its source stream.

Godot itself is not installed in the packaging environment, so the user's Godot 4.6.3 runtime remains the final parser/behavioral validation.
