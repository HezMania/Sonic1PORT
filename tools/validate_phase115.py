#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, py_compile, re, sys
from collections import Counter
from pathlib import Path

P = Path(__file__).resolve().parents[1]
S2 = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
checks: list[tuple[bool,str]] = []

def ck(condition, message):
    ok = bool(condition)
    checks.append((ok, message))
    print(("PASS: " if ok else "FAIL: ") + message)

def txt(rel: str) -> str:
    return (P / rel).read_text(errors="replace")

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off+1]

def func(text: str, name: str) -> str:
    marker = "func " + name
    a = text.index(marker)
    b = text.find("\nfunc ", a + 1)
    return text[a:len(text) if b < 0 else b]

manifest_path = P / "data/s1/s2test/phase115_ooz1_manifest.json"
manifest = json.loads(manifest_path.read_text())
cat = txt("scripts/data/level_catalog.gd")
main = txt("scripts/main.gd")
audio = txt("scripts/audio/sonic_audio.gd")
pal = txt("scripts/render/level_palette_cycler.gd")
anim = txt("scripts/render/level_art_animator.gd")
bg = txt("scripts/render/ghz_background_renderer.gd")
om = txt("scripts/objects/object_manager.gd")
boss = txt("scripts/objects/s2_mcz_boss_object.gd")

# ---------------------------------------------------------------------------
# Exact imported OOZ1 data
# ---------------------------------------------------------------------------
ck(manifest.get("phase") == 115 and manifest.get("level") == "Oil Ocean Zone Act 1", "Phase 115 manifest identifies retail OOZ1")
ck(manifest.get("start") == [0x60, 0x6AC], "OOZ1 exact retail start is $0060,$06AC")
ck(manifest.get("limits") == {"left":0,"right":0x2F80,"top":0,"bottom":0x680}, "OOZ1 retail LevelSize boundaries match $0000..$2F80/$0000..$0680")
ck(manifest.get("layout") == [128,16], "OOZ1 split foreground/background layouts retain retail 128x16 dimensions")
ck(manifest.get("background_cache") == [6,4], "OOZ Plane-B repeat cache records six chunks by four rows")
ck(manifest.get("map16") == {"base_bytes":0x15E0,"apm_offset":0x17A0,"apm_bytes":0x60}, "OOZ Map16 base and assembled APM_OOZ patch geometry are exact")
ck(manifest.get("map128_bytes") == 0x8000, "OOZ 128x128 mapping decompresses to $8000 bytes")
ck(manifest.get("collision_bytes") == 0x300, "OOZ collision index is exact $300 bytes")
ck(manifest.get("objects") == 189, "OOZ1 placement stream contains 189 six-byte records")
ck(manifest.get("active_shared_records") == 56, "Phase 115 activates 56 source-shared OOZ1 placement records")
ck(manifest.get("deferred_ooz_specific_records") == 133, "Phase 115 safely defers 133 OOZ-specific placement records")
expected_counts = {"0D":1,"19":13,"1C":21,"1F":17,"26":11,"33":11,"36":40,"3D":3,"3F":30,"41":2,"48":16,"4A":14,"50":8,"79":2}
ck(manifest.get("object_counts_hex") == expected_counts, "OOZ1 object-ID histogram is byte-exact")
ck(manifest.get("global_oil_object") == {"source_id":7,"y":0x758,"width":0x20,"submersion":0x30}, "Global retail Object $07 oil constants are recorded")
ck(manifest.get("music") == {"id":0x19C,"tempo":0xD0,"voices":6,"dac_ids":[0,1]}, "OOZ SMPS import metadata is exact")

expected_sizes = {
    "ooz1_art.bin": 0x10000,
    "ooz1_map16.bin": 0x1800,
    "ooz1_map128.bin": 0x8000,
    "ooz1_layout128.bin": 2 + 128*16,
    "ooz1_bg128.bin": 2 + 128*16,
    "ooz1_collision_primary.bin": 0x300,
    "ooz1_collision_secondary.bin": 0x300,
    "ooz1_objects.bin": 189*6,
    "ooz1_start.bin": 4,
}
for name, size in expected_sizes.items():
    p = P / "data/s1/s2test" / name
    ck(p.is_file() and p.stat().st_size == size, f"{name} has expected size {size:#x}")
