class_name S2EHZWaterfallObject
extends GenesisLevelObject

# Retail Object $49. The source swaps to the adjacent mapping frame whenever
# Sonic is horizontally inside the waterfall's 128-pixel interaction strip.
var sprite: Sprite2D

func initialize_object() -> void:
	active_width = 32
	sprite = make_sprite("res://assets/objects/s2_ehz/waterfall/%02d.png" % clampi(subtype, 0, 7))
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip

func tick() -> void:
	var frame = clampi(subtype, 0, 7)
	var p = player()
	if p != null and p.pixel_x() >= spawn_x - 0x40 and p.pixel_x() < spawn_x + 0x40:
		frame = clampi(frame + 1, 0, 7)
	set_sprite_frame(sprite, "s2_ehz/waterfall", frame)
