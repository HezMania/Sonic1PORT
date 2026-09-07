class_name S2MCZBossObject
extends Node2D

# Retail Sonic 2 Object $57 - Mystic Cave boss.
# Translation targets LevEvents_MCZ2 / Obj57: the $5A prelude is handled by
# SonicCamera/main, while this node preserves the source 8-hit machine cycle,
# falling rock/stalactite field, drill collision modes, $B3 defeat breakup,
# hover recovery, and two-pixel-per-frame camera release toward $2240.

const STATE_ASCEND := 0
const STATE_DESCEND_ROCKS := 1
const STATE_DESCEND_FINISH := 2
const STATE_HORIZONTAL := 3
const STATE_DEFEATED := 4
const STATE_ESCAPE_BOB := 5
const STATE_ESCAPE_RIGHT := 6

const START_X := 0x21A0
const START_Y := 0x560
const TOP_Y := 0x560
const ROCK_STOP_Y := 0x620
const ATTACK_Y := 0x660
const LEFT_X := 0x2120
const RIGHT_X := 0x2200
const FALL_X_MIN := 0x20F0
const FALL_X_MAX := 0x2230
const FALL_START_Y := 0x5F0
const FALL_DELETE_Y := 0x6F0
const CAMERA_ESCAPE_MAX := 0x2240

# Exact mapping-frame sequences from Ani_obj57. Delay byte 1 means each source
# mapping frame is held for two object executions by AnimateBoss.
const DIGGER_ANIMS := {
	3: [2,2,2,2,2,3,3,3,3,3,4,4,4,4],
	4: [2,2,2,2,2,3,3,3,4,4,4,2,2,3,3],
	5: [4,2,3,4],
	6: [2,3,4,4,2,2,3,3,3,4,4,4,2,2,2],
	7: [2,3,3,3,3,4,4,4,4,4,2,8,8,8,8],
	8: [9,9,9,9,9,10,10,10,10,10,11,11,11,11],
	9: [9,9,9,9,9,10,10,10,11,11,11,9,9,10,10],
	10: [11,9,10,11],
	11: [9,10,11,11,9,9,10,10,10,11,11,11,9,9,9],
	12: [9,10,10,10,10,11,11,11,11,11,9,8,8,8,8],
}
const DIGGER_NEXT := {3:4,4:5,5:5,6:7,7:8,8:9,9:10,10:10,11:12,12:3}
const DIGGER_LOOP_INDEX := {5:1,10:1}

var manager: SonicObjectManager
var alive: bool = true
var state: int = STATE_DESCEND_ROCKS
var x_fixed: int = START_X << 16
var y_fixed: int = START_Y << 16
var vel_x: int = 0
var vel_y: int = 0xC0
var countdown: int = 0x28
var hits: int = 8
var invincibility_timer: int = 0
var visual_tick: int = 0
var sine_count: int = 0
var facing_right: bool = false # Source render_flags bit 0 / x flip.
var collision_mode: int = 0   # 0 vertical drills, 1 horizontal drill tip.
var digger_hurt_sonic: bool = false
var rumble_active: bool = true
var vehicle_light_on: bool = false
var hover_fire_on: bool = true
var face_grin_timer: int = 0
var random_seed: int = 0x57A11426

var digger_anim_id: int = 3
var digger_anim_index: int = 0
var digger_anim_timer: int = 1
var digger_frame: int = 2

var diggers_detached: bool = false
var digger_a_x_fixed: int = 0
var digger_a_y_fixed: int = 0
var digger_a_vy: int = -0x380
var digger_b_x_fixed: int = 0
var digger_b_y_fixed: int = 0
var digger_b_vy: int = -0x380

var falling_stuff: Array[Dictionary] = []

