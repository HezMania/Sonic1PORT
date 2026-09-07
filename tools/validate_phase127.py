#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, py_compile, sys
P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(r): return (P/r).read_text(errors='replace')
def sha(b): return hashlib.sha256(b).hexdigest()
def be16(b,o): return (b[o]<<8)|b[o+1]

scz=txt('scripts/objects/s2_scz_object.gd')
wfz=txt('scripts/objects/s2_wfz_object.gd')
om=txt('scripts/objects/object_manager.gd')
cat=txt('scripts/data/level_catalog.gd')
cam=txt('scripts/camera/sonic_camera.gd')
bg=txt('scripts/render/ghz_background_renderer.gd')
fg=txt('scripts/render/ghz_renderer.gd')
main=txt('scripts/main.gd')
aud=txt('scripts/audio/sonic_audio.gd')
pcyc=txt('scripts/render/level_palette_cycler.gd')

# Runtime-reported SCZ corrections.
ck('"s2_directional_objpos": true' in cat, 'SCZ/WFZ opt into directional source-style ObjPosLoad')
opl=om[om.index('func obj_pos_load'):om.index('func _find_free_slot')]
ck('previous_block + SPAWN_RIGHT' in opl and 'screen_block + SPAWN_RIGHT' in opl, 'Rightward camera crossings load only the entering ObjPos edge')
ck('screen_block - SPAWN_LEFT' in opl and 'previous_block - SPAWN_LEFT' in opl, 'Leftward camera crossings load only the entering ObjPos edge')
ck('for record in records:' in opl and 'active_records.has(index)' in opl, 'Directional loader still protects active records from duplicates')
clamp=scz[scz.index('func _clamp_scz_player_to_camera'):scz.index('func _tick_tornado')]
ck('cam_x+0x11' in clamp and 'cam_x+vw-0x11' in clamp, 'SCZ player retains retail horizontal camera corridor')
ck('cam_y' not in clamp and 'VIEW_HEIGHT' not in clamp and 'viewport_height' not in clamp, 'SCZ no longer vertically clamps Sonic to the camera')
turt=scz[scz.index('func _tick_turtloid'):scz.index('func _spawn_turtloid_shot')]
ck('var old_x' in turt and 'nx-old_x' in turt and 'move_with_supported_object' in turt, 'Turtloid carries supported Sonic by source old-to-new displacement')
ck('resolve_solid_box_contact(nx,ny,0x18,0x0E,true,record_index)' in turt, 'Turtloid shell remains the retail-sized ride platform')
ck('ZONE_S2_SCZ_TEST' in fg and 'return 30' in fg, 'SCZ high-priority fortress terrain is below Sonic/Tornado')
ck('return 100' in fg, 'Normal/WFZ high-priority terrain remains foreground priority')
ck('request_level_transition(LevelCatalog.ZONE_S2_WFZ_TEST,1)' in scz, 'SCZ Tornado requests direct Wing Fortress transition at its finish')
ck('requested_level_transition' in main and '_load_level(direct_destination.x,direct_destination.y' in main.replace(' ',''), 'Main loop consumes source-seamless level transition request')

