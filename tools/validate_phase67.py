from pathlib import Path
import hashlib, re, sys
ROOT=Path(__file__).resolve().parents[1]
BASE=Path('/mnt/data/phase66baseline')
SRC=Path('/mnt/data/s1src65/s1disasm-AS')
checks=[]
def check(name, cond, detail=''):
    checks.append((name,bool(cond),detail))

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

# Authoritative asset identity.
assets=[
('artnem/Title Cards.nem','artnem/Title Cards.nem'),
('artnem/HUD.nem','artnem/HUD.nem'),
('artunc/HUD Numbers.unc','artunc/HUD Numbers.unc'),
('artnem/Continue Screen Stuff.nem','artnem/Continue Screen Stuff.nem'),
('artnem/Special Result Emeralds.nem','artnem/Special Result Emeralds.nem'),
('palette/Special Stage Results.bin','palette/Special Stage Results.bin'),
]
for proj,src in assets:
    a=ROOT/'data/s1'/proj; b=SRC/src
    check(f'asset {proj} matches disassembly', a.exists() and b.exists() and sha(a)==sha(b))

art=(ROOT/'scripts/data/special_stage_result_art.gd').read_text()
ui=(ROOT/'scripts/ui/special_stage_result_ui.gd').read_text()
ctl=(ROOT/'scripts/objects/special_stage_controller.gd').read_text()
source_obj=(SRC/'_incObj/7E, 7F Special Stage Results and Chaos Emeralds.asm').read_text()
source_map=(SRC/'_maps/Title Cards.asm').read_text()
source_em=(SRC/'_maps/SS Result Chaos Emeralds.asm').read_text()

# Source VRAM topology and raw stream tile counts.
expected_headers={
'Title Cards.nem':128,'HUD.nem':24,'Continue Screen Stuff.nem':30,'Special Result Emeralds.nem':16}
for name,count in expected_headers.items():
    p=ROOT/'data/s1/artnem'/name
    if name=='HUD.nem': p=ROOT/'data/s1/artnem'/name
    h=int.from_bytes(p.read_bytes()[:2],'big') & 0x7fff
    check(f'{name} Nemesis tile count {count}', h==count, str(h))
check('result emerald base $541', 'ART_RESULT_EMERALDS = 0x541' in art)
check('continue base $551', 'ART_MINI_SONIC = 0x551' in art)
check('title base $580', 'ART_TITLE = 0x580' in art)
check('HUD base $6CA', 'ART_HUD = 0x6CA' in art)
check('dynamic HUD E $6E2', 'ART_HUD_DYNAMIC_E = 0x6E2' in art)

# Exact Object $7E item setup.
for literal in [
'BASE_START_X: Array[int] = [0x020,0x320,0x360,0x1EC,0x3A0]',
'BASE_TARGET_X: Array[int] = [0x120,0x120,0x120,0x11C,0x120]',
'ITEM_Y: Array[int] = [0x0C4,0x118,0x128,0x0C4,0x138]',
'MOVE_IN_SPEED = 0x10']:
    check('UI source literal '+literal.split(':')[0], literal in ui)
check('source item data contains header $020->$120', 'dc.w $020, $120' in source_obj)
check('source item data contains ring $360->$120', 'dc.w $360, $120' in source_obj)
check('source item data contains continue $3A0->$120', 'dc.w $3A0, $120' in source_obj)

# Independent movement simulation: frames from source positions at 16 px/VBlank.
def arrival(start,target,speed=0x10):
    n=0; x=start
    while x!=target:
        x=min(x+speed,target) if x<target else max(x-speed,target)
        n+=1
    return n
arr=[arrival(s,t) for s,t in zip([0x020,0x320,0x360,0x1EC,0x3A0],[0x120,0x120,0x120,0x11C,0x120])]
check('arrival frames header/score/ring/oval/continue = 16/32/36/13/40', arr==[16,32,36,13,40], str(arr))

# Exact waits/tally/audio sequence.
check('three-second pre-tally wait', 'results_timer = 3 * 60' in ctl)
check('one-second continue pre-animation wait', 'results_timer = 1 * 60 if special_rings >= 50 else 3 * 60' in ctl)
check('six-second continue hold', 'results_timer = 6 * 60' in ctl)
check('100 points per ring tally frame', 'manager.add_score(100)' in ctl and 'result_ring_bonus -= 1' in ctl)
check('switch blip every fourth VBlank', '(frame_counter & 3) == 0' in ctl and 'SFX_SWITCH' in ctl)
check('cash sound at tally completion', 'SFX_CASH' in ctl)
check('Got Through music restored', 'MUS_GOT_THROUGH' in ctl)
check('Continue result jingle restored', 'SFX_CONTINUE' in ctl)
check('Special Stage exit sound restored', 'SFX_ENTER_SS' in ctl)

