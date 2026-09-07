class_name S2MTZObject
extends GenesisLevelObject

# Phase 120: zone-local Metropolis object adapter.  These IDs overlap objects
# from other Sonic 2 zones, so they are deliberately translated here rather
# than falling through to CPZ/ARZ/OOZ implementations.

var sprite: Sprite2D
var aux_sprite: Sprite2D
var orig_x: int = 0
var orig_y: int = 0
var state: int = 0
var timer: int = 0
var frame_counter: int = 0
var vel_x: int = 0
var vel_y: int = 0
var displacement: int = 0
var direction: int = 1
var remembered_standing: bool = false
var button_pressed_last: bool = false
var platform_fixed_x: int = 0
var platform_fixed_y: int = 0
var platform_segment_index: int = 0
var gear_rider_tooth: int = -1
var gear_step: int = 0
var gear_last_advance_frame: int = -1

# Obj42 steam children.
var steam_fx: Array = []

# Obj65 platform/cog state.
var platform_shape: int = 0
var platform_mode: int = 0
var platform_limit: int = 0
var platform_trigger: int = 0
var platform_motion_started: bool = false
var platform_cog: Sprite2D
var platform_cog_world_x: int = 0
var platform_cog_world_y: int = 0
const COG_FRAMES: Array[int] = [0,0,2,2,2,1,1,1]

# Obj67 spin tube state.
var cylinder_angle: int = 0
var tube_state: int = 0
var tube_angle: int = 0
var tube_path: Array[Vector2i] = []
var tube_target_index: int = 0
var tube_fixed_x: int = 0
var tube_fixed_y: int = 0
var tube_segment_timer: int = 0
var tube_reverse: bool = false
var tube_current_target: Vector2i = Vector2i.ZERO

# Obj68 / Obj6D spikes.
var spike_sprite: Sprite2D
var spike_offset: int = 0
var spike_direction: int = 0
var spike_expanding: bool = true
var spike_waiting: bool = false
var spike_wait: int = 0

# Obj69 nut.
var nut_turn: int = 0
var nut_max_drop: int = 0
var nut_falling: bool = false
var nut_landed: bool = false
var nut_fixed_y: int = 0
var nut_player_mode: int = 0
var nut_side: int = 0

# Obj6B platform.
var bounce_accel: int = 0

# Phase 123 Act-2 families.
var lava_cups: Array = []
var gear_sprites: Array = []
var gear_prev_positions: Array[Vector2i] = []
var lava_bubble_anim: int = 0
var lava_bubble_timer: int = 0

const LAVA_CUP_PATHS: Array = [
	[Vector2i(0,0),Vector2i(-0x16,0x0A),Vector2i(-0x20,0x20),Vector2i(-0x20,0xE0),Vector2i(-0x16,0xF6),Vector2i(0,0x100),Vector2i(0x16,0xF6),Vector2i(0x20,0xE0),Vector2i(0x20,0x20),Vector2i(0x16,0x0A)],
	[Vector2i(0,0),Vector2i(-0x16,0x0A),Vector2i(-0x20,0x20),Vector2i(-0x20,0x160),Vector2i(-0x0A,0x176),Vector2i(0,0x180),Vector2i(0x16,0x176),Vector2i(0x20,0x160),Vector2i(0x20,0x20),Vector2i(0x16,0x0A)],
	[Vector2i(0,0),Vector2i(-0x16,0x0A),Vector2i(-0x20,0x20),Vector2i(-0x20,0x1E0),Vector2i(-0x0A,0x1F6),Vector2i(0,0x200),Vector2i(0x16,0x1F6),Vector2i(0x20,0x1E0),Vector2i(0x20,0x20),Vector2i(0x16,0x0A)],
]
const LAVA_CUP_SPAWN: Array = [
	[[0,0,0x01],[-0x20,0x3A,0x03],[-0x20,0x80,0x03],[-0x20,0xC6,0x03],[0,0x100,0x06],[0x20,0xC6,0x08],[0x20,0x80,0x08],[0x20,0x3A,0x08]],
	[[0,0,0x11],[-0x20,0x5A,0x13],[-0x20,0xC0,0x13],[-0x20,0x126,0x13],[0,0x180,0x16],[0x20,0x126,0x18],[0x20,0xC0,0x18],[0x20,0x5A,0x18]],
	[[0,0,0x21],[-0x20,0x7A,0x23],[-0x20,0x100,0x23],[-0x20,0x186,0x23],[0,0x200,0x26],[0x20,0x186,0x28],[0x20,0x100,0x28],[0x20,0x7A,0x28]],
]
const GEAR_POSITIONS: Array = [
	[[0,-0x48,0],[0x32,-0x32,4],[0x48,0,8],[0x32,0x32,0x0C],[0,0x48,0x10],[-0x32,0x32,0x14],[-0x48,0,0x18],[-0x32,-0x32,0x1C]],
	[[0x0D,-0x48,1],[0x3F,-0x26,5],[0x48,0x0C,9],[0x27,0x3C,0x0D],[-0x0D,0x48,0x11],[-0x3F,0x26,0x15],[-0x48,-0x0C,0x19],[-0x27,-0x3C,0x1D]],
	[[0x19,-0x44,2],[0x46,-0x17,6],[0x46,0x17,0x0A],[0x19,0x44,0x0E],[-0x19,0x44,0x12],[-0x46,0x17,0x16],[-0x46,-0x17,0x1A],[-0x19,-0x44,0x1E]],
	[[0x27,-0x3C,3],[0x48,-0x0C,7],[0x3F,0x26,0x0B],[0x0D,0x48,0x0F],[-0x27,0x3C,0x13],[-0x48,0x0C,0x17],[-0x3F,-0x26,0x1B],[-0x0D,-0x48,0x1F]],
]

# Badnik transients.
var projectiles: Array = []
var attack_timer: int = 0
var attack_phase: int = 0
var body_hidden: bool = false
var shell_links: Array[Sprite2D] = []

# Retail misc/obj67.asm contains thirteen path tables shared by all three MTZ acts.
# Keeping the complete table here prevents later-act subtype indices from being
# silently clamped onto one of the three Act 1 paths.
const TUBE_PATHS: Array = [
	[Vector2i(0x7A8,0x270),Vector2i(0x750,0x270),Vector2i(0x740,0x280),Vector2i(0x740,0x3E0),Vector2i(0x750,0x3F0),Vector2i(0x7A8,0x3F0)],
	[Vector2i(0xC58,0x5F0),Vector2i(0xE28,0x5F0)],
	[Vector2i(0x1828,0x6B0),Vector2i(0x17D0,0x6B0),Vector2i(0x17C0,0x6C0),Vector2i(0x17C0,0x7E0),Vector2i(0x17B0,0x7F0),Vector2i(0x1758,0x7F0)],
	[Vector2i(0x5D8,0x370),Vector2i(0x780,0x370)],
	[Vector2i(0x5D8,0x5F0),Vector2i(0x700,0x5F0)],
	[Vector2i(0xBD8,0x1F0),Vector2i(0xC30,0x1F0),Vector2i(0xC40,0x1E0),Vector2i(0xC40,0x0C0),Vector2i(0xC50,0x0B0),Vector2i(0xCA8,0x0B0)],
	[Vector2i(0x1728,0x330),Vector2i(0x15D0,0x330),Vector2i(0x15C0,0x320),Vector2i(0x15C0,0x240),Vector2i(0x15D0,0x230),Vector2i(0x1628,0x230)],
	[Vector2i(0x6D8,0x1F0),Vector2i(0x730,0x1F0),Vector2i(0x740,0x1E0),Vector2i(0x740,0x100),Vector2i(0x750,0x0F0),Vector2i(0x7A8,0x0F0)],
	[Vector2i(0x7D8,0x330),Vector2i(0x828,0x330),Vector2i(0x840,0x340),Vector2i(0x840,0x458),Vector2i(0x828,0x470),Vector2i(0x7D8,0x470)],
	[Vector2i(0xFD8,0x3B0),Vector2i(0x1028,0x3B0),Vector2i(0x1040,0x398),Vector2i(0x1040,0x2C4),Vector2i(0x1058,0x2B0),Vector2i(0x10A8,0x2B0)],
	[Vector2i(0xFD8,0x4B0),Vector2i(0x1028,0x4B0),Vector2i(0x1040,0x4C0),Vector2i(0x1040,0x5D8),Vector2i(0x1058,0x5F0),Vector2i(0x10A8,0x5F0)],
	[Vector2i(0x2058,0x430),Vector2i(0x20A8,0x430),Vector2i(0x20C0,0x418),Vector2i(0x20C0,0x2C0),Vector2i(0x20D0,0x2B0),Vector2i(0x2128,0x2B0)],
	[Vector2i(0x2328,0x5B0),Vector2i(0x22D0,0x5B0),Vector2i(0x22C0,0x5A0),Vector2i(0x22C0,0x4C0),Vector2i(0x22D0,0x4B0),Vector2i(0x2328,0x4B0)],
]

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	match object_id:
		0x06: _init_cylinder()
		0x1C: _init_rope()
		0x2D: _init_barrier()
		0x42: _init_steam_spring()
		0x47: _init_button()
		0x64: _init_stomper()
		0x65: _init_long_platform()
		0x66: _init_spring_wall()
		0x67: _init_spin_tube()
		0x68: _init_spike_block()
		0x69: _init_nut()
		0x6A: _init_trigger_platform()
		0x31: _init_lava_marker()
		0x6B: _init_platform()
		0x6C: _init_lava_cups()
		0x70: _init_gear()
		0x71: _init_lava_bubble()
		0x72: _init_conveyor()
		0x6D: _init_floor_spike()
		0x6E: _init_circle_platform()
		0x74: _init_invisible_solid()
		0x9F: _init_shellcracker()
		0xA1: _init_slicer()
		0xA4: _init_asteron()

