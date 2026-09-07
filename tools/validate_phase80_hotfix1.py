#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

ring=(PROJECT/'scripts/objects/ring_group_object.gd').read_text()
manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()

check(('"s2_rings": "s2test/ehz1_rings.bin"' in catalog) or ('"s2_rings": "s2test/%s_rings.bin" % suffix' in catalog),'EHZ native S2 ring placement remains enabled')
check('"s2_rings": "s2test/hpz1_rings.bin"' in catalog,'HPZ native S2 ring placement remains enabled')
check('func _load_s2_ring_positions(path: String) -> bool:' in manager,'native S2 ring descriptor parser remains present')
check('mini(8, (subtype & 7) + 1)' in ring,'full 1..8 source ring-group count remains supported')
check('s2_rings' not in ring,'ring runtime no longer selects a separate S2 art folder')
check('set_sprite_frame(sprite, "rings", 0)' in ring,'initial ring frame uses shared S1/S2 ring art')
check('set_sprite_frame(sprite, "rings", frame)' in ring,'rotating ring animation uses shared ring art')
check('set_sprite_frame(sparkle, "rings", 4)' in ring,'ring collection sparkle uses shared ring art')
check('set_sprite_frame(sparkle, "rings", 4 + frame_index)' in ring,'sparkle sequence stays on shared ring art')
check(not (PROJECT/'assets/objects/s2_rings').exists(),'unused Phase 80 S2-specific ring render folder is removed')

# Run the prior stable Phase 79 regression suite. Phase 80 validator intentionally
# expected the removed S2 art folder, so its placement/source assertions are checked
# directly above rather than treating that obsolete visual expectation as a failure.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase79.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 79 physics/animation/camera regression validator still passes')

for name in ('ehz1','hpz1'):
    check((PROJECT/f'data/s1/s2test/{name}_rings.bin').is_file(),f'{name.upper()} native ring placement binary remains packaged')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE80_HOTFIX1_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