var hover_sprite: Sprite2D
var digger_a_sprite: Sprite2D
var vehicle_sprite: Sprite2D
var face_sprite: Sprite2D
var digger_b_sprite: Sprite2D

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(START_X, START_Y)
	hover_sprite = _make_sprite(0)
	# Retail Object $57's first digger subobject is linked before the vehicle/
	# Eggman pieces, while the offset second digger is linked after them. On the
	# Genesis, earlier same-priority sprite links win overlap. Preserve that
	# asymmetric drill priority instead of drawing both drills on opposite sides
	# of Eggman with the second drill always in front.
	digger_a_sprite = _make_sprite(4)
	vehicle_sprite = _make_sprite(2)
	face_sprite = _make_sprite(3)
	digger_b_sprite = _make_sprite(1)
	_set_part_texture(hover_sprite, 5)
	_set_part_texture(digger_a_sprite, 2)
	_set_part_texture(vehicle_sprite, 1)
	_set_part_texture(face_sprite, 14)
	_set_part_texture(digger_b_sprite, 2)
	_update_visuals()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	if invincibility_timer > 0:
		invincibility_timer -= 1
	if face_grin_timer > 0:
		face_grin_timer -= 1

	match state:
		STATE_ASCEND:
			_tick_ascend()
		STATE_DESCEND_ROCKS:
			_tick_descend_rocks()
		STATE_DESCEND_FINISH:
			_tick_descend_finish()
		STATE_HORIZONTAL:
			_tick_horizontal()
		STATE_DEFEATED:
			_tick_defeated()
		STATE_ESCAPE_BOB:
			_tick_escape_bob()
		STATE_ESCAPE_RIGHT:
			_tick_escape_right()

	if state < STATE_DEFEATED:
		_tick_digger_animation()
	_tick_falling_stuff()
	if diggers_detached:
		_tick_detached_diggers()
	if rumble_active and (visual_tick & 0x1F) == 0:
		SonicAudio.play_sfx(SonicAudio.SFX_RUMBLE)

	position = Vector2(x_fixed >> 16, _display_y())
	_update_visuals()
	if state < STATE_DEFEATED and invincibility_timer <= 0:
		var attacked: bool = _check_center_collision()
		if not attacked:
			_check_digger_collision()

func _tick_ascend() -> void:
	countdown -= 1
	if countdown == 0x28:
		collision_mode = 0
	if countdown < 0:
		vehicle_light_on = false
		_move_base()
		if (y_fixed >> 16) <= TOP_Y:
			y_fixed = TOP_Y << 16
			vel_y = 0x100
			var px: int = manager.player.pixel_x() if manager.player != null else 0x2190
			x_fixed = (RIGHT_X if px < 0x2190 else LEFT_X) << 16
			facing_right = px >= (x_fixed >> 16)
			state = STATE_DESCEND_ROCKS
	# Obj57_Main_Sub0 keeps Screen_Shaking_Flag set and still calls the falling
	# debris allocator while the animation/countdown pause is running.
	if (y_fixed >> 16) < ROCK_STOP_Y:
		rumble_active = true
		_maybe_spawn_falling_stuff()

func _tick_descend_rocks() -> void:
	_move_base()
	_maybe_spawn_falling_stuff()
	if (y_fixed >> 16) < ROCK_STOP_Y:
		return
	state = STATE_DESCEND_FINISH
	rumble_active = false

func _tick_descend_finish() -> void:
	_move_base()
	if (y_fixed >> 16) < ATTACK_Y:
		return
	y_fixed = ATTACK_Y << 16
	state = STATE_HORIZONTAL
	_set_digger_anim(6)
	countdown = 0x64
	hover_fire_on = false
	vehicle_light_on = true
	var px: int = manager.player.pixel_x() if manager.player != null else (x_fixed >> 16)
	facing_right = px >= (x_fixed >> 16)
	vel_x = 0x200 if facing_right else -0x200
	vel_y = 0

func _tick_horizontal() -> void:
	countdown -= 1
	if countdown <= 0x28:
		collision_mode = 1
	if countdown >= 0:
		return
	if digger_hurt_sonic:
		digger_hurt_sonic = false
		face_grin_timer = 0x30
		_begin_reascend()
		return
	_move_base()
	var bx: int = x_fixed >> 16
	if bx <= LEFT_X:
		x_fixed = LEFT_X << 16
		_begin_reascend()
	elif bx >= RIGHT_X:
		x_fixed = RIGHT_X << 16
		_begin_reascend()