func tick() -> void:
	frame_counter += 1
	_tick_projectiles()
	match object_id:
		0x06: _tick_cylinder()
		0x1C: pass
		0x2D: _tick_barrier()
		0x42: _tick_steam_spring()
		0x47: _tick_button()
		0x64: _tick_stomper()
		0x65: _tick_long_platform()
		0x66: _tick_spring_wall()
		0x67: _tick_spin_tube()
		0x68: _tick_spike_block()
		0x69: _tick_nut()
		0x6A: _tick_trigger_platform()
		0x31: _tick_lava_marker()
		0x6B: _tick_platform()
		0x6C: _tick_lava_cups()
		0x70: _tick_gear()
		0x71: _tick_lava_bubble()
		0x72: _tick_conveyor()
		0x6D: _tick_floor_spike()
		0x6E: _tick_circle_platform()
		0x74: _tick_invisible_solid()
		0x9F: _tick_shellcracker()
		0xA1: _tick_slicer()
		0xA4: _tick_asteron()

func suppress_central_despawn() -> bool:
	# Obj67 must stay alive while it owns Sonic; deleting the controller before
	# the final path point would leave object_control set and soft-lock the run.
	return object_id == 0x67 and tube_state != 0

func central_despawn_x() -> int:
	# Retail Obj65 mode 5 rewrites objoff_34 from CURRENT x every frame before
	# MarkObjGone. Keep that rule after the platform reaches its terminal point too.
	if object_id == 0x65 and platform_motion_started:
		return int(round(position.x))
	return spawn_x

func apply_vertical_wrap_shift(delta_y: int) -> void:
	# MTZ is a $800-pixel torus. When the camera crosses its vertical seam, all
	# source-space anchors must move with the Node so routines do not snap the
	# object back to its unwrapped authored Y on the next tick.
	position.y += delta_y
	spawn_y += delta_y
	orig_y += delta_y
	platform_cog_world_y += delta_y
	if platform_fixed_y != 0:
		platform_fixed_y += delta_y << 16
	if nut_fixed_y != 0:
		nut_fixed_y += delta_y << 16
	if tube_state != 0:
		tube_fixed_y += delta_y << 16
		tube_current_target.y += delta_y
	# Phase 123 Act-2 groups keep their own world/fixed-point child state. Shift
	# that state with the parent so the $800-pixel MTZ torus cannot make a cup
	# or gear jump toward the opposite vertical image on the next behavior tick.
	for i in range(lava_cups.size()):
		var cup: Dictionary = lava_cups[i]
		cup["y"] = int(cup["y"]) + (delta_y << 16)
		cup["old_y"] = int(cup.get("old_y", 0)) + delta_y
		lava_cups[i] = cup
	for i in range(gear_prev_positions.size()):
		var gp: Vector2i = gear_prev_positions[i]
		gear_prev_positions[i] = Vector2i(gp.x, gp.y + delta_y)

func _source_visible(cx: int, cy: int, margin: int = 32) -> bool:
	return manager != null and manager.is_world_point_on_screen(cx,cy,margin)

func _new_sprite(folder: String, frame: int, z: int = 1) -> Sprite2D:
	return make_sprite("res://assets/objects/s2_mtz/%s/%02d.png" % [folder, frame], z)

func _set_frame(s: Sprite2D, folder: String, frame: int) -> void:
	if s == null:
		return
	var path: String = "res://assets/objects/s2_mtz/%s/%02d.png" % [folder, frame]
	if ResourceLoader.exists(path):
		s.texture = load(path)

func _trigger_get(index: int, bit: int = 0) -> bool:
	if manager == null or index < 0 or index >= manager.mcz_button_vine_triggers.size():
		return false
	return (int(manager.mcz_button_vine_triggers[index]) & (1 << bit)) != 0

func _trigger_set(index: int, value: bool, bit: int = 0) -> void:
	if manager == null or index < 0 or index >= manager.mcz_button_vine_triggers.size():
		return
	var mask: int = 1 << bit
	var current: int = int(manager.mcz_button_vine_triggers[index])
	if value:
		current |= mask
	else:
		current &= ~mask
	manager.mcz_button_vine_triggers[index] = current & 0xFF

func _carry_and_platform(p: SonicPlayer, old_x: int, old_y: int, half_w: int, half_h: int) -> bool:
	var nx: int = int(round(position.x))
	var ny: int = int(round(position.y))
	var top: int = ny - half_h
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, nx-old_x, ny-old_y, nx-half_w, nx+half_w, top)
	return p.resolve_platform_top(nx-half_w, nx+half_w, top, record_index)

func _hazard_overlap(cx: int, cy: int, hw: int, hh: int) -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		return
	if absi(p.pixel_x()-cx) <= hw+p.width_radius and absi(p.pixel_y()-cy) <= hh+p.height_radius:
		p.apply_hazard_hit(cx)

func _react_badnik(cx: int, cy: int, hw: int, hh: int) -> bool:
	var p: SonicPlayer = player()
	if p == null or p.dead or body_hidden:
		return false
	if absi(p.pixel_x()-cx) > hw+p.width_radius or absi(p.pixel_y()-cy) > hh+p.height_radius:
		return false
	if p.invincible_timer > 0 or p.rolling or p.object_attack_active:
		var award: int = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(cx, cy, award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
		return true
	p.apply_hazard_hit(cx)
	return false

# -----------------------------------------------------------------------------
# $06 - MTZ rotating-cylinder controller. Subtype $80 is invisible: the cylinder
# itself is level art.  Retail advances the rider around a 40-pixel radius using
# its global cylinder angle while preserving the normal stood-on relationship.
# -----------------------------------------------------------------------------
func _init_cylinder() -> void:
	visible = false
	active_width = 0xC0

func _tick_cylinder() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead or p.object_control_override:
		return
	var dx: int = p.pixel_x()-orig_x
	if p.standing_on_object and p.support_record_index == record_index:
		if p.in_air or absi(dx) >= 0xC0:
			p.clear_object_support_for(record_index,true)
			return
		# Obj06_Cylinder uses CalcSine's cosine output * $2800, then subtracts
		# (y_radius-$13).  Angle starts at zero on RideObject_SetRide and adds 4.
		var yoff: int = int((GenesisMath.cosine(cylinder_angle & 0xFF)*0x28)>>8)
		var py: int = orig_y+yoff-(p.height_radius-0x13)
		p.update_s2_spiral_pathway(record_index,orig_x-0xC0,orig_x+0xC0,py,cylinder_angle)
		p.vel_y=0;cylinder_angle=(cylinder_angle+4)&0xFF
		if p.inertia==0:p.inertia=1
		return
	if absi(dx)>=0xC0 or p.in_air:return
	# Source capture is the narrow -$10..0 depth band beneath y+$3C.
	var depth: int=(orig_y+0x3C)-(p.pixel_y()+p.height_radius+4)
	if depth<=0 and depth>=-0x10:
		p.force_add_pixel_offset(0,depth+3)
		p.begin_s2_spiral_pathway(record_index,orig_x-0xC0,orig_x+0xC0)
		cylinder_angle=0
		if p.inertia==0:p.inertia=1

# $1C subtype 3 - static bolt/rope scenery.
func _init_rope() -> void:
	active_width = 0x10
	sprite = _new_sprite("rope", 2, 1)
	sprite.flip_v = false

# -----------------------------------------------------------------------------
# $2D - one-way MTZ barrier. A character in the source-side rectangle raises it
# 8 pixels/frame to $40; otherwise it drops by the same amount.
# -----------------------------------------------------------------------------
func _init_barrier() -> void:
	active_width = 0x0C
	sprite = _new_sprite("barrier", 1, 1)
	sprite.flip_v = false

func _tick_barrier() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var left: int
	var right: int
	if not x_flip:
		left = orig_x-0x200
		right = orig_x+0x18
	else:
		left = orig_x-0x18
		right = orig_x+0x200
	var wants_up: bool = p.pixel_x() >= left and p.pixel_x() < right and p.pixel_y() >= orig_y-0x20 and p.pixel_y() < orig_y+0x20 and not p.object_control_override
	var old_y: int = int(round(position.y))
	if wants_up:
		displacement = mini(0x40, displacement+8)
	else:
		displacement = maxi(0, displacement-8)
	position.y = orig_y-displacement
	var new_y: int = int(round(position.y))
	# Keep an established standing relationship coherent while the door moves.
	# SonicPlayer's support helper performs the source-shaped one-final-carry on
	# jump and then blocks re-capture, avoiding the old MZ-style random shove.
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index,0,new_y-old_y,orig_x-0x0C,orig_x+0x0C,new_y-0x20)
	p.resolve_solid_box_contact(orig_x, new_y, 0x0C, 0x20, true, record_index)

# -----------------------------------------------------------------------------
# $42 - steam spring. Exact $3B waits and 8-pixel piston travel; the spring only
# fires while routine_secondary is the source retract phase.
# -----------------------------------------------------------------------------
func _init_steam_spring() -> void:
	active_width = 0x10
	sprite = _new_sprite("steam_spring", 7, 1)
	position.y = orig_y+0x10
	displacement = 0x10
	timer = 0x3B

