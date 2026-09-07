#!/usr/bin/env python3
"""Phase 124: retail Sonic 2 Metropolis Zone Act 3 foundation.

Imports the exact retail MTZ3 terrain/layout/collision/object/ring/start streams,
reuses the retail MTZ art/PLC reconstruction and assembled APM_MTZ Map16 tail,
and preserves all 270 object records. Phase 124 also reconstructs Obj6E's
four circular-platform mapping frames for the MTZ-local adapter.
"""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
TOOLS=P/'tools'; DATA=P/'data'/'s1'/'s2test'; OUT=P/'assets'/'objects'/'s2_mtz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
p122=load('p122',TOOLS/'import_s2_mtz2_phase122.py')
trav=load('trav124',TOOLS/'import_s2_cpz_traversal_phase91.py')
terrain=load('terrain124',TOOLS/'import_sonic2_level.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def ring_group_count(raw:bytes)->int:
    off=0; n=0
    while off+1<len(raw):
        x=be16(raw,off); off+=2
        if x&0x8000: break
        if off+1>=len(raw): raise ValueError('truncated ring stream')
        off+=2; n+=1
    return n

def render_obj6e(src:Path, art:bytes)->dict:
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); zone=(src/'art/palettes/MTZ.bin').read_bytes()
    pals=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    maps=(src/'mappings/sprite/obj6E.bin').read_bytes(); d=OUT/'circle_platform'; d.mkdir(parents=True,exist_ok=True)
    for q in d.glob('*.png'): q.unlink()
    hashes={}
    # Frames 0-2 use ArtKos_LevelArt (tile base 0). Frame 3 changes its art base
    # to ArtNem_MtzWheelIndent at VRAM tile $3F0.
    for frame in range(4):
        raw=art if frame<3 else art[0x3F0*32:]
        im=trav.render_mapping(raw,maps,frame,pals,3)
        path=d/f'{frame:02d}.png'; im.save(path); hashes[str(path.relative_to(OUT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    return hashes

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_mtz3_phase124.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True)
    art,artmeta,retained=p122.build_art(src); map16,mapmeta=p122.build_map16(src)
    map128=terrain.kosinski_decompress((src/'mappings/128x128/MTZ.bin').read_bytes())
    layout=terrain.kosinski_decompress((src/'level/layout/MTZ_3.bin').read_bytes())
    col=terrain.kosinski_decompress((src/'collision/MTZ primary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(map128)==0x8000 and len(col)==0x300
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    outputs={
      'mtz3_art.bin':art,'mtz3_map16.bin':map16,'mtz3_map128.bin':map128,
      'mtz3_layout128.bin':header(128,16,fg),'mtz3_bg128.bin':header(128,16,bg),
      'mtz3_collision_primary.bin':col,'mtz3_collision_secondary.bin':col,
      'mtz3_objects.bin':(src/'level/objects/MTZ_3.bin').read_bytes(),
      'mtz3_rings.bin':(src/'level/rings/MTZ_3.bin').read_bytes(),
      'mtz3_start.bin':(src/'startpos/MTZ_3.bin').read_bytes(),
    }
    for n,b in outputs.items(): (DATA/n).write_bytes(b)
    for n,b in retained.items():
        q=DATA/n
        if not q.exists(): q.write_bytes(b)
    obj=outputs['mtz3_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    art_hashes=render_obj6e(src,art)
    manifest={
      'phase':124,'level':'Metropolis Zone Act 3',
      'start':[be16(outputs['mtz3_start.bin'],0),be16(outputs['mtz3_start.bin'],2)],
      'limits':{'left':0,'right':0x2A80,'top':-0x100,'bottom':0x800},
      'layout':[128,16],'background_scroll':{'x_divisor':8,'y_divisor':4},
      'art':artmeta,'map16':mapmeta,'map128_bytes':len(map128),'collision_bytes':len(col),
      'objects':len(obj)//6,'ring_groups':ring_group_count(outputs['mtz3_rings.bin']),
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'new_act3_families':{'6A':counts.get(0x6A,0),'6E':counts.get(0x6E,0)},
      'boss_event':{'approach_x':0x2530,'follow_lock_x':0x2980,'arena_trigger_x':0x2A80,'arena_x':0x2AB0,'screen_shift_frames':0x5A,'boss_deferred':True},
      'obj6e_sprite_sha256':art_hashes,
      'sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (DATA/'phase124_mtz3_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
