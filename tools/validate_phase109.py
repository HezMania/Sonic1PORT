#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, importlib.util, json, py_compile, sys

P=Path(__file__).resolve().parents[1]
SRC=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(name,cond,detail=''):
    ok=bool(cond); checks.append(ok); print(('PASS' if ok else 'FAIL')+': '+name+((' — '+str(detail)) if detail else ''))
def text(rel): return (P/rel).read_text(errors='replace')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m

spr=text('scripts/objects/s2_spring_object.gd')
plr=text('scripts/player/sonic_player.gd')
bg=text('scripts/render/ghz_background_renderer.gd')
cat=text('scripts/data/level_catalog.gd')
cam=text('scripts/camera/sonic_camera.gd')
main=text('scripts/main.gd')

# Retail Obj41 contact semantics: broad d1 shell != narrow width_pixels ride test.
ck('Obj41 up uses retail d1=$1B/d2=$08/d3=$10/width=$10','resolve_s2_spring_top(spawn_x, spawn_y, 0x1B, 0x08, 0x10, 0x10' in spr)
ck('Obj41 up broad fallback cannot create top support','resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x08, false' in spr)
ck('Player has dedicated retail S2 spring top resolver','func resolve_s2_spring_top' in plr)
ck('Retail spring resolver uses center reach','x_from_left: int = x - center_x + contact_center_reach' in plr)
ck('Retail spring resolver keeps +4 SolidObject Y bias','y - center_y + 4 + d2_total' in plr)
ck('Retail spring resolver performs narrow width_pixels test','x < center_x - landing_half_width or x >= center_x + landing_half_width' in plr)
ck('Retail spring resolver snaps with source -1 correction','center_y - jump_half_height - height_radius - 1' in plr)
ck('Retail spring stood-on path uses d3','center_y - walk_half_height' in plr)

# Dynamic_HTZ mountain DMA implementation.
ck('HTZ renderer loads sparse PatchHTZTiles RAM image','s2_htz_mountain_ram.bin' in bg)
ck('HTZ renderer loads exact Dynamic_HTZ word table','s2_htz_mountain_dma_offsets.bin' in bg)
ck('HTZ renderer implements Dynamic_HTZ selector','func _update_s2htz_dynamic_mountains' in bg and 'selector_word' in bg and '% 0x30' in bg)
ck('HTZ selector uses source transposed word index','(remainder & 7) * 12 + ((remainder & 0x38) >> 3)' in bg)
ck('HTZ dynamic DMA writes tiles $500-$517','(0x500 + i * 4)' in bg and 'refresh_s2test_art_range(0x500, 0x18)' in bg)
ck('HTZ dynamic mountains update every HTZ background tick','_update_s2htz_dynamic_mountains(camera_x)' in bg)
ram=P/'data/s1/s2test/s2_htz_mountain_ram.bin'; offs=P/'data/s1/s2test/s2_htz_mountain_dma_offsets.bin'
ck('HTZ sparse mountain RAM file exists at $4980 bytes',ram.is_file() and ram.stat().st_size==0x4980,ram.stat().st_size if ram.exists() else -1)
ck('HTZ mountain DMA table has 96 words',offs.is_file() and offs.stat().st_size==192,offs.stat().st_size if offs.exists() else -1)

# HTZ2 import/progression.
manifest_path=P/'data/s1/s2test/phase109_htz2_manifest.json'
ck('Phase109 manifest exists',manifest_path.is_file())
manifest=json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
ck('Phase109 manifest identifies HTZ2',manifest.get('phase')==109 and manifest.get('level')=='Hill Top Zone Act 2')
ck('HTZ2 start is retail $0060,$06AF',manifest.get('start')==[0x60,0x6AF],manifest.get('start'))
ck('HTZ2 right bound is retail $3280',manifest.get('limits',{}).get('right')==0x3280)
ck('HTZ2 has 259 retail placements',manifest.get('objects')==259,manifest.get('objects'))
ck('HTZ2 has 259/259 native placed-object coverage',manifest.get('native_placement_coverage')==259,manifest.get('native_placement_coverage'))
for n in ['layout128','bg128','objects','rings','start','map16','map128','collision_primary','collision_secondary','art']:
    f=P/f'data/s1/s2test/htz2_{n}.bin'
    ck('HTZ2 data exists '+n,f.is_file() and f.stat().st_size>0)
ck('Catalog accepts both HTZ acts','clampi(requested_act, 1, 2)' in cat and 'var prefix: String = "htz2" if act == 2 else "htz1"' in cat)
ck('Catalog uses retail HTZ2 $3280 bound','0x3280 if act == 2 else 0x2800' in cat)
ck('HTZ1 progresses to HTZ2','Vector2i(ZONE_S2_HTZ_TEST, 2) if act < 2' in cat)
ck('Z is direct HTZ2 warp key','KEY_Z:' in main and '_debug_warp(LevelCatalog.ZONE_S2_HTZ_TEST, 2)' in main)
ck('HTZ2 capsule remains boss-gated','"s2_egg_prison_requires_boss": act == 2' in cat)