func _spawn_steam(local_x: int, flip: bool) -> void:
	var s: Sprite2D = _new_sprite("steam", 0, 2)
	var wx: int=orig_x+local_x
	var wy: int=orig_y
	s.position = Vector2(wx-position.x, wy-position.y)
	s.flip_h = flip
	steam_fx.append({"sprite":s,"frame":0,"delay":7,"x":wx,"y":wy})

func _tick_steam_fx() -> void:
	for i in range(steam_fx.size()-1,-1,-1):
		var q: Dictionary = steam_fx[i]
		q["delay"] = int(q["delay"])-1
		if int(q["delay"]) < 0:
			q["delay"] = 7
			q["frame"] = int(q["frame"])+1
			var f: int = int(q["frame"])
			if f >= 7:
				(q["sprite"] as Sprite2D).queue_free()
				steam_fx.remove_at(i)
				continue
			_set_frame(q["sprite"] as Sprite2D,"steam",f)
		var ss: Sprite2D=q["sprite"] as Sprite2D
		ss.position=Vector2(float(q["x"])-position.x,float(q["y"])-position.y)
		if int(q["frame"]) == 3:
			_hazard_overlap(int(q["x"]),int(q["y"]),10,10)
		steam_fx[i] = q

func _tick_steam_spring() -> void:
	_tick_steam_fx()
	var p: SonicPlayer = player()
	if p == null:
		return
	var old_y: int = int(position.y)
	if state == 0:
		timer -= 1
		if timer < 0:
			timer = 0x3B
			state = 1
	elif state == 1:
		displacement = maxi(0, displacement-8)
		position.y = orig_y+displacement
		if displacement == 0:
			state = 2
			# Retail loc_266E4 creates the first steam child at +$28 and the
			# second at -$28 with horizontal flip.  The mapping itself is
			# asymmetric, so spawning at 0/+40 visibly puts both jets wrong.
			_spawn_steam(0x28,false)
			_spawn_steam(-0x28,true)
	elif state == 2:
		timer -= 1
		if timer < 0:
			timer = 0x3B
			state = 3
	else:
		displacement = mini(0x10, displacement+8)
		position.y = orig_y+displacement
		if displacement == 0x10:
			state = 0
	var ny: int = int(position.y)
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index,0,ny-old_y,orig_x-0x1B,orig_x+0x1B,ny-0x10)
	p.resolve_platform_top(orig_x-0x1B,orig_x+0x1B,ny-0x10,record_index)
	if state == 1 and p.standing_on_object and p.support_record_index == record_index:
		p.clear_object_support_for(record_index,true)
		p.vel_y = -0xA00
		if (subtype & 0x80) != 0:
			p.vel_x = 0
		p.in_air = true
		p.jumping = false
		p.spindash_active=false;p.spindash_counter=0
		p.begin_s2_spring_visual(subtype,0)
		SonicAudio.play_sfx(SonicAudio.SFX_SPRING)

# $47 - ButtonVine_Trigger switch.
func _init_button() -> void:
	active_width = 0x10
	position.y = orig_y+4
	sprite = _new_sprite("button",0,2)
	sprite.flip_v = false

func _tick_button() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	# Obj47_Main returns through MarkObjGone before touching ButtonVine_Trigger
	# when render_flags says the button is off screen.  This matters in MTZ1:
	# two horizontally loaded buttons share trigger byte 0, and the later,
	# off-screen one must not clear the bit set by the visible opening button.
	if not _source_visible(orig_x,int(position.y),32):
		button_pressed_last = false
		return
	var idx: int = subtype & 0x0F
	var trigger_bit: int = 7 if (subtype & 0x40) != 0 else 0
	var touched: bool = p.resolve_platform_top(orig_x-0x1B,orig_x+0x1B,int(position.y)-4,record_index)
	var pressed: bool = touched or (p.standing_on_object and p.support_record_index == record_index)
	if pressed:
		# Retail tests the whole trigger byte before playing Blip, then sets the
		# selected bit.  The local edge latch avoids replay if another bit is live.
		if not button_pressed_last and int(manager.mcz_button_vine_triggers[idx]) == 0:
			SonicAudio.play_sfx(SonicAudio.SFX_SWITCH)
		_trigger_set(idx,true,trigger_bit)
		_set_frame(sprite,"button",1)
	else:
		_trigger_set(idx,false,trigger_bit)
		_set_frame(sprite,"button",0)
	button_pressed_last = pressed

# -----------------------------------------------------------------------------
# $64 - twin stomper subtype 1. Retail uses 8px steps, a $40 stroke and $5A
# waits at both ends. Status X flip reverses which end is the home position.
# -----------------------------------------------------------------------------
func _init_stomper() -> void:
	# Obj64_Properties is selected by the high subtype nibble. Frame 0 is the
	# broad horizontal stomper; frame 1 is the narrow/tall piston. Placement
	# Y-flip is a real sprite flip and must not be discarded.
	var shape: int = (subtype >> 4) & 3
	var widths: Array[int] = [0x40,0x10,0x40,0x10]
	var radii: Array[int] = [0x0C,0x20,0x0C,0x20]
	active_width = widths[shape]
	platform_limit = 0x40
	sprite = _new_sprite("stomper",shape,1)
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip
	timer = 0

func _tick_stomper() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var old_x: int = int(position.x)
	var old_y: int = int(position.y)
	if state == 0:
		if displacement > 0:
			displacement = maxi(0,displacement-8)
		else:
			timer -= 1
			if timer < 0:
				timer=0x5A;state=1
	else:
		if displacement < 0x40:
			displacement = mini(0x40,displacement+8)
		else:
			timer -= 1
			if timer < 0:
				timer=0x5A;state=0
	var d: int = displacement
	if x_flip:
		d = 0x40-d
	position.y = orig_y+d
	var shape: int = (subtype >> 4) & 3
	var hw: int = [0x40,0x10,0x40,0x10][shape]
	var hh: int = [0x0C,0x20,0x0C,0x20][shape]
	_carry_and_platform(p,old_x,old_y,hw,hh)
	p.resolve_solid_box_contact(int(position.x),int(position.y),hw,hh,true,record_index)

# -----------------------------------------------------------------------------
# $65 - MTZ long platforms and synchronized cogs.
# -----------------------------------------------------------------------------
func _init_long_platform() -> void:
	platform_shape = (subtype >> 4) & 7
	# Obj65_Properties is indexed in four-byte strides: width/radius followed
	# by the next two bytes, which supply objoff_3C and the high-bit mode.
	var widths: Array[int] = [0x40,0x20,0x10,0x40,0x10,0x20,0x40,0x80]
	var radii: Array[int] = [0x0C,0x0C,0x10,0x0C,0x10,0,0x0C,7]
	active_width = widths[platform_shape]
	platform_limit = [0x80,0x40,0x00,0x80,0,0,0,0x80][platform_shape]
	platform_mode = subtype & 0x0F
	if platform_shape == 2:
		sprite = _new_sprite("cog",0,1)
		return
	sprite = _new_sprite("platform",clampi(platform_shape,0,3),1)
	sprite.flip_v = false
	if (subtype & 0x80) != 0:
		platform_trigger = subtype & 0x0F
		platform_mode = 7 if platform_shape == 3 else 1
		displacement = platform_limit if platform_mode == 7 else 0
		platform_cog = _new_sprite("cog",0,0)
		platform_cog_world_x = orig_x + (-0x4C if x_flip else -0x34)
		platform_cog_world_y = orig_y + 0x14
		platform_cog.flip_h = not x_flip
		platform_cog.position = Vector2(platform_cog_world_x-position.x,platform_cog_world_y-position.y)
		position.x = _platform_x_from_displacement()
	elif platform_mode == 3:
		# Obj65 mode 3's flipped property table starts at orig_x-$40 even with
		# zero displacement.  Initializing there is required for the Act-3
		# platform at $0F60,$0424 to overlap/activate from its authored rest pose.
		position.x = _platform_x_from_displacement()
	elif platform_mode == 4:
		platform_motion_started = false

func _platform_x_from_displacement() -> int:
	var d: int = displacement
	if x_flip:
		d = -d + (0x80 if (subtype & 0x80) != 0 else 0x40)
	return orig_x-d

