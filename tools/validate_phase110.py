#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import hashlib, json, py_compile, sys
P=Path(__file__).resolve().parents[1]
SRC=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(name,cond,detail=''):
    ok=bool(cond); checks.append(ok); print(('PASS' if ok else 'FAIL')+': '+name+((' — '+str(detail)) if detail else ''))
def text(rel): return (P/rel).read_text(errors='replace')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

htz=text('scripts/objects/s2_htz_object.gd'); boss=text('scripts/objects/s2_htz_boss_object.gd')
cam=text('scripts/camera/sonic_camera.gd'); main=text('scripts/main.gd'); mgr=text('scripts/objects/object_manager.gd')
cat=text('scripts/data/level_catalog.gd'); prison=text('scripts/objects/s2_egg_prison_object.gd')

# HTZ2 rising lava: exact retail subtype $06 semantics.
ck('Obj30 subtype 6 uses raw $E0 half width','active_width = 0xE0 if subtype == 6 else 0xC0' in htz)
ck('Obj30 subtype 6 uses $78 half height','subtype == 4 or subtype == 6 else 0x80' in htz)
ck('Only subtype 6 hurts supported Sonic','subtype == 6 and contact == SonicPlayer.SOLID_TOP and p.standing_on_object' in htz)
ck('HTZ1 subtype 4 no longer applies hazard damage','subtype == 4 and contact == SonicPlayer.SOLID_TOP' not in htz)
ck('HTZ2 rising lava uses source-rendered Act2 art','quake_lava_act2_a' in htz and 'quake_lava_act2_b' in htz)
ck('HTZ2 lava art tracks live retail palette cycle','manager.htz_lava_palette_frame & 0x0F' in htz)
for folder in ('quake_lava_act2_a','quake_lava_act2_b'):
    frames=sorted((P/'assets/objects/s2_htz'/folder).glob('*.png'))
    ck(folder+' has 16 palette states',len(frames)==16,len(frames))
    for f in frames:
        im=Image.open(f)
        ck(f'{folder}/{f.name} is exact 448x240 body',im.size==(448,240),im.size)
        ck(f'{folder}/{f.name} is nonblank',im.getbbox() is not None)

# Retail HTZ2 boss DLE.
seg=cam[cam.find('func _dle_s2_htz2'):cam.find('func _start_s2_htz2_quake')]
for value in ['0x2B00','0x2C50','0x2EDF','0x2EE0','0x2F5E','0x480','0x478','0x5A','0x30E0','0x428','0x430']:
    ck('HTZ2 boss camera contains '+value,value in seg)
ck('HTZ2 camera has persistent boss request','s2_htz2_boss_spawn_requested' in cam)
ck('HTZ2 camera exposes boss defeated flag','s2_htz2_boss_defeated' in cam)
ck('HTZ2 boss wait is camera-source timer','_s2_htz2_boss_gate_timer = sonic_camera.s2_htz2_event_timer' in main)
ck('HTZ2 main does not double-increment source $5A timer','_s2_htz2_boss_gate_timer += 1' not in main[main.find('func _tick_s2_htz2_boss_start'):main.find('func _tick_level_art')])
ck('HTZ2 boss starts retail boss music','spawn_s2_htz_boss()' in main and 'MUS_S2_BOSS' in main[main.find('func _tick_s2_htz2_boss_start'):main.find('func _tick_level_art')])

