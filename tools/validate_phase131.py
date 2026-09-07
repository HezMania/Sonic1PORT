#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, py_compile, sys
P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(r): return (P/r).read_text(errors='replace')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
main=txt('scripts/main.gd'); wfz=txt('scripts/objects/s2_wfz_object.gd')
boss=txt('scripts/objects/s2_wfz_boss_object.gd'); om=txt('scripts/objects/object_manager.gd')
cam=txt('scripts/camera/sonic_camera.gd'); bg=txt('scripts/render/ghz_background_renderer.gd')
fg=txt('scripts/render/ghz_renderer.gd'); data=txt('scripts/data/ghz_level_data.gd')
manifest=json.loads((P/'data/s1/s2test/phase131_wfz_manifest.json').read_text())

ck('Native Sonic 1 Phase 131' in main,'Debug overlay identifies Phase131')
ck(manifest.get('phase')==131 and manifest.get('level')=='Wing Fortress Zone','Phase131 manifest identifies Wing Fortress')
ck((P/'PHASE131_SONIC2_WING_FORTRESS_BOSS_END_CORRECTIONS.md').exists(),'Phase131 notes exist')

# ObjC2: exact interleaved Level_Layout correction.
rivet=wfz[wfz.index('func _tick_rivet'):wfz.index('# -----------------------------------------------------------------------------\n# $D9')]
ck('attacking_before_solid' in rivet and rivet.index('attacking_before_solid') < rivet.index('resolve_solid_box_contact'),'ObjC2 preserves pre-SolidObject attack/animation ordering')
ck('set_chunk_id_at(0x50 + i, 8, upper[i])' in rivet,'ObjC2 $850 write targets Plane-A row 8')
ck('set_chunk_id_at(0x50 + i, 9, lower[i])' in rivet,'ObjC2 $950 write targets Plane-A row 9')
ck('set_background_chunk_id_at' not in rivet,'ObjC2 no longer mutates the wrong background plane')
ck('[0x8A, 0x70, 0x71, 0x72, 0x73, 0x74]' in rivet,'ObjC2 first six-byte layout patch matches retail')
ck('[0x6E, 0x78, 0x79, 0x78, 0x78, 0x7A]' in rivet,'ObjC2 second six-byte layout patch matches retail')
ck('s2_wfz_layout_refresh_requested' in rivet and 'request_delete(true)' in rivet,'ObjC2 requests foreground refresh and permanent deletion')
ck('func set_chunk_id_at' in data and 'func set_background_chunk_id_at' in data,'Level data supports independent native Plane-A/Plane-B runtime edits')
refresh=main[main.index('object_manager.execute_objects()'):main.index('if object_manager.requested_level_transition.x >= 0:')]
ck('for cy in [8, 9]:' in refresh and 'range(0x50, 0x56)' in refresh and 'renderer.refresh_chunk(cx, cy)' in refresh,'Main refreshes exactly the twelve changed foreground cells')
ck('s2_wfz_layout_refresh_requested' in om,'Object manager carries the ObjC2 layout-redraw latch')

# Boss preload and true C5 proximity start.
boss_start=main[main.index('func _tick_s2_wfz_boss_start'):main.index('func _tick_level_art')]
ck('screen_x >= 0x2880 and sonic_camera.screen_y >= 0x400' in boss_start,'LevEvents_WFZ boss preload gate is Camera $2880,$400')
ck('spawn_s2_wfz_boss()' in boss_start,'Main preloads native C5 at the retail event gate')
wait=boss[boss.index('func _tick_wait'):boss.index('func _tick_prelude')]
ck('absi(p.pixel_x() - _boss_x()) >= 0x20' in wait,'C5 itself waits for the retail +/-$20 player proximity')
ck('timer = 0x5A' in wait and 'SonicAudio.stop_music()' in wait,'Actual fight start owns the $5A fade/prelude')
ck('eggman_sprite.visible = false' in boss[:boss.index('func tick')],'Robotnik is hidden during C5 preload/wait')
ck('eggman_sprite.visible = true' in wait and 'eggman_platform_sprite.visible = true' in wait,'Robotnik appears only when C5 actually starts')

# Independent boss child ownership.
ck('const LEFT_WALL_WORLD_X := START_X - WALL_OFFSET_X' in boss and 'const RIGHT_WALL_WORLD_X := START_X + WALL_OFFSET_X' in boss,'Laser walls have fixed authored world X coordinates')
ck('const WALL_WORLD_Y := START_Y + WALL_OFFSET_Y' in boss,'Laser walls have fixed authored world Y')
vis=boss[boss.index('func _update_visuals'):boss.index('func _make_sprite')]
ck('LEFT_WALL_WORLD_X - bx' in vis and 'RIGHT_WALL_WORLD_X - bx' in vis,'Wall sprites counter-transform against moving case')
ck('EGGMAN_WORLD_X - bx' in vis and 'eggman_world_y - by' in vis,'Robotnik counter-transforms against moving case')
walls=boss[boss.index('func _tick_walls'):boss.index('func _check_laser_hazard')]
ck('LEFT_WALL_WORLD_X' in walls and 'RIGHT_WALL_WORLD_X' in walls,'Wall collision remains at fixed world coordinates')
ck('shooter_sprite.position.x = 0' in vis,'Laser shooter alone follows case X')

