class_name SLZNativeObject
extends GenesisLevelObject

# Phase 36 source-driven Star Light Zone object families:
# $59 Elevator, $5A Circling Platform, $5B Staircase, $5C Foreground Pylon,
# $5D Fan, $5E Seesaw, $5F Walking Bomb.

var sprite: Sprite2D

# Elevator state.
var elev_spawner := false
var elev_spawn_delay := 0
var elev_spawn_delay_base := 0
var elev_action := 0
var elev_half_distance := 0.0
var elev_distance := 0.0
var elev_accel := 0
var elev_slowing := false
var elev_orig := Vector2.ZERO

# Stair state.
var stair_sprites: Array[Sprite2D] = []
var stair_offsets: Array[int] = [0, 0, 0, 0]
var stair_last_offsets: Array[int] = [0, 0, 0, 0]
var stair_delay := 0
var stair_touch := 0
var stair_mode := 0

# Seesaw state.
var seesaw_ball := false
var seesaw_parent: SLZNativeObject = null
var seesaw_state := 0
var seesaw_ball_state := 0
var seesaw_frame := 0
var seesaw_landing_speed := 0
var seesaw_orig := Vector2.ZERO
var seesaw_vel := Vector2.ZERO
var seesaw_ball_in_air := false

const SEESAW_SLOPE: Array[int] = [
	0x24,0x24,0x26,0x28,0x2A,0x2C,0x2A,0x28,0x26,0x24,
	0x23,0x22,0x21,0x20,0x1F,0x1E,0x1D,0x1C,0x1B,0x1A,
	0x19,0x18,0x17,0x16,0x15,0x14,0x13,0x12,0x11,0x10,
	0x0F,0x0E,0x0D,0x0C,0x0B,0x0A,0x09,0x08,0x07,0x06,
	0x05,0x04,0x03,0x02,0x02,0x02,0x02,0x02
]
const SEESAW_BALL_Y: Array[int] = [-8, -28, -47, -28, -8]

# Fan state.
var fan_switch_off := false
var fan_timer := 0
var fan_anim_step := 0
var fan_frame_timer := 0

# Bomb/fuse/shrapnel state.
var bomb_kind := 0 # 0 body, 1 fuse, 2 shrapnel
var bomb_mode := 0 # body: 0 walking, 1 waiting, 2 activated
var bomb_timer := 0
var bomb_vel := Vector2.ZERO
var bomb_anim_timer := 0
var bomb_anim_index := 0
var bomb_orig_y := 0

func initialize_object() -> void:
	match object_id:
		0x59:
			_init_elevator()
		0x5A:
			_init_circle()
		0x5B:
			_init_stair()
		0x5C:
			_init_pylon()
		0x5D:
			_init_fan()
		0x5E:
			_init_seesaw()
		0x5F:
			_init_bomb_body()
		_:
			request_delete(false)

func tick() -> void:
	if not alive:
		return
	if seesaw_ball:
		_tick_seesaw_ball()
		return
	if bomb_kind == 1:
		_tick_bomb_fuse()
		return
	if bomb_kind == 2:
		_tick_bomb_shrapnel()
		return
	match object_id:
		0x59:
			_tick_elevator()
		0x5A:
			_tick_circle()
		0x5B:
			_tick_stair()
		0x5C:
			_tick_pylon()
		0x5D:
			_tick_fan()
		0x5E:
			_tick_seesaw()
		0x5F:
			_tick_bomb_body()

# -----------------------------------------------------------------------------
# Object $59 - SLZ elevator platforms
# -----------------------------------------------------------------------------
func _init_elevator() -> void:
	active_width = 40
	elev_orig = position
	if (subtype & 0x80) != 0:
		elev_spawner = true
		visible = false
		elev_spawn_delay_base = (subtype & 0x7F) * 6
		elev_spawn_delay = elev_spawn_delay_base
		return
	var total_distances: Array[int] = [0x80,0x100,0x1A0,0x80,0x100,0x1A0,0xA0,0x120,0x160,0xA0,0x120,0x160,0x100,0x100,0x180]
	var actions: Array[int] = [1,1,1,3,3,3,1,1,1,3,3,3,5,7,9]
	var idx = clampi(subtype & 0x0F, 0, 14)
	elev_half_distance = float(total_distances[idx]) * 0.5
	elev_action = actions[idx]
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_level_object_texture("elevator")
	sprite.position.y = 8.0 # Map_Elev origin: 32px sprite spans y=-8..23.