for name, digest in manifest.get("sha256", {}).items():
    p = P / "data/s1/s2test" / name
    ck(p.is_file() and sha(p) == digest, f"Imported OOZ1 hash stable: {name}")

layout = (P/"data/s1/s2test/ooz1_layout128.bin").read_bytes()
bglay = (P/"data/s1/s2test/ooz1_bg128.bin").read_bytes()
ck(layout[:2] == bytes((127,15)) and bglay[:2] == bytes((127,15)), "OOZ1 split layouts retain S2 width/height header $7F,$0F")
bgraw = bglay[2:]
ck(all(v == 0 for v in bgraw[0:128]), "OOZ Plane-B row 0 is source blank")
ck(bgraw[128:134] == bytes([2,79,2,31,2,31]), "OOZ Plane-B cloud row begins exact six-chunk repeat")
ck(bgraw[256:262] == bytes([73,74,75,35,84,108]), "OOZ Plane-B middle row begins exact six-chunk repeat")
ck(bgraw[384:390] == bytes([76,77,78,50,90,116]), "OOZ Plane-B lower row begins exact six-chunk repeat")

# Art bank/APM and animation source retention.
artmeta = manifest["art"]
ck(artmeta.get("main_bytes") == 0x5520 and artmeta.get("main_tiles") == 0x2A9, "Kosinski OOZ main art is exact $5520 bytes/$2A9 tiles")
anim_expect = {
    "ooz_pulse_ball.bin": (0x2B6, 0x180, 4),
    "ooz_square_ball1.bin": (0x2BA, 0x200, 4),
    "ooz_square_ball2.bin": (0x2BE, 0x200, 4),
    "ooz_oil1.bin": (0x2C2, 0x800, 16),
    "ooz_oil2.bin": (0x2D2, 0x800, 16),
}
for name, (tile, size, seed_tiles) in anim_expect.items():
    p=P/"data/s1/s2test"/name
    ck(p.is_file() and p.stat().st_size == size, f"Retained dynamic-art source {name} has exact source length")
plc_tiles = {v["tile"] for v in artmeta.get("plc",{}).values()}
for tile in [0x2E2,0x2F4,0x30C,0x32C,0x332,0x336,0x346,0x354,0x368,0x39D,0x3C5,0x3E3,0x3FF,0x403,0x424,0x434,0x43C,0x45C,0x470,0x500,0x538]:
    ck(tile in plc_tiles, f"OOZ PLC destination tile ${tile:03X} present")
ck((P/"data/s1/palette/S2 Oil Ocean Zone.bin").stat().st_size == 0x60, "OOZ primary palette packaged as exact $60-byte source bank")
ck((P/"data/s1/palette/S2 Oil Ocean Oil Cycle.bin").stat().st_size == 0x10, "CyclingPal_Oil packaged as exact 16-byte/eight-color cycle")

