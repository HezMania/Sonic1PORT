class_name AnimalObject
extends Node2D

# Object $28. Phase 14 keeps the source per-zone animal table instead of
# hard-coding GHZ. Animals first launch straight upward at -$400; after their
# first floor hit they receive their species base speeds/gravity class.
var manager: SonicObjectManager
var alive := true
var animal_id := 0
var base_vel_x := 0
var base_vel_y := 0
var vel_x := 0
var vel_y := -0x400
var first_floor_hit := false
var frame_timer := 7
var frame_id := 2
var sprite: Sprite2D
var folder := "rabbit"
var is_prison_animal := false
var prison_delay := 0

func setup(owner: SonicObjectManager, world_x: int, world_y: int, type_id: int) -> void:
	manager = owner
	position = Vector2(world_x, world_y)
	animal_id = type_id
	match animal_id:
		3:
			folder = "squirrel"
			base_vel_x = -0x140
			base_vel_y = -0x180
		5:
			folder = "flicky"
			base_vel_x = -0x300
			base_vel_y = -0x400
		6:
			folder = "seal"
			base_vel_x = -0x280
			base_vel_y = -0x380
		_:
			folder = "rabbit"
			base_vel_x = -0x200
			base_vel_y = -0x400
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = true
	add_child(sprite)
	_set_frame(2)


func setup_prison(owner: SonicObjectManager, world_x: int, world_y: int, type_id: int, delay: int) -> void:
	setup(owner, world_x, world_y, type_id)
	is_prison_animal = true
	prison_delay = maxi(1, delay)
	vel_x = 0
	vel_y = 0
	first_floor_hit = false
	# Anml_FromPrison displays the animal in place until its individual delay
	# expires, then hands it to the normal floor/bounce routine.

func tick() -> void:
	if not alive:
		return
	if is_prison_animal and prison_delay > 0:
		prison_delay -= 1
		if prison_delay == 0:
			vel_y = -0x400
		return
	if not manager.is_world_x_on_screen(int(position.x), 96):
		alive = false
		return

	if not first_floor_hit:
		_object_fall(0x38)
		if vel_y >= 0 and _land_on_floor():
			first_floor_hit = true
			vel_x = base_vel_x
			vel_y = base_vel_y
			_set_frame(0)
		return

	if (animal_id & 1) != 0:
		# Odd animal IDs use Anml_SlowGravity (+$18) and alternate frames every 2 ticks.
		_object_fall(0x18)
		if vel_y >= 0 and _land_on_floor():
			vel_y = base_vel_y
		frame_timer -= 1
		if frame_timer < 0:
			frame_timer = 1
			frame_id = 1 - frame_id
			_set_frame(frame_id)
	else:
		# Even animal IDs use Anml_NormalGravity/ObjectFall (+$38), frame 1 while rising
		# and frame 0 while descending, bouncing at its base vertical speed.
		_object_fall(0x38)
		_set_frame(1 if vel_y < 0 else 0)
		if vel_y >= 0 and _land_on_floor():
			vel_y = base_vel_y

func _object_fall(gravity: int) -> void:
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + gravity)

func _land_on_floor() -> bool:
	var hit = manager.collision.find_floor(int(position.x), int(position.y) + 12, 13, 16, 0, false)
	var distance = int(hit["distance"])
	if distance >= 0:
		return false
	position.y += distance
	return true

func _set_frame(value: int) -> void:
	frame_id = clampi(value, 0, 2)
	if sprite != null:
		sprite.texture = load("res://assets/effects/%s/%02d.png" % [folder, frame_id])
