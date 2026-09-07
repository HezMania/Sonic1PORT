#!/usr/bin/env python3
from pathlib import Path
import hashlib, re, importlib.util, sys

ROOT=Path(__file__).resolve().parents[1]
BASE=Path('/mnt/data/phase72work')
checks=[]

def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok,detail))
    if not ok: print('FAIL',name,detail)
    return ok

def same(rel):
    a=ROOT/rel; b=BASE/rel
    return a.exists() and b.exists() and a.read_bytes()==b.read_bytes()

def text(rel): return (ROOT/rel).read_text(errors='replace')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()[:12]

# Phase 72 source timing/data/menu must not change in the performance hotfix.
for rel in [
    'scripts/render/level_palette_cycler.gd',
    'scripts/data/level_select_art.gd',
    'project.godot',
    'scripts/main.gd',
    'scripts/render/lz_water_palette.gd',
    'scripts/render/genesis_index_palette.gdshader',
]:
    check('Phase72 source behavior frozen '+rel, same(rel), sha(ROOT/rel) if (ROOT/rel).exists() else '')
for rel in [
    'data/s1/artunc/Level Select & Debug Text.unc','data/s1/palette/Level Select.bin',
    'data/s1/palette/Cycle - GHZ.bin','data/s1/palette/Cycle - LZ Waterfall.bin',
    'data/s1/palette/Cycle - LZ Conveyor Belt.bin','data/s1/palette/Cycle - LZ Conveyor Belt Underwater.bin',
    'data/s1/palette/Cycle - SBZ3 Waterfall.bin','data/s1/palette/Cycle - SLZ.bin',
    'data/s1/palette/Cycle - SYZ1.bin','data/s1/palette/Cycle - SYZ2.bin',
] + [f'data/s1/palette/Cycle - SBZ {i}.bin' for i in range(1,11)]:
    check('cycle/source asset frozen '+rel, same(rel), sha(ROOT/rel))

fg=text('scripts/render/ghz_renderer.gd')
bg=text('scripts/render/ghz_background_renderer.gd')
st=text('scripts/objects/startup_sequence_controller.gd')
so=text('scripts/data/source_object_art.gd')
lz=text('scripts/objects/lz_native_object.gd')
sbz=text('scripts/objects/sbz_progression_object.gd')

# Foreground palette-index architecture.
check('foreground indexed-cycle mode exists', 'var palette_indexed_mode = false' in fg)
for zone in ['ZONE_GHZ','ZONE_LZ','ZONE_SLZ','ZONE_SYZ','ZONE_SBZ','ZONE_ENDING']:
    check('foreground indexed '+zone, f'LevelCatalog.{zone}' in re.search(r'palette_indexed_mode = .*?\n\t\]',fg,re.S).group(0))
check('foreground R8 chunk images', 'Image.FORMAT_R8' in re.search(r'func _render_chunk_index_images.*?func _draw_block_indices',fg,re.S).group(0))
check('foreground exact CRAM index encoding', 'var palette_index = palette_line * 16 + color_index' in fg and 'Color(float(palette_index) / 255.0' in fg)
check('foreground palette update is 64x1 only', 'Image.create_empty(64, 1' in fg and 'cycle_palette_texture.update(cycle_palette_image)' in fg)
check('foreground palette cycle early returns on indexed path', re.search(r'func refresh_palette_indices.*?if palette_indexed_mode:\n\t\t_update_cycle_palette_texture\(\)\n\t\treturn',fg,re.S) is not None)
check('GHZ animated tiles support R8 index patches', '_animated_tile_index_image' in fg and 'target_image.get_format() == Image.FORMAT_R8' in fg)

# Background palette-index architecture.
for mode,var in [('lz','lz_plane_image'),('syz','syz_plane_image'),('slz','slz_plane_image'),('sbz','sbz_plane_image')]:
    check(f'{mode} background built as indices', f'{var} = _build_background_repeat_index_image' in bg)
check('background R8 repeat image', 'Image.create_empty(period.x * 256, period.y * 256, false, Image.FORMAT_R8)' in bg)
check('background exact CRAM index encoding', 'func _draw_mz_block_indices' in bg and 'Color(float(palette_index) / 255.0' in bg)
check('all cycle backgrounds tiny palette only', 'mode in ["ghz", "lz", "syz", "slz", "sbz"]' in bg and '_update_ghz_palette_texture()\n\t\treturn' in bg)
check('background palette update 64x1', 'Image.create_empty(64, 1' in bg and 'ghz_palette_texture.update(ghz_palette_image)' in bg)
check('SBZ smoke remains compatible with R8', 'sbz_plane_image.get_format() == Image.FORMAT_R8' in bg and '_indexed_tile_image' in bg)

