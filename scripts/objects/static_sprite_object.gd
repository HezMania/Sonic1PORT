class_name StaticSpriteObject
extends GenesisLevelObject

var sprite: Sprite2D

func initialize_object() -> void:
	var folder = ""
	var frame = 0
	match object_id:
		0x79:
			folder = "lamppost"
		_:
			folder = ""
	if folder != "":
		sprite = make_sprite("res://assets/objects/%s/%02d.png" % [folder, frame])
	else:
		queue_redraw()

func _draw() -> void:
	if object_id == 0x79:
		return
	# Unsupported placement records remain visible when F3 debug is enabled.
	if manager != null and manager.show_placeholders:
		draw_rect(Rect2(-4, -4, 8, 8), Color(1.0, 0.2, 0.8, 0.85), false, 1.0)
