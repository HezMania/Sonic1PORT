class_name S2ARZBossObject
extends Node2D

# Retail Sonic 2 Object $89 - Aquatic Ruin boss.
# The source is one linked multi-sprite object plus two pillar objects and transient
# arrow objects. This translation preserves the source arena coordinates, 8-hit
# health, $C8 horizontal motion, hover phase, hammer cadence, pillar rise/drop,
# arrow lanes, $B3 defeat countdown and $2C00 post-boss camera release.

const STATE_DESCEND := 0
const STATE_TRAVERSE := 1
const STATE_WAIT_HAMMER := 2
const STATE_HAMMER := 3
const STATE_EXPLODING := 4
const STATE_ESCAPE_BOB := 5
const STATE_ESCAPE_RIGHT := 6

const START_X := 0x2AE0
const START_Y := 0x388
const ACTIVE_Y := 0x430
const LEFT_TARGET_X := 0x2AB0
const RIGHT_TARGET_X := 0x2B10
const LEFT_PILLAR_X := 0x2A50
const RIGHT_PILLAR_X := 0x2B70
const PILLAR_START_Y := 0x510
const PILLAR_ACTIVE_Y := 0x488
const CAMERA_ESCAPE_MAX := 0x2C00
const ARROW_STICK_SHAKE_FRAMES: Array[int] = [4,6,5,4,6,4,5,4,6,4,4,6,5,4,6,4,5,4,6,4]

var manager: SonicObjectManager
var alive := true
var state := STATE_DESCEND
var x_fixed := START_X << 16
var y_fixed := START_Y << 16
var vel_x := 0
var vel_y := 0x100
var hits := 8
var invincibility_timer := 0
var sine_count := 0
var timer := 0
var visual_tick := 0
var target_left := true
var facing_left := false
var defeated := false
var random_seed := 0x89A2C041
var pillar_left_y := PILLAR_START_Y
var pillar_right_y := PILLAR_START_Y
var pillar_drop_started := false
var pillar_shake_timer := 0
var pillar_shake_right := false
var hammer_drop_y_fixed := 0
var hammer_drop_vel := -0x380
var hammer_drop_active := false
var arrows: Array[Dictionary] = []
var eye_flashes: Array[Dictionary] = []

var vehicle_sprite: Sprite2D
var face_sprite: Sprite2D
var hammer_sprite: Sprite2D
var flame_sprite: Sprite2D
var left_pillar_sprite: Sprite2D
var right_pillar_sprite: Sprite2D
var last_face_frame := -1
var last_hammer_frame := -1
var last_flame_frame := -1

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(START_X, START_Y)
	vehicle_sprite = _make_sprite(0)
	face_sprite = _make_sprite(2)
	hammer_sprite = _make_sprite(3)
	flame_sprite = _make_sprite(-1)
	left_pillar_sprite = _make_sprite(1)
	right_pillar_sprite = _make_sprite(1)
	vehicle_sprite.texture = load("res://assets/objects/s2_arz/boss/main/08.png")
	left_pillar_sprite.texture = load("res://assets/objects/s2_arz/boss/pillar_arrow/00.png")
	right_pillar_sprite.texture = load("res://assets/objects/s2_arz/boss/pillar_arrow/00.png")
	right_pillar_sprite.flip_h = true
	_set_face_frame(0)
	_set_hammer_frame(9)
	_set_flame_frame(6)
	_update_visuals()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	# Retail boss_sine_count advances independently of positional movement.
	# Keep it running while the boss is parked at a pillar waiting for phase $C0.
	sine_count = (sine_count + 2) & 0xFF
	if invincibility_timer > 0:
		invincibility_timer -= 1

	_raise_or_lower_pillars()
	_tick_arrows()
	_tick_eye_flashes()
	match state:
		STATE_DESCEND:
			_tick_descend()
		STATE_TRAVERSE:
			_tick_traverse()
		STATE_WAIT_HAMMER:
			_tick_wait_hammer()
		STATE_HAMMER:
			_tick_hammer()
		STATE_EXPLODING:
			_tick_exploding()
		STATE_ESCAPE_BOB:
			_tick_escape_bob()
		STATE_ESCAPE_RIGHT:
			_tick_escape_right()

	position = Vector2(x_fixed >> 16, _display_y())
	_update_visuals()
	_apply_pillar_collision()
	if state < STATE_EXPLODING:
		_check_boss_collision()
	if state == STATE_HAMMER and timer <= 0x14 and timer >= 0x0C:
		_check_hammer_collision()

