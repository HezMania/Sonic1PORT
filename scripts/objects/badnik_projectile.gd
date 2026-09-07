class_name BadnikProjectile
extends Node2D

var manager = null
var alive := true
var kind := ""
var sprite: Sprite2D
var vel_x := 0
var vel_y := 0
var anim_tick := 0
var delay := 0
var parent_badnik = null


func setup_ball_hog(owner, x: int, y: int, horizontal_velocity: int, seconds: int) -> void:
	manager = owner
	kind = "ball_hog"
	position = Vector2(x, y)
	vel_x = horizontal_velocity
	vel_y = 0
	delay = maxi(0, seconds) * 60
	sprite = _make_sprite("")
	sprite.texture = SourceObjectArt.ball_hog_texture(4)

func setup_crab(owner, x: int, y: int, horizontal_velocity: int) -> void:
	manager = owner
	kind = "crab"
	position = Vector2(x, y)
	vel_x = horizontal_velocity
	vel_y = -0x400
	sprite = _make_sprite("res://assets/objects/crabmeat/05.png")

func setup_buzz(owner, x: int, y: int, horizontal_velocity: int, parent) -> void:
	manager = owner
	kind = "buzz"
	position = Vector2(x, y)
	vel_x = horizontal_velocity
	vel_y = 0x200
	delay = 15
	parent_badnik = parent
	sprite = _make_sprite("res://assets/objects/buzz_missile/00.png")
	sprite.flip_h = horizontal_velocity > 0

func setup_newtron(owner, x: int, y: int, horizontal_velocity: int) -> void:
	manager = owner
	kind = "newtron"
	position = Vector2(x, y)
	vel_x = horizontal_velocity
	vel_y = 0
	sprite = _make_sprite("res://assets/objects/buzz_missile/02.png")
	sprite.flip_h = horizontal_velocity > 0

func tick() -> void:
	if not alive:
		return
	anim_tick += 1
	match kind:
		"ball_hog":
			_tick_ball_hog()
		"crab":
			_tick_crab()
		"buzz":
			_tick_buzz()
		"newtron":
			_tick_newtron()

	if not alive:
		return
	var p = manager.player if manager != null else null
	if p != null and not p.dead:
		if absi(p.pixel_x() - int(position.x)) <= 12 and absi(p.pixel_y() - int(position.y)) <= 12:
			p.apply_hazard_hit(int(position.x))

	if kind == "ball_hog":
		var bottom = 0x700
		if manager != null:
			bottom = int(manager.level_definition.get("limit_bottom", bottom)) + 224
		if position.y > bottom or position.x < -128 or position.x > 0x4000:
			alive = false
	elif position.y > 0x700 or position.x < -128 or position.x > 0x4000:
		alive = false

func _tick_ball_hog() -> void:
	# Cannonball uses ObjectFall, then bounces only while descending.
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
	if vel_y >= 0 and manager != null:
		var hit = manager.collision.find_floor(int(position.x), int(position.y) + 7, 13, 16, 0, false)
		var distance = int(hit["distance"])
		if distance < 0:
			position.y += distance
			vel_y = -0x300
			var raw_angle = int(hit["angle"]) & 0xFF
			# ObjFloorDist clears any angle whose bit 0 is set before returning d3.
			# Without this snap, some SBZ floor samples can be misread as a slope
			# and reverse a freshly launched right-facing Ball Hog cannonball.
			if (raw_angle & 1) != 0:
				raw_angle = 0
			var angle = GenesisMath.s8(raw_angle)
			if angle < 0 and vel_x >= 0:
				vel_x = -vel_x
			elif angle > 0 and vel_x < 0:
				vel_x = -vel_x

	delay -= 1
	if delay < 0:
		if manager != null:
			manager.spawn_plain_explosion(int(position.x), int(position.y))
		alive = false
		return
	if sprite != null:
		sprite.texture = SourceObjectArt.ball_hog_texture(4 + (int(anim_tick / 6) & 1))

func _tick_crab() -> void:
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
	var frame = 5 + ((anim_tick >> 1) & 1)
	_set_frame("crabmeat", frame)

func _tick_newtron() -> void:
	# Newtron's subtype-1 missile is active immediately and moves strictly
	# horizontally at $200. It reuses the active Buzz Bomber missile frames.
	position.x += float(vel_x) / 256.0
	_set_frame("buzz_missile", 2 + ((anim_tick >> 1) & 1))
	if manager != null and not manager.is_world_x_on_screen(int(position.x), 64):
		alive = false

func _tick_buzz() -> void:
	# The original flare waits 15 frames before becoming an active missile.
	if parent_badnik == null or not is_instance_valid(parent_badnik) or not parent_badnik.alive:
		alive = false
		return
	if delay > 0:
		delay -= 1
		_set_frame("buzz_missile", (anim_tick >> 3) & 1)
		return
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	_set_frame("buzz_missile", 2 + ((anim_tick >> 1) & 1))

func _make_sprite(path: String) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	if ResourceLoader.exists(path):
		s.texture = load(path)
	add_child(s)
	return s

func _set_frame(folder: String, frame: int) -> void:
	if sprite == null:
		return
	var path = "res://assets/objects/%s/%02d.png" % [folder, frame]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
