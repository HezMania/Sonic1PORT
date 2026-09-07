#!/usr/bin/env python3
from pathlib import Path
from zipfile import ZipFile
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE_ZIP = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/mnt/data/Sonic1PC_AnimatedLevelGfx_Phase59.zip')
checks = []

def check(name, ok, detail=''):
    checks.append((name, bool(ok), detail))

def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()

def sha_file(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

# Phase 59's complete source/fidelity suite must still pass separately.
renderer = (ROOT / 'scripts/render/ghz_renderer.gd').read_text()
for token in [
    'const MZ_MAGMA_ANIM_TILE = 0x2D2',
    'func _refresh_mz_magma_visible(',
    '_visible_foreground_chunk_ids(32)',
    'func _collect_chunk_block_patches(',
    'func _redraw_block_patch(',
    'ImageTexture',
    'texture.update(',
]:
    check(f'hotfix token: {token}', token in renderer)
check('magma hot path only', 'first_tile == MZ_MAGMA_ANIM_TILE and tile_count == 16' in renderer)
check('camera culling uses dynamic viewport width', 'display/window/size/viewport_width' in renderer)
check('camera culling uses dynamic viewport height', 'display/window/size/viewport_height' in renderer)
check('32x32 margin avoids edge pop-in', '_visible_foreground_chunk_ids(32)' in renderer)
check('block-level native blit', 'blit_rect(block_high, Rect2i(0, 0, 16, 16)' in renderer)
check('block redraw avoids per-patch Dictionary return', 'func _redraw_block_patch(low_image: Image, high_image: Image, patch: Dictionary, block_image_cache: Dictionary) -> int:' in renderer)

# Only the foreground renderer is allowed to differ from the accepted Phase 59 package.
if BASE_ZIP.is_file():
    with ZipFile(BASE_ZIP) as zf:
        base_names = {n for n in zf.namelist() if not n.endswith('/')}
        current_names = {str(p.relative_to(ROOT)).replace('\\', '/') for p in ROOT.rglob('*') if p.is_file()}
        ignored = {'tools/validate_phase59_hotfix1.py', 'PHASE59_HOTFIX1_PERFORMANCE.md', 'PHASE59_HOTFIX1_VALIDATION_RESULTS.txt'}
        common = sorted((base_names & current_names) - ignored)
        runtime_diffs = []
        all_diffs = []
        for rel in common:
            base = zf.read(rel)
            cur = (ROOT / rel).read_bytes()
            if base != cur:
                all_diffs.append(rel)
                if rel.startswith('scripts/') or rel == 'project.godot' or rel.endswith('.tscn'):
                    runtime_diffs.append(rel)
        check('only one runtime file changed from Phase 59', runtime_diffs == ['scripts/render/ghz_renderer.gd'], repr(runtime_diffs))
        check('LevelArtAnimator byte-identical to Phase 59', zf.read('scripts/render/level_art_animator.gd') == (ROOT/'scripts/render/level_art_animator.gd').read_bytes())
        check('MZ background renderer byte-identical to Phase 59', zf.read('scripts/render/ghz_background_renderer.gd') == (ROOT/'scripts/render/ghz_background_renderer.gd').read_bytes())
        for rel in [
            'scripts/render/genesis_palette_fade.gd',
            'scripts/ui/level_title_card_ui.gd',
            'scripts/player/sonic_player.gd',
            'scripts/collision/genesis_collision.gd',
            'scripts/audio/sonic_audio.gd',
            'scripts/objects/path_switcher_object.gd',
            'scripts/main.gd',
            'project.godot',
        ]:
            check(f'frozen Phase 59 baseline: {rel}', zf.read(rel) == (ROOT/rel).read_bytes())
else:
    check('Phase 59 baseline ZIP available', False, str(BASE_ZIP))

# Decode MZ map data independently and prove the 16x16 aggregation is safe.
def kos(data: bytes) -> bytes:
    out = bytearray()
    source = 2
    desc = data[0] | (data[1] << 8)
    bits_left = 16
    def bit(source, desc, bits_left):
        value = desc & 1
        desc >>= 1
        bits_left -= 1
        if bits_left == 0:
            desc = data[source] | (data[source+1] << 8)
            source += 2
            bits_left = 16
        return value, source, desc, bits_left
    while source < len(data):
        first, source, desc, bits_left = bit(source, desc, bits_left)
        if first:
            out.append(data[source]); source += 1; continue
        second, source, desc, bits_left = bit(source, desc, bits_left)
        if not second:
            hi, source, desc, bits_left = bit(source, desc, bits_left)
            lo, source, desc, bits_left = bit(source, desc, bits_left)
            length = ((hi << 1) | lo) + 2
            displacement = data[source] - 0x100; source += 1
        else:
            low, high = data[source], data[source+1]; source += 2
            displacement = (0xE000 | ((high & 0xF8) << 5) | low) - 0x10000
            short = high & 7
            if short:
                length = short + 2
            else:
                extra = data[source]; source += 1
                if extra == 0: break
                if extra == 1: continue
                length = extra + 1
        for _ in range(length): out.append(out[len(out) + displacement])
    return bytes(out)

class BitReader:
    def __init__(self, data): self.data=data; self.pos=0
    def read(self,n):
        v=0
        for _ in range(n):
            v=(v<<1)|((self.data[self.pos>>3]>>(7-(self.pos&7)))&1); self.pos+=1
        return v
    def peek(self,n): p=self.pos; v=self.read(n); self.pos=p; return v

def enigma(data: bytes) -> bytes:
    inline, flags = data[0], data[1]
    inc=(data[2]<<8)|data[3]; lit=(data[4]<<8)|data[5]
    r=BitReader(data[6:]); out=bytearray()
    def add(v): out.extend(((v>>8)&255, v&255))
    def inline_value():
        word=0
        for f,t in [(4,15),(3,14),(2,13),(1,12),(0,11)]:
            if flags&(1<<f) and r.read(1): word|=1<<t
        return (word+r.read(inline))&0xFFFF
    while True:
        peek=r.peek(7)
        if peek < 0x40: r.read(6); entry=peek; repeat=peek>>1
        else: r.read(7); entry=peek; repeat=peek
        count=(repeat&15)+1; op=entry>>4
        if op in (0,1):
            for _ in range(count): add(inc); inc=(inc+1)&0xFFFF
        elif op in (2,3):
            for _ in range(count): add(lit)
        elif op == 4:
            v=inline_value()
            for _ in range(count): add(v)
        elif op == 5:
            v=inline_value()
            for _ in range(count): add(v); v=(v+1)&0xFFFF
        elif op == 6:
            v=inline_value()
            for _ in range(count): add(v); v=(v-1)&0xFFFF
        elif op == 7:
            if (repeat&15)==15: break
            for _ in range(count): add(inline_value())
    return bytes(out)

def be16(data, off): return (data[off]<<8)|data[off+1]
chunks = kos((ROOT/'data/s1/map256/MZ (REV01).kos').read_bytes())
blocks = enigma((ROOT/'data/s1/map16/MZ.eni').read_bytes())
lo, hi = 0x2D2, 0x2E1
magma_blocks = set()
magma_words = []
for block_id in range(len(blocks)//8):
    words=[be16(blocks, block_id*8+i*2) for i in range(4)]
    hits=[lo <= (w&0x7FF) <= hi for w in words]
    if any(hits):
        magma_blocks.add(block_id)
        magma_words.extend(w for w,h in zip(words,hits) if h)
        check(f'MZ magma block {block_id:03X} is fully animated', all(hits), f'{sum(hits)}/4 tiles')
check('MZ magma uses four 16x16 source blocks', len(magma_blocks)==4, repr(sorted(magma_blocks)))
check('all MZ magma pattern words are high-priority', len(magma_words)==16 and all(w&0x8000 for w in magma_words), f'{len(magma_words)} words')

# Static default-viewport workload comparison. This is not a runtime benchmark;
# it measures the exact number of cached source chunks / patch placements the
# two algorithms would visit for the shipped 320x224 viewport.
def tile_patches(cid):
    n=0; base=(cid-1)*512
    for i in range(256):
        cw=be16(chunks,base+i*2); bid=cw&0x3FF
        for slot in range(4):
            if lo <= (be16(blocks,bid*8+slot*2)&0x7FF) <= hi: n+=1
    return n

def block_patches(cid):
    n=0; base=(cid-1)*512
    for i in range(256):
        bid=be16(chunks,base+i*2)&0x3FF
        if any(lo <= (be16(blocks,bid*8+s*2)&0x7FF) <= hi for s in range(4)): n+=1
    return n

summaries=[]
for act in (1,2,3):
    d=(ROOT/f'data/s1/levels/mz{act}.bin').read_bytes(); w=d[0]+1; h=d[1]+1; layout=list(d[2:2+w*h])
    unique={v&0x7F for v in layout if v&0x7F}
    affected={cid for cid in unique if tile_patches(cid)}
    old_blits=sum(tile_patches(cid) for cid in affected)
    old_uploads=len(affected)
    max_blocks=max_uploads=0
    for sx in range(0,w*256,16):
        for sy in range(0,h*256,16):
            margin=32
            x0=max(0,(sx-margin)>>8); x1=min(w-1,(sx+319+margin)>>8)
            y0=max(0,(sy-margin)>>8); y1=min(h-1,(sy+223+margin)>>8)
            visible={layout[y*w+x]&0x7F for y in range(y0,y1+1) for x in range(x0,x1+1)} & affected
            max_uploads=max(max_uploads,len(visible))
            max_blocks=max(max_blocks,sum(block_patches(cid) for cid in visible))
    summaries.append((act,old_blits,old_uploads,max_blocks,max_uploads))
    check(f'MZ{act} block-blit workload <= 12% of Phase 59 all-cache tile path', max_blocks <= old_blits*0.12, f'{old_blits} -> <= {max_blocks}')
    check(f'MZ{act} texture uploads <= 7 per hot update', max_uploads <= 7, f'{old_uploads} -> <= {max_uploads}')

passed=sum(ok for _,ok,_ in checks)
print(f'Phase 59 Hotfix 1 validation: {passed}/{len(checks)} checks passed')
for name,ok,detail in checks:
    print(f'[{"PASS" if ok else "FAIL"}] {name}' + (f' — {detail}' if detail else ''))
print('WORKLOAD ' + '; '.join(f'MZ{a}: blits {ob}->{nb}, uploads {ou}->{nu}' for a,ob,ou,nb,nu in summaries))
if passed != len(checks): raise SystemExit(1)
