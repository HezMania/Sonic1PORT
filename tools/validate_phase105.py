#!/usr/bin/env python3
from pathlib import Path
import json, sys, importlib.util
from collections import Counter

PROJECT=Path(__file__).resolve().parents[1]
SRC=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def check(name, cond, detail=''):
    checks.append(bool(cond)); print(('PASS' if cond else 'FAIL')+': '+name+((' — '+detail) if detail else ''))

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(m); return m
terrain=load('terrain105',PROJECT/'tools/import_sonic2_level.py')

boss=(PROJECT/'scripts/objects/s2_cnz_boss_object.gd').read_text()
manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
trav=(PROJECT/'scripts/objects/s2_cnz_traversal_object.gd').read_text()
main=(PROJECT/'scripts/main.gd').read_text()
cat=(PROJECT/'scripts/data/level_catalog.gd').read_text()
bg=(PROJECT/'scripts/render/ghz_background_renderer.gd').read_text()
pal=(PROJECT/'scripts/render/level_palette_cycler.gd').read_text()
audio=(PROJECT/'scripts/audio/sonic_audio.gd').read_text()

check('Obj51 draws left claw child frame 5','left_claw_sprite.texture = load("res://assets/objects/s2_cnz/boss/05.png")' in boss)
check('Obj51 draws Eggman child frame 6','eggman_sprite.texture = load("res://assets/objects/s2_cnz/boss/06.png")' in boss)
check('Obj51 draws right claw child frame 2','right_claw_sprite.texture = load("res://assets/objects/s2_cnz/boss/02.png")' in boss)
check('Obj51 keeps explicit patrol leg','var patrol_leg: int = 0' in boss and 'if patrol_leg == 0:' in boss)
check('Obj51 resets drop counter at patrol endpoints',boss.count('drop_attacks = 0') >= 2)
check('Obj51 defeat opens source C54 wall','manager.open_s2_cnz_boss_exit_wall()' in boss)
check('Manager restores C54 to DD','set_chunk_id_at(0x54, 0x0C, 0xDD)' in manager)
check('Manager requests post-defeat chunk refresh','cnz_boss_exit_refresh_requested = true' in manager)
check('Main consumes boss exit refresh','object_manager.cnz_boss_exit_refresh_requested' in main and 'refresh_level_chunk(0x54, 0x0C)' in main)
check('Death retry restores C50 arena chunk','set_chunk_id_at(0x50, 0x0C, 0xDD)' in main)
check('Death retry restores C54 arena chunk','set_chunk_id_at(0x54, 0x0C, 0xDD)' in main)
check('Triangle bumpers include source face rejection',manager.count('var face_test: int = diagonal_x + by - 8 - (py + 14)') == 2)
check('Triangle face can reject broad-phase hit',manager.count('if face_test >= 0:') == 2)
check('Flipper body uses raw $18 half-width','const FLIPPER_RAW_HALF_WIDTH := 0x18' in trav)
check('Flipper preserves source 12px sloped thickness','const FLIPPER_SOLID_THICKNESS := 0x0C' in trav)
check('Flipper has underside collision path','var underside_y: int = top_y + FLIPPER_SOLID_THICKNESS' in trav and 'p.vel_y < 0' in trav)

check('Hill Top zone slot registered','const ZONE_S2_HTZ_TEST := 12' in cat)
check('CNZ2 progression reaches HTZ1','Vector2i(ZONE_S2_HTZ_TEST, 1)' in cat)
check('HTZ catalog retains retail Act 1 right bound $2800','0x3280 if act == 2 else 0x2800' in cat or '"limit_right": 0x2800' in cat)
check('HTZ catalog uses S2 HTZ background mode','"background_mode": "s2htz"' in cat)
check('HTZ direct Y warp exists','KEY_Y:' in main and 'ZONE_S2_HTZ_TEST' in main)
check('HTZ music id is $19A','const MUS_S2_HTZ := 0x19A' in audio)
check('HTZ music is selected by Main','SonicAudio.play_music(SonicAudio.MUS_S2_HTZ, true)' in main)
check('HTZ palette cycle source is wired','S2 Hill Top Lava Cycle.bin' in pal and '_tick_s2_htz()' in pal)
check('HTZ background has source-shaped 128+96 split','if y < 128:' in bg and 'var lower_lengths: Array[int] = [3,5,7,8,10,15,16,16,16]' in bg)

