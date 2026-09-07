#!/usr/bin/env python3
from pathlib import Path
import hashlib, subprocess, sys
from PIL import Image
import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

main=(PROJECT/'scripts/main.gd').read_text()
check('SonicAudio.MUS_SBZ if act == 4 else SonicAudio.MUS_LZ' in main,
      'hidden LZ4/SBZ3 selects Scrap Brain music instead of Labyrinth music')

catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()
check('d["palette"] = "palette/SBZ Act 3.bin"' in catalog and 'd["internal_sbz3"] = true' in catalog,
      'SBZ3 retains its dedicated dry palette and internal level marker')

cycler=(PROJECT/'scripts/render/level_palette_cycler.gd').read_text()
check('"SBZ Act 3 Underwater.bin" if int(level.definition.get("act", 1)) == 4 else "Labyrinth Zone Underwater.bin"' in cycler,
      'LZ4/SBZ3 runtime palette selects dedicated underwater CRAM image')

pal_dir=PROJECT/'data/s1/palette'
expected_pal={
    'SBZ Act 3 Underwater.bin':'bd26e559e0b69890fdd3218297665c75597988340bcf45b06f3d5ff31f7cec5c',
    'Sonic - SBZ3 Underwater.bin':'f0df030946176fdfdb110f6275e4403c324dd52ca7d998365b260c209f608b0e',
}
for name,h in expected_pal.items():
    p=pal_dir/name
    check(p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==h,
          f'{name} matches authoritative Sonic 1 disassembly bytes')
full=(pal_dir/'SBZ Act 3 Underwater.bin').read_bytes()
son=(pal_dir/'Sonic - SBZ3 Underwater.bin').read_bytes()
check(len(full)==128 and len(son)==32 and full[:32]==son,
      'SBZ3 underwater full palette begins with the dedicated underwater Sonic line')

visual=(PROJECT/'scripts/player/sonic_visual.gd').read_text()
check('elif player.s2_spiral_pathway_active:' in visual and 'mode = 17' in visual,
      'EHZ Object $06 spiral now enters Sonic 2 SAnim_Tumble presentation')
check('player.s2_twirl_active and player.animation_style != SonicPlayer.ANIMATION_STYLE_SONIC1' in visual,
      'S1 spring-profile preference remains intact while Beta/Final spring twirls remain enabled')
check('func _update_s1_compat_tumble(player) -> void:' in visual and 's2_exclusive_s1_compat/tumble/%02d.png' in visual,
      'Sonic 1 animation profile has a dedicated S2-exclusive tumble fallback bank')
check('player.s2_spiral_visual_angle if player.s2_spiral_pathway_active else player.s2_twirl_angle' in visual,
      'spiral flip-angle table and spring flip counter feed the same tumble renderer')
check('var frame_base = 0x9B if beta else 0x5F' in visual,
      'Beta and Final animation profiles retain their native SAnim_Tumble mapping bases')

hashes=[
'bfb8384b7a709e4599498d8f9900aea8a09ebdabdd0bab25ff72ff2181490f75',
'76b564f258c1904c303dda310be6c18fc6bb464e2f21b5b18a008a873c75d133',
'bb294c357202588d65030b9651c603c77dbb7a6deadcf89fded1046de9e3861a',
'2968e1a10c10a789780a76d0b78ea527a269db5541620091a08a8d1e933b3c85',
'90afe4f65518c700d56266de74af25b80bb2ef83bfe0b1419263f12b364851c0',
'085ae283853d9e27a30609950f159405f750152026e274e968a4be11f39ca662',
'934873d9c025e34d1d3cb66880be0ef6c046b4a98d8dc70362003152f1040927',
'902b9a045d64cb1d66861003a25c4e70764c29a6ce437c2719a4377aa11a0bf4',
'043fd9b9196177bf775eb7fd9b4c837f1a119d6b0015edda3f0944fdda8703fe',
'f6e415ac1bd90fd887550c3865d6ecf86cd84c1602f8438a3df3d5b43661f16e',
'6ab7e636a286056310fae56e4e2c2b688247216a529a05241658e0c3a46d2e94',
'daa6c67166a85a7fdd93e5f6b28daf13a03dd0e6fc040207cdffdfeb028b987b',
]
compat=PROJECT/'assets/sonic/s2_exclusive_s1_compat/tumble'
all_exact=True
all_masks=True
for i,h in enumerate(hashes):
    p=compat/f'{i:02d}.png'
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=h:
        all_exact=False
        continue
    # Uploaded 64x64 silhouettes correspond exactly to the centered 64x64 crop
    # of retail S2 mapping frames $5F-$6A; only their colors/presentation differ.
    u=np.array(Image.open(p).convert('RGBA'))[:,:,3]>0
    src=np.array(Image.open(PROJECT/f'assets/sonic2/final/frames/{95+i:03d}.png').convert('RGBA'))[:,:,3]>0
    if src.shape != (80,80) or not np.array_equal(u,src[8:72,8:72]):
        all_masks=False
check(all_exact,'all 12 uploaded S1-compatible tumble PNGs are preserved byte-for-byte')
check(all_masks,'all 12 compatibility frames match retail S2 $5F-$6A tumble silhouettes exactly')

r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase85_hotfix2.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 85 Hotfix 2 and all chained earlier regressions still pass')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE86_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
