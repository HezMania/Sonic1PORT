class_name CollisionDebug
extends Node2D

var collision: GenesisCollision
var enabled: bool = true

func setup(collision_engine: GenesisCollision) -> void:
	collision = collision_engine
	queue_redraw()

func _process(_delta: float) -> void:
	if collision != null and enabled:
		queue_redraw()

func _draw() -> void:
	if collision == null or not enabled:
		return

	var mouse := get_global_mouse_position()
	var mx := floori(mouse.x)
	var my := floori(mouse.y)
	var block_origin := Vector2(floori(float(mx) / 16.0) * 16, floori(float(my) / 16.0) * 16)
	var info := collision.get_block_info(mx, my)

	var outline := Color(1.0, 1.0, 1.0, 0.8)
	if info["top_solid"]:
		outline = Color(0.2, 1.0, 0.2, 0.9)
	elif info["all_solid"]:
		outline = Color(1.0, 0.3, 0.2, 0.9)
	draw_rect(Rect2(block_origin, Vector2(16, 16)), outline, false, 1.0)
	draw_circle(mouse, 2.0, Color.WHITE)

	var floor_result := collision.find_floor(mx, my, 13, 16, 0)
	var distance := int(floor_result["distance"])
	var target := mouse + Vector2(0, distance)
	draw_line(mouse, target, Color(1.0, 0.9, 0.1), 1.0)
	draw_circle(target, 2.0, Color(1.0, 0.9, 0.1))
