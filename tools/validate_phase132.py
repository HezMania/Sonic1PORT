#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, py_compile, re, sys

P = Path(__file__).resolve().parents[1]
S2 = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
checks = []

def ck(value, msg):
    ok = bool(value)
    checks.append((ok, msg))
    print(("PASS: " if ok else "FAIL: ") + msg)

def txt(rel):
    return (P / rel).read_text(errors="replace")

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def be16(data, off):
    return (data[off] << 8) | data[off + 1]

main = txt("scripts/main.gd")
cat = txt("scripts/data/level_catalog.gd")
audio = txt("scripts/audio/sonic_audio.gd")
cam = txt("scripts/camera/sonic_camera.gd")
fg = txt("scripts/render/ghz_renderer.gd")
bg = txt("scripts/render/ghz_background_renderer.gd")
anim = txt("scripts/render/level_art_animator.gd")
om = txt("scripts/objects/object_manager.gd")
cpz = txt("scripts/objects/s2_cpz_traversal_object.gd")
mecha = txt("scripts/objects/s2_dez_mecha_sonic.gd")
wfz = txt("scripts/objects/s2_wfz_object.gd")
wfzb = txt("scripts/objects/s2_wfz_boss_object.gd")
manifest = json.loads((P / "data/s1/s2test/phase132_dez_manifest.json").read_text())

# Phase identity / integration.
ck("Native Sonic 1 Phase 132" in main, "Debug overlay identifies Phase132")
ck("Num0 SCZ  Num1 WFZ  Num2 DEZ" in main, "Debug overlay advertises the DEZ warp")
ck('KEY_KP_2:' in main and '_debug_warp(LevelCatalog.ZONE_S2_DEZ_TEST, 1)' in main[main.index('KEY_KP_2:'):main.index('KEY_K:', main.index('KEY_KP_2:'))], "NumPad 2 warps directly to Death Egg")
ck("const ZONE_S2_DEZ_TEST := 18" in cat, "Death Egg has a dedicated catalog zone ID")
ck('if zone == ZONE_S2_DEZ_TEST:' in cat and 'return _get_sonic2_dez_test()' in cat, "Catalog routes the Death Egg zone")
ck('return Vector2i(ZONE_S2_DEZ_TEST, 1)' in cat[cat.index('if zone == ZONE_S2_WFZ_TEST:'):], "Wing Fortress progresses directly into Death Egg")
ck('SonicAudio.play_music(SonicAudio.MUS_S2_DEZ, true)' in main, "Main starts native Death Egg music")
ck("const MUS_S2_DEZ := 0x1A0" in audio, "Death Egg music has port-local ID $1A0")
ck(manifest.get("phase") == 132 and manifest.get("level") == "Death Egg Zone", "Phase132 manifest identifies Death Egg")
ck((P / "PHASE132_SONIC2_DEATH_EGG_MECHA_SONIC.md").exists(), "Phase132 notes exist")

# Exact imported level data.
ck(manifest.get("start") == [0x60, 0x12D], "Retail Death Egg start is $0060,$012D")
ck(manifest.get("limits") == {"left":0,"right":0x1000,"top":0xC8,"bottom":0xC8}, "Retail Death Egg level limits are registered")
ck(manifest.get("layout") == [128,16], "Death Egg foreground/background are 128x16 chunks")
ck(manifest.get("objects") == 5, "Death Egg keeps all five retail placement records")
ck(manifest.get("object_counts_hex") == {"2D":3,"C6":1,"C7":1}, "Death Egg placement IDs are 3x$2D + $C6 + $C7")
ck(manifest.get("rings_bytes") == 2 and (P/"data/s1/s2test/dez1_rings.bin").read_bytes() == b"\xFF\xFF", "Death Egg correctly has no placed rings")
ck(manifest.get("apm_dez") == {"destination":0x17F8,"bytes":8}, "APM_DEZ Map16 patch lands at the retail $17F8 destination")
ck(manifest.get("animated_tile") == 0x326, "Animated DEZ background writes tile $326")
for fn, digest in manifest.get("sha256", {}).items():
    ck(sha(P / "data/s1/s2test" / fn) == digest, f"Generated DEZ data hash matches manifest: {fn}")
