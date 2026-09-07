#!/usr/bin/env python3
from pathlib import Path
import sys, re, json, zipfile
P=Path(__file__).resolve().parents[1]
SRC=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(name, cond, detail=''):
    checks.append(bool(cond)); print(('PASS' if cond else 'FAIL')+': '+name+((' — '+str(detail)) if detail else ''))

def text(rel): return (P/rel).read_text(errors='replace')

pal=text('scripts/render/level_palette_cycler.gd')
bg=text('scripts/render/ghz_background_renderer.gd')
cam=text('scripts/camera/sonic_camera.gd')
cat=text('scripts/data/level_catalog.gd')
mgr=text('scripts/objects/object_manager.gd')
plat=text('scripts/objects/s2_ehz_platform_object.gd')
rock=text('scripts/objects/s2_cpz_traversal_object.gd')
htz=text('scripts/objects/s2_htz_object.gd')
main=text('scripts/main.gd')

ck('HTZ PalCycle writes retail line2+$06 -> indices 19/20', '_write_run(level.palette, 19' in pal)
ck('HTZ PalCycle writes retail line2+$1C -> indices 30/31', '_write_run(level.palette, 30' in pal)
ck('Old incorrect HTZ palette destinations removed', '_write_run(level.palette, 35' not in pal and '_write_run(level.palette, 46' not in pal)
ck('HTZ background preserves exact 128-line far band', 'if y < 128:' in bg)
ck('HTZ background uses exact lower source run lengths', '[3,5,7,8,10,15,16,16,16]' in bg)
ck('HTZ autonomous cloud counter advances +4', 's2_htz_cloud_counter = (s2_htz_cloud_counter + 4)' in bg)
ck('HTZ lower interpolation uses exact source step multipliers', '[17,21,25,33,41,53,65,81,97]' in bg)
ck('HTZ scroll samples Genesis H-scroll with correct sign', 'source_x: int = posmod(-scroll_value' in bg)
ck('HTZ quake switches to unified source camera scroll', 'camera_model.s2_htz_quake_active' in bg and 'quake_source_x' in bg)
ck('HTZ catalog enables Act 1 retail dynamic event', '"dynamic_events": "s2_htz1"' in cat)
for v in ['s2_htz_quake_active','s2_htz_bg_y_offset','s2_htz_terrain_direction','s2_htz_terrain_delay']:
    ck('HTZ camera state '+v, v in cam)
for val in ['0x1800','0x1978','0x1E00','0x1F00','0x140','0xE0','0x78']:
    ck('HTZ LevEvents constant '+val, val in cam)
ck('Main mirrors HTZ earthquake offset into object runtime', 'object_manager.htz_bg_y_offset = sonic_camera.s2_htz_bg_y_offset' in main)
ck('Object $18 selects HTZ source art', '"s2_htz/platform"' in plat)
ck('Object $18 HTZ full-solid y radius is $30', '0x28 if use_arz_art else 0x30' in plat)
ck('Object $32 selects HTZ rock source art', 's2_htz/rock/00.png' in rock and 'use_htz_breakable_rock' in rock)
ck('Object $32 HTZ width is retail $18', '0x18 if use_htz_breakable_rock else 0x10' in rock)
ck('HTZ object class is preloaded', 'S2HTZObjectClass' in mgr)
ck('HTZ-specific IDs route only for s2_htz', 'bool(level_definition.get("s2_htz", false))' in mgr and '0x14, 0x16, 0x2F, 0x30, 0x31, 0x92, 0x95, 0x96' in mgr)
for oid in ['0x14','0x16','0x2F','0x30','0x31','0x92','0x95','0x96']:
    ck('HTZ object implementation contains '+oid, oid in htz)
for folder,minimum in [('platform',2),('rock',1),('seesaw',4),('seesaw_ball',2),('lift',5),('smash_ground',10),('spiker',5),('sol',5),('rexon',4)]:
    files=list((P/'assets/objects/s2_htz'/folder).glob('*.png'))
    ck('HTZ source-rendered '+folder+' frames', len(files)>=minimum and all(f.stat().st_size>100 for f in files), len(files))

obj=(P/'data/s1/s2test/htz1_objects.bin').read_bytes()
counts={}
for o in range(0,len(obj),6): counts[obj[o+4]]=counts.get(obj[o+4],0)+1
shared={0x03,0x0D,0x18,0x1C,0x26,0x2D,0x32,0x36,0x41,0x74,0x79,0x84}
htz_ids={0x14,0x16,0x2F,0x30,0x31,0x92,0x95,0x96}
covered=sum(n for k,n in counts.items() if k in shared|htz_ids)
ck('HTZ1 native placement coverage reaches 144/144', covered==144, covered)
manifest=json.loads((P/'data/s1/s2test/phase106_htz_object_art_manifest.json').read_text())
ck('Phase106 HTZ art manifest present', manifest.get('phase')==106 and len(manifest.get('files',{}))>=30, len(manifest.get('files',{})))

if SRC:
    asm=(SRC/'s2.asm').read_text(errors='replace')
    ck('Retail PalCycle source uses Normal_palette_line2+6', '(Normal_palette_line2+6)' in asm)
    ck('Retail PalCycle source uses Normal_palette_line2+$1C', '(Normal_palette_line2+$1C)' in asm)
    ck('Retail HTZ background counter advances +4', 'addq.w\t#4,(TempArray_LayerDef+$22).w' in asm)
    ck('Retail LevEvents HTZ start threshold $1800', 'LevEvents_HTZ_Routine1:' in asm and 'cmpi.w\t#$1800,(Camera_X_pos).w' in asm)
    ck('Retail LevEvents HTZ quake threshold $1978', 'cmpi.w\t#$1978,(Camera_X_pos).w' in asm)
    ck('Retail Obj18 HTZ mapping exists', (SRC/'mappings/sprite/obj18_a.bin').exists())
    ck('Retail HTZ rock art exists', (SRC/'art/nemesis/Rock from HTZ.bin').exists())
    ck('HTZ placement stream remains byte-identical', obj==(SRC/'level/objects/HTZ_1.bin').read_bytes())

passed=sum(checks); print(f'\n{passed}/{len(checks)} checks passed')
raise SystemExit(0 if passed==len(checks) else 1)