func _tick_long_platform() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if platform_shape == 2:
		_set_frame(sprite,"cog",COG_FRAMES[manager.mtz_platform_cog_x & 7])
		return
	var old_x: int = int(round(position.x))
	var old_y: int = int(round(position.y))
	if (subtype & 0x80) != 0:
		# Source modes 1/7 wait for their ButtonVine trigger. Modes 2/6 are
		# the automatic $B4-delay return trip, so the platform always comes
		# back even after Sonic steps off the button.
		if platform_mode == 1:
			if not platform_motion_started and _trigger_get(platform_trigger): platform_motion_started=true
			if platform_motion_started:
				if displacement < platform_limit: displacement=mini(platform_limit,displacement+2)
				else: platform_mode=2;timer=0xB4;platform_motion_started=false
		elif platform_mode == 2:
			if not platform_motion_started:
				timer-=1
				if timer<=0: platform_motion_started=true
			if platform_motion_started:
				if displacement > 0: displacement=maxi(0,displacement-2)
				else: platform_mode=1;timer=0xB4;platform_motion_started=false
		elif platform_mode == 7:
			if not platform_motion_started and _trigger_get(platform_trigger): platform_motion_started=true
			if platform_motion_started:
				if displacement > 0: displacement=maxi(0,displacement-2)
				else: platform_mode=6;timer=0xB4;platform_motion_started=false
		else: # source mode 6
			if not platform_motion_started:
				timer-=1
				if timer<=0: platform_motion_started=true
			if platform_motion_started:
				if displacement < platform_limit: displacement=mini(platform_limit,displacement+2)
				else: platform_mode=7;timer=0xB4;platform_motion_started=false
		position.x = _platform_x_from_displacement()
	elif platform_mode == 3:
		var left: int = orig_x-0x20 if not x_flip else orig_x-0xA0
		var right: int = orig_x+0x60 if not x_flip else orig_x-0x20
		var near: bool = p.pixel_x()>=left and p.pixel_x()<right and p.pixel_y()>=orig_y-0x10 and p.pixel_y()<orig_y+0x40
		# The Godot player center sits farther above a solid top than retail's
		# center-window test assumes. Treat an actual feet-on-top overlap as the
		# same activation condition so the $0F60,$0424 Act-3 platform responds on
		# the first standing frame instead of waiting for stale support state.
		var platform_top: int = int(position.y)-0x0C
		var feet_y: int = p.pixel_y()+p.height_radius
		var on_top_now: bool = absi(feet_y-platform_top)<=6 and absi(p.pixel_x()-int(position.x))<=active_width+p.width_radius
		if on_top_now or (p.standing_on_object and p.support_record_index==record_index): near=true
		if near: displacement=mini(platform_limit,displacement+0x10)
		else: displacement=maxi(0,displacement-0x10)
		position.x = _platform_x_from_displacement()
	elif platform_mode == 4:
		if p.standing_on_object and p.support_record_index==record_index:
			platform_mode=5
			platform_motion_started=true
	elif platform_mode == 5:
		# Retail loc_26E4A always moves +2. MTZ1 alone reverses between $1880
		# and $1BC0; MTZ2/3 stop when reaching their authored terminal X.
		position.x += 2
		var current_act: int = int(manager.level_definition.get("act",1)) if manager != null else 1
		if current_act != 3:
			if direction > 0 and int(position.x)>=0x1BC0:
				direction=-1
			elif direction < 0:
				position.x -= 4 # net -2 after the unconditional +2 above
				if int(position.x)<=0x1880: direction=1
		elif int(position.x)==0x1CC0 or int(position.x)==0x2940:
			platform_mode=0
		manager.mtz_platform_cog_x=int(position.x)
	var nx: int = int(round(position.x))
	var half_h: int = [0x0C,0x0C,0x10,0x0C,0x10,0,0x0C,7][platform_shape]
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index,nx-old_x,0,nx-active_width,nx+active_width,int(position.y)-half_h)
	p.resolve_solid_box_contact(nx,int(position.y),active_width,half_h,true,record_index)
	if platform_cog != null:
		platform_cog.position=Vector2(platform_cog_world_x-position.x,platform_cog_world_y-position.y)
		_set_frame(platform_cog,"cog",COG_FRAMES[displacement & 7])

# $66 - invisible vertical spring wall; art is baked into MTZ foreground.
func _init_spring_wall() -> void:
	visible = false
	active_width = 8

func _tick_spring_wall() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		return
	var hh: int = 0x80 if ((subtype>>4)&7)!=0 else 0x40
	# Retail calls SolidObject first, then applies the spring impulse when the
	# returned contact is a side collision.  Doing this in the opposite order let
	# the solid resolver cancel the fresh velocity, producing one bounce followed
	# by a slide down the wall.
	p.resolve_solid_box_contact(orig_x,orig_y,8,hh,true,record_index)
	var dx: int = p.pixel_x()-orig_x
	var dy: int = p.pixel_y()-orig_y
	if p.in_air and absi(dy)<=hh+p.height_radius and absi(dx)<=0x13+p.width_radius:
		var correct_side: bool = (dx>0 and not x_flip) or (dx<0 and x_flip)
		if correct_side:
			p.vel_x = 0x800 if dx>0 else -0x800
			p.vel_y = 0 if (subtype & 0x80) != 0 else -0x800
			p.inertia = p.vel_x
			p.in_air = true
			p.jumping = false
			p.facing_left = p.vel_x < 0
			p.lock_time = 0x0F
			if (subtype & 1) != 0:
				p.begin_s2_spring_visual(subtype,3)
			SonicAudio.play_sfx(SonicAudio.SFX_SPRING)

# -----------------------------------------------------------------------------
# $67 - MTZ spin tube. All thirteen retail paths are copied from misc/obj67.asm.
# -----------------------------------------------------------------------------
func _init_spin_tube() -> void:
	active_width=0x10
	sprite=_new_sprite("spin_tube_flash",0,3)
	sprite.flip_v=false
	# Retail treats subtype as signed. Negative subtypes traverse the selected
	# table backwards; simply masking the low nibble loses that behavior.
	var signed_sub: int = subtype if subtype < 0x80 else subtype - 0x100
	tube_reverse = signed_sub < 0
	var idx: int = ((-signed_sub) if tube_reverse else signed_sub) & 0x0F
	if idx >= TUBE_PATHS.size():
		push_warning("MTZ spin-tube path index %d is outside retail table" % idx)
		idx = 0
	tube_path.clear()
	for point in TUBE_PATHS[idx]:
		tube_path.append(Vector2i(point))

func _release_tube(p: SonicPlayer) -> void:
	tube_state=0
	p.object_control_override=false
	p.force_set_pixel_position(p.pixel_x(),p.pixel_y() & 0x7FF)
	if (subtype & 0x10)==0:
		p.vel_x=0;p.vel_y=0;p.inertia=0
	_set_frame(sprite,"spin_tube_flash",0)

func _tube_wrapped_point(raw: Vector2i, reference_y: int) -> Vector2i:
	# MTZ is an $800-pixel vertical torus. Use the nearest image of every path
	# node, matching the player's current wrapped image instead of jumping to raw Y.
	var ty: int = raw.y
	while ty-reference_y > 0x400: ty -= 0x800
	while ty-reference_y < -0x400: ty += 0x800
	return Vector2i(raw.x,ty)

func _start_tube_segment(p: SonicPlayer) -> void:
	if tube_target_index<0 or tube_target_index>=tube_path.size():
		_release_tube(p);return
	var cx: int=tube_fixed_x>>16;var cy: int=tube_fixed_y>>16
	tube_current_target = _tube_wrapped_point(tube_path[tube_target_index],cy)
	var dx: int=tube_current_target.x-cx;var dy: int=tube_current_target.y-cy
	var ax: int=absi(dx);var ay: int=absi(dy)
	# Obj67 loc_27374/loc_273C4 fixes the dominant axis at $1000 and
	# stores the high byte of (distance<<16)/$1000 as its segment timer.
	# That is floor(dominant_distance/16), with the timer decremented BEFORE
	# each movement step. Reproducing that order avoids overshooting short
	# diagonal corners and then snapping backward at the next tube node.
	if ay>=ax:
		p.vel_y=0x1000 if dy>=0 else -0x1000
		p.vel_x=0 if ay==0 else int((dx*0x1000)/ay)
		tube_segment_timer=maxi(0,ay >> 4)
	else:
		p.vel_x=0x1000 if dx>=0 else -0x1000
		p.vel_y=0 if ax==0 else int((dy*0x1000)/ax)
		tube_segment_timer=maxi(0,ax >> 4)

func _tick_spin_tube() -> void:
	var p: SonicPlayer=player()
	if p==null:return
	if tube_state!=0:
		var flash_seq: Array[int]=[1,0,0,0,0,0,0,1,0,0,0,1,0,0,1,0]
		_set_frame(sprite,"spin_tube_flash",flash_seq[int(frame_counter/2)%flash_seq.size()])
	if tube_state==0:
		if p.dead or p.debug_free_mode or p.object_control_override:return
		var dx: int=p.pixel_x()-orig_x+3+(0xA if x_flip else 0)
		var dy: int=p.pixel_y()-orig_y+0x20
		if dx>=0 and dx<0x10 and dy>=0 and dy<0x40:
			tube_state=1;tube_angle=0;p.clear_object_support();p.object_control_override=true
			p.rolling=true;p.in_air=true;p.jumping=false;p.inertia=0x800;p.vel_x=0;p.vel_y=0
			p.force_set_pixel_position(orig_x,orig_y);_set_frame(sprite,"spin_tube_flash",1)
			SonicAudio.play_sfx(SonicAudio.SFX_ROLL)
		return
	if p.dead:
		_release_tube(p);return
	# While Object $67 owns Sonic, no other controller may clear object-control
	# between segments. Reassert it every frame just like status $81 remains set
	# in retail until the final path node releases the character.
	p.object_control_override=true
	p.clear_object_support()
	p.rolling=true
	p.in_air=true
	p.jumping=false
	if tube_state==1:
		tube_angle += 2
		var sy: int=int((GenesisMath.sine(tube_angle & 0xFF))>>5)
		p.force_set_pixel_position(orig_x,orig_y-sy)
		if tube_angle>=0x80:
			tube_state=2
			var first_index: int = tube_path.size()-1 if tube_reverse else 0
			var a: Vector2i=_tube_wrapped_point(tube_path[first_index],p.pixel_y())
			p.force_set_pixel_position(a.x,a.y);tube_fixed_x=a.x<<16;tube_fixed_y=a.y<<16
			tube_target_index = first_index-1 if tube_reverse else first_index+1
			_start_tube_segment(p)
		return
	if tube_target_index<0 or tube_target_index>=tube_path.size():
		_release_tube(p);return
	# Retail does `subq.b #1,timer` then branches to MoveCharacter only while
	# the signed byte remains non-negative. The transition frame therefore
	# snaps to the exact node without applying one extra velocity step.
	tube_segment_timer-=1
	if tube_segment_timer>=0:
		tube_fixed_x+=p.vel_x<<8;tube_fixed_y+=p.vel_y<<8
		p.fixed_x=tube_fixed_x;p.fixed_y=tube_fixed_y
		p.position=Vector2(float(tube_fixed_x)/65536.0,float(tube_fixed_y)/65536.0)
		return
	# Retail snaps to the exact node before preparing the next segment.
	tube_fixed_x=tube_current_target.x<<16;tube_fixed_y=tube_current_target.y<<16
	p.force_set_pixel_position(tube_current_target.x,tube_current_target.y)
	tube_target_index += -1 if tube_reverse else 1
	if tube_target_index<0 or tube_target_index>=tube_path.size():
		_release_tube(p)
	else:
		_start_tube_segment(p)

