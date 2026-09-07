#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, sys, zipfile

P=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
S2=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
PHASE136=Path(sys.argv[3]).resolve() if len(sys.argv)>3 else None
PHASE134=Path(sys.argv[4]).resolve() if len(sys.argv)>4 else None
checks=[]
def ck(c,m):
    checks.append((bool(c),m)); print(('PASS' if c else 'FAIL')+': '+m)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha_bytes(b): return hashlib.sha256(b).hexdigest()
def sha_file(p): return sha_bytes(Path(p).read_bytes())

main=txt('scripts/main.gd')
c7=txt('scripts/objects/s2_dez_egg_robo.gd')
man=json.loads((P/'data/s1/s2test/phase137_dez_robot_animation_manifest.json').read_text())

ck('Native Sonic 1 Phase 137' in main,'Debug overlay identifies Phase137')
ck((P/'PHASE137_SONIC2_DEATH_EGG_ROBOT_ANIMATION.md').exists(),'Phase137 notes packaged')
ck(man.get('phase')==137,'Phase137 manifest version')
ck(man.get('baseline')=='Sonic1PC_S2DeathEggFinalBossCorrections_Phase136.zip','Phase137 records Phase136 baseline')

# Head timing: exact retail open hold -> close -> post-close wait.
ck('head_post_close_timer: int = 0' in c7,'C7 has separate post-close timer')
ck('head_intro_timer < 88' in c7,'C7 head animation spans 88 VBlanks')
ck('head_intro_timer <= 64' in c7 and '_set_part_frame(head, 0x15)' in c7,'C7 holds open frame $15 for first 64 VBlanks')
ck('head_intro_timer <= 72' in c7 and '_set_part_frame(head, 0)' in c7,'C7 close stage uses frame 0')
ck('head_intro_timer <= 80' in c7 and '_set_part_frame(head, 1)' in c7,'C7 close stage uses frame 1')
ck('_set_part_frame(head, 2)' in c7,'C7 close stage ends on frame 2')
ck('head_post_close_timer = 0x40' in c7 and 'head_post_close_timer -= 1' in c7,'C7 waits separate $40 after head closes')
ck(man['egg_robo']['head_open_hold_frames']==64 and man['egg_robo']['head_close_frames']==24 and man['egg_robo']['head_post_close_wait']==64,'Manifest records retail head timing')

# Target sensor uses delayed velocity history, not forward lead.
for tok,msg in [
    ('target_vx_history: Array[int] = [0, 0, 0, 0]','C7 has four-stage X velocity history'),
    ('target_vy_history: Array[int] = [0, 0, 0, 0]','C7 has four-stage Y velocity history'),
    ('var delayed_vx: int = int(target_vx_history[3])','Targeting uses oldest delayed X velocity'),
    ('var delayed_vy: int = int(target_vy_history[3])','Targeting uses oldest delayed Y velocity'),
    ('for i in range(3, 0, -1):','Targeting shifts velocity history newest→oldest'),
    ('target_sensor.global_position.x += float(GenesisMath.s16(delayed_vx)) / 256.0','Target X moves by delayed 8.8 velocity'),
    ('target_sensor.global_position.y += float(GenesisMath.s16(delayed_vy)) / 256.0','Target Y moves by delayed 8.8 velocity'),
]: ck(tok in c7,msg)
ck('p.pixel_x() + lead_x' not in c7 and 'p.pixel_y() + lead_y' not in c7,'Phase136 forward-lead targeting removed')
ck(man['egg_robo']['target_velocity_history_words']==['objoff_30','objoff_34','objoff_38','objoff_3C'],'Manifest records retail targeting history fields')

# Walking animation: exact linked-piece local-delta bridge.
ck('_apply_walk_group_limb_deltas(group, walk_recovery and walk_sequence_index < 4)' in c7,'Walk invokes linked-piece group animation every source tick')
ck('float(pdx - bdx) / 16.0' in c7 and 'float(pdy - bdy) / 16.0' in c7,'Genesis child world deltas are converted to Node2D-local deltas')
for name in ['front_lower_walk_offset','front_forearm_walk_offset','arm_walk_offset','front_thigh_walk_offset','back_lower_walk_offset','back_forearm_walk_offset','back_thigh_walk_offset']:
    ck((name+': Vector2 = Vector2.ZERO') in c7,f'Walk has independent linked offset: {name}')
# Selected exact entries from ObjC7_GroupAni_3E438 across early/middle/late frames.
for tok,msg in [
    ('ft = Vector2i(-8, -8)','Group 0 front-thigh delta matches retail'),
    ('bf = Vector2i(-20, -5)','Group 1 back-forearm delta matches retail'),
    ('bl = Vector2i(-24, -4)','Group 4/9 lower-leg delta matches retail'),
    ('aa = Vector2i(-19, -5)','Group 6 arm delta matches retail'),
    ('ff = Vector2i(8, 10)','Group 8 front-forearm delta matches retail'),
    ('ft = Vector2i(0, 8)','Group 11 front-thigh delta matches retail'),
]: ck(tok in c7,msg)
ck(man['egg_robo']['walk_linked_animation']=='ObjC7_GroupAni_3E438 exact per-child deltas','Manifest records exact linked walk animation')