# ---------------------------------------------------------------------------
# Catalog, progression, debug and music
# ---------------------------------------------------------------------------
for token,msg in [
    ("const ZONE_S2_OOZ_TEST := 14", "LevelCatalog reserves native OOZ zone slot 14"),
    ("if zone == ZONE_S2_OOZ_TEST:\n\t\treturn _get_sonic2_ooz_test(act)", "LevelCatalog routes OOZ requests before Sonic 1 clamping"),
    ('"layout": "s2test/ooz1_layout128.bin"', "OOZ catalog uses exact foreground layout"),
    ('"background_layout": "s2test/ooz1_bg128.bin"', "OOZ catalog uses exact Plane-B layout"),
    ('"s2_objects": "s2test/ooz1_objects.bin"', "OOZ catalog retains exact placement stream"),
    ('"s2_rings": "s2test/ooz1_rings.bin"', "OOZ catalog retains exact ring stream"),
    ('"chunk_word_format": "s2"', "OOZ uses retail Sonic 2 chunk-word decoding"),
    ('"background_mode": "s2ooz"', "OOZ selects dedicated source-shaped background deformation"),
    ('"s2_ooz": true', "OOZ level-definition flag is enabled"),
    ('"music_mode": "s2_ooz"', "OOZ level-definition music mode is explicit"),
    ('return Vector2i(ZONE_S2_MCZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_OOZ_TEST, 1)', "Completed MCZ2 now progresses into OOZ1"),
    ('if zone == ZONE_S2_OOZ_TEST:\n\t\t# Oil Ocean Act 2', "OOZ1 has explicit temporary post-act fallback until OOZ2 import"),
]: ck(token in cat,msg)
oozcat=func(cat,"_get_sonic2_ooz_test(requested_act: int = 1) -> Dictionary")
for token,msg in [
    ('"limit_right": 0x2F80', "OOZ1 catalog right boundary is $2F80"),
    ('"limit_bottom": 0x0680', "OOZ1 catalog bottom camera boundary is $680"),
    ('"palette": "palette/S2 Oil Ocean Zone.bin"', "OOZ1 loads retail palette"),
    ('"art_loads": [{"path":"s2test/ooz1_art.bin","tile":0,"compression":"raw"}]', "OOZ1 loads reconstructed retail VRAM bank at tile zero"),
]: ck(token in oozcat,msg)
ck("KEY_V:" in main and "_debug_warp(LevelCatalog.ZONE_S2_OOZ_TEST, 1)" in main, "V debug shortcut warps directly to OOZ1")
ck("const MUS_S2_OOZ := 0x19C" in audio, "OOZ receives dedicated non-colliding port music ID $19C")
ck("SonicAudio.play_music(SonicAudio.MUS_S2_OOZ, true)" in main, "Level music dispatcher starts OOZ music")
smps=json.loads((P/"data/s1/sound/s2_ehz_smps.json").read_text())
song=smps.get("music",{}).get(str(0x19C),{})
ck(song.get("name") == "Sonic 2 - Oil Ocean Zone", "SMPS database contains Oil Ocean Zone song")
ck(song.get("header",{}).get("tempo_mod") == 0xD0, "Imported OOZ song retains retail tempo modifier $D0")
ck(len(song.get("voices",[])) == 6, "Imported OOZ song retains six FM voices")

# ---------------------------------------------------------------------------
# PalCycle_OOZ and Animated_OOZ
# ---------------------------------------------------------------------------
palfunc=func(pal,"_tick_s2_ooz() -> Array[int]")
for token,msg in [
    ("pcyc_time -= 1", "OOZ palette timer decrements every VBlank"),
    ("pcyc_time = 7", "OOZ palette timer reloads retail value 7"),
    ("var start: int = pcyc_num & 3", "OOZ palette selects one of four source word offsets"),
    ("pcyc_num = (pcyc_num + 1) & 0xFFFF", "OOZ palette source frame advances one word per update"),
    ("42 + i", "OOZ cycling colors write CRAM indices 42..45"),
]: ck(token in palfunc,msg)
ck('s2_ooz_oil_cycle = _read_palette("S2 Oil Ocean Oil Cycle.bin")' in pal, "Palette cycler loads packaged CyclingPal_Oil")
ck("LevelCatalog.ZONE_S2_OOZ_TEST:\n\t\t\tchanged = _tick_s2_ooz()" in pal, "Palette dispatcher invokes PalCycle_OOZ only in OOZ")

