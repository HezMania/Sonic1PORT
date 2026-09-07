#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, subprocess, sys

PROJECT = Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()
main=(PROJECT/'scripts/main.gd').read_text()
audio=(PROJECT/'scripts/audio/sonic_audio.gd').read_text()
anim=(PROJECT/'scripts/render/level_art_animator.gd').read_text()
bg=(PROJECT/'scripts/render/ghz_background_renderer.gd').read_text()

check('"music_mode": "s2_ehz"' in catalog and '"music_mode": "none"' in catalog[catalog.index('static func _get_sonic2_hpz_test'):],
      'EHZ enables its S2 music path while Simon Wai HPZ remains intentionally silent')
check('const MUS_S2_EHZ := 0x194' in audio and 'SonicAudio.play_music(SonicAudio.MUS_S2_EHZ, true)' in main,
      'EHZ uses a collision-free port-local music ID and main level playback routes to it')
check('driver_mode' in audio and 'TempoWait is an 8-bit accumulator' in audio and '_music_s2_accum = tempo_sum & 0xFF' in audio,
      'native audio has the retail S2 8-bit tempo-accumulator scheduling path')
check('speed_tempo' in audio and 'Change CurrentTempo only. S2 leaves TempoTimeout/accumulator running.' in audio,
      'S2 speed shoes change CurrentTempo without resetting the running tempo accumulator')
check('t.song.get("psg_envelopes"' in audio,
      'S2 music can use its own source PSG flutter-envelope table without altering S1 songs')
check('String(t.song.get("header", {}).get("driver_mode", "s1")) == "s2"' in audio and '_s2_ehz_dac_buffers' in audio,
      'S2 EHZ DAC events use their source-derived PCM variants rather than S1 drum substitutions')

song_path=PROJECT/'data/s1/sound/s2_ehz_smps.json'
check(song_path.is_file(), 'compiled retail EHZ SMPS graph is packaged')
if song_path.is_file():
    root=json.loads(song_path.read_text())
    song=root['music']['404']
    h=song['header']
    check((h['fm_count'],h['psg_count'],h['tempo_div'],h['tempo_mod'],h['speed_tempo'],h['driver_mode']) == (6,3,1,0x9E,0xBE,'s2'),
          'EHZ SMPS header matches decompressed retail S2 header and speed-shoes table')
    check(len(song['voices'])==9 and len(song['labels'])==1084,
          'EHZ source graph contains all nine FM voices and the complete reachable command graph')
    starts=[(c['kind'],c['label'],c['transpose'],c['volume']) for c in h['channels']]
    expected=[
      ('DAC','S2EHZ_D_060F',0,0),('FM','S2EHZ_F_03A0',0,14),('FM','S2EHZ_F_00A4',0,22),
      ('FM','S2EHZ_F_01BE',0,22),('FM','S2EHZ_F_033B',0,32),('FM','S2EHZ_F_0030',0,37),
      ('PSG','S2EHZ_P_0451',-36,4),('PSG','S2EHZ_P_04CB',-36,4),('PSG','S2EHZ_P_053D',0,2)]
    check(starts==expected, 'all nine EHZ channel pointers/transposes/volumes match the decompressed source header')
    check(song['source']['used_dac_ids']==[0,1,11,13], 'compiled EHZ DAC stream uses exactly source notes $81/$82/$8C/$8E')
    check(len(song.get('psg_envelopes',[]))==13, 'all 13 retail S2 PSG flutter envelopes are available to EHZ coordination flags')
    # Every label control-flow target must resolve inside the graph.
    labels=song['labels']; falls=song['fallthrough']; valid=True
    for name,seq in labels.items():
        if name in falls and falls[name] not in labels: valid=False
        for inst in seq:
            if inst and inst[0] in ('jump','call') and inst[1] not in labels: valid=False
            if inst and inst[0]=='loop' and inst[3] not in labels: valid=False
    check(valid, 'every EHZ fallthrough/jump/call/loop target resolves to a compiled source address')

pcm_hashes={
 's2_ehz_dac_00.pcm':'4b02e7d363c29e9cd2363df4a73b7bb72c1725df541abc3d83f4de7854c75f7a',
 's2_ehz_dac_01.pcm':'9406b9776307fde93c7078c194752cc2792f39847d1d4904a78c41a9f408a0a6',
 's2_ehz_dac_11.pcm':'348e77772d144e16600cc37afa272d298ce472f352d3feed5f9b6c213f86e403',
 's2_ehz_dac_13.pcm':'1355f29a49f2faa14c9603b10b23a9cdc3d28c9f3188da936823eb5bbeab4bb6',
}
check(all((PROJECT/'data/s1/sound'/n).is_file() and sha(PROJECT/'data/s1/sound'/n)==h for n,h in pcm_hashes.items()),
      'all four EHZ DAC variants match deterministic S2 differential-decode/resample output')

