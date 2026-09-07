class_name ExplosionEffect
extends Node2D

# Object $27 - gray explosion used by monitors and destroyed badniks.
# Five mapping frames, each displayed for 8 frames. A badnik explosion asks the
# object manager to create Object $28 separately, while a monitor explosion does not.
var alive := true
var frame_id := 0
var frame_timer := 7
var sprite: Sprite2D

func setup(world_x: int, world_y: int) -> void:
	position = Vector2(world_x, world_y)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = load("res://assets/effects/explosion/00.png")
	add_child(sprite)

func tick() -> void:
	if not alive:
		return
	frame_timer -= 1
	if frame_timer >= 0:
		return
	frame_timer = 7
	frame_id += 1
	if frame_id >= 5:
		alive = false
		return
	sprite.texture = load("res://assets/effects/explosion/%02d.png" % frame_id)
