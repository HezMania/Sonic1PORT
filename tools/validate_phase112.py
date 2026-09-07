#!/usr/bin/env python3
from __future__ import annotations
import importlib.util, json, py_compile, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(c,m): checks.append((bool(c),m)); print(('PASS: ' if c else 'FAIL: ')+m)

mcz=(P/'scripts/objects/s2_mcz_object.gd').read_text()
om=(P/'scripts/objects/object_manager.gd').read_text()
cat=(P/'scripts/data/level_catalog.gd').read_text()
main=(P/'scripts/main.gd').read_text()
manifest=json.loads((P/'data/s1/s2test/phase112_mcz_objects_manifest.json').read_text())

ck('const S2MCZObjectClass = preload' in om,'ObjectManager preloads dedicated S2MCZObject class')
ck('return S2MCZObjectClass.new()' in om,'MCZ overlapping IDs route to MCZ class before ARZ/CPZ aliases')
ck('mcz_button_vine_triggers: Array[int]' in om and 'mcz_button_vine_triggers.fill(0)' in om,'Retail ButtonVine_Trigger equivalent is shared/reset per level')
ck(manifest['mcz1_records']==130 and manifest['newly_active_records']==88 and manifest['native_placement_coverage']==130,'MCZ1 reaches 130/130 native placement coverage')
ck('"backdrop_palette_index": 48' in cat and 'definition.get("backdrop_palette_index", 32)' in main,'MCZ transparent Plane-B backdrop selects black combined-palette index 48')
rawpal=(P/'data/s1/palette/S2 Mystic Cave Zone.bin').read_bytes()
ck(rawpal[64:66]==b'\0\0','MCZ zone palette entry 32 used by backdrop is source black')

# Exact retail-first geometry/state constants translated into native semantics.
for token,msg in [
 ('collapse_fragment_delay: Array[int] = [0x1A,0x16,0x12,0x0E,0x0A,0x02]','Obj1F exact six-piece MCZ collapse delays'),
 ('stomper_amount >= 0x60','Obj2A exact $60 rise extent'),('stomper_amount -= 8','Obj2A exact 8px return rate'),
 ('Vector3i(0,0x100,0x40)','Obj6A retail crate +Y leg'),('Vector3i(-0x100,0,0x80)','Obj6A retail crate -X leg'),
 ('0x10,0x10,true,record_index','Obj75 subtype-$F uses raw $10x$10 solid geometry'),
 ('spike_remaining=0x80','Obj76 exact $80 slide distance'),('0x40,0x10,true,record_index','Obj76 raw $40x$10 geometry'),
 ('gate_frame<4','Obj77 five retail mapping states'),('0x40,8,true,record_index','Obj77 $4B center reach translated to raw $40 width'),
 ('platform_left=orig_x-0x68','Obj7A exact $68 travel range'),('cx-0x18,cx+0x18','Obj7A exact $18 PlatformObject width'),
 ('orig_y+0x30','Obj7F exact +$30 hang Y'),('_release_hang(p,-0x300,false)','Obj7F exact -$300 release Y velocity'),
 ('vine_offset=0xB0','Obj80 exact $B0 travel'),('orig_y+vine_offset','Obj80 retains authored origin+offset model'),('_release_hang(p,-0x380,true)','Obj80 exact -$380 release Y velocity'),
 ('for i in range(8)','Obj81 uses eight authored log segments'),('draw_center_x=orig_x+(-0x48 if draw_angle==0x80 else 0x48)','Obj81 exact $48 horizontal settled offset'),
 ('timer=0x10','Obj9E exact $10 pre-charge delay'),('timer=0x1C','Obj9E exact $1C charge duration'),('timer=0x20','Obj9E exact $20 turnaround delay'),
 ('timer=0x40','ObjA3 exact initial $40 wait'),('timer=0x80','ObjA3 exact $80 flight/flash timers'),('0x440','ObjA3 source threshold table retained'),
 ('swing_speed = GenesisMath.s16(swing_speed - 8)','Obj15 exact 8-unit swing acceleration'),('swing_pause = 0x3C','Obj15 exact $3C endpoint pause'),
]: ck(token in mcz,msg)


