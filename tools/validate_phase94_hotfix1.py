#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
checks=[]
def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    bg=(ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
    trav=(ROOT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    boss=(ROOT/'scripts/objects/s2_cpz_boss_object.gd').read_text()
    prison=(ROOT/'scripts/objects/s2_egg_prison_object.gd').read_text()

    # CPZ full source-shaped background deformation.
    check('CPZ caches the six-chunk horizontal source repeat', 's2_ehz_plane_width = 6 * 128' in bg)
    check('CPZ caches all seven authored background rows', 's2_ehz_plane_height = 7 * 128' in bg)
    check('CPZ uses retail 1/8 and 1/2 horizontal camera sections', 'slow_scroll := -(int(camera_model.screen_x) >> 3)' in bg and 'fast_scroll := -(int(camera_model.screen_x) >> 1)' in bg)
    check('CPZ uses retail 1/4 vertical background camera', 'bg_y := int(camera_model.screen_y) >> 2' in bg)
    check('CPZ row $12 uses the source ripple table', 'source_row == 0x12' in bg and 'S2_EHZ_RIPPLE[ri]' in bg)
    check('CPZ deformation remains run-batched for Godot performance', 'while line < viewport_height and pool_index < s2_ehz_strips.size()' in bg and 'run_end - line' in bg)
    ripple=[1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3]
    max_runs=0
    for cam_y in range(0,0x721):
        bg_y=cam_y>>2; vals=[]; ro=0; in_ripple=False
        for line in range(224):
            row=((bg_y+line)&0x3FF)>>4
            if row>0x12: v=0x100
            elif row==0x12:
                if not in_ripple: ro=0
                in_ripple=True; v=ripple[ro&31]; ro+=1
            else: in_ripple=False; v=0
            vals.append(v)
        runs=1+sum(a!=b for a,b in zip(vals,vals[1:]))
        max_runs=max(max_runs,runs)
    check('CPZ source deformation stays far below the 96-strip pool', max_runs<=96, f'max runs={max_runs}')

    # Obj6B grouped square platforms.
    check('Obj6B selects oscillator bank from subtype $18-$1B', 'wave_off := 0x28 + (kind - 8) * 4' in trav and 'rate_off := wave_off + 2' in trav)
    check('Obj6B subtype $18 uses its unique half-wave path', 'if kind == 8:' in trav and 'wave = wave >> 1' in trav)
    check('Obj6B restores $10/$30/$50/$70 source radii', 'var radius = 0x10 + (kind - 8) * 0x20' in trav)
    b=(ROOT/'data/s1/s2test/cpz2_objects.bin').read_bytes()
    grouped=[]
    for i in range(0,len(b),6):
        x=int.from_bytes(b[i:i+2],'big'); yw=int.from_bytes(b[i+2:i+4],'big'); oid=b[i+4]; sub=b[i+5]
        if oid==0x6B and x in (0x0E40,0x0FC0,0x1240): grouped.append((x,yw&0xFFF,sub,bool(yw&0x4000)))
    from collections import Counter
    c=Counter((x,y) for x,y,_,_ in grouped)
    check('retail CPZ2 contains four-record Obj6B groups', all(c[k]==4 for k in ((0x0E40,0x180),(0x0FC0,0x4F0),(0x1240,0x480))), str(c))

    # Obj7A linked water platforms.
    check('Obj7A subtype $C only reverses the main member initially', 'if subtype == 0x0C and i == 0:' in trav and 'dir = -1' in trav)
    check('Obj7A detects approaching 48px edge contact in either ordering', 'approaching :=' in trav and 'absi(water_platform_x[0] - water_platform_x[1]) <= 0x30' in trav)
    check('Obj7A clamps members to contact before reversing', 'mid - 0x18' in trav and 'mid + 0x18' in trav and 'water_platform_dir[0] = -water_platform_dir[0]' in trav)

    # CPZ boss container: shell and liquid must stay separate.
    check('boss has separate glass/floor/fill sprites', all(t in boss for t in ('container_sprite: Sprite2D','container_floor_sprite: Sprite2D','container_fill_sprite: Sprite2D')))
    check('boss fill uses palette line 3 instead of gray palette line 1', '_set_direct_texture(container_fill_sprite, "mechanism_pal3"' in boss)
    check('boss glass uses source $A/$1C/$1E frames', 'shell_frame := 10' in boss and 'shell_frame = 28' in boss and 'shell_frame = 30' in boss)
    check('boss container extends from -$10 to -$58', 'container_x_offset = -0x10' in boss and 'maxi(-0x58, container_x_offset - 1)' in boss)
    check('boss fill advances through source frames $10-$1B', 'container_fill_stage < 11' in boss and '16 + clampi(container_fill_stage, 0, 11)' in boss)
    check('boss waits source $12 ticks at full extension before spill', 'container_spill_hold >= 0x12' in boss)
    check('Mega Mack begins at the extended container origin', 'var container_x := -container_x_offset if facing_right else container_x_offset' in boss and '- 0x38' in boss)

    # Egg Prison remains solid after activation/opening.
    main_tick=prison[prison.find('func tick()'):prison.find('func _tick_wait')]
    check('Egg Prison body collision runs from main tick after opening', 'p.resolve_solid_box(spawn_x, spawn_y, 0x2B, 0x18, true, record_index)' in main_tick)
    wait=prison[prison.find('func _tick_wait'):prison.find('func _activate')]
    check('Egg Prison switch remains a separate top contact', 'spawn_y - 0x28' in wait and 'resolve_solid_box_contact' in wait)

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore')
        cpz=asm[asm.find('SwScrl_CPZ:'):asm.find('SwScrl_DEZ:')]
        check('retail SwScrl_CPZ source contains <<5, <<7 and <<6 camera factors', 'asl.l\t#5,d4' in cpz and 'asl.l\t#7,d4' in cpz and 'asl.l\t#6,d5' in cpz)
        check('retail CPZ source marks ripple section row $12', 'cmpi.b\t#$12,d4' in cpz and 'SwScrl_RippleData' in cpz)
        obj6_start=asm.find('Obj6B:')
        obj6=asm[obj6_start:obj6_start+16000]
        check('retail Obj6B source uses $28/$2A and $2C/$2E oscillator pairs', '(Oscillating_Data+$28)' in obj6 and '(Oscillating_Data+$2A)' in obj6 and '(Oscillating_Data+$2C)' in obj6 and '(Oscillating_Data+$2E)' in obj6)
        obj7=asm[asm.find('Obj7A:'):asm.find('byte_29496:') if asm.find('byte_29496:')>asm.find('Obj7A:') else asm.find('Obj7B:')]
        check('retail Obj7A source uses 24px edge-contact reversal', '#$18,d0' in obj7 and '#$18,d2' in obj7)
        obj5=asm[asm.find('Obj5D_Container:'):asm.find('Obj5D_Gunk:')]
        check('retail boss container source uses -$10/-$58 and anim 6/7/8', '#-$10,Obj5D_x_vel' in asm[asm.find('Obj5D_Init:'):asm.find('Obj5D_Main:')] and '#-$58,Obj5D_x_vel' in obj5 and '#6,anim' in obj5 and '#7,anim' in obj5 and '#8,anim' in obj5)
        check('retail boss fill child advances to animation $17', '#$17,anim(a0)' in obj5)
        obj3_start=asm.find('Obj3E:')
        obj3=asm[obj3_start:obj3_start+18000]
        check('retail Egg Prison main continues SolidObject outside switch routine', 'SolidObject' in obj3 and '#$2B,d1' in obj3)

        prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase94.py'),str(s2)],capture_output=True,text=True)
        check('complete Phase 94 boss/end regression remains clean', prev.returncode==0, prev.stdout.strip().splitlines()[-1] if prev.stdout else '')

    passed=sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
