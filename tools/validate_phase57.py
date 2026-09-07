#!/usr/bin/env python3
from pathlib import Path
import hashlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = Path('/mnt/data/phase56work')
SRC = Path('/mnt/data/s1src56/s1disasm-AS/_inc/Palette Fading.asm')

checks = []
def check(name, cond, detail=''):
    checks.append((name, bool(cond), detail))

# -------------------------------------------------------------------------
# Independent iterative model of the 68000 one-channel-per-call routines.
# RGB values are represented directly as 0..7 triples.
# -------------------------------------------------------------------------
def black_in_step(cur, target):
    r,g,b = cur; tr,tg,tb = target
    if cur == target:
        return cur
    if b < tb:
        return (r,g,b+1)
    if g < tg:
        return (r,g+1,b)
    return (r+1,g,b)

def black_out_step(cur, target=None):
    r,g,b = cur
    if r > 0:
        return (r-1,g,b)
    if g > 0:
        return (r,g-1,b)
    if b > 0:
        return (r,g,b-1)
    return cur

def white_in_step(cur, target):
    r,g,b = cur; tr,tg,tb = target
    if cur == target:
        return cur
    if b > tb:
        return (r,g,b-1)
    if g > tg:
        return (r,g-1,b)
    return (r-1,g,b)

def white_out_step(cur, target=None):
    r,g,b = cur
    if r < 7:
        return (r+1,g,b)
    if g < 7:
        return (r,g+1,b)
    if b < 7:
        return (r,g,b+1)
    return cur

# Closed forms mirrored by genesis_palette_fade.gdshader.
def f_black_in(t, s):
    tr,tg,tb=t
    b=min(tb,s); rem=max(0,s-tb)
    g=min(tg,rem); rem=max(0,rem-tg)
    r=min(tr,rem)
    return (r,g,b)

def f_black_out(t, s):
    tr,tg,tb=t
    r=max(0,tr-s); rem=max(0,s-tr)
    g=max(0,tg-rem); rem=max(0,rem-tg)
    b=max(0,tb-rem)
    return (r,g,b)

def f_white_in(t,s):
    tr,tg,tb=t
    bs=7-tb; b=max(tb,7-s); rem=max(0,s-bs)
    gs=7-tg; g=max(tg,7-rem); rem=max(0,rem-gs)
    r=max(tr,7-rem)
    return (r,g,b)

def f_white_out(t,s):
    tr,tg,tb=t
    rs=7-tr; r=min(7,tr+s); rem=max(0,s-rs)
    gs=7-tg; g=min(7,tg+rem); rem=max(0,rem-gs)
    b=min(7,tb+rem)
    return (r,g,b)

mismatches=[]
for r in range(8):
  for g in range(8):
    for b in range(8):
      target=(r,g,b)
      modes = [
        ('black_in',(0,0,0),black_in_step,f_black_in),
        ('black_out',target,black_out_step,f_black_out),
        ('white_in',(7,7,7),white_in_step,f_white_in),
        ('white_out',target,white_out_step,f_white_out),
      ]
      for mode,start,stepper,closed in modes:
        cur=start
        for s in range(22):
          got=closed(target,s)
          if got != cur:
            mismatches.append((target,mode,s,cur,got))
            break
          cur = stepper(cur,target)
check('all 512 colors x 4 modes x 22 visible states match iterative source model', not mismatches,
      '' if not mismatches else str(mismatches[:3]))

fade_gd=(ROOT/'scripts/render/genesis_palette_fade.gd').read_text()
shader=(ROOT/'scripts/render/genesis_palette_fade.gdshader').read_text()
source=SRC.read_text(errors='replace')
check('explicit BackBufferCopy node is used', 'BackBufferCopy.new()' in fade_gd and 'COPY_MODE_VIEWPORT' in fade_gd)
check('BackBufferCopy is inserted before fade rect', fade_gd.find('add_child(backbuffer)') < fade_gd.find('add_child(rect)'))
check('fade helper uses shader instead of alpha overlay', 'ShaderMaterial.new()' in fade_gd and 'rect.color = Color(base.r' not in fade_gd)
check('shader uses explicit screen texture path', 'hint_screen_texture' in shader and 'textureLod(screen_texture, SCREEN_UV, 0.0)' in shader)
check('shader uses nearest non-repeating screen sampling', 'repeat_disable' in shader and 'filter_nearest' in shader)
check('black-in source channel order present', all(x in source for x in ['FadeIn_AddColor:', '.addBlue:', '.addGreen:', '.addRed:']))
check('black-out source channel order present', all(x in source for x in ['FadeOut_DecColor:', '.decRed:', '.decGreen:', '.decBlue:']))
check('white-in source channel order present', all(x in source for x in ['WhiteIn_DecColor:', '.decBlue:', '.decGreen:', '.decRed:']))
check('white-out source channel order present', all(x in source for x in ['WhiteOut_AddColor:', '.addRed:', '.addGreen:', '.addBlue:']))
check('22-frame source duration retained', 'move.w\t#22-1,d4' in source and 'const SOURCE_FRAMES := 22' in fade_gd)

# Ensure the accepted Phase 56 runtime systems are untouched.
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
protected = [
 'scripts/audio/sonic_audio.gd',
 'scripts/collision/genesis_collision.gd',
 'scripts/data/ghz_level_data.gd',
 'scripts/objects/path_switcher_object.gd',
 'scripts/player/sonic_player.gd',
 'project.godot',
]
for rel in protected:
    check(f'Phase 56 baseline unchanged: {rel}', sha(ROOT/rel)==sha(BASE/rel))

# Preserve the accepted Clean/U/waterfall audio behavior explicitly.
audio=(ROOT/'scripts/audio/sonic_audio.gd').read_text()
project=(ROOT/'project.godot').read_text()
main=(ROOT/'scripts/main.gd').read_text()
check('Clean remains startup audio mode', 'sonic/output_mode="clean"' in project)
check('U audio mode toggle remains', 'KEY_U' in main and 'toggle_output_mode' in main)
check('Phase 54 waterfall PCM path remains', 'waterfall' in audio.lower() and 'SFX_WATERFALL' in audio)

# Only the expected runtime palette files may differ from Phase 56.
changed=[]
for p in ROOT.rglob('*'):
    if not p.is_file():
        continue
    rel=p.relative_to(ROOT)
    bp=BASE/rel
    if bp.exists() and sha(p) != sha(bp):
        changed.append(str(rel))
expected_runtime={'scripts/render/genesis_palette_fade.gd','scripts/render/genesis_palette_fade.gdshader'}
runtime_changed={x for x in changed if x.startswith(('scripts/','project.godot','main.tscn'))}
check('runtime change is isolated to palette fade helper/shader', runtime_changed == expected_runtime, str(sorted(runtime_changed)))

passed=sum(1 for _,ok,_ in checks if ok)
print(f'Phase 57 static validation: {passed}/{len(checks)} checks passed')
for name,ok,detail in checks:
    print(('PASS' if ok else 'FAIL') + ': ' + name + ((' -- '+detail) if detail else ''))
if mismatches:
    sys.exit(1)
if passed != len(checks):
    sys.exit(1)
