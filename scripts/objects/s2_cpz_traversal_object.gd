class_name S2CPZTraversalObject
extends GenesisLevelObject

# Phase 91: retail Sonic 2 Chemical Plant traversal objects used by CPZ1.
# IDs handled here: $0B, $19, $1B, $1E, $2D, $32, $40, $6B, $74, $78, $7A, $7B.

var sprite: Sprite2D
var aux_sprites: Array[Sprite2D] = []
var state := 0
var timer := 0
var anim_dir := 1
var anim_frame := 0
var anim_tick := 0
var tip_initial_duration := 0
var orig_x := 0
var orig_y := 0
var fixed_y := 0
var object_vel_y := 0
var barrier_raise := 0
var pipe_proximity_timer := 0
var pipe_launch_timer := 0
var square_phase := 0
var stair_progress := 0
var stair_triggered := false
var stair_delay := 0
var stair_last_y: Array[int] = [0, 0, 0, 0]
var lever_anim_timer := 0
var water_platform_x: Array[int] = []
var water_platform_dir: Array[int] = []
var water_platform_last_x: Array[int] = []
var water_platform_min_x := 0
var water_platform_max_x := 0
var use_htz_breakable_rock := false
var htz_rock_broken := false
var htz_rock_fragments: Array[Sprite2D] = []
var htz_rock_fragment_velocity: Array[Vector2] = []
var htz_rock_fragment_timer := 0
const HTZ_ROCK_FRAGMENT_VELOCITY: Array[Vector2] = [
	Vector2(-2.0,-2.0), Vector2(0.0,-2.5), Vector2(2.0,-2.0),
	Vector2(-1.75,-1.75), Vector2(0.0,-2.0), Vector2(1.75,-1.75)
]

# CPZ spin-tube controller state.
var tube_active := false
var tube_cooldown := false
var tube_points: Array = []
var tube_target := 0
var tube_entry_mode := 0
var tube_paths: Dictionary = {}

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	match object_id:
		0x0B: _init_tipping_floor()
		0x19: _init_platform()
		0x1B: _init_booster()
		0x1E: _init_spin_tube()
		0x2D: _init_barrier()
		0x32: _init_breakable_block()
		0x40: _init_lever_spring()
		0x6B: _init_square_platform()
		0x74: _init_invisible_block()
		0x78: _init_staircase()
		0x7A: _init_water_platform()
		0x7B: _init_pipe_spring()

func tick() -> void:
	match object_id:
		0x0B: _tick_tipping_floor()
		0x19: _tick_platform()
		0x1B: _tick_booster()
		0x1E: _tick_spin_tube()
		0x2D: _tick_barrier()
		0x32: _tick_breakable_block()
		0x40: _tick_lever_spring()
		0x6B: _tick_square_platform()
		0x74: _tick_invisible_block()
		0x78: _tick_staircase()
		0x7A: _tick_water_platform()
		0x7B: _tick_pipe_spring()

func suppress_central_despawn() -> bool:
	# Obj1E deliberately owns Sonic while he can be far away from the controller.
	return object_id == 0x1E and tube_active

# -----------------------------------------------------------------------------
# Object $0B - CPZ tipping pipe sections
# -----------------------------------------------------------------------------
func _init_tipping_floor() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/s2_cpz/tipping/00.png")
	tip_initial_duration = ((subtype & 0xF0) + 0x10) - 1
	timer = tip_initial_duration
	anim_dir = 1
	anim_frame = 0
	anim_tick = 8
	state = 0

func _tick_tipping_floor() -> void:
	var p = player()
	if p == null:
		return
	if state == 0:
		# Obj0B adds a 16/32/48/64-frame subtype phase offset to the low byte
		# of Vint_runcount and starts only when the byte wraps to zero.
		var delay = ((subtype & 0x0F) + 1) << 4
		if ((manager.elapsed_frames + delay) & 0xFF) == 0:
			state = 1
	else:
		# The real object switches between two AnimateSprite scripts every
		# duration period. Each script walks to its terminal mapping and holds.
		timer -= 1
		if timer < 0:
			timer = tip_initial_duration if anim_dir < 0 else 0x7F
			anim_dir = -anim_dir
			anim_frame = 4 if anim_dir < 0 else 0
			anim_tick = 8
			_set_frame(sprite, "tipping", anim_frame)
		else:
			anim_tick -= 1
			if anim_tick <= 0:
				anim_tick = 8
				if anim_dir > 0 and anim_frame < 4:
					anim_frame += 1
				elif anim_dir < 0 and anim_frame > 0:
					anim_frame -= 1
				_set_frame(sprite, "tipping", anim_frame)

	# The original calls PlatformObject only while mapping frame 0 is visible.
	if anim_frame == 0:
		p.resolve_platform_top(spawn_x - 16, spawn_x + 16, spawn_y - 0x11, record_index)
	elif p.standing_on_object and p.support_record_index == record_index:
		p.clear_object_support()
		p.in_air = true

