class_name LZBossObject
extends Node2D

# Object $77 - Labyrinth Eggman.
# This is the source vertical chase: Eggman rises through the shaft, can be
# defeated early without stopping the ascent, waits at the top for Sonic, then
# escapes right and releases the boss screen lock/capsule path.

const BOSS_X := 0x1DE0
const BOSS_Y := 0x00C0
const BOSS_END := 0x2030

const STATE_START := 0
const STATE_MOVE1 := 1
const STATE_MOVE2 := 2
const STATE_MOVE3 := 3
const STATE_AT_TOP := 4
const STATE_WAIT := 5
const STATE_ESCAPE_WAIT := 6
const STATE_ESCAPE := 7

var manager: SonicObjectManager
var alive := true
var state := STATE_START
var boss_x_fixed := 0
var boss_y_fixed := 0
var vel_x := 0
var vel_y := 0
var sine_counter := 0
var hits := 8
var flash_timer := 0
var wait_timer := 0
var early_defeat := false
var facing_right := false
var visual_tick := 0
var random_seed := 0x77A35C11

var ship: Sprite2D
var face: Sprite2D
var flame: Sprite2D

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	boss_x_fixed = (BOSS_X + 0x30) << 16
	boss_y_fixed = (BOSS_Y + 0x500) << 16
	position = Vector2(boss_x_fixed >> 16, boss_y_fixed >> 16)
	ship = _make_sprite("res://assets/boss/eggman/00.png", 0)
	face = _make_sprite("res://assets/boss/eggman/01.png", 1)
	flame = _make_sprite("res://assets/boss/eggman/11.png", -1)
	flame.visible = false

func tick() -> void:
	if not alive:
		return
	visual_tick += 1
	if flash_timer > 0:
		flash_timer -= 1
	match state:
		STATE_START: _tick_start()
		STATE_MOVE1: _tick_move1()
		STATE_MOVE2: _tick_move2()
		STATE_MOVE3: _tick_move3()
		STATE_AT_TOP: _tick_at_top()
		STATE_WAIT: _tick_wait()
		STATE_ESCAPE_WAIT: _tick_escape_wait()
		STATE_ESCAPE: _tick_escape()
	if early_defeat and (visual_tick & 7) == 0:
		_spawn_defeat_explosion()
	_update_visuals()
	if not early_defeat and flash_timer <= 0:
		_check_player_collision()

func _tick_start() -> void:
	var p = manager.player
	if p != null and p.pixel_x() >= BOSS_X - 0x40:
		vel_y = -0x180
		vel_x = 0x60
		state = STATE_MOVE1
	_move_boss()

func _tick_move1() -> void:
	var x_done = (boss_x_fixed >> 16) >= BOSS_X + 0x68
	var y_done = (boss_y_fixed >> 16) <= BOSS_Y + 0x440
	if x_done:
		boss_x_fixed = (BOSS_X + 0x68) << 16
		vel_x = 0
	if y_done:
		boss_y_fixed = (BOSS_Y + 0x440) << 16
		vel_y = 0
	if x_done and y_done:
		vel_x = 0x140
		vel_y = -0x200
		state = STATE_MOVE2
	_move_boss()

func _tick_move2() -> void:
	var x_done = (boss_x_fixed >> 16) >= BOSS_X + 0x90
	var y_done = (boss_y_fixed >> 16) <= BOSS_Y + 0x400
	if x_done:
		boss_x_fixed = (BOSS_X + 0x90) << 16
		vel_x = 0
	if y_done:
		boss_y_fixed = (BOSS_Y + 0x400) << 16
		vel_y = 0
	if x_done and y_done:
		vel_y = -0x180
		sine_counter = 0
		state = STATE_MOVE3
	_move_boss()

func _tick_move3() -> void:
	if (boss_y_fixed >> 16) <= BOSS_Y + 0x40:
		boss_y_fixed = (BOSS_Y + 0x40) << 16
		vel_x = 0x140
		vel_y = -0x80
		if early_defeat:
			vel_x = GenesisMath.s16(vel_x << 1)
			vel_y = GenesisMath.s16(vel_y << 1)
		state = STATE_AT_TOP
		_move_boss()
		return

	# BLZ_ShipMove3: the internal X remains fixed while the displayed ship
	# oscillates +/-16px. Its upward velocity is throttled as Sonic falls behind.
	facing_right = true
	sine_counter = (sine_counter + 2) & 0xFF
	if GenesisMath.cosine(sine_counter) < 0:
		facing_right = false
	var applied_y = vel_y
	var p = manager.player
	if p != null:
		var distance = p.pixel_y() - (boss_y_fixed >> 16)
		if distance >= 72:
			applied_y = GenesisMath.s16(applied_y >> 1)
			if distance >= 112:
				applied_y = GenesisMath.s16(applied_y >> 1)
				if distance >= 152:
					applied_y = 0
	if early_defeat:
		applied_y = GenesisMath.s16(applied_y << 1)
	boss_y_fixed += applied_y << 8
	_sync_position(true)