ck((P/"data/s1/palette/S2 Death Egg Zone.bin").stat().st_size == 96, "Death Egg zone palette contains retail CRAM lines 1-3")
ck(len(list((P/"assets/objects/s2_dez/mecha").glob("*.png"))) == 23, "All 23 ObjAF Mecha Sonic mapping frames are reconstructed")
ck(len(list((P/"assets/objects/s2_dez/window").glob("*.png"))) == 8, "All 8 ObjAF remote-window mapping frames are reconstructed")
ck(len(list((P/"assets/objects/s2_dez/barrier").glob("*.png"))) >= 4, "Death Egg construction-barrier art is packaged")

# Level definition and rendering.
dezdef = cat[cat.index("static func _get_sonic2_dez_test"):cat.index("static func _get_sonic2_hpz_test")]
for needle, msg in [
    ('"layout": "s2test/dez1_layout128.bin"', "DEZ foreground layout path"),
    ('"background_layout": "s2test/dez1_bg128.bin"', "DEZ Plane-B layout path"),
    ('"map16": "s2test/dez1_map16.bin"', "DEZ Map16 path"),
    ('"chunk_map": "s2test/dez1_map128.bin"', "DEZ Map128 path"),
    ('"collision": "s2test/dez1_collision_primary.bin"', "DEZ primary collision path"),
    ('"collision_secondary": "s2test/dez1_collision_secondary.bin"', "DEZ secondary collision path"),
    ('"palette": "palette/S2 Death Egg Zone.bin"', "DEZ palette path"),
    ('"background_mode": "s2dez"', "DEZ background deformation mode"),
    ('"dynamic_events": "s2_dez"', "DEZ level event mode"),
    ('"s2_directional_objpos": true', "DEZ uses Sonic 2 directional ObjPosLoad"),
]: ck(needle in dezdef, msg)
ck("ZONE_S2_DEZ_TEST" in fg, "Death Egg foreground uses the indexed palette renderer")
ck('mode == "s2dez"' in bg and '_update_s2dez(camera_model)' in bg, "Background renderer dispatches SwScrl_DEZ")
ck('const S2_DEZ_ROW_HEIGHTS: Array[int]' in bg and bg[bg.index('const S2_DEZ_ROW_HEIGHTS'):].split('\n',1)[0].count('0x80') == 4, "SwScrl_DEZ row-height table includes all four $80 bands")
row_line = bg[bg.index('const S2_DEZ_ROW_HEIGHTS'):].split('\n',1)[0]
row_values = row_line[row_line.index('[')+1:row_line.rindex(']')].split(',')
ck(len(row_values) == 36, "SwScrl_DEZ has all 36 retail row-height entries")
ck('const S2_DEZ_STAR_SPEEDS: Array[int] = [3,2,4,1,2,4,3,4,2,6,3,4,1,2,4,3,2,3,4,1,3,4,2]' in bg, "SwScrl_DEZ preserves the first 23 source star rates")
ck('s2_dez_layer_x[24] = GenesisMath.s16(int(s2_dez_layer_x[24]) + 1)' in bg, "SwScrl_DEZ preserves the 24th +1 star rate")
ck('s2_dez_layer_x[29] = int((slow_word * 5) >> 3)' in bg and 's2_dez_layer_x[31] = int((slow_word * 7) >> 3)' in bg, "SwScrl_DEZ preserves 5/8, 6/8, 7/8 derived star rates")
ck('const S2_DEZ_ANIM_BACK_TILE = 0x326' in anim and 's2_dez_time = 4' in anim, "Animated_DEZ uses tile $326 and retail delay-4 cadence")

