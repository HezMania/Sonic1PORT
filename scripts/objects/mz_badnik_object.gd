class_name MZBadnikObject
extends GenesisLevelObject

var sprite: Sprite2D
var frame_tick = 0
var state = 0
var timer = 0
var vel_x = 0
var vel_y = 0
var origin_y = 0
var target_y = 0
var direction = -1
var grounded = false
var body_sprites: Array[Sprite2D] = []
var cat_phase = 0
var cat_mouth_open = false
var cat_floor_history: Array[int] = []
var cat_history_pos = 0
var cat_inertia = 0
var cat_x_fixed = 0
var cat_angle = 0
var cat_segment_data: Array = []
var cat_trail: Array[Vector2i] = []
var cat_fragment_data: Array[Dictionary] = []
var cat_fragment_timer = 0

const CAT_ANIM = [
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
	1,1,1,1,1,1,2,2,2,2,2,3,3,3,3,3,
	4,4,4,4,4,4,5,5,5,5,5,6,6,6,6,6,
	6,6,7,7,7,7,7,7,7,7,7,7,0xFF,7,7,0xFF,
	7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,6,
	6,6,6,6,6,6,5,5,5,5,5,4,4,4,4,4,
	4,3,3,3,3,3,2,2,2,2,2,1,1,1,1,1,
	1,1,0,0,0,0,0,0,0,0,0,0,0xFF,0,0,0xFF,
]

func initialize_object() -> void:
	origin_y = spawn_y
	match object_id:
		0x55:
			active_width = 16
			sprite = make_sprite("res://assets/objects/basaran/00.png")
			state = 0
		0x78:
			active_width = 8
			sprite = make_sprite("res://assets/objects/caterkiller/00.png")
			visible = false
			vel_y = 0
			state = 0
			cat_floor_history.resize(16)
			cat_floor_history.fill(0)
			cat_history_pos = 0
			cat_segment_data.clear()
			for i in range(3):
				var seg = make_sprite("res://assets/objects/caterkiller/08.png", -1)
				seg.visible = false
				body_sprites.append(seg)
				var floor_map: Array[int] = []
				floor_map.resize(16)
				floor_map.fill(0)
				cat_segment_data.append({
					"sprite": seg,
					"x_fixed": 0,
					"y": float(position.y),
					"flip": x_flip,
					"vel_x": 0,
					"inertia": 0,
					"segment_pos": (i + 1) * 4,
					"floor_map": floor_map,
					"angle": 0,
				})

func tick() -> void:
	frame_tick += 1
	if object_id == 0x55:
		_tick_basaran()
	else:
		_tick_caterkiller()
	if alive:
		_react_player()

func _tick_basaran() -> void:
	var p = player()
	if p == null:
		return
	match state:
		0: # hanging from ceiling; trigger within 128 x/y below
			_set_frame("basaran", 0)
			var dx = p.pixel_x() - int(position.x)
			var dy = p.pixel_y() - int(position.y)
			_face(dx)
			if absi(dx) < 128 and dy >= 0 and dy < 128 and ((frame_tick + record_index) & 7) == 0:
				target_y = p.pixel_y()
				state = 1
				vel_y = 0
		1: # drop to within 16px of remembered Sonic Y
			_face(p.pixel_x() - int(position.x))
			position.y += float(vel_y) / 256.0
			vel_y = GenesisMath.s16(vel_y + 0x18)
			_set_frame("basaran", 1)
			if target_y - int(position.y) < 16:
				vel_y = 0
				vel_x = direction * 0x100
				state = 2
		2: # fly while Sonic remains near
			position.x += float(vel_x) / 256.0
			_set_frame("basaran", 1 + ((frame_tick >> 2) % 3))
			if absi(p.pixel_x() - int(position.x)) >= 128 and ((frame_tick + record_index) & 7) == 0:
				state = 3
		3: # return to ceiling
			position += Vector2(float(vel_x) / 256.0, float(vel_y) / 256.0)
			vel_y = GenesisMath.s16(vel_y - 0x18)
			_set_frame("basaran", 1 + ((frame_tick >> 2) % 3))
			var hit = manager.collision.find_ceiling_sensor(int(position.x), int(position.y) - 12, false)
			if int(hit["distance"]) <= 0:
				position.y -= int(hit["distance"])
				position.x = int(position.x) & ~7
				vel_x = 0
				vel_y = 0
				state = 0

func _face(dx: int) -> void:
	direction = 1 if dx >= 0 else -1
	if sprite != null:
		sprite.flip_h = direction > 0