# -----------------------------------------------------------------------------
# $68 - block with a sequentially extending spike on each side.
# -----------------------------------------------------------------------------
func _init_spike_block() -> void:
	active_width=0x20
	sprite=_new_sprite("spike_block",4,1);sprite.flip_v=false
	spike_direction=((manager.elapsed_frames>>7)+subtype)&3
	spike_offset=0
	spike_expanding=((manager.elapsed_frames>>6)&1)==0
	# The spike child shares priority 4 with the block in retail but is allocated
	# first/behind the parent's body. Keep its local Z lower than the block so the
	# retracted blade disappears behind the square rather than painting over it.
	spike_sprite=_new_sprite("moving_spike",spike_direction,0);spike_sprite.flip_v=false

func _place_radial_spike() -> Vector2i:
	var dx: int=0;var dy: int=0
	match spike_direction:
		0: dy=-spike_offset
		1: dx=spike_offset
		2: dy=spike_offset
		3: dx=-spike_offset
	spike_sprite.position=Vector2(dx,dy)
	return Vector2i(orig_x+dx,orig_y+dy)

func _tick_spike_block() -> void:
	var p: SonicPlayer=player();if p==null:return
	p.resolve_solid_box_contact(orig_x,orig_y,0x10,0x10,true,record_index)
	if spike_waiting:
		if (manager.elapsed_frames&0x3F)==0: spike_waiting=false
	else:
		if spike_expanding:
			spike_offset+=8
			if spike_offset>=0x20:
				spike_offset=0x20
				spike_expanding=false
				# Retail sets spikearoundblock_waiting at FULL extension too;
				# retraction does not begin until the next $40-frame boundary.
				spike_waiting=true
		else:
			spike_offset-=8
			if spike_offset<=0:
				spike_offset=0;spike_expanding=true;spike_direction=(spike_direction+1)&3;spike_waiting=true
				_set_frame(spike_sprite,"moving_spike",spike_direction)
	var wp: Vector2i=_place_radial_spike()
	if spike_offset>=8: _hazard_overlap(wp.x,wp.y,12,12)

# $6D - floor spike: +$400 word = four pixels/frame to $20, three-frame hold.
func _init_floor_spike() -> void:
	active_width=0x10
	spike_sprite=_new_sprite("moving_spike",0,3);spike_sprite.flip_v=false
	spike_waiting=false;spike_expanding=true

func _tick_floor_spike() -> void:
	if spike_waiting:
		if ((manager.elapsed_frames-subtype)&0x7F)==0: spike_waiting=false;spike_expanding=true
	elif spike_expanding:
		spike_offset+=4
		if spike_offset>=0x20: spike_offset=0x20;spike_expanding=false;spike_wait=3
	else:
		if spike_wait>0: spike_wait-=1
		else:
			spike_offset-=4
			if spike_offset<=0: spike_offset=0;spike_waiting=true
	spike_sprite.position=Vector2(0,-spike_offset)
	if spike_offset>=8:_hazard_overlap(orig_x,orig_y-spike_offset,10,14)

# -----------------------------------------------------------------------------
# $69 - screw nut. Horizontal player input/velocity turns the nut and converts
# that rotation to 1/8-pixel vertical screw travel. High-bit variants fall when
# they reach their authored lower limit.
# -----------------------------------------------------------------------------
func _init_nut() -> void:
	active_width=0x20
	sprite=_new_sprite("nut",0,1);sprite.flip_v=false
	nut_max_drop=(subtype&0x7F)<<3
	nut_fixed_y=orig_y<<16

func _tick_nut() -> void:
	var p: SonicPlayer=player();if p==null:return
	var old_y: int=int(position.y)
	if nut_falling:
		nut_fixed_y+=vel_y<<8
		vel_y=GenesisMath.s16(vel_y+0x38)
		position.y=float(nut_fixed_y)/65536.0
		var floor_dist: int=int(manager.collision.find_floor_sensor(int(position.x),int(position.y)+0x0B,true,0).get("distance",0x40)) if manager.collision!=null else 0x40
		if floor_dist<0:
			position.y+=floor_dist
			nut_fixed_y=int(round(position.y))<<16;vel_y=0;nut_falling=false;nut_landed=true
	elif not nut_landed:
		var supported: bool=p.standing_on_object and p.support_record_index==record_index
		if not supported:
			nut_player_mode=0
		elif nut_player_mode==0:
			nut_player_mode=1
			nut_side=1 if orig_x-p.pixel_x()<0 else 0
		if supported and nut_player_mode==1:
			var lock_delta: int=p.pixel_x()-orig_x
			if nut_side!=0:lock_delta+=0x0F
			if lock_delta>=0 and lock_delta<0x10:
				p.force_set_pixel_position(orig_x,p.pixel_y());nut_player_mode=2
		elif supported and nut_player_mode==2:
			# Obj69 mode 4 accumulates the actual integer X displacement Sonic made
			# since the previous object pass, then snaps him back to the screw axis.
			var turn_delta: int=p.pixel_x()-orig_x
			nut_turn=GenesisMath.s16(nut_turn+turn_delta)
			p.force_set_pixel_position(orig_x,p.pixel_y())
			var screw: int=nut_turn>>3
			_set_frame(sprite,"nut",(screw>>1)&3)
			var ny: int=orig_y-screw
			if turn_delta<0 and ny-orig_y>=nut_max_drop:
				ny=orig_y+nut_max_drop
				nut_turn=-(nut_max_drop<<3)
				_set_frame(sprite,"nut",0)
				if (subtype&0x80)!=0:
					nut_falling=true;vel_y=0;nut_fixed_y=ny<<16
				else:
					nut_player_mode=0
			position.y=ny
	var ny2: int=int(round(position.y))
	if p.standing_on_object and p.support_record_index==record_index:
		p.move_with_supported_object(record_index,0,ny2-old_y,orig_x-0x20,orig_x+0x20,ny2-0x0B)
	p.resolve_solid_box_contact(orig_x,ny2,0x20,0x0B,true,record_index)

# -----------------------------------------------------------------------------
# $6A - MTZ trigger platform. Retail advances one entry of byte_27CDC each
# time a character steps off the platform: down, up-right, down, up-left.
# Velocities are 8.8 and each segment retains its exact $10/$20-frame timer.
# -----------------------------------------------------------------------------
const TRIGGER_PLATFORM_SEGMENTS: Array[Vector3i] = [
	Vector3i(0x000,0x400,0x10),
	Vector3i(0x400,-0x200,0x20),
	Vector3i(0x000,0x400,0x10),
	Vector3i(-0x400,-0x200,0x20),
]

func _init_trigger_platform() -> void:
	active_width=0x20
	sprite=_new_sprite("immobile_platform",1,1)
	sprite.flip_h=x_flip; sprite.flip_v=y_flip
	platform_fixed_x=orig_x<<16; platform_fixed_y=orig_y<<16
	platform_segment_index=clampi(int(subtype / 6),0,3)
	state=0; remembered_standing=false

func _tick_trigger_platform() -> void:
	var p: SonicPlayer=player(); if p==null:return
	var old_x:int=int(round(position.x)); var old_y:int=int(round(position.y))
	var stood:bool=p.standing_on_object and p.support_record_index==record_index
	if state==0:
		if stood:
			remembered_standing=true
		elif remembered_standing:
			remembered_standing=false
			var seg:Vector3i=TRIGGER_PLATFORM_SEGMENTS[platform_segment_index]
			vel_x=seg.x; vel_y=seg.y; timer=seg.z; state=1
	elif state==1:
		platform_fixed_x += GenesisMath.s16(vel_x)<<8
		platform_fixed_y += GenesisMath.s16(vel_y)<<8
		position=Vector2(float(platform_fixed_x)/65536.0,float(platform_fixed_y)/65536.0)
		timer-=1
		if timer<=0:
			state=0
			platform_segment_index=(platform_segment_index+1)&3
	var nx:int=int(round(position.x)); var ny:int=int(round(position.y))
	if p.standing_on_object and p.support_record_index==record_index:
		p.move_with_supported_object(record_index,nx-old_x,ny-old_y,nx-0x20,nx+0x20,ny-0x0C)
	p.resolve_solid_box_contact(nx,ny,0x20,0x0C,true,record_index)