s2=PROJECT/'data/s1/s2test'
req=['htz1_art.bin','htz1_map16.bin','htz1_map128.bin','htz1_layout128.bin','htz1_bg128.bin','htz1_collision_primary.bin','htz1_collision_secondary.bin','htz1_objects.bin','htz1_rings.bin','htz1_start.bin']
for n in req: check('HTZ generated '+n,(s2/n).is_file())
check('HTZ art bank is 0x10000 bytes',(s2/'htz1_art.bin').stat().st_size==0x10000)
check('HTZ Map16 bank is 0x1800 bytes',(s2/'htz1_map16.bin').stat().st_size==0x1800)
check('HTZ Map128 is 0x8000 bytes',(s2/'htz1_map128.bin').stat().st_size==0x8000)
start=(s2/'htz1_start.bin').read_bytes(); check('HTZ1 retail start is $0060,$03EF',start==bytes.fromhex('006003ef'),start.hex())
obj=(s2/'htz1_objects.bin').read_bytes(); c=Counter(obj[i+4] for i in range(0,len(obj),6)); check('HTZ1 has 144 retail placements',len(obj)//6==144,str(len(obj)//6))
existing={0x03,0x0D,0x18,0x1C,0x26,0x2D,0x32,0x36,0x41,0x74,0x79,0x84}
shared=sum(v for k,v in c.items() if k in existing); check('HTZ1 shared native coverage is 100/144',shared==100,str(shared))
deferred=sum(v for k,v in c.items() if k not in existing); check('HTZ-specific deferred records are exactly 44',deferred==44,str(deferred))

songdb=json.loads((PROJECT/'data/s1/sound/s2_ehz_smps.json').read_text()); song=songdb.get('music',{}).get('410',{})
check('HTZ SMPS song merged into database',song.get('name')=='Sonic 2 - Hill Top Zone')
check('HTZ song uses only retained DAC 0/1',song.get('source',{}).get('used_dac_ids')==[0,1],str(song.get('source',{}).get('used_dac_ids')))

if SRC:
    base=terrain.kosinski_decompress((SRC/'mappings/16x16/EHZ.bin').read_bytes())
    hpatch=terrain.kosinski_decompress((SRC/'mappings/16x16/HTZ.bin').read_bytes())
    m=(s2/'htz1_map16.bin').read_bytes()
    check('HTZ Map16 retains exact EHZ base prefix',m[:0x980]==base[:0x980])
    check('HTZ Map16 applies exact source patch at $980',m[0x980:0x980+len(hpatch)]==hpatch)
    map128=terrain.kosinski_decompress((SRC/'mappings/128x128/EHZ_HTZ.bin').read_bytes())
    check('HTZ Map128 copied from exact retail source',(s2/'htz1_map128.bin').read_bytes()==map128)
    check('HTZ object stream copied byte-identically',obj==(SRC/'level/objects/HTZ_1.bin').read_bytes())
    check('HTZ ring stream copied byte-identically',(s2/'htz1_rings.bin').read_bytes()==(SRC/'level/rings/HTZ_1.bin').read_bytes())
    source=(SRC/'s2.asm').read_text(errors='replace')
    check('Retail Obj51 restores C54 to DD','Level_Layout+$C54' in source and '#$DD' in source)
    check('Retail HTZ patches Block_Table+$980','Block_Table+$980' in source and 'BM16_HTZ' in source)

print(f'\n{sum(checks)}/{len(checks)} checks passed')
raise SystemExit(0 if all(checks) else 1)