# LevEvents_DEZ and ObjAF handoff.
dle = cam[cam.index("func _dle_s2_dez"):cam.index("func _dle_s2_mtz3")]
ck('screen_x >= 0x140' in dle and 's2_dez_mecha_spawn_requested = true' in dle, "LevEvents_DEZ allocates ObjAF at Camera X $140")
ck('limit_left = screen_x' in dle and 'screen_x >= 0x300' in dle, "Post-Mecha DEZ event follows Camera_Min_X to $300")
ck('screen_x >= 0x680' in dle and 'limit_left = 0x680' in dle, "DEZ late event locks Camera_Min_X at $680")
ck('s2_dez_final_boss_ready = true' in dle, "DEZ late event exposes final-boss readiness for Phase133")
ck('func _tick_s2_dez_mecha_start' in main and 'spawn_s2_dez_mecha_sonic()' in main, "Main consumes the DEZ ObjAF allocation request")
ck('s2_dez_mecha_spawn_requested = false' in main, "ObjAF allocation request clears only after successful spawn")
ck('object_manager.s2_dez_mecha_defeated' in main and 'sonic_camera.dle_routine = 4' in main, "ObjAF defeat advances LevEvents_DEZ to routine 4")
ck('sonic_camera.limit_right = 0x1000' in main[main.index('object_manager.s2_dez_mecha_defeated'):main.index('s2_wfz_layout_refresh_requested')], "ObjAF defeat restores Death Egg Camera_Max_X=$1000")
ck('sonic_camera.limit_left = 0x224' in main and 'sonic_camera.limit_right = 0x224' in main, "Mecha Sonic fight locks both camera sides at $224")
ck('(s2_dez_act and object_manager.boss_screen_lock and object_manager.boss_status < 1)' in main, "Player-side runtime bounds honor the DEZ boss lock")

# Mecha Sonic foundation.
ck('const SPAWN_X := 0x348' in mecha and 'const SPAWN_Y := 0x0A0' in mecha, "ObjAF native spawn is $348,$0A0")
ck('const ARENA_X := 0x224' in mecha, "ObjAF source arena gate is $224")
ck('var hits: int = 8' in mecha, "Mecha Sonic retains eight boss hits")
wait = mecha[mecha.index('func _tick_wait'):mecha.index('func _tick_prelude')]
ck('manager.current_screen_x < ARENA_X' in wait and 'timer = 0x3C' in wait and 'vy = 0x100' in wait, "ObjAF wait uses $224 gate, $3C prelude and $100 fall speed")
prelude = mecha[mecha.index('func _tick_prelude'):mecha.index('func _tick_fall')]
ck('SonicAudio.MUS_S2_BOSS' in prelude, "ObjAF starts Sonic 2 boss music after the prelude")
ck('manager.boss_screen_lock = true' in wait and 'manager.boss_limit_right = ARENA_X' in wait, "ObjAF owns the camera lock when the fight starts")
ck('invulnerability_timer = 0x20' in mecha, "ObjAF hit flash/invulnerability lasts $20 frames")
ck('timer = 0xFF' in mecha[mecha.index('func _begin_defeat'):mecha.index('func _tick_defeat')], "ObjAF defeat countdown is $FF")
ck('manager.s2_dez_mecha_defeated = true' in mecha, "ObjAF reports defeat back to the DEZ event system")
ck('manager.boss_limit_right = 0x1000' in mecha, "ObjAF defeat reopens the retail $1000 right boundary")
ck('S2DEZMechaSonicClass' in om and 'func spawn_s2_dez_mecha_sonic' in om, "Object manager owns the transient native ObjAF boss")
ck('s2_dez_mecha_spawned = false' in om and 's2_dez_mecha_defeated = false' in om, "Death Egg boss state resets on level setup")

