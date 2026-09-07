class_name S2EHZBossObject
extends Node2D

# Retail Sonic 2 Object $56 - Emerald Hill boss.
# Phase 89 keeps the source state/timer values and separates the visible pieces
# (Eggpod top/bottom, ground vehicle, three wheels, spike and chopper blades)
# while using the native Godot collision/terrain query path.

const STATE_APPROACH_DIAGONAL := 0
const STATE_APPROACH_VERTICAL := 1
const STATE_APPROACH_WAIT := 2
const STATE_ACTIVE := 3
const STATE_DEFEAT_FALL := 4
const STATE_DEFEAT_PAUSE := 5
const STATE_ESCAPE_PREP := 6
const STATE_ESCAPE_WAIT := 7
const STATE_ESCAPE_RISE := 8
const STATE_ESCAPE_RIGHT := 9

const LEFT_TURN_X := 0x28A0
const RIGHT_TURN_X := 0x2B08
const JOIN_X := 0x29D0
const JOIN_Y := 0x41E
const START_X := 0x2AF0
const START_Y := 0x2F8
const CAMERA_ESCAPE_MAX := 0x2AB0

var manager: SonicObjectManager
var alive := true
var state := STATE_APPROACH_DIAGONAL
var timer := 0
var x_fixed := START_X << 16
var y_fixed := START_Y << 16
var vel_x := 0
var vel_y := 0
var facing_right := false
var hits := 8
var invincibility_timer := 0
var defeated := false
var explosion_timer := 0
var visual_tick := 0
var random_seed := 0x56E12A09
var ground_joined := false
var spike_detached := false
var spike_world_x := 0
var spike_world_y := 0
var spike_detach_right := false
var ground_separated := false
var wreck_facing_right := false
var ground_world_x := 0
var ground_world_y := 0
var wheels_detached := false
var wheel_world_x: Array[int] = [0, 0, 0]
var wheel_world_y: Array[int] = [0, 0, 0]
var wheel_vel_x: Array[int] = [0, 0, 0]
var wheel_vel_y: Array[int] = [0, 0, 0]
var wheel_release_delay: Array[int] = [0, 0, 0]
var propeller_ground_timer := -1
var propeller_reloaded := false
var propeller_reload_timer := 0
var last_main_frame := -1
var last_top_frame := -1
var last_ground_frame := -1
var last_propeller_frame := -1
var last_spike_frame := -1
var last_wheel_frames: Array[int] = [-1, -1, -1]

var bottom_sprite: Sprite2D
var top_sprite: Sprite2D
var ground_sprite: Sprite2D
var propeller_sprite: Sprite2D
var spike_sprite: Sprite2D
var wheel_sprites: Array[Sprite2D] = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(START_X, START_Y)
	bottom_sprite = _make_sprite(3)
	top_sprite = _make_sprite(4)
	# Source priority: the ground motor vehicle is in front of the Eggpod/Robotnik
	# composite when they overlap during the join and wreck sequence.
	ground_sprite = _make_sprite(6)
	propeller_sprite = _make_sprite(1)
	spike_sprite = _make_sprite(7)
	for i in range(3):
		wheel_sprites.append(_make_sprite(5 if i < 2 else 4))
	_set_main_frame(0)
	_set_top_frame(1)
	_set_ground_frame(0)
	_set_propeller_frame(5)
	_set_spike_frame(1)
	_update_component_visibility()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	if invincibility_timer > 0:
		invincibility_timer -= 1

	match state:
		STATE_APPROACH_DIAGONAL:
			_tick_approach_diagonal()
		STATE_APPROACH_VERTICAL:
			_tick_approach_vertical()
		STATE_APPROACH_WAIT:
			_tick_approach_wait()
		STATE_ACTIVE:
			_tick_active()
		STATE_DEFEAT_FALL:
			_tick_defeat_fall()
		STATE_DEFEAT_PAUSE:
			_tick_defeat_pause()
		STATE_ESCAPE_PREP:
			_tick_escape_prep()
		STATE_ESCAPE_WAIT:
			_tick_escape_wait()
		STATE_ESCAPE_RISE:
			_tick_escape_rise()
		STATE_ESCAPE_RIGHT:
			_tick_escape_right()

	position = Vector2(x_fixed >> 16, y_fixed >> 16)
	_tick_detached_parts()
	_update_components()
	if (state == STATE_ACTIVE and not defeated) or spike_detached:
		_check_spike_collision()
	if state == STATE_ACTIVE and not defeated:
		_check_boss_collision()

