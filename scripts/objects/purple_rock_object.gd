class_name PurpleRockObject
extends GenesisLevelObject

var sprite: Sprite2D

func initialize_object() -> void:
	active_width = 24
	sprite = make_sprite("res://assets/objects/purple_rock/00.png")

func tick() -> void:
	var p = player()
	if p == null:
		return
	# Object 3B passes 32x32 dimensions to SolidObject.
	p.resolve_solid_box(spawn_x, spawn_y, 16, 16, true, record_index)
