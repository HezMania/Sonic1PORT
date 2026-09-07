#!/usr/bin/env python3
from __future__ import annotations
import re, subprocess, sys
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
checks=[]
def check(cond,msg):
    ok=bool(cond); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)

player=(PROJECT/'scripts/player/sonic_player.gd').read_text()
visual=(PROJECT/'scripts/player/sonic_visual.gd').read_text()
main=(PROJECT/'scripts/main.gd').read_text()

# Optional source roots passed explicitly for source-provenance checks.
s1root=Path(sys.argv[1]) if len(sys.argv)>1 else None
s2root=Path(sys.argv[2]) if len(sys.argv)>2 else None

check('const PHYSICS_PROFILE_SONIC1 := 0' in player,'Sonic 1 profile is enum/default zero')
check('var physics_profile := PHYSICS_PROFILE_SONIC1' in player,'fresh launch defaults to Sonic 1 physics')
respawn=player[player.index('func respawn()'):player.index('func respawn_at')]
check('physics_profile =' not in respawn,'respawn preserves the user-selected physics profile')
check('KEY_K:' in main and 'toggle_sonic2_physics()' in main,'K runtime shortcut toggles S1/S2 physics')
check('physics_profile_name()' in player and 'phys:%s' in player,'debug state reports active physics profile')

# Exact S2 normal-Sonic release table and charge math.
expected=[0x800,0x880,0x900,0x980,0xA00,0xA80,0xB00,0xB80,0xC00]
m=re.search(r'const S2_SPINDASH_SPEEDS: Array\[int\] = \[(.*?)\]',player,re.S)
vals=[]
if m:
    vals=[int(x,16) for x in re.findall(r'0x[0-9A-Fa-f]+',m.group(1))]
check(vals==expected,'runtime spindash release table is the retail S2 nine-entry table')
check('spindash_counter -= spindash_counter >> 5' in player,'charge decays by counter >> 5 each held frame')
check('spindash_counter = mini(0x800, spindash_counter + 0x200)' in player,'each rev adds $200 and caps at $800')
check('clampi((spindash_counter >> 8) & 0xFF, 0, S2_SPINDASH_SPEEDS.size() - 1)' in player,'release indexes table from the source high byte')
check('_spindash_duck_ready' in player and 'not edge_balance' in player,'spindash requires prior grounded crouch and does not steal balance state')
check('Input.is_action_just_pressed("A")' in player and 'Input.is_action_just_pressed("B")' in player and 'Input.is_action_just_pressed("C")' in player,'separate A/B/C press edges can each rev the charge')

# S2 rolling behavior isolated behind profile switch.
check('var roll_dec := 0x20 if physics_profile == PHYSICS_PROFILE_SONIC2 else (speed_deceleration >> 2)' in player,'S2 uses fixed $20 controlled roll deceleration while S1 keeps deceleration/4')
check('vel_y = roll_vel_y if physics_profile == PHYSICS_PROFILE_SONIC2 else clampi(roll_vel_y, -0x1000, 0x1000)' in player,'S2 roll Y remains uncapped while S1 retains +/-$1000 cap')
check('vel_x = clampi(GenesisMath.s16((GenesisMath.cosine(angle) * inertia) >> 8), -0x1000, 0x1000)' in player,'both profiles retain source roll X-component cap')

# Balance/wobble state.
check('const BALANCE_SEQUENCE: Array[int] = [0x3A, 0x3B]' in visual,'visual uses Sonic 1 balance frames $3A/$3B')
check('_tick_animation(BALANCE_SEQUENCE.size(), 31)' in visual,'balance animation uses source delay 31')
check('func _update_edge_balance()' in player,'player has terrain/object edge-balance detection')
check('if int(center.get("distance", 0)) < 12:' in player,'terrain balance keeps Sonic 1 12px center-floor threshold')
check('if x < support_left + 4:' in player and 'elif x >= support_right - 4:' in player,'object balance uses 4px source edge regions')

# S2 spindash visual sequence and source-generated frame files.
check('const S2_SPINDASH_SEQUENCE: Array[int] = [0, 1, 0, 2, 0, 3, 0, 4, 0, 5]' in visual,'visual follows 42,43,42,44,42,45,42,46,42,47 order')
for i in range(6):
    p=PROJECT/f'assets/sonic2/spindash/{i:02d}.png'
    check(p.is_file(),f'S2 spindash frame {i:02d} exists')
    if p.is_file():
        check(Image.open(p).size==(64,64),f'S2 spindash frame {i:02d} keeps 64x64 player-origin canvas')

