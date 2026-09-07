class_name BadnikObject
extends GenesisLevelObject

# Phase 6 translates the GHZ badnik state machines that were previously only
# represented by conservative movement placeholders. Values remain in Genesis
# 8.8 velocity scale where the original code used obVelX/obVelY.

var sprite: Sprite2D
var folder := ""
var frame_count := 1
var frame_tick := 0

var state := 0
var timer := 0
var vel_x := 0
var vel_y := 0
var direction := -1
var anim_id := 0
var grounded := true
var collision_active := true

# Newtron state.
var newtron_anim_tick := 0
var newtron_fired := false
var newtron_original_y := 0

# Chopper state.
var chopper_original_y := 0

# Crabmeat flags.
var crab_fire_toggle := false
var crab_check_toggle := false
var floor_angle := 0

# Buzz Bomber: 0 normal, 1 already fired, 2 Sonic nearby / preparing to fire.
var buzz_state := 0

# Ball Hog state.
const HOG_SEQUENCE: Array[int] = [
	0,0,2,2,3,2, 0,0,2,2,3,2, 0,0,2,2,3,2, 0,0,1
]
var hog_anim_tick = 0
var hog_launched = false

func initialize_object() -> void:
	match object_id:
		0x1E:
			_init_ball_hog()
		0x1F:
			_init_crab()
		0x22:
			_init_buzz()
		0x2B:
			_init_chopper()
		0x40:
			_init_motobug()
		0x42:
			_init_newtron()
		_:
			folder = "motobug"
			frame_count = 1
	match object_id:
		0x1E:
			active_width = 12
		0x22:
			active_width = 24
		0x2B:
			active_width = 16
		_:
			active_width = 20
	if object_id == 0x1E:
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.ball_hog_texture(0)
		sprite.visible = grounded
	else:
		sprite = make_sprite("res://assets/objects/%s/00.png" % folder)
	_update_facing()

func _init_ball_hog() -> void:
	folder = "ball_hog"
	frame_count = 6
	state = 0
	vel_x = 0
	vel_y = 0
	direction = 1 if x_flip else -1
	grounded = false
	collision_active = false
	hog_anim_tick = 0
	hog_launched = false

func _init_motobug() -> void:
	folder = "motobug"
	frame_count = 7
	state = 0 # Moto_Action_Ledge
	timer = 0
	direction = 1 if not x_flip else -1
	vel_x = 0
	anim_id = 0
	_ground_initial(14)

func _init_crab() -> void:
	folder = "crabmeat"
	frame_count = 7
	state = 0 # Crab_Action_WaitFire
	timer = 0
	direction = 1 if not x_flip else -1
	vel_x = 0
	anim_id = 0
	_ground_initial(16)

func _init_buzz() -> void:
	folder = "buzz"
	frame_count = 6
	state = 0 # Buzz_Action_Wait
	timer = 0
	# obStatus bit 0 set -> positive X in the original Buzz routine.
	direction = 1 if x_flip else -1
	vel_x = 0
	anim_id = 0

func _init_chopper() -> void:
	folder = "chopper"
	frame_count = 2
	state = 0
	chopper_original_y = int(position.y)
	vel_y = -0x700
	anim_id = 1
	collision_active = true

func _init_newtron() -> void:
	folder = "newtron"
	frame_count = 11
	state = 0 # Newt_Action_ChkDistance
	newtron_anim_tick = 0
	newtron_fired = false
	newtron_original_y = int(position.y)
	vel_x = 0
	vel_y = 0
	grounded = false
	collision_active = false

func tick() -> void:
	frame_tick += 1
	match object_id:
		0x1E:
			_tick_ball_hog()
		0x40:
			_tick_motobug()
		0x1F:
			_tick_crab()
		0x22:
			_tick_buzz()
		0x2B:
			_tick_chopper()
		0x42:
			_tick_newtron()
		_:
			_tick_legacy_badnik()

	if alive:
		_react_to_player()

