class_name S2ARZEnvironmentObject
extends GenesisLevelObject

var sprite: Sprite2D
var lower_sprite: Sprite2D
var state: int = 0
var timer: int = 0
var frame_counter: int = 0
var vel_y: int = 0
var base_x: int = 0
var base_y: int = 0
var lower_y: float = 0.0
var lower_vel_y: int = 0
var leaf_cooldown: int = 0
var bubble_timer: int = 0
var bubble_burst_left: int = 0
var bubble_delay: int = 0
var nudge: int = 0
var nudge_enabled: bool = false
var last_collision_y: int = 0
const BUBBLE_TYPES: Array[int] = [0,1,0,0,0,0,1,0,0,0,0,1,0,1,0,0,1,0]
var bubble_mini_count: int = -1
var bubble_type_start: int = 0
var bubble_allow_large: bool = false
var bubble_large_spawned: bool = false

func initialize_object() -> void:
	base_x = spawn_x
	base_y = spawn_y
	match object_id:
		0x1F:
			active_width = 0x20
			sprite = make_sprite("res://assets/objects/s2_arz/collapse/00.png", 1)
		0x23:
			active_width = 0x10
			sprite = make_sprite("res://assets/objects/s2_arz/falling_pillar/00.png", 1)
			lower_sprite = make_sprite("res://assets/objects/s2_arz/falling_pillar/01.png", 1)
			lower_y = 48.0
			lower_sprite.position.y = lower_y
		0x24:
			active_width = 0x10
			sprite = make_sprite("res://assets/objects/s2_arz/bubble_generator/00.png", 0)
			bubble_timer = subtype & 0x7F
			bubble_delay = 0
		0x2B:
			active_width = 0x10
			sprite = make_sprite("res://assets/objects/s2_arz/rising_pillar/00.png", 1)
			timer = 0
		0x2C:
			active_width = 0x80
			visible = false
		0x82:
			var shape_index: int = clampi((((subtype >> 3) & 0x0E) >> 1), 0, 1)
			active_width = 0x20 if shape_index == 0 else 0x1C
			sprite = make_sprite("res://assets/objects/s2_arz/platform82/%02d.png" % shape_index, 1)
			state = subtype & 0x0F
			nudge_enabled = state != 0 and state != 7
			subtype = subtype & 0x0F
			last_collision_y = int(position.y)

func tick() -> void:
	frame_counter += 1
	match object_id:
		0x1F: _tick_collapse()
		0x23: _tick_falling_pillar()
		0x24: _tick_bubbles()
		0x2B: _tick_rising_pillar()
		0x2C: _tick_leaves_trigger()
		0x82: _tick_platform82()

func _tick_collapse() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if state == 0:
		p.resolve_platform_top(int(position.x) - 0x20, int(position.x) + 0x20, int(position.y) - 16, record_index)
		if p.standing_on_object and p.support_record_index == record_index:
			state = 1; timer = 7
	elif state == 1:
		p.resolve_platform_top(int(position.x) - 0x20, int(position.x) + 0x20, int(position.y) - 16, record_index)
		timer -= 1
		if timer < 0:
			state = 2
			sprite.visible = false
			var delays: Array[int] = [0x16,0x1A,0x18,0x12,0x06,0x0E,0x0A,0x02]
			for i in range(delays.size()):
				manager.spawn_s2_arz_debris(int(position.x), int(position.y), "res://assets/objects/s2_arz/collapse_fragments/%02d.png" % i, 0, 0, 0x38, delays[i], 1)
			timer = 0x80
	else:
		timer -= 1
		if timer < 0:
			request_delete(false)

func _tick_falling_pillar() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	p.resolve_solid_box(int(position.x), int(position.y), 0x10, 0x20, true, record_index)
	var lower_center_y: int = int(position.y + lower_y)
	p.resolve_solid_box(int(position.x), lower_center_y, 0x10, 0x10, true, record_index)
	if state == 0 and absi(p.pixel_x() - int(position.x)) < 0x80:
		state = 1; timer = 8
	if state == 1:
		timer -= 1
		var shakes: Array[int] = [0,1,-1,1,0,-1,0,1]
		var idx: int = clampi(timer, 0, 7)
		lower_sprite.position.x = float(shakes[idx])
		if timer < 0:
			state = 2; lower_sprite.position.x = 0
	elif state == 2:
		lower_y += float(lower_vel_y) / 256.0
		lower_vel_y = GenesisMath.s16(lower_vel_y + 0x38)
		lower_sprite.position.y = lower_y
		var hit: Dictionary = manager.collision.find_floor_sensor(int(position.x), int(position.y + lower_y + 0x10), true, false)
		var dist: int = int(hit.get("distance", 0x7FFF))
		if dist < 0:
			lower_y += dist
			lower_vel_y = 0
			state = 3
			set_sprite_frame(lower_sprite, "s2_arz/falling_pillar", 2)
		lower_sprite.position.y = lower_y