# Placed DEZ objects / deliberate final-boss boundary.
ck('bool(manager.level_definition.get("s2_dez", false))' in cpz and 's2_dez/barrier/00.png' in cpz, "Object $2D uses the DEZ construction-stripe art in Death Egg")
# $C6/$C7 must still fall to unsupported in the experimental namespace this phase.
dez_route_block = om[om.index('if bool(level_definition.get("experimental_sonic2", false)):'):om.index('\tmatch id:', om.index('if bool(level_definition.get("experimental_sonic2", false)):') + 1)]
ck('0xC6' not in dez_route_block and '0xC7' not in dez_route_block, "Objects $C6/$C7 remain deliberately deferred to Phase133")
objs = (P/'data/s1/s2test/dez1_objects.bin').read_bytes()
records = [objs[i:i+6] for i in range(0,len(objs),6)]
ck(Counter(r[4] for r in records) == Counter({0x2D:3,0xC6:1,0xC7:1}), "Packaged DEZ object stream preserves exact numeric IDs")

# Wing Fortress carry-forward fixes reported after Phase131.
hook = wfz[wfz.index('func _init_hook'):wfz.index('func _tick_hook')]
hook_tick = wfz[wfz.index('func _tick_hook'):wfz.index('func _init_clucker')]
ck('hook_initial_extended = (subtype & 0x70) != 0' in hook and 'state = motion_extent if hook_initial_extended else 0' in hook, "WFZ hook initial state follows retail subtype $70 selector")
ck('var wants_extend: bool = held != hook_initial_extended' in hook_tick, "WFZ hooks move only according to authored home state and held state")
open_state = wfzb[wfzb.index('func _tick_open'):wfzb.index('func _tick_shooter_down')]
ck('if releaser_release_count < 3' in open_state, "WFZ first laser waits until all three boss platforms are released")
releaser = wfzb[wfzb.index('func _tick_releaser'):wfzb.index('func _tick_eggman')]
ck('releaser_timer = 0x40 if releaser_release_count < 3 else 0x80' in releaser, "WFZ initial boss-platform release cadence is accelerated without changing replacement cadence")
vis = wfzb[wfzb.index('func _update_visuals'):wfzb.index('func _make_sprite')]
ck('laser_sprite.position = Vector2(0, 0x0D + beam_stage * 0x10)' in vis, "WFZ blue charge beam overlaps the orange laser core")
ck('6 + ((int(frame_counter / 6.0)) & 1)' in vis, "WFZ Robotnik stays on his intended waiting animation frames")
walls = wfzb[wfzb.index('func _tick_walls'):wfzb.index('func _check_laser_hazard')]
ck('0x0B, 0x40' in walls and '0x13, 0x40' not in walls, "WFZ side-beam collision is narrowed by eight pixels")
wfz_camera = main[main.index('elif s2_wfz_boss_act and sonic_camera.s2_wfz_event_subroutine >= 2'):main.index('elif fz_boss_act')]
ck('sonic_camera.limit_left = 0x2880' in wfz_camera[wfz_camera.index('else:'):], "Post-boss WFZ camera no longer ratchets its left boundary forward")
ck('p.inertia = 0x400' in wfz and 'p.in_air = false' in wfz[wfz.index('if state == 12'):wfz.index('if state == 13')], "WFZ scripted approach presents Sonic as grounded walking")
ck('p.vel_y = -0x680' in wfz and 'p.vel_y = GenesisMath.s16(p.vel_y + 0x38)' in wfz, "WFZ Tornado jump uses normal Sonic 2 jump impulse/gravity")
ck('_spawn_getaway_flame(0x3070, 0x3B0)' in wfz and '_spawn_late_getaway_flames()' in wfz, "WFZ getaway restores Eggman craft flame/thrust pieces")
ck('p.hang_on_pole = true' in wfz and '0x3118' in wfz, "WFZ getaway uses the retail invisible grab point for Sonic")