# Two independent forearms/hands.
for tok,msg in [
    ('var front_hand_state: int = 0','Front forearm owns independent state'),
    ('var back_hand_state: int = 0','Back forearm owns independent state'),
    ('_trigger_front_hand()','Attack 4 triggers front hand'),
    ('_trigger_back_hand()','Attack 4 triggers back hand'),
    ('timer = 0x40\n\t\t\t\t_trigger_back_hand()','Back hand trigger follows $40 parent delay'),
    ('front_hand_timer = 0x10','Front hand starts retail $10 drop'),
    ('back_hand_timer = 0x10','Back hand starts retail $10 drop'),
    ('htimer = 0x20','Forearm launch/reverse stages use $20 timers'),
    ('hvy = GenesisMath.s16(hvy + 0x20)','Forearm drop uses +$20 Y acceleration'),
    ('hvx = -0x800 if facing_left else 0x800','Forearm launch uses retail $800 X speed'),
    ('hvx = GenesisMath.s16(-hvx)','Forearm reverses X velocity'),
    ('back_forearm.position = Vector2(bdx - sx * 12, bdy + 8) + back_forearm_walk_offset + back_forearm_offset','Rear hand has its own rendered offset'),
]: ck(tok in c7,msg)
ck(man['egg_robo']['back_forearm_trigger_delay']==64 and man['egg_robo']['forearm_motion_frames']==[16,32,32,32],'Manifest records independent forearm timing')

# Frozen runtime-confirmed Phase134 content.
if PHASE134 is not None and PHASE134.exists():
    with zipfile.ZipFile(PHASE134) as z:
        for rel in ['scripts/objects/s2_dez_mecha_sonic.gd','scripts/render/ghz_background_renderer.gd','data/s1/s2test/dez1_objects.bin']:
            ck(sha_bytes(z.read(rel))==sha_file(P/rel),f'Phase134 runtime-confirmed file frozen: {rel}')

# Phase136 delta is intentionally tiny.
if PHASE136 is not None and PHASE136.exists():
    allowed={'scripts/main.gd','scripts/objects/s2_dez_egg_robo.gd'}
    with zipfile.ZipFile(PHASE136) as z:
        changed=[]
        for rel in z.namelist():
            if rel.endswith('/'): continue
            pp=P/rel
            if pp.exists() and sha_bytes(z.read(rel))!=sha_file(pp): changed.append(rel)
    ck(set(changed)==allowed,'Phase137 modifies only main label and C7 runtime among Phase136 files')

# Retail source evidence.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    head=asm[asm.index('ObjC7_Head:'):asm.index('ObjC7_Jet:')]
    ck('btst\t#3,$22(a1)' in head and 'move.w\t#$40,objoff_2A(a0)' in head,'Retail head waits on C6 status bit 3 and stores $40 timer')
    ani=asm[asm.index('Ani_objC7_a:'):asm.index('Ani_objC7_b:')]
    ck('dc.b   7,$15,$15,$15,$15,$15,$15,$15,$15,  0,  1,  2,$FA' in ani,'Retail head animation is eight $15 entries then 0,1,2')
    target=asm[asm.index('ObjC7_TargettingSensor:'):asm.index('ObjC7_TargettingLock:')]
    ck('move.w\t-(a1),y_vel(a0)' in target and 'move.w\t-(a1),x_vel(a0)' in target,'Retail target loads oldest velocity history into sensor speed')
    ck('moveq\t#2,d6' in target and 'move.l\t-(a1),-(a2)' in target,'Retail target shifts three longwords of velocity history')
    ck('move.w\tx_vel(a2),d0' in target and 'move.w\td0,(a1)+' in target,'Retail target stores current player X velocity into newest history slot')
    arm=asm[asm.index('loc_3D856:'):asm.index('loc_3D8D2:')]
    ck('bset\t#4,status(a0)' in arm and 'bset\t#5,status(a0)' in arm,'Retail parent triggers both forearm children with status bits 4 and 5')
    front=asm[asm.index('ObjC7_FrontForearm:'):asm.index('ObjC7_Arm:')]
    back=asm[asm.index('ObjC7_BackForearm:'):asm.index('ObjC7_BackThigh:')]
    ck('#$10,objoff_2A(a0)' in front and '#$800,d2' in front and 'neg.w\tx_vel(a0)' in front,'Retail front forearm uses $10 drop/$800 launch/reverse')
    ck('bclr\t#5,status(a1)' in back and 'loc_3DACC' in back and 'loc_3DB32' in back,'Retail back forearm reuses the same launch/reverse states')
    group=asm[asm.index('ObjC7_GroupAni_3E438:'):asm.index('ChildObjC7_Shoulder:')]
    for evidence,msg in [
        ('c7ani objoff_34, $F8, $F8','Retail group 0 front-thigh delta found'),
        ('c7ani objoff_3C, $EC, $FB','Retail group 1 rear-forearm delta found'),
        ('c7ani objoff_3A, $E8, $FC','Retail group 4 back-lower delta found'),
        ('c7ani objoff_32, $ED, $FB','Retail group 6 arm delta found'),
        ('c7ani objoff_30, $08, $0A','Retail group 8 front-forearm delta found'),
    ]: ck(evidence in group,msg)

# Parser-oriented sanity for Godot 4.6.3 target.
for rel in ['scripts/main.gd','scripts/objects/s2_dez_egg_robo.gd']:
    body=txt(rel)
    ck(not any(x in body for x in ['<<<<<<<','=======','>>>>>>>']),f'{rel} has no conflict markers')
    ck(body.count('(')==body.count(')'),f'{rel} parentheses balance')
    ck(body.count('[')==body.count(']'),f'{rel} brackets balance')
    ck(body.count('{')==body.count('}'),f'{rel} braces balance')
ck(':=' not in c7,'C7 hotfix keeps explicit declarations for Godot 4.6.3')

passed=sum(ok for ok,_ in checks)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' -',msg)
    raise SystemExit(1)
