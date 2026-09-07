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
    if token not in t: return ''
    a=t.index(token); b=t.find('\nfunc ',a+1); return t[a:len(t) if b<0 else b]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod

M=json.loads((P/'data/s1/s2test/phase119_mtz1_manifest.json').read_text())
cat=txt('scripts/data/level_catalog.gd'); main=txt('scripts/main.gd'); audio=txt('scripts/audio/sonic_audio.gd')
om=txt('scripts/objects/object_manager.gd'); oo=txt('scripts/objects/s2_ooz_object.gd'); proj=txt('scripts/objects/s2_ooz_projectile.gd')
fg=txt('scripts/render/ghz_renderer.gd'); bg=txt('scripts/render/ghz_background_renderer.gd')
pal=txt('scripts/render/level_palette_cycler.gd'); art=txt('scripts/render/level_art_animator.gd')

# Manifest and imported files.
ck(M.get('phase')==119,'Manifest identifies Phase 119')
ck(M.get('level')=='Metropolis Zone Act 1','Manifest identifies retail Metropolis Zone Act 1')
ck(M.get('start')==[0x60,0x28C],'Retail MTZ1 start is $0060,$028C')
ck(M.get('limits')=={'left':0,'right':0x2280,'top':-0x100,'bottom':0x800},'Retail MTZ1 level limits recorded exactly')
ck(M.get('layout')==[128,16],'MTZ1 layout is 128x16 chunks')
ck(M.get('background_scroll')=={'x_divisor':8,'y_divisor':4},'MTZ1 Plane-B camera ratios are 1/8 X and 1/4 Y')
ck(M.get('objects')==193,'All 193 MTZ1 object records retained')
ck(M.get('rings')==104,'All 104 MTZ1 ring records retained')
ck(M.get('active_shared_records')==27,'27 already-compatible shared object placements active')
ck(M.get('deferred_mtz_specific_records')==166,'166 MTZ-specific placements preserved for object completion')
ck(M.get('map16',{}).get('base_bytes')==0x12C0,'MTZ base 16x16 mapping decompresses to $12C0 bytes')
ck(M.get('map16',{}).get('apm_offset')==0x1730,'APM_MTZ runtime patch begins at $1730')
ck(M.get('map16',{}).get('apm_bytes')==0xD0,'APM_MTZ runtime patch is $D0 bytes')
ck(M.get('map128_bytes')==0x8000,'MTZ 128x128 mapping bank is $8000 bytes')
ck(M.get('collision_bytes')==0x300,'MTZ collision index is $300 bytes')
ck(M.get('art',{}).get('main_bytes')==0x6300 and M.get('art',{}).get('main_tiles')==792,'Main MTZ art is $6300 bytes / 792 tiles')
pc=M.get('palette_cycles',{})
ck(pc=={'cycle1_frames':6,'cycle1_period':18,'cycle2_frames':3,'cycle2_period':3,'cycle3_frames':10,'cycle3_period':10},'Manifest records all three retail MTZ palette-cycle periods')
music=M.get('music',{})
ck(music.get('id')==0x19D and music.get('tempo')==234,'Native MTZ music is port-local $19D with retail tempo 234')
for rel,dig in M.get('sha256',{}).items():
    p=P/'data/s1/s2test'/rel
    ck(p.is_file() and sha(p)==dig,f'Imported output hash stable: {rel}')
for rel,size in [
 ('data/s1/s2test/mtz1_art.bin',0x10000),('data/s1/s2test/mtz1_map16.bin',0x1800),
 ('data/s1/s2test/mtz1_map128.bin',0x8000),('data/s1/s2test/mtz1_layout128.bin',2+128*16),
 ('data/s1/s2test/mtz1_bg128.bin',2+128*16),('data/s1/s2test/mtz1_collision_primary.bin',0x300),
 ('data/s1/s2test/mtz1_collision_secondary.bin',0x300),('data/s1/s2test/mtz1_objects.bin',193*6),
 ('data/s1/s2test/mtz1_rings.bin',628),('data/s1/s2test/mtz1_start.bin',4),
 ('data/s1/s2test/mtz_cylinder.bin',0x1000),('data/s1/s2test/mtz_lava.bin',0x600),('data/s1/s2test/mtz_anim_back.bin',0x240),
 ('data/s1/palette/S2 Metropolis Zone.bin',0x60),('data/s1/palette/S2 MTZ Cycle 1.bin',12),
 ('data/s1/palette/S2 MTZ Cycle 2.bin',12),('data/s1/palette/S2 MTZ Cycle 3.bin',20),
]:
    p=P/rel; ck(p.is_file() and p.stat().st_size==size,f'{rel} has expected size {size:#x}')