# Exact WFZ imported data.
manifest=json.loads((P/'data/s1/s2test/phase127_wfz_manifest.json').read_text())
ck(manifest['phase']==127 and manifest['level']=='Wing Fortress Zone', 'Phase127 manifest identifies Wing Fortress')
ck(manifest['source_revision']=='retail final', 'WFZ import explicitly uses final retail revision')
ck(manifest['start']==[0x60,0x4CC], 'WFZ retail start is $0060,$04CC')
ck(manifest['limits']=={'left':0,'right':0x3FFF,'top':0,'bottom':0x720}, 'WFZ retail level limits are exact')
ck(manifest['layout']==[128,16], 'WFZ foreground/Plane-B layout dimensions are 128x16')
ck(manifest['supplement_tile']==0x307, 'WFZ supplement art is patched at retail tile $307')
ck(manifest['objects']==157, 'All 157 final-revision WFZ object records are imported')
expected={'19':16,'26':19,'2D':1,'72':1,'74':5,'79':3,'80':10,'8B':11,'AD':10,'AE':10,'B2':2,'B4':12,'B5':8,'B6':5,'B8':5,'B9':6,'BA':2,'BC':2,'BD':5,'BE':7,'C0':8,'C1':4,'C2':1,'C5':1,'D9':3}
ck(manifest['object_counts_hex']==expected, 'WFZ object ID counts match the retail stream')
for name,h in manifest['sha256'].items():
    q=P/'data/s1/s2test'/name
    ck(q.exists() and sha(q.read_bytes())==h, f'WFZ generated data hash matches manifest: {name}')
obj=(P/'data/s1/s2test/wfz1_objects.bin').read_bytes()
ck(len(obj)==157*6 and len(obj)%6==0, 'WFZ placement file is 157 six-byte records')
c=Counter(obj[i+4] for i in range(0,len(obj),6))
ck({f'{k:02X}':v for k,v in sorted(c.items())}==expected, 'WFZ placement stream independently decodes to expected IDs/counts')
start=(P/'data/s1/s2test/wfz1_start.bin').read_bytes()
ck(len(start)==4 and be16(start,0)==0x60 and be16(start,2)==0x4CC, 'WFZ start bytes decode exactly')
for name,size in [('wfz1_map16.bin',0x1800),('wfz1_map128.bin',0x8000),('wfz1_collision_primary.bin',0x300),('wfz1_collision_secondary.bin',0x300)]:
    ck((P/'data/s1/s2test'/name).stat().st_size==size, f'{name} has expected runtime size')
ck((P/'data/s1/palette/S2 Wing Fortress Zone.bin').stat().st_size==96, 'WFZ 48-color retail palette is present')
for name,size in [('S2 WFZ Fire Cycle.bin',32),('S2 WFZ Conveyor Cycle.bin',32),('S2 WFZ Cycle 1.bin',68),('S2 WFZ Cycle 2.bin',24)]:
    ck((P/'data/s1/palette'/name).stat().st_size==size, f'{name} source palette-cycle table is present')

if S2:
    ck(obj==(S2/'level/objects/WFZ_1.bin').read_bytes(), 'WFZ object stream is byte-for-byte final retail source')
    ck((P/'data/s1/s2test/wfz1_rings.bin').read_bytes()==(S2/'level/rings/WFZ_1.bin').read_bytes(), 'WFZ ring stream is byte-for-byte retail source')
    ck(start==(S2/'startpos/WFZ.bin').read_bytes(), 'WFZ start stream is byte-for-byte retail source')
    ck((P/'data/s1/palette/S2 Wing Fortress Zone.bin').read_bytes()==(S2/'art/palettes/WFZ.bin').read_bytes(), 'WFZ base palette is byte-for-byte retail source')
    for a,b in [('WFZ Fire Cycle.bin','S2 WFZ Fire Cycle.bin'),('WFZ Conveyor Cycle.bin','S2 WFZ Conveyor Cycle.bin'),('WFZ Cycle 1.bin','S2 WFZ Cycle 1.bin'),('WFZ Cycle 2.bin','S2 WFZ Cycle 2.bin')]:
        ck((P/'data/s1/palette'/b).read_bytes()==(S2/'art/palettes'/a).read_bytes(), f'{b} is byte-for-byte retail source')
    src=(S2/'s2.asm').read_text(errors='replace')
    for q,msg in [
        ('move.w\t#$40,d1','Obj19 source contains $40 horizontal amplitude'),
        ('move.b\t(Oscillating_Data+$38).w,d1','Obj19 source uses oscillator $38 for circular movement'),
        ('jsrto\t(PlatformObject).l','Obj19 source uses PlatformObject carry'),
        ('move.w\t#$A0,objoff_2E(a0)','Obj80 source has $A0 hook maximum'),
        ('cmpi.w\t#$2880,(Camera_X_pos).w','WFZ boss approach gate is $2880'),
        ('cmpi.w\t#$2BC0,(Camera_X_pos).w','WFZ ship transition gate is $2BC0'),
        ('PalCycle_WFZ:','Retail PalCycle_WFZ source exists'),
        ('CyclingPal_WFZFire:','Retail WFZ fire-cycle table exists'),
    ]:
        ck(q in src,msg)