func _tick_descend() -> void:
	_move_base()
	if (y_fixed >> 16) < ACTIVE_Y:
		return
	y_fixed = ACTIVE_Y << 16
	vel_y = 0
	vel_x = -0xC8
	target_left = true
	# Retail Obj89 starts by travelling left with render_flags bit 0 clear.
	# In this port facing_left=true flips the art, so the source orientation is false.
	facing_left = false
	state = STATE_TRAVERSE

func _tick_traverse() -> void:
	_move_base()
	var px: int = x_fixed >> 16
	if target_left:
		if px > LEFT_TARGET_X:
			return
		x_fixed = LEFT_TARGET_X << 16
	else:
		if px < RIGHT_TARGET_X:
			return
		x_fixed = RIGHT_TARGET_X << 16
	vel_x = 0
	state = STATE_WAIT_HAMMER

func _tick_wait_hammer() -> void:
	# Source waits for boss_sine_count == $C0 (-$40) before starting the swing.
	if sine_count != 0xC0:
		return
	timer = 0x1E
	state = STATE_HAMMER
	SonicAudio.play_sfx(SonicAudio.SFX_CHAIN_STOMP)

func _tick_hammer() -> void:
	if timer == 0x14:
		_start_pillar_shake_and_arrow()
	timer -= 1
	if timer >= 0:
		return
	target_left = not target_left
	# Obj89 bchg #0,render_flags after each hammer swing: facing is opposite
	# the next target side, not equal to the travel target.
	facing_left = not target_left
	vel_x = -0xC8 if target_left else 0xC8
	state = STATE_TRAVERSE

func _tick_exploding() -> void:
	if (visual_tick & 7) == 0:
		var off: Vector2i = _random_explosion_offset()
		manager.spawn_boss_explosion((x_fixed >> 16) + off.x, _display_y() + off.y)
	timer -= 1
	if timer == 0x78:
		hammer_drop_active = true
		hammer_drop_y_fixed = y_fixed
	if hammer_drop_active:
		hammer_drop_y_fixed += hammer_drop_vel << 8
		hammer_drop_vel = GenesisMath.s16(hammer_drop_vel + 0x38)
		if (hammer_drop_y_fixed >> 16) >= 0x540:
			hammer_drop_active = false
	if timer >= 0:
		return
	timer = -0x12
	vel_x = 0
	vel_y = 0
	facing_left = false
	state = STATE_ESCAPE_BOB

func _tick_escape_bob() -> void:
	# Obj89 SubA: 18-frame downward acceleration, then a short upward recovery.
	timer += 1
	if timer < 0:
		vel_y = GenesisMath.s16(vel_y + 0x18)
	elif timer == 0:
		vel_y = 0
	elif timer < 0x18:
		vel_y = GenesisMath.s16(vel_y - 8)
	elif timer == 0x18:
		vel_y = 0
		manager.set_boss_defeated()
		SonicAudio.play_music(SonicAudio.MUS_S2_ARZ, true)
	elif timer >= 0x20:
		vel_x = 0x400
		vel_y = -0x40
		state = STATE_ESCAPE_RIGHT
	_move_base()

func _tick_escape_right() -> void:
	_move_base()
	manager.unlock_s2_arz_boss_right_boundary()
	var view_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= CAMERA_ESCAPE_MAX and (x_fixed >> 16) > manager.current_screen_x + view_width + 96:
		alive = false

func _move_base() -> void:
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8

func _display_y() -> int:
	if state >= STATE_EXPLODING:
		return y_fixed >> 16
	var phase: float = float(sine_count) * TAU / 256.0
	return (y_fixed >> 16) + int(round(sin(phase) * 4.0))

func _raise_or_lower_pillars() -> void:
	if defeated:
		pillar_drop_started = true
	if pillar_drop_started:
		pillar_left_y = mini(PILLAR_START_Y, pillar_left_y + 1)
		pillar_right_y = mini(PILLAR_START_Y, pillar_right_y + 1)
		return
	if pillar_left_y > PILLAR_ACTIVE_Y:
		pillar_left_y -= 1
	if pillar_right_y > PILLAR_ACTIVE_Y:
		pillar_right_y -= 1

func _apply_pillar_collision() -> void:
	if manager.player == null or pillar_left_y >= PILLAR_START_Y:
		return
	# Source Obj89_Pillar_SolidObject: d1=$23,d2=$44,d3=$45 at y+4.
	manager.player.resolve_solid_box(LEFT_PILLAR_X, pillar_left_y + 4, 0x23, 0x44, true, -0x8901)
	manager.player.resolve_solid_box(RIGHT_PILLAR_X, pillar_right_y + 4, 0x23, 0x44, true, -0x8902)

func _start_pillar_shake_and_arrow() -> void:
	pillar_shake_timer = 0x1F
	pillar_shake_right = not target_left
	_spawn_arrow(pillar_shake_right)