# Object counts / namespace safety.
raw=(P/'data/s1/s2test/mtz1_objects.bin').read_bytes(); counts=Counter(raw[i+4] for i in range(0,len(raw),6))
expected={'06':5,'0D':1,'1C':1,'26':10,'2D':3,'36':7,'41':4,'42':4,'47':9,'64':2,'65':32,'66':30,'67':3,'68':9,'69':9,'6B':6,'6D':8,'74':11,'79':5,'9F':3,'A1':4,'A4':27}
ck({f'{k:02X}':v for k,v in sorted(counts.items())}==expected,'MTZ1 object-ID histogram matches retail placement stream')
block=func(om,'_make_object_for_id(id: int) -> GenesisLevelObject')
for oid in ['0x06','0x1C','0x2D','0x42','0x47','0x64','0x65','0x66','0x67','0x68','0x69','0x6B','0x6D','0x74','0x9F','0xA1','0xA4']:
    ck(oid in block,f'MTZ namespace blocker contains {oid}')
ck('bool(level_definition.get("s2_mtz", false))' in block and 'S2UnsupportedObjectClass.new()' in block,'MTZ-specific IDs cannot alias older zone object adapters')
for oid in ['0x0D','0x26','0x36','0x41','0x79']:
    ck(oid in block,f'Shared MTZ object ID {oid} remains routed to an active adapter')

# Level catalog, routing, hotkey, audio.
ck('const ZONE_S2_MTZ_TEST := 15' in cat,'Metropolis has dedicated Sonic 2 zone namespace')
mtz=func(cat,'_get_sonic2_mtz_test(requested_act: int = 1) -> Dictionary')
for needle,msg in [
 ('"layout": "s2test/mtz1_layout128.bin"','MTZ1 foreground layout wired'),
 ('"background_layout": "s2test/mtz1_bg128.bin"','MTZ1 Plane-B layout wired'),
 ('"s2_objects": "s2test/mtz1_objects.bin"','MTZ1 object stream wired'),
 ('"s2_rings": "s2test/mtz1_rings.bin"','MTZ1 ring stream wired'),
 ('"start": "s2test/mtz1_start.bin"','MTZ1 start stream wired'),
 ('"map16": "s2test/mtz1_map16.bin"','Patched MTZ Map16 wired'),
 ('"chunk_map": "s2test/mtz1_map128.bin"','MTZ Map128 wired'),
 ('"collision": "s2test/mtz1_collision_primary.bin"','MTZ primary collision wired'),
 ('"collision_secondary": "s2test/mtz1_collision_secondary.bin"','MTZ secondary collision wired'),
 ('"palette": "palette/S2 Metropolis Zone.bin"','MTZ palette wired'),
 ('"limit_right": 0x2280','MTZ1 right boundary $2280'),('"limit_top": -0x0100','MTZ1 top boundary -$100'),
 ('"limit_bottom": 0x0800','MTZ1 bottom boundary $800'),('"background_mode": "s2mtz"','MTZ source background mode selected'),
 ('"dynamic_events": "none"','MTZ1 correctly has no DLE'),('"s2_mtz": true','MTZ namespace flag enabled'),
 ('"music_mode": "s2_mtz"','MTZ music mode enabled')]: ck(needle in mtz,msg)
