#!/usr/bin/env python3
"""Phase 120: reconstruct retail Sonic 2 Metropolis Act 1 object sprite banks."""
from pathlib import Path
import hashlib, importlib.util, json, sys

P=Path(__file__).resolve().parents[1]
OUT=P/'assets/objects/s2_mtz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
trav=load('trav120',P/'tools/import_s2_cpz_traversal_phase91.py')
boss=load('boss120',P/'tools/import_s2_ehz_boss.py')

def be16(b,o): return (b[o]<<8)|b[o+1]

def clear(d):
    d.mkdir(parents=True,exist_ok=True)
    for q in d.glob('*.png'): q.unlink()

def bank(raw,maps,dest,pals,base,frames=None, only=None):
    d=OUT/dest; clear(d)
    n=be16(maps,0)//2 if frames is None else frames
    use=range(n) if only is None else only
    out=[]
    for i in use:
        trav.render_mapping(raw,maps,i,pals,base).save(d/f'{i:02d}.png'); out.append(i)
    return out

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_mtz_objects_phase120.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); OUT.mkdir(parents=True,exist_ok=True)
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); zone=(src/'art/palettes/MTZ.bin').read_bytes()
    pals=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    art=(P/'data/s1/s2test/mtz1_art.bin').read_bytes(); mp=src/'mappings/sprite'
    monitor=boss.nemesis_decompress((src/'art/nemesis/Monitor and contents.bin').read_bytes())
    specs={}
    specs['cylinder_controller']=bank(art,(mp/'obj65_a.bin').read_bytes(),'cylinder_controller',pals,3,only=[0]) # invisible controller: debug/reference only
    specs['rope']=bank(art[0x3FD*32:],(mp/'obj1C_e.bin').read_bytes(),'rope',pals,1,only=[2])
    specs['barrier']=bank(art,(mp/'obj2D.bin').read_bytes(),'barrier',pals,3,only=[1])
    specs['steam_spring']=bank(art,(mp/'obj42.bin').read_bytes(),'steam_spring',pals,3,only=[7])
    specs['steam']=bank(art[0x405*32:],(mp/'obj42.bin').read_bytes(),'steam',pals,1,only=range(0,7))
    specs['button']=bank(art[0x424*32:],(mp/'obj47.bin').read_bytes(),'button',pals,0)
    specs['stomper']=bank(art,(mp/'obj64.bin').read_bytes(),'stomper',pals,1)
    specs['platform']=bank(art,(mp/'obj65_a.bin').read_bytes(),'platform',pals,3)
    specs['cog']=bank(art[0x55F*32:],(mp/'obj65_b.bin').read_bytes(),'cog',pals,3)
    specs['spring_wall']=bank(monitor,(mp/'obj66.bin').read_bytes(),'spring_wall',pals,0)
    specs['spin_tube_flash']=bank(art[0x56B*32:],(mp/'obj67.bin').read_bytes(),'spin_tube_flash',pals,3)
    specs['spike_block']=bank(art[0x414*32:],(mp/'obj68.bin').read_bytes(),'spike_block',pals,3,only=[4])
    specs['moving_spike']=bank(art[0x41C*32:],(mp/'obj68.bin').read_bytes(),'moving_spike',pals,1,only=range(0,4))
    specs['nut']=bank(art[0x500*32:],(mp/'obj69.bin').read_bytes(),'nut',pals,1)
    specs['immobile_platform']=bank(art,(mp/'obj65_a.bin').read_bytes(),'immobile_platform',pals,3)
    specs['shellcracker']=bank(art[0x31C*32:],(mp/'objA0.bin').read_bytes(),'shellcracker',pals,0)
    specs['slicer']=bank(art[0x43C*32:],(mp/'objA2.bin').read_bytes(),'slicer',pals,1)
    specs['asteron']=bank(art[0x368*32:],(mp/'objA4.bin').read_bytes(),'asteron',pals,0)
    # Obj67 path data used by Act 1 subtypes 0/1/2, taken verbatim from misc/obj67.asm.
    paths={
      '0':[[0x7A8,0x270],[0x750,0x270],[0x740,0x280],[0x740,0x3E0],[0x750,0x3F0],[0x7A8,0x3F0]],
      '1':[[0xC58,0x5F0],[0xE28,0x5F0]],
      '2':[[0x1828,0x6B0],[0x17D0,0x6B0],[0x17C0,0x6C0],[0x17C0,0x7E0],[0x17B0,0x7F0],[0x1758,0x7F0]],
    }
    manifest={'phase':120,'banks':specs,'tube_paths':paths,'sha256':{}}
    for q in sorted(OUT.rglob('*.png')): manifest['sha256'][str(q.relative_to(OUT))]=hashlib.sha256(q.read_bytes()).hexdigest()
    (P/'data/s1/s2test/phase120_mtz_objects_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
