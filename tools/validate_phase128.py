#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
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
bg=txt('scripts/render/ghz_background_renderer.gd')
cat=txt('scripts/data/level_catalog.gd')
gpal=txt('scripts/data/genesis_palette.gd')
ldata=txt('scripts/data/ghz_level_data.gd')
imp=txt('tools/import_s2_wfz_phase128.py')
manifest=json.loads((P/'data/s1/s2test/phase128_wfz_manifest.json').read_text())

ck('Native Sonic 1 Phase 128' in main,'Debug overlay identifies Phase128')
ck(manifest.get('phase')==128 and manifest.get('level')=='Wing Fortress Zone','Phase128 WFZ manifest identifies correction pass')
ck((P/'PHASE128_SONIC2_WING_FORTRESS_CORRECTIONS.md').exists(),'Phase128 implementation notes exist')

# Blocking runtime error.
ck('manager.camera' not in wfz,'WFZ objects never access nonexistent ObjectManager.camera')
ck('var s2_wfz_bg_x_offset: int = 0' in om and 'var s2_wfz_bg_y_offset: int = 0' in om,'ObjectManager exposes WFZ event background offsets')
ck('object_manager.s2_wfz_bg_x_offset = sonic_camera.s2_wfz_bg_x_offset' in main,'Main copies WFZ camera X offset before object execution')
ship=wfz[wfz.index('func _tick_ship_fire'):wfz.index('func _init_belt_platform_maker')]
ck('manager.s2_wfz_bg_x_offset' in ship and 'manager.camera' not in ship,'ObjBC ship fire consumes copied WFZ background offset')

# Background/palette.
ck('mode in ["s2scz", "s2wfz"]' in bg,'WFZ Plane-B empty cells use shared SCZ/WFZ sky palette line')
ck('"background_mode": "s2wfz", "backdrop_palette_index": 32' in cat,'WFZ window clear color is palette index 32')
ck('"palette_line0": "palette/S2 Sonic and Tails.bin"' in cat,'WFZ selects retail S2 Sonic/Tails CRAM line 0')
ck('sonic_palette_path: String = "palette/Sonic.bin"' in gpal,'Generic palette loader retains S1 default while permitting a level line-0 override')
ck('definition.get("palette_line0", "palette/Sonic.bin")' in ldata,'Level data consumes optional palette-line0 override')
ck((P/'data/s1/palette/S2 Sonic and Tails.bin').stat().st_size==32,'S2 Sonic/Tails line-0 palette is 32 bytes')
ck((P/'data/s1/palette/S2 Wing Fortress Zone.bin').stat().st_size==96,'WFZ zone palette remains exact three CRAM lines')
if S2 is not None:
    ck((P/'data/s1/palette/S2 Sonic and Tails.bin').read_bytes()==(S2/'art/palettes/SonicAndTails.bin').read_bytes(),'S2 line-0 palette is byte-for-byte retail source')
    ck((P/'data/s1/palette/S2 Wing Fortress Zone.bin').read_bytes()==(S2/'art/palettes/WFZ.bin').read_bytes(),'WFZ lines 1-3 palette is byte-for-byte retail source')

# Clucker priority.
base=wfz[wfz.index('func _init_clucker_base'):wfz.index('func _tick_clucker_base')]
bird=wfz[wfz.index('func _init_clucker()'):wfz.index('func _tick_clucker()')]
ck('_new_sprite("clucker", 12, 3)' in base,'Clucker base renders above bird')
ck('_new_sprite("clucker", 21, 2)' in bird,'Clucker bird renders behind base')

# Obj19 exact top-only platform/carry and source placement/motion.
plat=wfz[wfz.index('func _init_platform'):wfz.index('func _init_conveyor')]
ck('move_with_supported_object(record_index, nx-old_x, ny-old_y' in plat,'Obj19 carries supported Sonic by old-to-new X/Y displacement')
ck('resolve_platform_top(nx-active_width, nx+active_width, ny-0x11, record_index)' in plat,'Obj19 uses PlatformObject-style top-only collision')
ck('resolve_solid_box_contact' not in plat,'Obj19 has no full box-solid collision')
for off in ('0x08','0x1C','0x38','0x3C'):
    ck(f's2_source_osc_byte({off})' in plat,f'Obj19 retains retail Oscillating_Data source offset {off}')
obj=(P/'data/s1/s2test/wfz1_objects.bin').read_bytes()
records=[obj[i:i+6] for i in range(0,len(obj),6)]
p19=[r for r in records if len(r)==6 and r[4]==0x19]
ck(len(p19)==16,'WFZ retains all 16 retail Obj19 platform placement records')
if S2 is not None:
    ck(obj==(S2/'level/objects/WFZ_1.bin').read_bytes(),'WFZ full object stream remains byte-for-byte retail source')

