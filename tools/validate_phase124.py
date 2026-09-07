#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, py_compile, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def be16(b,o): return (b[o]<<8)|b[o+1]
def func(t,name):
    token='func '+name
    if token not in t:return ''
    a=t.index(token); b=t.find('\nfunc ',a+1)
    return t[a:len(t) if b<0 else b]
def parse_objects(raw):
    assert len(raw)%6==0
    out=[]
    for i in range(0,len(raw),6):
        yw=be16(raw,i+2)
        out.append((be16(raw,i),yw&0xFFF,(yw>>12)&0xF,raw[i+4],raw[i+5]))
    return out

def ring_groups(raw):
    o=0;n=0
    while o+1<len(raw):
        x=be16(raw,o);o+=2
        if x&0x8000: break
        if o+1>=len(raw): return -1
        o+=2;n+=1
    return n

mtz=txt('scripts/objects/s2_mtz_object.gd')
om=txt('scripts/objects/object_manager.gd')
cat=txt('scripts/data/level_catalog.gd')
cam=txt('scripts/camera/sonic_camera.gd')
main=txt('scripts/main.gd')
M=json.loads((P/'data/s1/s2test/phase124_mtz3_manifest.json').read_text())
raw=(P/'data/s1/s2test/mtz3_objects.bin').read_bytes(); objs=parse_objects(raw); counts=Counter(x[3] for x in objs)

# Exact MTZ3 foundation.
ck(M['phase']==124 and M['level']=='Metropolis Zone Act 3','Phase124 manifest identifies Metropolis Zone Act 3')
ck(M['start']==[0x60,0x20C],'Retail MTZ3 start is $0060,$020C')
ck(M['limits']=={'left':0,'right':0x2A80,'top':-0x100,'bottom':0x800},'Retail MTZ3 camera limits are preserved')
ck(M['layout']==[128,16],'MTZ3 foreground/background layout dimensions are 128x16 chunks')
ck(len(raw)==270*6 and len(objs)==270,'All 270 retail MTZ3 object records are retained')
ck((P/'data/s1/s2test/mtz3_rings.bin').stat().st_size==298,'Exact 298-byte MTZ3 ring stream is retained')
ck(ring_groups((P/'data/s1/s2test/mtz3_rings.bin').read_bytes())==74,'MTZ3 ring stream decodes to 74 retail groups')
ck((P/'data/s1/s2test/mtz3_map128.bin').stat().st_size==0x8000,'MTZ3 Map128 is exact $8000-byte decompressed table')
ck((P/'data/s1/s2test/mtz3_map16.bin').stat().st_size==0x1800,'MTZ3 assembled APM_MTZ Map16 is $1800 bytes')
ck((P/'data/s1/s2test/mtz3_collision_primary.bin').stat().st_size==0x300,'MTZ3 primary collision index is $300 bytes')
ck((P/'data/s1/s2test/mtz3_collision_secondary.bin').read_bytes()==(P/'data/s1/s2test/mtz3_collision_primary.bin').read_bytes(),'MTZ3 secondary collision mirrors retail MTZ collision index')
ck(counts[0x6A]==2,'MTZ3 contains exactly two Object $6A walk-off platforms')
ck(counts[0x6E]==28,'MTZ3 contains exactly 28 Object $6E circular-platform records')
expected={'06':2,'1C':1,'26':11,'2D':4,'31':8,'36':14,'3E':1,'41':9,'42':9,'47':1,'64':3,'65':39,'66':11,'67':5,'68':7,'69':10,'6A':2,'6B':8,'6C':1,'6D':5,'6E':28,'70':8,'71':4,'72':4,'74':11,'79':6,'9F':3,'A1':13,'A4':42}
ck({f'{k:02X}':v for k,v in sorted(counts.items())}==expected,'Every MTZ3 retail object ID/count matches source')
for rel,dig in M['sha256'].items():
    q=P/'data/s1/s2test'/rel
    ck(q.is_file() and sha(q)==dig,f'MTZ3 imported hash stable: {rel}')
for rel,dig in M['obj6e_sprite_sha256'].items():
    q=P/'assets/objects/s2_mtz'/rel
    ck(q.is_file() and sha(q)==dig,f'Obj6E rendered frame hash stable: {rel}')

