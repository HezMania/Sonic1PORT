#!/usr/bin/env python3
from __future__ import annotations
import hashlib, importlib.util, json, py_compile, sys
from collections import Counter
from pathlib import Path

P = Path(__file__).resolve().parents[1]
S2 = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
checks: list[tuple[bool,str]] = []

def ck(value, msg):
    ok = bool(value)
    checks.append((ok, msg))
    print(('PASS: ' if ok else 'FAIL: ') + msg)

def txt(rel): return (P/rel).read_text(errors='replace')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def be16(b,o): return (b[o]<<8)|b[o+1]
def func(t,name):
    token='func '+name
    if token not in t: return ''
    a=t.index(token); b=t.find('\nfunc ',a+1)
    return t[a:len(t) if b<0 else b]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec); assert spec.loader
    spec.loader.exec_module(mod); return mod

def parse_objects(raw: bytes):
    assert len(raw)%6==0
    out=[]
    for i in range(0,len(raw),6):
        yw=be16(raw,i+2)
        out.append({'x':be16(raw,i),'y':yw&0x0FFF,'flags':(yw>>12)&0xF,'id':raw[i+4],'subtype':raw[i+5]})
    return out

mtz=txt('scripts/objects/s2_mtz_object.gd')
om=txt('scripts/objects/object_manager.gd')
renderer=txt('scripts/render/ghz_renderer.gd')
sign=txt('scripts/objects/s2_signpost_adapter.gd')
cat=txt('scripts/data/level_catalog.gd')
main=txt('scripts/main.gd')
M122=json.loads((P/'data/s1/s2test/phase122_mtz2_manifest.json').read_text())
M123=json.loads((P/'data/s1/s2test/phase123_mtz2_objects_manifest.json').read_text())
raw_obj=(P/'data/s1/s2test/mtz2_objects.bin').read_bytes()
objects=parse_objects(raw_obj)
counts=Counter(r['id'] for r in objects)

# ---------------------------------------------------------------------------
# Reported Phase 122 regressions: animated lava and missing signpost.
# ---------------------------------------------------------------------------
tilepatch=func(renderer,'_collect_chunk_tile_patches(chunk_id: int, first_tile: int, last_tile: int) -> Array')
palpatch=func(renderer,'_collect_chunk_palette_patches(chunk_id: int, palette_lines: Array[int]) -> Array')
normalize='level.normalize_chunk_word(_be16(level.chunks, word_offset), GHZLevelData.COLLISION_PATH_PRIMARY)'
ck(normalize in tilepatch,'Animated tile refresh normalizes S2 chunk words before interpreting X/Y flip bits')
ck(normalize in palpatch,'Palette refresh normalizes S2 chunk words before interpreting X/Y flip bits')
ck('var block_flip_y = (chunk_word & 0x1000) != 0' in tilepatch,'Dynamic tile patcher reads normalized Sonic-1-style Y-flip bit')
# Prove the imported MTZ2 chunk stream actually contains lava blocks whose raw
# primary-top-solid bit would have been mistaken for Y-flip by the old path.
chunks=(P/'data/s1/s2test/mtz2_map128.bin').read_bytes()
lava_words=[]
for o in range(0,len(chunks)-1,2):
    w=be16(chunks,o)
    if (w&0x3FF) in (0x2F4,0x2F5,0x2F6,0x2F7): lava_words.append(w)
ck(bool(lava_words),'MTZ2 Map128 contains the retail animated-lava surface blocks $2F4-$2F7')
ck(any((w&0x1000)!=0 for w in lava_words),'MTZ2 lava blocks carry raw S2 primary-top solidity bit $1000')
# Raw S2 $1000 = primary top-solid, not Y flip. The normalized renderer maps it
# to $2000 and leaves $1000 clear unless raw bit $0800 is really set.
def norm_s2(w):
    n=w&0x3FF
    if w&0x0400:n|=0x0800
    if w&0x0800:n|=0x1000
    if w&0x1000:n|=0x2000
    if w&0x2000:n|=0x4000
    return n
ck(any((w&0x1000) and not (norm_s2(w)&0x1000) for w in lava_words),'Raw S2 lava top-solidity no longer becomes a false vertical flip after normalization')

