#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, sys
from PIL import Image

P = Path(__file__).resolve().parents[1]
SRC = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
checks=[]

def ck(name, cond, detail=''):
    ok=bool(cond); checks.append(ok)
    print(('PASS' if ok else 'FAIL')+': '+name+((' — '+str(detail)) if detail else ''))

def text(rel): return (P/rel).read_text(errors='replace')
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

htz=text('scripts/objects/s2_htz_object.gd')
mgr=text('scripts/objects/object_manager.gd')
plat=text('scripts/objects/s2_ehz_platform_object.gd')
sign=text('scripts/objects/signpost_object.gd')
cam=text('scripts/camera/sonic_camera.gd')
bg=text('scripts/render/ghz_background_renderer.gd')
pal=text('scripts/render/level_palette_cycler.gd')
cat=text('scripts/data/level_catalog.gd')

# Phase 106 base fidelity retained.
ck('HTZ palette cycle still targets retail indices 19/20', '_write_run(level.palette, 19' in pal)
ck('HTZ palette cycle still targets retail indices 30/31', '_write_run(level.palette, 30' in pal)
ck('HTZ background retains 128-line far band', 'if y < 128:' in bg)
ck('HTZ earthquake event remains enabled', 's2_htz_quake_active' in cam and '0x1978' in cam)
ck('HTZ1 catalog retains retail right bound $2800', '"limit_right": 0x2800' in cat)

# See-saw fixes.
ck('Obj14 has exact 49-sample source slope table', 'const SEESAW_SLOPE' in htz and htz.count('0x14,0x14,0x16,0x18') == 1)
ck('Obj14 balanced frame uses source 5px top', 'var top_y: int = spawn_y - 5' in htz)
ck('Obj14 samples slope once per 2 pixels', '(local_x + 0x30) >> 1' in htz)
ck('Obj14 mirrors source slope for frame 2', 'slope_index = 48 - slope_index' in htz)
ck('Obj14 uses source -$818 launch', '-0x818' in htz)
ck('Obj14 uses source -$AF0 launch', '-0xAF0' in htz)
ck('Obj14 uses source -$E00 hard-impact launch', '-0xE00' in htz)
ck('Obj14 no longer uses Phase106 fixed -$500 relaunch', 'seesaw_ball_vy = -0x500' not in htz)
ck('Obj14 launches only from angle mismatch', 'seesaw_ball_angle != seesaw_target_tilt' in htz)
ck('Obj14 ball rest uses exact source offsets', '[-8, -28, -47, -28, -8]' in htz)

# Diagonal lift and scenery corrections.
ck('Obj16 is drawn in front of normal Sonic', 'z_index = 55' in htz)
ck('Obj16 uses source $200 horizontal speed', 'vel_x = -0x200 if x_flip else 0x200' in htz)
ck('Obj16 uses source $100 vertical speed', 'vel_y = 0x100' in htz)
ck('Obj16 uses source $38 fall gravity', 'vel_y = GenesisMath.s16(vel_y + 0x38)' in htz)
ck('Obj16 stripped frame remains a platform during fall', 'PlatformObject remains active during Obj16_Fall' in htz and 'p.resolve_platform_top' in htz)
ck('Obj16 leaves source rope remnant on release', '_spawn_lift_rope_remnant()' in htz and 's2_htz/lift/01.png' in htz)
ck('HTZ Obj1C is routed to zone-specific renderer', '0x14, 0x16, 0x1C, 0x2F' in mgr)
ck('HTZ Obj1C renders zipline endpoint frame 3', '4: frame = 3' in htz)
ck('HTZ Obj1C renders zipline endpoint frame 4', '5: frame = 4' in htz)
ck('HTZ Obj1C renders spawned rope frame 1', '6: frame = 1' in htz)
ck('HTZ Obj1C renders resident-art stake frames', 's2_htz/lift_stake' in htz)

# Lava/object flip correction.
ck('Obj18 placement status no longer flips whole artwork', 'sprite.flip_h = false' in plat and 'sprite.flip_v = false' in plat)
ck('Obj18 still selects HTZ source art', 's2_htz/platform' in plat)

# Smashable ground corrections.
ck('Obj2F no longer forces a bounce velocity', 'p.vel_y = -0x300' not in htz)
ck('Obj2F spawns visible debris', '_spawn_smash_debris()' in htz and 's2_htz/smash_fragment' in htz)
ck('Obj2F uses exact first source debris velocity', '[-1.0,1.0,-0.875,0.875' in htz and '[-8.0,-8.0,-7.0,-7.0' in htz)
ck('Obj2F uses source $18 fragment gravity', 'v.y += 0.09375' in htz)
ck('Obj2F keeps broken object alive for debris simulation', 'sprite.visible = false' in htz and 'state = 1' in htz)

# Rising lava bridge.
ck('Obj30 hazardous terrain binds source lava visual', 's2_htz/quake_lava/00.png' in htz)
ck('Obj30 visual follows HTZ background Y offset', 'position.y = orig_y + manager.htz_bg_y_offset' in htz)