# -----------------------------------------------------------------------------
# Object $19 - CPZ moving platform
# -----------------------------------------------------------------------------
func _init_platform() -> void:
	# Obj19 selects one of four mapping/width pairs from subtype bits 4-5.
	# CPZ2 uses the second pair ($18 wide, mapping frame 1) for its smaller
	# circular platforms; Phase 93 treated every subtype as the large frame 0.
	var shape = (subtype >> 4) & 3
	var widths: Array[int] = [0x20, 0x18, 0x40, 0x20]
	active_width = widths[shape]
	var texture_path = "res://assets/objects/s2_cpz/platform/00.png"
	if shape == 1:
		texture_path = "res://assets/objects/s2_cpz/platform_small/00.png"
	sprite = make_sprite(texture_path)
	fixed_y = spawn_y << 16
	# Obj19 subtype 7 always starts $C0 above its origin. Subtype 3 does so
	# only when status bit 0 / the source X-flip bit is set.
	var kind = subtype & 0x0F
	if kind == 7 or (kind == 3 and x_flip):
		position.y -= 0xC0
		fixed_y = int(position.y) << 16

func _tick_platform() -> void:
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)
	var kind = subtype & 0x0F
	match kind:
		0, 1:
			# Obj19_MoveRoutine1/2: horizontal oscillation. Routine 0 uses the
			# $08 source channel/$40 span; routine 1 uses $0C/$60.
			var source_off = 0x08 if kind == 0 else 0x0C
			var span = 0x40 if kind == 0 else 0x60
			var disp_h = manager.s2_source_osc_byte(source_off)
			if x_flip:
				disp_h = span - disp_h
			position.x = orig_x - disp_h
			position.y = orig_y
		2:
			var disp_v = manager.s2_source_osc_byte(0x1C)
			if x_flip:
				disp_v = 0x80 - disp_v
			position.x = orig_x
			position.y = orig_y - disp_v
		3:
			# MoveRoutine4 advances to the one-shot vertical movement when stood on.
			if p.standing_on_object and p.support_record_index == record_index:
				subtype = (subtype & 0xF0) | 4
		4, 6, 7:
			# MoveRoutine5/6: ObjectMove plus +/-8 acceleration around Y-$60.
			fixed_y += object_vel_y << 8
			position.y = fixed_y >> 16
			var target = orig_y - 0x60
			var accel = 8 if target >= int(position.y) else -8
			object_vel_y = GenesisMath.s16(object_vel_y + accel)
			if kind == 4 and object_vel_y == 0:
				subtype = (subtype & 0xF0) | 5
		5:
			pass
		8, 9, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F:
			# MoveRoutine7/8: the smaller CPZ2 platforms trace the source
			# two-channel circular path. Kinds C-F mirror the horizontal result.
			var dx = GenesisMath.s8(manager.s2_source_osc_byte(0x38) - 0x40)
			var dy = GenesisMath.s8(manager.s2_source_osc_byte(0x3C) - 0x40)
			if (kind & 4) != 0:
				dx = -dx
				dy = -dy
			if (kind & 2) != 0:
				dx = -dx
				var swap = dx
				dx = dy
				dy = swap
			if kind >= 0x0C:
				dx = -dx
			position.x = orig_x + dx
			position.y = orig_y + dy
		_:
			position = Vector2(orig_x, orig_y)

	var nx = int(position.x)
	var ny = int(position.y)
	p.move_with_supported_object(record_index, nx - old_x, ny - old_y, nx - active_width, nx + active_width, ny - 0x11)
	p.resolve_platform_top(nx - active_width, nx + active_width, ny - 0x11, record_index)

# -----------------------------------------------------------------------------
# Object $1B - CPZ speed booster
# -----------------------------------------------------------------------------
func _init_booster() -> void:
	active_width = 32
	sprite = make_sprite("res://assets/objects/s2_cpz/booster/00.png")
	sprite.flip_h = x_flip

