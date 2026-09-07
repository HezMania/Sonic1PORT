#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, py_compile, struct, sys
from pathlib import Path
from PIL import Image

P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(c,m):
    checks.append((bool(c),m)); print(('PASS: ' if c else 'FAIL: ')+m)
def sha(p:Path): return hashlib.sha256(p.read_bytes()).hexdigest()
def txt(rel): return (P/rel).read_text(errors='replace')

def func(text,name):
    marker='func '+name
    a=text.index(marker)
    b=text.find('\nfunc ',a+1)
    return text[a:len(text) if b<0 else b]

manifest=json.loads((P/'data/s1/s2test/phase114_mcz_boss_manifest.json').read_text())
boss=txt('scripts/objects/s2_mcz_boss_object.gd')
om=txt('scripts/objects/object_manager.gd')
cam=txt('scripts/camera/sonic_camera.gd')
main=txt('scripts/main.gd')
cat=txt('scripts/data/level_catalog.gd')
pal=txt('scripts/render/level_palette_cycler.gd')
egg=txt('scripts/objects/s2_egg_prison_object.gd')

# Import manifest and source-rendered asset bank.
ck(manifest.get('phase')==114 and manifest.get('boss')=='Object $57','Phase 114 manifest identifies retail Object $57')
ck(manifest.get('boss_hits')==8,'Object $57 retail 8-hit count recorded')
ck(manifest.get('boss_start')==[0x21A0,0x560],'Object $57 exact start $21A0,$0560')
ck(manifest.get('boss_art_tiles')==0xCC,'MCZ boss Nemesis art decompresses to $CC tiles')
ck(manifest.get('eggpod_tiles')==0x60,'Eggpod Nemesis art decompresses to $60 tiles')
ck(manifest.get('eggpod_relative_tile')==0x140,'Eggpod bank reconstructed at exact +$140 tile offset')
ck(manifest.get('falling_art_tiles')==8,'MCZ falling rock/stalactite art is exactly 8 tiles')
ck(manifest.get('camera')=={'prelude_x':0x2080,'lock_x':0x20F0,'bottom':0x5D0,'top':0x5C8,'screen_shift':0x5A,'escape_right':0x2240},'MCZ2 boss camera constants match retail')
ck(manifest.get('arena')=={'left_patrol':0x2120,'right_patrol':0x2200,'bottom_y':0x660},'Object $57 patrol arena constants match retail')
ck(manifest.get('egg_prison')==[0x22E0,0x660],'MCZ2 Egg Prison placement recorded at $22E0,$0660')
for rel,h in manifest['files'].items():
    p=P/rel
    ck(p.is_file() and sha(p)==h,f'Imported asset hash stable: {rel}')
parts=sorted((P/'assets/objects/s2_mcz/boss/parts').glob('*.png'))
fall=sorted((P/'assets/objects/s2_mcz/boss/falling').glob('*.png'))
pris=sorted((P/'assets/objects/s2_mcz/egg_prison').glob('*.png'))
ck([p.stem for p in parts]==[f'{i:02d}' for i in list(range(13))+list(range(14,20))],'Boss part bank contains mapping frames $00-$0C,$0E-$13')
ck([p.stem for p in fall]==['13','20'],'Falling art contains mapping frames $0D/$14 only')
ck([p.stem for p in pris]==[f'{i:02d}' for i in range(6)],'MCZ Egg Prison contains all six retail mapping frames')
for p in parts+fall+pris:
    try:
        im=Image.open(p); ok=im.width>0 and im.height>0 and im.mode=='RGBA'
    except Exception: ok=False
    ck(ok,f'{p.relative_to(P)} is a valid nonempty RGBA source render')
ck((P/'data/s1/palette/S2 MCZ Boss.bin').stat().st_size==32,'Pal_MCZ_B packaged as exact one-line 32-byte CRAM bank')

