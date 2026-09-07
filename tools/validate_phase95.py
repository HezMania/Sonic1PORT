#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
checks=[]
def check(name, cond, detail=''):
    ok=bool(cond); checks.append((name,ok)); print(('PASS' if ok else 'FAIL')+': '+name+(f' ({detail})' if detail else ''))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    s2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    cat=(ROOT/'scripts/data/level_catalog.gd').read_text()
    main=(ROOT/'scripts/main.gd').read_text()
    audio=(ROOT/'scripts/audio/sonic_audio.gd').read_text()
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    plat=(ROOT/'scripts/objects/s2_ehz_platform_object.gd').read_text()
    surf=(ROOT/'scripts/effects/lz_water_surface_effect.gd').read_text()
    fg=(ROOT/'scripts/render/ghz_renderer.gd').read_text()
    cyc=(ROOT/'scripts/render/level_palette_cycler.gd').read_text()
    wet=(ROOT/'scripts/render/lz_water_palette.gd').read_text()
    bg=(ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
    prison=(ROOT/'scripts/objects/s2_egg_prison_object.gd').read_text()
    hazard=(ROOT/'scripts/objects/s2_cpz_hazard_object.gd').read_text()
    manifest=json.loads((ROOT/'data/s1/s2test/phase95_arz1_manifest.json').read_text())

    check('Phase 95 defines native S2 ARZ test zone', 'ZONE_S2_ARZ_TEST := 10' in cat and '_get_sonic2_arz_test' in cat)
    for tok in ('"limit_right": 0x28C0','"limit_top": 0x200','"limit_bottom": 0x600','"chunk_pixel_size": 128','"chunk_word_format": "s2"'):
        check('ARZ1 catalog contains '+tok, tok in cat)
    check('ARZ1 uses static source water height $410', '"s2_static_water_y": 0x410' in cat and '"s2_arz_water": true' in cat)
    check('ARZ1 uses indexed ARZ Plane B', '"background_mode": "s2arz"' in cat and ('"s2_background_indices": "s2test/arz1_bg_indices.bin"' in cat or '"s2_background_indices": "s2test/%s_bg_indices.bin" % prefix' in cat))
    check('CPZ2 progresses to ARZ1', 'Vector2i(ZONE_S2_ARZ_TEST, 1)' in cat)
    check('O directly warps to ARZ1', 'KEY_O:' in main and '_debug_warp(LevelCatalog.ZONE_S2_ARZ_TEST, 1)' in main)
    check('ARZ1 uses retail S2 music slot', 'MUS_S2_ARZ := 0x198' in audio and 'SonicAudio.MUS_S2_ARZ' in main)
    check('ARZ music includes new DAC samples $83 and $8D', 's2_ehz_dac_02.pcm' in audio and 's2_ehz_dac_12.pcm' in audio and (ROOT/'data/s1/sound/s2_ehz_dac_02.pcm').stat().st_size>0 and (ROOT/'data/s1/sound/s2_ehz_dac_12.pcm').stat().st_size>0)

    expected_sizes={
        'arz1_art.bin':65536,'arz1_map16.bin':6400,'arz1_map128.bin':32768,
        'arz1_layout128.bin':2050,'arz1_bg128.bin':2050,'arz1_collision_primary.bin':768,
        'arz1_collision_secondary.bin':768,'arz1_objects.bin':1092,'arz1_rings.bin':410,
        'arz1_start.bin':4,'arz1_bg_indices.bin':16384*1536,
    }
    for name,size in expected_sizes.items():
        p=ROOT/'data/s1/s2test'/name
        check(name+' exact generated size', p.exists() and p.stat().st_size==size, str(p.stat().st_size if p.exists() else -1))
    for name,digest in manifest['output_sha256'].items():
        p=ROOT/'data/s1/s2test'/name
        check(name+' deterministic hash', p.exists() and sha(p)==digest)
    check('ARZ normal palette has three zone CRAM lines', (ROOT/'data/s1/palette/S2 Aquatic Ruin Zone.bin').stat().st_size==96)
    check('ARZ underwater palette is full 64-colour CRAM', (ROOT/'data/s1/palette/S2 Aquatic Ruin Underwater.bin').stat().st_size==128)
    check('ARZ water palette cycle has four 4-colour frames', (ROOT/'data/s1/palette/S2 EHZ ARZ Water Cycle.bin').stat().st_size==32)

    counts=Counter()
    b=(ROOT/'data/s1/s2test/arz1_objects.bin').read_bytes()
    for i in range(0,len(b),6): counts[b[i+4]]+=1
    expected={0x03:30,0x0D:1,0x18:11,0x1F:5,0x22:8,0x23:5,0x24:10,0x26:13,0x2B:4,0x2C:34,0x36:1,0x40:6,0x41:8,0x79:3,0x82:2,0x83:3,0x8C:6,0x8D:4,0x8E:11,0x91:17}
    check('ARZ1 has exactly 182 source object records', sum(counts.values())==182, str(sum(counts.values())))
    check('ARZ1 exact object-ID histogram preserved', dict(counts)==expected, str(dict(counts)))
    shared={0x03,0x0D,0x18,0x26,0x36,0x40,0x41,0x79}
    supported=sum(v for k,v in counts.items() if k in shared)
    check('Phase 95 activates 73 shared ARZ1 records', supported==73, str(supported))
    check('109 ARZ-specific records remain explicitly deferred', 182-supported==109, str(182-supported))

    check('ObjectManager enables fixed water for s2_static_water_y', 's2_static_water >= 0' in om and 'water_surface_y = s2_static_water' in om)
    check('ARZ uses dedicated animated water-surface art', 'use_s2_arz_surface' in surf and 's2_arz/water_surface' in surf and 'frame_timer = 5' in surf)
    check('ARZ underwater palette shader uses dedicated source palette', 'S2 Aquatic Ruin Underwater.bin' in wet and 'ZONE_S2_ARZ_TEST' in wet)
    check('ARZ foreground is palette-indexed for safe CRAM cycling', 'LevelCatalog.ZONE_S2_CPZ_TEST, LevelCatalog.ZONE_S2_ARZ_TEST' in fg)
    check('ARZ palette cycle targets source CRAM indices 34-37 every six VBlanks', 'func _tick_s2_arz' in cyc and 'pcyc_time = 5' in cyc and '_write_run(level.palette, 34' in cyc)

    exact_rows='[0xB0,0x70,0x30,0x60,0x15,0x0C,0x0E,0x06,0x0C,0x1F,0x30,0xC0,0xF0,0xF0,0xF0,0xF0]'
    exact_nums='[0,0,0,1,3,4,5,6,7,8,9,0,0,0,0,0]'
    check('ARZ background keeps exact SwScrl row heights', exact_rows in bg)
    check('ARZ background keeps exact 1/10..9/10 row ratios', exact_nums in bg)
    check('ARZ background uses $119/$100 target and $10 chase', 'camera_x * 0x119' in bg and '-0x10, 0x10' in bg)
    check('ARZ1 background Y follows CameraY-$180', 'var bg_y := int(camera_model.screen_y) - 0x180' in bg)
    check('ARZ background stays on batched strip renderer', 'mode == "s2arz"' in bg and 'pool_index < s2_ehz_strips.size()' in bg)

    check('ARZ Obj18 selects source pair with ((subtype>>3)&$E)', '((subtype >> 3) & 0x0E) >> 1' in plat)
    check('ARZ Obj18 full-solid variants use $28 y radius', 'full_solid' in plat and '0x28' in plat and 'resolve_solid_box' in plat)
    check('ARZ Obj18 uses retail source oscillator byte $18', 's2_source_osc_byte(0x18)' in plat)
    check('ARZ platform and surface source frames were generated', len(list((ROOT/'assets/objects/s2_arz/platform').glob('*.png')))==2 and len(list((ROOT/'assets/objects/s2_arz/water_surface').glob('*.png')))==2)

    check('Phase 95 narrows S2 Egg Prison body collision by 16px/side', 'active_width = 0x1B' in prison and 'resolve_solid_box(spawn_x, spawn_y, 0x1B' in prison)
    check('Phase 95 restores Grabber rear-leg layer and grabbed frame', 'make_sprite("res://assets/objects/s2_cpz/grabber/03.png", 3)' in hazard and 'set_sprite_frame(aux_sprite, "s2_cpz/grabber", 4 if grabbed_player else 3)' in hazard)

    music=json.loads((ROOT/'data/s1/sound/s2_ehz_smps.json').read_text())['music']
    arz=music.get('408',{})
    check('compiled ARZ song has retail tempo $E0', int(arz.get('header',{}).get('tempo_mod',-1))==0xE0, str(arz.get('header',{}).get('tempo_mod')))
    check('compiled ARZ song contains six FM voices', len(arz.get('voices',[]))==6, str(len(arz.get('voices',[]))))

    if s2 is not None:
        asm=(s2/'s2.asm').read_text(errors='ignore')
        check('retail ARZ1 LevelSize is $0,$28C0,$200,$600', 'zoneTableEntry.w\t$0,\t$28C0,\t$200,\t$600\t; ARZ act 1' in asm)
        check('retail ARZ1 water height is $410', '$410, $510\t; ARZ' in asm[asm.find('WaterHeight:'):asm.find('WaterHeight:')+4000] if asm.find('WaterHeight:')>=0 else False)
        sw=asm[asm.find('SwScrl_ARZ:'):asm.find('SwScrl_CPZ:') if asm.find('SwScrl_CPZ:')>asm.find('SwScrl_ARZ:') else asm.find('SwScrl_ARZ:')+20000]
        check('retail SwScrl_ARZ contains $119 camera multiplier', '#$119' in sw)
        check('retail SwScrl_ARZ contains $10 BG X chase step', '#$10' in sw)
        check('retail ARZ palette cycle uses 4 colours and 4 frames', 'PalCycle_ARZ:' in asm and 'CyclingPal_EHZ_ARZ_Water' in asm and 'andi.w\t#3,d0' in asm[asm.find('PalCycle_ARZ:'):asm.find('PalCycle_ARZ:')+700])
        prev=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase94.py'),str(s2)],capture_output=True,text=True)
        check('Phase 94 boss/end regression remains clean except intentional HF1/95 presentation deltas', prev.returncode==0, prev.stdout.strip().splitlines()[-1] if prev.stdout else '')

    passed=sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed==len(checks) else 1
if __name__=='__main__': raise SystemExit(main())
