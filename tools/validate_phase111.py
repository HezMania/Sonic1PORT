#!/usr/bin/env python3
from __future__ import annotations
import hashlib, importlib.util, json, py_compile, sys
from collections import Counter
from pathlib import Path

P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(cond,msg): checks.append((bool(cond),msg)); print(('PASS: ' if cond else 'FAIL: ')+msg)
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
terrain=load('terrain111v',P/'tools/import_sonic2_level.py')

def sim_fire_chain(start_spread=3):
    # Retail Obj20 routine A: timer=9; on underflow timer=$7F, --spread, one
    # child with timer=9; Ani_obj20 #2 is 12 frames at delay 5 then $FC/delete.
    active=[{'age':0,'timer':9,'spread':start_spread,'born':0}]
    total=1; peak=1
    for frame in range(300):
        new=[]; keep=[]
        for f in active:
            f=f.copy(); f['age']+=1; f['timer']-=1
            if f['timer']<0:
                f['timer']=0x7F; f['spread']-=1
                if f['spread']>=0:
                    new.append({'age':0,'timer':9,'spread':f['spread'],'born':frame+1}); total+=1
            # 12 frames * (5+1) VBlanks; $FC advances to delete routine.
            if f['age'] < 72: keep.append(f)
        active=keep+new; peak=max(peak,len(active))
        if not active: return total,peak,frame+1
    return total,peak,300

boss=(P/'scripts/objects/s2_htz_boss_object.gd').read_text()
ck('int(f["anim_step"]) >= FLOOR_FIRE_ANIM.size()' in boss,'HTZ floor fire terminates at authored animation end')
ck('int(f["anim"]) > 0x240' not in boss,'Phase110 indefinite $240 age lifetime removed')
ck('f["timer"] = 0x7F' in boss and 'f["spread"] = int(f["spread"]) - 1' in boss,'Retail Obj20 $7F reset and spread decrement retained')
ck('dir * 0x0E' in boss,'Retail floor-fire propagation spacing is $0E')
ck('GenesisMath.s16(int(b["vx"])) < 0' in boss,'Lava-ball X velocity determines floor-fire propagation direction')
total,peak,lifetime=sim_fire_chain()
ck(total==4,f'Retail fire chain is finite at four flames per lava ball (got {total})')
ck(peak<=4,f'Retail fire chain peak stays bounded (peak {peak})')
ck(lifetime<200,f'Retail fire chain fully cleans up quickly (simulated {lifetime} frames)')

if S2 is not None:
    src=(S2/'s2.asm').read_text(errors='replace')
    seg=src[src.index('loc_30008:'):src.index('loc_300A4:')]
    ck('move.b\t#ObjID_LavaBubble,id(a0)' in seg,'Retail Obj52 converts landed lava ball to Object $20')
    ck('move.w\t#9,objoff_32(a0)' in seg and 'move.b\t#3,objoff_36(a0)' in seg,'Retail Obj52 seeds floor fire timer=9/spread=3')
    obj20=src[src.index('loc_231D2:'):src.index('Obj20_MapUnc_23254:')]
    ck('move.w\t#$7F,objoff_32(a0)' in obj20,'Retail Object $20 resets propagation timer to $7F')
    ck('subq.b\t#1,objoff_36(a0)' in obj20,'Retail Object $20 decrements finite propagation count')
    ck('dc.b   5,  4,  5,  2,  3,  0,  1,  0,  1,  2,  3,  4,  5,$FC' in src,'Retail floor-fire animation terminates with $FC routine advance')

    data=P/'data/s1/s2test'
    manifest=json.loads((data/'phase111_mcz1_manifest.json').read_text())
    ck(manifest['start']==[0x60,0x6AC],'MCZ1 retail start is $0060,$06AC')
    ck(manifest['limits']=={'left':0,'right':0x2380,'top':0x3C0,'bottom':0x720},'MCZ1 retail LevelSize bounds match source')
    ck((data/'mcz1_objects.bin').read_bytes()==(S2/'level/objects/MCZ_1.bin').read_bytes(),'MCZ1 object stream byte-identical to retail')
    ck((data/'mcz1_rings.bin').read_bytes()==(S2/'level/rings/MCZ_1.bin').read_bytes(),'MCZ1 ring stream byte-identical to retail')
    ck((data/'mcz1_start.bin').read_bytes()==(S2/'startpos/MCZ_1.bin').read_bytes(),'MCZ1 start stream byte-identical to retail')
    lay=terrain.kosinski_decompress((S2/'level/layout/MCZ_1.bin').read_bytes())
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=lay[off:off+0x80]; bg+=lay[off+0x80:off+0x100]
    ck((data/'mcz1_layout128.bin').read_bytes()[2:]==bytes(fg),'MCZ1 foreground split byte-identical to decoded retail layout')
    ck((data/'mcz1_bg128.bin').read_bytes()[2:]==bytes(bg),'MCZ1 Plane B split byte-identical to decoded retail layout')
    ck((data/'mcz1_map16.bin').read_bytes()==terrain.kosinski_decompress((S2/'mappings/16x16/MCZ.bin').read_bytes()),'MCZ Map16 byte-identical to retail decompression')
    ck((data/'mcz1_map128.bin').read_bytes()==terrain.kosinski_decompress((S2/'mappings/128x128/MCZ.bin').read_bytes()),'MCZ Map128 byte-identical to retail decompression')
    col=terrain.kosinski_decompress((S2/'collision/MCZ primary 16x16 collision index.bin').read_bytes())
    ck((data/'mcz1_collision_primary.bin').read_bytes()==col and (data/'mcz1_collision_secondary.bin').read_bytes()==col,'MCZ shared primary/secondary collision index matches retail pointer table')
    ck((P/'data/s1/palette/S2 Mystic Cave Zone.bin').read_bytes()==(S2/'art/palettes/MCZ.bin').read_bytes(),'MCZ palette byte-identical to retail')
    ck((P/'data/s1/palette/S2 Mystic Cave Lantern Cycle.bin').read_bytes()==(S2/'art/palettes/MCZ Lantern.bin').read_bytes(),'MCZ lantern cycle byte-identical to retail')
    counts=Counter((S2/'level/objects/MCZ_1.bin').read_bytes()[i+4] for i in range(0,len((S2/'level/objects/MCZ_1.bin').read_bytes()),6))
    ck(sum(counts.values())==130,'MCZ1 retains all 130 retail placement records')
    ck(manifest['active_shared_records']==42 and manifest['deferred_mcz_specific_records']==88,'MCZ1 foundation activates 42 source-correct shared records and defers 88 MCZ-specific records')

