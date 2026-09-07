class_name SYZBossObject
extends Node2D

# Object $75 - Spring Yard Eggman.
# Source flow: enter from the right, patrol above ten Object $76 blocks, select
# the block under Sonic, descend with the spike, grab/lift/break that block,
# resume patrolling, then run the common 8-hit explosion/recovery/escape path.

const BOSS_X := 0x2C00
const BOSS_Y := 0x4CC
const BOSS_END := 0x2D40
const LEFT_X := BOSS_X + 0x08
const RIGHT_X := BOSS_X + 0x138
const REST_Y := BOSS_Y + 0x0E
const DESCEND_Y := BOSS_Y + 0x8A
const BLOCK_FIRST_X := BOSS_X + 0x10

const STATE_ENTER := 0
const STATE_MOVE := 1
const STATE_ATTACK := 2
const STATE_EXPLODE := 3
const STATE_RECOVER := 4
const STATE_ESCAPE := 5

const ATTACK_DESCEND := 0
const ATTACK_LIFT := 1
const ATTACK_LIFT_STOP := 2
const ATTACK_BREAK := 3

var manager: SonicObjectManager
var alive := true
var state := STATE_ENTER
var attack_phase := ATTACK_DESCEND
var x_fixed := 0
var y_fixed := 0
var vel_x := -0x100
var vel_y := 0
var sine_counter := 0
var hits := 8
var flash_timer := 0
var timer := 0
var facing_right := false
var defeated := false
var visual_tick := 0
var phase_attacked := false
var shake_offset := 0
var spike_extension := 0
var spike_collision_disabled := false
var held_block = null
var random_seed := 0x75A31C2D

var ship: Sprite2D
var face: Sprite2D
var flame: Sprite2D
var spike: Sprite2D

func setup(owner: SonicObjectManager, x: int, y: int) -> void:
	manager = owner
	x_fixed = x << 16
	y_fixed = y << 16
	position = Vector2(x, y)
	ship = _make_sprite("res://assets/boss/eggman/00.png", 0)
	face = _make_sprite("res://assets/boss/eggman/01.png", 1)
	flame = _make_sprite("res://assets/boss/eggman/08.png", -1)
	flame.visible = true
	spike = _make_sprite("res://assets/boss/syz_spike/00.png", -1)
	spike.position = Vector2.ZERO

func tick() -> void:
	if not alive:
		return
	visual_tick += 1
	if flash_timer > 0:
		flash_timer -= 1
	shake_offset = 0
	match state:
		STATE_ENTER: _tick_enter()
		STATE_MOVE: _tick_move()
		STATE_ATTACK: _tick_attack()
		STATE_EXPLODE: _tick_explode()
		STATE_RECOVER: _tick_recover()
		STATE_ESCAPE: _tick_escape()
	_update_spike()
	_update_position()
	_update_visuals()
	if not defeated and flash_timer <= 0:
		_check_player_collision()
	_check_spike_collision()

func _tick_enter() -> void:
	_bob_and_move()
	if (x_fixed >> 16) < RIGHT_X:
		x_fixed = RIGHT_X << 16
		vel_x = -0x140
		state = STATE_MOVE

func _tick_move() -> void:
	var x = x_fixed >> 16
	if x <= LEFT_X:
		x_fixed = LEFT_X << 16
		facing_right = true
		vel_x = 0x140
		phase_attacked = false
	elif x >= RIGHT_X:
		x_fixed = RIGHT_X << 16
		facing_right = false
		phase_attacked = false

	# BSYZ_MainMovement restores the patrol speed after each attack.
	vel_x = 0x140 if facing_right else -0x140
	if not phase_attacked and _try_begin_attack():
		_bob_and_move()
		return
	_bob_and_move()