# -----------------------------------------------------------------------------
# $6B - MTZ platform. Act 1 uses type 2 horizontal $80 oscillator and type 7
# stood-on bounce/fall routine.
# -----------------------------------------------------------------------------
func _init_platform() -> void:
	active_width=0x20
	sprite=_new_sprite("immobile_platform",1,1)
	sprite.flip_h=x_flip
	sprite.flip_v=y_flip
	platform_mode=subtype&0x0F
	platform_fixed_y=orig_y<<16

func _tick_platform() -> void:
	var p: SonicPlayer=player();if p==null:return
	var old_x: int=int(round(position.x));var old_y: int=int(round(position.y))
	if platform_mode==2:
		# loc_27E74: horizontal $80 oscillator.
		var d: int=manager.s2_source_osc_byte(0x1C)
		if x_flip:d=-d+0x80
		position.x=orig_x-d
	elif platform_mode==4:
		# loc_27EA2/27EAC: the Act-2/3 vertical platform uses the same $1C
		# source oscillator, reflected around its $80 range by status bit 0.
		var d4: int=manager.s2_source_osc_byte(0x1C)
		if x_flip:d4=-d4+0x80
		position.y=orig_y-d4
	elif platform_mode==5:
		# loc_27EC4: ride the half-amplitude Oscillating_Data channel until a
		# character stands on it, then advance to the falling type 6.
		position.y=orig_y+(manager.s2_source_osc_byte(0x00)>>1)
		if p.standing_on_object and p.support_record_index==record_index:
			platform_mode=6
			vel_y=0
			platform_fixed_y=int(round(position.y))<<16
	elif platform_mode==6:
		# ObjectMove + gravity 8. Keep full 16.16 position so the fall does not
		# stutter, then become inert once it has travelled below the camera.
		platform_fixed_y += GenesisMath.s16(vel_y)<<8
		position.y=float(platform_fixed_y)/65536.0
		vel_y=GenesisMath.s16(vel_y+8)
		if int(position.y) > orig_y + 0x400:
			platform_mode=0
	elif platform_mode==7:
		if state==0 and p.standing_on_object and p.support_record_index==record_index:
			state=1;bounce_accel=8;vel_y=0;platform_fixed_y=int(round(position.y))<<16
		if state==1:
			# ObjectMove preserves 16.16 position while adding 8.8 velocity.
			platform_fixed_y += GenesisMath.s16(vel_y)<<8
			position.y=float(platform_fixed_y)/65536.0
			if vel_y==0x2A8:bounce_accel=-8
			vel_y=GenesisMath.s16(vel_y+bounce_accel)
			if bounce_accel<0 and vel_y<=0:
				state=0;vel_y=0;platform_mode=0
	var nx: int=int(round(position.x));var ny: int=int(round(position.y))
	if p.standing_on_object and p.support_record_index==record_index:
		p.move_with_supported_object(record_index,nx-old_x,ny-old_y,nx-0x20,nx+0x20,ny-0x0C)
	p.resolve_solid_box_contact(nx,ny,0x20,0x0C,true,record_index)

# -----------------------------------------------------------------------------
# $6E - circular MTZ platform. The first three mapping variants are solid and
# use Oscillating_Data+$20/$24 around a $38 radius; frame 3 is the half-radius
# wheel-indent decoration and is intentionally non-solid in retail.
# -----------------------------------------------------------------------------
func _init_circle_platform() -> void:
	platform_shape=(subtype>>4)&3
	var widths:Array[int]=[0x10,0x28,0x60,0x0C]
	active_width=widths[platform_shape]+0x40
	sprite=_new_sprite("circle_platform",platform_shape,1 if platform_shape<3 else 2)
	sprite.flip_h=x_flip; sprite.flip_v=y_flip

func _tick_circle_platform() -> void:
	var old_x:int=int(round(position.x)); var old_y:int=int(round(position.y))
	var dx:int; var dy:int
	if platform_shape==3:
		dx=(manager.s2_source_osc_byte(0x20)>>1)-0x1C
		dy=(manager.s2_source_osc_byte(0x24)>>1)-0x1C
	else:
		dx=manager.s2_source_osc_byte(0x20)-0x38
		dy=manager.s2_source_osc_byte(0x24)-0x38
	if (subtype&1)!=0:
		dx=-dx;dy=-dy
	if (subtype&2)!=0:
		dx=-dx
		var tmp:int=dx;dx=dy;dy=tmp
	position=Vector2(orig_x+dx,orig_y+dy)
	if platform_shape==3:return
	var p:SonicPlayer=player();if p==null:return
	var widths:Array[int]=[0x10,0x28,0x60,0x0C]
	var radii:Array[int]=[0x0C,0x08,0x18,0x0C]
	var hw:int=widths[platform_shape];var hh:int=radii[platform_shape]
	_carry_and_platform(p,old_x,old_y,hw,hh)
	p.resolve_solid_box_contact(int(round(position.x)),int(round(position.y)),hw,hh,true,record_index)

# $74 - invisible source SolidObject. Subtype nibbles encode half-extents.
func _init_invisible_solid() -> void:
	visible=false
	active_width=((subtype&0xF0)+0x10)>>1

func _tick_invisible_solid() -> void:
	var p: SonicPlayer=player();if p==null:return
	var hw: int=((subtype&0xF0)+0x10)>>1
	var hh: int=((subtype&0x0F)+1)<<3
	p.resolve_solid_box_contact(orig_x,orig_y,hw,hh,true,record_index)

# -----------------------------------------------------------------------------
# $9F Shellcracker. Walking body plus eight-link telescoping claw chain.
# -----------------------------------------------------------------------------
func _init_shellcracker() -> void:
	active_width=0x18
	sprite=_new_sprite("shellcracker",0,3);sprite.flip_v=false
	vel_x=0x40 if x_flip else -0x40
	timer=0x140
	# Obj9F spawns ObjA0 children with objoff_2E = 0,2,...,$E.  Child 0 is
	# the claw (mapping 5); the other seven become joint mapping 4 after init.
	for i in range(8):
		var frame: int = 5 if i == 0 else 4
		var s: Sprite2D=_new_sprite("shellcracker",frame,2)
		s.visible=false;s.flip_v=false;shell_links.append(s)

func _shell_set_chain(elapsed: int, show_chain: bool = true) -> int:
	# Exact ObjA0 spacing comes from each child moving at $400 (4 px/frame)
	# after its staggered byte_381A4 delay.  This yields full-extension offsets
	# 72,62,54,46,38,30,22,14 pixels instead of eight evenly packed pieces.
	var delays: Array[int] = [0,3,5,7,9,11,13,15]
	var travel: Array[int] = [13,12,10,8,6,4,2,0]
	var bases: Array[int] = [20,14,14,14,14,14,14,14]
	var sign: int=1 if sprite.flip_h else -1
	var claw_offset: int = bases[0]
	for i in range(shell_links.size()):
		var s: Sprite2D=shell_links[i]
		s.visible=show_chain
		var local_t: int = maxi(0,elapsed-delays[i])
		var duration: int = travel[i]
		var moved: int = 0
		if duration > 0:
			if local_t <= duration:
				moved = local_t * 4
			elif local_t <= duration + 8:
				moved = duration * 4
			else:
				moved = maxi(0,(duration * 2 + 8 - local_t) * 4)
		var offset: int = bases[i] + moved
		s.position=Vector2(sign*offset,-8 if i==0 else -2)
		_set_frame(s,"shellcracker",5 if i==0 else 4)
		if i == 0:
			claw_offset = offset
	return claw_offset

func _tick_shellcracker() -> void:
	if body_hidden:return
	var p: SonicPlayer=player();if p==null:return
	if state==0:
		position.x+=float(vel_x)/256.0
		var fd: int=int(manager.collision.find_floor_sensor(int(position.x),int(position.y)+0x0C,true,0).get("distance",0)) if manager.collision!=null else 0
		if fd>=-8 and fd<0x0C:position.y+=fd
		else:vel_x=-vel_x;sprite.flip_h=vel_x>0
		timer-=1
		if timer<0:state=1;timer=0x3B
		var dx: int=p.pixel_x()-int(position.x)
		if _source_visible(int(position.x),int(position.y)) and absi(p.pixel_y()-int(position.y))<0x40 and absi(dx)<0x60 and ((dx<0 and vel_x<0) or (dx>0 and vel_x>0)):
			state=2;attack_phase=0;_set_frame(sprite,"shellcracker",3)
			_shell_set_chain(0,true)
		else:_set_frame(sprite,"shellcracker",int(frame_counter/15)%3)
	elif state==1:
		timer-=1
		if timer<0:state=0;timer=0x140
	else:
		# The longest ObjA0 child cycle is 35 frames. Keep the claw/joints alive
		# through the entire reverse trip; the old phase hid them when extension
		# reached zero, making the claw disappear before Shellcracker resumed.
		var claw_offset: int = _shell_set_chain(attack_phase,true)
		var sign: int=1 if sprite.flip_h else -1
		_hazard_overlap(int(position.x)+sign*claw_offset,int(position.y)-8,10,10)
		attack_phase += 1
		if attack_phase > 35:
			_shell_set_chain(0,false)
			state=1;timer=0x20;attack_phase=0;_set_frame(sprite,"shellcracker",0)
	_react_badnik(int(position.x),int(position.y),0x18,0x0C)

