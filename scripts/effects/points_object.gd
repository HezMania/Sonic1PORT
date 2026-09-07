class_name PointsObject
extends Node2D

# Object $29 - score popup from a destroyed badnik.
var alive := true
var velocity_y := -0x300
var sprite: Sprite2D

func setup(world_x: int, world_y: int, points: int) -> void:
	position = Vector2(world_x, world_y)
	var frame = 0
	match points:
		100:
			frame = 0
		200:
			frame = 1
		500:
			frame = 2
		1000:
			frame = 3
		10000:
			frame = 5
		100000:
			frame = 6
		_:
			frame = 0
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = load("res://assets/effects/points/%02d.png" % frame)
	add_child(sprite)

func tick() -> void:
	if not alive:
		return
	if velocity_y >= 0:
		alive = false
		return
	position.y += float(velocity_y) / 256.0
	velocity_y = GenesisMath.s16(velocity_y + 0x18)
