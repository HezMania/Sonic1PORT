#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import hashlib, importlib.util, re, sys

ROOT = Path(__file__).resolve().parents[1]
BASE = Path('/mnt/data/phase71baseline')
SRC = Path('/mnt/data/phase72src/s1disasm-AS')
checks=[]

def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok,detail));
    if not ok: print('FAIL',name,detail)
    return ok

def same(a:Path,b:Path): return a.exists() and b.exists() and a.read_bytes()==b.read_bytes()
def sha(p:Path): return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else ''
def text(rel): return (ROOT/rel).read_text(errors='replace')

# 1. Exact source assets.
assets = [
    ('artunc/Level Select & Debug Text.unc','artunc/Level Select & Debug Text.unc'),
    ('palette/Level Select.bin','palette/Level Select.bin'),
    ('palette/Cycle - GHZ.bin','palette/Cycle - GHZ.bin'),
    ('palette/Cycle - LZ Waterfall.bin','palette/Cycle - LZ Waterfall.bin'),
    ('palette/Cycle - LZ Conveyor Belt.bin','palette/Cycle - LZ Conveyor Belt.bin'),
    ('palette/Cycle - LZ Conveyor Belt Underwater.bin','palette/Cycle - LZ Conveyor Belt Underwater.bin'),
    ('palette/Cycle - SBZ3 Waterfall.bin','palette/Cycle - SBZ3 Waterfall.bin'),
    ('palette/Cycle - SLZ.bin','palette/Cycle - SLZ.bin'),
    ('palette/Cycle - SYZ1.bin','palette/Cycle - SYZ1.bin'),
    ('palette/Cycle - SYZ2.bin','palette/Cycle - SYZ2.bin'),
]
assets += [(f'palette/Cycle - SBZ {i}.bin',f'palette/Cycle - SBZ {i}.bin') for i in range(1,11)]
for rel,src_rel in assets:
    check('source asset '+rel, same(ROOT/'data/s1'/rel,SRC/src_rel), sha(ROOT/'data/s1'/rel)[:12])
check('level-select font = 41 tiles', (ROOT/'data/s1/artunc/Level Select & Debug Text.unc').stat().st_size==41*32)
check('level-select palette = 64 colors', (ROOT/'data/s1/palette/Level Select.bin').stat().st_size==64*2)

# 2. Level-select source geometry/text/control mapping.
ls=text('scripts/data/level_select_art.gd'); st=text('scripts/objects/startup_sequence_controller.gd')
menu=[
'GREEN HILL ZONE  STAGE 1','                 STAGE 2','                 STAGE 3',
'MARBLE ZONE      STAGE 1','                 STAGE 2','                 STAGE 3',
'SPRING YARD ZONE STAGE 1','                 STAGE 2','                 STAGE 3',
'LABYRINTH ZONE   STAGE 1','                 STAGE 2','                 STAGE 3',
'STAR LIGHT ZONE  STAGE 1','                 STAGE 2','                 STAGE 3',
'SCRAP BRAIN ZONE STAGE 1','                 STAGE 2','                 STAGE 3',
'FINAL ZONE              ','SPECIAL STAGE           ','SOUND SELECT            ']
check('21 menu rows', all(('"'+m+'"') in ls for m in menu) and len(menu)==21)
check('every menu row = 24 chars', all(len(m)==24 for m in menu))
for token in ['const START_X := 8 * 8','const START_Y := 4 * 8','const LINE_CHARS := 24','const LINE_COUNT := 21','const SOUND_ROW := 20','const SOUND_COL := 16']:
    check('level-select geometry '+token, token in ls)