func setup_spawned_elevator(owner: SonicObjectManager, world_x: int, world_y: int) -> void:
	manager = owner
	object_id = 0x59
	subtype = 0x0E
	record_index = -300000 - manager.elapsed_frames - manager.transient_objects.size()
	spawn_x = world_x
	spawn_y = world_y
	position = Vector2(world_x, world_y)
	alive = true
	_init_elevator()

func _tick_elevator() -> void:
	if elev_spawner:
		elev_spawn_delay -= 1
		if elev_spawn_delay <= 0:
			elev_spawn_delay = maxi(1, elev_spawn_delay_base)
			var child = SLZNativeObject.new()
			child.name = "SLZElevatorSpawned"
			manager.add_child(child)
			child.setup_spawned_elevator(manager, int(position.x), int(position.y))
			manager.transient_objects.append(child)
		return
	var p = player()
	if p == null:
		return
	var old = position
	if (elev_action & 1) != 0 and elev_action != 9:
		if p.standing_on_object and p.support_record_index == record_index:
			elev_action += 1
	var motion_action = elev_action
	if (motion_action & 1) == 0 or motion_action == 9:
		_elev_move_distance()
	# Elev_Move clears the action byte when the destination is reached, but the
	# caller still applies that frame's final position using the old action.
	match motion_action:
		2:
			position.y = elev_orig.y - elev_distance
		4:
			position.y = elev_orig.y + elev_distance
		6:
			position.x = elev_orig.x + elev_distance
			position.y = elev_orig.y - elev_distance * 0.5
		8:
			position.x = elev_orig.x - elev_distance
			position.y = elev_orig.y + elev_distance * 0.5
		9:
			position.y = elev_orig.y - elev_distance
	var dx = position.x - old.x
	var dy = position.y - old.y
	p.move_with_supported_object_fractional(record_index, dx, dy, int(position.x) - 40, int(position.x) + 40, int(position.y) - 8)
	p.resolve_platform_top(int(position.x) - 40, int(position.x) + 40, int(position.y) - 8, record_index)
	if motion_action == 9 and elev_action == 0:
		if p.standing_on_object and p.support_record_index == record_index:
			p.clear_object_support()
			p.in_air = true
		request_delete(false)

func _elev_move_distance() -> void:
	if not elev_slowing:
		elev_accel = mini(0x800, elev_accel + 0x10)
	else:
		elev_accel = maxi(0, elev_accel - 0x10)
	elev_distance += float(elev_accel) / 256.0
	if elev_distance > elev_half_distance:
		elev_slowing = true
	var full = elev_half_distance * 2.0
	if elev_distance >= full:
		elev_distance = full
		if elev_action != 9:
			elev_action = 0

# -----------------------------------------------------------------------------
# Object $5A - circling platform
# -----------------------------------------------------------------------------
func _init_circle() -> void:
	active_width = 24
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_level_object_texture("circle")

func _signed_byte(value: int) -> int:
	value &= 0xFF
	return value - 0x100 if value >= 0x80 else value

func _tick_circle() -> void:
	var p = player()
	if p == null:
		return
	var old = position
	var dx = _signed_byte((manager.oscillate_22() - 0x50) & 0xFF)
	var dy = _signed_byte((manager.oscillate_26() - 0x50) & 0xFF)
	if (subtype & 1) != 0:
		dx = -dx
		dy = -dy
	if (subtype & 2) != 0:
		dx = -dx
		var swap = dx
		dx = dy
		dy = swap
	if (subtype & 4) != 0:
		dx = -dx
	position = Vector2(spawn_x + dx, spawn_y + dy)
	var move = position - old
	p.move_with_supported_object_fractional(record_index, move.x, move.y, int(position.x) - 24, int(position.x) + 24, int(position.y) - 8)
	p.resolve_platform_top(int(position.x) - 24, int(position.x) + 24, int(position.y) - 8, record_index)

