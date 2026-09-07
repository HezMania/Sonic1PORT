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

def be16(b,o=0): return (b[o]<<8)|b[o+1]

manifest=json.loads((P/'data/s1/s2test/phase117_ooz2_manifest.json').read_text())
cat=txt('scripts/data/level_catalog.gd')
main=txt('scripts/main.gd')
cam=txt('scripts/camera/sonic_camera.gd')
om=txt('scripts/objects/object_manager.gd')
oo=txt('scripts/objects/s2_ooz_object.gd')
swing=txt('scripts/objects/s2_arz_swing_object.gd')

# Exact OOZ2 package data.
ck(manifest.get('phase')==117,'Phase 117 manifest identifies the pass')
ck(manifest.get('level')=='Oil Ocean Zone Act 2','Manifest identifies retail Oil Ocean Act 2')
ck(manifest.get('start')==[0x60,0x56C],'OOZ2 start is exact retail $0060,$056C')
ck(manifest.get('limits')=={'left':0,'right':0x2D00,'top':0,'bottom':0x680},'OOZ2 LevelSize is exact retail $0000..$2D00/$0000..$0680')
ck(manifest.get('layout_128')==[128,16] and manifest.get('background_128')==[128,16],'OOZ2 foreground/Plane-B split is 128x16 chunks each')
expected={'15':1,'19':13,'1C':17,'1F':10,'26':16,'33':8,'36':29,'3D':4,'3E':1,'3F':18,'41':6,'43':6,'45':5,'48':24,'4A':16,'50':12,'74':1,'79':3}
ck(manifest.get('object_counts_hex')==expected,'All 190 OOZ2 retail placement IDs/counts are exact')
ck(manifest.get('object_records')==190 and manifest.get('native_routed_records')==190,'All 190 OOZ2 object records are retained and routed')
ck(manifest.get('boss_gated_egg_prison_records')==1,'Retail OOZ2 Egg Prison is retained and boss-gated')
ck(manifest.get('new_object_frames')=={'15':4,'43':1,'45':29},'OOZ2-only/shared source mapping frame banks reconstructed exactly')

for n in ['layout128','bg128','objects','rings','start','art','map16','map128','collision_primary','collision_secondary']:
    ck((P/f'data/s1/s2test/ooz2_{n}.bin').is_file(),f'Packaged OOZ2 {n} data exists')
for rel,digest in manifest.get('asset_sha256',{}).items():
    p=P/'assets/objects/s2_ooz'/rel
    ck(p.is_file() and sha(p)==digest,f'OOZ2 rendered asset hash stable: {rel}')

# Level catalog/progression/debug access.
oozcat=func(cat,'_get_sonic2_ooz_test(requested_act: int = 1) -> Dictionary')
for needle,msg in [
    ('clampi(requested_act, 1, 2)','OOZ catalog supports both acts'),
    ('"limit_right": 0x2D00 if act == 2 else 0x2F80','Act 2 right boundary is retail $2D00'),
    ('"dynamic_events": "s2_ooz2" if act == 2 else "none"','OOZ2 selects its dedicated level event'),
    ('"s2_egg_prison_requires_boss": act == 2','OOZ2 capsule remains gated until boss completion'),
]: ck(needle in oozcat,msg)
ck('return Vector2i(ZONE_S2_OOZ_TEST, 2) if act < 2 else Vector2i(ZONE_GHZ, 1)' in cat,'OOZ1 progresses to OOZ2; post-OOZ2 remains safe fallback pending boss pass')
ck('KEY_B:' in main and '_debug_warp(LevelCatalog.ZONE_S2_OOZ_TEST, 2)' in main,'B is direct OOZ2 runtime warp; V remains OOZ1')

# Retail pre-boss LevEvents_OOZ2 boundary/oil handoff, deliberately stopping before Obj55.
dle=func(cam,'_dle_s2_ooz2() -> void')
for needle,msg in [
    ('screen_x >= 0x2668','OOZ2 oil/camera transition begins at retail $2668'),
    ('target_bottom = 0x1E0','OOZ2 camera bottom target becomes retail $1E0'),
    ('screen_x >= 0x2880','OOZ2 arena lock begins at retail $2880'),
    ('limit_left = 0x2880','OOZ2 arena left boundary locks to $2880'),
    ('limit_right = 0x28C0','OOZ2 arena right boundary locks to $28C0'),
    ('limit_top = 0x1D8','OOZ2 arena vertical clamp uses retail $1D8'),
]: ck(needle in dle,msg)
ck('s2_ooz2' in cam and '_dle_s2_ooz2()' in cam,'OOZ2 dynamic event is dispatched by SonicCamera')
ck('Object $55' in dle and 'stops at that stable arena lock' in dle,'Phase 117 explicitly defers the Object $55 boss prelude instead of spawning a partial boss')
oil=func(om,'_tick_s2_ooz_oil() -> void')
ck('S2_OOZ2_BOSS_OIL_Y := 0x2D8' in om,'OOZ2 raised global oil Y constant is retail $2D8')
ck('current_screen_x >= 0x2668' in oil and 'oil_y = S2_OOZ2_BOSS_OIL_Y' in oil,'Global oil surface follows the retail $2668 event transition')

