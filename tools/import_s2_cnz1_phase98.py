#!/usr/bin/env python3
"""Phase 98: import retail Sonic 2 Casino Night Act 1 terrain/presentation data."""
from __future__ import annotations
import hashlib, importlib.util, json, re, sys
from collections import Counter
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'tools'; OUT=PROJECT/'data'/'s1'; S2TEST=OUT/'s2test'; PAL=OUT/'palette'; SOUND=OUT/'sound'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain_phase98',TOOLS/'import_sonic2_level.py')
pres=load('pres_phase98',TOOLS/'import_s2_ehz_presentation.py')

def sha(b): return hashlib.sha256(b).hexdigest()
def be16(b,o): return (b[o]<<8)|b[o+1]
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def extract_apm(src:Path):
    text=(src/'s2.lst').read_text(errors='replace')
    m=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_CNZ label \*',text)
    if not m: raise ValueError('APM_CNZ not found')
    start=int(m.group(1),16)
    rom=(src/'s2built.bin').read_bytes()
    dest=be16(rom,start); words=be16(rom,start+2)+1
    patch=rom[start+4:start+4+words*2]
    if len(patch)!=0xA0 or dest!=0x1760: raise ValueError((dest,len(patch)))
    return dest,patch

def seed_art(src:Path, resident:bytes):
    # Retail CNZ resident art ends exactly at tile $330. Dynamic_Normal supplies
    # two 16-tile flipping banks at $330 and $540; SlotMachine supplies three
    # 16-tile picture banks at $550/$560/$570. Seed the source's initial state.
    v=bytearray(0x800*32); v[:len(resident)]=resident
    flip=(src/'art/uncompressed/Flipping foreground section (CNZ).bin').read_bytes()
    slot=(src/'art/uncompressed/Slot pictures.bin').read_bytes()
    for dst,source_tile in ((0x540,0x00),(0x330,0x70)):
        piece=flip[source_tile*32:(source_tile+0x10)*32]
        if len(piece)!=0x10*32: raise ValueError('CNZ flip source short')
        v[dst*32:(dst+0x10)*32]=piece
    for i,dst in enumerate((0x550,0x560,0x570)):
        piece=slot[i*0x10*32:(i+1)*0x10*32]
        if len(piece)!=0x10*32: raise ValueError('CNZ slot source short')
        v[dst*32:(dst+0x10)*32]=piece
    return bytes(v),flip

def add_song(src:Path):
    data=pres.saxman_decompress((src/'sound/music/CNZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x199
    pres.label=lambda kind,off:f"S2CNZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data); song['id']=0x199; song['name']='Sonic 2 - Casino Night Zone'; song['header']['voice_label']='S2CNZ_Voices'
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x199)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    # CNZ uses only DAC event IDs 0 and 1, already retained by the EHZ import.
    return song

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_cnz1_phase98.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); S2TEST.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True); SOUND.mkdir(parents=True,exist_ok=True)
    req={
      'art':src/'art/kosinski/CNZ.bin','map16':src/'mappings/16x16/CNZ.bin','map128':src/'mappings/128x128/CNZ.bin',
      'layout':src/'level/layout/CNZ_1.bin','objects':src/'level/objects/CNZ_1.bin','rings':src/'level/rings/CNZ_1.bin','start':src/'startpos/CNZ_1.bin',
      'colp':src/'collision/CNZ primary 16x16 collision index.bin','cols':src/'collision/CNZ secondary 16x16 collision index.bin',
      'pal':src/'art/palettes/CNZ.bin','cyc1':src/'art/palettes/CNZ Cycle 1.bin','cyc3':src/'art/palettes/CNZ Cycle 3.bin','cyc4':src/'art/palettes/CNZ Cycle 4.bin',
      'flip':src/'art/uncompressed/Flipping foreground section (CNZ).bin','slot':src/'art/uncompressed/Slot pictures.bin','music':src/'sound/music/CNZ.bin',
    }
    for p in req.values():
        if not p.is_file(): raise FileNotFoundError(p)
    resident=terrain.kosinski_decompress(req['art'].read_bytes())
    art,flip=seed_art(src,resident)
    base16=terrain.kosinski_decompress(req['map16'].read_bytes()); dest,patch=extract_apm(src)
    map16=bytearray(0x1800); map16[:len(base16)]=base16; map16[dest:dest+len(patch)]=patch; map16=bytes(map16)
    map128=terrain.kosinski_decompress(req['map128'].read_bytes()); layout=terrain.kosinski_decompress(req['layout'].read_bytes())
    colp=terrain.kosinski_decompress(req['colp'].read_bytes()); cols=terrain.kosinski_decompress(req['cols'].read_bytes())
    if len(resident)!=0x6600 or len(layout)!=0x1000 or len(map128)!=0x8000: raise ValueError((len(resident),len(layout),len(map128)))
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        base=row*0x100; fg+=layout[base:base+0x80]; bg+=layout[base+0x80:base+0x100]
    outputs={
      'cnz1_art.bin':art,'cnz1_map16.bin':map16,'cnz1_map128.bin':map128,
      'cnz1_layout128.bin':header(128,16,fg),'cnz1_bg128.bin':header(128,16,bg),
      'cnz1_collision_primary.bin':colp,'cnz1_collision_secondary.bin':cols,
      'cnz1_objects.bin':req['objects'].read_bytes(),'cnz1_rings.bin':req['rings'].read_bytes(),'cnz1_start.bin':req['start'].read_bytes(),
      's2_cnz_flip_tiles.bin':flip,
    }
    for n,b in outputs.items(): (S2TEST/n).write_bytes(b)
    (PAL/'S2 Casino Night Zone.bin').write_bytes(req['pal'].read_bytes())
    (PAL/'S2 CNZ Cycle 1.bin').write_bytes(req['cyc1'].read_bytes())
    (PAL/'S2 CNZ Cycle 3.bin').write_bytes(req['cyc3'].read_bytes())
    (PAL/'S2 CNZ Cycle 4.bin').write_bytes(req['cyc4'].read_bytes())
    song=add_song(src)
    obj=outputs['cnz1_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    supported={0x03,0x0D,0x26,0x36,0x41,0x74,0x79}; shared=sum(v for k,v in counts.items() if k in supported)
    manifest={
      'phase':98,'level':'Casino Night Zone Act 1','start':[be16(outputs['cnz1_start.bin'],0),be16(outputs['cnz1_start.bin'],2)],
      'limits':{'left':0,'right':0x27A0,'top':0,'bottom':0x720},'layout_128':[128,16],'background_128':[128,16],
      'resident_art_bytes':len(resident),'map16_base_bytes':len(base16),'map16_apm':{'destination':dest,'bytes':len(patch)},
      'object_records':len(obj)//6,'supported_shared_records':shared,'deferred_cnz_specific_records':len(obj)//6-shared,
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'music':{'id':0x199,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']},
      'output_sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (S2TEST/'phase98_cnz1_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