# -----------------------------------------------------------------------------
# Object $5B - four-block staircase
# -----------------------------------------------------------------------------
func _init_stair() -> void:
	active_width = 80
	stair_mode = subtype & 7
	visible = true
	var tex = SourceObjectArt.slz_level_object_texture("stair")
	for i in range(4):
		var sp = Sprite2D.new()
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.texture = tex
		sp.position = Vector2(i * 32, 0)
		sp.z_index = 30
		add_child(sp)
		stair_sprites.append(sp)

func _tick_stair() -> void:
	var p = player()
	if p == null:
		return
	# Stair_Move runs on the parent before the child Stair_Solid routines. Use
	# the touch state latched by the previous frame, update the Y table first,
	# then let this frame's contacts seed the next parent update.
	if stair_mode == 0:
		if stair_delay == 0 and stair_touch == 1:
			stair_delay = 30
		elif stair_delay > 0:
			stair_delay -= 1
			if stair_delay == 0:
				stair_mode = 1
	elif stair_mode == 2:
		if stair_delay == 0 and stair_touch < 0:
			stair_delay = 60
		elif stair_delay > 0:
			stair_delay -= 1
			if stair_delay == 0:
				stair_mode = 1
			else:
				var wobble = (stair_delay >> 2) & 1
				stair_offsets = [wobble, wobble ^ 1, wobble, wobble ^ 1]
	if stair_mode == 1 and stair_offsets[0] < 128:
		var d = stair_offsets[0] + 1
		stair_offsets[0] = mini(128, d)
		stair_offsets[1] = int(d * 3 / 4)
		stair_offsets[2] = int(d / 2)
		stair_offsets[3] = int(d / 4)

	stair_touch = 0
	var mapping: Array[int] = [0,1,2,3]
	if x_flip:
		mapping = [3,2,1,0]
	for i in range(4):
		var yoff = stair_offsets[mapping[i]]
		var last_yoff = stair_last_offsets[mapping[i]]
		var cx = spawn_x + i * 32
		var cy = spawn_y + yoff
		stair_sprites[i].position = Vector2(i * 32, yoff)
		var sid = -400000 - record_index * 4 - i
		p.move_with_supported_object(sid, 0, yoff - last_yoff, cx - 16, cx + 16, cy - 16)
		var contact = p.resolve_solid_box_contact(cx, cy, 16, 16, true, sid)
		if contact == SonicPlayer.SOLID_TOP:
			stair_touch = 1
		elif contact == SonicPlayer.SOLID_BOTTOM:
			stair_touch = -1
	stair_last_offsets = stair_offsets.duplicate()

func suppress_central_despawn() -> bool:
	# Object $5C lives at authored position (0,0) but switches to screen-fixed
	# rendering and must persist for the entire act.
	return object_id == 0x5C

# -----------------------------------------------------------------------------
# Object $5C - screen-fixed foreground pylon
# -----------------------------------------------------------------------------
func _init_pylon() -> void:
	active_width = 16
	z_index = 130
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_pylon_texture()
	# The generated texture keeps Map_Pylon's origin at (16,160).
	sprite.position = Vector2(0, 0)
	_tick_pylon()

func _tick_pylon() -> void:
	# Pyl_Display stores raw VDP screen coordinates. BuildSpr_Draw then wraps
	# every piece to 9-bit X ($000-$1FF); both axes include the VDP's $80
	# sprite-coordinate bias. Convert that raw coordinate back to Godot screen
	# pixels before adding the Camera2D world origin.
	# Map_Pylon's nine pieces all start at relative X -$10. The hardware
	# applies the 9-bit wrap *after* that mapping offset, so wrap the piece
	# coordinate and then convert back to this combined texture's center.
	var raw_piece_x = ((-2 * manager.current_screen_x) - 0x10) & 0x1FF
	var screen_x = raw_piece_x - 0x80 + 0x10
	var raw_y = 0x100 - ((2 * manager.current_screen_y) & 0x3F)
	var screen_y = raw_y - 0x80
	position = Vector2(manager.current_screen_x + screen_x, manager.current_screen_y + screen_y)