func _tick_at_top() -> void:
	var x_done = (boss_x_fixed >> 16) >= BOSS_X + 0x16C
	var y_done = (boss_y_fixed >> 16) <= BOSS_Y
	if x_done:
		boss_x_fixed = (BOSS_X + 0x16C) << 16
		vel_x = 0
	if y_done:
		boss_y_fixed = BOSS_Y << 16
		vel_y = 0
	if x_done and y_done:
		state = STATE_WAIT
		facing_right = false
	_move_boss()

func _tick_wait() -> void:
	var p = manager.player
	if early_defeat:
		_begin_escape_wait(0)
	elif p != null and p.pixel_x() >= BOSS_X + 0xE8 and p.pixel_y() <= BOSS_Y + 0x30:
		_begin_escape_wait(50)
	_move_boss()

func _begin_escape_wait(frames: int) -> void:
	wait_timer = frames
	facing_right = true
	state = STATE_ESCAPE_WAIT
	# REV01 clears f_lockscreen here and restores LZ music. The native sound
	# driver is still deferred, but releasing the lock/capsule gate is exact.
	manager.release_lz_boss_screen_lock()
	manager.set_boss_defeated()

func _tick_escape_wait() -> void:
	if early_defeat:
		_start_escape()
		return
	wait_timer -= 1
	if wait_timer <= 0:
		_start_escape()

func _start_escape() -> void:
	wait_timer = 0
	vel_x = 0x400
	vel_y = -0x40
	early_defeat = false
	state = STATE_ESCAPE
	_move_boss()

func _tick_escape() -> void:
	manager.unlock_lz_boss_right_boundary()
	_move_boss()
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= BOSS_END and int(position.x) > manager.current_screen_x + view_width + 96:
		alive = false
		queue_free()

func _move_boss() -> void:
	boss_x_fixed += vel_x << 8
	boss_y_fixed += vel_y << 8
	_sync_position(false)

func _sync_position(oscillate_x: bool) -> void:
	var draw_x = boss_x_fixed >> 16
	if oscillate_x:
		draw_x += GenesisMath.sine(sine_counter) >> 4
	position = Vector2(draw_x, boss_y_fixed >> 16)

func _check_player_collision() -> void:
	var p = manager.player
	if p == null or p.dead or p.drowning or p.hurt_state:
		return
	if absi(p.pixel_x() - int(position.x)) > p.width_radius + 24 or absi(p.pixel_y() - int(position.y)) > p.height_radius + 24:
		return
	if not p.can_attack_object():
		p.apply_hazard_hit(int(position.x))
		return

	# React_BossHit: negate and halve Sonic's current velocity.
	var incoming_x = p.vel_x
	if incoming_x == 0 and p.inertia != 0:
		incoming_x = p.inertia
	var incoming_y = p.vel_y
	p.vel_x = GenesisMath.s16(GenesisMath.s16(-incoming_x) >> 1)
	p.vel_y = GenesisMath.s16(GenesisMath.s16(-incoming_y) >> 1)
	# ReactToItem separates the player from the boss through its collision pass.
	# The native overlap test needs the same side-axis separation so Sonic does
	# not remain embedded and lose the source rebound on the following frame.
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

	flash_timer = 0x20
	hits -= 1
	SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
	if hits <= 0:
		early_defeat = true
		manager.add_score(100)

func _spawn_defeat_explosion() -> void:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var ox = (random_seed & 0x3F) - 0x20
	var oy = (random_seed >> 8) & 0x1F
	manager.spawn_monitor_explosion(int(position.x) + ox, int(position.y) + oy)

func _update_visuals() -> void:
	if ship == null:
		return
	ship.flip_h = facing_right
	face.flip_h = facing_right
	flame.flip_h = facing_right

	var face_frame = 1 + (int(visual_tick / 6) & 1)
	if early_defeat:
		face_frame = 7
	elif flash_timer > 0:
		face_frame = 5
	elif manager.player != null and manager.player.hurt_state:
		face_frame = 3 + (int(visual_tick / 5) & 1)
	elif state == STATE_ESCAPE:
		face_frame = 1 + (int(visual_tick / 4) & 1)
	face.texture = load("res://assets/boss/eggman/%02d.png" % face_frame)

	# The Object $77 flame child is blank before Escape2 in the supplied source.
	flame.visible = state == STATE_ESCAPE
	if flame.visible:
		var escape_frames = [9, 8, 11, 12, 11, 12, 9, 8]
		var fi = int(visual_tick / 3) % escape_frames.size()
		flame.texture = load("res://assets/boss/eggman/%02d.png" % escape_frames[fi])

func _make_sprite(path: String, z: int) -> Sprite2D:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.z_index = z
	sp.texture = load(path)
	add_child(sp)
	return sp
