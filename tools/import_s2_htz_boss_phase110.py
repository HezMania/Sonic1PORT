#!/usr/bin/env python3
"""Phase 110: retail Sonic 2 Hill Top boss, Act-2 rising lava, and capsule art."""
from __future__ import annotations
from pathlib import Path
from PIL import Image
import importlib.util, hashlib, json, sys
import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'assets/objects/s2_htz'
DATA=PROJECT/'data/s1/s2test'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
bossutil=load('bossutil110',PROJECT/'tools/import_s2_ehz_boss.py')
trav=load('trav110',PROJECT/'tools/import_s2_cpz_traversal_phase91.py')
p95=load('p95110',PROJECT/'tools/import_s2_arz1_phase95.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def render_mapping(raw: bytes, mappings: bytes, frame: int, palettes, base_palette: int) -> Image.Image:
    return bossutil.render_frame(raw,mappings,frame,palettes,base_palette)

def render_plane_crop(art:bytes,map16:bytes,map128:bytes,bg_with_header:bytes,x0:int,y0:int,w:int,h:int)->np.ndarray:
    bg=bg_with_header[2:]
    indices=np.zeros((h,w),dtype=np.uint8); cache={}
    cx0,cx1=x0//128,(x0+w-1)//128; cy0,cy1=y0//128,(y0+h-1)//128
    for cy in range(cy0,cy1+1):
        for cx in range(cx0,cx1+1):
            cid=bg[cy*128+cx]
            chunk=p95.render_chunk(map128,map16,art,cid,cache)
            wx,wy=cx*128,cy*128
            ix0=max(x0,wx); iy0=max(y0,wy); ix1=min(x0+w,wx+128); iy1=min(y0+h,wy+128)
            indices[iy0-y0:iy1-y0,ix0-x0:ix1-x0]=chunk[iy0-wy:iy1-wy,ix0-wx:ix1-wx]
    return indices

def write_cycle_crop(folder:Path,indices:np.ndarray,palettes,cycle):
    folder.mkdir(parents=True,exist_ok=True)
    for p in folder.glob('*.png'): p.unlink()
    for frame in range(16):
        flat=[]
        for line in palettes: flat.extend(line)
        c=cycle[frame*4:frame*4+4]
        flat[19],flat[20],flat[30],flat[31]=c[0],c[1],c[2],c[3]
        lut=np.array(flat,dtype=np.uint8); rgba=lut[indices]; rgba[:,:,3]=255
        Image.fromarray(rgba,'RGBA').save(folder/f'{frame:02d}.png')

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_htz_boss_phase110.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve()
    sonic=(src/'art/palettes/SonicAndTails.bin').read_bytes(); htz=(src/'art/palettes/HTZ.bin').read_bytes()
    palettes=[bossutil.decode_line(sonic)]+[bossutil.decode_line(htz[i*32:(i+1)*32]) for i in range(3)]

    egg=bossutil.nemesis_decompress((src/'art/nemesis/Eggpod.bin').read_bytes())
    hboss=bossutil.nemesis_decompress((src/'art/nemesis/HTZ boss.bin').read_bytes())
    maps=(src/'mappings/sprite/obj52_b.bin').read_bytes()
    assert len(egg)//32==96
    combined=egg+hboss
    main_dir=OUT/'boss/main'; main_dir.mkdir(parents=True,exist_ok=True)
    flame_dir=OUT/'boss/flame'; flame_dir.mkdir(parents=True,exist_ok=True)
    proj_dir=OUT/'boss/projectile'; proj_dir.mkdir(parents=True,exist_ok=True)
    for d in (main_dir,flame_dir,proj_dir):
        for p in d.glob('*.png'): p.unlink()
    # Main Eggpod-based mappings can address the HTZ boss PLC immediately after the 96 Eggpod tiles.
    for frame in (1,16): render_mapping(combined,maps,frame,palettes,0).save(main_dir/f'{frame:02d}.png')
    # Attached flame frames are children of the Eggpod-based parent, so use the combined bank.
    for frame in range(2,12): render_mapping(combined,maps,frame,palettes,0).save(flame_dir/f'{frame:02d}.png')
    # Free-moving flamethrower/lava-ball children have ArtNem_HTZBoss as their art base.
    for frame in range(12,16): render_mapping(hboss,maps,frame,palettes,0).save(proj_dir/f'{frame:02d}.png')

    smoke=bossutil.nemesis_decompress((src/'art/nemesis/Smoke trail from CPZ and HTZ bosses.bin').read_bytes())
    smoke_maps=(src/'mappings/sprite/obj52_a.bin').read_bytes(); smoke_dir=OUT/'boss/smoke'; smoke_dir.mkdir(parents=True,exist_ok=True)
    for p in smoke_dir.glob('*.png'): p.unlink()
    for frame in range(4): render_mapping(smoke,smoke_maps,frame,palettes,0).save(smoke_dir/f'{frame:02d}.png')

    fire=bossutil.nemesis_decompress((src/'art/nemesis/Fireball 1.bin').read_bytes())
    fire_maps=(src/'mappings/sprite/obj20_b.bin').read_bytes(); fire_dir=OUT/'boss/fire'; fire_dir.mkdir(parents=True,exist_ok=True)
    for p in fire_dir.glob('*.png'): p.unlink()
    for frame in range(6): render_mapping(fire,fire_maps,frame,palettes,1).save(fire_dir/f'{frame:02d}.png')

    prison=bossutil.nemesis_decompress((src/'art/nemesis/Egg Prison.bin').read_bytes())
    prison_maps=(src/'mappings/sprite/obj3E.bin').read_bytes(); prison_dir=OUT/'egg_prison'; prison_dir.mkdir(parents=True,exist_ok=True)
    for p in prison_dir.glob('*.png'): p.unlink()
    for frame in range(6): render_mapping(prison,prison_maps,frame,palettes,1).save(prison_dir/f'{frame:02d}.png')

    # Lower-route HTZ2 Obj30 subtype 6 has d1=$EB,d2=$78 -> raw half-width $E0 and full 448x240 body.
    # LevEvents_HTZ2 lower route sets Camera_BG_X_offset=-$680; the authored lava face is therefore the
    # Plane-B rectangle at world collision X + $680.
    art=(DATA/'htz2_art.bin').read_bytes(); map16=(DATA/'htz2_map16.bin').read_bytes(); map128=(DATA/'htz2_map128.bin').read_bytes(); bg=(DATA/'htz2_bg128.bin').read_bytes()
    cycle_raw=(src/'art/palettes/Hill Top Lava.bin').read_bytes()
    cycle=[trav.genesis_color(int.from_bytes(cycle_raw[i*2:i*2+2],'big'),False) for i in range(len(cycle_raw)//2)]
    assert len(cycle)>=64
    crops={
      'quake_lava_act2_a': (0x1760+0x680-0xE0, 0x4F0-0x78, 0x1C0, 0xF0),
      'quake_lava_act2_b': (0x1920+0x680-0xE0, 0x4F0-0x78, 0x1C0, 0xF0),
    }
    for name,(x0,y0,w,h) in crops.items():
        idx=render_plane_crop(art,map16,map128,bg,x0,y0,w,h)
        write_cycle_crop(OUT/name,idx,palettes,cycle)

    files=[]
    for folder in ('boss/main','boss/flame','boss/projectile','boss/smoke','boss/fire','egg_prison','quake_lava_act2_a','quake_lava_act2_b'):
        files += sorted((OUT/folder).glob('*.png'))
    manifest={
      'phase':110,'boss':'Object $52','boss_hits':8,'boss_start':[0x3040,0x580],
      'camera':{'cutoff':0x2B00,'shift':0x2C50,'lock_trigger':0x2EDF,'left':0x2EE0,'right':0x2F5E,'bottom':0x480,'top_lock':0x478,'post_x':0x30E0,'top_release':0x428,'bottom_release':0x430,'escape_right':0x3160},
      'act2_lava':{'subtype':6,'half_width':0xE0,'half_height':0x78,'size':[448,240],'placements':[0x1760,0x1920]},
      'files':{str(p.relative_to(PROJECT)):sha(p) for p in files},
    }
    (DATA/'phase110_htz_boss_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
