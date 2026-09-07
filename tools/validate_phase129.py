#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import hashlib, json, py_compile, sys
P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(r): return (P/r).read_text(errors='replace')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

wfz=txt('scripts/objects/s2_wfz_object.gd')
om=txt('scripts/objects/object_manager.gd')
main=txt('scripts/main.gd')
imp=txt('tools/import_s2_wfz_phase129.py')
manifest=json.loads((P/'data/s1/s2test/phase129_wfz_manifest.json').read_text())

ck('Native Sonic 1 Phase 129' in main,'Debug overlay identifies Phase129')
ck(manifest.get('phase')==129 and manifest.get('level')=='Wing Fortress Zone','Phase129 manifest identifies WFZ correction pass')
ck((P/'PHASE129_SONIC2_WING_FORTRESS_TRAVERSAL_CORRECTIONS.md').exists(),'Phase129 implementation notes exist')


# Phase128 foundation invariants retained.
cat=txt('scripts/data/level_catalog.gd')
bg=txt('scripts/render/ghz_background_renderer.gd')
ck('manager.camera' not in wfz,'WFZ runtime adapter retains Phase128 manager.camera crash fix')
ck('"background_mode": "s2wfz", "backdrop_palette_index": 32' in cat,'WFZ keeps palette-index-32 sky/backdrop clear')
ck('mode in ["s2scz", "s2wfz"]' in bg,'WFZ Plane-B empty cells keep shared blue sky palette line')
base=wfz[wfz.index('func _init_clucker_base'):wfz.index('func _tick_clucker_base')]
bird=wfz[wfz.index('func _init_clucker()'):wfz.index('func _tick_clucker()')]
ck('_new_sprite("clucker", 12, 3)' in base and '_new_sprite("clucker", 21, 2)' in bird,'Clucker base remains above the bird')
torn=wfz[wfz.index('func _init_tornado'):wfz.index('func _init_vprop')]
ck('pilot = _new_sprite("pilot", 0, 4)' in torn and 'TAILS_PILOT_SEQUENCE[pilot_step]' in torn,'Tails remains present and animated in the WFZ Tornado')

# Reported parser failure at Phase128 obj_pos_load right bound.
pos=om[om.index('func obj_pos_load'):om.index('func _spawn_record')]
ck('var screen_block: int =' in pos,'ObjPosLoad screen block has explicit int type')
ck('var previous_block: int =' in pos,'ObjPosLoad previous block has explicit int type')
ck('var left: int =' in pos and 'var right: int =' in pos,'ObjPosLoad left/right bounds have explicit int types')
ck('var right:=' not in pos,'Phase128 inferred right declaration is absent')

# Opening lasers.
laser=wfz[wfz.index('func _init_laser'):wfz.index('func _init_wheel')]
ck('sprite.visible = false' in laser,'Opening ObjB9 lasers start hidden')
ck('orig_x >= manager.current_screen_x and orig_x <= manager.current_screen_x + vw' in laser,'ObjB9 activates only when its center reaches the actual viewport')
ck('sprite.visible = true' in laser and 'vx = -0x1000' in laser,'ObjB9 becomes visible only as retail leftward launch begins')

# Launchers.
launch=wfz[wfz.index('func _init_launcher'):wfz.index('func _init_break_panel')]
ck('motion_dir = 1 if x_flip else -1' in launch,'ObjC0 travel direction matches source status-bit sense')
ck('vx = 0x0C00 * motion_dir' in launch and 'vx += 0x80 * motion_dir' in launch,'ObjC0 uses source $C00 launch speed and $80 acceleration in corrected direction')
ck('p.resolve_platform_top' in launch and 'resolve_solid_box_contact' not in launch,'ObjC0 remains top-only PlatformObject collision')

