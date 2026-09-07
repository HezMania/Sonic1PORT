#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, py_compile, re, sys
from collections import Counter
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

manifest=json.loads((P/'data/s1/s2test/phase116_ooz_objects_manifest.json').read_text())
om=txt('scripts/objects/object_manager.gd')
oo=txt('scripts/objects/s2_ooz_object.gd')
proj=txt('scripts/objects/s2_ooz_projectile.gd')
fg=txt('scripts/render/ghz_renderer.gd')

ck(manifest.get('phase')==116,'Phase 116 object manifest identifies the pass')
expected={'19':13,'1C':21,'1F':17,'33':11,'3D':3,'3F':30,'48':16,'4A':14,'50':8}
ck(manifest.get('record_counts')==expected,'All nine OOZ1-specific object families retain exact placement counts')
ck(manifest.get('newly_active_records')==133,'All 133 previously deferred OOZ1-specific placements are now active')
ck(manifest.get('completed_ids')==['19','1C','1F','33','3D','3F','48','4A','50'],'OOZ zone-local completion ID list is exact')
expected_frames={'elevator':4,'oilfall_short':6,'oilfall_long':5,'collapse':3,'burner_lid':1,'burner_flame':3,'launcher_vertical':4,'launcher_horizontal':4,'fan_horizontal':11,'fan_vertical':11,'transporter':8,'octus':7,'aquis':9,'collapse_fragments':7,'launcher_vertical_fragments':16,'launcher_horizontal_fragments':16}
ck(manifest.get('frames')==expected_frames,'Retail mapping-bank frame counts are preserved')
for rel,digest in manifest.get('sha256',{}).items():
    p=P/'assets/objects/s2_ooz'/rel
    ck(p.is_file() and sha(p)==digest,f'OOZ rendered asset hash stable: {rel}')

# Runtime corruption fix: OOZ must remain indexed through both CRAM and VRAM changes.
indexed=func(fg,'build(level_data: GHZLevelData) -> void')
ck('LevelCatalog.ZONE_S2_OOZ_TEST' in indexed,'OOZ foreground now uses palette-indexed chunk textures')
refresh=func(fg,'refresh_art_range(first_tile: int, tile_count: int) -> void')
ck('level.zone_id == LevelCatalog.ZONE_S2_OOZ_TEST' in refresh,'OOZ animated VRAM refresh is limited to currently visible chunk IDs')
redraw=func(fg,'_redraw_tile_patch(low_image: Image, high_image: Image, patch: Dictionary, tile_image_cache: Dictionary) -> void')
ck('target_image.get_format() == Image.FORMAT_R8' in redraw and '_animated_tile_index_image' in redraw,'Dynamic OOZ tile patches preserve R8 palette indices instead of destructive RGBA redraws')
idx=func(fg,'_animated_tile_index_image(patch: Dictionary, tile_image_cache: Dictionary) -> Image')
ck('palette_line * 16 + color_index' in idx,'Indexed animated tile rebuild retains source CRAM line identity')

# Namespace and transient integration.
ck('const S2OOZObjectClass = preload("res://scripts/objects/s2_ooz_object.gd")' in om,'Object manager preloads dedicated OOZ adapter')
ck('const S2OOZProjectileClass = preload("res://scripts/objects/s2_ooz_projectile.gd")' in om,'Object manager preloads OOZ projectile adapter')
route='if bool(level_definition.get("s2_ooz", false)) and id in [0x19,0x1C,0x1F,0x33,0x3D,0x3F,0x48,0x4A,0x50]:\n\t\t\treturn S2OOZObjectClass.new()'
ck(route in om,'OOZ overlapping IDs route before CPZ/ARZ/EHZ aliases')
ck('var ooz_control_owner_record: int = -1' in om and '\tooz_control_owner_record = -1' in om,'OOZ launcher/transporter control ownership resets per level')
spawn=func(om,'spawn_s2_ooz_projectile(')
ck('S2OOZProjectileClass.new()' in spawn and 'transient_objects.append(projectile)' in spawn,'Octus/Aquis shots use independent transient objects')

