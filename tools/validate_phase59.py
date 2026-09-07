#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from zipfile import ZipFile
import hashlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ZIP = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/mnt/data/phase55src/s1disasm-AS(2).zip')
checks: list[tuple[str, bool, str]] = []

def check(name: str, ok: bool, detail: str = '') -> None:
    checks.append((name, bool(ok), detail))

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

# 1. New runtime/source files.
required = [
    'scripts/render/level_art_animator.gd',
    'scripts/render/ghz_renderer.gd',
    'scripts/render/ghz_background_renderer.gd',
    'data/s1/artunc/MZ Lava.unc',
]
for rel in required:
    check(f'exists: {rel}', (ROOT / rel).is_file())

# 2. Retained art must be byte-identical to the authoritative disassembly.
source_assets = [
    'GHZ Waterfall.unc',
    'GHZ Flower Large.unc',
    'GHZ Flower Small.unc',
    'MZ Lava Surface.unc',
    'MZ Lava.unc',
    'MZ Background Torch.unc',
]
if SOURCE_ZIP.is_file():
    with ZipFile(SOURCE_ZIP) as zf:
        for name in source_assets:
            src = zf.read(f's1disasm-AS/artunc/{name}')
            dst = (ROOT / 'data/s1/artunc' / name).read_bytes()
            check(f'source art exact: {name}', src == dst, f'{len(dst)} bytes')
        ani_asm = zf.read('s1disasm-AS/_inc/AnimateLevelGfx.asm').decode('latin1')
        constants = zf.read('s1disasm-AS/_Constants.asm').decode('latin1')
else:
    ani_asm = ''
    constants = ''
    check('authoritative source zip available', False, str(SOURCE_ZIP))

# 3. Source tile destinations and timing constants.
source_tokens = [
    ('GHZ waterfall timer', 'move.b\t#6-1,(v_lani0_time).w'),
    ('GHZ big flower timer', 'move.b\t#16-1,(v_lani1_time).w'),
    ('GHZ small flower short timer', 'move.b\t#8-1,(v_lani2_time).w'),
    ('GHZ small flower long timer', 'move.b\t#128-1,(v_lani2_time).w'),
    ('MZ lava timer', 'move.b\t#20-1,(v_lani0_time).w'),
    ('MZ magma timer', 'move.b\t#2-1,(v_lani1_time).w'),
    ('MZ torch timer', 'move.b\t#8-1,(v_lani2_time).w'),
]
for label, token in source_tokens:
    check(f'source timing: {label}', token in ani_asm)
for label, token in [
    ('GHZ big flower', 'ArtTile_GHZ_Big_Flower_1:\tequ ArtTile_Level+$35C'),
    ('GHZ small flower', 'ArtTile_GHZ_Small_Flower:\tequ ArtTile_Level+$36C'),
    ('GHZ waterfall', 'ArtTile_GHZ_Waterfall:\t\tequ ArtTile_Level+$378'),
    ('MZ magma', 'ArtTile_MZ_Animated_Magma:\tequ ArtTile_Level+$2D2'),
    ('MZ lava', 'ArtTile_MZ_Animated_Lava:\tequ ArtTile_Level+$2E2'),
    ('MZ torch', 'ArtTile_MZ_Torch:\t\tequ ArtTile_Level+$2F2'),
]:
    check(f'source VRAM slot: {label}', token in constants)

anim = (ROOT / 'scripts/render/level_art_animator.gd').read_text()
for token in [
    'GHZ_BIG_FLOWER_TILE = 0x35C',
    'GHZ_SMALL_FLOWER_TILE = 0x36C',
    'GHZ_WATERFALL_TILE = 0x378',
    'MZ_MAGMA_TILE = 0x2D2',
    'MZ_LAVA_TILE = 0x2E2',
    'MZ_TORCH_TILE = 0x2F2',
    'lani0_time = 6 - 1',
    'lani1_time = 16 - 1',
    'lani2_time = 128 - 1',
    'lani0_time = 20 - 1',
    'lani1_time = 2 - 1',
    'lani2_time = 8 - 1',
    'GHZ_SMALL_FLOWER_SEQUENCE = [0, 1, 2, 1]',
]:
    check(f'animator token: {token}', token in anim)

# 4. Independently verify the compact MZ magma interpretation. The 68000
# selects one of 16 routines that copy 4 consecutive bytes (wrapping at 16)
# from each 16-byte source scanline, then repeats for four 8px columns.
src = (ROOT / 'data/s1/artunc/MZ Lava.unc').read_bytes()
def direct_vram_reference(frame: int, shift: int) -> bytes:
    out = bytearray()
    base = frame * 0x200
    for column in range(4):
        start = (shift + column * 4) & 0x0F
        for y in range(32):
            row = src[base + y * 16: base + (y + 1) * 16]
            out += bytes(row[(start + i) & 0x0F] for i in range(4))
    return bytes(out)

def tile_major_formula(frame: int, shift: int) -> bytes:
    out = bytearray(0x200)
    base = frame * 0x200
    for column in range(4):
        for tile_y in range(4):
            tile = column * 4 + tile_y
            for py in range(8):
                y = tile_y * 8 + py
                for b in range(4):
                    sx = (shift + column * 4 + b) & 0x0F
                    out[tile * 32 + py * 4 + b] = src[base + y * 16 + sx]
    return bytes(out)