func _tick_approach_diagonal() -> void:
	# Obj56_VehicleMain_Sub0: collision disabled, one pixel left/down per frame.
	if (x_fixed >> 16) > JOIN_X:
		x_fixed -= 1 << 16
		y_fixed += 1 << 16
		return
	x_fixed = JOIN_X << 16
	state = STATE_APPROACH_VERTICAL

func _tick_approach_vertical() -> void:
	# Obj56_VehicleMain_Sub2_0: finish the six-pixel vertical join.
	if (y_fixed >> 16) < JOIN_Y:
		y_fixed += 1 << 16
		return
	y_fixed = JOIN_Y << 16
	ground_joined = true
	propeller_ground_timer = 0x18
	timer = 0x3C
	state = STATE_APPROACH_WAIT

func _tick_approach_wait() -> void:
	timer -= 1
	if timer >= 0:
		return
	vel_x = -0x200
	state = STATE_ACTIVE

func _tick_active() -> void:
	_handle_active_direction()
	x_fixed += vel_x << 8
	# The original main body's Y is the mean Y of its two foreground wheels - $14.
	# Query the same visible axle positions against native collision so the car
	# follows EHZ2's authored boss-floor slope rather than hovering at a fixed Y.
	var px = x_fixed >> 16
	var floor_a = _floor_surface_y(px + 0x1C, (y_fixed >> 16) + 0x30)
	var floor_b = _floor_surface_y(px - 0x0C, (y_fixed >> 16) + 0x30)
	if floor_a >= 0 and floor_b >= 0:
		y_fixed = (int((floor_a + floor_b) / 2) - 0x24) << 16
	_maybe_detach_spike_on_last_hit()

func _handle_active_direction() -> void:
	var px = x_fixed >> 16
	if px <= LEFT_TURN_X or px >= RIGHT_TURN_X:
		facing_right = not facing_right
		vel_x = -vel_x

func _tick_defeat_fall() -> void:
	if (visual_tick & 7) == 0:
		var off = _random_explosion_offset()
		manager.spawn_boss_explosion((x_fixed >> 16) + off.x, (y_fixed >> 16) + off.y)
	explosion_timer -= 1
	vel_y = GenesisMath.s16(vel_y + 0x38)
	y_fixed += vel_y << 8
	var floor_y = _floor_surface_y(x_fixed >> 16, (y_fixed >> 16) + 0x28)
	if floor_y >= 0 and (y_fixed >> 16) + 0x24 >= floor_y:
		y_fixed = (floor_y - 0x24) << 16
		vel_y = 0
	if explosion_timer >= 0:
		return
	vel_x = 0
	timer = 0x0C
	state = STATE_DEFEAT_PAUSE

func _tick_defeat_pause() -> void:
	timer -= 1
	if timer >= 0:
		return
	propeller_reloaded = true
	propeller_reload_timer = 0x10
	timer = 0x32
	# Obj56 sets Boss_defeated_flag and restarts level music as soon as the
	# post-defeat propeller is created, before Eggman actually flies away.
	manager.set_boss_defeated()
	SonicAudio.play_music(SonicAudio.MUS_S2_EHZ, true)
	state = STATE_ESCAPE_PREP

