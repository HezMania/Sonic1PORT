#!/usr/bin/env python3
"""Phase 112: reconstruct retail Sonic 2 Mystic Cave object graphics."""
from pathlib import Path
import importlib.util, json, hashlib, sys

P=Path(__file__).resolve().parents[1]
OUT=P/'assets/objects/s2_mcz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
trav=load('trav112',P/'tools/import_s2_cpz_traversal_phase91.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def s8(v): return v-0x100 if v&0x80 else v
def s16(v): return v-0x10000 if v&0x8000 else v

def mapping_blob(frames):
    table=bytearray(len(frames)*2); body=bytearray()
    for fi,pieces in enumerate(frames):
        off=len(frames)*2+len(body); table[fi*2:fi*2+2]=off.to_bytes(2,'big'); body+=len(pieces).to_bytes(2,'big')
        for y,size,attr,aux,x in pieces:
            body+=bytes((y&0xff,size&0xff)); body+=(attr&0xffff).to_bytes(2,'big'); body+=(aux&0xffff).to_bytes(2,'big'); body+=(x&0xffff).to_bytes(2,'big')
    return bytes(table+body)

def pieces(m,frame):
    off=be16(m,frame*2); n=be16(m,off); out=[]
    for i in range(n):
        q=off+2+i*8; out.append((s8(m[q]),m[q+1],be16(m,q+2),be16(m,q+4),s16(be16(m,q+6))))
    return out

def save_bank(raw,maps,folder,pals,base):
    d=OUT/folder; d.mkdir(parents=True,exist_ok=True)
    for p in d.glob('*.png'): p.unlink()
    n=be16(maps,0)//2
    for i in range(n): trav.render_mapping(raw,maps,i,pals,base).save(d/f'{i:02d}.png')
    return n

def render_mapping_sized(raw,mappings,frame,palettes,base_palette,size=320):
    from PIL import Image
    off=be16(mappings,frame*2); count=be16(mappings,off); pcs=[]
    for i in range(count):
        q=off+2+i*8; pcs.append((s8(mappings[q]),mappings[q+1],be16(mappings,q+2),s16(be16(mappings,q+6))))
    canvas=Image.new('RGBA',(size,size),(0,0,0,0)); pix=canvas.load(); origin=size//2
    for y,sz,attr,x in reversed(pcs):
        wt=((sz>>2)&3)+1; ht=(sz&3)+1; bt=attr&0x7FF; hf=bool(attr&0x0800); vf=bool(attr&0x1000); pal=palettes[(base_palette|((attr>>13)&3))&3]
        for dx in range(wt):
            for dy in range(ht):
                sx=wt-1-dx if hf else dx; sy=ht-1-dy if vf else dy; tp=trav.tile_pixels(raw,bt+sx*ht+sy)
                for yy in range(8):
                    for xx in range(8):
                        ci=tp[7-yy if vf else yy][7-xx if hf else xx]
                        if ci==0: continue
                        px=origin+x+dx*8+xx; py=origin+y+dy*8+yy
                        if 0<=px<size and 0<=py<size: pix[px,py]=pal[ci]
    return canvas

def save_bank_sized(raw,maps,folder,pals,base,size=320):
    d=OUT/folder; d.mkdir(parents=True,exist_ok=True)
    for p in d.glob('*.png'): p.unlink()
    n=be16(maps,0)//2
    for i in range(n): render_mapping_sized(raw,maps,i,pals,base,size).save(d/f'{i:02d}.png')
    return n

def save_pieces(raw,maps,frame,folder,pals,base):
    d=OUT/folder; d.mkdir(parents=True,exist_ok=True)
    for p in d.glob('*.png'): p.unlink()
    ps=pieces(maps,frame)
    for i,piece in enumerate(ps): trav.render_mapping(raw,mapping_blob([[piece]]),0,pals,base).save(d/f'{i:02d}.png')
    return len(ps)

INLINE_NORMAL=mapping_blob([
 [(-8,9,0x6060,0x6030,-24),(-8,9,0x6860,0x6830,0)],
 [(-8,5,0x6066,0x6033,-8)],
 [(-24,5,0x406A,0x4035,-12),(-8,0x0B,0x406E,0x4037,-12)],
 [(-88,5,0x406A,0x4035,-12),(-72,0x0B,0x406E,0x4037,-12),(-56,5,0x6066,0x6033,-8),(-40,5,0x6066,0x6033,-8),(-24,5,0x6066,0x6033,-8),(-8,5,0x6066,0x6033,-8),(8,5,0x6066,0x6033,-8),(24,5,0x6066,0x6033,-8),(40,5,0x6066,0x6033,-8),(56,5,0x6066,0x6033,-8)],
])
INLINE_HAZARD=mapping_blob([
 [(-8,0x0D,0x6058,0x602C,-32),(-8,0x0D,0x6858,0x682C,0)],
 [(-8,5,0x6066,0x6033,-8)],
 [(-24,5,0x406A,0x4035,-12),(-8,0x0B,0x406E,0x4037,-12)],
])

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_mcz_objects_phase112.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); OUT.mkdir(parents=True,exist_ok=True)
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); zone=(src/'art/palettes/MCZ.bin').read_bytes()
    pals=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    art=(P/'data/s1/s2test/mcz1_art.bin').read_bytes()
    result={}
    specs=[
      ('collapse','obj1F_c.bin',0x3F4,3),('stomper','obj2A.bin',0,2),('crate','obj6A.bin',0x3D4,3),
      ('brick','obj75.bin',0,1),('sliding_spikes','obj76.bin',0,0),('gate','obj77.bin',0x43C,3),
      ('pull_switch','obj7F.bin',0x40E,3),('vine','obj80_a.bin',0x41E,3),('drawbridge','obj81.bin',0x43C,3),
      ('crawlton','obj9E.bin',0x3C0,1),('flasher','objA3.bin',0x3A8,0),
    ]
    for folder,mapn,tile,base in specs:
        mp=(src/'mappings/sprite'/mapn).read_bytes(); raw=art[tile*32:] if tile else art
        result[folder]=save_bank_sized(raw,mp,folder,pals,base,320) if folder=='vine' else save_bank(raw,mp,folder,pals,base)
    result['collapse_fragments']=save_pieces(art[0x3F4*32:],(src/'mappings/sprite/obj1F_c.bin').read_bytes(),1,'collapse_fragments',pals,3)
    # Shared inline MCZ platform/swing mappings use absolute level-art tiles.
    result['shared_platform']=save_bank(art,INLINE_NORMAL,'shared_platform',pals,0)
    result['swing_hazard']=save_bank(art,INLINE_HAZARD,'swing_hazard',pals,0)
    # Obj77/81 use the same individual log tile; expose a centered single-log frame for bridge rotation.
    one_log=mapping_blob([[(-8,5,0,0,-8)]])
    result['gate_log']=save_bank(art[0x43C*32:],one_log,'gate_log',pals,3)
    obj=(P/'data/s1/s2test/mcz1_objects.bin').read_bytes()
    deferred_ids={0x15,0x1F,0x2A,0x6A,0x75,0x76,0x77,0x7A,0x7F,0x80,0x81,0x9E,0xA3}
    completed=sum(1 for i in range(0,len(obj),6) if obj[i+4] in deferred_ids)
    manifest={'phase':112,'frames':result,'mcz1_records':len(obj)//6,'newly_active_records':completed,'native_placement_coverage':len(obj)//6,'sha256':{}}
    for p in sorted(OUT.rglob('*.png')): manifest['sha256'][str(p.relative_to(OUT))]=hashlib.sha256(p.read_bytes()).hexdigest()
    (P/'data/s1/s2test/phase112_mcz_objects_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
