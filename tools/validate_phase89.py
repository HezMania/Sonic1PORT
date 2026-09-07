#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
DATA=PROJECT/'data/s1/s2test'
SOUND=PROJECT/'data/s1/sound'
ASSET=PROJECT/'assets/objects/s2_ehz'
checks=[]
def check(ok,msg):
    ok=bool(ok); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def png_count(folder): return len(list((ASSET/folder).glob('*.png')))

catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()
main=(PROJECT/'scripts/main.gd').read_text()
camera=(PROJECT/'scripts/camera/sonic_camera.gd').read_text()
manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
boss=(PROJECT/'scripts/objects/s2_ehz_boss_object.gd').read_text()
prison=(PROJECT/'scripts/objects/s2_egg_prison_object.gd').read_text()
audio=(PROJECT/'scripts/audio/sonic_audio.gd').read_text()

check('"dynamic_events": "s2_ehz2" if act == 2 else "none"' in catalog,
      'EHZ2 selects the retail boss dynamic-event path without changing EHZ1')
check('0x3E: return S2EggPrisonObjectClass.new()' in manager and 'S2EggPrisonObjectClass' in manager,
      'S2 Object $3E now dispatches to its own Egg Prison implementation')
check('spawn_s2_ehz_boss' in manager and 'S2EHZBossObjectClass.new()' in manager,
      'LevEvents can create the dedicated retail S2 Object $56 boss')
check('unlock_s2_ehz_boss_right_boundary' in manager and '0x2AB0' in manager,
      'EHZ boss escape expands the right camera boundary toward source $2AB0')

for token in ['0x2780','0x28F0','0x390','0x388','0x5A']:
    check(token in camera, f'EHZ2 DLE retains source threshold {token}')
check('s2_ehz2_music_fade_requested = true' in camera and 'boss_triggered = true' in camera,
      'EHZ2 DLE separates arena music fade from the delayed boss creation trigger')
check('SonicAudio.MUS_S2_BOSS' in main and 'sonic_camera.s2_ehz2_music_fade_requested' in main,
      'main loop stops EHZ music for the prelude and starts retail S2 Boss music at spawn')
check('spawn_s2_ehz_boss()' in main and 's2_ehz2_boss_act' in main,
      'main loop wires the EHZ2 DLE trigger to Object $56')
check('MUS_S2_END_LEVEL if current_zone == LevelCatalog.ZONE_S2_TEST' in main,
      'S2 acts use retail End-of-Level music for the results sequence')
check('_s2_boss_prelude_stopped = false' in main[main.index('func _complete_regular_death_restart'):main.index('func _restart_level_presentation_after_death')],
      'death/Starpost retries reset the EHZ2 prelude and boss-music gates')

for token in ['var hits := 8','LEFT_TURN_X := 0x28A0','RIGHT_TURN_X := 0x2B08','START_X := 0x2AF0','START_Y := 0x2F8','JOIN_X := 0x29D0','JOIN_Y := 0x41E']:
    check(token in boss, f'Object $56 preserves source boss constant: {token}')
for token in ['timer = 0x3C','invincibility_timer = 0x20','vel_y = -0x180','explosion_timer = 0xB3','timer = 0x0C','timer = 0x32','timer = 0x60']:
    check(token in boss, f'Object $56 preserves source timer/velocity: {token}')
check('_maybe_detach_spike_on_last_hit' in boss and 'hits != 1' in boss and 'spike_detach_right' in boss,
      'Object $56 implements the one-hit-left directional spike separation rule')
check('manager.add_score(1000)' in boss and 'manager.set_boss_defeated()' in boss,
      'boss defeat awards 1000 points and enters the source defeated-flag escape flow')
check('SonicAudio.play_music(SonicAudio.MUS_S2_EHZ, true)' in boss,
      'EHZ music restarts at the source post-defeat propeller stage')

for token in ['timer = 0x1D','lid_vel_y = -0x400','lid_vel_x = 0x800','timer = 0xB4','for i in range(8)','manager.prison_animals_alive()','manager.begin_act_complete()']:
    check(token in prison, f'Egg Prison preserves source release behavior: {token}')
check('button_sprite.position.y = -0x20' in prison and 'spawn_y - 0x28' in prison,
      'Egg Prison switch sits at source y-$28 and lowers eight pixels when pressed')