# HTZ2 traversal event foundation (boss routines intentionally next pass).
ck('Camera routes HTZ2 dynamic events','"s2_htz2": _dle_s2_htz2()' in cam)
ck('HTZ2 earthquake starts at retail $14C0','screen_x < 0x14C0' in cam[cam.find('func _dle_s2_htz2'):cam.find('func _start_s2_htz_quake')])
ck('HTZ2 upper/lower initial offsets are retail $2C0/$300','_start_s2_htz2_quake(0x2C0)' in cam and '_start_s2_htz2_quake(0x300)' in cam)
ck('HTZ2 upper movement threshold is retail $1678','_tick_s2_htz2_quake_motion(0x2C0, 0x1678, 0x1A00)' in cam)
ck('HTZ2 lower movement threshold is retail $15F0','_tick_s2_htz2_quake_motion(0x300, 0x15F0, 0x1AC0)' in cam)
ck('HTZ2 traversal stops before dedicated boss pass at $2B00','screen_x >= 0x2B00' in cam and 'dle_routine = 0x0A' in cam)

# Source equality / authoritative data.
if SRC:
    imp=load('terrain109v',P/'tools/import_sonic2_level.py')
    src_obj=(SRC/'level/objects/HTZ_2.bin').read_bytes(); obj=(P/'data/s1/s2test/htz2_objects.bin').read_bytes()
    ck('HTZ2 object stream byte-identical to retail',obj==src_obj)
    ck('HTZ2 ring stream byte-identical to retail',(P/'data/s1/s2test/htz2_rings.bin').read_bytes()==(SRC/'level/rings/HTZ_2.bin').read_bytes())
    ck('HTZ2 start byte-identical to retail',(P/'data/s1/s2test/htz2_start.bin').read_bytes()==(SRC/'startpos/HTZ_2.bin').read_bytes())
    raw=imp.kosinski_decompress((SRC/'level/layout/HTZ_2.bin').read_bytes())
    fg=bytearray(); bgraw=bytearray()
    for row in range(16):
        o=row*0x100; fg+=raw[o:o+0x80]; bgraw+=raw[o+0x80:o+0x100]
    ck('HTZ2 foreground layout byte-identical after source split',(P/'data/s1/s2test/htz2_layout128.bin').read_bytes()==bytes((127,15))+bytes(fg))
    ck('HTZ2 background layout byte-identical after source split',(P/'data/s1/s2test/htz2_bg128.bin').read_bytes()==bytes((127,15))+bytes(bgraw))
    asm=(SRC/'s2.asm').read_text(errors='replace')
    seg=asm[asm.find('Obj41_Up:'):asm.find('Obj41_Horizontal:')]
    ck('Retail Obj41 source confirms d1=$1B/d2=8/d3=$10','move.w\t#$1B,d1' in seg and 'move.w\t#8,d2' in seg and 'move.w\t#$10,d3' in seg)
    ck('Retail SolidObject top path uses width_pixels', 'move.b\twidth_pixels(a0),d1' in asm[asm.find('loc_19B56:'):asm.find('loc_19B8E:')])
    dyn=asm[asm.find('Dynamic_HTZ:'):asm.find('Dynamic_CNZ:')]
    ck('Retail Dynamic_HTZ uses divisor $30','divu.w\t#$30,d0' in dyn)
    ck('Retail Dynamic_HTZ DMAs six four-tile groups','moveq\t#5,d5' in dyn and 'tiles_to_bytes(4)/2' in dyn)
    ev=asm[asm.find('LevEvents_HTZ2:'):asm.find('LevEvents_HTZ2_Prepare:')]
    ck('Retail HTZ2 event contains $14C0/$1678/$15F0 thresholds',all(x in ev for x in ['#$14C0','#$1678','#$15F0']))

# Generated hashes and script syntax.
for rel,want in manifest.get('sha256',{}).items():
    f=P/'data/s1/s2test'/rel
    ck('Phase109 generated hash '+rel,f.is_file() and sha(f)==want)
for rel in ['tools/import_s2_htz2_phase109.py','tools/validate_phase109.py']:
    try:
        py_compile.compile(str(P/rel),doraise=True); good=True; detail=''
    except Exception as e:
        good=False; detail=e
    ck(rel+' compiles',good,detail)

print(f'\n{sum(checks)}/{len(checks)} checks passed')
raise SystemExit(0 if all(checks) else 1)
