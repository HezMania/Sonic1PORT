class_name GrassFireObject
extends Node2D

# Object $35 - fire that spreads across MZ's burnable grass platform.
# The first flame advances 1 px/frame and plants a child every 16 px; children
# remain fixed to their place on the parent slope while the platform depresses.

var manager: SonicObjectManager
var platform: MarbleObject
var alive = true
var root_flame = false
var local_x = 0
var frame_tick = 0
var sprite: Sprite2D

func setup(owner: SonicObjectManager, parent_platform: MarbleObject, x_offset: int, is_root: bool) -> void:
	manager = owner
	platform = parent_platform
	root_flame = is_root
	local_x = x_offset
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	add_child(sprite)
	_update_position()
	_update_visual()

func tick() -> void:
	if not alive:
		return
	if platform == null or not is_instance_valid(platform) or not platform.alive:
		alive = false
		return
	frame_tick += 1
	if root_flame:
		local_x += 1
		# GFire_Spread starts at the platform's left edge, moves across roughly
		# 132 px, and creates a stationary child each time it reaches the next
		# 16-pixel boundary.
		if local_x <= platform.active_width * 2 + 4 and ((local_x + 8) & 0x0F) == 0:
			manager.spawn_grass_fire_child(platform, local_x)
		if local_x >= platform.active_width * 2 + 4:
			root_flame = false
	_update_position()
	_update_visual()
	_react_player()

func _update_position() -> void:
	if platform == null:
		return
	var world_x = int(platform.position.x) - platform.active_width + local_x
	var world_y = platform.grass_surface_y(world_x) + 5
	position = Vector2(world_x, world_y)

func _update_visual() -> void:
	if sprite == null:
		return
	var phase = int(frame_tick / 6.0) & 3
	var frame = 0 if phase < 2 else 1
	var path = "res://assets/objects/lava_ball/%02d.png" % frame
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.flip_h = (phase & 1) != 0

func _react_player() -> void:
	var p = manager.player
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - int(position.x)) <= p.width_radius + 8 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 8:
		p.apply_hazard_hit(int(position.x))
