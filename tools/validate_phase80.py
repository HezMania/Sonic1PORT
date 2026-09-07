#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from PIL import Image
import hashlib, importlib.util, subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg,detail=''):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg+((' — '+detail) if detail else ''))

def sha(p:Path): return hashlib.sha256(p.read_bytes()).hexdigest()

def parse(data:bytes):
    out=[]; off=0; term=False
    while off+1<len(data):
        x=int.from_bytes(data[off:off+2],'big'); off+=2
        if x&0x8000: term=True; break
        if off+1>=len(data): break
        yd=int.from_bytes(data[off:off+2],'big'); off+=2
        out.append((x,yd&0xFFF,bool(yd&0x8000),((yd>>12)&7)+1,yd))
    return out,term

catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()
manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
ring=(PROJECT/'scripts/objects/ring_group_object.gd').read_text()

check('"s2_rings": "s2test/ehz1_rings.bin"' in catalog,'EHZ test definition enables native S2 ring data')
check('"s2_rings": "s2test/hpz1_rings.bin"' in catalog,'HPZ test definition enables native S2 ring data')
check('func _load_s2_ring_positions(path: String) -> bool:' in manager,'object manager has source-native S2 ring parser')
check('(y_descriptor & 0x8000) != 0' in manager and '(y_descriptor >> 12) & 7' in manager,'S2 vertical/count descriptor bits are decoded directly')
check('var orientation = 4 if vertical else 1' in manager,'S2 descriptors map to existing exact $18 vertical/horizontal RingGroup spacing')
check('"id": 0x25' in manager,'native S2 descriptors feed the established ring-group object')
check('records.sort_custom' in manager,'source ring groups are sorted for ObjPosLoad after parsing')
check('mini(8, (subtype & 7) + 1)' in ring,'ring group supports full 1..8 source count')
check('art_folder = "s2_rings"' in ring and 'experimental_sonic2' in ring,'S2 test levels select source S2 ring mappings without changing S1 art')

for name,groups_expected,rings_expected in [('ehz1',137,226),('hpz1',92,219)]:
    p=PROJECT/f'data/s1/s2test/{name}_rings.bin'
    check(p.is_file(),f'{name.upper()} native ring binary is packaged')
    if p.is_file():
        groups,term=parse(p.read_bytes())
        check(term,f'{name.upper()} ring list retains negative-X source terminator')
        check(len(groups)==groups_expected,f'{name.upper()} source descriptor count is {groups_expected}',str(len(groups)))
        check(sum(x[3] for x in groups)==rings_expected,f'{name.upper()} expands to {rings_expected} exact rings',str(sum(x[3] for x in groups)))
        if name=='hpz1': check(sum(x[3]==8 for x in groups)==2,'HPZ preserves both valid eight-ring source groups')

for i in range(8):
    p=PROJECT/f'assets/objects/s2_rings/{i:02d}.png'
    check(p.is_file(),f'S2 ring mapping frame {i} is packaged')
    if p.is_file(): check(Image.open(p).size==(96,96),f'S2 ring mapping frame {i} keeps source-centered 96x96 canvas')

# Phase 79 must remain a clean baseline regression.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase79.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 79 animation/physics/camera validator still passes')

if len(sys.argv)>=3:
    retail=Path(sys.argv[1]); beta=Path(sys.argv[2])
    src_e=retail/'level/rings/EHZ_1.bin'; src_h=beta/'level/rings/HPZ_1.bin'
    check(src_e.read_bytes()==(PROJECT/'data/s1/s2test/ehz1_rings.bin').read_bytes(),'EHZ ring descriptors are byte-for-byte retail source')
    check(src_h.read_bytes()==(PROJECT/'data/s1/s2test/hpz1_rings.bin').read_bytes(),'HPZ ring descriptors are byte-for-byte Simon Wai source')

    spec=importlib.util.spec_from_file_location('p80import',PROJECT/'tools/import_s2_rings.py'); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    art=mod.nemesis_decompress((retail/'art/nemesis/Ring.bin').read_bytes())
    rm=(retail/'mappings/sprite/Rings.bin').read_bytes(); bm=(beta/'mappings/sprite/obj25.bin').read_bytes()
    for fr in range(8):
        ro=int.from_bytes(rm[fr*2:fr*2+2],'big'); bo=int.from_bytes(bm[fr*2:fr*2+2],'big')
        check(int.from_bytes(bm[bo:bo+2],'big')==1 and rm[ro:ro+8]==bm[bo+2:bo+10],f'Beta/final ring visual piece {fr} is byte-identical')
    ep=mod.decode_palette_line((retail/'art/palettes/EHZ.bin').read_bytes())
    hp=mod.decode_palette_line((beta/'art/palettes/HPZ.bin').read_bytes())
    used=set()
    for b in art: used.update((b>>4,b&15))
    check(all(ep[i]==hp[i] for i in used if i),'EHZ and Simon Wai HPZ share all palette entries used by ring art')
    rendered=mod.render_retail_ring_frames(art,rm,ep)
    for i,im in enumerate(rendered):
        shipped=Image.open(PROJECT/f'assets/objects/s2_rings/{i:02d}.png').convert('RGBA')
        check(list(im.getdata())==list(shipped.getdata()),f'S2 ring frame {i} regenerates pixel-for-pixel from source')
else:
    print('SKIP: pass retail S2 root and Simon Wai root for source-regeneration checks')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE80_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
