#!/usr/bin/env python3
from __future__ import annotations
import hashlib, importlib.util, json, py_compile, sys
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
    token='func '+name
    if token not in t:return ''
    a=t.index(token);b=t.find('\nfunc ',a+1);return t[a:len(t) if b<0 else b]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod

def be16(b,o): return (b[o]<<8)|b[o+1]

mtz=txt('scripts/objects/s2_mtz_object.gd')
om=txt('scripts/objects/object_manager.gd')
base=txt('scripts/objects/genesis_level_object.gd')
spikes=txt('scripts/objects/s2_spikes_object.gd')
cat=txt('scripts/data/level_catalog.gd')
main=txt('scripts/main.gd')
M=json.loads((P/'data/s1/s2test/phase122_mtz2_manifest.json').read_text())

# ---------------------------------------------------------------------------
# Phase 121 carry-forward corrections.
# ---------------------------------------------------------------------------
button=func(mtz,'_tick_button() -> void')
ck('if not _source_visible(orig_x,int(position.y),32):' in button,'Obj47 does not touch ButtonVine_Trigger while off-screen')
ck('trigger_bit: int = 7 if (subtype & 0x40) != 0 else 0' in button,'Obj47 preserves retail subtype-bit6 -> trigger-bit7 semantics')
ck('_trigger_set(idx,true,trigger_bit)' in button and '_trigger_set(idx,false,trigger_bit)' in button,'Obj47 sets/clears only its selected trigger bit')
ck('int(manager.mcz_button_vine_triggers[idx]) == 0' in button,'Obj47 Blip test follows retail whole-byte trigger check')
trig=func(mtz,'_trigger_set(index: int, value: bool, bit: int = 0) -> void')
ck('current |= mask' in trig and 'current &= ~mask' in trig,'ButtonVine trigger writes preserve unrelated bits')

shellinit=func(mtz,'_init_shellcracker() -> void')
shell=func(mtz,'_shell_set_chain(elapsed: int, show_chain: bool = true) -> int')
shelltick=func(mtz,'_tick_shellcracker() -> void')
ck('frame: int = 5 if i == 0 else 4' in shellinit,'Shellcracker child 0 is claw frame 5; children 1..7 are joint frame 4')
ck('[0,3,5,7,9,11,13,15]' in shell,'Shellcracker uses exact ObjA0 stagger delays')
ck('[13,12,10,8,6,4,2,0]' in shell,'Shellcracker uses exact ObjA0 extension travel durations')
ck('[20,14,14,14,14,14,14,14]' in shell,'Shellcracker uses retail tucked claw/joint offsets')
ck('var offset: int = bases[i] + moved' in shell and 'local_t <= duration + 8' in shell,'Shellcracker keeps the retail 8-frame extended hold before retracting')
ck('s.position=Vector2(sign*offset,-8 if i==0 else -2)' in shell,'Shellcracker claw/joints use distinct retail Y offsets')
ck('attack_phase > 35' in shelltick and '_shell_set_chain(0,false)' in shelltick,'Shellcracker keeps claw visible through the full reverse trip')
ck('claw_offset' in shelltick and '_hazard_overlap' in shelltick,'Shellcracker hit point follows the moving claw rather than a fixed 56px guess')

# MTZ vertical wrap object-space correction demonstrated by the supplied video.
wrap=func(om,'_wrap_object_to_camera_image(obj: GenesisLevelObject) -> void')
ck('0x400' in wrap and '0x800' in wrap,'Object manager chooses nearest image in the retail $800 MTZ vertical torus')
ck('obj.apply_vertical_wrap_shift(delta_y)' in wrap,'Manager delegates vertical seam shifts to object adapters')
execf=func(om,'execute_objects() -> void')
ck('bool(level_definition.get("s2_mtz", false))' in execf and '_wrap_object_to_camera_image(obj)' in execf,'MTZ active objects are wrapped before their behavior tick')
ck('func apply_vertical_wrap_shift(delta_y: int) -> void:' in base,'Base level objects expose a vertical-wrap shift hook')
mtzwrap=func(mtz,'apply_vertical_wrap_shift(delta_y: int) -> void')
for needle,msg in [
    ('orig_y += delta_y','MTZ cached authored Y follows seam shifts'),
    ('platform_fixed_y += delta_y << 16','MTZ 16.16 platform Y follows seam shifts'),
    ('nut_fixed_y += delta_y << 16','MTZ screw/nut fixed Y follows seam shifts'),
    ('tube_fixed_y += delta_y << 16','Controlled MTZ tube fixed Y follows seam shifts')]: ck(needle in mtzwrap,msg)
spwrap=func(spikes,'apply_vertical_wrap_shift(delta_y: int) -> void')
ck('origin_y += delta_y' in spwrap,'Shared S2 spike origin follows MTZ vertical seam shift')
nut=func(mtz,'_tick_nut() -> void')
ck('&0x7FF' not in nut,'Obj69 no longer snaps a wrapped top-screen bolt back to bottom-space every tick')
plat=func(mtz,'_tick_platform() -> void')
ck('position.y=float(platform_fixed_y)/65536.0' in plat,'Obj6B keeps signed wrapped 16.16 Y instead of forcing $000..$7FF')

