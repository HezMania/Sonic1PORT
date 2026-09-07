#!/usr/bin/env python3
"""Phase 126: retail Sonic 2 Sky Chase Zone foundation/completion.

Imports exact SCZ terrain, object/ring/start streams, WFZ/SCZ map data and PLC art,
reconstructs the SCZ object sprites, and adds the retail SCZ SMPS song.
"""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
TOOLS=P/'tools'; DATA=P/'data'/'s1'/'s2test'; PAL=P/'data'/'s1'/'palette'; SOUND=P/'data'/'s1'/'sound'; OUT=P/'assets'/'objects'/'s2_scz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
terrain=load('terrain126',TOOLS/'import_sonic2_level.py')
boss=load('boss126',TOOLS/'import_s2_ehz_boss.py')
trav=load('trav126',TOOLS/'import_s2_cpz_traversal_phase91.py')
pres=load('pres126',TOOLS/'import_s2_ehz_presentation.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def frame_count(m:bytes)->int:
    return be16(m,0)//2 if len(m)>=2 else 0

def render_family(src:Path, art_rel:str, map_rel:str, folder:str, base_pal:int, pals, limit:int|None=None):
    raw=boss.nemesis_decompress((src/art_rel).read_bytes()); maps=(src/map_rel).read_bytes()
    # ObjB2's mapping also references the pilot/player VRAM bank ($280/$2A0).
    # Leave those pieces transparent in the one-player native port while keeping
    # every Tornado piece; padding prevents the generic mapping renderer from
    # indexing beyond the object's own Nemesis art.
    raw = raw + bytes(max(0,0x2C0*32-len(raw))) if folder == 'tornado' else raw
    n=frame_count(maps)
    if limit is not None:n=min(n,limit)
    d=OUT/folder; d.mkdir(parents=True,exist_ok=True)
    for q in d.glob('*.png'):q.unlink()
    for i in range(n): trav.render_mapping(raw,maps,i,pals,base_pal).save(d/f'{i:02d}.png')
    return {'frames':n,'raw_bytes':len(raw),'map_bytes':len(maps)}

def add_song(src:Path):
    data=pres.saxman_decompress((src/'sound/music/SCZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x19E
    pres.label=lambda kind,off:f"S2SCZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data); song['id']=0x19E; song['name']='Sonic 2 - Sky Chase Zone'; song['header']['voice_label']='S2SCZ_Voices'
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x19E)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    return {'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']}

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_scz_phase126.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
    main_art=terrain.kosinski_decompress((src/'art/kosinski/WFZ_SCZ.bin').read_bytes())
    v=bytearray(0x800*32); v[:len(main_art)]=main_art
    plc=[
      ('art/nemesis/The Tornado.bin',0x500),('art/nemesis/Clouds.bin',0x54F),
      ('art/nemesis/Vertical spinning blades in WFZ.bin',0x561),('art/nemesis/Balkrie (jet badnik) from SCZ.bin',0x565),
      ('art/nemesis/Turtle badnik from SCZ.bin',0x38A),('art/nemesis/Bomber badnik from SCZ.bin',0x36E),
      ('art/nemesis/Horizontal spinning blades in WFZ.bin',0x3CD),
    ]
    plcmeta={}
    for rel,tile in plc:
        raw=boss.nemesis_decompress((src/rel).read_bytes()); off=tile*32
        if off+len(raw)>len(v): raise ValueError(f'PLC overflow {rel}')
        v[off:off+len(raw)]=raw; plcmeta[rel]={'tile':tile,'tiles':len(raw)//32}
    map16base=terrain.kosinski_decompress((src/'mappings/16x16/WFZ_SCZ.bin').read_bytes())
    map16=bytearray(0x1800); map16[:len(map16base)]=map16base
    map128=terrain.kosinski_decompress((src/'mappings/128x128/WFZ_SCZ.bin').read_bytes())
    layout=terrain.kosinski_decompress((src/'level/layout/SCZ.bin').read_bytes())
    cp=terrain.kosinski_decompress((src/'collision/WFZ and SCZ primary 16x16 collision index.bin').read_bytes())
    cs=terrain.kosinski_decompress((src/'collision/WFZ and SCZ secondary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(map128)==0x8000 and len(cp)==0x300 and len(cs)==0x300
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    outputs={
      'scz1_art.bin':bytes(v),'scz1_map16.bin':bytes(map16),'scz1_map128.bin':map128,
      'scz1_layout128.bin':header(128,16,fg),'scz1_bg128.bin':header(128,16,bg),
      'scz1_collision_primary.bin':cp,'scz1_collision_secondary.bin':cs,
      'scz1_objects.bin':(src/'level/objects/SCZ_1.bin').read_bytes(),
      'scz1_rings.bin':(src/'level/rings/SCZ_1.bin').read_bytes(),
      'scz1_start.bin':(src/'startpos/SCZ.bin').read_bytes(),
    }
    for n,b in outputs.items():(DATA/n).write_bytes(b)
    (PAL/'S2 Sky Chase Zone.bin').write_bytes((src/'art/palettes/SCZ.bin').read_bytes())
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); zone=(src/'art/palettes/SCZ.bin').read_bytes()
    pals=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    sprites={
      'tornado':render_family(src,'art/nemesis/The Tornado.bin','mappings/sprite/objB2_a.bin','tornado',0,pals),
      'cloud':render_family(src,'art/nemesis/Clouds.bin','mappings/sprite/objB3.bin','cloud',2,pals),
      'vprop':render_family(src,'art/nemesis/Vertical spinning blades in WFZ.bin','mappings/sprite/objB4.bin','vprop',1,pals),
      'hprop':render_family(src,'art/nemesis/Horizontal spinning blades in WFZ.bin','mappings/sprite/objB5.bin','hprop',1,pals),
      'balkiry':render_family(src,'art/nemesis/Balkrie (jet badnik) from SCZ.bin','mappings/sprite/objAC.bin','balkiry',0,pals),
      'turtloid':render_family(src,'art/nemesis/Turtle badnik from SCZ.bin','mappings/sprite/obj9C.bin','turtloid',0,pals),
      'nebula':render_family(src,'art/nemesis/Bomber badnik from SCZ.bin','mappings/sprite/obj99.bin','nebula',1,pals),
    }
    music=add_song(src)
    obj=outputs['scz1_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    manifest={'phase':126,'level':'Sky Chase Zone','start':[be16(outputs['scz1_start.bin'],0),be16(outputs['scz1_start.bin'],2)],
      'limits':{'left':0,'right':0x3FFF,'top':0,'bottom':0x500},'layout':[128,16],
      'main_art_bytes':len(main_art),'map16_bytes':len(map16base),'map128_bytes':len(map128),
      'objects':len(obj)//6,'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'events':{'vx0':1,'turn_x':0x1180,'down_y':0x500,'stop_x':0x1400,'finish_player_x':0x1568},
      'plc':plcmeta,'sprites':sprites,'music':music,'sha256':{k:sha(v) for k,v in outputs.items()}}
    (DATA/'phase126_scz_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