func _tick_caterkiller() -> void:
	# Object $78 is four linked OST entries in the source: the head, body1,
	# body2, body3. Each body entry copies velocity/inertia from the previous
	# entry and reads that parent's 16-byte floor map. This is what creates the
	# characteristic alternating accordion motion and staggered corner turns.
	if state == 3:
		_tick_cat_fragments()
		return

	if state == 0:
		position.y += float(vel_y) / 256.0
		vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
		var hit = manager.collision.find_floor(int(position.x), int(position.y) + 7, 13, 16, 0, false)
		var floor_distance = int(hit["distance"])
		if floor_distance <= 0:
			position.y += floor_distance
			vel_y = 0
			grounded = true
			state = 1
			timer = 7
			cat_x_fixed = int(round(position.x * 65536.0))
			cat_history_pos = 0
			cat_floor_history.fill(0)
			cat_inertia = 0
			cat_angle = 0
			cat_mouth_open = false
			visible = true
			_initialize_cat_segments()
			_update_cat_animation_source()
			_update_cat_segments_visuals()
		return

	# Cat_Undulate: 8 stationary ticks between 16-tick movement passes.
	if state == 1:
		timer -= 1
		if timer >= 0:
			_update_cat_animation_source()
			_update_cat_segments_visuals()
			return
		state = 2
		timer = 16
		cat_mouth_open = not cat_mouth_open
		# Source bchg #4 alternates between head movement and body compression.
		if cat_mouth_open:
			vel_x = -0xC0
			cat_inertia = 0x40
		else:
			vel_x = 0
			cat_inertia = -0x40

	# Cat_Floor decrements before moving. The head may remain still in one half
	# of the cycle, but the segment chain still propagates parent inertia.
	timer -= 1
	if timer < 0:
		state = 1
		timer = 7
		vel_x = 0
		cat_inertia = 0
		_update_cat_animation_source()
		_update_cat_segments_visuals()
		return

	_move_cat_head_source()
	_move_cat_segments_source()
	_update_cat_animation_source()
	_update_cat_segments_visuals()

func _initialize_cat_segments() -> void:
	var gap = -12 if x_flip else 12
	for i in range(cat_segment_data.size()):
		var data: Dictionary = cat_segment_data[i]
		data["x_fixed"] = cat_x_fixed + ((gap * (i + 1)) << 16)
		data["y"] = int(position.y)
		data["flip"] = x_flip
		data["vel_x"] = 0
		data["inertia"] = 0
		data["segment_pos"] = (i + 1) * 4
		var floor_map: Array = data["floor_map"]
		floor_map.fill(0)
		data["floor_map"] = floor_map
		data["angle"] = 0
		cat_segment_data[i] = data
		var seg: Sprite2D = data["sprite"]
		seg.visible = true
		seg.texture = load("res://assets/objects/caterkiller/08.png")

func _cat_negate_subpixel(fixed_value: int) -> int:
	# REV01 Caterkiller turn fix performs `neg.w obSubpixelX`: only the low
	# 16-bit subpixel word is negated while the integer X word is preserved.
	var whole = fixed_value >> 16
	var subpixel = fixed_value & 0xFFFF
	subpixel = (-GenesisMath.s16(subpixel)) & 0xFFFF
	return (whole << 16) | subpixel

func _move_cat_head_source() -> void:
	if vel_x == 0:
		return
	var previous_pixel_x = cat_x_fixed >> 16
	var signed_speed = -vel_x if x_flip else vel_x
	cat_x_fixed += signed_speed << 8
	position.x = float(cat_x_fixed) / 65536.0
	if (cat_x_fixed >> 16) == previous_pixel_x:
		return

	var hit = manager.collision.find_floor(int(position.x), int(position.y) + 7, 13, 16, 0, false)
	var d = int(hit["distance"])
	if d < -8 or d >= 12:
		# Cat_Floor .ledgeHit (REV01). The original does NOT restore the previous
		# X position here. It writes the $80 reversal marker, negates the current
		# subpixel, and can consume/clear one extra history slot when turning from
		# the right. Restoring old X in Phase 21 widened the body chain during a
		# turn until one or more segments appeared to vanish.
		var pos = cat_history_pos & 0x0F
		cat_floor_history[pos] = 0x80
		cat_x_fixed = _cat_negate_subpixel(cat_x_fixed)
		if (cat_x_fixed & 0xFFFF) != 0 and x_flip:
			cat_x_fixed -= 1 << 16
			pos = (pos + 1) & 0x0F
			cat_floor_history[pos] = 0
		x_flip = not x_flip
		cat_history_pos = (pos + 1) & 0x0F
		position.x = float(cat_x_fixed) / 65536.0
		return

	position.y += d
	cat_floor_history[cat_history_pos] = d
	cat_history_pos = (cat_history_pos + 1) & 0x0F