all_magma = all(direct_vram_reference(f, s) == tile_major_formula(f, s) for f in range(3) for s in range(16))
check('MZ magma: 3 frames x 16 byte shifts match direct VRAM copy', all_magma, '48/48 states')
check('MZ magma GDScript uses column-major tile order', 'var tile_index = column * 4 + tile_y' in anim)
check('MZ magma GDScript wraps 16-byte source rows', '(shift + column * 4 + byte_in_row) & 0x0F' in anim)

# 5. Renderer update path should retain CPU images and patch via native Image
# blits, while ImageTexture.update preserves the existing texture resource.
fg = (ROOT / 'scripts/render/ghz_renderer.gd').read_text()
bg = (ROOT / 'scripts/render/ghz_background_renderer.gd').read_text()
check('foreground retains CPU chunk images', '"low_image": images["low"]' in fg and '"high_image": images["high"]' in fg)
check('foreground uses native 8x8 blit patches', 'target_image.blit_rect(tile_image' in fg)
check('foreground updates existing ImageTextures', 'low_texture.update(low_image)' in fg and 'high_texture.update(high_image)' in fg)
check('foreground invalidates patch cache for new dynamic chunks', 'art_range_patch_cache.clear()' in fg)
check('MZ background uses native 8x8 blit patches', 'image.blit_rect(tile_image' in bg)
check('MZ background updates existing ImageTexture', 'chunk_texture.update(image)' in bg)

# 6. Main-loop ordering: AnimateLevelGfx equivalent occurs before ExecuteObjects
# advances the shared oscillator, and pauses skip it.
main = (ROOT / 'scripts/main.gd').read_text()
normal_tick = main.find('\n\t_tick_level_art()\n\n\tif game_over_ui.active:')
execute = main.find('\n\tobject_manager.execute_objects()\n', normal_tick)
pause = main.find('\n\tif game_paused:\n\t\treturn\n')
check('main integrates LevelArtAnimator', 'var level_art_animator = LevelArtAnimator.new()' in main and 'level_art_animator.setup(level, renderer, background_renderer)' in main)
check('normal art tick occurs after pause gate', pause >= 0 and normal_tick > pause)
check('normal art tick occurs before ExecuteObjects/oscillator advance', normal_tick >= 0 and execute > normal_tick)
check('title-card blocking path still advances animated art', 'if level_title_card.blocking:\n\t\t\t_tick_level_art()' in main)

# 7. Accepted Phase 58 HF1 systems stay frozen.
expected_hashes = {
    'scripts/render/genesis_palette_fade.gd': '8c2aeb1dc128167da8b1b13b1e3bee812d7a65b46a63979fd63d28c4d323ac34',
    'scripts/ui/level_title_card_ui.gd': 'd9e8fdf27d8fedc14c0e8351e6e2ac8dce247d59de9a14bc1fdec444f7bea42a',
    'scripts/player/sonic_player.gd': 'e5427c095abe598e089b40395f0148d2ba2bb6838cf1b77e4a1766e6aab7e502',
    'scripts/audio/sonic_audio.gd': '37b0bddbea5037ec53638e7d36d70b5c05c46684a8e4091cb54c32c526fc99a7',
    'scripts/collision/genesis_collision.gd': '2e2dbec4158e1555ad5c3b760e42a33eb342b5fbd6758d7180663743f32b0fcc',
    'scripts/objects/path_switcher_object.gd': '85e891b092bc4b5a679a60cbc3716ca0b9bdff105527ff0a638e7c8e1acf6b5f',
    'project.godot': 'eee557da58171f4db34f5a70781ee1cf60ab39bf3eef3fa0fed67fca64c947be',
}
for rel, digest in expected_hashes.items():
    check(f'frozen baseline: {rel}', sha(ROOT / rel) == digest)

# 8. Carry-forward Godot 4.6.3 parser compatibility and U audio toggle.
# The older Sonic_Animate locals no longer exist in the current player rewrite;
# the two still-live Special Stage inferred-array sites must remain plain '='.
ss_art = (ROOT / 'scripts/data/special_stage_art.gd').read_text()
check('Godot parser fix: Special Stage palette_line uses =', 'var palette_line = [0, 3, 1, 2][block_id - 0x2D]' in ss_art)
check('Godot parser fix: Special Stage flash_palette uses =', 'var flash_palette = [0, 3, 1, 2][block_id - 0x4B]' in ss_art)
check('new Phase 59 main locals avoid inferred :=', 'var level_art_animator = LevelArtAnimator.new()' in main)
check('U remains Authentic/Clean toggle', 'KEY_U' in main and 'SonicAudio.toggle_output_mode()' in main)

passed = sum(ok for _, ok, _ in checks)
print(f'Phase 59 validation: {passed}/{len(checks)} checks passed')
for name, ok, detail in checks:
    suffix = f' — {detail}' if detail else ''
    print(f'[{"PASS" if ok else "FAIL"}] {name}{suffix}')
if passed != len(checks):
    raise SystemExit(1)
