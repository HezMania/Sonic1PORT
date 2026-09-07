class_name S2ARZDebrisObject
extends Node2D

var manager: SonicObjectManager
var alive: bool = true
var sprite: Sprite2D
var vel_x: int = 0
var vel_y: int = 0
var gravity: int = 0x38
var delay: int = 0

func setup(owner: SonicObjectManager, world_x: int, world_y: int, texture_path: String, vx: int, vy: int, gravity_value: int, delay_frames: int = 0, z: int = 2) -> void:
	manager = owner
	position = Vector2(world_x, world_y)
	vel_x = vx
	vel_y = vy
	gravity = gravity_value
	delay = delay_frames
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = z
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	add_child(sprite)

func tick() -> void:
	if delay > 0:
		delay -= 1
		return
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + gravity)
	if manager != null and (int(position.y) > manager.current_screen_y + 600 or absi(int(position.x) - manager.current_screen_x) > 1000):
		alive = false
		queue_free()
