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
om=txt('scripts/objects/object_manager.gd')
man=json.loads((P/'data/s1/s2test/phase139_dez_robot_linked_slam_explosion_manifest.json').read_text())

ck('Native Sonic 1 Phase 139' in main,'Debug overlay identifies Phase139')
ck((P/'PHASE139_SONIC2_DEATH_EGG_ROBOT_LINKED_SLAM_EXPLOSIONS.md').exists(),'Phase139 notes packaged')
ck(man.get('phase')==139,'Phase139 manifest version')
ck(man.get('baseline')=='Sonic1PC_S2DeathEggRobotFidelity_Phase138.zip','Phase139 records Phase138 baseline')

# Parent-follow bridge for shoulder/head/jet.
for tok,msg in [
 ('shoulder.position = Vector2(bdx + sx * 12, bdy - 20) + slam_torso_offset','Shoulder follows main-object slam lurch'),
 ('head.position = Vector2(bdx, bdy - 52) + slam_torso_offset','Head follows main-object slam lurch'),
 ('jet.position = Vector2(bdx + sx * 56, bdy + 24) + slam_torso_offset','Jet follows main-object slam lurch'),
 ('var head_hit: bool = absi(p.pixel_x() - bx)','Head collision X follows lurching body anchor'),
 ('absi(p.pixel_y() - (by - 0x34))','Head collision Y follows lurching body anchor'),
 ('Vector2i(torso_x + sx * 12, torso_y - 20)','Shoulder hazard center follows lurching body anchor'),
]: ck(tok in c7,msg)
ck('front_lower.position = Vector2(bdx - sx * 4, bdy + 60) + front_lower_walk_offset' in c7,'Front lower leg stays outside slam torso offset')
ck('back_lower.position = Vector2(bdx - sx * 4, bdy + 60) + back_lower_walk_offset' in c7,'Back lower leg stays outside slam torso offset')
followers=man['retail_parent_followers']
ck(followers['parts']==['shoulder','head','jet'] and followers['lower_legs_remain_stationary_during_off_3E30A'] is True,'Manifest records retail parent-follow/fixed split')

# Scoped high-priority defeat explosions.
ck('func spawn_boss_explosion_front(x: int, y: int) -> void:' in om,'ObjectManager exposes scoped front boss-explosion path')
ck('_spawn_explosion_at_z(x, y, 130)' in om,'Front boss explosions use Z=130')
ck('func _spawn_explosion_at_z(x: int, y: int, draw_z: int) -> void:' in om and 'explosion.z_index = draw_z' in om,'Explosion helper accepts explicit draw depth')
ck('func _spawn_explosion(x: int, y: int) -> void:\n\t_spawn_explosion_at_z(x, y, 56)' in om,'Existing explosion paths retain Z=56 default')
ck('manager.spawn_boss_explosion_front((x_fixed >> 16) + rx, (y_fixed >> 16) + ry)' in c7,'C7 random defeat/ending explosions use front path')
ck('manager.spawn_boss_explosion(int(b["x"]) >> 16, int(b["y"]) >> 16)' in c7,'C7 bomb explosion path remains unchanged')
exp=man['retail_boss_explosion']
ck(exp['project_dez_defeat_explosion_z']>exp['project_terrain_high_z'],'C7 defeat explosion depth clears high-priority terrain')
ck(exp['scope']=='C7 defeat/ending random explosions only','Manifest records narrow explosion scope')

# Phase138 slam/layering behavior retained.
for tok,msg in [
 ('const SLAM_GROUP_DX16: Array[int] = [-32, -20, -8, -4, 0, 4, 12, 24, 24]','Phase138 retail slam torso X retained'),
 ('const SLAM_GROUP_DY16: Array[int] = [12, 20, 20, 12, 0, -24, -24, -12, -4]','Phase138 retail slam torso Y retained'),
 ('const SLAM_THIGH_DX16: Array[int] = [-8, -6, -2, 0, 0, 2, 4, 4, 6]','Phase138 retail thigh X retained'),
 ('const SLAM_THIGH_DY16: Array[int] = [4, 6, 4, 2, 0, -6, -4, -4, -2]','Phase138 retail thigh Y retained'),
 ('const SLAM_GROUP_FRAMES: int = 8','Phase138 eight-VBlank group timing retained'),
 ('s.z_as_relative = false\n\ts.z_index = z','Phase138 absolute C7 part layering retained'),
 ('s.z_as_relative = false\n\t\ts.z_index = original.z_index','Phase138 breakup layering retained'),
 ('target_sensor.z_index = 55','Phase138 target sensor depth retained'),
 ('target_lock.z_index = 54','Phase138 target lock depth retained'),
]: ck(tok in c7,msg)

# Frozen Phase134 runtime-confirmed files.
for rel,expected in man['frozen_phase134_sha256'].items():
    ck(sha_file(P/rel)==expected,f'Phase134 runtime-confirmed file frozen: {rel}')

# Baseline delta among Phase138 files is tightly scoped.
if BASE is not None and BASE.exists():
    with zipfile.ZipFile(BASE) as z:
        changed=[]
        for rel in z.namelist():
            if rel.endswith('/'): continue
            pp=P/rel
            if pp.exists() and sha_bytes(z.read(rel))!=sha_file(pp): changed.append(rel)
    ck(set(changed)=={'scripts/main.gd','scripts/objects/s2_dez_egg_robo.gd','scripts/objects/object_manager.gd'},'Phase139 modifies only main label, C7 runtime, and explosion helper among Phase138 files')

# Retail final source evidence.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    follow=asm[asm.index('ObjC7_Shoulder:'):asm.index('ObjC7_BackLowerLeg:')]
    shoulder=asm[asm.index('ObjC7_Shoulder:'):asm.index('ObjC7_FrontLowerLeg:')]
    head=asm[asm.index('ObjC7_Head:'):asm.index('ObjC7_Jet:')]
    jet=asm[asm.index('ObjC7_Jet:'):asm.index('ObjC7_BackLowerLeg:')]
    ck('bsr.w\tloc_3E282' in shoulder,'Retail shoulder calls loc_3E282 parent follower')
    ck('bsr.w\tloc_3E282' in head,'Retail head calls loc_3E282 parent follower')
    ck('bra.w\tloc_3E282' in jet,'Retail jet calls loc_3E282 parent follower')
    follower=asm[asm.index('loc_3E282:'):asm.index('ObjC7_PositionChildren:')]
    ck('move.w\tx_pos(a2),d0' in follower and 'move.w\ty_pos(a2),d0' in follower,'loc_3E282 rebuilds child position from parent X/Y')
    lower=asm[asm.index('ObjC7_FrontLowerLeg:'):asm.index('ObjC7_FrontForearm:')]
    ck('loc_3E282' not in lower,'Retail front lower leg has no parent-follow call')
    exp58=asm[asm.index('Obj58_Init:'):asm.index('Obj58_Main:')]
    ck('make_art_tile(ArtTile_ArtNem_FieryExplosion,0,1)' in exp58,'Retail Obj58 sets high-priority art bit')
    ck('move.b\t#0,priority(a0)' in exp58,'Retail Obj58 object priority is 0')
    bossload=asm[asm.index('Boss_LoadExplosion:'):asm.index('; ===========================================================================',asm.index('Boss_LoadExplosion:'))]
    ck('ObjID_BossExplosion' in bossload,'Retail Boss_LoadExplosion creates Obj58')

# Parser-oriented sanity for Godot 4.6.3 target.
for rel in ['scripts/main.gd','scripts/objects/s2_dez_egg_robo.gd','scripts/objects/object_manager.gd']:
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
