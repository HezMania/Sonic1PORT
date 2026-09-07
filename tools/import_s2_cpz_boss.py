#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from PIL import Image
import importlib.util, sys

PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'assets/objects/s2_cpz/boss'

# Reuse the deterministic Nemesis+mapping renderer from Phase 89.
spec=importlib.util.spec_from_file_location('ehzboss', PROJECT/'tools/import_s2_ehz_boss.py')
mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

def main():
    if len(sys.argv)!=2:
        print('usage: import_s2_cpz_boss.py <retail Sonic 2 disassembly root>'); return 2
    root=Path(sys.argv[1]).resolve()
    sonic=(root/'art/palettes/SonicAndTails.bin').read_bytes()
    cpz=(root/'art/palettes/CPZ.bin').read_bytes()
    if len(sonic)!=32 or len(cpz)!=96: raise ValueError('unexpected CPZ palette sizes')
    pals=[mod.decode_line(sonic)]+[mod.decode_line(cpz[i*32:(i+1)*32]) for i in range(3)]
    outputs=[
      ('eggpod_pal0','art/nemesis/Eggpod.bin','mappings/sprite/obj5D_b.bin',7,0),
      ('eggpod_pal1','art/nemesis/Eggpod.bin','mappings/sprite/obj5D_b.bin',7,1),
      ('mechanism_pal1','art/nemesis/CPZ boss.bin','mappings/sprite/obj5D_a.bin',40,1),
      ('mechanism_pal3','art/nemesis/CPZ boss.bin','mappings/sprite/obj5D_a.bin',40,3),
      ('jets','art/nemesis/Horizontal jet.bin','mappings/sprite/obj5D_c.bin',2,0),
      ('smoke','art/nemesis/Smoke trail from CPZ and HTZ bosses.bin','mappings/sprite/obj5D_d.bin',4,0),
    ]
    for folder,art,mp,frames,pal in outputs:
        tiles=mod.render_bank(root, f'../s2_cpz/boss/{folder}', art, mp, frames, pals, pal)
        # render_bank is rooted in the EHZ OUT; move generated directory into CPZ boss.
        generated=(PROJECT/'assets/objects/s2_ehz/../s2_cpz/boss'/folder).resolve()
        print(folder,frames,tiles,generated)
    # Ensure prison art exists in shared S2 location; regenerate using CPZ CRAM so
    # the placed CPZ2 capsule inherits the active zone palette rather than EHZ.
    dest=PROJECT/'assets/objects/s2_cpz/egg_prison'; dest.mkdir(parents=True,exist_ok=True)
    raw=mod.nemesis_decompress((root/'art/nemesis/Egg Prison.bin').read_bytes())
    maps=(root/'mappings/sprite/obj3E.bin').read_bytes()
    for old in dest.glob('*.png'): old.unlink()
    for i in range(6): mod.render_frame(raw,maps,i,pals,1).save(dest/f'{i:02d}.png')
    print('egg_prison',6)
    return 0
if __name__=='__main__': raise SystemExit(main())
