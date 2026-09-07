class_name MZBossObject
extends Node2D

# Object $73 - Marble Zone Eggman. This follows the source's major secondary
# routines: entrance, U-shaped swoops, random lava-pool fireballs, dropped fire,
# 8-hit defeat/explosion, recovery and rightward escape.

const BOSS_X := 0x1800
const BOSS_Y := 0x210
const BOSS_END := 0x1960
const LEFT_X := BOSS_X + 0x30
const RIGHT_X := BOSS_X + 0x110
const TARGET_Y := BOSS_Y + 0x1C
const LAVA_Y := BOSS_Y + 0xD8

const STATE_ENTER := 0
const STATE_CHGDIR := 1
const STATE_DROP_FIRE := 2
const STATE_EXPLODE := 3
const STATE_RECOVER := 4
const STATE_ESCAPE := 5

var manager: SonicObjectManager
var alive := true
var state := STATE_ENTER
var phase_index := 0
var x_fixed := 0
var y_fixed := 0
var vel_x := 0
var vel_y := 0
var sine_counter := 2
var hits := 8
var flash_timer := 0
var timer := 0
var facing_right := false
var defeated := false
var visual_tick := 0
var random_seed := 0x734D5A21
var lava_timer := 0

var ship: Sprite2D
var face: Sprite2D
var flame: Sprite2D
var tube: Sprite2D

func setup(owner: SonicObjectManager, x: int, y: int) -> void:
	manager = owner
	x_fixed = x << 16
	y_fixed = y << 16
	position = Vector2(x, y)
	ship = _make_sprite("res://assets/boss/eggman/00.png", 0)
	face = _make_sprite("res://assets/boss/eggman/01.png", 1)
	flame = _make_sprite("res://assets/boss/eggman/08.png", -1)
	flame.visible = false
	# Object $73 routine 8: the weapon pipe is a separate boss child.  Its
	# mapping already contains the +$14 Y offset relative to Eggman.
	tube = _make_sprite("res://assets/boss/mz_tube/00.png", 0)
	vel_x = -0x100
	lava_timer = _next_lava_timer()

func tick() -> void:
	if not alive:
		return
	visual_tick += 1
	if flash_timer > 0:
		flash_timer -= 1
	match state:
		STATE_ENTER: _tick_enter()
		STATE_CHGDIR: _tick_change_dir()
		STATE_DROP_FIRE: _tick_drop_fire()
		STATE_EXPLODE: _tick_explode()
		STATE_RECOVER: _tick_recover()
		STATE_ESCAPE: _tick_escape()
	_update_position()
	_update_visuals()
	if not defeated and flash_timer <= 0:
		_check_player_collision()

func _tick_enter() -> void:
	var bob_vel = GenesisMath.sine(sine_counter & 0xFF) >> 2
	sine_counter = (sine_counter + 2) & 0xFF
	vel_y = bob_vel
	_move()
	if (x_fixed >> 16) <= RIGHT_X:
		x_fixed = RIGHT_X << 16
		vel_x = 0
		vel_y = 0
		state = STATE_CHGDIR

func _tick_change_dir() -> void:
	var y = y_fixed >> 16
	if vel_x == 0:
		if y != TARGET_Y:
			vel_y = 0x40 if y < TARGET_Y else -0x40
			_move()
			return
		vel_x = 0x200 if facing_right else -0x200
		vel_y = 0x100
	_move()
	vel_y = GenesisMath.s16(vel_y - 4)
	_spawn_random_pool_lava()
	var x = x_fixed >> 16
	if facing_right and x >= RIGHT_X:
		x_fixed = RIGHT_X << 16
		vel_x = 0
		vel_y = -0x180 if (y_fixed >> 16) >= TARGET_Y else 0x180
		phase_index = (phase_index + 1) & 3
		state = STATE_DROP_FIRE
		timer = 80
		facing_right = false
	elif not facing_right and x <= LEFT_X:
		x_fixed = LEFT_X << 16
		vel_x = 0
		vel_y = -0x180 if (y_fixed >> 16) >= TARGET_Y else 0x180
		phase_index = (phase_index + 1) & 3
		state = STATE_DROP_FIRE
		timer = 80
		facing_right = true