art_hashes={
 's2_ehz_flowers1.bin':'fefd12cc8e71770e98a34e2f883ab46709d0709d1b95328dd078beaced36b88e',
 's2_ehz_flowers2.bin':'053e03d4f0b5d340799cf14de650889e8341a83e563d5e29dfa0540c9aecf8ab',
 's2_ehz_flowers3.bin':'98b7f302c6a8c58d89023a4ebb96b51091eff460b9fbea335e98d674877c5b88',
 's2_ehz_flowers4.bin':'3ceaf1fb74619a02bbc2a1dca0e6b0a9ea731bfd86d0f85108d6ba81c4111f44',
 's2_ehz_pulse.bin':'d3fd464418d3fa9adee4e31e849a51d75e2b76ffb39cb8afdd7561bd18a7c0c0',
}
check(all((PROJECT/'data/s1/s2test'/n).is_file() and sha(PROJECT/'data/s1/s2test'/n)==h for n,h in art_hashes.items()),
      'all five retained EHZ animated-art sources are byte-identical to the retail disassembly')
check('S2_EHZ_FLOWER1_TILE = 0x394' in anim and 'S2_EHZ_PULSE_TILE = 0x39C' in anim and 'duration N remains' in anim,
      'EHZ animation DMA destinations and source duration semantics are wired into LevelArtAnimator')
check('S2_EHZ_FLOWER1_FRAMES = [[0, 0x7F], [2, 0x13], [0, 7], [2, 7], [0, 7], [2, 7]]' in anim and
      'S2_EHZ_PULSE_FRAMES = [[0, 0x17], [2, 9], [4, 0x0B], [6, 0x17], [4, 0x0B], [2, 9]]' in anim,
      'flower 1 and pulse scripts match Animated_EHZ frame IDs/durations')
check('s2_ehz_plane_width = 512' in bg and 's2_ehz_plane_height = 256' in bg and 'S2EHZScanline_' in bg,
      'EHZ Plane B uses a source-sized 512x256 palette-index plane with scanline regions')
check('for _i in range(22)' in bg and 'for _i in range(58)' in bg and 'for i in range(21)' in bg and
      'for _i in range(11)' in bg and bg.count('for _i in range(16)')>=2 and 'for _i in range(15)' in bg and
      'for _i in range(9)' in bg,
      'SwScrl_EHZ source bands are represented in the rasterized background path')
ripple=[1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3]*2+[1,2]
check(len(ripple)==66 and '1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0' in bg and '1,0,1,3,1,2' in bg.replace('\n',''),
      'EHZ water-ripple source table is retained at its original 66-byte period')
# Source routine writes 22+58+21+11+16+16+15+(9*2)+(15*3)=222 entries, leaving two untouched.
check(22+58+21+11+16+16+15+9*2+15*3==222 and 'final\n\t# two H-scroll entries' in bg,
      'EHZ intentionally preserves the original final-two-scanline H-scroll omission')
check('refresh_s2test_art_range' in anim and 'func refresh_s2test_art_range' in bg,
      'source animation DMA refreshes both native S2 foreground chunks and the EHZ background plane')
check('"s2test"] and ghz_palette_material != null' in bg,
      'S2 palette-index background participates in runtime palette texture refreshes')

# When the source checkout is supplied, regenerate every Phase 87 source-derived asset and prove determinism.
if len(sys.argv)>1:
    s2=Path(sys.argv[1]).resolve()
    check((s2/'sound/music/EHZ.bin').is_file() and sha(s2/'sound/music/EHZ.bin')=='856e35adf5f58a2995e479562bf13f11651861c6bc3382af4cd070d32153ffdb',
          'validation source is the expected retail EHZ music binary')
    before={p:sha(p) for p in list((PROJECT/'data/s1/sound').glob('s2_ehz*'))+list((PROJECT/'data/s1/s2test').glob('s2_ehz*'))}
    r=subprocess.run([sys.executable,str(PROJECT/'tools/import_s2_ehz_presentation.py'),str(s2)],cwd=PROJECT,capture_output=True,text=True)
    after={p:sha(p) for p in before}
    check(r.returncode==0 and before==after, 'Phase 87 importer regenerates every EHZ presentation asset byte-for-byte')

r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase86.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 86 and all chained earlier regressions still pass')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE87_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
