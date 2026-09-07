class_name SLZBossObject
extends Node2D

# Object $7A - Star Light Eggman. This is the source seesaw-bomb encounter:
# Eggman patrols between $2008 and $2138, pauses over one of the three subtype
# $FF seesaws, drops Object $7B, takes eight hits, then performs the common
# explosion/recovery/escape sequence while opening the right bound to $2160.

const BOSS_X := 0x2000
const BOSS_Y := 0x0210
const BOSS_END := 0x2160
const LEFT_X := BOSS_X + 0x08
const RIGHT_X := BOSS_X + 0x138

const STATE_START := 0
const STATE_MOVE := 1
const STATE_MAKE_BALL := 2
const STATE_EXPLODE := 3
const STATE_RECOVER := 4
const STATE_ESCAPE := 5

var manager: SonicObjectManager
var alive := true
var state := STATE_START
var x_fixed := 0
var y_fixed := 0
var vel_x := -0x100
var vel_y := 0
var sine_counter := 0
var facing_right := false
var hits := 8
var flash_timer := 0
var timer := 0
var defeated := false
var selected_seesaw: SLZNativeObject = null
var seesaws: Array = []
var visual_tick := 0
var random_seed := 0x7A5A17E1

var ship: Sprite2D
var face: Sprite2D
var flame: Sprite2D
var pipe: Sprite2D

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	x_fixed = (BOSS_X + 0x188) << 16
	y_fixed = (BOSS_Y + 0x18) << 16
	position = Vector2(x_fixed >> 16, y_fixed >> 16)
	ship = _make_sprite("res://assets/boss/eggman/00.png", 0)
	face = _make_sprite("res://assets/boss/eggman/01.png", 1)
	flame = _make_sprite("res://assets/boss/eggman/08.png", -1)
	pipe = _make_sprite("", -1)
	pipe.texture = SourceObjectArt.slz_boss_pipe_texture()
	seesaws = manager.get_slz_boss_seesaws()

func tick() -> void:
	if not alive:
		return
	visual_tick += 1
	if flash_timer > 0:
		flash_timer -= 1
	match state:
		STATE_START: _tick_start()
		STATE_MOVE: _tick_move()
		STATE_MAKE_BALL: _tick_make_ball()
		STATE_EXPLODE: _tick_explode()
		STATE_RECOVER: _tick_recover()
		STATE_ESCAPE: _tick_escape()
	_update_position()
	_update_visuals()
	if not defeated and flash_timer <= 0:
		_check_player_collision()

func _tick_start() -> void:
	vel_x = -0x100
	if (x_fixed >> 16) < BOSS_X + 0x120:
		state = STATE_MOVE
	_bob_and_move()

func _tick_move() -> void:
	var x = x_fixed >> 16
	vel_x = 0x200 if facing_right else -0x200
	if not facing_right and x <= LEFT_X:
		x_fixed = LEFT_X << 16
		facing_right = true
		vel_x = 0x200
	elif facing_right and x >= RIGHT_X:
		x_fixed = RIGHT_X << 16
		facing_right = false
		vel_x = -0x200

	selected_seesaw = _find_drop_seesaw()
	if selected_seesaw != null:
		state = STATE_MAKE_BALL
		timer = 40
	_bob_and_move()

func _find_drop_seesaw() -> SLZNativeObject:
	var drop_offset = 40 if vel_x >= 0 else -40
	for entry in seesaws:
		if entry == null or not is_instance_valid(entry) or not entry.alive:
			continue
		var saw = entry as SLZNativeObject
		if saw == null:
			continue
		var p = manager.player
		if p != null and p.standing_on_object and p.support_record_index == saw.record_index:
			continue
		if manager.slz_boss_seesaw_has_ball(saw):
			continue
		if int(saw.position.x) + drop_offset == (x_fixed >> 16):
			return saw
	return null

func _tick_make_ball() -> void:
	# BSLZ_MakeBall does not call BossMove/ShipUpdate while its timer is active,
	# so the ship (including its bob) freezes at the post-alignment position.
	# The existing patrol velocity is retained and resumes immediately when the
	# timer expires through BSLZ_ShipUpdate.
	if timer == 40 and selected_seesaw != null and is_instance_valid(selected_seesaw):
		manager.spawn_slz_boss_spikeball(self, selected_seesaw, x_fixed >> 16, (y_fixed >> 16) + 0x20)
	timer -= 1
	if timer <= 0:
		selected_seesaw = null
		state = STATE_MOVE
		_bob_and_move()

func _tick_explode() -> void:
	if (visual_tick & 7) == 0:
		_spawn_defeat_explosion()
	timer -= 1
	if timer >= 0:
		return
	state = STATE_RECOVER
	vel_y = 0
	vel_x = 0
	facing_right = true
	defeated = false
	timer = -24
	manager.set_boss_defeated()