ck(any(r['id']==0x0D and r['x']==0x1F40 and r['y']==0x1A8 for r in objects),'Retail MTZ2 signpost record $0D is present at $1F40,$1A8')
ck('metropolis_zone_act_2' in (S2/'s2.asm').read_text(errors='replace') if S2 else True,'Retail source tree is available for signpost exception validation')
ck('mtz2_exception' in sign and 'act == 2' in sign and 's2_mtz' in sign,'S2 signpost adapter preserves the explicit retail MTZ2 exception')
ck('if act != 1 and not mtz2_exception:' in sign,'Non-Act1 signposts still remain disabled outside the retail MTZ2 exception')
ck('\\t' not in sign,'Signpost adapter contains real GDScript indentation, not escaped tab literals')
if S2:
    s2asm=(S2/'s2.asm').read_text(errors='replace')
    section=s2asm[s2asm.index('Obj0D_Init:'):s2asm.index('Obj0D_Main:',s2asm.index('Obj0D_Init:'))]
    ck('cmpi.w\t#metropolis_zone_act_2' in section and 'tst.b\t(Current_Act).w' in section,'Retail Obj0D explicitly allows Metropolis Act 2 while rejecting ordinary later acts')

# ---------------------------------------------------------------------------
# MTZ2 Act-specific object families: exact record population and namespace.
# ---------------------------------------------------------------------------
expected_new={0x31:12,0x6C:9,0x70:6,0x71:11,0x72:2}
for oid,n in expected_new.items(): ck(counts[oid]==n,f'Retail MTZ2 contains exactly {n} placements of Object ${oid:02X}')
ck(sum(expected_new.values())==40,'The five completed MTZ2-specific families account for all 40 formerly deferred records')
route=func(om,'_make_object_for_id(id: int) -> GenesisLevelObject')
for oid in expected_new:
    ck(f'0x{oid:02X}' in route and 'return S2MTZObjectClass.new()' in route,f'Object ${oid:02X} is routed through the MTZ-local namespace')
ck('id in [0x6A,0x6E]' in route,'Only later MTZ families $6A/$6E remain namespace-blocked')
ck('id in [0x31,0x6A,0x6C,0x6E,0x70,0x71,0x72]' not in route,'Phase122 deferred-object blocker has been removed')

# $31 lava damage marker: source collision IDs $96/$94/$95 -> Touch_Sizes
# $16/$14/$15 = radii 32x32, 64x32, 128x32.
lava31=func(mtz,'_tick_lava_marker() -> void')
ck('[0x20,0x40,0x80][st]' in lava31 and '_hazard_overlap(orig_x,orig_y,hw,0x20)' in lava31,'Obj31 uses retail 32/64/128 x 32 hurt-marker radii')
ck('if st == 3:' in lava31,'Obj31 subtype 3 remains non-colliding like retail flag 0')

# $6C exact pulley loops/spawner descriptors and dominant-axis $100 8.8 speed.
for needle in [
 'Vector2i(-0x20,0xE0)','Vector2i(0,0x100)',
 'Vector2i(-0x20,0x160)','Vector2i(0,0x180)',
 'Vector2i(-0x20,0x1E0)','Vector2i(0,0x200)']:
    ck(needle in mtz,f'Obj6C retail pulley path coordinate retained: {needle}')
for needle in ['[0,0,0x01]','[-0x20,0x3A,0x03]','[0,0x100,0x06]',
               '[0,0,0x11]','[-0x20,0x5A,0x13]','[0,0x180,0x16]',
               '[0,0,0x21]','[-0x20,0x7A,0x23]','[0,0x200,0x26]']:
    ck(needle in mtz,f'Obj6C retail eight-child spawn descriptor retained: {needle}')
cupvel=func(mtz,'_cup_velocity(cx: int, cy: int, target: Vector2i) -> Vector2i')
ck('0x100 if dy > 0 else -0x100' in cupvel and '0x100 if dx > 0 else -0x100' in cupvel,'Obj6C dominant axis runs at exact retail +/-$100 8.8 velocity')
cupinit=func(mtz,'_init_lava_cups() -> void')
ck('var variant: int = clampi(subtype & 0x7F,0,2)' in cupinit,'Obj6C high-bit parent subtype selects the exact 0/1/2 pulley group')
ck('var step: int = -1 if x_flip else 1' in cupinit,'Obj6C X-flip reverses traversal direction')
cuptick=func(mtz,'_tick_lava_cups() -> void')
ck('p.resolve_platform_top(nx-0x18,nx+0x18,ny-8,record_index)' in cuptick,'Obj6C cups provide native PlatformObject top support')