func _tick_ball_hog() -> void:
	# Hog_Main: fall invisibly until the 38px-tall badnik reaches the floor.
	if not grounded:
		position.y += float(vel_y) / 256.0
		vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
		var hit = _floor_at(int(position.x), int(position.y) + 19)
		var distance = int(hit["distance"])
		if distance < 0:
			position.y += distance
			vel_y = 0
			grounded = true
			collision_active = true
			hog_anim_tick = 0
			if sprite != null:
				sprite.visible = true
		return

	# Ani_Hog: delay 9 means each script entry is held for ten frames.
	var frame = HOG_SEQUENCE[int(hog_anim_tick / 10) % HOG_SEQUENCE.size()]
	if sprite != null:
		sprite.texture = SourceObjectArt.ball_hog_texture(frame)
	if frame == 1:
		if not hog_launched:
			hog_launched = true
			manager.spawn_ball_hog_cannonball(
				int(position.x) + (4 if x_flip else -4),
				int(position.y) + 12,
				0x100 if x_flip else -0x100,
				subtype & 0xFF
			)
	else:
		hog_launched = false
	hog_anim_tick = (hog_anim_tick + 1) % (HOG_SEQUENCE.size() * 10)

func _tick_motobug() -> void:
	if not grounded:
		_tick_initial_fall(14)
		return

	if state == 0:
		# Moto_Action_Ledge: wait one second, then turn and drive.
		timer -= 1
		if timer >= 0:
			anim_id = 0
			_update_moto_animation()
			return
		state = 1
		direction = -direction
		vel_x = direction * 0x100
		anim_id = 1
		_update_facing()
	else:
		position.x += float(vel_x) / 256.0
		var hit = _floor_at(int(position.x), int(position.y) + 14)
		var distance = int(hit["distance"])
		if distance < -8 or distance >= 12:
			state = 0
			timer = 59
			vel_x = 0
			anim_id = 0
		else:
			position.y += distance
	_update_moto_animation()

func _update_moto_animation() -> void:
	if anim_id == 0:
		set_sprite_frame(sprite, folder, 2)
	else:
		var seq: Array[int] = [0, 1, 0, 2]
		set_sprite_frame(sprite, folder, seq[(frame_tick >> 3) % seq.size()])

func _tick_crab() -> void:
	if not grounded:
		_tick_initial_fall(16)
		return

	if state == 0:
		timer -= 1
		if timer < 0:
			var was_set = crab_fire_toggle
			crab_fire_toggle = not crab_fire_toggle
			if was_set and manager.is_world_x_on_screen(int(position.x)):
				_crab_fire()
			else:
				_crab_start_scuttle()
	else:
		timer -= 1
		if timer < 0:
			_crab_prepare_wait()
		else:
			position.x += float(vel_x) / 256.0
			crab_check_toggle = not crab_check_toggle
			if crab_check_toggle:
				var ahead_x = int(position.x) + direction * 16
				var ahead = _floor_at(ahead_x, int(position.y) + 16)
				var ahead_distance = int(ahead["distance"])
				if ahead_distance < -8 or ahead_distance >= 12:
					_crab_prepare_wait()
				else:
					_align_crab_to_floor()
			else:
				_align_crab_to_floor()
	_update_crab_animation()

func _crab_start_scuttle() -> void:
	state = 1
	timer = 127
	direction = -direction
	vel_x = direction * 0x80
	anim_id = 3
	_update_facing()

func _crab_prepare_wait() -> void:
	state = 0
	timer = 59
	vel_x = 0
	anim_id = 0

func _crab_fire() -> void:
	state = 0
	timer = 59
	vel_x = 0
	anim_id = 6
	manager.spawn_crab_projectile(int(position.x) - 16, int(position.y), -0x100)
	manager.spawn_crab_projectile(int(position.x) + 16, int(position.y), 0x100)

func _align_crab_to_floor() -> void:
	var hit = _floor_at(int(position.x), int(position.y) + 16)
	var distance = int(hit["distance"])
	if distance >= -8 and distance < 12:
		position.y += distance
		floor_angle = int(hit["angle"]) & 0xFF

