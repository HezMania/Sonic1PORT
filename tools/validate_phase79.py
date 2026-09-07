#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from PIL import Image
import hashlib, re, subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

player=(PROJECT/'scripts/player/sonic_player.gd').read_text()
visual=(PROJECT/'scripts/player/sonic_visual.gd').read_text()
camera=(PROJECT/'scripts/camera/sonic_camera.gd').read_text()
main=(PROJECT/'scripts/main.gd').read_text()

# Existing Phase 78 physics remains isolated and default-S1.
check('const PHYSICS_PROFILE_SONIC1 := 0' in player and 'const PHYSICS_PROFILE_SONIC2 := 1' in player,'S1/S2 physics profiles retained')
check('var physics_profile := PHYSICS_PROFILE_SONIC1' in player,'fresh launch still defaults to S1 physics')
check('const S2_SPINDASH_SPEEDS: Array[int]' in player and '0xC00' in player,'retail S2 spindash speed table retained')
check('spindash_counter -= spindash_counter >> 5' in player,'retail S2 spindash decay retained')
check('spindash_counter = mini(0x800, spindash_counter + 0x200)' in player,'retail S2 spindash rev increment/cap retained')

# Independent animation profile selector.
check('const ANIMATION_STYLE_SONIC1 := 0' in player and 'ANIMATION_STYLE_SONIC2_BETA := 1' in player and 'ANIMATION_STYLE_SONIC2_FINAL := 2' in player,'three independent animation presentation styles exist')
check('var animation_style = ANIMATION_STYLE_SONIC1' in player,'fresh launch defaults to S1 presentation')
check('func cycle_animation_style()' in player and '(animation_style + 1) % 3' in player,'animation selector cycles all three styles')
check('KEY_L:' in main and 'cycle_animation_style()' in main,'L cycles animation presentation independently')
check('KEY_K:' in main and 'toggle_sonic2_physics()' in main,'K remains independent physics selector')
check('anim:%s' in player and 'animation_style_name()' in player,'debug state reports selected animation style')

# User-supplied S1-compatible spindash frames are copied byte-for-byte.
expected_hashes=[
'33cff88a0bed8ad3222608b429ccfa6ebee4dda202d38328b01cef54295ea811',
'0e84c0476e3ea935d5c008579424dc223220681b982b40f0bf2f68532113a402',
'8d0cc0c8f4f174d30ad1a04af2731e061992cf531be4ec76436153c7b221432e',
'bac01a110cd44c4eee631f3e96586e75a2e18282b13960ed7fd3c4e954990d16',
'7686a37a599895c073d1b24b1fe2bc22e6b9e90c749ecc0426fa9c248fee14e8',
'f40f773cb976473ac32fe098c5d13e2ef8446ddac7e7afaa136ff4f1d896684a']
for i,h in enumerate(expected_hashes):
    p=PROJECT/f'assets/sonic/spindash_s1_compat/{i:02d}.png'
    check(p.is_file(),f'S1-compatible spindash frame {i} exists')
    if p.is_file():
        check(hashlib.sha256(p.read_bytes()).hexdigest()==h,f'S1-compatible spindash frame {i} is byte-for-byte user upload')
        check(Image.open(p).size==(64,64),f'S1-compatible spindash frame {i} remains 64x64')
check('S1_COMPAT_SPINDASH_SEQUENCE' in visual and 'spindash_s1_compat' in visual,'S1 presentation routes active spindash to uploaded art')

# S2 beta/final source presentation banks and key source animation IDs.
check((PROJECT/'assets/sonic2/beta/frame_count.txt').read_text().strip()=='167','Simon Wai bank contains all 167 source mapping frames')
check((PROJECT/'assets/sonic2/final/frame_count.txt').read_text().strip()=='214','retail S2 bank contains all 214 source mapping frames')
check('BETA_SPINDASH' in visual and '0x71, 0x72, 0x71, 0x73' in visual,'Simon Wai spindash animation uses source $71-$76 family')
check('FINAL_SPINDASH' in visual and '0x42, 0x43, 0x42, 0x44' in visual,'retail S2 spindash animation uses source $42-$47 family')
check('BETA_BALANCE' in visual and '0x89, 0x8A' in visual,'Simon Wai balance uses source frames $89/$8A')
check('FINAL_BALANCE' in visual and '0xCC, 0xCD, 0xCE, 0xCD' in visual,'retail S2 balance uses source animation frames')
check('(0x800 - speed) >> 9' in visual and '(0x800 - speed) >> 8' in visual,'beta/final walk-run animation timing preserves source difference')
check('frame_modifier = (octant_modifier + (octant_modifier >> 1)) * 4' in visual,'Simon Wai angle-bank stride is source 12-frame spacing')
check('frame_modifier = octant_modifier * 2' in visual and 'frame_modifier = octant_modifier * 4' in visual,'retail S2 run/walk angle-bank strides are source-sized')

