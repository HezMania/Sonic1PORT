#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, subprocess, sys

PROJECT = Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

objdata=(PROJECT/'data/s1/s2test/ehz1_objects.bin').read_bytes()
counts=Counter(objdata[i+4] for i in range(0,len(objdata),6))
check(len(objdata)==810 and hashlib.sha256(objdata).hexdigest()=='8e1a1852bf2f7995cfea0ac85d11a34e6758daede11a786f4304965211dfbcad',
      'EHZ1 native 135-record object layout remains byte-for-byte unchanged')
check(counts[0x26]==13 and counts[0x79]==3 and counts[0x0D]==1,
      'EHZ1 source contains 13 monitors, 3 starposts and 1 signpost')

manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
check(('0x0D: return SignpostObject.new()' in manager) or ('0x0D: return S2SignpostAdapterClass.new()' in manager),
      'S2 dispatcher enables source object $0D through requested shared runtime/adapter')
for oid,code in [(0x26,'S2MonitorAdapterClass.new()'),(0x79,'LamppostObject.new()')]:
    check(f'0x{oid:02X}: return {code}' in manager,f'S2 dispatcher enables source object ${oid:02X} through requested shared runtime')
for oid,klass in [(0x03,'S2PlaneSwitcherObjectClass'),(0x11,'S2EHZBridgeObjectClass'),(0x18,'S2EHZPlatformObjectClass'),(0x1C,'S2EHZSceneryObjectClass'),(0x36,'S2SpikesObjectClass'),(0x41,'S2SpringObjectClass')]:
    check(f'0x{oid:02X}: return {klass}.new()' in manager,f'Phase 81 S2 dispatcher ${oid:02X} remains intact')
check('_: return S2UnsupportedObjectClass.new()' in manager,'unsupported S2 IDs remain isolated from the S1 namespace')
check(sum(counts[x] for x in {0x03,0x0D,0x11,0x18,0x1C,0x26,0x36,0x41,0x79})==90,
      'Phase 82 actively supports exactly 90 of 135 EHZ source records')
check(sum(counts[x] for x in {0x06,0x49,0x4B,0x5C,0x9D})==45,
      'the remaining 45 EHZ records are the intended deferred objects')

spring=(PROJECT/'scripts/objects/s2_spring_object.gd').read_text()
check('func _anim_frames() -> Array[int]:' in spring and 'var vertical_frames: Array[int] = [1, 2, 0]' in spring and 'var horizontal_frames: Array[int] = [4, 5, 3]' in spring and 'var diagonal_frames: Array[int] = [8, 9, 7]' in spring,
      'S2 spring animation returns explicitly typed Array[int] locals')
check('return [1,2,0] if orientation' not in spring and 'return [1, 2, 0] if orientation' not in spring,
      'the Phase 81 chained generic-Array return is gone')
check('p.begin_s2_spring_visual(subtype, orientation)' in spring,
      'S2 spring launch explicitly informs the animation-profile layer')

player=(PROJECT/'scripts/player/sonic_player.gd').read_text()
check('func begin_s2_spring_visual(source_subtype: int, spring_orientation: int) -> void:' in player,
      'player owns an animation-style-aware S2 spring visual bridge')
check('if animation_style == ANIMATION_STYLE_SONIC1:' in player and 'spring_pose_timer = 48' in player,
      'Sonic 1 presentation always selects the classic spring pose')
check('if (source_subtype & 1) != 0:' in player and 's2_twirl_active = true' in player,
      'S2 spring subtype bit 0 enables tumble state')
check('s2_twirl_speed = 4 if spring_orientation in [0, 2] else 8' in player,
      'S2 vertical/horizontal tumble speeds match the source 4/8 values')
check('s2_twirl_remaining = 0 if (source_subtype & 2) != 0 else 1' in player and 's2_twirl_remaining = 1 if (source_subtype & 2) != 0 else 3' in player,
      'S2 yellow/red tumble counts match Obj41 source setup')
check('_update_s2_twirl_angle()' in player[player.index('func _jump_angle()'):player.index('# -----------------------------------------------------------------------------\n# Slope force')],
      'S2 flip angle advances from the same jump-angle stage as retail Sonic 2')

visual=(PROJECT/'scripts/player/sonic_visual.gd').read_text()
check('player.s2_twirl_active and player.animation_style != SonicPlayer.ANIMATION_STYLE_SONIC1' in visual and 'mode = 17' in visual,
      'twirl rendering is restricted to Beta/Final presentation profiles')
check('var frame_base = 0x9B if beta else 0x5F' in visual,
      'SAnim_Tumble uses Simon Wai $9B and retail S2 $5F mapping bases')
check('elif player.spring_pose_timer > 0:' in visual,
      'classic spring pose can display for horizontal as well as airborne S2 springs')
for style,base in [('beta',0x9B),('final',0x5F)]:
    frames=PROJECT/f'assets/sonic2/{style}/frames'
    check(all((frames/f'{i:03d}.png').is_file() for i in range(base,base+12)),
          f'all 12 {style} tumble source frames are already packaged')

adapter=(PROJECT/'scripts/objects/s2_monitor_adapter.gd').read_text()
check('extends MonitorObject' in adapter,'S2 monitor adapter directly reuses proven Sonic 1 MonitorObject code')
for src,dst,label in [(1,2,'1-up'),(3,1,'Robotnik'),(4,6,'10 rings'),(5,3,'speed shoes'),(6,4,'shield'),(7,5,'invincibility')]:
    token=f'{src}: return {dst}' if src != 1 else '1, 2: return 2'
    check(token in adapter,f'S2 monitor subtype {src} maps to the S1 {label} semantic slot')

# Source placement facts for the two twirl springs are fixed in the byte-for-byte layout.
twirl=[]
for i in range(0,len(objdata),6):
    x=(objdata[i]<<8)|objdata[i+1]
    y=((objdata[i+2]<<8)|objdata[i+3])&0x0FFF
    oid=objdata[i+4]; subtype=objdata[i+5]
    if oid==0x41 and (subtype&1): twirl.append((x,y,subtype))
check(twirl==[(0x08AC,0x0238,0x03),(0x0EF4,0x01B8,0x03)],
      'EHZ1 twirl regression targets are the two source subtype-$03 yellow vertical springs')

# Previous verified systems must remain healthy. Phase 80 HF1 chains Phase 79.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase80_hotfix1.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 80 Hotfix 1 rings + Phase 79 physics/animation/camera regression still passes')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE82_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
