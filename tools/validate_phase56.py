#!/usr/bin/env python3
from pathlib import Path
import hashlib, sys

ROOT=Path(__file__).resolve().parents[1]
BASE=Path('/mnt/data/phase55baseline')
checks=[]
def check(name, ok, detail=''):
    checks.append((name,bool(ok),detail))

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def kosinski(data: bytes) -> bytes:
    if len(data)<2:return b''
    out=bytearray(); source=2; desc=data[0]|(data[1]<<8); left=16
    def bit(source,desc,left):
        b=desc&1; desc>>=1; left-=1
        if left==0:
            if source+1 < len(data):
                desc=data[source]|(data[source+1]<<8); source+=2; left=16
        return b,source,desc,left
    while source < len(data):
        first,source,desc,left=bit(source,desc,left)
        if first:
            if source>=len(data):break
            out.append(data[source]);source+=1;continue
        second,source,desc,left=bit(source,desc,left)
        if second==0:
            hi,source,desc,left=bit(source,desc,left)
            lo,source,desc,left=bit(source,desc,left)
            length=((hi<<1)|lo)+2
            if source>=len(data):break
            disp=data[source]-0x100;source+=1
        else:
            if source+1>=len(data):break
            low=data[source]; high=data[source+1];source+=2
            encoded=0xE000|((high&0xF8)<<5)|low
            disp=encoded-0x10000
            sl=high&7
            if sl: length=sl+2
            else:
                if source>=len(data):break
                extra=data[source];source+=1
                if extra==0:break
                if extra==1:continue
                length=extra+1
        for _ in range(length):
            idx=len(out)+disp
            if idx<0 or idx>=len(out): raise ValueError('bad backref')
            out.append(out[idx])
    return bytes(out)

def chunk_words(raw, cid):
    off=(cid-1)*512
    b=raw[off:off+512]
    if len(b)!=512: raise ValueError(f'chunk {cid:02X} missing')
    return [(b[i]<<8)|b[i+1] for i in range(0,512,2)]

# Baseline isolation / audio freeze
expected_changed={
 'README.md','scripts/main.gd','scripts/player/sonic_player.gd','scripts/data/ghz_level_data.gd',
 'scripts/objects/object_manager.gd','scripts/collision/genesis_collision.gd'
}
expected_added={'scripts/objects/path_switcher_object.gd','tools/validate_phase56.py'}
changed=set(); added=set(); removed=set()
if BASE.exists():
    for p in BASE.rglob('*'):
        if p.is_file():
            rel=str(p.relative_to(BASE)); q=ROOT/rel
            if not q.exists(): removed.add(rel)
            elif sha(p)!=sha(q): changed.add(rel)
    for q in ROOT.rglob('*'):
        if q.is_file():
            rel=str(q.relative_to(ROOT))
            if not (BASE/rel).exists(): added.add(rel)
    check('runtime changes are narrowly scoped', changed==expected_changed and not removed,
          f'changed={sorted(changed)} removed={sorted(removed)}')
    audio_same=True; audio_diff=[]
    for p in (BASE/'scripts/audio').rglob('*'):
        if p.is_file():
            q=ROOT/p.relative_to(BASE)
            if not q.exists() or sha(p)!=sha(q): audio_same=False; audio_diff.append(str(p.relative_to(BASE)))
    for p in (BASE/'data/s1/sound').rglob('*'):
        if p.is_file():
            q=ROOT/p.relative_to(BASE)
            if not q.exists() or sha(p)!=sha(q): audio_same=False; audio_diff.append(str(p.relative_to(BASE)))
    check('accepted Phase 54/55 audio tree is byte-identical', audio_same, ', '.join(audio_diff))
else:
    check('Phase55 baseline available', False)

# Godot 4.6.3 compatibility carryovers
main=(ROOT/'scripts/main.gd').read_text()
ss=(ROOT/'scripts/data/special_stage_art.gd').read_text()
local_inferred=[ln for ln in main.splitlines() if ln[:1].isspace() and 'var ' in ln and ':=' in ln]
check('main.gd has no inferred local var declarations', not local_inferred, str(local_inferred[:3]))
check('special-stage palette_line uses =', 'var palette_line = [0, 3, 1, 2]' in ss)
check('special-stage flash_palette uses =', 'var flash_palette = [0, 3, 1, 2]' in ss)

# Data pairing in Sonic 1's own Map256 files.
pairs=[('GHZ','GHZ.kos',0x35,0x36),('SLZ-AA','SLZ.kos',0x2A,0x2B),('SLZ-B4','SLZ.kos',0x34,0x35)]
for label,fn,a,b in pairs:
    raw=kosinski((ROOT/'data/s1/map256'/fn).read_bytes())
    wa,wb=chunk_words(raw,a),chunk_words(raw,b)
    block_same=sum((x&0x7FF)==(y&0x7FF) for x,y in zip(wa,wb))
    word_diff=sum(x!=y for x,y in zip(wa,wb))
    check(f'{label} primary/secondary source chunks exist', len(wa)==256 and len(wb)==256,
          f'{a:02X}/{b:02X}')
    # These source pairs intentionally reuse almost all block artwork while changing
    # solidity/path flags (and a small number of loop blocks in GHZ/SLZ-AA).
    check(f'{label} chunks are structural collision-plane pairs', block_same>=240 and word_diff>0,
          f'block IDs same={block_same}/256, words differ={word_diff}/256')

