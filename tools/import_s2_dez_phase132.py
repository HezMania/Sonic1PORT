#!/usr/bin/env python3
"""Phase 132: retail Sonic 2 Death Egg Zone foundation + Mecha Sonic assets."""
from __future__ import annotations
import hashlib, importlib.util, json, re, sys
from collections import Counter
from pathlib import Path
P=Path(__file__).resolve().parents[1]; TOOLS=P/'tools'; DATA=P/'data'/'s1'/'s2test'; PAL=P/'data'/'s1'/'palette'; SOUND=P/'data'/'s1'/'sound'; OUT=P/'assets'/'objects'/'s2_dez'
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);assert spec.loader;spec.loader.exec_module(m);return m
terrain=load('terrain132',TOOLS/'import_sonic2_level.py')
pres=load('pres132',TOOLS/'import_s2_ehz_presentation.py')
trav=load('trav132',TOOLS/'import_s2_cpz_traversal_phase91.py')
boss=load('boss132',TOOLS/'import_s2_ehz_boss.py')
def be16(b,o):return (b[o]<<8)|b[o+1]
def sha(b):return hashlib.sha256(b).hexdigest()
def hdr(w,h,b):assert len(b)==w*h;return bytes((w-1,h-1))+bytes(b)
def frame_count(m):return be16(m,0)//2 if len(m)>=2 else 0
def extract_apm_dez(src):
    text=(src/'s2.lst').read_text(errors='replace')
    ms=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_DEZ label \*',text)
    me=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_DEZ_End:',text)
    if not ms or not me:raise ValueError('APM_DEZ not found')
    start,end=int(ms.group(1),16),int(me.group(1),16);rom=(src/'s2built.bin').read_bytes()
    dest=be16(rom,start);wc=be16(rom,start+2);patch=rom[start+4:end]
    assert len(patch)==(wc+1)*2 and dest+len(patch)==0x1800
    return dest,patch
def render_family(src,art_rel,map_rel,folder,pals,pal_line):
    raw=boss.nemesis_decompress((src/art_rel).read_bytes());maps=(src/map_rel).read_bytes();n=frame_count(maps)
    need=len(raw)//32
    for fi in range(n):
        off=be16(maps,fi*2); count=be16(maps,off)
        for j in range(count):
            q=maps[off+2+j*8:off+10+j*8]
            if len(q)<8: continue
            size=q[1]; attr=be16(q,2); wt=((size>>2)&3)+1; ht=(size&3)+1
            need=max(need,(attr&0x7ff)+wt*ht)
    if len(raw)<need*32: raw += bytes(need*32-len(raw))
    d=OUT/folder;d.mkdir(parents=True,exist_ok=True)
    for q in d.glob('*.png'):q.unlink()
    for i in range(n):trav.render_mapping(raw,maps,i,pals,pal_line).save(d/f'{i:02d}.png')
    return {'frames':n,'tiles':len(raw)//32,'map_bytes':len(maps)}
def add_song(src):
    raw=(src/'sound/music/DEZ.bin').read_bytes();data=pres.saxman_decompress(raw)
    pres.PORT_MUSIC_ID=0x1A0
    pres.label=lambda kind,off:f"S2DEZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data);song['id']=0x1A0;song['name']='Sonic 2 - Death Egg Zone';song['header']['voice_label']='S2DEZ_Voices';song['source']['song_sha256']=sha(raw)
    dbp=SOUND/'s2_ehz_smps.json';db=json.loads(dbp.read_text());db.setdefault('music',{})[str(0x1A0)]=song;dbp.write_text(json.dumps(db,indent=2)+'\n')
    return {'id':0x1A0,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']}
def main():
    if len(sys.argv)!=2:raise SystemExit('usage: import_s2_dez_phase132.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve();DATA.mkdir(parents=True,exist_ok=True);PAL.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    art=terrain.kosinski_decompress((src/'art/kosinski/CPZ_DEZ.bin').read_bytes());v=bytearray(0x800*32);v[:len(art)]=art
    anim=(src/'art/uncompressed/Animated background section (CPZ and DEZ).bin').read_bytes();v[0x326*32:0x328*32]=anim[:64]
    m16base=terrain.kosinski_decompress((src/'mappings/16x16/CPZ_DEZ.bin').read_bytes());dest,patch=extract_apm_dez(src);m16=bytearray(0x1800);m16[:len(m16base)]=m16base;m16[dest:dest+len(patch)]=patch
    m128=terrain.kosinski_decompress((src/'mappings/128x128/CPZ_DEZ.bin').read_bytes());layout=terrain.kosinski_decompress((src/'level/layout/DEZ.bin').read_bytes())
    cp=terrain.kosinski_decompress((src/'collision/CPZ and DEZ primary 16x16 collision index.bin').read_bytes());cs=terrain.kosinski_decompress((src/'collision/CPZ and DEZ secondary 16x16 collision index.bin').read_bytes())
    assert len(layout)==0x1000 and len(m128)==0x8000 and len(cp)==0x300 and len(cs)==0x300
    fg=bytearray();bg=bytearray()
    for row in range(16):
        o=row*0x100;fg+=layout[o:o+0x80];bg+=layout[o+0x80:o+0x100]
    objs=(src/'level/objects/DEZ_1.bin').read_bytes();rings=(src/'level/rings/DEZ_1.bin').read_bytes();start=(src/'startpos/DEZ.bin').read_bytes()
    outputs={'dez1_art.bin':bytes(v),'dez1_map16.bin':bytes(m16),'dez1_map128.bin':m128,'dez1_layout128.bin':hdr(128,16,fg),'dez1_bg128.bin':hdr(128,16,bg),'dez1_collision_primary.bin':cp,'dez1_collision_secondary.bin':cs,'dez1_objects.bin':objs,'dez1_rings.bin':rings,'dez1_start.bin':start,'s2_dez_anim_back.bin':anim}
    for n,b in outputs.items():(DATA/n).write_bytes(b)
    pal=(src/'art/palettes/DEZ.bin').read_bytes();(PAL/'S2 Death Egg Zone.bin').write_bytes(pal)
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes();pals=[trav.palette_line(sonic)]+[trav.palette_line(pal[i*32:(i+1)*32]) for i in range(3)]
    sprites={
      'mecha':render_family(src,'art/nemesis/Silver Sonic.bin','mappings/sprite/objAF_a.bin','mecha',pals,1),
      'window':render_family(src,'art/nemesis/Window in back that Robotnik looks through in DEZ.bin','mappings/sprite/objAF_b.bin','window',pals,0),
    }
    music=add_song(src);counts=Counter(objs[i+4] for i in range(0,len(objs),6))
    manifest={'phase':132,'level':'Death Egg Zone','source_revision':'retail final','start':[be16(start,0),be16(start,2)],'limits':{'left':0,'right':0x1000,'top':0xC8,'bottom':0xC8},'layout':[128,16],'objects':len(objs)//6,'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},'rings_bytes':len(rings),'apm_dez':{'destination':dest,'bytes':len(patch)},'animated_tile':0x326,'sprites':sprites,'music':music,'sha256':{k:sha(v) for k,v in outputs.items()}}
    (DATA/'phase132_dez_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
