class_name S2ARZBadnikObject
extends GenesisLevelObject

var sprite: Sprite2D
var frame_counter: int = 0
var state: int = 0
var timer: int = 0
var vel_x: int = 0
var vel_y: int = 0
var move_timer: int = 0
var bubble_timer: int = 0
var wall_sprites: Array[Sprite2D] = []

func initialize_object() -> void:
	match object_id:
		0x8C:
			active_width = 12
			sprite = make_sprite("res://assets/objects/s2_arz/whisp/00.png", 2)
			timer = 0x10
			move_timer = 4
		0x8D, 0x8E:
			active_width = 16
			sprite = make_sprite("res://assets/objects/s2_arz/grounder/00.png", 2)
			# Obj8D_Init clears the source Y-flip bit used by the placement record.
			sprite.flip_v = false
			_snap_to_floor(20)
			if object_id == 0x8E:
				_start_grounder_walk()
			else:
				sprite.visible = false
				_create_grounder_wall()
		0x91:
			active_width = 16
			sprite = make_sprite("res://assets/objects/s2_arz/chopchop/00.png", 2)
			move_timer = 0x200
			bubble_timer = 0x50
			vel_x = 0x40 if x_flip else -0x40

func tick() -> void:
	frame_counter += 1
	match object_id:
		0x8C: _tick_whisp()
		0x8D, 0x8E: _tick_grounder()
		0x91: _tick_chopchop()
	if alive: _react_to_player()

func _tick_whisp() -> void:
	set_sprite_frame(sprite, "s2_arz/whisp", (frame_counter >> 1) & 1)
	if state == 0:
		timer -= 1
		if timer < 0:
			move_timer -= 1
			if move_timer < 0:
				state = 3; vel_x = -0x200; vel_y = -0x200
			else:
				state = 1; timer = 0x60; vel_y = -0x100
	elif state == 1:
		var p: SonicPlayer = player()
		if p != null:
			vel_x = clampi(vel_x + (-0x10 if p.pixel_x() < int(position.x) else 0x10), -0x200, 0x200)
			vel_y = clampi(vel_y + (-0x10 if p.pixel_y() < int(position.y) else 0x10), -0x200, 0x200)
			sprite.flip_h = p.pixel_x() > int(position.x)
		position.x += float(vel_x)/256.0; position.y += float(vel_y)/256.0
		timer -= 1
		if timer < 0:
			state = 2; timer = manager.next_random_word() & 0x1F; vel_x = 0; vel_y = 0
	elif state == 2:
		timer -= 1
		if timer < 0: state = 0; timer = 0
	else:
		position.x += float(vel_x)/256.0; position.y += float(vel_y)/256.0

func _tick_grounder() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if state == 0:
		if absi(p.pixel_x() - int(position.x)) <= 0x60:
			_break_grounder_wall()
			state = 1; timer = 16; sprite.visible = true; set_sprite_frame(sprite, "s2_arz/grounder", 0)
	elif state == 1:
		timer -= 1
		set_sprite_frame(sprite, "s2_arz/grounder", 0 if timer > 8 else 1)
		if timer < 0: _start_grounder_walk()
	elif state == 2:
		position.x += float(vel_x)/256.0
		var hit: Dictionary = manager.collision.find_floor_sensor(int(position.x), int(position.y)+20, true, false)
		var dist: int = int(hit.get("distance", 0x7FFF))
		if dist >= -1 and dist < 12:
			position.y += dist
			set_sprite_frame(sprite, "s2_arz/grounder", 2 + ((frame_counter >> 2) % 3))
		else:
			state = 3; timer = 0x3B
	elif state == 3:
		timer -= 1
		if timer < 0:
			vel_x = -vel_x; sprite.flip_h = not sprite.flip_h; state = 2

func _create_grounder_wall() -> void:
	var offsets: Array[Vector2i] = [Vector2i(0,-0x14),Vector2i(0x10,-4),Vector2i(0,0x0C),Vector2i(-0x10,-4)]
	for offset in offsets:
		var wall: Sprite2D = Sprite2D.new()
		wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wall.centered = true
		wall.z_index = 3
		wall.position = Vector2(offset.x, offset.y)
		var path: String = "res://assets/objects/s2_arz/grounder_wall/00.png"
		if ResourceLoader.exists(path):
			wall.texture = load(path)
		add_child(wall)
		wall_sprites.append(wall)

