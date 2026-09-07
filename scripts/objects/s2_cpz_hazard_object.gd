class_name S2CPZHazardObject
extends GenesisLevelObject

# Phase 92: remaining retail CPZ1 hazards/Badniks.
# $1D Blue Droplets, $A5 Spiny, $A6 wall Spiny, $A7 Grabber.

var sprite: Sprite2D
var aux_sprite: Sprite2D
var hanger_sprite: Sprite2D
var grabber_string: Line2D
var frame_tick := 0

# Obj1D controller keeps the source-created six child droplets together.
var droplets: Array = []

# Spiny state.
var spiny_vel_x := 0
var spiny_vel_y := 0
var spiny_turn_timer := 0
var spiny_cooldown := 0
var spiny_shot_timer := -1

# Grabber state.
var grabber_state := 0 # 0 patrol, 1 pause, 2 descend/return, 3 carrying, 4 hold
var grabber_turn_timer := 0
var grabber_timer := 0
var grabber_vel_x := 0
var grabber_vel_y := 0
var grabber_saved_vel_x := 0
var grabbed_player := false

func initialize_object() -> void:
	match object_id:
		0x1D: _init_droplets()
		0xA5, 0xA6: _init_spiny()
		0xA7: _init_grabber()

func tick() -> void:
	frame_tick += 1
	match object_id:
		0x1D: _tick_droplets()
		0xA5, 0xA6: _tick_spiny()
		0xA7: _tick_grabber()

func request_delete(mark_destroyed: bool = false) -> void:
	if object_id == 0xA7:
		_release_grabbed_player(true)
	super.request_delete(mark_destroyed)

# -----------------------------------------------------------------------------
# Object $1D - CPZ blue jumping droplets
# -----------------------------------------------------------------------------
func _init_droplets() -> void:
	active_width = 0x80
	visible = false
	var straight = (subtype & 0xF0) != 0
	var count = (subtype & 0x0F) + 1
	var accel_x = -0x0B if x_flip else 0x0B
	var offset_x = -0x60 if x_flip else 0x60
	for i in range(count):
		var s = make_sprite("res://assets/objects/s2_cpz/blue/00.png", 1)
		var q = {
			"sprite": s,
			"x": float(spawn_x), "y": float(spawn_y),
			"vx": 0, "vy": -0x480,
			"delay": i * 3, "wait_reload": 0x3B,
			"ax": accel_x, "offset": offset_x,
			"straight": straight, "moving": false,
		}
		droplets.append(q)

func _tick_droplets() -> void:
	var p = player()
	for i in range(droplets.size()):
		var q: Dictionary = droplets[i]
		if not bool(q["moving"]):
			q["delay"] = int(q["delay"]) - 1
			if int(q["delay"]) < 0:
				q["moving"] = true
				q["delay"] = int(q["wait_reload"])
		else:
			q["x"] = float(q["x"]) + float(int(q["vx"])) / 256.0
			q["y"] = float(q["y"]) + float(int(q["vy"])) / 256.0
			q["vy"] = GenesisMath.s16(int(q["vy"]) + 0x18)
			if bool(q["straight"]):
				if int(q["vy"]) == 0:
					q["x"] = float(spawn_x + int(q["offset"]))
				if float(q["y"]) >= float(spawn_y):
					q["x"] = float(spawn_x)
					q["y"] = float(spawn_y)
					q["vy"] = -0x480
					q["vx"] = 0
			else:
				q["vx"] = GenesisMath.s16(int(q["vx"]) + int(q["ax"]))
				if int(q["vy"]) == 0:
					q["ax"] = -int(q["ax"])
				if float(q["y"]) >= float(spawn_y):
					q["x"] = float(spawn_x)
					q["y"] = float(spawn_y)
					q["vy"] = -0x480
					q["vx"] = 0
					q["moving"] = false
		var s = q["sprite"] as Sprite2D
		s.position = Vector2(float(q["x"]) - spawn_x, float(q["y"]) - spawn_y)
		if p != null and not p.dead:
			if absi(p.pixel_x() - int(float(q["x"]))) <= 8 + p.width_radius and absi(p.pixel_y() - int(float(q["y"]))) <= 8 + p.height_radius:
				p.apply_hazard_hit(int(float(q["x"])))
		droplets[i] = q

