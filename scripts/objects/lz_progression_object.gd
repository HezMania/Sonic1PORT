class_name LZProgressionObject
extends GenesisLevelObject

# Phase 33 source-driven Labyrinth progression objects:
#   $0B breakable wind-tunnel pole
#   $0C flapping wind-tunnel door
#   $63 conveyor wheels / group spawners / moving platforms

var sprite: Sprite2D

# Object $0B.
var pole_grabbed = false
var pole_broken = false
var pole_inert = false
var pole_touch_latched = false
var pole_break_timer = 0

# Object $0C.
var flap_frame = 0
var flap_opening = false
var flap_wait = 0
var flap_period = 0
var flap_anim_timer = 0

# Object $63.
var conveyor_spawner = false
var conveyor_wheel = false
var conveyor_platform = false
var conveyor_group = -1
var conveyor_support_id = -1
var conveyor_target_index = 0
var conveyor_increment = 1
var conveyor_reversed = false
var conveyor_targets: Array[Vector2i] = []
var conveyor_velocity = Vector2.ZERO
var conveyor_frame = 0

func initialize_object() -> void:
	match object_id:
		0x0B:
			_init_pole()
		0x0C:
			_init_flap_door()
		0x63:
			_init_conveyor_record()
		_:
			request_delete(false)

func tick() -> void:
	if not alive:
		return
	match object_id:
		0x0B:
			_tick_pole()
		0x0C:
			_tick_flap_door()
		0x63:
			if conveyor_platform:
				_tick_conveyor_platform()
			elif conveyor_wheel:
				_tick_conveyor_wheel()

func suppress_central_despawn() -> bool:
	# Source spawners are allowed to unload/reload groups, but keeping these very
	# small controller objects resident avoids native duplicate/stale blocker state
	# while the actual moving platforms still follow the exact source paths.
	return object_id == 0x0B or object_id == 0x0C or conveyor_spawner

# -----------------------------------------------------------------------------
# Object $0B - breakable pole in LZ3 wind tunnels
# -----------------------------------------------------------------------------
func _init_pole() -> void:
	active_width = 8
	z_index = 40
	pole_break_timer = (subtype & 0xFF) * 60
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.lz_breakable_pole_texture(0)

func _tick_pole() -> void:
	var p = player()
	if p == null:
		return
	if pole_inert:
		manager.set_lz_wind_blocker(record_index, false)
		return

	if pole_grabbed:
		manager.set_lz_wind_blocker(record_index, true)
		if p.dead or p.drowning or p.hurt_state:
			_release_pole()
			return
		if pole_break_timer > 0:
			pole_break_timer -= 1
			if pole_break_timer == 0:
				pole_broken = true
				sprite.texture = SourceObjectArt.lz_breakable_pole_texture(1)
				_release_pole()
				return

		var target_y = p.pixel_y()
		if p.input_up:
			target_y -= 1
		if p.input_down:
			target_y += 1
		target_y = clampi(target_y, spawn_y - 24, spawn_y + 12)
		p.force_set_pixel_position(spawn_x + 20, target_y)
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		if p.jump_pressed:
			_release_pole()
		return

	manager.set_lz_wind_blocker(record_index, false)
	if p.dead or p.drowning or p.hurt_state or p.debug_free_mode:
		pole_touch_latched = false
		return
	# React_LZPole increments obColProp when the 8x64 hitbox is touched. That
	# flag persists while the tunnel carries Sonic to the source +20px grab
	# threshold; it is not recomputed as a one-frame proximity test.
	if absi(p.pixel_x() - spawn_x) <= p.width_radius + 4 and absi(p.pixel_y() - spawn_y) <= p.height_radius + 32:
		pole_touch_latched = true
	if not pole_touch_latched or p.pixel_x() <= spawn_x + 20:
		return

	pole_touch_latched = false
	pole_grabbed = true
	manager.set_lz_wind_blocker(record_index, true)
	p.clear_object_support()
	p.vel_x = 0
	p.vel_y = 0
	p.inertia = 0
	p.facing_left = false
	p.in_air = true
	p.rolling = false
	p.jumping = false
	p.hang_on_pole = true
	p.object_control_override = true
	p.force_set_pixel_position(spawn_x + 20, p.pixel_y())

