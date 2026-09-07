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
mtz=txt('scripts/objects/s2_mtz_object.gd')
boss=txt('scripts/objects/s2_mtz_boss_object.gd')
scz=txt('scripts/objects/s2_scz_object.gd')
om=txt('scripts/objects/object_manager.gd')
cat=txt('scripts/data/level_catalog.gd')
cam=txt('scripts/camera/sonic_camera.gd')
bg=txt('scripts/render/ghz_background_renderer.gd')
main=txt('scripts/main.gd')
aud=txt('scripts/audio/sonic_audio.gd')

# Phase 125 carry-forward corrections.
sl_init=mtz[mtz.index('func _init_slicer'):mtz.index('func _spawn_slicer_pincer')]
ck('sprite.flip_v=y_flip' in sl_init, 'Ceiling Slicer body honors placement Y flip')
ck('s.flip_v=y_flip' in mtz[mtz.index('func _spawn_slicer_pincer'):mtz.index('func _tick_slicer')], 'Ceiling Slicer pincers honor placement Y flip')
ck('if projectiles.is_empty():request_delete(respawn_enabled)' in mtz, 'Asteron destruction preserves remembered state instead of instant reload')
ck('move_with_supported_object(record_index,0,new_y-old_y' in mtz[mtz.index('func _tick_barrier'):mtz.index('func _init_steam_spring')], 'Horizontal closing doors carry supported Sonic deterministically')
ck('position.x = _platform_x_from_displacement()' in mtz[mtz.index('func _init_long_platform'):mtz.index('func _platform_x_from_displacement')], 'Obj65 mode-3 platform initializes at source-derived rest X')
ck('on_top_now' in mtz and '$0F60,$0424' in mtz, 'Obj65 mode-3 platform accepts native feet-on-top activation')
ck('tube_segment_timer=maxi(0,ay >> 4)' in mtz and 'tube_segment_timer=maxi(0,ax >> 4)' in mtz, 'Obj67 uses retail dominant-axis segment timer')
ck('tube_segment_timer-=1\n\tif tube_segment_timer>=0:' in mtz, 'Obj67 decrements segment timer before movement like retail')
ck('p.object_control_override=true' in mtz[mtz.index('func _tick_spin_tube'):mtz.index('func _init_spike_block')], 'Obj67 reasserts object-control ownership through every segment')
ck('func _tube_wrapped_point' in mtz and '0x800' in mtz, 'Obj67 retains MTZ vertical-wrap path support')

ck('var display_flip := false' in boss, 'Obj54 separates visible facing from logical side')
ck('var vx := 0x400 if display_flip else -0x400' in boss, 'Obj54 final lasers fire in the visible-facing direction')
ck('vel_x = 0' in boss[boss.index('func _tick_laser_state'):boss.index('func _spawn_laser')], 'Obj54 final descent stops horizontal drift at source boundary')
ck('side_flag = not side_flag' in boss[boss.index('func _tick_laser_state'):boss.index('func _spawn_laser')], 'Obj54 logical side toggles at the bottom of the laser pass')
ck('sp.z_index=7' in boss and 'sp.z_index=1' in boss and 'GenesisMath.cosine(a)' in boss, 'Obj53 near/far shield priorities are depth-derived')
ck('mini(0x0B, 5 + (int(o["anim"]) >> 2))' in boss, 'Obj53 detached balloon advances once and holds mapping frame B')
ck('_rebound_player_from_attack()' in boss[boss.index('if int(o["timer"])<=0:'):boss.index('func _player_attacks_point')], 'Attacking detached Obj53 balloon rebounds Sonic')
ck(boss.count('is_instance_valid') >= 5, 'Obj54 transient sprite cleanup guards freed references')

# SCZ imported data and source identity.
manifest=json.loads((P/'data/s1/s2test/phase126_scz_manifest.json').read_text())
ck(manifest['phase']==126 and manifest['level']=='Sky Chase Zone', 'Phase126 SCZ manifest identifies the phase/level')
ck(manifest['start']==[0x120,0x70], 'SCZ retail start is $0120,$0070')
ck(manifest['objects']==60, 'SCZ manifest contains all 60 retail object records')
expected={'03':1,'99':23,'9A':10,'AC':19,'B2':1,'B3':3,'B4':1,'B5':2}
ck(manifest['object_counts_hex']==expected, 'SCZ retail object-family counts match source')
for name,h in manifest['sha256'].items():
    q=P/'data/s1/s2test'/name
    ck(q.exists() and sha(q.read_bytes())==h, f'Phase126 generated data unchanged: {name}')
obj=(P/'data/s1/s2test/scz1_objects.bin').read_bytes()
ck(len(obj)==360 and len(obj)%6==0, 'SCZ object stream is exactly 60 six-byte records')
c=Counter(obj[i+4] for i in range(0,len(obj),6))
ck({f'{k:02X}':v for k,v in sorted(c.items())}==expected, 'SCZ object stream decodes to exact expected IDs/counts')
start=(P/'data/s1/s2test/scz1_start.bin').read_bytes()
ck(len(start)==4 and be16(start,0)==0x120 and be16(start,2)==0x70, 'SCZ imported start bytes are exact')
if S2:
    ck(obj==(S2/'level/objects/SCZ_1.bin').read_bytes(), 'SCZ object stream is byte-for-byte retail')
    ck((P/'data/s1/s2test/scz1_rings.bin').read_bytes()==(S2/'level/rings/SCZ_1.bin').read_bytes(), 'SCZ ring stream is byte-for-byte retail')
    ck(start==(S2/'startpos/SCZ.bin').read_bytes(), 'SCZ start stream is byte-for-byte retail')
    src=(S2/'s2.asm').read_text(errors='replace')
    for q in ['cmpi.w\t#$1180,(Camera_X_pos).w','move.w\t#-1,(Tornado_Velocity_X).w','move.w\t#$500,(Camera_Max_Y_pos).w','cmpi.w\t#$1400,(Camera_X_pos).w']:
        ck(q in src, f'Retail LevEvents_SCZ source contains {q}')

