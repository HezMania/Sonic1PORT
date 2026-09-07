#!/usr/bin/env python3
from __future__ import annotations
import hashlib, importlib.util, json, tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
DATA = PROJECT / 'data/s1/s2test'
ROOT = PROJECT

checks=[]
def check(cond,msg):
    checks.append((bool(cond),msg))
    print(('PASS' if cond else 'FAIL')+': '+msg)


def be16(data,off): return (data[off]<<8)|data[off+1]

def read_layout(path):
    b=path.read_bytes(); w=b[0]+1; h=b[1]+1; body=b[2:]
    assert len(body)==w*h,(path,len(body),w,h)
    return w,h,body

def word_old(map256, layout, wx_block, wy_block):
    w,h,body=layout
    cx=wx_block//16; cy=wy_block//16
    if cx>=w or cy>=h: return 0
    cid=body[cy*w+cx]
    if cid==0: return 0
    bx=wx_block&15; by=wy_block&15
    off=(cid-1)*512+(by*16+bx)*2
    return be16(map256,off) if off+1<len(map256) else 0

def word_native(map128, layout, wx_block, wy_block):
    w,h,body=layout
    cx=wx_block//8; cy=wy_block//8
    if cx>=w or cy>=h: return 0
    cid=body[cy*w+cx]
    if cid==0: return 0
    bx=wx_block&7; by=wy_block&7
    off=cid*128+(by*8+bx)*2
    return be16(map128,off) if off+1<len(map128) else 0

def compare_plane(label, old_map, old_layout, native_map, native_layout, native_rows=None):
    ow,oh,_=old_layout; nw,nh,_=native_layout
    max_bx=nw*8; max_by=(native_rows if native_rows is not None else nh)*8
    mismatches=[]
    for by in range(max_by):
        for bx in range(max_bx):
            a=word_old(old_map,old_layout,bx,by)
            b=word_native(native_map,native_layout,bx,by)
            if a!=b:
                mismatches.append((bx,by,a,b))
                if len(mismatches)>=8: break
        if len(mismatches)>=8: break
    check(not mismatches, f'{label}: native 128x128 raw block words exactly match Phase 76/64 converted world geometry')
    if mismatches:
        print('  mismatches:',mismatches)
    return max_bx*max_by

# Shipped files / dimensions.
expected={
 'ehz1_map128.bin':32768,'ehz1_layout128.bin':2050,'ehz1_bg128.bin':2050,
 'hpz1_map128.bin':32768,'hpz1_layout128.bin':2050,'hpz1_bg128.bin':74,
}
for name,size in expected.items():
    p=DATA/name
    check(p.is_file(),f'{name} exists')
    if p.is_file(): check(p.stat().st_size==size,f'{name} size = {size}')

