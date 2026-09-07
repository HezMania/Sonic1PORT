class_name LavaBallObject
extends Node2D

var manager: SonicObjectManager
var subtype = 0
var vel_x = 0
var vel_y = 0
var origin_y = 0
var alive = true
var sprite: Sprite2D
var frame_tick = 0
var stopped = false
var stopped_timer = 0

const SPEEDS = [-0x400, -0x500, -0x600, -0x700, -0x200, 0x200, -0x200, 0x200, 0]

func setup(owner: SonicObjectManager, x: int, y: int, kind: int) -> void:
	manager = owner
	subtype = clampi(kind, 0, 8)
	position = Vector2(x, y)
	origin_y = y
	vel_y = int(SPEEDS[subtype])
	if subtype >= 6:
		vel_x = vel_y
		vel_y = 0
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	add_child(sprite)
	_update_visual()

func tick() -> void:
	if not alive:
		return
	frame_tick += 1
	if stopped:
		stopped_timer -= 1
		_update_visual()
		_react_player()
		if stopped_timer <= 0:
			alive = false
		return
	if not stopped:
		match subtype:
			0, 1, 2, 3:
				position += Vector2(float(vel_x) / 256.0, float(vel_y) / 256.0)
				vel_y = GenesisMath.s16(vel_y + 0x18)
				if int(position.y) > origin_y:
					alive = false
					return
			4:
				position.y += float(vel_y) / 256.0
				var hit = manager.collision.find_ceiling_sensor(int(position.x), int(position.y) - 8, false)
				if int(hit["distance"]) < 0:
					position.y -= int(hit["distance"])
					_stop_on_surface()
			5:
				position.y += float(vel_y) / 256.0
				var hit = manager.collision.find_floor(int(position.x), int(position.y) + 8, 13, 16, 0, false)
				if int(hit["distance"]) < 0:
					position.y += int(hit["distance"])
					_stop_on_surface()
			6:
				position.x += float(vel_x) / 256.0
				var hit = manager.collision.find_left_wall_sensor(int(position.x) - 8, int(position.y), false)
				if int(hit["distance"]) < 0:
					position.x -= int(hit["distance"])
					_stop_on_surface()
			7:
				position.x += float(vel_x) / 256.0
				var hit = manager.collision.find_right_wall_sensor(int(position.x) + 8, int(position.y), false)
				if int(hit["distance"]) < 0:
					position.x += int(hit["distance"])
					_stop_on_surface()
	_update_visual()
	_react_player()
	if not manager.is_world_x_on_screen(int(position.x), 192):
		alive = false

func _stop_on_surface() -> void:
	stopped = true
	stopped_timer = 6
	vel_x = 0
	vel_y = 0

func _update_visual() -> void:
	var zone = int(manager.level_definition.get("zone", LevelCatalog.ZONE_MZ)) if manager != null else LevelCatalog.ZONE_MZ
	if zone == LevelCatalog.ZONE_SLZ:
		var frame = 0
		var anim_flip_h = false
		var anim_flip_v = false
		if subtype >= 6:
			if stopped:
				frame = 5
			else:
				var step = int(frame_tick / 6.0) & 3
				frame = 3 if step < 2 else 4
				anim_flip_v = (step & 1) != 0
		else:
			if stopped:
				frame = 2
			else:
				var step = int(frame_tick / 6.0) & 3
				frame = 0 if step < 2 else 1
				anim_flip_h = (step & 1) != 0
		sprite.texture = SourceObjectArt.slz_fireball_texture(frame)
		sprite.flip_h = (subtype == 6) != anim_flip_h
		var direction_flip_v = subtype == 4 or (subtype <= 3 and vel_y < 0)
		sprite.flip_v = direction_flip_v != anim_flip_v
		return
	var frame = 0
	if subtype >= 6:
		frame = 5 if stopped else 3 + (int(frame_tick / 6.0) & 1)
	else:
		frame = 2 if stopped else (int(frame_tick / 6.0) & 1)
	var path = "res://assets/objects/lava_ball/%02d.png" % frame
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.flip_h = subtype == 6
	sprite.flip_v = subtype == 4 or (subtype <= 3 and vel_y < 0)

func _react_player() -> void:
	var p = manager.player
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - int(position.x)) <= p.width_radius + 8 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 8:
		p.apply_hazard_hit(int(position.x))
