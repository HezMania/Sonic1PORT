#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, re, sys, zipfile
from PIL import Image

P=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
S2=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
PHASE135=Path(sys.argv[3]).resolve() if len(sys.argv)>3 else None
PHASE134=Path(sys.argv[4]).resolve() if len(sys.argv)>4 else None
checks=[]
def ck(c,m):
    checks.append((bool(c),m)); print(('PASS' if c else 'FAIL')+': '+m)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha_bytes(b): return hashlib.sha256(b).hexdigest()
def sha_file(p): return sha_bytes(Path(p).read_bytes())

main=txt('scripts/main.gd')
c6=txt('scripts/objects/s2_dez_eggman_runner.gd')
c7=txt('scripts/objects/s2_dez_egg_robo.gd')
mecha=txt('scripts/objects/s2_dez_mecha_sonic.gd')
bg=txt('scripts/render/ghz_background_renderer.gd')
imp=txt('tools/import_s2_dez_final_phase135.py')
man=json.loads((P/'data/s1/s2test/phase136_dez_final_corrections_manifest.json').read_text())

ck('Native Sonic 1 Phase 136' in main,'Debug overlay identifies Phase136')
ck((P/'PHASE136_SONIC2_DEATH_EGG_FINAL_BOSS_CORRECTIONS.md').exists(),'Phase136 notes packaged')
ck(man.get('phase')==136,'Phase136 correction manifest version')

# C6 door: raw Object width, actual runtime PLC art, and opening bridge.
ck('resolve_solid_box_contact(DOOR_X, DOOR_Y, 0x08, 0x20' in c6,'C6 door passes raw width_pixels $08 to native SolidObject adapter')
ck('door_state = 1' in c6 and 'door_timer >= 8' in c6 and 'mini(3, door_timer >> 1)' in c6,'C6 door retains retail 0→1→2→3 opening sequence')
ck("Stripy blocks from CPZ.bin" in imp and 'nemesis_decompress' in imp,'C6 importer uses dynamic retail construction-stripe Nemesis PLC')
ck('level_art[0x328*32:]' not in imp,'C6 importer no longer samples nonexistent static DEZ art at tile $328')
expected_boxes=[[88,64,104,128],[88,64,104,112],[88,64,104,96],[88,64,104,80]]
boxes=[]
for i in range(4):
    f=P/f'assets/objects/s2_dez/eggman_door/{i:02d}.png'
    im=Image.open(f).convert('RGBA')
    b=im.getbbox(); boxes.append(list(b) if b else [])
    ck(bool(b),f'C6 corrected door frame {i} is visible')
ck(boxes==expected_boxes,'C6 door frames have exact 16px stripe width and retail 64/48/32/16px heights')
ck(man['door']['raw_half_width']==8 and man['door']['frame_bboxes']==expected_boxes,'C6 correction manifest records raw width and frame geometry')

# C7 source-facing orientation and height split.
ck('const STAND_Y: int = 0x124' in c7,'Live Death Egg Robot standing origin is $124')
ck('const DEFEAT_FLOOR_Y: int = 0x15C' in c7,'Defeated shell floor remains retail $15C')
ck('y_fixed = STAND_Y << 16' in c7,'Normal stomp landing returns to standing Y $124')
ck('if (y_fixed >> 16) < DEFEAT_FLOOR_Y:' in c7 and 'y_fixed = DEFEAT_FLOOR_Y << 16' in c7,'Defeat bounce alone uses floor Y $15C')
ck('s.flip_h = not facing_left' in c7,'Left-facing retail C7 art is unflipped; right-facing art is flipped')
ck(c7.count('var sx: int = 1 if facing_left else -1')>=3,'C7 linked-part/hazard/bomb mirroring follows retail render-flag sense')

# C7 selector: increment before raw byte_3D680 table lookup.
inc=c7.find('attack_index = (attack_index + 1) & 3')
lookup=c7.find('attack_kind = ATTACK_ORDER[attack_index]')
ck(inc>=0 and lookup>inc,'C7 increments selector before indexing raw [2,0,2,4] table')
ck(man['egg_robo']['raw_selector']==[2,0,2,4] and man['egg_robo']['effective_initial_cycle']==[0,2,4,2],'Manifest records raw and effective opening attack cycles')

# Exact body deltas/durations from off_3E40C / off_3E42C.
DX=[0,-16,-8,0,-12,0,-16,-8,0,-12,0,0]
DY=[-4,-4,4,8,-4,0,-4,4,8,-4,0,8]
D=[0x20,0x10,0x10,0x10,0x20,0x20,0x10,0x10,0x10,0x20,0x20,0x10]
F=[0,1,2,3,4,5,6,7,8,9,10,1,2,3,4,5,6,7,8]
R=[8,7,6,5,11]
forward=sum(DX[g]*D[g] for g in F)//16
forward_y=sum(DY[g]*D[g] for g in F)//16
recovery=sum(((-DX[g]) if i<4 else DX[g])*D[g] for i,g in enumerate(R))//16
recovery_y=sum(((-DY[g]) if i<4 else DY[g])*D[g] for i,g in enumerate(R))//16
ck(forward==-168 and recovery==24 and forward+recovery==-144 and forward_y+recovery_y==0,'Retail C7 walk tables produce -168+24=-144px net with zero Y drift')
for token,msg in [
 ('const WALK_GROUP_DX16: Array[int] = [0, -16, -8, 0, -12, 0, -16, -8, 0, -12, 0, 0]','C7 walk DX table embedded'),
 ('const WALK_GROUP_DY16: Array[int] = [-4, -4, 4, 8, -4, 0, -4, 4, 8, -4, 0, 8]','C7 walk DY table embedded'),
 ('const WALK_FORWARD_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1, 2, 3, 4, 5, 6, 7, 8]','C7 off_3E40C group order embedded'),
 ('const WALK_RECOVERY_SEQUENCE: Array[int] = [8, 7, 6, 5, 11]','C7 off_3E42C recovery order embedded'),
 ('x_fixed += dx16 * 0x1000','C7 applies source 1/16px deltas to 16.16 position'),
]: ck(token in c7,msg)
ck(man['egg_robo']['first_walk_forward_pixels']==-168 and man['egg_robo']['first_walk_recovery_pixels']==24 and man['egg_robo']['first_walk_net_pixels']==-144,'Manifest records source walk displacement')

