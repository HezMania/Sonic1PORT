#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, re, sys, zipfile
from PIL import Image
P=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
S2=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
BASE=Path(sys.argv[3]).resolve() if len(sys.argv)>3 else None
checks=[]
def ck(c,m): checks.append((bool(c),m)); print(('PASS' if c else 'FAIL')+': '+m)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha(data): return hashlib.sha256(data).hexdigest()
main=txt('scripts/main.gd'); om=txt('scripts/objects/object_manager.gd'); cam=txt('scripts/camera/sonic_camera.gd'); audio=txt('scripts/audio/sonic_audio.gd')
c6=txt('scripts/objects/s2_dez_eggman_runner.gd'); c7=txt('scripts/objects/s2_dez_egg_robo.gd'); mecha=txt('scripts/objects/s2_dez_mecha_sonic.gd'); bg=txt('scripts/render/ghz_background_renderer.gd')
manifest=json.loads((P/'data/s1/s2test/phase135_dez_final_manifest.json').read_text())

ck('Native Sonic 1 Phase 135' in main,'Debug overlay identifies Phase135')
ck((P/'PHASE135_SONIC2_DEATH_EGG_FINAL_BOSS.md').exists(),'Phase135 notes packaged')
ck(manifest.get('phase')==135,'Phase135 manifest version')
ck(manifest['objects']['C6_records']==[[0x440,0x168,0xC6,0xA6]],'Exact authored C6 record retained')
ck(manifest['objects']['C7_records']==[[0x840,0x19C,0xC7,0x02]],'Exact authored C7 record retained')
ck(manifest['frames']=={'c6_runner':8,'c6_door':4,'c7':23},'Retail C6/C7 mapping frame counts')
ck(manifest['egg_robo_art_tiles']==327,'Retail Eggrobo art decompresses to 327 tiles')
ck(manifest['music']['id']==0x1A1 and manifest['music']['tempo']==169,'End Boss port-local ID/tempo')
ck(manifest['music']['dac_ids']==[1,8,9,10],'End Boss exact DAC event set')

# Object routing / lifecycle bridge.
ck('S2DEZEggmanRunnerClass = preload' in om and 'S2DEZEggRoboClass = preload' in om,'C6/C7 classes preload in ObjectManager')
ck('bool(level_definition.get("s2_dez", false)) and id == 0xC6' in om,'C6 routed only in DEZ namespace')
ck('bool(level_definition.get("s2_dez", false)) and id == 0xC7' in om,'C7 routed only in DEZ namespace')
for flag in ['s2_dez_c6_departed','s2_dez_final_boss_active','s2_dez_ending_active']:
    ck(f'var {flag}: bool = false' in om and f'\t{flag} = false' in om,f'{flag} is defined and reset')
ck('if (fz_boss_act or s2_dez_act) and object_manager.final_ending_requested:' in main,'DEZ final fade enters existing ending controller')
ck('object_manager.s2_dez_final_boss_active' in main and 'sonic_camera.limit_left = 0x680' in main and 'sonic_camera.limit_right = 0x740' in main,'Main loop bridges C7 final arena lock')
ck('object_manager.boss_status >= 2' in main and 'object_manager.boss_limit_right' in main,'C7 defeat restores $1000 right camera path')
ck('limit_left = 0x680' in cam and 'limit_right = 0x740' in cam and 's2_dez_final_boss_ready = true' in cam,'LevEvents_DEZ final arena uses retail $680..$740 gate')

# C6 runner / door source constants.
for token,msg in [
 ('const DOOR_X: int = 0x3F8','C6 door X $3F8'),('const DOOR_Y: int = 0x160','C6 door Y $160'),
 ('< 0x5C','C6 wake distance $5C'),('timer = 0x18','C6 pre-run wait $18'),('vx = 0x200','C6 run speed $200'),
 ('wx >= 0x810','C6 departure X $810'),('vx = 0x80','C6 jump X speed $80'),('vy = -0x200','C6 jump Y speed -$200'),
 ('vy = GenesisMath.s16(vy + 0x10)','C6 fall gravity +$10'),('timer = 0x50','C6 jump lifetime $50'),
 ('resolve_solid_box_contact(DOOR_X, DOOR_Y, 0x13, 0x20','C6 door SolidObject dimensions $13/$20/$20')]: ck(token in c6,msg)
