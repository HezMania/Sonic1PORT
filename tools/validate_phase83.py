#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

obj=(PROJECT/'data/s1/s2test/ehz1_objects.bin').read_bytes()
counts=Counter(obj[i+4] for i in range(0,len(obj),6))
check(len(obj)==810 and hashlib.sha256(obj).hexdigest()=='8e1a1852bf2f7995cfea0ac85d11a34e6758daede11a786f4304965211dfbcad',
      'EHZ1 native 135-record object layout remains byte-for-byte unchanged')
check((counts[0x4B],counts[0x5C],counts[0x9D],counts[0x49],counts[0x06])==(11,13,8,10,3),
      'source counts are 11 Buzzer, 13 Masher, 8 Coconuts, 10 waterfall, 3 spiral')

mgr=(PROJECT/'scripts/objects/object_manager.gd').read_text()
check('0x49: return S2EHZWaterfallObjectClass.new()' in mgr,'S2 waterfall is dispatched in the isolated S2 namespace')
check('0x4B, 0x5C, 0x9D: return S2EHZBadnikObjectClass.new()' in mgr,'all three EHZ badnik IDs dispatch through the native S2 runtime')
check('_: return S2UnsupportedObjectClass.new()' in mgr,'unsupported S2 IDs remain isolated from Sonic 1 IDs')
supported={0x03,0x0D,0x11,0x18,0x1C,0x26,0x36,0x41,0x49,0x4B,0x5C,0x79,0x9D}
check(sum(counts[x] for x in supported)==132,'Phase 83 actively supports exactly 132 of 135 EHZ1 records')
check(counts[0x06]==3,'only three twisting-spiral records remain deferred')

spring=(PROJECT/'scripts/objects/s2_spring_object.gd').read_text()
check('const DIAG_UP_PROFILE: Array[int]' in spring and '16,16,16,16,16,16,16,16,16,16,16,16,14,12,10,8,6,4,2,0,-2,-4,-4,-4,-4,-4,-4,-4' in spring,
      'diagonal-up spring uses the exact 28-byte retail S2 slope profile')
check('var sample = 53 - d0 if x_flip else d0' in spring and 'var index = clampi(sample >> 1, 0, 27)' in spring,
      'diagonal spring mirrors/halves X exactly like SlopedSolid_cont')
check('resolve_platform_top(spawn_x - 27, spawn_x + 28, surface_y, record_index)' in spring,
      'ground diagonal spring follows its sampled source surface rather than a flat 32x32 box')
check('if (subtype & 0x80) != 0:' in spring,'spring negative subtype preserves Kill Transverse Speed behavior')
check('var vertical_frames: Array[int] = [1, 2, 0]' in spring and 'var horizontal_frames: Array[int] = [4, 5, 3]' in spring,
      'Phase 82 typed Array[int] spring fix remains intact')

player=(PROJECT/'scripts/player/sonic_player.gd').read_text()
check('spring_pose_timer = 0 if spring_orientation == 1 else 48' in player,
      'S1 presentation no longer forces spring pose for horizontal/side launches')
check('source_uses_spring_pose = spring_orientation == 0 or spring_orientation == 3' in player,
      'Beta/Final normal spring pose follows retail up/diagonal-up assignment')
check('if (source_subtype & 1) != 0:' in player and 's2_twirl_active = true' in player,
      'Beta/Final twirl subtype handling remains active')

bad=(PROJECT/'scripts/objects/s2_ehz_badnik_object.gd').read_text()
for token,label in [
    ('buzzer_move_timer = 0x100','Buzzer source travel timer'),
    ('buzzer_turn_delay = 0x1E','Buzzer source turnaround timer'),
    ('distance < 0x28 or distance > 0x30','Buzzer source firing strip'),
    ('buzzer_shot_timer = 0x32','Buzzer source shot timer'),
    ('buzzer_shot_timer == 0x14','Buzzer source projectile timing'),
    ('masher_vel_y = -0x400','Masher initial jump velocity'),
    ('masher_vel_y = GenesisMath.s16(masher_vel_y + 0x18)','Masher source gravity'),
    ('masher_vel_y = -0x500','Masher repeating jump reset'),
    ('COCONUT_CLIMB_SPEED: Array[int] = [-0x100, 0x100, -0x100, 0x100, -0x100, 0x100]','Coconuts climb speed table'),
    ('COCONUT_CLIMB_TIME: Array[int] = [0x20, 0x18, 0x10, 0x28, 0x20, 0x10]','Coconuts climb time table'),
    ('absi(p.pixel_x() - int(position.x)) < 0x60','Coconuts attack distance'),
]: check(token in bad,label+' is present')

proj=(PROJECT/'scripts/objects/s2_ehz_projectile.gd').read_text()
check('vel_y = 0x180' in proj and '5 + ((frame_tick >> 2) & 1)' in proj,'Buzzer projectile uses source downward speed and two mapping frames')
check('vel_y = GenesisMath.s16(vel_y + 0x20)' in proj,'coconut projectile uses source +$20 gravity')

water=(PROJECT/'scripts/objects/s2_ehz_waterfall_object.gd').read_text()
check('spawn_x - 0x40' in water and 'spawn_x + 0x40' in water and 'frame + 1' in water,
      'waterfall uses source x±$40 mapping-frame switch')

expected_counts={'buzzer':7,'masher':2,'coconuts':4,'waterfall':8}
for folder,n in expected_counts.items():
    files=sorted((PROJECT/f'assets/objects/s2_ehz/{folder}').glob('*.png'))
    check(len(files)==n,f'{folder} source mapping bank contains {n} rendered frames')

# Strong identity checks for representative source-regenerated frames.
sha={
'buzzer/00.png':'5998e6bf9ecfef37a14b6587df9c965e2bbe82f61792335f9d3c3f90eb5d26dc',
'buzzer/05.png':'58d8fbc36e2cb14a9fd475afe2a4f954785041aa8fc8def88e397a063d66bc29',
'masher/00.png':'82c9654ebd1c31261939bc8a19ba8053485dd8677140bc14927e2e2f19b9fb60',
'coconuts/00.png':'472c00f6abb42596f470812b4211b7becf60c0b7dde7529440f75117e1f28966',
'coconuts/03.png':'3d9d4bd4e56856faeaa5e88716c2f6a5d5421f5afdd2a01c5a0138ed383862c4',
'waterfall/05.png':'eaa6f9950cb2d04d799ef390ea504ac52006cb02831b751a2a733cdefe2fb62c',
}
for rel,digest in sha.items():
    data=(PROJECT/'assets/objects/s2_ehz'/rel).read_bytes()
    check(hashlib.sha256(data).hexdigest()==digest,f'{rel} matches the source-regenerated Phase 83 frame')

# Ring/physics/chunk regression boundary.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase80_hotfix1.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 80 HF1 shared-ring and earlier S2 terrain/physics regressions still pass')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE83_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
