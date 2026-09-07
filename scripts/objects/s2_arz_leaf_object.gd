class_name S2ARZLeafObject
extends Node2D

var manager: SonicObjectManager
var alive: bool = true
var sprite: Sprite2D
var vel_x: int = 0
var vel_y: int = 0
var base_x: float = 0.0
var base_y: float = 0.0
var angle: int = 0
var angle_step: int = 4
var frame_timer: int = 11
var frame_base: int = 0

func setup(owner: SonicObjectManager, world_x: int, world_y: int, vx: int, vy: int, frame: int) -> void:
	manager = owner
	position = Vector2(world_x, world_y)
	base_x = float(world_x)
	base_y = float(world_y)
	vel_x = vx
	vel_y = vy
	frame_base = frame & 1
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = 1
	add_child(sprite)
	_set_frame(frame_base)

func _set_frame(frame: int) -> void:
	var path: String = "res://assets/objects/s2_arz/leaves/%02d.png" % frame
	if ResourceLoader.exists(path): sprite.texture = load(path)

func tick() -> void:
	angle = (angle + angle_step) & 0xFF
	base_x += float(vel_x) / 256.0
	base_y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + 6)
	position.x = base_x + float(GenesisMath.sine(angle) >> 6)
	position.y = base_y + float(GenesisMath.cosine(angle) >> 6)
	frame_timer -= 1
	if frame_timer < 0:
		frame_timer = 11
		frame_base ^= 2
		_set_frame(frame_base)
	if manager != null and (absi(int(position.x) - manager.current_screen_x) > 900 or int(position.y) > manager.current_screen_y + 600):
		alive = false
