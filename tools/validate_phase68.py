from pathlib import Path
from collections import Counter
import hashlib,re,sys
ROOT=Path(__file__).resolve().parents[1]
BASE=Path('/mnt/data/phase67baseline68')
SRC=Path('/mnt/data/s1src/extracted/s1disasm-AS')
checks=[]
def check(name,cond,detail=''): checks.append((name,bool(cond),detail))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

# Exact source asset.
proj_art=ROOT/'data/s1/artnem/SBZ Small Vertical Door.nem'
src_art=SRC/'artnem/SBZ Small Vertical Door.nem'
check('SBZ small-door art exists',proj_art.exists())
check('SBZ small-door art byte-identical to disassembly',proj_art.exists() and sha(proj_art)==sha(src_art),sha(proj_art) if proj_art.exists() else '')

src_obj=(SRC/'_incObj/2A SBZ Small Door.asm').read_text()
src_anim=(SRC/'_anim/SBZ Small Door.asm').read_text()
src_map=(SRC/'_maps/SBZ Small Door.asm').read_text()
obj=(ROOT/'scripts/objects/sbz_small_door_object.gd').read_text()
art=(ROOT/'scripts/data/source_object_art.gd').read_text()
om=(ROOT/'scripts/objects/object_manager.gd').read_text()

# Source constants/structure.
check('source horizontal trigger is 64px', 'move.w\t#64,d1' in src_obj)
check('source display half-width is 8', 'move.b\t#16/2,obActWid(a0)' in src_obj)
check('source collision passes 6 + Sonic width', 'move.w\t#12/2+sonic_solid_width,d1' in src_obj)
check('source collision half-height is 32', 'move.w\t#64/2,d2' in src_obj)
check('source stood-on height is +1', 'addq.w\t#1,d3' in src_obj)
check('source solid only while mapping frame zero', 'tst.b\tobFrame(a0)' in src_obj and 'bsr.w\tSolidObject' in src_obj)
check('source opening script is 0..8', 'dc.b 0, 1, 2, 3, 4, 5, 6, 7' in src_anim and '\n\t\tdc.b 8' in src_anim)
check('source closing script is 8..0', 'dc.b 8, 7, 6, 5, 4, 3, 2, 1' in src_anim and '\n\t\tdc.b 0' in src_anim)
check('source animation delay is zero', '.close:\t\tdc.b 0' in src_anim and '.open:\t\tdc.b 0' in src_anim)
check('source has nine mapping frames', src_map.count('mappingsTableEntry.w')==9, str(src_map.count('mappingsTableEntry.w')))
check('source door pieces are 2x4', src_map.count('spritePiece')==18 and all('2, 4' in line for line in src_map.splitlines() if 'spritePiece' in line))

# Runtime translation literals.
for name,literal in [
('Object $2A has dedicated class','class_name SBZSmallDoorObject'),
('Object $2A dispatch installed','0x2A:\n\t\t\treturn SBZSmallDoorObjectClass.new()'),
('active width 8','active_width = 8'),
('trigger left boundary','px + 64 >= spawn_x'),
('trigger right boundary','px - 64 < spawn_x'),
('left approach orientation','wanted_open = not x_flip'),
('right approach orientation','wanted_open = x_flip'),
('opening starts frame zero','_set_frame(0 if opening else 8)'),
('opening advances one frame/VBlank','_set_frame(door_frame + 1)'),
('closing advances one frame/VBlank','_set_frame(door_frame - 1)'),
('solid only at frame zero','if door_frame == 0:'),
('initial collision 12x64','resolve_solid_box_contact(spawn_x, spawn_y, 6, 32, true, record_index)'),
('stood-on top uses 33px','resolve_platform_top(spawn_x - 6, spawn_x + 6, spawn_y - 33, record_index)'),
]: check(name,literal in (om if 'dispatch' in name else obj))

check('source-art renderer has nine frames','frame = clampi(frame, 0, 8)' in art and 'var separation = frame * 4' in art)
check('source-art top half mapping motion','32 - separation' in art)
check('source-art bottom half mapping motion','64 + separation' in art)
check('source-art applies mapping Y flip',art.count('false, true, 3)')>=2)
check('source-art uses palette line 3','false, true, 3)' in art)
check('SBZ1/SBZ2 palette selection retained','"SBZ Act 2.bin" if act == 2 else "SBZ Act 1.bin"' in art)

# Direct 68000 trigger simulation vs translated predicate for every retail door
# over a +/-100px neighborhood and both status orientations.
def ref_open(px,ox,xflip):
    d0=(px+64)&0xffff
    if d0 < (ox&0xffff): return False
    d0=(d0-64-64)&0xffff
    if d0 >= (ox&0xffff): return False
    d0=(d0+64)&0xffff
    if d0 >= (ox&0xffff):
        return bool(xflip)
    return not bool(xflip)
def port_open(px,ox,xflip):
    if px+64 >= ox and px-64 < ox:
        return (not xflip) if px < ox else bool(xflip)
    return False

doors=[]
for fn in ['sbz1 (REV01).bin','sbz2.bin']:
    data=(ROOT/'data/s1/objpos'/fn).read_bytes(); off=0
    while off+5<len(data):
        x=(data[off]<<8)|data[off+1]
        if x==0xffff: break
        yf=(data[off+2]<<8)|data[off+3]; oid=data[off+4]&0x7f
        if oid==0x2a: doors.append((fn,x,yf&0xfff,bool(yf&0x4000)))
        off+=6