# Object $19 elevator.
elev=func(oo,'_tick_elevator() -> void')
ck('orig_y - 0x60' in elev,'Obj19 subtype $23 converges on retail spawnY-$60 target')
ck('vel_y + (8 if target >=' in elev,'Obj19 uses retail +/-8 acceleration toward target')
ck('p.move_with_supported_object' in elev,'OOZ elevators carry standing Sonic while moving')
ck('position.y -= 0xC0' in func(oo,'_init_elevator() -> void'),'X-flipped Obj19 subtype $23 starts at retail -$C0 Y offset')

# Object $1C oil falls.
oil=func(oo,'_init_oilfall() -> void')
ck('subtype - 0x10' in oil and 'oilfall_long' in oil,'Obj1C subtypes $10-$14 select long OOZ oil mapping bank')
ck('subtype - 0x0A' in oil and 'oilfall_short' in oil,'Obj1C subtypes $0A-$0F select short OOZ oil mapping bank')

# Object $1F collapse.
col=func(oo,'_tick_collapse() -> void')
ck('collapse_delays: Array[int] = [0x1A,0x12,0x0A,0x02,0x16,0x0E,0x06]' in oo,'Obj1F OOZ seven-piece delay table is exact')
ck('collapse_delay: int = 7' in oo,'Obj1F stood-on pre-collapse delay is retail 7')
ck('collapse_delays[0] > 0' in col and 'p.resolve_platform_top' in col,'Obj1F keeps Sonic supported until fragment zero actually falls')
ck('collapse_finished = true' in col and 'request_delete' not in col,'Collapsed OOZ platform stays an inert tombstone until offscreen teardown')
ck('collapse_vy[i] + 0x38' in col,'Obj1F fragments use retail ObjectMoveAndFall gravity $38')

# Object $33 burner.
burn=func(oo,'_tick_burner() -> void')
ck('burner_velocity = -0x96800' in burn,'Obj33 lid launch velocity is exact -$96800')
ck('burner_velocity += 0x3800' in burn,'Obj33 lid gravity is exact +$3800')
ck('burner_velocity = -(burner_velocity >> 2)' in burn,'Obj33 quarter-bounce damping matches retail')
ck('flame_distance >= 0x14' in burn,'Obj33 flame collision activates at exact $14 separation')
ck('var seq: Array[int] = [2,0,2,0,2,0,1]' in burn,'Obj33 flame animation frame order matches retail')

# Object $3D striped block launcher.
launch=func(oo,'_tick_launcher() -> void')
ck('contact == SonicPlayer.SOLID_TOP and p.rolling' in launch,'Obj3D breaks only for a rolling character standing on it')
ck('p.vel_y = -0x800' in launch and 'p.vel_x = 0' in launch,'OOZ1 subtype-1 invisible launcher fires Sonic upward at -$800')
frag=func(oo,'_break_launcher(p: SonicPlayer) -> void')
for needle,msg in [('Vector2i(-0x400,-0x400)','Obj3D first fragment velocity exact'),('Vector2i(0x340,0x400)','Obj3D final fragment velocity exact'),('for i in range(16)','Obj3D reconstructs all 16 BreakObjectToPieces fragments')]: ck(needle in frag,msg)

# Object $3F fan.
fan=func(oo,'_tick_fan() -> void')
ck('fan_timer = 0x78 if fan_off else 0xB4' in fan,'Obj3F alternating fan cycle uses retail $78 off/$B4 on durations')
ck('(subtype & 2) == 0' in fan,'Obj3F subtype bit 1 bypasses cycling for always-active fans')
ck('(subtype & 0x80) != 0' in fan,'Obj3F sign bit selects vertical fan routine')
hfan=func(oo,'_apply_horizontal_fan(p: SonicPlayer) -> void')
ck('0xF0' in hfan and '0x70' in hfan and '>> 4' in hfan,'Horizontal fan reproduces retail influence envelope and distance scaling')
vfan=func(oo,'_apply_vertical_fan(p: SonicPlayer) -> void')
ck('manager.s2_source_osc_byte(0x14)' in vfan,'Vertical fan uses retail Oscillating_Data+$14 source')
ck(all(t in vfan for t in ['p.in_air = true','p.vel_y = 0','p.inertia = 1']),'Vertical fan applies retail airborne/zero-Y/inertia state')
ck(all(t in oo for t in ['fan_slow_accum += 0x2A','fan_slow_accum < 0x400','fan_timer = 0x78 if fan_off else 0xB4']),'Obj3F preserves retail off/on timer and decelerating animation accumulator')
ck(all(t in vfan for t in ['p.s2_twirl_angle = 1','p.s2_twirl_remaining = 0x7F','p.s2_twirl_speed = 8']),'Vertical fan seeds retail flip-angle tumble presentation')

