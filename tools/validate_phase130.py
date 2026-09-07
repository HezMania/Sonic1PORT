#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import hashlib, json, py_compile, sys
P=Path(__file__).resolve().parents[1]
S2=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(r): return (P/r).read_text(errors='replace')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

main=txt('scripts/main.gd'); wfz=txt('scripts/objects/s2_wfz_object.gd')
boss=txt('scripts/objects/s2_wfz_boss_object.gd'); om=txt('scripts/objects/object_manager.gd')
cat=txt('scripts/data/level_catalog.gd'); cyc=txt('scripts/render/level_palette_cycler.gd')
fg=txt('scripts/render/ghz_renderer.gd'); imp=txt('tools/import_s2_wfz_phase130.py')
manifest=json.loads((P/'data/s1/s2test/phase130_wfz_manifest.json').read_text())

ck('Native Sonic 1 Phase 130' in main,'Debug overlay identifies Phase130')
ck(manifest.get('phase')==130 and manifest.get('level')=='Wing Fortress Zone','Phase130 manifest identifies Wing Fortress')
ck((P/'PHASE130_SONIC2_WING_FORTRESS_BOSS_END.md').exists(),'Phase130 implementation notes exist')

# Runtime report 1: exact WFZ palette-cycle target line.
wfzcyc=cyc[cyc.index('func _tick_s2_wfz'):cyc.index('func _load_cycle_data')]
ck('_write_run(level.palette, 39, source, source_offset, 4)' in wfzcyc,'WFZ fire/conveyor cycle writes combined CRAM 39..42')
ck('_write_single(level.palette, 46' in wfzcyc,'WFZ flash cycle 1 writes combined CRAM 46')
ck('_write_single(level.palette, 47' in wfzcyc,'WFZ flash cycle 2 writes combined CRAM 47')
ck('_write_run(level.palette, 55' not in wfzcyc and '_write_single(level.palette, 62' not in wfzcyc and '_write_single(level.palette, 63' not in wfzcyc,'Old incorrect fourth-line WFZ cycle targets are gone')
pal=(P/'data/s1/palette/S2 Wing Fortress Zone.bin').read_bytes()
ck([int.from_bytes(pal[i*2:i*2+2],'big') for i in range(34,38)]==[0x0244,0x0268,0x048A,0x04AC],'Brown/gold WFZ terrain bridge remains intact')

# Runtime report 2: stop terrain rerasterization during rapid CRAM cycles.
mode=fg[fg.index('palette_indexed_mode = level != null'):fg.index('cycle_palette_image = null')]
ck('LevelCatalog.ZONE_S2_WFZ_TEST' in mode,'WFZ foreground uses palette-indexed renderer')
refresh=fg[fg.index('func refresh_palette_indices'):fg.index('func _collect_chunk_palette_patches')]
ck('if palette_indexed_mode:' in refresh and '_update_cycle_palette_texture()' in refresh and 'return' in refresh,'Indexed palette refresh updates palette texture and exits before RGBA chunk patches')
ck('static var _texture_cache: Dictionary = {}' in wfz,'WFZ sprite texture cache from Phase129 is retained')
ck('wfz_frame_path' in wfz,'WFZ animated sprites suppress same-frame texture reassignments')

# Runtime report 3: circular platform carry.
plat=wfz[wfz.index('func _tick_platform'):wfz.index('func _init_conveyor')]
ck('riding_old_surface' in plat and 'feet_y' in plat,'Obj19 recognizes prior top-surface support across descending circular motion')
ck('p.force_add_pixel_offset(nx - old_x, ny - old_y)' in plat,'Obj19 applies direct old-word to new-word X/Y carry before re-resolve')
ck('resolve_platform_top(nx - active_width, nx + active_width, ny - 0x11, record_index)' in plat,'Obj19 reaffirms retail top-only PlatformObject surface')
ck('GenesisMath.s8((a - 0x40) & 0xFF)' in wfz and 'GenesisMath.s8((b - 0x40) & 0xFF)' in wfz,'Circular Obj19 retains source byte-wrap/sign-extension math')

