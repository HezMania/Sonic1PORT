#!/usr/bin/env python3
from pathlib import Path
import json, subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name,cond,detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))

def block(text,start,end):
    a=text.find(start)
    if a<0:return ''
    b=text.find(end,a+len(start))
    return text[a:] if b<0 else text[a:b]

def be16(b,o): return (b[o]<<8)|b[o+1]
def bumper_count(b):
    n=0
    for o in range(0,len(b)-5,6):
        x=be16(b,o+2); y=be16(b,o+4)
        if x==0xFFFF: break
        if x==0 and y==0: continue
        n+=1
    return n

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    main_gd=(ROOT/'scripts/main.gd').read_text()
    catalog=(ROOT/'scripts/data/level_catalog.gd').read_text()
    manager=(ROOT/'scripts/objects/object_manager.gd').read_text()
    camera=(ROOT/'scripts/camera/sonic_camera.gd').read_text()
    completion=(ROOT/'scripts/objects/s2_cnz_completion_object.gd').read_text()
    boss=(ROOT/'scripts/objects/s2_cnz_boss_object.gd').read_text()
    palette=(ROOT/'scripts/render/level_palette_cycler.gd').read_text()
    prison=(ROOT/'scripts/objects/s2_egg_prison_object.gd').read_text()
    manifest=json.loads((ROOT/'data/s1/s2test/phase104_cnz_boss_manifest.json').read_text())
    p103=json.loads((ROOT/'data/s1/s2test/phase103_cnz2_manifest.json').read_text())

    check('Phase104 HUD identity is active','Native Sonic 1 Phase 104' in main_gd)
    check('CNZ catalog enables separate bumper data','"s2_cnz_bumpers": "s2test/%s_bumpers.bin" % prefix' in catalog)
    check('CNZ2 dynamic events enabled','"dynamic_events": "s2_cnz2" if act == 2 else "none"' in catalog)
    check('CNZ2 boss definition gate enabled','"s2_cnz_boss": act == 2' in catalog)

    check('CNZ1 special bumper count is 53',manifest.get('cnz1_special_bumpers')==53)
    check('CNZ2 special bumper count is 52',manifest.get('cnz2_special_bumpers')==52)
    check('manager loads SpecialCNZBumpers table','func _load_s2_cnz_bumpers' in manager and 'func _tick_s2_cnz_special_bumpers' in manager)
    check('special bumper type extents match retail','$20' in manager and 'Vector2i(0x40, 8)' in manager and 'Vector2i(8, 0x40)' in manager)
    check('special bumper rebound magnitude is $A00',manager.count('0xA00')>=10 and '_cnz_bumper_reflect' in manager)

    check('D8 palette health folders generated',all(len(list((ROOT/f'assets/objects/s2_cnz/bonus_block_p{i}').glob('*.png')))==6 for i in range(3)))
    check('D8 starts green on palette line 2','bonus_block_p2/%02d.png' in completion)
    check('D8 hit palette sequence uses 2-hit_count','2 - mini(hit_count, 2)' in completion)

    check('Obj51 boss mapping bank has 21 frames',manifest.get('boss_mapping_frames')==21 and len(list((ROOT/'assets/objects/s2_cnz/boss').glob('*.png')))==21)
    check('Obj51 boss uses retail start', 'START_X := 0x2A46' in boss and 'START_Y := 0x654' in boss)
    check('Obj51 patrol bounds match retail','LEFT_X := 0x28C0' in boss and 'RIGHT_X := 0x29C0' in boss)
    check('Obj51 health is 8 hits','var hits: int = 8' in boss)
    check('Obj51 drop and dive thresholds retained','0x6B0' in boss and '0x67C' in boss and 'DIVE_BOTTOM_Y := 0x680' in boss)
    check('Obj51 defeat countdown is $B3','countdown = 0xB3' in boss)
    check('Obj51 escape camera target is $2B20','CAMERA_ESCAPE_MAX := 0x2B20' in boss and 'mini(0x2B20, boss_limit_right + 2)' in manager)
    check('Object manager can allocate CNZ boss','func spawn_s2_cnz_boss() -> bool' in manager and 'S2CNZBossObjectClass' in manager)

    cnz_dle=block(camera,'func _dle_s2_cnz2','func _dle_fz')
    for label,val in [('approach $27C0','0x27C0'),('arena $2890','0x2890'),('left $2860','0x2860'),('right $28E0','0x28E0'),('top $4E0','0x4E0'),('wait $5A','0x5A'),('post $2A00','0x2A00'),('bottom $5D0','0x5D0')]:
        check('CNZ2 DLE retains '+label,val in cnz_dle)
    check('CNZ2 DLE mutates source layout $C54/$C50','set_chunk_id_at(0x54, 0x0C, 0xF9)' in cnz_dle and 'set_chunk_id_at(0x50, 0x0C, 0xF9)' in cnz_dle)
    check('CNZ2 layout mutations request renderer refresh','s2_cnz2_refresh_c54_requested' in camera and 'refresh_level_chunk(0x54, 0x0C)' in main_gd)

    check('CNZ boss palette line imported',(ROOT/'data/s1/palette/S2 CNZ Boss.bin').stat().st_size==32)
    check('CNZ boss palette cycle 1 imported',(ROOT/'data/s1/palette/S2 CNZ Boss Cycle 1.bin').stat().st_size==18)
    check('CNZ boss palette cycle 2 imported',(ROOT/'data/s1/palette/S2 CNZ Boss Cycle 2.bin').stat().st_size==20)
    check('CNZ boss palette cycle 3 imported',(ROOT/'data/s1/palette/S2 CNZ Boss Cycle 3.bin').stat().st_size==16)
    check('CNZ boss palette activation writes CRAM line 1','activate_s2_cnz_boss_palette' in palette and '_write_run(level.palette, 16, s2_cnz_boss_palette, 0, 16)' in palette)
    check('CNZ boss-only cycles update indices 18/19/20/30/31',all(f'level.palette, {n}' in palette for n in (18,19,20,30,31)))

    check('CNZ Egg Prison has dedicated boss-palette art',len(list((ROOT/'assets/objects/s2_cnz/egg_prison').glob('*.png')))==6 and 's2_cnz/egg_prison' in prison)
    check('CNZ2 retains 254/254 ordinary placement coverage',p103.get('native_placement_records')==254 and p103.get('deferred_placement_records')==0)
    check('Phase103 spring half-width correction retained','resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x10' in (ROOT/'scripts/objects/s2_spring_object.gd').read_text() and 'resolve_solid_box_contact(spawn_x, spawn_y, 0x0A, 0x0F' in (ROOT/'scripts/objects/s2_spring_object.gd').read_text())

    prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase102.py')] + ([str(s2)] if s2 else []),capture_output=True,text=True)
    detail=prev.stdout.strip().splitlines()[-1] if prev.stdout.strip() else prev.stderr.strip()[-200:]
    check('Phase102 regression suite remains clean',prev.returncode==0,detail)

    if s2 is not None:
        src1=(s2/'level/objects/CNZ 1 bumpers.bin').read_bytes(); src2=(s2/'level/objects/CNZ 2 bumpers.bin').read_bytes()
        out1=(ROOT/'data/s1/s2test/cnz1_bumpers.bin').read_bytes(); out2=(ROOT/'data/s1/s2test/cnz2_bumpers.bin').read_bytes()
        check('CNZ1 special bumper table copied byte-identically',src1==out1 and bumper_count(src1)==53)
        check('CNZ2 special bumper table copied byte-identically',src2==out2 and bumper_count(src2)==52)
        asm=(s2/'s2.asm').read_text(errors='ignore')
        events=block(asm,'LevEvents_CNZ2:','LevEvents_CPZ:')
        obj51=block(asm,'Obj51:','JmpTo59_DeleteObject')
        d8=block(asm,'ObjD8:','ObjD8_MapUnc_2C8C4:')
        check('retail CNZ2 event source loads Obj51','move.b\t#ObjID_CNZBoss,id(a1)' in events)
        check('retail Obj51 source start and 8-hit property','#$2A46,x_pos(a0)' in obj51 and '#$654,y_pos(a0)' in obj51 and '#8,objoff_32(a0)' in obj51)
        check('retail Obj51 source patrol bounds retained','#$28C0,(Boss_X_pos).w' in obj51 and '#$29C0,(Boss_X_pos).w' in obj51)
        check('retail ObjD8 palette decrement retained','subi.w\t#palette_line_1,art_tile(a0)' in d8)

    passed=sum(ok for _,ok in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