func _tick_escape_prep() -> void:
	# Reloaded propeller rises for $10 frames before entering its normal loop.
	if propeller_reload_timer >= 0:
		propeller_reload_timer -= 1
	timer -= 1
	if timer >= 0:
		return
	_separate_ground_vehicle()
	timer = 0x60
	state = STATE_ESCAPE_RISE

func _tick_escape_wait() -> void:
	# Retained for readable source-state correspondence; current translation
	# transitions directly from prep to the $60-frame rise.
	state = STATE_ESCAPE_RISE

func _tick_escape_rise() -> void:
	timer -= 1
	y_fixed -= 1 << 16
	# Obj56_FlyingOff expands Camera_Max_X_pos during both the $60-frame rise
	# and the subsequent horizontal escape.
	manager.unlock_s2_ehz_boss_right_boundary()
	if timer >= 0:
		return
	facing_right = true
	state = STATE_ESCAPE_RIGHT

func _tick_escape_right() -> void:
	x_fixed += 6 << 16
	manager.unlock_s2_ehz_boss_right_boundary()
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= CAMERA_ESCAPE_MAX and (x_fixed >> 16) > manager.current_screen_x + view_width + 96:
		alive = false

func _check_boss_collision() -> void:
	if invincibility_timer > 0:
		return
	var p = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx = x_fixed >> 16
	var by = y_fixed >> 16
	if absi(p.pixel_x() - bx) > 0x20 + p.width_radius:
		return
	if absi(p.pixel_y() - by) > 0x18 + p.height_radius:
		return
	if p.can_attack_object():
		p.vel_x = GenesisMath.s16(-int(p.vel_x / 2))
		p.vel_y = GenesisMath.s16(-int(p.vel_y / 2))
		hits -= 1
		invincibility_timer = 0x20
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			_begin_defeat()
		return
	p.apply_hazard_hit(bx)

func _check_spike_collision() -> void:
	var p = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var spike_pos = _spike_world_position()
	if absi(p.pixel_x() - spike_pos.x) > 0x12 + p.width_radius or absi(p.pixel_y() - spike_pos.y) > 0x12 + p.height_radius:
		return
	p.apply_hazard_hit(spike_pos.x)

func _begin_defeat() -> void:
	if defeated:
		return
	defeated = true
	# The wreck keeps the facing it had at the moment of defeat. Eggman later
	# turns right to escape, but the abandoned wheeled vehicle does not mirror.
	wreck_facing_right = facing_right
	if not spike_detached:
		_detach_spike()
	_detach_wheels(vel_x)
	manager.add_score(1000)
	vel_x = 0
	vel_y = -0x180
	explosion_timer = 0xB3
	state = STATE_DEFEAT_FALL
	_set_top_frame(6)

func _maybe_detach_spike_on_last_hit() -> void:
	# Obj56_Spike loc_2F8AA: when collision_property reaches 1, the spike
	# separates only if Sonic is on the side toward which the spike points.
	if spike_detached or hits != 1 or manager.player == null:
		return
	var spike_pos = _spike_world_position()
	var sonic_right_of_spike = manager.player.pixel_x() > spike_pos.x
	if (sonic_right_of_spike and facing_right) or ((not sonic_right_of_spike) and (not facing_right)):
		_detach_spike()

func _detach_spike() -> void:
	var attached = _spike_world_position()
	spike_world_x = attached.x
	spike_world_y = attached.y
	spike_detach_right = facing_right
	spike_detached = true

func _detach_wheels(source_vel_x: int) -> void:
	if wheels_detached:
		return
	wheels_detached = true
	var sign = -1 if facing_right else 1
	var offsets: Array[int] = [0x1C * sign, -0x0C * sign, -0x2C * sign]
	for i in range(3):
		var wx = (x_fixed >> 16) + offsets[i]
		var floor_y = _floor_surface_y(wx, (y_fixed >> 16) + 0x40)
		wheel_world_x[i] = wx
		wheel_world_y[i] = (floor_y - 0x10) if floor_y >= 0 else (y_fixed >> 16) + 0x14
		wheel_vel_x[i] = -source_vel_x if i == 2 else source_vel_x
		wheel_vel_y[i] = -0x300
		wheel_release_delay[i] = 0x15