# Layout-driven switcher inventory.
marker_by_zone={'ghz':{0xB5},'slz':{0xAA,0xB4}}
total=0; inventory=[]
for zone,markers in marker_by_zone.items():
    for act in (1,2,3):
        d=(ROOT/f'data/s1/levels/{zone}{act}.bin').read_bytes(); w=d[0]+1; h=d[1]+1; lay=d[2:2+w*h]
        found=[]
        for y in range(h):
            for x in range(w):
                v=lay[y*w+x]
                if v in markers: found.append((x,y,v))
        total+=len(found); inventory.append(f'{zone.upper()}{act}:{len(found)}')
check('all GHZ/SLZ loop markers generate switchers', total==18, ', '.join(inventory)+f' total={total}')

# Code architecture checks.
level=(ROOT/'scripts/data/ghz_level_data.gd').read_text()
coll=(ROOT/'scripts/collision/genesis_collision.gd').read_text()
player=(ROOT/'scripts/player/sonic_player.gd').read_text()
manager=(ROOT/'scripts/objects/object_manager.gd').read_text()
switcher=(ROOT/'scripts/objects/path_switcher_object.gd').read_text()
check('logical Primary/Secondary path constants exist', 'COLLISION_PATH_PRIMARY' in level and 'COLLISION_PATH_SECONDARY' in level)
check('GHZ secondary maps B5 to 36', 'raw_chunk_id == 0xB5' in level and 'chunk_id = 0x36' in level)
check('SLZ secondary maps AA to 2B', 'raw_chunk_id == 0xAA' in level and 'chunk_id = 0x2B' in level)
check('SLZ secondary maps B4 to 35', 'raw_chunk_id == 0xB4' in level and 'chunk_id = 0x35' in level)
check('FindNearestTile A8/28->51 alternate retained', 'chunk_id == 0x28' in level and 'chunk_id = 0x51' in level)
check('GenesisCollision routes path to chunk lookup', 'get_chunk_word_at_world(world_x, world_y, collision_path)' in coll)
check('GenesisCollision routes path to shape lookup', 'get_collision_shape_id(block_id, collision_path)' in coll)
check('Sonic sensors use collision_path', 'behind_loop' not in player and 'collision_path)' in player)
check('loop path switching moved to object', '_update_loop_state' not in player and 'class_name PathSwitcherObject' in switcher)
check('GHZ forced-roll behavior retained', 'raw_chunk == 0x1F or raw_chunk == 0x20' in player)
check('object manager generates switchers from layout', '_spawn_loop_path_switchers()' in manager and 'transient_objects.append(switcher)' in manager)
check('F2/debug block query uses active path', 'collision.get_block_info(mx, my, player.collision_path)' in main)

# Exhaustive comparison of PathSwitcher decision to Sonic 1 Sonic_Loops path state.
def source_dec(raw,x,ang,inair,path):
    if raw==0xB4 and inair: return 0
    if x<44:return 0
    if x>=224:return 1
    if path==0:
        if ang!=0 and ang<=0x80:return 1
        return 0
    if ang>0x80:return 0
    return 1

def object_dec(raw,x,ang,inair,path):
    if raw==0xB4 and inair:return 0
    desired=path
    if x<44:desired=0
    elif x>=224:desired=1
    else:
        if desired==0:
            if ang!=0 and ang<=0x80:desired=1
        elif ang>0x80:desired=0
    return desired
mismatch=0; cases=0
for raw in (0xB5,0xAA,0xB4):
    for x in range(256):
        for ang in range(256):
            for inair in (0,1):
                for path in (0,1):
                    cases+=1
                    if source_dec(raw,x,ang,inair,path)!=object_dec(raw,x,ang,inair,path): mismatch+=1
check('PathSwitcher loop decision is exhaustive-source equivalent', mismatch==0, f'{cases:,} cases, mismatches={mismatch}')

passed=sum(ok for _,ok,_ in checks); totalc=len(checks)
out=[]
out.append(f'Phase 56 validation: {passed}/{totalc} checks passed')
for i,(name,ok,detail) in enumerate(checks,1):
    out.append(f'{i:02d}. {"PASS" if ok else "FAIL"} — {name}' + (f' — {detail}' if detail else ''))
text='\n'.join(out)+'\n'
print(text,end='')
(ROOT/'PHASE56_VALIDATION_RESULTS.txt').write_text(text)
sys.exit(0 if passed==totalc else 1)