for token,msg in [
    ("const S2_OOZ_PULSE_TILE = 0x2B6", "Animated_OOZ pulse destination is tile $2B6"),
    ("const S2_OOZ_SQUARE1_TILE = 0x2BA", "Animated_OOZ first square destination is tile $2BA"),
    ("const S2_OOZ_SQUARE2_TILE = 0x2BE", "Animated_OOZ second square destination is tile $2BE"),
    ("const S2_OOZ_OIL1_TILE = 0x2C2", "Animated_OOZ first oil destination is tile $2C2"),
    ("const S2_OOZ_OIL2_TILE = 0x2D2", "Animated_OOZ second oil destination is tile $2D2"),
    ("const S2_OOZ_PULSE_FRAMES = [[0,0x0B],[4,5],[8,9],[4,3]]", "Variable-timed OOZ pulse animation matches retail frame table"),
    ("const S2_OOZ_SQUARE_FRAMES = [[0,6],[4,6],[8,6],[0x0C,6]]", "OOZ square animation uses source offsets 0,4,8,$C with duration 6"),
    ("const S2_OOZ_OIL_FRAMES = [[0,0x11],[0x10,0x11],[0x20,0x11],[0x30,0x11],[0x20,0x11],[0x10,0x11]]", "OOZ oil animation matches source six-frame palindrome and duration $11"),
    ('s2_ooz_pulse = _read("res://data/s1/s2test/ooz_pulse_ball.bin")', "Animator loads retained OOZ pulse source"),
    ("_tick_s2_ooz_slot(4, S2_OOZ_OIL2_TILE", "Animator services all five retail OOZ Dynamic_Normal slots"),
    ("background.refresh_s2test_art_range(first_tile, tile_count)", "OOZ dynamic VRAM updates refresh cached Plane B tile references"),
]: ck(token in anim,msg)

# ---------------------------------------------------------------------------
# SwScrl_OOZ background path
# ---------------------------------------------------------------------------
for token,msg in [
    ('mode == "s2ooz"', "Background renderer recognizes s2ooz mode"),
    ("s2_ehz_plane_width = 6 * 128", "OOZ Plane B caches exact six-chunk horizontal repeat"),
    ("s2_ehz_plane_height = 4 * 128", "OOZ Plane B caches four authored rows"),
    ("_update_s2ooz(camera_model)", "Background update dispatch reaches SwScrl_OOZ path"),
]: ck(token in bg,msg)
bgfunc=func(bg,"_update_s2ooz(camera_model: SonicCamera) -> void")
for token,msg in [
    ("var bg_x: int = camera_x >> 3", "OOZ background X follows foreground at retail 1/8 rate"),
    ("var bg_y: int = (camera_y >> 3) + 0x50", "InitCam_OOZ vertical relation CameraY/8+$50 reproduced"),
    ("var base_scroll: int = -bg_x", "OOZ base Plane-B H-scroll uses negated background X"),
    ("(s2_ehz_vint_counter & 7) == 0", "OOZ ripple phase advances every eight VBlanks"),
    ("(s2_ehz_ripple_phase - 1) & 0x1F", "OOZ ripple source phase decrements modulo $20"),
    ("224 if y_term >= 0xB0 else 48 + y_term", "OOZ source first-band DBF count/clamp is reproduced"),
    ("base_scroll >> 3, 8", "OOZ medium-cloud 1/8 rate is represented"),
    ("base_scroll >> 4, 8", "OOZ slow-cloud 1/16 rate is represented"),
    ("base_scroll >> 2, 8", "OOZ fast-cloud 1/4 rate is represented"),
    ("for i in range(33)", "OOZ autonomous ripple emits source $21-line segment"),
    ("S2_EHZ_RIPPLE[(s2_ehz_ripple_phase + i)", "OOZ reuses exact retail SwScrl_RippleData") ,
    ("base_scroll, 72", "OOZ final source band emits $48 lines") ,
    ("ProjectSettings.get_setting(\"display/window/size/viewport_width\")", "OOZ renderer preserves project dynamic viewport width"),
]: ck(token in bgfunc,msg)
ck('mode in ["s2test", "s2cpz", "s2cnz", "s2htz", "s2ooz"]' in bg, "OOZ is included in targeted Plane-B animated-art refresh path")

