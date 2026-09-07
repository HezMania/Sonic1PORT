# Phase 23 validation

Phase 23 was statically and asset-validated outside the Godot editor. Runtime behavior should still be verified in Godot 4.6.3.

## Source-derived asset validation

Re-generated from the supplied disassembly:
- SYZ floating blocks frames 0–4
- Bumper frames 0–2
- Roller frames 0–4
- Button frames 0–2
- giant spike-ball `.ball` frame
- small spike-ball frame

The floating blocks are generated from the decompressed SYZ level-art bank, not a generic replacement texture.

## Behavioral checks

- Bumper does not clear Sonic's `rolling` flag.
- Bumper hitbox is rectangular and source-sized.
- Roller stays hidden while waiting at its grounded spawn point.
- Roller rolling order is 3→4→2.
- Spike-chain and circular giant-ball visible angles use the high byte of a 16-bit accumulator.
- Giant spike-ball no longer cycles unrelated mapping frames.
- Floating-block movement continues to use source oscillator channels/ranges.
- Source Sonic `$600` top speed and `$680` jump speed remain unchanged.
- Dynamic ProjectSettings viewport sizing remains present.
- Godot 4.6.3 `Sonic_Animate` local declarations remain in their previously tested `=` form.
