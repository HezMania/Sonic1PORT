#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, re, sys, wave

P = Path(__file__).resolve().parents[1]
S2 = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
checks=[]
def ck(v,msg):
    ok=bool(v); checks.append((ok,msg)); print(('PASS: ' if ok else 'FAIL: ')+msg)
def txt(rel): return (P/rel).read_text(errors='replace')
def sha(rel): return hashlib.sha256((P/rel).read_bytes()).hexdigest()

main=txt('scripts/main.gd')
bg=txt('scripts/render/ghz_background_renderer.gd')
audio=txt('scripts/audio/sonic_audio.gd')
mecha=txt('scripts/objects/s2_dez_mecha_sonic.gd')
cpz=txt('scripts/objects/s2_cpz_traversal_object.gd')
cat=txt('scripts/data/level_catalog.gd')
om=txt('scripts/objects/object_manager.gd')
cam=txt('scripts/camera/sonic_camera.gd')
manifest=json.loads((P/'data/s1/s2test/phase133_dez_fidelity_manifest.json').read_text())

# Phase identity / direct entry.
ck('Native Sonic 1 Phase 133' in main,'Debug overlay identifies Phase133')
ck('KEY_KP_2:' in main and '_debug_warp(LevelCatalog.ZONE_S2_DEZ_TEST, 1)' in main,'NumPad 2 retains direct DEZ warp')
ck('event.physical_keycode in [KEY_KP_0, KEY_KP_1, KEY_KP_2]' in main,'NumPad warps prefer physical keypad keycodes')
ck('debug_key = int(event.physical_keycode)' in main,'Physical keypad code replaces ambiguous logical code')
debugwarp=main[main.index('func _debug_warp'):main.index('func _unhandled_input')]
ck('_reset_view_after_respawn(debug_player)' in debugwarp,'Direct warp primes the camera/background via respawn-proven view path')
ck(manifest.get('phase')==133,'Phase133 fidelity manifest identifies phase')
ck((P/'PHASE133_SONIC2_DEATH_EGG_FIDELITY.md').exists(),'Phase133 notes are packaged')

# DEZ registered baseline remains intact.
dezdef=cat[cat.index('static func _get_sonic2_dez_test'):cat.index('static func _get_sonic2_hpz_test')]
for needle,msg in [
    ('"limit_right": 0x1000','DEZ right limit remains $1000'),
    ('"limit_top": 0x00C8','DEZ fixed top remains $C8'),
    ('"limit_bottom": 0x00C8','DEZ fixed bottom remains $C8'),
    ('"background_mode": "s2dez"','DEZ SwScrl mode retained'),
    ('"s2_dez": true','DEZ definition flag retained'),
]: ck(needle in dezdef,msg)
ck((P/'data/s1/s2test/dez1_start.bin').read_bytes()==bytes([0,0x60,1,0x2D]),'DEZ retail start remains $0060,$012D')
objs=(P/'data/s1/s2test/dez1_objects.bin').read_bytes()
records=[objs[i:i+6] for i in range(0,len(objs),6)]
ck(Counter(r[4] for r in records)==Counter({0x2D:3,0xC6:1,0xC7:1}),'DEZ placement stream still has 3x$2D + $C6 + $C7')

# Background first-frame fidelity / cache footprint.
dez_branch_start=bg.index('elif mode == "s2dez"', bg.index('func _setup_s2test'))
dez_branch_end=bg.index('\n\telse:', dez_branch_start)
setup=bg[dez_branch_start:dez_branch_end]
ck('elif mode == "s2dez"' in setup,'DEZ has a dedicated background-cache setup branch')
ck('s2_ehz_plane_width = 36 * 128' in setup,'DEZ Plane-B cache is cropped to 36 authored chunk columns')
ck('s2_ehz_plane_height = 6 * 128' in setup,'DEZ Plane-B cache is cropped to 6 authored chunk rows')
update=bg[bg.index('func _update_s2dez'):bg.index('\nfunc ',bg.index('func _update_s2dez')+5)]
ck('var logical_y: int = camera_model.screen_y' in update,'SwScrl_DEZ begins from Camera_BG_Y-equivalent $C8 camera Y')
ck('var logical_y: int = 0' not in update,'Phase132 zero-Y DEZ background bug is removed')
ck('posmod(logical_y + line, s2_ehz_plane_height)' in update,'DEZ strip source Y derives from corrected logical Y')
# Verify crop covers all actual nonzero authored cells after 2-byte header.
bgdata=(P/'data/s1/s2test/dez1_bg128.bin').read_bytes()
w=bgdata[0]+1; h=bgdata[1]+1; cells=bgdata[2:2+w*h]
nz=[(x,y) for y in range(h) for x,v in enumerate(cells[y*w:(y+1)*w]) if v]
ck(w==128 and h==16,'DEZ Plane-B source remains 128x16 chunks')
ck(max(x for x,y in nz)<36 and max(y for x,y in nz)<6,'36x6 cache contains every nonzero DEZ Plane-B cell')
ck(36*128*(6*128) < 4_000_000,'DEZ R8 cache footprint is below 4 MiB instead of ~32 MiB')
row_line=bg[bg.index('const S2_DEZ_ROW_HEIGHTS'):].split('\n',1)[0]
row_values=[x.strip() for x in row_line[row_line.index('[')+1:row_line.rindex(']')].split(',')]
ck(len(row_values)==36,'All 36 retail SwScrl_DEZ row bands remain present')

