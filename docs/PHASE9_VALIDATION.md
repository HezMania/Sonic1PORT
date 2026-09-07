# Phase 9 validation notes

## Asset reconstruction
Generated directly from the supplied disassembly:

- 5 explosion PNGs
- 3 shield PNGs
- 4 invincibility-star PNGs
- 3 rabbit PNGs
- 3 Flicky PNGs
- 7 score-popup PNGs

All use nearest-neighbor Genesis 4bpp decoding and the combined Sonic/GHZ CRAM palette already used by the native level renderer.

## Runtime paths checked
- badnik destruction -> score registration -> gray explosion + GHZ animal + points popup
- monitor break -> gray explosion + Object $2E power-up, no animal
- shield flag -> Object $38 shield visibility
- invincibility timer -> shield hidden + four star trails
- end-of-act -> card slide -> 3-second wait -> bonus tally -> 3-second post wait

## Retained compatibility correction
The user-tested Godot 4.6.3 `Sonic_Animate` local declarations using `=` remain unchanged.

## Known limitation
No Godot executable is installed in the artifact environment, so validation is static/data-level rather than a final Godot editor run. The GHZ loop front/back chunk-layer switch is deliberately not changed in Phase 9.

## Package integrity
Static validation found 43 GDScript files, 41 named native classes, 299 PNG assets total, and 25 new Phase 9 effect PNGs. All PNGs decode, all literal `res://` paths resolve, delimiter checks pass, and the final ZIP passes `unzip -t`.
