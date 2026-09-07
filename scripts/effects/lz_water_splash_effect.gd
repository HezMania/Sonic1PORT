class_name LZWaterSplashEffect
extends Node2D

var manager: SonicObjectManager
var alive := true
var source_x := 0
var frame := 0
var frame_timer := 4
var sprite: Sprite2D

func setup(owner: SonicObjectManager, world_x: int) -> void:
	manager = owner
	source_x = world_x
	z_index = 55
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.texture = SourceObjectArt.lz_water_splash_texture(0)
	add_child(sprite)

func tick() -> void:
	if manager == null or not manager.water_enabled:
		alive = false
		return
	# Map_Splash's shared source bounds are X -$10 and Y -$1E.
	position = Vector2(source_x - 0x10, manager.water_surface_y - 0x1E)
	frame_timer -= 1
	if frame_timer >= 0:
		return
	frame += 1
	if frame >= 3:
		alive = false
		return
	frame_timer = 4
	sprite.texture = SourceObjectArt.lz_water_splash_texture(frame)