# Full retail Obj67 table, including the four MTZ2 subtypes 3/4/5/6.
ck(mtz.count('Vector2i(') >= 62,'Obj67 adapter contains the complete multi-act tube path coordinate table')
for start in ['0x5D8,0x370','0x5D8,0x5F0','0xBD8,0x1F0','0x1728,0x330','0x2058,0x430','0x2328,0x5B0']:
    ck(start in mtz,f'Obj67 retail path table contains start {start}')
spin=func(mtz,'_init_spin_tube() -> void')
ck('var idx: int = subtype & 0x0F' in spin and 'idx >= TUBE_PATHS.size()' in spin,'Obj67 uses actual subtype path index without clamping valid later-act paths')
ck('tube_path.append(Vector2i(point))' in spin,'Obj67 preserves Godot 4.6 typed Array path copy fix')

# ---------------------------------------------------------------------------
# Exact MTZ2 foundation.
# ---------------------------------------------------------------------------
ck(M.get('phase')==122 and M.get('level')=='Metropolis Zone Act 2','Phase122 MTZ2 manifest identifies correct phase/act')
ck(M.get('start')==[0x60,0x5EC],'MTZ2 retail start is $0060,$05EC')
ck(M.get('limits')=={'left':0,'right':0x1E80,'top':-0x100,'bottom':0x800},'MTZ2 retail LevelSize bounds are exact')
ck(M.get('objects')==220,'MTZ2 retains all 220 retail object records')
ck(M.get('rings')==90,'MTZ2 source ring stream contains 90 six-byte descriptors')
ck(M.get('active_existing_records')==180 and M.get('deferred_act2_specific_records')==40,'MTZ2 enables 180 established records and safely defers 40 Act-2-specific records')
expected={'06':4,'0D':1,'1C':12,'26':13,'2D':3,'31':12,'36':11,'41':6,'42':5,'47':4,'64':1,'65':10,'66':19,'67':4,'68':6,'69':9,'6B':14,'6C':9,'6D':12,'70':6,'71':11,'72':2,'74':12,'79':3,'9F':3,'A1':7,'A4':21}
ck(M.get('object_counts_hex')==expected,'MTZ2 object-ID histogram matches retail exactly')
for rel,size in [
 ('mtz2_art.bin',0x10000),('mtz2_map16.bin',0x1800),('mtz2_map128.bin',0x8000),
 ('mtz2_layout128.bin',2+128*16),('mtz2_bg128.bin',2+128*16),
 ('mtz2_collision_primary.bin',0x300),('mtz2_collision_secondary.bin',0x300),
 ('mtz2_objects.bin',220*6),('mtz2_rings.bin',544),('mtz2_start.bin',4)]:
    q=P/'data/s1/s2test'/rel; ck(q.is_file() and q.stat().st_size==size,f'{rel} has expected size {size:#x}')
for rel,dig in M.get('sha256',{}).items():
    q=P/'data/s1/s2test'/rel; ck(q.is_file() and sha(q)==dig,f'MTZ2 imported output hash stable: {rel}')

# Namespace: new Act2 families must not alias unrelated earlier-zone IDs.
route=func(om,'_make_object_for_id(id: int) -> GenesisLevelObject')
for oid in ['0x31','0x6C','0x70','0x71','0x72']:
    ck(oid in route,f'MTZ2 deferred object ID {oid} is explicitly namespace-blocked')
ck('id in [0x31,0x6A,0x6C,0x6E,0x70,0x71,0x72]' in route,'MTZ later-act blocker is evaluated before shared older-zone routing')

# Catalog/routing/hotkey.
mtzcat=func(cat,'_get_sonic2_mtz_test(requested_act: int = 1) -> Dictionary')
for needle,msg in [
 ('clampi(requested_act, 1, 2)','MTZ catalog accepts Acts 1 and 2'),
 ('var prefix: String = "mtz%d" % act','MTZ catalog selects per-act imported streams'),
 ('0x2280 if act == 1 else 0x1E80','MTZ catalog selects exact right boundary per act'),
 ('"s2_objects": "s2test/%s_objects.bin" % prefix','MTZ catalog selects exact object stream'),
 ('"s2_rings": "s2test/%s_rings.bin" % prefix','MTZ catalog selects exact ring stream'),
 ('"start": "s2test/%s_start.bin" % prefix','MTZ catalog selects exact start stream'),
 ('"limit_top": -0x0100','MTZ vertical-wrap top sentinel retained'),
 ('"limit_bottom": 0x0800','MTZ vertical-wrap bottom sentinel retained')]: ck(needle in mtzcat,msg)