func _tick_recover() -> void:
	timer += 1
	if timer < 0:
		vel_y = GenesisMath.s16(vel_y + 0x18)
	elif timer == 0:
		vel_y = 0
	elif timer < 32:
		vel_y = GenesisMath.s16(vel_y - 8)
	elif timer == 32:
		vel_y = 0
	elif timer >= 42:
		state = STATE_ESCAPE
	_move_no_bob()

func _tick_escape() -> void:
	vel_x = 0x400
	vel_y = -0x40
	manager.unlock_slz_boss_right_boundary()
	# BSLZ_Escape calls BossMove once, then branches to BSLZ_ShipUpdate which
	# calls BossMove a second time before applying the normal sine bob. Preserve
	# that literal two-integration escape behavior.
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8
	sine_counter = (sine_counter + 2) & 0xFF
	position = Vector2(x_fixed >> 16, (y_fixed >> 16) + (GenesisMath.sine(sine_counter) >> 6))
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= BOSS_END and int(position.x) > manager.current_screen_x + view_width + 96:
		alive = false

func _bob_and_move() -> void:
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8
	sine_counter = (sine_counter + 2) & 0xFF
	position = Vector2(x_fixed >> 16, (y_fixed >> 16) + (GenesisMath.sine(sine_counter) >> 6))

func _move_no_bob() -> void:
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8
	position = Vector2(x_fixed >> 16, y_fixed >> 16)

func _update_position() -> void:
	if state == STATE_START or state == STATE_MOVE or state == STATE_MAKE_BALL:
		position = Vector2(x_fixed >> 16, (y_fixed >> 16) + (GenesisMath.sine(sine_counter) >> 6))
	else:
		position = Vector2(x_fixed >> 16, y_fixed >> 16)

func is_hittable() -> bool:
	return alive and not defeated and state < STATE_EXPLODE and flash_timer <= 0 and hits > 0

func hit_by_spikeball() -> void:
	if not is_hittable():
		return
	_register_hit()

func _check_player_collision() -> void:
	var p = manager.player
	if p == null or p.dead or p.drowning or p.hurt_state:
		return
	if absi(p.pixel_x() - int(position.x)) > p.width_radius + 24 or absi(p.pixel_y() - int(position.y)) > p.height_radius + 24:
		return
	if not p.can_attack_object():
		p.apply_hazard_hit(int(position.x))
		return
	var incoming_x = p.vel_x if p.vel_x != 0 else p.inertia
	var incoming_y = p.vel_y
	p.vel_x = GenesisMath.s16(GenesisMath.s16(-incoming_x) >> 1)
	p.vel_y = GenesisMath.s16(GenesisMath.s16(-incoming_y) >> 1)
	p.inertia = 0
	p.in_air = true
	p.rolling = true
	p.jumping = false
	p.clear_object_support()
	p._sync_position()
	_register_hit()

func _register_hit() -> void:
	flash_timer = 0x20
	hits -= 1
	SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
	if hits > 0:
		return
	manager.add_score(100)
	defeated = true
	state = STATE_EXPLODE
	timer = 120
	vel_x = 0

func _spawn_defeat_explosion() -> void:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var ox = (random_seed & 0x3F) - 0x20
	var oy = (random_seed >> 8) & 0x1F
	manager.spawn_monitor_explosion(int(position.x) + ox, int(position.y) + oy)

func _update_visuals() -> void:
	var flip = facing_right
	ship.flip_h = flip
	face.flip_h = flip
	flame.flip_h = flip
	pipe.flip_h = flip
	# Face state follows the source child: normal, hit, laugh, defeated, panic.
	var face_frame = 1 + (int(visual_tick / 6) & 1)
	if state >= STATE_EXPLODE and state < STATE_ESCAPE:
		face_frame = 7
	elif flash_timer > 0:
		face_frame = 5
	elif manager.player != null and manager.player.hurt_state:
		face_frame = 3 + (int(visual_tick / 5) & 1)
	elif state == STATE_ESCAPE:
		face_frame = 6
	face.texture = load("res://assets/boss/eggman/%02d.png" % face_frame)
	# Source animation 7 is the blank flame used for MakeBall, Explode and
	# Recover. Start/Move use the normal flame and Escape uses the long flame.
	flame.visible = state == STATE_START or state == STATE_MOVE or state == STATE_ESCAPE
	if flame.visible:
		var flame_frame = 8 + (int(visual_tick / 4) & 1)
		if state == STATE_ESCAPE:
			var escape_frames: Array[int] = [11, 12, 11, 12, 9, 8]
			flame_frame = escape_frames[int(visual_tick / 3) % escape_frames.size()]
		flame.texture = load("res://assets/boss/eggman/%02d.png" % flame_frame)

func _make_sprite(path: String, z: int) -> Sprite2D:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.z_index = z
	if not path.is_empty():
		sp.texture = load(path)
	add_child(sp)
	return sp
