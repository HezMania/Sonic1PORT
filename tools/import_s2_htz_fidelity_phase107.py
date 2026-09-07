#!/usr/bin/env python3
from pathlib import Path
import importlib.util, sys, json, hashlib
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'assets/objects/s2_htz'

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
trav=load_module('trav107',PROJECT/'tools/import_s2_cpz_traversal_phase91.py')

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def render_piece(raw,pal,base_tile,w,h):
    im=Image.new('RGBA',(w*8,h*8),(0,0,0,0)); pix=im.load()
    for dx in range(w):
        for dy in range(h):
            tp=trav.tile_pixels(raw,base_tile+dx*h+dy)
            for yy in range(8):
                for xx in range(8):
                    ci=tp[yy][xx]
                    if ci: pix[dx*8+xx,dy*8+yy]=pal[ci]
    return im

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_htz_fidelity_phase107.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve()
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); htz=(src/'art/palettes/HTZ.bin').read_bytes()
    palettes=[trav.palette_line(sonic)]+[trav.palette_line(htz[i*32:(i+1)*32]) for i in range(3)]
    resident=(PROJECT/'data/s1/s2test/htz1_art.bin').read_bytes()

    # Spiker maps use tiles $3DE (Sol body) and $520+ (Spiker drill parts).
    spiker_raw=trav.nemesis_decode((src/'art/nemesis/Driller badnik from HTZ.bin').read_bytes())
    sol_raw=trav.nemesis_decode((src/'art/nemesis/Sol badnik from HTZ.bin').read_bytes())
    v=bytearray(0x600*32)
    v[0x3DE*32:0x3DE*32+len(sol_raw)] = sol_raw
    v[0x520*32:0x520*32+len(spiker_raw)] = spiker_raw
    maps=(src/'mappings/sprite/obj93.bin').read_bytes(); d=OUT/'spiker'; d.mkdir(parents=True,exist_ok=True)
    for i in range(int.from_bytes(maps[:2],'big')//2): trav.render_mapping(bytes(v),maps,i,palettes,0).save(d/f'{i:02d}.png')

    # HTZ Object $1C subtypes 7/8 are the resident-art lift stakes.
    maps=(src/'mappings/sprite/obj1C_a.bin').read_bytes(); d=OUT/'lift_stake'; d.mkdir(parents=True,exist_ok=True)
    for i in range(2): trav.render_mapping(resident,maps,i,palettes,2).save(d/f'{i:02d}.png')

    # Obj2F debris pieces are the authored 2x2 tile chunks used by the stack.
    d=OUT/'smash_fragment'; d.mkdir(parents=True,exist_ok=True)
    for i,tile in enumerate((0x4A,0x4E,0x52)):
        render_piece(resident,palettes[2],tile,2,2).save(d/f'{i:02d}.png')

    # Visible top strip for the earthquake lava face. Obj30 itself is collision-only
    # in retail, but this texture mirrors the Plane-B lava bank so the native quake
    # foreground does not expose a transparent gap while the BG offset moves.
    lava=(src/'art/uncompressed/Lava.bin').read_bytes(); sheet=Image.new('RGBA',(64,48),(0,0,0,0))
    for ty in range(6):
        for tx in range(8):
            tile=trav.tile_pixels(lava,ty*8+tx)
            for y in range(8):
                for x in range(8):
                    ci=tile[y][x]
                    if ci: sheet.putpixel((tx*8+x,ty*8+y),palettes[1][ci])
    wide=Image.new('RGBA',(384,48),(0,0,0,0))
    for x in range(0,384,64): wide.alpha_composite(sheet,(x,0))
    d=OUT/'quake_lava'; d.mkdir(parents=True,exist_ok=True); wide.save(d/'00.png')

    manifest={'phase':107,'files':{str(p.relative_to(PROJECT)):sha(p) for p in sorted((OUT).rglob('*.png')) if any(x in str(p) for x in ('spiker','lift_stake','smash_fragment','quake_lava'))}}
    (PROJECT/'data/s1/s2test/phase107_htz_fidelity_art_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