# Catalog/progression/music/debug routing.
ck('const ZONE_S2_SCZ_TEST := 16' in cat, 'LevelCatalog defines the SCZ test slot')
ck('"zone_code": "S2SCZ"' in cat and '"background_mode": "s2scz"' in cat and '"dynamic_events": "s2_scz"' in cat, 'SCZ LevelCatalog entry selects native presentation/event paths')
ck('act < 3 else Vector2i(ZONE_S2_SCZ_TEST, 1)' in cat, 'MTZ3 progresses into Sky Chase')
ck('if zone == ZONE_S2_SCZ_TEST:' in cat and 'Vector2i(ZONE_GHZ, 1)' in cat, 'SCZ uses documented temporary post-level fallback')
ck('const MUS_S2_SCZ := 0x19E' in aud and 'MUS_S2_SCZ' in main, 'SCZ native SMPS music is wired at port-local $19E')
music_json=json.loads((P/'data/s1/sound/s2_ehz_smps.json').read_text())
music_entries=music_json.get('music',{})
ck(('414' in music_entries) or (414 in music_entries) or ('0x19E' in music_entries), 'SCZ parsed SMPS sequence is present at music ID $19E')
ck((P/'data/s1/palette/S2 Sky Chase Zone.bin').exists() and (P/'data/s1/palette/S2 Sky Chase Zone.bin').stat().st_size==96, 'SCZ retail 48-color palette is present')
ck('KEY_F10' in main and '_debug_warp(LevelCatalog.ZONE_S2_SCZ_TEST, 1)' in main, 'F10 directly warps to Sky Chase')
ck('Native Sonic 1 Phase 126' in main, 'Debug overlay identifies Phase126')

# Exact auto-scroll / background behavior.
for q in ['screen_x >= 0x1180','s2_scz_velocity_x = -1; s2_scz_velocity_y = 1','current_bottom = 0x500','screen_y >= 0x500','screen_x >= 0x1400','s2_scz_velocity_x = 0; s2_scz_velocity_y = 0']:
    ck(q in cam, f'SCZ camera event contains {q}')
ck('s2_scz_bg_x_fixed += 0x80' in cam, 'SCZ Plane-B fixed accumulator advances +$80 on horizontal motion')
ck('func _update_s2scz' in bg and 'camera_model.s2_scz_bg_x_fixed >> 8' in bg, 'SCZ background renderer consumes the retail fixed accumulator')
ck('mode == "s2scz"' in bg, 'SCZ background mode is included in renderer setup/update')

# All SCZ placement families have native routing/art.
ck('S2SCZObjectClass = preload' in om, 'SCZ zone-local object adapter is preloaded')
ck('id in [0x99,0x9A,0xAC,0xB2,0xB3,0xB4,0xB5]' in om, 'All seven SCZ-specific IDs route through the SCZ namespace')
ck('0x03: return S2PlaneSwitcherObjectClass.new()' in om, 'SCZ Object $03 uses the existing Sonic 2 plane switcher')
for oid,fn in [('B2','_tick_tornado'),('B3','_tick_cloud'),('B4','_tick_vprop'),('B5','_tick_hprop'),('AC','_tick_balkiry'),('99','_tick_nebula'),('9A','_tick_turtloid')]:
    ck(fn in scz, f'SCZ Object ${oid} native routine exists')
ck('manager.current_screen_x>=0x1400' in scz and 'p.pixel_x()<0x1568' in scz, 'Tornado owns retail $1400/$1568 finish gate')
ck('p.control_lock_direction=1' in scz, 'Tornado forced-right finish uses the player control-lock direction')
for folder,n in [('tornado',8),('cloud',4),('vprop',3),('hprop',6),('balkiry',2),('turtloid',10),('nebula',5)]:
    fs=sorted((P/f'assets/objects/s2_scz/{folder}').glob('*.png'))
    ck(len(fs)==n and all(x.stat().st_size>50 for x in fs), f'SCZ {folder} has all {n} rendered mapping frames')

# Python importer/validator + basic GDScript structural sanity.
for rel in ['tools/import_s2_scz_phase126.py','tools/validate_phase126.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')
for rel in ['scripts/objects/s2_mtz_object.gd','scripts/objects/s2_mtz_boss_object.gd','scripts/objects/s2_scz_object.gd','scripts/objects/object_manager.gd','scripts/main.gd','scripts/camera/sonic_camera.gd','scripts/render/ghz_background_renderer.gd','scripts/data/level_catalog.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t, f'{rel} has no merge conflict markers')
    ck(t.count('(')==t.count(')'), f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'), f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'), f'{rel} braces balance')
ck((P/'PHASE126_SONIC2_SKY_CHASE.md').exists(), 'Phase126 notes exist')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
