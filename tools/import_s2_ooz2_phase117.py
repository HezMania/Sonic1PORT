#!/usr/bin/env python3
"""Phase 117: retail Sonic 2 Oil Ocean Act 2 data/traversal foundation."""
from __future__ import annotations
import hashlib, importlib.util, json, shutil, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
DATA=P/'data'/'s1'/'s2test'
ASSET=P/'assets'/'objects'/'s2_ooz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain117',P/'tools'/'import_sonic2_level.py')
trav=load('trav117',P/'tools'/'import_s2_cpz_traversal_phase91.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def save_bank(raw,maps,folder,pals,base):
    d=ASSET/folder; d.mkdir(parents=True,exist_ok=True)
    for p in d.glob('*.png'): p.unlink()
    frames=be16(maps,0)//2
    for i in range(frames):
        trav.render_mapping(raw,maps,i,pals,base).save(d/f'{i:02d}.png')
    return frames

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_ooz2_phase117.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True); ASSET.mkdir(parents=True,exist_ok=True)
    req={
      'layout':src/'level/layout/OOZ_2.bin', 'objects':src/'level/objects/OOZ_2.bin',
      'rings':src/'level/rings/OOZ_2.bin', 'start':src/'startpos/OOZ_2.bin',
      'obj15_map':src/'mappings/sprite/obj15_a.bin','obj43_map':src/'mappings/sprite/obj43.bin','obj45_map':src/'mappings/sprite/obj45.bin',
      'sonic_palette':src/'art/palettes/SonicAndTails.bin','zone_palette':src/'art/palettes/OOZ.bin',
    }
    for f in req.values():
        if not f.is_file(): raise FileNotFoundError(f)

    layout=terrain.kosinski_decompress(req['layout'].read_bytes())
    if len(layout)!=0x1000: raise ValueError(f'OOZ2 layout {len(layout):#x} != $1000')
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        o=row*0x100; fg+=layout[o:o+0x80]; bg+=layout[o+0x80:o+0x100]

    # Both acts share the exact OOZ art/mappings/collision bank. Keep explicit
    # Act 2 copies so the catalog and validator are self-contained.
    for suffix in ['art','map16','map128','collision_primary','collision_secondary']:
        srcp=DATA/f'ooz1_{suffix}.bin'
        if not srcp.is_file(): raise FileNotFoundError(srcp)
        (DATA/f'ooz2_{suffix}.bin').write_bytes(srcp.read_bytes())

    outputs={
      'ooz2_layout128.bin':header(128,16,fg), 'ooz2_bg128.bin':header(128,16,bg),
      'ooz2_objects.bin':req['objects'].read_bytes(), 'ooz2_rings.bin':req['rings'].read_bytes(),
      'ooz2_start.bin':req['start'].read_bytes(),
    }
    for n,b in outputs.items(): (DATA/n).write_bytes(b)

    # Obj43/45 are the only OOZ2 placement families not already reconstructed in
    # Phase 116. Render their source mappings through the exact Phase115 OOZ VRAM
    # image and current OOZ/Sonic CRAM lines.
    art=(DATA/'ooz1_art.bin').read_bytes()
    sonic=req['sonic_palette'].read_bytes(); zone=req['zone_palette'].read_bytes()
    pals=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    frames15=save_bank(art[0x3E3*32:], req['obj15_map'].read_bytes(), 'swing', pals, 2)
    frames43=save_bank(art[0x30C*32:], req['obj43_map'].read_bytes(), 'sliding_spike', pals, 2)
    frames45=save_bank(art[0x3C5*32:], req['obj45_map'].read_bytes(), 'pressure_spring', pals, 2)

    obj=outputs['ooz2_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    routed={0x15,0x19,0x1C,0x1F,0x26,0x33,0x36,0x3D,0x3E,0x3F,0x41,0x43,0x45,0x48,0x4A,0x50,0x74,0x79}
    manifest={
      'phase':117,'level':'Oil Ocean Zone Act 2',
      'start':[be16(outputs['ooz2_start.bin'],0),be16(outputs['ooz2_start.bin'],2)],
      'limits':{'left':0,'right':0x2D00,'top':0,'bottom':0x680},
      'layout_128':[128,16],'background_128':[128,16],
      'object_records':len(obj)//6,
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'native_routed_records':sum(v for k,v in counts.items() if k in routed),
      'boss_gated_egg_prison_records':counts.get(0x3E,0),
      'new_object_frames':{'15':frames15,'43':frames43,'45':frames45},
      'dynamic_event':{'oil_raise_x':0x2668,'oil_y':0x2D8,'camera_max_y':0x1E0,'arena_x':0x2880,'arena_right':0x28C0,'screen_shift':0x5A},
      'boss':'Object $55 / boss palette/music/ScreenShift completion deferred to Phase 118',
      'source_sha256':{k:sha(v.read_bytes()) for k,v in req.items()},
      'output_sha256':{k:sha(v) for k,v in outputs.items()},
      'asset_sha256':{},
    }
    for d in [ASSET/'swing',ASSET/'sliding_spike',ASSET/'pressure_spring']:
        for p in sorted(d.glob('*.png')):
            manifest['asset_sha256'][str(p.relative_to(ASSET))]=sha(p.read_bytes())
    (DATA/'phase117_ooz2_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