# -----------------------------------------------------------------------------
# Objects $A5/$A6 - CPZ Spiny floor/wall variants
# -----------------------------------------------------------------------------
func _init_spiny() -> void:
	active_width = 16
	spiny_turn_timer = 0x80
	spiny_cooldown = 0
	spiny_shot_timer = -1
	if object_id == 0xA5:
		spiny_vel_x = -0x40
		spiny_vel_y = 0
		sprite = make_sprite("res://assets/objects/s2_cpz/spiny/00.png", 1)
	else:
		spiny_vel_x = 0
		spiny_vel_y = -0x40
		sprite = make_sprite("res://assets/objects/s2_cpz/spiny/03.png", 1)
	_update_spiny_facing()

func _tick_spiny() -> void:
	if spiny_shot_timer >= 0:
		spiny_shot_timer -= 1
		if spiny_shot_timer == 0x14:
			_spawn_spiny_shot()
		if spiny_shot_timer < 0:
			spiny_cooldown = 0x40
	else:
		if spiny_cooldown > 0:
			spiny_cooldown -= 1
		elif _spiny_player_in_range():
			spiny_shot_timer = 0x28
			_set_spiny_frame(2 if object_id == 0xA5 else 5)
			_react_enemy(16, 12)
			return

		spiny_turn_timer -= 1
		if spiny_turn_timer <= 0:
			spiny_turn_timer = 0x80
			if object_id == 0xA5:
				spiny_vel_x = -spiny_vel_x
			else:
				spiny_vel_y = -spiny_vel_y
		position.x += float(spiny_vel_x) / 256.0
		position.y += float(spiny_vel_y) / 256.0
		_update_spiny_facing()
		var phase = int(frame_tick / 10)
		_set_spiny_frame((phase & 1) if object_id == 0xA5 else 3 + (phase & 1))
	_react_enemy(16, 12)

func _spiny_player_in_range() -> bool:
	var p = player()
	return p != null and absi(int(position.x) - p.pixel_x()) < 0x60

func _update_spiny_facing() -> void:
	if sprite == null:
		return
	var p = player()
	if p != null:
		x_flip = p.pixel_x() < int(position.x)
	sprite.flip_h = x_flip

func _set_spiny_frame(frame: int) -> void:
	set_sprite_frame(sprite, "s2_cpz/spiny", frame)
	sprite.flip_h = x_flip

func _spawn_spiny_shot() -> void:
	var p = player()
	var direction = -1 if p != null and p.pixel_x() < int(position.x) else 1
	if object_id == 0xA5:
		manager.spawn_s2_cpz_spiny_projectile(int(position.x), int(position.y), direction * 0x100, -0x300, direction < 0)
	else:
		manager.spawn_s2_cpz_spiny_projectile(int(position.x), int(position.y), direction * 0x300, 0, direction < 0)

# -----------------------------------------------------------------------------
# Object $A7 - Grabber
# -----------------------------------------------------------------------------
func _init_grabber() -> void:
	active_width = 20
	grabber_vel_x = 0x40 if x_flip else -0x40
	grabber_turn_timer = 0xFF
	grabber_state = 0
	sprite = make_sprite("res://assets/objects/s2_cpz/grabber/00.png", 2)
	aux_sprite = make_sprite("res://assets/objects/s2_cpz/grabber/03.png", 3) # ObjA8 is displayed after the parent at the same source priority; keep the rear/second leg set visible over the precomposited body.
	hanger_sprite = make_sprite("res://assets/objects/s2_cpz/grabber/02.png", 0)
	grabber_string = Line2D.new()
	grabber_string.width = 1.0
	grabber_string.default_color = Color(0.88, 0.88, 0.88, 1.0)
	grabber_string.z_index = 0
	add_child(grabber_string)
	_update_grabber_children()