# ---------------------------------------------------------------------------
# Global Object $07 oil and OOZ namespace isolation
# ---------------------------------------------------------------------------
for token,msg in [
    ("const S2_OOZ_OIL_SUPPORT_RECORD := -0x7007", "OOZ global oil owns a collision support identity outside placement indices"),
    ("const S2_OOZ_OIL_Y := 0x758", "Object $07 oil base Y is retail $758"),
    ("const S2_OOZ_OIL_WIDTH := 0x20", "Object $07 oil half-width is retail $20"),
    ("const S2_OOZ_OIL_MAX_SUBMERSION := 0x30", "Object $07 submersion counter starts at retail $30"),
    ('bool(level_definition.get("s2_ooz", false))', "Object manager gates global oil to OOZ levels"),
    ("_tick_s2_ooz_oil()", "OOZ global oil executes in native object pass"),
]: ck(token in om,msg)
oil=func(om,"_tick_s2_ooz_oil() -> void")
for token,msg in [
    ("p.standing_on_object and p.support_record_index == S2_OOZ_OIL_SUPPORT_RECORD", "Oil tests its own previous-frame standing ownership"),
    ("if ooz_oil_submersion <= 0:", "Oil checks suffocation before next sink decrement"),
    ("p.kill()", "Fully submerged Object $07 kills Sonic through normal death path"),
    ("ooz_oil_submersion -= 1", "Standing on oil sinks one pixel per frame"),
    ("ooz_oil_submersion += 1", "Leaving oil recovers its support depth one pixel per frame"),
    ("S2_OOZ_OIL_Y - ooz_oil_submersion", "Oil support height derives from source y_pos minus objoff_38"),
    ("var px: int = p.pixel_x()", "Global oil tracks Sonic's X every frame"),
    ("p.snap_supported_slope", "Already-owned oil support follows its sinking surface without recapture jitter"),
    ("p.resolve_platform_top", "Fresh oil contact uses native platform top crossing") ,
]: ck(token in oil,msg)
block='if bool(level_definition.get("s2_ooz", false)) and id in [0x19,0x1C,0x1F,0x33,0x3D,0x3F,0x48,0x4A,0x50]:\n\t\t\treturn S2UnsupportedObjectClass.new()'
ck(block in om, "OOZ-specific IDs are namespace-blocked instead of aliasing unrelated CPZ/ARZ/EHZ objects")
for shared in ["0x0D: return S2SignpostAdapterClass.new()", "0x26: return S2MonitorAdapterClass.new()", "0x36: return S2SpikesObjectClass.new()", "0x41: return S2SpringObjectClass.new()", "0x79: return LamppostObject.new()"]:
    ck(shared in om, f"Shared OOZ placement adapter remains available: {shared.split(':')[0]}")

# ---------------------------------------------------------------------------
# Phase 114 carried correction: asymmetric MCZ drill draw priority
# ---------------------------------------------------------------------------
setup=func(boss,"setup(owner: SonicObjectManager) -> void")
ck("digger_a_sprite = _make_sprite(4)" in setup, "MCZ main/first drill now draws in front of Eggman/vehicle overlap")
ck("digger_b_sprite = _make_sprite(1)" in setup, "MCZ offset/second drill now draws behind Eggman/vehicle overlap")
ck("vehicle_sprite = _make_sprite(2)" in setup and "face_sprite = _make_sprite(3)" in setup, "MCZ vehicle/Eggman relative layers stay unchanged")
ck("digger_b_sprite.position = Vector2(0x28 if facing_right else -0x28, 0)" in boss, "MCZ second drill retains retail facing-dependent side offset")
ck("digger_b_x_fixed -= 1 << 16" in boss and "digger_a_x_fixed += 1 << 16" in boss, "Detached MCZ drills retain source opposite-direction breakup")

