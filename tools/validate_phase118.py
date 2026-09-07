#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, py_compile, sys
from pathlib import Path
P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def func(t,name):
    a=t.index('func '+name); b=t.find('\nfunc ',a+1); return t[a:len(t) if b<0 else b]

manifest=json.loads((P/'data/s1/s2test/phase118_ooz_boss_manifest.json').read_text())
main=txt('scripts/main.gd'); cam=txt('scripts/camera/sonic_camera.gd'); om=txt('scripts/objects/object_manager.gd')
oo=txt('scripts/objects/s2_ooz_object.gd'); proj=txt('scripts/objects/s2_ooz_projectile.gd')
player=txt('scripts/player/sonic_player.gd'); swing=txt('scripts/objects/s2_arz_swing_object.gd')
pal=txt('scripts/render/level_palette_cycler.gd'); cat=txt('scripts/data/level_catalog.gd')
boss=txt('scripts/objects/s2_ooz_boss_object.gd'); prison=txt('scripts/objects/s2_egg_prison_object.gd')

# Imported art/palette/manifest.
ck(manifest.get('phase')==118,'Manifest identifies Phase 118')
ck(manifest.get('boss')=='Object $55' and manifest.get('boss_hits')==8,'Manifest identifies eight-hit retail Object $55')
ck(manifest.get('boss_start')==[0x2940,0x2D0],'Manifest records retail boss start $2940,$2D0')
ck(manifest.get('laser_targets_y')==[0x238,0x230,0x240,0x25F],'Manifest records exact four laser target Ys')
ck(manifest.get('egg_prison')==[0x2AC0,0x240],'Manifest records exact OOZ2 Egg Prison placement')
camman=manifest.get('camera',{})
for key,val in [('oil_transition_x',0x2668),('oil_y',0x2D8),('arena_lock_x',0x2880),('arena_max_x',0x28C0),('camera_bottom',0x1E0),('camera_top',0x1D8),('screen_shift',0x5A),('defeat_right',0x2A20)]:
    ck(camman.get(key)==val,f'Manifest camera constant {key} is retail {val:#x}')
for frame in range(0x16): ck((P/f'assets/objects/s2_ooz/boss/parts/{frame:02d}.png').is_file(),f'OOZ boss mapping frame ${frame:02X} packaged')
for frame in range(6): ck((P/f'assets/objects/s2_ooz/egg_prison/{frame:02d}.png').is_file(),f'OOZ Egg Prison frame {frame} packaged')
ck((P/'data/s1/palette/S2 OOZ Boss.bin').is_file() and (P/'data/s1/palette/S2 OOZ Boss.bin').stat().st_size==32,'OOZ boss palette packaged as one CRAM line')
for rel,dig in manifest.get('files',{}).items(): ck((P/rel).is_file() and sha(P/rel)==dig,f'Imported output hash stable: {rel}')

