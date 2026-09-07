class_name GHZBossObject
extends Node2D

# Object $3D/$48 - Green Hill Zone Eggman + wrecking ball.
# This keeps the original boss controller's state/timer structure while using
# native Sprite2D children for the ship/face/flame and chain pieces.

const BOSS_GHZ_X := 0x2960
const BOSS_GHZ_Y := 0x300
const BOSS_GHZ_END := 0x2AC0

const STATE_START := 0
const STATE_MAKE_BALL := 1
const STATE_WAIT := 2
const STATE_TRAVEL := 3
const STATE_EXPLODE := 4
const STATE_RECOVER := 5
const STATE_ESCAPE := 6

var manager: SonicObjectManager
var alive := true
var state := STATE_START
var timer := 0
var base_x_fixed := 0
var base_y_fixed := 0
var vel_x := 0
var vel_y := 0
var facing_right := false
var sine_counter := 0
var hits := 8
var flash_timer := 0
var recovery_counter := 0
var defeated := false
var random_seed := 0x3D48A55A

var ship: Sprite2D
var face: Sprite2D
var flame: Sprite2D
var anchor: Sprite2D
var links: Array[Sprite2D] = []
var ball: Sprite2D
var chain_created := false
var chain_anchor_y := 0
var chain_radii: Array[int] = [0, 0, 0, 0, 0]
var chain_targets: Array[int] = [16, 32, 48, 64, 96]
var swing_word := 0x4080
var swing_speed := -0x200
var swing_counterclockwise := false
var swing_enabled := false
var visual_tick := 0

func setup(owner: SonicObjectManager, world_x: int, world_y: int) -> void:
	manager = owner
	base_x_fixed = world_x << 16
	base_y_fixed = world_y << 16
	position = Vector2(world_x, world_y)
	ship = _make_sprite("res://assets/boss/eggman/00.png", 0)
	face = _make_sprite("res://assets/boss/eggman/01.png", 1)
	flame = _make_sprite("res://assets/boss/eggman/08.png", -1)
	flame.visible = false
	vel_y = 0x100

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	if flash_timer > 0:
		flash_timer -= 1

	match state:
		STATE_START:
			_tick_start()
		STATE_MAKE_BALL:
			_tick_make_ball()
		STATE_WAIT:
			_tick_wait()
		STATE_TRAVEL:
			_tick_travel()
		STATE_EXPLODE:
			_tick_explode()
		STATE_RECOVER:
			_tick_recover()
		STATE_ESCAPE:
			_tick_escape()

	_update_display_position()
	_update_face_and_flame()
	_update_chain()
	if not defeated and flash_timer <= 0:
		_check_player_collision()

func _tick_start() -> void:
	_boss_move()
	if (base_y_fixed >> 16) >= BOSS_GHZ_Y + 0x38:
		base_y_fixed = (BOSS_GHZ_Y + 0x38) << 16
		vel_y = 0
		state = STATE_MAKE_BALL

func _tick_make_ball() -> void:
	vel_x = -0x100
	vel_y = -0x40
	_boss_move()
	if (base_x_fixed >> 16) <= BOSS_GHZ_X + 0xA0:
		base_x_fixed = (BOSS_GHZ_X + 0xA0) << 16
		vel_x = 0
		vel_y = 0
		state = STATE_WAIT
		timer = 120 - 1
		_create_chain()

func _tick_wait() -> void:
	timer -= 1
	if timer >= 0:
		return
	state = STATE_TRAVEL
	timer = 0x40 - 1
	vel_x = 0x100
	if (base_x_fixed >> 16) == BOSS_GHZ_X + 0xA0:
		timer = (0x40 * 2) - 1
		vel_x = 0x40
	if not facing_right:
		vel_x = -vel_x
	swing_enabled = true

func _tick_travel() -> void:
	timer -= 1
	if timer < 0:
		facing_right = not facing_right
		timer = 0x40 - 1
		state = STATE_WAIT
		vel_x = 0
		return
	_boss_move()

func _tick_explode() -> void:
	if (visual_tick & 7) == 0:
		var off = _random_explosion_offset()
		manager.spawn_monitor_explosion(int(position.x) + off.x, int(position.y) + off.y)
	timer -= 1
	if timer >= 0:
		return
	facing_right = true
	vel_x = 0
	manager.set_boss_defeated()
	state = STATE_RECOVER
	recovery_counter = -38

func _tick_recover() -> void:
	recovery_counter += 1
	if recovery_counter < 0:
		vel_y = GenesisMath.s16(vel_y + 0x18)
	elif recovery_counter == 0:
		vel_y = 0
	elif recovery_counter < 0x30:
		vel_y = GenesisMath.s16(vel_y - 8)
	elif recovery_counter == 0x30:
		vel_y = 0
	elif recovery_counter >= 0x38:
		state = STATE_ESCAPE
		return
	_boss_move()

func _tick_escape() -> void:
	vel_x = 0x400
	vel_y = -0x40
	manager.unlock_boss_right_boundary()
	_boss_move()
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= BOSS_GHZ_END and int(position.x) > manager.current_screen_x + view_width + 96:
		alive = false

func _boss_move() -> void:
	base_x_fixed += vel_x << 8
	base_y_fixed += vel_y << 8

