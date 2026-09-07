#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
checks = []

def check(name, cond, detail=''):
    ok = bool(cond)
    checks.append((name, ok))
    print(('PASS' if ok else 'FAIL') + ': ' + name + (f' ({detail})' if detail else ''))

def sha(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    s2 = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
    cat = (ROOT/'scripts/data/level_catalog.gd').read_text()
    main_gd = (ROOT/'scripts/main.gd').read_text()
    surf = (ROOT/'scripts/effects/lz_water_surface_effect.gd').read_text()
    bg = (ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
    om = (ROOT/'scripts/objects/object_manager.gd').read_text()
    manifest = json.loads((ROOT/'data/s1/s2test/phase96_arz2_manifest.json').read_text())

    check('ARZ catalog dispatch now preserves requested act', 'return _get_sonic2_arz_test(act)' in cat)
    check('ARZ catalog clamps to retail two acts', 'act = clampi(act, 1, 2)' in cat)
    check('ARZ2 uses retail right bound $3FFF', '0x28C0 if act == 1 else 0x3FFF' in cat)
    check('ARZ2 uses retail top bound $180', '0x200 if act == 1 else 0x180' in cat)
    check('ARZ2 uses retail bottom bound $710', '0x600 if act == 1 else 0x710' in cat)
    check('ARZ2 uses retail fixed water $510', '0x410 if act == 1 else 0x510' in cat)
    check('ARZ2 selects its native layout/object/ring/start payload', 'var prefix := "arz%d" % act' in cat and '"s2_objects": "s2test/%s_objects.bin" % prefix' in cat)
    check('ARZ2 selects its own indexed Plane B', '"s2_background_indices": "s2test/%s_bg_indices.bin" % prefix' in cat)
    check('ARZ1 now progresses directly to ARZ2', 'Vector2i(ZONE_S2_ARZ_TEST, 2) if act < 2' in cat)
    check('P directly warps to ARZ2', 'KEY_P:' in main_gd and '_debug_warp(LevelCatalog.ZONE_S2_ARZ_TEST, 2)' in main_gd)

    expected_sizes = {
        'arz2_layout128.bin': 2050,
        'arz2_bg128.bin': 2050,
        'arz2_objects.bin': 1332,
        'arz2_rings.bin': 598,
        'arz2_start.bin': 4,
        'arz2_bg_indices.bin': 16384*1536,
    }
    for name, size in expected_sizes.items():
        p = ROOT/'data/s1/s2test'/name
        check(name + ' exact generated size', p.exists() and p.stat().st_size == size, str(p.stat().st_size if p.exists() else -1))
    for name, digest in manifest['output_sha256'].items():
        p = ROOT/'data/s1/s2test'/name
        check(name + ' deterministic hash', p.exists() and sha(p) == digest)

    start = (ROOT/'data/s1/s2test/arz2_start.bin').read_bytes()
    check('ARZ2 source start is $0060,$037E', start == bytes.fromhex('0060037e'), start.hex())
    b = (ROOT/'data/s1/s2test/arz2_objects.bin').read_bytes()
    counts = Counter(b[i+4] for i in range(0, len(b), 6))
    expected = {0x03:28,0x15:4,0x18:10,0x1F:10,0x22:16,0x23:11,0x24:10,0x26:18,0x2B:7,0x2C:9,0x3E:1,0x40:10,0x41:17,0x79:4,0x82:13,0x83:1,0x8C:19,0x8D:4,0x8E:9,0x91:21}
    check('ARZ2 has exactly 222 source object records', sum(counts.values()) == 222, str(sum(counts.values())))
    check('ARZ2 exact object-ID histogram preserved', dict(counts) == expected, str(dict(counts)))
    shared = {0x03,0x18,0x26,0x3E,0x40,0x41,0x79}
    supported = sum(v for k,v in counts.items() if k in shared)
    check('ARZ2 activates 88 already-native shared records', supported == 88, str(supported))
    check('ARZ2 retains 134 ARZ-specific placements for later object pass', 222-supported == 134, str(222-supported))
    check('Egg Prison remains available as temporary ARZ2 test exit', '0x3E: return S2EggPrisonObjectClass.new()' in om)

    check('ARZ water line now anchors full mapping canvas at object origin', 'manager.water_surface_y - 0x60' in surf)
    check('ARZ water fix is isolated from cropped CPZ surface positioning', 'elif use_s2_surface:' in surf and 'manager.water_surface_y - 8' in surf)
    check('ARZ water animation cadence remains two frames / six VBlanks', 'frame_timer = 5' in surf and 'frame = (frame + 1) & 1' in surf)

    check('ARZ1 background retains CameraY-$180 model', 'int(camera_model.screen_y) - 0x180 if act == 1' in bg)
    check('ARZ2 background uses retail (CameraY-$E0)/2 model', '(int(camera_model.screen_y) - 0xE0) >> 1' in bg)
    check('ARZ horizontal $119/$100 target remains intact', 'camera_x * 0x119' in bg)
    check('ARZ horizontal chase remains capped at $10 per VBlank', '-0x10, 0x10' in bg)
    check('ARZ exact 16 source row heights remain intact', '[0xB0,0x70,0x30,0x60,0x15,0x0C,0x0E,0x06,0x0C,0x1F,0x30,0xC0,0xF0,0xF0,0xF0,0xF0]' in bg)

    check('Phase96 importer is packaged', (ROOT/'tools/import_s2_arz2_phase96.py').is_file())
    check('Phase96 documentation is packaged', (ROOT/'PHASE96_SONIC2_AQUATIC_RUIN_ACT2.md').is_file())

    # Preserve the exact Phase 95 ARZ1 payload while adding Act 2.
    p95 = json.loads((ROOT/'data/s1/s2test/phase95_arz1_manifest.json').read_text())
    for name, digest in p95['output_sha256'].items():
        p = ROOT/'data/s1/s2test'/name
        check('Phase95 regression hash ' + name, p.exists() and sha(p) == digest)

    if s2 is not None:
        asm = (s2/'s2.asm').read_text(errors='ignore')
        check('retail ARZ2 LevelSize is $0,$3FFF,$180,$710', 'zoneTableEntry.w\t$0,\t$3FFF,\t$180,\t$710\t; ARZ act 2' in asm)
        wh = asm[asm.find('WaterHeight:'):asm.find('WaterHeight:')+4000] if asm.find('WaterHeight:') >= 0 else ''
        check('retail ARZ water pair is $410,$510', '$410, $510\t; ARZ' in wh)
        init = asm[asm.find('InitCam_ARZ:'):asm.find('InitCam_SCZ:')]
        check('retail InitCam_ARZ Act2 subtracts $E0 then halves Y', 'subi.w\t#$E0,d0' in init and 'lsr.w\t#1,d0' in init)
        events = asm[asm.find('LevEvents_ARZ2:'):asm.find('LevEvents_SCZ:')]
        check('retail ARZ2 boss prelude source located for next pass', '#$2810' in events and '#$2A40' in events and '#$5A' in events and 'ObjID_ARZBoss' in events)
        check('retail ARZ2 object placement bytes match package', (s2/'level/objects/ARZ_2.bin').read_bytes() == b)
        check('retail ARZ2 ring placement bytes match package', (s2/'level/rings/ARZ_2.bin').read_bytes() == (ROOT/'data/s1/s2test/arz2_rings.bin').read_bytes())
        check('retail ARZ2 start bytes match package', (s2/'startpos/ARZ_2.bin').read_bytes() == start)
        prev = subprocess.run([sys.executable, str(ROOT/'tools/validate_phase94.py'), str(s2)], capture_output=True, text=True)
        check('Phase94 boss/end regression remains clean', prev.returncode == 0, prev.stdout.strip().splitlines()[-1] if prev.stdout else '')

    passed = sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed == len(checks) else 1

if __name__ == '__main__':
    raise SystemExit(main())