func _release_pole() -> void:
	var p = player()
	pole_grabbed = false
	# Pole_Action advances permanently to Pole_Display on any release. An intact
	# voluntarily-released pole remains visible but can never be grabbed again.
	pole_inert = true
	manager.set_lz_wind_blocker(record_index, false)
	if p != null:
		p.hang_on_pole = false
		p.object_control_override = false

# -----------------------------------------------------------------------------
# Object $0C - timed flapping door before a wind tunnel
# -----------------------------------------------------------------------------
func _init_flap_door() -> void:
	active_width = 40
	z_index = 40
	flap_period = (subtype & 0xFF) * 60
	flap_wait = 0
	flap_frame = 0
	flap_opening = false
	flap_anim_timer = 0
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.lz_flapping_door_texture(flap_frame)

func _tick_flap_door() -> void:
	var p = player()
	if p == null:
		return

	# Flap_OpenClose decrements an initially-zero wait timer, toggles obAnim,
	# then AnimateSprite takes four ticks per mapping frame (delay byte = 3).
	flap_wait -= 1
	if flap_wait < 0:
		flap_wait = flap_period
		flap_opening = not flap_opening

	var wanted = 2 if flap_opening else 0
	if flap_frame != wanted:
		flap_anim_timer -= 1
		if flap_anim_timer < 0:
			flap_anim_timer = 3
			flap_frame += 1 if wanted > flap_frame else -1
			sprite.texture = SourceObjectArt.lz_flapping_door_texture(flap_frame)
	else:
		flap_anim_timer = 3

	# Source only blocks the wind tunnel / becomes solid while fully closed and
	# Sonic is still on the left side of the door.
	var blocks_tunnel = flap_frame == 0 and p.pixel_x() < spawn_x
	manager.set_lz_wind_blocker(record_index, blocks_tunnel)
	if blocks_tunnel:
		p.resolve_solid_box_contact(int(position.x), int(position.y), 8, 32, true, record_index)

# -----------------------------------------------------------------------------
# Object $63 - LZ conveyor system
# -----------------------------------------------------------------------------
func _init_conveyor_record() -> void:
	if (subtype & 0x80) != 0:
		conveyor_spawner = true
		conveyor_group = subtype & 0x7F
		visible = false
		manager.spawn_lz_conveyor_group(conveyor_group)
		return

	active_width = 16
	z_index = 40
	sprite = make_sprite("")
	if subtype == 0x7F:
		conveyor_wheel = true
		z_index = 90
		conveyor_frame = 0
		sprite.texture = SourceObjectArt.lz_conveyor_texture(0, false)
	else:
		# Normal objpos data does not contain standalone moving platforms; they are
		# created by the high-bit group spawners from objpos/platforms/*.bin.
		request_delete(false)

func setup_conveyor_platform(owner: SonicObjectManager, world_x: int, world_y: int, platform_subtype: int, group_id: int, child_index: int) -> void:
	manager = owner
	object_id = 0x63
	subtype = platform_subtype & 0xFF
	spawn_x = world_x
	spawn_y = world_y
	position = Vector2(world_x, world_y)
	alive = true
	conveyor_platform = true
	conveyor_group = group_id
	conveyor_support_id = -10000 - group_id * 100 - child_index
	record_index = conveyor_support_id
	active_width = 16
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.lz_conveyor_texture(4, true)
	conveyor_targets = _targets_for_group(group_id)
	if conveyor_targets.is_empty():
		request_delete(false)
		return
	conveyor_target_index = clampi(subtype & 0x0F, 0, conveyor_targets.size() - 1)
	conveyor_increment = 1
	if manager.lz_conveyor_reversed:
		conveyor_reversed = true
		conveyor_increment = -1
		conveyor_target_index = _wrapped_target_index(conveyor_target_index + conveyor_increment)
	_set_conveyor_velocity()

func _tick_conveyor_wheel() -> void:
	if (manager.elapsed_frames & 3) != 0:
		return
	var delta = -1 if manager.lz_conveyor_reversed else 1
	conveyor_frame = posmod(conveyor_frame + delta, 4)
	sprite.texture = SourceObjectArt.lz_conveyor_texture(conveyor_frame, false)