nextf=func(cat,'next_level(zone: int, act: int) -> Vector2i')
ck('ZONE_S2_OOZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_MTZ_TEST, 1)' in nextf,'OOZ1 -> OOZ2 -> MTZ1 progression is wired')
ck('if zone == ZONE_S2_MTZ_TEST:' in nextf and 'return Vector2i(ZONE_GHZ, 1)' in nextf,'MTZ1 uses safe fallback until MTZ2 import')
ck('KEY_G:' in main and '_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 1)' in main,'G hotkey warps directly to MTZ1')
ck('const MUS_S2_MTZ := 0x19D' in audio,'Audio constant reserves MTZ at $19D')
play=func(main,'_play_level_music(zone: int, act: int, keep_credits: bool = false) -> void')
ck('ZONE_S2_MTZ_TEST' in play and 'MUS_S2_MTZ' in play,'Level loader starts Metropolis music')
ck('current_zone == LevelCatalog.ZONE_S2_MTZ_TEST' in main[main.index('MUS_S2_END_LEVEL'):main.index('MUS_S2_END_LEVEL')+900],'MTZ act completion uses Sonic 2 end-level music')

# Palette-indexed terrain + exact MTZ palette streams.
ck('LevelCatalog.ZONE_S2_MTZ_TEST' in fg,'MTZ foreground uses palette-indexed renderer')
pt=func(pal,'_tick_s2_mtz() -> Array[int]')
for needle,msg in [
 ('pcyc_time = 0x11','MTZ palette stream 1 reloads $11 (18 VBlanks)'),('_write_single(level.palette, 37','MTZ stream 1 targets CRAM index 37'),
 ('s2_mtz_timer2 = 2','MTZ palette stream 2 reloads 2 (3 VBlanks)'),('_write_run(level.palette, 33','MTZ stream 2 targets CRAM indices 33..35'),
 ('s2_mtz_timer3 = 9','MTZ palette stream 3 reloads 9 (10 VBlanks)'),('_write_single(level.palette, 47','MTZ stream 3 targets CRAM index 47')]: ck(needle in pt,msg)
loadpal=func(pal,'_load_cycle_data() -> void')
for name in ['S2 MTZ Cycle 1.bin','S2 MTZ Cycle 2.bin','S2 MTZ Cycle 3.bin']:
    ck(name in loadpal,f'Palette cycler loads {name}')

# Dynamic_Normal art.
for needle,msg in [
 ('S2_MTZ_LAVA_TILE = 0x340','MTZ lava destination tile $340'),('S2_MTZ_CYLINDER_TILE = 0x34C','MTZ cylinder destination tile $34C'),
 ('S2_MTZ_BACK1_TILE = 0x35C','MTZ background animation slot 1 tile $35C'),('S2_MTZ_BACK2_TILE = 0x362','MTZ background animation slot 2 tile $362'),
 ('[0x00,0x10,0x20,0x30,0x40,0x50,0x60,0x70]','MTZ cylinder uses exact eight source tile offsets'),
 ('[0x00,0x0C,0x18,0x24,0x18,0x0C]','MTZ lava uses exact six-frame source sequence')]: ck(needle in art,msg)
at=func(art,'_tick_s2_mtz() -> void')
ck('s2_mtz_times[0] = 0' in at and '0x10' in at,'MTZ cylinder advances 16 tiles every VBlank')
ck('s2_mtz_times[1] = 0x0D' in at and '0x0C' in at,'MTZ lava uses source duration $0D and 12-tile DMA')
ck('_tick_s2_mtz_per_frame_slot(2, S2_MTZ_BACK1_TILE' in at and '_tick_s2_mtz_per_frame_slot(3, S2_MTZ_BACK2_TILE' in at,'Both MTZ background animation scripts run')

