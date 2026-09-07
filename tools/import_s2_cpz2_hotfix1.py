#!/usr/bin/env python3
"""Phase 93 Hotfix 1: CPZ2 water-surface and missing Obj19 small-platform art."""
from pathlib import Path
import importlib.util, sys, hashlib, json

PROJECT = Path(__file__).resolve().parents[1]
ASSET = PROJECT / 'assets/objects/s2_cpz'
DATA = PROJECT / 'data/s1/s2test'

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod
trav = load('trav', PROJECT / 'tools/import_s2_cpz_traversal_phase91.py')

def sha(p: Path): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: import_s2_cpz2_hotfix1.py <retail Sonic 2 source root>')
    src = Path(sys.argv[1]).resolve()
    req = {
        'sonicpal': src/'art/palettes/SonicAndTails.bin',
        'cpzpal': src/'art/palettes/CPZ.bin',
        'platformart': src/'art/nemesis/Large moving platform from CNZ.bin',
        'platformmap': src/'mappings/sprite/obj19.bin',
        'waterart': src/'art/nemesis/Top of water in HPZ and CNZ.bin',
        'watermap': src/'mappings/sprite/obj04_a.bin',
    }
    for p in req.values():
        if not p.is_file(): raise FileNotFoundError(p)
    sonic = req['sonicpal'].read_bytes(); cpz = req['cpzpal'].read_bytes()
    palettes = [trav.palette_line(sonic)] + [trav.palette_line(cpz[i*32:(i+1)*32]) for i in range(3)]

    # Obj19 frame 1 is the 24px-wide smaller CPZ platform used by subtypes
    # $18/$1A/$1D/$1F in Act 2. Keep it in a separate folder so historical
    # Phase 91 frame-count validators remain meaningful.
    raw = trav.nemesis_decode(req['platformart'].read_bytes())
    maps = req['platformmap'].read_bytes()
    dest = ASSET/'platform_small'; dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob('*.png'): old.unlink()
    trav.render_mapping(raw, maps, 1, palettes, 3).save(dest/'00.png')

    # Obj04 frames 0..2. The mappings span local x=-$60..+$40 and y=-8..+8.
    # render_mapping's origin is (96,96), so crop exactly to that authored box.
    raw = trav.nemesis_decode(req['waterart'].read_bytes())
    maps = req['watermap'].read_bytes()
    dest = ASSET/'water_surface'; dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob('*.png'): old.unlink()
    for frame in range(3):
        canvas = trav.render_mapping(raw, maps, frame, palettes, 0)
        canvas.crop((0, 88, 160, 104)).save(dest/f'{frame:02d}.png')

    manifest = {
        'phase': '93_hotfix1',
        'obj19_small_frame': 1,
        'water_surface_frames': [0,1,2],
        'water_surface_local_bounds': [-0x60,-8,0x40,8],
        'source_sha256': {k: sha(v) for k,v in req.items()},
        'output_sha256': {str(p.relative_to(PROJECT)): sha(p) for p in sorted((ASSET/'platform_small').glob('*.png')) + sorted((ASSET/'water_surface').glob('*.png'))},
    }
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA/'phase93_hotfix1_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps(manifest, indent=2))

if __name__ == '__main__': main()