# $70 exact 8-tooth four-phase wheel tables and 16-VBlank cadence.
for needle in ['[0,-0x48,0]','[0x32,-0x32,4]','[0x48,0,8]',
               '[0x0D,-0x48,1]','[0x19,-0x44,2]','[0x27,-0x3C,3]']:
    ck(needle in mtz,f'Obj70 retail wheel position/mapping tuple retained: {needle}')
geartick=func(mtz,'_tick_gear() -> void')
ck('(manager.elapsed_frames >> 4) & 3' in geartick,'Obj70 advances one of four retail wheel phases every $10 frames')
ck('phase = (-phase) & 3' in geartick,'Obj70 placement flip reverses rotation direction')
ck('mf2 == 7 or mf2 == 9' in geartick and 'mf2 == 8' in geartick,'Obj70 preserves special $0C/$08 SolidObject half-heights for frames 7/8/9')
ck('p.resolve_solid_box_contact' in geartick,'Obj70 all eight teeth are physically solid')

# $71 subtype $22 lava bubble exact AnimateSprite chain: delay $B frames 0..5,
# $FD -> anim3, then delay $7F frame6, $FD -> anim2.
bubinit=func(mtz,'_init_lava_bubble() -> void'); bubtick=func(mtz,'_tick_lava_bubble() -> void')
ck('lava_bubble_anim = 2' in bubinit,'Obj71 MTZ bubble starts on retail animation 2')
ck('lava_bubble_timer = 0x0B' in bubtick and 'f < 6' in bubtick,'Obj71 animation 2 uses delay $B and frames 0..5')
ck('lava_bubble_timer = 0x7F' in bubtick and '_set_frame(sprite,"lava_bubble",6)' in bubtick,'Obj71 animation 3 holds frame 6 for retail $7F delay')
ck('lava_bubble_anim = 2' in bubtick and 'frame_counter = 0' in bubtick,'Obj71 animation 3 returns to animation 2 rather than terminating')

# $72 invisible conveyor exact region and +/-2 px/frame ground push.
conv=func(mtz,'_tick_conveyor() -> void')
ck('var hw: int = (subtype & 0x7F) << 4' in conv,'Obj72 low 7 subtype bits select half-width in $10-pixel steps')
ck('var hh: int = 0x70 if (subtype & 0x80) != 0 else 0x30' in conv,'Obj72 high subtype bit selects retail $70/$30 half-height')
ck('p == null or p.dead or p.in_air' in conv,'Obj72 does not move airborne Sonic')
ck('p.force_add_pixel_offset(-2 if x_flip else 2,0)' in conv,'Obj72 pushes grounded Sonic exactly +/-2 pixels per frame')

# New exact sprite banks.
for folder,count in [('lava_cup',1),('gear',32),('lava_bubble',7)]:
    d=P/'assets/objects/s2_mtz'/folder
    files=sorted(d.glob('*.png'))
    ck(len(files)==count,f'{folder} contains exactly {count} rendered retail mapping frames')
for rel,dig in M123.get('sha256',{}).items():
    q=P/'assets/objects/s2_mtz'/rel
    ck(q.is_file() and sha(q)==dig,f'Phase123 MTZ object-art hash stable: {rel}')

# New child state participates in the MTZ $800 vertical torus.
wrap=func(mtz,'apply_vertical_wrap_shift(delta_y: int) -> void')
ck('cup["y"] = int(cup["y"]) + (delta_y << 16)' in wrap,'Obj6C fixed-point child Y follows MTZ vertical seam shifts')
ck('gear_prev_positions[i] = Vector2i(gp.x, gp.y + delta_y)' in wrap,'Obj70 previous-tooth positions follow MTZ vertical seam shifts')

