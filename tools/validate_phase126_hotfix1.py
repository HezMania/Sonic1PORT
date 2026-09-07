#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, py_compile, sys
from PIL import Image
P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v);checks.append((ok,msg));print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(r): return (P/r).read_text(errors='replace')
def sha(b): return hashlib.sha256(b).hexdigest()
scz=txt('scripts/objects/s2_scz_object.gd'); boss=txt('scripts/objects/s2_mtz_boss_object.gd')
om=txt('scripts/objects/object_manager.gd'); main=txt('scripts/main.gd'); cam=txt('scripts/camera/sonic_camera.gd')
bg=txt('scripts/render/ghz_background_renderer.gd'); cat=txt('scripts/data/level_catalog.gd')
manifest=json.loads((P/'data/s1/s2test/phase126_scz_manifest.json').read_text())

# Preserve exact Phase126 imported SCZ data.
ck(manifest['phase']==126 and manifest['objects']==60, 'Phase126 SCZ manifest/60 retail records preserved')
for name,h in manifest['sha256'].items():
    q=P/'data/s1/s2test'/name
    ck(q.exists() and sha(q.read_bytes())==h, f'Imported SCZ data unchanged: {name}')

# MTZ boss camera + balloon lifecycle.
wrap=cam[cam.index('func _vertical_wrap_enabled'):cam.index('func _initial_bottom_for_position')]
ck('dynamic_event == "s2_mtz3" and dle_routine >= 2' in wrap and 'return false' in wrap, 'MTZ3 disables $800 vertical wrap at retail $2530 boss approach')
ck('current_bottom = 0x500' in cam and 'target_bottom = 0x450' in cam and 'target_bottom = 0x400' in cam, 'MTZ3 retains retail $500->$450->$400 camera limits')
orb=boss[boss.index('func _tick_orbs'):boss.index('func _player_attacks_point')]
ck('"landed":false' in boss and '"bounce_phase":1' in boss, 'Detached boss balloons track retail landed/bounce state')
ck('0x4AC-(GenesisMath.sine(phase)>>2)' in orb, 'Boss balloons use retail Obj53 sine bounce around floor $4AC')
ck('if (phase&1)!=0:' in orb and 'face_right' in orb, 'Boss balloons move one pixel every other phase toward Sonic')
ck('clampi(x,0x2AB8,0x2BE8)' in orb, 'Boss balloons are guarded inside the locked MTZ arena')
ck('int(o["timer"]) < -0xC0' not in orb, 'Boss balloons no longer expire via non-retail lifetime drift')

# Sky background.
ck('"background_mode": "s2scz", "backdrop_palette_index": 32' in cat, 'SCZ backdrop uses retail blue palette-line color 0')
plane=bg[bg.index('func _build_s2_ehz_plane_index_image'):bg.index('func _setup_mz')]
ck('32 if mode == "s2scz" else 0' in plane, 'SCZ Plane-B blank chunks clear to combined palette index 32')
draw=bg[bg.index('func _draw_mz_block_indices'):bg.index('func _indexed_tile_image')]
ck('if color_index == 0:' in draw and 'prefilled backdrop index' in draw, 'SCZ Plane-B pen 0 preserves the prefilled backdrop')

# Shared Tornado velocity and source-shaped SCZ badnik motion.
ck('var s2_scz_scroll_vx := 0' in om and 'var s2_scz_scroll_vy := 0' in om, 'Object manager exposes Tornado_Velocity_X/Y')
ck('object_manager.s2_scz_scroll_vx = sonic_camera.s2_scz_velocity_x' in main and 'object_manager.s2_scz_scroll_vy = sonic_camera.s2_scz_velocity_y' in main, 'Main loop mirrors SwScrl_SCZ velocity to objects')
ck(scz.count('manager.s2_scz_scroll_vx<<16')>=4, 'Nebula/Turtloid/Balkiry/cloud motion receives SCZ horizontal world scroll')
ck(scz.count('manager.s2_scz_scroll_vy<<16')>=3, 'Nebula/Turtloid/Balkiry receive SCZ vertical world scroll')
ck('plane_y_fixed += manager.s2_scz_scroll_vy << 16' in scz, 'Tornado itself receives vertical auto-scroll before player steering')
ck('vx=-0xC0' in scz, 'Nebula retains exact retail -$C0 own X velocity')
ck('vx=-0x500 if y_flip else -0x300' in scz, 'Balkiry consumes placement render bit 1 for retail -$500/-$300 speed')

