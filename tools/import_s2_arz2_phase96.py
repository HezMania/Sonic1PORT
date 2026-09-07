#!/usr/bin/env python3
"""Phase 96: import retail Sonic 2 Aquatic Ruin Act 2 core data/presentation."""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from collections import Counter
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
TOOLS = PROJECT / 'tools'
OUT = PROJECT / 'data' / 's1'
S2TEST = OUT / 's2test'


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    return mod


p95 = load('phase95_arz', TOOLS / 'import_s2_arz1_phase95.py')
terrain = load('terrain_arz2', TOOLS / 'import_sonic2_level.py')


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit('usage: import_s2_arz2_phase96.py <retail Sonic 2 root>')
    src = Path(sys.argv[1]).resolve()
    S2TEST.mkdir(parents=True, exist_ok=True)

    req = {
        'art': src / 'art/kosinski/ARZ.bin',
        'map16': src / 'mappings/16x16/ARZ.bin',
        'map128': src / 'mappings/128x128/ARZ.bin',
        'layout': src / 'level/layout/ARZ_2.bin',
        'objects': src / 'level/objects/ARZ_2.bin',
        'rings': src / 'level/rings/ARZ_2.bin',
        'start': src / 'startpos/ARZ_2.bin',
    }
    for path in req.values():
        if not path.is_file():
            raise FileNotFoundError(path)

    # ARZ1/2 share resident level art, Map16/Map128 and collision. Recreate the
    # exact same VRAM image used by Phase 95 so the Act 2 Plane-B cache includes
    # the source waterfall animation seed and APM_ARZ patch as well.
    art = p95.seed_anim(src, terrain.kosinski_decompress(req['art'].read_bytes()))
    base16 = terrain.kosinski_decompress(req['map16'].read_bytes())
    dest, patch = p95.extract_apm(src)
    map16 = bytearray(0x1800)
    map16[:len(base16)] = base16
    map16[dest:dest + len(patch)] = patch
    map16 = bytes(map16)
    map128 = terrain.kosinski_decompress(req['map128'].read_bytes())
    layout = terrain.kosinski_decompress(req['layout'].read_bytes())
    if len(layout) != 0x1000 or len(map128) != 0x8000:
        raise ValueError((len(layout), len(map128)))

    fg = bytearray()
    bg = bytearray()
    for row in range(16):
        base = row * 0x100
        fg += layout[base:base + 0x80]
        bg += layout[base + 0x80:base + 0x100]

    bgindices, unique = p95.build_bg_indices(bytes(bg), map128, map16, art, 128, 12)
    outputs = {
        'arz2_layout128.bin': p95.header(128, 16, fg),
        'arz2_bg128.bin': p95.header(128, 16, bg),
        'arz2_objects.bin': req['objects'].read_bytes(),
        'arz2_rings.bin': req['rings'].read_bytes(),
        'arz2_start.bin': req['start'].read_bytes(),
        'arz2_bg_indices.bin': bgindices,
    }
    for name, data in outputs.items():
        (S2TEST / name).write_bytes(data)

    obj = outputs['arz2_objects.bin']
    counts = Counter(obj[i + 4] for i in range(0, len(obj), 6))
    # Existing Phase-95 runtime families plus the already-native Egg Prison.
    supported = {0x03, 0x18, 0x26, 0x3E, 0x40, 0x41, 0x79}
    supported_count = sum(v for k, v in counts.items() if k in supported)
    manifest = {
        'phase': 96,
        'level': 'Aquatic Ruin Zone Act 2',
        'start': [p95.be16(outputs['arz2_start.bin'], 0), p95.be16(outputs['arz2_start.bin'], 2)],
        'limits': {'left': 0, 'right': 0x3FFF, 'top': 0x180, 'bottom': 0x710},
        'water': {'static_y': 0x510},
        'layout_128': [128, 16],
        'background_128': [128, 16],
        'background_index_plane': [16384, 1536],
        'background_unique_chunks': unique,
        'object_records': len(obj) // 6,
        'supported_shared_records': supported_count,
        'deferred_arz_specific_records': len(obj) // 6 - supported_count,
        'object_counts_hex': {f'{k:02X}': v for k, v in sorted(counts.items())},
        'apm_arz': {'destination': dest, 'bytes': len(patch)},
        'background_vertical_model': '(CameraY-$E0)/2',
        'output_sha256': {k: sha(v) for k, v in outputs.items()},
    }
    (S2TEST / 'phase96_arz2_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