nextf=func(cat,'next_level(zone: int, act: int) -> Vector2i')
ck('Vector2i(ZONE_S2_MTZ_TEST, 2) if act < 2 else Vector2i(ZONE_GHZ, 1)' in nextf,'MTZ1 progresses to MTZ2; MTZ2 safely falls back until MTZ3')
ck('KEY_G:' in main and '_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 1)' in main,'G remains MTZ1 direct warp')
ck('KEY_C:' in main and '_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 2)' in main,'C directly warps to MTZ2')
ck('Native Sonic 1 Phase 122' in main,'Debug overlay identifies Phase122')

# Phase119/120 assets and MTZ1 foundation remain hash-identical to their manifests.
p119=json.loads((P/'data/s1/s2test/phase119_mtz1_manifest.json').read_text())
for rel,dig in p119.get('sha256',{}).items():
    q=P/'data/s1/s2test'/rel; ck(q.is_file() and sha(q)==dig,f'Phase119 MTZ1 source foundation unchanged: {rel}')
p120=json.loads((P/'data/s1/s2test/phase120_mtz_objects_manifest.json').read_text())
for rel,dig in p120.get('sha256',{}).items():
    q=P/'assets/objects/s2_mtz'/rel; ck(q.is_file() and sha(q)==dig,f'Phase120 MTZ object art unchanged: {rel}')

# Retail-source byte validation when source tree is supplied.
if S2 is not None:
    imp=load('mtz122_import',P/'tools/import_s2_mtz2_phase122.py')
    terrain=load('mtz122_terrain',P/'tools/import_sonic2_level.py')
    raw_obj=(S2/'level/objects/MTZ_2.bin').read_bytes()
    raw_ring=(S2/'level/rings/MTZ_2.bin').read_bytes()
    raw_start=(S2/'startpos/MTZ_2.bin').read_bytes()
    ck((P/'data/s1/s2test/mtz2_objects.bin').read_bytes()==raw_obj,'Packaged MTZ2 object stream is byte-for-byte retail')
    ck((P/'data/s1/s2test/mtz2_rings.bin').read_bytes()==raw_ring,'Packaged MTZ2 ring stream is byte-for-byte retail')
    ck((P/'data/s1/s2test/mtz2_start.bin').read_bytes()==raw_start,'Packaged MTZ2 start position is byte-for-byte retail')
    layout=terrain.kosinski_decompress((S2/'level/layout/MTZ_2.bin').read_bytes())
    fg=bytearray(); bg=bytearray()
    for r in range(16):
        off=r*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    ck((P/'data/s1/s2test/mtz2_layout128.bin').read_bytes()==bytes((127,15))+bytes(fg),'MTZ2 foreground layout is exact decompressed retail half')
    ck((P/'data/s1/s2test/mtz2_bg128.bin').read_bytes()==bytes((127,15))+bytes(bg),'MTZ2 Plane-B layout is exact decompressed retail half')
    ck((P/'data/s1/s2test/mtz2_map128.bin').read_bytes()==terrain.kosinski_decompress((S2/'mappings/128x128/MTZ.bin').read_bytes()),'MTZ2 Map128 is exact retail decompression')
    col=terrain.kosinski_decompress((S2/'collision/MTZ primary 16x16 collision index.bin').read_bytes())
    ck((P/'data/s1/s2test/mtz2_collision_primary.bin').read_bytes()==col,'MTZ2 primary collision is exact retail decompression')
    rebuilt_map16,_=imp.build_map16(S2)
    ck((P/'data/s1/s2test/mtz2_map16.bin').read_bytes()==rebuilt_map16,'MTZ2 Map16 includes exact assembled APM_MTZ tail')
    misc=(S2/'misc/obj67.asm').read_text(errors='replace')
    for label in ['word_2740C','word_27426','word_27430','word_2744A','word_27454','word_2745E','word_27478','word_27492','word_274AC','word_274C6','word_274E0','word_274FA','word_27514']:
        ck(label in misc,f'Retail Obj67 source includes path table {label}')
    asm=(S2/'s2.asm').read_text(errors='replace')
    for needle,msg in [
      ('tst.b\trender_flags(a0)\n\tbpl.s\tBranchTo_JmpTo12_MarkObjGone','Retail Obj47 gates trigger handling on visibility'),
      ('btst\t#6,subtype(a0)','Retail Obj47 subtype bit6 selects trigger bit7'),
      ('move.b\t#4,mapping_frame(a0)\n\taddq.w\t#6,x_pos(a0)','Retail Shellcracker non-claw children become mapping frame4'),
      ('dc.b   0\t; 0\n\tdc.b   3\t; 1\n\tdc.b   5','Retail Shellcracker stagger table starts 0,3,5')]: ck(needle in asm,msg)

# Static sanity / Python tooling.
for rel in ['scripts/objects/s2_mtz_object.gd','scripts/objects/object_manager.gd','scripts/objects/genesis_level_object.gd','scripts/objects/s2_spikes_object.gd','scripts/data/level_catalog.gd','scripts/main.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')
for rel in ['tools/import_s2_mtz2_phase122.py','tools/validate_phase122.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