# Phase117 runtime fixes.
cap=func(oo,'_capture_launcher(p: SonicPlayer) -> void')
breaker=func(oo,'_break_launcher(p: SonicPlayer) -> void')
ck('if subtype != 0' in breaker and '_capture_launcher(p)' in breaker,'Broken subtype-$01 giant launcher directly enters invisible-launcher capture')
ck('p.vel_x = 0' in cap and 'p.vel_y = -0x800' in cap,'Giant vertical launcher uses retail 0/-$800 launch vector')
ck('p.inertia = 0x800' in cap and 'p.object_control_override = true' in cap,'Obj3D capture preserves retail rolling object-control state')
ck('ooz_transport_invulnerable := false' in player,'Sonic owns explicit OOZ transport invulnerability state')
ck('or ooz_transport_invulnerable or' in func(player,'apply_hazard_hit(source_x: int) -> bool'),'Hazard damage is suppressed while an OOZ transporter owns Sonic')
trans=func(oo,'_capture_transporter(p: SonicPlayer) -> void')
ck('p.ooz_transport_invulnerable = true' in trans,'Obj48 enables transport invulnerability on capture')
release=func(oo,'_release_ooz_control(p: SonicPlayer) -> void')
ck('p.ooz_transport_invulnerable = false' in release,'Owning OOZ controller clears transport invulnerability on release')
ck('ooz_transport_invulnerable = false' in func(player,'respawn() -> void'),'Respawn always clears OOZ transport invulnerability')
spinit=func(oo,'_init_sliding_spike() -> void'); sptick=func(oo,'_tick_sliding_spike() -> void')
ck('_new_sprite("sliding_spike", 0, 12)' in spinit,'Sliding spike heads render in front of foreground terrain')
ck('nx <= sliding_spike_min_x' in sptick and 'nx >= sliding_spike_max_x' in sptick,'Sliding spike endpoint motion clamps robustly at source bounds')
ck('sliding_spike_dir[0] > 0 and sliding_spike_dir[1] < 0' in sptick,'Paired spike collision test runs only while heads move toward each other')
ck('sliding_spike_x[0] - 0x18 >= sliding_spike_x[1] + 0x18' in sptick,'Paired spikes catch the source $30 separation crossing and reverse together')
ck('sprite.z_index = 1 if folder == "octus" else 3' in proj,'Octus projectiles render behind the Octus body')
vfan=func(oo,'_apply_vertical_fan(p: SonicPlayer) -> void')
ck('manager.s2_source_osc_byte(0x14)' in vfan,'Vertical fan still uses retail oscillator channel $14')
ck('var fan_delta_fixed: int = -d1 << 12' in vfan,'Vertical fan retains source /16 force as native 16.16 subpixels')
ck('p.fixed_y += fan_delta_fixed' in vfan and 'p.vel_y = 0' in vfan,'Vertical fan applies smooth fixed-point correction and retains zero Y velocity')
aqw=func(oo,'_update_aquis_wing() -> void')
ck('Vector2(10 if status_faces_left else -10, -6)' in aqw,'Aquis wing offset follows corrected reconstructed-art side with retail $A/-6 magnitude')
resolve=func(swing,'_resolve_platform(index: int, old_local: Vector2) -> void')
ck('0x10 if manager != null and bool(manager.level_definition.get("s2_ooz", false)) else 8' in resolve,'OOZ swinging platform raises support top by 8 pixels without changing ARZ behavior')

# Level event / palette / spawn wiring.
dle=func(cam,'_dle_s2_ooz2() -> void')
for needle,msg in [('screen_x >= 0x2668','OOZ2 oil transition trigger $2668'),('target_bottom = 0x1E0','OOZ2 camera bottom $1E0'),('screen_x >= 0x2880','OOZ2 arena trigger $2880'),('limit_left = 0x2880','OOZ2 arena left $2880'),('limit_right = 0x28C0','OOZ2 arena right $28C0'),('limit_top = 0x1D8','OOZ2 top clamp $1D8'),('s2_ooz2_music_fade_requested = true','OOZ2 requests retail music fade'),('s2_ooz2_boss_palette_requested = true','OOZ2 requests Pal_OOZ_B'),('s2_ooz2_event_timer >= 0x5A','OOZ2 waits exact $5A ScreenShift frames'),('s2_ooz2_boss_spawn_requested = true','OOZ2 requests Object $55 allocation'),('dle_routine = 6','OOZ2 advances to post-boss Routine4 state')]: ck(needle in dle,msg)
ck('"s2_ooz_boss": act == 2' in cat,'Only OOZ2 advertises native Object $55 boss support')
ck('var s2_ooz2_boss_act' in main,'Main loop reads OOZ2 boss capability')
ck('activate_s2_ooz_boss_palette()' in main,'Main loop applies OOZ boss palette')
start=func(main,'_tick_s2_ooz2_boss_start(player: SonicPlayer, active: bool) -> void')
ck('0x5A' in start and 'spawn_s2_ooz_boss()' in start,'Main watchdog preserves exact boss wait and idempotent spawn')
ck('SonicAudio.MUS_S2_BOSS' in start,'OOZ2 boss starts Sonic 2 boss music')
spawn=func(om,'spawn_s2_ooz_boss() -> bool')
ck('boss_limit_right = 0x28C0' in spawn and 'S2OOZBossObjectClass.new()' in spawn,'Object manager spawns OOZ boss with retail arena max')
unlock=func(om,'unlock_s2_ooz_boss_right_boundary() -> void')
ck('mini(0x2A20, boss_limit_right + 2)' in unlock,'OOZ boss defeat opens right camera exactly 2 px/frame to $2A20')
activate=func(pal,'activate_s2_ooz_boss_palette() -> void')
ck('_write_run(level.palette, 16, s2_ooz_boss_palette, 0, 16)' in activate,'Pal_OOZ_B replaces exactly CRAM line 1')
ck('s2_ooz_boss_palette = _read_palette("S2 OOZ Boss.bin")' in pal,'Palette cycler loads imported OOZ boss palette')
ck('ZONE_S2_OOZ_TEST' in main[main.index('MUS_S2_END_LEVEL'):main.index('MUS_S2_END_LEVEL')+600],'OOZ completion uses Sonic 2 end-level music')
ck('art_folder = "s2_ooz/egg_prison"' in prison,'OOZ2 Egg Prison uses OOZ boss-palette art')