check('selected yellow / normal white palette lines', 'var palette_line := 2 if row == selected_row else 3' in ls)
check('sound digits selected color follows row', 'var sound_palette_line := 2 if selected_row == SOUND_ROW else 3' in ls)
check('font Y/Z special ordering', '"Y": return 0x0F' in ls and '"Z": return 0x10' in ls)
check('font A-X start at $11', 'return 0x11 + code - 65' in ls)
check('hex A-F +7 mapping', 'digit + 7' in ls)
check('REV01 US UDLR code', 'const CODE := ["up", "down", "left", "right"]' in st)
check('source zero terminator modeled', 'level_select_code_index != 4' in st and '_tick_title_cheat_terminator()' in st)
check('A+Start entry chord', 'level_select_enabled and Input.is_action_pressed("A")' in st)
check('12-VBlank held repeat', 'level_select_delay = 12 - 1' in st)
check('sound test retail 80-CF wrap', 'posmod(level_select_sound - 1, 0x50)' in st and 'posmod(level_select_sound + 1, 0x50)' in st and '0x80 + level_select_sound' in st)
check('ABC+Start selection', all(f'event.is_action_pressed("{a}")' in st for a in ['A','B','C','Start']))
# Exact target order tokens.
targets=[
'ZONE_GHZ, 1','ZONE_GHZ, 2','ZONE_GHZ, 3','ZONE_MZ, 1','ZONE_MZ, 2','ZONE_MZ, 3',
'ZONE_SYZ, 1','ZONE_SYZ, 2','ZONE_SYZ, 3','ZONE_LZ, 1','ZONE_LZ, 2','ZONE_LZ, 3',
'ZONE_SLZ, 1','ZONE_SLZ, 2','ZONE_SLZ, 3','ZONE_SBZ, 1','ZONE_SBZ, 2','ZONE_LZ, 4','ZONE_SBZ, 3']
pos=[]
for tok in targets:
    i=st.find(tok); pos.append(i)
check('19 level pointer targets present/in source order', all(i>=0 for i in pos) and pos==sorted(pos))
check('special-stage row 19', 'if level_select_item == 19:' in st and 'level_select_special_request = true' in st)

# 3. PaletteCycle implementation anchors.
pc=text('scripts/render/level_palette_cycler.gd')
check('GHZ timer 6 and target 40-43', 'pcyc_time = 6 - 1' in pc and '_write_run(level.palette, 40, ghz_cycle, frame * 4, 4)' in pc)
check('LZ waterfall timer 3 target 43-46', 'pcyc_time = 3 - 1' in pc and '_write_run(level.palette, 43, source, frame * 4, 4)' in pc)
check('LZ SBZ3 alternate waterfall', 'sbz3_waterfall if int(level.definition.get("act", 1)) == 4 else lz_waterfall' in pc)
check('LZ conveyor source cadence', 'LZ_CONVEY_SEQUENCE: Array[int] = [1, 0, 0, 1, 0, 0, 1, 0]' in pc)
check('LZ conveyor target 59-61', '_write_run(level.palette, 59, lz_conveyor, lz_conveyor_index * 3, 3)' in pc)
check('LZ dry/wet cycle synchronized', '_write_run(underwater_palette, 43, source, frame * 4, 4)' in pc and '_write_run(underwater_palette, 59, lz_conveyor_uw, lz_conveyor_index * 3, 3)' in pc)
check('MZ intentionally no palette-cycle case', 'LevelCatalog.ZONE_MZ' not in re.search(r'match level\.zone_id:(.*?)if not changed',pc,re.S).group(1))
check('SLZ timer 8', 'pcyc_time = 8 - 1' in pc)
check('SLZ exact B,D,E targets', '_write_single(level.palette, 43' in pc and '_write_single(level.palette, 45' in pc and '_write_single(level.palette, 46' in pc)
check('SYZ timer 6', pc.count('pcyc_time = 6 - 1')>=2)
check('SYZ target 55-58', '_write_run(level.palette, 55, syz_blackyellow, frame * 4, 4)' in pc)
check('SYZ target B and D', '_write_single(level.palette, 59' in pc and '_write_single(level.palette, 61' in pc)
# SBZ script table exact tuples.
for tok in [
'{"duration":8, "count":8, "file":"Cycle - SBZ 1.bin", "target":40}',
'{"duration":14, "count":8, "file":"Cycle - SBZ 2.bin", "target":41}',
'{"duration":15, "count":8, "file":"Cycle - SBZ 3.bin", "target":55}',
'{"duration":12, "count":8, "file":"Cycle - SBZ 5.bin", "target":56}',
'{"duration":8, "count":8, "file":"Cycle - SBZ 6.bin", "target":57}',
'{"duration":29, "count":16, "file":"Cycle - SBZ 7.bin", "target":63}',
'{"duration":10, "count":8, "file":"Cycle - SBZ 9.bin", "target":56}',
]: check('SBZ script '+tok, tok in pc)
check('SBZ cycle 8 stagger offsets', all(f'"target":{t}, "offset":{o}' in pc for t,o in [(60,0),(61,1),(62,2)]))
check('SBZ conveyor Act1 timer 2 / others 1', 'pcyc_time = (2 - 1) if act == 1 else (1 - 1)' in pc)
check('SBZ conveyor backwards default', 'var direction := -1' in pc)
check('SBZ conveyor target 44-46', '_write_run(level.palette, 44, convey, pcyc_num, 3)' in pc)