# Palette bridge: user reference matches the SCZ retained browns exactly.
pal=(P/'data/s1/palette/S2 Wing Fortress Zone.bin').read_bytes()
ck(len(pal)==96,'WFZ runtime zone palette is 96 bytes')
expected_words=[0x0244,0x0268,0x048A,0x04AC]
actual=[int.from_bytes(pal[i*2:i*2+2],'big') for i in range(34,38)]
ck(actual==expected_words,'WFZ ship colors are brown/gold $0244,$0268,$048A,$04AC from the supplied visual target')
if S2 is not None:
    retail=(S2/'art/palettes/WFZ.bin').read_bytes(); scz=(S2/'art/palettes/SCZ.bin').read_bytes()
    ck(all(pal[i*2:i*2+2]==scz[i*2:i*2+2] for i in range(34,38)),'Four corrected terrain colors exactly match retail SCZ handoff colors')
    ck(all(pal[i*2:i*2+2]==retail[i*2:i*2+2] for i in list(range(34))+list(range(38,48))),'All other WFZ zone colors remain byte-for-byte retail WFZ')
ck(manifest.get('runtime_palette_bridge',{}).get('indices')==[34,35,36,37],'Manifest records the four-color SCZ->WFZ runtime palette bridge')

# Circular moving platforms and carry.
plat=wfz[wfz.index('func _init_platform'):wfz.index('func _init_conveyor')]
ck('GenesisMath.s8((a - 0x40) & 0xFF)' in plat and 'GenesisMath.s8((b - 0x40) & 0xFF)' in plat,'Obj19 circular oscillator deltas use source byte-wrap then sign extension')
ck('move_with_supported_object(record_index, nx - old_x, ny - old_y' in plat,'Obj19 carries supported Sonic by old-to-new horizontal and vertical displacement')
ck('resolve_platform_top(nx - active_width, nx + active_width, ny - 0x11' in plat,'Obj19 remains retail top-only PlatformObject')
for off in ('0x08','0x1C','0x38','0x3C'):
    ck(f's2_source_osc_byte({off})' in plat,f'Obj19 retains Oscillating_Data source offset {off}')

# Propeller slowdown guard and source animation/effect path.
ck('static var _texture_cache: Dictionary = {}' in wfz,'WFZ object frames share a class-wide texture cache')
setframe=wfz[wfz.index('func _set_frame'):wfz.index('func _player_overlap')]
ck('wfz_frame_path' in setframe,'Animated sprites skip redundant same-frame texture assignments')
ck('_texture_cache.get(path)' in setframe and '_texture_cache[path] = tex' in setframe,'WFZ frame resources are loaded once and reused across giant propellers')
vprop=wfz[wfz.index('func _init_vprop'):wfz.index('func _init_hprop')]
hprop=wfz[wfz.index('func _init_hprop'):wfz.index('func _init_tilt_platform')]
ck('(frame_counter >> 1) % 3' in vprop,'Vertical propeller retains retail 0,1,2 delay-1 animation cadence')
ck('(frame_counter >> 1) % 6' in hprop,'Horizontal propeller retains WFZ animation-4 six-frame cadence')
ck('GenesisMath.s16((~d1) & 0xFFFF)' in hprop,'Horizontal propeller airflow applies source 16-bit NOT semantics')

# Flipping/tilting platforms.
tilt=wfz[wfz.index('func _init_tilt_platform'):wfz.index('func _init_turret')]
ck('func _release_tilt_support' in tilt and 'clear_object_support_for(record_index, true)' in tilt,'ObjB6 releases supported Sonic when a flip begins')
ck('func _tick_tilt_animation' in tilt and 'timer <= 72' in tilt and 'platform_frame = 2' in tilt,'ObjB6 implements flip/vertical-hold/return animation phases')
anim=tilt[tilt.index('func _tick_tilt_animation'):tilt.index('func _tick_tilt_platform')]
ck('resolve_solid_box_contact' not in anim and 'resolve_platform_top' not in anim,'ObjB6 has no collision while tilted/animating')
waiting=tilt[tilt.index('func _tick_tilt_platform'):]
ck('resolve_solid_box_contact' in waiting,'ObjB6 retains retail SolidObject only while horizontal/waiting')

# Belt platforms.
belt=wfz[wfz.index('func _init_belt_platform_maker'):wfz.index('func _init_retract_platform')]
children=wfz[wfz.index('func _tick_children'):]
ck('"stage":0,"anim_tick":0' in belt,'ObjBD children begin in source expansion stage')
ck('_set_frame(s, "beltplat", 2)' in children and '_set_frame(s, "beltplat", 1)' in children and '_set_frame(s, "beltplat", 0)' in children,'ObjBD executes 2->1->0 expansion frames')
ck('if stage == 1:' in children and 'q["yf"]' in children,'ObjBD travels only after fully expanding')
ck('resolve_platform_top(x - 0x23, x + 0x23, y - 5, support)' in children,'Fully expanded ObjBD uses retail top-only platform surface')
ck('q["stage"] = 2' in children and 'anim_tick < 6' in children,'ObjBD executes 0->1->2 contraction before deletion')

