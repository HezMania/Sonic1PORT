# Phase 28 validation report

Static/source validation was performed against the Phase 28 project and the supplied `s1disasm-AS.zip`. Godot itself is not installed in the packaging environment, so final parser/runtime behavior remains a Godot 4.6.3 test.

## Source-asset provenance

The following compressed streams in the Phase 28 project compare byte-for-byte equal with the files extracted from the supplied disassembly archive:

- `Boss - Weapons.nem` — 745 bytes — SHA-256 `f5c39a76b6fa7ebfe56c0959c963a8350326e46ee584e42937296fdaa8321c71`
- `LZ Vertical Door.nem` — 161 bytes — SHA-256 `70af1b28015f1a04287c1b6384cf5dad2fd2aa27c4ddc63e80bdf0ec4f013993`
- `LZ Horizontal Door.nem` — 338 bytes — SHA-256 `8bdcc84e27d72b6ee774b76b43e9448421b47cbd7c33880f4b10e338764fdd18`

Generated source-derived PNG checks:

- SYZ boss spike: 16x32 — SHA-256 `4dac5092b47ff51fba818fb5723686a397fbf04738cb43dc0f4335fb7789b77f`
- LZ vertical door: 16x64 — SHA-256 `3a3eec43709bb7b100d088509aeaa053baa00e09f8a9d06ea56ac58c51139cbf`
- LZ horizontal door: 128x32 — SHA-256 `29578f0b820f4c3b3ca684a742f559ef39eb8417dd8ce2e19e8537ecd2df32d7`

The Nemesis/mapping renderer used for these replacements was cross-checked against the earlier source-rendered Marble boss pipe generated from the same `Boss - Weapons` stream and produced zero differing pixels with the known Phase 19 source render.

## SYZ boss hover check

Using the packaged 256-entry `GenesisMath.SINE` table and the source `sine/4 -> 8.8 velY -> 16.16 BossMove` relationship:

- Phase 27 direct render-offset interpretation: approximately -64..+64 pixel offset, about 128 pixels total span.
- Phase 28 integrated source interpretation: approximately 10.26 pixels total vertical span over one 128-tick sine cycle.

`syz_boss_object.gd` no longer contains `bob_offset`; `_bob_and_move()` writes the sine result into `vel_y` and `_update_position()` renders the integrated fixed-point boss Y plus only the explicit attack shake offset.

The spike child no longer adds the Phase 27 `+12` base-Y offset and its hazard height uses the source 12-pixel half-height.

## LZ water checks

Represented source constants/state:

- initial water: `$0B8/$328/$900` for LZ1/2/3;
- target approach: 1 pixel/frame;
- visible surface sway: `oscillate_02 >> 1`;
- LZ1 target transitions `$B8,$108,$E8,$318,$5C8,$3A8` with routine latch behavior;
- LZ2 targets `$328,$3C8,$428`;
- LZ3 target/routine family `$900,$4C8,$308,$508,$188,$608,$7C0,$128`;
- LZ1 alternate switch-5 close flag and LZ3 switch 8 action;
- underwater movement `$300/$06/$40`, jump `$380`, normal underwater air gravity `$10`;
- REV01 background ripple uses a 128-byte base wobble sequence repeated across the 256-byte source index space and starts only at/below the dynamic waterline.

Known deferred water fidelity:

- foreground `Lz_Scroll_Data` scanline ripple;
- underwater palette/HBlank split;
- 30-second air timer, drowning countdown, bubble replenishment and splash/water-surface objects;
- LZ wind tunnels and water slides;
- LZ3 foreground-layout mutation at the first water event.

## Package integrity

- GDScript files: **69**
- Named native classes: **67**
- PNG assets: **535**
- Failed PNG decodes: **0**
- Missing concrete literal `res://` resources: **0**
- Duplicate `class_name` declarations: **0**
- Rough bracket/parenthesis/brace warnings: **0**

All three newly retained original Nemesis streams compare byte-for-byte with the supplied disassembly copies.

## Runtime test checklist

1. SYZ3 boss idle/patrol hover should now be subtle (roughly a ten-pixel total vertical band), not the very large Phase 27 rise/fall.
2. The SYZ spike should visually match the original white/gray Boss-Weapons spike, remain centered on the Eggmobile, extend during descent, retract after the attack, and hurt with the source-sized collision body.
3. LZ vertical doors should use the narrow gold 16x64 source graphic; horizontal doors should use the 128x32 four-panel source graphic.
4. LZ1 water should begin near `$B8` and change height along the original camera-route thresholds. Crossing the surface should immediately change Sonic's movement/jump/gravity on the following source-equivalent state frame.
5. In LZ1 after the `$1080` dynamic-water event, the special switch-5 alternate state should allow the already-opened small door to close through type `$06`.
6. Underwater portions of the LZ background should show the source background wobble only at/below the current dynamic waterline.