# Camera / event prelude.
dle=func(cam,'_dle_s2_mcz2() -> void')
for token,msg in [
 ('screen_x >= 0x2080','LevEvents_MCZ2 first threshold is $2080'),
 ('target_bottom = 0x5D0','MCZ2 boss approach target bottom is $5D0'),
 ('screen_x >= 0x20F0','MCZ2 arena lock threshold is $20F0'),
 ('limit_left = 0x20F0','MCZ2 left boundary hard-locks at $20F0'),
 ('limit_right = 0x20F0','MCZ2 right boundary hard-locks at $20F0'),
 ('screen_y >= 0x5C8','MCZ2 top-clamp threshold is $5C8'),
 ('limit_top = 0x5C8','MCZ2 top boundary clamps at $5C8'),
 ('s2_mcz2_music_fade_requested = true','MCZ2 lock requests level-music fade'),
 ('s2_mcz2_boss_palette_requested = true','MCZ2 lock requests Pal_MCZ_B'),
 ('s2_mcz2_event_timer += 1','MCZ2 Routine3 advances ScreenShift clock'),
 ('s2_mcz2_event_timer >= 0x5A','MCZ2 waits exact $5A frames'),
 ('s2_mcz2_boss_spawn_requested = true','MCZ2 Routine3 requests Object $57 allocation'),
 ('dle_routine = 6','MCZ2 enters post-spawn Routine4-equivalent state'),
 ('limit_left = screen_x','MCZ2 post-boss routine follows Camera_X on the left'),
]: ck(token in dle,msg)
for token,msg in [
 ('const S2_MCZ_RIPPLE_DATA: Array[int] = [','Camera packages retail SwScrl_RippleData for MCZ screen shake'),
 ('camera.offset = Vector2(S2_MCZ_RIPPLE_DATA[i + 1], S2_MCZ_RIPPLE_DATA[i])','MCZ screen shake applies source horizontal/vertical sample pair'),
 ('var s2_mcz_screen_shake_active := false','Camera owns MCZ visual screen-shake flag'),
 ('var s2_mcz2_event_timer := 0','Camera owns MCZ2 ScreenShift state'),
 ('var s2_mcz2_music_fade_requested := false','Camera owns MCZ2 fade request'),
 ('var s2_mcz2_boss_palette_requested := false','Camera owns MCZ2 boss-palette request'),
 ('var s2_mcz2_boss_spawn_requested := false','Camera owns persistent MCZ2 boss spawn request'),
]: ck(token in cam,msg)

# Main-loop durable boss handoff and arena boundaries.
for token,msg in [
 ('var _s2_mcz2_boss_gate_timer := -1','Main has MCZ2 boss gate watchdog'),
 ('var _s2_mcz2_boss_spawn_attempts := 0','Main has MCZ2 durable spawn retry counter'),
 ('bool(level.definition.get("s2_mcz_boss", false))','Main detects MCZ2 boss act from level data'),
 ('s2_mcz2_boss_act and sonic_camera.dle_routine >= 4 and object_manager.boss_status < 1','Player runtime bounds lock during MCZ2 boss'),
 ('sonic_camera.limit_left = 0x20F0','Main enforces retail MCZ2 left arena lock'),
 ('sonic_camera.limit_right = 0x20F0','Main enforces retail MCZ2 right arena lock'),
 ('sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)','Main accepts Object $57 escape boundary release'),
 ('level_palette_cycler.activate_s2_mcz_boss_palette()','Main activates Pal_MCZ_B at the arena handoff'),
 ('_tick_s2_mcz2_boss_start(player, s2_mcz2_boss_act)','Main executes durable MCZ2 boss prelude helper'),
 ('object_manager.boss_object.get("rumble_active")','Main bridges Object $57 Screen_Shaking_Flag into the camera'),
 ('object_manager.elapsed_frames & 0x3F','MCZ visual shake indexes the source 64-step Timer_frames phase'),
 ('SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)','Boss helper starts Sonic 2 boss music'),
]: ck(token in main,msg)
helper=func(main,'_tick_s2_mcz2_boss_start(player: SonicPlayer, active: bool) -> void')
for token,msg in [
 ('sonic_camera.screen_x >= 0x20F0','MCZ2 watchdog recognizes arena camera threshold'),
 ('player.pixel_x() >= 0x2190','MCZ2 watchdog recovers from a player already inside arena'),
 ('sonic_camera.s2_mcz2_event_timer','MCZ2 watchdog synchronizes to camera ScreenShift'),
 ('0x5A','MCZ2 watchdog preserves exact $5A wait'),
 ('object_manager.spawn_s2_mcz_boss()','MCZ2 watchdog allocates Object $57 idempotently'),
]: ck(token in helper,msg)