# Phase 116 runtime report carry-forward fixes.
launcher=func(oo,'_tick_launcher() -> void')
ck('rolling_before_solid' in launcher and launcher.index('rolling_before_solid') < launcher.index('resolve_solid_box_contact'),'Obj3D snapshots Roll state before solid resolution')
ck('resolve_solid_box_contact(orig_x, orig_y, 0x10, 0x10' in launcher,'Obj3D preserves raw $10 striped-block geometry while native solid helper supplies player margin')
ck('contact == SonicPlayer.SOLID_TOP and rolling_before_solid' in launcher,'Obj3D breaks from a rolling top contact as retail does')
suppress=func(oo,'suppress_central_despawn() -> bool')
ck('object_id == 0x48' in suppress and 'transport_state != 0' in suppress,'Obj48 suppresses central despawn for the full controlled transport flight')
ck('manager.ooz_control_owner_record == record_index' in suppress,'OOZ transport/launcher controller ownership also prevents premature despawn')
move=func(oo,'_move_player_pixels(p: SonicPlayer, dx: int, dy: int) -> void')
ck('p.fixed_x += dx << 16' in move and 'p.fixed_y += dy << 16' in move and 'p.position = Vector2(float(p.fixed_x)' in move,'Fan/controller corrections remain synchronized to Sonic authoritative 16.16 position')
vfan=func(oo,'_apply_vertical_fan(p: SonicPlayer) -> void')
ck('manager.s2_source_osc_byte(0x14)' in vfan and 'p.vel_y = 0' in vfan,'Vertical fan retains retail oscillator and zero-Y-velocity behavior')
oct=func(oo,'_update_octus_air_animation() -> void')
ck('octus_air_anim_counter' in oct and '1 + (int((octus_air_anim_counter - 16) / 4) % 3)' in oct,'Octus airborne state enters frames 1/2/3 spinning-leg loop')
aq=func(oo,'_update_aquis_facing() -> void')
ck('status_faces_left' in aq and 'sprite.flip_h = not status_faces_left' in aq,'Aquis source status direction is inverted only for reconstructed left-facing art')
aqshot=func(oo,'_spawn_aquis_bullet() -> void')
ck('bullet_vx: int = 0x300 if source_status_left else -0x300' in aqshot,'Aquis projectile velocity still follows original source status semantics')

# New OOZ2 Object $43 / $45 support and zone-correct Obj15 graphics.
ck('id in [0x19,0x1C,0x1F,0x33,0x3D,0x3F,0x43,0x45,0x48,0x4A,0x50]' in om,'OOZ namespace routes Obj43/45 before overlapping adapters')
ck('0x15, 0x83: return S2ARZSwingObjectClass.new()' in om,'OOZ2 Obj15 uses the shared retail swinging-platform state machine')
ck('0x26: return S2MonitorAdapterClass.new()' in om,'OOZ2 Obj26 monitors retain shared adapter')
ck('0x36: return S2SpikesObjectClass.new()' in om,'OOZ2 Obj36 spikes retain shared adapter')
ck('0x3E: return S2EggPrisonObjectClass.new()' in om,'OOZ2 Obj3E Egg Prison retains shared boss-gated adapter')
ck('0x41: return S2SpringObjectClass.new()' in om,'OOZ2 Obj41 springs retain shared Sonic 2 adapter')
ck('0x74' in om and 'S2CPZTraversalObjectClass.new()' in om,'OOZ2 Obj74 invisible solid block remains on source-compatible generic traversal adapter')
ck('0x79: return LamppostObject.new()' in om,'OOZ2 Obj79 starposts retain shared checkpoint adapter')
sp=func(oo,'_init_sliding_spike() -> void')
ck('travel = 0xE8' in sp and 'offsets = [-0x18, 0x18]' in sp,'Obj43 subtype $06 source range/paired offsets are exact')
ck('travel = 0xA8' in sp and 'offsets = [-0x58, -0x28]' in sp,'Obj43 subtype $0C source range/paired offsets are exact')
spt=func(oo,'_tick_sliding_spike() -> void')
ck('sliding_spike_x[i] + sliding_spike_dir[i]' in spt,'Obj43 moves exactly one pixel per tick')
ck('sliding_spike_x[0] - 0x18 == sliding_spike_x[1] + 0x18' in spt,'Obj43 paired heads reverse at exact retail $30 separation test')
ck('0x18 + p.width_radius' in spt and '0x28 + p.height_radius' in spt,'Obj43 reproduces collision_flags $A5 Touch_Sizes[$25] = $18x$28')
press=func(oo,'_tick_pressure_spring() -> void')
ck('resolve_solid_box_contact(int(round(position.x)), orig_y, 0x14, 0x0C' in press,'Obj45 native solid box uses raw $14/$0C geometry behind retail d1=$1F/d2=$0C/d3=$0D')
ck('pressure_compression < 0x12' in press,'Obj45 maximum horizontal compression is retail $12 pixels')
ck('(pressure_compression + 0x0A) << 7' in press,'Obj45 release converts displacement+10 to 7.8 launch magnitude exactly')
ck('mini(4, pressure_compression)' in press,'Obj45 returns to home at retail four pixels per frame')
ck('0x0A + pressure_compression' in press,'Obj45 mapping frame tracks retail $A+compression')
ck('var zone_root: String = "s2_ooz"' in swing and 'assets/objects/%s/swing' in swing,'Shared Obj15 adapter selects reconstructed OOZ swinging-platform art in Oil Ocean')
ck((P/'assets/objects/s2_ooz/swing/00.png').is_file(),'OOZ Obj15 platform frame is packaged')

