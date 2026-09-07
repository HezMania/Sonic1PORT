#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import re, subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

obj=(PROJECT/'data/s1/s2test/ehz1_objects.bin').read_bytes()
records=[]
for i in range(0,len(obj),6):
    if i+6>len(obj): break
    records.append((int.from_bytes(obj[i:i+2],'big'), int.from_bytes(obj[i+2:i+4],'big')&0xFFF, obj[i+4], obj[i+5]))
spirals=[r for r in records if r[2]==0x06]
check(len(records)==135,'EHZ1 retains all 135 native object records')
check(spirals==[(0x12C0,0x280,0x06,0),(0x24C0,0x280,0x06,0),(0x2640,0x280,0x06,0)],
      'all three retail EHZ1 Object $06 spiral placements remain exact')

mgr=(PROJECT/'scripts/objects/object_manager.gd').read_text()
check('S2EHZSpiralPathObjectClass' in mgr and '0x06: return S2EHZSpiralPathObjectClass.new()' in mgr,
      'S2 Object $06 is now routed to the dedicated EHZ spiral pathway class')
spiral=(PROJECT/'scripts/objects/s2_ehz_spiral_path_object.gd').read_text()
check('const COSINE_TABLE: Array[int]' in spiral and '0x1A0' in spiral,
      'spiral uses the source 416-pixel Obj06 cosine pathway')
# Parse GDScript arrays to prove exact source cardinalities/endpoints.
cossec=spiral.split('const COSINE_TABLE: Array[int] = [',1)[1].split(']',1)[0]
cos=[int(x) for x in re.findall(r'-?\d+',cossec)]
flipsec=spiral.split('const FLIP_ANGLE_TABLE: Array[int] = [',1)[1].split(']',1)[0]
flip=[int(x,0) for x in re.findall(r'0x[0-9A-Fa-f]+|\d+',flipsec)]
check(len(cos)==416 and cos[:16]==[32]*16 and cos[-16:]==[32]*16,
      'Obj06 cosine table contains all 416 source entries with correct flat endpoints')
check(min(cos)==-37 and max(cos)==32,
      'Obj06 vertical excursion matches retail source (-37..+32 pixels)')
check(len(flip)==52 and flip[:4]==[0,0,1,1] and flip[-4:]==[1,1,0,0],
      'Obj06 52-byte flip-angle table matches source endpoints')
check('absi(p.inertia) < 0x600' in spiral,
      'spiral releases Sonic below the retail $600 inertia threshold')
check('p.pixel_x() - spawn_x + 0xD0' in spiral and 'offset >= 0x1A0' in spiral,
      'attached spiral uses the exact -$D0..+$CF horizontal range')
check('near_min = 0xB0 if p.standing_on_object else 0xC0' in spiral and 'near_max = 0xC0 if p.standing_on_object else 0xD0' in spiral,
      'initial capture preserves Obj06 normal/platform standing windows')
check('dy < 0 or dy >= 0x30' in spiral,
      'initial capture preserves Obj06 +$10..+$3F vertical window')
check('COSINE_TABLE[offset] - (p.height_radius - 0x13)' in spiral,
      'spiral Y position preserves source y-radius correction')

player=(PROJECT/'scripts/player/sonic_player.gd').read_text()
check('func begin_s2_spiral_pathway' in player and 'inertia = vel_x' in player and 'angle = 0' in player,
      'RideObject_SetRide bridge seeds inertia from X velocity and resets physical angle')
check('func animation_surface_angle()' in player and 's2_spiral_visual_angle' in player,
      'source flip_angle is kept visual-only instead of corrupting terrain physics')
check('experimental_sonic2' in player and 'limit_bottom' in player and 'viewport_height' in player,
      'experimental S2 bottom death uses source camera lower boundary plus viewport height')
visual=(PROJECT/'scripts/player/sonic_visual.gd').read_text()
check(visual.count('player.animation_surface_angle() & 0xFF')>=2,
      'S1-compatible and S2 animation banks both honor Obj06 visual flip angle')

main=(PROJECT/'scripts/main.gd').read_text()
check('_restart_level_presentation_after_death()' in main,
      'ordinary death restart now re-enters the level presentation path')
check('_play_level_music(current_zone, current_act, false)' in main,
      'ordinary death explicitly restarts level music from its beginning')
check('level_title_card.begin(current_zone, current_act' in main,
      'ordinary death replays supported source title cards after respawn')
check('bool(definition.get("skip_title_card", false))' in main,
      'experimental zones that deliberately lack an imported title-card bank stay guarded')

r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase84.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 84 object/spring/badnik regressions still pass')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE85_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
