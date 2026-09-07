#!/usr/bin/env python3
"""Phase 122: retail Sonic 2 Metropolis Zone Act 2 foundation.

Imports the exact retail MTZ2 terrain/layout/collision/object/ring/start streams,
reconstructs the assembled APM_MTZ 16x16 tail, seeds the Dynamic_Normal animated
VRAM slots, loads the retail MTZ PLC art bank, palette cycles, and SMPS music.
Existing MTZ object families remain active; Act-2-only object families are preserved
byte-for-byte but namespace-blocked for the next dedicated completion pass.
"""
from __future__ import annotations
import hashlib, importlib.util, json, re, sys
from collections import Counter
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'tools'; OUT=PROJECT/'data'/'s1'; DATA=OUT/'s2test'; PAL=OUT/'palette'; SOUND=OUT/'sound'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain122',TOOLS/'import_sonic2_level.py')
bossutil=load('bossutil122',TOOLS/'import_s2_ehz_boss.py')
pres=load('pres122',TOOLS/'import_s2_ehz_presentation.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

# Retail PlrList_Mtz1 + PlrList_Mtz2 destinations from s2.constants.asm.
PLC=[
 ('art/nemesis/Shellcracker badnik from MTZ.bin',0x31C),
 ('art/nemesis/Exploding star badnik from MTZ.bin',0x368),
 ('art/nemesis/Large spinning wheel from MTZ.bin',0x378),
 ('art/nemesis/Large spinning wheel from MTZ - indent.bin',0x3F0),
 ('art/nemesis/Lava cup from MTZ.bin',0x3F9),
 ('art/nemesis/Bolt end and rope from MTZ.bin',0x3FD),
 ('art/nemesis/Steam from MTZ.bin',0x405),
 ('art/nemesis/MTZ spike block.bin',0x414),
 ('art/nemesis/Spike from MTZ.bin',0x41C),
 ('art/nemesis/Button.bin',0x424),
 ('art/nemesis/Spikes.bin',0x434),
 ('art/nemesis/Praying mantis badnik from MTZ.bin',0x43C),
 ('art/nemesis/Vertical spring.bin',0x45C),
 ('art/nemesis/Horizontal spring.bin',0x470),
 ('art/nemesis/Similarly shaded blocks from MTZ.bin',0x500),
 ('art/nemesis/Lava bubble from MTZ.bin',0x536),
 ('art/nemesis/Small cog from MTZ.bin',0x55F),
 ('art/nemesis/Spin tube flash from MTZ.bin',0x56B),
]

ANIM=[
 ('mtz_cylinder.bin','art/uncompressed/Spinning metal cylinder (MTZ).bin',0x34C,16,0),
 ('mtz_lava.bin','art/uncompressed/Lava.bin',0x340,12,0),
 ('mtz_anim_back.bin','art/uncompressed/Animated section of MTZ background.bin',0x35C,6,0),
 # Second six-tile destination starts on source frame $C (tile 12), matching
 # the first entry of the retail reverse phase script.
 ('mtz_anim_back2_seed.bin','art/uncompressed/Animated section of MTZ background.bin',0x362,6,12),
]

def extract_apm_mtz(src:Path)->tuple[int,bytes]:
    text=(src/'s2.lst').read_text(errors='replace')
    ms=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_MTZ label \*',text)
    me=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_MTZ_End:',text)
    if not ms or not me: raise ValueError('Could not locate APM_MTZ in s2.lst')
    start=int(ms.group(1),16); end=int(me.group(1),16); rom=(src/'s2built.bin').read_bytes()
    dest=be16(rom,start); count=be16(rom,start+2); patch=rom[start+4:end]
    expected=(count+1)*2
    if len(patch)!=expected: raise ValueError(f'APM_MTZ length mismatch {len(patch):#x}!={expected:#x}')
    if dest+len(patch)!=0x1800: raise ValueError(f'APM_MTZ end mismatch {dest:#x}+{len(patch):#x}')
    return dest,patch

def build_art(src:Path)->tuple[bytes,dict,dict[str,bytes]]:
    main=terrain.kosinski_decompress((src/'art/kosinski/MTZ.bin').read_bytes())
    assert len(main)==0x6300, hex(len(main))
    v=bytearray(0x800*32); v[:len(main)]=main
    meta={'main_bytes':len(main),'main_tiles':len(main)//32,'animated':{},'plc':{}}
    retained={}
    for outname,rel,tile,tiles_per_frame,src_tile in ANIM:
        raw=(src/rel).read_bytes()
        # Save each unique source under the canonical runtime filename; the
        # second background seed uses the same retained source file.
        if rel.endswith('Animated section of MTZ background.bin'):
            retained['mtz_anim_back.bin']=raw
        else:
            retained[outname]=raw
        n=tiles_per_frame*32; so=src_tile*32
        v[tile*32:tile*32+n]=raw[so:so+n]
        meta['animated'][f'{rel}@{tile:03X}']={'tile':tile,'source_tile':src_tile,'source_bytes':len(raw),'seed_bytes':n,'tiles_per_frame':tiles_per_frame}
    for rel,tile in PLC:
        raw=bossutil.nemesis_decompress((src/rel).read_bytes())
        off=tile*32
        if off+len(raw)>len(v): raise ValueError(f'PLC overflow: {rel}')
        v[off:off+len(raw)]=raw
        meta['plc'][f'{rel}@{tile:03X}']={'source':rel,'tile':tile,'tiles':len(raw)//32,'bytes':len(raw)}
    return bytes(v),meta,retained

def build_map16(src:Path)->tuple[bytes,dict]:
    base=terrain.kosinski_decompress((src/'mappings/16x16/MTZ.bin').read_bytes())
    dest,patch=extract_apm_mtz(src)
    out=bytearray(0x1800); out[:len(base)]=base; out[dest:dest+len(patch)]=patch
    return bytes(out),{'base_bytes':len(base),'apm_offset':dest,'apm_bytes':len(patch)}

def add_song(src:Path):
    data=pres.saxman_decompress((src/'sound/music/MTZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x19D
    pres.label=lambda kind,off:f"S2MTZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data); song['id']=0x19D; song['name']='Sonic 2 - Metropolis Zone'; song['header']['voice_label']='S2MTZ_Voices'
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x19D)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    return song

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_mtz2_phase122.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True)
    art,artmeta,retained=build_art(src); map16,mapmeta=build_map16(src)
    map128=terrain.kosinski_decompress((src/'mappings/128x128/MTZ.bin').read_bytes())
    layout=terrain.kosinski_decompress((src/'level/layout/MTZ_2.bin').read_bytes())
    col=terrain.kosinski_decompress((src/'collision/MTZ primary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(map128)==0x8000 and len(col)==0x300
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    outputs={
      'mtz2_art.bin':art,'mtz2_map16.bin':map16,'mtz2_map128.bin':map128,
      'mtz2_layout128.bin':header(128,16,fg),'mtz2_bg128.bin':header(128,16,bg),
      'mtz2_collision_primary.bin':col,'mtz2_collision_secondary.bin':col,
      'mtz2_objects.bin':(src/'level/objects/MTZ_2.bin').read_bytes(),
      'mtz2_rings.bin':(src/'level/rings/MTZ_2.bin').read_bytes(),
      'mtz2_start.bin':(src/'startpos/MTZ_2.bin').read_bytes(),
    }
    for n,b in outputs.items(): (DATA/n).write_bytes(b)
    for n,b in retained.items(): (DATA/n).write_bytes(b)
    (PAL/'S2 Metropolis Zone.bin').write_bytes((src/'art/palettes/MTZ.bin').read_bytes())
    (PAL/'S2 MTZ Cycle 1.bin').write_bytes((src/'art/palettes/MTZ Cycle 1.bin').read_bytes())
    (PAL/'S2 MTZ Cycle 2.bin').write_bytes((src/'art/palettes/MTZ Cycle 2.bin').read_bytes())
    (PAL/'S2 MTZ Cycle 3.bin').write_bytes((src/'art/palettes/MTZ Cycle 3.bin').read_bytes())
    song=add_song(src)
    obj=outputs['mtz2_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    active_ids={0x0D,0x26,0x36,0x41,0x42,0x47,0x64,0x65,0x66,0x67,0x68,0x69,0x6B,0x6D,0x74,0x79,0x9F,0xA1,0xA4,0x06,0x1C,0x2D}
    active=sum(v for k,v in counts.items() if k in active_ids)
    manifest={
      'phase':122,'level':'Metropolis Zone Act 2',
      'start':[be16(outputs['mtz2_start.bin'],0),be16(outputs['mtz2_start.bin'],2)],
      'limits':{'left':0,'right':0x1E80,'top':-0x100,'bottom':0x800},
      'layout':[128,16],'background_scroll':{'x_divisor':8,'y_divisor':4},
      'art':artmeta,'map16':mapmeta,'map128_bytes':len(map128),'collision_bytes':len(col),
      'objects':len(obj)//6,'rings':len(outputs['mtz2_rings.bin'])//6,
      'active_existing_records':active,'deferred_act2_specific_records':len(obj)//6-active,
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'palette_cycles':{'cycle1_frames':6,'cycle1_period':18,'cycle2_frames':3,'cycle2_period':3,'cycle3_frames':10,'cycle3_period':10},
      'music':{'id':0x19D,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']},
      'sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (DATA/'phase122_mtz2_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