# Boss gate/integration.
ck('"s2_wfz_boss": true' in cat and '"s2_wfz_boss_active": true' in cat,'WFZ boss event is enabled in LevelCatalog')
ck('const S2WFZBossObjectClass = preload' in om,'Object manager preloads native WFZ boss adapter')
ck('func spawn_s2_wfz_boss() -> bool' in om,'Object manager exposes WFZ boss spawn gate')
ck('boss_limit_right = 0x2C60' in om and 'boss_screen_lock = true' in om,'WFZ boss manager initializes authored arena state')
ck('func _tick_s2_wfz_boss_start' in main and 'sonic_camera.s2_wfz_boss_ready' in main,'Main loop bridges LevEvents_WFZ to boss spawn')
ck('_tick_s2_wfz_boss_start(player, s2_wfz_boss_act)' in main,'WFZ boss watchdog runs every active WFZ frame')
ck('sonic_camera.current_bottom = 0x442' in main and 'sonic_camera.target_bottom = 0x442' in main,'Object C5 clamps live/target lower camera boundary to $442')
ck('sonic_camera.current_bottom = 0x720' in main and 'sonic_camera.target_bottom = 0x720' in main,'Boss defeat restores lower camera boundary to $720')

# Object C5 source-shaped states/timers.
ck('const START_X := 0x2B80' in boss and 'const START_Y := 0x450' in boss,'WFZ boss uses retail placed Object C5 coordinates')
ck('var hits: int = 8' in boss,'WFZ boss has retail eight hit points')
ck('timer = 0x5A' in boss,'WFZ boss uses retail $5A music/prelude wait')
ck('timer = 0x60' in boss and 'vy = 0x40' in boss,'WFZ case uses retail $60 descent timer and $40 Y speed')
ck('timer = 0x70' in boss and 'vx = direction * 0x100' in boss,'WFZ case uses retail $70 patrol and $100 X speed')
ck('timer = 0x0E' in boss,'Laser shooter uses retail $E down/up travel')
ck('timer = 0x40' in boss,'Laser charge uses retail $40 wait')
ck('timer = 0x80' in boss and 'vx = direction * 0x80' in boss,'Laser sweep uses retail $80 timer and $80 X speed')
ck('timer = 0xEF' in boss,'Defeat sequence uses retail $EF explosion countdown')
ck('manager.set_boss_defeated()' in boss and 'SonicAudio.MUS_S2_WFZ' in boss,'Boss defeat restores WFZ music and sets defeated status')

# Boss machinery/visuals/collision.
ck((P/'assets/objects/s2_wfz/boss').exists() and len(list((P/'assets/objects/s2_wfz/boss').glob('*.png')))==19,'All 19 ObjC5 mapping frames are reconstructed')
ck((P/'assets/objects/s2_wfz/boss_eggman').exists() and len(list((P/'assets/objects/s2_wfz/boss_eggman').glob('*.png')))==8,'All 8 ObjC6 Robotnik mapping frames are reconstructed')
ck((P/'assets/objects/s2_wfz/boss_eggman_platform/00.png').exists(),'Robotnik waiting platform is reconstructed')
ck('left_wall_sprite' in boss and 'right_wall_sprite' in boss and '_tick_walls()' in boss,'Boss includes two flashing solid laser walls')
ck('resolve_solid_box_contact(_boss_x() - WALL_OFFSET_X' in boss and 'resolve_solid_box_contact(_boss_x() + WALL_OFFSET_X' in boss,'Laser wall collision uses both authored sides')
ck('for i in range(3):' in boss and 'p.resolve_platform_top' in boss,'Boss creates three top-only moving platforms')
ck('p.move_with_supported_object(support_id, px - old_x, py - old_y' in boss,'Boss moving platforms carry supported Sonic on both axes')
ck('p.apply_hazard_hit(px)' in boss,'Boss platform undersides retain hazard behavior')
ck('beam_stage <= 4' in boss and '14 + beam_stage' in boss,'Laser extends through source long-beam mapping stages')
ck('_check_laser_hazard()' in boss and 'beam_active' in boss,'Fully extended boss laser has an active hazard region')
ck('SonicAudio.SFX_HIT_BOSS' in boss and 'invulnerable_timer = 0x20' in boss,'Boss hits play hit SFX and enforce hit invulnerability')