# -----------------------------------------------------------------------------
# $A1 Slicer. Walks at $40, pauses/throws paired homing pincers when Sonic is
# ahead in the retail $80x$40 acquisition window.
# -----------------------------------------------------------------------------
func _init_slicer() -> void:
	active_width=0x10
	sprite=_new_sprite("slicer",0,3);sprite.flip_v=y_flip
	vel_x=0x40 if x_flip else -0x40

func _spawn_slicer_pincer(xoff: int) -> void:
	# ObjA1_LoadPincers: both children start on mapping frame 5 at source
	# horizontal offsets +6 and -$10. Render X-flip mirrors those offsets.
	var s: Sprite2D=_new_sprite("slicer",5,2);s.flip_v=y_flip
	var ox: int=-xoff if sprite.flip_h else xoff
	var x: float=position.x+ox
	var y: float=position.y
	s.position=Vector2(ox,0)
	var start_vx: int=0x200 if sprite.flip_h else -0x200
	projectiles.append({"kind":"slicer","sprite":s,"x":x,"y":y,"vx":start_vx,"vy":0,"age":0,"frame":5,"phase":0,"fall_timer":0})

func _tick_slicer() -> void:
	if body_hidden:return
	var p: SonicPlayer=player();if p==null:return
	if state==0:
		position.x+=float(vel_x)/256.0
		var fd: int=int(manager.collision.find_floor_sensor(int(position.x),int(position.y)+0x10,true,0).get("distance",0)) if manager.collision!=null else 0
		if fd>=-8 and fd<0x0C:position.y+=fd
		else:vel_x=-vel_x;sprite.flip_h=vel_x>0
		_set_frame(sprite,"slicer",0 if (int(frame_counter/20)&1)==0 else 2)
		var dx: int=p.pixel_x()-int(position.x);var dy: int=p.pixel_y()-int(position.y)
		var ahead: bool=(dx>0 and sprite.flip_h) or (dx<0 and not sprite.flip_h)
		if _source_visible(int(position.x),int(position.y)) and ahead and absi(dx)<0x80 and absi(dy)<0x40:
			state=1;timer=8;_set_frame(sprite,"slicer",3)
	elif state==1:
		timer-=1
		if timer<0:
			# Retail advances to routine 8 after ObjA1_LoadPincers. Routine 8
			# only MarkObjGone's the body; it never grows/reloads another pair.
			state=2;_set_frame(sprite,"slicer",4);_spawn_slicer_pincer(6);_spawn_slicer_pincer(-0x10)
	else:
		pass
	_react_badnik(int(position.x),int(position.y),0x10,0x10)

# -----------------------------------------------------------------------------
# $A4 Asteron. Stationary proximity trigger, short charge, then a five-way
# starburst. The body remains alive until its children finish, matching the
# self-replacement explosion lifecycle instead of recursively respawning stars.
# -----------------------------------------------------------------------------
func _init_asteron() -> void:
	active_width=0x10
	sprite=_new_sprite("asteron",0,3);sprite.flip_v=false
	# MTZ high-priority Plane-A tiles render at absolute Z=100. Retail Asteron
	# priority 4 sits in front of them, so do not inherit the object's Z=40.
	sprite.z_as_relative=false
	sprite.z_index=120

func _asteron_burst() -> void:
	body_hidden=true;sprite.visible=false
	manager.spawn_badnik_destruction(int(position.x),int(position.y),0)
	# ObjA4_Obj98InitData: exact offsets, velocities, mapping frames, and
	# horizontal render bits for the five finite star projectiles.
	var shots: Array=[
		{"off":Vector2i(0,-8),"vel":Vector2i(0,-0x400),"frame":2,"flip":false},
		{"off":Vector2i(8,-4),"vel":Vector2i(0x300,-0x100),"frame":3,"flip":true},
		{"off":Vector2i(8,8),"vel":Vector2i(0x300,0x300),"frame":4,"flip":true},
		{"off":Vector2i(-8,8),"vel":Vector2i(-0x300,0x300),"frame":4,"flip":false},
		{"off":Vector2i(-8,-4),"vel":Vector2i(-0x300,-0x100),"frame":3,"flip":false},
	]
	for shot in shots:
		var off: Vector2i=shot["off"]
		var v: Vector2i=shot["vel"]
		var f: int=int(shot["frame"])
		var s: Sprite2D=_new_sprite("asteron",f,2);s.flip_v=false;s.flip_h=bool(shot["flip"]);s.z_as_relative=false;s.z_index=120
		var x: float=position.x+off.x;var y: float=position.y+off.y
		s.position=Vector2(off.x,off.y)
		projectiles.append({"kind":"asteron","sprite":s,"x":x,"y":y,"vx":v.x,"vy":v.y,"age":0,"frame":f})

func _tick_asteron() -> void:
	if body_hidden:
		# Asteron is a remembered placement. Once its self-replacement burst has
		# finished, set the respawn bit exactly like a destroyed badnik instead of
		# allowing ObjPosLoad to recreate it immediately.
		if projectiles.is_empty():request_delete(respawn_enabled)
		return
	var p: SonicPlayer=player();if p==null:return
	var dx: int=p.pixel_x()-int(position.x);var dy: int=p.pixel_y()-int(position.y)
	if state==0:
		if _source_visible(int(position.x),int(position.y)) and absi(dx)<=0x60 and absi(dy)<=0x40: state=1
	elif state==1:
		# Retail routine 4 waits until either axis is $10..$5F away, then sets
		# a $40 velocity on each qualifying axis toward the closest character.
		var armed: bool=false
		if absi(dx)>=0x10 and absi(dx)<0x60: vel_x=0x40 if dx>0 else -0x40;armed=true
		if absi(dy)>=0x10 and absi(dy)<0x60: vel_y=0x40 if dy>0 else -0x40;armed=true
		if armed: state=2;timer=0x40
	else:
		position.x+=float(vel_x)/256.0;position.y+=float(vel_y)/256.0
		_set_frame(sprite,"asteron",(frame_counter>>1)&1);timer-=1
		if timer<0:_asteron_burst()
	_react_badnik(int(position.x),int(position.y),0x10,0x10)

# -----------------------------------------------------------------------------
# Phase 123: MTZ Act 2 object families.
# -----------------------------------------------------------------------------

# $31 - invisible lava damage markers. Collision flags $96/$94/$95 select
# Touch_Sizes indices $16/$14/$15 = 32x32, 64x32 and 128x32.
func _init_lava_marker() -> void:
	visible = false
	active_width = [0x20,0x40,0x80,0][mini(subtype & 3,3)]

func _tick_lava_marker() -> void:
	var st: int = subtype & 3
	if st == 3:
		return
	var hw: int = [0x20,0x40,0x80][st]
	_hazard_overlap(orig_x,orig_y,hw,0x20)

# $6C - the MTZ2 lava-cup pulley assemblies. Retail high-bit placements are
# spawners for eight child cups; each child follows one of three ten-node loops
# at one pixel/frame on its dominant axis. Keeping the children under one native
# adapter preserves the exact authored group without consuming object slots.
func _init_lava_cups() -> void:
	# The adapter node itself has no drawing, but its Sprite2D children inherit
	# CanvasItem visibility. Keeping the parent visible is required for the cups.
	visible = true
	active_width = 0x280
	var variant: int = clampi(subtype & 0x7F,0,2)
	for desc in LAVA_CUP_SPAWN[variant]:
		var child_sub: int = int(desc[2])
		var group: int = clampi((child_sub >> 4) & 3,0,2)
		var start_index: int = child_sub & 0x0F
		var step: int = -1 if x_flip else 1
		var target_index: int = posmod(start_index + step,LAVA_CUP_PATHS[group].size())
		var wx: int = orig_x + int(desc[0])
		var wy: int = orig_y + int(desc[1])
		var sp: Sprite2D = _new_sprite("lava_cup",0,1)
		sp.position = Vector2(wx-orig_x,wy-orig_y)
		lava_cups.append({"sprite":sp,"group":group,"target":target_index,"step":step,"x":wx<<16,"y":wy<<16,"old_x":wx,"old_y":wy})

func _cup_velocity(cx: int, cy: int, target: Vector2i) -> Vector2i:
	var dx: int = target.x-cx
	var dy: int = target.y-cy
	var ax: int = absi(dx); var ay: int = absi(dy)
	if ax == 0 and ay == 0:
		return Vector2i.ZERO
	if ay >= ax:
		var vy: int = 0x100 if dy > 0 else -0x100
		var vx: int = 0 if ay == 0 else int(float(dx*0x100)/float(ay))
		return Vector2i(vx,vy)
	var vx2: int = 0x100 if dx > 0 else -0x100
	var vy2: int = 0 if ax == 0 else int(float(dy*0x100)/float(ax))
	return Vector2i(vx2,vy2)

