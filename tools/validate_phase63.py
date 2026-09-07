#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from zipfile import ZipFile
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE_ZIP = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/mnt/data/Sonic1PC_InteractionFidelity_Phase62.zip')
SOURCE_ZIP = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('/mnt/data/phase55src/s1disasm-AS(2).zip')
checks: list[tuple[str,bool,str]] = []

def check(name, ok, detail=''):
    checks.append((name, bool(ok), detail))

def sha_bytes(b: bytes): return hashlib.sha256(b).hexdigest()

def sha_file(p: Path): return sha_bytes(p.read_bytes())

# Required files / source asset.
for rel in [
    'scripts/render/level_art_animator.gd',
    'scripts/render/ghz_background_renderer.gd',
    'data/s1/artunc/SBZ Background Smoke.unc',
]:
    check(f'exists: {rel}', (ROOT/rel).is_file())

ani_asm = constants = ''
if SOURCE_ZIP.is_file():
    with ZipFile(SOURCE_ZIP) as zf:
        src = zf.read('s1disasm-AS/artunc/SBZ Background Smoke.unc')
        dst = (ROOT/'data/s1/artunc/SBZ Background Smoke.unc').read_bytes()
        check('SBZ smoke art byte-identical to disassembly', src == dst, f'{len(dst)} bytes')
        check('SBZ smoke source size is 7 x 12 tiles', len(dst) == 7*12*32, f'{len(dst)} bytes')
        ani_asm = zf.read('s1disasm-AS/_inc/AnimateLevelGfx.asm').decode('latin1')
        constants = zf.read('s1disasm-AS/_Constants.asm').decode('latin1')
else:
    check('authoritative source ZIP available', False, str(SOURCE_ZIP))

for label, token in [
    ('puff 1 tile', 'ArtTile_SBZ_Smoke_Puff_1:\tequ ArtTile_Level+$448'),
    ('puff 2 tile', 'ArtTile_SBZ_Smoke_Puff_2:\tequ ArtTile_Level+$454'),
]:
    check(f'source VRAM slot: {label}', token in constants)
for label, token in [
    ('puff 1 frame time', 'move.b\t#8-1,(v_lani0_time).w'),
    ('puff 2 frame time', 'move.b\t#8-1,(v_lani1_time).w'),
    ('puff 1 inter-cycle wait', 'move.b\t#3*60,(v_lani2_frame).w'),
    ('puff 2 inter-cycle wait', 'move.b\t#2*60,(v_lani2_time).w'),
]:
    check(f'source timing: {label}', token in ani_asm)