# Final Tornado / end handoff.
torn=wfz[wfz.index('func _init_tornado'):wfz.index('# -----------------------------------------------------------------------------\n# $B4/$B5')]
ck('elif subtype == 0x54:' in torn,'WFZ end Tornado subtype $54 is active')
ck('manager.boss_status < 1 or p.pixel_y() < 0x5EC' in torn,'End Tornado waits for boss defeat and retail Y $5EC gate')
ck('timer < 0x40' in torn and 'fixed_x = 0x2E58 << 16' in torn and 'fixed_y = 0x66C << 16' in torn,'End Tornado retains retail $40 wait and $2E58,$66C staging position')
ck('timer < 0x30' in torn and 'timer < 0x100' in torn,'End Tornado retains source $30 approach and $100 landed hold gates')
ck('timer >= 0x460' in torn and 'manager.s2_wfz_getaway_active = true' in torn,'End Tornado switches background getaway at source $460 gate')
ck('timer < 0x9C0' in torn and 'manager.request_level_transition' in torn,'End Tornado performs source $9C0 final handoff gate')
ck('sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 6)' in main,'Main bridges end Tornado into LevEvents_WFZ getaway routine 6')

# Source asset/data invariants.
ck(manifest.get('objects')==157 and manifest.get('layout')==[128,16] and manifest.get('supplement_tile')==0x307,'WFZ final object/layout/supplement invariants remain exact')
obj=(P/'data/s1/s2test/wfz1_objects.bin').read_bytes(); ck(len(obj)//6==157,'WFZ retains all 157 final object records')
for fn,h in manifest.get('sha256',{}).items(): ck(sha(P/'data/s1/s2test'/fn)==h,f'Phase130 generated data hash matches manifest: {fn}')
if S2 is not None:
    retail=(S2/'art/palettes/WFZ.bin').read_bytes(); scz=(S2/'art/palettes/SCZ.bin').read_bytes()
    ck(all(pal[i*2:i*2+2]==scz[i*2:i*2+2] for i in range(34,38)),'Four brown/gold bridge colors exactly match SCZ handoff colors')
    ck((P/'data/s1/s2test/wfz1_objects.bin').read_bytes()==(S2/'level/objects/WFZ_1.bin').read_bytes(),'WFZ object stream remains byte-for-byte retail')
    ck((P/'data/s1/s2test/wfz1_rings.bin').read_bytes()==(S2/'level/rings/WFZ_1.bin').read_bytes(),'WFZ ring stream remains byte-for-byte retail')
    ck((P/'data/s1/s2test/wfz1_start.bin').read_bytes()==(S2/'startpos/WFZ.bin').read_bytes(),'WFZ start stream remains byte-for-byte retail')

try:
    py_compile.compile(str(P/'tools/import_s2_wfz_phase130.py'),doraise=True); ck(True,'Phase130 WFZ importer compiles')
except Exception as e:
    print(e); ck(False,'Phase130 WFZ importer compiles')

# Structural guard for every edited script. This does not replace runtime Godot
# validation but catches truncated edits/merge damage in the packaged phase.
for rel in ['scripts/objects/s2_wfz_object.gd','scripts/objects/s2_wfz_boss_object.gd','scripts/objects/object_manager.gd','scripts/render/level_palette_cycler.gd','scripts/render/ghz_renderer.gd','scripts/data/level_catalog.gd','scripts/main.gd']:
    body=txt(rel)
    ck('<<<<<<<' not in body and '=======' not in body and '>>>>>>>' not in body,f'{rel} has no merge-conflict markers')
    ck(body.count('(')==body.count(')'),f'{rel} parentheses balance')
    ck(body.count('[')==body.count(']'),f'{rel} brackets balance')
    ck(body.count('{')==body.count('}'),f'{rel} braces balance')

passed=sum(1 for ok,_ in checks if ok)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' - '+msg)
    raise SystemExit(1)
