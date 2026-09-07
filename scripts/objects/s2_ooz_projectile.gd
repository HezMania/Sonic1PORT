class_name S2OOZProjectile
extends Node2D

var manager: SonicObjectManager
var alive: bool = true
var sprite: Sprite2D
var folder: String = ""
var frame_sequence: Array[int] = []
var frame_delay: int = 3
var frame_counter: int = 0
var vel_x: int = 0
var vel_y: int = 0
var startup_delay: int = 0
var half_width: int = 8
var half_height: int = 8

func setup(owner: SonicObjectManager, world_x: int, world_y: int, texture_folder: String, frames: Array[int], delay: int, vx: int, vy: int, wait_frames: int = 0, face_left: bool = false) -> void:
	manager = owner
	position = Vector2(world_x, world_y)
	folder = texture_folder
	frame_sequence = frames.duplicate()
	frame_delay = maxi(1, delay)
	vel_x = vx
	vel_y = vy
	startup_delay = wait_frames
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = 1 if folder == "octus" else 3
	sprite.flip_h = face_left
	add_child(sprite)
	_set_frame(0)

func _set_frame(index: int) -> void:
	if sprite == null or frame_sequence.is_empty():
		return
	var f: int = frame_sequence[index % frame_sequence.size()]
	var path: String = "res://assets/objects/s2_ooz/%s/%02d.png" % [folder, f]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func tick() -> void:
	if not alive:
		return
	if startup_delay > 0:
		startup_delay -= 1
		return
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	frame_counter += 1
	if not frame_sequence.is_empty() and frame_counter % frame_delay == 0:
		_set_frame(int(frame_counter / frame_delay))
	_react_player()
	if manager != null and (int(position.y) > manager.current_screen_y + 520 or int(position.y) < manager.current_screen_y - 320 or absi(int(position.x) - manager.current_screen_x) > 900):
		alive = false
		queue_free()

func _react_player() -> void:
	if manager == null:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - int(position.x)) > half_width + p.width_radius:
		return
	if absi(p.pixel_y() - int(position.y)) > half_height + p.height_radius:
		return
	if p.invincible_timer > 0 or p.rolling or p.object_attack_active:
		alive = false
		queue_free()
		return
	p.apply_hazard_hit(int(position.x))