func _tick_booster() -> void:
	var p = player()
	if p == null:
		return
	# Timer_frames bit 1 directly selects mapping frame 0 or 2.
	var frame = 2 if ((manager.elapsed_frames >> 1) & 1) != 0 else 0
	_set_frame(sprite, "booster", frame)
	if p.in_air:
		return
	if absi(p.pixel_x() - spawn_x) >= 16 or absi(p.pixel_y() - spawn_y) >= 16:
		return

	var direction = -1 if x_flip else 1
	var directed_speed = p.vel_x * direction
	if directed_speed < 0x1000:
		var power = 0x0A00 if (subtype & 2) != 0 else 0x1000
		p.vel_x = power * direction
		p.inertia = p.vel_x
		p.facing_left = direction < 0
		p.lock_time = 15
		p.pushing = false
	SonicAudio.play_sfx(SonicAudio.SFX_SPRING)

# -----------------------------------------------------------------------------
# Object $1E - CPZ spin tube controller
# -----------------------------------------------------------------------------
func _init_spin_tube() -> void:
	active_width = 0x120
	visible = false
	var raw = FileAccess.get_file_as_string("res://data/s1/s2test/cpz_spin_tube_paths.json")
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		tube_paths = parsed

func _tick_spin_tube() -> void:
	var p = player()
	if p == null or tube_paths.is_empty():
		return
	if tube_active:
		_tube_follow_path(p)
		return
	if tube_cooldown:
		if not _tube_inside_detector(p):
			tube_cooldown = false
		return
	if p.dead or p.drowning or p.debug_free_mode or p.object_control_override:
		return
	if not _tube_inside_detector(p):
		return

	var width = _tube_detector_width()
	var dx = p.pixel_x() - spawn_x
	var dy = p.pixel_y() - spawn_y
	# Retail loc_225FC selects the entry/exit bank from objoff_2A:
	#   $A0  -> off_22980 entries 0..3
	#   $100 -> entries 4..7, with X mirrored around $100
	#   $120 -> entries 8..11
	# Phase 91 accidentally swapped the $100/$120 cases, which makes the first
	# CPZ1 tube (subtype $02, width $120) take the wrong local curve and often
	# hit a zero byte_227BE continuation.
	var base = 0
	if width == 0xA0:
		base = 0
	elif width == 0x120:
		base = 8
	else:
		base = 4
		dx = 0x100 - dx

	var entry_mode = 0
	if dx < 0x80:
		entry_mode = 3 if dy < 0x40 else 2
	else:
		var selector_table: Array[int] = [2,2,2,2,2,2,2,2,2,2,0,2,0,1,2,1]
		entry_mode = selector_table[(subtype >> 2) & 0x0F]
		# Source value 2 means choose entry 0/1 from Timer_second bit 0.
		if entry_mode == 2:
			entry_mode = int(manager.elapsed_frames / 60) & 1

	tube_entry_mode = entry_mode
	var entry: Array = tube_paths.get("entry", [])
	if entry.is_empty():
		return
	var idx = clampi(base + entry_mode, 0, entry.size() - 1)
	var rel: Array = entry[idx]
	var points: Array = []
	for q in rel:
		points.append(Vector2i(spawn_x + int(q[0]), spawn_y + int(q[1])))
	_start_tube_path(p, points, false)

func _tube_detector_width() -> int:
	match subtype & 3:
		0: return 0xA0
		1: return 0x100
		2: return 0x120
		_: return 0x120
	return 0x120

func _tube_inside_detector(p: SonicPlayer) -> bool:
	var dx = p.pixel_x() - spawn_x
	var dy = p.pixel_y() - spawn_y
	return dx >= 0 and dx < _tube_detector_width() and dy >= 0 and dy < 0x80

func _start_tube_path(p: SonicPlayer, source_points: Array, reverse: bool) -> void:
	if source_points.size() < 2:
		return
	var points: Array = source_points.duplicate(true)
	if reverse:
		points.reverse()
	tube_points = points
	tube_target = 1
	tube_active = true
	p.object_control_override = true
	p.clear_object_support()
	p.rolling = true
	p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
	p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH
	p.inertia = 0x800
	p.vel_x = 0
	p.vel_y = 0
	p.pushing = false
	p.in_air = true
	p.jumping = false
	var start: Vector2i = tube_points[0]
	p.force_set_pixel_position(start.x, start.y)
	SonicAudio.play_sfx(SonicAudio.SFX_ROLL)

