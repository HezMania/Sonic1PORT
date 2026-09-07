#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    main_gd=(ROOT/'scripts/main.gd').read_text()
    cam=(ROOT/'scripts/camera/sonic_camera.gd').read_text()
    cat=(ROOT/'scripts/data/level_catalog.gd').read_text()
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    boss=(ROOT/'scripts/objects/s2_arz_boss_object.gd').read_text()
    cpz=(ROOT/'scripts/objects/s2_cpz_boss_object.gd').read_text()
    prison=(ROOT/'scripts/objects/s2_egg_prison_object.gd').read_text()

    # Reported Phase 96 bugs.
    check('CPZ container_x has explicit int type', 'var container_x: int = -container_x_offset if facing_right else container_x_offset' in cpz)
    check('CPZ container_local_x has explicit int type', 'var container_local_x: int = -container_x_offset if facing_right else container_x_offset' in cpz)
    check('old ambiguous container_x inference is gone', 'var container_x :=' not in cpz)
    check('old ambiguous container_local_x inference is gone', 'var container_local_x :=' not in cpz)
    check('Egg Prison body uses runtime-corrected $23 half-width', 'active_width = 0x23' in prison and 'resolve_solid_box(spawn_x, spawn_y, 0x23, 0x18, true, record_index)' in prison)
    check('Egg Prison button renders behind body', 'button_sprite = make_sprite("res://assets/objects/%s/04.png" % art_folder, -2)' in prison)
    check('Egg Prison button remains a separate $1B x 8 solid', 'resolve_solid_box_contact(spawn_x, button_y, 0x1B, 8, true, button_support_id)' in prison)
    check('Egg Prison switch has distinct stable support id', 'button_support_id = -0x3E00 - record_index' in prison)
    tick=prison[prison.find('func tick()'):prison.find('func _tick_button_collision')]
    check('button collision continues from main tick after activation', '_tick_button_collision(p)' in tick)
    check('only WAIT state can activate retained button contact', 'if state == STATE_WAIT and contact == SonicPlayer.SOLID_TOP' in prison)
    check('ARZ selects ARZ-paletted Egg Prison art', 'art_folder = "s2_arz/egg_prison"' in prison)

    # Catalog + DLE.
    check('ARZ2 enables retail dynamic event path', '"dynamic_events": "s2_arz2" if act == 2 else "none"' in cat)
    check('ARZ2 boss is definition-gated to Act 2', '"s2_arz_boss": act == 2' in cat)
    check('ARZ2 Egg Prison waits for boss defeat', '"s2_egg_prison_requires_boss": act == 2' in cat)
    check('ARZ2 DLE contains $2810 entrance trigger', 'screen_x >= 0x2810' in cam)
    check('ARZ2 DLE contains $2A40 arena lock', 'screen_x >= 0x2A40' in cam and 'limit_right = 0x2A40' in cam)
    check('ARZ2 DLE tightens bottom to $400', 'target_bottom = 0x400' in cam)
    check('ARZ2 DLE clamps top at $3F8', 'screen_y >= 0x3F8' in cam and 'limit_top = 0x3F8' in cam)
    check('ARZ2 DLE preserves $5A ScreenShift wait', 's2_arz2_event_timer >= 0x5A' in cam)
    check('ARZ2 allocates boss before delayed boss music', 's2_arz2_boss_spawn_requested = true' in cam and 's2_arz2_boss_music_requested = true' in cam)
    check('main loop has durable ARZ2 boss spawn recovery', 'func _tick_s2_arz2_boss_start' in main_gd and 'object_manager.spawn_s2_arz_boss()' in main_gd)
    check('ARZ2 prelude fades music', 's2_arz2_music_fade_requested' in main_gd and 'SonicAudio.stop_music()' in main_gd)
    check('ARZ2 delayed trigger starts Sonic 2 boss music', 's2_arz2_boss_music_requested' in main_gd and 'SonicAudio.MUS_S2_BOSS' in main_gd)

    # Object manager and boss constants/behaviour.
    check('ARZ boss class is preloaded', 'S2ARZBossObjectClass = preload("res://scripts/objects/s2_arz_boss_object.gd")' in om)
    check('ARZ boss manager spawn is definition-gated', 'func spawn_s2_arz_boss() -> bool:' in om and 'level_definition.get("s2_arz_boss", false)' in om)
    check('ARZ boss manager starts camera at $2A40', 'boss_limit_right = 0x2A40' in om)
    check('ARZ post-boss camera opens toward $2C00 by two/frame', 'func unlock_s2_arz_boss_right_boundary()' in om and 'mini(0x2C00, boss_limit_right + 2)' in om)
    constants={'START_X := 0x2AE0','START_Y := 0x388','ACTIVE_Y := 0x430','LEFT_TARGET_X := 0x2AB0','RIGHT_TARGET_X := 0x2B10','LEFT_PILLAR_X := 0x2A50','RIGHT_PILLAR_X := 0x2B70','PILLAR_START_Y := 0x510','PILLAR_ACTIVE_Y := 0x488','CAMERA_ESCAPE_MAX := 0x2C00'}
    check('Object $89 core source coordinates are preserved', all(x in boss for x in constants))
    check('Object $89 begins with eight hits', 'var hits := 8' in boss)
    check('Object $89 uses source $C8 horizontal speed', 'vel_x = -0xC8' in boss and 'else 0xC8' in boss)
    check('Object $89 oscillator advances independently while waiting for phase $C0', 'sine_count = (sine_count + 2) & 0xFF' in boss and 'sine_count != 0xC0' in boss and boss.find('sine_count = (sine_count + 2) & 0xFF') < boss.find('match state:'))
    check('Object $89 hammer countdown is $1E with $14 impact', 'timer = 0x1E' in boss and 'if timer == 0x14:' in boss)
    check('Object $89 pillars use source solid envelope', '0x23, 0x44, true, -0x8901' in boss and '0x23, 0x44, true, -0x8902' in boss)
    check('Object $89 arrow lanes are exact', '[0x458, 0x478, 0x498, 0x4B8]' in boss)
    check('Object $89 preserves $28-frame bulging-eye launch child', '"timer": 0x28' in boss and 'pillar_arrow/02.png' in boss)
    check('Object $89 arrow stop X coordinates are exact', '0x2A77' in boss and '0x2B49' in boss)
    check('stuck arrows are top-solid $1B platforms', 'resolve_platform_top(int(a["x"]) - 0x1B, int(a["x"]) + 0x1C' in boss)
    check('arrow supports keep stable IDs across removals', '"support_id": support_id' in boss and 'int(a["support_id"])' in boss)
    check('arrow stand countdown is source $1F', 'a["timer"] = 0x1F' in boss)
    check('defeated arrows fall to source $4F0 cutoff', 'int(a["y"]) > 0x4F0' in boss)
    check('Object $89 defeat timer is source $B3', 'timer = 0xB3' in boss)
    check('Object $89 awards boss score', 'manager.add_score(1000)' in boss)
    check('Object $89 defeat resumes ARZ music', 'SonicAudio.play_music(SonicAudio.MUS_S2_ARZ, true)' in boss)
    check('Object $89 escape uses $400/-$40 velocity', 'vel_x = 0x400' in boss and 'vel_y = -0x40' in boss)

    # Art/import package.
    check('Phase97 boss importer is packaged', (ROOT/'tools/import_s2_arz_boss_phase97.py').is_file())
    check('Phase97 documentation is packaged', (ROOT/'PHASE97_SONIC2_AQUATIC_RUIN_BOSS_END.md').is_file())
    check('ARZ boss main mapping set has 12 rendered frames', len(list((ROOT/'assets/objects/s2_arz/boss/main').glob('*.png'))) == 12)
    check('ARZ pillar/arrow mapping set has 7 rendered frames', len(list((ROOT/'assets/objects/s2_arz/boss/pillar_arrow').glob('*.png'))) == 7)
    check('ARZ Egg Prison has 6 ARZ-paletted frames', len(list((ROOT/'assets/objects/s2_arz/egg_prison').glob('*.png'))) == 6)
    check('debug HUD identifies current Phase 97 build', 'Native Sonic 1 Phase 97' in main_gd)

    # Preserve Phase96 payload/fixes.
    prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase96.py')] + ([str(s2)] if s2 else []),capture_output=True,text=True)
    check('Phase96 ARZ1/ARZ2 foundation regression remains clean', prev.returncode==0, prev.stdout.strip().splitlines()[-1] if prev.stdout else '')

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore')
        ev=asm[asm.find('LevEvents_ARZ2:'):asm.find('LevEvents_SCZ:')]
        check('retail LevEvents_ARZ2 confirms $2810/$2A40/$400/$3F8/$5A', all(x in ev for x in ('#$2810','#$2A40','#$400','#$3F8','#$5A')))
        check('retail LevEvents_ARZ2 allocates ObjID_ARZBoss before boss music', ev.find('ObjID_ARZBoss') >= 0 and ev.find('ObjID_ARZBoss') < ev.find('MusID_Boss'))
        o=asm[asm.find('Obj89:'):asm.find('Obj8A:') if asm.find('Obj8A:')>asm.find('Obj89:') else asm.find('Obj8B:')]
        check('retail Obj89 confirms spawn/active coordinates', '#$2AE0,x_pos' in o and '#$388,y_pos' in o and '#$430,(Boss_Y_pos)' in o)
        check('retail Obj89 confirms eight-hit boss', '#8,boss_hitcount2' in o)
        check('retail Obj89 confirms pillar X/Y source coordinates', '#$2A50,x_pos' in o and '#$510,y_pos' in o and '#$2B70,x_pos' in o)
        check('retail Obj89 confirms arrow stop coordinates', '#$2A77' in o and '#$2B49' in o)
        check('retail Obj89 confirms arrow platform timer $1F', '#$1F,obj89_arrow_timer' in o)
        check('retail Obj89 confirms pillar SolidObject d1/d2/d3', '#$23,d1' in o and '#$44,d2' in o and '#$45,d3' in o)
        placement=(s2/'level/objects/ARZ_2.bin').read_bytes()
        found=[]
        for i in range(0,len(placement),6):
            if (placement[i+4]&0x7F)==0x3E:
                found.append((int.from_bytes(placement[i:i+2],'big')&0x7FFF,int.from_bytes(placement[i+2:i+4],'big')&0xFFF))
        check('retail ARZ2 Egg Prison placement is $2C9C,$4B1', found==[(0x2C9C,0x4B1)], str(found))
        before=[]
        for folder in ('boss/main','boss/pillar_arrow','egg_prison'):
            for p in sorted((ROOT/'assets/objects/s2_arz'/folder).glob('*.png')):
                before.append((str(p.relative_to(ROOT)),p.read_bytes()))
        regen=subprocess.run([sys.executable,str(ROOT/'tools/import_s2_arz_boss_phase97.py'),str(s2)],capture_output=True,text=True)
        after=[]
        for folder in ('boss/main','boss/pillar_arrow','egg_prison'):
            for p in sorted((ROOT/'assets/objects/s2_arz'/folder).glob('*.png')):
                after.append((str(p.relative_to(ROOT)),p.read_bytes()))
        check('ARZ boss/prison art regenerates deterministically from retail source', regen.returncode==0 and before==after, regen.stdout.strip().replace('\n','; '))

    passed=sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