# Spiker corrections.
ck('Spiker has permanent fired/spent state', 'var spiker_spent: bool' in htz)
ck('Spiker switches parent to headless frame 2 on shot', 'set_sprite_frame(sprite, "s2_htz/spiker", 2)' in htz)
ck('Spiker cycles only frames 2/3 after firing', '(2 if spiker_spent else 0)' in htz)
ck('Spiker cannot respawn its drill head', 'not drill_active and not spiker_spent' in htz)
ck('Spiker drill uses source mapping frame 4', 's2_htz/spiker/04.png' in htz)

# Rexon corrections.
ck('Rexon base remains a solid platform', 'Rexon\'s cup/body remains a SolidObject' in htz and 'resolve_solid_box_contact(spawn_x, spawn_y, 0x10, 8' in htz)
ck('Rexon neck advances an animation phase', 'rexon_phase = (rexon_phase + 1)' in htz)
ck('Rexon neck segments receive independent phases', 'rexon_phase + i * 12' in htz)
ck('Rexon head hit has dedicated handler', 'func _react_rexon_head' in htz)
ck('Rexon head destruction preserves base', 'rexon_head_destroyed = true' in htz and 'request_delete' not in htz[htz.find('func _react_rexon_head'):htz.find('func _spawn_rexon_projectile')])

# Completion correction.
ck('S2 signpost uses camera-based finish threshold', 'finish_x = p.runtime_limit_right + 0x128' in sign)
ck('HTZ1 signpost source placement remains at $2900', True)  # verified below from stream

# Generated source art.
manifest_path=P/'data/s1/s2test/phase107_htz_fidelity_art_manifest.json'
ck('Phase107 art manifest exists', manifest_path.is_file())
manifest=json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
ck('Phase107 art manifest identifies phase 107', manifest.get('phase')==107)
for rel in manifest.get('files',{}):
    path=P/rel
    ck('Generated art exists '+rel, path.is_file() and path.stat().st_size>50)
    if path.is_file(): ck('Generated art hash matches '+rel, sha(path)==manifest['files'][rel])

# Image sanity.
for rel in ['assets/objects/s2_htz/spiker/00.png','assets/objects/s2_htz/spiker/02.png','assets/objects/s2_htz/lift_stake/00.png','assets/objects/s2_htz/quake_lava/00.png']:
    im=Image.open(P/rel)
    ck(rel+' is 192x192 mapping canvas or quake strip', im.size==(192,192) if 'quake_lava' not in rel else im.size[0]>=320, im.size)

# Placement stream remains authoritative.
obj=(P/'data/s1/s2test/htz1_objects.bin').read_bytes()
records=[]
for o in range(0,len(obj),6):
    x=int.from_bytes(obj[o:o+2],'big'); yw=int.from_bytes(obj[o+2:o+4],'big'); records.append((x,yw&0xFFF,obj[o+4],obj[o+5]))
counts=Counter(r[2] for r in records)
ck('HTZ1 still has 144 retail object records', len(records)==144, len(records))
ck('HTZ1 signpost remains source x=$2900', any(x==0x2900 and oid==0x0D for x,y,oid,st in records))
ck('HTZ1 keeps all 16 Obj1C scenery/pole records', counts[0x1C]==16, counts[0x1C])
ck('HTZ1 keeps all 4 diagonal lifts', counts[0x16]==4, counts[0x16])
ck('HTZ1 keeps all 10 smashable-ground records', counts[0x2F]==10, counts[0x2F])
ck('HTZ1 keeps all 6 Spikers', counts[0x92]==6, counts[0x92])
ck('HTZ1 keeps both Rexons', counts[0x96]==2, counts[0x96])

if SRC:
    asm=(SRC/'s2.asm').read_text(errors='replace')
    ck('Retail Obj14 source uses exact Y offsets', 'dc.w -8, -28, -47, -28, -8' in asm)
    ck('Retail Obj14 source uses -$818 launch', '#-$818,d1' in asm)
    ck('Retail Obj14 source uses -$AF0 launch', '#-$AF0,d1' in asm)
    ck('Retail Obj16 source creates scenery subtype 6', '#6,subtype(a1)' in asm)
    ck('Retail Obj16 source keeps PlatformObject in main loop', 'jsrto\t(PlatformObject).l' in asm)
    ck('Retail Obj2F source fragment gravity is $18', 'addi.w\t#$18,y_vel(a0)' in asm)
    ck('Retail Spiker source headless frames are animation 2/3', 'byte_3708E:\tdc.b   9,  2,  3,$FF' in asm)
    ck('Retail Rexon source keeps base SolidObject', 'Obj94_SolidCollision:' in asm and '#$1B,d1' in asm)
    ck('HTZ object stream remains byte-identical to retail', obj==(SRC/'level/objects/HTZ_1.bin').read_bytes())
    ck('Retail Obj1C zipline mapping exists', (SRC/'mappings/sprite/obj16.bin').is_file())
    ck('Retail Spiker mapping exists', (SRC/'mappings/sprite/obj93.bin').is_file())

print(f'\n{sum(checks)}/{len(checks)} checks passed')
raise SystemExit(0 if all(checks) else 1)