# -----------------------------------------------------------------------------
# Object $5E - SLZ seesaw and spikeball
# -----------------------------------------------------------------------------
func _init_seesaw() -> void:
	active_width = 48
	z_index = 40
	seesaw_orig = position
	seesaw_frame = 2 if x_flip else 0
	seesaw_state = seesaw_frame
	sprite = make_sprite("")
	_update_seesaw_visual()
	if subtype == 0:
		var ball = SLZNativeObject.new()
		ball.name = "SLZSeesawBall"
		manager.add_child(ball)
		ball.setup_seesaw_ball(manager, self)
		manager.transient_objects.append(ball)

func setup_seesaw_ball(owner: SonicObjectManager, parent: SLZNativeObject) -> void:
	manager = owner
	object_id = 0x5E
	record_index = -700000 - owner.elapsed_frames - owner.transient_objects.size()
	alive = true
	seesaw_ball = true
	seesaw_parent = parent
	seesaw_orig = parent.position
	seesaw_ball_state = 2 if parent.x_flip else 0
	seesaw_state = seesaw_ball_state
	active_width = 12
	z_index = 39
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_seesaw_ball_texture(true)
	_align_seesaw_ball()

func _tick_seesaw() -> void:
	var p = player()
	if p == null:
		return

	var is_supported = p.standing_on_object and p.support_record_index == record_index
	if is_supported:
		# See_Seesaw_StoodOn goes straight to See_ChkSide; it does not also run
		# the platform routine's state-change step in the same frame.
		var dx = int(position.x) - p.pixel_x()
		var target = 2
		if dx < 0:
			dx = -dx
			target = 0
		if dx < 8:
			target = 1
		_change_seesaw_frame(target)
	else:
		# See_Seesaw_Platform first responds to a spikeball-selected state, then
		# captures Sonic's incoming Y speed immediately before SlopeObject.
		_change_seesaw_frame(seesaw_state)
		seesaw_landing_speed = p.vel_y

	var top_y = _seesaw_top_y_for(p.pixel_x())
	if top_y == 0x7FFFFFFF:
		if is_supported:
			p.clear_object_support_for(record_index, false)
		return
	if is_supported:
		# See_Seesaw_StoodOn uses ExitPlatform followed by
		# SlopeObject_AssumeStoodOn: once supported, Sonic follows the sampled
		# slope directly instead of re-running the fresh-landing penetration test.
		p.snap_supported_slope(int(position.x) - 48, int(position.x) + 48, top_y, record_index)
	else:
		p.resolve_platform_top(int(position.x) - 48, int(position.x) + 48, top_y, record_index)

func _seesaw_top_y_for(world_x: int) -> int:
	var local_x = world_x - (int(position.x) - 48)
	if local_x < 0 or local_x >= 96:
		return 0x7FFFFFFF
	var idx = clampi(local_x >> 1, 0, 47)
	if (seesaw_frame & 2) != 0:
		idx = 47 - idx
	var height = 0x15 if (seesaw_frame & 1) != 0 else SEESAW_SLOPE[idx]
	return int(position.y) - height

func _change_seesaw_frame(target: int) -> void:
	target = clampi(target, 0, 2)
	if seesaw_frame != target:
		if seesaw_frame < target:
			seesaw_frame += 1
		else:
			seesaw_frame -= 1
		seesaw_state = target
		_update_seesaw_visual()

func _update_seesaw_visual() -> void:
	if sprite == null:
		return
	sprite.texture = SourceObjectArt.slz_seesaw_texture((seesaw_frame & 1) != 0)
	sprite.flip_h = (seesaw_frame & 2) != 0

func _align_seesaw_ball() -> void:
	if seesaw_parent == null or not is_instance_valid(seesaw_parent):
		return
	var frame = clampi(seesaw_parent.seesaw_frame, 0, 2)
	var left_side = seesaw_ball_state == 2
	var index = frame + (2 if left_side else 0)
	position.x = seesaw_orig.x + (-40 if left_side else 40)
	position.y = seesaw_orig.y + SEESAW_BALL_Y[index]
	seesaw_vel = Vector2.ZERO

