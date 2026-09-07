#!/usr/bin/env python3
"""Phase 126 Hotfix 1: reconstruct Tails' dynamic Tornado pilot mapping piece.

ObjB2's SCZ mapping has a 3x2 (six-tile) piece at (-$30,-8) sourced from the
Tails dynamic PLC bank at VRAM $7A0. ObjB2_Animate_Pilot requests Tails DPLC
frames $10,1,2,3,4. LoadTailsDynPLC_Part2 streams each DPLC entry sequentially,
so the first six loaded tiles are exactly the six tiles used by that piece.
"""
from pathlib import Path
import sys
from PIL import Image

P=Path(__file__).resolve().parents[1]
OUT=P/'assets'/'objects'/'s2_scz'/'pilot'

def be16(b,o): return (b[o]<<8)|b[o+1]

def palette_line(raw:bytes):
    out=[]
    for i in range(16):
        w=be16(raw,i*2)
        r=((w>>1)&7)*255//7; g=((w>>5)&7)*255//7; b=((w>>9)&7)*255//7
        out.append((r,g,b,0 if i==0 else 255))
    return out

def tile_pixels(raw:bytes,tile:int):
    off=tile*32; rows=[]
    for y in range(8):
        row=[]
        for q in raw[off+y*4:off+y*4+4]: row.extend((q>>4,q&15))
        rows.append(row)
    return rows

def first_dplc_tiles(dplc:bytes,frame:int):
    off=be16(dplc,frame*2); count=be16(dplc,off)
    if count<1: raise ValueError(f'DPLC frame {frame:X} has no entries')
    e=be16(dplc,off+2); n=((e>>12)&15)+1; start=e&0xFFF
    if n<6: raise ValueError(f'first DPLC packet has only {n} tiles')
    return list(range(start,start+6))

def render_piece(art:bytes,tiles,pal):
    # Genesis sprite order for size $09 (3 columns x 2 rows) is column-major.
    im=Image.new('RGBA',(24,16),(0,0,0,0)); px=im.load()
    for j,tile in enumerate(tiles):
        tx=j//2; ty=j%2; tp=tile_pixels(art,tile)
        for y in range(8):
            for x in range(8):
                ci=tp[y][x]
                if ci: px[tx*8+x,ty*8+y]=pal[ci]
    return im

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_scz_hotfix1_pilot.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); OUT.mkdir(parents=True,exist_ok=True)
    art=(src/"art/uncompressed/Tails's art.bin").read_bytes()
    dplc=(src/'mappings/spriteDPLC/Tails.bin').read_bytes()
    pal=palette_line((src/'art/palettes/SonicAndTails.bin').read_bytes()[:32])
    frames=[0x10,1,2,3,4]
    meta=[]
    for out_id,source_frame in enumerate(frames):
        tiles=first_dplc_tiles(dplc,source_frame)
        render_piece(art,tiles,pal).save(OUT/f'{out_id:02d}.png')
        meta.append((out_id,source_frame,tiles))
    for q in sorted(OUT.glob('*.png')):
        if int(q.stem)>=len(frames):q.unlink()
    for out_id,source_frame,tiles in meta:
        print(f'{out_id:02d}: Tails DPLC ${source_frame:02X} -> {tiles}')

if __name__=='__main__': main()
