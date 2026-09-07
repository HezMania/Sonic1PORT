class_name MZBossFireObject
extends Node2D

# Object $74 - Marble boss fire. The source waits 30 frames, drops to the floor,
# then creates two spreading fronts at ±$A0 (8.8) and leaves 103-frame flames
# whenever a front crosses a 16-pixel boundary.
var manager: SonicObjectManager
var alive = true
var state = 0
var timer = 30
var vel_y = 0
var impact_x = 0
var floor_y = 0
var main_sprite: Sprite2D
var flames: Array[Dictionary] = []
var fronts: Array[Dictionary] = []

func setup(owner: SonicObjectManager, x: int, y: int) -> void:
	manager = owner
	position = Vector2(x, y)
	main_sprite = _make_sprite("res://assets/objects/lava_ball/00.png")
	main_sprite.flip_v = true

func tick() -> void:
	if not alive:
		return
	match state:
		0: _tick_telegraph()
		1: _tick_drop()
		2: _tick_spread()
	_update_flames()
	_react_player()

func _tick_telegraph() -> void:
	timer -= 1
	main_sprite.visible = ((timer >> 2) & 1) == 0
	if timer <= 0:
		state = 1
		main_sprite.visible = true
		main_sprite.flip_v = false

func _tick_drop() -> void:
	vel_y = GenesisMath.s16(vel_y + 0x18)
	position.y += float(vel_y) / 256.0
	var hit = manager.collision.find_floor(int(position.x), int(position.y) + 8, 13, 16, 0, false)
	if int(hit["distance"]) < 0:
		position.y += int(hit["distance"])
		impact_x = int(position.x)
		floor_y = int(position.y) - 2
		main_sprite.visible = false
		state = 2
		_spawn_flame(impact_x, floor_y)
		fronts = [
			{"x_fixed": impact_x << 8, "direction": -1, "last_cell": impact_x >> 4, "active": true},
			{"x_fixed": impact_x << 8, "direction": 1, "last_cell": impact_x >> 4, "active": true},
		]

func _tick_spread() -> void:
	var active_fronts = 0
	for i in range(fronts.size()):
		var f = fronts[i]
		if not bool(f.get("active", false)):
			continue
		active_fronts += 1
		var direction = int(f["direction"])
		var x_fixed = int(f["x_fixed"]) + direction * 0xA0
		var world_x = x_fixed >> 8
		# Right-side source clamp is boss_mz_x+$140. On either side, stop a
		# spreading front once it leaves the solid platform rather than teleporting
		# flames across a gap.
		if world_x > 0x1940:
			f["active"] = false
			fronts[i] = f
			continue
		var floor_hit = manager.collision.find_floor(world_x, floor_y + 8, 13, 32, 0, false)
		var d = int(floor_hit["distance"])
		if d >= 12:
			f["active"] = false
			fronts[i] = f
			continue
		var cell = world_x >> 4
		if cell != int(f["last_cell"]):
			f["last_cell"] = cell
			_spawn_flame(world_x, floor_y + d)
		f["x_fixed"] = x_fixed
		fronts[i] = f
	if active_fronts == 0 and flames.is_empty():
		alive = false

func _spawn_flame(x: int, y: int) -> void:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.texture = load("res://assets/objects/lava_ball/00.png")
	sp.position = Vector2(x - int(position.x), y - int(position.y))
	add_child(sp)
	# BossFire_GenericTimer = 103.  The normal lifetime uses Ani_Fire's
	# vertical flame sequence; only the short final burnout uses frame 2.
	flames.append({"sprite": sp, "life": 103, "burnout": 0, "x": x, "y": y})

func _update_flames() -> void:
	for i in range(flames.size() - 1, -1, -1):
		var f = flames[i]
		var raw_sprite = f.get("sprite")
		if raw_sprite == null or not is_instance_valid(raw_sprite):
			flames.remove_at(i)
			continue
		var sp = raw_sprite as Sprite2D
		var burnout = int(f.get("burnout", 0))
		if burnout > 0:
			burnout -= 1
			f["burnout"] = burnout
			if burnout <= 0:
				sp.queue_free()
				flames.remove_at(i)
			else:
				flames[i] = f
			continue

		var life = int(f["life"]) - 1
		f["life"] = life
		if life <= 0:
			# Source switches to the non-hurting vertical-collision frame, moves
			# it four pixels upward, then lets the short animation finish.
			sp.texture = load("res://assets/objects/lava_ball/02.png")
			sp.flip_h = false
			sp.position.y -= 4
			f["burnout"] = 6
			flames[i] = f
			continue

		# Ani_Fire .vertical: 0, 0|xflip, 1, 1|xflip with delay 5.
		var seq = int((103 - life) / 6) & 3
		var frame = 0 if seq < 2 else 1
		sp.texture = load("res://assets/objects/lava_ball/%02d.png" % frame)
		sp.flip_h = seq == 1 or seq == 3
		flames[i] = f

func _react_player() -> void:
	var p = manager.player
	if p == null or p.dead:
		return
	if state <= 1 and main_sprite.visible and absi(p.pixel_x() - int(position.x)) <= p.width_radius + 8 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 8:
		p.apply_hazard_hit(int(position.x))
		return
	for f in flames:
		if int(f.get("life", 0)) <= 0:
			continue
		if absi(p.pixel_x() - int(f["x"])) <= p.width_radius + 8 and absi(p.pixel_y() - int(f["y"])) <= p.height_radius + 8:
			p.apply_hazard_hit(int(f["x"]))
			return

func _make_sprite(path: String) -> Sprite2D:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.texture = load(path)
	add_child(sp)
	return sp
