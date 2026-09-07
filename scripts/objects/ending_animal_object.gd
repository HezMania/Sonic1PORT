class_name EndingAnimalObject
extends GenesisLevelObject

# Object $28 with ending-only subtypes $0A-$14.
# The source positions these animals in levels/ending and wakes most of them
# when Sonic comes within 184 pixels from the right.

const SPEEDS := {
	0x0A: Vector2i(-0x440, -0x400), 0x0B: Vector2i(-0x440, -0x400),
	0x0C: Vector2i(-0x440, -0x400), 0x0D: Vector2i(-0x300, -0x400),
	0x0E: Vector2i(-0x300, -0x400), 0x0F: Vector2i(-0x180, -0x300),
	0x10: Vector2i(-0x180, -0x300), 0x11: Vector2i(-0x140, -0x180),
	0x12: Vector2i(-0x1C0, -0x300), 0x13: Vector2i(-0x200, -0x300),
	0x14: Vector2i(-0x280, -0x380),
}

var sprite: Sprite2D
var vel_x := 0
var vel_y := 0
var base_vel_x := 0
var base_vel_y := 0
var activated := false
var frame_id := 0
var frame_timer := 7
var double_hop := false

func initialize_object() -> void:
	var speed: Vector2i = SPEEDS.get(subtype, Vector2i(-0x200, -0x300))
	base_vel_x = speed.x
	base_vel_y = speed.y
	vel_x = base_vel_x
	vel_y = base_vel_y
	active_width = 8
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.flip_h = true
	sprite.z_index = 0
	add_child(sprite)
	_set_frame(0)
	# DoubleHop ($14) starts moving immediately; all other ending animals wait
	# for Anml_CheckCloseToSonic.
	activated = subtype == 0x14

func suppress_central_despawn() -> bool:
	return true

func tick() -> void:
	if not alive:
		return
	if not activated:
		if _close_to_sonic():
			activated = true
		else:
			_update_facing_if_stationary()
			_return_or_delete()
			return

	match subtype:
		0x0A, 0x0B:
			_tick_fly_left()
		0x0C:
			_tick_stay_face(true)
		0x0D:
			_tick_hop_left()
		0x0E, 0x10, 0x12:
			_tick_stay_face(false)
		0x0F, 0x11:
			_tick_hop_around()
		0x13:
			_tick_double_fly()
		0x14:
			_tick_double_hop()
		_:
			_tick_hop_left()
	_return_or_delete()

func _close_to_sonic() -> bool:
	var p := player()
	return p != null and (p.pixel_x() - int(position.x) - 184) < 0

func _tick_fly_left() -> void:
	_object_fall(0x18)
	if vel_y >= 0 and _land_on_floor():
		vel_y = base_vel_y
	_animate_flying()

func _tick_stay_face(slow: bool) -> void:
	vel_x = 0
	_object_fall(0x18 if slow else 0x38)
	_bounce_frame()
	_face_sonic()
	if slow:
		_animate_flying()

func _tick_hop_left() -> void:
	vel_x = base_vel_x
	_object_fall(0x38)
	_bounce_frame()

func _tick_hop_around() -> void:
	_object_fall(0x38)
	_set_frame(1 if vel_y < 0 else 0)
	if vel_y >= 0 and _land_on_floor():
		vel_x = -vel_x
		sprite.flip_h = not sprite.flip_h
		vel_y = base_vel_y

func _tick_double_fly() -> void:
	_object_fall(0x18)
	if vel_y >= 0 and _land_on_floor():
		double_hop = not double_hop
		if not double_hop:
			vel_x = -vel_x
			sprite.flip_h = not sprite.flip_h
		vel_y = base_vel_y
	_animate_flying()

func _tick_double_hop() -> void:
	_object_fall(0x38)
	_set_frame(1 if vel_y < 0 else 0)
	if vel_y >= 0 and _land_on_floor():
		double_hop = not double_hop
		if not double_hop:
			vel_x = -vel_x
			sprite.flip_h = not sprite.flip_h
		vel_y = base_vel_y

func _object_fall(gravity: int) -> void:
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + gravity)

func _bounce_frame() -> void:
	_set_frame(1 if vel_y < 0 else 0)
	if vel_y >= 0 and _land_on_floor():
		vel_y = base_vel_y

func _land_on_floor() -> bool:
	var hit = manager.collision.find_floor(int(position.x), int(position.y) + 12, 13, 16, 0, false)
	var distance := int(hit["distance"])
	if distance >= 0:
		return false
	position.y += distance
	return true

func _animate_flying() -> void:
	frame_timer -= 1
	if frame_timer < 0:
		frame_timer = 1
		_set_frame(1 - frame_id)

func _update_facing_if_stationary() -> void:
	if subtype in [0x0C, 0x0E, 0x10, 0x12]:
		_face_sonic()

func _face_sonic() -> void:
	var p := player()
	if p != null:
		sprite.flip_h = int(position.x) >= p.pixel_x()

func _set_frame(value: int) -> void:
	frame_id = clampi(value, 0, 2)
	if sprite != null:
		sprite.texture = SourceObjectArt.ending_animal_texture(subtype, frame_id)

func _return_or_delete() -> void:
	var p := player()
	if p == null:
		return
	# Anml_End_ChkDel keeps animals while Sonic is to their right or while they
	# remain within roughly one screen plus 64 pixels after he passes left.
	var dx := int(position.x) - p.pixel_x()
	if dx >= 0 and dx < 384 and not manager.is_world_x_on_screen(int(position.x), 32):
		request_delete(false)