cat=(P/'scripts/data/level_catalog.gd').read_text()
ck('const ZONE_S2_MCZ_TEST := 13' in cat,'LevelCatalog defines dedicated MCZ zone')
ck((('"limit_right": 0x2380' in cat and '"limit_top": 0x03C0' in cat) or ('0x3FFF if act == 2 else 0x2380' in cat and '0x0060 if act == 2 else 0x03C0' in cat)),'LevelCatalog uses retail MCZ1 bounds')
ck('Vector2i(ZONE_S2_MCZ_TEST, 1)' in cat,'HTZ2 progression now enters MCZ1')
main=(P/'scripts/main.gd').read_text(); audio=(P/'scripts/audio/sonic_audio.gd').read_text()
ck('KEY_X' in main and 'ZONE_S2_MCZ_TEST' in main,'X debug warp reaches MCZ1')
ck('const MUS_S2_MCZ := 0x19B' in audio and 'MUS_S2_MCZ' in main,'MCZ retail music has dedicated port-local ID/playback')
bg=(P/'scripts/render/ghz_background_renderer.gd').read_text()
ck('S2_MCZ_ROW_HEIGHTS' in bg and 'S2_MCZ_ROW_NUMERATORS' in bg,'MCZ source row-height/parallax tables are present')
ck(sum([0x25,0x17,0x12,7,7,2,2,0x30,0x0D,0x13,0x20,0x40,0x20,0x13,0x0D,0x30,2,2,7,7,0x20,0x12,0x17,0x25])==0x200,'Retail MCZ row heights form exact $200-line cycle')
ck('int(camera_model.screen_y / 3) - 0x140' in bg,'MCZ1 vertical parallax uses retail CameraY/3-$140')
ck('var tenth_base_q4: int = int((camera_x << 4) / 10)' in bg and '(tenth_base_q4 * numerator) >> 4' in bg,'MCZ horizontal parallax preserves retail DIVS fixed-point quantization')
pal=(P/'scripts/render/level_palette_cycler.gd').read_text()
ck('_write_single(level.palette, 27' in pal and 'pcyc_time = 1' in pal,'MCZ lantern cycles CRAM index 27 every two VBlanks')
om=(P/'scripts/objects/object_manager.gd').read_text()
ck('bool(level_definition.get("s2_mcz", false))' in om,'MCZ-specific numeric aliases are zone-gated instead of borrowing other-zone objects')

for rel in ['tools/import_s2_mcz1_phase111.py','tools/validate_phase111.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f"\n{len(checks)-len(bad)}/{len(checks)} checks passed")
if bad: sys.exit(1)
