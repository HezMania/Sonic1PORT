class_name MZBlockFragment
extends Node2D

var manager: SonicObjectManager
var alive := true
var vel_x := 0
var vel_y := 0
var sprite: Sprite2D

func setup(owner: SonicObjectManager, x: int, y: int, vx: int, vy: int, quadrant: int) -> void:
	manager = owner
	position = Vector2(x, y)
	vel_x = vx
	vel_y = vy
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.texture = load("res://assets/objects/mz_smashblock/01.png")
	sprite.region_enabled = true
	# The source's four-piece mapping is represented as four clipped quadrants.
	# The decoded frame is centered on a 96x96 canvas; its visible 32x32 block
	# occupies (32,32)-(64,64). Crop the four actual source quadrants.
	sprite.region_rect = Rect2(32 + (quadrant & 1) * 16, 32 + ((quadrant >> 1) & 1) * 16, 16, 16)
	add_child(sprite)

func tick() -> void:
	if not alive:
		return
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + 0x38)
	if position.y > manager.player.pixel_y() + 640 or not manager.is_world_x_on_screen(int(position.x), 320):
		alive = false
