#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, py_compile, sys
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

mtz=txt('scripts/objects/s2_mtz_object.gd')
om=txt('scripts/objects/object_manager.gd')
base=txt('scripts/objects/genesis_level_object.gd')
p120=json.loads((P/'data/s1/s2test/phase120_mtz_objects_manifest.json').read_text())
p119=json.loads((P/'data/s1/s2test/phase119_mtz1_manifest.json').read_text())

# Foundation/assets stay untouched.
ck(p120.get('phase')==120,'Phase120 MTZ object-art manifest remains present')
for rel,dig in p120.get('sha256',{}).items():
    q=P/'assets/objects/s2_mtz'/rel
    ck(q.is_file() and sha(q)==dig,f'Phase120 object art unchanged: {rel}')
for rel,dig in p119.get('sha256',{}).items():
    q=P/'data/s1/s2test'/rel
    ck(q.is_file() and sha(q)==dig,f'Phase119 MTZ1 level foundation unchanged: {rel}')

# Obj67 crash/path progression.
spin=func(mtz,'_init_spin_tube() -> void')+func(mtz,'_tick_spin_tube() -> void')+func(mtz,'_start_tube_segment(p: SonicPlayer) -> void')
ck('tube_path = TUBE_PATHS[idx].duplicate()' not in spin,'Obj67 no longer assigns untyped Array.duplicate() into Array[Vector2i]')
ck('tube_path.clear()' in spin and 'tube_path.append(Vector2i(point))' in spin,'Obj67 copies typed Vector2i path points safely')
ck('tube_target_index=1' in spin and 'tube_target_index+=1' in spin,'Obj67 advances through every path segment')
ck('tube_segment_timer-=1' in spin and '_start_tube_segment(p)' in spin,'Obj67 countdown hands off to subsequent segments')
ck('return object_id == 0x67 and tube_state != 0' in mtz,'Obj67 remains resident while controlling Sonic')

# Steam spring exact child placement.
steam=func(mtz,'_tick_steam_spring() -> void')+func(mtz,'_spawn_steam(local_x: int, flip: bool) -> void')
ck('_spawn_steam(0x28,false)' in steam,'Obj42 first steam child spawns at +$28')
ck('_spawn_steam(-0x28,true)' in steam,'Obj42 second steam child spawns at -$28 and flips')
ck('var wx: int=orig_x+local_x' in steam,'Obj42 steam placement is anchored to the source object X')

# Button sound edge trigger.
button=func(mtz,'_tick_button() -> void')
ck('button_pressed_last' in button,'Obj47 tracks its previous pressed state')
ck('if not button_pressed_last:' in button and 'SonicAudio.play_sfx(SonicAudio.SFX_SWITCH)' in button,'Obj47 switch SFX is edge-triggered')
ck('touched or (p.standing_on_object and p.support_record_index == record_index)' in button,'Obj47 maintains pressed state while Sonic remains supported')

# Slicer one-shot lifecycle.
slicer=func(mtz,'_tick_slicer() -> void')
ck('state=2;_set_frame(sprite,"slicer",4);_spawn_slicer_pincer(6);_spawn_slicer_pincer(-0x10)' in slicer,'Slicer enters spent routine after firing paired pincers')
ck('if timer<0:state=0' not in slicer,'Slicer does not regenerate pincers after they disappear')
ck('_source_visible' in slicer,'Slicer acquisition is gated to source-visible screen range')

# Asteron priority.
aster=func(mtz,'_init_asteron() -> void')+func(mtz,'_asteron_burst() -> void')
ck('sprite.z_as_relative=false' in aster and 'sprite.z_index=120' in aster,'Asteron body renders above high-priority MTZ foreground')
ck('s.z_as_relative=false;s.z_index=120' in aster,'Asteron burst children preserve foreground priority')

# Screen-visible helper without changing horizontal OPL loading semantics.
ck('func is_world_point_on_screen' in om,'Object manager exposes a viewport-aware source visibility helper')
vis=func(om,'is_world_point_on_screen(world_x: int, world_y: int, margin: int = 32) -> bool')
ck('viewport_width' in vis and 'viewport_height' in vis,'Visibility helper uses dynamic viewport dimensions')
ck('current_screen_y' in vis,'Visibility helper checks vertical screen position')
opl=func(om,'obj_pos_load(screen_x: int, screen_y: int = 0) -> void')
ck('var left = maxi(0, screen_block - SPAWN_LEFT)' in opl and 'var right = screen_block + SPAWN_RIGHT' in opl,'Retail-style horizontal OPL spawn window remains unchanged')

# Four-way spike block layering/timing.
spike=func(mtz,'_init_spike_block() -> void')+func(mtz,'_tick_spike_block() -> void')
ck('_new_sprite("moving_spike",spike_direction,0)' in spike,'Obj68 moving spike renders behind its block body')
ck('spike_offset+=8' in spike and 'spike_offset-=8' in spike,'Obj68 keeps retail 8px extension/retraction speed')
ck('spike_offset=0x20' in spike and 'spike_expanding=false' in spike and 'spike_waiting=true' in spike,'Obj68 waits at full extension before retracting')
ck('(manager.elapsed_frames&0x3F)==0' in spike,'Obj68 wait releases on retail $40-frame boundary')

