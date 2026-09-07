from pathlib import Path
import subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
bg=(ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
anim=(ROOT/'scripts/render/level_art_animator.gd').read_text()
fg=(ROOT/'scripts/render/ghz_renderer.gd').read_text()
checks=[]
def check(ok,msg):
    checks.append(bool(ok)); print(('PASS' if ok else 'FAIL')+': '+msg)
check('const S2_EHZ_MAX_STRIPS := 96' in bg and 'for i in range(S2_EHZ_MAX_STRIPS)' in bg,
      'EHZ background uses a bounded run pool rather than one Sprite2D per viewport scanline')
check('while run_end < viewport_height' in bg and 'if next_scroll != scroll_value:' in bg and
      'run_height := run_end - line' in bg,
      'consecutive equal SwScrl_EHZ scanlines are coalesced without changing their source offsets')
check('_collect_s2_ehz_plane_tile_patches' in bg and
      's2_ehz_plane_image.blit_rect' in bg and
      'var rebuilt := _build_s2_ehz_plane_index_image()' not in bg[bg.index('func refresh_s2test_art_range'):bg.index('func refresh_mz_art_range')],
      'animated EHZ Plane B updates patch referenced 8x8 tiles instead of rebuilding the full plane')
segment=anim[anim.index('func _tick_s2_ehz()'):anim.index('func _tick_sbz()')]
check(segment.count('_notify_art_change(S2_EHZ_FLOWER1_TILE, 10)') == 1 and
      '_copy_bytes_to_art(destination_tile' in segment and '_copy_frame(destination_tile' not in segment,
      'five EHZ DMA slots batch into one renderer notification per changed VBlank')
check('limit_to_visible := level.zone_id == LevelCatalog.ZONE_S2_TEST' in fg and
      'not visible_ids.has(chunk_id)' in fg,
      'S2 animated foreground art redraw is limited to visible native-128 chunks')
# Source SwScrl shape must remain untouched.
check('for _i in range(22)' in bg and 'for _i in range(58)' in bg and 'for i in range(21)' in bg and
      'for _i in range(11)' in bg and bg.count('for _i in range(16)') >= 2 and
      'for _i in range(15)' in bg and 'for _i in range(9)' in bg,
      'retail EHZ scanline deformation bands remain source-shaped')
# Prove the fixed pool is safe across the native EHZ horizontal camera span and all ripple phases.
ripple=[1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3,
        1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3,1,2]
def values(camera_x, phase):
    d2=-camera_x; out=[0]*22; slow=d2>>6; out += [slow]*58
    start=phase&31; out += [slow+ripple[(start+i)%len(ripple)] for i in range(21)]; out += [0]*11
    near=d2>>4; out += [near]*16; mid=near+(near>>1); out += [mid]*16
    target=(d2>>1)-(d2>>3); quotient=int(float(target<<8)/48.0); step=quotient<<8; grad=(d2>>3)<<16
    for _ in range(15): out.append(grad>>16); grad+=step
    for _ in range(9):
        v=grad>>16; out += [v,v]; grad += step*2
    for _ in range(15):
        v=grad>>16; out += [v,v,v]; grad += step*3
    # Source leaves lines 222/223 untouched; zero is the initialized worst-case boundary for run count.
    out += [0,0]
    return out
max_runs=0
for x in range(0,0x4001,16):
    for phase in range(32):
        v=values(x,phase); runs=1+sum(a!=b for a,b in zip(v,v[1:])); max_runs=max(max_runs,runs)
check(max_runs <= 96, f'96-strip pool covers exhaustive EHZ h-scroll run count (maximum {max_runs})')
# Re-run the Phase 87 source/fidelity regression.
r=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase87.py')], cwd=ROOT)
check(r.returncode==0,'Phase 87 and chained earlier fidelity regressions still pass')
print(f'\n{sum(checks)}/{len(checks)} checks passed')
sys.exit(0 if all(checks) else 1)