func _break_grounder_wall() -> void:
	var offsets: Array[Vector2i] = [Vector2i(0,-0x14),Vector2i(0x10,-4),Vector2i(0,0x0C),Vector2i(-0x10,-4)]
	var wall_velocities: Array[Vector2i] = [Vector2i(0x100,-0x200),Vector2i(0x100,-0x100),Vector2i(-0x100,-0x200),Vector2i(-0x100,-0x100)]
	for i in range(offsets.size()):
		var offset: Vector2i = offsets[i]
		var velocity: Vector2i = wall_velocities[i]
		manager.spawn_s2_arz_debris(int(position.x)+offset.x, int(position.y)+offset.y, "res://assets/objects/s2_arz/grounder_wall/00.png", velocity.x, velocity.y, 0x38, 0, 3)
	for wall in wall_sprites:
		if is_instance_valid(wall):
			wall.queue_free()
	wall_sprites.clear()
	var rock_frames: Array[int] = [0,2,0,1,0]
	var rock_velocities: Array[Vector2i] = [Vector2i(-0x100,-0x400),Vector2i(0x400,-0x300),Vector2i(0x200,0),Vector2i(-0x300,-0x100),Vector2i(-0x300,-0x300)]
	for i in range(rock_frames.size()):
		var rv: Vector2i = rock_velocities[i]
		manager.spawn_s2_arz_debris(int(position.x), int(position.y), "res://assets/objects/s2_arz/grounder_rocks/%02d.png" % rock_frames[i], rv.x, rv.y, 0x38, 0, 3)

func _start_grounder_walk() -> void:
	var p: SonicPlayer = player()
	state = 2
	vel_x = -0x100 if p == null or p.pixel_x() < int(position.x) else 0x100
	sprite.flip_h = vel_x > 0
	set_sprite_frame(sprite, "s2_arz/grounder", 2)

func _snap_to_floor(radius: int) -> void:
	var hit: Dictionary = manager.collision.find_floor_sensor(int(position.x), int(position.y)+radius, true, false)
	var d: int = int(hit.get("distance", 0x7FFF))
	if d < 0: position.y += d

func _tick_chopchop() -> void:
	set_sprite_frame(sprite, "s2_arz/chopchop", int(frame_counter / 5) & 1)
	bubble_timer -= 1
	if bubble_timer <= 0:
		bubble_timer = 0x50
		manager.spawn_lz_bubble(int(position.x) + (-0x14 if sprite.flip_h else 0x14), int(position.y)+6, 0, frame_counter & 0x7F)
	if state == 0:
		move_timer -= 1
		if move_timer < 0:
			move_timer = 0x200; vel_x = -vel_x; sprite.flip_h = not sprite.flip_h
		position.x += float(vel_x)/256.0
		var p: SonicPlayer = player()
		if p != null:
			var dx: int = p.pixel_x() - int(position.x)
			var dy: int = p.pixel_y() - int(position.y)
			var toward: bool = (dx < 0 and vel_x < 0) or (dx > 0 and vel_x > 0)
			if absi(dy) < 0x20 and absi(dx) >= 0x20 and absi(dx) < 0xA0 and toward:
				state = 1; timer = 0x10; vel_x = 0
	elif state == 1:
		timer -= 1
		if timer < 0:
			var p: SonicPlayer = player()
			if p != null:
				vel_x = -0x200 if p.pixel_x() < int(position.x) else 0x200
				vel_y = -0x80 if p.pixel_y() < int(position.y) else 0x80
				sprite.flip_h = vel_x > 0
			state = 2
	else:
		position.x += float(vel_x)/256.0; position.y += float(vel_y)/256.0

func _react_to_player() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead or (object_id == 0x8D and not sprite.visible): return
	# Retail collision_flags: Whisp $0B => 8x8, Grounder/ChopChop $02 => 12x20.
	var hw: int = 12
	var hh: int = 20
	if object_id == 0x8C:
		hw = 8
		hh = 8
	if absi(p.pixel_x()-int(position.x)) > hw+p.width_radius: return
	if absi(p.pixel_y()-int(position.y)) > hh+p.height_radius: return
	if p.invincible_timer > 0 or p.rolling:
		var award: int = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0: p.vel_y = -p.vel_y
		else: p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(int(position.x))