# Make sure all prior Phase 77 native-chunk static checks still pass.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase77.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 77 native 128x128 chunk validator still passes')

if s1root and s1root.is_dir():
    s1ani=(s1root/'_anim/Sonic.asm').read_text(errors='ignore')
    check(bool(re.search(r'fr_Balance1:\s*equ\s*\$3A',s1ani)),'S1 source confirms Balance1 frame $3A')
    check(bool(re.search(r'fr_Balance2:\s*equ\s*\$3B',s1ani)),'S1 source confirms Balance2 frame $3B')
    check(bool(re.search(r'SonAni_Balance:\s*dc\.b\s+31',s1ani)),'S1 source confirms balance delay 31')
else:
    print('SKIP: Sonic 1 source root not supplied')

if s2root and s2root.is_dir():
    asm=(s2root/'s2.asm').read_text(errors='ignore')
    check('move.w\t#$20,d4' in asm or 'move.w\t#$20,d4' in asm.replace('    ','\t'),'S2 source contains fixed $20 controlled roll deceleration')
    table=re.search(r'SpindashSpeeds:\s*(.*?)SpindashSpeedsSuper:',asm,re.S)
    srcvals=[]
    if table:
        srcvals=[int(x,16) for x in re.findall(r'dc\.w\s+\$([0-9A-Fa-f]+)',table.group(1))]
    check(srcvals==expected,'S2 source release table matches runtime exactly')
    anim=re.search(r'SonAni_Spindash:dc\.b\s+0,([^\n]+)',asm)
    check(anim is not None and '$42,$43,$42,$44,$42,$45,$42,$46,$42,$47' in anim.group(1).replace(' ',''),'S2 source animation order matches runtime')

    art=(s2root/"art/uncompressed/Sonic's art.bin").read_bytes()
    pal=(s2root/'art/palettes/SonicAndTails.bin').read_bytes()
    maps=(s2root/'mappings/sprite/Sonic.bin').read_bytes()
    dplc=(s2root/'mappings/spriteDPLC/Sonic.bin').read_bytes()
    colors=[]
    for i in range(16):
        w=int.from_bytes(pal[i*2:i*2+2],'big')
        colors.append(((w&0xE)*17,((w>>4)&0xE)*17,((w>>8)&0xE)*17,0 if i==0 else 255))
    def tile(idx):
        dat=art[idx*32:(idx+1)*32]; rows=[]
        for y in range(8):
            row=[]
            for b in dat[y*4:y*4+4]: row += [b>>4,b&15]
            rows.append(row)
        return rows
    for out_idx,fr in enumerate(range(0x42,0x48)):
        moff=int.from_bytes(maps[fr*2:fr*2+2],'big')
        count=int.from_bytes(maps[moff:moff+2],'big')
        piece=maps[moff+2:moff+10]
        y=int.from_bytes(piece[0:1],'big',signed=True); size=piece[1]; x=int.from_bytes(piece[6:8],'big',signed=True)
        doff=int.from_bytes(dplc[fr*2:fr*2+2],'big')
        dcount=int.from_bytes(dplc[doff:doff+2],'big'); entry=int.from_bytes(dplc[doff+2:doff+4],'big')
        n=((entry>>12)&15)+1; start=entry&0xFFF
        check(count==1 and dcount==1 and size==0x0F and n==16,f'S2 source frame ${fr:02X} is one 4x4 / 16-tile piece')
        img=Image.new('RGBA',(64,64),(0,0,0,0)); px=img.load(); wt=((size>>2)&3)+1; ht=(size&3)+1
        for j in range(wt*ht):
            tx=j//ht; ty=j%ht; tp=tile(start+j)
            for yy in range(8):
                for xx in range(8):
                    px[32+x+tx*8+xx,32+y+ty*8+yy]=colors[tp[yy][xx]]
        shipped=Image.open(PROJECT/f'assets/sonic2/spindash/{out_idx:02d}.png').convert('RGBA')
        check(list(img.getdata())==list(shipped.getdata()),f'S2 source frame ${fr:02X} regenerates shipped PNG pixel-for-pixel')
else:
    print('SKIP: Sonic 2 source root not supplied')

passed=sum(ok for ok,_ in checks); total=len(checks)
print(f'\n{passed}/{total} checks passed')
if passed!=total: raise SystemExit(1)
