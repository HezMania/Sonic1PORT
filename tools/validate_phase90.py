#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, subprocess, sys
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'data/s1'
checks=[]
def check(ok,msg):
    checks.append((bool(ok),msg)); print(('PASS' if ok else 'FAIL')+': '+msg)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    cat=(ROOT/'scripts/data/level_catalog.gd').read_text()
    main=(ROOT/'scripts/main.gd').read_text()
    audio=(ROOT/'scripts/audio/sonic_audio.gd').read_text()
    bg=(ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
    anim=(ROOT/'scripts/render/level_art_animator.gd').read_text()
    cyc=(ROOT/'scripts/render/level_palette_cycler.gd').read_text()
    boss=(ROOT/'scripts/objects/s2_ehz_boss_object.gd').read_text()
    prison=(ROOT/'scripts/objects/s2_egg_prison_object.gd').read_text()
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()

    check('ZONE_S2_CPZ_TEST := 9' in cat and 'return _get_sonic2_cpz_test()' in cat, 'CPZ1 has an isolated Sonic 2 catalog slot')
    check('"layout": "s2test/cpz1_layout128.bin"' in cat and '"chunk_pixel_size": 128' in cat and '"chunk_word_format": "s2"' in cat, 'CPZ1 uses native S2 128x128 terrain words')
    check('"limit_right": 0x2780' in cat and '"limit_bottom": 0x720' in cat, 'CPZ1 retains retail level bounds $2780/$720')
    check('"background_mode": "s2cpz"' in cat and 'func _update_s2cpz' in bg and 'mode == "s2cpz"' in bg, 'CPZ does not accidentally execute EHZ scanline deformation')
    check('KEY_M:' in main and '_debug_warp(LevelCatalog.ZONE_S2_CPZ_TEST, 1)' in main, 'M debug shortcut enters retail CPZ1')
    check('Vector2i(ZONE_S2_CPZ_TEST, 1)' in cat, 'completed EHZ2 now progresses into CPZ1')

    files={n:D/'s2test'/n for n in ['cpz1_art.bin','cpz1_map16.bin','cpz1_map128.bin','cpz1_layout128.bin','cpz1_bg128.bin','cpz1_collision_primary.bin','cpz1_collision_secondary.bin','cpz1_objects.bin','cpz1_rings.bin','cpz1_start.bin','s2_cpz_anim_back.bin']}
    check(all(p.is_file() for p in files.values()), 'all CPZ1 terrain/ring/object/start assets are packaged')
    check(files['cpz1_art.bin'].stat().st_size==0x10000 and files['cpz1_map16.bin'].stat().st_size==0x1800 and files['cpz1_map128.bin'].stat().st_size==0x8000, 'CPZ VRAM/Map16/Map128 containers have source-native extents')
    layout=files['cpz1_layout128.bin'].read_bytes(); bglo=files['cpz1_bg128.bin'].read_bytes()
    check(layout[:2]==bytes([127,15]) and len(layout)==2050 and bglo[:2]==bytes([127,15]) and len(bglo)==2050, 'foreground/background layouts are exact 128x16 native chunk grids')
    start=files['cpz1_start.bin'].read_bytes()
    check(start[:4]==bytes.fromhex('006001ec'), 'CPZ1 source start position is $0060,$01EC')
    map16=files['cpz1_map16.bin'].read_bytes()
    check(map16[0x17F8:0x1800]==bytes.fromhex('4370437143704371'), 'APM_CPZ exact animated block patch occupies Block_Table+$17F8')
    animsrc=files['s2_cpz_anim_back.bin'].read_bytes(); art=files['cpz1_art.bin'].read_bytes()
    check(len(animsrc)==0x200 and art[0x370*32:0x372*32]==animsrc[:64], 'CPZ animated background is seeded at source VRAM tile $370')
    check('S2_CPZ_ANIM_BACK_TILE = 0x370' in anim and 's2_cpz_time = 4' in anim and '_tick_s2_cpz()' in anim, 'Dynamic_Normal CPZ two-tile animation runs on five-VBlank source timing')

    for n,size in [('S2 Chemical Plant Zone.bin',96),('S2 CPZ Cycle 1.bin',54),('S2 CPZ Cycle 2.bin',42),('S2 CPZ Cycle 3.bin',32)]:
        check((D/'palette'/n).is_file() and (D/'palette'/n).stat().st_size==size, f'{n} packaged at exact source size')
    check('_tick_s2_cpz()' in cyc and '_write_run(level.palette, 60' in cyc and '_write_single(level.palette, 63' in cyc and '_write_single(level.palette, 47' in cyc, 'PalCycle_CPZ writes the three retail CRAM destinations')

    obj=files['cpz1_objects.bin'].read_bytes(); counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    expected={0x03:60,0x0B:4,0x0D:1,0x19:7,0x1B:8,0x1D:7,0x1E:9,0x26:19,0x2D:2,0x32:4,0x41:5,0x6B:2,0x74:2,0x78:2,0x79:3,0x7B:5,0xA5:10,0xA6:1,0xA7:2}
    check(len(obj)==918 and len(obj)//6==153 and dict(counts)==expected, 'all 153 retail CPZ1 object records are retained byte-for-byte by ID distribution')
    supported={0x03,0x0D,0x26,0x41,0x79}
    check(sum(v for k,v in counts.items() if k in supported)==88, '88/153 CPZ1 placements already resolve through shared S2 runtime classes')
    check('0x03: return S2PlaneSwitcherObjectClass.new()' in om and '0x26: return S2MonitorAdapterClass.new()' in om and '0x41: return S2SpringObjectClass.new()' in om and '0x79: return LamppostObject.new()' in om, 'shared CPZ plane switchers/monitors/springs/starposts use established S2 dispatch')

    db=json.loads((D/'sound/s2_ehz_smps.json').read_text())
    song=db['music'].get(str(0x197),{})
    check('const MUS_S2_CPZ := 0x197' in audio and 'MUS_S2_CPZ' in main and song.get('name')=='Sonic 2 - Chemical Plant Zone', 'retail CPZ song has isolated port-local music ID $197')
    hdr=song.get('header',{})
    check(hdr.get('tempo_mod')==0xEE and hdr.get('speed_tempo')==0xFF and len(song.get('voices',[]))==6, 'CPZ SMPS retains source tempo $EE, speed-shoes table $FF and six FM voices')
    check(song.get('source',{}).get('used_dac_ids')==[0,1], 'CPZ DAC stream uses only already-native S2 Sample 1/2 events')
    labels=song.get('labels',{}); fall=song.get('fallthrough',{})
    targets_ok=all(v in labels for v in fall.values())
    check(len(labels)==772 and targets_ok, 'compiled CPZ SMPS graph contains 772 reachable labels with resolved fallthroughs')

    check('ground_sprite = _make_sprite(6)' in boss and 'wreck_facing_right = facing_right' in boss and 'ground_sprite.flip_h = wreck_facing_right if defeated else facing_right' in boss, 'Phase 89 boss layering/orientation correction is carried into Phase 90')
    check('var phase := mini(3, int(open_anim_tick / 4))' in prison, 'Egg Prison precomposited opening no longer visually loops shut/open forever')

    # Historical source-independent regressions should still pass.
    r=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase89_hotfix2.py')],cwd=ROOT,text=True,capture_output=True)
    check(r.returncode==0, 'complete Phase 89 Hotfix 2 regression chain still passes')

    if len(sys.argv)>1:
        src=Path(sys.argv[1])
        source_map={
            'cpz1_objects.bin':src/'level/objects/CPZ_1.bin',
            'cpz1_rings.bin':src/'level/rings/CPZ_1.bin',
            'cpz1_start.bin':src/'startpos/CPZ_1.bin',
            's2_cpz_anim_back.bin':src/'art/uncompressed/Animated background section (CPZ and DEZ).bin',
        }
        for outn,sp in source_map.items(): check(files[outn].read_bytes()==sp.read_bytes(), f'{outn} is byte-identical to retail source')
        check((D/'palette/S2 Chemical Plant Zone.bin').read_bytes()==(src/'art/palettes/CPZ.bin').read_bytes(), 'CPZ palette is byte-identical to retail source')
        for i in range(1,4): check((D/f'palette/S2 CPZ Cycle {i}.bin').read_bytes()==(src/f'art/palettes/CPZ Cycle {i}.bin').read_bytes(), f'CPZ palette cycle {i} is byte-identical to retail source')
        manifest=json.loads((D/'s2test/phase90_cpz1_manifest.json').read_text())
        check(manifest['source_sha256']['objects']==sha(src/'level/objects/CPZ_1.bin') and manifest['source_sha256']['music']==sha(src/'sound/music/CPZ.bin'), 'Phase 90 manifest fingerprints the supplied retail source')

    failed=[m for ok,m in checks if not ok]
    print(f'\n{len(checks)-len(failed)}/{len(checks)} checks passed')
    if failed:
        for m in failed: print('FAILED:',m)
        return 1
    return 0
if __name__=='__main__': raise SystemExit(main())
