#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,py_compile,sys,zipfile
P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
 ok=bool(v);checks.append((ok,msg));print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(r): return (P/r).read_text(errors='replace')
def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
mtz=txt('scripts/objects/s2_mtz_object.gd'); boss=txt('scripts/objects/s2_mtz_boss_object.gd'); main=txt('scripts/main.gd'); om=txt('scripts/objects/object_manager.gd'); cat=txt('scripts/data/level_catalog.gd'); cam=txt('scripts/camera/sonic_camera.gd'); prison=txt('scripts/objects/s2_egg_prison_object.gd')
# Phase124 imported MTZ3 data remains retail exact.
manifest=json.loads((P/'data/s1/s2test/phase124_mtz3_manifest.json').read_text())
for name,h in manifest['sha256'].items():
 q=P/'data/s1/s2test'/name; ck(q.exists() and sha(q.read_bytes())==h,f'Phase124 MTZ3 imported data unchanged: {name}')
if S2:
 ck((P/'data/s1/s2test/mtz3_objects.bin').read_bytes()==(S2/'level/objects/MTZ_3.bin').read_bytes(),'MTZ3 object stream remains byte-for-byte retail')
 ck((P/'data/s1/s2test/mtz3_rings.bin').read_bytes()==(S2/'level/rings/MTZ_3.bin').read_bytes(),'MTZ3 ring stream remains byte-for-byte retail')
 src=(S2/'s2.asm').read_text(errors='replace')
 for q in ['move.w\t#$2B50,x_pos(a0)','move.w\t#$380,y_pos(a0)','move.b\t#8,boss_hitcount2(a0)','move.w\t#$EF,(Boss_Countdown).w','cmpi.w\t#$2BF0,(Camera_Max_X_pos).w']:
  ck(q in src,f'Retail Obj54 source contains {q}')
# Carry-forward MTZ fixes.
ck('func _gear_entry(step: int, child: int)' in mtz,'Obj70 uses physical-tooth frame identity')
ck('gear_step + (-1 if x_flip else 1)' in mtz,'Obj70 counter-clockwise direction advances the 32-frame circle backwards')
ck('child*4 + step' in mtz and '(mf >> 2) & 7' in mtz,'Obj70 maps frame phase back to the same physical tooth')
ck('gear_rider_tooth' in mtz and 'move_with_supported_object' in mtz,'Obj70 rider carry remains tooth-locked')
ck('tube_reverse = signed_sub < 0' in mtz,'Obj67 honors signed reverse subtypes')
ck('func _tube_wrapped_point' in mtz and '0x800' in mtz,'Obj67 chooses the nearest MTZ vertical-wrap image per node')
ck('tube_current_target.y += delta_y' in mtz,'Obj67 active target follows vertical screen wrap')
ck('p.standing_on_object and p.support_record_index==record_index: near=true' in mtz,'Obj65 mode 3 reacts to authoritative player support')
ck('current_act != 3' in mtz and 'int(position.x)==0x1CC0 or int(position.x)==0x2940' in mtz,'Obj65 mode 5 uses retail Act3 +2px terminal destinations')
# Boss integration.
ck('class_name S2MTZBossObject' in boss,'Object $54 native boss class exists')
for q in ['const BOSS_START := Vector2i(0x2B50,0x380)','var hits := 8','const CAMERA_END := 0x2BF0','defeat_timer=0xEF','vel_x=0x400; vel_y=-0x40','ORB_ANGLES: Array[int] = [0x24,0x6C,0xB4,0xFC,0x48,0x90,0xD8]']:
 ck(q in boss,f'Object $54 retail constant/behavior present: {q}')
ck('lasers_remaining = 3' in boss and '_spawn_laser()' in boss and '0x400 if not side_flag else -0x400' in boss,'Object $54 final attack emits three ±$400 lasers')
ck('invulnerable_timer=0x40' in boss,'Object $54 uses retail $40 hit invulnerability')
ck('manager.unlock_s2_mtz_boss_right_boundary()' in boss,'Object $54 escape requests retail camera release')
ck('S2MTZBossObjectClass = preload' in om and 'func spawn_s2_mtz_boss() -> bool:' in om,'Object manager can spawn Object $54')
ck('boss_limit_right = 0x2AB0' in om and 'mini(0x2BF0, boss_limit_right + 2)' in om,'Object manager owns $2AB0->$2BF0 MTZ boss camera range')
ck('"s2_mtz_boss": act == 3' in cat,'MTZ3 enables Object $54 boss runtime')
ck('"s2_egg_prison_requires_boss": act == 3' in cat,'MTZ3 Egg Prison remains boss-gated')
ck('art_folder = "s2_mtz/egg_prison"' in prison,'MTZ3 Egg Prison uses MTZ-rendered source art')
ck('func _tick_s2_mtz3_boss_start' in main and '0x5A' in main[main.index('func _tick_s2_mtz3_boss_start'):main.index('func _tick_level_art')],'Main loop preserves exact $5A Object $54 allocation gate')
ck('SonicAudio.MUS_S2_BOSS' in main[main.index('func _tick_s2_mtz3_boss_start'):main.index('func _tick_level_art')],'Main loop starts Sonic 2 boss music after Object $54 allocation')
ck('s2_mtz3_boss_act and sonic_camera.dle_routine >= 6' in main and 'object_manager.boss_screen_lock' in main,'MTZ3 player bounds follow boss lock/release state')
ck('Routine5 follows Camera_X after Object $54 is spawned' in cam,'Camera documents retail post-spawn Routine5 handoff')
# Boss and capsule source-rendered art.
parts=sorted((P/'assets/objects/s2_mtz/boss/parts').glob('*.png')); eggs=sorted((P/'assets/objects/s2_mtz/egg_prison').glob('*.png'))
ck(len(parts)==0x15 and all(q.stat().st_size>100 for q in parts),'All 21 Object $54 mapping frames rendered')
ck(len(eggs)==6 and all(q.stat().st_size>100 for q in eggs),'All six MTZ Egg Prison frames rendered')
bm=json.loads((P/'data/s1/s2test/phase125_mtz_boss_manifest.json').read_text())
ck(bm['boss']=='Object $54' and bm['hits']==8 and bm['egg_prison']==[0x2C90,0x4A0],'Phase125 boss-art manifest matches retail placement/hits')
# Static structure / Python compilation.
for rel in ['scripts/objects/s2_mtz_object.gd','scripts/objects/s2_mtz_boss_object.gd','scripts/objects/object_manager.gd','scripts/main.gd','scripts/camera/sonic_camera.gd','scripts/data/level_catalog.gd']:
 t=txt(rel)
 ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge conflict markers')
 ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
 ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
 ck(t.count('{')==t.count('}'),f'{rel} braces balance')
for rel in ['tools/import_s2_mtz_boss_phase125.py','tools/validate_phase125.py']:
 try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
 except Exception as e: ck(False,f'{rel} compiles: {e}')
ck('Native Sonic 1 Phase 125' in main,'Debug overlay identifies Phase125')
ck((P/'PHASE125_SONIC2_METROPOLIS_BOSS_END.md').exists(),'Phase125 notes exist')
bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
 print('Failures:'); [print(' - '+m) for m in bad]; raise SystemExit(1)
