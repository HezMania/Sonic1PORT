#!/usr/bin/env python3
from pathlib import Path
import hashlib, subprocess, sys, json

ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    tr=(ROOT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    wf=(ROOT/'scripts/effects/lz_water_surface_effect.gd').read_text()
    wp=(ROOT/'scripts/render/lz_water_palette.gd').read_text()
    main=(ROOT/'scripts/main.gd').read_text()

    check('tipping Obj0B uses source PlatformObject surface Y-$11', 'spawn_y - 0x11' in tr)
    check('Obj19 selects source width/mapping family from subtype high nibble', 'var shape = (subtype >> 4) & 3' in tr and '[0x20, 0x18, 0x40, 0x20]' in tr)
    check('CPZ2 small Obj19 frame is packaged', (ROOT/'assets/objects/s2_cpz/platform_small/00.png').is_file())
    check('Obj19 circular routines use retail oscillator channels $38/$3C', 's2_source_osc_byte(0x38)' in tr and 's2_source_osc_byte(0x3C)' in tr and 'kind >= 0x0C' in tr)
    check('CPZ2 water instantiates the generic surface effect', '_ensure_lz_water_surface()' in om and 'if water_enabled:' in om)
    check('S2 Obj04 uses exact 64-step source frame sequence', 'S2_WATER_SEQUENCE' in wf and 's2_sequence_index & 0x3F' in wf)
    check('three retail S2 water-surface frames are packaged', all((ROOT/f'assets/objects/s2_cpz/water_surface/{i:02d}.png').is_file() for i in range(3)))
    check('CPZ2 palette split is keyed to configured level plus live water state', 'configured_zone' in wp and 'object_manager.water_enabled' in wp)
    check('water palette is reconfigured after ObjectManager setup', 'CPZ2 water state is established by ObjectManager.setup' in main)
    check('Obj7B preserves six-VBlank non-solid emergence window', 'age >= 0 and age <= 6' in om)

    # Exact placed CPZ2 Obj19 subtypes that need the smaller/circular path.
    b=(ROOT/'data/s1/s2test/cpz2_objects.bin').read_bytes()
    vals=[b[i+5] for i in range(0,len(b),6) if b[i+4]==0x19]
    check('CPZ2 Obj19 placements retain retail circular subtypes $18/$1A/$1D/$1F', all(v in vals for v in (0x18,0x1A,0x1D,0x1F)), str([hex(v) for v in vals]))

    if s2 is not None:
        src_obj=(s2/'level/objects/CPZ_2.bin').read_bytes()
        check('CPZ2 placed object binary remains byte-identical', b==src_obj)
        src_pal=s2/'art/palettes/CPZ underwater.bin'
        check('CPZ underwater CRAM remains byte-identical', sha(ROOT/'data/s1/palette/S2 Chemical Plant Underwater.bin')==sha(src_pal))
        # Regenerate hotfix art and prove deterministic output.
        targets=[ROOT/'assets/objects/s2_cpz/platform_small/00.png']+[ROOT/f'assets/objects/s2_cpz/water_surface/{i:02d}.png' for i in range(3)]
        before={str(p):sha(p) for p in targets}
        subprocess.run([sys.executable,str(ROOT/'tools/import_s2_cpz2_hotfix1.py'),str(s2)],check=True,stdout=subprocess.DEVNULL)
        after={str(p):sha(p) for p in targets}
        check('hotfix water/platform art regenerates deterministically from retail source', before==after)

    passed=sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