func _separate_ground_vehicle() -> void:
	if ground_separated:
		return
	ground_separated = true
	ground_world_x = x_fixed >> 16
	ground_world_y = (y_fixed >> 16) + 8

func _tick_detached_parts() -> void:
	if spike_detached:
		spike_world_x += 3 if spike_detach_right else -3
	if not wheels_detached:
		return
	for i in range(3):
		if wheel_release_delay[i] > 0:
			wheel_release_delay[i] -= 1
			continue
		wheel_world_x[i] += int(wheel_vel_x[i] / 0x100)
		wheel_world_y[i] += int(wheel_vel_y[i] / 0x100)
		wheel_vel_y[i] = GenesisMath.s16(wheel_vel_y[i] + 0x38)
		var floor_y = _floor_surface_y(wheel_world_x[i], wheel_world_y[i] + 0x10)
		if floor_y >= 0 and wheel_world_y[i] + 0x10 >= floor_y and wheel_vel_y[i] >= 0:
			wheel_world_y[i] = floor_y - 0x10
			wheel_vel_y[i] = -0x200

func _floor_surface_y(world_x: int, probe_y: int) -> int:
	if manager.collision == null:
		return -1
	var hit = manager.collision.find_floor(world_x, probe_y, 13, 16, 0, false)
	return probe_y + int(hit.get("distance", 0))

func _update_components() -> void:
	_update_component_visibility()
	bottom_sprite.flip_h = facing_right
	top_sprite.flip_h = facing_right
	ground_sprite.flip_h = wreck_facing_right if defeated else facing_right
	propeller_sprite.flip_h = facing_right
	spike_sprite.flip_h = facing_right
	for wheel in wheel_sprites:
		wheel.flip_h = wreck_facing_right if wheels_detached else facing_right

	# Vehicle top: SAnim normal 1/2, hit 5, laughter 3/4, escape 6.
	var top_frame = 1 + ((visual_tick >> 3) & 1)
	if defeated or state >= STATE_DEFEAT_FALL:
		top_frame = 6
	elif invincibility_timer > 0:
		top_frame = 5
	elif manager.player != null and (manager.player.hurt_state or manager.player.dead):
		top_frame = 3 + ((visual_tick >> 3) & 1)
	_set_top_frame(top_frame)
	_set_main_frame(0)
	_set_ground_frame(0)

	# Ground vehicle exists from boss creation at world Y $426 while Eggman flies
	# diagonally down to meet it. Once active it follows the parent at y+$08.
	if ground_separated:
		ground_sprite.position = Vector2(ground_world_x - (x_fixed >> 16), ground_world_y - (y_fixed >> 16))
	elif not ground_joined:
		ground_sprite.position = Vector2(0, 0x426 - (y_fixed >> 16))
	else:
		ground_sprite.position = Vector2(0, 8)
	var sign = -1 if facing_right else 1
	var wheel_x_offsets: Array[int] = [0x1C * sign, -0x0C * sign, -0x2C * sign]
	for i in range(3):
		if wheels_detached:
			wheel_sprites[i].position = Vector2(wheel_world_x[i] - (x_fixed >> 16), wheel_world_y[i] - (y_fixed >> 16))
		else:
			var wheel_x = (x_fixed >> 16) + wheel_x_offsets[i]
			var floor_y = _floor_surface_y(wheel_x, 0x440)
			var wheel_y = (floor_y - 0x10) if floor_y >= 0 else 0x432
			wheel_sprites[i].position = Vector2(wheel_x_offsets[i], wheel_y - (y_fixed >> 16))
		var frame = (4 if i < 2 else 6) + ((visual_tick >> 1) & 1)
		_set_wheel_frame(i, frame)

	# Spike remains attached at +/-$36 until Obj56 sets separation bit 3. Once
	# detached it has its own world position/heading and no longer inherits boss motion.
	if spike_detached:
		spike_sprite.flip_h = spike_detach_right
		spike_sprite.position = Vector2(spike_world_x - (x_fixed >> 16), spike_world_y - (y_fixed >> 16))
	else:
		var spike_local_y = 0x10 if ground_joined else 0x42E - (y_fixed >> 16)
		spike_sprite.position = Vector2((0x36 if facing_right else -0x36), spike_local_y)
	_set_spike_frame(1 + (int(visual_tick / 6) % 3))

	# Chopper animation. Once Eggman touches the car it winds down; after defeat
	# it is re-created and rises from y+12 exactly like routine $C.
	if propeller_reloaded:
		var py = 12 - mini(16, 0x10 - maxi(-1, propeller_reload_timer))
		propeller_sprite.position = Vector2(0, py)
		_set_propeller_frame(5 + ((visual_tick >> 1) & 1))
	elif ground_joined:
		propeller_sprite.position = Vector2.ZERO
		if propeller_ground_timer > -0x10:
			propeller_ground_timer -= 1
			var seq: Array[int] = [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0]
			var idx = clampi(0x18 - maxi(0, propeller_ground_timer), 0, seq.size() - 1)
			_set_propeller_frame(seq[idx])
	else:
		propeller_sprite.position = Vector2.ZERO
		_set_propeller_frame(5 + ((visual_tick >> 1) & 1))

