#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import sys

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'assets/objects/s2_cpz'

def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off + 1]

class BitReader:
    def __init__(self, data: bytes): self.data=data; self.pos=0
    def read(self, count:int)->int:
        v=0
        for _ in range(count):
            b=self.data[self.pos>>3]; bit=7-(self.pos&7)
            v=(v<<1)|((b>>bit)&1); self.pos+=1
        return v
    def peek(self,count:int)->int:
        p=self.pos; v=self.read(count); self.pos=p; return v

def nemesis_decode(data: bytes) -> bytes:
    header=be16(data,0); xor_mode=bool(header&0x8000); rows_needed=(header&0x7FFF)*8
    table=[0]*256; pos=2; marker=data[pos]; pos+=1
    while marker != 0xFF:
        pal=marker&0x0F
        while True:
            marker=data[pos]; pos+=1
            if marker>=0x80: break
            bit_len=marker&0x0F; repeat=(marker>>4)&7; code=data[pos]; pos+=1
            packed=(bit_len<<8)|(repeat<<4)|pal
            if bit_len==8: table[code]=packed
            else:
                shift=8-bit_len; first=code<<shift
                for i in range(1<<shift): table[first+i]=packed
    r=BitReader(data[pos:]+b'\0\0'); out=bytearray(); row=pixels=finished=previous=0
    while finished<rows_needed:
        if r.peek(6)==0x3F:
            r.read(6); q=r.read(7); repeat=((q>>4)&7)+1; pal=q&0x0F
        else:
            idx=r.peek(8); packed=table[idx]; bit_len=(packed>>8)&0xFF
            if not bit_len: raise ValueError('bad Nemesis prefix')
            r.read(bit_len); repeat=((packed>>4)&7)+1; pal=packed&0x0F
        for _ in range(repeat):
            if finished>=rows_needed: break
            row=(row<<4)|pal; pixels+=1
            if pixels==8:
                value=row
                if xor_mode: value^=previous; previous=value
                out.extend(value.to_bytes(4,'big')); finished+=1; row=pixels=0
    return bytes(out)

def genesis_color(word:int, transparent=False):
    if transparent: return (0,0,0,0)
    return (((word>>1)&7)*255//7,((word>>5)&7)*255//7,((word>>9)&7)*255//7,255)

def palette_line(data:bytes):
    return [genesis_color(int.from_bytes(data[i*2:i*2+2],'big'),i==0) for i in range(16)]

def tile_pixels(raw:bytes, idx:int):
    t=raw[idx*32:(idx+1)*32]; rows=[]
    for y in range(8):
        row=[]
        for b in t[y*4:y*4+4]: row.extend([b>>4,b&0xF])
        rows.append(row)
    return rows

def render_mapping(raw:bytes,mappings:bytes,frame:int,palettes,base_palette:int)->Image.Image:
    off=be16(mappings,frame*2); count=be16(mappings,off); pieces=[]
    for i in range(count):
        q=mappings[off+2+i*8:off+10+i*8]
        if len(q)<8: raise ValueError(f'truncated mapping frame {frame}')
        y=int.from_bytes(q[0:1],'big',signed=True); size=q[1]; attr=be16(q,2); x=int.from_bytes(q[6:8],'big',signed=True)
        pieces.append((y,size,attr,x))
    canvas=Image.new('RGBA',(192,192),(0,0,0,0)); pix=canvas.load(); ox=oy=96
    for y,size,attr,x in reversed(pieces):
        wt=((size>>2)&3)+1; ht=(size&3)+1; base=attr&0x7FF; hf=bool(attr&0x0800); vf=bool(attr&0x1000)
        mp=(attr>>13)&3; pal=palettes[(base_palette|mp)&3]
        for dx in range(wt):
            for dy in range(ht):
                sx=wt-1-dx if hf else dx; sy=ht-1-dy if vf else dy
                tp=tile_pixels(raw,base+sx*ht+sy)
                for yy in range(8):
                    for xx in range(8):
                        ci=tp[7-yy if vf else yy][7-xx if hf else xx]
                        if not ci: continue
                        px=ox+x+dx*8+xx; py=oy+y+dy*8+yy
                        if 0<=px<192 and 0<=py<192: pix[px,py]=pal[ci]
    return canvas

def save_bank(source:Path, folder:str, art_name:str, mappings:bytes, base_palette:int, frames:int, palettes):
    raw=nemesis_decode((source/'art/nemesis'/art_name).read_bytes())
    dest=OUT/folder; dest.mkdir(parents=True,exist_ok=True)
    for old in dest.glob('*.png'): old.unlink()
    for frame in range(frames):
        render_mapping(raw,mappings,frame,palettes,base_palette).save(dest/f'{frame:02d}.png')
    print(folder,frames)

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_cpz_hazards_phase92.py <retail Sonic 2 source root>')
    source=Path(sys.argv[1]); OUT.mkdir(parents=True,exist_ok=True)
    sonic=(source/'art/palettes/SonicAndTails.bin').read_bytes(); cpz=(source/'art/palettes/CPZ.bin').read_bytes()
    palettes=[palette_line(sonic)]+[palette_line(cpz[i*32:(i+1)*32]) for i in range(3)]
    save_bank(source,'blue','CPZ worm enemy.bin',(source/'mappings/sprite/obj1D.bin').read_bytes(),3,1,palettes)
    save_bank(source,'spiny','Weird crawling badnik from CPZ.bin',(source/'mappings/sprite/objA6.bin').read_bytes(),1,8,palettes)
    built=(source/'s2built.bin').read_bytes()
    # ObjA7 mapping table is inline in the retail built ROM at $3921A.
    # Copy enough of the mapping block to retain all seven body/leg frames.
    grab_map=built[0x3921A:0x39340]
    save_bank(source,'grabber','Spider badnik from CPZ.bin',grab_map,1,7,palettes)

if __name__=='__main__': main()
