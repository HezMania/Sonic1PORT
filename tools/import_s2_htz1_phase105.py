#!/usr/bin/env python3
"""Phase 105: retail Sonic 2 Hill Top Act 1 terrain/presentation foundation."""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from collections import Counter
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'tools'; OUT=PROJECT/'data'/'s1'; S2TEST=OUT/'s2test'; PAL=OUT/'palette'; SOUND=OUT/'sound'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain_htz105',TOOLS/'import_sonic2_level.py')
pres=load('pres_htz105',TOOLS/'import_s2_ehz_presentation.py')
bossutil=load('bossutil_htz105',TOOLS/'import_s2_ehz_boss.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def build_art(src:Path)->tuple[bytes,dict]:
    main=terrain.kosinski_decompress((src/'art/kosinski/EHZ_HTZ.bin').read_bytes())
    supp=terrain.kosinski_decompress((src/'art/kosinski/HTZ_Supp.bin').read_bytes())
    v=bytearray(0x800*32)
    v[:len(main)]=main
    # LoadZoneTiles patches HTZ supplemental art at tile $1FC, overwriting the
    # EHZ tail exactly as the retail loader does.
    dst=0x1FC*32; v[dst:dst+len(supp)]=supp
    # HTZ shares APM_EHZ's flower/pulse destinations. Seed their first retail
    # animation frames so the map patch is meaningful before a dynamic-art pass.
    seeded={}
    entries=[
      ('art/uncompressed/EHZ and HTZ flowers - 1.bin',0x394,0),
      ('art/uncompressed/EHZ and HTZ flowers - 2.bin',0x396,2),
      ('art/uncompressed/EHZ and HTZ flowers - 3.bin',0x398,0),
      ('art/uncompressed/EHZ and HTZ flowers - 4.bin',0x39A,0),
      ('art/uncompressed/Pulsing ball against checkered background (EHZ).bin',0x39C,0),
    ]
    for rel,dt,st in entries:
        raw=(src/rel).read_bytes(); piece=raw[st*32:(st+2)*32]
        v[dt*32:dt*32+len(piece)]=piece; seeded[rel]={'tile':dt,'bytes':len(piece)}
    # Dynamic_HTZ streams 24 cliff tiles to $500 and an 8-tile cloud slice to
    # $518. Seed source frame zero; runtime dynamic mountain selection remains a
    # later fidelity pass, but the authored background is never blank.
    cliffs=bossutil.nemesis_decompress((src/'art/nemesis/Dynamically reloaded cliffs in HTZ background.bin').read_bytes())
    v[0x500*32:0x518*32]=cliffs[:0x18*32]
    clouds=(src/'art/uncompressed/Background clouds (HTZ).bin').read_bytes()
    v[0x518*32:0x520*32]=clouds[:8*32]
    return bytes(v), {'main':len(main),'supp':len(supp),'supp_tile':0x1FC,'cliffs':len(cliffs),'clouds':len(clouds),'seeded':seeded}

def build_map16(src:Path)->tuple[bytes,dict]:
    base=terrain.kosinski_decompress((src/'mappings/16x16/EHZ.bin').read_bytes())
    patch=terrain.kosinski_decompress((src/'mappings/16x16/HTZ.bin').read_bytes())
    dest,apm=terrain.extract_apm_ehz(src)
    out=bytearray(0x1800); out[:len(base)]=base; out[0x980:0x980+len(patch)]=patch; out[dest:dest+len(apm)]=apm
    return bytes(out), {'base':len(base),'htz_patch_offset':0x980,'htz_patch':len(patch),'apm_offset':dest,'apm':len(apm)}

def add_song(src:Path):
    data=pres.saxman_decompress((src/'sound/music/HTZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x19A
    pres.label=lambda kind,off:f"S2HTZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data); song['id']=0x19A; song['name']='Sonic 2 - Hill Top Zone'; song['header']['voice_label']='S2HTZ_Voices'
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x19A)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    return song

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_htz1_phase105.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); S2TEST.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True)
    art,artmeta=build_art(src); map16,mapmeta=build_map16(src)
    map128=terrain.kosinski_decompress((src/'mappings/128x128/EHZ_HTZ.bin').read_bytes())
    layout=terrain.kosinski_decompress((src/'level/layout/HTZ_1.bin').read_bytes())
    colp=terrain.kosinski_decompress((src/'collision/EHZ and HTZ primary 16x16 collision index.bin').read_bytes())
    cols=terrain.kosinski_decompress((src/'collision/EHZ and HTZ secondary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(map128)==0x8000
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    outputs={
      'htz1_art.bin':art,'htz1_map16.bin':map16,'htz1_map128.bin':map128,
      'htz1_layout128.bin':header(128,16,fg),'htz1_bg128.bin':header(128,16,bg),
      'htz1_collision_primary.bin':colp,'htz1_collision_secondary.bin':cols,
      'htz1_objects.bin':(src/'level/objects/HTZ_1.bin').read_bytes(),
      'htz1_rings.bin':(src/'level/rings/HTZ_1.bin').read_bytes(),
      'htz1_start.bin':(src/'startpos/HTZ_1.bin').read_bytes(),
    }
    for n,b in outputs.items(): (S2TEST/n).write_bytes(b)
    (PAL/'S2 Hill Top Zone.bin').write_bytes((src/'art/palettes/HTZ.bin').read_bytes())
    (PAL/'S2 Hill Top Lava Cycle.bin').write_bytes((src/'art/palettes/Hill Top Lava.bin').read_bytes())
    song=add_song(src)
    obj=outputs['htz1_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    existing={0x03,0x0D,0x18,0x1C,0x26,0x2D,0x32,0x36,0x41,0x74,0x79,0x84}
    shared=sum(v for k,v in counts.items() if k in existing)
    manifest={
      'phase':105,'level':'Hill Top Zone Act 1','start':[be16(outputs['htz1_start.bin'],0),be16(outputs['htz1_start.bin'],2)],
      'limits':{'left':0,'right':0x2800,'top':0,'bottom':0x720},'layout':[128,16],
      'art':artmeta,'map16':mapmeta,'objects':len(obj)//6,'already_shared_records':shared,
      'deferred_htz_specific_records':len(obj)//6-shared,'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'music':{'id':0x19A,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']},
      'sha256':{k:sha(v) for k,v in outputs.items()}
    }
    (S2TEST/'phase105_htz1_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
