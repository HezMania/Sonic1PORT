#!/usr/bin/env python3
"""Phase 93: import retail Sonic 2 Chemical Plant Act 2 data and new CPZ2 object art."""
from pathlib import Path
from collections import Counter
import hashlib, importlib.util, json, sys

PROJECT=Path(__file__).resolve().parents[1]
S2TEST=PROJECT/'data/s1/s2test'
PAL=PROJECT/'data/s1/palette'
ASSET=PROJECT/'assets/objects/s2_cpz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod
terrain=load('terrain',PROJECT/'tools/import_sonic2_level.py')
trav=load('trav',PROJECT/'tools/import_s2_cpz_traversal_phase91.py')

def sha(b): return hashlib.sha256(b).hexdigest()
def be16(b,o): return (b[o]<<8)|b[o+1]
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_cpz2_phase93.py <retail Sonic 2 source root>')
    src=Path(sys.argv[1]).resolve()
    req={
      'layout':src/'level/layout/CPZ_2.bin','objects':src/'level/objects/CPZ_2.bin',
      'rings':src/'level/rings/CPZ_2.bin','start':src/'startpos/CPZ_2.bin',
      'underwater':src/'art/palettes/CPZ underwater.bin',
      'sonicpal':src/'art/palettes/SonicAndTails.bin','cpzpal':src/'art/palettes/CPZ.bin',
      'leverart':src/'art/nemesis/Lever spring.bin','levermap':src/'mappings/sprite/obj40.bin',
      'platformart':src/'art/nemesis/Moving block from CPZ.bin','platformmap':src/'mappings/sprite/obj7A.bin',
    }
    for p in req.values():
        if not p.is_file(): raise FileNotFoundError(p)
    layout=terrain.kosinski_decompress(req['layout'].read_bytes())
    if len(layout)!=0x1000: raise ValueError(f'CPZ2 layout {len(layout):#x} != $1000')
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        base=row*0x100; fg+=layout[base:base+0x80]; bg+=layout[base+0x80:base+0x100]
    outputs={
      'cpz2_layout128.bin':header(128,16,fg),'cpz2_bg128.bin':header(128,16,bg),
      'cpz2_objects.bin':req['objects'].read_bytes(),'cpz2_rings.bin':req['rings'].read_bytes(),
      'cpz2_start.bin':req['start'].read_bytes(),
    }
    S2TEST.mkdir(parents=True,exist_ok=True)
    for n,b in outputs.items(): (S2TEST/n).write_bytes(b)
    PAL.mkdir(parents=True,exist_ok=True)
    (PAL/'S2 Chemical Plant Underwater.bin').write_bytes(req['underwater'].read_bytes())

    sonic=req['sonicpal'].read_bytes(); cpz=req['cpzpal'].read_bytes()
    palettes=[trav.palette_line(sonic)]+[trav.palette_line(cpz[i*32:(i+1)*32]) for i in range(3)]
    banks=[('lever_spring',req['leverart'],req['levermap'],0,2),('water_platform',req['platformart'],req['platformmap'],3,1)]
    for folder,artp,mapp,basepal,frames in banks:
        raw=trav.nemesis_decode(artp.read_bytes()); maps=mapp.read_bytes(); dest=ASSET/folder; dest.mkdir(parents=True,exist_ok=True)
        for old in dest.glob('*.png'): old.unlink()
        for frame in range(frames): trav.render_mapping(raw,maps,frame,palettes,basepal).save(dest/f'{frame:02d}.png')

    obj=outputs['cpz2_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    manifest={
      'phase':93,'level':'Chemical Plant Zone Act 2','start':[be16(outputs['cpz2_start.bin'],0),be16(outputs['cpz2_start.bin'],2)],
      'limits':{'left':0,'right':0x2A80,'top':0,'bottom':0x720},'layout_128':[128,16],'background_128':[128,16],
      'object_records':len(obj)//6,'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'water':{'initial':0x710,'dynamic_trigger_x':0x1DE0,'target_after_trigger':0x510},
      'boss_event':'deferred to Phase 94 (LevEvents_CPZ2 / Object $5D)',
      'egg_prison':'placed $3E retained but intentionally inert until boss phase',
      'source_sha256':{k:sha(p.read_bytes()) for k,p in req.items()},'output_sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (S2TEST/'phase93_cpz2_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