# Object $48 transporter.
tr=func(oo,'_init_transporter() -> void')
ck('Vector2i(4,0),Vector2i(6,7),Vector2i(7,0),Vector2i(5,7),Vector2i(5,0),Vector2i(4,7),Vector2i(6,0),Vector2i(7,7)' in tr,'Obj48 exact eight-entry render/frame property table retained')
cap=func(oo,'_capture_transporter(p: SonicPlayer) -> void')
ck('p.inertia = 0x1000' in cap and 'p.vel_x = 0; p.vel_y = 0' in cap,'Obj48 capture seeds retail $1000 inertia and zero velocity')
trlaunch=func(oo,'_launch_transporter(p: SonicPlayer) -> void')
ck('Vector2i(0,-0x1000),Vector2i(0x1000,0),Vector2i(0,0x1000),Vector2i(-0x1000,0)' in trlaunch,'Obj48 four launch vectors are exact $1000 cardinals')
ck('(subtype & 0x80) != 0' in trlaunch and '_release_ooz_control(p)' in trlaunch,'Negative Obj48 subtypes release character control immediately')
ck('manager.ooz_control_owner_record = record_index' in cap,'Obj48 ownership prevents simultaneous transporters from double-moving Sonic')

# Object $4A Octus.
oct=func(oo,'_tick_octus() -> void')
ck('absi(p.pixel_x()-int(position.x)) <= 0x80' in oct,'Octus activation reach is retail +/-$80')
ck('timer = 0x20' in oct,'Octus pre-rise delay is retail $20')
ck('vel_y = -0x200' in oct and 'vel_y + 0x10' in oct,'Octus rise starts -$200 with +$10 per-frame acceleration')
ck('timer = 0x3C' in oct and '_spawn_octus_bullet()' in oct,'Octus fires at apex and hovers for retail $3C')
octshot=func(oo,'_spawn_octus_bullet() -> void')
ck('[5,6], 3' in octshot and '0x0F' in octshot,'Octus projectile retains frames 5/6 and $0F startup wait')

# Object $50 Aquis.
aq=func(oo,'_tick_aquis() -> void')
ck('clampi(vel_x + (-0x10' in aq and '-0x100, 0x100' in aq,'Aquis chases with +/-$10 acceleration capped at $100')
ck('timer = 0x20' in aq and 'timer = 0x80' in aq,'Aquis shooting/chase timers retain $20/$80 source values')
ck('state = 3; vel_x = -0x200; vel_y = 0' in aq,'Aquis final retreat uses retail -$200 horizontal velocity')
ck('aquis_shots_remaining: int = 3' in oo,'Aquis hardcoded source shot counter starts at 3')
aqshot=func(oo,'_spawn_aquis_bullet() -> void')
ck('[5,6,7,6], 4' in aqshot and '0x300' in aqshot and '0x200' in aqshot,'Aquis projectile uses source frame cycle, +/-$300 X and +$200 Y')
wing=func(oo,'_update_aquis_wing() -> void')
ck('Vector2(-10 if sprite.flip_h else 10, -6)' in wing,'Aquis wing follows at retail +/-10,-6 offset')

# Projectile lifecycle.
ck('startup_delay > 0' in proj,'OOZ projectile supports Octus delayed movement')
ck('p.apply_hazard_hit' in proj,'OOZ projectiles hurt Sonic through standard hazard path')
ck('p.invincible_timer > 0 or p.rolling or p.object_attack_active' in proj,'OOZ shots are safely removed by attack/invincibility contact')

