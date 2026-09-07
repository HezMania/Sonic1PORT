#!/usr/bin/env python3
"""Phase 95: import retail Sonic 2 Aquatic Ruin Act 1 core data/presentation."""
from __future__ import annotations
import hashlib, importlib.util, json, re, struct, sys
from collections import Counter
from pathlib import Path
import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'tools'; OUT=PROJECT/'data'/'s1'; S2TEST=OUT/'s2test'; PAL=OUT/'palette'; SOUND=OUT/'sound'; ASSET=PROJECT/'assets'/'objects'/'s2_arz'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain',TOOLS/'import_sonic2_level.py')
pres=load('pres',TOOLS/'import_s2_ehz_presentation.py')
trav=load('trav',TOOLS/'import_s2_cpz_traversal_phase91.py')

def sha(b): return hashlib.sha256(b).hexdigest()
def be16(b,o): return (b[o]<<8)|b[o+1]
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

def extract_apm(src:Path):
    text=(src/'s2.lst').read_text(errors='replace')
    ms=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_ARZ label \*',text)
    me=re.search(r'(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_ARZ_End:',text)
    if not ms or not me: raise ValueError('APM_ARZ not found')
    s,e=int(ms.group(1),16),int(me.group(1),16); rom=(src/'s2built.bin').read_bytes()
    dest=be16(rom,s); words=be16(rom,s+2)+1; patch=rom[s+4:e]
    if len(patch)!=words*2: raise ValueError('APM_ARZ size mismatch')
    return dest,patch

def seed_anim(src:Path, art:bytes):
    v=bytearray(0x800*32); v[:min(len(art),len(v))]=art[:len(v)]
    entries=[
      ('art/uncompressed/ARZ waterfall patterns - 1.bin',0x557,0),
      ('art/uncompressed/ARZ waterfall patterns - 1.bin',0x430,4),
      ('art/uncompressed/ARZ waterfall patterns - 2.bin',0x42C,0),
      ('art/uncompressed/ARZ waterfall patterns - 3.bin',0x428,0),
    ]
    for rel,dst,src_tile in entries:
        raw=(src/rel).read_bytes(); piece=raw[src_tile*32:src_tile*32+4*32]
        if len(piece)!=128: raise ValueError(rel)
        v[dst*32:dst*32+128]=piece
    return bytes(v)

def tile_pixels(art:bytes, tile:int):
    a=np.zeros((8,8),dtype=np.uint8); off=tile*32
    if off+32>len(art): return a
    for y in range(8):
        for x in range(8):
            b=art[off+y*4+(x>>1)]; a[y,x]=(b>>4)&15 if (x&1)==0 else b&15
    return a

def render_block(map16:bytes,art:bytes,block_id:int,bfx=False,bfy=False):
    out=np.zeros((16,16),dtype=np.uint8)
    for oy in range(2):
      for ox in range(2):
        sx=1-ox if bfx else ox; sy=1-oy if bfy else oy
        o=block_id*8+(sy*2+sx)*2
        if o+1>=len(map16): continue
        w=(map16[o]<<8)|map16[o+1]; ti=w&0x7ff; pal=(w>>13)&3
        fx=bool(w&0x0800)^bfx; fy=bool(w&0x1000)^bfy
        t=tile_pixels(art,ti)
        if fx:t=np.fliplr(t)
        if fy:t=np.flipud(t)
        # color zero stays global palette index zero/transparent-style backdrop
        q=np.where(t==0,0,pal*16+t).astype(np.uint8)
        out[oy*8:(oy+1)*8,ox*8:(ox+1)*8]=q
    return out

def render_chunk(map128:bytes,map16:bytes,art:bytes,cid:int,cache:dict):
    if cid in cache:return cache[cid]
    out=np.zeros((128,128),dtype=np.uint8); base=cid*128
    for by in range(8):
      for bx in range(8):
        o=base+(by*8+bx)*2
        if o+1>=len(map128):continue
        w=(map128[o]<<8)|map128[o+1]
        bid=w&0x3ff; bfx=bool(w&0x0400); bfy=bool(w&0x0800)
        out[by*16:(by+1)*16,bx*16:(bx+1)*16]=render_block(map16,art,bid,bfx,bfy)
    cache[cid]=out; return out

