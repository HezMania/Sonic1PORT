#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, sys, re
from PIL import Image

P=Path(__file__).resolve().parents[1]
SRC=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(name,cond,detail=''):
    ok=bool(cond); checks.append(ok); print(('PASS' if ok else 'FAIL')+': '+name+((' — '+str(detail)) if detail else ''))
def text(rel): return (P/rel).read_text(errors='replace')
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

htz=text('scripts/objects/s2_htz_object.gd')
cpz=text('scripts/objects/s2_cpz_traversal_object.gd')
spr=text('scripts/objects/s2_spring_object.gd')
mgr=text('scripts/objects/object_manager.gd')
pal=text('scripts/render/level_palette_cycler.gd')
slz=text('scripts/objects/slz_native_object.gd')
sign=text('scripts/objects/signpost_object.gd')

# Seesaw ownership/collision parity with the proven SLZ bridge.
ck('HTZ seesaw uses supported-slope ownership path','snap_supported_slope' in htz and 'supported_before' in htz)
ck('SLZ comparison path still uses supported-slope ownership','snap_supported_slope' in slz and 'See_Seesaw_StoodOn' in slz)
ck('HTZ seesaw uses source 49-sample table','const SEESAW_SLOPE' in htz and '0x14,0x14,0x16,0x18' in htz and '-14,-14,-14,-14,-14' in htz)
ck('HTZ seesaw flat frame is 5 pixels','var height: int = 5 if seesaw_tilt == 1' in htz)
ck('HTZ seesaw samples once per two pixels','local_x >> 1' in htz)
ck('HTZ seesaw mirrors right tilt','index = 48 - index' in htz)
ck('HTZ seesaw launch immediately syncs native transform','p._sync_position()' in htz[htz.find('func _tick_seesaw_ball_flight'):htz.find('# -----------------------------------------------------------------------------\n# Object $16')])
ck('HTZ seesaw keeps source launch strengths',all(x in htz for x in ['-0x818','-0xAF0','-0xE00']))

# Lift rendering and falling split.
ck('Obj16 left-going mapping uses baked mirrored source folder','lift_flipped' in htz and 'if x_flip else "s2_htz/lift"' in htz)
ck('Obj16 runtime sprite flip is neutral after choosing authored mapping','sprite.flip_h = false' in htz[htz.find('func _init_lift'):htz.find('func _spawn_lift_rope_remnant')])
ck('Obj16 stripped falling frame uses same direction-specific mapping','_set_lift_frame(2)' in htz)
ck('Obj16 rope remnant uses direction-specific mapping','lift_rope_remnant.texture = load("res://assets/objects/%s/01.png" % lift_folder)' in htz)
ck('Obj16 remains front priority','z_index = 55' in htz)
ck('Obj16 falling platform retains support','PlatformObject remains active during Obj16_Fall' in htz and 'move_with_supported_object' in htz)

# Rexon exact chained oscillator.
ck('Rexon models five linked Obj97 children','for i in range(5)' in htz and 'rexon_links.size() != 5' in htz)
ck('Rexon source stagger wait table', 'REXON_WAIT: Array[int] = [0x1E, 0x18, 0x12, 0x0C, 0x06]' in htz)
ck('Rexon source complementary raise table','REXON_RAISE: Array[int] = [0x06, 0x0C, 0x12, 0x18, 0x1E]' in htz)
ck('Rexon source phase starts retained','REXON_NORMAL_PHASE: Array[int] = [0x24, 0x20, 0x1C, 0x1A' in htz)
ck('Rexon uses exact 32-pair oscillator table','const REXON_OSC: Array[Vector2i]' in htz and htz.count('Vector2i(1,-15)')>=2)
ck('Rexon oscillator reverses at $18/$28','phase <= 0x18 or phase >= 0x28' in htz)
ck('Rexon writes next child through chain','func _rexon_place_next_link' in htz and 'i + 1' in htz)
ck('Rexon preserves child subpixels during integer link writes','rexon_link_fixed_x[i + 1] & 0xFF' in htz and 'rexon_link_fixed_y[i + 1] & 0xFF' in htz)
ck('Rexon base remains solid after head death','resolve_solid_box_contact(spawn_x, spawn_y, 0x10, 8' in htz and 'rexon_head_destroyed = true' in htz)

# HTZ rock debris.
ck('HTZ Obj32 has six exact source velocities','HTZ_ROCK_FRAGMENT_VELOCITY' in cpz and cpz.count('Vector2(')>=6)
ck('HTZ Obj32 spawns six mapping-piece fragments','for i in range(6)' in cpz and 's2_htz/rock_fragment/%02d.png' in cpz)
ck('HTZ Obj32 uses $18 fragment gravity','v.y += 0.09375' in cpz)
ck('HTZ Obj32 keeps fragment owner alive after break','htz_rock_broken = true' in cpz and '_tick_htz_rock_debris()' in cpz)

# Spring fresh-collision envelope.
ck('Obj41 up fresh half-height is retail d2=$08','resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x08' in spr)
ck('Obj41 horizontal fresh half-height is retail d2=$0E','resolve_solid_box_contact(spawn_x, spawn_y, 0x0A, 0x0E' in spr)
ck('Obj41 down fresh half-height is retail d2=$08',spr.count('resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x08')>=2)
ck('Old buried-spring symmetric $10 fresh envelope removed','0x12, 0x10, true, record_index' not in spr)

