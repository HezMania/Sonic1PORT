class_name S2EHZBadnikObject
extends GenesisLevelObject

# Retail EHZ badniks used by the native S2 test slot:
# $4B Buzzer, $5C Masher, $9D Coconuts.
var sprite: Sprite2D
var flame: Sprite2D
var frame_tick := 0
var collision_active := true

# Buzzer state.
var buzzer_vel_x := 0
var buzzer_move_timer := 0
var buzzer_turn_delay := 0
var buzzer_shooting := false
var buzzer_shooting_disabled := false
var buzzer_shot_timer := 0

# Masher state.
var masher_initial_y := 0
var masher_vel_y := 0

# Coconuts state.
var coconut_state := 0 # 0 idle, 1 climbing, 2 throw-up, 3 throw-down
var coconut_timer := 0
var coconut_attack_timer := 0
var coconut_climb_index := 0
var coconut_vel_y := 0

const COCONUT_CLIMB_SPEED: Array[int] = [-0x100, 0x100, -0x100, 0x100, -0x100, 0x100]
const COCONUT_CLIMB_TIME: Array[int] = [0x20, 0x18, 0x10, 0x28, 0x20, 0x10]

func initialize_object() -> void:
	match object_id:
		0x4B:
			_init_buzzer()
		0x5C:
			_init_masher()
		0x9D:
			_init_coconuts()

func _init_buzzer() -> void:
	active_width = 24
	buzzer_vel_x = 0x100 if x_flip else -0x100
	buzzer_move_timer = 0x100
	buzzer_turn_delay = 0
	sprite = make_sprite("res://assets/objects/s2_ehz/buzzer/00.png", 1)
	sprite.flip_h = x_flip
	flame = make_sprite("res://assets/objects/s2_ehz/buzzer/03.png", 0)
	flame.flip_h = x_flip

func _init_masher() -> void:
	active_width = 16
	masher_initial_y = spawn_y
	masher_vel_y = -0x400
	sprite = make_sprite("res://assets/objects/s2_ehz/masher/00.png", 1)

func _init_coconuts() -> void:
	active_width = 16
	coconut_state = 0
	coconut_timer = 0x10
	coconut_attack_timer = 0
	coconut_climb_index = 0
	sprite = make_sprite("res://assets/objects/s2_ehz/coconuts/00.png", 1)
	_face_coconuts_player()

func tick() -> void:
	frame_tick += 1
	match object_id:
		0x4B:
			_tick_buzzer()
		0x5C:
			_tick_masher()
		0x9D:
			_tick_coconuts()
	if alive:
		_react_to_player()

func _tick_buzzer() -> void:
	if buzzer_shooting:
		buzzer_shot_timer -= 1
		if buzzer_shot_timer == 0x14:
			_spawn_buzzer_shot()
		if buzzer_shot_timer < 0:
			buzzer_shooting = false
		set_sprite_frame(sprite, "s2_ehz/buzzer", 1)
	else:
		_buzzer_check_player()
		buzzer_turn_delay -= 1
		if buzzer_turn_delay == 0x0F:
			buzzer_shooting_disabled = false
			buzzer_vel_x = -buzzer_vel_x
			x_flip = not x_flip
			sprite.flip_h = x_flip
			flame.flip_h = x_flip
			buzzer_move_timer = 0x100
		elif buzzer_turn_delay < 0:
			buzzer_move_timer -= 1
			if buzzer_move_timer > 0:
				position.x += float(buzzer_vel_x) / 256.0
			else:
				buzzer_turn_delay = 0x1E
		set_sprite_frame(sprite, "s2_ehz/buzzer", 0)
	if flame != null:
		flame.visible = buzzer_turn_delay < 0
		if flame.visible:
			set_sprite_frame(flame, "s2_ehz/buzzer", 3 + (int(frame_tick / 3) & 1))

func _buzzer_check_player() -> void:
	if buzzer_shooting_disabled:
		return
	var p = player()
	if p == null:
		return
	var signed_dx = int(position.x) - p.pixel_x()
	var distance = absi(signed_dx)
	if distance < 0x28 or distance > 0x30:
		return
	# render/status bit 0 set means the source Buzzer faces/moves right.
	if signed_dx < 0 and not x_flip:
		return
	if signed_dx >= 0 and x_flip:
		return
	buzzer_shooting_disabled = true
	buzzer_shooting = true
	buzzer_shot_timer = 0x32