func _tick_seesaw_ball() -> void:
	if seesaw_parent == null or not is_instance_valid(seesaw_parent) or not seesaw_parent.alive:
		request_delete(false)
		return

	if not seesaw_ball_in_air:
		var diff = absi(seesaw_ball_state - seesaw_parent.seesaw_state)
		if diff != 0:
			var vy = -0x818
			var vx = -0x114
			if diff != 1:
				vy = -0xAF0
				vx = -0xCC
				if seesaw_parent.seesaw_landing_speed >= 0xA00:
					vy = -0xE00
					vx = -0xA0
			if position.x < seesaw_orig.x:
				vx = -vx
			seesaw_vel = Vector2(vx, vy)
			seesaw_ball_in_air = true
		else:
			_align_seesaw_ball()
	else:
		_tick_seesaw_ball_flight()

	_react_seesaw_ball()

func _seesaw_object_fall() -> void:
	position.x += seesaw_vel.x / 256.0
	position.y += seesaw_vel.y / 256.0
	seesaw_vel.y += 0x38

func _tick_seesaw_ball_flight() -> void:
	if seesaw_vel.y < 0:
		_seesaw_object_fall()
		# Literal source compare: while the ball is still within 47px of its
		# home Y on the way up, ObjectFall runs a second time this frame.
		if int(position.y) >= int(seesaw_orig.y) - 47:
			_seesaw_object_fall()
		return

	_seesaw_object_fall()
	var left_side = position.x < seesaw_orig.x
	var frame = clampi(seesaw_parent.seesaw_frame, 0, 2)
	var index = frame + (2 if left_side else 0)
	var landing_y = int(seesaw_orig.y) + SEESAW_BALL_Y[index]
	if int(position.y) < landing_y:
		return

	position.y = landing_y
	var target = 2 if seesaw_vel.x < 0 else 0
	seesaw_parent.seesaw_state = target
	seesaw_ball_state = target
	if target != seesaw_parent.seesaw_frame:
		var p = player()
		if p != null and p.standing_on_object and p.support_record_index == seesaw_parent.record_index:
			p.clear_object_support()
			p.vel_y = -int(seesaw_vel.y)
			p.in_air = true
			p.jumping = false
			p.pushing = false
			p.spring_pose_timer = 48
			p._sync_position()
	seesaw_vel = Vector2.ZERO
	seesaw_ball_in_air = false

func _react_seesaw_ball() -> void:
	var p = player()
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - int(position.x)) <= p.width_radius + 8 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 8:
		p.apply_hazard_hit(int(position.x))

# -----------------------------------------------------------------------------
# Object $5D - SLZ fan
# -----------------------------------------------------------------------------
func _init_fan() -> void:
	active_width = 16
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_fan_texture(0)
	fan_switch_off = false
	fan_timer = 0
	fan_anim_step = 0
	fan_frame_timer = 0

func _tick_fan() -> void:
	var always_on = (subtype & 2) != 0
	if not always_on:
		# Source starts fan_time at 0. The first underflow toggles fan_switch to
		# OFF for 2 seconds; the next underflow turns it ON for 3 seconds.
		fan_timer -= 1
		if fan_timer < 0:
			fan_timer = 120
			fan_switch_off = not fan_switch_off
			# BCHG followed by BEQ tests the *previous* bit: initial 0->1
			# remains at 120 (OFF), while 1->0 changes to 180 (ON).
			if not fan_switch_off:
				fan_timer = 180
	if fan_switch_off:
		return
	_push_player_from_fan()
	# obTimeFrame resets to zero, so an active fan advances every frame.
	fan_frame_timer -= 1
	if fan_frame_timer < 0:
		fan_frame_timer = 0
		fan_anim_step = (fan_anim_step + 1) % 3
		var frame = fan_anim_step
		if (subtype & 1) != 0:
			# Source adds a base frame offset of 2: 3,4,2,... after the
			# first animation advance, not 1,0,2.
			frame = 2 + fan_anim_step
		sprite.texture = SourceObjectArt.slz_fan_texture(frame)

func _s16(value: int) -> int:
	value &= 0xFFFF
	return value - 0x10000 if value >= 0x8000 else value

