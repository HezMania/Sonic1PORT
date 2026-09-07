#!/usr/bin/env python3
from __future__ import annotations
import hashlib, importlib.util, json, py_compile, struct, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(c,m):
    checks.append((bool(c),m)); print(('PASS: ' if c else 'FAIL: ')+m)
def sha(p:Path): return hashlib.sha256(p.read_bytes()).hexdigest()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod

def fn(text:str,name:str,next_name:str|None=None)->str:
    a=text.index('func '+name)
    if next_name is not None:
        b=text.index('func '+next_name,a+1)
    else:
        b=text.find('\nfunc ',a+1); b=len(text) if b<0 else b
    return text[a:b]

manifest=json.loads((P/'data/s1/s2test/phase113_mcz2_manifest.json').read_text())
cat=(P/'scripts/data/level_catalog.gd').read_text()
cam=(P/'scripts/camera/sonic_camera.gd').read_text()
mcz=(P/'scripts/objects/s2_mcz_object.gd').read_text()
player=(P/'scripts/player/sonic_player.gd').read_text()
visual=(P/'scripts/player/sonic_visual.gd').read_text()
cpz=(P/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
om=(P/'scripts/objects/object_manager.gd').read_text()
sign=(P/'scripts/objects/s2_signpost_adapter.gd').read_text()
egg=(P/'scripts/objects/s2_egg_prison_object.gd').read_text()

# Retail Act 2 dataset / level definition.
ck(manifest['phase']==113 and manifest['level']=='Mystic Cave Zone Act 2','Phase 113 MCZ2 manifest identity')
ck(manifest['start']==[0x60,0x5AC],'MCZ2 exact retail start $0060,$05AC')
ck(manifest['limits']=={'left':0,'right':0x3FFF,'top':0x60,'bottom':0x720},'MCZ2 exact LevelSize bounds')
ck(manifest['object_records']==148,'MCZ2 exact 148 retail placement records')
expected={'0D':1,'15':2,'1F':16,'26':13,'2A':5,'36':21,'3E':1,'40':9,'41':12,'6A':3,'75':11,'76':3,'77':2,'79':4,'7A':3,'7F':7,'80':8,'81':7,'9E':6,'A3':14}
ck(manifest['object_counts_hex']==expected,'MCZ2 full retail object-ID distribution')
ck(manifest['native_routed_records']==148 and manifest['active_traversal_records']==146,'All MCZ2 records route natively; Act2 signpost and boss-gated capsule stay inactive')
for suffix in ['art','map16','map128','collision_primary','collision_secondary']:
    ck((P/f'data/s1/s2test/mcz2_{suffix}.bin').read_bytes()==(P/f'data/s1/s2test/mcz1_{suffix}.bin').read_bytes(),f'MCZ2 shares exact retail MCZ {suffix} data with Act 1')

for token,msg in [
 ('var act: int = clampi(requested_act, 1, 2)','MCZ catalog accepts Acts 1 and 2'),
 ('var prefix: String = "mcz%d" % act','MCZ catalog selects act-specific imported streams'),
 ('"limit_right": 0x3FFF if act == 2 else 0x2380','MCZ2 right bound $3FFF'),
 ('"limit_top": 0x0060 if act == 2 else 0x03C0','MCZ2 top bound $0060'),
 ('"dynamic_events": "s2_mcz2" if act == 2 else "none"','MCZ2 selects dedicated LevEvents path'),
 ('"s2_egg_prison_requires_boss": act == 2','MCZ2 Egg Prison remains boss-gated'),
 ('return Vector2i(ZONE_S2_MCZ_TEST, 2) if act < 2 else Vector2i(ZONE_GHZ, 1)','MCZ1 normal progression now enters MCZ2'),
]: ck(token in cat,msg)

# Phase 113 MCZ2 pre-boss DLE mirrors routines 0/2 and the arena geometry.
for token,msg in [
 ('"s2_mcz2": _dle_s2_mcz2()','Camera dispatches MCZ2 DLE'),
 ('screen_x >= 0x2080','MCZ2 first event threshold $2080'),
 ('target_bottom = 0x5D0','MCZ2 source max-Y target $5D0'),
 ('screen_x >= 0x20F0','MCZ2 arena threshold $20F0'),
 ('limit_left = 0x20F0','MCZ2 left arena lock $20F0'),
 ('limit_right = 0x20F0','MCZ2 right arena lock $20F0'),
 ('screen_y >= 0x5C8','MCZ2 source top-lock threshold $5C8'),
 ('limit_top = 0x5C8','MCZ2 source top lock $5C8'),
]: ck(token in cam,msg)

# MCZ1 carry-forward fixes.
spike=fn(mcz,'_tick_sliding_spikes() -> void','_init_gate() -> void')
ck('var old_x: int = int(position.x)' in spike and 'new_x-old_x' in spike,'Obj76 saves old X and carries a stood-on Sonic with its slide')
ck('move_with_supported_object(record_index,new_x-old_x,0' in spike,'Obj76 standing carry uses native moving-solid support path')
collapse=fn(mcz,'_tick_collapse() -> void','_init_stomper() -> void')
ck('collapse_fragment_delay[0] > 0' in collapse and 'resolve_platform_top' in collapse,'Obj1F retains top support while first fragment delay is active')
ck('collapse_fragment_delay[i] == 0' in collapse and 'clear_object_support_for(record_index, true)' in collapse,'Obj1F releases Sonic only when the top fragment delay reaches zero')
ck('collapse_finished = true' in collapse and 'request_delete' not in collapse,'Obj1F keeps an inert tombstone instead of immediate nearby respawn')
ck('collapse_fragment_delay: Array[int] = [0x1A,0x16,0x12,0x0E,0x0A,0x02]' in mcz,'Obj1F retains exact MCZ six-fragment delay table')

crawl=fn(mcz,'_tick_crawlton() -> void','_init_flasher() -> void')
ck('CRAWLTON_SEGMENT_THRESHOLDS: Array[int] = [0x18,0x14,0x10,0x0C,0x08,0x04,0x00]' in mcz,'Crawlton seven segment thresholds match retail child routine')
ck('crawl_tail_world' in crawl and 'crawl_history' not in mcz,'Crawlton body uses anchored absolute segment positions, not trailing head history')
ck('timer-=1' in crawl and 'if timer<=0' in crawl and 'moved_this_frame=true' in crawl,'Crawlton decrements $1C countdown before source-style ObjectMove')
ck('if timer < CRAWLTON_SEGMENT_THRESHOLDS[i]' in crawl,'Crawlton moves only the segments whose source threshold has elapsed')

# Vine/pull-switch Hang2 presentation. The two PNG SHA-256s are the exact user uploads.
ck('var mcz_vine_hang := false' in player and 'mcz_vine_hang = false' in player,'Sonic owns/reset a dedicated MCZ vine-hang visual state')
ck(mcz.count('p.mcz_vine_hang=true')==2 and 'p.mcz_vine_hang = false' in mcz,'Obj7F and Obj80 enter Hang2 state and release clears it')
ck('const FINAL_HANG2: Array[int] = [0x6B, 0x6C]' in visual,'Retail final animation profile uses SonAni_Hang2 frames $6B/$6C')
ck('_update_source_loop(player, FINAL_HANG2, 0x13' in visual,'Retail SonAni_Hang2 delay $13 is preserved')
ck('_update_s1_mcz_vine_hang(player, mode_changed)' in visual and '_tick_animation(2, 0x13)' in visual,'S1 profile uses supplied two-frame Hang2-compatible animation at source timing')
v0=P/'assets/sonic/s2_exclusive_s1_compat/vine_hang/00.png'; v1=P/'assets/sonic/s2_exclusive_s1_compat/vine_hang/01.png'
ck(sha(v0)=='f9dfddbe563f7e309c197016a99c947d760ab565edd85cc16a0358e2a9c2508a','Supplied vine frame 0 packaged byte-for-byte')
ck(sha(v1)=='2a04f596e52ac514813b46928c821f17e9cc5c8244b23e717e7dbc0129ef3734','Supplied vine frame 1 packaged byte-for-byte')
for f,n in [(v0,0),(v1,1)]:
    b=f.read_bytes(); wh=struct.unpack('>II',b[16:24]) if b[:8]==b'\x89PNG\r\n\x1a\n' else (0,0)
    ck(wh==(64,64),f'Supplied vine frame {n} retains 64x64 source canvas')

# New Act2 Obj15 modes and Obj40 zone-palette art.
ck('source_angle: int = manager.s2_source_osc_byte(0x18)' in mcz,'MCZ2 Obj15 ordinary swings use retail Oscillating_Data+$18 source')
ck('mode == 0x10 and source_angle < 0x40' in mcz,'Obj15 subtype $1x applies source lower clamp at $40')
ck('mode == 0x30 and source_angle > 0x40' in mcz,'Obj15 subtype $3x applies source upper clamp at $40')
ck('mode == 0x40 and absi' in mcz,'Only special subtype-$4x Obj15 uses spike-edge hazard response')
ck((P/'assets/objects/s2_mcz/lever_spring/00.png').is_file() and (P/'assets/objects/s2_mcz/lever_spring/01.png').is_file(),'MCZ-palette Obj40 lever-spring frames packaged')
ck('var root: String = "s2_mcz" if manager != null and bool(manager.level_definition.get("s2_mcz", false)) else "s2_cpz"' in cpz,'Shared Obj40 selects MCZ precomposited art in Mystic Cave')

# Namespace routing and source guards.
ck('bool(level_definition.get("s2_mcz", false)) and id in [0x15,0x1F,0x2A,0x6A,0x75,0x76,0x77,0x7A,0x7F,0x80,0x81,0x9E,0xA3]' in om,'All MCZ-specific Act2 IDs route before ARZ/CPZ aliases')
ck('0x0D: return S2SignpostAdapterClass.new()' in om and '0x26: return S2MonitorAdapterClass.new()' in om and '0x36: return S2SpikesObjectClass.new()' in om and '0x40, 0x6B' in om and '0x41: return S2SpringObjectClass.new()' in om and '0x3E: return S2EggPrisonObjectClass.new()' in om and '0x79: return LamppostObject.new()' in om,'MCZ2 shared IDs use existing retail S2 adapters')
ck('if int(owner.level_definition.get("act", 1)) != 1:' in sign,'Retail single-player Act2 signpost placement self-disables')
ck('requires_boss_defeat' in egg and 'manager.boss_status < 1' in egg,'Placed MCZ2 Egg Prison remains inert until boss defeat')

if S2 is not None:
    terrain=load('terrainvalidate113',P/'tools'/'import_sonic2_level.py')
    layout=terrain.kosinski_decompress((S2/'level/layout/MCZ_2.bin').read_bytes())
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        o=row*0x100; fg+=layout[o:o+0x80]; bg+=layout[o+0x80:o+0x100]
    ck((P/'data/s1/s2test/mcz2_layout128.bin').read_bytes()==bytes((127,15))+bytes(fg),'MCZ2 foreground layout is exact retail Kosinski decode/split')
    ck((P/'data/s1/s2test/mcz2_bg128.bin').read_bytes()==bytes((127,15))+bytes(bg),'MCZ2 Plane-B layout is exact retail Kosinski decode/split')
    ck((P/'data/s1/s2test/mcz2_objects.bin').read_bytes()==(S2/'level/objects/MCZ_2.bin').read_bytes(),'MCZ2 object stream byte-identical to retail')
    ck((P/'data/s1/s2test/mcz2_rings.bin').read_bytes()==(S2/'level/rings/MCZ_2.bin').read_bytes(),'MCZ2 ring stream byte-identical to retail')
    ck((P/'data/s1/s2test/mcz2_start.bin').read_bytes()==(S2/'startpos/MCZ_2.bin').read_bytes(),'MCZ2 start stream byte-identical to retail')
    asm=(S2/'s2.asm').read_text(errors='replace')
    for needle,msg in [
      ('zoneTableEntry.w\t$0,\t$3FFF,\t$60,\t$720\t; MCZ act 2','Retail LevelSize confirms MCZ2 $0000..$3FFF/$0060..$0720'),
      ('cmpi.w\t#$2080,(Camera_X_pos).w','Retail LevEvents_MCZ2 first threshold $2080 confirmed'),
      ('move.w\t#$5D0,(Camera_Max_Y_pos).w','Retail LevEvents_MCZ2 max-Y $5D0 confirmed'),
      ('cmpi.w\t#$20F0,(Camera_X_pos).w','Retail LevEvents_MCZ2 arena threshold $20F0 confirmed'),
      ('cmpi.w\t#$5C8,(Camera_Y_pos).w','Retail LevEvents_MCZ2 top-lock threshold $5C8 confirmed'),
      ('cmpi.b\t#$5A,(ScreenShift).w','Retail boss prelude $5A ScreenShift confirmed/deferred'),
      ('SonAni_Hang2:\tdc.b $13,$6B,$6C,$FF','Retail SonAni_Hang2 exact delay/frames confirmed'),
      ('move.b\t#AniIDSonAni_Hang2,anim(a1)','Retail hanging objects explicitly request Hang2'),
      ('move.w\t#$80,sliding_spikes_remaining_movement(a0)','Retail Obj76 exact $80 slide confirmed'),
      ('moveq\t#$18,d1','Retail Crawlton first segment threshold $18 confirmed'),
    ]: ck(needle in asm,msg)

for rel in ['tools/import_s2_mcz2_phase113.py','tools/validate_phase113.py','tools/import_s2_mcz_objects_phase112.py','tools/validate_phase112.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:'); [print(' - '+x) for x in bad]; sys.exit(1)