func _try_begin_attack() -> bool:
	var p = manager.player
	if p == null or p.dead:
		return false
	var player_index = (p.pixel_x() - BOSS_X) >> 5
	if player_index < 0 or player_index > 9:
		return false
	var center_x = BLOCK_FIRST_X + player_index * 0x20
	if absi((x_fixed >> 16) - center_x) > 1:
		return false
	x_fixed = center_x << 16
	vel_x = 0
	vel_y = 0x180
	held_block = manager.get_syz_boss_block(player_index)
	spike_collision_disabled = false
	attack_phase = ATTACK_DESCEND
	state = STATE_ATTACK
	return true

func _tick_attack() -> void:
	match attack_phase:
		ATTACK_DESCEND:
			vel_y = 0x180
			_move()
			if (y_fixed >> 16) >= DESCEND_Y:
				y_fixed = DESCEND_Y << 16
				vel_y = 0
				if _held_block_valid():
					held_block.grab_by(self)
					spike_collision_disabled = true
					timer = 50
				else:
					held_block = null
					timer = 0
				attack_phase = ATTACK_LIFT
		ATTACK_LIFT:
			timer -= 1
			if timer < 0:
				vel_y = -0x800 if _held_block_valid() else -0x400
				attack_phase = ATTACK_LIFT_STOP
			elif timer <= 30:
				shake_offset = -2 if (timer & 2) == 0 else 2
		ATTACK_LIFT_STOP:
			var target_y = REST_Y - (0x18 if _held_block_valid() else 0)
			if (y_fixed >> 16) <= target_y:
				y_fixed = target_y << 16
				vel_y = 0
				timer = 45 if _held_block_valid() else 8
				attack_phase = ATTACK_BREAK
			else:
				if vel_y < -0x40:
					vel_y = GenesisMath.s16(vel_y + 0x0C)
				_move()
		ATTACK_BREAK:
			timer -= 1
			if timer == 0:
				if _held_block_valid():
					held_block.break_apart()
				held_block = null
			if timer <= -30:
				y_fixed = REST_Y << 16
				vel_y = 0
				spike_collision_disabled = false
				phase_attacked = true
				state = STATE_MOVE
				return
			var current_y = y_fixed >> 16
			if current_y < REST_Y:
				var step = 2 if _held_block_valid() else 1
				y_fixed = mini(REST_Y, current_y + step) << 16
			if _held_block_valid():
				shake_offset = -2 if (timer & 2) == 0 else 2

func _tick_explode() -> void:
	if (visual_tick & 7) == 0:
		var off = _random_explosion_offset()
		manager.spawn_monitor_explosion(int(position.x) + off.x, int(position.y) + off.y)
	timer -= 1
	if timer >= 0:
		return
	manager.set_boss_defeated()
	state = STATE_RECOVER
	timer = -1
	vel_x = 0
	vel_y = 0
	facing_right = true
	spike_collision_disabled = true

func _tick_recover() -> void:
	# BSYZ_Recovery: timer advances from -1; Eggman rises for 32 ticks, waits
	# until tick 42, then transitions to the escape path.
	timer += 1
	if timer < 0:
		vel_y = GenesisMath.s16(vel_y + 0x18)
		_move()
		return
	if timer == 0:
		vel_y = 0
		_move()
		return
	if timer < 32:
		vel_y = GenesisMath.s16(vel_y - 8)
		_move()
		return
	if timer == 32:
		vel_y = 0
		_move()
		return
	if timer < 42:
		_move()
		return
	state = STATE_ESCAPE

func _tick_escape() -> void:
	vel_x = 0x400
	vel_y = -0x40
	manager.unlock_syz_boss_right_boundary()
	_move()
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= BOSS_END and int(position.x) > manager.current_screen_x + view_width + 96:
		alive = false

func _bob_and_move() -> void:
	# BSYZ_CalcSine writes CalcSine/4 into obVelY (8.8 velocity), then
	# BossMove integrates that velocity into the internal 16.16 boss Y.
	# Do not treat the sine result as a direct pixel/render offset.
	vel_y = GenesisMath.s16(GenesisMath.sine(sine_counter & 0xFF) >> 2)
	sine_counter = (sine_counter + 2) & 0xFF
	_move()

func _move() -> void:
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8