# Object-manager allocation and escape boundary.
for token,msg in [
 ('const S2MCZBossObjectClass = preload("res://scripts/objects/s2_mcz_boss_object.gd")','Object manager preloads native MCZ boss class'),
 ('func spawn_s2_mcz_boss() -> bool:','Object manager exposes MCZ boss allocator'),
 ('level_definition.get("s2_mcz_boss", false)','MCZ boss allocator is level-data gated'),
 ('boss_limit_right = 0x20F0','MCZ boss starts with exact locked right boundary'),
 ('boss.name = "S2MCZBoss"','Object $57 gets a dedicated transient instance'),
 ('func unlock_s2_mcz_boss_right_boundary() -> void:','Object manager exposes MCZ escape unlock'),
 ('mini(0x2240, boss_limit_right + 2)','MCZ escape expands Max_X exactly +2/frame to $2240'),
]: ck(token in om,msg)

# Native Object $57 state machine.
for token,msg in [
 ('var state: int = STATE_DESCEND_ROCKS','Object $57 starts in source boss_routine=2, not re-ascent routine 0'),
 ('const START_X := 0x21A0','Object $57 X start exact'),('const START_Y := 0x560','Object $57 Y start exact'),
 ('const ROCK_STOP_Y := 0x620','Falling-rock descent stops at Y $620'),('const ATTACK_Y := 0x660','Horizontal attack height is Y $660'),
 ('const LEFT_X := 0x2120','Boss left patrol clamp $2120'),('const RIGHT_X := 0x2200','Boss right patrol clamp $2200'),
 ('const FALL_X_MIN := 0x20F0','Falling hazard X minimum $20F0'),('const FALL_X_MAX := 0x2230','Falling hazard X maximum $2230'),
 ('const FALL_START_Y := 0x5F0','Falling hazard starts at Y $5F0'),('const FALL_DELETE_Y := 0x6F0','Falling hazard stop/delete Y $6F0'),
 ('var vel_y: int = 0xC0','Initial boss vertical velocity is +$C0'),('var countdown: int = 0x28','Source initial Boss_Countdown is $28'),
 ('var hits: int = 8','Native Object $57 requires eight hits'),('countdown = 0x64','Attack/re-ascent countdown is $64'),
 ('vel_x = 0x200 if facing_right else -0x200','Horizontal drill attack speed is $200'),('vel_y = -0xC0','Re-ascent speed is -$C0'),
 ('countdown = 0xB3','Final defeat explosion countdown is $B3'),('countdown = -0x12','Post-explosion hover countdown starts at -$12'),
 ('countdown == 0x18','Escape hover restores level music at source count $18'),('countdown >= 0x20','Escape flight begins at source count $20'),
 ('vel_x = 0x400','Escape X velocity is $400'),('vel_y = -0x40','Escape Y velocity is -$40'),
 ('manager.unlock_s2_mcz_boss_right_boundary()','Object $57 drives source +2 camera release'),
]: ck(token in boss,msg)

# Digger animations and collision modes.
for anim in range(3,13): ck(f'{anim}:' in boss,f'Digger animation sequence {anim:X} represented')
ck('const DIGGER_NEXT := {3:4,4:5,5:5,6:7,7:8,8:9,9:10,10:10,11:12,12:3}' in boss,'Digger transition graph matches Ani_obj57 $3-$C flow')
ck('const DIGGER_LOOP_INDEX := {5:1,10:1}' in boss,'Digger vertical/horizontal loop subanimations match $FC,1')
ck('if countdown <= 0x28:' in boss and 'collision_mode = 1' in boss,'Horizontal drill collision enables at Boss_Countdown <= $28')
ck('if countdown == 0x28:' in boss and 'collision_mode = 0' in boss,'Re-ascent restores vertical drill collision at source $28')
ck('(0x30 if facing_right else -0x30)' in boss and 'by + 4' in boss,'Horizontal drill hazard is X +/-$30,Y+$04')
ck('for hx in [bx + 0x14, bx - 0x14]:' in boss and '(by - 0x20)' in boss,'Vertical drill hazards are X +/-$14,Y-$20')
ck('4 + p.width_radius' in boss and '0x10 + p.height_radius' in boss,'Vertical drill hazard uses source $04x$10 radii')
ck('0x18 + p.width_radius' in boss and '0x18 + p.height_radius' in boss,'Central boss collision uses Touch_Sizes[$0F]=$18,$18')