func _tube_follow_path(p: SonicPlayer) -> void:
	if tube_target >= tube_points.size():
		_tube_finish_segment(p)
		return
	var target: Vector2i = tube_points[tube_target]
	var cx = p.pixel_x()
	var cy = p.pixel_y()
	var dx = target.x - cx
	var dy = target.y - cy
	var dominant = maxi(absi(dx), absi(dy))
	if dominant <= 8:
		p.force_set_pixel_position(target.x, target.y)
		tube_target += 1
		if tube_target >= tube_points.size():
			_tube_finish_segment(p)
		return
	# loc_22902 makes the dominant axis exactly $800 and derives the other
	# component proportionally. Integer pixel stepping preserves that path shape.
	var vx = int(round(float(dx) * 8.0 / float(dominant)))
	var vy = int(round(float(dy) * 8.0 / float(dominant)))
	p.vel_x = vx << 8
	p.vel_y = vy << 8
	p.force_set_pixel_position(cx + vx, cy + vy)

func _tube_finish_segment(p: SonicPlayer) -> void:
	# Entry-path completion selects an absolute CPZ tube path through byte_227BE.
	# Zero means this entry is itself an exit. Negative selectors traverse the
	# source main path backwards.
	if tube_entry_mode < 4:
		var continue_map: Array = tube_paths.get("continue_map", [])
		var map_idx = (subtype & 0xFC) + tube_entry_mode
		var selector = int(continue_map[map_idx]) if map_idx >= 0 and map_idx < continue_map.size() else 0
		tube_entry_mode = 4
		if selector != 0:
			var main_paths: Array = tube_paths.get("main", [])
			var path_idx = absi(selector)
			if path_idx >= 0 and path_idx < main_paths.size():
				var points: Array = []
				for q in main_paths[path_idx]:
					points.append(Vector2i(int(q[0]), int(q[1])))
				_start_tube_path(p, points, selector < 0)
				return
		_tube_release(p, true)
		return
	_tube_release(p, false)

func _tube_release(p: SonicPlayer, wait_until_clear: bool) -> void:
	# Retail Obj1E releases control first; the separate Obj7B cover can only
	# spring Sonic after his next normal movement pass. Mark this VBlank so an
	# Obj7B later in the same object loop cannot launch him immediately.
	manager.mark_s2_pipe_exit_frame()
	p.wrap_vertical_0x800()
	p.object_control_override = false
	p.in_air = true
	tube_active = false
	tube_cooldown = wait_until_clear
	tube_points.clear()
	tube_target = 0
	tube_entry_mode = 0

# -----------------------------------------------------------------------------
# Object $2D - CPZ one-way lifting barrier
# -----------------------------------------------------------------------------
func _init_barrier() -> void:
	active_width = 8
	var barrier_path: String = "res://assets/objects/s2_cpz/barrier/00.png"
	if manager != null and bool(manager.level_definition.get("s2_dez", false)):
		# DEZ Object $2D uses Construction Stripes 1 at ArtTile $328.
		barrier_path = "res://assets/objects/s2_dez/barrier/00.png"
	sprite = make_sprite(barrier_path)
	sprite.flip_h = x_flip

func _tick_barrier() -> void:
	var p = player()
	if p == null:
		return
	var in_x = false
	if x_flip:
		in_x = p.pixel_x() >= spawn_x - 0x18 and p.pixel_x() < spawn_x + 0x200
	else:
		in_x = p.pixel_x() >= spawn_x - 0x200 and p.pixel_x() < spawn_x + 0x18
	var wanted = in_x and p.pixel_y() >= spawn_y - 0x20 and p.pixel_y() < spawn_y + 0x20 and not p.object_control_override
	if wanted:
		barrier_raise = mini(0x40, barrier_raise + 8)
	else:
		barrier_raise = maxi(0, barrier_raise - 8)
	position.y = spawn_y - barrier_raise
	# Obj2D passes d1=$13 to SolidObject, but that is the Genesis combined
	# player+object horizontal distance. resolve_solid_box_contact() already
	# adds Sonic's radius, so DEZ must pass the object's actual width_pixels=8.
	var solid_half_width: int = 8 if manager != null and bool(manager.level_definition.get("s2_dez", false)) else 19
	p.resolve_solid_box_contact(spawn_x, int(position.y), solid_half_width, 32, true, record_index)