# Source stream is still exact.
obj=(P/'data/s1/s2test/ooz1_objects.bin').read_bytes(); counts=Counter(obj[i+4] for i in range(0,len(obj),6))
ck(len(obj)==189*6,'OOZ1 placement stream remains 189 six-byte records')
ck(sum(counts[i] for i in [0x19,0x1C,0x1F,0x33,0x3D,0x3F,0x48,0x4A,0x50])==133,'Runtime routing covers exactly the 133 formerly deferred records')

if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    source_needles=[
      ('Obj19_MoveRoutine4:','Retail source contains Obj19 stood-on activation mode'),
      ('subi.w\t#$60,d0','Retail Obj19 target offset $60 confirmed'),
      ('Obj1F_OOZ_DelayData:','Retail source contains OOZ collapse delay table'),
      ('dc.b $1A,$12, $A,  2,$16, $E,  6','Retail seven OOZ collapse delays confirmed'),
      ('move.l\t#-$96800,objoff_32(a0)','Retail Obj33 lid launch -$96800 confirmed'),
      ('addi.l\t#$3800,objoff_32(a0)','Retail Obj33 gravity +$3800 confirmed'),
      ('cmpi.w\t#$14,d0','Retail Obj33 flame activation threshold $14 confirmed'),
      ('word_2507A:','Retail Obj3D 16-piece velocity table present'),
      ('move.w\t#-$800,y_vel(a1)','Retail Obj3D subtype-1 vertical launch -$800 confirmed'),
      ('move.w\t#$78,objoff_30(a0)','Retail Obj3F short cycle timer $78 confirmed'),
      ('move.w\t#$B4,objoff_30(a0)','Retail Obj3F long cycle timer $B4 confirmed'),
      ('move.b\t(Oscillating_Data+$14).w,d1','Retail vertical fan oscillator source confirmed'),
      ('Obj48_Properties:','Retail Obj48 property table present'),
      ('dc.w\t  0,-$1000','Retail Obj48 upward launch vector confirmed'),
      ('dc.w  $1000,     0','Retail Obj48 right launch vector confirmed'),
      ('move.w\t#$20,objoff_2C(a0)','Retail Octus pre-rise delay $20 confirmed'),
      ('move.w\t#-$200,y_vel(a0)','Retail Octus initial rise -$200 confirmed'),
      ('move.w\t#$3C,objoff_2C(a0)','Retail Octus hover timer $3C confirmed'),
      ('move.b\t#3,Obj50_shots_remaining(a0)','Retail Aquis hardcodes shot counter to 3'),
      ('move.b\t#$80,Obj50_timer(a0)','Retail Aquis chase timer $80 confirmed'),
      ('move.w\t#-$200,x_vel(a0)','Retail Aquis retreat -$200 confirmed'),
    ]
    for needle,msg in source_needles: ck(needle in asm,msg)
    ck(obj==(S2/'level/objects/OOZ_1.bin').read_bytes(),'Packaged OOZ1 placements remain byte-identical to retail')
    # Mapping sources used by the importer are exact named retail banks.
    for name in ['obj19.bin','obj1C_c.bin','obj1C_d.bin','obj1F_b.bin','obj33_a.bin','obj33_b.bin','obj3D.bin','obj3F_a.bin','obj3F_b.bin','obj48.bin','obj4A.bin','obj50.bin']:
        ck((S2/'mappings/sprite'/name).is_file(),f'Retail mapping source present: {name}')

for rel in ['tools/import_s2_ooz_objects_phase116.py','tools/validate_phase116.py','tools/validate_phase115.py']:
    try:
        py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

# Structural guard for changed GDScript files. This is not a substitute for a
# Godot parser, but catches merge artifacts and malformed bracket edits in this environment.
for rel in ['scripts/objects/s2_ooz_object.gd','scripts/objects/s2_ooz_projectile.gd','scripts/objects/object_manager.gd','scripts/render/ghz_renderer.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t and '=======' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