# Phase123 carry-forward fixes.
gearinit=func(mtz,'_init_gear() -> void'); geartick=func(mtz,'_tick_gear() -> void')
cupinit=func(mtz,'_init_lava_cups() -> void')
stomper=func(mtz,'_init_stomper() -> void')
plat=func(mtz,'_tick_platform() -> void')
ck('visible = true' in gearinit,'Obj70 parent stays visible so its eight gear-tooth sprites render')
ck('gear_rider_tooth = -1' in gearinit,'Obj70 initializes stable rider-tooth identity')
ck('if gear_rider_tooth < 0 or gear_rider_tooth >= 8:' in geartick,'Obj70 selects a rider tooth only when support begins')
ck('new_positions[gear_rider_tooth]' in geartick,'Obj70 carries Sonic with the same tooth across animation phases')
ck('visible = true' in cupinit,'Obj6C parent stays visible so all lava-cup children render')
ck('sprite.flip_v = y_flip' in stomper,'Obj64 respects retail placement Y-flip for upside-down pistons')
ck('platform_mode==4' in plat and 's2_source_osc_byte(0x1C)' in plat,'Obj6B type 4 moving platforms use retail $1C oscillator')
ck('platform_mode==5' in plat and 'platform_mode=6' in plat,'Obj6B type 5 bobbing platforms transition to falling type 6 when stood on')
ck('platform_mode==6' in plat and 'vel_y=GenesisMath.s16(vel_y+8)' in plat,'Obj6B type 6 preserves retail falling gravity')

# MTZ3-only Obj6A.
route=func(om,'_make_object_for_id(id: int) -> GenesisLevelObject')
ck('0x6A' in route and '0x6E' in route and 'return S2MTZObjectClass.new()' in route,'MTZ3 Objects $6A/$6E are routed to the MTZ-local adapter')
ck('id in [0x6A,0x6E]' not in route,'Old MTZ3 unsupported-object blocker is removed')
init=func(mtz,'initialize_object() -> void'); tick=func(mtz,'tick() -> void')
ck('0x6A: _init_trigger_platform()' in init and '0x6A: _tick_trigger_platform()' in tick,'Object $6A is initialized and ticked natively')
trig=func(mtz,'_tick_trigger_platform() -> void')
for n in ['Vector3i(0x000,0x400,0x10)','Vector3i(0x400,-0x200,0x20)','Vector3i(-0x400,-0x200,0x20)']:
    ck(n in mtz,f'Obj6A retail motion-table entry retained: {n}')
ck('elif remembered_standing:' in trig and 'state=1' in trig,'Obj6A starts its next segment only when Sonic walks off')
ck('platform_fixed_x += GenesisMath.s16(vel_x)<<8' in trig and 'platform_fixed_y += GenesisMath.s16(vel_y)<<8' in trig,'Obj6A integrates retail 8.8 velocity through 16.16 position')
ck('platform_segment_index=(platform_segment_index+1)&3' in trig,'Obj6A cycles all four retail motion segments')

# MTZ3 Obj6E exact shapes/motion.
circinit=func(mtz,'_init_circle_platform() -> void'); circtick=func(mtz,'_tick_circle_platform() -> void')
ck('platform_shape=(subtype>>4)&3' in circinit,'Obj6E high subtype nibble selects one of four retail mapping variants')
ck('[0x10,0x28,0x60,0x0C]' in circinit,'Obj6E retail half-width table is retained')
ck('[0x0C,0x08,0x18,0x0C]' in circtick,'Obj6E retail Y-radius table is retained')
ck('s2_source_osc_byte(0x20)-0x38' in circtick and 's2_source_osc_byte(0x24)-0x38' in circtick,'Obj6E solid variants use exact $20/$24 oscillator channels around $38')
ck('(manager.s2_source_osc_byte(0x20)>>1)-0x1C' in circtick,'Obj6E wheel-indent variant uses retail half-amplitude $1C radius')
ck('if (subtype&1)!=0:' in circtick and 'dx=-dx;dy=-dy' in circtick,'Obj6E subtype bit 0 reverses both axes')
ck('if (subtype&2)!=0:' in circtick and 'var tmp:int=dx;dx=dy;dy=tmp' in circtick,'Obj6E subtype bit 1 performs retail negate/swap transform')
ck('if platform_shape==3:return' in circtick,'Obj6E frame 3 wheel-indent decoration remains non-solid')
ck('p.resolve_solid_box_contact' in circtick,'Obj6E frames 0-2 provide native solid/carry collision')