# Door art and collision.
barrier=P/'assets/objects/s2_dez/barrier/00.png'
ck(barrier.exists() and barrier.stat().st_size>100,'Corrected DEZ construction-door PNG is packaged')
try:
    from PIL import Image
    im=Image.open(barrier).convert('RGBA')
    alpha=im.getchannel('A')
    box=alpha.getbbox()
    ck(im.size==(192,192),'DEZ door frame keeps standard 192x192 object canvas')
    ck(box is not None and (box[2]-box[0])==16,'DEZ door visible retail mapping spans 16 pixels while collision half-width is 8')
    colors=set(px[:3] for px in im.getdata() if px[3])
    ck(any(r>150 and g>120 and b<100 for r,g,b in colors),'DEZ door contains source yellow construction stripes')
except Exception as e:
    print('PIL barrier check:',e); ck(False,'DEZ barrier image can be inspected')
barfn=cpz[cpz.index('func _tick_barrier'):cpz.index('func _init_breakable_block')]
ck('var solid_half_width: int = 8 if' in barfn,'DEZ door native collision uses true width_pixels=8')
ck('resolve_solid_box_contact(spawn_x, int(position.y), solid_half_width, 32' in barfn,'Door resolver receives corrected half width')
ck('s2_dez/barrier/00.png' in cpz,'Object $2D selects corrected DEZ door art')

# User-supplied S2 sound bank integration.
needed=['22','30','3C','5C','6E']
for code in needed:
    rel=f'assets/audio/sfx_pcm/S2_{code}.wav'
    path=P/rel
    ck(path.exists() and path.stat().st_size>44,f'S2 Sound{code} PCM is packaged')
    if path.exists():
        try:
            with wave.open(str(path),'rb') as wf:
                ck(wf.getnframes()>0 and wf.getframerate()>0,f'S2 Sound{code} is a valid non-empty WAV')
        except Exception as e:
            print(e); ck(False,f'S2 Sound{code} is a valid WAV')
    ck(sha(rel)==manifest['sha256'][rel],f'S2 Sound{code} hash matches Phase133 manifest')
ck('func play_s2_pcm_sfx(sample_id: int) -> bool:' in audio,'SonicAudio exposes on-demand S2 PCM playback')
ck('"%s/S2_%02X.wav"' in audio,'S2 PCM loader uses separate S2_XX resource namespace')
ck('0x200 | sid' in audio,'S2 PCM cache keys cannot collide with Sonic 1 IDs')
ck('SonicAudio.SFX_SPINDASH' not in mecha,'Invalid SonicAudio.SFX_SPINDASH reference is removed')

# Mecha top-level lifecycle and static prelanding presentation.
ck('const PH_WAIT: int = 0' in mecha and 'const PH_FALL: int = 2' in mecha,'Mecha uses explicit source-shaped top-level phases')
ck('var hits: int = 8' in mecha,'Mecha remains an 8-hit boss')
wait=mecha[mecha.index('func _tick_wait'):mecha.index('func _tick_prelude')]
pre=mecha[mecha.index('func _tick_prelude'):mecha.index('func _tick_fall')]
fall=mecha[mecha.index('func _tick_fall'):mecha.index('func _enter_cooldown')]
ck('manager.current_screen_x < ARENA_X' in wait and 'timer = 0x3C' in wait and 'vy = 0x100' in wait,'Mecha preserves $224 gate, $3C prelude, and $100 fall velocity')
ck('mapping_frame = 0' in wait and 'mapping_frame = 0' in pre and 'mapping_frame = 0' in fall,'Mecha body/spines stay static at mapping frame 0 until landing')
ck('_set_flame_animation(0, true)' in mecha[mecha.index('func setup'):mecha.index('func tick')],'Mecha falling flame child is active from initialization')
ck('FLAME_FRAMES' in mecha and '[0x0B, 0x0C]' in mecha,'Mecha fall flame uses retail mapping frames $B/$C')
ck('SonicAudio.play_s2_pcm_sfx(S2_SFX_FIRE)' in fall,'Mecha fall emits retail Fire cue')
ck('(manager.elapsed_frames & 0x1F) == 0' in fall,'Mecha Fire cue follows retail 32-VBlank cadence')

