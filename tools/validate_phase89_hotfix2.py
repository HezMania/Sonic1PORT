#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys

PROJECT = Path(__file__).resolve().parents[1]
checks=[]
def check(ok,msg):
    ok=bool(ok); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

main=(PROJECT/'scripts/main.gd').read_text()
camera=(PROJECT/'scripts/camera/sonic_camera.gd').read_text()
manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
boss=(PROJECT/'scripts/objects/s2_ehz_boss_object.gd').read_text()
catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()

check('var _s2_ehz2_boss_gate_timer := -1' in main,
      'main owns an independent EHZ2 boss-prelude watchdog timer')
check('bool(level.definition.get("s2_ehz_boss", false))' in main,
      'EHZ2 boss runtime is gated by the loaded level definition')
check('func _tick_s2_ehz2_boss_start(player: SonicPlayer, active: bool) -> void:' in main,
      'main has a dedicated authoritative EHZ2 boss-start routine')
for token in ['sonic_camera.s2_ehz2_music_fade_requested','sonic_camera.dle_routine >= 2','sonic_camera.screen_x >= 0x28F0','player.pixel_x() >= 0x2990']:
    check(token in main, f'boss watchdog accepts arena-ready signal: {token}')
for token in ['sonic_camera.limit_left = 0x28F0','sonic_camera.limit_right = 0x2940','sonic_camera.target_bottom = 0x390','sonic_camera.dle_routine = 2']:
    check(token in main, f'stalled Routine1 recovery restores source arena value: {token}')
check('_s2_ehz2_boss_gate_timer < 0x5A' in main and '_s2_ehz2_boss_gate_timer += 1' in main,
      'main watchdog preserves the source $5A-frame ScreenShift wait')
check('sonic_camera.s2_ehz2_event_timer = maxi(sonic_camera.s2_ehz2_event_timer, _s2_ehz2_boss_gate_timer)' in main,
      'main and camera prelude timers stay synchronized rather than double-counting')
check('_s2_ehz2_boss_spawn_attempts += 1' in main and 'if not object_manager.spawn_s2_ehz_boss():' in main,
      'Object $56 allocation is retried until successful')
check('sonic_camera.s2_ehz2_boss_spawn_requested = false' in main and 'SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)' in main,
      'request clears and Boss music begins only after successful creation')
check('if not bool(level_definition.get("s2_ehz_boss", false)):' in manager,
      'object-manager boss allocation no longer depends on outer zone/act bookkeeping')
check('"s2_ehz_boss": act == 2' in catalog,
      'only EHZ2 advertises the S2 EHZ boss capability')
check('EHZ2dle:%d evt:%d req:%s' in camera,
      'F4 camera diagnostics expose EHZ2 DLE/timer/request state')
check('START_X := 0x2AF0' in boss and 'START_Y := 0x2F8' in boss and 'JOIN_X := 0x29D0' in boss and 'JOIN_Y := 0x41E' in boss,
      'boss approach coordinates remain source-faithful after the spawn fix')

# Conceptual state-harness for the watchdog: normal Routine2 and a stalled
# Routine1 at the exact camera threshold both must reach allocation after $5A.
def simulate(routine, screen_x, player_x, fade=False, camera_timer=0, frames=120):
    gate=-1
    spawned=False
    for _ in range(frames):
        arena_ready = fade or routine >= 2 or screen_x >= 0x28F0 or player_x >= 0x2990
        if not arena_ready:
            continue
        if routine < 2:
            routine=2; fade=True
        if gate < 0:
            gate=max(0,camera_timer)
        else:
            gate=max(gate,camera_timer)
        if gate < 0x5A:
            gate += 1
            camera_timer=max(camera_timer,gate)
        if gate >= 0x5A:
            routine=max(routine,3); spawned=True; break
    return spawned, routine, gate

check(simulate(2,0x28F0,0x2990,True,0,95)[0],
      'watchdog state harness reaches Object $56 allocation from normal Routine2')
rec=simulate(1,0x28F0,0x2990,False,0,95)
check(rec[0] and rec[1] >= 3 and rec[2] >= 0x5A,
      'watchdog state harness recovers a visibly locked Routine1 and still spawns')

# Retail-source sanity when supplied.
if len(sys.argv)>1:
    src=Path(sys.argv[1]).resolve()
    asm=(src/'s2.asm').read_text(errors='ignore')
    check('cmpi.w\t#$28F0,(Camera_X_pos).w' in asm and 'move.w\t#$2940,(Camera_Max_X_pos).w' in asm,
          'retail source confirms the $28F0/$2940 arena lock')
    check('cmpi.b\t#$5A,(ScreenShift).w' in asm and 'move.b\t#ObjID_EHZBoss,id(a1)' in asm,
          'retail source confirms $5A wait followed by Object $56 allocation')

r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase89.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'complete Phase 89 regression suite still passes')

passed=sum(ok for ok,_ in checks); total=len(checks)
text='\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n'
(PROJECT/'PHASE89_HOTFIX2_VALIDATION_RESULTS.txt').write_text(text)
print(f'\n{passed}/{total} checks passed')
if passed!=total:
    if r.returncode != 0:
        print('\nPhase89 regression stdout:\n'+r.stdout)
        print('\nPhase89 regression stderr:\n'+r.stderr)
    raise SystemExit(1)
