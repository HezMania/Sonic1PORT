#!/usr/bin/env python3
from pathlib import Path
import subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
checks = []

def check(name, cond, detail=''):
    ok = bool(cond)
    checks.append((name, ok))
    print(('PASS' if ok else 'FAIL') + ': ' + name + (f' ({detail})' if detail else ''))

def block(text, start, end):
    a = text.find(start)
    if a < 0:
        return ''
    b = text.find(end, a + len(start))
    return text[a:] if b < 0 else text[a:b]

def main():
    s2 = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
    main_gd = (ROOT/'scripts/main.gd').read_text()
    trav = (ROOT/'scripts/objects/s2_cnz_traversal_object.gd').read_text()
    comp = (ROOT/'scripts/objects/s2_cnz_completion_object.gd').read_text()
    shared = (ROOT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    art = (ROOT/'scripts/render/level_art_animator.gd').read_text()
    bg = (ROOT/'scripts/render/ghz_background_renderer.gd').read_text()
    player = (ROOT/'scripts/player/sonic_player.gd').read_text()

    check('Phase102-or-later HUD identity is active', ('Native Sonic 1 Phase 102' in main_gd) or ('Native Sonic 1 Phase 103' in main_gd) or ('Native Sonic 1 Phase 104' in main_gd))

    # User-report item 1: D6 cages in front of Sonic.
    check('ObjD6 cage is raised above normal Sonic z-order', 'point_pokey/00.png", 20)' in comp)
    check('ObjD6 front-layer intent is documented against source priority order', 'source priority 1 while Sonic uses priority 2' in comp)

    # User-report item 2: upward flipper low-end slide direction.
    flipper = block(trav, 'func _tick_flipper()', 'func _flipper_surface_y')
    check('Obj86 non-flipped flipper negates mapping_frame-1 exactly like source', 'if not x_flip:' in flipper and 'slide_pixels = -slide_pixels' in flipper)
    check('Obj86 flipped flipper leaves mapping_frame-1 sign untouched', flipper.find('if not x_flip:') < flipper.find('slide_pixels = -slide_pixels'))
    check('Obj86 still writes forced slide to x velocity and inertia', 'p.vel_x = slide_pixels << 8' in flipper and 'p.inertia = p.vel_x' in flipper)
    check('Obj86 still samples 36 source heights over $46 pixels', 'sample >> 1' in trav and 'd0 >= 0x46' in trav)

    # User-report item 3: D8 source collision is $D7 -> Touch_Sizes[$17] = 8x8.
    d8 = block(comp, 'func _tick_bonus_block()', 'func _bonus_rebound')
    check('ObjD8 native hit test uses raw 8x8 source half-size', '8 + p.width_radius' in d8 and '8 + p.height_radius' in d8)
    check('ObjD8 no longer uses the old $12 manual half-size', '0x12 + p.width_radius' not in d8 and '0x12 + p.height_radius' not in d8)

    # User-report item 4: D4 source $2B already contains Sonic $0B margin.
    d4 = block(trav, 'func _tick_big_block()', 'func _init_elevator')
    check('ObjD4 native solid uses raw $20 block half-width', 'resolve_solid_box(new_x, new_y, 0x20, 0x20' in d4)
    check('ObjD4 moving support bounds also use raw $20 width', 'new_x-0x20, new_x+0x20' in d4)
    check('ObjD4 does not pass source $2B center envelope into native collision', 'resolve_solid_box(new_x, new_y, 0x2B' not in d4)

    # User-report item 5: Obj85 flash interval accelerates with compression.
    launcher = block(trav, 'func _tick_launcher()', 'func _release_launcher')
    check('Obj85 has persistent flash countdown state', 'launcher_flash_timer' in trav and 'launcher_flash_frame' in trav)
    check('Obj85 flash countdown is remaining travel divided by two', 'launcher_flash_timer = (cap - compression) >> 1' in launcher)
    check('Obj85 flash toggles source mapping frames 1 and 5', 'launcher_flash_frame = 1 if launcher_flash_frame == 5 else 5' in launcher)
    check('Obj85 keeps four-frame compression cadence', 'if press_divider >= 4:' in launcher)
    check('Obj85 uses $20 vertical and $1C diagonal compression caps', '0x1C if diagonal else 0x20' in launcher)

    # User-report item 6: CNZ mutable animation art must refresh both planes.
    check('CNZ animated tiles notify Plane B cache as well as foreground', 'LevelCatalog.ZONE_S2_CNZ_TEST' in block(art, 'func _notify_art_change', 'static func _read'))
    check('CNZ Plane-B cache accepts live animated-art patching', 'mode in ["s2test", "s2cpz", "s2cnz"]' in bg)
    check('CNZ retains two independent 16-tile animation streams', 'for slot in range(2):' in block(art, 'func _tick_s2_cnz()', 'func _tick_s2_cpz'))

    # User-report item 7: Obj74 + D5 entry interaction.
    obj74 = block(shared, 'func _tick_invisible_block()', '# -----------------------------------------------------------------------------\n# Object $78')
    check('Obj74 native invisible solid uses raw subtype width', 'active_width, half_h' in obj74)
    check('Obj74 no longer double-adds source $0B Sonic margin', 'active_width + 11' not in obj74)
    elevator = block(trav, 'func _tick_elevator()', 'func _init_hex_bumper')
    check('ObjD5 uses dedicated PlatformObjectD5-style helper', '_elevator_platform_top' in elevator)
    check('ObjD5 helper refuses to steal support from another object', 'p.standing_on_object and p.support_record_index != record_index' in elevator)
    check('ObjD5 keeps raw $10 platform half-width', 'spawn_x-0x10, spawn_x+0x10' in elevator)

    # Shared native bridge semantics that justify the raw-width translations.
    bridge = block(player, 'func resolve_solid_box_contact', 'func can_attack_object')
    check('native solid bridge expands player extents itself', 'player_left = x - width_radius' in bridge and 'player_right = x + width_radius' in bridge)

    # Full Phase101 regression after the semantic validator update.
    prev = subprocess.run([sys.executable, str(ROOT/'tools/validate_phase101.py')] + ([str(s2)] if s2 else []), capture_output=True, text=True)
    detail = prev.stdout.strip().splitlines()[-1] if prev.stdout.strip() else prev.stderr.strip()[-200:]
    check('Phase101 regression suite remains clean', prev.returncode == 0, detail)

    if s2 is not None:
        asm = (s2/'s2.asm').read_text(errors='ignore')
        o85 = block(asm, 'Obj85:', 'Obj86:')
        o86 = block(asm, 'Obj86:', 'Obj87:')
        od4 = block(asm, 'ObjD4:', 'ObjD5:')
        od5 = block(asm, 'ObjD5:', 'ObjD6:')
        od6 = block(asm, 'ObjD6:', 'ObjD7:')
        od8 = block(asm, 'ObjD8:', 'ObjD9:')
        o74 = block(asm, 'Obj74:', 'Obj7C:')
        pd5 = block(asm, 'PlatformObjectD5:', 'PlatformObject11_cont:')
        animated = block(asm, 'Animated_CNZ:', 'Animated_CNZ_2P:')
        sonic_init = block(asm, 'Sonic_Init:', 'Tails_Init:')
        touch = block(asm, 'Touch_Sizes:', 'Touch_ChkValue')

        check('retail Obj86 confirms non-flipped branch negates forced slide', 'btst\t#0,status(a0)' in o86 and 'bne.s\tloc_2B272' in o86 and 'neg.w\td1' in o86)
        check('retail Obj86 confirms mapping_frame-1 forced slide', 'move.b\tmapping_frame(a0),d1' in o86 and 'subq.w\t#1,d1' in o86)
        check('retail ObjD8 confirms $D7 collision selector', 'move.b\t#$D7,collision_flags(a0)' in od8)
        check('retail Touch_Sizes $17 is 8x8', 'dc.b   8,  8\t; $17' in touch)
        check('retail ObjD4 true sprite half-width is $20', 'move.b\t#$20,width_pixels(a0)' in od4)
        check('retail ObjD4 passes $2B only to center-based SolidObject', 'move.w\t#$2B,d1' in od4 and 'SolidObject' in od4)
        check('retail Obj85 flash reset is ($20-compression)>>1', 'subi.w\t#$20,d0' in o85 and 'lsr.w\t#1,d0' in o85 and 'move.b\td0,objoff_33(a0)' in o85)
        check('retail Obj85 diagonal flash reset uses $1C', 'subi.w\t#$1C,d0' in o85)
        check('retail Obj85 toggles mapping bit2 on flash', 'bchg\t#2,mainspr_mapframe(a0)' in o85)
        check('retail Animated_CNZ declares two 16-tile streams', animated.count('zoneanimdecl -1, ArtUnc_CNZFlipTiles') == 2 and animated.count('$10,$10') >= 2)
        check('retail Obj74 stores raw width then adds $B only for SolidObject', 'move.b\td0,width_pixels(a0)' in o74 and 'addi.w\t#$B,d1' in o74)
        check('retail PlatformObjectD5 skips when player already stands elsewhere', 'btst\t#3,status(a1)' in pd5 and 'bne.s\tloc_19D8E' in pd5)
        check('retail ObjD5 uses PlatformObjectD5', 'PlatformObjectD5' in od5)
        check('retail ObjD6 uses priority 1', 'move.b\t#1,priority(a0)' in od6)
        check('retail Sonic uses priority 2', 'move.b\t#2,priority(a0)' in sonic_init)

    passed = sum(ok for _, ok in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed == len(checks) else 1

if __name__ == '__main__':
    raise SystemExit(main())
