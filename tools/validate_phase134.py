#!/usr/bin/env python3
from pathlib import Path
import re, sys
P=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
S2=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
checks=[]
def ck(c,m):
    checks.append((bool(c),m)); print(('PASS' if c else 'FAIL')+': '+m)
def txt(rel): return (P/rel).read_text(errors='replace')
main=txt('scripts/main.gd')
cat=txt('scripts/data/level_catalog.gd')
bg=txt('scripts/render/ghz_background_renderer.gd')
mecha=txt('scripts/objects/s2_dez_mecha_sonic.gd')
ck('Native Sonic 1 Phase 134' in main,'Debug overlay identifies Phase134')
ck((P/'PHASE134_SONIC2_DEATH_EGG_MECHA_COLLISION.md').exists(),'Phase134 notes are packaged')
ck('"background_mode": "s2dez", "backdrop_palette_index": 17' in cat,'DEZ viewport backdrop selects opaque retail black index 17')
ck('17 if mode == "s2dez"' in bg,'DEZ indexed Plane-B empty pixels use opaque black index 17')
ck('Authored nonzero DEZ pixels' in bg,'DEZ horizon/nonzero artwork is explicitly preserved')
# Verify combined palette index 17 is exactly black.
def be_words(path):
    b=path.read_bytes(); return [(b[i]<<8)|b[i+1] for i in range(0,len(b)-1,2)]
zone=be_words(P/'data/s1/palette/S2 Death Egg Zone.bin')
ck(len(zone)>=2 and zone[1]==0x000,'Retail DEZ palette line1/color1 used for index17 is exactly black')
ck('const TOUCH_X: int = 0x0C' in mecha and 'const TOUCH_Y: int = 0x0C' in mecha,'Mecha player touch box is retail 12x12')
ck('HIT_Y + p.height_radius' not in mecha[mecha.index('func _check_player_contact'):mecha.index('func _begin_defeat')],'Player touch no longer uses ObjAF floor/body radii')
contact=mecha[mecha.index('func _check_player_contact'):mecha.index('func _begin_defeat')]
ck('mapping_frame == 6 or mapping_frame == 7 or mapping_frame == 8' in contact,'Mecha ball mapping frames 6/7/8 have dedicated collision behavior')
ball=contact[contact.index('if mapping_frame == 6'):contact.index('if invulnerability_timer > 0')]
ck('apply_hazard_hit' in ball and 'hits -=' not in ball,'Mecha ball frames hurt Sonic and cannot decrement boss health')
ck(contact.index('if invulnerability_timer > 0') < contact.index('if p.can_attack_object()'),'Boss touch is disabled throughout the hit-flash interval')
ck('p.vel_x = GenesisMath.s16(-p.vel_x)' in contact,'Successful boss hit negates Sonic X velocity')
ck('p.vel_y = GenesisMath.s16(-p.vel_y)' in contact,'Successful boss hit negates Sonic Y velocity')
ck('invulnerability_timer = 0x20' in contact,'Mecha retains retail $20 hit-flash/touch-disable interval')
ck('const HIT_X: int = 0x10' in mecha and 'const HIT_Y: int = 0x1B' in mecha,'ObjAF $10/$1B radii remain intact for object/floor geometry')
ck('var probe_y: int = _y() + HIT_Y' in mecha,'Floor probing still uses ObjAF y_radius rather than touch box')
# Source-shaped attack and deferred final boss remain intact.
ck('ATTACK_SEQUENCE' in mecha and '[\n\t0x06, 0x00, 0x10, 0x06,' in mecha,'Phase133 retail Mecha attack selector retained')
ck('S2_SFX_SPINDASH_RELEASE' in mecha and 'play_s2_pcm_sfx' in mecha,'User-supplied S2 PCM integration retained')
om=txt('scripts/objects/object_manager.gd')
route=om[om.index('if bool(level_definition.get("experimental_sonic2", false)):'):om.index('\tmatch id:',om.index('if bool(level_definition.get("experimental_sonic2", false)):')+1)]
ck('0xC6' not in route and '0xC7' not in route,'Final DEZ Objects $C6/$C7 remain deferred')
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    ck('move.b\t#$1A,collision_flags(a0)' in asm,'Retail ObjAF enables normal collision flag $1A on landing')
    d24=asm[asm.index('loc_39D24:'):asm.index('loc_39D4A:')]
    ck(all(f'cmpi.b\t#{n},d0' in d24 for n in (6,7,8)) and 'move.b\t#$9A,collision_flags(a0)' in d24,'Retail ObjAF maps frames 6/7/8 to harmful $9A collision')
    sizes=asm[asm.index('Touch_Sizes:'):asm.index('Touch_Boss:')]
    # Entry $1A is documented in the source table as $C,$C.
    ck('dc.b  $C, $C\t; $1A' in sizes,'Retail TouchResponse entry $1A is 12x12')
    enemy=asm[asm.index('Touch_Enemy_Part2:'):asm.index('Touch_KillEnemy:')]
    ck('neg.w\tx_vel(a0)' in enemy and 'neg.w\ty_vel(a0)' in enemy and 'move.b\t#0,collision_flags(a1)' in enemy,'Retail boss hit negates both Sonic velocities and clears boss touch collision')
# Structural sanity.
for rel in ['scripts/main.gd','scripts/data/level_catalog.gd','scripts/render/ghz_background_renderer.gd','scripts/objects/s2_dez_mecha_sonic.gd']:
    body=txt(rel)
    ck('<<<<<<<' not in body and '=======' not in body and '>>>>>>>' not in body,f'{rel} has no conflict markers')
    ck(body.count('(')==body.count(')'),f'{rel} parentheses balance')
    ck(body.count('[')==body.count(']'),f'{rel} brackets balance')
    ck(body.count('{')==body.count('}'),f'{rel} braces balance')
passed=sum(ok for ok,_ in checks)
print(f'\n{passed}/{len(checks)} checks passed')
if passed!=len(checks):
    print('Failures:')
    for ok,msg in checks:
        if not ok: print(' -',msg)
    raise SystemExit(1)