# Native chunk zero is retained, exactly like Sonic 2 Map128 storage.
for zone in ('ehz1','hpz1'):
    m=(DATA/f'{zone}_map128.bin').read_bytes()
    check(not any(m[:128]),f'{zone}: source chunk 0 retained as all-zero 128-byte record')
    check(len(m)//128==256,f'{zone}: native bank contains all 256 source chunk records')

# World-size identity versus old converted representation.
ehz_old_fg=read_layout(DATA/'ehz1_layout.bin'); ehz_new_fg=read_layout(DATA/'ehz1_layout128.bin')
ehz_old_bg=read_layout(DATA/'ehz1_bg.bin'); ehz_new_bg=read_layout(DATA/'ehz1_bg128.bin')
hpz_old_fg=read_layout(DATA/'hpz1_layout.bin'); hpz_new_fg=read_layout(DATA/'hpz1_layout128.bin')
hpz_old_bg=read_layout(DATA/'hpz1_bg.bin'); hpz_new_bg=read_layout(DATA/'hpz1_bg128.bin')
check((ehz_old_fg[0]*256,ehz_old_fg[1]*256)==(ehz_new_fg[0]*128,ehz_new_fg[1]*128),'EHZ foreground world dimensions unchanged')
check((ehz_old_bg[0]*256,ehz_old_bg[1]*256)==(ehz_new_bg[0]*128,ehz_new_bg[1]*128),'EHZ background world dimensions unchanged')
check((hpz_old_fg[0]*256,hpz_old_fg[1]*256)==(hpz_new_fg[0]*128,hpz_new_fg[1]*128),'HPZ foreground world dimensions unchanged')
check(hpz_new_bg[0]*128==hpz_old_bg[0]*256,'HPZ background width unchanged')
check(hpz_new_bg[1]*128==9*128,'HPZ native background drops Phase 76-only padded tenth 128px row')

# Exhaustive raw word parity over source extents.
ehz_old_map=(DATA/'ehz1_map256.bin').read_bytes(); ehz_native_map=(DATA/'ehz1_map128.bin').read_bytes()
hpz_old_map=(DATA/'hpz1_map256.bin').read_bytes(); hpz_native_map=(DATA/'hpz1_map128.bin').read_bytes()
count=0
count+=compare_plane('EHZ foreground',ehz_old_map,ehz_old_fg,ehz_native_map,ehz_new_fg)
count+=compare_plane('EHZ background',ehz_old_map,ehz_old_bg,ehz_native_map,ehz_new_bg)
count+=compare_plane('HPZ foreground',hpz_old_map,hpz_old_fg,hpz_native_map,hpz_new_fg)
count+=compare_plane('HPZ background source extent',hpz_old_map,hpz_old_bg,hpz_native_map,hpz_new_bg,native_rows=9)
check(count==397824,f'exhaustive parity covered {count:,} world 16x16 block positions')

# Old Phase76 padded final HPZ BG half-row must be zero.
padded_ok=True
for by in range(72,80):
    for bx in range(64):
        if word_old(hpz_old_map,hpz_old_bg,bx,by)!=0:
            padded_ok=False; break
check(padded_ok,'Phase 76 HPZ background padding removed without discarding nonzero source terrain')

# Full-byte layout IDs are exercised natively (proves no 7-bit fallback).
check(max(ehz_new_bg[2])==0xFF,'EHZ native background exercises chunk ID $FF')
check(max(hpz_new_bg[2])==0xE7,'HPZ native background exercises chunk ID $E7')
check(max(hpz_new_fg[2])==0xB9,'HPZ native foreground exercises chunk ID $B9')

# Catalog/runtime wiring assertions.
catalog=(ROOT/'scripts/data/level_catalog.gd').read_text()
level_data=(ROOT/'scripts/data/ghz_level_data.gd').read_text()
renderer=(ROOT/'scripts/render/ghz_renderer.gd').read_text()
bgr=(ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
camera=(ROOT/'scripts/camera/sonic_camera.gd').read_text()
player=(ROOT/'scripts/player/sonic_player.gd').read_text()
check(catalog.count('"chunk_pixel_size": 128')>=2,'both experimental Sonic 2 slots select native 128px chunks')
check('ehz1_map128.bin' in catalog and 'hpz1_map128.bin' in catalog,'catalog uses native Map128 banks for EHZ and HPZ')
check('ehz1_map256.bin' not in catalog and 'hpz1_map256.bin' not in catalog,'runtime catalog no longer references converted S2 Map256 banks')
check('func chunk_data_offset(chunk_id: int)' in level_data and 'chunk_storage_includes_zero' in level_data,'level data supports source-native chunk-0 storage')
check('var shift = chunk_shift()' in level_data and 'var blocks = blocks_per_chunk()' in level_data,'terrain collision addressing uses per-level chunk geometry')
check('level.chunk_pixel_size()' in renderer and 'level.chunk_data_offset(chunk_id)' in renderer,'foreground renderer uses per-level chunk geometry')
check('background_chunk_size = level.chunk_pixel_size() if mode == "s2test" else 256' in bgr,'S2 test background renderer uses native chunk size')
check('player.level.world_width_pixels()' in camera and 'player.level.world_height_pixels()' in camera,'debug camera bounds use physical world dimensions')
check(player.count('level.world_width_pixels()')>=3 and player.count('level.world_height_pixels()')>=2,'player debug/absolute bounds use physical world dimensions')

# Preserve S1 defaults/paths.
check('return int(definition.get("chunk_pixel_size", 256))' in level_data,'Sonic 1 defaults remain 256x256')
check('return (chunk_id - 1) * chunk_record_bytes()' in level_data,'Sonic 1 chunk bank retains ID-1 storage convention')
check('return raw_chunk_id & 0x7F' in level_data,'Sonic 1 layout bit-7 semantics remain intact')

# Manifest provenance and regenerated native files.
manifest=json.loads((DATA/'phase77_native_manifest.json').read_text())
check(manifest.get('phase')==77 and manifest.get('runtime_chunk_bytes')==128,'Phase 77 native manifest identifies 128-byte Map128 records')

# Optional source regeneration if roots are supplied in known sibling work dirs.
retail_src=PROJECT.parent/'s2'/'Sonic 2'
simon_src=PROJECT.parent/'s2sw'/'Sonic-2-Simon-Wai-Disassembly-main'
if retail_src.is_dir() and simon_src.is_dir():
    tool=ROOT/'tools/import_s2_native_chunks.py'
    import subprocess
    with tempfile.TemporaryDirectory() as td:
        dest=Path(td)/'data/s1'; dest.mkdir(parents=True)
        r=subprocess.run(['python',str(tool),str(retail_src),str(simon_src),str(dest)],capture_output=True,text=True)
        check(r.returncode==0,'native importer regenerates from both supplied Sonic 2 sources')
        if r.returncode==0:
            for name in expected:
                check((dest/'s2test'/name).read_bytes()==(DATA/name).read_bytes(),f'source regeneration matches {name} byte-for-byte')
else:
    print('SKIP: source regeneration roots not present beside project')

passed=sum(1 for ok,_ in checks if ok); total=len(checks)
print(f'\n{passed}/{total} checks passed')
if passed!=total:
    raise SystemExit(1)