# Catalog/progression/music/debug.
ck('const ZONE_S2_WFZ_TEST := 17' in cat, 'LevelCatalog defines Wing Fortress slot 17')
ck('"zone_code": "S2WFZ"' in cat and '"background_mode": "s2wfz"' in cat and '"dynamic_events": "s2_wfz"' in cat, 'WFZ catalog selects native background/events')
ck('if zone == ZONE_S2_SCZ_TEST:' in cat and 'Vector2i(ZONE_S2_WFZ_TEST, 1)' in cat, 'Catalog progression points SCZ to WFZ')
ck('const MUS_S2_WFZ := 0x19F' in aud, 'WFZ SMPS port-local music ID is $19F')
music=json.loads((P/'data/s1/sound/s2_ehz_smps.json').read_text()).get('music',{})
ck(str(0x19F) in music and music[str(0x19F)]['name']=='Sonic 2 - Wing Fortress Zone', 'Parsed WFZ SMPS song exists in runtime music database')
ck('KEY_KP_0:' in main and 'KEY_KP_1:' in main, 'NumPad 0/1 are SCZ/WFZ debug warps')
ck('_debug_warp(LevelCatalog.ZONE_S2_WFZ_TEST, 1)' in main, 'NumPad 1 directly warps to Wing Fortress')
ck('Num0 SCZ' in main and 'Num1 WFZ' in main, 'Debug overlay documents numeric-keypad SCZ/WFZ warps')
ck('Native Sonic 1 Phase 127' in main, 'Debug overlay identifies Phase127')

# WFZ camera/background/palette translation.
for q in ['screen_x>=0x2BC0 and screen_y>=0x580','s2_wfz_bg_x_offset<0x800','s2_wfz_bg_x_offset>=0x600','screen_x>=0x2880 and screen_y>=0x400','screen_y>=0x500']:
    ck(q in cam, f'WFZ DLE contains source gate/operation: {q}')
ck('s2_wfz_boss_active' in cam and 'player.control_locked=true' in cam, 'Boss control lock is gated until dedicated WFZ boss adapter is armed')
ck('const S2_WFZ_TRANSITION_SEGMENTS' in bg and 'const S2_WFZ_NORMAL_SEGMENTS' in bg, 'WFZ renderer contains both source row-segment tables')
ck('screen_x>=0x2700' in bg.replace(' ',''), 'WFZ background switches to transition table at source X $2700')
ck('s2_wfz_cloud_large_fixed+=0x8000' in bg and 's2_wfz_cloud_medium_fixed+=0x4000' in bg and 's2_wfz_cloud_small_fixed+=0x2000' in bg, 'WFZ cloud layers keep retail 16.16 fixed-point rates')
ck('logical_y' in bg and '0x7FF' in bg, 'WFZ logical background Y is wrapped to retail $7FF')
ck('LevelCatalog.ZONE_S2_WFZ_TEST' in pcyc and 'func _tick_s2_wfz' in pcyc, 'WFZ palette cycle is connected to level tick')
ck('_write_run(level.palette, 55' in pcyc and '_write_single(level.palette, 62' in pcyc and '_write_single(level.palette, 63' in pcyc, 'PalCycle_WFZ writes exact CRAM indices $6E/$7C/$7E')
ck('manager.s2_wfz_fire_toggle' in pcyc and 's2_wfz_belt_cycle if belt else s2_wfz_fire_cycle' in pcyc, 'Obj8B fire/conveyor toggle selects correct source cycle family')

