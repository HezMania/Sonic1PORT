#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, re, subprocess, sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / "data/s1/s2test"
checks = []

def check(ok, msg):
    checks.append((bool(ok), msg))
    print(("PASS" if ok else "FAIL") + ": " + msg)

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def parse_paths(path: Path):
    groups=[]; cur=None
    for line in path.read_text().splitlines():
        if re.match(r"word_[0-9A-Fa-f]+:\s*obj1E67Size", line):
            cur=[]; groups.append(cur); continue
        if cur is not None:
            if re.match(r"word_[0-9A-Fa-f]+_End", line):
                cur=None; continue
            m=re.search(r"dc\.w\s+\$([0-9A-Fa-f]+),\s*\$([0-9A-Fa-f]+)", line)
            if m: cur.append([int(m.group(1),16),int(m.group(2),16)])
    return groups

def main():
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    obj=(ROOT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    importer=ROOT/'tools/import_s2_cpz_traversal_phase91.py'
    data=(D/'cpz1_objects.bin').read_bytes()
    counts=Counter(data[i+4] for i in range(0,len(data),6))
    expected={0x03:60,0x0B:4,0x0D:1,0x19:7,0x1B:8,0x1D:7,0x1E:9,0x26:19,0x2D:2,0x32:4,0x41:5,0x6B:2,0x74:2,0x78:2,0x79:3,0x7B:5,0xA5:10,0xA6:1,0xA7:2}
    check(len(data)==918 and len(data)//6==153 and dict(counts)==expected, 'all 153 retail CPZ1 placement records remain unchanged by ID distribution')

    old_supported={0x03,0x0D,0x26,0x41,0x79}
    new_supported={0x0B,0x19,0x1B,0x1E,0x2D,0x32,0x6B,0x74,0x78,0x7B}
    supported=old_supported|new_supported
    check(sum(v for k,v in counts.items() if k in supported)==133, 'Phase 91 raises CPZ1 runtime coverage to 133/153 placed objects')
    deferred={0x1D,0xA5,0xA6,0xA7}
    check(sum(v for k,v in counts.items() if k in deferred)==20 and set(counts)-supported==deferred, 'only 20 CPZ1 droplet/Badnik placements remain deferred')

    dispatch='0x0B, 0x19, 0x1B, 0x1E, 0x2D, 0x32, 0x6B, 0x74, 0x78, 0x7B: return S2CPZTraversalObjectClass.new()'
    check('S2CPZTraversalObjectClass' in om and dispatch in om, 'all ten Phase 91 CPZ object IDs dispatch through the isolated Sonic 2 class')
    check('0xA5' not in dispatch and 'S2UnsupportedObjectClass.new()' in om, 'deferred S2 IDs still remain safely inert rather than falling into Sonic 1 objects')

    path_file=D/'cpz_spin_tube_paths.json'
    path_db=json.loads(path_file.read_text())
    check(len(path_db.get('entry',[]))==12 and len(path_db.get('main',[]))==15 and len(path_db.get('continue_map',[]))==64, 'CPZ spin-tube package has 12 entry paths, 15 main selectors and 64 continuation bytes')
    check(path_db['main'][0]==path_db['main'][1], 'Obj1E main selector table preserves the duplicated word_22EA6 entries 0/1')
    expected_continue=[2,1,0,0,-1,3,0,0,4,-2,0,0,-3,-4,0,0,-5,-5,0,0,7,6,0,0,-7,-6,0,0,8,9,0,0,-8,-9,0,0,11,10,0,0,12,0,0,0,-11,-10,0,0,-12,0,0,0,0,13,0,0,-13,14,0,0,0,-14,0,0]
    check(path_db['continue_map']==expected_continue, 'Obj1E byte_227BE continuation table is exact')

    asset_counts={'tipping':5,'platform':1,'booster':3,'barrier':1,'breakblock':1,'stair':1,'tube_spring':5}
    check(all(len(list((ROOT/'assets/objects/s2_cpz'/folder).glob('*.png')))==count for folder,count in asset_counts.items()), 'all source-rendered CPZ traversal sprite frames are packaged')

    check('0x0A00 if (subtype & 2) != 0 else 0x1000' in obj and 'p.lock_time = 15' in obj and 'directed_speed < 0x1000' in obj, 'Obj1B uses retail yellow/red boost strengths, direction lock and super-speed guard')
    check('absi(p.pixel_x() - spawn_x) >= 16' in obj and 'absi(p.pixel_y() - spawn_y) >= 16' in obj and 'if p.in_air:' in obj, 'Obj1B activation remains the retail grounded 32x32 detector')

    check('selector_table: Array[int] = [2,2,2,2,2,2,2,2,2,2,0,2,0,1,2,1]' in obj and 'int(manager.elapsed_frames / 60) & 1' in obj, 'Obj1E preserves selector table and Timer_second parity branch')
    check('p.object_control_override = true' in obj and 'p.inertia = 0x800' in obj and 'SonicAudio.SFX_ROLL' in obj, 'Obj1E captures Sonic into rolling object-control state at $800 inertia')
    check('selector < 0' in obj and 'points.reverse()' in obj and 'wait_until_clear' in obj, 'Obj1E supports reverse main paths and source-style entry exit cooldown')
    check('return object_id == 0x1E and tube_active' in obj, 'active spin-tube traversal cannot be killed by central offscreen despawn')

    check('_s2_source_osc_pos = [0x0080' in om and '0x3848,0x2080,0x3080,0x5080,0x7080' in om and '0x00EE,0x00B4,0x010E,0x01C2,0x0276' in om, 'S2 OscillateNum state starts from exact retail positions/rates')
    check('1 << (15 - i)' in om and 'var accel: Array[int] = [2,2,2,2,4,8,8,4,2,2,2,3,5,7,2,2]' in om, 'S2 OscillateNum uses source bit order and acceleration table')
    check('manager.s2_source_osc_byte(0x0C)' in obj and 'manager.s2_source_osc_byte(0x1C)' in obj, 'Obj19 CPZ platforms read the source $0C/$1C oscillator channels')
    check('object_vel_y = GenesisMath.s16(object_vel_y + accel)' in obj and 'var target = orig_y - 0x60' in obj, 'Obj19 subtypes 6/7 use retail ±8 acceleration around Y-$60')

    check('manager.s2_source_osc_byte(0x2C)' in obj and 'manager.s2_source_osc_word(0x2E)' in obj and 'square_phase = (square_phase + 1) & 3' in obj, 'Obj6B CPZ pair follows retail $2C/$2E square-path oscillator and quadrant changes')
    check('var radius = 0x30' in obj and 'resolve_solid_box_contact(nx, ny, 27, 16' in obj, 'Obj6B subtype $19 retains source $30 square radius and solid dimensions')

    check('barrier_raise = mini(0x40, barrier_raise + 8)' in obj and 'barrier_raise = maxi(0, barrier_raise - 8)' in obj, 'Obj2D barrier raises/lowers by 8 pixels to the source $40 limit')
    check('spawn_x - 0x200' in obj and 'spawn_x + 0x200' in obj and 'spawn_y - 0x20' in obj, 'Obj2D one-way activation rectangles preserve source direction and vertical range')

    check('contact == SonicPlayer.SOLID_TOP and p.rolling' in obj and 'p.vel_y = -0x300' in obj, 'Obj32 CPZ block breaks only under a rolling stood-on Sonic and applies source bounce velocity')
    check('active_width = ((subtype & 0xF0) + 0x10) >> 1' in obj and '((subtype & 0x0F) + 1) << 3' in obj, 'Obj74 invisible-solid subtype width/height formulas match retail source')
    check('stair_delay = 0x1E' in obj and 'clampi(stair_progress + direction, -0x80, 0x80)' in obj and 'half + quarter' in obj, 'Obj78 staircases retain $1E delay, ±$80 travel and 1,3/4,1/2,1/4 offsets')
    check('p.vel_y = -0x0A80 if (subtype & 2) != 0 else -0x1000' in obj and 'p.force_add_pixel_offset(0, 4)' in obj, 'Obj7B pipe spring retains source strengths and 4-pixel launch inset')
    check('pipe_proximity_timer = 30' in obj and 'current_frame_one' in obj and 'tube_spring", 3' in obj, 'Obj7B cover uses one-shot launch frame plus source-shaped 30-tick proximity sequence')

    r=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase90_hotfix1.py')],cwd=ROOT,text=True,capture_output=True)
    check(r.returncode==0, 'complete verified Phase 90 Hotfix 1 regression suite still passes')

    if len(sys.argv)>1:
        source=Path(sys.argv[1])
        check(data==(source/'level/objects/CPZ_1.bin').read_bytes(), 'packaged CPZ1 object layout is byte-identical to supplied retail source')
        src_entry=parse_paths(source/'misc/obj1E_a.asm')
        src_unique=parse_paths(source/'misc/obj1E_b.asm')
        src_main=[src_unique[0],src_unique[0]]+src_unique[1:]
        check(path_db['entry']==src_entry, 'all 12 generated Obj1E entry paths are byte-coordinate exact')
        check(path_db['main']==src_main, 'all 15 generated Obj1E main selector paths are byte-coordinate exact')

        before={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'assets/objects/s2_cpz').rglob('*.png')}
        before[str(path_file.relative_to(ROOT))]=sha(path_file)
        rr=subprocess.run([sys.executable,str(importer),str(source)],cwd=ROOT,text=True,capture_output=True)
        check(rr.returncode==0, 'Phase 91 sprite/path importer regenerates successfully from retail source')
        after={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'assets/objects/s2_cpz').rglob('*.png')}
        after[str(path_file.relative_to(ROOT))]=sha(path_file)
        check(before==after, 'Phase 91 generated CPZ sprite/path assets are deterministic')

    failed=[msg for ok,msg in checks if not ok]
    print(f"\n{len(checks)-len(failed)}/{len(checks)} checks passed")
    if failed:
        if r.returncode != 0:
            print(r.stdout); print(r.stderr)
        for msg in failed: print('FAILED:',msg)
        return 1
    return 0

if __name__=='__main__':
    raise SystemExit(main())
