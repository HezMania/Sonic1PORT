#!/usr/bin/env python3
from __future__ import annotations
import hashlib, subprocess, sys
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'data/s1/s2test'
checks=[]
def check(ok,msg):
    checks.append((bool(ok),msg)); print(('PASS' if ok else 'FAIL')+': '+msg)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    om=(ROOT/'scripts/objects/object_manager.gd').read_text()
    tr=(ROOT/'scripts/objects/s2_cpz_traversal_object.gd').read_text()
    hz=(ROOT/'scripts/objects/s2_cpz_hazard_object.gd').read_text()
    proj=(ROOT/'scripts/objects/s2_cpz_spiny_projectile.gd').read_text()
    player=(ROOT/'scripts/player/sonic_player.gd').read_text()
    data=(D/'cpz1_objects.bin').read_bytes(); counts=Counter(data[i+4] for i in range(0,len(data),6))
    expected={0x03:60,0x0B:4,0x0D:1,0x19:7,0x1B:8,0x1D:7,0x1E:9,0x26:19,0x2D:2,0x32:4,0x41:5,0x6B:2,0x74:2,0x78:2,0x79:3,0x7B:5,0xA5:10,0xA6:1,0xA7:2}
    check(len(data)==918 and len(data)//6==153 and dict(counts)==expected,'all 153 retail CPZ1 placement records remain unchanged')
    check(sha(D/'cpz1_objects.bin')=='672c6b5ed672b889ad8629662f8e569fafca953046bfeeff999207bae17a4046','CPZ1 placement binary retains verified SHA-256')

    # User-reported traversal corrections.
    check('var was_rolling = p.rolling' in tr and 'contact == SonicPlayer.SOLID_TOP and was_rolling' in tr,'Obj32 snapshots rolling state before native solid collision like retail breakableblock_mainchar_anim')
    check('p.vel_y = -0x300' in tr and 'SonicAudio.SFX_WALL_SMASH' in tr,'Obj32 tube cap retains source -$300 break bounce and smash event')
    check(tr.count('ny - 0x11')>=2,'Obj19 moving platform carry and landing both use retail d3=$11 top offset')
    check('resolve_solid_box_contact(spawn_x, spawn_y, 18, 16, true, record_index)' in tr,'Obj7B native side envelope no longer double-counts Sonic radius')
    check('spawn_x - 0x10' in tr and 'spawn_x + 0x10' in tr and 'spawn_y + 0x30' in tr,'Obj7B source proximity animation detector remains ±$10 by +$30')

    check(player.count('physics_profile == PHYSICS_PROFILE_SONIC2')>5,'Sonic 2 movement correction is explicitly profile-gated')
    check('old_inertia <= -speed_max' in player and 'old_inertia >= speed_max' in player,'S2 ground acceleration preserves pre-existing over-cap inertia in both directions')
    check('inertia = maxi(-speed_max, inertia - speed_acceleration)' in player and 'inertia = mini(speed_max, inertia + speed_acceleration)' in player,'Sonic 1 ground speed-cap path remains intact')

    # Phase 92 dispatch and complete placed-object coverage.
    check('S2CPZHazardObjectClass' in om and 'S2CPZSpinyProjectileClass' in om,'CPZ hazard and Spiny projectile classes are isolated in S2 namespace')
    check('0x1D, 0xA5, 0xA6, 0xA7: return S2CPZHazardObjectClass.new()' in om,'all four formerly deferred CPZ IDs now dispatch natively')
    supported={0x03,0x0B,0x0D,0x19,0x1B,0x1D,0x1E,0x26,0x2D,0x32,0x41,0x6B,0x74,0x78,0x79,0x7B,0xA5,0xA6,0xA7}
    check(sum(v for k,v in counts.items() if k in supported)==153 and set(counts)<=supported,'CPZ1 reaches 153/153 supported placed source objects')

    # Obj1D.
    check('(subtype & 0x0F) + 1' in hz and 'i * 3' in hz,'Obj1D creates low-nibble+1 droplets with source 3-frame staggering')
    check('"vy": -0x480' in hz and '0x18' in hz and '0x0B' in hz and '0x60' in hz,'Obj1D preserves -$480 launch, +$18 gravity, $B horizontal acceleration and $60 straight offset')
    check('(subtype & 0xF0) != 0' in hz and 'q["ax"] = -int(q["ax"])' in hz,'Obj1D subtype selects straight/arc paths and arc reverses horizontal acceleration at apex')
    check('p.apply_hazard_hit' in hz,'Obj1D droplets are active player hazards')

    # Spiny / wall Spiny.
    check('spiny_turn_timer = 0x80' in hz and 'spiny_vel_x = -0x40' in hz and 'spiny_vel_y = -0x40' in hz,'ObjA5/A6 retain $80 turn timer and source -$40 patrol velocities')
    check('absi(int(position.x) - p.pixel_x()) < 0x60' in hz,'Spiny firing detector retains source ±$60 horizontal window')
    check('spiny_shot_timer = 0x28' in hz and 'spiny_shot_timer == 0x14' in hz and 'spiny_cooldown = 0x40' in hz,'Spiny preserves $28 attack timer, $14 shot point and $40 cooldown')
    check('direction * 0x100, -0x300' in hz and 'direction * 0x300, 0' in hz,'floor/wall Spiny projectiles use source initial velocities')
    check('vel_y = GenesisMath.s16(vel_y + 0x20)' in proj,'Obj98 Spiny projectile applies source +$20 gravity')
    check('6 + ((frame_tick >> 2) & 1)' in proj,'Spiny projectile animates through source mapping frames 6/7')

    # Grabber.
    check('grabber_vel_x = 0x40 if x_flip else -0x40' in hz and 'grabber_turn_timer = 0xFF' in hz,'ObjA7 patrol uses source ±$40 velocity and $FF turn timer')
    check('absi(dx) < 0x40 and dy < 0 and dy > -0x80' in hz,'ObjA7 attack detector matches ±$40 X and player-below <$80 source window')
    check('grabber_timer = 0x10' in hz and 'grabber_vel_y = 0x200' in hz and 'grabber_timer = 0x40' in hz,'ObjA7 keeps source $10 pause, $200 descent and $40 down/up timer')
    check('p.object_control_override = true' in hz and 'p.force_set_pixel_position' in hz and 'p.object_control_override = false' in hz,'Grabber captures, carries and safely releases Sonic through object-control override')
    check('grabber_string.points = PackedVector2Array' in hz and 'grabber/02.png' in hz and 'grabber/03.png' in hz,'Grabber includes source hanger/legs presentation and expanding string')

    assets={'blue':1,'spiny':8,'grabber':7}
    check(all(len(list((ROOT/'assets/objects/s2_cpz'/k).glob('*.png')))==v for k,v in assets.items()),'all source-rendered Phase 92 CPZ hazard/Badnik frames are packaged')

    # Preserve Phase 91 traversal foundation.
    check('selector_table: Array[int] = [2,2,2,2,2,2,2,2,2,2,0,2,0,1,2,1]' in tr and 'p.object_control_override = true' in tr,'Phase 91 spin-tube selector/capture path remains present')
    check('manager.s2_source_osc_byte(0x0C)' in tr and 'manager.s2_source_osc_byte(0x1C)' in tr,'Phase 91 Obj19 source oscillator channels remain present')
    check('barrier_raise = mini(0x40, barrier_raise + 8)' in tr and 'stair_delay = 0x1E' in tr,'Phase 91 barrier/stair source timing remains present')

    r=subprocess.run([sys.executable,str(ROOT/'tools/validate_phase90_hotfix1.py')],cwd=ROOT,text=True,capture_output=True)
    check(r.returncode==0,'verified Phase 90 Hotfix 1 terrain/palette regression suite still passes')

    if len(sys.argv)>1:
        source=Path(sys.argv[1])
        check(data==(source/'level/objects/CPZ_1.bin').read_bytes(),'packaged CPZ1 object layout is byte-identical to retail source')
        asm=(source/'s2.asm').read_text()
        check('move.b\t(MainCharacter+anim).w,breakableblock_mainchar_anim(a0)' in asm and 'cmpi.b\t#AniIDSonAni_Roll,breakableblock_mainchar_anim(a0)' in asm,'retail Obj32 confirms roll state is sampled before SolidObject')
        check('move.w\t#$11,d3' in asm and 'Obj19_Main:' in asm,'retail Obj19 confirms platform top parameter d3=$11')
        check('move.w\t#$1B,d1' in asm and 'Obj7B_Main:' in asm and 'move.b\t#$10,width_pixels(a0)' in asm,'retail Obj7B confirms $1B SolidObject envelope with $10 sprite width')
        check('cmp.w\td6,d0' in asm and 'sub.w\td5,d0' in asm and 'Sonic_MoveRight:' in asm,'retail S2 movement restores already-over-cap inertia after attempted acceleration')
        check('move.w\t#-$480,y_vel(a0)' in asm and 'move.w\t#$60,objoff_3A(a1)' in asm and 'move.w\t#$B,objoff_36(a1)' in asm,'retail Obj1D constants match packaged hazard implementation')
        check('move.w\t#-$40,x_vel(a0)' in asm and 'move.w\t#$80,objoff_2A(a0)' in asm and 'ObjA5:' in asm,'retail floor Spiny patrol constants match')
        check('move.w\t#-$40,y_vel(a0)' in asm and 'ObjA6:' in asm,'retail wall Spiny patrol velocity matches')
        check('move.w\t#$FF,objoff_2A(a0)' in asm and 'move.b\t#$10,objoff_2C(a0)' in asm and 'move.w\t#$200,y_vel(a0)' in asm,'retail Grabber patrol/pause/descent constants match')
        importer=ROOT/'tools/import_s2_cpz_hazards_phase92.py'
        before={str(p.relative_to(ROOT)):sha(p) for folder in assets for p in (ROOT/'assets/objects/s2_cpz'/folder).glob('*.png')}
        rr=subprocess.run([sys.executable,str(importer),str(source)],cwd=ROOT,text=True,capture_output=True)
        check(rr.returncode==0,'Phase 92 CPZ hazard importer regenerates successfully from retail source')
        after={str(p.relative_to(ROOT)):sha(p) for folder in assets for p in (ROOT/'assets/objects/s2_cpz'/folder).glob('*.png')}
        check(before==after,'Phase 92 generated CPZ hazard/Badnik assets are deterministic')

    failed=[m for ok,m in checks if not ok]
    print(f'\n{len(checks)-len(failed)}/{len(checks)} checks passed')
    if failed:
        if r.returncode!=0: print(r.stdout); print(r.stderr)
        for m in failed: print('FAILED:',m)
        return 1
    return 0

if __name__=='__main__': raise SystemExit(main())
