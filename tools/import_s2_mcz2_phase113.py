#!/usr/bin/env python3
"""Phase 113: retail Sonic 2 Mystic Cave Act 2 terrain/data foundation."""
from __future__ import annotations
import hashlib, importlib.util, json, shutil, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
DATA=P/'data'/'s1'/'s2test'
ASSET=P/'assets'/'objects'/'s2_mcz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain113',P/'tools'/'import_sonic2_level.py')
trav=load('trav113',P/'tools'/'import_s2_cpz_traversal_phase91.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_mcz2_phase113.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True)
    req={
      'layout':src/'level/layout/MCZ_2.bin', 'objects':src/'level/objects/MCZ_2.bin',
      'rings':src/'level/rings/MCZ_2.bin', 'start':src/'startpos/MCZ_2.bin',
      'lever_art':src/'art/nemesis/Lever spring.bin', 'lever_map':src/'mappings/sprite/obj40.bin',
      'sonic_palette':src/'art/palettes/SonicAndTails.bin', 'zone_palette':src/'art/palettes/MCZ.bin',
    }
    for f in req.values():
        if not f.is_file(): raise FileNotFoundError(f)

    layout=terrain.kosinski_decompress(req['layout'].read_bytes())
    if len(layout)!=0x1000: raise ValueError(f'MCZ2 layout {len(layout):#x} != $1000')
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        o=row*0x100; fg += layout[o:o+0x80]; bg += layout[o+0x80:o+0x100]

    # MCZ acts share art, mappings and collision. Keep act-specific copies so the
    # catalog remains self-contained and Phase 113 validation can prove exactly
    # which data the Act 2 definition consumes.
    common=['art','map16','map128','collision_primary','collision_secondary']
    for suffix in common:
        srcp=DATA/f'mcz1_{suffix}.bin'
        if not srcp.is_file(): raise FileNotFoundError(srcp)
        (DATA/f'mcz2_{suffix}.bin').write_bytes(srcp.read_bytes())

    outputs={
      'mcz2_layout128.bin':header(128,16,fg), 'mcz2_bg128.bin':header(128,16,bg),
      'mcz2_objects.bin':req['objects'].read_bytes(), 'mcz2_rings.bin':req['rings'].read_bytes(),
      'mcz2_start.bin':req['start'].read_bytes(),
    }
    for n,b in outputs.items(): (DATA/n).write_bytes(b)

    # Obj40 is shared code/art, but the Genesis maps it through the current zone
    # CRAM. Re-render its two source frames with the MCZ palette rather than
    # reusing CPZ's precomposited RGBA textures.
    sonic=req['sonic_palette'].read_bytes(); zone=req['zone_palette'].read_bytes()
    palettes=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    raw=trav.nemesis_decode(req['lever_art'].read_bytes()); maps=req['lever_map'].read_bytes()
    dest=ASSET/'lever_spring'; dest.mkdir(parents=True,exist_ok=True)
    for old in dest.glob('*.png'): old.unlink()
    for frame in range(2): trav.render_mapping(raw,maps,frame,palettes,0).save(dest/f'{frame:02d}.png')

    obj=outputs['mcz2_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    traversal_supported={0x0D,0x15,0x1F,0x26,0x2A,0x36,0x40,0x41,0x6A,0x75,0x76,0x77,0x79,0x7A,0x7F,0x80,0x81,0x9E,0xA3}
    active=sum(v for k,v in counts.items() if k in traversal_supported and k not in {0x0D,0x3E})
    manifest={
      'phase':113,'level':'Mystic Cave Zone Act 2',
      'start':[be16(outputs['mcz2_start.bin'],0),be16(outputs['mcz2_start.bin'],2)],
      'limits':{'left':0,'right':0x3FFF,'top':0x60,'bottom':0x720},
      'layout_128':[128,16],'background_128':[128,16],
      'object_records':len(obj)//6,'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'native_routed_records':len(obj)//6,'active_traversal_records':active,'act2_disabled_signpost_records':counts.get(0x0D,0),'boss_gated_egg_prison_records':counts.get(0x3E,0),
      'dynamic_event':{'trigger_x':0x2080,'arena_x':0x20F0,'bottom':0x5D0,'top_lock_y':0x5C8,'screen_shift':0x5A},
      'boss':'Object $57 / complete boss sequence deferred to Phase 114',
      'source_sha256':{k:sha(v.read_bytes()) for k,v in req.items()},
      'output_sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (DATA/'phase113_mcz2_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