func _push_player_from_fan() -> void:
	var p = player()
	if p == null or p.dead or p.debug_free_mode:
		return
	# Literal integer translation of Fan_Action's range and force arithmetic.
	# obStatus bit 0 is the placement X-flip; subtype bit 0 is the backwards-
	# blowing variant and reverses the final force independently.
	var d0 = _s16(p.pixel_x() - int(position.x))
	if not x_flip:
		d0 = _s16(-d0)
	var ranged = d0 + 0x50
	if ranged < 0 or ranged >= 0xF0:
		return
	var d1 = p.pixel_y() + 0x60 - int(position.y)
	if d1 < 0 or d1 >= 0x70:
		return

	d0 = ranged - 0x50
	if ranged < 0x50:
		d0 = _s16(((~d0) & 0xFFFF) * 2)
	d0 = _s16(d0 + 0x60)
	var low = (- (d0 & 0xFF)) & 0xFF
	d0 = _s16((d0 & 0xFF00) | low)
	d0 >>= 4
	if not x_flip:
		d0 = -d0
	if (subtype & 1) != 0:
		d0 = -d0
	p.fixed_x += d0 * 65536
	p._sync_position()

# -----------------------------------------------------------------------------
# Object $5F - Walking Bomb, fuse and shrapnel
# -----------------------------------------------------------------------------
func _init_bomb_body() -> void:
	active_width = 12
	bomb_kind = 0
	bomb_mode = 0
	bomb_timer = 1535
	# Bom_Main toggles status bit 0 once, then the initial zero-length Waiting
	# state toggles it back while selecting velocity. Net result: authored
	# X-flip is retained, with flipped Bombs walking right and unflipped Bombs left.
	bomb_vel = Vector2(0x10 if x_flip else -0x10, 0)
	bomb_anim_timer = 19
	bomb_anim_index = 0
	z_index = 35
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_bomb_texture(5)
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip
	# The 32x48 generated texture keeps Map_Bomb's origin at (16,26). Whole
	# mapping Y-flip mirrors that origin, so compensate the two-pixel centering.
	sprite.position.y = 2.0 if y_flip else -2.0

func setup_bomb_fuse(owner: SonicObjectManager, world_x: int, world_y: int, flip_h: bool, flip_v: bool) -> void:
	manager = owner
	object_id = 0x5F
	record_index = -500000 - owner.elapsed_frames - owner.transient_objects.size()
	position = Vector2(world_x, world_y)
	spawn_x = world_x
	spawn_y = world_y
	x_flip = flip_h
	y_flip = flip_v
	alive = true
	bomb_kind = 1
	bomb_orig_y = world_y
	bomb_timer = 143
	bomb_vel = Vector2(0, -0x10 if flip_v else 0x10)
	bomb_anim_timer = 3
	bomb_anim_index = 0
	# Fuse has the same source priority as the body but occupies a later OST
	# slot, so the body wins overlap. Keep it one Godot layer behind the body.
	z_index = 34
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_bomb_texture(8)
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip
	sprite.position.y = 2.0 if y_flip else -2.0

func setup_bomb_shrapnel(owner: SonicObjectManager, world_x: int, world_y: int, vel_x: int, vel_y: int) -> void:
	manager = owner
	object_id = 0x5F
	record_index = -600000 - owner.elapsed_frames - owner.transient_objects.size()
	position = Vector2(world_x, world_y)
	spawn_x = world_x
	spawn_y = world_y
	alive = true
	bomb_kind = 2
	bomb_vel = Vector2(vel_x, vel_y)
	bomb_anim_timer = 3
	bomb_anim_index = 0
	z_index = 36
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.slz_bomb_texture(10)
	sprite.position.y = -2.0