# Source-shaped Plane B.
setupbg=func(bg,'_setup_s2test() -> void')
ck('elif mode == "s2mtz"' in setupbg and '9 * 128' in setupbg and '4 * 128' in setupbg,'MTZ Plane-B cache uses exact 9x4 authored repeat')
bgt=func(bg,'_update_s2mtz(camera_model: SonicCamera) -> void')
ck('int(camera_model.screen_x) >> 3' in bgt,'MTZ Plane B tracks camera X at 1/8')
ck('int(camera_model.screen_y) >> 2' in bgt,'MTZ Plane B tracks camera Y at 1/4')
ck('strip.region_rect = Rect2' in bgt and 'viewport_width, viewport_height' in bgt,'MTZ background uses one uniform full-screen scroll region')
ck('as Sprite2D' in bgt,'MTZ background strip is explicitly cast for Godot typing')
# Validate the repeat itself from imported bytes (first 126 authored columns; last two are guards).
bgb=(P/'data/s1/s2test/mtz1_bg128.bin').read_bytes()[2:]
rows=[bgb[r*128:(r+1)*128] for r in range(16)]
ck(all(rows[r][:126]==(rows[r][:9]*14) for r in range(16)),'MTZ1 Plane-B first 126 columns repeat every 9 chunks')
ck(all(rows[r]==rows[r%4] for r in range(16)),'MTZ1 Plane-B rows repeat every 4 chunk rows')

# Six carried-forward OOZ runtime corrections.
aqinit=func(oo,'_init_aquis() -> void')
ck('aquis_wing.z_as_relative = false' in aqinit and 'aquis_wing.z_index = 60' in aqinit,'Aquis fin is forced to an absolute layer above its body')
spawnproj=func(om,'spawn_s2_ooz_projectile(x: int, y: int, folder: String, frames: Array[int], frame_delay: int, horizontal_velocity: int, vertical_velocity: int, startup_delay: int = 0, face_left: bool = false) -> void')
ck('folder == "octus"' in spawnproj and 'projectile.z_as_relative = false' in spawnproj and 'projectile.z_index = 30' in spawnproj,'Octus projectile uses absolute behind-parent layer')
vfan=func(oo,'_apply_vertical_fan(p: SonicPlayer) -> void')
ck('manager.s2_source_osc_byte(0x14)' in vfan,'Vertical fan still uses retail Oscillating_Data+$14')
ck('var fan_delta_fixed: int = -d1 << 12' in vfan and 'p.fixed_y += fan_delta_fixed' in vfan,'Vertical fan preserves discarded /16 bits in 16.16 gameplay position')
ck('p.position = Vector2(float(p.pixel_x()), float(p.pixel_y()))' in vfan,'Vertical fan presents whole-pixel Genesis sprite position to avoid fractional shimmer')
launch=func(oo,'_tick_launcher() -> void')
ck('rolling_top_overlap' in launch and 'orig_y-0x28' in launch and 'p.pixel_y() <= orig_y' in launch,'OOZ giant launcher has robust downward rolling top-contact recovery window')
cap=func(oo,'_capture_launcher(p: SonicPlayer) -> void')
ck('p.vel_x = 0' in cap and 'p.vel_y = -0x800' in cap,'Subtype-$01 launcher still uses exact upward 0/-$800 vector')
spinit=func(oo,'_init_sliding_spike() -> void')
ck('sprite.z_as_relative = false' in spinit and 'sprite.z_index = 120' in spinit and 'sliding_spike_partner.z_index = 120' in spinit,'Sliding spike heads force absolute Z above high-priority foreground')
sptick=func(oo,'_tick_sliding_spike() -> void')
ck('sliding_spike_x[1] - 0x18 <= sliding_spike_x[0] + 0x18' in sptick,'Paired sliding spikes catch the source $30 center-separation crossing')
ck('sliding_spike_dir[0] = -1' in sptick and 'sliding_spike_dir[1] = 1' in sptick,'Paired sliding spikes reverse apart together at contact')

# Native music entry exists and is structurally present.
db=json.loads((P/'data/s1/sound/s2_ehz_smps.json').read_text())
song=db.get('music',{}).get(str(0x19D),{})
ck(song.get('id')==0x19D and song.get('name')=='Sonic 2 - Metropolis Zone','MTZ song entry packaged in SMPS database')
ck(song.get('header',{}).get('tempo_mod')==234,'MTZ SMPS header retains retail tempo')