# -----------------------------------------------------------------------------
# Object $32 - CPZ breakable metal block
# -----------------------------------------------------------------------------
func _init_breakable_block() -> void:
	use_htz_breakable_rock = manager != null and bool(manager.level_definition.get("s2_htz", false))
	active_width = 0x18 if use_htz_breakable_rock else 0x10
	sprite = make_sprite("res://assets/objects/s2_htz/rock/00.png" if use_htz_breakable_rock else "res://assets/objects/s2_cpz/breakblock/00.png")
	htz_rock_broken = false
	htz_rock_fragment_timer = 0

func _spawn_htz_rock_debris() -> void:
	for i in range(6):
		var frag: Sprite2D = make_sprite("res://assets/objects/s2_htz/rock_fragment/%02d.png" % i, 3)
		htz_rock_fragments.append(frag)
		htz_rock_fragment_velocity.append(HTZ_ROCK_FRAGMENT_VELOCITY[i])

func _tick_htz_rock_debris() -> void:
	htz_rock_fragment_timer += 1
	for i in range(htz_rock_fragments.size()):
		var frag: Sprite2D = htz_rock_fragments[i]
		if frag == null or not is_instance_valid(frag):
			continue
		var v: Vector2 = htz_rock_fragment_velocity[i]
		frag.position += v
		v.y += 0.09375 # Obj32_Fragment: +$18 in 8.8
		htz_rock_fragment_velocity[i] = v
	if htz_rock_fragment_timer > 180:
		request_delete(false)

func _tick_breakable_block() -> void:
	if htz_rock_broken:
		_tick_htz_rock_debris()
		return
	var p = player()
	if p == null:
		return
	# Retail Obj32 snapshots Sonic's Roll animation BEFORE SolidObject. Our
	# floor-contact helper resets the rolling flag when it establishes support,
	# so preserve the pre-contact state exactly like breakableblock_mainchar_anim.
	var was_rolling = p.rolling
	var contact = p.resolve_solid_box_contact(spawn_x, spawn_y, active_width, 16, true, record_index)
	if contact == SonicPlayer.SOLID_TOP and was_rolling:
		# Obj32_BouncePlayer explicitly reasserts roll status/radii/animation.
		p.rolling = true
		p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
		p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH
		p.object_attack_active = true
		p.vel_y = -0x300
		p.in_air = true
		p.clear_object_support()
		SonicAudio.play_sfx(SonicAudio.SFX_WALL_SMASH)
		if use_htz_breakable_rock:
			# BreakObjectToPieces turns the six authored 16x16 mapping pieces into
			# live fragments. Keep this object alive only as their owner.
			if manager != null:
				manager.mark_record_destroyed(record_index)
			sprite.visible = false
			_spawn_htz_rock_debris()
			htz_rock_broken = true
		else:
			request_delete(true)


# -----------------------------------------------------------------------------
# Object $40 - CPZ red pressure/lever spring
# -----------------------------------------------------------------------------
const LEVER_SLOPE_DIAG: Array[int] = [8,8,8,8,8,8,8,9,10,11,12,13,14,15,16,16,17,18,19,20,20,21,21,22,23,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24]
const LEVER_SLOPE_FLAT: Array[int] = [8,8,8,8,8,8,8,9,10,11,12,12,12,12,13,13,13,13,13,13,14,14,15,15,16,16,16,16,15,15,14,14,13,13,13,13,13,13,13,13]
const LEVER_KICK: Array[int] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,3,3,3,3,3,3,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

func _init_lever_spring() -> void:
	active_width = 0x1C
	var root: String = "s2_mcz" if manager != null and bool(manager.level_definition.get("s2_mcz", false)) else "s2_cpz"
	sprite = make_sprite("res://assets/objects/%s/lever_spring/00.png" % root)
	sprite.flip_h = x_flip
	lever_anim_timer = 0