func _update_component_visibility() -> void:
	bottom_sprite.visible = true
	top_sprite.visible = true
	ground_sprite.visible = true
	for wheel in wheel_sprites:
		wheel.visible = true
	spike_sprite.visible = true
	propeller_sprite.visible = (not ground_joined) or propeller_ground_timer > -0x10 or propeller_reloaded

func _spike_world_position() -> Vector2i:
	if spike_detached:
		return Vector2i(spike_world_x, spike_world_y)
	var sy = (y_fixed >> 16) + 0x10 if ground_joined else 0x42E
	return Vector2i((x_fixed >> 16) + (0x36 if facing_right else -0x36), sy)

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	return Vector2i((random_seed & 0x3F) - 32, ((random_seed >> 8) & 0x3F) - 16)

func _make_sprite(order: int) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = order
	add_child(sprite)
	return sprite

func _set_main_frame(frame: int) -> void:
	if frame == last_main_frame:
		return
	last_main_frame = frame
	bottom_sprite.texture = load("res://assets/objects/s2_ehz/boss_vehicle_pal1/%02d.png" % frame)

func _set_top_frame(frame: int) -> void:
	if frame == last_top_frame:
		return
	last_top_frame = frame
	top_sprite.texture = load("res://assets/objects/s2_ehz/boss_vehicle_pal0/%02d.png" % frame)

func _set_ground_frame(frame: int) -> void:
	if frame == last_ground_frame:
		return
	last_ground_frame = frame
	ground_sprite.texture = load("res://assets/objects/s2_ehz/boss_ground_pal0/%02d.png" % frame)

func _set_propeller_frame(frame: int) -> void:
	if frame == last_propeller_frame:
		return
	last_propeller_frame = frame
	propeller_sprite.texture = load("res://assets/objects/s2_ehz/boss_propeller/%02d.png" % frame)

func _set_spike_frame(frame: int) -> void:
	if frame == last_spike_frame:
		return
	last_spike_frame = frame
	spike_sprite.texture = load("res://assets/objects/s2_ehz/boss_ground_pal1/%02d.png" % frame)

func _set_wheel_frame(index: int, frame: int) -> void:
	if index < 0 or index >= wheel_sprites.size() or last_wheel_frames[index] == frame:
		return
	last_wheel_frames[index] = frame
	wheel_sprites[index].texture = load("res://assets/objects/s2_ehz/boss_ground_pal1/%02d.png" % frame)