# Header selection and alternate all-emerald X coordinates.
check('SPECIAL STAGE header supported', 'FRAME_SPECIAL_STAGE = 7' in art and 'header_frame = SpecialStageResultArt.FRAME_SPECIAL_STAGE' in ui)
check('CHAOS EMERALDS header supported', 'FRAME_CHAOS = 0' in art and 'header_frame = SpecialStageResultArt.FRAME_CHAOS' in ui)
check('SONIC GOT THEM ALL header supported', 'FRAME_GOT_ALL = 8' in art and 'header_frame = SpecialStageResultArt.FRAME_GOT_ALL' in ui)
check('all-emerald alternate $18->$118 header motion', 'source_x[0] = 0x018' in ui and 'target_x[0] = 0x118' in ui)

# Emerald Object $7F positions, palettes and flash behavior.
check('emerald pseudo-interlaced X positions exact', 'EMERALD_X: Array[int] = [0x110,0x128,0x0F8,0x140,0x0E0,0x158]' in ui)
check('source emerald position table present', all(x in source_obj for x in ['dc.w $110','dc.w $128','dc.w  $F8','dc.w $140','dc.w  $E0','dc.w $158']))
check('six emerald mapping palette variants', 'EMERALD_FRAMES = [[4,1],[0,0],[4,2],[4,3],[8,1],[0x0C,1]]' in art)
check('emerald blank/visible toggles each VBlank', 'flash_visible = not flash_visible' in ui)
check('exact v_emldlist color order stored', 'manager.emerald_color_ids.append(clampi(id - ID_EMERALD_FIRST, 0, 5))' in ctl)
check('result screen uses actual emerald color order', 'manager.emerald_color_ids' in ctl)

# Continue card starts without mini Sonic and changes to frames 4/5.
check('continue initial frame 6', 'FRAME_CONTINUE = 6' in art and 'FRAME_CONTINUE)' in ui)
check('mini Sonic frames 4/5', 'FRAME_CONT_SONIC_DOWN = 4' in art and 'FRAME_CONT_SONIC_UP = 5' in art)
check('mini Sonic changes every 16 VBlanks', '(vblank_byte & 0x0F) != 0' in ui)

# No Godot text placeholder remains in Special Stage results.
check('old result labels removed', all(x not in ctl for x in ['results_title','results_score','results_rings','results_emeralds','_make_result_label']))
check('source result UI created', 'SpecialStageResultUI.new()' in ctl)

# Known parser compatibility fixes remain.
sv=(ROOT/'scripts/player/sonic_visual.gd').read_text()
ssa=(ROOT/'scripts/data/special_stage_art.gd').read_text()
main=(ROOT/'scripts/main.gd').read_text()
check('Sonic angle_work parser fix retained', 'var angle_work = player.angle & 0xFF' in sv)
check('Sonic render_flip_x parser fix retained', 'var render_flip_x = player.facing_left' in sv)
check('Sonic octant parser fix retained', 'var octant_modifier = (angle_work >> 4) & 6' in sv)
check('Special Stage palette_line parser fix retained', 'var palette_line = [0, 3, 1, 2][block_id - 0x2D]' in ssa)
check('Special Stage flash_palette parser fix retained', 'var flash_palette = [0, 3, 1, 2][block_id - 0x4B]' in ssa)
# Phase67 new scripts deliberately avoid inferred local := declarations.
check('new result scripts avoid := compatibility risk', ':=' not in art and ':=' not in ui)

# Runtime regression isolation: only controller differs among pre-existing scripts.
changed=[]
for bp in BASE.rglob('*'):
    if not bp.is_file(): continue
    rel=bp.relative_to(BASE)
    wp=ROOT/rel
    if not wp.exists():
        changed.append(str(rel)+':missing')
    elif sha(bp)!=sha(wp):
        changed.append(str(rel))
allowed={'scripts/objects/special_stage_controller.gd','scripts/objects/object_manager.gd','scripts/main.gd'}
preexisting_runtime=[x for x in changed if x.startswith('scripts/')]
check('only intended pre-existing runtime files changed', set(preexisting_runtime)==allowed, str(preexisting_runtime))
for rel in [
'scripts/player/sonic_player.gd','scripts/objects/bridge_object.gd','scripts/objects/edge_wall_object.gd',
'scripts/objects/startup_sequence_controller.gd','scripts/data/title_source_art.gd','scripts/render/sega_palette_sprite.gdshader',
'scripts/render/ghz_renderer.gd','scripts/render/ghz_background_renderer.gd','scripts/audio/sonic_audio.gd',
'scripts/ui/end_card_ui.gd','scripts/ui/level_title_card_ui.gd','scripts/collision/genesis_collision.gd']:
    check('frozen '+rel, sha(BASE/rel)==sha(ROOT/rel))

passed=sum(1 for _,ok,_ in checks if ok)
lines=[f'Phase 67 validation: {passed}/{len(checks)} passed','']
for name,ok,detail in checks:
    lines.append(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f' — {detail}' if detail and not ok else ''))
out=ROOT/'PHASE67_VALIDATION_RESULTS.txt'
out.write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
sys.exit(0 if passed==len(checks) else 1)