func _tick_lever_spring() -> void:
	var p = player()
	if p == null:
		return
	if lever_anim_timer > 0:
		lever_anim_timer -= 1
		_set_lever_spring_frame(1 if lever_anim_timer > 4 else 0)
	var local_x = clampi(p.pixel_x() - (spawn_x - 0x27), 0, 39)
	if x_flip:
		local_x = 39 - local_x
	var slope = LEVER_SLOPE_FLAT if lever_anim_timer > 4 else LEVER_SLOPE_DIAG
	var top_y = spawn_y - int(slope[local_x])
	var contact = p.resolve_platform_top(spawn_x - 0x27, spawn_x + 0x27, top_y, record_index)
	if not contact:
		return
	# loc_2641E arms the compression once Sonic is past the inner 16px edge,
	# then launches when the board returns to mapping frame zero.
	var trigger = p.pixel_x() > spawn_x - 0x10 if not x_flip else p.pixel_x() < spawn_x + 0x10
	if not trigger:
		return
	if lever_anim_timer == 0:
		lever_anim_timer = 8
		return
	if lever_anim_timer != 4:
		return
	var kick_index = clampi(p.pixel_x() - (spawn_x - 0x1C), 0, LEVER_KICK.size() - 1)
	if x_flip:
		kick_index = LEVER_KICK.size() - 1 - kick_index
	var kick: int = LEVER_KICK[kick_index]
	# 68000 sub.b targets the high byte of the big-endian 8.8 speed word,
	# so each table step is $100 of velocity, not one raw 8.8 unit.
	var kick_velocity: int = kick << 8
	p.vel_y = -0x400 - kick_velocity
	if absi(p.vel_x) >= 0x400:
		p.vel_x += -kick_velocity if x_flip else kick_velocity
	p.in_air = true
	p.clear_object_support()
	p.jumping = false
	p.pushing = false
	p.begin_s2_spring_visual(subtype, 3)
	match subtype & 0x0C:
		0x04: p.set_collision_path(GHZLevelData.COLLISION_PATH_PRIMARY)
		0x08: p.set_collision_path(GHZLevelData.COLLISION_PATH_SECONDARY, 0x400000 + record_index)
	SonicAudio.play_sfx(SonicAudio.SFX_SPRING)


func _set_lever_spring_frame(frame: int) -> void:
	if sprite == null:
		return
	var root: String = "s2_mcz" if manager != null and bool(manager.level_definition.get("s2_mcz", false)) else "s2_cpz"
	var path: String = "res://assets/objects/%s/lever_spring/%02d.png" % [root, frame]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

# -----------------------------------------------------------------------------
# Object $7A - CPZ water-top sideways platform group
# -----------------------------------------------------------------------------
func _init_water_platform() -> void:
	# byte_293B4 entries used by retail CPZ2 subtypes 0, 6 and $C.
	var count := 1
	var span := 0x68
	var offsets: Array[int] = [-0x68]
	if subtype == 6:
		count = 2
		span = 0xA8
		offsets = [-0xB0, 0x40]
	elif subtype == 0x0C:
		count = 2
		span = 0xE8
		offsets = [-0x80, 0x80]
	active_width = span + 0x30
	water_platform_min_x = spawn_x - span
	water_platform_max_x = spawn_x + span
	water_platform_x.clear()
	water_platform_dir.clear()
	water_platform_last_x.clear()
	for i in range(count):
		var px = spawn_x + offsets[i]
		water_platform_x.append(px)
		water_platform_last_x.append(px)
		# Obj7A subtype $C sets objoff_36 only on the main entry; the linked
		# second platform keeps the zero/default direction. Phase 93 incorrectly
		# sent both left, which prevents the source edge-contact reversal.
		var dir := 1
		if subtype == 0x0C and i == 0:
			dir = -1
		water_platform_dir.append(dir)
		var s = make_sprite("res://assets/objects/s2_cpz/water_platform/00.png")
		s.position = Vector2(px - spawn_x, 0)
		aux_sprites.append(s)

func _tick_water_platform() -> void:
	var p = player()
	if p == null:
		return
	var old_positions = water_platform_x.duplicate()
	for i in range(water_platform_x.size()):
		var nx = water_platform_x[i] + water_platform_dir[i]
		if nx <= water_platform_min_x:
			nx = water_platform_min_x
			water_platform_dir[i] = 1
		elif nx >= water_platform_max_x:
			nx = water_platform_max_x
			water_platform_dir[i] = -1
		water_platform_x[i] = nx

	# loc_2953E reverses the two linked platforms when their 24px edges touch.
	# Resolve the pair before player carrying so they can never cross through
	# each other if both one-pixel moves land on/past the contact coordinate.
	if water_platform_x.size() == 2:
		var approaching := (water_platform_x[0] < water_platform_x[1] and water_platform_dir[0] > 0 and water_platform_dir[1] < 0) or (water_platform_x[1] < water_platform_x[0] and water_platform_dir[1] > 0 and water_platform_dir[0] < 0)
		if approaching and absi(water_platform_x[0] - water_platform_x[1]) <= 0x30:
			var mid := int((water_platform_x[0] + water_platform_x[1]) / 2)
			if water_platform_x[0] < water_platform_x[1]:
				water_platform_x[0] = mid - 0x18
				water_platform_x[1] = mid + 0x18
			else:
				water_platform_x[1] = mid - 0x18
				water_platform_x[0] = mid + 0x18
			water_platform_dir[0] = -water_platform_dir[0]
			water_platform_dir[1] = -water_platform_dir[1]

	for i in range(water_platform_x.size()):
		var nx = water_platform_x[i]
		aux_sprites[i].position.x = nx - spawn_x
		var support_id = 0x7A0000 + record_index * 4 + i
		p.move_with_supported_object(support_id, nx - old_positions[i], 0, nx - 0x18, nx + 0x18, spawn_y - 8)
		p.resolve_platform_top(nx - 0x18, nx + 0x18, spawn_y - 8, support_id)