func _spawn_buzzer_shot() -> void:
	# Retail Obj4B spawns at the stinger, which is on the OPPOSITE side from
	# the projectile's initial horizontal velocity.  The Phase 83 port tied the
	# offset sign to velocity and therefore emitted the shot from the head side.
	var horizontal_velocity = 0x180 if x_flip else -0x180
	var stinger_offset = -0x0D if x_flip else 0x0D
	manager.spawn_s2_buzzer_projectile(int(position.x) + stinger_offset, int(position.y) + 0x18, horizontal_velocity, x_flip)

func _tick_masher() -> void:
	position.y += float(masher_vel_y) / 256.0
	masher_vel_y = GenesisMath.s16(masher_vel_y + 0x18)
	if int(position.y) > masher_initial_y:
		position.y = masher_initial_y
		masher_vel_y = -0x500
	var frame = 0
	if int(position.y) <= masher_initial_y - 0xC0:
		frame = (frame_tick >> 2) & 1
	elif masher_vel_y < 0:
		frame = (frame_tick >> 3) & 1
	else:
		frame = 0
	set_sprite_frame(sprite, "s2_ehz/masher", frame)

func _tick_coconuts() -> void:
	match coconut_state:
		0:
			_face_coconuts_player()
			var p = player()
			if p != null and absi(p.pixel_x() - int(position.x)) < 0x60:
				if coconut_attack_timer <= 0:
					coconut_state = 2
					coconut_timer = 8
					coconut_attack_timer = 0x20
					set_sprite_frame(sprite, "s2_ehz/coconuts", 1)
					return
				coconut_attack_timer -= 1
			coconut_timer -= 1
			if coconut_timer < 0:
				_start_coconuts_climb()
		1:
			coconut_timer -= 1
			if coconut_timer == 0:
				coconut_state = 0
				coconut_timer = 0x10
				return
			position.y += float(coconut_vel_y) / 256.0
			set_sprite_frame(sprite, "s2_ehz/coconuts", int(frame_tick / 6) & 1)
		2:
			coconut_timer -= 1
			if coconut_timer < 0:
				coconut_state = 3
				coconut_timer = 8
				set_sprite_frame(sprite, "s2_ehz/coconuts", 2)
				_spawn_coconut()
		3:
			coconut_timer -= 1
			if coconut_timer < 0:
				_start_coconuts_climb()

func _start_coconuts_climb() -> void:
	if coconut_climb_index >= COCONUT_CLIMB_SPEED.size():
		coconut_climb_index = 0
	coconut_state = 1
	coconut_vel_y = COCONUT_CLIMB_SPEED[coconut_climb_index]
	coconut_timer = COCONUT_CLIMB_TIME[coconut_climb_index]
	coconut_climb_index += 1

func _face_coconuts_player() -> void:
	var p = player()
	if p == null or sprite == null:
		return
	x_flip = p.pixel_x() < int(position.x)
	sprite.flip_h = x_flip

func _spawn_coconut() -> void:
	# Obj9D_ThrowData: facing left -> x-$B, +$100; facing right -> x+$B, -$100.
	var offset = -0x0B if x_flip else 0x0B
	var speed = 0x100 if x_flip else -0x100
	manager.spawn_s2_coconut_projectile(int(position.x) + offset, int(position.y) - 0x0D, speed, x_flip)

func _react_to_player() -> void:
	if not collision_active:
		return
	var p = player()
	if p == null or p.dead:
		return
	var half_w = 18
	var half_h = 16
	if object_id == 0x4B:
		half_w = 24
	elif object_id == 0x9D:
		half_w = 12
		half_h = 18
	if absi(p.pixel_x() - int(position.x)) > half_w + p.width_radius:
		return
	if absi(p.pixel_y() - int(position.y)) > half_h + p.height_radius:
		return
	if p.invincible_timer > 0 or p.rolling:
		var award = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(int(position.x))