# SetupEnding is a non-displayed explosion anchor in retail.
ending_enter=c7[c7.find('state = ST_ENDING'):c7.find('func _tick_ending')]
ck('body.visible = false' in ending_enter and 'head.visible = false' in ending_enter,'C7 remaining body/head stop rendering when SetupEnding begins')
ck('x_fixed = (p.pixel_x() - ending_timer) << 16' in c7,'Invisible SetupEnding explosion anchor still follows retail Sonic-relative path')

# Frozen runtime-confirmed Phase134 content.
if PHASE134 is not None and PHASE134.exists():
    with zipfile.ZipFile(PHASE134) as z:
        for rel in ['scripts/objects/s2_dez_mecha_sonic.gd','scripts/render/ghz_background_renderer.gd','data/s1/s2test/dez1_objects.bin']:
            ck(sha_bytes(z.read(rel))==sha_file(P/rel),f'Phase134 runtime-confirmed file frozen: {rel}')

# Phase135 delta must remain tightly scoped.
if PHASE135 is not None and PHASE135.exists():
    allowed={
        'assets/objects/s2_dez/eggman_door/00.png','assets/objects/s2_dez/eggman_door/01.png',
        'assets/objects/s2_dez/eggman_door/02.png','assets/objects/s2_dez/eggman_door/03.png',
        'scripts/main.gd','scripts/objects/s2_dez_egg_robo.gd','scripts/objects/s2_dez_eggman_runner.gd',
        'tools/import_s2_dez_final_phase135.py',
    }
    with zipfile.ZipFile(PHASE135) as z:
        changed=[]
        for rel in z.namelist():
            if rel.endswith('/'): continue
            pp=P/rel
            if pp.exists() and sha_bytes(z.read(rel))!=sha_file(pp): changed.append(rel)
    ck(set(changed)==allowed,'Phase136 changes only intended Phase135 runtime/import files')

# Retail source evidence.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    c6src=asm[asm.index('ObjC6_State2_State1:'):asm.index('ObjC6_SubObjData3:')]
    ck('move.w\t#$13,d1' in c6src and 'move.w\t#$20,d2' in c6src and 'move.w\t#$20,d3' in c6src,'Retail C6 SolidObject uses expanded d1=$13 and vertical $20/$20')
    sub=asm[asm.index('ObjC6_SubObjData4:'):asm.index('ObjC6_SubObjData:')]
    ck('ArtTile_ArtNem_ConstructionStripes_1' in sub and ',4,1,8,0' in sub,'Retail C6 subtype $A8 raw width_pixels is $08')
    source_art=S2/'art/nemesis/Stripy blocks from CPZ.bin'
    source_map=S2/'mappings/sprite/objC6_b.bin'
    ck(sha_file(source_art)==man['door']['art_sha256'],'Manifest construction-stripe art hash matches retail source')
    ck(sha_file(source_map)==man['door']['mapping_sha256'],'Manifest C6 door mapping hash matches retail source')
    c7src=asm[asm.index('loc_3D640:'):asm.index('loc_3D684:')]
    ck(c7src.find('addq.b\t#1,d0') < c7src.find('move.b\tbyte_3D680(pc,d0.w),d0'),'Retail C7 source increments selector before byte_3D680 lookup')
    ck(re.search(r'byte_3D680:\s*\n\s*dc\.b\s+2\s*\n\s*dc\.b\s+0.*\n\s*dc\.b\s+2.*\n\s*dc\.b\s+4',c7src,re.S) is not None,'Retail byte_3D680 raw selector is 2,0,2,4')
    rise=asm[asm.index('loc_3D5C2:'):asm.index('loc_3D62E:')]
    ck('#$79' in rise and '#-$100' in rise,'Retail boss rise is $79 at -$100, yielding active origin $124 from $19C')
    defeat=asm[asm.index('loc_3D8E6:'):asm.index('loc_3D922:')]
    ck('#$15C' in defeat,'Retail $15C Y is confined to defeated body bounce')
    setup=asm[asm.index('ObjC7_SetupEnding:'):asm.index('ObjC7_Shoulder:')]
    ck('DisplaySprite' not in setup,'Retail ObjC7_SetupEnding does not submit the midsection sprite')

# Parser-oriented sanity for exact Godot 4.6.3 target.
for rel in ['scripts/main.gd','scripts/objects/s2_dez_eggman_runner.gd','scripts/objects/s2_dez_egg_robo.gd']:
    body=txt(rel)
    ck(not any(x in body for x in ['<<<<<<<','=======','>>>>>>>']),f'{rel} has no conflict markers')
    ck(body.count('(')==body.count(')'),f'{rel} parentheses balance')
    ck(body.count('[')==body.count(']'),f'{rel} brackets balance')
    ck(body.count('{')==body.count('}'),f'{rel} braces balance')
ck(':=' not in c6,'C6 correction keeps explicit declarations')
ck(':=' not in c7,'C7 correction keeps explicit declarations')

passed=sum(ok for ok,_ in checks)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' -',msg)
    raise SystemExit(1)
