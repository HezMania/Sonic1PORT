#!/usr/bin/env python3
"""Phase 116: reconstruct the retail Sonic 2 Oil Ocean Act 1 object banks."""
from pathlib import Path
import hashlib, importlib.util, json, sys

P=Path(__file__).resolve().parents[1]
OUT=P/'assets/objects/s2_ooz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
trav=load('trav116',P/'tools/import_s2_cpz_traversal_phase91.py')

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

def clear_folder(d):
    d.mkdir(parents=True,exist_ok=True)
    for p in d.glob('*.png'): p.unlink()

def save_bank(raw,maps,folder,pals,base,frames=None):
    d=OUT/folder; clear_folder(d)
    n=be16(maps,0)//2 if frames is None else frames
    for i in range(n): trav.render_mapping(raw,maps,i,pals,base).save(d/f'{i:02d}.png')
    return n

def save_pieces(raw,maps,frame,folder,pals,base):
    d=OUT/folder; clear_folder(d); ps=pieces(maps,frame)
    for i,piece in enumerate(ps): trav.render_mapping(raw,mapping_blob([[piece]]),0,pals,base).save(d/f'{i:02d}.png')
    return len(ps)

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_ooz_objects_phase116.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); OUT.mkdir(parents=True,exist_ok=True)
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); zone=(src/'art/palettes/OOZ.bin').read_bytes()
    pals=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    art=(P/'data/s1/s2test/ooz1_art.bin').read_bytes()
    specs=[
      ('elevator','obj19.bin',0x2F4,3),
      ('oilfall_short','obj1C_c.bin',0x346,2),
      ('oilfall_long','obj1C_d.bin',0x346,2),
      ('collapse','obj1F_b.bin',0x39D,3),
      ('burner_lid','obj33_a.bin',0x32C,3),
      ('burner_flame','obj33_b.bin',0x2E2,3),
      ('launcher_vertical','obj3D.bin',0x332,3),
      ('launcher_horizontal','obj3D.bin',0x3FF,3),
      ('fan_horizontal','obj3F_a.bin',0x403,3),
      ('fan_vertical','obj3F_b.bin',0x403,3),
      ('transporter','obj48.bin',0x368,3),
      ('octus','obj4A.bin',0x538,1),
      ('aquis','obj50.bin',0x500,1),
    ]
    result={}
    for folder,mapn,tile,base in specs:
        maps=(src/'mappings/sprite'/mapn).read_bytes(); raw=art[tile*32:]
        result[folder]=save_bank(raw,maps,folder,pals,base)
    result['collapse_fragments']=save_pieces(art[0x39D*32:],(src/'mappings/sprite/obj1F_b.bin').read_bytes(),1,'collapse_fragments',pals,3)
    # Obj3D has frame 1 (vertical broken) and frame 3 (horizontal broken), each 16 mapping pieces.
    result['launcher_vertical_fragments']=save_pieces(art[0x332*32:],(src/'mappings/sprite/obj3D.bin').read_bytes(),1,'launcher_vertical_fragments',pals,3)
    result['launcher_horizontal_fragments']=save_pieces(art[0x3FF*32:],(src/'mappings/sprite/obj3D.bin').read_bytes(),3,'launcher_horizontal_fragments',pals,3)

    obj=(P/'data/s1/s2test/ooz1_objects.bin').read_bytes(); ids={0x19,0x1C,0x1F,0x33,0x3D,0x3F,0x48,0x4A,0x50}
    counts={f'{i:02X}':sum(1 for o in range(0,len(obj),6) if obj[o+4]==i) for i in sorted(ids)}
    manifest={'phase':116,'frames':result,'completed_ids':sorted(f'{i:02X}' for i in ids),'record_counts':counts,'newly_active_records':sum(counts.values()),'sha256':{}}
    for p in sorted(OUT.rglob('*.png')): manifest['sha256'][str(p.relative_to(OUT))]=hashlib.sha256(p.read_bytes()).hexdigest()
    (P/'data/s1/s2test/phase116_ooz_objects_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
