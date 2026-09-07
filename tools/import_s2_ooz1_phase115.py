#!/usr/bin/env python3
"""Phase 115: retail Sonic 2 Oil Ocean Act 1 terrain/presentation foundation.

The importer keeps the original S2 128x128 chunk, 16x16 block, collision,
object/ring/start and palette streams. OOZ's animated pattern mapping is stored
inside the assembled ROM, so APM_OOZ is recovered from the exact supplied
s2.lst/s2built.bin pair and patched into the decompressed Map16 table.
"""
from __future__ import annotations
import hashlib, importlib.util, json, re, sys
from collections import Counter
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'tools'; OUT=PROJECT/'data'/'s1'; DATA=OUT/'s2test'; PAL=OUT/'palette'; SOUND=OUT/'sound'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain115',TOOLS/'import_sonic2_level.py')
bossutil=load('bossutil115',TOOLS/'import_s2_ehz_boss.py')
pres=load('pres115',TOOLS/'import_s2_ehz_presentation.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

# Exact retail PLC destination tiles from s2.constants.asm. The duplicate four
# stripy-block source really is loaded twice, once vertical and once horizontal.
PLC=[
 ('art/nemesis/Green flame from OOZ burners.bin',0x2E2),
 ('art/nemesis/Rising platform from OOZ.bin',0x2F4),
 ('art/nemesis/Spiked ball from OOZ.bin',0x30C),
 ('art/nemesis/Burner Platform from OOZ.bin',0x32C),
 ('art/nemesis/4 stripy blocks from OOZ.bin',0x332),
 ('art/nemesis/Cascading oil hitting oil from OOZ.bin',0x336),
 ('art/nemesis/Cascading oil from OOZ.bin',0x346),
 ('art/nemesis/Ball on spring from OOZ (beta holdovers).bin',0x354),
 ('art/nemesis/Transporter ball from OOZ.bin',0x368),
 ('art/nemesis/OOZ collapsing platform.bin',0x39D),
 ('art/nemesis/Push spring from OOZ.bin',0x3C5),
 ('art/nemesis/Swinging platform from OOZ.bin',0x3E3),
 ('art/nemesis/4 stripy blocks from OOZ.bin',0x3FF),
 ('art/nemesis/Fan from OOZ.bin',0x403),
 ('art/nemesis/Button.bin',0x424),
 ('art/nemesis/Spikes.bin',0x434),
 ('art/nemesis/Diagonal spring.bin',0x43C),
 ('art/nemesis/Vertical spring.bin',0x45C),
 ('art/nemesis/Horizontal spring.bin',0x470),
 ('art/nemesis/Seahorse from OOZ.bin',0x500),
 ('art/nemesis/Octopus badnik from OOZ.bin',0x538),
]
ANIM=[
 ('ooz_pulse_ball.bin','art/uncompressed/Pulsing ball (OOZ).bin',0x2B6,4),
 ('ooz_square_ball1.bin','art/uncompressed/Square rotating around ball in OOZ - 1.bin',0x2BA,4),
 ('ooz_square_ball2.bin','art/uncompressed/Square rotating around ball in OOZ - 2.bin',0x2BE,4),
 ('ooz_oil1.bin','art/uncompressed/Oil - 1.bin',0x2C2,16),
 ('ooz_oil2.bin','art/uncompressed/Oil - 2.bin',0x2D2,16),
]

def extract_apm_ooz(src:Path)->tuple[int,bytes]:
    text=(src/'s2.lst').read_text(errors='replace')
    ms=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_OOZ label \*',text)
    me=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_OOZ_End:',text)
    if not ms or not me: raise ValueError('Could not locate APM_OOZ in s2.lst')
    start=int(ms.group(1),16); end=int(me.group(1),16); rom=(src/'s2built.bin').read_bytes()
    dest=be16(rom,start); count=be16(rom,start+2); patch=rom[start+4:end]
    expected=(count+1)*2
    if len(patch)!=expected: raise ValueError(f'APM_OOZ length mismatch {len(patch):#x}!={expected:#x}')
    if dest+len(patch)!=0x1800: raise ValueError(f'APM_OOZ end mismatch {dest:#x}+{len(patch):#x}')
    return dest,patch

def build_art(src:Path)->tuple[bytes,dict,dict[str,bytes]]:
    main=terrain.kosinski_decompress((src/'art/kosinski/OOZ.bin').read_bytes())
    assert len(main)==0x2A9*32, hex(len(main))
    v=bytearray(0x800*32); v[:len(main)]=main
    meta={'main_bytes':len(main),'main_tiles':len(main)//32,'animated':{},'plc':{}}
    retained={}
    for outname,rel,tile,tiles_per_frame in ANIM:
        raw=(src/rel).read_bytes(); retained[outname]=raw
        # Source VRAM is initialized before the first Dynamic_Normal tick. Seed
        # frame zero so APM_OOZ never references blank tiles on level entry.
        n=tiles_per_frame*32; v[tile*32:tile*32+n]=raw[:n]
        meta['animated'][rel]={'tile':tile,'source_bytes':len(raw),'seed_bytes':n,'tiles_per_frame':tiles_per_frame}
    for rel,tile in PLC:
        raw=bossutil.nemesis_decompress((src/rel).read_bytes())
        off=tile*32
        if off+len(raw)>len(v): raise ValueError(f'PLC overflow: {rel}')
        v[off:off+len(raw)]=raw
        meta['plc'][f'{rel}@{tile:03X}']={'source':rel,'tile':tile,'tiles':len(raw)//32,'bytes':len(raw)}
    return bytes(v),meta,retained

def build_map16(src:Path)->tuple[bytes,dict]:
    base=terrain.kosinski_decompress((src/'mappings/16x16/OOZ.bin').read_bytes())
    dest,patch=extract_apm_ooz(src)
    out=bytearray(0x1800); out[:len(base)]=base; out[dest:dest+len(patch)]=patch
    return bytes(out),{'base_bytes':len(base),'apm_offset':dest,'apm_bytes':len(patch)}

def add_song(src:Path):
    data=pres.saxman_decompress((src/'sound/music/OOZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x19C
    pres.label=lambda kind,off:f"S2OOZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data); song['id']=0x19C; song['name']='Sonic 2 - Oil Ocean Zone'; song['header']['voice_label']='S2OOZ_Voices'
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x19C)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    return song

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_ooz1_phase115.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True)
    art,artmeta,retained=build_art(src); map16,mapmeta=build_map16(src)
    map128=terrain.kosinski_decompress((src/'mappings/128x128/OOZ.bin').read_bytes())
    layout=terrain.kosinski_decompress((src/'level/layout/OOZ_1.bin').read_bytes())
    col=terrain.kosinski_decompress((src/'collision/OOZ primary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(map128)==0x8000 and len(col)==0x300
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    outputs={
      'ooz1_art.bin':art,'ooz1_map16.bin':map16,'ooz1_map128.bin':map128,
      'ooz1_layout128.bin':header(128,16,fg),'ooz1_bg128.bin':header(128,16,bg),
      'ooz1_collision_primary.bin':col,'ooz1_collision_secondary.bin':col,
      'ooz1_objects.bin':(src/'level/objects/OOZ_1.bin').read_bytes(),
      'ooz1_rings.bin':(src/'level/rings/OOZ_1.bin').read_bytes(),
      'ooz1_start.bin':(src/'startpos/OOZ_1.bin').read_bytes(),
    }
    for n,b in outputs.items(): (DATA/n).write_bytes(b)
    for n,b in retained.items(): (DATA/n).write_bytes(b)
    (PAL/'S2 Oil Ocean Zone.bin').write_bytes((src/'art/palettes/OOZ.bin').read_bytes())
    (PAL/'S2 Oil Ocean Oil Cycle.bin').write_bytes((src/'art/palettes/OOZ Oil.bin').read_bytes())
    song=add_song(src)
    obj=outputs['ooz1_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    # Phase 115 activates source-shared adapters plus global Object $07 oil.
    # Zone-specific object IDs stay byte-identical but are namespace-blocked
    # until the dedicated OOZ object pass so they cannot instantiate CPZ/ARZ/EHZ
    # objects that reuse the same numeric IDs.
    active_ids={0x0D,0x26,0x36,0x41,0x79}
    active=sum(v for k,v in counts.items() if k in active_ids)
    manifest={
      'phase':115,'level':'Oil Ocean Zone Act 1',
      'start':[be16(outputs['ooz1_start.bin'],0),be16(outputs['ooz1_start.bin'],2)],
      'limits':{'left':0,'right':0x2F80,'top':0,'bottom':0x680},
      'layout':[128,16],'background_cache':[6,4],
      'art':artmeta,'map16':mapmeta,'map128_bytes':len(map128),'collision_bytes':len(col),
      'objects':len(obj)//6,'active_shared_records':active,'deferred_ooz_specific_records':len(obj)//6-active,
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'global_oil_object':{'source_id':7,'y':0x758,'width':0x20,'submersion':0x30},
      'music':{'id':0x19C,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']},
      'sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (DATA/'phase115_ooz1_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
