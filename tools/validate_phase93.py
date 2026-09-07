#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, importlib.util, sys, subprocess, tempfile, shutil

PROJECT=Path(__file__).resolve().parents[1]
DATA=PROJECT/'data/s1/s2test'

def load(name,path):
    s=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
terrain=load('terrain',PROJECT/'tools/import_sonic2_level.py')
checks=[]
def check(name,cond):
    checks.append((name,bool(cond))); print(('PASS' if cond else 'FAIL')+': '+name)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: validate_phase93.py <retail Sonic 2 root>')
    src=Path(sys.argv[1])
    layout=terrain.kosinski_decompress((src/'level/layout/CPZ_2.bin').read_bytes())
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        b=row*0x100; fg+=layout[b:b+0x80]; bg+=layout[b+0x80:b+0x100]
    check('CPZ2 foreground is exact retail 128x16 layout', (DATA/'cpz2_layout128.bin').read_bytes()==bytes((127,15))+bytes(fg))
    check('CPZ2 background is exact retail 128x16 layout', (DATA/'cpz2_bg128.bin').read_bytes()==bytes((127,15))+bytes(bg))
    check('CPZ2 object placement binary is byte-identical to retail source', (DATA/'cpz2_objects.bin').read_bytes()==(src/'level/objects/CPZ_2.bin').read_bytes())
    check('CPZ2 ring placement binary is byte-identical to retail source', (DATA/'cpz2_rings.bin').read_bytes()==(src/'level/rings/CPZ_2.bin').read_bytes())
    check('CPZ2 start is source $0060,$012C', (DATA/'cpz2_start.bin').read_bytes()==bytes.fromhex('0060012c'))
    obj=(DATA/'cpz2_objects.bin').read_bytes(); counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    check('CPZ2 retains all 202 placed source objects', len(obj)==202*6)
    check('CPZ2 contains six Obj40 lever springs and three Obj7A water platforms', counts[0x40]==6 and counts[0x7A]==3)
    check('CPZ2 retains one placed Egg Prison for the deferred boss phase', counts[0x3E]==1)
    check('exact retail CPZ underwater palette is packaged', (PROJECT/'data/s1/palette/S2 Chemical Plant Underwater.bin').read_bytes()==(src/'art/palettes/CPZ underwater.bin').read_bytes())

    catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()
    check('CPZ catalog accepts acts 1-2', '_get_sonic2_cpz_test(act)' in catalog and 'act = clampi(act, 1, 2)' in catalog)
    check('CPZ2 uses retail right/bottom bounds $2A80/$720', '0x2780 if act == 1 else 0x2A80' in catalog and '"limit_bottom": 0x720' in catalog)
    check('CPZ1 progression now enters CPZ2', 'Vector2i(ZONE_S2_CPZ_TEST, 2) if act < 2' in catalog)
    check('CPZ2 water and deferred boss/prison flags are isolated to act 2', '"s2_cpz_water": act == 2' in catalog and '"defer_s2_egg_prison": act == 2' in catalog)

    maintext=(PROJECT/'scripts/main.gd').read_text()
    check('N direct warp enters CPZ2', 'KEY_N:' in maintext and '_debug_warp(LevelCatalog.ZONE_S2_CPZ_TEST, 2)' in maintext)

    om=(PROJECT/'scripts/objects/object_manager.gd').read_text()
    check('Obj40 and Obj7A dispatch through the isolated CPZ traversal class', '0x32, 0x40, 0x6B' in om and '0x78, 0x7A, 0x7B' in om)
    check('CPZ2 Egg Prison remains inert until boss phase', 'defer_s2_egg_prison' in om and 'return S2UnsupportedObjectClass.new()' in om)
    check('CPZ2 water initializes at source $710', 'water_surface_y = 0x710' in om and 'water_actual_y = 0x710' in om)
    check('DynamicWaterCPZ2 changes target to $510 at camera X $1DE0', '0x510 if screen_x >= 0x1DE0 else 0x710' in om)
    check('CPZ2 water approaches its target one pixel per frame', 'water_actual_y += 1' in om and 'water_actual_y -= 1' in om)
    check('LZ wind/slide features are not accidentally applied to CPZ2', 'if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_LZ:' in om)

    player=(PROJECT/'scripts/player/sonic_player.gd').read_text()
    check('underwater movement is driven by water_enabled rather than LZ zone identity', 'var has_water := object_manager != null and bool(object_manager.water_enabled)' in player)
    water=(PROJECT/'scripts/render/lz_water_palette.gd').read_text()
    cycler=(PROJECT/'scripts/render/level_palette_cycler.gd').read_text()
    check('water palette shader supports CPZ2 and its dedicated source palette', 'ZONE_S2_CPZ_TEST and act == 2' in water and 'S2 Chemical Plant Underwater.bin' in water)
    check('CPZ2 palette cycler loads and updates the underwater CRAM model', 'cpz_wet_path' in cycler and 'underwater_palette[int(idx)]' in cycler)

    trav=(PROJECT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    check('tube release marks the VBlank before relinquishing object control', 'manager.mark_s2_pipe_exit_frame()' in trav and 'p.object_control_override = false' in trav)
    check('Obj7B suppresses only same-frame spring contact after tube release', 'manager.s2_pipe_exit_blocked_this_frame()' in trav and 'not current_frame_one and not just_left_tube' in trav)
    check('Obj40 uses the retail 40-byte slope tables and $400 base launch', 'LEVER_SLOPE_DIAG' in trav and 'LEVER_SLOPE_FLAT' in trav and 'p.vel_y = -0x400 - kick' in trav)
    check('Obj40 subtype twirl is treated as an upward-diagonal spring, not a side shove', 'p.begin_s2_spring_visual(subtype, 3)' in trav)
    check('Obj7A source CPZ2 subtype groups 0/6/$C are implemented', 'if subtype == 6:' in trav and 'elif subtype == 0x0C:' in trav and 'water_platform_min_x' in trav)
    check('new Obj40/Obj7A source-rendered graphics are packaged', all((PROJECT/f'assets/objects/s2_cpz/{f}/{n}').is_file() for f,n in [('lever_spring','00.png'),('lever_spring','01.png'),('water_platform','00.png')]))

    # Verify the previously user-confirmed CPZ1 source files remain byte-identical to Phase90 manifest hashes.
    import json
    m=json.loads((DATA/'phase90_cpz1_manifest.json').read_text())
    check('verified CPZ1 terrain/object/ring/start payloads remain unchanged', all(sha(DATA/name)==digest for name,digest in m['output_sha256'].items()))

    passed=sum(c for _,c in checks); print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
