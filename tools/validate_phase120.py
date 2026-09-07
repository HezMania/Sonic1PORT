#!/usr/bin/env python3
from __future__ import annotations
import hashlib, importlib.util, json, py_compile, sys
from collections import Counter
from pathlib import Path
from PIL import Image

P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def func(t,name):
    token='func '+name
    if token not in t:return ''
    a=t.index(token);b=t.find('\nfunc ',a+1);return t[a:len(t) if b<0 else b]

m=json.loads((P/'data/s1/s2test/phase120_mtz_objects_manifest.json').read_text())
p119=json.loads((P/'data/s1/s2test/phase119_mtz1_manifest.json').read_text())
om=txt('scripts/objects/object_manager.gd'); mtz=txt('scripts/objects/s2_mtz_object.gd')
cat=txt('scripts/data/level_catalog.gd'); main=txt('scripts/main.gd')

ck(m.get('phase')==120,'Object-art manifest identifies Phase 120')
expected_banks={
'cylinder_controller':[0],'rope':[2],'barrier':[1],'steam_spring':[7],'steam':list(range(7)),'button':[0,1,2],
'stomper':[0,1],'platform':[0,1,2,3],'cog':[0,1,2],'spring_wall':[0,1],'spin_tube_flash':[0,1],
'spike_block':[4],'moving_spike':[0,1,2,3],'nut':[0,1,2,3],'immobile_platform':[0,1,2,3],
'shellcracker':list(range(6)),'slicer':list(range(9)),'asteron':list(range(5))}
ck(m.get('banks')==expected_banks,'All retail MTZ1 object sprite banks/frames are reconstructed')
paths=m.get('tube_paths',{})
ck(paths.get('0')==[[0x7A8,0x270],[0x750,0x270],[0x740,0x280],[0x740,0x3E0],[0x750,0x3F0],[0x7A8,0x3F0]],'Obj67 subtype 0 path is exact')
ck(paths.get('1')==[[0xC58,0x5F0],[0xE28,0x5F0]],'Obj67 subtype 1 path is exact')
ck(paths.get('2')==[[0x1828,0x6B0],[0x17D0,0x6B0],[0x17C0,0x6C0],[0x17C0,0x7E0],[0x17B0,0x7F0],[0x1758,0x7F0]],'Obj67 subtype 2 path is exact')
ck(len(m.get('sha256',{}))==60,'Phase 120 packages all 60 rendered mapping frames')
for rel,dig in m.get('sha256',{}).items():
    q=P/'assets/objects/s2_mtz'/rel
    ck(q.is_file() and sha(q)==dig,f'Rendered object frame hash stable: {rel}')
    if q.is_file():
        try:
            im=Image.open(q); im.verify(); ck(im.width>0 and im.height>0,f'Rendered PNG decodes: {rel}')
        except Exception as e: ck(False,f'Rendered PNG decodes: {rel}: {e}')

# The Phase119 terrain/presentation foundation must remain byte-identical.
for rel,dig in p119.get('sha256',{}).items():
    q=P/'data/s1/s2test'/rel
    ck(q.is_file() and sha(q)==dig,f'Phase119 MTZ1 foundation unchanged: {rel}')

raw=(P/'data/s1/s2test/mtz1_objects.bin').read_bytes(); counts=Counter(raw[i+4] for i in range(0,len(raw),6))
mtz_specific=[0x06,0x1C,0x2D,0x42,0x47,0x64,0x65,0x66,0x67,0x68,0x69,0x6B,0x6D,0x74,0x9F,0xA1,0xA4]
ck(sum(counts[i] for i in mtz_specific)==166,'All 166 deferred MTZ-specific placement records are covered')
ck(sum(counts.values())==193,'All 193 retail MTZ1 object records remain present')
ck(sum(counts[i] for i in [0x0D,0x26,0x36,0x41,0x79])==27,'All 27 Phase119 shared placements remain active')

route=func(om,'_make_object_for_id(id: int) -> GenesisLevelObject')
ck('const S2MTZObjectClass = preload("res://scripts/objects/s2_mtz_object.gd")' in om,'Object manager preloads dedicated MTZ adapter')
for oid in mtz_specific:
    ck(f'0x{oid:02X}' in route,f'MTZ route contains Object ${oid:02X}')
