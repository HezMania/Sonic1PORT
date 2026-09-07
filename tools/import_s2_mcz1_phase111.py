#!/usr/bin/env python3
"""Phase 111: retail Sonic 2 Mystic Cave Act 1 terrain/presentation foundation."""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from collections import Counter
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'tools'; OUT=PROJECT/'data'/'s1'; DATA=OUT/'s2test'; PAL=OUT/'palette'; SOUND=OUT/'sound'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain111',TOOLS/'import_sonic2_level.py')
bossutil=load('bossutil111',TOOLS/'import_s2_ehz_boss.py')
pres=load('pres111',TOOLS/'import_s2_ehz_presentation.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

PLC=[
 ('art/nemesis/Firefly from MCZ.bin',0x3A8),
 ('art/nemesis/Snake badnik from MCZ.bin',0x3C0),
 ('art/nemesis/Large wooden box from MCZ.bin',0x3D4),
 ('art/nemesis/Collapsing platform from MCZ.bin',0x3F4),
 ('art/nemesis/Pull switch from MCZ.bin',0x40E),
 ('art/nemesis/Vine that lowers from MCZ.bin',0x41E),
 ('art/nemesis/Long horizontal spike.bin',0x42C),
 ('art/nemesis/Spikes.bin',0x434),
 ('art/nemesis/Drawbridge logs from MCZ.bin',0x43C),
 ('art/nemesis/Lever spring.bin',0x440),
 ('art/nemesis/Vertical spring.bin',0x45C),
 ('art/nemesis/Horizontal spring.bin',0x470),
]

def build_art(src:Path):
    main=terrain.kosinski_decompress((src/'art/kosinski/MCZ.bin').read_bytes())
    assert len(main)==0x3A8*32, hex(len(main))
    v=bytearray(0x800*32); v[:len(main)]=main
    meta={'main_bytes':len(main),'main_tiles':len(main)//32,'plc':{}}
    for rel,tile in PLC:
        raw=bossutil.nemesis_decompress((src/rel).read_bytes())
        off=tile*32; v[off:off+len(raw)]=raw
        meta['plc'][rel]={'tile':tile,'tiles':len(raw)//32,'bytes':len(raw)}
    return bytes(v),meta

def add_song(src:Path):
    song_bytes=pres.saxman_decompress((src/'sound/music/MCZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x19B
    pres.label=lambda kind,off:f"S2MCZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(song_bytes); song['id']=0x19B; song['name']='Sonic 2 - Mystic Cave Zone'; song['header']['voice_label']='S2MCZ_Voices'
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x19B)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    return song

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_mcz1_phase111.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True)
    art,artmeta=build_art(src)
    map16=terrain.kosinski_decompress((src/'mappings/16x16/MCZ.bin').read_bytes())
    map128=terrain.kosinski_decompress((src/'mappings/128x128/MCZ.bin').read_bytes())
    layout=terrain.kosinski_decompress((src/'level/layout/MCZ_1.bin').read_bytes())
    col=terrain.kosinski_decompress((src/'collision/MCZ primary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(map128)==0x8000 and len(col)==0x300
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    outputs={
      'mcz1_art.bin':art,
      'mcz1_map16.bin':map16,
      'mcz1_map128.bin':map128,
      'mcz1_layout128.bin':header(128,16,fg),
      'mcz1_bg128.bin':header(128,16,bg),
      'mcz1_collision_primary.bin':col,
      'mcz1_collision_secondary.bin':col,
      'mcz1_objects.bin':(src/'level/objects/MCZ_1.bin').read_bytes(),
      'mcz1_rings.bin':(src/'level/rings/MCZ_1.bin').read_bytes(),
      'mcz1_start.bin':(src/'startpos/MCZ_1.bin').read_bytes(),
    }
    for n,b in outputs.items(): (DATA/n).write_bytes(b)
    (PAL/'S2 Mystic Cave Zone.bin').write_bytes((src/'art/palettes/MCZ.bin').read_bytes())
    (PAL/'S2 Mystic Cave Lantern Cycle.bin').write_bytes((src/'art/palettes/MCZ Lantern.bin').read_bytes())
    song=add_song(src)
    obj=outputs['mcz1_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    # Only families already translated with zone-correct retail semantics are active
    # in this foundation. MCZ-specific families are retained byte-for-byte and
    # deliberately inert until their dedicated completion pass.
    active_ids={0x0D,0x26,0x36,0x41,0x74,0x79}
    active=sum(v for k,v in counts.items() if k in active_ids)
    manifest={
      'phase':111,'level':'Mystic Cave Zone Act 1',
      'start':[be16(outputs['mcz1_start.bin'],0),be16(outputs['mcz1_start.bin'],2)],
      'limits':{'left':0,'right':0x2380,'top':0x3C0,'bottom':0x720},
      'layout':[128,16],'background_repeat':[4,4],
      'art':artmeta,'map16_bytes':len(map16),'map128_bytes':len(map128),'collision_bytes':len(col),
      'objects':len(obj)//6,'active_shared_records':active,'deferred_mcz_specific_records':len(obj)//6-active,
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'music':{'id':0x19B,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']},
      'sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (DATA/'phase111_mcz1_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
