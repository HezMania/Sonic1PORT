#!/usr/bin/env python3
"""Phase 90: import retail Sonic 2 Chemical Plant Act 1 core level/presentation data.

Outputs native 128x128 terrain, collision, palette, object/ring/start data, the
first source animated-background frame, exact APM_CPZ block patch, palette-cycle
sources, and the retail CPZ SMPS song. CPZ-specific placed-object behavior and
full SwScrl_CPZ deformation remain later passes.
"""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from collections import Counter
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
TOOLS = PROJECT / 'tools'
OUT = PROJECT / 'data' / 's1'
S2TEST = OUT / 's2test'
SOUND = OUT / 'sound'
PAL = OUT / 'palette'


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod

terrain = load('phase64', TOOLS / 'import_sonic2_level.py')
pres = load('phase87', TOOLS / 'import_s2_ehz_presentation.py')


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off + 1]


def header_layout(width: int, height: int, body: bytes) -> bytes:
    if len(body) != width * height:
        raise ValueError(f'layout body {len(body)} != {width}x{height}')
    return bytes((width - 1, height - 1)) + body


def extract_apm_cpz(src: Path) -> tuple[int, bytes]:
    # begin_animpat encodes destination byte offset then word-count-minus-one.
    # Resolve the exact assembled range via the retail listing/ROM, as with EHZ.
    import re
    text = (src / 's2.lst').read_text(errors='replace')
    ms = re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_CPZ label \*', text)
    me = re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_CPZ_End:', text)
    if not ms or not me:
        raise ValueError('Could not locate APM_CPZ in s2.lst')
    start, end = int(ms.group(1), 16), int(me.group(1), 16)
    rom = (src / 's2built.bin').read_bytes()
    dest = be16(rom, start)
    words_minus_one = be16(rom, start + 2)
    patch = rom[start + 4:end]
    expected = (words_minus_one + 1) * 2
    if len(patch) != expected:
        raise ValueError(f'APM_CPZ length {len(patch):#x} != {expected:#x}')
    if dest + len(patch) != 0x1800:
        raise ValueError(f'APM_CPZ does not end at $1800: {dest:#x}+{len(patch):#x}')
    return dest, patch