ck('return S2MTZObjectClass.new()' in route,'Placed MTZ-specific IDs route to S2MTZObject')
for oid in [0x6A,0x6C,0x6E,0x70,0x71]:
    ck(f'0x{oid:02X}' in route,f'Later-act Object ${oid:02X} remains namespace-blocked')
ck('return S2UnsupportedObjectClass.new()' in route,'Later-act MTZ IDs cannot alias older zone adapters')

# Adapter coverage and important retail constants/lifecycles.
for oid,init,tick in [
(0x06,'_init_cylinder','_tick_cylinder'),(0x1C,'_init_rope',''),(0x2D,'_init_barrier','_tick_barrier'),
(0x42,'_init_steam_spring','_tick_steam_spring'),(0x47,'_init_button','_tick_button'),(0x64,'_init_stomper','_tick_stomper'),
(0x65,'_init_long_platform','_tick_long_platform'),(0x66,'_init_spring_wall','_tick_spring_wall'),(0x67,'_init_spin_tube','_tick_spin_tube'),
(0x68,'_init_spike_block','_tick_spike_block'),(0x69,'_init_nut','_tick_nut'),(0x6B,'_init_platform','_tick_platform'),
(0x6D,'_init_floor_spike','_tick_floor_spike'),(0x74,'_init_invisible_solid','_tick_invisible_solid'),
(0x9F,'_init_shellcracker','_tick_shellcracker'),(0xA1,'_init_slicer','_tick_slicer'),(0xA4,'_init_asteron','_tick_asteron')]:
    ck(f'0x{oid:02X}: {init}()' in mtz,f'Object ${oid:02X} has MTZ initializer')
    if tick: ck(f'0x{oid:02X}: {tick}()' in mtz,f'Object ${oid:02X} has MTZ tick routine')

for needle,msg in [
('0xC0','Obj06 cylinder keeps broad $C0 ride range'),('0x28','Obj06/Obj42 source $28 geometry represented'),
('displacement = mini(0x40, displacement+8)','Obj2D barrier raises in 8px steps to $40'),
('timer = 0x3B','Obj42 steam spring keeps retail $3B wait'),('p.vel_y = -0xA00','Obj42 spring launches at -$A00'),
('manager.mcz_button_vine_triggers','Obj47/Obj65 use shared ButtonVine_Trigger table'),
('timer=0x5A','Obj64 keeps retail $5A stomper pause'),('displacement = mini(0x40,displacement+8)','Obj64 keeps 8px/$40 stomper stroke'),
('timer=0xB4','Obj65 button platforms keep retail $B4 endpoint pause'),('0x1BC0','Obj65 MTZ1 traverse reaches $1BC0'),('0x1880','Obj65 MTZ1 traverse reverses at $1880'),
('p.vel_x = 0x800 if dx>0 else -0x800','Obj66 spring wall uses source-facing $800 horizontal launch'),('p.vel_y = -0x800','Obj66 spring wall uses -$800 vertical launch'),
('tube_angle>=0x80','Obj67 keeps initial $80-angle sine phase'),('p.vel_y=0x1000 if dy>=0 else -0x1000','Obj67 dominant-axis path magnitude is $1000 = 16 px/frame'),
('spike_offset+=8','Obj68 spike extends 8px/frame'),('spike_offset>=0x20','Obj68 spike stroke is $20'),
('spike_offset+=4','Obj6D floor spike extends 4px/frame'),("(manager.elapsed_frames-subtype)&0x7F",'Obj6D preserves authored $80-frame subtype phasing'),
('nut_max_drop=(subtype&0x7F)<<3','Obj69 low 7 subtype bits select travel in 8px units'),('var screw: int=nut_turn>>3','Obj69 screw converts turn into 1:8 vertical travel'),
('manager.s2_source_osc_byte(0x1C)','Obj6B subtype 2 reads the retail shared oscillator byte +$1C'),('vel_y==0x2A8','Obj6B subtype 7 reverses acceleration at $2A8'),
('((subtype&0xF0)+0x10)>>1','Obj74 subtype high nibble reconstructs width'),('((subtype&0x0F)+1)<<3','Obj74 subtype low nibble reconstructs height'),
('for i in range(8)','Shellcracker creates eight claw links'),('timer=0x140','Shellcracker keeps $140 patrol timer'),
('absi(dx)<0x80 and absi(dy)<0x40','Slicer uses retail forward acquisition window'),('clampi(int(q["vx"])+tx,-0x200,0x200)','Slicer pincer steering clamps to $200'),
('Vector2i(0,-0x400)','Asteron has exact finite five-way starburst'),
('if projectiles.is_empty():request_delete(false)','Asteron waits for finite projectiles before cleanup'),
('return object_id == 0x67 and tube_state != 0','Spin tube suppresses despawn while controlling Sonic')]: ck(needle in mtz,msg)