def build_bg_indices(bg:bytes,map128:bytes,map16:bytes,art:bytes,w=128,h=12):
    plane=np.zeros((h*128,w*128),dtype=np.uint8); cache={0:np.zeros((128,128),dtype=np.uint8)}
    for cy in range(h):
      for cx in range(w):
        cid=bg[cy*w+cx]
        plane[cy*128:(cy+1)*128,cx*128:(cx+1)*128]=render_chunk(map128,map16,art,cid,cache)
    return plane.tobytes(),len(cache)

def add_song_and_dac(src:Path):
    data=pres.saxman_decompress((src/'sound/music/ARZ.bin').read_bytes())
    pres.PORT_MUSIC_ID=0x198
    pres.label=lambda kind,off:f"S2ARZ_{'D' if kind=='DAC' else ('P' if kind=='PSG' else 'F')}_{off:04X}"
    song=pres.parse_song(data); song['id']=0x198; song['name']='Sonic 2 - Aquatic Ruin Zone'; song['header']['voice_label']='S2ARZ_Voices'
    # Preserve source tempo. Existing S2 path uses the retail speed-shoes tempo mechanism.
    dbp=SOUND/'s2_ehz_smps.json'; db=json.loads(dbp.read_text()); db.setdefault('music',{})[str(0x198)]=song; dbp.write_text(json.dumps(db,indent=2)+'\n')
    # ARZ adds raw DAC events $83 and $8D -> event IDs 2 and 12.
    # Sonic 2 zDACMasterPlaylist: $83 = Sample 3, delay $06; $8D = Sample 6, delay $05.
    for event_id,sample_no,delay in [(2,3,0x06),(12,6,0x05)]:
        raw=(src/'sound/DAC'/f'Sample {sample_no}.bin').read_bytes(); dec=pres.decode_s2_dac(raw)
        rate=3579540.0/(60.0+delay*4.0)/2.0; vals=pres.resample_linear(dec,rate,pres.MIX_RATE)
        pres.write_pcm16(SOUND/f's2_ehz_dac_{event_id:02d}.pcm',vals)
    return song

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_arz1_phase95.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); S2TEST.mkdir(parents=True,exist_ok=True); PAL.mkdir(parents=True,exist_ok=True); SOUND.mkdir(parents=True,exist_ok=True); ASSET.mkdir(parents=True,exist_ok=True)
    req={
      'art':src/'art/kosinski/ARZ.bin','map16':src/'mappings/16x16/ARZ.bin','map128':src/'mappings/128x128/ARZ.bin',
      'layout':src/'level/layout/ARZ_1.bin','objects':src/'level/objects/ARZ_1.bin','rings':src/'level/rings/ARZ_1.bin','start':src/'startpos/ARZ_1.bin',
      'colp':src/'collision/ARZ primary 16x16 collision index.bin','cols':src/'collision/ARZ secondary 16x16 collision index.bin',
      'pal':src/'art/palettes/ARZ.bin','underwater':src/'art/palettes/ARZ underwater.bin','cycle':src/'art/palettes/EHZ ARZ Water.bin',
      'waterart':src/'art/nemesis/Top of water in ARZ.bin','watermap':src/'mappings/sprite/obj04_b.bin',
      'platformmap':src/'mappings/sprite/obj18_b.bin','sonicpal':src/'art/palettes/SonicAndTails.bin','music':src/'sound/music/ARZ.bin',
    }
    for p in req.values():
      if not p.is_file(): raise FileNotFoundError(p)
    art=seed_anim(src,terrain.kosinski_decompress(req['art'].read_bytes()))
    base16=terrain.kosinski_decompress(req['map16'].read_bytes()); dest,patch=extract_apm(src); map16=bytearray(0x1800); map16[:len(base16)]=base16; map16[dest:dest+len(patch)]=patch; map16=bytes(map16)
    map128=terrain.kosinski_decompress(req['map128'].read_bytes()); layout=terrain.kosinski_decompress(req['layout'].read_bytes()); colp=terrain.kosinski_decompress(req['colp'].read_bytes()); cols=terrain.kosinski_decompress(req['cols'].read_bytes())
    if len(layout)!=0x1000 or len(map128)!=0x8000: raise ValueError((len(layout),len(map128)))
    fg=bytearray();bg=bytearray()
    for row in range(16):
      base=row*0x100; fg+=layout[base:base+0x80]; bg+=layout[base+0x80:base+0x100]
    bgindices,unique=build_bg_indices(bytes(bg),map128,map16,art,128,12)
    outputs={
      'arz1_art.bin':art,'arz1_map16.bin':map16,'arz1_map128.bin':map128,'arz1_layout128.bin':header(128,16,fg),'arz1_bg128.bin':header(128,16,bg),
      'arz1_collision_primary.bin':colp,'arz1_collision_secondary.bin':cols,'arz1_objects.bin':req['objects'].read_bytes(),'arz1_rings.bin':req['rings'].read_bytes(),'arz1_start.bin':req['start'].read_bytes(),
      'arz1_bg_indices.bin':bgindices,
    }
    for n,b in outputs.items():(S2TEST/n).write_bytes(b)
    (PAL/'S2 Aquatic Ruin Zone.bin').write_bytes(req['pal'].read_bytes()); (PAL/'S2 Aquatic Ruin Underwater.bin').write_bytes(req['underwater'].read_bytes()); (PAL/'S2 EHZ ARZ Water Cycle.bin').write_bytes(req['cycle'].read_bytes())
    # Source platform frames (Obj18 ARZ bank) from resident level art.
    sonic=req['sonicpal'].read_bytes(); zone=req['pal'].read_bytes(); palettes=[trav.palette_line(sonic)]+[trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    pd=ASSET/'platform'; pd.mkdir(parents=True,exist_ok=True)
    for old in pd.glob('*.png'):old.unlink()
    for frame in range(2): trav.render_mapping(art,req['platformmap'].read_bytes(),frame,palettes,2).save(pd/f'{frame:02d}.png')
    # ARZ-specific two-frame water surface.
    wd=ASSET/'water_surface'; wd.mkdir(parents=True,exist_ok=True)
    for old in wd.glob('*.png'):old.unlink()
    raw=trav.nemesis_decode(req['waterart'].read_bytes()); maps=req['watermap'].read_bytes()
    for frame in range(2): trav.render_mapping(raw,maps,frame,palettes,0).save(wd/f'{frame:02d}.png')
    song=add_song_and_dac(src)
    obj=outputs['arz1_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6)); supported={0x03,0x0D,0x18,0x26,0x36,0x40,0x41,0x79}; sc=sum(v for k,v in counts.items() if k in supported)
    manifest={'phase':95,'level':'Aquatic Ruin Zone Act 1','start':[be16(outputs['arz1_start.bin'],0),be16(outputs['arz1_start.bin'],2)],'limits':{'left':0,'right':0x28C0,'top':0x200,'bottom':0x600},'water':{'static_y':0x410},'layout_128':[128,16],'background_128':[128,16],'background_index_plane':[16384,1536],'background_unique_chunks':unique,'object_records':len(obj)//6,'supported_shared_records':sc,'deferred_arz_specific_records':len(obj)//6-sc,'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},'apm_arz':{'destination':dest,'bytes':len(patch)},'music':{'id':0x198,'tempo':song['header']['tempo_mod'],'voices':len(song['voices']),'dac_ids':song['source']['used_dac_ids']},'output_sha256':{k:sha(v) for k,v in outputs.items()}}
    (S2TEST/'phase95_arz1_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n'); print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