# ---------------------------------------------------------------------------
# Direct supplied-retail-source confirmations
# ---------------------------------------------------------------------------
if S2 is not None:
    asm=(S2/"s2.asm").read_text(errors="replace")
    source_needles=[
        ("zoneTableEntry.w\t$0,\t$2F80,\t$0,\t$680\t; OOZ act 1", "Retail LevelSize confirms OOZ1 $2F80/$680 boundaries"),
        ("InitCam_OOZ:", "Retail source contains InitCam_OOZ"),
        ("lsr.w\t#3,d0\n\taddi.w\t#$50,d0", "Retail InitCam_OOZ confirms CameraY/8+$50"),
        ("SwScrl_OOZ:", "Retail source contains SwScrl_OOZ"),
        ("asl.l\t#5,d0\n\tadd.l\td0,(Camera_BG_X_pos).w", "Retail SwScrl_OOZ advances background X at 1/8 fixed-point rate"),
        ("moveq\t#$20,d1", "Retail OOZ ripple loop is $21 scanlines via DBF"),
        ("moveq\t#$47,d1", "Retail OOZ final constant band is $48 scanlines via DBF"),
        ("PalCycle_OOZ:", "Retail source contains PalCycle_OOZ"),
        ("move.w\t#7,(PalCycle_Timer).w", "Retail PalCycle_OOZ reload value is 7"),
        ("lea\t(Normal_palette_line3+$14).w,a1", "Retail OOZ palette writes Normal_palette_line3+$14"),
        ("Obj07_Init:", "Retail source contains global Object $07 oil"),
        ("move.w\t#$758,y_pos(a0)", "Retail Object $07 oil Y=$758 confirmed"),
        ("move.b\t#$20,width_pixels(a0)", "Retail Object $07 width=$20 confirmed"),
        ("move.b\t#$30,oil_char1submersion(a0)", "Retail Object $07 initial submersion=$30 confirmed"),
        ("Animated_OOZ:\tzoneanimstart", "Retail source contains Animated_OOZ table"),
        ("zoneanimdecl -1, ArtUnc_OOZPulseBall, ArtTile_ArtUnc_OOZPulseBall, 4, 4", "Retail pulse Dynamic_Normal declaration confirmed"),
        ("zoneanimdecl 6, ArtUnc_OOZSquareBall1, ArtTile_ArtUnc_OOZSquareBall1, 4, 4", "Retail square Dynamic_Normal declaration confirmed"),
        ("zoneanimdecl $11, ArtUnc_Oil1, ArtTile_ArtUnc_Oil1, 6,$10", "Retail oil Dynamic_Normal declaration confirmed"),
    ]
    for needle,msg in source_needles:
        ck(needle in asm,msg)
    src_start=(S2/"startpos/OOZ_1.bin").read_bytes()
    ck((be16(src_start,0),be16(src_start,2)) == (0x60,0x6AC), "Retail OOZ_1 start-position file confirms $0060,$06AC")
    ck((P/"data/s1/s2test/ooz1_start.bin").read_bytes() == src_start, "Packaged OOZ1 start file is byte-identical to retail")
    ck((P/"data/s1/s2test/ooz1_objects.bin").read_bytes() == (S2/"level/objects/OOZ_1.bin").read_bytes(), "Packaged OOZ1 object stream is byte-identical to retail")
    ck((P/"data/s1/s2test/ooz1_rings.bin").read_bytes() == (S2/"level/rings/OOZ_1.bin").read_bytes(), "Packaged OOZ1 ring stream is byte-identical to retail")
    ck((P/"data/s1/palette/S2 Oil Ocean Zone.bin").read_bytes() == (S2/"art/palettes/OOZ.bin").read_bytes(), "Packaged OOZ palette is byte-identical to retail")
    ck((P/"data/s1/palette/S2 Oil Ocean Oil Cycle.bin").read_bytes() == (S2/"art/palettes/OOZ Oil.bin").read_bytes(), "Packaged CyclingPal_Oil is byte-identical to retail")

# Python tooling compilation and basic GDScript structural sanity.
for rel in ["tools/import_s2_ooz1_phase115.py","tools/validate_phase115.py","tools/validate_phase114.py"]:
    try:
        py_compile.compile(str(P/rel), doraise=True)
        ck(True, f"{rel} compiles")
    except Exception as e:
        ck(False, f"{rel} compiles: {e}")

# No Godot binary is present in the build environment, but catch common edit
# accidents: modified files must have no conflict markers and all introduced
# functions must begin at column zero while their bodies remain tab-indented.
for rel in [
    "scripts/data/level_catalog.gd","scripts/main.gd","scripts/audio/sonic_audio.gd",
    "scripts/render/level_palette_cycler.gd","scripts/render/level_art_animator.gd",
    "scripts/render/ghz_background_renderer.gd","scripts/objects/object_manager.gd",
    "scripts/objects/s2_mcz_boss_object.gd",
]:
    t=txt(rel)
    ck("<<<<<<<" not in t and ">>>>>>>" not in t and "=======" not in t, f"{rel} contains no merge-conflict markers")

bad=[m for ok,m in checks if not ok]
print(f"\n{len(checks)-len(bad)}/{len(checks)} checks passed")
if bad:
    print("Failures:")
    for m in bad: print(" - "+m)
    raise SystemExit(1)