# Byte/source equivalence when retail source root supplied.
if S2 is not None:
    terrain=load('terrain_validate119',P/'tools/import_sonic2_level.py')
    ck((P/'data/s1/s2test/mtz1_start.bin').read_bytes()==(S2/'startpos/MTZ_1.bin').read_bytes(),'MTZ1 start bytes are retail-identical')
    ck((P/'data/s1/s2test/mtz1_objects.bin').read_bytes()==(S2/'level/objects/MTZ_1.bin').read_bytes(),'MTZ1 object stream is retail-identical')
    ck((P/'data/s1/s2test/mtz1_rings.bin').read_bytes()==(S2/'level/rings/MTZ_1.bin').read_bytes(),'MTZ1 ring stream is retail-identical')
    map128=terrain.kosinski_decompress((S2/'mappings/128x128/MTZ.bin').read_bytes())
    ck((P/'data/s1/s2test/mtz1_map128.bin').read_bytes()==map128,'MTZ Map128 is exact retail decompression')
    col=terrain.kosinski_decompress((S2/'collision/MTZ primary 16x16 collision index.bin').read_bytes())
    ck((P/'data/s1/s2test/mtz1_collision_primary.bin').read_bytes()==col and (P/'data/s1/s2test/mtz1_collision_secondary.bin').read_bytes()==col,'Both MTZ collision paths use exact retail MTZ primary index')
    layout=terrain.kosinski_decompress((S2/'level/layout/MTZ_1.bin').read_bytes())
    f=bytearray(); b=bytearray()
    for row in range(16):
        o=row*0x100; f+=layout[o:o+0x80]; b+=layout[o+0x80:o+0x100]
    ck((P/'data/s1/s2test/mtz1_layout128.bin').read_bytes()==bytes((127,15))+bytes(f),'MTZ foreground layout split is exact')
    ck((P/'data/s1/s2test/mtz1_bg128.bin').read_bytes()==bytes((127,15))+bytes(b),'MTZ Plane-B layout split is exact')
    for out,src in [('S2 Metropolis Zone.bin','MTZ.bin'),('S2 MTZ Cycle 1.bin','MTZ Cycle 1.bin'),('S2 MTZ Cycle 2.bin','MTZ Cycle 2.bin'),('S2 MTZ Cycle 3.bin','MTZ Cycle 3.bin')]:
        ck((P/'data/s1/palette'/out).read_bytes()==(S2/'art/palettes'/src).read_bytes(),f'{out} is byte-identical to retail palette source')
    asm=(S2/'s2.asm').read_text(errors='replace')
    for needle,msg in [
      ('LevEvents_MTZ:\n\trts','Retail LevEvents_MTZ is an RTS for Act 1/2'),
      ('move.b\t(Oscillating_Data+$14).w,d1','Retail OOZ vertical fan uses oscillator byte +$14'),
      ('cmp.w\td0,d2','Retail sliding-spike pair compares its two $18-offset edges'),
      ('eori.b\t#1,objoff_36(a0)','Retail sliding spike reverses first head at contact'),
      ('eori.b\t#1,objoff_36(a1)','Retail sliding spike reverses partner at contact'),
      ('move.w\t#-$800,y_vel(a1)','Retail subtype launcher uses -$800 Y velocity')]: ck(needle in asm,msg)

# Tooling/docs / basic static syntax guards.
for rel in ['tools/import_s2_mtz1_phase119.py','tools/validate_phase119.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')
for rel in ['scripts/data/level_catalog.gd','scripts/main.gd','scripts/audio/sonic_audio.gd','scripts/objects/object_manager.gd','scripts/objects/s2_ooz_object.gd','scripts/objects/s2_ooz_projectile.gd','scripts/render/ghz_renderer.gd','scripts/render/ghz_background_renderer.gd','scripts/render/level_palette_cycler.gd','scripts/render/level_art_animator.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')
ck((P/'PHASE119_SONIC2_METROPOLIS_ACT1.md').is_file(),'Phase 119 implementation report packaged')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