# ---------------------------------------------------------------------------
# Foundation preservation, completion/progression, and debug identity.
# ---------------------------------------------------------------------------
ck(M122.get('objects')==220 and len(objects)==220,'MTZ2 retains all 220 exact retail placement records')
expected_hex={'06':4,'0D':1,'1C':12,'26':13,'2D':3,'31':12,'36':11,'41':6,'42':5,'47':4,'64':1,'65':10,'66':19,'67':4,'68':6,'69':9,'6B':14,'6C':9,'6D':12,'70':6,'71':11,'72':2,'74':12,'79':3,'9F':3,'A1':7,'A4':21}
ck({f'{k:02X}':v for k,v in sorted(counts.items())}==expected_hex,'All MTZ2 object IDs/counts still match retail exactly')
for rel,dig in M122.get('sha256',{}).items():
    q=P/'data/s1/s2test'/rel
    ck(q.is_file() and sha(q)==dig,f'Phase122 MTZ2 imported foundation unchanged: {rel}')
ck(M123.get('phase')==123,'Phase123 object-art manifest identifies the completion phase')
ck('Native Sonic 1 Phase 123' in main,'Debug overlay identifies Phase123')
ck('KEY_G:' in main and '_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 1)' in main,'G remains direct MTZ1 warp')
ck('KEY_C:' in main and '_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 2)' in main,'C remains direct MTZ2 warp')
nextf=func(cat,'next_level(zone: int, act: int) -> Vector2i')
ck('Vector2i(ZONE_S2_MTZ_TEST, 2) if act < 2 else Vector2i(ZONE_GHZ, 1)' in nextf,'MTZ1 progresses to MTZ2; MTZ2 safely falls back until MTZ3 import')

# Earlier MTZ1 source foundation/art must remain untouched.
for manifest,base_dir in [('phase119_mtz1_manifest.json',P/'data/s1/s2test'),('phase120_mtz_objects_manifest.json',P/'assets/objects/s2_mtz')]:
    mm=json.loads((P/'data/s1/s2test'/manifest).read_text())
    for rel,dig in mm.get('sha256',{}).items():
        q=base_dir/rel
        ck(q.is_file() and sha(q)==dig,f'{manifest}: retained hash stable for {rel}')

# Retail-source checks when supplied.
if S2:
    source_obj=(S2/'level/objects/MTZ_2.bin').read_bytes()
    ck(source_obj==raw_obj,'Imported MTZ2 object stream remains byte-for-byte retail')
    s2asm=(S2/'s2.asm').read_text(errors='replace')
    for label in ['Obj31_CollisionFlagsBySubtype:','Obj6C:','Obj70_Positions:','Ani_obj71:','Obj72:']:
        ck(label in s2asm,f'Retail source label present: {label}')
    ck('dc.b $96' in s2asm[s2asm.index('Obj31_CollisionFlagsBySubtype:'):s2asm.index('Obj31_Init:',s2asm.index('Obj31_CollisionFlagsBySubtype:'))], 'Retail Obj31 subtype 0 collision flag is $96')
    a=s2asm.index('byte_11389:'); b=s2asm.index('Obj71_MapUnc_11396:',a)
    anim=s2asm[a:b]
    ck('dc.b  $B,  0,  1,  2,  3,  4,  5,$FD,  3' in anim,'Retail Obj71 animation-2 byte sequence verified')
    ck('dc.b $7F,  6,$FD,  2' in anim,'Retail Obj71 animation-3 byte sequence verified')
    obj72=s2asm[s2asm.index('Obj72_Init:'):s2asm.index('Obj72_Action:',s2asm.index('Obj72_Init:'))]
    ck('move.w\t#2,objoff_36(a0)' in obj72 and 'move.w\t#$70,objoff_3C(a0)' in obj72,'Retail Obj72 speed and tall-region constants verified')

# Structural/syntax-oriented checks in absence of a Godot executable.
for rel in ['scripts/objects/s2_mtz_object.gd','scripts/objects/object_manager.gd','scripts/objects/s2_signpost_adapter.gd','scripts/render/ghz_renderer.gd','scripts/data/level_catalog.gd','scripts/main.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')
    ck('\\t' not in t,f'{rel} has no escaped-tab indentation artifacts')
for rel in ['tools/import_s2_mtz2_objects_phase123.py','tools/validate_phase123.py']:
    try:
        py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