ck('<=0x0C+p.width_radius' in mcz and '<=0x0C+p.height_radius' in mcz,'Obj75 rotating endpoint uses retail Touch_Sizes[$1A] $0C x $0C hazard envelope')
ck('_react_badnik(int(position.x),int(position.y),8,8,true)' in mcz,'Obj9E Crawlton uses retail Touch_Sizes[$0B] 8 x 8 enemy envelope')

# Generated mapping coverage.
expected={'collapse':2,'collapse_fragments':6,'stomper':1,'crate':1,'brick':3,'sliding_spikes':1,'gate':5,'pull_switch':2,'vine':7,'drawbridge':2,'crawlton':3,'flasher':5,'shared_platform':4,'swing_hazard':3,'gate_log':1}
for folder,n in expected.items():
    files=list((P/'assets/objects/s2_mcz'/folder).glob('*.png'))
    ck(len(files)==n,f'{folder} reconstructed source frame count {n}')
ck((P/'assets/objects/s2_mcz/vine/00.png').read_bytes()[:8]==b'\x89PNG\r\n\x1a\n','Tall MCZ vine frames are packaged PNG resources')

if S2 is not None:
    src=(S2/'s2.asm').read_text(errors='replace')
    obj=(S2/'level/objects/MCZ_1.bin').read_bytes(); counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    deferred={0x15,0x1F,0x2A,0x6A,0x75,0x76,0x77,0x7A,0x7F,0x80,0x81,0x9E,0xA3}
    ck(sum(counts[i] for i in deferred)==88,'Retail MCZ1 has exactly 88 formerly deferred MCZ-specific records')
    ck((P/'data/s1/s2test/mcz1_objects.bin').read_bytes()==obj,'MCZ1 placement stream remains byte-identical to retail')
    for needle,msg in [
      ('Obj1F_MCZ_DelayData:\n\tdc.b $1A,$16,$12, $E, $A,  2','Retail Obj1F MCZ delay table confirmed'),
      ('cmpi.w\t#$60,objoff_30(a0)','Retail Obj2A $60 travel confirmed'),
      ('byte_27CF4:','Retail Obj6A normal velocity table present'),('byte_27D12:','Retail Obj6A flipped velocity table present'),
      ('move.w\t#$80,sliding_spikes_remaining_movement(a0)','Retail Obj76 $80 movement confirmed'),
      ('move.w\t#$4B,d1','Retail Obj77/$81 $4B center-reach confirmed'),
      ('byte_293B4:','Retail Obj7A authored range/start table present'),
      ('addi.w\t#$30,y_pos(a1)','Retail Obj7F +$30 hang offset confirmed'),
      ('move.w\t#$B0,objoff_2E(a0)','Retail Obj80 $B0 travel confirmed'),
      ('addi.w\t#$94,y_pos(a1)','Retail Obj80 +$94 hang offset confirmed'),
      ('moveq\t#8,d1','Retail Obj81 eight-log child count confirmed'),
      ('move.b\t#$10,objoff_3A(a0)','Retail Obj9E $10 pre-charge timer confirmed'),
      ('move.b\t#$1C,objoff_3A(a0)','Retail Obj9E $1C charge timer confirmed'),
      ('move.w\t#$40,objoff_2A(a0)','Retail ObjA3 initial $40 timer confirmed'),
      ('word_38810:','Retail ObjA3 threshold table confirmed'),
    ]: ck(needle in src,msg)

for rel in ['tools/import_s2_mcz_objects_phase112.py','tools/validate_phase112.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:'); [print(' - '+x) for x in bad]; sys.exit(1)