# Object $55 lifecycle.
for needle,msg in [('var hits := 8','Object $55 starts with eight hits'),('BOSS_X := 0x2940','Main vehicle X is $2940'),('MAIN_START_Y := 0x2D0','Main vehicle start/dive Y is $2D0'),('MAIN_HOVER_Y := 0x290','Main hover target Y is $290'),('MAIN_BOB_Y := 0x28C','Main pre-dive bob target Y is $28C'),('countdown = 0xA8','Unhit main hover wait is $A8'),('vel_y = -0x80','Boss uses source -$80 rise velocity'),('vel_y = 0x80','Boss uses source +$80 dive/lower velocity'),('if cycle_was_hit:','Hit latch selects the retaliatory attack path'),('_enter_spike_chain()','Hit main cycle enters spike chain'),('_enter_shooter()','Unhit/main return enters laser shooter')]: ck(needle in boss,msg)
sh=func(boss,'_tick_shooter() -> void')
ck('countdown = 0x80' in sh and 'shots_remaining = 3' in sh,'Laser shooter waits $80 and prepares three shots')
ck('countdown = 0x28' in sh,'Laser shooter waits $28 between shots')
choose=func(boss,'_choose_laser_target() -> void')
ck('used_laser_positions' in choose and 'LASER_TARGETS[candidate]' in choose,'Laser shooter selects unique entries from exact target table')
fire=func(boss,'_fire_laser() -> void')
ck('0x400 if flip_x else -0x400' in fire and '0x20 if flip_x else -0x20' in fire,'Laser spawn uses source ±$20 offset / ±$400 X velocity')
las=func(boss,'_tick_lasers() -> void')
ck('0x2988' in las and '0x28F8' in las and '0x250' in las,'Laser ground crossings seed the two exact source wave origins at ground Y $250')
wave=func(boss,'_tick_waves() -> void')
ck('int(w["count"]) > 0' in wave and '* 0x10' in wave,'Floor wave propagates finitely at 16-pixel spacing')
ck('WAVE_FRAMES' in wave and 'ai >= WAVE_FRAMES.size()' in wave,'Floor-wave source animation reaches deterministic cleanup')
spike=func(boss,'_spike_points() -> Array[Vector2i]')
ck('0x68' in spike and 'phase - 6' in spike,'Spike chain uses source $68 radius and 6-angle linked spacing')
ck('sine_count >= 0xFE' in func(boss,'_tick_spike_chain() -> void'),'Spike chain exits at retail sine count $FE')
head=func(boss,'_spike_head_frame() -> int')
ck('0x52' in head and '0x6B' in head and '0x92' in head and '0x15' in head,'Spike-head mapping thresholds match source')
hit=func(boss,'_check_main_collision() -> void')
ck('hits -= 1' in hit and 'invulnerable_timer = 0x20' in hit and 'cycle_was_hit = true' in hit,'Boss hit decrements one hit, starts $20 immunity and latches retaliation')
defeat=func(boss,'_tick_defeated() -> void')
ck('countdown' in defeat and 'manager.set_boss_defeated()' in defeat,'Defeat countdown raises shared Boss_defeated flag')
ck('SonicAudio.MUS_S2_OOZ' in defeat,'Defeat restores Oil Ocean level music')
ck('manager.unlock_s2_ooz_boss_right_boundary()' in defeat,'Defeated boss drives retail right-camera expansion')
ck('countdown = 0xB3' in func(boss,'_begin_defeat() -> void'),'Boss defeat timer is retail $B3')