func _tick_bomb_body() -> void:
	var p = player()
	if p == null:
		return
	if bomb_mode != 2 and absi(p.pixel_x() - int(position.x)) < 96 and absi(p.pixel_y() - int(position.y)) < 96 and not p.debug_free_mode:
		bomb_mode = 2
		bomb_timer = 143
		bomb_vel.x = 0
		bomb_anim_index = 0
		bomb_anim_timer = 19
		sprite.texture = SourceObjectArt.slz_bomb_texture(7)
		var fuse = SLZNativeObject.new()
		fuse.name = "SLZBombFuse"
		manager.add_child(fuse)
		fuse.setup_bomb_fuse(manager, int(position.x), int(position.y), x_flip, y_flip)
		manager.transient_objects.append(fuse)
	if bomb_mode == 0:
		bomb_timer -= 1
		position.x += bomb_vel.x / 256.0
		if bomb_timer < 0:
			bomb_mode = 1
			bomb_timer = 179
			bomb_vel.x = 0
			bomb_anim_index = 0
			bomb_anim_timer = 19
			sprite.texture = SourceObjectArt.slz_bomb_texture(1)
	elif bomb_mode == 1:
		bomb_timer -= 1
		if bomb_timer < 0:
			bomb_mode = 0
			bomb_timer = 1535
			x_flip = not x_flip
			sprite.flip_h = x_flip
			bomb_vel.x = 0x10 if x_flip else -0x10
			bomb_anim_index = 0
			bomb_anim_timer = 19
			sprite.texture = SourceObjectArt.slz_bomb_texture(5)
	elif bomb_mode == 2:
		bomb_timer -= 1
		if bomb_timer < 0:
			manager.spawn_monitor_explosion(int(position.x), int(position.y))
			request_delete(true)
			return
	_update_bomb_animation()
	_react_bomb_body()

func _update_bomb_animation() -> void:
	bomb_anim_timer -= 1
	if bomb_anim_timer >= 0:
		return
	if bomb_mode == 0:
		bomb_anim_timer = 19
		var frames: Array[int] = [5,4,3,2]
		bomb_anim_index = (bomb_anim_index + 1) % frames.size()
		sprite.texture = SourceObjectArt.slz_bomb_texture(frames[bomb_anim_index])
	elif bomb_mode == 1:
		bomb_anim_timer = 19
		bomb_anim_index ^= 1
		sprite.texture = SourceObjectArt.slz_bomb_texture([1,0][bomb_anim_index])
	else:
		bomb_anim_timer = 19
		bomb_anim_index ^= 1
		sprite.texture = SourceObjectArt.slz_bomb_texture([7,6][bomb_anim_index])

func _react_bomb_body() -> void:
	var p = player()
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - int(position.x)) > p.width_radius + 12 or absi(p.pixel_y() - int(position.y)) > p.height_radius + 12:
		return
	# Source obColType is col_24x24|col_hurt ($80 subgroup), not col_badnik.
	# Rolling/jumping therefore never destroys the Bomb; contact is always
	# processed through React_ChkHurt (invincibility still suppresses damage).
	p.apply_hazard_hit(int(position.x))

func _tick_bomb_fuse() -> void:
	bomb_timer -= 1
	position += bomb_vel / 256.0
	bomb_anim_timer -= 1
	if bomb_anim_timer < 0:
		bomb_anim_timer = 3
		bomb_anim_index ^= 1
		sprite.texture = SourceObjectArt.slz_bomb_texture(8 + bomb_anim_index)
	if bomb_timer >= 0:
		return
	var speeds = [Vector2(-0x200,-0x300), Vector2(-0x100,-0x200), Vector2(0x200,-0x300), Vector2(0x100,-0x200)]
	for velocity in speeds:
		var shrapnel = SLZNativeObject.new()
		shrapnel.name = "SLZBombShrapnel"
		manager.add_child(shrapnel)
		shrapnel.setup_bomb_shrapnel(manager, int(position.x), bomb_orig_y, int(velocity.x), int(velocity.y))
		manager.transient_objects.append(shrapnel)
	request_delete(false)

func _tick_bomb_shrapnel() -> void:
	position += bomb_vel / 256.0
	bomb_vel.y += 0x18
	bomb_anim_timer -= 1
	if bomb_anim_timer < 0:
		bomb_anim_timer = 3
		bomb_anim_index ^= 1
		sprite.texture = SourceObjectArt.slz_bomb_texture(10 + bomb_anim_index)
	var p = player()
	if p != null and not p.dead and absi(p.pixel_x() - int(position.x)) <= p.width_radius + 4 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 4:
		p.apply_hazard_hit(int(position.x))
	var viewport_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if position.x < manager.current_screen_x - 32 or position.x > manager.current_screen_x + viewport_width + 32 or position.y < manager.current_screen_y - 48 or position.y > manager.current_screen_y + viewport_height + 48:
		request_delete(false)
