#!/usr/bin/env python3
"""Phase 125: import retail Sonic 2 Metropolis Object $54 boss / Egg Prison art."""
from pathlib import Path
import hashlib, importlib.util, json, sys
P=Path(__file__).resolve().parents[1]
OUT=P/'assets/objects/s2_mtz'; DATA=P/'data/s1/s2test'
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
boss=load('boss125',P/'tools/import_s2_ehz_boss.py')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 if len(sys.argv)!=2: raise SystemExit('usage: import_s2_mtz_boss_phase125.py <retail Sonic 2 root>')
 src=Path(sys.argv[1]).resolve()
 sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); zone=(src/'art/palettes/MTZ.bin').read_bytes()
 if len(sonic)!=32 or len(zone)!=96: raise ValueError('unexpected MTZ palette source size')
 pals=[boss.decode_line(sonic)]+[boss.decode_line(zone[i*32:(i+1)*32]) for i in range(3)]
 mtz=boss.nemesis_decompress((src/'art/nemesis/MTZ boss.bin').read_bytes()); egg=boss.nemesis_decompress((src/'art/nemesis/Eggpod.bin').read_bytes()); jets=boss.nemesis_decompress((src/'art/nemesis/Horizontal jet.bin').read_bytes()); maps=(src/'mappings/sprite/obj54.bin').read_bytes()
 # Obj54's mappings are relative to ArtTile_ArtNem_MTZBoss=$37C while its PLC also loads
 # common Eggpod art at $500 and EggpodJets at $560. Reconstruct that relative VRAM bank.
 total_tiles=max(len(mtz)//32, 0x184+len(egg)//32, 0x1E4+len(jets)//32)
 bank=bytearray(total_tiles*32); bank[:len(mtz)]=mtz; bank[0x184*32:0x184*32+len(egg)]=egg; bank[0x1E4*32:0x1E4*32+len(jets)]=jets; raw=bytes(bank)
 d=OUT/'boss/parts'; d.mkdir(parents=True,exist_ok=True)
 for q in d.glob('*.png'): q.unlink()
 for frame in range(0x15): boss.render_frame(raw,maps,frame,pals,0).save(d/f'{frame:02d}.png')
 pr=boss.nemesis_decompress((src/'art/nemesis/Egg Prison.bin').read_bytes()); pm=(src/'mappings/sprite/obj3E.bin').read_bytes(); pd=OUT/'egg_prison'; pd.mkdir(parents=True,exist_ok=True)
 for q in pd.glob('*.png'): q.unlink()
 for frame in range(6): boss.render_frame(pr,pm,frame,pals,1).save(pd/f'{frame:02d}.png')
 files=sorted(d.glob('*.png'))+sorted(pd.glob('*.png'))
 manifest={'phase':125,'boss':'Object $54','hits':8,'start':[0x2B50,0x380],'arena':[0x2AB0,0x2BF0],'egg_prison':[0x2C90,0x4A0],'boss_frames':0x15,'sha256':{str(q.relative_to(P)):sha(q) for q in files}}
 DATA.mkdir(parents=True,exist_ok=True); (DATA/'phase125_mtz_boss_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