# Hook correction.
ck('raw=raw[4*32:]' in imp and 'raw=bytes(4*32)+raw' not in imp,'Hook $3FA/$3FE art fudge slices four leading source tiles instead of prepending blanks')
hooks=sorted((P/'assets/objects/s2_wfz/hook').glob('*.png'))
ck(len(hooks)==13,'All 13 WFZ hook mapping frames are generated')
ck(all(Image.open(q).convert('RGBA').getbbox() is not None for q in hooks),'Every generated WFZ hook frame contains visible pixels')

# Belt platform correction.
beltinit=wfz[wfz.index('func _init_belt_platform_maker'):wfz.index('func _tick_belt_platform_maker')]
children=wfz[wfz.index('func _tick_children'):]
ck('visible = true' in beltinit,'Belt maker parent remains visible so child sprites render')
ck('resolve_platform_top(x-0x23, x+0x23, y-5, support)' in children,'Belt child uses retail top-only PlatformObject collision')
ck('resolve_solid_box_contact(x, y, 0x23, 5' not in children,'Belt child is no longer fully box-solid')

# Other source PlatformObject users corrected without changing source-solid B6.
retract=wfz[wfz.index('func _tick_retract_platform'):wfz.index('func _init_launcher')]
launcher=wfz[wfz.index('func _tick_launcher'):wfz.index('func _init_break_panel')]
tilt=wfz[wfz.index('func _tick_tilt_platform'):wfz.index('func _init_turret')]
ck('resolve_platform_top(orig_x-0x23, orig_x+0x23, orig_y-0x19' in retract,'ObjBE extended platform uses top-only PlatformObject collision')
ck('resolve_platform_top' in launcher and 'resolve_solid_box_contact' not in launcher,'ObjC0 launcher uses top-only PlatformObject collision')
ck('resolve_solid_box_contact' in tilt,'ObjB6 tilting platform deliberately retains retail SolidObject behavior')

# Tornado/Tails pilot.
ck('const TAILS_PILOT_SEQUENCE' in wfz and 'var pilot: Sprite2D' in wfz,'WFZ Tornado has source pilot animation state')
torn=wfz[wfz.index('func _init_tornado'):wfz.index('func _init_vprop')]
ck('pilot = _new_sprite("pilot", 0, 4)' in torn and 'pilot.position = Vector2(-36, 0)' in torn,'WFZ Tornado instantiates Tails pilot at reconstructed mapping offset')
ck('TAILS_PILOT_SEQUENCE[pilot_step]' in torn and '/ 9' in torn,'WFZ pilot advances with source nine-frame cadence')
pilot_w=sorted((P/'assets/objects/s2_wfz/pilot').glob('*.png'))
pilot_s=sorted((P/'assets/objects/s2_scz/pilot').glob('*.png'))
ck(len(pilot_w)==5,'WFZ includes all five Tails pilot frames')
ck(len(pilot_s)==5 and [sha(x) for x in pilot_w]==[sha(x) for x in pilot_s],'WFZ pilot frames exactly reuse verified SCZ reconstruction')

# Importer/data integrity.
try:
    py_compile.compile(str(P/'tools/import_s2_wfz_phase128.py'),doraise=True); ck(True,'Phase128 WFZ importer compiles')
except Exception: ck(False,'Phase128 WFZ importer compiles')
ck(manifest.get('objects')==157,'Phase128 manifest retains all 157 WFZ records')
ck(manifest.get('layout')==[128,16],'Phase128 manifest retains exact 128x16 WFZ layouts')
ck(manifest.get('supplement_tile')==0x307,'Phase128 retains WFZ supplement at tile $307')
for fn,h in manifest.get('sha256',{}).items():
    ck(sha(P/'data/s1/s2test'/fn)==h,f'Phase128 generated data hash matches manifest: {fn}')

# Basic GDScript structural checks for touched files (Godot binary is not bundled).
for rel in ['scripts/objects/s2_wfz_object.gd','scripts/objects/object_manager.gd','scripts/main.gd','scripts/render/ghz_background_renderer.gd','scripts/data/genesis_palette.gd','scripts/data/ghz_level_data.gd','scripts/data/level_catalog.gd']:
    s=txt(rel)
    ck('<<<<<<<' not in s and '=======' not in s and '>>>>>>>' not in s,f'{rel} has no merge-conflict markers')
    ck(s.count('(')==s.count(')'),f'{rel} parentheses balance')
    ck(s.count('[')==s.count(']'),f'{rel} brackets balance')
    ck(s.count('{')==s.count('}'),f'{rel} braces balance')

passed=sum(1 for ok,_ in checks if ok)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' - '+msg)
    raise SystemExit(1)
