#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'data/s1/s2test'
checks=[]
def check(ok,msg):
    checks.append((bool(ok),msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

def blocks_for_layout(layout: bytes, map128: bytes):
    out=set()
    for cid in layout:
        if cid==0: continue
        base=cid*128
        if base+128>len(map128): continue
        for i in range(0,128,2):
            out.add(((map128[base+i]<<8)|map128[base+i+1]) & 0x3FF)
    return out

def blocks_referencing(blocks, map16, targets):
    refs=set()
    for block in blocks:
        base=block*8
        if base+8>len(map16): continue
        for i in range(0,8,2):
            word=(map16[base+i]<<8)|map16[base+i+1]
            if (word & 0x7FF) in targets:
                refs.add(block)
    return refs

def main():
    renderer=(ROOT/'scripts/render/ghz_renderer.gd').read_text()
    anim=(ROOT/'scripts/render/level_art_animator.gd').read_text()
    check('LevelCatalog.ZONE_S2_CPZ_TEST,' in renderer and 'palette_indexed_mode = level != null' in renderer,
          'CPZ foreground uses palette-indexed chunk textures')
    check('foreground.refresh_palette_indices(changed)' in (ROOT/'scripts/render/level_palette_cycler.gd').read_text()
          and 'if palette_indexed_mode:' in renderer and '_update_cycle_palette_texture()' in renderer,
          'CPZ CRAM cycles resolve to palette-texture updates instead of RGBA chunk rebuilds')
    check('background.refresh_s2test_art_range(S2_CPZ_ANIM_BACK_TILE, 2)' in anim,
          'CPZ animated VRAM slot refresh explicitly targets Plane B')
    cpz_func=anim.split('func _tick_s2_cpz() -> void:',1)[1].split('\nfunc ',1)[0]
    check('_copy_frame(' not in cpz_func and '_copy_bytes_to_art(' in cpz_func,
          'CPZ animated art no longer invokes generic foreground+background notification')

    map16=(D/'cpz1_map16.bin').read_bytes()
    map128=(D/'cpz1_map128.bin').read_bytes()
    fg=(D/'cpz1_layout128.bin').read_bytes()[2:]
    bg=(D/'cpz1_bg128.bin').read_bytes()[2:]
    fgb=blocks_for_layout(fg,map128); bgb=blocks_for_layout(bg,map128)
    targets={0x370,0x371}
    fgrefs=blocks_referencing(fgb,map16,targets)
    bgrefs=blocks_referencing(bgb,map16,targets)
    check(not fgrefs, 'no CPZ1 foreground block references VRAM tiles $370-$371')
    check(bgrefs=={0x2FF}, 'CPZ animated tiles $370-$371 are used only by background block $2FF')
    block=map16[0x2FF*8:0x300*8]
    check(block==bytes.fromhex('4370437143704371'), 'background block $2FF retains exact APM_CPZ mapping')
    art=(D/'cpz1_art.bin').read_bytes(); src=(D/'s2_cpz_anim_back.bin').read_bytes()
    check(art[0x370*32:0x372*32]==src[:64], 'initial CPZ animated VRAM frame remains byte-exact')

    r=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase90.py')],cwd=ROOT,text=True,capture_output=True)
    check(r.returncode==0, 'complete Phase 90 regression suite still passes')
    failed=[m for ok,m in checks if not ok]
    print(f'\n{len(checks)-len(failed)}/{len(checks)} checks passed')
    if failed:
        print(r.stdout); print(r.stderr)
        for m in failed: print('FAILED:',m)
        return 1
    return 0
if __name__=='__main__': raise SystemExit(main())