# Falling rocks, screen rumble, break-up and visual phase.
ck('(visual_tick & 0x1F) == 0' in boss,'Falling-spike cadence includes source low-5==0 event')
ck('(visual_tick & 7) == 0 and not spawn_spike' in boss,'Falling-stone cadence includes remaining low-3==0 events')
ck('frame: int = 0x14 if spawn_spike else 0x0D' in boss,'Falling spike/stone mapping frames are $14/$0D')
ck('int(f["vy"]) + 0x10' in boss,'Falling debris net gravity is source $38-$28=$10')
ck('SonicAudio.SFX_RUMBLE' in boss and '(visual_tick & 0x1F) == 0' in boss,'Screen-shake phase plays rumble on source 32-frame cadence')
ck('countdown <= 0x78 and not diggers_detached' in boss,'Defeated drills begin separating at Boss_Countdown $78')
ck('digger_b_x_fixed -= 1 << 16' in boss and 'digger_a_x_fixed += 1 << 16' in boss,'Defeated drills separate one pixel/frame in opposite directions')
ck('digger_a_vy + 0x38' in boss and 'digger_b_vy + 0x38' in boss,'Detached drills use source +$38 gravity')
ck('face_frame = 19' in boss and 'face_frame = 18' in boss,'Burnt/hit Eggman frames $13/$12 represented')
ck('face_frame = 14 + ((visual_tick >> 3) & 1)' in boss,'Normal Eggman face uses source $0E/$0F pair')
ck('hover_frame = 5 + ((visual_tick >> 1) & 1)' in boss and 'var hover_frame: int = 7' in boss,'Hover fire frames $05/$06 and fire-off frame $07 represented')

# Palette and capsule handoff.
for token,msg in [
 ('var s2_mcz_boss_palette: Array[Color] = []','Palette cycler owns MCZ boss CRAM line'),
 ('var s2_mcz_boss_active: bool = false','Palette cycler tracks Current_Boss_ID-equivalent MCZ state'),
 ('if s2_mcz_boss_active:\n\t\treturn []','Normal MCZ lantern cycle stops during boss'),
 ('func activate_s2_mcz_boss_palette() -> void:','MCZ boss palette activation path exists'),
 ('_write_run(level.palette, 16, s2_mcz_boss_palette, 0, 16)','Pal_MCZ_B replaces exactly CRAM indices 16..31'),
 ('s2_mcz_boss_palette = _read_palette("S2 MCZ Boss.bin")','Pal_MCZ_B source file loads at setup'),
]: ck(token in pal,msg)
ck('"s2_mcz_boss": act == 2' in cat,'MCZ boss enabled only for Act 2')
ck('"s2_egg_prison_requires_boss": act == 2' in cat,'MCZ2 Egg Prison remains boss-gated')
ck('bool(manager.level_definition.get("s2_mcz", false))' in egg and 'art_folder = "s2_mcz/egg_prison"' in egg,'Egg Prison selects source-rendered MCZ capsule art')
ck('manager.set_boss_defeated()' in boss,'Object $57 exposes the Egg Prison only at post-defeat handoff')
ck('SonicAudio.play_music(SonicAudio.MUS_S2_MCZ, true)' in boss,'Object $57 restores Mystic Cave level music before capsule phase')
ck('return Vector2i(ZONE_S2_MCZ_TEST, 2) if act < 2 else Vector2i(ZONE_GHZ, 1)' in cat,'MCZ2 completed tally has a safe post-zone fallback until next retail zone import')

