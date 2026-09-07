class_name S2ARZArrowObject
extends GenesisLevelObject

var sprite: Sprite2D
var anim_state: int = 0
var anim_timer: int = 0
var projectile_mode: bool = false
var loop_frame: int = 1
var vel_x: int = 0

func initialize_object() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/s2_arz/arrow/01.png", 2)
	sprite.flip_h = x_flip

func setup_projectile(owner: SonicObjectManager, world_x: int, world_y: int, horizontal_velocity: int, face_left: bool) -> void:
	manager = owner
	record_index = -1
	object_id = 0x22
	position = Vector2(world_x, world_y)
	spawn_x = world_x
	spawn_y = world_y
	projectile_mode = true
	vel_x = horizontal_velocity
	x_flip = face_left
	active_width = 16
	sprite = make_sprite("res://assets/objects/s2_arz/arrow/00.png", 4)
	sprite.flip_h = face_left

func suppress_central_despawn() -> bool:
	return projectile_mode

func tick() -> void:
	if projectile_mode:
		_tick_arrow()
	else:
		_tick_shooter()

func _tick_shooter() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var near_player: bool = absi(p.pixel_x() - int(position.x)) < 0x40
	if anim_state == 0:
		set_sprite_frame(sprite, "s2_arz/arrow", 1)
		if near_player:
			anim_state = 1
			anim_timer = 3
			loop_frame = 1
	elif anim_state == 1:
		# Ani_obj22 animation 1: 1,2 loop while a player remains inside $40.
		anim_timer -= 1
		if anim_timer < 0:
			anim_timer = 3
			loop_frame = 2 if loop_frame == 1 else 1
			set_sprite_frame(sprite, "s2_arz/arrow", loop_frame)
		if not near_player:
			anim_state = 2
			anim_timer = 7
			set_sprite_frame(sprite, "s2_arz/arrow", 3)
	elif anim_state == 2:
		# Ani_obj22 animation 2: 3,4,$FC,4,3,1,$FD,0.  The $FC event is
		# where the retail routine creates the arrow projectile.
		anim_timer -= 1
		if anim_timer < 0:
			anim_timer = 7
			anim_state = 3
			set_sprite_frame(sprite, "s2_arz/arrow", 4)
	elif anim_state == 3:
		anim_timer -= 1
		if anim_timer < 0:
			var speed: int = -0x400 if x_flip else 0x400
			manager.spawn_s2_arz_arrow(int(position.x), int(position.y), speed, x_flip)
			anim_state = 4
			anim_timer = 7
			set_sprite_frame(sprite, "s2_arz/arrow", 4)
	elif anim_state == 4:
		anim_timer -= 1
		if anim_timer < 0:
			anim_state = 5; anim_timer = 7
			set_sprite_frame(sprite, "s2_arz/arrow", 3)
	elif anim_state == 5:
		anim_timer -= 1
		if anim_timer < 0:
			anim_state = 6; anim_timer = 7
			set_sprite_frame(sprite, "s2_arz/arrow", 1)
	else:
		anim_timer -= 1
		if anim_timer < 0:
			anim_state = 0
			set_sprite_frame(sprite, "s2_arz/arrow", 1)

func _tick_arrow() -> void:
	position.x += float(vel_x) / 256.0
	var probe_x: int = int(position.x) + (8 if vel_x > 0 else -8)
	var hit: Dictionary = {}
	if vel_x > 0:
		hit = manager.collision.find_right_wall_sensor(probe_x, int(position.y), false)
	else:
		hit = manager.collision.find_left_wall_sensor(probe_x, int(position.y), false)
	if int(hit.get("distance", 8)) < 0:
		alive = false
		queue_free()
		return
	var p: SonicPlayer = player()
	if p != null and not p.dead:
		# Collision flag $9B uses Touch_Sizes[$1B] = 8x4 half extents.
		if absi(p.pixel_x() - int(position.x)) <= 8 + p.width_radius and absi(p.pixel_y() - int(position.y)) <= 4 + p.height_radius:
			p.apply_hazard_hit(int(position.x))
	if manager != null and absi(int(position.x) - manager.current_screen_x) > 900:
		alive = false
		queue_free()
