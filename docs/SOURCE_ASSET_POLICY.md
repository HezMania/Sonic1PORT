# Source-asset fidelity policy

Beginning with Phase 28, this project follows a strict source-art rule:

> If the original Sonic 1 disassembly contains a known source graphic, do not invent, redraw, or reconstruct a substitute.

For known source assets, the native project should:

1. recover the original compressed/raw art stream from the supplied disassembly;
2. use the original mapping frame and tile-base relationship;
3. use the original palette line/source palette;
4. decode/render the resulting native PNG without smoothing or stylistic reinterpretation;
5. retain the original source stream in `data/s1/` when practical so provenance can be rechecked later.

If a required original source asset is genuinely unavailable, the missing visual must be documented as missing rather than silently replaced with invented art. A temporary placeholder may only be used when clearly identified as a placeholder and should not be described as source-faithful.