func _update_spike() -> void:
	if state == STATE_ATTACK:
		if attack_phase == ATTACK_DESCEND:
			spike_extension = mini(0x94, spike_extension + 7)
		elif attack_phase == ATTACK_BREAK and timer < 0:
			spike_extension = maxi(0, spike_extension - 5)
	elif spike_extension > 0:
		spike_extension = maxi(0, spike_extension - 5)
	if spike != null:
		spike.position = Vector2(0, spike_extension >> 2)

func _update_position() -> void:
	position = Vector2(x_fixed >> 16, (y_fixed >> 16) + shake_offset)

func _update_visuals() -> void:
	ship.flip_h = facing_right
	face.flip_h = facing_right
	flame.flip_h = facing_right
	spike.flip_h = facing_right
	var face_frame = 1 + (int(visual_tick / 6) & 1)
	if state == STATE_EXPLODE or state == STATE_RECOVER:
		face_frame = 7
	elif state == STATE_ESCAPE:
		face_frame = 6
	elif flash_timer > 0:
		face_frame = 5
	elif state == STATE_ATTACK and attack_phase != ATTACK_DESCEND:
		face_frame = 6
	face.texture = load("res://assets/boss/eggman/%02d.png" % face_frame)
	flame.visible = state == STATE_ENTER or state == STATE_MOVE or state == STATE_ESCAPE
	if flame.visible:
		var ff = 11 + ((visual_tick >> 2) & 1) if state == STATE_ESCAPE else 8 + ((visual_tick >> 2) & 1)
		flame.texture = load("res://assets/boss/eggman/%02d.png" % ff)

func _check_player_collision() -> void:
	var p = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	if absi(p.pixel_x() - int(position.x)) > p.width_radius + 24 or absi(p.pixel_y() - int(position.y)) > p.height_radius + 24:
		return
	if p.can_attack_object():
		var incoming_x = p.vel_x
		if incoming_x == 0 and p.inertia != 0:
			incoming_x = p.inertia
		var incoming_y = p.vel_y
		p.vel_x = GenesisMath.s16(GenesisMath.s16(-incoming_x) >> 1)
		p.vel_y = GenesisMath.s16(GenesisMath.s16(-incoming_y) >> 1)
		var dx = p.pixel_x() - int(position.x)
		var dy = p.pixel_y() - int(position.y)
		if absi(dx) >= absi(dy):
			var edge = 24 + p.width_radius + 1
			var target_x = int(position.x) - edge if dx < 0 else int(position.x) + edge
			p.fixed_x = target_x << 16
			if dx < 0 and p.vel_x >= 0:
				p.vel_x = -maxi(0x80, absi(incoming_x) >> 1)
			elif dx >= 0 and p.vel_x <= 0:
				p.vel_x = maxi(0x80, absi(incoming_x) >> 1)
		p.inertia = 0
		p.in_air = true
		p.rolling = true
		p.jumping = false
		p.clear_object_support()
		p._sync_position()
		flash_timer = 0x28
		hits -= 1
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			defeated = true
			state = STATE_EXPLODE
			timer = 180
			vel_x = 0
			vel_y = 0
			spike_collision_disabled = true
			manager.add_score(1000)
		return
	p.apply_hazard_hit(int(position.x))

func _check_spike_collision() -> void:
	if defeated or flash_timer > 0 or spike_collision_disabled or spike == null:
		return
	var p = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var sx = int(position.x)
	var sy = int(position.y + spike.position.y)
	if absi(p.pixel_x() - sx) <= p.width_radius + 8 and absi(p.pixel_y() - sy) <= p.height_radius + 12:
		p.apply_hazard_hit(sx)

func _held_block_valid() -> bool:
	return held_block != null and is_instance_valid(held_block) and held_block.alive and not held_block.broken

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	return Vector2i((random_seed & 0x3F) - 32, (random_seed >> 8) & 0x1F)

func _make_sprite(path: String, z: int) -> Sprite2D:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.z_index = z
	sp.texture = load(path)
	add_child(sp)
	return sp