func _spawn_arrow(from_right: bool) -> void:
	var lane_table: Array[int] = [0x458, 0x478, 0x498, 0x4B8]
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var lane: int = lane_table[random_seed & 3]
	var launch_x: int = RIGHT_PILLAR_X - 0x1A if from_right else LEFT_PILLAR_X + 0x1A
	# Obj89_Pillar_Shoot creates the temporary bulging-eye mapping at the same
	# source launch point for $28 frames, then creates the arrow 9 pixels lower.
	var eye_sprite: Sprite2D = _make_sprite(2)
	eye_sprite.texture = load("res://assets/objects/s2_arz/boss/pillar_arrow/02.png")
	eye_sprite.flip_h = from_right
	eye_flashes.append({"x": launch_x, "y": lane, "timer": 0x28, "sprite": eye_sprite})
	var sprite: Sprite2D = _make_sprite(2)
	sprite.texture = load("res://assets/objects/s2_arz/boss/pillar_arrow/04.png")
	sprite.flip_h = from_right
	# Keep a stable support id. Array indices change as old arrows are removed, but
	# Sonic's standing/support relationship must continue to identify the same arrow.
	var support_id: int = -0x8A00 - visual_tick - arrows.size()
	arrows.append({
		"x": launch_x,
		"y": lane + 9,
		"vx": -3 if from_right else 3,
		"state": 0, # 0 flying, 1 stuck/platform, 2 falling
		"timer": 0,
		"sprite": sprite,
		"frame_tick": 0,
		"support_id": support_id,
	})