func _tick_lava_cups() -> void:
	var p: SonicPlayer = player()
	for i in range(lava_cups.size()):
		var c: Dictionary = lava_cups[i]
		var old_x: int = int(c["x"]) >> 16
		var old_y: int = int(c["y"]) >> 16
		var group: int = int(c["group"])
		var ti: int = int(c["target"])
		var rel_target: Vector2i = LAVA_CUP_PATHS[group][ti]
		var target: Vector2i = Vector2i(orig_x+rel_target.x,orig_y+rel_target.y)
		if old_x == target.x and old_y == target.y:
			ti = posmod(ti + int(c["step"]),LAVA_CUP_PATHS[group].size())
			c["target"] = ti
			rel_target = LAVA_CUP_PATHS[group][ti]
			target = Vector2i(orig_x+rel_target.x,orig_y+rel_target.y)
		var v: Vector2i = _cup_velocity(old_x,old_y,target)
		var xf: int = int(c["x"]) + (v.x << 8)
		var yf: int = int(c["y"]) + (v.y << 8)
		var nx: int = xf >> 16; var ny: int = yf >> 16
		# Clamp each dominant-axis arrival exactly to the source node.
		if (v.x > 0 and nx >= target.x) or (v.x < 0 and nx <= target.x):
			if absi(target.x-old_x) >= absi(target.y-old_y): xf = target.x << 16
		if (v.y > 0 and ny >= target.y) or (v.y < 0 and ny <= target.y):
			if absi(target.y-old_y) >= absi(target.x-old_x): yf = target.y << 16
		c["x"] = xf; c["y"] = yf
		nx = xf >> 16; ny = yf >> 16
		(c["sprite"] as Sprite2D).position = Vector2(nx-orig_x,ny-orig_y)
		if p != null and not p.dead:
			if p.standing_on_object and p.support_record_index == record_index and p.pixel_x() >= old_x-0x18 and p.pixel_x() < old_x+0x18 and absi((p.pixel_y()+p.height_radius)-(old_y-8)) <= 5:
				p.move_with_supported_object(record_index,nx-old_x,ny-old_y,nx-0x18,nx+0x18,ny-8)
			p.resolve_platform_top(nx-0x18,nx+0x18,ny-8,record_index)
		lava_cups[i] = c

# $70 - giant eight-tooth MTZ gear. The source advances between four exact
# position tables every $10 frames; each tooth owns its corresponding mapping
# frame and SolidObject geometry.
func _gear_entry(step: int, child: int) -> Array:
	# Object $70 advances each physical tooth's mapping frame by +/-1 through the
	# 32-frame circle. The low two bits select one position table; the upper bits
	# select which of the eight positions belongs to that SAME physical tooth.
	var mf: int = (child*4 + step) & 0x1F
	var phase: int = mf & 3
	var around: int = (mf >> 2) & 7
	return GEAR_POSITIONS[phase][around]

func _init_gear() -> void:
	visible = true
	active_width = 0x80
	gear_rider_tooth = -1
	gear_step = 0
	gear_last_advance_frame = manager.elapsed_frames if manager != null else frame_counter
	for i in range(8):
		var e: Array = _gear_entry(gear_step,i)
		var sp: Sprite2D = _new_sprite("gear",int(e[2]),1)
		sp.flip_h=false; sp.flip_v=false
		sp.position = Vector2(int(e[0]),int(e[1]))
		gear_sprites.append(sp)
		gear_prev_positions.append(Vector2i(orig_x+int(e[0]),orig_y+int(e[1])))

func _tick_gear() -> void:
	var p: SonicPlayer = player()
	var ef: int = manager.elapsed_frames if manager != null else frame_counter
	# Source Timer_frames bit $F advances once per $10 frames. Direction is the
	# sign of status bit 0: clockwise +1, counter-clockwise -1.
	if (ef & 0x0F)==0 and ef != gear_last_advance_frame:
		gear_last_advance_frame=ef
		gear_step = (gear_step + (-1 if x_flip else 1)) & 0x1F
	var new_positions: Array[Vector2i] = []
	for i in range(8):
		var e: Array = _gear_entry(gear_step,i)
		var wx: int = orig_x+int(e[0]); var wy: int = orig_y+int(e[1]); var mf: int = int(e[2])
		new_positions.append(Vector2i(wx,wy))
		var sp: Sprite2D = gear_sprites[i] as Sprite2D
		sp.position = Vector2(wx-orig_x,wy-orig_y)
		_set_frame(sp,"gear",mf)
	if p != null and not p.dead:
		var supported: bool = p.standing_on_object and p.support_record_index == record_index
		if supported and gear_prev_positions.size()==8:
			# Retain the same physical child identity across mapping-table phases. This
			# eliminates the four-frame/table wrap snap seen when standing on a tooth.
			if gear_rider_tooth<0 or gear_rider_tooth>=8:
				var best_d: int=0x7FFFFFFF
				for i in range(8):
					var op: Vector2i=gear_prev_positions[i]
					var d: int=absi(p.pixel_x()-op.x)+absi((p.pixel_y()+p.height_radius)-op.y)
					if d<best_d: best_d=d; gear_rider_tooth=i
			if gear_rider_tooth>=0:
				var op2: Vector2i=gear_prev_positions[gear_rider_tooth]
				var np2: Vector2i=new_positions[gear_rider_tooth]
				p.move_with_supported_object(record_index,np2.x-op2.x,np2.y-op2.y,np2.x-0x10,np2.x+0x10,np2.y-0x10)
		else:
			gear_rider_tooth=-1
		for i in range(8):
			var e2: Array=_gear_entry(gear_step,i)
			var mf2: int=int(e2[2])&0x0F
			var hh: int=0x0C if mf2==7 or mf2==9 else (8 if mf2==8 else 0x10)
			var wp: Vector2i=new_positions[i]
			p.resolve_solid_box_contact(wp.x,wp.y,0x10,hh,true,record_index)
	gear_prev_positions=new_positions

# $71 subtype $22 - MTZ lava bubble. Ani_obj71 animation 2 walks frames 0..5
# at delay $B then switches to animation 3's frame 6 for $80 VBlanks before
# returning to animation 2.
func _init_lava_bubble() -> void:
	active_width = 0x10
	sprite = _new_sprite("lava_bubble",0,1)
	lava_bubble_anim = 2
	lava_bubble_timer = 0

func _tick_lava_bubble() -> void:
	if sprite == null:
		return
	lava_bubble_timer -= 1
	if lava_bubble_timer >= 0:
		return
	if lava_bubble_anim == 2:
		var f: int = int(frame_counter / 12)
		if f < 6:
			_set_frame(sprite,"lava_bubble",f)
			lava_bubble_timer = 0x0B
		else:
			lava_bubble_anim = 3
			_set_frame(sprite,"lava_bubble",6)
			lava_bubble_timer = 0x7F
	else:
		lava_bubble_anim = 2
		frame_counter = 0
		_set_frame(sprite,"lava_bubble",0)
		lava_bubble_timer = 0x0B

# $72 - invisible conveyor region. MTZ2 uses the same source object as CNZ:
# low 7 subtype bits select half-width in $10-pixel steps, high bit selects the
# tall $70 half-height, and placement X-flip reverses the two-pixel push.
func _init_conveyor() -> void:
	visible = false
	active_width = (subtype & 0x7F) << 4

func _tick_conveyor() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead or p.in_air:
		return
	var hw: int = (subtype & 0x7F) << 4
	var hh: int = 0x70 if (subtype & 0x80) != 0 else 0x30
	if p.pixel_x() >= orig_x-hw and p.pixel_x() < orig_x+hw and p.pixel_y() >= orig_y-hh and p.pixel_y() < orig_y+hh:
		p.force_add_pixel_offset(-2 if x_flip else 2,0)

# Shared transient update for Slicer pincers / Asteron stars.
func _tick_projectiles() -> void:
	if projectiles.is_empty():return
	var p: SonicPlayer=player()
	for i in range(projectiles.size()-1,-1,-1):
		var q: Dictionary=projectiles[i]
		q["age"]=int(q["age"])+1
		var kind: String=String(q["kind"])
		if kind=="slicer":
			var phase: int=int(q.get("phase",0))
			if phase==0:
				if p!=null:
					var tx: int=-0x10 if float(q["x"])>p.pixel_x() else 0x10
					var ty: int=-0x10 if float(q["y"])>p.pixel_y() else 0x10
					q["vx"]=clampi(int(q["vx"])+tx,-0x200,0x200)
					q["vy"]=clampi(int(q["vy"])+ty,-0x200,0x200)
				if int(q["age"])>=0x78:
					q["phase"]=1;q["fall_timer"]=0x60;q["age"]=0
			else:
				q["fall_timer"]=int(q["fall_timer"])-1
				if int(q["fall_timer"])<0:
					(q["sprite"] as Sprite2D).queue_free();projectiles.remove_at(i);continue
		q["x"]=float(q["x"])+float(int(q["vx"]))/256.0
		q["y"]=float(q["y"])+float(int(q["vy"]))/256.0
		if kind=="slicer" and int(q.get("phase",0))==1:
			q["vy"]=GenesisMath.s16(int(q["vy"])+0x38)
		var s: Sprite2D=q["sprite"] as Sprite2D;s.position=Vector2(float(q["x"])-position.x,float(q["y"])-position.y)
		if kind=="slicer":_set_frame(s,"slicer",5+((int(q["age"])>>2)&3))
		# Obj98 Asteron children keep the authored mapping frame for life.
		if p!=null and not p.dead and absi(p.pixel_x()-int(float(q["x"])))<=8+p.width_radius and absi(p.pixel_y()-int(float(q["y"])))<=8+p.height_radius:p.apply_hazard_hit(int(float(q["x"])))
		if kind=="asteron" and int(q["age"])>=0x100:
			s.queue_free();projectiles.remove_at(i)
		else:projectiles[i]=q