# Collision/identity corrections.
badnik=scz[scz.index('func _badnik_contact'):scz.index('func _hazard')]
ck('if p.vel_y >= 0:' in badnik and 'GenesisMath.s16(-p.vel_y)' not in badnik, 'Upward badnik attacks do not reverse/bounce Sonic downward')
ck('if not y_flip:_hazard' in scz, 'SCZ vertical propeller uses source render-bit-1 collision disable')
turt=scz[scz.index('func _init_turtloid'):scz.index('func _spawn_turtloid_shot')]
ck('_turtloid_rider_contact' in turt and 'request_delete' not in turt, 'Destroying Turtloid rider does not delete the carrier body')
ck('p.resolve_solid_box_contact' in turt and 'Only separate Obj9B is a badnik' in turt, 'Turtloid body remains a rideable non-badnik platform')
ck('rider.queue_free(); rider=null' in turt and 'state=4; vx=-0x80' in turt, 'Destroyed rider disappears while Turtloid resumes retail left motion')

# Tornado pilot/movement/bounds.
ck('const TAILS_PILOT_SEQUENCE' in scz and 'pilot=_new_sprite("pilot",0,4)' in scz, 'Tornado includes native Tails pilot overlay and retail frame sequence')
ck('pilot.position=Vector2(-36,0)' in scz, 'Tails pilot overlay matches ObjB2 mapping piece (-$30,-8), centered 24x16')
ck('_clamp_scz_player_to_camera' in scz and 'cam_x+vw-0x11' in scz and 'cam_y+vh-8' in scz, 'Tornado/Sonic remain inside visible camera corridor during SCZ flight')
for i in range(5):
    q=P/f'assets/objects/s2_scz/pilot/{i:02d}.png'
    ok=q.exists()
    if ok:
        im=Image.open(q); ok=im.size==(24,16) and im.getbbox() is not None
    ck(ok,f'Tails pilot frame {i:02d} is a non-empty 24x16 image')

# Hotkey migration.
ck('KEY_KP_0:' in main and '_debug_warp(LevelCatalog.ZONE_S2_SCZ_TEST, 1)' in main[main.index('KEY_KP_0:'):], 'NumPad 0 directly warps to Sky Chase')
ck('KEY_F10:' not in main[main.index('match event.keycode:'):main.index('KEY_K:')], 'F10 is no longer consumed by the Sky Chase test warp')
ck('Num0 SCZ' in main and 'F10 SCZ' not in main, 'Debug overlay documents NumPad 0 Sky Chase warp')

# Retail-source assertions for the fixes.
if S2:
    src=(S2/'s2.asm').read_text(errors='replace')
    for q,msg in [
        ('move.w\t(Tornado_Velocity_X).w,d0','SCZ badnik helper adds Tornado X velocity'),
        ('move.w\t(Tornado_Velocity_Y).w,d0','SCZ badnik helper adds Tornado Y velocity'),
        ('move.w\t#-$C0,x_vel(a0)','Nebula retail own speed is -$C0'),
        ('move.w\t#-$300,x_vel(a0)','Balkiry retail default speed is -$300'),
        ('move.w\t#-$500,x_vel(a0)','Balkiry retail fast speed is -$500'),
        ('Obj9B_SubObjData:','Turtloid rider is a distinct Object $9B'),
        ('subObjData Obj9A_Obj98_MapUnc_37B62,make_art_tile(ArtTile_ArtNem_Turtloid,0,0),4,5,$18,0','Turtloid carrier collision flags are zero'),
        ('Tails_pilot_frames:','Retail Tornado pilot frame table exists'),
        ('cmpi.w\t#$4AC,y_pos(a0)','Obj53 lands balloons at $4AC'),
        ('asr.w\t#2,d0','Obj53 bounce uses sine divided by four'),
    ]:
        ck(q in src,msg)

# Tools and structural sanity.
for rel in ['tools/import_s2_scz_phase126.py','tools/import_s2_scz_hotfix1_pilot.py','tools/validate_phase126.py','tools/validate_phase126_hotfix1.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')
for rel in ['scripts/objects/s2_scz_object.gd','scripts/objects/s2_mtz_boss_object.gd','scripts/objects/object_manager.gd','scripts/main.gd','scripts/camera/sonic_camera.gd','scripts/render/ghz_background_renderer.gd','scripts/data/level_catalog.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad:print(' - '+m)
    raise SystemExit(1)