# Catalog/progression/debug warp.
getmtz=func(cat,'_get_sonic2_mtz_test(requested_act: int = 1) -> Dictionary')
ck('clampi(requested_act, 1, 3)' in getmtz,'LevelCatalog accepts all three Metropolis acts')
ck('right_limit = 0x2A80' in getmtz,'MTZ3 catalog uses retail $2A80 camera right boundary')
ck('"dynamic_events": "s2_mtz3" if act == 3 else "none"' in getmtz,'MTZ3 selects its retail dynamic-level event')
ck('"s2_mtz3_foundation": act == 3' in getmtz,'MTZ3 is explicitly marked as the Phase124 boss-boundary foundation')
ck('"s2_egg_prison_requires_boss": act == 3' in getmtz,'MTZ3 Egg Prison remains gated until the boss is implemented')
nextf=func(cat,'next_level(zone: int, act: int) -> Vector2i')
ck('Vector2i(ZONE_S2_MTZ_TEST, act + 1) if act < 3' in nextf,'Metropolis progression is MTZ1 -> MTZ2 -> MTZ3')
ck('KEY_F8:' in main and '_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 3)' in main,'F8 directly warps to MTZ3 for runtime testing')
ck('Native Sonic 1 Phase 124' in main,'Debug overlay identifies Phase124')
ck('G MTZ1  C MTZ2  F8 MTZ3' in main,'Debug overlay documents all three Metropolis warps')

# Exact LevEvents_MTZ3 foundation through Object $54 boundary.
dle=func(cam,'_dle_s2_mtz3() -> void')
for n in ['screen_x >= 0x2530','current_bottom = 0x500','target_bottom = 0x450','screen_x >= 0x2980','target_bottom = 0x400','screen_x >= 0x2A80','limit_left = 0x2AB0','limit_right = 0x2AB0','s2_mtz3_event_timer >= 0x5A']:
    ck(n in dle,f'LevEvents_MTZ3 retail transition retained: {n}')
ck('s2_mtz3_music_fade_requested = true' in dle,'MTZ3 arena lock requests retail music fade')
ck('s2_mtz3_boss_ready = true' in dle,'MTZ3 exposes safe post-$5A boss-ready boundary')
ck('Obj54' not in dle and 'spawn' not in dle.lower().replace('spawned',''),'Phase124 camera DLE does not allocate incomplete Object $54')
ck('s2_mtz3_foundation_act' in main and 'SonicAudio.stop_music()' in main,'Main loop honors MTZ3 retail arena music fade')
ck('_tick_s2_mtz3' not in main,'Phase124 does not start an incomplete MTZ boss controller')
ck('(s2_mtz3_foundation_act and sonic_camera.dle_routine >= 6)' in main,'Player level-bound lock follows the MTZ3 authored boss arena')

# Previous MTZ foundations/data remain exact.
for mf in ['phase119_mtz1_manifest.json','phase122_mtz2_manifest.json']:
    m=json.loads((P/'data/s1/s2test'/mf).read_text())
    for rel,dig in m.get('sha256',{}).items():
        q=P/'data/s1/s2test'/rel
        ck(q.is_file() and sha(q)==dig,f'{mf}: previous imported data unchanged: {rel}')

# Retail source cross-checks when source tree supplied.
if S2:
    ck((S2/'level/objects/MTZ_3.bin').read_bytes()==raw,'MTZ3 object stream is byte-for-byte retail')
    ck((S2/'level/rings/MTZ_3.bin').read_bytes()==(P/'data/s1/s2test/mtz3_rings.bin').read_bytes(),'MTZ3 ring stream is byte-for-byte retail')
    ck((S2/'startpos/MTZ_3.bin').read_bytes()==(P/'data/s1/s2test/mtz3_start.bin').read_bytes(),'MTZ3 start position is byte-for-byte retail')
    asm=(S2/'s2.asm').read_text(errors='replace')
    sec=asm[asm.index('LevEvents_MTZ3:'):asm.index('LevEvents_WFZ:',asm.index('LevEvents_MTZ3:'))]
    for n in ['#$2530','#$500','#$450','#$2980','#$400','#$2A80','#$2AB0','#$5A','ObjID_MTZBoss']:
        ck(n in sec,f'Retail LevEvents_MTZ3 source contains {n}')
    o6a=asm[asm.index('Obj6A:'):asm.index('Obj6B:',asm.index('Obj6A:'))]
    ck('byte_27CDC:' in o6a and '0,$10' in o6a and '0,$20' in o6a,'Retail Obj6A motion table is present in source')
    o6e=asm[asm.index('Obj6E:'):asm.index('Obj70:',asm.index('Obj6E:'))]
    ck('(Oscillating_Data+$20)' in o6e and '(Oscillating_Data+$24)' in o6e,'Retail Obj6E source uses the $20/$24 oscillator channels')

# Structural checks.
for rel in ['scripts/objects/s2_mtz_object.gd','scripts/objects/object_manager.gd','scripts/data/level_catalog.gd','scripts/camera/sonic_camera.gd','scripts/main.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')
    ck('\\t' not in t,f'{rel} has no escaped-tab artifacts')
for rel in ['tools/import_s2_mtz3_phase124.py','tools/validate_phase124.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