# Camera: S1 immediate behavior + retail S2 delay/recenter.
check('const S2_LOOK_DELAY_FRAMES := 0x78' in camera,'S2 look delay is exact $78 frames')
check('look_delay_counter = mini(S2_LOOK_DELAY_FRAMES, look_delay_counter + 1)' in camera,'look delay counts held frames')
check('if look_delay_counter < S2_LOOK_DELAY_FRAMES:' in camera,'camera does not pan before S2 delay expires')
check('if player.spindash_active:' in camera and '_reset_look_shift()' in camera,'active spindash recenters vertical look bias')
# The S1 branch must still immediately alter look_shift with no counter gate.
s1_branch=camera[camera.index('# Sonic 1 has no look-delay counter'):camera.index('func _reset_look_shift')]
check('look_shift = mini(MAX_LOOK_UP, look_shift + 2)' in s1_branch and 'look_shift = maxi(MAX_LOOK_DOWN, look_shift - 2)' in s1_branch,'S1 look panning remains immediate')

# Prior native 128x128 terrain regression suite.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase77.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 77 native 128x128 terrain validator still passes')

# Optional source validation: script values + selected regenerated sprite pixels.
def source_renderer(root:Path):
    art=(root/"art/uncompressed/Sonic's art.bin").read_bytes(); maps=(root/'mappings/sprite/Sonic.bin').read_bytes(); dplc=(root/'mappings/spriteDPLC/Sonic.bin').read_bytes()
    palfile=root/'art/palettes/SonicAndTails.bin'
    if not palfile.exists(): palfile=root/'art/palettes/Sonic and Tails.bin'
    pal=palfile.read_bytes(); colors=[]
    for i in range(16):
        w=int.from_bytes(pal[i*2:i*2+2],'big'); colors.append(((w&0xE)*17,((w>>4)&0xE)*17,((w>>8)&0xE)*17,0 if i==0 else 255))
    def tile(idx):
        dat=art[idx*32:(idx+1)*32]; rows=[]
        for y in range(8):
            row=[]
            for b in dat[y*4:y*4+4]: row += [b>>4,b&15]
            rows.append(row)
        return rows
    def render(fr):
        do=int.from_bytes(dplc[fr*2:fr*2+2],'big'); dc=int.from_bytes(dplc[do:do+2],'big'); loaded=[]
        for i in range(dc):
            e=int.from_bytes(dplc[do+2+i*2:do+4+i*2],'big'); n=((e>>12)&15)+1; start=e&0xFFF; loaded.extend(range(start,start+n))
        mo=int.from_bytes(maps[fr*2:fr*2+2],'big'); c=int.from_bytes(maps[mo:mo+2],'big')
        im=Image.new('RGBA',(80,80),(0,0,0,0)); px=im.load()
        for i in range(c):
            p=maps[mo+2+i*8:mo+10+i*8]; y=int.from_bytes(p[:1],'big',signed=True); sz=p[1]; at=int.from_bytes(p[2:4],'big'); x=int.from_bytes(p[6:8],'big',signed=True)
            wt=((sz>>2)&3)+1; ht=(sz&3)+1; base=at&0x7FF; hf=bool(at&0x800); vf=bool(at&0x1000)
            for j in range(wt*ht):
                tp=tile(loaded[base+j]); tx=j//ht; ty=j%ht
                for yy in range(8):
                    for xx in range(8):
                        ci=tp[7-yy if vf else yy][7-xx if hf else xx]
                        if ci: px[40+x+tx*8+xx,40+y+ty*8+yy]=colors[ci]
        return im
    return render

if len(sys.argv)>=3:
    beta=Path(sys.argv[1]); final=Path(sys.argv[2])
    basm=(beta/'s2b.asm').read_text(errors='ignore'); fasm=(final/'s2.asm').read_text(errors='ignore')
    check('SonAni_Spindash:\tdc.b $00, $71, $72, $71, $73, $71, $74, $71, $75, $71, $76, $71, $FF' in basm,'Simon Wai source confirms beta spindash sequence')
    check('SonAni_Spindash:dc.b   0,$42,$43,$42,$44,$42,$45,$42,$46,$42,$47,$FF' in fasm,'retail S2 source confirms final spindash sequence')
    check('cmpi.w\t#$78,(Sonic_Look_delay_counter).w' in fasm,'retail S2 source confirms $78 look delay')
    br=source_renderer(beta); fr=source_renderer(final)
    for style,render,ids in [('beta',br,[0x01,0x10,0x3C,0x71,0x89]),('final',fr,[0x01,0x0F,0x2D,0x42,0xCC])]:
        for fid in ids:
            shipped=Image.open(PROJECT/f'assets/sonic2/{style}/frames/{fid:03d}.png').convert('RGBA')
            check(list(render(fid).getdata())==list(shipped.getdata()),f'{style} frame ${fid:02X} regenerates pixel-for-pixel from source')
else:
    print('SKIP: pass Simon Wai root and retail S2 root for source-regeneration checks')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
(PROJECT/'PHASE79_VALIDATION_RESULTS.txt').write_text('\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n')
if passed!=total: raise SystemExit(1)
