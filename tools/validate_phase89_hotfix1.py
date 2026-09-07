#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys

PROJECT = Path(__file__).resolve().parents[1]
checks=[]
def check(ok,msg):
    ok=bool(ok); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

camera=(PROJECT/'scripts/camera/sonic_camera.gd').read_text()
main=(PROJECT/'scripts/main.gd').read_text()
manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()

check('var s2_ehz2_boss_spawn_requested := false' in camera,
      'EHZ2 DLE has a persistent boss-allocation request latch')
check(camera.count('s2_ehz2_boss_spawn_requested = false') >= 1,
      'boss request latch resets with level/camera configuration')
check('s2_ehz2_event_timer >= 0x5A' in camera and 's2_ehz2_boss_spawn_requested = true' in camera,
      'the exact $5A prelude completion asserts the persistent Object $56 request')
check('func spawn_s2_ehz_boss() -> bool:' in manager,
      'Object $56 allocation returns an explicit success acknowledgement')
check('boss_object != null and is_instance_valid(boss_object):\n\t\treturn true' in manager,
      'an already-created EHZ boss acknowledges the request idempotently')
check('transient_objects.append(boss)\n\treturn true' in manager,
      'new Object $56 creation acknowledges only after it is registered for ticking')
check('(sonic_camera.s2_ehz2_boss_spawn_requested or sonic_camera.dle_routine >= 3)' in main,
      'main retries delivery after Routine3 instead of depending on one trigger edge')
check('if object_manager.spawn_s2_ehz_boss():' in main and 'sonic_camera.s2_ehz2_boss_spawn_requested = false' in main,
      'the request is cleared only after Object $56 creation succeeds')
spawn_block=main[main.index('if s2_ehz2_boss_act and object_manager.boss_status < 1 and (sonic_camera.s2_ehz2_boss_spawn_requested'):main.index('if sbz2_transition_act:', main.index('if s2_ehz2_boss_act and object_manager.boss_status < 1 and (sonic_camera.s2_ehz2_boss_spawn_requested'))]
check('SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)' in spawn_block,
      'Boss music starts only inside the successful Object $56 acknowledgement path')
check('elif s2_ehz2_boss_act and sonic_camera.boss_triggered:' not in main,
      'the old one-frame generic boss-trigger spawn branch is removed')

r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase89.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'complete Phase 89 regression suite still passes')

passed=sum(ok for ok,_ in checks); total=len(checks)
text='\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n'
(PROJECT/'PHASE89_HOTFIX1_VALIDATION_RESULTS.txt').write_text(text)
print(f'\n{passed}/{total} checks passed')
if passed!=total: raise SystemExit(1)