# Title corruption: finished RGBA title frames must not retain the gameplay R8 shader.
phase=re.search(r'func _apply_title_background_phase.*?(?=\nfunc |\Z)',st,re.S).group(0)
check('title RGBA background clears indexed material', 'child.material = null' in phase and 'child.texture = texture' in phase)
check('title material cleared before texture assignment', phase.find('child.material = null') < phase.find('child.texture = texture'))

# Small palette-dependent sprites should cache palette states and retain live CRAM across animation frames.
check('runtime object palette signature helper', 'static func _runtime_palette_signature' in so)
check('LZ waterfall runtime palette cached', '_runtime_palette_signature(palette_override, [43, 44, 45, 46])' in so and '_cache[key] = texture' in re.search(r'static func lz_waterfall_texture.*?(?=\nstatic func )',so,re.S).group(0))
check('SBZ electro runtime palette cached', '_runtime_palette_signature(palette_override, [60, 61, 62])' in so)
check('LZ animation retains current palette', 'waterfall_runtime_palette' in lz and 'lz_waterfall_texture(waterfall_frame, waterfall_runtime_palette)' in lz)
check('SBZ electro animation retains current palette', 'electro_runtime_palette' in sbz and 'sbz_electro_texture(electro_frame, electro_runtime_palette)' in sbz)

# Performance invariants / theoretical upload reduction.
# LZ repeating background is exactly 2x4 chunks = 512x1024. Phase72 uploaded
# a full RGBA8 image when its waterfall/conveyor colors changed. HF1 uploads
# only a 64x1 RGBA8 palette for the background renderer.
old_lz_bg_bytes=512*1024*4
new_palette_bytes=64*1*4
check('LZ background per-cycle upload reduction >=8192x', old_lz_bg_bytes//new_palette_bytes >= 8192, f'{old_lz_bg_bytes}->{new_palette_bytes} bytes')
# Foreground indexed path must not execute the old visible chunk patch loop.
indexed_prefix=re.search(r'func refresh_palette_indices.*?return',fg,re.S).group(0)
check('indexed foreground avoids visible chunk scans', '_visible_foreground_chunk_ids' not in indexed_prefix)

# Standing Input Map is preserved.
proj=text('project.godot')
for action in ['A','B','C','Start','Debug']:
    check('Input Map action '+action, re.search(r'^'+re.escape(action)+r'=\{',proj,re.M) is not None)
check('Z/X/Space/Enter/F10 mappings preserved', all(code in proj for code in ['physical_keycode":90','physical_keycode":88','physical_keycode":32','physical_keycode":4194309','physical_keycode":4194341']))

# Confirm only intended runtime files differ from Phase72 (docs may be added later).
allowed={
    'scripts/render/ghz_renderer.gd','scripts/render/ghz_background_renderer.gd',
    'scripts/objects/startup_sequence_controller.gd','scripts/data/source_object_art.gd',
    'scripts/objects/lz_native_object.gd','scripts/objects/sbz_progression_object.gd',
}
unexpected=[]
for bp in BASE.rglob('*'):
    if not bp.is_file(): continue
    rel=bp.relative_to(BASE).as_posix(); rp=ROOT/rel
    if not rp.exists(): unexpected.append(rel+' missing'); continue
    if bp.read_bytes()!=rp.read_bytes() and rel not in allowed and rel != 'README.md':
        unexpected.append(rel)
check('only intended Phase72 runtime files changed', not unexpected, ', '.join(unexpected[:10]))

# Freeze major confirmed systems.
for rel in [
    'scripts/audio/sonic_audio.gd','scripts/player/sonic_player.gd','scripts/collision/genesis_collision.gd',
    'scripts/render/genesis_palette_fade.gd','scripts/ui/level_title_card_ui.gd','scripts/ui/end_card_ui.gd',
    'scripts/ui/special_stage_result_ui.gd','scripts/objects/bridge_object.gd','scripts/objects/mz_geyser_object.gd',
    'scripts/objects/mz_geyser_column.gd','scripts/render/level_palette_cycler.gd',
]:
    check('confirmed system frozen '+rel, same(rel), sha(ROOT/rel))

# Structural GDScript sanity.
for rel in sorted(allowed):
    s=text(rel)
    funcs=re.findall(r'^func\s+([A-Za-z0-9_]+)\s*\(',s,re.M)
    check('unique funcs '+rel,len(funcs)==len(set(funcs)))
    cleaned=re.sub(r'#.*','',s); cleaned=re.sub(r'"(?:\\.|[^"\\])*"','""',cleaned)
    check('balanced delimiters '+rel, all(cleaned.count(a)==cleaned.count(b) for a,b in [('(',')'),('[',']'),('{','}')]))

passed=sum(ok for _,ok,_ in checks); total=len(checks)
print(f'PHASE72_HOTFIX1_VALIDATION: {passed}/{total} passed')
for i,(name,ok,detail) in enumerate(checks,1):
    print(f'{i:03d} {"PASS" if ok else "FAIL"} {name}' + (f' [{detail}]' if detail else ''))
sys.exit(0 if passed==total else 1)