# Platform releaser and one-at-a-time spiked platforms.
releaser=boss[boss.index('func _tick_releaser'):boss.index('func _tick_eggman')]
ck('releaser_timer = 0x40' in boss and 'releaser_y_fixed += 0x40 << 8' in releaser,'Platform releaser uses retail $40-frame/$40-speed descent')
ck('releaser_timer = 0x10' in releaser and 'releaser_timer = 0x80' in releaser,'Platform releaser uses retail $10 initial wait and $80 release cadence')
ck('releaser_slot = (releaser_slot + 1) % 3' in releaser,'Platform release slot order rotates 1,2,0')
spawn=boss[boss.index('func _spawn_released_platform'):boss.index('func _tick_releaser')]
ck('releaser_x_fixed >> 16' in spawn and 'releaser_y_fixed >> 16' in spawn,'Each boss platform spawns at releaser current position')
ck('"vy": 0x100' in spawn and '"timer": 0x60' in spawn,'Released platform begins with retail $100 down speed and $60 timer')
ck('for i in range(3)' not in boss,'Boss no longer pre-spawns a line of three platforms')
platforms=boss[boss.index('func _tick_platforms'):boss.index('func _tick_walls')]
ck('item["vx"] = -0x100' in platforms and 'item["timer"] = 0xC0' in platforms,'Boss platforms use retail left start and $C0 reversal timer')
ck('p.resolve_platform_top' in platforms and 'p.apply_hazard_hit(px)' in platforms,'Boss platforms are top-only with separate spiked underside hazard')

# End Tornado visible jump and source layout patches.
torn=wfz[wfz.index('func _tick_tornado_end'):wfz.index('# -----------------------------------------------------------------------------\n# $B4/$B5')]
for token,msg in [('0x40','retail $40 wait'),('0x380','Camera-BG $380 wait'),('0x30','retail $30 prepare'),('0x38','retail $38 jump window'),('0x100','retail $100 landed gate'),('0x437','retail $437 ship-jump gate'),('0x460','retail $460 getaway gate'),('0x9C0','retail $9C0 handoff')]:
    ck(token in torn,f'End Tornado retains {msg}')
ck('sin(PI * t)' in torn and 'cutscene_start_x' in torn,'First end jump is rendered as a visible parabola')
ck('sin(PI * second_t)' in torn and 'cutscene_second_jump' in torn,'Jump toward the approaching ship is visibly staged')
ck('_pin_player_to_tornado(p)' in torn,'Sonic is pinned only after landing on the Tornado')
ck('manager.s2_wfz_getaway_active = true' in torn,'Source $460 gate switches LevEvents_WFZ to getaway routine')
getlayout=wfz[wfz.index('func _apply_wfz_getaway_layout'):wfz.index('# -----------------------------------------------------------------------------\n# $B4/$B5')]
ck('set_background_chunk_id_at(0x52 + i, 0' in getlayout and '0x52 + i, 1' in getlayout,'ObjB2 applies $0D2/$1D2 Plane-B edits')
ck('set_background_chunk_id_at(0x56 + i, 11' in getlayout and '0x56 + i, 12' in getlayout,'ObjB2 applies $BD6/$CD6 Plane-B edits')
ck('[0x50, 0x1F, 0x00, 0x25]' in getlayout and '[0x25, 0x00, 0x1F, 0x50]' in getlayout,'ObjB2 getaway layout bytes match retail')
ck('s2_wfz_background_refresh_requested = true' in getlayout,'ObjB2 requests one cached Plane-B refresh after landing')
bgrefresh=bg[bg.index('func refresh_s2_wfz_getaway_layout'):bg.index('func refresh_s2test_art_range')]
ck('range(0x52, 0x56)' in bgrefresh and 'range(0x56, 0x5A)' in bgrefresh,'Background renderer refreshes only the sixteen ObjB2-mutated cells')

# Background scroll fidelity / no static-cache vertical replay.
wfzbg=bg[bg.index('func _update_s2wfz'):bg.index('func _update_s2mtz')]
ck('camera_model.s2_wfz_bg_x_pos' in wfzbg and 'camera_model.s2_wfz_bg_y_pos' in wfzbg,'WFZ renderer samples integrated Camera_BG position')
ck('camera_model.dle_routine >= 6' in wfzbg and 'sampled_bg_y = clampi' in wfzbg,'Getaway clamps static Plane-B cache instead of replaying it vertically')
ck('posmod(bg_y + line' in wfzbg,'Normal WFZ keeps wrap sampling before getaway')
wfzcam=cam[cam.index('func _dle_s2_wfz'):cam.index('func _dle_s2_mtz3')]
ck('_step_s2_wfz_bg_to_target' in wfzcam,'LevEvents_WFZ uses native ScrollBG integrator')
step=cam[cam.index('func _step_s2_wfz_bg_to_target'):cam.index('func _dle_s2_wfz')]
ck('clampi(target_x - s2_wfz_bg_x_pos, -16, 16)' in step and 'clampi(target_y - s2_wfz_bg_y_pos, -16, 16)' in step,'WFZ ScrollBG movement is capped to +/-16 pixels/frame per axis')

