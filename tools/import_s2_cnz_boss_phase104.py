#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from PIL import Image
import json, shutil, sys

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from import_s2_ehz_boss import nemesis_decompress, decode_line, be16, tile_pixels
from import_s2_cpz_traversal_phase91 import render_mapping


def render_frame_bias(raw: bytes, mappings: bytes, frame: int, palettes, base_palette: int, tile_bias: int) -> Image.Image:
    off = be16(mappings, frame * 2)
    count = be16(mappings, off)
    pieces = []
    for i in range(count):
        q = mappings[off + 2 + i * 8:off + 2 + (i + 1) * 8]
        if len(q) != 8:
            raise ValueError(f'frame {frame} piece {i} truncated')
        y = int.from_bytes(q[0:1], 'big', signed=True)
        size = q[1]
        attr = be16(q, 2)
        x = int.from_bytes(q[6:8], 'big', signed=True)
        pieces.append((y, size, attr, x))
    im = Image.new('RGBA', (192, 192), (0,0,0,0))
    px = im.load(); ox = oy = 96
    for y,size,attr,x in reversed(pieces):
        wt=((size>>2)&3)+1; ht=(size&3)+1
        base=(attr&0x7FF)+tile_bias
        hf=bool(attr&0x0800); vf=bool(attr&0x1000)
        map_pal=(attr>>13)&3
        pal=palettes[(base_palette|map_pal)&3]
        for dx in range(wt):
            for dy in range(ht):
                sx=wt-1-dx if hf else dx
                sy=ht-1-dy if vf else dy
                t=tile_pixels(raw, base+sx*ht+sy)
                for yy in range(8):
                    for xx in range(8):
                        ci=t[7-yy if vf else yy][7-xx if hf else xx]
                        if not ci: continue
                        tx=ox+x+dx*8+xx; ty=oy+y+dy*8+yy
                        if 0<=tx<192 and 0<=ty<192: px[tx,ty]=pal[ci]
    return im


def parse_bumpers(data: bytes):
    result=[]
    for off in range(0, len(data)-5, 6):
        typ=int.from_bytes(data[off:off+2],'big')
        x=int.from_bytes(data[off+2:off+4],'big')
        y=int.from_bytes(data[off+4:off+6],'big')
        if x == 0xFFFF: break
        if x == 0 and y == 0: continue
        result.append({'type':typ,'x':x,'y':y})
    return result