func _begin_reascend() -> void:
	vel_x = 0
	vel_y = -0xC0
	state = STATE_ASCEND
	countdown = 0x64
	hover_fire_on = true
	vehicle_light_on = false
	_set_digger_anim(11)

func _tick_defeated() -> void:
	rumble_active = false
	countdown -= 1
	if (visual_tick & 7) == 0:
		var off: Vector2i = _random_explosion_offset()
		manager.spawn_boss_explosion((x_fixed >> 16) + off.x, _display_y() + off.y)
	if countdown <= 0x78 and not diggers_detached:
		_detach_diggers()
	if countdown >= 0:
		return
	facing_right = true
	vel_x = 0
	vel_y = 0
	countdown = -0x12
	state = STATE_ESCAPE_BOB

func _tick_escape_bob() -> void:
	countdown += 1
	if countdown < 0:
		if (y_fixed >> 16) < ROCK_STOP_Y:
			countdown -= 1
		vel_y = GenesisMath.s16(vel_y + 0x10)
	elif countdown == 0:
		vel_y = 0
	elif countdown < 0x18:
		vel_y = GenesisMath.s16(vel_y - 8)
	elif countdown == 0x18:
		vel_y = 0
		manager.set_boss_defeated()
		SonicAudio.play_music(SonicAudio.MUS_S2_MCZ, true)
	elif countdown >= 0x20:
		hover_fire_on = true
		vehicle_light_on = false
		face_grin_timer = 0
		state = STATE_ESCAPE_RIGHT
	_move_base()
	sine_count = (sine_count + 2) & 0xFF

func _tick_escape_right() -> void:
	vel_x = 0x400
	vel_y = -0x40
	_move_base()
	sine_count = (sine_count + 2) & 0xFF
	manager.unlock_s2_mcz_boss_right_boundary()
	var view_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= CAMERA_ESCAPE_MAX and (x_fixed >> 16) > manager.current_screen_x + view_width + 96:
		alive = false

func _move_base() -> void:
	x_fixed += GenesisMath.s16(vel_x) << 8
	y_fixed += GenesisMath.s16(vel_y) << 8

func _display_y() -> int:
	var by: int = y_fixed >> 16
	if state == STATE_ESCAPE_BOB or state == STATE_ESCAPE_RIGHT:
		var phase: float = float(sine_count) * TAU / 256.0
		by += int(round(sin(phase) * 4.0))
	return by

func _maybe_spawn_falling_stuff() -> void:
	# Obj57_SpawnStoneSpike uses Vint_runcount: one spike on low-5 == 0,
	# otherwise a harmless stone on the remaining low-3 == 0 frames.
	var low: int = visual_tick & 0x1F
	var spawn_spike: bool = low == 0
	var spawn_stone: bool = (visual_tick & 7) == 0 and not spawn_spike
	if not spawn_spike and not spawn_stone:
		return
	var x: int = FALL_X_MIN
	for _try in range(16):
		x = FALL_X_MIN + (manager.next_random_word() & 0x1FF)
		if x <= FALL_X_MAX:
			break
	if x > FALL_X_MAX:
		x = FALL_X_MIN + (visual_tick % (FALL_X_MAX - FALL_X_MIN + 1))
	var sprite: Sprite2D = _make_sprite(-1)
	var frame: int = 0x14 if spawn_spike else 0x0D
	sprite.texture = load("res://assets/objects/s2_mcz/boss/falling/%02d.png" % frame)
	falling_stuff.append({
		"x": x,
		"yf": FALL_START_Y << 16,
		"vy": 0,
		"spike": spawn_spike,
		"sprite": sprite,
	})