mismatch=[]
for fn,x,y,xf in doors:
    for px in range(x-100,x+101):
        for orient in [False,True]:
            if ref_open(px,x,orient)!=port_open(px,x,orient): mismatch.append((fn,x,px,orient)); break
check('door trigger matches 68000 comparisons around every retail placement',not mismatch,str(mismatch[:4]))
check('retail Object $2A placement count is 14',len(doors)==14,str(len(doors)))
check('SBZ1 has 8 small doors',sum(1 for d in doors if d[0].startswith('sbz1'))==8)
check('SBZ2 has 6 small doors',sum(1 for d in doors if d[0]=='sbz2.bin')==6)
check('retail door orientation split includes both directions',any(d[3] for d in doors) and any(not d[3] for d in doors))

# Stable desired animation sequences from AnimateSprite delay=0 + afBack,1.
def port_seq(opening,start,steps):
    frame=start; out=[]; prev=-1
    wanted=1 if opening else 0
    for _ in range(steps):
        if wanted!=prev:
            prev=wanted; frame=0 if opening else 8
        elif opening and frame<8: frame+=1
        elif (not opening) and frame>0: frame-=1
        out.append(frame)
    return out
check('opening sequence exact 0..8 then hold',port_seq(True,0,11)==[0,1,2,3,4,5,6,7,8,8,8],str(port_seq(True,0,11)))
check('closing sequence exact 8..0 then hold',port_seq(False,8,11)==[8,7,6,5,4,3,2,1,0,0,0],str(port_seq(False,8,11)))

# Placed-object coverage milestone. Parse the current dispatch match block.
all_ids=set()
for p in (ROOT/'data/s1/objpos').glob('*.bin'):
    b=p.read_bytes(); off=0
    while off+5<len(b):
        x=(b[off]<<8)|b[off+1]
        if x==0xffff: break
        all_ids.add(b[off+4]&0x7f); off+=6
block=om[om.index('func _make_object_for_id'):om.index('func _load_objpos')]
dispatch=set(int(x,16) for x in re.findall(r'0x([0-9A-Fa-f]{2})',block))
missing=sorted(all_ids-dispatch)
check('every placed retail object ID has explicit dispatch',not missing,','.join(f'{x:02X}' for x in missing))
# Baseline should demonstrate why Phase68 exists.
base_om=(BASE/'scripts/objects/object_manager.gd').read_text()
base_block=base_om[base_om.index('func _make_object_for_id'):base_om.index('func _load_objpos')]
base_dispatch=set(int(x,16) for x in re.findall(r'0x([0-9A-Fa-f]{2})',base_block))
check('Phase67 baseline sole placed-ID dispatch gap was $2A',sorted(all_ids-base_dispatch)==[0x2a],str(sorted(all_ids-base_dispatch)))

# Regression isolation.
def changed_files():
    out=[]
    for bp in BASE.rglob('*'):
        if not bp.is_file(): continue
        rel=bp.relative_to(BASE); wp=ROOT/rel
        if not wp.exists() or sha(bp)!=sha(wp): out.append(str(rel))
    return out
changed=changed_files(); runtime=[x for x in changed if x.startswith('scripts/')]
allowed={'scripts/objects/object_manager.gd','scripts/data/source_object_art.gd'}
check('only intended pre-existing runtime scripts changed',set(runtime)==allowed,str(runtime))
for rel in [
'scripts/player/sonic_player.gd','scripts/objects/bridge_object.gd','scripts/objects/edge_wall_object.gd',
'scripts/objects/startup_sequence_controller.gd','scripts/objects/special_stage_controller.gd',
'scripts/ui/special_stage_result_ui.gd','scripts/ui/end_card_ui.gd','scripts/ui/level_title_card_ui.gd',
'scripts/render/ghz_renderer.gd','scripts/render/ghz_background_renderer.gd','scripts/audio/sonic_audio.gd',
'scripts/collision/genesis_collision.gd']:
    check('frozen '+rel,sha(BASE/rel)==sha(ROOT/rel))

# Parser compatibility carry-forward.
sv=(ROOT/'scripts/player/sonic_visual.gd').read_text(); ss=(ROOT/'scripts/data/special_stage_art.gd').read_text()
check('Sonic angle_work parser fix retained','var angle_work = player.angle & 0xFF' in sv)
check('Sonic render_flip_x parser fix retained','var render_flip_x = player.facing_left' in sv)
check('Sonic octant parser fix retained','var octant_modifier = (angle_work >> 4) & 6' in sv)
check('Special Stage palette_line parser fix retained','var palette_line = [0, 3, 1, 2][block_id - 0x2D]' in ss)
check('Special Stage flash_palette parser fix retained','var flash_palette = [0, 3, 1, 2][block_id - 0x4B]' in ss)
check('new door local inference avoids :=','var wanted_open :=' not in obj)

passed=sum(ok for _,ok,_ in checks)
lines=[f'Phase 68 validation: {passed}/{len(checks)} passed','']
for name,ok,detail in checks:
    lines.append(f"[{'PASS' if ok else 'FAIL'}] {name}"+(f' — {detail}' if detail and not ok else ''))
(ROOT/'PHASE68_VALIDATION_RESULTS.txt').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
sys.exit(0 if passed==len(checks) else 1)