func _update_display_position() -> void:
	var bob = GenesisMath.sine(sine_counter & 0xFF) >> 6
	position = Vector2(base_x_fixed >> 16, (base_y_fixed >> 16) + bob)
	sine_counter = (sine_counter + 2) & 0xFF

func _update_face_and_flame() -> void:
	ship.flip_h = facing_right
	face.flip_h = facing_right
	flame.flip_h = facing_right

	var face_frame = 1 + (int(visual_tick / 6) & 1)
	if state == STATE_EXPLODE or state == STATE_RECOVER:
		face_frame = 7
	elif state == STATE_ESCAPE:
		face_frame = 6 if ((visual_tick >> 2) & 1) == 0 else 1
	elif flash_timer > 0:
		# Ani_Eggman.facehit is delay 31: frame 5 remains visible for the
		# entire collision-disabled hit window before returning to frame 1.
		# The original flashing is a palette flash, not idle/hit frame flicker.
		face_frame = 5
	elif manager.player != null and (manager.player.hurt_state or manager.player.dead):
		face_frame = 3 + (int(visual_tick / 5) & 1)
	elif state == STATE_WAIT and (base_x_fixed >> 16) == BOSS_GHZ_X + 0xA0:
		face_frame = 3 + (int(visual_tick / 5) & 1)
	face.texture = load("res://assets/boss/eggman/%02d.png" % face_frame)

	if state == STATE_ESCAPE:
		flame.visible = true
		flame.texture = load("res://assets/boss/eggman/%02d.png" % (11 + ((visual_tick >> 2) & 1)))
	elif vel_x != 0 and state < STATE_EXPLODE:
		flame.visible = true
		flame.texture = load("res://assets/boss/eggman/%02d.png" % (8 + ((visual_tick >> 2) & 1)))
	else:
		flame.visible = false

	# The original alternates one palette entry black/white while hit. Keep
	# sprite visibility stable here; hiding the face itself produces a much more
	# severe flicker than the Genesis palette effect.
	ship.visible = true
	face.visible = true

func _check_player_collision() -> void:
	var p = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var dx = absi(p.pixel_x() - int(position.x))
	var dy = absi(p.pixel_y() - int(position.y))
	if dx > 24 + p.width_radius or dy > 24 + p.height_radius:
		return
	if p.can_attack_object():
		p.vel_x = GenesisMath.s16(-int(p.vel_x / 2))
		p.vel_y = GenesisMath.s16(-int(p.vel_y / 2))
		flash_timer = 0x20
		hits -= 1
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			defeated = true
			state = STATE_EXPLODE
			timer = 0xB3
			manager.add_score(1000)
			flame.visible = false
		return
	p.apply_hazard_hit(int(position.x))

func _create_chain() -> void:
	if chain_created:
		return
	chain_created = true
	anchor = _make_sprite("res://assets/boss/anchor/00.png", -2)
	for i in range(4):
		var link = _make_sprite("res://assets/objects/swing_ghz/01.png", -3)
		links.append(link)
	ball = _make_sprite("res://assets/boss/ball/01.png", -2)

func _update_chain() -> void:
	if not chain_created or anchor == null:
		return
	if defeated:
		if ball != null:
			ball.visible = false
		for link in links:
			link.visible = false
		anchor.visible = false
		return
	chain_anchor_y = mini(32, chain_anchor_y + 1)
	for i in range(chain_radii.size()):
		chain_radii[i] = mini(chain_targets[i], chain_radii[i] + 1)
	if swing_enabled:
		if not swing_counterclockwise:
			swing_speed += 8
			if swing_speed >= 0x200:
				swing_speed = 0x200
				swing_counterclockwise = true
		else:
			swing_speed -= 8
			if swing_speed <= -0x200:
				swing_speed = -0x200
				swing_counterclockwise = false
		swing_word = (swing_word + swing_speed) & 0xFFFF
	var swing_angle = (swing_word >> 8) & 0xFF
	var sine = GenesisMath.sine(swing_angle)
	var cosine = GenesisMath.cosine(swing_angle)
	anchor.position = Vector2(0, chain_anchor_y)
	anchor.texture = load("res://assets/boss/anchor/%02d.png" % ((visual_tick >> 3) & 1))
	for i in range(links.size()):
		var radius = chain_radii[i]
		links[i].position = Vector2((cosine * radius) >> 8, chain_anchor_y + ((sine * radius) >> 8))
	var ball_radius = chain_radii[4]
	ball.position = Vector2((cosine * ball_radius) >> 8, chain_anchor_y + ((sine * ball_radius) >> 8))
	ball.texture = load("res://assets/boss/ball/%02d.png" % (visual_tick & 1))
	var p = manager.player
	if p != null and not p.dead:
		var bx = int(position.x + ball.position.x)
		var by = int(position.y + ball.position.y)
		if absi(p.pixel_x() - bx) <= 20 + p.width_radius and absi(p.pixel_y() - by) <= 20 + p.height_radius:
			p.apply_hazard_hit(bx)

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var x = (random_seed & 0x3F) - 32
	var y = (random_seed >> 8) & 0x1F
	return Vector2i(x, y)

func _make_sprite(path: String, order: int) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.texture = load(path)
	sprite.z_index = order
	add_child(sprite)
	return sprite