func _tick_grabber() -> void:
	match grabber_state:
		0:
			if _grabber_should_attack():
				grabber_state = 1
				grabber_saved_vel_x = grabber_vel_x
				grabber_vel_x = 0
				grabber_timer = 0x10
			else:
				grabber_turn_timer -= 1
				if grabber_turn_timer < 0:
					grabber_turn_timer = 0xFF
					grabber_vel_x = -grabber_vel_x
					x_flip = not x_flip
		1:
			grabber_timer -= 1
			if grabber_timer < 0:
				grabber_state = 2
				grabber_vel_y = 0x200
				grabber_timer = 0x40
		2:
			grabber_timer -= 1
			if grabber_timer == 0x20:
				grabber_vel_y = -grabber_vel_y
			if not grabbed_player:
				_try_grab_player()
			if grabbed_player:
				grabber_state = 3
				if grabber_vel_y > 0:
					grabber_vel_y = -grabber_vel_y
				grabber_timer = mini(grabber_timer + 1, 0x40)
			elif grabber_timer <= 0:
				grabber_state = 0
				grabber_vel_y = 0
				grabber_vel_x = grabber_saved_vel_x
		3:
			grabber_timer -= 1
			_hold_grabbed_player()
			if grabber_timer <= 0:
				grabber_state = 4
				grabber_vel_y = 0
				grabber_timer = 0x20
		4:
			grabber_timer -= 1
			_hold_grabbed_player()
			var p = player()
			if grabber_timer <= 0 or (p != null and p.jump_pressed):
				_release_grabbed_player(false)
				grabber_state = 0
				grabber_vel_x = grabber_saved_vel_x
				grabber_turn_timer = 0xFF

	position.x += float(grabber_vel_x) / 256.0
	position.y += float(grabber_vel_y) / 256.0
	_update_grabber_children()
	_react_enemy(18, 16)

func _grabber_should_attack() -> bool:
	var p = player()
	if p == null or p.dead:
		return false
	var dx = int(position.x) - p.pixel_x()
	var dy = int(position.y) - p.pixel_y()
	return absi(dx) < 0x40 and dy < 0 and dy > -0x80

func _try_grab_player() -> void:
	var p = player()
	if p == null or p.dead or p.hurt_state:
		return
	# Legs are the source collision child. Keep the native grab window narrow.
	if absi(p.pixel_x() - int(position.x)) <= 13 + p.width_radius and absi(p.pixel_y() - (int(position.y) + 18)) <= 12 + p.height_radius:
		grabbed_player = true
		p.object_control_override = true
		p.clear_object_support()
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		p.in_air = true
		p.rolling = false
		p.width_radius = SonicPlayer.SONIC_WIDTH
		p.height_radius = SonicPlayer.SONIC_HEIGHT
		set_sprite_frame(sprite, "s2_cpz/grabber", 1)

func _hold_grabbed_player() -> void:
	if not grabbed_player:
		return
	var p = player()
	if p == null or p.dead:
		grabbed_player = false
		return
	p.force_set_pixel_position(int(position.x), int(position.y) + 24)
	p.vel_x = 0
	p.vel_y = 0

func _release_grabbed_player(become_airborne: bool) -> void:
	if not grabbed_player:
		return
	var p = player()
	if p != null:
		p.object_control_override = false
		p.in_air = true
		if become_airborne:
			p.vel_y = 0
	grabbed_player = false
	if sprite != null:
		set_sprite_frame(sprite, "s2_cpz/grabber", 0)

func _update_grabber_children() -> void:
	if sprite != null:
		sprite.flip_h = x_flip
	if aux_sprite != null:
		aux_sprite.flip_h = x_flip
		aux_sprite.position = Vector2.ZERO
		# Retail ObjA8 inherits the parent's mapping_frame then adds 3. The
		# child therefore alternates frames 3/4 with the Grabber body instead
		# of remaining permanently on the first legs mapping.
		set_sprite_frame(aux_sprite, "s2_cpz/grabber", 4 if grabbed_player else 3)
	if hanger_sprite != null:
		hanger_sprite.position = Vector2(0, float(spawn_y - 12) - position.y)
	if grabber_string != null:
		var top_y = float(spawn_y - 8) - position.y
		grabber_string.points = PackedVector2Array([Vector2(0, top_y), Vector2(0, -8)])

# Common enemy collision response matching the existing EHZ native badniks.
func _react_enemy(half_w: int, half_h: int) -> void:
	if grabbed_player:
		return
	var p = player()
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - int(position.x)) > half_w + p.width_radius or absi(p.pixel_y() - int(position.y)) > half_h + p.height_radius:
		return
	if p.invincible_timer > 0 or p.rolling:
		var award = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
		_release_grabbed_player(true)
		request_delete(respawn_enabled)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(int(position.x))