func _tick_eye_flashes() -> void:
	for i in range(eye_flashes.size() - 1, -1, -1):
		var e: Dictionary = eye_flashes[i]
		var sprite: Sprite2D = e["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			eye_flashes.remove_at(i)
			continue
		e["timer"] = int(e["timer"]) - 1
		if int(e["timer"]) <= 0 or defeated:
			sprite.queue_free()
			eye_flashes.remove_at(i)
			continue
		sprite.position = Vector2(int(e["x"]) - (x_fixed >> 16), int(e["y"]) - _display_y())
		eye_flashes[i] = e

func _tick_arrows() -> void:
	for i in range(arrows.size() - 1, -1, -1):
		var a: Dictionary = arrows[i]
		var sprite: Sprite2D = a["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			arrows.remove_at(i)
			continue
		if defeated and int(a["state"]) < 2:
			a["state"] = 2
			a["timer"] = 0
		match int(a["state"]):
			0:
				a["x"] = int(a["x"]) + int(a["vx"])
				_check_arrow_hazard(a)
				if int(a["vx"]) < 0 and int(a["x"]) <= 0x2A77:
					a["x"] = 0x2A77
					a["state"] = 1
				elif int(a["vx"]) > 0 and int(a["x"]) >= 0x2B49:
					a["x"] = 0x2B49
					a["state"] = 1
			1:
				# Ani_obj89_a animation 0 is finite: 20 source frames at duration 1,
				# then $FD,1 switches to the settled animation (frame 4). The old
				# modulo-3 approximation shook forever until the arrow dropped.
				a["frame_tick"] = int(a["frame_tick"]) + 1
				var shake_index: int = int(a["frame_tick"]) >> 1
				var f: int = ARROW_STICK_SHAKE_FRAMES[shake_index] if shake_index < ARROW_STICK_SHAKE_FRAMES.size() else 4
				sprite.texture = load("res://assets/objects/s2_arz/boss/pillar_arrow/%02d.png" % f)
				if manager.player != null:
					var support_id: int = int(a["support_id"])
					var was_supported: bool = manager.player.standing_on_object and manager.player.support_record_index == support_id
					manager.player.resolve_platform_top(int(a["x"]) - 0x1B, int(a["x"]) + 0x1C, int(a["y"]), support_id)
					if manager.player.standing_on_object and manager.player.support_record_index == support_id:
						if not was_supported and int(a["timer"]) <= 0:
							a["timer"] = 0x1F
				if int(a["timer"]) > 0:
					a["timer"] = int(a["timer"]) - 1
					if int(a["timer"]) <= 0:
						a["state"] = 2
			2:
				a["y"] = int(a["y"]) + 4
				if int(a["y"]) > 0x4F0:
					sprite.queue_free()
					arrows.remove_at(i)
					continue
		sprite.position = Vector2(int(a["x"]) - (x_fixed >> 16), int(a["y"]) - _display_y())
		arrows[i] = a

func _check_arrow_hazard(a: Dictionary) -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	if absi(p.pixel_x() - int(a["x"])) <= 0x10 + p.width_radius and absi(p.pixel_y() - int(a["y"])) <= 6 + p.height_radius:
		p.apply_hazard_hit(int(a["x"]))

func _check_hammer_collision() -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var hx: int = (x_fixed >> 16) + (-0x18 if facing_left else 0x18)
	var hy: int = _display_y() + 0x18
	if absi(p.pixel_x() - hx) <= 0x18 + p.width_radius and absi(p.pixel_y() - hy) <= 0x20 + p.height_radius:
		p.apply_hazard_hit(hx)

func _check_boss_collision() -> void:
	if invincibility_timer > 0:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = x_fixed >> 16
	var by: int = _display_y()
	if absi(p.pixel_x() - bx) > 0x22 + p.width_radius or absi(p.pixel_y() - by) > 0x18 + p.height_radius:
		return
	if p.can_attack_object():
		p.vel_x = GenesisMath.s16(-int(p.vel_x / 2))
		p.vel_y = GenesisMath.s16(-int(p.vel_y / 2))
		hits -= 1
		invincibility_timer = 0x40
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			_begin_defeat()
		return
	p.apply_hazard_hit(bx)

func _begin_defeat() -> void:
	if defeated:
		return
	defeated = true
	pillar_drop_started = true
	manager.add_score(1000)
	timer = 0xB3
	vel_x = 0
	vel_y = 0
	state = STATE_EXPLODING
	_set_face_frame(5)

func _update_visuals() -> void:
	var bx: int = x_fixed >> 16
	var by: int = _display_y()
	var shake_x_left := 0
	var shake_y_left := 0
	var shake_x_right := 0
	var shake_y_right := 0
	if pillar_shake_timer > 0:
		pillar_shake_timer -= 1
		var off: int = 1 if (visual_tick & 1) == 0 else -1
		if pillar_shake_right:
			shake_x_right = off
			shake_y_right = off
		else:
			shake_x_left = off
			shake_y_left = off
	left_pillar_sprite.visible = pillar_left_y < PILLAR_START_Y
	right_pillar_sprite.visible = pillar_right_y < PILLAR_START_Y
	left_pillar_sprite.position = Vector2(LEFT_PILLAR_X - bx + shake_x_left, pillar_left_y - by + shake_y_left)
	right_pillar_sprite.position = Vector2(RIGHT_PILLAR_X - bx + shake_x_right, pillar_right_y - by + shake_y_right)

	vehicle_sprite.flip_h = facing_left
	face_sprite.flip_h = facing_left
	hammer_sprite.flip_h = facing_left
	flame_sprite.flip_h = facing_left
	var face_frame: int = (visual_tick >> 3) & 1
	if defeated:
		face_frame = 5
	elif invincibility_timer > 0:
		face_frame = 5
	elif manager.player != null and (manager.player.hurt_state or manager.player.dead):
		face_frame = 2 + ((visual_tick >> 3) & 1)
	_set_face_frame(face_frame)
	_set_flame_frame(6 + ((visual_tick >> 2) & 1))
	if hammer_drop_active:
		hammer_sprite.visible = true
		hammer_sprite.position = Vector2(-1, (hammer_drop_y_fixed >> 16) - by)
		_set_hammer_frame(9)
	elif defeated and state >= STATE_ESCAPE_BOB:
		hammer_sprite.visible = false
	else:
		hammer_sprite.visible = true
		hammer_sprite.position = Vector2.ZERO
		if state == STATE_HAMMER:
			var swing_frame: int = 10 if timer > 0x14 else 11
			_set_hammer_frame(swing_frame)
		else:
			_set_hammer_frame(9)

func _make_sprite(order: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = order
	add_child(sprite)
	return sprite

func _set_face_frame(frame: int) -> void:
	frame = clampi(frame, 0, 5)
	if frame == last_face_frame:
		return
	last_face_frame = frame
	face_sprite.texture = load("res://assets/objects/s2_arz/boss/main/%02d.png" % frame)

func _set_hammer_frame(frame: int) -> void:
	frame = clampi(frame, 9, 11)
	if frame == last_hammer_frame:
		return
	last_hammer_frame = frame
	hammer_sprite.texture = load("res://assets/objects/s2_arz/boss/main/%02d.png" % frame)

func _set_flame_frame(frame: int) -> void:
	frame = clampi(frame, 6, 7)
	if frame == last_flame_frame:
		return
	last_flame_frame = frame
	flame_sprite.texture = load("res://assets/objects/s2_arz/boss/main/%02d.png" % frame)

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	return Vector2i((random_seed & 0x3F) - 32, ((random_seed >> 8) & 0x3F) - 24)