ck('door_timer >= 8' in c6 and 'mini(3, door_timer >> 1)' in c6,'C6 door animates 0→1→2→3 at retail cadence')
ck('manager.s2_dez_c6_departed = true' in c6,'C6 explicitly wakes final boss after departure')

# C7 final boss top-level source constants.
for token,msg in [
 ('const HITS: int = 0x0C','Death Egg Robot has 12 hits'),('const ATTACK_ORDER: Array[int] = [2, 0, 2, 4]','Exact C7 top-level attack selector'),
 ('timer = 0x3C','C7 prelude $3C'),('timer = 0x79','C7 rise timer $79'),('vy = -0x100','C7 rise speed -$100'),
 ('timer = 0x1F','C7 ready delay $1F'),('SonicAudio.MUS_S2_END_BOSS','C7 starts retail final boss music'),
 ('timer = 0x80','Stomp rise/tracking phase includes $80'),('target_timer = 0xE0','Target sensor preserves $A0+$40 total'),
 ('vy = 0x800','Stomp descent speed $800'),('timer = 0x20','C7 uses $20 attack/stomp windows'),
 ('[0x60, -0x800], [0xC0, -0xA00]','Retail bomb velocity pairs'),('b["vy"] = GenesisMath.s16(int(b["vy"]) + 0x38)','C7 bomb gravity +$38'),
 ('hit_flash = 0x3C','C7 hit flash $3C'),('manager.add_score(100)','C7 defeat adds 100 points'),
 ('y_fixed = FLOOR_Y << 16','Defeated body settles at Y $15C'),('timer = 0x40','Defeat wait includes $40'),
 ('manager.boss_limit_right = 0x1000','C7 defeat opens Max-X to $1000'),('manager.current_screen_x < 0x840','Ending setup waits for Camera X $840'),
 ('p.pixel_x() < 0xEC0','Ending chase waits for Sonic X $EC0'),('timer = 0x16','White fade lasts $16 frames'),
 ('manager.request_final_ending()','White fade hands off to ending controller')]: ck(token in c7,msg)
ck('BREAK_SPEEDS' in c7 and all(x in c7 for x in ['[0x200, -0x400]','[-0x100, -0x100]','[0x300, -0x300]','[-0x100, -0x400]','[0x180, -0x200]','[-0x200, -0x300]','[0, -0x400]','[0x100, -0x300]']),'Exact eight C7 break-apart velocity pairs')
ck('body_hit' in c7 and 'head_hit' in c7 and '_hazard_centers()' in c7,'C7 separates attackable body/head from hazardous linked pieces')
ck('manager.s2_dez_final_boss_active = true' in c7 and 'manager.s2_dez_final_boss_active = false' in c7,'C7 owns final arena lock lifecycle')

# Assets. Frame 21 is intentionally transparent: retail head startup mapping is tile 4 blank.
for folder,count in [('eggman_runner',8),('eggman_door',4),('egg_robo',23)]:
    fs=sorted((P/'assets/objects/s2_dez'/folder).glob('*.png')); ck(len(fs)==count,f'{folder} contains {count} rendered frames')
    for f in fs:
        a=Image.open(f).convert('RGBA').getchannel('A')
        intended_blank=(folder=='egg_robo' and f.stem=='21')
        ck(bool(a.getbbox()) or intended_blank,f'{folder}/{f.name} is visible or source-intentional blank')
ck(bool(Image.open(P/'assets/objects/s2_dez/eggman_runner/00.png').convert('RGBA').getchannel('A').getbbox()),'Robotnik runner frame 0 contains reconstructed PLC art')
ck(bool(Image.open(P/'assets/objects/s2_dez/eggman_runner/04.png').convert('RGBA').getchannel('A').getbbox()),'Robotnik running frame 4 contains reconstructed PLC art')

