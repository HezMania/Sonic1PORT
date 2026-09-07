#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, subprocess, sys
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
checks=[]
def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def obj_counts(path):
    b=Path(path).read_bytes(); assert len(b)%6==0
    return Counter(b[i+4] for i in range(0,len(b),6))

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    env=(ROOT/'scripts/objects/s2_arz_environment_object.gd').read_text()
    swing=(ROOT/'scripts/objects/s2_arz_swing_object.gd').read_text()
    arrow=(ROOT/'scripts/objects/s2_arz_arrow_object.gd').read_text()
    bad=(ROOT/'scripts/objects/s2_arz_badnik_object.gd').read_text()
    leaf=(ROOT/'scripts/objects/s2_arz_leaf_object.gd').read_text()
    debris=(ROOT/'scripts/objects/s2_arz_debris_object.gd').read_text()
    bg=(ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
    main=(ROOT/'scripts/main.gd').read_text()
    d=ROOT/'data/s1/s2test'
    m1=json.loads((d/'phase95_arz1_manifest.json').read_text())
    m2=json.loads((d/'phase96_arz2_manifest.json').read_text())
    c1=obj_counts(d/'arz1_objects.bin'); c2=obj_counts(d/'arz2_objects.bin')
    deferred={0x15,0x1F,0x22,0x23,0x24,0x2B,0x2C,0x82,0x83,0x8C,0x8D,0x8E,0x91}

    check('Phase 99-or-later HUD identity is active','Native Sonic 1 Phase 99' in main or 'Native Sonic 1 Phase 100' in main)
    check('ARZ1 still retains all 182 source placements',sum(c1.values())==182)
    check('ARZ2 still retains all 222 source placements',sum(c2.values())==222)
    check('Phase95 manifest records 109 deferred ARZ placements',m1['deferred_arz_specific_records']==109)
    check('Phase96 manifest records 134 deferred ARZ placements',m2['deferred_arz_specific_records']==134)
    check('all formerly deferred ARZ IDs are now native-dispatched',all((f'0x{x:02X}' in om) for x in deferred))
    check('ARZ environment family dispatch covers 1F/23/24/2B/2C/82','0x1F, 0x23, 0x24, 0x2B, 0x2C, 0x82: return S2ARZEnvironmentObjectClass.new()' in om)
    check('ARZ swinging families 15/83 are dispatched','0x15, 0x83: return S2ARZSwingObjectClass.new()' in om)
    check('ARZ arrow shooter 22 is dispatched','0x22: return S2ARZArrowObjectClass.new()' in om)
    check('ARZ badnik families 8C/8D/8E/91 are dispatched','0x8C, 0x8D, 0x8E, 0x91: return S2ARZBadnikObjectClass.new()' in om)

    # Object-specific source translations.
    check('Obj1F uses exact ARZ eight-piece delay order','[0x16,0x1A,0x18,0x12,0x06,0x0E,0x0A,0x02]' in env)
    check('Obj1F breakup uses eight source mapping pieces',len(list((ROOT/'assets/objects/s2_arz/collapse_fragments').glob('*.png')))==8)
    check('Obj22 uses retail $40 player detection distance','< 0x40' in arrow)
    check('Obj22 preserves $400 arrow velocity','-0x400 if x_flip else 0x400' in arrow)
    check('Obj22 projectile uses retail $9B 8x4 hit extents','8 + p.width_radius' in arrow and '4 + p.height_radius' in arrow)
    check('Obj23 has separate lower pillar fall state','lower_vel_y = GenesisMath.s16(lower_vel_y + 0x38)' in env and 'lower_sprite.position.y = lower_y' in env)
    check('Obj24 uses source bubble group table','[0,1,0,0,0,0,1,0,0,0,0,1,0,1,0,0,1,0]' in env)
    check('Obj24 uses subtype low seven bits as maker timebase','bubble_timer = subtype & 0x7F' in env)
    check('Obj2B rises in four-pixel source steps','position.y -= 4' in env and 'timer = 3' in env)
    check('Obj2B breakup uses all fourteen mapping pieces',len(list((ROOT/'assets/objects/s2_arz/rising_fragments').glob('*.png')))==14)
    check('Obj2B uses source fragment gravity $18','0x18, fragment_delays[i]' in env)
    check('Obj2C uses source trigger half-sizes 32/64/128 by 32','1: half_w = 64; half_h = 32' in env and '2: half_w = 128; half_h = 32' in env)
    check('Obj2C requires source $200 movement threshold','absi(p.vel_x) < 0x200 and absi(p.vel_y) < 0x200' in env)
    check('Obj2C creates four leaves with source velocities','Vector2i(-0x80,-0x80)' in env and 'Vector2i(0x80,0x80)' in env)
    check('leaf transient preserves source two-bank frame toggle','frame_base ^= 2' in leaf)
    check('Obj82 subtype 1 has $1E stand delay','timer = 0x1E' in env)
    check('Obj82 clears nudge before falling','nudge_enabled = false' in env)
    check('Obj82 carries Sonic by collision-center delta','center_y - last_collision_y' in env)
    check('Obj15 reads source oscillator $18','s2_source_osc_byte(0x18)' in swing)
    check('Obj15 detachable subtype releases only at oscillator zero','detaching and osc == 0' in swing)
    check('Obj15 detached platform retains its chain/anchor visuals','l.visible = false' not in swing and 'anchor_sprite.visible = false' not in swing)
    check('Obj83 uses exact one-third phases 0/85/171','[0, 85, 171]' in swing)
    check('Whisp uses four source homing cycles','move_timer = 4' in bad and 'timer = 0x60' in bad)
    check('Grounder hidden-wall variant retains source $60 trigger distance','<= 0x60' in bad)
    check('Grounder wall cover uses four source offsets','Vector2i(0,-0x14)' in bad and 'Vector2i(-0x10,-4)' in bad)
    check('Grounder emits five source rock frames','[0,2,0,1,0]' in bad)
    check('Grounder/ChopChop use source collision half-size 12x20','var hw: int = 12' in bad and 'var hh: int = 20' in bad)
    check('Whisp uses source collision half-size 8x8','hw = 8' in bad and 'hh = 8' in bad)
    check('ChopChop patrol uses source $200 timer and $40 speed','move_timer = 0x200' in bad and 'vel_x = 0x40 if x_flip else -0x40' in bad)
    check('generic ARZ debris is a managed finite transient','var alive: bool = true' in debris and 'queue_free()' in debris)

    expected_assets={'collapse':2,'collapse_fragments':8,'falling_pillar':3,'rising_pillar':14,'rising_fragments':14,'platform82':2,'swing':4,'arrow':5,'leaves':4,'whisp':2,'grounder':5,'grounder_wall':1,'grounder_rocks':3,'chopchop':2,'bubble_generator':2}
    for folder,n in expected_assets.items():
        check(f'ARZ {folder} source-rendered frame count',len(list((ROOT/'assets/objects/s2_arz'/folder).glob('*.png')))==n)

    # CNZ regression correction from the user's Phase98 report.
    cnz=bg[bg.find('func _update_s2cnz'):bg.find('func _update_s2cnz')+3000]
    check('CNZ ripple is limited to logical Y $80-$8F','elif logical_y < 144:' in cnz and 'logical_y - 128' in cnz)
    check('CNZ lower 1/8 parallax starts at logical Y $90','else:\n\t\t\tnumerator = numerators[9]' in cnz)
    check('old Phase98 64-line ripple cutoff is absent','logical_y < 192' not in cnz)

    prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase98.py')] + ([str(s2)] if s2 else []),capture_output=True,text=True)
    detail=prev.stdout.strip().splitlines()[-1] if prev.stdout.strip() else prev.stderr.strip()[-160:]
    check('Phase98 regression suite remains clean after corrected CNZ expectation',prev.returncode==0,detail)

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore')
        check('retail Obj1F ARZ delay data matches imported sequence','Obj1F_ARZ_DelayData:' in asm and 'dc.b $16,$1A,$18,$12,  6, $E, $A,  2' in asm)
        check('retail Obj22 confirms $40 detect and $400 arrow speed','cmpi.w\t#$40,d0' in asm[asm.find('Obj22:'):asm.find('Obj23:')] and 'move.w\t#$400,x_vel(a0)' in asm[asm.find('Obj22:'):asm.find('Obj23:')])
        check('retail Obj2C confirms $200 velocity threshold','cmpi.w\t#$200,d0' in asm[asm.find('Obj2C:'):asm.find('Obj2D:',asm.find('Obj2C:')+1)])
        check('retail Obj2C confirms collision flags D6/D4/D5','dc.b $D6' in asm[asm.find('Obj2C:'):asm.find('Obj2D:',asm.find('Obj2C:')+1)] and 'dc.b $D4' in asm[asm.find('Obj2C:'):asm.find('Obj2D:',asm.find('Obj2C:')+1)] and 'dc.b $D5' in asm[asm.find('Obj2C:'):asm.find('Obj2D:',asm.find('Obj2C:')+1)])
        check('retail Obj82 confirms $1E stand delay','move.w\t#$1E,objoff_36(a0)' in asm[asm.find('Obj82:'):asm.find('Obj83:')])
        cnzsrc=asm[asm.find('SwScrl_CNZ_RowHeights:'):asm.find('sub_D160:')]
        check('retail CNZ row table is eight $10 rows then 0/-$10',cnzsrc.count('dc.b  $10')>=8 and 'dc.b    0' in cnzsrc and 'dc.b -$10' in cnzsrc)
        # Reconstruct all new object art again and require stable bytes.
        files=sorted((ROOT/'assets/objects/s2_arz').glob('*/*.png'))
        before={str(x.relative_to(ROOT)):sha(x) for x in files}
        regen=subprocess.run([sys.executable,str(ROOT/'tools/import_s2_arz_objects_phase99.py'),str(s2)],capture_output=True,text=True)
        files2=sorted((ROOT/'assets/objects/s2_arz').glob('*/*.png'))
        after={str(x.relative_to(ROOT)):sha(x) for x in files2}
        check('Phase99 ARZ object art regenerates deterministically from retail source',regen.returncode==0 and before==after,regen.stderr.strip()[-160:])

    passed=sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