# Object $52 implementation / retail values.
ck('Object $52 class is preloaded','S2HTZBossObjectClass' in mgr)
ck('Object $52 manager spawn is definition gated','func spawn_s2_htz_boss' in mgr and 's2_htz_boss' in mgr[mgr.find('func spawn_s2_htz_boss'):mgr.find('func unlock_s2_htz_boss_right_boundary')])
ck('HTZ boss camera release reaches $3160','mini(0x3160, boss_limit_right + 2)' in mgr)
ck('Catalog enables HTZ boss only in Act 2','"s2_htz_boss": act == 2' in cat)
ck('HTZ Egg Prison uses HTZ art','art_folder = "s2_htz/egg_prison"' in prison)
ck('Boss starts at retail $3040,$580','RIGHT_X := 0x3040' in boss and 'RIGHT_BOTTOM_Y := 0x580' in boss)
ck('Boss has retail 8 hits','var hits: int = 8' in boss)
ck('Boss raise/lower speed is retail $E0','boss_y_vel: int = -0xE0' in boss and 'boss_y_vel = 0xE0' in boss)
ck('Boss uses retail left/right wells',all(v in boss for v in ['LEFT_X := 0x2F40','RIGHT_X := 0x3040','LEFT_BOTTOM_Y := 0x5A0','RIGHT_BOTTOM_Y := 0x580']))
ck('Boss uses retail top heights',all(v in boss for v in ['LEFT_TOP_Y := 0x518','RIGHT_TOP_Y := 0x4FC']))
ck('Boss uses retail lava-ball launch heights',all(v in boss for v in ['LEFT_BALL_Y := 0x538','RIGHT_BALL_Y := 0x548']))
ck('Boss body collision is retail $20x$1C','0x20 + p.width_radius' in boss and '0x1C + p.height_radius' in boss)
ck('Boss hit invulnerability is retail $20','invincibility_timer = 0x20' in boss)
ck('Boss attached-flame collision uses source offset table','FLAME_X_OFFSETS' in boss and 'FLAME_Y_RADII' in boss)
ck('Boss moving flamethrower uses $70 and 4 px/frame','dir * 0x70' in boss and '"vx":dir * 4' in boss)
ck('Boss lava balls use retail +- $1C00 X velocity','-0x1C00 if side == 0 else 0x1C00' in boss)
ck('Boss lava balls use retail -$5400/-$6400 Y velocities','-0x5400' in boss and '-0x6400' in boss)
ck('Boss lava-ball gravity is retail $380','+ 0x380' in boss)
ck('Boss defeat countdown is retail $B3','defeat_countdown = 0xB3' in boss)
ck('Boss defeat awards displayed 1000 points','manager.add_score(1000)' in boss)
ck('Boss restores HTZ music after $-3C defeat handoff','defeat_countdown > -0x3C' in boss and 'MUS_S2_HTZ' in boss)

# Generated boss/capsule source art.
expected={
 'boss/main':2,'boss/flame':10,'boss/projectile':4,'boss/smoke':4,'boss/fire':6,'egg_prison':6,
}
for folder,n in expected.items():
    files=sorted((P/'assets/objects/s2_htz'/folder).glob('*.png'))
    ck(folder+' generated frame count',len(files)==n,len(files))
    for f in files:
        im=Image.open(f); ck(str(f.relative_to(P))+' is 192x192',im.size==(192,192),im.size); ck(str(f.relative_to(P))+' nonblank',im.getbbox() is not None)

manifest_path=P/'data/s1/s2test/phase110_htz_boss_manifest.json'
ck('Phase110 manifest exists',manifest_path.is_file())
manifest=json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
ck('Phase110 manifest identifies Object $52',manifest.get('phase')==110 and manifest.get('boss')=='Object $52')
ck('Manifest records retail lava dimensions',manifest.get('act2_lava',{}).get('size')==[448,240])
for rel,want in manifest.get('files',{}).items():
    f=P/rel; ck('manifest asset exists '+rel,f.is_file());
    if f.is_file(): ck('manifest hash matches '+rel,sha(f)==want)

if SRC:
    asm=(SRC/'s2.asm').read_text(errors='replace')
    ev=asm[asm.find('LevEvents_HTZ2:'):asm.find('LevEvents_HPZ:')]
    for val in ['#$2B00','#$2C50','#$2EDF','#$2EE0','#$2F5E','#$480','#$478','#$5A','#$30E0','#$428','#$430']:
        ck('Retail LevEvents_HTZ2 source contains '+val,val in ev)
    o30=asm[asm.find('; Object 30 - Large rising lava during earthquake in HTZ'):asm.find('; Object 33 - Green platform from OOZ')]
    ck('Retail Obj30 subtype6 uses d1=$EB', 'move.w\t#$EB,d1' in o30)
    ck('Retail Obj30 subtype6 uses d2=$78', 'move.w\t#$78,d2' in o30)
    ck('Retail Obj30 subtype6 calls hurt-supported routine','Obj30_HurtSupportedPlayers' in o30)
    o52=asm[asm.find('; Object 52 - HTZ boss'):asm.find('; Object 89 - ARZ boss')]
    for val in ['#$3040','#$580','#8,objoff_32','#-$E0,(Boss_Y_vel)','#$B3,(Boss_Countdown)','#$3160,(Camera_Max_X_pos)']:
        ck('Retail Obj52 source contains '+val,val in o52)

for rel in ['tools/import_s2_htz_boss_phase110.py','tools/validate_phase110.py']:
    try: py_compile.compile(str(P/rel),doraise=True); good=True; detail=''
    except Exception as e: good=False; detail=e
    ck(rel+' compiles',good,detail)

print(f'\n{sum(checks)}/{len(checks)} checks passed')
raise SystemExit(0 if all(checks) else 1)
