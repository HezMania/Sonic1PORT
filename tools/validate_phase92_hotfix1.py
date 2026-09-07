#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(ok,msg):
    checks.append((bool(ok),msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

def main():
    tr=(ROOT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    pr=(ROOT/'scripts/objects/s2_cpz_spiny_projectile.gd').read_text()
    check('elif width == 0x120:\n\t\tbase = 8' in tr,'$120 tube controllers use entry bank 8..11')
    check('else:\n\t\tbase = 4\n\t\tdx = 0x100 - dx' in tr,'$100 tube controllers use bank 4..7 with source X mirror')
    check('base = 0' in tr and 'if width == 0xA0' in tr,'$A0 tube controllers retain bank 0..3')
    check('var map_idx = (subtype & 0xFC) + tube_entry_mode' in tr and 'continue_map[map_idx]' in tr,'byte_227BE continuation remains subtype+entry indexed')
    check('p.rolling = true' in tr and 'p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT' in tr and 'p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH' in tr,'Obj32 break bounce reasserts roll state and roll radii')
    check('p.object_attack_active = true' in tr and 'p.vel_y = -0x300' in tr,'Obj32 retains attack state and source -$300 bounce')
    check('spiny/06.png", 0)' in pr,'Spiny Obj98 projectile renders behind z=1 Badnik body')
    r=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase92.py')],cwd=ROOT,text=True,capture_output=True)
    check(r.returncode==0,'complete Phase 92 regression suite still passes')
    if len(sys.argv)>1:
        src=Path(sys.argv[1]); asm=(src/'s2.asm').read_text()
        check('cmpi.w\t#$A0,d2' in asm and 'moveq\t#8,d3' in asm and 'cmpi.w\t#$120,d2' in asm and 'moveq\t#4,d3' in asm and 'neg.w\td0' in asm,'retail loc_225FC confirms $A0/$100/$120 bank ordering and $100 mirror')
        check('bset\t#2,status(a1)' in asm and 'move.b\t#$E,y_radius(a1)' in asm and 'move.b\t#7,x_radius(a1)' in asm and 'move.w\t#-$300,y_vel(a1)' in asm,'retail Obj32_BouncePlayer confirms roll status/radii and -$300 bounce')
    failed=[m for ok,m in checks if not ok]
    print(f'\n{len(checks)-len(failed)}/{len(checks)} checks passed')
    if failed:
        if r.returncode!=0: print(r.stdout); print(r.stderr)
        return 1
    return 0
if __name__=='__main__': raise SystemExit(main())