func _move_cat_segments_source() -> void:
	# Cat_BodySeg1/2. Every segment reads the preceding object's floor-history
	# byte at its own delayed position, copies that byte into its own history,
	# and performs the REV01 low-word correction independently when $80 reaches
	# it. This keeps all three body entries alive/connected through a reversal.
	var parent_vel = vel_x
	var parent_inertia = cat_inertia
	var parent_map: Array = cat_floor_history
	for i in range(cat_segment_data.size()):
		var data: Dictionary = cat_segment_data[i]
		var seg_inertia = parent_inertia
		var seg_vel = GenesisMath.s16(parent_vel + seg_inertia)
		data["inertia"] = seg_inertia
		data["vel_x"] = seg_vel
		var old_pixel_x = int(data["x_fixed"]) >> 16
		var signed_speed = -seg_vel if bool(data["flip"]) else seg_vel
		data["x_fixed"] = int(data["x_fixed"]) + (signed_speed << 8)

		if (int(data["x_fixed"]) >> 16) != old_pixel_x:
			var pos = int(data["segment_pos"]) & 0x0F
			var floor_value = int(parent_map[pos])
			var own_map: Array = data["floor_map"]
			if floor_value == 0x80:
				own_map[pos] = 0x80
				data["x_fixed"] = _cat_negate_subpixel(int(data["x_fixed"]))
				# Exact REV01 extra-pixel/extra-slot path. Only a segment currently
				# facing right and travelling at -$C0 consumes the second slot.
				if (int(data["x_fixed"]) & 0xFFFF) != 0 and bool(data["flip"]) and seg_vel == -0xC0:
					data["x_fixed"] = int(data["x_fixed"]) - (1 << 16)
					pos = (pos + 1) & 0x0F
					own_map[pos] = 0
				data["flip"] = not bool(data["flip"])
				data["segment_pos"] = (pos + 1) & 0x0F
			else:
				data["y"] = int(data["y"]) + GenesisMath.s8(floor_value)
				own_map[pos] = floor_value & 0xFF
				data["segment_pos"] = (pos + 1) & 0x0F
			data["floor_map"] = own_map

		# Native representation guard: the source uses four independent OST entries.
		# If delayed subpixel turn propagation ever creates an impossible visual gap
		# in this child-sprite representation, keep the link within 28px of its
		# immediate parent while preserving that segment's own delayed flip state.
		var parent_x_fixed = cat_x_fixed if i == 0 else int(cat_segment_data[i - 1]["x_fixed"])
		var delta_fixed = int(data["x_fixed"]) - parent_x_fixed
		var max_link = 28 << 16
		if absi(delta_fixed) > max_link:
			data["x_fixed"] = parent_x_fixed + (max_link if delta_fixed > 0 else -max_link)

		cat_segment_data[i] = data
		parent_vel = seg_vel
		parent_inertia = seg_inertia
		parent_map = data["floor_map"]

func _update_cat_animation_source() -> void:
	# Only the head runs the head mapping bank. The source's bit-7 cat_mode flag
	# enables this during an undulation pass; CAT_ANIM's $FF entries briefly hold
	# the current pose.
	if state != 2:
		if sprite != null:
			sprite.flip_h = x_flip
		return
	var anim_value = int(CAT_ANIM[cat_angle & 0x7F])
	cat_angle = (cat_angle + 4) & 0x7F
	if anim_value != 0xFF:
		_set_frame("caterkiller", anim_value + (16 if cat_mouth_open else 0))
	if sprite != null:
		sprite.flip_h = x_flip