def main() -> int:
    if len(sys.argv)!=2:
        print('usage: import_s2_cnz_boss_phase104.py <retail Sonic 2 source root>', file=sys.stderr); return 2
    root=Path(sys.argv[1]).resolve()
    sonic=(root/'art/palettes/SonicAndTails.bin').read_bytes()
    cnz=(root/'art/palettes/CNZ.bin').read_bytes()
    boss_pal=(root/'art/palettes/CNZ Boss.bin').read_bytes()
    normal_pals=[decode_line(sonic)] + [decode_line(cnz[i*32:(i+1)*32]) for i in range(3)]
    boss_pals=[decode_line(sonic), decode_line(boss_pal), decode_line(cnz[32:64]), decode_line(cnz[64:96])]

    # ObjD8 starts on palette line 2 and subtracts palette_line_1 after each hit.
    raw=nemesis_decompress((root/'art/nemesis/Drop target from CNZ.bin').read_bytes())
    maps=(root/'mappings/sprite/objD8.bin').read_bytes()
    out=PROJECT/'assets/objects/s2_cnz'
    for pal_line in (0,1,2):
        dest=out/f'bonus_block_p{pal_line}'; dest.mkdir(parents=True, exist_ok=True)
        for old in dest.glob('*.png'): old.unlink()
        for frame in range(6):
            render_mapping(raw,maps,frame,normal_pals,pal_line).save(dest/f'{frame:02d}.png')

    # Obj51's authored mapping tile indices are relative to a deliberate art-tile
    # fudge of -$60. The raw CNZ boss Nemesis stream begins at real tile 0, so
    # subtract $60 from every mapping tile index while rendering.
    boss_raw=nemesis_decompress((root/'art/nemesis/CNZ boss.bin').read_bytes())
    egg_raw=nemesis_decompress((root/'art/nemesis/Eggpod.bin').read_bytes())
    boss_maps=(root/'mappings/sprite/obj51.bin').read_bytes()
    # Object art_tile is $3A7 (real boss load $407 minus $60 mapping fudge). Thus
    # mapping tile $60 is real boss tile zero. The same mappings deliberately reuse
    # Eggpod graphics loaded at VRAM tile $500, i.e. relative mapping tile $159.
    boss_rel=0x60; egg_rel=0x500-0x3A7
    bank_tiles=max(boss_rel+len(boss_raw)//32, egg_rel+len(egg_raw)//32)
    bank=bytearray(bank_tiles*32)
    bank[boss_rel*32:boss_rel*32+len(boss_raw)]=boss_raw
    bank[egg_rel*32:egg_rel*32+len(egg_raw)]=egg_raw
    boss_dest=out/'boss'; boss_dest.mkdir(parents=True, exist_ok=True)
    for old in boss_dest.glob('*.png'): old.unlink()
    frame_count=next(be16(boss_maps,i)//2 for i in range(0, min(16,len(boss_maps)), 2) if be16(boss_maps,i) != 0)
    for frame in range(frame_count):
        render_frame_bias(bytes(bank),boss_maps,frame,boss_pals,0,0).save(boss_dest/f'{frame:02d}.png')

    # The capsule PLC is loaded while Pal_CNZ_B is still active. Obj3E uses
    # palette line 1, so render its six authored frames through that boss line.
    prison_raw=nemesis_decompress((root/'art/nemesis/Egg Prison.bin').read_bytes())
    prison_maps=(root/'mappings/sprite/obj3E.bin').read_bytes()
    prison_dest=out/'egg_prison'; prison_dest.mkdir(parents=True, exist_ok=True)
    for old in prison_dest.glob('*.png'): old.unlink()
    for frame in range(6):
        render_mapping(prison_raw,prison_maps,frame,boss_pals,1).save(prison_dest/f'{frame:02d}.png')

    data_dest=PROJECT/'data/s1/s2test'; data_dest.mkdir(parents=True, exist_ok=True)
    b1=(root/'level/objects/CNZ 1 bumpers.bin').read_bytes()
    b2=(root/'level/objects/CNZ 2 bumpers.bin').read_bytes()
    (data_dest/'cnz1_bumpers.bin').write_bytes(b1)
    (data_dest/'cnz2_bumpers.bin').write_bytes(b2)

    pal_dest=PROJECT/'data/s1/palette'; pal_dest.mkdir(parents=True, exist_ok=True)
    copies={
        'CNZ Boss.bin':'S2 CNZ Boss.bin',
        'CNZ Boss Cycle 1.bin':'S2 CNZ Boss Cycle 1.bin',
        'CNZ Boss Cycle 2.bin':'S2 CNZ Boss Cycle 2.bin',
        'CNZ Boss Cycle 3.bin':'S2 CNZ Boss Cycle 3.bin',
    }
    for src_name,dst_name in copies.items():
        shutil.copyfile(root/'art/palettes'/src_name, pal_dest/dst_name)

    manifest={
        'phase':104,
        'cnz1_special_bumpers':len(parse_bumpers(b1)),
        'cnz2_special_bumpers':len(parse_bumpers(b2)),
        'boss_mapping_frames':frame_count,
        'boss_tiles':len(boss_raw)//32,
        'boss_start':[0x2A46,0x654],
        'boss_patrol':[0x28C0,0x29C0],
        'boss_hits':8,
        'boss_camera':{'lock_left':0x2860,'lock_right':0x28E0,'escape_right':0x2B20},
    }
    (data_dest/'phase104_cnz_boss_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('CNZ1 bumpers',manifest['cnz1_special_bumpers'])
    print('CNZ2 bumpers',manifest['cnz2_special_bumpers'])
    print('boss frames',frame_count,'tiles',manifest['boss_tiles'])
    return 0

if __name__=='__main__': raise SystemExit(main())
