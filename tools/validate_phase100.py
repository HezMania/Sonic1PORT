#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, subprocess, sys
from collections import Counter

ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name,cond,detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def obj_counts(path):
    b=Path(path).read_bytes(); assert len(b)%6==0
    return Counter(b[i+4] for i in range(0,len(b),6))

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    main=(ROOT/'scripts/main.gd').read_text()
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    cnz=(ROOT/'scripts/objects/s2_cnz_traversal_object.gd').read_text()
    cpz=(ROOT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    player=(ROOT/'scripts/player/sonic_player.gd').read_text()
    manifest=json.loads((ROOT/'data/s1/s2test/phase100_cnz1_traversal_manifest.json').read_text())
    counts=obj_counts(ROOT/'data/s1/s2test/cnz1_objects.bin')
    activated={0x44:74,0x72:4,0x84:18,0x85:7,0x86:38,0xD4:15,0xD5:5,0xD7:12}
    remaining={0xC8:2,0xD2:4,0xD6:15,0xD8:44}

    check('Phase100 HUD identity is active','Native Sonic 1 Phase 100' in main)
    check('CNZ1 still retains all 286 source placement records',sum(counts.values())==286)
    check('Phase100 activates exactly 173 formerly deferred records',sum(activated.values())==173 and manifest['new_native_traversal_records']==173)
    check('Phase100 reaches 221/286 native CNZ1 placements',manifest['native_records_after_phase100']==221)
    check('Phase100 leaves exactly 65 records for the next CNZ pass',sum(remaining.values())==65 and manifest['remaining_deferred_records']==65)
    check('activated source record counts match retail placement stream',all(counts[k]==v for k,v in activated.items()))
    check('remaining source record counts match retail placement stream',all(counts[k]==v for k,v in remaining.items()))
    check('CNZ traversal class is preloaded','S2CNZTraversalObjectClass = preload' in om)
    check('all eight Phase100 IDs route to native CNZ traversal','0x44, 0x72, 0x84, 0x85, 0x86, 0xD4, 0xD5, 0xD7: return S2CNZTraversalObjectClass.new()' in om)

    # Global Obj40 fix: byte operation on the high byte of 8.8 speed.
    check('Obj40 kick table is promoted into the 8.8 high byte','var kick_velocity: int = kick << 8' in cpz)
    check('Obj40 vertical launch now spans source -$400..-$800','p.vel_y = -0x400 - kick_velocity' in cpz)
    check('Obj40 non-flipped horizontal kick increases outgoing speed','p.vel_x += -kick_velocity if x_flip else kick_velocity' in cpz)
    check('Obj40 retains exact 72-byte source kick table','const LEVER_KICK: Array[int]' in cpz and cpz[cpz.find('const LEVER_KICK'):cpz.find('func _init_lever_spring')].count(',')>=71)

    # Player pinball semantics.
    check('Sonic player has native pinball_mode latch','var pinball_mode := false' in player)
    check('pinball_mode resets on respawn','rolling = false\n\tpinball_mode = false' in player)
    check('pinball mode skips roll jumping','if not pinball_mode and _try_jump()' in player)
    check('pinball mode forces +/-$400 instead of unrolling','inertia = -0x400 if facing_left else 0x400' in player)
    check('pinball mode preserves roll state on landing','if rolling and not pinball_mode:' in player)
    check('pinball mode bypasses non-jump upward speed cap','if not pinball_mode:\n\t\t\tvel_y = clampi(vel_y, -0xFC0, 0xFC0)' in player)
    check('Obj84 has a public player bridge','func set_s2_pinball_mode(enabled: bool)' in player)

    # Object 44 / 72 / 84.
    check('Obj44 uses retail -$700 radial strength','* -0x700) >> 8' in cnz)
    check('Obj44 perturbs angle with the low two frame bits','Engine.get_physics_frames() & 3' in cnz)
    check('Obj44 uses bumper sound','SonicAudio.SFX_BUMPER' in cnz)
    check('Obj72 computes width from low seven subtype bits','(subtype & 0x7F) << 4' in cnz)
    check('Obj72 retains retail $30/$70 vertical regions','0x70 if (subtype & 0x80) != 0 else 0x30' in cnz)
    check('Obj72 carries grounded Sonic by two pixels','var speed: int = -2 if x_flip else 2' in cnz)
    check('Obj84 retains retail 20/40/80/100 spans','[0x20, 0x40, 0x80, 0x100]' in cnz)
    check('Obj84 supports both X and Y crossing modes','(subtype & 4) != 0' in cnz and '_pinball_axis_side' in cnz)
    check('Obj84 reverses enable direction when flipped','var enable: bool = positive_crossing != x_flip' in cnz)

    # Obj85 launcher.
    check('Obj85 supports vertical and diagonal art banks','launcher_vertical' in cnz and 'launcher_diagonal' in cnz)
    check('Obj85 vertical compression caps at $20','0x1C if diagonal else 0x20' in cnz)
    check('Obj85 requires actual compression before release','elif compression > 0:' in cnz)
    check('Obj85 vertical launch uses (compression+$10)<<7','(compression + 0x10) << 7' in cnz)
    check('Obj85 diagonal launch uses (compression+4)<<7','(compression + 4) << 7' in cnz)
    check('Obj85 $81 subtype preserves source attached -$20 surface launch','GenesisMath.s8(subtype) < 0' in cnz and 'p.in_air = false' in cnz and 'p.angle = 0xE0' in cnz)

    # Obj86 flippers.
    check('Obj86 imports all three source upward slope tables','FLIPPER_SLOPE_0' in cnz and 'FLIPPER_SLOPE_1' in cnz and 'FLIPPER_SLOPE_2' in cnz)
    check('Obj86 upward launch adds retail $800 base impulse','mini(d0, 0x40) << 5) + 0x800' in cnz)
    check('Obj86 horizontal subtype launches at $1000','p.vel_x = -0x1000 if contact == SonicPlayer.SOLID_LEFT else 0x1000' in cnz)
    check('Obj86 horizontal launch applies retail $F lock','p.lock_time = 0x0F' in cnz)

    # D4/D5/D7.
    check('ObjD4 starts $60 from its origin','0x60 if x_flip else -0x60' in cnz and '0x60 if y_flip else -0x60' in cnz)
    check('ObjD4 uses source +/-4 acceleration','+ (4 if origin_x > old_x else -4)' in cnz and '+ (4 if origin_y > old_y else -4)' in cnz)
    check('ObjD4 translates source $2B center envelope to raw $20 native half-width','resolve_solid_box(new_x, new_y, 0x20, 0x20' in cnz)
    check('ObjD5 derives travel distance from subtype*4','(subtype & 0xFF) << 2' in cnz)
    check('ObjD5 activates only after Sonic stands on it','p.standing_on_object and p.support_record_index == record_index' in cnz)
    check('ObjD5 returns after player leaves destination','state = 3' in cnz and 'object_vel_y = 0' in cnz and 'object_fixed_y = initial_y << 16' in cnz)
    check('ObjD7 uses source +/-$800 cardinal rebound','p.vel_x = -0x800' in cnz and 'p.vel_x = 0x800' in cnz and 'p.vel_y = -0x800' in cnz and 'p.vel_y = 0x800' in cnz)
    check('ObjD7 moving subtype spans origin +/-$60','origin_x - 0x60' in cnz and 'origin_x + 0x60' in cnz)
    check('ObjD7 has vertical and horizontal hit animations','hex_bumper", 1 if state == 1 else 2' in cnz)

    expected={'round_bumper':2,'launcher_vertical':6,'launcher_diagonal':6,'flipper':6,'big_block':1,'elevator':1,'hex_bumper':3}
    for folder,n in expected.items():
        files=sorted((ROOT/'assets/objects/s2_cnz'/folder).glob('*.png'))
        check(f'CNZ {folder} retail-rendered frame count',len(files)==n)
        try:
            from PIL import Image
            nonempty=True
            for f in files:
                im=Image.open(f).convert('RGBA')
                nonempty = nonempty and im.size==(192,192) and im.getbbox() is not None
            check(f'CNZ {folder} frames are 192x192 and non-empty',nonempty)
        except Exception as e:
            check(f'CNZ {folder} frames are 192x192 and non-empty',False,str(e))

    prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase99.py')] + ([str(s2)] if s2 else []),capture_output=True,text=True)
    detail=prev.stdout.strip().splitlines()[-1] if prev.stdout.strip() else prev.stderr.strip()[-160:]
    check('Phase99 regression suite remains clean',prev.returncode==0,detail)

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore')
        obj40=asm[asm.find('Obj40:'):asm.find('Obj42:')]
        check('retail Obj40 writes -$400 then sub.b kick into y_vel','move.w\t#-$400,y_vel(a1)' in obj40 and 'sub.b\td0,y_vel(a1)' in obj40)
        check('retail Obj40 applies byte kick to fast x_vel too','sub.b\td0,x_vel(a1)' in obj40)
        o44=asm[asm.find('Obj44:'):asm.find('Obj45:',asm.find('Obj44:'))]
        check('retail Obj44 confirms fixed -$700 bumper impulse','muls.w\t#-$700,d1' in o44 and 'muls.w\t#-$700,d0' in o44)
        o72=asm[asm.find('Obj72:'):asm.find('Obj73:',asm.find('Obj72:'))]
        check('retail Obj72 confirms two-pixel conveyor carry','move.w\t#2,objoff_36(a0)' in o72)
        o84=asm[asm.find('Obj84:'):asm.find('Obj85:')]
        check('retail Obj84 confirms pinball_mode enable/disable','move.b\t#1,pinball_mode(a1)' in o84 and 'move.b\t#0,pinball_mode(a1)' in o84)
        check('retail Obj84 confirms 20/40/80/100 span table',all(x in o84 for x in ['dc.w   $20','dc.w   $40','dc.w   $80','dc.w  $100']))
        o85=asm[asm.find('Obj85:'):asm.find('Obj86:')]
        check('retail Obj85 confirms $20/$1C compression maxima','cmpi.w\t#$20,objoff_38(a0)' in o85 and 'cmpi.w\t#$1C,objoff_38(a0)' in o85)
        check('retail Obj85 confirms compression-scaled <<7 launch','lsl.w\t#7,d0' in o85)
        o86=asm[asm.find('Obj86:'):asm.find('Obj87:',asm.find('Obj86:'))]
        check('retail Obj86 confirms $1000 horizontal flipper launch','move.w\t#-$1000,x_vel(a1)' in o86)
        check('retail Obj86 confirms $800 upward base','addi.w\t#$800,d2' in o86)
        od4=asm[asm.find('ObjD4:'):asm.find('ObjD5:')]
        check('retail ObjD4 confirms $60 offset and 4 acceleration','subi.w\t#$60,x_pos(a0)' in od4 and 'moveq\t#4,d1' in od4)
        od5=asm[asm.find('ObjD5:'):asm.find('ObjD6:')]
        check('retail ObjD5 confirms subtype*4 travel and 8 acceleration','lsl.w\t#2,d0' in od5 and 'moveq\t#8,d1' in od5)
        od7=asm[asm.find('ObjD7:'):asm.find('ObjD8:',asm.find('ObjD7:'))]
        check('retail ObjD7 confirms +/-$800 bumper speeds','move.w\t#-$800,x_vel(a1)' in od7 and 'move.w\t#$800,x_vel(a1)' in od7 and 'move.w\t#-$800,y_vel(a1)' in od7 and 'move.w\t#$800,y_vel(a1)' in od7)
        check('retail ObjD7 confirms +/-$60 patrol bounds','subi.w\t#$60,d0' in od7 and 'addi.w\t#$60,d1' in od7)

        files=sorted((ROOT/'assets/objects/s2_cnz').glob('*/*.png'))
        before={str(x.relative_to(ROOT)):sha(x) for x in files}
        regen=subprocess.run([sys.executable,str(ROOT/'tools/import_s2_cnz_traversal_phase100.py'),str(s2)],capture_output=True,text=True)
        files2=sorted((ROOT/'assets/objects/s2_cnz').glob('*/*.png'))
        after={str(x.relative_to(ROOT)):sha(x) for x in files2}
        check('Phase100 CNZ art regenerates deterministically from retail source',regen.returncode==0 and before==after,regen.stderr.strip()[-160:])

    passed=sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
