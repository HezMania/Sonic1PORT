class_name S2EHZProjectile
extends GenesisLevelObject

var sprite: Sprite2D
var kind := 0 # 0 Buzzer shot, 1 Coconut
var vel_x := 0
var vel_y := 0
var frame_tick := 0
var life := 0

func setup_buzzer(owner: SonicObjectManager, x: int, y: int, horizontal_velocity: int, face_left: bool) -> void:
	manager = owner
	record_index = -830000 - owner.elapsed_frames - owner.transient_objects.size()
	object_id = 0x4B
	kind = 0
	alive = true
	position = Vector2(x, y)
	vel_x = horizontal_velocity
	vel_y = 0x180
	active_width = 16
	sprite = make_sprite("res://assets/objects/s2_ehz/buzzer/05.png", 1)
	sprite.flip_h = face_left

func setup_coconut(owner: SonicObjectManager, x: int, y: int, horizontal_velocity: int, face_left: bool) -> void:
	manager = owner
	record_index = -831000 - owner.elapsed_frames - owner.transient_objects.size()
	object_id = 0x98
	kind = 1
	alive = true
	position = Vector2(x, y)
	vel_x = horizontal_velocity
	vel_y = -0x100
	active_width = 8
	sprite = make_sprite("res://assets/objects/s2_ehz/coconuts/03.png", 1)
	sprite.flip_h = face_left

func tick() -> void:
	frame_tick += 1
	life += 1
	if kind == 0:
		position.x += float(vel_x) / 256.0
		position.y += float(vel_y) / 256.0
		set_sprite_frame(sprite, "s2_ehz/buzzer", 5 + ((frame_tick >> 2) & 1))
	else:
		# Obj98_CoconutFall applies +$20 gravity before ObjectMove.
		vel_y = GenesisMath.s16(vel_y + 0x20)
		position.x += float(vel_x) / 256.0
		position.y += float(vel_y) / 256.0
	_hurt_player()
	if life > 600 or absi(int(position.x) - manager.current_screen_x) > 640 or int(position.y) > manager.current_screen_y + 512:
		request_delete(false)

func _hurt_player() -> void:
	var p = player()
	if p == null or p.dead:
		return
	var half = 8 if kind == 1 else 10
	if absi(p.pixel_x() - int(position.x)) <= half + p.width_radius and absi(p.pixel_y() - int(position.y)) <= half + p.height_radius:
		p.apply_hazard_hit(int(position.x))
