class_name S2ARZSwingObject
extends GenesisLevelObject

var platform_sprites: Array[Sprite2D] = []
var link_sprites: Array[Sprite2D] = []
var anchor_sprite: Sprite2D
var frame_counter: int = 0
var angle_word: int = 0
var detached: bool = false
var detaching: bool = false
var vel_x: int = 0
var vel_y: int = 0
var water_base_y: int = 0
var old_platform_positions: Array[Vector2] = []

func initialize_object() -> void:
	active_width = 0x20
	if object_id == 0x83:
		_init_rotator()
	else:
		_init_swing()

func _new_visual(frame: int, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.z_index = z
	# Obj15 is shared code across ARZ/OOZ, but the default art bank is the
	# Oil Ocean swinging-platform Nemesis art. Use the retail zone-local bank
	# when OOZ owns the placement instead of borrowing Aquatic Ruin graphics.
	var zone_root: String = "s2_ooz" if manager != null and bool(manager.level_definition.get("s2_ooz", false)) else "s2_arz"
	var path: String = "res://assets/objects/%s/swing/%02d.png" % [zone_root, frame]
	if ResourceLoader.exists(path): s.texture = load(path)
	add_child(s)
	return s

func _init_swing() -> void:
	var links: int = maxi(1, subtype & 0x0F)
	anchor_sprite = _new_visual(2, 0)
	for i in range(links):
		var l: Sprite2D = _new_visual(1, 0)
		link_sprites.append(l)
	var pform: Sprite2D = _new_visual(0, 1)
	platform_sprites.append(pform)
	old_platform_positions.append(Vector2.ZERO)
	angle_word = 0x8000

func _init_rotator() -> void:
	angle_word = 0
	if x_flip: angle_word |= 0x4000
	if y_flip: angle_word |= 0x8000
	anchor_sprite = _new_visual(2, 0)
	for i in range(9): link_sprites.append(_new_visual(1, 0))
	for i in range(3):
		platform_sprites.append(_new_visual(0, 1))
		old_platform_positions.append(Vector2.ZERO)

func tick() -> void:
	frame_counter += 1
	if object_id == 0x83: _tick_rotator()
	else: _tick_swing()

func _tick_swing() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var link_count: int = link_sprites.size()
	if detached:
		var old_pos: Vector2 = platform_sprites[0].position
		if vel_y != 0 or water_base_y == 0:
			platform_sprites[0].position.x += float(vel_x) / 256.0
			platform_sprites[0].position.y += float(vel_y) / 256.0
			vel_y = GenesisMath.s16(vel_y + 0x18)
			var water: Variant = manager.get_lz_water_y()
			if water != null and int(position.y + platform_sprites[0].position.y) >= int(water):
				platform_sprites[0].position.y = float(int(water) - int(position.y))
				water_base_y = int(platform_sprites[0].position.y)
				vel_y = 0; vel_x = 0x100
		else:
			platform_sprites[0].position.x += float(vel_x) / 256.0
			platform_sprites[0].position.y = float(water_base_y + (manager.s2_source_osc_byte(0x14) >> 1))
			var probe_x: int = int(position.x + platform_sprites[0].position.x) + 0x20
			var wall: Dictionary = manager.collision.find_right_wall_sensor(probe_x, int(position.y + platform_sprites[0].position.y), false)
			if int(wall.get("distance", 8)) < 0: vel_x = 0
		_resolve_platform(0, old_pos)
		return

	var osc: int = manager.s2_source_osc_byte(0x18)
	var source_angle: int = osc
	var mode: int = subtype & 0x70
	if mode == 0x10 and source_angle < 0x40: source_angle = 0x40
	elif mode == 0x30 and source_angle > 0x40: source_angle = 0x40
	var angle: int = source_angle
	if x_flip: angle = (0x80 - angle) & 0xFF
	var sinv: int = GenesisMath.sine(angle)
	var cosv: int = GenesisMath.cosine(angle)
	for i in range(link_count):
		var length: int = (i + 1) * 16
		link_sprites[i].position = Vector2(float((cosv * length) >> 8), float((sinv * length) >> 8))
	var platform_length: int = link_count * 16 + 8
	var old_pos: Vector2 = platform_sprites[0].position
	platform_sprites[0].position = Vector2(float((cosv * platform_length) >> 8), float((sinv * platform_length) >> 8))
	_resolve_platform(0, old_pos)
	if (subtype & 0x80) != 0 and not detaching and p.standing_on_object and p.support_record_index == record_index:
		detaching = true
	if detaching and osc == 0:
		detached = true
		vel_x = -0x200 if x_flip else 0x200
		vel_y = 0

func _tick_rotator() -> void:
	var speed: int = GenesisMath.s8(subtype & 0xF0) << 3
	angle_word = (angle_word + speed) & 0xFFFF
	var arm_phases: Array[int] = [0, 85, 171]
	for arm in range(3):
		var phase: int = ((angle_word >> 8) + arm_phases[arm]) & 0xFF
		var sinv: int = GenesisMath.sine(phase)
		var cosv: int = GenesisMath.cosine(phase)
		for j in range(3):
			var li: int = arm * 3 + j
			var radius: int = (j + 1) * 16
			link_sprites[li].position = Vector2(float((cosv * radius) >> 8), float((sinv * radius) >> 8))
		var old_pos: Vector2 = platform_sprites[arm].position
		platform_sprites[arm].position = Vector2(float((cosv * 64) >> 8), float((sinv * 64) >> 8))
		_resolve_platform(arm, old_pos)

func _resolve_platform(index: int, old_local: Vector2) -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var local: Vector2 = platform_sprites[index].position
	var wx: int = int(position.x + local.x)
	var wy: int = int(position.y + local.y)
	var dx: int = int(round(local.x - old_local.x))
	var dy: int = int(round(local.y - old_local.y))
	var top_y: int = wy - (0x10 if manager != null and bool(manager.level_definition.get("s2_ooz", false)) else 8)
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, dx, dy, wx-0x20, wx+0x20, top_y)
	p.resolve_platform_top(wx-0x20, wx+0x20, top_y, record_index)