# Audio wiring and user-provided PCM set.
ck('const MUS_S2_END_BOSS := 0x1A1' in audio,'Audio exposes final boss music ID $1A1')
ck('9: _load_pcm16("res://data/s1/sound/s2_ehz_dac_09.pcm")' in audio,'Final boss DAC event 9 is loaded')
db=json.loads((P/'data/s1/sound/s2_ehz_smps.json').read_text())['music']['417']
ck(db['source']['used_dac_ids']==[1,8,9,10],'Packaged final boss SMPS graph reports exact DAC IDs')
ck(db['header']['tempo_mod']==169 and db['header']['driver_mode']=='s2','Final boss SMPS uses retail S2 tempo/driver')
for sid in [0x28,0x37,0x39,0x3D,0x44,0x61]:
    ck((P/f'assets/audio/sfx_pcm/S2_{sid:02X}.wav').exists(),f'User S2 PCM ${sid:02X} packaged')
ck((P/'data/s1/sound/s2_ehz_dac_09.pcm').stat().st_size>0,'Reconstructed final boss DAC event 9 is nonempty')

# Phase134 runtime-confirmed freeze boundary.
if BASE is not None and BASE.exists():
    with zipfile.ZipFile(BASE) as z:
        for rel in ['scripts/objects/s2_dez_mecha_sonic.gd','scripts/render/ghz_background_renderer.gd','data/s1/s2test/dez1_objects.bin']:
            ck(sha(z.read(rel))==sha((P/rel).read_bytes()),f'Phase134 frozen baseline unchanged: {rel}')

# Retail source evidence.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    c6src=asm[asm.index('ObjC6_State2_State1:'):asm.index('ObjC6_SubObjData3:')]
    ck(all(t in c6src for t in ['#$3F8','#$160','#$18','#$200','#$810','#$80','#-$200','#$50']),'Retail C6 constants found in source')
    ck('move.w\t#$13,d1' in c6src and 'move.w\t#$20,d2' in c6src and 'move.w\t#$20,d3' in c6src,'Retail C6 door SolidObject dimensions found')
    c7start=asm[asm.index('ObjC7_Body:'):asm.index('ObjC7_Shoulder:')]
    ck('move.b\t#$C,collision_property(a0)' in c7start,'Retail C7 12-hit health found')
    ck(re.search(r'byte_3D680:\s*\n\s*dc\.b\s+2\s*\n\s*dc\.b\s+0.*\n\s*dc\.b\s+2.*\n\s*dc\.b\s+4',c7start,re.S) is not None,'Retail C7 attack order 2,0,2,4 found')
    ending=asm[asm.index('loc_3D8E6:'):asm.index('ObjC7_Shoulder:')]
    ck('#$15C' in ending and '#$840' in ending and '#$EC0' in ending and '#$16' in ending,'Retail C7 defeat/ending gates $15C/$840/$EC0/$16 found')
    ck('GameModeID_EndingSequence' in ending,'Retail C7 ends in EndingSequence mode')
    constants=(S2/'s2.constants.asm').read_text(errors='replace')
    ck('ArtTile_ArtNem_RobotnikUpper          = $0500' in constants and 'ArtTile_ArtNem_RobotnikRunning        = $0518' in constants and 'ArtTile_ArtNem_RobotnikLower          = $0564' in constants,'Retail Robotnik PLC VRAM bases $500/$518/$564 found')

# Parser-oriented structural sanity.
for rel in ['scripts/main.gd','scripts/camera/sonic_camera.gd','scripts/audio/sonic_audio.gd','scripts/objects/object_manager.gd','scripts/objects/s2_dez_eggman_runner.gd','scripts/objects/s2_dez_egg_robo.gd','scripts/objects/s2_dez_mecha_sonic.gd','scripts/render/ghz_background_renderer.gd']:
    body=txt(rel)
    ck(not any(x in body for x in ['<<<<<<<','=======','>>>>>>>']),f'{rel} has no conflict markers')
    ck(body.count('(')==body.count(')'),f'{rel} parentheses balance')
    ck(body.count('[')==body.count(']'),f'{rel} brackets balance')
    ck(body.count('{')==body.count('}'),f'{rel} braces balance')
# New scripts deliberately avoid inferred local declarations to reduce 4.6.3 parser risk.
ck(':=' not in c6,'C6 new script avoids inferred declarations')
ck(':=' not in c7,'C7 new script avoids inferred declarations')

passed=sum(ok for ok,_ in checks)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' -',msg)
    raise SystemExit(1)
