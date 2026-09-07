#!/usr/bin/env python3
"""Phase 108 HTZ runtime-fidelity art derived from retail Sonic 2 sources."""
from pathlib import Path
import importlib.util, sys, json, hashlib
from PIL import Image, ImageOps
import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'assets/objects/s2_htz'
DATA = PROJECT / 'data/s1/s2test'

def load_module(name, path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
trav=load_module('trav108', PROJECT/'tools/import_s2_cpz_traversal_phase91.py')
p95=load_module('p95108', PROJECT/'tools/import_s2_arz1_phase95.py')

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def be16(b,o): return (b[o]<<8)|b[o+1]

def render_mapping_piece(raw: bytes, mappings: bytes, frame: int, piece_index: int, palettes, base_palette: int) -> Image.Image:
    offset=be16(mappings,frame*2); count=be16(mappings,offset)
    if not 0 <= piece_index < count: raise IndexError(piece_index)
    q=mappings[offset+2+piece_index*8:offset+10+piece_index*8]
    y=int.from_bytes(q[0:1],'big',signed=True); size=q[1]; attr=be16(q,2); x=int.from_bytes(q[6:8],'big',signed=True)
    canvas=Image.new('RGBA',(192,192),(0,0,0,0)); pix=canvas.load(); ox=oy=96
    wt=((size>>2)&3)+1; ht=(size&3)+1; base=attr&0x7FF
    hf=bool(attr&0x0800); vf=bool(attr&0x1000); mp=(attr>>13)&3
    pal=palettes[(base_palette|mp)&3]
    for dx in range(wt):
        for dy in range(ht):
            sx=wt-1-dx if hf else dx; sy=ht-1-dy if vf else dy
            tp=trav.tile_pixels(raw,base+sx*ht+sy)
            for yy in range(8):
                for xx in range(8):
                    ci=tp[7-yy if vf else yy][7-xx if hf else xx]
                    if not ci: continue
                    px=ox+x+dx*8+xx; py=oy+y+dy*8+yy
                    if 0<=px<192 and 0<=py<192: pix[px,py]=pal[ci]
    return canvas

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_htz_fidelity_phase108.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve()
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); htz=(src/'art/palettes/HTZ.bin').read_bytes()
    palettes=[trav.palette_line(sonic)]+[trav.palette_line(htz[i*32:(i+1)*32]) for i in range(3)]

    # Obj16 status bit 0 remains a render X-flip in retail. Bake a mirrored copy
    # of every mapping frame so the hook/vine art stays visibly mirrored across
    # texture swaps and the stripped falling frame.
    src_lift=OUT/'lift'; dst=OUT/'lift_flipped'; dst.mkdir(parents=True,exist_ok=True)
    for p in dst.glob('*.png'): p.unlink()
    for p in sorted(src_lift.glob('*.png')):
        ImageOps.mirror(Image.open(p).convert('RGBA')).save(dst/p.name)

    # Obj32 HTZ rock frame 0 is six authored pieces. BreakObjectToPieces keeps
    # those mapping offsets and assigns Obj32_VelArray1 to the six children.
    rock_raw=trav.nemesis_decode((src/'art/nemesis/Rock from HTZ.bin').read_bytes())
    rock_map=(src/'mappings/sprite/obj32_a.bin').read_bytes()
    off=be16(rock_map,0); count=be16(rock_map,off)
    assert count==6, count
    d=OUT/'rock_fragment'; d.mkdir(parents=True,exist_ok=True)
    for p in d.glob('*.png'): p.unlink()
    for i in range(count): render_mapping_piece(rock_raw,rock_map,0,i,palettes,2).save(d/f'{i:02d}.png')

    # Obj30 is collision-only in the ROM. The visible rising lava is the exact
    # Plane-B rectangle behind subtype $04: x $1C80-$1DFF, y $478-$567. Render
    # that authored 384x240 area from HTZ's native chunk/block/tile data instead
    # of substituting the unrelated generic Lava.bin (the Phase-107 source of
    # the yellow/brown art mismatch).
    art=(DATA/'htz1_art.bin').read_bytes(); map16=(DATA/'htz1_map16.bin').read_bytes(); map128=(DATA/'htz1_map128.bin').read_bytes()
    bg=(DATA/'htz1_bg128.bin').read_bytes()[2:]
    x0,y0,w,h=0x1C80,0x478,0x180,0xF0
    indices=np.zeros((h,w),dtype=np.uint8); cache={}
    cx0,cx1=x0//128,(x0+w-1)//128; cy0,cy1=y0//128,(y0+h-1)//128
    for cy in range(cy0,cy1+1):
        for cx in range(cx0,cx1+1):
            cid=bg[cy*128+cx]
            chunk=p95.render_chunk(map128,map16,art,cid,cache)
            wx,wy=cx*128,cy*128
            ix0=max(x0,wx); iy0=max(y0,wy); ix1=min(x0+w,wx+128); iy1=min(y0+h,wy+128)
            indices[iy0-y0:iy1-y0,ix0-x0:ix1-x0]=chunk[iy0-wy:iy1-wy,ix0-wx:ix1-wx]

    cycle_raw=(src/'art/palettes/Hill Top Lava.bin').read_bytes()
    cycle=[trav.genesis_color(int.from_bytes(cycle_raw[i*2:i*2+2],'big'),False) for i in range(len(cycle_raw)//2)]
    assert len(cycle)>=64
    d=OUT/'quake_lava'; d.mkdir(parents=True,exist_ok=True)
    for p in d.glob('*.png'): p.unlink()
    for frame in range(16):
        flat=[]
        for line in palettes: flat.extend(line)
        c=cycle[frame*4:frame*4+4]
        flat[19],flat[20],flat[30],flat[31]=c[0],c[1],c[2],c[3]
        lut=np.array(flat,dtype=np.uint8)
        rgba=lut[indices]
        # World-plane color index zero is backdrop, not transparency. The crop is
        # authored lava/terrain and must remain opaque all the way to its bottom.
        rgba[:,:,3]=255
        Image.fromarray(rgba,'RGBA').save(d/f'{frame:02d}.png')

    files=[]
    for folder in ('lift_flipped','rock_fragment','quake_lava'):
        files.extend(sorted((OUT/folder).glob('*.png')))
    manifest={'phase':108,'files':{str(p.relative_to(PROJECT)):sha(p) for p in files},
              'lift_flipped_frames':len(list((OUT/'lift_flipped').glob('*.png'))),
              'rock_fragments':count,'quake_lava_frames':16,'quake_lava_size':[384,240]}
    (DATA/'phase108_htz_fidelity_art_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