anim = (ROOT/'scripts/render/level_art_animator.gd').read_text()
bg = (ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
for token in [
    'SBZ_SMOKE_PUFF1_TILE = 0x448',
    'SBZ_SMOKE_PUFF2_TILE = 0x454',
    'LevelCatalog.ZONE_SBZ:',
    'SBZ Background Smoke.unc',
    'func _tick_sbz()',
    'lani0_time = 8 - 1',
    'lani1_time = 8 - 1',
    'lani2_frame = 3 * 60',
    'lani2_time = 2 * 60',
    'background.refresh_sbz_art_range(SBZ_SMOKE_PUFF1_TILE, 24)',
]:
    check(f'animator token: {token}', token in anim)
check('SBZ blank state duplicates first six source tiles', 'destination_tile + 6' in anim and '6 * GHZLevelData.TILE_BYTES' in anim)
check('SBZ changes batched into one background notification', anim.count('_notify_sbz_art_change()') == 2, 'one call site + function definition')

# Independent source timing simulation: capture the first 500 VBlank write events.
def source_events(n=500):
    l0t=l0f=l1t=l1f=l2t=l2f=0
    out=[]
    for tick in range(1,n+1):
        ev=[]
        if l2f:
            l2f=(l2f-1)&0xff
        else:
            l0t-=1
            if l0t<0:
                l0t=7; d=l0f&0xff; l0f=(l0f+1)&0xff; d&=7
                if d==0:
                    l2f=180; ev.append(('p1','blank'))
                else:
                    ev.append(('p1',d-1))
        if l2t:
            l2t=(l2t-1)&0xff
        else:
            l1t-=1
            if l1t<0:
                l1t=7; d=l1f&0xff; l1f=(l1f+1)&0xff; d&=7
                if d==0:
                    l2t=120; ev.append(('p2','blank'))
                else:
                    ev.append(('p2',d-1))
        if ev: out.append((tick,tuple(ev)))
    return out

ev = source_events()
expected_prefix = [
    (1, (('p1','blank'),('p2','blank'))),
    (129, (('p2',0),)),
    (137, (('p2',1),)),
    (145, (('p2',2),)),
    (153, (('p2',3),)),
    (161, (('p2',4),)),
    (169, (('p2',5),)),
    (177, (('p2',6),)),
    (185, (('p2','blank'),)),
    (189, (('p1',0),)),
]
check('SBZ source schedule prefix matches 68000 counters', ev[:10] == expected_prefix, repr(ev[:10]))
check('puff 1 first visible frame is VBlank 189', any(t==189 and ('p1',0) in e for t,e in ev))
check('puff 2 first visible frame is VBlank 129', any(t==129 and ('p2',0) in e for t,e in ev))
check('visible smoke frames are exactly 8 VBlanks apart', all((b[0]-a[0])==8 for seq in ['p1','p2'] for a,b in zip([x for x in ev if any(q[0]==seq and q[1] != 'blank' for q in x[1])], [x for x in ev if any(q[0]==seq and q[1] != 'blank' for q in x[1])][1:]) if (b[0]-a[0]) < 100))

# Layout period verification; this proves the compact repeating plane is exact.
def layout_period(path: Path):
    b=path.read_bytes(); w=b[0]+1; h=b[1]+1; a=b[2:2+w*h]
    px=next(k for k in range(1,w+1) if w%k==0 and all(a[y*w+x]==a[y*w+(x%k)] for y in range(h) for x in range(w)))
    py=next(k for k in range(1,h+1) if h%k==0 and all(a[y*w+x]==a[(y%k)*w+x] for y in range(h) for x in range(w)))
    return w,h,px,py
w1,h1,px1,py1=layout_period(ROOT/'data/s1/levels/sbz1bg.bin')
w2,h2,px2,py2=layout_period(ROOT/'data/s1/levels/sbz2bg.bin')
check('SBZ1 background exact repeat period = 5x2 chunks', (w1,h1,px1,py1)==(30,2,5,2), f'{w1}x{h1} -> {px1}x{py1}')
check('SBZ2 background exact repeat period = 3x2 chunks', (w2,h2,px2,py2)==(60,6,3,2), f'{w2}x{h2} -> {px2}x{py2}')
check('SBZ1 compact texture <= 1280x512', px1*256 <=1280 and py1*256<=512)
check('SBZ2 compact texture <= 768x512', px2*256 <=768 and py2*256<=512)
for token in [
    'func _sbz_background_repeat_period()',
    'sbz_plane_width = sbz_repeat_chunks.x * 256',
    'sbz_plane_height = sbz_repeat_chunks.y * 256',
    'func refresh_sbz_art_range(',
    'sbz_plane_texture.update(sbz_plane_image)',
    'func _collect_sbz_plane_tile_patches(',
]:
    check(f'background token: {token}', token in bg)

# Independently decode source maps and prove the animated slots are used by
# SBZ1's compact period but not SBZ2's background (matching the shipped maps).
def kos(data: bytes) -> bytes:
    out=bytearray(); source=2; desc=data[0]|(data[1]<<8); bits=16
    def bit(source,desc,bits):
        v=desc&1; desc>>=1; bits-=1
        if bits==0:
            desc=data[source]|(data[source+1]<<8); source+=2; bits=16
        return v,source,desc,bits
    while source<len(data):
        a,source,desc,bits=bit(source,desc,bits)
        if a: out.append(data[source]); source+=1; continue
        b,source,desc,bits=bit(source,desc,bits)
        if not b:
            hi,source,desc,bits=bit(source,desc,bits); lo,source,desc,bits=bit(source,desc,bits)
            length=((hi<<1)|lo)+2; disp=data[source]-0x100; source+=1
        else:
            low,high=data[source],data[source+1]; source+=2
            disp=(0xE000|((high&0xF8)<<5)|low)-0x10000; short=high&7
            if short: length=short+2
            else:
                extra=data[source]; source+=1
                if extra==0: break
                if extra==1: continue
                length=extra+1
        for _ in range(length): out.append(out[len(out)+disp])
    return bytes(out)
class BR:
    def __init__(self,d): self.d=d; self.p=0
    def read(self,n):
        v=0
        for _ in range(n):
            v=(v<<1)|((self.d[self.p>>3]>>(7-(self.p&7)))&1); self.p+=1
        return v
    def peek(self,n): p=self.p;v=self.read(n);self.p=p;return v
def enigma(data: bytes) -> bytes:
    inline,flags=data[0],data[1]; inc=(data[2]<<8)|data[3]; lit=(data[4]<<8)|data[5]
    r=BR(data[6:]); out=bytearray()
    def add(v): out.extend(((v>>8)&255,v&255))
    def inval():
        w=0
        for f,t in [(4,15),(3,14),(2,13),(1,12),(0,11)]:
            if flags&(1<<f) and r.read(1): w|=1<<t
        return (w+r.read(inline))&0xffff
    while True:
        pk=r.peek(7)
        if pk<0x40: r.read(6); e=pk; rep=pk>>1
        else: r.read(7); e=pk; rep=pk
        count=(rep&15)+1; op=e>>4
        if op in (0,1):
            for _ in range(count): add(inc); inc=(inc+1)&0xffff
        elif op in (2,3):
            for _ in range(count): add(lit)
        elif op==4:
            v=inval()
            for _ in range(count): add(v)
        elif op==5:
            v=inval()
            for _ in range(count): add(v); v=(v+1)&0xffff
        elif op==6:
            v=inval()
            for _ in range(count): add(v); v=(v-1)&0xffff
        elif op==7:
            if (rep&15)==15: break
            for _ in range(count): add(inval())
    return bytes(out)
def be16(d,o): return (d[o]<<8)|d[o+1]
chunks=kos((ROOT/'data/s1/map256/SBZ (REV01).kos').read_bytes())
blocks=enigma((ROOT/'data/s1/map16/SBZ.eni').read_bytes())
def patch_count(bgname,px,py):
    b=(ROOT/'data/s1/levels'/bgname).read_bytes(); w=b[0]+1; a=b[2:]
    n=0
    for cy in range(py):
        for cx in range(px):
            cid=a[cy*w+cx]; base=(cid-1)*512
            for i in range(256):
                cw=be16(chunks,base+i*2); bid=cw&0x3ff
                for slot in range(4):
                    ti=be16(blocks,bid*8+slot*2)&0x7ff
                    if 0x448<=ti<=0x45f: n+=1
    return n
p1=patch_count('sbz1bg.bin',px1,py1); p2=patch_count('sbz2bg.bin',px2,py2)
check('SBZ1 compact period contains smoke tile placements', p1==84, f'{p1} 8x8 placements')
check('SBZ2 background contains no smoke tile placements', p2==0, f'{p2} placements')

# Baseline isolation: only two runtime scripts differ from confirmed Phase 62.
if BASE_ZIP.is_file():
    with ZipFile(BASE_ZIP) as zf:
        base_names={n for n in zf.namelist() if not n.endswith('/')}
        current_names={str(p.relative_to(ROOT)).replace('\\','/') for p in ROOT.rglob('*') if p.is_file()}
        runtime_diffs=[]
        for rel in sorted(base_names & current_names):
            if not (rel.startswith('scripts/') or rel.endswith('.tscn') or rel=='project.godot'):
                continue
            if zf.read(rel)!=(ROOT/rel).read_bytes(): runtime_diffs.append(rel)
        check('only SBZ animation/background runtime scripts changed', runtime_diffs == [
            'scripts/render/ghz_background_renderer.gd',
            'scripts/render/level_art_animator.gd',
        ], repr(runtime_diffs))
        for rel in [
            'scripts/audio/sonic_audio.gd',
            'scripts/main.gd',
            'scripts/player/sonic_player.gd',
            'scripts/collision/genesis_collision.gd',
            'scripts/ui/level_title_card_ui.gd',
            'scripts/ui/end_card_ui.gd',
            'scripts/render/genesis_palette_fade.gd',
            'scripts/render/ghz_renderer.gd',
            'scripts/objects/badnik_object.gd',
            'scripts/objects/monitor_object.gd',
            'scripts/objects/giant_ring_object.gd',
            'project.godot',
        ]:
            check(f'frozen Phase 62 baseline: {rel}', zf.read(rel)==(ROOT/rel).read_bytes())
else:
    check('Phase 62 baseline ZIP available', False, str(BASE_ZIP))

# Within the two modified renderer files, previously accepted zone routines
# should remain byte-identical to Phase 62.
def extract_func(text: str, name: str) -> str:
    start=text.find(f'func {name}(')
    if start<0: return ''
    nxt=text.find('\nfunc ', start+1)
    return text[start:] if nxt<0 else text[start:nxt]
if BASE_ZIP.is_file():
    with ZipFile(BASE_ZIP) as zf:
        base_anim=zf.read('scripts/render/level_art_animator.gd').decode('utf-8')
        cur_anim=anim
        for fn in ['_tick_ghz','_tick_mz','_build_mz_magma_frame','_notify_art_change']:
            check(f'frozen prior animator function: {fn}', extract_func(base_anim,fn).rstrip()==extract_func(cur_anim,fn).rstrip())
        base_bg=zf.read('scripts/render/ghz_background_renderer.gd').decode('utf-8')
        cur_bg=bg
        for fn in ['_setup_ghz','_setup_mz','_setup_lz','_setup_syz','_setup_slz','_update_mz','_update_lz','_update_slz','_update_syz','_update_ghz','refresh_mz_art_range']:
            check(f'frozen non-SBZ background function: {fn}', extract_func(base_bg,fn).rstrip()==extract_func(cur_bg,fn).rstrip())

# Carry-forward compatibility / UI controls.
main=(ROOT/'scripts/main.gd').read_text()
ss=(ROOT/'scripts/data/special_stage_art.gd').read_text()
check('U remains audio mode toggle', 'KEY_U' in main and 'SonicAudio.toggle_output_mode()' in main)
check('Special Stage parser fix palette_line uses =', 'var palette_line = [0, 3, 1, 2][block_id - 0x2D]' in ss)
check('Special Stage parser fix flash_palette uses =', 'var flash_palette = [0, 3, 1, 2][block_id - 0x4B]' in ss)

passed=sum(ok for _,ok,_ in checks)
print(f'Phase 63 validation: {passed}/{len(checks)} checks passed')
for name,ok,detail in checks:
    print(f'[{"PASS" if ok else "FAIL"}] {name}' + (f' — {detail}' if detail else ''))
if passed != len(checks): raise SystemExit(1)