# Native WFZ object routing and key source behaviors.
ck('S2WFZObjectClass = preload' in om, 'WFZ zone-local adapter is preloaded')
route='id in [0x19,0x72,0x80,0x8B,0xAD,0xAE,0xB2,0xB4,0xB5,0xB6,0xB8,0xB9,0xBA,0xBC,0xBD,0xBE,0xC0,0xC1,0xC2,0xD9]'
ck(route in om, 'All Phase127 WFZ-local overlapping IDs route before generic Sonic 2 adapters')
for oid,fn in [('19','_tick_platform'),('72','_tick_conveyor'),('80','_tick_hook'),('8B','_tick_palette_switcher'),('AD','_tick_clucker_base'),('AE','_tick_clucker'),('B2','_tick_tornado'),('B4','_tick_vprop'),('B5','_tick_hprop'),('B6','_tick_tilt_platform'),('B8','_tick_turret'),('B9','_tick_laser'),('BC','_tick_ship_fire'),('BD','_tick_belt_platform_maker'),('BE','_tick_retract_platform'),('C0','_tick_launcher'),('C1','_tick_break_panel'),('C2','_tick_rivet'),('D9','_tick_grab')]:
    ck(fn in wfz, f'WFZ Object ${oid} native Phase127 routine exists')
ck('manager.s2_source_osc_byte(0x38)' in wfz and 'manager.s2_source_osc_byte(0x3C)' in wfz, 'Obj19 circular platforms use shared source oscillator channels $38/$3C')
ck('move_with_supported_object(record_index' in wfz[wfz.index('func _tick_platform'):wfz.index('func _init_conveyor')], 'Obj19 moving platforms carry supported Sonic')
ck('p.object_control_override=true' in wfz and 'p.hang_on_pole=true' in wfz, 'WFZ hooks/grab points enter native object-control hang state')
ck('motion_extent = (subtype & 0x7F) << 4' in wfz, 'ObjC0 launcher travel distance is subtype*16')
ck('vx = -0x1000' in wfz, 'ObjB9 opening lasers use retail -$1000 X velocity')
ck('object_id == 0xB2' in wfz[wfz.index('func suppress_central_despawn'):wfz.index('func _new_sprite')], 'WFZ event Tornado survives central ObjPos despawn')
ck('0xC5' not in route, 'WFZ boss Object $C5 remains deliberately isolated for boss phase')
for folder,minframes in [('platform',4),('clucker',22),('tornado',8),('vprop',3),('hprop',6),('tilt',4),('turret',5),('laser',1),('wheel',1),('shipfire',1),('beltplat',3),('retract',5),('launcher',1),('breakpanel',6),('rivet',1),('hook',13)]:
    fs=sorted((P/f'assets/objects/s2_wfz/{folder}').glob('*.png'))
    ck(len(fs)>=minframes and all(x.stat().st_size>40 for x in fs), f'WFZ {folder} mapping export contains {minframes}+ frames')

# Tools, notes, and structural sanity.
for rel in ['tools/import_s2_wfz_phase127.py','tools/validate_phase127.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')
for rel in ['scripts/objects/s2_scz_object.gd','scripts/objects/s2_wfz_object.gd','scripts/objects/object_manager.gd','scripts/main.gd','scripts/camera/sonic_camera.gd','scripts/render/ghz_background_renderer.gd','scripts/render/ghz_renderer.gd','scripts/render/level_palette_cycler.gd','scripts/data/level_catalog.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t, f'{rel} has no merge conflict markers')
    ck(t.count('(')==t.count(')'), f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'), f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'), f'{rel} braces balance')
ck((P/'PHASE127_SONIC2_WING_FORTRESS.md').exists(), 'Phase127 implementation notes exist')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