# Spring-wall collision/impulse ordering.
spring=func(mtz,'_tick_spring_wall() -> void')
solid_pos=spring.find('p.resolve_solid_box_contact')
impulse_pos=spring.find('p.vel_x = 0x800')
ck(solid_pos>=0 and impulse_pos>solid_pos,'Obj66 resolves wall contact before applying spring impulse')
ck('p.vel_y = 0 if (subtype & 0x80) != 0 else -0x800' in spring,'Obj66 preserves retail horizontal-only subtype and normal -$800 vertical launch')
ck('p.lock_time = 0x0F' in spring,'Obj66 keeps retail $0F movement lock')

# Shellcracker mapping identity.
shell=func(mtz,'_shell_set_chain(extension: float) -> void')
ck('_set_frame(s,"shellcracker",5 if i==7 else 4)' in shell,'Shellcracker uses frame 5 for the claw shell and frame 4 for seven joints')
for f in (4,5):
    q=P/f'assets/objects/s2_mtz/shellcracker/{f:02d}.png'
    ck(q.is_file() and Image.open(q).getbbox() is not None,f'Shellcracker source-rendered frame {f} exists and has pixels')

# Downward platform exact 16.16 integration.
plat=func(mtz,'_init_platform() -> void')+func(mtz,'_tick_platform() -> void')
ck('platform_fixed_y=orig_y<<16' in plat,'Obj6B keeps a 16.16 Y accumulator')
ck('platform_fixed_y += GenesisMath.s16(vel_y)<<8' in plat,'Obj6B ObjectMove uses exact 8.8-to-16.16 velocity integration')
ck('position.y=float((platform_fixed_y>>16)&0x7FF)' in plat,'Obj6B display/collision position derives from fixed-point Y')
ck('if vel_y==0x2A8:bounce_accel=-8' in plat,'Obj6B keeps retail $2A8 turnaround velocity')

# Moving Obj65 platform range follows current X.
ck('func central_despawn_x() -> int:' in base,'Base level object exposes source MarkObjGone X hook')
rangef=func(mtz,'central_despawn_x() -> int')
ck('object_id == 0x65 and platform_mode == 5' in rangef and 'position.x' in rangef,'Obj65 moving traverse reports current X for range checks')
ck('var range_x = obj.central_despawn_x()' in opl,'Central despawn uses object-specific source X')
ck('0x1BC0' in mtz and '0x1880' in mtz,'Obj65 MTZ1 traversal still spans $1880..$1BC0')

# MTZ badnik activation guard.
shelltick=func(mtz,'_tick_shellcracker() -> void')
astertick=func(mtz,'_tick_asteron() -> void')
ck('_source_visible' in shelltick,'Shellcracker attack acquisition is viewport-gated')
ck('_source_visible' in astertick,'Asteron activation is viewport-gated')

# Static sanity.
for rel in ['scripts/objects/s2_mtz_object.gd','scripts/objects/object_manager.gd','scripts/objects/genesis_level_object.gd']:
    t=txt(rel)
    ck('<<<<<<<' not in t and '>>>>>>>' not in t,f'{rel} has no merge-conflict markers')
    ck(t.count('(')==t.count(')'),f'{rel} parentheses balance')
    ck(t.count('[')==t.count(']'),f'{rel} brackets balance')
    ck(t.count('{')==t.count('}'),f'{rel} braces balance')

if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    misc=(S2/'misc/obj67.asm').read_text(errors='replace')
    source=[
        ('addi.w\t#$28,x_pos(a1)','Retail Obj42 moves first steam child +$28'),
        ('subi.w\t#$28,x_pos(a1)','Retail Obj42 moves second steam child -$28'),
        ('bset\t#0,render_flags(a1)','Retail Obj42 flips the second steam child'),
        ('tst.b\t(a3)','Retail Obj47 checks trigger before playing sound'),
        ('addq.b\t#2,routine(a0)\n\tmove.b\t#4,mapping_frame(a0)\n\tbsr.w\tObjA1_LoadPincers','Retail Slicer advances to terminal routine after firing'),
        ('move.b\t#4,mapping_frame(a0)','Retail Obj68 block mapping is frame 4'),
        ('move.w\t#1,spikearoundblock_waiting(a0)','Retail Obj68 waits at endpoint'),
        ('move.w\t#-$800,x_vel(a1)','Retail Obj66 spring-wall horizontal impulse is $800'),
        ('move.w\t#-$800,y_vel(a1)','Retail Obj66 spring-wall vertical impulse is -$800'),
        ('move.b\t#4,mapping_frame(a0)\n\taddq.w\t#6,x_pos(a0)','Retail Shellcracker non-tip links use mapping frame 4'),
        ('move.b\t#5,mapping_frame(a1)','Retail Shellcracker children initially use mapping frame 5'),
        ('cmpi.w\t#$2A8,y_vel(a0)','Retail Obj6B drop platform reverses acceleration at $2A8'),
        ('move.w\tx_pos(a0),objoff_34(a0)\n\tmove.w\tx_pos(a0),(MTZ_Platform_Cog_X).w','Retail Obj65 moving traverse refreshes its range-reference X'),
    ]
    for needle,msg in source: ck(needle in asm,msg)
    for start in ['$7A8','$C58','$1828']:
        ck(start in misc,f'Retail Obj67 Act1 path source contains {start}')

for rel in ['tools/validate_phase120.py','tools/validate_phase121.py']:
    try: py_compile.compile(str(P/rel),doraise=True); ck(True,f'{rel} compiles')
    except Exception as e: ck(False,f'{rel} compiles: {e}')

bad=[m for ok,m in checks if not ok]
print(f'\n{len(checks)-len(bad)}/{len(checks)} checks passed')
if bad:
    print('Failures:')
    for m in bad: print(' - '+m)
    raise SystemExit(1)