# Visible hooks.
hooks=sorted((P/'assets/objects/s2_wfz/hook').glob('*.png'))
ck(len(hooks)==13,'All 13 WFZ Obj80 mapping frames are generated')
ck(all(Image.open(q).size==(64,256) for q in hooks),'Obj80 uses centered 64x256 canvas that includes Y+$80 hook extent')
boxes=[Image.open(q).convert('RGBA').getbbox() for q in hooks]
ck(all(bb is not None and (bb[2]-bb[0])>=20 for bb in boxes),'Every Obj80 frame contains the full mechanical hook, not only the 6px chain')
ck('var hook_frame: int = 0 if state == 0' in wfz,'Obj80 uses mapping frame 0 at zero extension exactly like retail')
ck('raw=raw[4*32:]' in imp and "Image.new('RGBA',(64,256)" in imp,'Phase129 importer preserves $3FA/$3FE art fudge and no longer clips the hook piece')

# Wind tunnel / break-panel sequence.
ck('func _tick_s2_wfz_wind_tunnel' in om,'WFZ manager implements global retail WindTunnel effect')
wind=om[om.index('func _tick_s2_wfz_wind_tunnel'):om.index('func _tick_s2_ooz_oil')]
ck('0x1510' in wind and '0x1AF0' in wind and '0x0400' in wind and '0x0580' in wind,'First retail WFZ wind rectangle is exact')
ck('0x20F0' in wind and '0x2500' in wind and '0x0618' in wind and '0x0680' in wind,'Second retail WFZ wind rectangle is exact')
ck('px - 4' in wind and 'p.vel_x = -0x400' in wind and 'p.vel_y = 0' in wind,'Wind tunnel applies source -4px carry, -$400 X velocity and zero Y velocity')
ck('p.input_up' in wind and 'p.input_down' in wind,'Wind tunnel permits retail one-pixel Up/Down steering')
panel=wfz[wfz.index('func _init_break_panel'):wfz.index('# $C2 - boss-area rivet')]
ck('manager.s2_wfz_wind_holding = true' in panel and 'manager.s2_wfz_wind_holding = false' in panel,'ObjC1 sets/clears the WindTunnel_holding_flag bridge while Sonic hangs')
ck('orig_x - 0x14' in panel and 'timer = (subtype & 0xFF) * 0x3C' in panel,'ObjC1 uses source X-$14 hang position and subtype*$3C hold timer')

# Core WFZ source data remains exact.
obj=(P/'data/s1/s2test/wfz1_objects.bin').read_bytes()
ck(len(obj)//6==157,'WFZ retains all 157 final-revision object records')
if S2 is not None:
    for fn,src_rel in [
        ('wfz1_objects.bin','level/objects/WFZ_1.bin'),('wfz1_rings.bin','level/rings/WFZ_1.bin'),('wfz1_start.bin','startpos/WFZ.bin')]:
        ck((P/'data/s1/s2test'/fn).read_bytes()==(S2/src_rel).read_bytes(),f'{fn} remains byte-for-byte retail source')
ck(manifest.get('objects')==157 and manifest.get('layout')==[128,16] and manifest.get('supplement_tile')==0x307,'Manifest retains WFZ object/layout/supplement invariants')
for fn,h in manifest.get('sha256',{}).items():
    ck(sha(P/'data/s1/s2test'/fn)==h,f'Phase129 generated data hash matches manifest: {fn}')

try:
    py_compile.compile(str(P/'tools/import_s2_wfz_phase129.py'),doraise=True); ck(True,'Phase129 WFZ importer compiles')
except Exception as e:
    print(e); ck(False,'Phase129 WFZ importer compiles')

# Structural checks on edited GDScript (no Godot binary is bundled in this environment).
for rel in ['scripts/objects/s2_wfz_object.gd','scripts/objects/object_manager.gd','scripts/main.gd']:
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
