#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

obj=(PROJECT/'data/s1/s2test/ehz1_objects.bin').read_bytes()
counts=Counter(obj[i+4] for i in range(0,len(obj),6))
check(len(obj)==810 and sha(PROJECT/'data/s1/s2test/ehz1_objects.bin')=='8e1a1852bf2f7995cfea0ac85d11a34e6758daede11a786f4304965211dfbcad',
      'EHZ1 native 135-record object layout remains byte-for-byte unchanged')
check((counts[0x4B],counts[0x5C],counts[0x9D],counts[0x41])==(11,13,8,14),
      'EHZ1 still contains 11 Buzzer, 13 Masher, 8 Coconuts and 14 springs')

bad=(PROJECT/'scripts/objects/s2_ehz_badnik_object.gd').read_text()
check('var horizontal_velocity = 0x180 if x_flip else -0x180' in bad,
      'Buzzer projectile horizontal velocity matches retail Obj4B')
check('var stinger_offset = -0x0D if x_flip else 0x0D' in bad,
      'Buzzer projectile source position uses the opposite-sign stinger offset')
check('int(position.y) + 0x18' in bad,
      'Buzzer projectile retains retail +$18 stinger Y offset')

spring=(PROJECT/'scripts/objects/s2_spring_object.gd').read_text()
check('resolve_solid_box_contact(spawn_x, spawn_y, 0x1B, 0x10, true, record_index)' in spring,
      'vertical S2 springs use source $1B/$10 standing envelope')
check('resolve_solid_box_contact(spawn_x, spawn_y, 0x13, 0x0F, true, record_index)' in spring,
      'horizontal S2 springs use source $13/$0F solid envelope')
check('var launch_inset = 6 if dir.x != 0 and dir.y != 0 else 8' in spring and
      'p.force_add_pixel_offset(-dir.x * launch_inset, -dir.y * launch_inset)' in spring,
      'S2 spring launch applies retail 6px diagonal / 8px axial compression inset')
check('return spawn_y - int(profile[index])' in spring and 'profile[index]) - int(profile[0])' not in spring,
      'diagonal spring support uses absolute signed source slope heights')
check('16,16,16,16,16,16,16,16,16,16,16,16,14,12,10,8,6,4,2,0,-2,-4,-4,-4,-4,-4,-4,-4' in spring,
      'retail 28-byte diagonal-up spring profile remains intact')

imp=(PROJECT/'tools/import_s2_ehz_badnik_art.py').read_text()
check("root/'art/palettes/SonicAndTails.bin'" in imp and "root/'art/palettes/EHZ.bin'" in imp,
      'badnik importer reconstructs the active EHZ CRAM from Sonic/Tails line 0 + EHZ lines 1-3')
check("palettes[(attr>>13)&3]" in imp,
      'sprite mapping palette bits select the correct active CRAM line per piece')
check('for y,size,attr,x in reversed(pieces):' in imp,
      'badnik composite preserves first-piece-in-front Genesis sprite-link priority')

manifest=json.loads((PROJECT/'data/s1/s2test/phase84_badnik_art_manifest.json').read_text())
expected_counts={'buzzer':7,'masher':2,'coconuts':4}
for folder,n in expected_counts.items():
    files=sorted((PROJECT/f'assets/objects/s2_ehz/{folder}').glob('*.png'))
    check(len(files)==n,f'{folder} retains all {n} source mapping frames')
    for p in files:
        check(sha(p)==manifest['outputs'][folder][p.name],f'{folder}/{p.name} matches Phase 84 source-regenerated output')

# These hashes specifically distinguish the corrected active-palette/priority render from Phase 83.
check(sha(PROJECT/'assets/objects/s2_ehz/buzzer/00.png')=='5877e50f00de0007bd20ed44427739b0aa0ad00c7ae40b778854f35d38fa0d06',
      'Buzzer frame 0 uses corrected Sonic/Tails palette line')
check(sha(PROJECT/'assets/objects/s2_ehz/coconuts/02.png')=='acc58edd043cd9cfe09b9c1b8557ab656868d8d0bb0aba627223b6f1692a4232',
      'Coconuts throw frame 2 keeps raised arm in front with corrected palette')
check(sha(PROJECT/'assets/objects/s2_ehz/coconuts/03.png')=='08bdc18a0a1d216c9a68480bfa75e562768d8b7e787d366eed8e389a2008f416',
      'Coconut projectile honors mapping-selected EHZ palette line 2')

# Phase 82 chains the previously verified S2 physics/animation/camera and ring systems.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase82.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 82 shared-object + earlier S2 regressions still pass')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE84_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
