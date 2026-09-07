#!/usr/bin/env python3
from pathlib import Path
import json, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
checks=[]
def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))

def block(text,start,end):
    a=text.find(start)
    if a<0: return ''
    b=text.find(end,a+len(start))
    return text[a:] if b<0 else text[a:b]

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    main_gd=(ROOT/'scripts/main.gd').read_text()
    catalog=(ROOT/'scripts/data/level_catalog.gd').read_text()
    spring=(ROOT/'scripts/objects/s2_spring_object.gd').read_text()
    manifest=json.loads((ROOT/'data/s1/s2test/phase103_cnz2_manifest.json').read_text())

    check('Phase103 HUD identity is active', 'Native Sonic 1 Phase 103' in main_gd)
    check('T key warps directly to CNZ2', 'KEY_T:' in main_gd and '_debug_warp(LevelCatalog.ZONE_S2_CNZ_TEST, 2)' in main_gd)
    check('CNZ catalog accepts both acts', 'clampi(requested_act, 1, 2)' in catalog)
    check('CNZ2 retail right bound is $2A80', '0x27A0 if act == 1 else 0x2A80' in catalog)
    check('CNZ1 progresses to CNZ2', 'Vector2i(ZONE_S2_CNZ_TEST, 2) if act < 2' in catalog)
    check('CNZ2 Egg Prison stays boss-gated', '"s2_egg_prison_requires_boss": act == 2' in catalog)
    check('CNZ2 boss events remain deferred', '"dynamic_events": "none"' in block(catalog,'static func _get_sonic2_cnz_test','static func _get_sonic2_hpz_test'))

    check('up spring native shell half-width is $12', 'resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x10' in spring)
    check('horizontal spring native shell half-width is $0A', 'resolve_solid_box_contact(spawn_x, spawn_y, 0x0A, 0x0F' in spring)
    check('down spring native shell half-width is $12', spring.count('resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x10') == 2)
    check('diagonal-up source slope reach remains intact', 'var d0 = world_x - spawn_x + 27' in spring and 'sample >> 1' in spring)

    required=['cnz2_art.bin','cnz2_map16.bin','cnz2_map128.bin','cnz2_layout128.bin','cnz2_bg128.bin','cnz2_collision_primary.bin','cnz2_collision_secondary.bin','cnz2_objects.bin','cnz2_rings.bin','cnz2_start.bin']
    check('all CNZ2 payload files exist', all((ROOT/'data/s1/s2test'/n).is_file() for n in required))
    check('CNZ2 manifest start is $0060,$058C', manifest.get('start') == [0x60,0x58C])
    check('CNZ2 manifest bounds match retail', manifest.get('limits') == {'left':0,'right':0x2A80,'top':0,'bottom':0x720})
    check('CNZ2 contains 254 retail object records', manifest.get('object_records') == 254)
    check('CNZ2 placement coverage is 254/254', manifest.get('native_placement_records') == 254 and manifest.get('deferred_placement_records') == 0)

    prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase102.py')] + ([str(s2)] if s2 else []),capture_output=True,text=True)
    detail=prev.stdout.strip().splitlines()[-1] if prev.stdout.strip() else prev.stderr.strip()[-200:]
    check('Phase102 regression suite remains clean', prev.returncode==0, detail)

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore')
        obj41=block(asm,'Obj41_Up:','Obj41_DiagonallyUp:')
        events=block(asm,'LevEvents_CNZ:','LevEvents_CPZ:')
        check('retail Obj41 up source reach is $1B', 'move.w\t#$1B,d1' in obj41)
        check('retail Obj41 horizontal source reach is $13', 'move.w\t#$13,d1' in obj41)
        check('retail CNZ2 event threshold $27C0 retained as next-phase source target', 'cmpi.w\t#$27C0,(Camera_X_pos).w' in events)
        check('retail CNZ2 boss arena uses $2860..$28E0', 'move.w\t#$2860,(Camera_Min_X_pos).w' in events and 'move.w\t#$28E0,(Camera_Max_X_pos).w' in events)
        check('retail CNZ2 loads Obj51 boss', 'move.b\t#ObjID_CNZBoss,id(a1)' in events)

    passed=sum(ok for _,ok in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
