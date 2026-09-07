# Phase 11 validation

Godot itself is not installed in the packaging environment, so this is static/data validation; Godot 4.6.3 runtime testing remains the definitive check.

## Independent decompression checks

The original source data was decoded outside Godot using independent Python translations of the same Genesis formats:

| Zone | Main art tiles | 16x16 blocks | 256x256 chunks |
|---|---:|---:|---:|
| GHZ | 461 primary tiles | 439 | 82 |
| LZ | 454 | 196 | 82 |
| MZ | 663 | 372 | 82 |
| SLZ | 874 | 414 | 82 |
| SYZ | 882 | 431 | 82 |
| SBZ | 681 | 602 | 82 |

GHZ additionally loads its secondary bank at tile `$1CD` plus the flower/waterfall terrain ranges used by the established Phase 1 renderer.

## Layout/start validation

| Level | Layout | Start |
|---|---|---|
| GHZ1 | 48x5 | (80, 944) |
| GHZ2 | 33x6 | (80, 252) |
| GHZ3 | 48x6 | (80, 944) |
| LZ1 | 32x8 | (96, 108) |
| LZ2 | 19x8 | (80, 236) |
| LZ3 | 35x8 | (80, 748) |
| MZ1 | 26x6 | (48, 614) |
| MZ2 | 27x6 | (48, 614) |
| MZ3 | 28x8 | (48, 358) |
| SLZ1 | 34x8 | (64, 716) |
| SLZ2 | 34x7 | (64, 332) |
| SLZ3 | 35x8 | (64, 332) |
| SYZ1 | 37x5 | (48, 957) |
| SYZ2 | 43x6 | (48, 445) |
| SYZ3 | 49x7 | (48, 236) |
| SBZ1 | 36x8 | (48, 1164) |
| SBZ2 | 40x8 | (48, 1868) |

The catalog's SBZ act-3 slot represents internally identified Final Zone using SBZ2 layout + `objpos/fz.bin` + `startpos/fz.bin`. The flooded SBZ3 corridor is LZ act 4 internally and remains a special transition for a later phase.

## Green Hill object-placement validation

- GHZ1: 214 records, all placement IDs have native Phase-10/11 handlers.
- GHZ2: 244 records. New unsupported IDs are `$15` Swinging Platform and `$3C` Smashable Wall; F3 exposes them as placeholders.
- GHZ3 REV01: 286 records. Unsupported IDs include `$15` Swinging Platform, `$17` Helix, `$3C` Smashable Wall and `$3E` Prison/Capsule. The GHZ3 boss event is also deferred.

## Render validation

`GHZ2_PREVIEW.png` and `GHZ3_PREVIEW.png` were assembled from the packaged Genesis data through independent Nemesis/Enigma/Kosinski decoding, 4bpp tiles, block words, chunk words and layout bytes. Both produced coherent full-act terrain rather than malformed/decompression garbage.

## Static package checks

- Every literal `res://` resource path in GDScript resolves inside the package.
- 46 GDScript files are present.
- 336 generated PNG assets are retained from previous validated phases.
- Six zone map16 banks and six zone map256 banks are packaged.
- Collision-index data and start positions are packaged for every registered main zone.
- User-required Godot 4.6.3 `Sonic_Animate` local declarations still use `=` instead of `:=`.
- The GHZ loop front/back chunk switch was intentionally not changed in Phase 11.
