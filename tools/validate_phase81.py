#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, subprocess, sys

PROJECT = Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()
objpath=PROJECT/'data/s1/s2test/ehz1_objects.bin'
data=objpath.read_bytes() if objpath.exists() else b''
manifest=json.loads((PROJECT/'data/s1/s2test/phase81_objects_manifest.json').read_text())

check(len(data)==810 and len(data)%6==0,'EHZ1 native object list is 810 bytes / 135 six-byte records')
check(hashlib.sha256(data).hexdigest()=='8e1a1852bf2f7995cfea0ac85d11a34e6758daede11a786f4304965211dfbcad','EHZ1 object list matches source SHA-256')

counts=Counter(data[i+4] for i in range(0,len(data),6))
expected={0x03:19,0x06:3,0x0D:1,0x11:7,0x18:7,0x1C:14,0x26:13,0x36:12,0x41:14,0x49:10,0x4B:11,0x5C:13,0x79:3,0x9D:8}
check(dict(counts)==expected,'all 135 source object IDs/counts are preserved, including full ID $9D')

flag_counts=Counter()
for i in range(0,len(data),6):
    yf=(data[i+2]<<8)|data[i+3]
    flag_counts[(bool(yf&0x2000),bool(yf&0x4000),bool(yf&0x8000))]+=1
check(flag_counts[(True,False,False)]==3,'source list contains the expected three X-flipped placements')
check(flag_counts[(False,True,False)]==9,'source list contains the expected nine Y-flipped placements')
check(flag_counts[(False,False,True)]==48,'source list contains the expected 48 remember-state placements')

check('func _load_s2_objpos(path: String) -> bool:' in manager,'dedicated native six-byte S2 object loader is present')
check('"id": int(data[offset + 4])' in manager,'S2 loader preserves the full 8-bit object ID')
check('"x_flip": (y_flags & 0x2000) != 0' in manager,'S2 source bit 13 maps to X flip')
check('"y_flip": (y_flags & 0x4000) != 0' in manager,'S2 source bit 14 maps to Y flip')
check('"remember": (y_flags & 0x8000) != 0' in manager,'S2 source bit 15 maps to S2 remember/respawn state')
check(catalog.count('"s2_objects":')==1 and '"s2_objects": "s2test/ehz1_objects.bin"' in catalog,'native S2 object list is enabled only for EHZ in Phase 81')

supported={0x03,0x11,0x18,0x1C,0x36,0x41}
check(sum(counts[x] for x in supported)==73,'Phase 81 supports exactly 73 of 135 EHZ source object records')
for oid,klass in [(0x03,'S2PlaneSwitcherObjectClass'),(0x11,'S2EHZBridgeObjectClass'),(0x18,'S2EHZPlatformObjectClass'),(0x1C,'S2EHZSceneryObjectClass'),(0x36,'S2SpikesObjectClass'),(0x41,'S2SpringObjectClass')]:
    check(f'0x{oid:02X}: return {klass}.new()' in manager,f'S2 object ${oid:02X} has an isolated Phase 81 dispatcher')
check('_: return S2UnsupportedObjectClass.new()' in manager,'unsupported S2 IDs cannot fall through to same-numbered Sonic 1 objects')

plane=(PROJECT/'scripts/objects/s2_plane_switcher_object.gd').read_text()
check('(subtype & 0x80) != 0 and p.in_air' in plane,'Obj03 negative-subtype airborne guard is retained')
check('(subtype & 0x08) != 0' in plane and '(subtype & 0x10) != 0' in plane,'Obj03 uses separate crossing-direction path bits')
platform=(PROJECT/'scripts/objects/s2_ehz_platform_object.gd').read_text()
check('manager.oscillate_1a()' in platform and 'GenesisMath.sine' in platform,'Obj18 uses global oscillation plus stood-on sine nudge')
spikes=(PROJECT/'scripts/objects/s2_spikes_object.gd').read_text()
check('move_offset >= 32' in spikes and 'move_delay = 60' in spikes,'Obj36 retains 32px retract distance and 60-frame endpoint pauses')
check('contact == SonicPlayer.SOLID_LEFT or contact == SonicPlayer.SOLID_RIGHT' in spikes,'S2 sideways spikes hurt on either SolidObject side')
spring=(PROJECT/'scripts/objects/s2_spring_object.gd').read_text()
check('0x0A00 if (subtype & 2) != 0 else 0x1000' in spring,'Obj41 uses source yellow/red spring strengths')
check('GHZLevelData.COLLISION_PATH_SECONDARY' in spring,'Obj41 can select the S2 secondary collision path after launch')
scenery=(PROJECT/'scripts/objects/s2_ehz_scenery_object.gd').read_text()
check('subtype == 0x02' in scenery and 's2_ehz/bridge/01.png' in scenery,'all EHZ Obj1C subtype $02 records use the source bridge-stake frame')

expected_assets=[]
expected_assets += [PROJECT/f'assets/objects/s2_ehz/platform/{i:02d}.png' for i in range(2)]
expected_assets += [PROJECT/f'assets/objects/s2_ehz/bridge/{i:02d}.png' for i in range(2)]
expected_assets += [PROJECT/f'assets/objects/s2_ehz/spikes/{i:02d}.png' for i in range(8)]
for color in ('red','yellow'):
    expected_assets += [PROJECT/f'assets/objects/s2_ehz/spring_vertical_{color}/{i:02d}.png' for i in (0,1,2,6)]
    expected_assets += [PROJECT/f'assets/objects/s2_ehz/spring_horizontal_{color}/{i:02d}.png' for i in (3,4,5)]
    expected_assets += [PROJECT/f'assets/objects/s2_ehz/spring_diagonal_{color}/{i:02d}.png' for i in (7,8,9,10)]
check(all(p.is_file() for p in expected_assets),f'all {len(expected_assets)} source-rendered Phase 81 object frames are packaged')
check(manifest['ehz1_objects']['records']==135 and manifest['ehz1_objects']['sha256']==hashlib.sha256(data).hexdigest(),'Phase 81 source manifest matches packaged native layout')

# The ring hotfix is the previous runtime-confirmed baseline. Its validator also
# chains into Phase 79's physics/animation/camera suite.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase80_hotfix1.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 80 Hotfix 1 ring + Phase 79 regression validator still passes')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE81_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