func _update_crab_animation() -> void:
	if anim_id == 6:
		set_sprite_frame(sprite, folder, 4)
		return
	if state == 0:
		set_sprite_frame(sprite, folder, 0 if _crab_slope_kind() == 0 else 2)
		return
	var slope_kind = _crab_slope_kind()
	if slope_kind == 0:
		var seq: Array[int] = [1, 1, 0]
		set_sprite_frame(sprite, folder, seq[(frame_tick >> 4) % seq.size()])
	else:
		var seq: Array[int] = [1, 3, 2]
		set_sprite_frame(sprite, folder, seq[(frame_tick >> 4) % seq.size()])
		# The original animation tables X-flip individual leg frames on slopes.
		sprite.flip_h = (direction < 0) != (slope_kind == 2)

func _crab_slope_kind() -> int:
	var signed = GenesisMath.s8(floor_angle)
	if signed >= 6:
		return 1 if direction < 0 else 2
	if signed <= -6:
		return 2 if direction < 0 else 1
	return 0

func _tick_buzz() -> void:
	if state == 0:
		timer -= 1
		if timer < 0:
			if buzz_state == 2:
				_buzz_fire()
			else:
				state = 1
				timer = 127
				vel_x = direction * 0x400
				anim_id = 1
	else:
		timer -= 1
		if timer < 0:
			buzz_state = 0
			direction = -direction
			timer = 59
			state = 0
			vel_x = 0
			anim_id = 0
			_update_facing()
		else:
			position.x += float(vel_x) / 256.0
			if buzz_state == 0:
				var p = player()
				if p != null and absi(p.pixel_x() - int(position.x)) < 96 and manager.is_world_x_on_screen(int(position.x)):
					buzz_state = 2
					timer = 29
					state = 0
					vel_x = 0
					anim_id = 0
	_update_buzz_animation()

func _buzz_fire() -> void:
	var missile_x = int(position.x) + direction * 20
	var missile_y = int(position.y) + 28
	manager.spawn_buzz_missile(missile_x, missile_y, direction * 0x200, self)
	buzz_state = 1
	timer = 59
	state = 0
	vel_x = 0
	anim_id = 2

func _update_buzz_animation() -> void:
	var base = 0
	match anim_id:
		1:
			base = 2
		2:
			base = 4
		_:
			base = 0
	set_sprite_frame(sprite, folder, base + ((frame_tick >> 1) & 1))
	_update_facing()


func _tick_chopper() -> void:
	# Object $2B - Chopper. Mirrors Chop_ChgSpeed: launch upward at -$700,
	# add $18 every frame, and restart the leap when it returns below spawn Y.
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + 0x18)

	if int(position.y) > chopper_original_y:
		position.y = chopper_original_y
		vel_y = -0x700

	var trigger_y = chopper_original_y - 0xC0
	if int(position.y) <= trigger_y:
		anim_id = 1 # fast
	else:
		anim_id = 0 # slow while rising / near the water line
		if vel_y >= 0:
			anim_id = 2 # still while falling

	match anim_id:
		1:
			set_sprite_frame(sprite, folder, (frame_tick >> 2) & 1)
		2:
			set_sprite_frame(sprite, folder, 0)
		_:
			set_sprite_frame(sprite, folder, (frame_tick >> 3) & 1)

func _tick_newtron() -> void:
	# Object $42 - Newtron. Secondary routine equivalents:
	# 0 distance check, 1 appearing, 2 dropping, 3 floor run, 4 green fire,
	# 5 detached horizontal flight.
	match state:
		0:
			_newtron_check_distance()
		1:
			_newtron_wait_drop()
		2:
			_newtron_drop()
		3:
			_newtron_move_on_floor()
		4:
			_newtron_green_fire()
		5:
			position.x += float(vel_x) / 256.0

func _newtron_face_player() -> void:
	var p = player()
	if p == null:
		return
	direction = 1 if p.pixel_x() >= int(position.x) else -1
	_update_facing()

func _newtron_check_distance() -> void:
	_newtron_face_player()
	set_sprite_frame(sprite, folder, 10) # Ani_Newt .blank
	var p = player()
	if p == null:
		return
	if absi(p.pixel_x() - int(position.x)) >= 128:
		return

	newtron_anim_tick = 0
	newtron_fired = false
	if subtype == 1:
		state = 4 # Newt_Action_GreenNewtron
	else:
		state = 1 # Newt_Action_WaitDrop

