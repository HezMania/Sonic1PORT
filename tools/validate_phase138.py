#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, sys, zipfile
P=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
S2=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
BASE=Path(sys.argv[3]).resolve() if len(sys.argv)>3 else None
checks=[]
def ck(c,m):
    checks.append((bool(c),m)); print(('PASS' if c else 'FAIL')+': '+m)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha_bytes(b): return hashlib.sha256(b).hexdigest()
def sha_file(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
main=txt('scripts/main.gd')
c7=txt('scripts/objects/s2_dez_egg_robo.gd')
man=json.loads((P/'data/s1/s2test/phase138_dez_robot_fidelity_manifest.json').read_text())

ck('Native Sonic 1 Phase 138' in main,'Debug overlay identifies Phase138')
ck((P/'PHASE138_SONIC2_DEATH_EGG_ROBOT_FIDELITY.md').exists(),'Phase138 notes packaged')
ck(man.get('phase')==138,'Phase138 manifest version')
ck(man.get('baseline')=='Sonic1PC_S2DeathEggRobotAnimation_Phase137(1).zip','Phase138 records uploaded Phase137 baseline')

# Render-depth correction: C7 children are absolute and entirely below normal Sonic Z=50.
ck('s.z_as_relative = false\n\ts.z_index = z' in c7,'C7 main part sprites use absolute canvas Z')
for tok,z,name in [
    ('BackLower',41,'back lower'),('BackForearm',41,'back forearm'),('BackThigh',41,'back thigh'),
    ('Jet',42,'jet'),('Body',44,'body'),('Arm',45,'arm'),('FrontThigh',45,'front thigh'),
    ('FrontLower',46,'front lower'),('FrontForearm',47,'front forearm'),('Shoulder',48,'shoulder'),('Head',49,'head')]:
    ck(f'_new_part("{tok}",' in c7 and f', {z})' in [line for line in c7.splitlines() if f'_new_part("{tok}"' in line][0],f'C7 {name} absolute Z is {z}')
ck(max(man['retail_render_priority']['project_part_z'].values()) < man['retail_render_priority']['project_normal_sonic_z'],'All C7 fight pieces sort below normal Sonic')
ck(man['retail_render_priority']['children_z_as_relative'] is False,'Manifest records non-relative child Z')
ck('target_sensor.z_as_relative = false' in c7 and 'target_sensor.z_index = 55' in c7,'Target sensor remains intentionally above Sonic')
ck('target_lock.z_as_relative = false' in c7 and 'target_lock.z_index = 54' in c7,'Target lock remains intentionally above Sonic')
ck('s.z_as_relative = false\n\t\ts.z_index = original.z_index' in c7,'Defeat fragments preserve source part depth')
ck('s.z_index = 50\n\t\ts.texture = original.texture' not in c7,'Phase137 flattened breakup Z removed')

# Exact retail off_3E30A body/thigh motion.
for tok,msg in [
 ('const SLAM_GROUP_DX16: Array[int] = [-32, -20, -8, -4, 0, 4, 12, 24, 24]','Slam torso X deltas match retail'),
 ('const SLAM_GROUP_DY16: Array[int] = [12, 20, 20, 12, 0, -24, -24, -12, -4]','Slam torso Y deltas match retail'),
 ('const SLAM_THIGH_DX16: Array[int] = [-8, -6, -2, 0, 0, 2, 4, 4, 6]','Slam thigh X deltas match retail'),
 ('const SLAM_THIGH_DY16: Array[int] = [4, 6, 4, 2, 0, -6, -4, -4, -2]','Slam thigh Y deltas match retail'),
 ('const SLAM_GROUP_FRAMES: int = 8','Each retail slam group lasts 8 VBlanks'),
 ('_begin_slam_recovery()','Landing starts linked retail recovery'),
 ('if not _tick_slam_recovery():','Stomp state waits for linked recovery completion'),
 ('slam_torso_offset += Vector2(float(body_dx16) / 16.0, float(body_dy16) / 16.0)','Slam body applies 1/16-pixel deltas'),
 ('slam_thigh_offset += Vector2(float(thigh_dx16) / 16.0, float(thigh_dy16) / 16.0)','Slam thighs apply independent 1/16-pixel deltas'),
 ('if not facing_left:\n\t\tbody_dx16 = -body_dx16','Slam X motion mirrors with facing'),
 ('body.position = Vector2(bdx, bdy) + slam_torso_offset','Rendered body follows retail slam offset'),
 ('front_thigh.position = Vector2(bdx + sx * (4 + tdx), bdy + 36 + tdy) + front_thigh_walk_offset + slam_thigh_offset','Front thigh follows retail slam offset'),
 ('back_thigh.position = Vector2(bdx + sx * (4 + tdx), bdy + 36 + tdy) + back_thigh_walk_offset + slam_thigh_offset','Back thigh follows retail slam offset'),
]: ck(tok in c7,msg)
ck('timer = 0x30' not in c7,'Phase137 stationary post-slam timer removed')
slam=man['retail_stomp_recovery']
ck(slam['groups']==list(range(9)) and slam['frames_per_group']==8 and slam['total_frames']==72,'Manifest records nine retail groups / 72 VBlanks')
ck(sum(slam['torso_dx16'])==0 and sum(slam['torso_dy16'])==0,'Retail torso recovery returns to anchor')
ck(sum(slam['thigh_dx16'])==0 and sum(slam['thigh_dy16'])==0,'Retail thigh recovery returns to anchor')

# Phase137 behavior retained.
for tok,msg in [
 ('head_intro_timer < 88','Phase137 head-entry timing retained'),
 ('target_vx_history: Array[int] = [0, 0, 0, 0]','Phase137 delayed target history retained'),
 ('_apply_walk_group_limb_deltas(group, walk_recovery and walk_sequence_index < 4)','Phase137 exact linked walk retained'),
 ('_trigger_front_hand()','Phase137 front forearm attack retained'),
 ('_trigger_back_hand()','Phase137 rear forearm attack retained'),
]: ck(tok in c7,msg)

# Frozen Phase134 runtime-confirmed files by known hashes.
for rel,expected in man['frozen_phase134_sha256'].items():
    ck(sha_file(P/rel)==expected,f'Phase134 runtime-confirmed file frozen: {rel}')

# Existing Phase137 payload delta should be only main label + C7 runtime.
if BASE is not None and BASE.exists():
    with zipfile.ZipFile(BASE) as z:
        changed=[]
        for rel in z.namelist():
            if rel.endswith('/'): continue
            pp=P/rel
            if pp.exists() and sha_bytes(z.read(rel))!=sha_file(pp): changed.append(rel)
    ck(set(changed)=={'scripts/main.gd','scripts/objects/s2_dez_egg_robo.gd'},'Phase138 modifies only main label and C7 runtime among Phase137 files')

# Retail final source evidence.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    sonic=asm[asm.index('Obj01_Init:'):asm.index('Obj01_Control:')]
    ck('move.b\t#2,priority(a0)' in sonic,'Retail Sonic object priority is 2')
    c7init=asm[asm.index('ObjC7_Body:'):asm.index('loc_3D5A8:')]
    ck('move.b\t#5,priority(a0)' in c7init,'Retail C7 body priority is 5')
    sub=asm[asm.index('ObjC7_SubObjData:'):asm.index('Ani_objC7_a:')]
    ck('),4,4,$38,$00' in sub,'Retail C7 child default priority is 4')
    back=asm[asm.index('ObjC7_BackLowerLeg:'):asm.index('ObjC7_TargettingSensor:')]
    ck(back.count('move.b\t#5,priority(a0)')>=3,'Retail rear leg/forearm/thigh explicitly use priority 5')
    land=asm[asm.index('loc_3D7B8:'):asm.index('loc_3D82E:')]
    ck('lea\t(off_3E30A).l,a1' in land and 'bsr.w\tloc_3E1AA' in land,'Retail landing runs off_3E30A linked animation')
    group=asm[asm.index('ObjC7_GroupAni_3E318:'):asm.index('off_3E3D0:')]
    for ev,msg in [
      ('c7ani       $00, $E0, $0C','Retail slam group 0 torso delta found'),
      ('c7ani objoff_34, $F8, $04','Retail slam group 0 front-thigh delta found'),
      ('c7ani       $00, $EC, $14','Retail slam group 1 torso delta found'),
      ('c7ani       $00, $04, $E8','Retail slam group 5 torso delta found'),
      ('c7ani       $00, $18, $FC','Retail slam group 8 torso delta found'),
      ('c7ani objoff_3E, $06, $FE','Retail slam group 8 rear-thigh delta found'),
    ]: ck(ev in group,msg)
    seq=asm[asm.index('off_3E30A:'):asm.index('ObjC7_GroupAni_3E318:')]
    ck('dc.b 0, 1, 2, 3, 4, 5, 6, 7, 8, $C0' in seq,'Retail landing sequence is groups 0 through 8')

# Parser-oriented sanity for Godot 4.6.3 target.
for rel in ['scripts/main.gd','scripts/objects/s2_dez_egg_robo.gd']:
    body=txt(rel)
    ck(not any(x in body for x in ['<<<<<<<','=======','>>>>>>>']),f'{rel} has no conflict markers')
    ck(body.count('(')==body.count(')'),f'{rel} parentheses balance')
    ck(body.count('[')==body.count(']'),f'{rel} brackets balance')
    ck(body.count('{')==body.count('}'),f'{rel} braces balance')
ck(':=' not in c7,'C7 keeps explicit declarations for Godot 4.6.3')

passed=sum(ok for ok,_ in checks)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' -',msg)
    raise SystemExit(1)
