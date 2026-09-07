# Phase 2 validation notes

## Retained Phase 1 data validation

- GHZ1 primary Nemesis bank: 461 tiles
- GHZ1 secondary Nemesis bank: 369 tiles
- GHZ 16×16 mappings: 439 blocks
- GHZ 256×256 mappings: 82 chunks
- GHZ1 layout: 48 × 5 chunks

## Player asset validation

The Sonic art/mapping/DPLC preprocessing produced 88 frame textures:

```text
assets/sonic/frames/00.png ... 87.png
```

Every generated image was reopened and verified successfully. All frames are 64×64 RGBA textures so the Sprite2D origin remains stable across animation frames.

## Spawn/collision sanity check

Original GHZ1 start position:

```text
X = 80
Y = 944
```

Using standing radii `width=9`, `height=19`, the two Phase 2 floor sensors at that point returned:

```text
left sensor:  distance 3, angle $FC
right sensor: distance 0, angle $FC
```

The right sensor is therefore already on the terrain and Sonic does not need a hard-coded spawn-floor adjustment.

## Terrain priority validation

The decompressed GHZ map16 bank contains 1,756 pattern words. During validation:

```text
high-priority pattern words: 242
low-priority pattern words:  1,514
blocks containing high-priority tiles: 63
```

Phase 2 keeps these categories in separate rendered layers.

## Runtime validation status

The previously supplied Phase 1 project was confirmed by the project owner to run correctly in Godot 4.6.3. The Phase 2 package was built on that same project/data path and its generated assets/data were independently checked as described above.

A Godot executable is not installed in the artifact-generation container, so final engine-side gameplay testing should be done in Godot 4.6.3. F2 enables the player sensor overlay specifically to make collision discrepancies easy to report with position/velocity/angle values from the on-screen status line.