check('manager.time_frozen = true' in prison,
      'Egg Prison switch stops the HUD level timer when pressed, matching Update_HUD_timer')
check('open_anim_tick' in prison and 'state < STATE_RELEASE' in prison,
      'Egg Prison opening animation starts from activation rather than level-spawn age')

obj=(DATA/'ehz2_objects.bin').read_bytes()
records=[]
for i in range(0,len(obj),6):
    x=int.from_bytes(obj[i:i+2],'big'); yw=int.from_bytes(obj[i+2:i+4],'big')
    records.append((x,yw&0x0FFF,obj[i+4],obj[i+5]))
counts=Counter(r[2] for r in records)
check(len(records)==158 and counts[0x3E]==1,
      'EHZ2 still preserves all 158 retail placement records including one Egg Prison')
check((0x2B50,0x422,0x3E,0) in records and (0x29C0,0x429,0x0D,0) in records,
      'retail EHZ2 capsule/signpost placements remain byte-faithful at $2B50/$29C0')
implemented={0x03,0x06,0x0D,0x11,0x18,0x1C,0x26,0x36,0x3E,0x41,0x49,0x4B,0x5C,0x79,0x9D}
check(sum(counts[x] for x in implemented)==158,
      'all 158 source-placed EHZ2 objects now map to implemented runtime classes')

expected_counts={'boss_vehicle_pal0':7,'boss_vehicle_pal1':7,'boss_ground_pal0':8,'boss_ground_pal1':8,'boss_propeller':7,'egg_prison':6}
for folder,n in expected_counts.items():
    check(png_count(folder)==n, f'{folder} packages all {n} source mapping frames')

songs=json.loads((SOUND/'s2_ehz_smps.json').read_text())['music']
check(all(str(x) in songs for x in (0x194,0x195,0x196)),
      'S2 music database contains EHZ, Boss and End-of-Level songs')
check(songs[str(0x195)]['header']['tempo_mod']==0xE3 and songs[str(0x195)]['source']['used_dac_ids']==[0,1,8,10],
      'retail Boss SMPS graph keeps tempo $E3 and source DAC event set')
check(songs[str(0x196)]['header']['tempo_mod']==0xAA and songs[str(0x196)]['source']['used_dac_ids']==[0,1,7,10],
      'retail End-of-Level SMPS graph keeps tempo $AA and source DAC event set')
check('const MUS_S2_BOSS := 0x195' in audio and 'const MUS_S2_END_LEVEL := 0x196' in audio,
      'runtime exposes isolated port-local IDs for both new Sonic 2 songs')
for event in (7,8,10):
    p=SOUND/f's2_ehz_dac_{event:02d}.pcm'
    check(p.is_file() and p.stat().st_size>1000 and f'{event}: _load_pcm16("res://data/s1/sound/s2_ehz_dac_{event:02d}.pcm")' in audio,
          f'S2 DAC event {event} has decoded PCM and is registered by the driver')

# Verified presentation/performance baseline must remain intact.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase87_hotfix1.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 87 Hotfix 1 presentation/performance regression chain still passes')

# Optional deterministic regeneration from the supplied retail disassembly.
if len(sys.argv)>1:
    src=Path(sys.argv[1]).resolve()
    tracked=[]
    for folder in expected_counts:
        tracked += sorted((ASSET/folder).glob('*.png'))
    tracked += [SOUND/'s2_ehz_smps.json'] + [SOUND/f's2_ehz_dac_{e:02d}.pcm' for e in (7,8,10)]
    before={str(p.relative_to(PROJECT)):sha(p) for p in tracked}
    rr=subprocess.run([sys.executable,str(PROJECT/'tools/import_s2_ehz_boss.py'),str(src)],cwd=PROJECT,capture_output=True,text=True)
    after={str(p.relative_to(PROJECT)):sha(p) for p in tracked}
    check(rr.returncode==0 and before==after,
          'Phase 89 importer regenerates boss/capsule art, SMPS graphs and DAC PCM byte-for-byte from retail source')

passed=sum(ok for ok,_ in checks); total=len(checks)
text='\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n'
(PROJECT/'PHASE89_VALIDATION_RESULTS.txt').write_text(text)
print(f'\n{passed}/{total} checks passed')
if passed!=total: raise SystemExit(1)