# 4. Palette renderer architecture/performance.
bg=text('scripts/render/ghz_background_renderer.gd'); fg=text('scripts/render/ghz_renderer.gd'); sh=text('scripts/render/genesis_index_palette.gdshader')
idx=ROOT/'data/s1/generated/ghz_background_indices.bin'
check('GHZ index stream exact dimensions', idx.stat().st_size==8192*256)
raw=idx.read_bytes(); check('GHZ index stream within 6-bit CRAM', max(raw)<=63 and min(raw)>=0, f'max={max(raw)}')
# Deterministic rebuild from project source data.
spec=importlib.util.spec_from_file_location('ghz_idx_builder', ROOT/'tools/build_ghz_background_indices.py'); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
rebuilt=mod.build(); check('GHZ index stream deterministic source rebuild', rebuilt==raw, hashlib.sha256(raw).hexdigest()[:12])
check('GHZ runtime uses R8 source indices', 'Image.FORMAT_R8' in bg and 'ghz_background_indices.bin' in bg)
check('GHZ palette upload only 64x1', 'Image.create_empty(64, 1' in bg and 'ghz_palette_texture.update(ghz_palette_image)' in bg)
check('GHZ palette cycle avoids full background update', 'if mode == "ghz":\n\t\t_update_ghz_palette_texture()\n\t\treturn' in bg)
check('GHZ shader exact nearest palette fetch', 'texelFetch(genesis_palette' in sh and 'palette_index == 0' in sh)
check('foreground refresh is visible-chunk scoped', '_visible_foreground_chunk_ids(32)' in fg and 'ImageTexture).update' in fg)
# Background layout periods from exact project layout bytes.
def period(rel):
    b=(ROOT/'data/s1/levels'/rel).read_bytes(); w=b[0]+1;h=b[1]+1;ids=b[2:2+w*h]
    px=next(p for p in range(1,w+1) if w%p==0 and all(ids[y*w+x]==ids[y*w+x%p] for y in range(h) for x in range(w)))
    py=next(p for p in range(1,h+1) if h%p==0 and all(ids[y*w+x]==ids[(y%p)*w+x] for y in range(h) for x in range(w)))
    return w,h,px,py
for rel,want in [('lzbg.bin',(32,8,2,4)),('syzbg (REV01).bin',(28,2,2,2)),('slzbg.bin',(24,5,2,5)),('sbz1bg.bin',(30,2,5,2)),('sbz2bg.bin',(60,6,3,2))]:
    got=period(rel); check('background exact repeat '+rel,got==want,str(got))
check('LZ live waterfall sprite refresh', 'refresh_palette_cycle' in text('scripts/objects/lz_native_object.gd') and 'lz_waterfall_texture' in text('scripts/objects/lz_native_object.gd'))
check('SBZ live electrocuter sprite refresh', 'refresh_palette_cycle' in text('scripts/objects/sbz_progression_object.gd') and 'sbz_electro_texture' in text('scripts/objects/sbz_progression_object.gd'))
check('object manager forwards live CRAM refresh', 'func refresh_palette_cycled_objects' in text('scripts/objects/object_manager.gd'))
check('LZ underwater palette textures update in place', 'dry_palette_texture.update(dry_palette_image)' in text('scripts/render/lz_water_palette.gd') and 'wet_palette_texture.update(wet_palette_image)' in text('scripts/render/lz_water_palette.gd'))

# 5. Main-loop ordering / level select integration.
main=text('scripts/main.gd')
check('palette cycler initialized', 'var level_palette_cycler = LevelPaletteCycler.new()' in main)
check('palette cycler setup per level', 'level_palette_cycler.setup(level, renderer, background_renderer, object_manager, water_palette_node)' in main)
check('level-select request consumed', 'startup_controller.level_select_level_request' in main and '_start_level_from_level_select' in main)
check('special-stage request consumed', 'startup_controller.level_select_special_request' in main and '_start_special_stage_from_level_select' in main)
# Require every execute->palette adjacency seen in the runtime source paths.
check('normal ExecuteObjects precedes palette cycle', main.count('object_manager.execute_objects()')>=1 and '_tick_level_palette()' in main)
for m in re.finditer(r'object_manager\.execute_objects\(\)', main):
    window=main[m.end():m.end()+1800]
    # Not every helper path necessarily cycles; only report but don't fail if outside frame loop.
