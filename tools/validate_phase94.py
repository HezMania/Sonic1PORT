#!/usr/bin/env python3
from pathlib import Path
import hashlib, subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    cat=(ROOT/'scripts/data/level_catalog.gd').read_text()
    cam=(ROOT/'scripts/camera/sonic_camera.gd').read_text()
    main=(ROOT/'scripts/main.gd').read_text()
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    boss=(ROOT/'scripts/objects/s2_cpz_boss_object.gd').read_text()
    prison=(ROOT/'scripts/objects/s2_egg_prison_object.gd').read_text()

    check('CPZ2 catalog enables retail dynamic events', '"dynamic_events": "s2_cpz2" if act == 2 else "none"' in cat)
    check('CPZ2 boss and prison gate are isolated to Act 2', '"s2_cpz_boss": act == 2' in cat and '"s2_egg_prison_requires_boss": act == 2' in cat)
    check('CPZ2 still uses retail source water configuration', '"s2_cpz_water": act == 2' in cat)
    check('CPZ2 progression remains explicit until ARZ is imported', 'Vector2i(ZONE_GHZ, 1)' in cat and 'Aquatic Ruin' in cat)

    check('camera enters CPZ2 DLE at $2680 and tightens bottom to $450', 'screen_x >= 0x2680' in cam and 'target_bottom = 0x450' in cam)
    check('camera locks CPZ2 arena at $2A20', 'screen_x >= 0x2A20' in cam and 'limit_left = 0x2A20' in cam and 'limit_right = 0x2A20' in cam)
    check('camera applies source $448 upper boundary in prelude', 'screen_y >= 0x448' in cam and 'limit_top = 0x448' in cam)
    check('camera uses exact $5A ScreenShift wait', 's2_cpz2_event_timer >= 0x5A' in cam)
    check('main-loop watchdog keeps CPZ boss allocation authoritative', '_tick_s2_cpz2_boss_start' in main and 'spawn_s2_cpz_boss()' in main and '_s2_cpz2_boss_spawn_attempts += 1' in main)
    check('S2 boss music starts only after successful allocation', 'if not object_manager.spawn_s2_cpz_boss()' in main and 'SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)' in main)

    check('ObjectManager dispatches placed Egg Prison and can spawn Object $5D', '0x3E: return S2EggPrisonObjectClass.new()' in om and 'S2CPZBossObjectClass.new()' in om)
    check('CPZ boss arena begins locked at $2A20', 'boss_limit_right = 0x2A20' in om and 'boss_screen_lock = true' in om)
    check('CPZ boss escape opens camera toward $2C30', 'mini(0x2C30, boss_limit_right + 2)' in om)

    for token in ('START_X = 0x2B80','START_Y = 0x4B0','HOVER_Y = 0x4C0','LEFT_SIDE_X = 0x2A50','RIGHT_SIDE_X = 0x2B30','TRACK_LEFT_X = 0x2A28','TRACK_RIGHT_X = 0x2B70','PIPE_SEGMENTS = 0x0C'):
        check('boss source constant '+token, token in boss)
    check('CPZ boss retains eight hits and $20 hit immunity', 'var hits = 8' in boss and 'invincibility_timer = 0x20' in boss)
    check('CPZ boss source movement uses $100 descent and +/-$300 side travel', 'vel_y = 0x100' in boss and '0x300 if target > px else -0x300' in boss)
    check('CPZ boss creates twelve pipe stages and two pump cycles', 'pipe_visible < PIPE_SEGMENTS' in boss and 'pump_cycles_left = 2' in boss)
    check('CPZ boss tracks Sonic+$4C inside source limits', 'manager.player.pixel_x() + 0x4C' in boss and 'TRACK_LEFT_X, TRACK_RIGHT_X' in boss)
    check('CPZ Mega Mack is hazardous and resumes side cycle after floor hit', 'p.apply_hazard_hit(gx)' in boss and 'state = STATE_MOVE_SIDE' in boss)
    check('CPZ boss defeat uses source $B3 / -$26 / $30 / $38 timing', 'defeat_timer = 0xB3' in boss and 'defeat_timer = -0x26' in boss and 'defeat_timer == 0x30' in boss and 'defeat_timer >= 0x38' in boss)
    check('CPZ boss escape uses $400,-$40 and two-pixel camera release', 'vel_x = 0x400' in boss and 'vel_y = -0x40' in boss and 'unlock_s2_cpz_boss_right_boundary()' in boss)
    check('CPZ boss restarts Chemical Plant music before escape', 'SonicAudio.play_music(SonicAudio.MUS_S2_CPZ, true)' in boss)

    check('CPZ2 Egg Prison waits for boss defeat', 'manager.boss_status < 1' in prison and 'requires_boss_defeat' in prison)
    check('CPZ2 Egg Prison uses CPZ-paletted art', 'art_folder = "s2_cpz/egg_prison"' in prison)
    check('Egg Prison retains source opening/release timers', 'timer = 0x1D' in prison and 'timer = 0xB4' in prison)
    check('Egg Prison hands off to normal act-complete tally', 'manager.begin_act_complete()' in prison)

    counts={'eggpod_pal0':7,'eggpod_pal1':7,'mechanism_pal1':40,'mechanism_pal3':40,'jets':2,'smoke':4}
    for folder,n in counts.items():
        files=sorted((ROOT/'assets/objects/s2_cpz/boss'/folder).glob('*.png'))
        check(f'{folder} has {n} source-rendered frames', len(files)==n, str(len(files)))
    check('CPZ-paletted Egg Prison has six source frames', len(list((ROOT/'assets/objects/s2_cpz/egg_prison').glob('*.png')))==6)

    b=(ROOT/'data/s1/s2test/cpz2_objects.bin').read_bytes()
    recs=[]
    for i in range(0,len(b),6):
        x=int.from_bytes(b[i:i+2],'big'); yw=int.from_bytes(b[i+2:i+4],'big'); oid=b[i+4]; sub=b[i+5]
        if oid==0x3E: recs.append((i//6,x,yw&0x0FFF,sub))
    check('CPZ2 keeps one placed Egg Prison at $2CD0,$4E0', recs==[(201,0x2CD0,0x4E0,0)], str(recs))

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore')
        event=asm[asm.find('LevEvents_CPZ2:'):asm.find('LevEvents_DEZ:')]
        check('retail LevEvents_CPZ2 contains $2680/$450/$2A20/$448/$5A and Obj5D', all(t in event for t in ('#$2680','#$450','#$2A20','#$448','#$5A','ObjID_CPZBoss')))
        obj_start=asm.find('Obj5D:')
        obj=asm[obj_start:obj_start+120000]
        check('retail Object $5D source contains start position and eight-hit collision', all(t in obj for t in ('#$2B80','#$4B0','#8,collision_property')))
        check('CPZ2 object payload remains byte-identical to retail source', b==(s2/'level/objects/CPZ_2.bin').read_bytes())

        targets=[]
        for folder,n in counts.items(): targets += [ROOT/f'assets/objects/s2_cpz/boss/{folder}/{i:02d}.png' for i in range(n)]
        targets += [ROOT/f'assets/objects/s2_cpz/egg_prison/{i:02d}.png' for i in range(6)]
        before={str(p):sha(p) for p in targets}
        subprocess.run([sys.executable,str(ROOT/'tools/import_s2_cpz_boss.py'),str(s2)],check=True,stdout=subprocess.DEVNULL)
        after={str(p):sha(p) for p in targets}
        check('CPZ boss/prison art regenerates deterministically from retail source', before==after)

        prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase93_hotfix1.py'),str(s2)],capture_output=True,text=True)
        check('Phase 93 Hotfix 1 traversal/water regression boundary stays clean', prev.returncode==0, prev.stdout.strip().splitlines()[-1] if prev.stdout else '')

    passed=sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