# Cooldown and exact attack sequence.
seq=[0x06,0x00,0x10,0x06,0x06,0x1E,0x00,0x10,0x06,0x06,0x10,0x06,0x00,0x06,0x10,0x1E]
seq_text=re.search(r'const ATTACK_SEQUENCE: Array\[int\] = \[(.*?)\n\]',mecha,re.S)
parsed=[]
if seq_text:
    parsed=[int(x,0) for x in re.findall(r'0x[0-9A-Fa-f]+|\b\d+\b',seq_text.group(1))]
ck(parsed==seq,'Mecha exact 16-entry retail attack selector is implemented')
cd=mecha[mecha.index('func _enter_cooldown'):mecha.index('func _tick_attack')]
ck('timer = 0x64' in cd,'Mecha cooldown is retail $64 frames')
ck('if timer == 0x32:' in cd,'Mecha second buzz occurs at cooldown $32')
ck(cd.count('S2_SFX_MECHA_BUZZ')>=2,'Mecha buzz plays at cooldown entry and halfway point')

# Main and flame animation scripts.
for needle,msg in [
    ('[0, 1, 2]','Animation 0 frame list'),
    ('[4, 5, 4, 3]','Animation 2 frame list'),
    ('[6, 7, 8]','Animation 4 frame list'),
    ('[0x0D, 0x0E]','Wind-up flame frames $D/$E'),
    ('[0x09, 0x0A]','Dash flame frames 9/$A'),
    ('const ANIM_DELAYS: Array[int] = [2, 0x45, 3, 3, 2, 3]','Retail main animation delays'),
]: ck(needle in mecha,msg)
ck('ANIM_SECONDARY' in mecha and 'secondary += 2' in mecha[mecha.index('func _animate_checked'):mecha.index('func _set_flame_animation')],'AnimateSprite_Checked $FD secondary advance is represented')
ck('anim_duration = 1' in mecha[mecha.index('func _animate_checked'):mecha.index('func _set_flame_animation')],'AnimateSprite_Checked $FC hold behavior is represented')

# Four retail attack families.
spin=mecha[mecha.index('func _spin_setup'):mecha.index('func _common_pose_setup')]
ck('repeat_count = 2' in spin and 'timer = 0x20' in spin,'Spin family uses two $20 windups')
ck('timer = 0x40' in spin and '_set_alternating_speed(0x800)' in spin,'Spin family uses $40/$800 dash')
ck('_decelerate_x()' in spin and '0x20' in mecha[mecha.index('func _decelerate_x'):mecha.index('func _move_main')],'Spin dash decelerates by source $20')
ck('S2_SFX_SPINDASH_RELEASE' in spin,'Spin family uses supplied Spindash Release cue')
ground=mecha[mecha.index('func _common_pose_setup'):mecha.index('func _jump_charge')]
ck('_set_animation(3)' in ground,'Ground/jump windup uses retail animation 3')
ck('S2_SFX_LASER_BEAM' in ground,'Ground-dash charge uses retail Laser Beam cue')
ck('_set_alternating_speed(0x800)' in ground,'Ground dash uses retail $800 speed')
jump=mecha[mecha.index('func _jump_charge'):mecha.index('func _close_from_current')]
ck('_set_alternating_speed(0x400)' in jump,'Jump families use retail $400 horizontal speed')
ck('if timer == 0x3C:' in jump and 'vy = -0x600' in jump,'Jump launches at timer $3C with -$600 Y velocity')
ck('vy = GenesisMath.s16(vy + 0x38)' in jump,'Jump uses retail +$38 gravity')
ck('if with_spikes and not spike_spawned and vy >= 0:' in jump,'Spike family emits projectiles on transition to downward travel')
ck('S2_SFX_SPIKE_SWITCH' in jump,'Spike emission uses supplied Spike Switch cue')
ck('var min_x:' not in mecha and 'var max_x:' not in mecha,'Phase132 artificial arena-edge bounce/clamp is removed')
ck('vx = speed if direction_toggle else -speed' in mecha,'loc_39D60 alternating left/right speed helper is represented')

