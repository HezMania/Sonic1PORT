#!/usr/bin/env python3
"""Phase 128: retail Sonic 2 Wing Fortress Zone correction pass.

Imports the final-revision WFZ terrain/background, combined WFZ/SCZ art with the
WFZ supplement at its retail VRAM offset, exact collisions/start/rings/objects,
zone palette, core object mapping renders, and the retail WFZ SMPS song.
"""
from __future__ import annotations
import hashlib, importlib.util, json, sys, shutil
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
TOOLS=P/'tools'; DATA=P/'data'/'s1'/'s2test'; PAL=P/'data'/'s1'/'palette'; SOUND=P/'data'/'s1'/'sound'; OUT=P/'assets'/'objects'/'s2_wfz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
terrain=load('terrain127',TOOLS/'import_sonic2_level.py')
boss=load('boss127',TOOLS/'import_s2_ehz_boss.py')
trav=load('trav127',TOOLS/'import_s2_cpz_traversal_phase91.py')
pres=load('pres127',TOOLS/'import_s2_ehz_presentation.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)
def frame_count(m:bytes)->int: return be16(m,0)//2 if len(m)>=2 else 0

def render_family(src:Path, art_rel:str, map_rel:str, folder:str, base_pal:int, pals, limit:int|None=None):
    raw=boss.nemesis_decompress((src/art_rel).read_bytes()); maps=(src/map_rel).read_bytes()
    n=frame_count(maps)
    if limit is not None:n=min(n,limit)
    # Several shared mappings contain frames for other zones/PLC combinations.
    # Pad absent source banks transparently so those unused mapping frames can be
    # exported without inventing pixels; WFZ runtime selects only its source frame.
    required_tiles=len(raw)//32
    for fi in range(n):
        off=be16(maps,fi*2); count=be16(maps,off)
        for j in range(count):
            q=maps[off+2+j*8:off+10+j*8]
            if len(q)<8: continue
            size=q[1]; attr=be16(q,2); wt=((size>>2)&3)+1; ht=(size&3)+1
            required_tiles=max(required_tiles,(attr&0x7FF)+wt*ht)
    if len(raw)<required_tiles*32: raw=raw+bytes(required_tiles*32-len(raw))
    d=OUT/folder; d.mkdir(parents=True,exist_ok=True)
    for q in d.glob('*.png'):q.unlink()
    for i in range(n):
        try: trav.render_mapping(raw,maps,i,pals,base_pal).save(d/f'{i:02d}.png')
        except Exception as e:
            # Hook mappings address the art as if it were loaded eight tiles before
            # the PLC base. Prepending those transparent/source-relative tiles is
            # handled below by its caller; all other failures are fatal.
            raise RuntimeError(f'{folder} frame {i}: {e}') from e
    return {'frames':n,'tiles':len(raw)//32,'map_bytes':len(maps)}

def render_hook(src:Path,pals):
    raw=boss.nemesis_decompress((src/'art/nemesis/Hook on chain from WFZ.bin').read_bytes())
    # Obj80 loads the art at $3FA but sets art_tile to the source's $3FE
    # Hook_Fudge constant. Mapping tile 0 therefore starts at raw art tile 4.
    # A standalone renderer must drop those four leading source tiles; prepending
    # blanks (Phase127) shifted the relationship the wrong way and made all 13
    # hook frames transparent.
    raw=raw[4*32:]
    maps=(src/'mappings/sprite/obj80_b.bin').read_bytes(); n=frame_count(maps)
    d=OUT/'hook';d.mkdir(parents=True,exist_ok=True)
    for q in d.glob('*.png'):q.unlink()
    for i in range(n):trav.render_mapping(raw,maps,i,pals,1).save(d/f'{i:02d}.png')
    return {'frames':n,'tiles':len(raw)//32,'map_bytes':len(maps),'source_art_offset':-128}

def add_song(src:Path):
    data=pres.saxman_decompress((src/'sound/music/WFZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x19F
    pres.label=lambda kind,off:f"S2WFZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data); song['id']=0x19F; song['name']='Sonic 2 - Wing Fortress Zone'; song['header']['voice_label']='S2WFZ_Voices'
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x19F)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    return {'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']}

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_wfz_phase128.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
    main_art=terrain.kosinski_decompress((src/'art/kosinski/WFZ_SCZ.bin').read_bytes())
    supp=terrain.kosinski_decompress((src/'art/kosinski/WFZ_Supp.bin').read_bytes())
    supp_off=0x307*32
    v=bytearray(max(len(main_art),supp_off+len(supp)))
    v[:len(main_art)]=main_art; v[supp_off:supp_off+len(supp)]=supp
    map16base=terrain.kosinski_decompress((src/'mappings/16x16/WFZ_SCZ.bin').read_bytes())
    map16=bytearray(0x1800);map16[:len(map16base)]=map16base
    map128=terrain.kosinski_decompress((src/'mappings/128x128/WFZ_SCZ.bin').read_bytes())
    layout=terrain.kosinski_decompress((src/'level/layout/WFZ.bin').read_bytes())
    cp=terrain.kosinski_decompress((src/'collision/WFZ and SCZ primary 16x16 collision index.bin').read_bytes())
    cs=terrain.kosinski_decompress((src/'collision/WFZ and SCZ secondary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(map128)==0x8000 and len(cp)==0x300 and len(cs)==0x300
    fg=bytearray();bg=bytearray()
    for row in range(16):
        off=row*0x100;fg+=layout[off:off+0x80];bg+=layout[off+0x80:off+0x100]
    outputs={
      'wfz1_art.bin':bytes(v),'wfz1_map16.bin':bytes(map16),'wfz1_map128.bin':map128,
      'wfz1_layout128.bin':header(128,16,fg),'wfz1_bg128.bin':header(128,16,bg),
      'wfz1_collision_primary.bin':cp,'wfz1_collision_secondary.bin':cs,
      'wfz1_objects.bin':(src/'level/objects/WFZ_1.bin').read_bytes(),
      'wfz1_rings.bin':(src/'level/rings/WFZ_1.bin').read_bytes(),
      'wfz1_start.bin':(src/'startpos/WFZ.bin').read_bytes(),
    }
    for n,b in outputs.items():(DATA/n).write_bytes(b)
    pal=(src/'art/palettes/WFZ.bin').read_bytes();(PAL/'S2 Wing Fortress Zone.bin').write_bytes(pal)
    for source_name, port_name in [
        ('WFZ Fire Cycle.bin','S2 WFZ Fire Cycle.bin'),
        ('WFZ Conveyor Cycle.bin','S2 WFZ Conveyor Cycle.bin'),
        ('WFZ Cycle 1.bin','S2 WFZ Cycle 1.bin'),
        ('WFZ Cycle 2.bin','S2 WFZ Cycle 2.bin'),
    ]:
        (PAL/port_name).write_bytes((src/'art/palettes'/source_name).read_bytes())
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes()
    (PAL/'S2 Sonic and Tails.bin').write_bytes(sonic)
    pals=[trav.palette_line(sonic)]+[trav.palette_line(pal[i*32:(i+1)*32]) for i in range(3)]
    fam={
      'platform':('art/nemesis/Moving platform from WFZ.bin','mappings/sprite/obj19.bin',1),
      'clucker':('art/nemesis/Scratch from WFZ.bin','mappings/sprite/objAE.bin',0),
      'tornado':('art/nemesis/The Tornado.bin','mappings/sprite/objB2_a.bin',0),
      'vprop':('art/nemesis/Vertical spinning blades in WFZ.bin','mappings/sprite/objB4.bin',1),
      'hprop':('art/nemesis/Horizontal spinning blades in WFZ.bin','mappings/sprite/objB5.bin',1),
      'tilt':('art/nemesis/Tilting plaforms in WFZ.bin','mappings/sprite/objB6.bin',1),
      'turret':('art/nemesis/Wall turret from WFZ.bin','mappings/sprite/objB8.bin',0),
      'laser':('art/nemesis/Red horizontal laser from WFZ.bin','mappings/sprite/objB9.bin',2),
      'wheel':('art/nemesis/Wheel for belt in WFZ.bin','mappings/sprite/objBA.bin',2),
      'shipfire':("art/nemesis/Thrust from Robotnik's getaway ship in WFZ.bin",'mappings/sprite/objBC.bin',2),
      'beltplat':('art/nemesis/Platform on belt in WFZ.bin','mappings/sprite/objBD.bin',1),
      'retract':('art/nemesis/Retracting platform from WFZ.bin','mappings/sprite/objBE.bin',3),
      'launcher':('art/nemesis/Catapult that shoots Sonic to the side from WFZ.bin','mappings/sprite/objC0.bin',1),
      'breakpanel':('art/nemesis/Breakaway panels from WFZ.bin','mappings/sprite/objC1.bin',1),
      'rivet':('art/nemesis/WFZ boss chamber switch.bin','mappings/sprite/objC2.bin',1),
    }
    sprites={k:render_family(src,a,m,k,paln,pals) for k,(a,m,paln) in fam.items()}
    sprites['hook']=render_hook(src,pals)
    # WFZ ObjB2 uses the same dynamic pilot bank already reconstructed for SCZ.
    # Copy all five verified frames so a clean Phase128 import is reproducible.
    pilot_src=P/'assets'/'objects'/'s2_scz'/'pilot'; pilot_dst=OUT/'pilot'
    if pilot_dst.exists(): shutil.rmtree(pilot_dst)
    shutil.copytree(pilot_src,pilot_dst)
    sprites['pilot']={'frames':len(list(pilot_dst.glob('*.png'))),'source':'verified SCZ Tails pilot reconstruction'}
    music=add_song(src)
    obj=outputs['wfz1_objects.bin'];counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    manifest={'phase':128,'level':'Wing Fortress Zone','source_revision':'retail final','start':[be16(outputs['wfz1_start.bin'],0),be16(outputs['wfz1_start.bin'],2)],
      'limits':{'left':0,'right':0x3FFF,'top':0,'bottom':0x720},'layout':[128,16],
      'main_art_bytes':len(main_art),'supplement_bytes':len(supp),'supplement_tile':0x307,'combined_art_bytes':len(v),
      'map16_bytes':len(map16base),'map128_bytes':len(map128),'objects':len(obj)//6,
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},'rings_bytes':len(outputs['wfz1_rings.bin']),
      'events':{'boss_plc_gate':[0x2880,0x400],'lock_left':0x2880,'control_lock_y':0x500,'bg_transition':[0x2BC0,0x580]},
      'sprites':sprites,'music':music,'sha256':{k:sha(v) for k,v in outputs.items()}}
    (DATA/'phase128_wfz_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