# Level presentation/progression stays Phase119 exact.
mtzcat=func(cat,'_get_sonic2_mtz_test(requested_act: int = 1) -> Dictionary')
for needle,msg in [('"layout": "s2test/mtz1_layout128.bin"','MTZ1 layout unchanged'),('"s2_objects": "s2test/mtz1_objects.bin"','Retail object stream unchanged'),('"s2_mtz": true','MTZ namespace remains enabled'),('"music_mode": "s2_mtz"','MTZ music remains enabled')]:ck(needle in mtzcat,msg)
ck('KEY_G:' in main and '_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 1)' in main,'G still warps directly to MTZ1')
nextf=func(cat,'next_level(zone: int, act: int) -> Vector2i')
ck('if zone == ZONE_S2_MTZ_TEST:' in nextf and 'return Vector2i(ZONE_GHZ, 1)' in nextf,'MTZ1 still uses safe fallback pending MTZ2')

if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    source_checks=[
    ('move.w\t#-$A00,y_vel(a1)','Retail Obj42 launch is -$A00'),('move.w\t#$3B,objoff_32(a0)','Retail Obj42 waits $3B'),
    ('move.w\t#$5A,objoff_36(a0)','Retail Obj64 endpoint wait is $5A'),('addi.w\t#$10,objoff_3A(a0)','Retail Obj65 proximity motion advances $10'),
    ('move.w\t#$B4,objoff_36(a0)','Retail Obj65 endpoint timer is $B4'),('cmpi.w\t#$1BC0,x_pos(a0)','Retail MTZ1 long platform endpoint is $1BC0'),
    ('cmpi.w\t#$1880,x_pos(a0)','Retail MTZ1 reverse endpoint is $1880'),('move.w\t#-$800,x_vel(a1)','Retail Obj66 horizontal spring speed is $800'),
    ('move.w\t#-$800,y_vel(a1)','Retail Obj66 vertical spring speed is -$800'),('move.w\t#$1000,d2','Retail Obj67 path speed magnitude is $1000'),
    ('addi.w\t#$800,spikearoundblock_offset(a0)','Retail Obj68 spike moves $800 fixed per tick'),('addi.w\t#$400,floorspike_offset(a0)','Retail Obj6D spike moves $400 fixed per tick'),
    ('lsl.w\t#3,d0','Retail Obj69 travel subtype is multiplied by eight'),('asr.w\t#3,d0','Retail Obj69 screw movement divides by eight'),
    ('move.b\t(Oscillating_Data+$1C).w,d0','Retail Obj6B subtype 2 reads oscillator +$1C'),('cmpi.w\t#$2A8,y_vel(a0)','Retail Obj6B subtype 7 changes acceleration at $2A8'),
    ('move.w\t#$140,objoff_2A(a0)','Retail Shellcracker patrol timer is $140'),('moveq\t#7,d6','Retail Shellcracker attack allocates eight claw links'),
    ('ObjA1_LoadPincers','Retail Slicer uses paired pincer children'),('ObjA4:','Retail Asteron source is present')]
    for needle,msg in source_checks: ck(needle in asm,msg)
    misc=(S2/'misc/obj67.asm').read_text(errors='replace')
    for x in ['$7A8','$C58','$1828']:
        ck(x in misc,f'Retail Obj67 source contains start {x}')

for rel in ['tools/import_s2_mtz_objects_phase120.py','tools/validate_phase120.py']:
    try: py_compile.compile(str(P/rel),doraise=True);ck(True,f'{rel} compiles')
    except Exception as e:ck(False,f'{rel} compiles: {e}')
for rel in ['scripts/objects/s2_mtz_object.gd','scripts/objects/object_manager.gd','scripts/data/level_catalog.gd','scripts/main.gd']:
    t=txt(rel);ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance');ck(t.count('[')==t.count(']'),f'{rel} brackets balance');ck(t.count('{')==t.count('}'),f'{rel} braces balance')
ck((P/'PHASE120_SONIC2_METROPOLIS_ACT1_COMPLETION.md').is_file(),'Phase 120 implementation report packaged')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
