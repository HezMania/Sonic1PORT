#!/usr/bin/env python3
"""Phase 88: import retail Sonic 2 Emerald Hill Zone Act 2 into the native S2 test path."""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
HERE = PROJECT / 'tools'

def load_phase64():
    spec = importlib.util.spec_from_file_location('phase64_import', HERE / 'import_sonic2_level.py')
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod

phase64 = load_phase64()

def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def header_layout(width: int, height: int, body: bytes) -> bytes:
    if len(body) != width * height:
        raise ValueError(f'layout body {len(body)} != {width}x{height}')
    return bytes((width - 1, height - 1)) + body

def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit('usage: import_s2_ehz2.py <retail Sonic 2 root>')
    src = Path(sys.argv[1]).resolve()
    out = PROJECT / 'data/s1/s2test'
    out.mkdir(parents=True, exist_ok=True)

    paths = {
        'layout': src/'level/layout/EHZ_2.bin',
        'objects': src/'level/objects/EHZ_2.bin',
        'rings': src/'level/rings/EHZ_2.bin',
        'start': src/'startpos/EHZ_2.bin',
        'map128': src/'mappings/128x128/EHZ_HTZ.bin',
    }
    for p in paths.values():
        if not p.is_file():
            raise FileNotFoundError(p)

    ram = phase64.kosinski_decompress(paths['layout'].read_bytes())
    if len(ram) != 0x1000:
        raise ValueError(f'EHZ2 layout decoded to {len(ram):#x}, expected 0x1000')
    fg = bytearray(); bg = bytearray()
    for row in range(16):
        base = row * 0x100
        fg += ram[base:base+0x80]
        bg += ram[base+0x80:base+0x100]

    outputs = {
        'ehz2_layout128.bin': header_layout(128,16,bytes(fg)),
        'ehz2_bg128.bin': header_layout(128,16,bytes(bg)),
        'ehz2_objects.bin': paths['objects'].read_bytes(),
        'ehz2_rings.bin': paths['rings'].read_bytes(),
        'ehz2_start.bin': paths['start'].read_bytes(),
    }
    for name, blob in outputs.items():
        (out/name).write_bytes(blob)

    obj = outputs['ehz2_objects.bin']
    counts = {}
    for i in range(0,len(obj),6):
        oid = obj[i+4]
        counts[f'{oid:02X}'] = counts.get(f'{oid:02X}',0)+1

    manifest = {
        'phase': 88,
        'source': 'retail Sonic 2 disassembly',
        'level': 'Emerald Hill Zone Act 2',
        'layout_decoded_bytes': len(ram),
        'foreground_128': [128,16],
        'background_128': [128,16],
        'start': [int.from_bytes(outputs['ehz2_start.bin'][:2],'big'), int.from_bytes(outputs['ehz2_start.bin'][2:4],'big')],
        'limits': {'left':0,'right':0x2940,'top':0,'bottom':0x420},
        'object_records': len(obj)//6,
        'object_counts_hex': counts,
        'source_sha256': {k: sha(p.read_bytes()) for k,p in paths.items()},
        'output_sha256': {k: sha(v) for k,v in outputs.items()},
        'shared_native_map128_sha256': sha(phase64.kosinski_decompress(paths['map128'].read_bytes())),
    }
    (out/'phase88_ehz2_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))

if __name__ == '__main__':
    main()
