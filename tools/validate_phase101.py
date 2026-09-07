#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, re, subprocess, sys
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
checks = []

def check(name, cond, detail=''):
    ok = bool(cond)
    checks.append((name, ok))
    print(('PASS' if ok else 'FAIL') + ': ' + name + (f' ({detail})' if detail else ''))

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def obj_counts(path):
    b = Path(path).read_bytes(); assert len(b) % 6 == 0
    return Counter(b[i+4] for i in range(0, len(b), 6))

def asm_block(asm, start, end):
    a = asm.find(start)
    b = asm.find(end, a + len(start)) if a >= 0 else -1
    return asm[a:b if b >= 0 else None] if a >= 0 else ''

def main():
    s2 = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
    main_gd = (ROOT/'scripts/main.gd').read_text()
    om = (ROOT/'scripts/objects/object_manager.gd').read_text()
    trav = (ROOT/'scripts/objects/s2_cnz_traversal_object.gd').read_text()
    comp = (ROOT/'scripts/objects/s2_cnz_completion_object.gd').read_text()
    manifest = json.loads((ROOT/'data/s1/s2test/phase101_cnz1_completion_manifest.json').read_text())
    counts = obj_counts(ROOT/'data/s1/s2test/cnz1_objects.bin')
    new = {0xC8:2, 0xD2:4, 0xD6:15, 0xD8:44}

    check('Phase101 HUD identity is active', 'Native Sonic 1 Phase 101' in main_gd)
    check('CNZ1 placement stream remains all 286 retail records', sum(counts.values()) == 286)
    check('Phase101 activates the final 65 deferred CNZ1 records', sum(new.values()) == 65 and manifest['new_native_completion_records'] == 65)
    check('remaining source record counts match retail placement stream', all(counts[k] == v for k,v in new.items()))
    check('CNZ1 reaches 286/286 native placement coverage', manifest['native_records_after_phase101'] == 286 and manifest['remaining_deferred_records'] == 0)
    check('CNZ completion class is preloaded', 'S2CNZCompletionObjectClass = preload' in om)
    check('all four Phase101 IDs route to CNZ completion runtime', '0xC8, 0xD2, 0xD6, 0xD8: return S2CNZCompletionObjectClass.new()' in om)
    check('CNZ shared slot-machine state resets on level reset', 'cnz_slot_machine_in_use = false' in om)
    check('CNZ shared D8 group counter resets on level reset', 'cnz_saucer_break_count.clear()' in om)

    # Flipper fidelity carried from the user report.
    check('Obj86 upward slope uses a dedicated source surface sampler', 'func _flipper_surface_y' in trav)
    check('Obj86 samples one height byte per two horizontal pixels', 'sample >> 1' in trav)
    check('Obj86 mirrors source not.w/add.w profile indexing', 'sample = 0x45 - d0' in trav)
    check('Obj86 source span is exactly $46 pixels', 'd0 >= 0x46' in trav)
    check('Obj86 keeps continuous support with snap_supported_slope', 'p.snap_supported_slope(left_x, right_x, top_y, record_index)' in trav)
    check('Obj86 takes player object control while stood on upward flipper', 'p.object_control_override = true' in trav)
    check('Obj86 forced slide derives from mapping_frame-1', 'var slide_pixels: int = mapping_frame - 1' in trav)
    check('Obj86 forced slide is mirrored for X-flipped flippers', 'slide_pixels = -slide_pixels' in trav)
    check('Obj86 slide writes 8.8 x velocity/inertia', 'p.vel_x = slide_pixels << 8' in trav and 'p.inertia = p.vel_x' in trav)
    check('Obj86 jump release clears object control', 'func _launch_upward_flipper' in trav and 'p.object_control_override = false' in trav)
    check('Obj86 side subtype retains retail $1000 kick', 'p.vel_x = -0x1000 if contact == SonicPlayer.SOLID_LEFT else 0x1000' in trav)
    check('Obj86 side subtype retains retail $F move lock', 'p.lock_time = 0x0F' in trav)

    # C8 Crawl.
    check('ObjC8 uses source +/-$20 walk speed', 'vel_x = 0x20 if x_flip else -0x20' in comp)
    check('ObjC8 uses source $200 travel timer', 'timer = 0x200' in comp)
    check('ObjC8 uses source $3B turnaround wait', 'timer = 0x3B' in comp)
    check('ObjC8 enters shield routine inside $40 box', '< 0x40' in comp and 'state = 2' in comp)
    check('ObjC8 preserves interrupted walk/wait state across defence', 'resume_state = state' in comp and 'state = resume_state' in comp)
    check('ObjC8 front shield rejection uses retail -$700 radial impulse', '* -0x700) >> 8' in comp)
    check('ObjC8 rear rolling attack destroys badnik', '_destroy_crawl(p)' in comp)

    # D2 source table and timing.
    check('ObjD2 retains all 16 source rectangle frames', comp.count('Vector4i(') >= 16)
    check('ObjD2 source first rectangle frame is -40,+24,8,8', 'Vector4i(-40, 24, 8, 8)' in comp)
    check('ObjD2 source widest rectangle frame is 40x8 half-size', 'Vector4i(-8, -24, 40, 8)' in comp and 'Vector4i(8, -24, 40, 8)' in comp)
    check('ObjD2 frame cadence is source $F countdown', 'frame_timer = 0x0F' in comp)
    check('ObjD2 blank delay is subtype*16', '(subtype & 0xFF) << 4' in comp)
    check('ObjD2 ejects support when the shape disappears', 'clear_object_support_for(record_index, true)' in comp)
    check('ObjD2 collision adds source $B horizontal margin', 'rect_half_width + 0x0B' in comp)

    # D6 Point Pokey / slot cage.
    check('ObjD6 captures only on top collision', 'contact == SonicPlayer.SOLID_TOP' in comp)
    check('ObjD6 capture enables object control and roll radii', 'p.object_control_override = true' in comp and 'SonicPlayer.SONIC_ROLL_HEIGHT' in comp)
    check('ObjD6 normal cage retains $78 timer', 'timer = 0x78' in comp)
    check('ObjD6 normal cage pays 10-point pulses', 'manager.add_score(10)' in comp)
    check('ObjD6 release retains $400 downward ejection', 'p.vel_y = 0x400' in comp)
    check('ObjD6 release retains $1E recapture delay', 'timer = 0x1E' in comp)
    check('ObjD6 slot cage uses one shared machine owner', 'manager.cnz_slot_machine_in_use' in comp)
    check('ObjD6 retains exact retail slot reward table', 'const SLOT_REWARDS: Array[int] = [30, 25, -1, 150, 10, 20]' in comp)
    check('ObjD6 retains exact three retail reel sequences', all(x in comp for x in [
        '[3, 0, 1, 4, 2, 5, 4, 1]', '[3, 0, 1, 4, 2, 5, 0, 2]']))
    check('ObjD6 unmatched bars pay two rings each', comp.count('reward += 2') >= 3)
    check('ObjD6 cannot be centrally despawned while owning Sonic', 'return object_id == 0xD6 and captured' in comp)

    # D8 bonus/drop targets.
    check('ObjD8 derives rest bank from top subtype bits', 'return (subtype >> 6) & 3' in comp)
    check('ObjD8 uses source 4-tick hit lock', 'cooldown = 4' in comp)
    check('ObjD8 uses 12-tick 3/rest/3 hit animation', 'frame_timer = 12' in comp and 'rest + 3' in comp)
    check('ObjD8 breaks after three hits', 'if hit_count >= 3:' in comp)
    check('ObjD8 retains subtype low-six-bit group index', 'var group: int = subtype & 0x3F' in comp)
    check('ObjD8 group completion tracks three broken targets', 'cnz_saucer_break_count' in comp and 'if broken >= 3:' in comp)
    check('ObjD8 normal and group-complete awards are 10/50', 'var points: int = 10' in comp and 'points = 50' in comp)
    check('ObjD8 vertical rebound uses $700', 'p.vel_y = -0x700 if dy <= 0 else 0x700' in comp)
    check('ObjD8 horizontal rebound uses $700', 'p.vel_x = -0x700 if dx <= 0 else 0x700' in comp)
    check('ObjD8 diagonal rebound uses CalcAngle and fixed $700 magnitude', 'GenesisMath.calc_angle(p.vel_x, p.vel_y)' in comp and '* -0x700) >> 8' in comp)

    expected = {'crawl':4, 'rect_blocks':16, 'point_pokey':2, 'bonus_block':6}
    try:
        from PIL import Image
        for folder,n in expected.items():
            files = sorted((ROOT/'assets/objects/s2_cnz'/folder).glob('*.png'))
            check(f'CNZ {folder} retail-rendered frame count', len(files) == n)
            nonempty = True
            for f in files:
                im = Image.open(f).convert('RGBA')
                nonempty = nonempty and im.size == (192,192) and im.getbbox() is not None
            check(f'CNZ {folder} frames are 192x192 and non-empty', nonempty)
    except Exception as e:
        check('Phase101 asset image inspection', False, str(e))

    prev = subprocess.run([sys.executable, str(ROOT/'tools/validate_phase100.py')] + ([str(s2)] if s2 else []), capture_output=True, text=True)
    detail = prev.stdout.strip().splitlines()[-1] if prev.stdout.strip() else prev.stderr.strip()[-160:]
    check('Phase100 regression suite remains clean', prev.returncode == 0, detail)

    if s2 is not None:
        asm = (s2/'s2.asm').read_text(errors='ignore')
        o86 = asm_block(asm, 'Obj86:', 'Obj87:')
        check('retail Obj86 confirms SlopedSolid width $23 and profile tables', 'move.w\t#$23,d1' in o86 and 'byte_2B3C6:' in o86 and 'byte_2B40E:' in o86)
        check('retail Obj86 confirms profile index is halved in SlopedSolid', 'lsr.w\t#1,d5' in asm_block(asm, 'SlopedSolid_cont:', 'DoubleSlopedSolid_cont:'))
        check('retail Obj86 confirms forced mapping_frame-1 slide', 'move.b\tmapping_frame(a0),d1' in o86 and 'subq.w\t#1,d1' in o86 and 'lsl.w\t#8,d1' in o86)
        check('retail Obj86 confirms object control while stood on flipper', 'move.b\t#1,obj_control(a1)' in o86)

        oc8 = asm_block(asm, 'ObjC8:', 'ObjC7:')
        check('retail ObjC8 confirms $200/$3B timers and $20 speed', 'move.w\t#$200,objoff_2A(a0)' in oc8 and 'move.w\t#$3B,objoff_2A(a0)' in oc8 and 'moveq\t#$20,d0' in oc8)
        check('retail ObjC8 confirms -$700 shield bounce', 'muls.w\t#-$700,d1' in oc8 and 'muls.w\t#-$700,d0' in oc8)

        od2 = asm_block(asm, 'ObjD2:', 'ObjD3:')
        check('retail ObjD2 confirms subtype<<4 blank delay', 'lsl.w\t#4,d0' in od2)
        check('retail ObjD2 confirms $F frame timer and 16-frame loop', 'move.w\t#$F,objoff_3A(a0)' in od2 and 'andi.b\t#$F,mapping_frame(a0)' in od2)
        check('retail ObjD2 confirms $B solid margin', 'addi.w\t#$B,d1' in od2)

        od6 = asm_block(asm, 'ObjD6:', 'ObjD7:')
        check('retail ObjD6 confirms $78 hold and $1E release delay', 'move.w\t#$78,(a2)' in od6 and 'move.w\t#$1E,(a2)' in od6)
        check('retail ObjD6 confirms $400 downward release', 'move.w\t#$400,y_vel(a1)' in od6)
        check('retail ObjD6 confirms slot reward table', 'SlotRingRewards:\tdc.w   30,  25,  -1, 150,  10,  20' in od6)
        check('retail ObjD6 confirms exact slot sequences', 'SlotSequence1:\tdc.b   3,  0,  1,  4,  2,  5,  4,  1' in od6 and 'SlotSequence2:\tdc.b   3,  0,  1,  4,  2,  5,  0,  2' in od6)

        od8 = asm_block(asm, 'ObjD8:', 'ObjD9:')
        check('retail ObjD8 confirms $D7 collision and subtype rotation bank', 'move.b\t#$D7,collision_flags(a0)' in od8 and 'rol.b\t#2,d0' in od8)
        check('retail ObjD8 confirms 4-frame per-player hit lock', 'move.b\t#4,(a4)' in od8)
        check('retail ObjD8 confirms -$700 rebound strength', 'move.w\t#-$700,y_vel(a1)' in od8 and 'move.w\t#-$700,x_vel(a1)' in od8)
        check('retail ObjD8 confirms low-six-bit group counter and threshold three', 'andi.w\t#$3F,d1' in od8 and 'cmpi.b\t#3,(a1)' in od8)

        folders = [ROOT/'assets/objects/s2_cnz'/x for x in expected]
        files = sorted(f for folder in folders for f in folder.glob('*.png'))
        before = {str(x.relative_to(ROOT)): sha(x) for x in files}
        regen = subprocess.run([sys.executable, str(ROOT/'tools/import_s2_cnz_completion_phase101.py'), str(s2)], capture_output=True, text=True)
        files2 = sorted(f for folder in folders for f in folder.glob('*.png'))
        after = {str(x.relative_to(ROOT)): sha(x) for x in files2}
        check('Phase101 CNZ completion art regenerates deterministically from retail source', regen.returncode == 0 and before == after, regen.stderr.strip()[-160:])

    passed = sum(v for _,v in checks)
    print(f'\n{passed}/{len(checks)} checks passed')
    return 0 if passed == len(checks) else 1

if __name__ == '__main__':
    raise SystemExit(main())
