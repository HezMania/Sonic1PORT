#!/usr/bin/env python3
"""Phase 135: retail Sonic 2 Death Egg final boss / Object C6+C7 assets."""
from __future__ import annotations
import hashlib, importlib.util, json, struct, sys, zipfile
from pathlib import Path

P=Path(__file__).resolve().parents[1]
TOOLS=P/'tools'; DATA=P/'data'/'s1'/'s2test'; SOUND=P/'data'/'s1'/'sound'; OUT=P/'assets'/'objects'/'s2_dez'; PCM=P/'assets'/'audio'/'sfx_pcm'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);assert spec.loader;spec.loader.exec_module(m);return m
trav=load('trav135',TOOLS/'import_s2_cpz_traversal_phase91.py')
boss=load('boss135',TOOLS/'import_s2_ehz_boss.py')
pres=load('pres135',TOOLS/'import_s2_ehz_presentation.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def frame_count(m): return be16(m,0)//2 if len(m)>=2 else 0

def render_mapping_bank(raw:bytes,maps:bytes,dest:Path,pals,base_palette:int):
    n=frame_count(maps); dest.mkdir(parents=True,exist_ok=True)
    for old in dest.glob('*.png'): old.unlink()
    for i in range(n): trav.render_mapping(raw,maps,i,pals,base_palette).save(dest/f'{i:02d}.png')
    return n

def compile_end_boss_music(src:Path):
    raw=(src/'sound/music/End_Boss.bin').read_bytes(); data=pres.saxman_decompress(raw)
    old_id=pres.PORT_MUSIC_ID; old_label=pres.label
    try:
        pres.PORT_MUSIC_ID=0x1A1
        pres.label=lambda kind,off:f"S2ENDBOSS_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
        song=pres.parse_song(data)
    finally:
        pres.PORT_MUSIC_ID=old_id; pres.label=old_label
    song['id']=0x1A1; song['name']='Sonic 2 - Death Egg Final Boss'; song['header']['voice_label']='S2ENDBOSS_Voices'; song['header'].pop('speed_tempo',None); song['source']['song_sha256']=sha(raw)
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x1A1)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    # End Boss uses DAC event 9 -> Sample 5 with source delay $1C.
    sample=(src/'sound/DAC/Sample 5.bin').read_bytes(); decoded=pres.decode_s2_dac(sample)
    rate=3579540.0/(60.0+0x1C*4.0)/2.0; vals=pres.resample_linear(decoded,rate,pres.MIX_RATE); pres.write_pcm16(SOUND/'s2_ehz_dac_09.pcm',vals)
    return {'id':0x1A1,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']}

def extract_sfx(sfx_zip:Path):
    wanted=[0x28,0x37,0x39,0x3D,0x44,0x61]
    PCM.mkdir(parents=True,exist_ok=True); found={}
    with zipfile.ZipFile(sfx_zip) as z:
        names={Path(n).name.upper():n for n in z.namelist()}
        for sid in wanted:
            key=f'S2_{sid:02X}.WAV'
            if key not in names: raise FileNotFoundError(key)
            data=z.read(names[key]); out=PCM/f'S2_{sid:02X}.wav'; out.write_bytes(data); found[f'{sid:02X}']={'bytes':len(data),'sha256':sha(data)}
    return found

def main():
    if len(sys.argv) not in (2,3): raise SystemExit('usage: import_s2_dez_final_phase135.py <Sonic 2 root> [SFX zip]')
    src=Path(sys.argv[1]).resolve(); sfx=Path(sys.argv[2]).resolve() if len(sys.argv)==3 else Path('/mnt/data/Sega Genesis - Sonic the Hedgehog 2 - Miscellaneous - Sound Effects.zip')
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); dez=(src/'art/palettes/DEZ.bin').read_bytes(); pals=[trav.palette_line(sonic)]+[trav.palette_line(dez[i*32:(i+1)*32]) for i in range(3)]
    level_art=(DATA/'dez1_art.bin').read_bytes(); c6a=(src/'mappings/sprite/objC6_a.bin').read_bytes(); c6b=(src/'mappings/sprite/objC6_b.bin').read_bytes(); c7m=(src/'mappings/sprite/objC7.bin').read_bytes()

    # Obj C6 mappings use absolute tiles $500-$57F. PlrList_Dez2 overlays three
    # Robotnik PLC banks there at runtime. Reconstruct that exact VRAM interval.
    c6_vram=bytearray(level_art)
    if len(c6_vram)<0x580*32: c6_vram.extend(b'\0'*(0x580*32-len(c6_vram)))
    for tile_base,filename in [(0x500,"Robotnik's head.bin"),(0x518,'Robotnik.bin'),(0x564,"Robotnik's lover half.bin")]:
        bank=boss.nemesis_decompress((src/'art/nemesis'/filename).read_bytes()); start=tile_base*32; c6_vram[start:start+len(bank)]=bank
    n_c6a=render_mapping_bank(bytes(c6_vram),c6a,OUT/'eggman_runner',pals,0)

    # Obj C6 subtype $A8 uses PlrList_Dez2's dynamic Nemesis construction-stripe
    # PLC at VRAM tile $328. It is NOT part of the static DEZ Kosinski bank.
    stripe_art=boss.nemesis_decompress((src/'art/nemesis/Stripy blocks from CPZ.bin').read_bytes())
    n_c6b=render_mapping_bank(stripe_art,c6b,OUT/'eggman_door',pals,1)
    egg_art=boss.nemesis_decompress((src/'art/nemesis/Eggrobo.bin').read_bytes()); n_c7=render_mapping_bank(egg_art,c7m,OUT/'egg_robo',pals,0)
    sfx_info=extract_sfx(sfx); music=compile_end_boss_music(src)
    objs=(DATA/'dez1_objects.bin').read_bytes(); recs=[]
    for i in range(0,len(objs),6): recs.append([be16(objs,i),be16(objs,i+2)&0xFFF,objs[i+4],objs[i+5]])
    manifest={'phase':135,'objects':{'C6_records':[r for r in recs if r[2]==0xC6],'C7_records':[r for r in recs if r[2]==0xC7]},'frames':{'c6_runner':n_c6a,'c6_door':n_c6b,'c7':n_c7},'egg_robo_art_tiles':len(egg_art)//32,'music':music,'sfx':sfx_info,'source_sha256':{'objC6_a':sha(c6a),'objC6_b':sha(c6b),'objC7':sha(c7m),'Eggrobo':sha((src/'art/nemesis/Eggrobo.bin').read_bytes()),'End_Boss':sha((src/'sound/music/End_Boss.bin').read_bytes())}}
    (DATA/'phase135_dez_final_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n'); print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