# Rising lava exact Plane-B art/palette sync.
ck('Object manager exposes HTZ lava cycle frame','var htz_lava_palette_frame: int = 0' in mgr)
ck('Palette cycler mirrors applied HTZ frame to object manager','manager.htz_lava_palette_frame = frame' in pal)
ck('Quake lava switches source-rendered frame with palette cycle','set_sprite_frame(sprite, "s2_htz/quake_lava", manager.htz_lava_palette_frame & 0x0F)' in htz)
ck('Quake lava remains tied to earthquake Y offset','position.y = orig_y + manager.htz_bg_y_offset' in htz)

manifest_path=P/'data/s1/s2test/phase108_htz_fidelity_art_manifest.json'
ck('Phase108 art manifest exists',manifest_path.is_file())
manifest=json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
ck('Phase108 art manifest identifies phase 108',manifest.get('phase')==108)
ck('Phase108 has five mirrored lift mapping frames',manifest.get('lift_flipped_frames')==5,manifest.get('lift_flipped_frames'))
ck('Phase108 has six HTZ rock fragments',manifest.get('rock_fragments')==6,manifest.get('rock_fragments'))
ck('Phase108 has sixteen quake lava palette states',manifest.get('quake_lava_frames')==16,manifest.get('quake_lava_frames'))
ck('Phase108 quake lava fills full $F0 height',manifest.get('quake_lava_size')==[384,240],manifest.get('quake_lava_size'))
for rel,want in manifest.get('files',{}).items():
    path=P/rel
    ck('Generated art exists '+rel,path.is_file() and path.stat().st_size>50)
    if path.is_file(): ck('Generated art hash matches '+rel,sha(path)==want)
for i in range(16):
    im=Image.open(P/f'assets/objects/s2_htz/quake_lava/{i:02d}.png')
    ck(f'quake lava frame {i:02d} is 384x240',im.size==(384,240),im.size)
for i in range(6):
    im=Image.open(P/f'assets/objects/s2_htz/rock_fragment/{i:02d}.png')
    ck(f'rock fragment {i:02d} is source mapping canvas',im.size==(192,192),im.size)
    ck(f'rock fragment {i:02d} is nonblank',im.getbbox() is not None)

# Authoritative stream/regression invariants.
obj=(P/'data/s1/s2test/htz1_objects.bin').read_bytes(); records=[]
for o in range(0,len(obj),6):
    x=int.from_bytes(obj[o:o+2],'big'); yw=int.from_bytes(obj[o+2:o+4],'big'); records.append((x,yw&0xFFF,bool(yw&0x2000),obj[o+4],obj[o+5]))
counts=Counter(r[3] for r in records)
ck('HTZ1 remains 144 retail placements',len(records)==144,len(records))
ck('HTZ1 keeps four diagonal lifts',counts[0x16]==4,counts[0x16])
ck('HTZ1 includes one X-flipped left lift',sum(1 for r in records if r[3]==0x16 and r[2])==1)
ck('HTZ1 keeps both Rexons',counts[0x96]==2,counts[0x96])
ck('HTZ1 signpost remains retail $2900',any(x==0x2900 and oid==0x0D for x,y,xf,oid,st in records))
ck('S2 signpost still uses camera-bound finish threshold','runtime_limit_right + 0x128' in sign)

if SRC:
    asm=(SRC/'s2.asm').read_text(errors='replace')
    ck('Retail Obj14 uses source slope table label','byte_21C8E:' in asm)
    ck('Retail Obj14 uses SlopePlatform d3=8','moveq\t#8,d3' in asm[asm.find('Obj14_UpdateMappingAndCollision:'):asm.find('return_21A74:')])
    ck('Retail Obj16 preserves render flags on spawned remnant','move.b\trender_flags(a0),render_flags(a1)' in asm[asm.find('Obj16_Slide:'):asm.find('Obj16_Fall:')])
    ck('Retail Rexon has five-child create loop','moveq\t#4,d6' in asm[asm.find('Obj94_CreateHead:'):asm.find('Obj97_Oscillate:')])
    ck('Retail Rexon wait bytes present','dc.b $1E' in asm[asm.find('byte_3744E:'):asm.find('Obj97_InitialWait:')])
    ck('Retail Rexon exact oscillator table present','byte_376A8:' in asm and 'dc.b $F,$FF' in asm[asm.find('byte_376A8:'):asm.find('Object 98')])
    ck('Retail Obj32 six HTZ velocity pairs present','Obj32_VelArray1:' in asm and 'dc.w  $1C0,-$1C0' in asm[asm.find('Obj32_VelArray1:'):asm.find('Obj32_VelArray2:')])
    ck('Retail Obj41 up d2 is 8','Obj41_Up:' in asm and 'move.w\t#8,d2' in asm[asm.find('Obj41_Up:'):asm.find('Obj41_Horizontal:')])
    ck('Retail Obj41 horizontal d2 is $E','move.w\t#$E,d2' in asm[asm.find('Obj41_Horizontal:'):asm.find('Obj41_Down:')])
    ck('HTZ object stream remains byte-identical to retail',obj==(SRC/'level/objects/HTZ_1.bin').read_bytes())

# Python generation tools themselves compile.
import py_compile
for rel in ['tools/import_s2_htz_fidelity_phase108.py','tools/validate_phase108.py']:
    try:
        py_compile.compile(str(P/rel),doraise=True); good=True
    except Exception as e:
        good=False; detail=e
    ck(rel+' compiles',good,'' if good else detail)

print(f'\n{sum(checks)}/{len(checks)} checks passed')
raise SystemExit(0 if all(checks) else 1)