# Source comparisons when the retail tree is supplied.
if S2 is not None:
    ck((P/'data/s1/s2test/dez1_objects.bin').read_bytes() == (S2/'level/objects/DEZ_1.bin').read_bytes(), "DEZ object placement stream is byte-for-byte retail")
    ck((P/'data/s1/s2test/dez1_rings.bin').read_bytes() == (S2/'level/rings/DEZ_1.bin').read_bytes(), "DEZ ring stream is byte-for-byte retail")
    ck((P/'data/s1/s2test/dez1_start.bin').read_bytes() == (S2/'startpos/DEZ.bin').read_bytes(), "DEZ start position is byte-for-byte retail")
    ck((P/'data/s1/palette/S2 Death Egg Zone.bin').read_bytes() == (S2/'art/palettes/DEZ.bin').read_bytes(), "DEZ palette is byte-for-byte retail")
    asm = (S2/'s2.asm').read_text(errors='replace')
    ck('cmpi.w\t#$224,d0' in asm and 'move.w\t#$3C,objoff_2A(a0)' in asm, "Retail ObjAF source contains $224/$3C boss gates")
    ck('move.b\t#8,collision_property(a0)' in asm and 'move.w\t#$FF,objoff_32(a0)' in asm, "Retail ObjAF source contains 8-hit/$FF defeat lifecycle")
    ck('move.w\t#$1000,(Camera_Max_X_pos).w' in asm and 'addq.b\t#2,(Dynamic_Resize_Routine).w' in asm, "Retail ObjAF defeat reopens camera and advances LevEvents")
    ck('SwScrl_DEZ_RowHeights:' in asm and 'dc.b $80\t; 35' in asm, "Retail source contains all 36 SwScrl_DEZ row bands")

# Python importer and project-reference hygiene.
try:
    py_compile.compile(str(P/'tools/import_s2_dez_phase132.py'), doraise=True)
    ck(True, "Phase132 Death Egg importer compiles")
except Exception as exc:
    print(exc)
    ck(False, "Phase132 Death Egg importer compiles")

# Verify literal res:// preload/load references used by scripts exist. Ignore dynamic/interpolated paths.
missing = []
for gd in (P/'scripts').rglob('*.gd'):
    body = gd.read_text(errors='replace')
    for path in re.findall(r'(?:preload|load)\(\s*"(res://[^"%{}]+)"\s*\)', body):
        target = P / path[6:]
        if not target.exists():
            missing.append((str(gd.relative_to(P)), path))
ck(not missing, "All literal script preload/load res:// paths exist")
if missing:
    for item in missing[:20]: print('  missing:', item)

# Lightweight structural parser checks over every modified integration file.
struct_files = [
    'scripts/main.gd','scripts/data/level_catalog.gd','scripts/audio/sonic_audio.gd',
    'scripts/camera/sonic_camera.gd','scripts/render/ghz_renderer.gd',
    'scripts/render/ghz_background_renderer.gd','scripts/render/level_art_animator.gd',
    'scripts/objects/object_manager.gd','scripts/objects/s2_cpz_traversal_object.gd',
    'scripts/objects/s2_dez_mecha_sonic.gd','scripts/objects/s2_wfz_object.gd',
    'scripts/objects/s2_wfz_boss_object.gd',
]
for rel in struct_files:
    body = txt(rel)
    ck('<<<<<<<' not in body and '=======' not in body and '>>>>>>>' not in body, f'{rel} has no merge-conflict markers')
    ck(body.count('(') == body.count(')'), f'{rel} parentheses balance')
    ck(body.count('[') == body.count(']'), f'{rel} brackets balance')
    ck(body.count('{') == body.count('}'), f'{rel} braces balance')

passed = sum(1 for ok,_ in checks if ok)
print(f"\n{passed}/{len(checks)} checks passed")
if passed != len(checks):
    print("Failures:")
    for ok,msg in checks:
        if not ok: print(" - " + msg)
    raise SystemExit(1)