# Source confirmation when supplied.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    source=[('move.w\t#$2D8,(Oil+y_pos).w','Retail oil Y $2D8 confirmed'),('move.w\t#$28C0,(Camera_Max_X_pos).w','Retail arena max X $28C0 confirmed'),('moveq\t#PalID_OOZ_B,d0','Retail boss palette load confirmed'),('cmpi.b\t#$5A,(ScreenShift).w','Retail $5A ScreenShift wait confirmed'),('move.b\t#ObjID_OOZBoss,id(a1)','Retail Object $55 allocation confirmed'),('move.b\t#8,boss_hitcount2(a0)','Retail Object $55 eight hits confirmed'),('move.w\t#$A8,(Boss_Countdown).w','Retail main hover wait $A8 confirmed'),('dc.w  $238','Retail laser target $238 confirmed'),('dc.w  $25F','Retail laser target $25F confirmed'),('move.w\t#5,Obj55_Wave_delay(a1)','Retail wave propagation delay 5 confirmed'),('move.b\t#7,Obj55_Wave_count(a1)','Retail seven child waves confirmed'),('move.w\t#$10,d0','Retail 16-pixel wave spacing confirmed'),('cmpi.b\t#$FE,boss_sine_count(a0)','Retail spike-chain end angle $FE confirmed'),('muls.w\t#$68,d1','Retail spike-chain radius $68 confirmed'),('move.w\t#$B3,(Boss_Countdown).w','Retail generic boss defeat countdown $B3 confirmed'),('cmpi.w\t#$2A20,(Camera_Max_X_pos).w','Retail post-boss camera target $2A20 confirmed')]
    for needle,msg in source: ck(needle in asm,msg)
    ck((P/'data/s1/palette/S2 OOZ Boss.bin').read_bytes()==(S2/'art/palettes/OOZ Boss.bin').read_bytes(),'Packaged OOZ boss palette is byte-identical to retail')
    ck((S2/'art/nemesis/OOZ boss.bin').is_file() and (S2/'mappings/sprite/obj55.bin').is_file(),'Retail OOZ boss art/mapping sources present')

# Scripts/assets/docs/tooling.
for rel in ['tools/import_s2_ooz_boss_phase118.py','tools/validate_phase118.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')
for rel in ['scripts/objects/s2_ooz_object.gd','scripts/objects/s2_ooz_projectile.gd','scripts/objects/s2_ooz_boss_object.gd','scripts/objects/s2_arz_swing_object.gd','scripts/objects/s2_egg_prison_object.gd','scripts/player/sonic_player.gd','scripts/objects/object_manager.gd','scripts/data/level_catalog.gd','scripts/camera/sonic_camera.gd','scripts/render/level_palette_cycler.gd','scripts/main.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')
ck((P/'PHASE118_SONIC2_OIL_OCEAN_BOSS_END.md').is_file(),'Phase 118 implementation report packaged')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
