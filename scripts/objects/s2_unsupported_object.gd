class_name S2UnsupportedObject
extends GenesisLevelObject

# Phase 81: source-native Sonic 2 placement records that do not yet have a
# faithful runtime class are deliberately inert. F3 still exposes their exact
# source position without accidentally routing a colliding S1 object ID.
func initialize_object() -> void:
	visible = true
	queue_redraw()

func _draw() -> void:
	if manager != null and manager.show_placeholders:
		draw_rect(Rect2(-4, -4, 8, 8), Color(0.2, 0.8, 1.0, 0.9), false, 1.0)
		draw_line(Vector2(-6, 0), Vector2(6, 0), Color(0.2, 0.8, 1.0, 0.9), 1.0)
		draw_line(Vector2(0, -6), Vector2(0, 6), Color(0.2, 0.8, 1.0, 0.9), 1.0)
