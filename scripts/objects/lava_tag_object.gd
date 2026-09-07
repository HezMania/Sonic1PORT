class_name LavaTagObject
extends GenesisLevelObject

const WIDTHS = [32, 64, 128]

func initialize_object() -> void:
	active_width = int(WIDTHS[clampi(subtype & 3, 0, 2)])
	visible = false

func tick() -> void:
	var p = player()
	if p == null or p.dead:
		return
	var half_w = int(WIDTHS[clampi(subtype & 3, 0, 2)])
	if absi(p.pixel_x() - spawn_x) <= half_w + p.width_radius and absi(p.pixel_y() - spawn_y) <= 32 + p.height_radius:
		p.apply_hazard_hit(spawn_x)