# Direct retail source confirmations and original placement bytes.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    needles=[
      ('move.w\t#$21A0,x_pos(a0)','Retail Obj57 X=$21A0 confirmed'),('move.w\t#$560,y_pos(a0)','Retail Obj57 Y=$560 confirmed'),
      ('move.b\t#8,boss_hitcount2(a0)','Retail Obj57 8-hit count confirmed'),('move.w\t#$C0,(Boss_Y_vel).w','Retail Obj57 initial +$C0 Y velocity confirmed'),
      ('move.b\t#2,boss_routine(a0)','Retail Obj57 starts in routine 2 confirmed'),('move.w\t#$28,(Boss_Countdown).w','Retail Obj57 initial countdown $28 confirmed'),
      ('cmpi.w\t#$620,(Boss_Y_pos).w','Retail rock-descent threshold $620 confirmed'),('cmpi.w\t#$660,(Boss_Y_pos).w','Retail attack Y $660 confirmed'),
      ('move.w\t#-$200,(Boss_X_vel).w','Retail horizontal base speed -$200 confirmed'),('move.w\t#$64,(Boss_Countdown).w','Retail attack/re-ascent countdown $64 confirmed'),
      ('move.w\t#-$C0,(Boss_Y_vel).w','Retail re-ascent velocity -$C0 confirmed'),('move.w\t#$B3,(Boss_Countdown).w','Retail defeat countdown $B3 confirmed'),
      ('move.w\t#-$12,(Boss_Countdown).w','Retail escape hover starts at -$12 confirmed'),('cmpi.w\t#$18,(Boss_Countdown).w','Retail level-music restore threshold $18 confirmed'),
      ('cmpi.w\t#$20,(Boss_Countdown).w','Retail escape-state threshold $20 confirmed'),('move.w\t#$400,(Boss_X_vel).w','Retail escape X velocity $400 confirmed'),
      ('move.w\t#-$40,(Boss_Y_vel).w','Retail escape Y velocity -$40 confirmed'),('cmpi.w\t#$2240,(Camera_Max_X_pos).w','Retail escape camera goal $2240 confirmed'),
      ('move.b\t#$14,mapping_frame(a1)','Retail falling spike mapping frame $14 confirmed'),('move.b\t#$B1,collision_flags(a1)','Retail falling spike hazard collision $B1 confirmed'),
      ('move.l\t#$40004,d1','Retail horizontal drill collision $04x$04 confirmed'),('move.l\t#$100004,d1','Retail vertical drill collision $04x$10 confirmed'),
      ('cmpi.b\t#$5A,(ScreenShift).w','Retail MCZ2 boss prelude waits ScreenShift $5A'),('move.b\t#ObjID_MCZBoss,id(a1)','Retail MCZ2 event allocates Obj57'),
      ('move.w\t#MusID_Boss,d0','Retail MCZ2 event starts boss music'),('moveq\t#PalID_MCZ_B,d0','Retail MCZ2 event loads Pal_MCZ_B'),
    ]
    for n,m in needles: ck(n in asm,m)
    boss_pal_src=S2/'art/palettes/MCZ Boss.bin'
    ck((P/'data/s1/palette/S2 MCZ Boss.bin').read_bytes()==boss_pal_src.read_bytes(),'Packaged Pal_MCZ_B is byte-identical to retail source')
    obj=(S2/'level/objects/MCZ_2.bin').read_bytes()
    records=[]
    for off in range(0,len(obj)-5,6):
        x=int.from_bytes(obj[off:off+2],'big'); yword=int.from_bytes(obj[off+2:off+4],'big'); oid=obj[off+4]; sub=obj[off+5]
        if x==0xFFFF: break
        records.append((x,yword&0x0FFF,oid,sub))
    ck((0x22E0,0x660,0x3E,0) in records,'Retail MCZ2 placement stream contains Egg Prison $3E at $22E0,$0660')

for rel in ['tools/import_s2_mcz_boss_phase114.py','tools/validate_phase114.py','tools/validate_phase113.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:'); [print(' - '+m) for m in bad]; raise SystemExit(1)