func _update_cat_segments_visuals() -> void:
	for i in range(cat_segment_data.size()):
		var data: Dictionary = cat_segment_data[i]
		var seg: Sprite2D = data["sprite"]
		# Routines 4 and 8 retain body1. Only the middle routine-6 segment runs
		# Caterkiller's offset body animation, which gives the source its alternating
		# two-up/two-forward look instead of all four parts bobbing together.
		if i == 1 and state == 2:
			var seg_angle = int(data["angle"]) & 0x7F
			var anim_value = int(CAT_ANIM[seg_angle])
			seg_angle = (seg_angle + 4) & 0x7F
			if int(CAT_ANIM[(seg_angle + 4) & 0x7F]) == 0xFF:
				seg_angle = (seg_angle + 4) & 0x7F
			if anim_value == 0xFF:
				anim_value = 0
			data["angle"] = seg_angle
			var path = "res://assets/objects/caterkiller/%02d.png" % (8 + clampi(anim_value, 0, 7))
			if ResourceLoader.exists(path):
				seg.texture = load(path)
		else:
			seg.texture = load("res://assets/objects/caterkiller/08.png")
		seg.flip_h = bool(data["flip"])
		seg.position.x = float(int(data["x_fixed"]) - cat_x_fixed) / 65536.0
		seg.position.y = float(int(data["y"]) - int(position.y))
		cat_segment_data[i] = data

func _begin_cat_fragmentation() -> void:
	if state == 3:
		return
	state = 3
	cat_fragment_timer = 480
	cat_fragment_data.clear()
	var speeds = [-0x200, -0x180, 0x180, 0x200]
	var sprites: Array[Sprite2D] = [sprite]
	for seg in body_sprites:
		sprites.append(seg)
	for i in range(sprites.size()):
		var sp = sprites[i]
		if sp == null or not is_instance_valid(sp):
			continue
		var wx = int(position.x + sp.position.x)
		var wy = int(position.y + sp.position.y)
		var vx = int(speeds[i])
		if x_flip:
			vx = -vx
		sp.visible = true
		sp.position = Vector2(wx - int(position.x), wy - int(position.y))
		if i == 0:
			_set_frame("caterkiller", 16 if cat_mouth_open else 0)
		else:
			sp.texture = load("res://assets/objects/caterkiller/08.png")
		cat_fragment_data.append({"sprite": sp, "x": float(wx), "y": float(wy), "vx": vx, "vy": -0x400, "head": i == 0})

func _tick_cat_fragments() -> void:
	cat_fragment_timer -= 1
	var any_visible = false
	for i in range(cat_fragment_data.size()):
		var data: Dictionary = cat_fragment_data[i]
		var raw = data.get("sprite")
		if raw == null or not is_instance_valid(raw):
			continue
		var sp = raw as Sprite2D
		var x = float(data["x"]) + float(int(data["vx"])) / 256.0
		var y = float(data["y"]) + float(int(data["vy"])) / 256.0
		var vy = GenesisMath.s16(int(data["vy"]) + SonicPlayer.GRAVITY)
		if vy >= 0:
			var probe_y = int(y) + (7 if bool(data["head"]) else 0)
			var hit = manager.collision.find_floor(int(x), probe_y, 13, 16, 0, false)
			var d = int(hit["distance"])
			if d < 0:
				y += d
				vy = -0x400
		data["x"] = x
		data["y"] = y
		data["vy"] = vy
		sp.position = Vector2(x - position.x, y - position.y)
		cat_fragment_data[i] = data
		if y < 0x900:
			any_visible = true
	if cat_fragment_timer <= 0 or not any_visible:
		request_delete(respawn_enabled)

func _set_frame(folder: String, frame: int) -> void:
	if sprite == null:
		return
	var path = "res://assets/objects/%s/%02d.png" % [folder, frame]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func _react_player() -> void:
	var p = player()
	if p == null or p.dead or not visible or state == 3:
		return
	var head_overlap = absi(p.pixel_x() - int(position.x)) <= p.width_radius + 14 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 16
	if head_overlap:
		if p.can_attack_object():
			var award = manager.register_badnik_hit()
			manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
			request_delete(respawn_enabled)
			if p.vel_y >= 0:
				p.vel_y = -p.vel_y
		else:
			p.apply_hazard_hit(int(position.x))
		return
	# React_CaterkillerBody sets the touched segment's break flag first, then runs
	# the ordinary hurt handler. The break flag propagates through the parent
	# chain until all four entries enter Cat_Fragment, even when Sonic is
	# invincible and therefore takes no damage.
	for seg in body_sprites:
		if not seg.visible:
			continue
		var sx = int(position.x + seg.position.x)
		var sy = int(position.y + seg.position.y)
		if absi(p.pixel_x() - sx) <= p.width_radius + 8 and absi(p.pixel_y() - sy) <= p.height_radius + 8:
			_begin_cat_fragmentation()
			p.apply_hazard_hit(sx)
			return