# Stream routing sanity.
obj=(P/'data/s1/s2test/ooz2_objects.bin').read_bytes(); counts=Counter(obj[i+4] for i in range(0,len(obj),6))
ck(len(obj)==190*6,'OOZ2 object stream is exactly 190 six-byte records')
ck({f'{k:02X}':v for k,v in sorted(counts.items())}==expected,'Packaged OOZ2 stream count histogram matches manifest')

if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    ck(obj==(S2/'level/objects/OOZ_2.bin').read_bytes(),'Packaged OOZ2 placements are byte-identical to retail source')
    ck((P/'data/s1/s2test/ooz2_rings.bin').read_bytes()==(S2/'level/rings/OOZ_2.bin').read_bytes(),'Packaged OOZ2 rings are byte-identical to retail source')
    ck((P/'data/s1/s2test/ooz2_start.bin').read_bytes()==(S2/'startpos/OOZ_2.bin').read_bytes(),'Packaged OOZ2 start bytes are byte-identical to retail source')
    source_needles=[
      ('LevEvents_OOZ2_Routine1:','Retail OOZ2 dynamic event routine 1 present'),
      ('cmpi.w\t#$2668,(Camera_X_pos).w','Retail OOZ2 oil/camera trigger $2668 confirmed'),
      ('move.w\t#$2D8,(Oil+y_pos).w','Retail OOZ2 raised oil Y $2D8 confirmed'),
      ('move.w\t#$1E0,(Camera_Max_Y_pos).w','Retail OOZ2 camera max Y $1E0 confirmed'),
      ('cmpi.w\t#$2880,(Camera_X_pos).w','Retail OOZ2 arena trigger $2880 confirmed'),
      ('move.w\t#$28C0,(Camera_Max_X_pos).w','Retail OOZ2 arena right $28C0 confirmed'),
      ('cmpi.w\t#$1D8,(Camera_Y_pos).w','Retail OOZ2 boss vertical clamp $1D8 confirmed'),
      ('cmpi.b\t#$5A,(ScreenShift).w','Retail OOZ2 boss ScreenShift wait $5A confirmed for Phase118 boundary'),
      ('move.b\t#ObjID_OOZBoss,id(a1)','Retail Object $55 boss allocation confirmed for Phase118'),
      ('word_2507A:','Retail Obj3D 16-piece breakup velocity table present'),
      ('move.b\t(MainCharacter+anim).w,objoff_32(a0)','Retail Obj3D snapshots Sonic animation before SolidObject'),
      ('cmpi.b\t#AniIDSonAni_Roll,objoff_32(a0)','Retail Obj3D requires Roll animation to break'),
      ('Obj3D_InvisibleLauncher:','Retail invisible launcher controller remains after breakup'),
      ('move.b\tobjoff_2C(a0),d0','Retail Obj48 controller state contributes to MarkObjGone bypass'),
      ('byte_23E54:','Retail Obj43 subtype table present'),
      ('dc.b $E8','Retail Obj43 $E8 paired travel range present'),
      ('subi.w\t#$18,d0','Retail Obj43 paired-head separation uses $18 offsets'),
      ('Obj45:','Retail Obj45 pressure spring routine present'),
      ('addi.w\t#$12,d0','Retail Obj45 maximum horizontal displacement $12 confirmed'),
      ('addq.w\t#4,x_pos(a0)','Retail Obj45 four-pixel return step confirmed'),
      ('ArtTile_ArtNem_OOZSwingPlat','Retail Obj15 defaults to Oil Ocean swinging-platform art'),
    ]
    for needle,msg in source_needles: ck(needle in asm,msg)
    for name in ['obj15_a.bin','obj43.bin','obj45.bin']:
        ck((S2/'mappings/sprite'/name).is_file(),f'Retail OOZ2 mapping source present: {name}')

for rel in ['tools/import_s2_ooz2_phase117.py','tools/validate_phase117.py','tools/validate_phase116.py']:
    try:
        py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

# Structural guard for changed GDScript without a Godot executable in this environment.
for rel in ['scripts/objects/s2_ooz_object.gd','scripts/objects/s2_arz_swing_object.gd','scripts/objects/object_manager.gd','scripts/data/level_catalog.gd','scripts/camera/sonic_camera.gd','scripts/main.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t and '=======' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