# -----------------------------------------------------------------------------
# Object $6B - CPZ square-path platform pair
# -----------------------------------------------------------------------------
func _init_square_platform() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/s2_cpz/stair/00.png")
	# CPZ places overlapping Obj6B $18/$19 records to form four-block square
	# groups. Their low nibbles deliberately select different oscillator/radius
	# pairs; treating every one as $19 collapses the four source blocks into two.
	square_phase = (1 if x_flip else 0) | (2 if y_flip else 0)
	var kind := clampi(subtype & 0x0F, 8, 0x0B)
	var rate_off := 0x2A + (kind - 8) * 4
	if manager.s2_source_osc_word(rate_off) < 0:
		square_phase ^= 1

func _tick_square_platform() -> void:
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)
	var kind := clampi(subtype & 0x0F, 8, 0x0B)
	var wave_off := 0x28 + (kind - 8) * 4
	var rate_off := wave_off + 2
	var wave = manager.s2_source_osc_byte(wave_off)
	# Obj6B type 8 alone halves Oscillating_Data+$28 before applying its $10 radius.
	if kind == 8:
		wave = wave >> 1
	var rate = manager.s2_source_osc_word(rate_off)
	if rate == 0:
		square_phase = (square_phase + 1) & 3
	var radius = 0x10 + (kind - 8) * 0x20
	match square_phase & 3:
		0:
			position.x = orig_x + wave - radius
			position.y = orig_y - radius
		1:
			position.x = orig_x + radius
			position.y = orig_y + (radius - 1 - wave)
		2:
			position.x = orig_x + (radius - 1 - wave)
			position.y = orig_y + radius
		_:
			position.x = orig_x - radius
			position.y = orig_y + wave - radius
	var nx = int(position.x)
	var ny = int(position.y)
	p.move_with_supported_object(record_index, nx - old_x, ny - old_y, nx - 16, nx + 16, ny - 16)
	p.resolve_solid_box_contact(nx, ny, 27, 16, true, record_index)

# -----------------------------------------------------------------------------
# Object $74 - invisible CPZ solid
# -----------------------------------------------------------------------------
func _init_invisible_block() -> void:
	visible = false
	active_width = ((subtype & 0xF0) + 0x10) >> 1

func _tick_invisible_block() -> void:
	var p = player()
	if p == null:
		return
	var half_h = ((subtype & 0x0F) + 1) << 3
	# Obj74's source adds $0B because original SolidObject compares the player
	# center against d1. The native bridge already compares player extents to the
	# raw object half-width; adding $0B again created an invisible side strip.
	p.resolve_solid_box_contact(spawn_x, spawn_y, active_width, half_h, true, record_index)

# -----------------------------------------------------------------------------
# Object $78 - four-block CPZ staircase
# -----------------------------------------------------------------------------
func _init_staircase() -> void:
	active_width = 80
	for i in range(4):
		var stair_sprite = make_sprite("res://assets/objects/s2_cpz/stair/00.png")
		stair_sprite.position = Vector2(i * 32, 0)
		aux_sprites.append(stair_sprite)
		stair_last_y[i] = spawn_y
	stair_progress = 0

