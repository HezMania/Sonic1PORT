#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, subprocess, sys
from collections import Counter

ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name,cond,detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    cat=(ROOT/'scripts/data/level_catalog.gd').read_text(); main=(ROOT/'scripts/main.gd').read_text()
    bg=(ROOT/'scripts/render/ghz_background_renderer.gd').read_text(); pal=(ROOT/'scripts/render/level_palette_cycler.gd').read_text()
    art=(ROOT/'scripts/render/level_art_animator.gd').read_text(); fg=(ROOT/'scripts/render/ghz_renderer.gd').read_text()
    boss=(ROOT/'scripts/objects/s2_arz_boss_object.gd').read_text(); audio=(ROOT/'scripts/audio/sonic_audio.gd').read_text()
    d=ROOT/'data/s1/s2test'; manifest=json.loads((d/'phase98_cnz1_manifest.json').read_text())

    # User-reported ARZ boss carry-forward corrections.
    check('ARZ Obj89 initial traverse keeps source unflipped facing', 'target_left = true\n\t# Retail Obj89 starts' in boss and 'facing_left = false\n\tstate = STATE_TRAVERSE' in boss)
    check('ARZ Obj89 toggles facing opposite next target', 'facing_left = not target_left' in boss)
    seq='[4,6,5,4,6,4,5,4,6,4,4,6,5,4,6,4,5,4,6,4]'
    check('ARZ embedded arrow has exact 20-frame source shake sequence', seq in boss)
    check('ARZ embedded arrow settles to frame 4 after finite shake', 'if shake_index < ARROW_STICK_SHAKE_FRAMES.size() else 4' in boss)
    check('old infinite modulo-three arrow shake is gone', 'frame_tick\"]) % 3' not in boss)

    # Catalog/routing/music.
    check('Casino Night has dedicated S2 catalog zone', 'const ZONE_S2_CNZ_TEST := 11' in cat and '_get_sonic2_cnz_test' in cat)
    check('CNZ1 source start is imported', manifest['start']==[0x60,0x2AC], str(manifest['start']))
    check('CNZ1 retail camera bounds are catalogued', all(x in cat for x in ('"limit_right": 0x27A0','"limit_top": 0','"limit_bottom": 0x720')))
    check('ARZ2 progression now enters CNZ1', 'Vector2i(ZONE_S2_CNZ_TEST, 1)' in cat)
    check('Q is direct CNZ1 test shortcut', 'KEY_Q:' in main and '_debug_warp(LevelCatalog.ZONE_S2_CNZ_TEST, 1)' in main)
    check('CNZ music has isolated port-local ID $199', 'const MUS_S2_CNZ := 0x199' in audio and 'SonicAudio.MUS_S2_CNZ' in main)
    check('CNZ uses Sonic 2 end-level music path', 'current_zone == LevelCatalog.ZONE_S2_CNZ_TEST' in main)
    check('debug HUD is Phase98-or-later', 'Native Sonic 1 Phase 98' in main or 'Native Sonic 1 Phase 99' in main or 'Native Sonic 1 Phase 100' in main)

    # Native data payload.
    expected={
      'cnz1_art.bin':0x10000,'cnz1_map16.bin':0x1800,'cnz1_map128.bin':0x8000,
      'cnz1_layout128.bin':2+128*16,'cnz1_bg128.bin':2+128*16,'cnz1_start.bin':4,
      'cnz1_objects.bin':1716,'cnz1_rings.bin':572,'s2_cnz_flip_tiles.bin':6656,
    }
    for name,size in expected.items(): check(f'{name} retained at expected size',(d/name).is_file() and (d/name).stat().st_size==size,str((d/name).stat().st_size if (d/name).exists() else -1))
    check('CNZ APM patch is source $1760/$A0', manifest['map16_apm']=={'destination':0x1760,'bytes':0xA0},str(manifest['map16_apm']))
    check('CNZ object stream retains all 286 records', manifest['object_records']==286)
    check('48 records use already-native shared object families', manifest['supported_shared_records']==48)
    check('238 CNZ-specific records remain retained for next pass', manifest['deferred_cnz_specific_records']==238)
    check('CNZ object counts retain 74 round bumpers and 44 ObjD8 records', manifest['object_counts_hex'].get('44')==74 and manifest['object_counts_hex'].get('D8')==44)

    # Presentation source translations.
    check('CNZ background renderer is enabled and dispatched', 'mode == "s2cnz"' in bg and 'func _update_s2cnz' in bg)
    check('CNZ Plane B uses CameraY/64', 'var bg_y := int(camera_model.screen_y) >> 6' in bg)
    check('CNZ sub_D160 ten-layer ratios are preserved', '[64,57,50,43,36,29,22,4,4,8]' in bg)
    check('CNZ source 16-line ripple band is preserved', 'logical_y < 144' in bg and 'logical_y < 192' not in bg[bg.find('func _update_s2cnz'):bg.find('func _update_s2cnz')+2500] and 'S2_EHZ_RIPPLE[ri]' in bg)
    check('CNZ foreground uses indexed CRAM renderer', 'LevelCatalog.ZONE_S2_CNZ_TEST' in fg and 'palette_indexed_mode' in fg)
    check('CNZ background CRAM cycles update palette texture', '"s2arz", "s2cnz"]' in bg)
    check('CNZ PalCycle loads all three source streams', all(x in pal for x in ('S2 CNZ Cycle 1.bin','S2 CNZ Cycle 3.bin','S2 CNZ Cycle 4.bin')))
    check('CNZ PalCycle uses eight-VBlank source period', 'func _tick_s2_cnz() -> Array[int]:' in pal and 'pcyc_time = 7' in pal)
    check('CNZ Cycle1 targets exact CRAM indices', '[37,38,39,43,44,45]' in pal)
    check('CNZ Cycle3 targets exact CRAM indices 50-52', '50 + i' in pal)
    check('CNZ Cycle4 targets exact CRAM indices 57-59', all(f'_write_single(level.palette, {i}' in pal for i in (57,58,59)))
    check('CNZ Animated_CNZ destinations are $330/$540', 'S2_CNZ_FLIP1_TILE = 0x330' in art and 'S2_CNZ_FLIP2_TILE = 0x540' in art)
    check('CNZ both 16-frame dynamic scripts are retained', art.count('S2_CNZ_FLIP1_FRAMES')>=2 and art.count('S2_CNZ_FLIP2_FRAMES')>=2)
    check('CNZ dynamic DMA copies full 16-tile source frames', '_copy_frame(destinations[slot], s2_cnz_flip' in art and ', 0x10)' in art)
    check('CNZ music parse retained source tempo/voice/DAC metadata', manifest['music']=={'id':0x199,'tempo':72,'voices':3,'dac_ids':[0,1]},str(manifest['music']))
    check('Phase98 importer and documentation are packaged',(ROOT/'tools/import_s2_cnz1_phase98.py').is_file() and (ROOT/'PHASE98_SONIC2_CASINO_NIGHT_ACT1.md').is_file())

    prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase97.py')] + ([str(s2)] if s2 else []),capture_output=True,text=True)
    detail=prev.stdout.strip().splitlines()[-1] if prev.stdout.strip() else prev.stderr.strip()[-120:]
    check('Phase97 ARZ boss/end regression remains clean',prev.returncode==0,detail)

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore'); const=(s2/'s2.constants.asm').read_text(errors='ignore')
        check('retail LevelSize confirms CNZ1 $27A0/$720','zoneTableEntry.w\t$0,\t$27A0,\t$0,\t$720\t; CNZ act 1' in asm)
        check('retail CNZ1 LevEvents has no act-1 camera event sequence','LevEvents_CNZ:' in asm and 'rts\t\t\t; no events for act 1' in asm)
        sw=asm[asm.find('SwScrl_CNZ:'):asm.find('SwScrl_CNZ_2P:')]
        check('retail SwScrl_CNZ confirms Y >> 6 and source ripple', 'lsr.w\t#6,d0' in sw and 'SwScrl_RippleData' in sw)
        sub=asm[asm.find('sub_D160:'):asm.find('SwScrl_CNZ_2P:')]
        check('retail sub_D160 source routine is present','move.w\t#6,d1' in sub and 'asr.w\t#3,d0' in sub)
        check('retail CNZ dynamic destinations confirm $330/$540','ArtTile_ArtUnc_CNZFlipTiles_1         = $0330' in const and 'ArtTile_ArtUnc_CNZFlipTiles_2         = $0540' in const)
        ani=asm[asm.find('Animated_CNZ:'):asm.find('zoneanimend',asm.find('Animated_CNZ:'))+20]
        check('retail Animated_CNZ contains both long $C7 hold frames',ani.count('$C7')>=3)
        cyc=asm[asm.find('PalCycle_CNZ:'):asm.find('PalCycle_CPZ:')]
        check('retail PalCycle_CNZ confirms timer 7 and Cycle1/3/4','move.w\t#7,(PalCycle_Timer).w' in cyc and all(x in cyc for x in ('CyclingPal_CNZ1','CyclingPal_CNZ3','CyclingPal_CNZ4')))
        # Deterministic source reconstruction check.
        before={n:sha(d/n) for n in expected}
        regen=subprocess.run([sys.executable,str(ROOT/'tools/import_s2_cnz1_phase98.py'),str(s2)],capture_output=True,text=True)
        after={n:sha(d/n) for n in expected}
        check('CNZ1 payload regenerates deterministically from retail source',regen.returncode==0 and before==after,regen.stderr.strip()[-120:])

    passed=sum(v for _,v in checks); print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