# Exact radial projectiles.
expected=[(0,-24,0,-0x300,0x0F),(-16,-16,-0x200,-0x200,0x10),(-24,0,-0x300,0,0x11),(-16,16,-0x200,0x200,0x12),(0,24,0,0x300,0x13),(16,16,0x200,0x200,0x14),(24,0,0x300,0,0x15),(16,-16,0x200,-0x200,0x16)]
block=mecha[mecha.index('const SPIKE_DATA: Array = ['):mecha.index(']\n\n# User-supplied',mecha.index('const SPIKE_DATA: Array = ['))+1]
rows=re.findall(r'\[\s*(-?0x[0-9A-Fa-f]+|-?\d+)\s*,\s*(-?0x[0-9A-Fa-f]+|-?\d+)\s*,\s*(-?0x[0-9A-Fa-f]+|-?\d+)\s*,\s*(-?0x[0-9A-Fa-f]+|-?\d+)\s*,\s*(0x[0-9A-Fa-f]+|\d+)\s*\]',block)
def parse_num(s):
    sign=-1 if s.startswith('-') else 1; t=s[1:] if sign<0 else s; return sign*int(t,0)
actual=[tuple(parse_num(x) for x in row) for row in rows]
ck(actual==expected,'All eight radial spike offsets/velocities/mapping frames match byte_39D92')
ck('p.width_radius + 5' in mecha and 'p.height_radius + 4' in mecha,'Radial spikes use ObjAF projectile 5x4 hazard radii')

# Hit/defeat lifecycle.
contact=mecha[mecha.index('func _check_player_contact'):mecha.index('func _begin_defeat')]
ck('invulnerability_timer = 0x20' in contact,'Mecha hit flash remains $20')
defeat=mecha[mecha.index('func _begin_defeat'):mecha.index('func _update_visual')]
ck('timer = 0xFF' in defeat,'Mecha defeat timer remains $FF')
ck('manager.boss_limit_right = 0x1000' in defeat,'Mecha defeat reopens DEZ camera right boundary')
ck('manager.s2_dez_mecha_defeated = true' in defeat,'Mecha defeat advances DEZ event bridge')

# Final boss remains intentionally deferred.
dezroute=om[om.index('if bool(level_definition.get("experimental_sonic2", false)):'):om.index('\tmatch id:',om.index('if bool(level_definition.get("experimental_sonic2", false)):')+1)]
ck('0xC6' not in dezroute and '0xC7' not in dezroute,'Final DEZ Objects $C6/$C7 remain deferred for the next phase')

# Source verification if retail tree supplied.
if S2 is not None:
    asm=(S2/'s2.asm').read_text(errors='replace')
    source_seq=re.search(r'byte_398B0:\n((?:\s*dc\.b[^\n]*\n){16})',asm)
    vals=[]
    if source_seq:
        for line in source_seq.group(1).splitlines():
            m=re.search(r'dc\.b\s+\$?([0-9A-Fa-f]+)',line)
            if m: vals.append(int(m.group(1),16 if '$' in m.group(0) else 10))
    ck(vals==seq,'Implemented attack selector matches retail byte_398B0')
    ck('moveq\t#SndID_Fire,d0' in asm and 'andi.b\t#$1F,d0' in asm,'Retail source confirms falling Fire cue every $20 VBlanks')
    ck('move.w\t#$800,d0' in asm and 'move.w\t#$400,d0' in asm,'Retail source confirms $800 ground/spin and $400 jump horizontal speeds')
    ck('move.w\t#-$600,y_vel(a0)' in asm and 'addi.w\t#$38,y_vel(a0)' in asm,'Retail source confirms -$600 jump and +$38 gravity')
    ck('byte_39D92:' in asm and 'moveq\t#7,d6' in asm,'Retail source confirms eight radial spike projectiles')
    # Baseline level data remains exact.
    ck((P/'data/s1/s2test/dez1_objects.bin').read_bytes()==(S2/'level/objects/DEZ_1.bin').read_bytes(),'DEZ objects remain byte-for-byte retail')
    ck((P/'data/s1/palette/S2 Death Egg Zone.bin').read_bytes()==(S2/'art/palettes/DEZ.bin').read_bytes(),'DEZ palette remains byte-for-byte retail')

# Manifest hashes for corrected art/SFX.
for rel,digest in manifest.get('sha256',{}).items():
    ck(sha(rel)==digest,f'Phase133 artifact hash matches manifest: {rel}')

# Literal resource references and lightweight structure checks.
missing=[]
for gd in (P/'scripts').rglob('*.gd'):
    body=gd.read_text(errors='replace')
    for path in re.findall(r'(?:preload|load)\(\s*"(res://[^"%{}]+)"\s*\)',body):
        if not (P/path[6:]).exists(): missing.append((gd.relative_to(P),path))
ck(not missing,'All literal script preload/load res:// paths exist')
if missing:
    print('Missing refs:',missing[:20])

struct=['scripts/main.gd','scripts/render/ghz_background_renderer.gd','scripts/audio/sonic_audio.gd','scripts/objects/s2_cpz_traversal_object.gd','scripts/objects/s2_dez_mecha_sonic.gd']
for rel in struct:
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