func _tick_conveyor_platform() -> void:
	var p = player()
	if p == null or conveyor_targets.is_empty():
		return

	if manager.is_switch_pressed(0x0E) and not conveyor_reversed:
		conveyor_reversed = true
		manager.lz_conveyor_reversed = true
		conveyor_increment = -conveyor_increment
		conveyor_target_index = _wrapped_target_index(conveyor_target_index + conveyor_increment)
		_set_conveyor_velocity()

	var target = conveyor_targets[conveyor_target_index]
	if int(round(position.x)) == target.x and int(round(position.y)) == target.y:
		position = Vector2(target.x, target.y)
		conveyor_target_index = _wrapped_target_index(conveyor_target_index + conveyor_increment)
		_set_conveyor_velocity()
		target = conveyor_targets[conveyor_target_index]

	var old = position
	position += conveyor_velocity
	# The 68000 initializes division remainders so both axes land exactly on a
	# corner. Snap only within one source major-axis step to reproduce that exact
	# endpoint in the native floating-point representation.
	if absf(position.x - target.x) <= 1.01 and absf(position.y - target.y) <= 1.01:
		position = Vector2(target.x, target.y)

	var dx = position.x - old.x
	var dy = position.y - old.y
	var left = int(round(position.x)) - 16
	var right = int(round(position.x)) + 16
	var top = int(round(position.y)) - 8
	p.move_with_supported_object_fractional(conveyor_support_id, dx, dy, left, right, top)
	p.resolve_platform_top(left, right, top, conveyor_support_id)

func _wrapped_target_index(index: int) -> int:
	if conveyor_targets.is_empty():
		return 0
	return posmod(index, conveyor_targets.size())

func _set_conveyor_velocity() -> void:
	var target = conveyor_targets[conveyor_target_index]
	var dx = float(target.x) - position.x
	var dy = float(target.y) - position.y
	var ax = absf(dx)
	var ay = absf(dy)
	if ax < 0.001 and ay < 0.001:
		conveyor_velocity = Vector2.ZERO
		return
	# LCon_ChangeDir keeps the larger axis at exactly 1 px/frame and computes the
	# smaller component by signed distance ratio.
	if ax >= ay:
		conveyor_velocity.x = 1.0 if dx > 0.0 else -1.0
		conveyor_velocity.y = 0.0 if ax == 0.0 else dy / ax
	else:
		conveyor_velocity.y = 1.0 if dy > 0.0 else -1.0
		conveyor_velocity.x = 0.0 if ay == 0.0 else dx / ay

func _targets_for_group(group_id: int) -> Array[Vector2i]:
	match group_id:
		0:
			return [Vector2i(0x1078, 0x21A), Vector2i(0x10BE, 0x260), Vector2i(0x10BE, 0x393), Vector2i(0x108C, 0x3C5), Vector2i(0x1022, 0x390), Vector2i(0x1022, 0x244)]
		1:
			return [Vector2i(0x127E, 0x280), Vector2i(0x12CE, 0x2D0), Vector2i(0x12CE, 0x46E), Vector2i(0x1232, 0x420), Vector2i(0x1232, 0x2CC)]
		2:
			return [Vector2i(0xD22, 0x482), Vector2i(0xD22, 0x5DE), Vector2i(0xDAE, 0x5DE), Vector2i(0xDAE, 0x482)]
		3:
			return [Vector2i(0xD62, 0x3A2), Vector2i(0xDEE, 0x3A2), Vector2i(0xDEE, 0x4DE), Vector2i(0xD62, 0x4DE)]
		4:
			return [Vector2i(0xCAC, 0x242), Vector2i(0xDDE, 0x242), Vector2i(0xDDE, 0x3DE), Vector2i(0xC52, 0x3DE), Vector2i(0xC52, 0x29C)]
		5:
			return [Vector2i(0x1252, 0x20A), Vector2i(0x13DE, 0x20A), Vector2i(0x13DE, 0x2BE), Vector2i(0x1252, 0x2BE)]
	return []
