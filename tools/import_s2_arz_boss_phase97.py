#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import importlib.util, sys

PROJECT=Path(__file__).resolve().parents[1]
# Reuse deterministic Nemesis/mapping renderer from Phase 89.
spec=importlib.util.spec_from_file_location('ehzboss', PROJECT/'tools/import_s2_ehz_boss.py')
mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

def main():
    if len(sys.argv)!=2:
        print('usage: import_s2_arz_boss_phase97.py <retail Sonic 2 disassembly root>'); return 2
    root=Path(sys.argv[1]).resolve()
    sonic=(root/'art/palettes/SonicAndTails.bin').read_bytes()
    arz=(root/'art/palettes/ARZ.bin').read_bytes()
    if len(sonic)!=32 or len(arz)!=96: raise ValueError('unexpected ARZ palette sizes')
    pals=[mod.decode_line(sonic)]+[mod.decode_line(arz[i*32:(i+1)*32]) for i in range(3)]
    raw=mod.nemesis_decompress((root/'art/nemesis/ARZ boss.bin').read_bytes())
    egg=mod.nemesis_decompress((root/'art/nemesis/Eggpod.bin').read_bytes())
    # Obj89_b child mappings reference the Eggpod at VRAM $500 while the object
    # base art tile is ARZBoss $3E0: relative tile offset $120. Build that exact
    # sparse VRAM-relative bank so the authored mapping words render unchanged.
    bank=bytearray(max(len(raw), (0x120*32)+len(egg)))
    bank[:len(raw)]=raw
    bank[0x120*32:0x120*32+len(egg)]=egg
    outputs=[
        ('pillar_arrow','mappings/sprite/obj89_a.bin',7),
        ('main','mappings/sprite/obj89_b.bin',12),
    ]
    base=PROJECT/'assets/objects/s2_arz/boss'
    for folder,maprel,frames in outputs:
        dest=base/folder; dest.mkdir(parents=True,exist_ok=True)
        for old in dest.glob('*.png'): old.unlink()
        maps=(root/maprel).read_bytes()
        source = raw if folder == 'pillar_arrow' else bytes(bank)
        for i in range(frames):
            mod.render_frame(source,maps,i,pals,0).save(dest/f'{i:02d}.png')
        print(folder,frames,len(source)//32)
    # Re-render the shared Egg Prison through the active ARZ CRAM.
    dest=PROJECT/'assets/objects/s2_arz/egg_prison'; dest.mkdir(parents=True,exist_ok=True)
    prison=mod.nemesis_decompress((root/'art/nemesis/Egg Prison.bin').read_bytes())
    maps=(root/'mappings/sprite/obj3E.bin').read_bytes()
    for old in dest.glob('*.png'): old.unlink()
    for i in range(6): mod.render_frame(prison,maps,i,pals,1).save(dest/f'{i:02d}.png')
    print('egg_prison',6)
    return 0
if __name__=='__main__': raise SystemExit(main())