# Core Phase130 fixes retained.
cyc=txt('scripts/render/level_palette_cycler.gd')
wfzcyc=cyc[cyc.index('func _tick_s2_wfz'):cyc.index('func _load_cycle_data')]
ck('_write_run(level.palette, 39, source, source_offset, 4)' in wfzcyc and '_write_single(level.palette, 46' in wfzcyc and '_write_single(level.palette, 47' in wfzcyc,'Correct WFZ palette-cycle CRAM line remains intact')
ck('LevelCatalog.ZONE_S2_WFZ_TEST' in fg[fg.index('palette_indexed_mode = level != null'):fg.index('cycle_palette_image = null')],'WFZ remains on indexed foreground renderer for palette-cycle performance')
ck('static var _texture_cache: Dictionary = {}' in wfz,'WFZ object texture cache remains active')
plat=wfz[wfz.index('func _tick_platform'):wfz.index('func _init_conveyor')]
ck('riding_old_surface' in plat and 'p.force_add_pixel_offset(nx - old_x, ny - old_y)' in plat,'Circular Obj19 carry fix remains intact')

# Data/source invariants.
ck(manifest.get('objects')==157 and manifest.get('layout')==[128,16] and manifest.get('supplement_tile')==0x307,'WFZ final object/layout/supplement invariants remain exact')
obj=(P/'data/s1/s2test/wfz1_objects.bin').read_bytes()
ck(len(obj)//6==157,'WFZ retains all 157 final object records')
# Explicit authored records C2/C5/B2 end.
records=[obj[i:i+6] for i in range(0,len(obj),6)]
ck(any(r[4]==0xC2 and (int.from_bytes(r[:2],'big')&0x3fff)==0x2958 for r in records),'Retail C2 rivet record remains at $2958')
ck(any(r[4]==0xC5 and (int.from_bytes(r[:2],'big')&0x3fff)==0x2B80 for r in records),'Retail C5 boss record remains at $2B80')
ck(any(r[4]==0xB2 and r[5]==0x54 and (int.from_bytes(r[:2],'big')&0x3fff)==0x2C60 for r in records),'Retail end Tornado record remains at $2C60,$5EC')
for fn,h in manifest.get('sha256',{}).items(): ck(sha(P/'data/s1/s2test'/fn)==h,f'Generated WFZ data hash matches manifest: {fn}')
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    ck('lea\t(Level_Layout+$850).w,a1' in asm and 'lea\t(Level_Layout+$950).w,a1' in asm,'Retail source contains ObjC2 $850/$950 layout writes')
    ck('lea\t(Level_Layout+$80).w,a4\t; first background line' in asm,'Retail renderer establishes +$80 as first background half-row')
    ck('move.w\t#$2C60,x_pos(a0)' in asm and 'move.w\t#$4E6,y_pos(a0)' in asm,'Retail source fixes Robotnik at $2C60,$4E6')
    ck('move.w\t#$80,objoff_2A(a0)' in asm and 'ObjC5_PlatformReleaserLoadP' in asm,'Retail source uses one-at-a-time $80 platform release cadence')
    ck((P/'data/s1/s2test/wfz1_objects.bin').read_bytes()==(S2/'level/objects/WFZ_1.bin').read_bytes(),'WFZ object stream remains byte-for-byte retail')

try:
    py_compile.compile(str(P/'tools/import_s2_wfz_phase130.py'),doraise=True); ck(True,'WFZ importer compiles')
except Exception as e:
    print(e); ck(False,'WFZ importer compiles')

for rel in ['scripts/objects/s2_wfz_object.gd','scripts/objects/s2_wfz_boss_object.gd','scripts/objects/object_manager.gd','scripts/camera/sonic_camera.gd','scripts/render/ghz_background_renderer.gd','scripts/render/ghz_renderer.gd','scripts/data/ghz_level_data.gd','scripts/main.gd']:
    body=txt(rel)
    ck('<<<<<<<' not in body and '=======' not in body and '>>>>>>>' not in body,f'{rel} has no merge-conflict markers')
    ck(body.count('(')==body.count(')'),f'{rel} parentheses balance')
    ck(body.count('[')==body.count(']'),f'{rel} brackets balance')
    ck(body.count('{')==body.count('}'),f'{rel} braces balance')

passed=sum(1 for ok,_ in checks if ok)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' - '+msg)
    raise SystemExit(1)