func _newtron_wait_drop() -> void:
	_newtron_face_player()
	newtron_anim_tick += 1
	var seq: Array[int] = [0, 1, 3, 4, 5]
	var step = mini(seq.size() - 1, int(newtron_anim_tick / 20))
	set_sprite_frame(sprite, folder, seq[step])

	# Newt_Action_WaitDrop begins ObjectFall once the appearing animation has
	# reached frame 4. Frame 4 is the fourth entry in the 20-tick script.
	if newtron_anim_tick >= 60:
		state = 2
		vel_y = 0

func _newtron_drop() -> void:
	set_sprite_frame(sprite, folder, 5)
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
	var hit = _floor_at(int(position.x), int(position.y) + 16)
	var distance = int(hit["distance"])
	if distance >= 0:
		return

	position.y += distance
	vel_y = 0
	state = 3
	grounded = true
	collision_active = true
	vel_x = direction * 0x200
	anim_id = 2

func _newtron_move_on_floor() -> void:
	position.x += float(vel_x) / 256.0
	var hit = _floor_at(int(position.x), int(position.y) + 16)
	var distance = int(hit["distance"])
	if distance < -8 or distance >= 12:
		state = 5 # Newt_Action_MoveInAir: keep horizontal velocity only
	else:
		position.y += distance
	set_sprite_frame(sprite, folder, 6 + (int(frame_tick / 3) & 1))

func _newtron_green_fire() -> void:
	# Green Newtron keeps the facing direction chosen by ChkDistance; unlike the
	# blue appearing routine, Newt_Action_GreenNewtron does not re-face Sonic.
	newtron_anim_tick += 1
	var seq: Array[int] = [0, 1, 1, 2, 1, 1, 0]
	var step = mini(seq.size() - 1, int(newtron_anim_tick / 20))
	var frame = seq[step]
	set_sprite_frame(sprite, folder, frame)

	if frame == 1:
		collision_active = true
	if frame == 2 and not newtron_fired:
		newtron_fired = true
		manager.spawn_newtron_missile(
			int(position.x) + direction * 0x14,
			int(position.y) - 8,
			direction * 0x200
		)

	# Ani_Newt .fires ends with afRoutine, advancing to Newt_GreenDelete.
	if newtron_anim_tick >= 140:
		request_delete(true)

func _tick_legacy_badnik() -> void:
	if frame_count > 1:
		set_sprite_frame(sprite, folder, (frame_tick >> 4) % frame_count)

func _ground_initial(radius: int) -> void:
	var hit = _floor_at(int(position.x), int(position.y) + radius)
	var distance = int(hit["distance"])
	if distance < 0:
		position.y += distance
		vel_y = 0
		grounded = true
		floor_angle = int(hit["angle"]) & 0xFF
	else:
		grounded = false
		vel_y = 0

func _tick_initial_fall(radius: int) -> void:
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
	var hit = _floor_at(int(position.x), int(position.y) + radius)
	var distance = int(hit["distance"])
	if distance < 0:
		position.y += distance
		vel_y = 0
		grounded = true
		floor_angle = int(hit["angle"]) & 0xFF

func _floor_at(x: int, y: int) -> Dictionary:
	return manager.collision.find_floor(x, y, 13, 16, 0, false)

func _update_facing() -> void:
	if sprite != null:
		sprite.flip_h = direction > 0

func _react_to_player() -> void:
	if not collision_active:
		return
	var p = player()
	if p == null or p.dead:
		return
	var half_w = 18
	var half_h = 16
	if object_id == 0x1E:
		half_w = 12
		half_h = 18
	elif object_id == 0x22:
		half_w = 24
		half_h = 12
	elif object_id == 0x2B:
		half_w = 12
		half_h = 16
	elif object_id == 0x42:
		half_w = 20
		half_h = 16 if subtype == 1 else 8
	if absi(p.pixel_x() - int(position.x)) > half_w + p.width_radius:
		return
	if absi(p.pixel_y() - int(position.y)) > half_h + p.height_radius:
		return

	# Jumping sets rolling in this port, matching Sonic's attacking ball state.
	# Merely walking off a ledge no longer destroys an enemy.
	var attacking = p.invincible_timer > 0 or p.rolling
	if attacking:
		var award = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(int(position.x))