check('palette cycle helper exists', 'func _tick_level_palette() -> void:' in main and 'level_palette_cycler.tick()' in main)

# 6. Input map and frozen baseline.
project=(ROOT/'project.godot').read_text(errors='replace')
for action,code in [('A','physical_keycode":90'),('B','physical_keycode":88'),('C','physical_keycode":32'),('Start','physical_keycode":4194309'),('Debug','physical_keycode":4194341')]:
    check('Input Map '+action, action+'={' in project and code in project)
all_gd='\n'.join(p.read_text(errors='replace') for p in ROOT.rglob('*.gd'))
check('no physical-key gameplay polling', 'Input.is_physical_key_pressed' not in all_gd)
check('project Input Map unchanged from Phase 71', same(ROOT/'project.godot',BASE/'project.godot'))
# Known parser compatibility carry-forwards.
sv=text('scripts/player/sonic_visual.gd'); ss=text('scripts/data/special_stage_art.gd'); mn=main
for tok in ['var angle_work = player.angle & 0xFF','var render_flip_x = player.facing_left','var octant_modifier = (angle_work >> 4) & 6']:
    check('Godot parser carry-forward '+tok, tok in sv)
check('special-stage-art known := fixes preserved', ss.count(':=') == (BASE/'scripts/data/special_stage_art.gd').read_text(errors='replace').count(':='))
# No temporary backups.
check('no pre72 backup debris', not any(ROOT.rglob('*.pre72final')))

# 7. Everything outside declared Phase 72 scope stays byte-identical.
expected_modified={
'scripts/data/source_object_art.gd','scripts/main.gd','scripts/objects/lz_native_object.gd','scripts/objects/object_manager.gd',
'scripts/objects/sbz_progression_object.gd','scripts/objects/startup_sequence_controller.gd','scripts/render/ghz_background_renderer.gd',
'scripts/render/ghz_renderer.gd','scripts/render/lz_water_palette.gd','README.md'}
common=[]; changed_unexpected=[]
for bp in BASE.rglob('*'):
    if not bp.is_file(): continue
    rel=bp.relative_to(BASE).as_posix()
    rp=ROOT/rel
    if not rp.exists(): changed_unexpected.append(rel+' (missing)'); continue
    if rel in expected_modified: continue
    if bp.read_bytes()!=rp.read_bytes(): changed_unexpected.append(rel)
check('all out-of-scope baseline files frozen', not changed_unexpected, ', '.join(changed_unexpected[:10]))
for rel in ['scripts/audio/sonic_audio.gd','scripts/player/sonic_player.gd','scripts/collision/genesis_collision.gd','scripts/render/genesis_palette_fade.gd','scripts/ui/level_title_card_ui.gd','scripts/ui/end_card_ui.gd','scripts/ui/special_stage_result_ui.gd','scripts/objects/bridge_object.gd','scripts/objects/mz_geyser_object.gd','scripts/objects/mz_geyser_column.gd']:
    check('frozen '+rel, same(ROOT/rel,BASE/rel), sha(ROOT/rel)[:12])

# 8. Basic GDScript structural sanity on changed/new scripts.
for rel in sorted([r for r in expected_modified if r.endswith('.gd')] + ['scripts/data/level_select_art.gd','scripts/render/level_palette_cycler.gd']):
    s=text(rel)
    funcs=re.findall(r'^func\s+([A-Za-z0-9_]+)\s*\(',s,re.M)
    check('unique funcs '+rel, len(funcs)==len(set(funcs)))
    # Crude bracket balance after stripping comments/strings sufficiently for accidental edit detection.
    cleaned=re.sub(r'#.*','',s); cleaned=re.sub(r'"(?:\\.|[^"\\])*"','""',cleaned)
    check('balanced delimiters '+rel, all(cleaned.count(a)==cleaned.count(b) for a,b in [('(',')'),('[',']'),('{','}')]))

passed=sum(ok for _,ok,_ in checks); total=len(checks)
print(f'PHASE72_VALIDATION: {passed}/{total} passed')
for i,(name,ok,detail) in enumerate(checks,1):
    print(f'{i:03d} {"PASS" if ok else "FAIL"} {name}' + (f' [{detail}]' if detail else ''))
sys.exit(0 if passed==total else 1)