func _tick_falling_stuff() -> void:
	for i in range(falling_stuff.size() - 1, -1, -1):
		var f: Dictionary = falling_stuff[i]
		var sprite: Sprite2D = f["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			falling_stuff.remove_at(i)
			continue
		f["yf"] = int(f["yf"]) + (GenesisMath.s16(int(f["vy"])) << 8)
		# ObjectMoveAndFall adds $38, then Obj57 subtracts $28 from y_vel.
		f["vy"] = GenesisMath.s16(int(f["vy"]) + 0x10)
		var wx: int = int(f["x"])
		var wy: int = int(f["yf"]) >> 16
		if bool(f["spike"]):
			_check_small_hazard(wx, wy, 4, 0x10)
		sprite.position = Vector2(wx - (x_fixed >> 16), wy - _display_y())
		falling_stuff[i] = f
		if wy > FALL_DELETE_Y:
			sprite.queue_free()
			falling_stuff.remove_at(i)

func _detach_diggers() -> void:
	diggers_detached = true
	digger_a_x_fixed = x_fixed
	digger_a_y_fixed = y_fixed
	digger_b_x_fixed = ((x_fixed >> 16) + (0x28 if facing_right else -0x28)) << 16
	digger_b_y_fixed = y_fixed
	digger_a_vy = -0x380
	digger_b_vy = -0x380

func _tick_detached_diggers() -> void:
	# Obj57_FallApart always separates sub2 right and sub5 left, regardless of
	# the vehicle flip, while both receive normal +$38 gravity.
	digger_b_x_fixed -= 1 << 16
	if (digger_b_y_fixed >> 16) < FALL_DELETE_Y:
		digger_b_y_fixed += GenesisMath.s16(digger_b_vy) << 8
		digger_b_vy = GenesisMath.s16(digger_b_vy + 0x38)
	else:
		digger_b_vy = 0
	digger_a_x_fixed += 1 << 16
	if (digger_a_y_fixed >> 16) < FALL_DELETE_Y:
		digger_a_y_fixed += GenesisMath.s16(digger_a_vy) << 8
		digger_a_vy = GenesisMath.s16(digger_a_vy + 0x38)
	else:
		digger_a_vy = 0

func _check_center_collision() -> bool:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return false
	var bx: int = x_fixed >> 16
	var by: int = _display_y()
	# collision_flags $0F -> Touch_Sizes[$0F] = $18,$18.
	if absi(p.pixel_x() - bx) > 0x18 + p.width_radius or absi(p.pixel_y() - by) > 0x18 + p.height_radius:
		return false
	if p.can_attack_object():
		p.vel_x = GenesisMath.s16(-int(p.vel_x / 2))
		p.vel_y = GenesisMath.s16(-int(p.vel_y / 2))
		hits -= 1
		invincibility_timer = 0x20
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			_begin_defeat()
		return true
	p.apply_hazard_hit(bx)
	return false

func _check_digger_collision() -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = x_fixed >> 16
	var by: int = _display_y()
	if collision_mode == 1:
		# BossCollision_MCZ routine 1: one $04x$04 tip at X +/- $30, Y+$04.
		var hx: int = bx + (0x30 if facing_right else -0x30)
		var hy: int = by + 4
		if absi(p.pixel_x() - hx) <= 4 + p.width_radius and absi(p.pixel_y() - hy) <= 4 + p.height_radius:
			if p.apply_hazard_hit(hx):
				digger_hurt_sonic = true
		return
	# BossCollision_MCZ routine 0: two narrow vertical drill hitboxes at X +/-
	# $14, Y-$20, each $04x$10.
	for hx in [bx + 0x14, bx - 0x14]:
		if absi(p.pixel_x() - hx) <= 4 + p.width_radius and absi(p.pixel_y() - (by - 0x20)) <= 0x10 + p.height_radius:
			if p.apply_hazard_hit(hx):
				digger_hurt_sonic = true
			return

func _check_small_hazard(hx: int, hy: int, hw: int, hh: int) -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	if absi(p.pixel_x() - hx) <= hw + p.width_radius and absi(p.pixel_y() - hy) <= hh + p.height_radius:
		p.apply_hazard_hit(hx)

func _begin_defeat() -> void:
	if state >= STATE_DEFEATED:
		return
	manager.add_score(1000)
	countdown = 0xB3
	state = STATE_DEFEATED
	rumble_active = false
	hover_fire_on = false
	vehicle_light_on = true

func _set_digger_anim(anim_id: int) -> void:
	digger_anim_id = anim_id
	digger_anim_index = 0
	digger_anim_timer = 1
	var seq: Array = DIGGER_ANIMS.get(digger_anim_id, [2])
	digger_frame = int(seq[0])

func _tick_digger_animation() -> void:
	digger_anim_timer -= 1
	if digger_anim_timer >= 0:
		return
	digger_anim_timer = 1
	var seq: Array = DIGGER_ANIMS.get(digger_anim_id, [2])
	digger_anim_index += 1
	if digger_anim_index >= seq.size():
		if DIGGER_LOOP_INDEX.has(digger_anim_id):
			digger_anim_index = int(DIGGER_LOOP_INDEX[digger_anim_id])
		else:
			digger_anim_id = int(DIGGER_NEXT.get(digger_anim_id, digger_anim_id))
			digger_anim_index = 0
		seq = DIGGER_ANIMS.get(digger_anim_id, [2])
	digger_frame = int(seq[digger_anim_index])

func _update_visuals() -> void:
	var alpha: float = 0.35 if invincibility_timer > 0 and (invincibility_timer & 2) == 0 else 1.0
	var flip: bool = facing_right
	for sprite in [hover_sprite, digger_a_sprite, vehicle_sprite, face_sprite, digger_b_sprite]:
		if sprite != null:
			sprite.flip_h = flip
			sprite.modulate = Color(1, 1, 1, alpha)

	var hover_frame: int = 7
	if state < STATE_DEFEATED and hover_fire_on:
		hover_frame = 5 + ((visual_tick >> 1) & 1)
	_set_part_texture(hover_sprite, hover_frame)
	_set_part_texture(vehicle_sprite, 0 if vehicle_light_on else 1)

	var face_frame: int = 14 + ((visual_tick >> 3) & 1)
	if state == STATE_DEFEATED:
		face_frame = 19
	elif state == STATE_ESCAPE_BOB:
		# Sub8 pins frame $12 before entering SubA; SubA does not call AnimateBoss.
		face_frame = 18
	elif state == STATE_ESCAPE_RIGHT:
		# SubA selects animation $D at $20; SubC resumes AnimateBoss normal face.
		face_frame = 14 + ((visual_tick >> 3) & 1)
	elif invincibility_timer > 0:
		face_frame = 18
	elif face_grin_timer > 0:
		face_frame = 16 + ((visual_tick >> 3) & 1)
	_set_part_texture(face_sprite, face_frame)

	_set_part_texture(digger_a_sprite, digger_frame)
	_set_part_texture(digger_b_sprite, digger_frame)
	if diggers_detached:
		digger_a_sprite.position = Vector2((digger_a_x_fixed >> 16) - (x_fixed >> 16), (digger_a_y_fixed >> 16) - _display_y())
		digger_b_sprite.position = Vector2((digger_b_x_fixed >> 16) - (x_fixed >> 16), (digger_b_y_fixed >> 16) - _display_y())
	else:
		digger_a_sprite.position = Vector2.ZERO
		digger_b_sprite.position = Vector2(0x28 if facing_right else -0x28, 0)
	vehicle_sprite.position = Vector2.ZERO
	face_sprite.position = Vector2.ZERO
	hover_sprite.position = Vector2.ZERO

func _set_part_texture(sprite: Sprite2D, frame: int) -> void:
	if sprite == null:
		return
	var path: String = "res://assets/objects/s2_mcz/boss/parts/%02d.png" % frame
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var rx: int = ((random_seed >> 8) & 0x3F) - 0x20
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var ry: int = ((random_seed >> 8) & 0x2F) - 0x18
	return Vector2i(rx, ry)

func _make_sprite(order: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = order
	add_child(sprite)
	return sprite