func _tick_drop_fire() -> void:
	# Return to TARGET_Y, then drop Object $74 and wait 80 frames.
	if vel_y != 0:
		_move()
		var y = y_fixed >> 16
		if (vel_y < 0 and y <= TARGET_Y) or (vel_y > 0 and y >= TARGET_Y):
			y_fixed = TARGET_Y << 16
			vel_y = 0
			manager.spawn_mz_boss_fire(x_fixed >> 16, TARGET_Y + 0x18)
			timer = 80
			return
	timer -= 1
	if timer <= 0:
		state = STATE_CHGDIR

func _tick_explode() -> void:
	if (visual_tick & 7) == 0:
		var off = _random_explosion_offset()
		manager.spawn_monitor_explosion(int(position.x) + off.x, int(position.y) + off.y)
	timer -= 1
	if timer >= 0:
		return
	manager.set_boss_defeated()
	state = STATE_RECOVER
	timer = -38
	vel_x = 0
	vel_y = 0
	facing_right = true

func _tick_recover() -> void:
	# BMZ_Recover uses a -38..56 timer. During the negative portion Eggman
	# falls only until boss_mz_y+$60 ($270); reaching that boundary immediately
	# clears Y velocity. Phase 17 accidentally carried the positive fall speed
	# into the rise phase, causing him to sink far below the source position.
	timer += 1
	if timer == 0:
		vel_y = 0
		timer = 0
		_move()
		return
	if timer < 0:
		if (y_fixed >> 16) >= BOSS_Y + 0x60:
			y_fixed = (BOSS_Y + 0x60) << 16
			vel_y = 0
			timer = 0
		else:
			vel_y = GenesisMath.s16(vel_y + 0x18)
		_move()
		return
	if timer < 48:
		vel_y = GenesisMath.s16(vel_y - 8)
		_move()
		return
	if timer == 48:
		vel_y = 0
		_move()
		return
	if timer < 56:
		_move()
		return
	state = STATE_ESCAPE

func _tick_escape() -> void:
	vel_x = 0x500
	vel_y = -0x40
	manager.unlock_mz_boss_right_boundary()
	_move()
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= BOSS_END and int(position.x) > manager.current_screen_x + view_width + 96:
		alive = false

func _move() -> void:
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8

func _update_position() -> void:
	position = Vector2(x_fixed >> 16, y_fixed >> 16)

func _spawn_random_pool_lava() -> void:
	lava_timer -= 1
	if lava_timer > 0:
		return
	lava_timer = _next_lava_timer()
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var x = BOSS_X + 0x78 + (random_seed % 0x50)
	manager.spawn_lava_ball(x, LAVA_Y, 0)

func _next_lava_timer() -> int:
	random_seed = int((random_seed * 1664525 + 1013904223) & 0x7FFFFFFF)
	return 0x40 + (random_seed & 0x1F)

func _update_visuals() -> void:
	ship.flip_h = facing_right
	face.flip_h = facing_right
	flame.flip_h = facing_right
	if tube != null:
		tube.flip_h = facing_right
	var face_frame = 1 + (int(visual_tick / 6) & 1)
	if state == STATE_EXPLODE or state == STATE_RECOVER:
		face_frame = 7
	elif state == STATE_ESCAPE:
		face_frame = 6
	elif flash_timer > 0:
		face_frame = 5
	elif state == STATE_DROP_FIRE and vel_y == 0:
		face_frame = 4
	face.texture = load("res://assets/boss/eggman/%02d.png" % face_frame)
	flame.visible = (vel_x != 0 and state < STATE_EXPLODE) or state == STATE_ESCAPE
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
		# React_BossHit negates and halves Sonic's current X/Y velocity. Grounded
		# rolling Sonic can reach this native object with inertia still carrying the
		# meaningful horizontal speed even when vel_x has already been clipped by a
		# same-frame contact. Use inertia only as that representation fallback, then
		# perform the source negate/asr operation.
		var incoming_x = p.vel_x
		if incoming_x == 0 and p.inertia != 0:
			incoming_x = p.inertia
		var incoming_y = p.vel_y
		p.vel_x = GenesisMath.s16(GenesisMath.s16(-incoming_x) >> 1)
		p.vel_y = GenesisMath.s16(GenesisMath.s16(-incoming_y) >> 1)

		# ReactToItem's RAM-order collision leaves Sonic outside the boss on the next
		# frame. Our box overlap has no automatic separation, so a side strike could
		# remain embedded and visually cancel the rebound. Separate only along the
		# dominant side axis; the rebound velocity itself remains React_BossHit.
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
			manager.add_score(1000)
		return
	p.apply_hazard_hit(int(position.x))

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
