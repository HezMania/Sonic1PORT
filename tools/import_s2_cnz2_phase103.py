#!/usr/bin/env python3
"""Phase 103: import retail Sonic 2 Casino Night Act 2 core level data."""
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


p98 = load('phase98_cnz', TOOLS / 'import_s2_cnz1_phase98.py')
terrain = load('terrain_phase103', TOOLS / 'import_sonic2_level.py')


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit('usage: import_s2_cnz2_phase103.py <retail Sonic 2 root>')
    src = Path(sys.argv[1]).resolve()
    S2TEST.mkdir(parents=True, exist_ok=True)

    req = {
        'art': src / 'art/kosinski/CNZ.bin',
        'map16': src / 'mappings/16x16/CNZ.bin',
        'map128': src / 'mappings/128x128/CNZ.bin',
        'layout': src / 'level/layout/CNZ_2.bin',
        'objects': src / 'level/objects/CNZ_2.bin',
        'rings': src / 'level/rings/CNZ_2.bin',
        'start': src / 'startpos/CNZ_2.bin',
        'colp': src / 'collision/CNZ primary 16x16 collision index.bin',
        'cols': src / 'collision/CNZ secondary 16x16 collision index.bin',
    }
    for path in req.values():
        if not path.is_file():
            raise FileNotFoundError(path)

    # Acts 1 and 2 share the same resident art, map tables and collision. Rebuild
    # the seeded CNZ VRAM image here so Act 2 is independently reproducible from
    # the retail source rather than depending on Phase 98-generated files.
    resident = terrain.kosinski_decompress(req['art'].read_bytes())
    art, _flip = p98.seed_art(src, resident)
    base16 = terrain.kosinski_decompress(req['map16'].read_bytes())
    dest, patch = p98.extract_apm(src)
    map16 = bytearray(0x1800)
    map16[:len(base16)] = base16
    map16[dest:dest + len(patch)] = patch
    map16 = bytes(map16)
    map128 = terrain.kosinski_decompress(req['map128'].read_bytes())
    layout = terrain.kosinski_decompress(req['layout'].read_bytes())
    colp = terrain.kosinski_decompress(req['colp'].read_bytes())
    cols = terrain.kosinski_decompress(req['cols'].read_bytes())
    if len(resident) != 0x6600 or len(layout) != 0x1000 or len(map128) != 0x8000:
        raise ValueError((len(resident), len(layout), len(map128)))

    fg = bytearray()
    bg = bytearray()
    for row in range(16):
        base = row * 0x100
        fg += layout[base:base + 0x80]
        bg += layout[base + 0x80:base + 0x100]

    outputs = {
        'cnz2_art.bin': art,
        'cnz2_map16.bin': map16,
        'cnz2_map128.bin': map128,
        'cnz2_layout128.bin': p98.header(128, 16, fg),
        'cnz2_bg128.bin': p98.header(128, 16, bg),
        'cnz2_collision_primary.bin': colp,
        'cnz2_collision_secondary.bin': cols,
        'cnz2_objects.bin': req['objects'].read_bytes(),
        'cnz2_rings.bin': req['rings'].read_bytes(),
        'cnz2_start.bin': req['start'].read_bytes(),
    }
    for name, data in outputs.items():
        (S2TEST / name).write_bytes(data)

    obj = outputs['cnz2_objects.bin']
    counts = Counter(obj[i + 4] for i in range(0, len(obj), 6))
    supported = {
        0x03, 0x0D, 0x26, 0x3E, 0x41, 0x74, 0x79,
        0x44, 0x72, 0x84, 0x85, 0x86, 0xD4, 0xD5, 0xD7,
        0xC8, 0xD2, 0xD6, 0xD8,
    }
    supported_count = sum(v for k, v in counts.items() if k in supported)
    manifest = {
        'phase': 103,
        'level': 'Casino Night Zone Act 2',
        'start': [p98.be16(outputs['cnz2_start.bin'], 0), p98.be16(outputs['cnz2_start.bin'], 2)],
        'limits': {'left': 0, 'right': 0x2A80, 'top': 0, 'bottom': 0x720},
        'layout_128': [128, 16],
        'background_128': [128, 16],
        'resident_art_bytes': len(resident),
        'map16_base_bytes': len(base16),
        'map16_apm': {'destination': dest, 'bytes': len(patch)},
        'object_records': len(obj) // 6,
        'native_placement_records': supported_count,
        'deferred_placement_records': len(obj) // 6 - supported_count,
        'object_counts_hex': {f'{k:02X}': v for k, v in sorted(counts.items())},
        'boss_event_status': 'deferred_to_next_phase',
        'output_sha256': {k: sha(v) for k, v in outputs.items()},
    }
    (S2TEST / 'phase103_cnz2_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