def build_cpz_song(src: Path) -> dict:
    data = pres.saxman_decompress((src / 'sound/music/CPZ.bin').read_bytes())
    # Reuse the proven S2 parser with a CPZ-local label namespace.
    pres.PORT_MUSIC_ID = 0x197
    pres.label = lambda kind, off: f"S2CPZ_{'D' if kind == 'DAC' else ('P' if kind == 'PSG' else 'F')}_{off:04X}"
    song = pres.parse_song(data)
    song['id'] = 0x197
    song['name'] = 'Sonic 2 - Chemical Plant Zone'
    song['header']['voice_label'] = 'S2CPZ_Voices'
    # CPZ's source header tempo is retained by parse_song. The port's speed-up
    # command uses the same accelerated S2 tempo target already proven in EHZ.
    song['header']['speed_tempo'] = 0xFF
    song['source']['song_sha256'] = sha((src / 'sound/music/CPZ.bin').read_bytes())
    return song


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: import_s2_cpz1_phase90.py <retail Sonic 2 root>', file=sys.stderr)
        return 2
    src = Path(sys.argv[1]).resolve()
    req = {
        'art': src/'art/kosinski/CPZ_DEZ.bin',
        'map16': src/'mappings/16x16/CPZ_DEZ.bin',
        'map128': src/'mappings/128x128/CPZ_DEZ.bin',
        'layout': src/'level/layout/CPZ_1.bin',
        'objects': src/'level/objects/CPZ_1.bin',
        'rings': src/'level/rings/CPZ_1.bin',
        'start': src/'startpos/CPZ_1.bin',
        'colp': src/'collision/CPZ and DEZ primary 16x16 collision index.bin',
        'cols': src/'collision/CPZ and DEZ secondary 16x16 collision index.bin',
        'pal': src/'art/palettes/CPZ.bin',
        'anim': src/'art/uncompressed/Animated background section (CPZ and DEZ).bin',
        'cycle1': src/'art/palettes/CPZ Cycle 1.bin',
        'cycle2': src/'art/palettes/CPZ Cycle 2.bin',
        'cycle3': src/'art/palettes/CPZ Cycle 3.bin',
        'music': src/'sound/music/CPZ.bin',
    }
    for p in req.values():
        if not p.is_file(): raise FileNotFoundError(p)

    main_art = terrain.kosinski_decompress(req['art'].read_bytes())
    vram = bytearray(0x800 * 32)
    vram[:len(main_art)] = main_art
    anim = req['anim'].read_bytes()
    if len(anim) < 64: raise ValueError('CPZ animated background source truncated')
    vram[0x370*32:0x372*32] = anim[:64]

    base_map16 = terrain.kosinski_decompress(req['map16'].read_bytes())
    apm_dest, apm_patch = extract_apm_cpz(src)
    map16 = bytearray(0x1800)
    map16[:len(base_map16)] = base_map16
    map16[apm_dest:apm_dest+len(apm_patch)] = apm_patch
    map128 = terrain.kosinski_decompress(req['map128'].read_bytes())
    layout = terrain.kosinski_decompress(req['layout'].read_bytes())
    colp = terrain.kosinski_decompress(req['colp'].read_bytes())
    cols = terrain.kosinski_decompress(req['cols'].read_bytes())
    if len(layout) != 0x1000: raise ValueError(f'CPZ1 layout {len(layout):#x} != $1000')
    if len(map128) != 0x8000: raise ValueError(f'CPZ Map128 {len(map128):#x} != $8000')

    fg = bytearray(); bg = bytearray()
    for row in range(16):
        base = row * 0x100
        fg += layout[base:base+0x80]
        bg += layout[base+0x80:base+0x100]

    S2TEST.mkdir(parents=True, exist_ok=True); PAL.mkdir(parents=True, exist_ok=True); SOUND.mkdir(parents=True, exist_ok=True)
    outputs = {
        'cpz1_art.bin': bytes(vram),
        'cpz1_map16.bin': bytes(map16),
        'cpz1_map128.bin': map128,
        'cpz1_layout128.bin': header_layout(128,16,bytes(fg)),
        'cpz1_bg128.bin': header_layout(128,16,bytes(bg)),
        'cpz1_collision_primary.bin': colp,
        'cpz1_collision_secondary.bin': cols,
        'cpz1_objects.bin': req['objects'].read_bytes(),
        'cpz1_rings.bin': req['rings'].read_bytes(),
        'cpz1_start.bin': req['start'].read_bytes(),
        's2_cpz_anim_back.bin': anim,
    }
    for name, blob in outputs.items(): (S2TEST/name).write_bytes(blob)
    (PAL/'S2 Chemical Plant Zone.bin').write_bytes(req['pal'].read_bytes())
    (PAL/'S2 CPZ Cycle 1.bin').write_bytes(req['cycle1'].read_bytes())
    (PAL/'S2 CPZ Cycle 2.bin').write_bytes(req['cycle2'].read_bytes())
    (PAL/'S2 CPZ Cycle 3.bin').write_bytes(req['cycle3'].read_bytes())

    # Merge CPZ into the already-generated retail S2 music table.
    music_path = SOUND/'s2_ehz_smps.json'
    db = json.loads(music_path.read_text()) if music_path.is_file() else {'music':{}}
    song = build_cpz_song(src)
    db.setdefault('music', {})[str(0x197)] = song
    music_path.write_text(json.dumps(db, indent=2) + '\n')

    obj = outputs['cpz1_objects.bin']
    counts = Counter(obj[i+4] for i in range(0,len(obj),6))
    shared_ids = {0x03,0x0D,0x26,0x41,0x79}
    shared_count = sum(v for k,v in counts.items() if k in shared_ids)
    manifest = {
        'phase': 90,
        'level': 'Chemical Plant Zone Act 1',
        'start': [be16(outputs['cpz1_start.bin'],0),be16(outputs['cpz1_start.bin'],2)],
        'limits': {'left':0,'right':0x2780,'top':0,'bottom':0x720},
        'layout_128':[128,16], 'background_128':[128,16],
        'object_records':len(obj)//6,
        'shared_supported_records':shared_count,
        'deferred_cpz_specific_records':len(obj)//6-shared_count,
        'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
        'decoded_sizes': {'art':len(main_art),'vram_art':len(vram),'map16_base':len(base_map16),'map16_apm':len(map16),'map128':len(map128),'layout':len(layout),'colp':len(colp),'cols':len(cols)},
        'apm_cpz': {'destination':apm_dest,'bytes':len(apm_patch)},
        'music': {'id':0x197,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'labels':len(song['labels']),'dac_ids':song['source']['used_dac_ids']},
        'source_sha256': {k:sha(p.read_bytes()) for k,p in req.items()},
        'output_sha256': {k:sha(v) for k,v in outputs.items()},
    }
    (S2TEST/'phase90_cpz1_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