func _tick_staircase() -> void:
	var p = player()
	if p == null:
		return
	if stair_triggered:
		if stair_delay > 0:
			stair_delay -= 1
		else:
			var direction = -1 if (subtype & 7) == 4 else 1
			stair_progress = clampi(stair_progress + direction, -0x80, 0x80)

	# Obj78 derives 3/4, 1/2 and 1/4 offsets with signed shifts.
	var half = stair_progress >> 1
	var quarter = stair_progress >> 2
	var base_offsets: Array[int] = [stair_progress, half + quarter, half, quarter]
	if x_flip:
		base_offsets.reverse()

	var top_touched = false
	for i in range(4):
		var cx = spawn_x + i * 32
		var cy = spawn_y + int(base_offsets[i])
		aux_sprites[i].position = Vector2(i * 32, int(base_offsets[i]))
		var support_id = 0x780000 + record_index * 8 + i
		p.move_with_supported_object(support_id, 0, cy - stair_last_y[i], cx - 16, cx + 16, cy - 16)
		var contact = p.resolve_solid_box_contact(cx, cy, 27, 16, true, support_id)
		if contact == SonicPlayer.SOLID_TOP:
			top_touched = true
		stair_last_y[i] = cy
	if top_touched and not stair_triggered:
		stair_triggered = true
		stair_delay = 0x1E

# -----------------------------------------------------------------------------
# Object $7B - CPZ spin-tube exit cover/spring
# -----------------------------------------------------------------------------
func _init_pipe_spring() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/s2_cpz/tube_spring/00.png")
	pipe_proximity_timer = 0
	pipe_launch_timer = 0

func _tick_pipe_spring() -> void:
	var p = player()
	if p == null:
		return

	# Ani_obj7B animation 2/3: duration 5, frames 1,2,2,2,4.
	# AnimateSprite therefore holds each script entry for six ticks.
	if pipe_launch_timer > 0:
		pipe_launch_timer -= 1
		_set_frame(sprite, "tube_spring", 3)
		if pipe_launch_timer == 0:
			pipe_launch_timer = -1
	elif pipe_launch_timer < 0:
		pipe_launch_timer = 0
		_set_frame(sprite, "tube_spring", 0)
	elif pipe_proximity_timer > 0:
		pipe_proximity_timer -= 1
		var elapsed = 29 - pipe_proximity_timer
		var frame = 1 if elapsed < 6 else 2 if elapsed < 24 else 4
		_set_frame(sprite, "tube_spring", frame)
		if pipe_proximity_timer == 0:
			_set_frame(sprite, "tube_spring", 0)

	var current_frame_one = pipe_launch_timer == 0 and pipe_proximity_timer >= 24
	var contact = SonicPlayer.SOLID_NONE
	var just_left_tube = manager.s2_pipe_exit_blocked_this_frame()
	# Obj7B_Main deliberately skips SolidObject only while mapping frame 1 is up.
	if not current_frame_one and not just_left_tube:
		# S2 passes d1=$1B to SolidObject, but that value already includes the
		# character's horizontal radius. Native resolve_solid_box_contact adds
		# Sonic's radius itself, so an 18px object half-width reproduces the
		# source ~27px center-to-center envelope instead of extending ~9px too far.
		contact = p.resolve_solid_box_contact(spawn_x, spawn_y, 18, 16, true, record_index)
	if contact == SonicPlayer.SOLID_TOP:
		p.force_add_pixel_offset(0, 4)
		p.clear_object_support()
		p.vel_y = -0x0A80 if (subtype & 2) != 0 else -0x1000
		if (subtype & 0x80) != 0:
			p.vel_x = 0
		p.in_air = true
		p.pushing = false
		p.jumping = false
		p.begin_s2_spring_visual(subtype, 0)
		match subtype & 0x0C:
			0x04: p.set_collision_path(GHZLevelData.COLLISION_PATH_PRIMARY)
			0x08: p.set_collision_path(GHZLevelData.COLLISION_PATH_SECONDARY, 0x7B0000 + record_index)
		SonicAudio.play_sfx(SonicAudio.SFX_SPRING)
		# Source animation 1 shows mapping frame 3 for one tick before returning.
		pipe_launch_timer = 1

	# Proximity animation begins when a character is within the $20 x $30
	# exit region. Do not restart it until the existing sequence has completed.
	if pipe_launch_timer == 0 and pipe_proximity_timer == 0 and p.pixel_x() >= spawn_x - 0x10 and p.pixel_x() < spawn_x + 0x10 and p.pixel_y() >= spawn_y and p.pixel_y() < spawn_y + 0x30:
		pipe_proximity_timer = 30

func _set_frame(target_sprite: Sprite2D, folder: String, frame: int) -> void:
	if target_sprite == null:
		return
	var path = "res://assets/objects/s2_cpz/%s/%02d.png" % [folder, frame]
	if ResourceLoader.exists(path):
		target_sprite.texture = load(path)