func _tick_bubbles() -> void:
	if sprite != null:
		set_sprite_frame(sprite, "s2_arz/bubble_generator", (frame_counter >> 4) & 1)
	if manager == null or not manager.water_enabled:
		return
	sprite.visible = manager.water_surface_y < int(position.y)
	if not sprite.visible or not manager.is_world_x_on_screen(int(position.x), 32):
		return
	bubble_delay -= 1
	if bubble_delay >= 0:
		return
	if bubble_mini_count < 0:
		var random_word: int = manager.next_random_word()
		bubble_mini_count = random_word & 7
		while bubble_mini_count >= 6:
			random_word = manager.next_random_word()
			bubble_mini_count = random_word & 7
		bubble_type_start = random_word & 0x0C
		bubble_timer -= 1
		bubble_allow_large = bubble_timer < 0
		bubble_large_spawned = false
		if bubble_allow_large:
			bubble_timer = subtype & 0x7F
	bubble_delay = manager.next_random_word() & 0x1F
	var type_index: int = clampi(bubble_type_start + bubble_mini_count, 0, BUBBLE_TYPES.size() - 1)
	var type_id: int = BUBBLE_TYPES[type_index]
	if bubble_allow_large and not bubble_large_spawned:
		if (manager.next_random_word() & 3) == 0 or bubble_mini_count == 0:
			type_id = 2
			bubble_large_spawned = true
	var rx: int = (manager.next_random_word() & 0x0F) - 8
	manager.spawn_lz_bubble(int(position.x) + rx, int(position.y), type_id, manager.next_random_word() & 0x7F)
	bubble_mini_count -= 1
	if bubble_mini_count < 0:
		bubble_delay += (manager.next_random_word() & 0x7F) + 0x80

func _tick_rising_pillar() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if state == 0 and absi(p.pixel_x() - int(position.x)) < 0x40:
		state = 1; timer = 0
	elif state == 1:
		timer -= 1
		if timer < 0:
			timer = 3
			position.y -= 4
			var frame: int = mini(6, 1 + int((base_y - int(position.y)) / 4))
			set_sprite_frame(sprite, "s2_arz/rising_pillar", frame)
			if frame >= 6: state = 2
	var half_h: int = 0x18 + mini(0x18, maxi(0, base_y - int(position.y)))
	p.resolve_solid_box(int(position.x), int(position.y), 0x10, half_h, true, record_index)
	if state == 2 and p.standing_on_object and p.support_record_index == record_index:
		state = 3
		sprite.visible = false
		var fragment_velocities: Array[Vector2i] = [
			Vector2i(-0x200,-0x200),Vector2i(0x200,-0x200),
			Vector2i(-0x1C0,-0x1C0),Vector2i(0x1C0,-0x1C0),
			Vector2i(-0x180,-0x180),Vector2i(0x180,-0x180),
			Vector2i(-0x140,-0x140),Vector2i(0x140,-0x140),
			Vector2i(-0x100,-0x100),Vector2i(0x100,-0x100),
			Vector2i(-0x0C0,-0x0C0),Vector2i(0x0C0,-0x0C0),
			Vector2i(-0x080,-0x080),Vector2i(0x080,-0x080)]
		var fragment_delays: Array[int] = [0,0,0,0,4,4,8,8,0x0C,0x0C,0x10,0x10,0x14,0x14]
		for i in range(fragment_velocities.size()):
			var fv: Vector2i = fragment_velocities[i]
			manager.spawn_s2_arz_debris(int(position.x), int(position.y), "res://assets/objects/s2_arz/rising_fragments/%02d.png" % i, fv.x, fv.y, 0x18, fragment_delays[i], 1)
		p.rolling = true
		p.vel_y = -0x200
		timer = 0xA0
	elif state == 3:
		timer -= 1
		if timer < 0:
			request_delete(false)

func _tick_leaves_trigger() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead: return
	if leaf_cooldown > 0: leaf_cooldown -= 1; return
	var half_w: int = 32
	var half_h: int = 32
	match subtype & 3:
		1: half_w = 64; half_h = 32
		2: half_w = 128; half_h = 32
	if absi(p.pixel_x() - int(position.x)) > half_w + p.width_radius: return
	if absi(p.pixel_y() - int(position.y)) > half_h + p.height_radius: return
	if absi(p.vel_x) < 0x200 and absi(p.vel_y) < 0x200: return
	var speeds: Array[Vector2i] = [Vector2i(-0x80,-0x80),Vector2i(0xC0,-0x40),Vector2i(-0xC0,0x40),Vector2i(0x80,0x80)]
	for i in range(4):
		var rx: int = (manager.next_random_word() & 0x0F) - 8
		var ry: int = (manager.next_random_word() & 0x0F) - 8
		var vx: int = speeds[i].x
		if p.facing_left: vx = -vx
		manager.spawn_s2_arz_leaf(p.pixel_x()+rx, p.pixel_y()+ry, vx, speeds[i].y, manager.next_random_word() & 1)
	leaf_cooldown = 16

func _tick_platform82() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var half_h: int = 8 if active_width == 0x20 else 0x30
	if state == 1:
		if timer == 0 and p.standing_on_object and p.support_record_index == record_index:
			timer = 0x1E
		elif timer > 0:
			timer -= 1
			if timer == 0:
				state = 2
				nudge_enabled = false
	elif state == 2:
		position.y += float(vel_y) / 256.0
		vel_y = GenesisMath.s16(vel_y + 8)
		var hit: Dictionary = manager.collision.find_floor_sensor(int(position.x), int(position.y) + half_h, true, false)
		var d: int = int(hit.get("distance", 0x7FFF))
		if d < 0:
			position.y += d + 1
			vel_y = 0
			state = 0
	if nudge_enabled:
		if p.standing_on_object and p.support_record_index == record_index:
			nudge = mini(0x40, nudge + 4)
		else:
			nudge = maxi(0, nudge - 4)
	else:
		nudge = 0
	var bob: int = (GenesisMath.sine(nudge & 0xFF) * 4) >> 8
	var center_y: int = int(position.y) + bob
	if sprite != null:
		sprite.position.y = float(bob)
	var dy: int = center_y - last_collision_y
	p.move_with_supported_object(record_index, 0, dy, int(position.x) - active_width, int(position.x) + active_width, center_y - half_h)
	p.resolve_solid_box(int(position.x), center_y, active_width, half_h, true, record_index)
	last_collision_y = center_y
