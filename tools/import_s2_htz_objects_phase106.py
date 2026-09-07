#!/usr/bin/env python3
from pathlib import Path
import sys, importlib.util, json, hashlib

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'assets/objects/s2_htz'

def load_module(name, path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
trav=load_module('trav106', PROJECT/'tools/import_s2_cpz_traversal_phase91.py')

def frame_count(mapping: bytes) -> int:
    if len(mapping)<2: return 0
    return int.from_bytes(mapping[:2], 'big')//2

def save_frames(raw: bytes, mapping: bytes, palettes, base_pal: int, folder: str, frames=None):
    d=OUT/folder; d.mkdir(parents=True, exist_ok=True)
    for p in d.glob('*.png'): p.unlink()
    count=frame_count(mapping) if frames is None else frames
    for i in range(count):
        trav.render_mapping(raw,mapping,i,palettes,base_pal).save(d/f'{i:02d}.png')
    return count

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_htz_objects_phase106.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); OUT.mkdir(parents=True,exist_ok=True)
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes()
    htz=(src/'art/palettes/HTZ.bin').read_bytes()
    palettes=[trav.palette_line(sonic)]+[trav.palette_line(htz[i*32:(i+1)*32]) for i in range(3)]
    resident=(PROJECT/'data/s1/s2test/htz1_art.bin').read_bytes()
    results={}
    # Obj18 uses resident level art. HTZ's negative $9A/$9B placements select frame 1.
    results['platform']=save_frames(resident,(src/'mappings/sprite/obj18_a.bin').read_bytes(),palettes,2,'platform')
    # Obj2F, Spiker and Sol also use ArtKos_LevelArt and therefore must be rendered
    # from the final HTZ resident bank rather than from an EHZ/CPZ object sheet.
    results['smash_ground']=save_frames(resident,(src/'mappings/sprite/obj2F.bin').read_bytes(),palettes,2,'smash_ground')
    spiker_raw=trav.nemesis_decode((src/'art/nemesis/Driller badnik from HTZ.bin').read_bytes())
    spiker_vram=(b'\0'*(0x520*32))+spiker_raw
    results['spiker']=save_frames(spiker_vram,(src/'mappings/sprite/obj93.bin').read_bytes(),palettes,0,'spiker')
    sol_plc_raw=trav.nemesis_decode((src/'art/nemesis/Sol badnik from HTZ.bin').read_bytes())
    fire1_raw=trav.nemesis_decode((src/'art/nemesis/Fireball 1.bin').read_bytes())
    sol_buf=bytearray((0x3DE*32)+len(sol_plc_raw))
    sol_buf[0x39E*32:0x39E*32+len(fire1_raw)]=fire1_raw
    sol_buf[0x3DE*32:0x3DE*32+len(sol_plc_raw)]=sol_plc_raw
    results['sol']=save_frames(bytes(sol_buf),(src/'mappings/sprite/obj95.bin').read_bytes(),palettes,0,'sol')
    # Nemesis object banks.
    banks=[
      ('rock','Rock from HTZ.bin','obj32_a.bin',2),
      ('seesaw','See-saw in HTZ.bin','obj14_a.bin',0),
      ('lift','HTZ zip-line platform.bin','obj16.bin',2),
      ('rexon','Rexxon (lava snake) from HTZ.bin','obj97.bin',3),
    ]
    for folder, art_name, map_name, pal in banks:
        raw=trav.nemesis_decode((src/'art/nemesis'/art_name).read_bytes())
        results[folder]=save_frames(raw,(src/'mappings/sprite'/map_name).read_bytes(),palettes,pal,folder)
    # The seesaw's loose counterweight uses Sol's Nemesis bank with obj14_b mappings.
    sol_raw=trav.nemesis_decode((src/'art/nemesis/Sol badnik from HTZ.bin').read_bytes())
    results['seesaw_ball']=save_frames(sol_raw,(src/'mappings/sprite/obj14_b.bin').read_bytes(),palettes,0,'seesaw_ball')
    manifest={'phase':106,'frames':results,'files':{str(p.relative_to(PROJECT)):sha(p) for p in sorted(OUT.rglob('*.png'))}}
    (PROJECT/'data/s1/s2test/phase106_htz_object_art_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
