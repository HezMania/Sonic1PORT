#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from PIL import Image
import sys

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'assets/objects/s2_ehz'


def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off+1]


class BitReader:
    def __init__(self, data: bytes): self.data=data; self.pos=0
    def read(self, count: int) -> int:
        v=0
        for _ in range(count):
            b=self.data[self.pos>>3]; bit=7-(self.pos&7)
            v=(v<<1)|((b>>bit)&1); self.pos+=1
        return v
    def peek(self,count:int)->int:
        p=self.pos; v=self.read(count); self.pos=p; return v


def nemesis_decompress(data: bytes) -> bytes:
    header=be16(data,0); xor_mode=bool(header&0x8000); target_rows=(header&0x7fff)*8
    table=[0]*256; source=2; marker=data[source]; source+=1
    while marker != 0xff and source < len(data):
        palette=marker&0xf
        while source < len(data):
            marker=data[source]; source+=1
            if marker >= 0x80: break
            length=marker&0xf; repeat=(marker>>4)&7
            code=data[source]; source+=1
            value=(length<<8)|(repeat<<4)|palette
            if length==8: table[code]=value
            else:
                shift=8-length; first=code<<shift
                for i in range(1<<shift): table[first+i]=value
    reader=BitReader(data[source:]+b'\0\0'); out=bytearray(); row=pixels=rows=previous=0
    while rows<target_rows:
        if reader.peek(6)==0x3f:
            reader.read(6); value=reader.read(7); repeat=((value>>4)&7)+1; pixel=value&0xf
        else:
            idx=reader.peek(8); value=table[idx]; length=(value>>8)&0xff
            if not length: raise ValueError('invalid Nemesis prefix')
            reader.read(length); repeat=((value>>4)&7)+1; pixel=value&0xf
        for _ in range(repeat):
            if rows>=target_rows: break
            row=(row<<4)|pixel; pixels+=1
            if pixels==8:
                word=row
                if xor_mode: word ^= previous; previous=word
                out.extend(word.to_bytes(4,'big')); rows+=1; pixels=0; row=0
    return bytes(out)


def genesis_color(w:int, transparent=False):
    if transparent: return (0,0,0,0)
    return (((w>>1)&7)*255//7,((w>>5)&7)*255//7,((w>>9)&7)*255//7,255)


def decode_line(data:bytes):
    return [genesis_color(int.from_bytes(data[i*2:i*2+2],'big'), i==0) for i in range(16)]


def tile_pixels(raw:bytes,index:int):
    d=raw[index*32:(index+1)*32]
    if len(d)!=32: raise ValueError(f'tile {index} out of range')
    rows=[]
    for y in range(8):
        r=[]
        for b in d[y*4:y*4+4]: r.extend((b>>4,b&15))
        rows.append(r)
    return rows


def render_frame(raw:bytes, mappings:bytes, frame:int, palettes):
    off=be16(mappings,frame*2); count=be16(mappings,off); pieces=[]
    for i in range(count):
        q=mappings[off+2+i*8:off+2+(i+1)*8]
        if len(q)!=8: raise ValueError(f'frame {frame} piece {i} truncated')
        y=int.from_bytes(q[0:1],'big',signed=True); size=q[1]
        attr=be16(q,2); x=int.from_bytes(q[6:8],'big',signed=True)
        pieces.append((y,size,attr,x))
    im=Image.new('RGBA',(128,128),(0,0,0,0)); px=im.load(); ox=oy=64
    # Genesis sprite-link priority: the earliest piece in the mapping is visually
    # in front of later pieces.  Composite backwards so the first piece wins.
    for y,size,attr,x in reversed(pieces):
        wt=((size>>2)&3)+1; ht=(size&3)+1; base=attr&0x7ff
        hf=bool(attr&0x0800); vf=bool(attr&0x1000); pal=palettes[(attr>>13)&3]
        for dx in range(wt):
            for dy in range(ht):
                sx=wt-1-dx if hf else dx; sy=ht-1-dy if vf else dy
                t=tile_pixels(raw,base+sx*ht+sy)
                for yy in range(8):
                    for xx in range(8):
                        ci=t[7-yy if vf else yy][7-xx if hf else xx]
                        if ci: px[ox+x+dx*8+xx,oy+y+dy*8+yy]=pal[ci]
    return im


def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_ehz_badnik_art.py <retail-s2-root>')
    root=Path(sys.argv[1])
    sonic=(root/'art/palettes/SonicAndTails.bin').read_bytes()
    ehz=(root/'art/palettes/EHZ.bin').read_bytes()
    if len(sonic)!=32 or len(ehz)!=96: raise ValueError('unexpected EHZ active palette source sizes')
    palettes=[decode_line(sonic)]+[decode_line(ehz[i*32:(i+1)*32]) for i in range(3)]
    banks=[
        ('buzzer','art/nemesis/Buzzer enemy.bin','mappings/sprite/obj4B.bin',7),
        ('masher','art/nemesis/EHZ Pirahna badnik.bin','mappings/sprite/obj5C.bin',2),
        ('coconuts','art/nemesis/Coconuts badnik from EHZ.bin','mappings/sprite/obj9D.bin',4),
    ]
    for folder,art_rel,map_rel,count in banks:
        raw=nemesis_decompress((root/art_rel).read_bytes()); mappings=(root/map_rel).read_bytes()
        dest=OUT/folder; dest.mkdir(parents=True,exist_ok=True)
        for old in dest.glob('*.png'): old.unlink()
        for fr in range(count): render_frame(raw,mappings,fr,palettes).save(dest/f'{fr:02d}.png')
        print(f'{folder}: {count} frames')

if __name__=='__main__': main()
