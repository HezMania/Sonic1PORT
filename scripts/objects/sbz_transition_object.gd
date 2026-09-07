class_name SBZTransitionObject
extends GenesisLevelObject

# Native bridge for the late SBZ2 scripted objects:
#   $83 False Floor / breakaway blocks
#   $82 Scrap Eggman / floor switch cutscene
# These are spawned by DLE_SBZ2 rather than the ordinary object-position list.

const MODE_FLOOR := 0
const MODE_EGGMAN := 1
const FLOOR_SUPPORT_ID := -0x83

const FLOOR_LEFT := 0x2000
const FLOOR_RIGHT := 0x2100
const FLOOR_Y := 0x5D0
const FLOOR_TOP := FLOOR_Y - 0x10
const FLOOR_BLOCK_FIRST_X := 0x2010
const FLOOR_BLOCK_COUNT := 8

const EGGMAN_START_X := 0x2160
const EGGMAN_START_Y := 0x5A4
const SWITCH_X := 0x2130
const SWITCH_Y := 0x5BC

var mode := MODE_FLOOR

# FalseFloor state.
var floor_breaking := false
var floor_break_index := 0
var floor_phase := 0
var floor_break_just_started := false
var floor_blocks: Array[Sprite2D] = []
var floor_fragments: Array[Dictionary] = []

# ScrapEggman state.
var floor_object: SBZTransitionObject
var eggman_sprite: Sprite2D
var switch_sprite: Sprite2D
var eggman_state := 0 # 0 wait, 1 laugh, 2 leap, 3 done/laugh
var eggman_delay := 0
var eggman_vx := 0 # 8.8 source velocity
var eggman_vy := 0
var eggman_fixed_x := 0
var eggman_fixed_y := 0
var switch_pressed := false
var anim_id := -1
var anim_frame_index := 0
var anim_timer := 0

func setup_false_floor(owner: SonicObjectManager) -> void:
	manager = owner
	object_id = 0x83
	mode = MODE_FLOOR
	position = Vector2.ZERO
	z_index = 38
	alive = true
	floor_breaking = false
	floor_break_index = 0
	floor_phase = 0
	floor_break_just_started = false
	floor_blocks.clear()
	floor_fragments.clear()
	for i in range(FLOOR_BLOCK_COUNT):
		var block := Sprite2D.new()
		block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		block.centered = true
		block.texture = SourceObjectArt.sbz_false_floor_texture(0)
		block.position = Vector2(FLOOR_BLOCK_FIRST_X + i * 0x20, FLOOR_Y)
		add_child(block)
		floor_blocks.append(block)

func setup_scrap_eggman(owner: SonicObjectManager, floor_ref: SBZTransitionObject) -> void:
	manager = owner
	object_id = 0x82
	mode = MODE_EGGMAN
	floor_object = floor_ref
	position = Vector2(EGGMAN_START_X, EGGMAN_START_Y)
	z_index = 46
	alive = true
	eggman_state = 0
	eggman_delay = 0
	eggman_vx = 0
	eggman_vy = 0
	eggman_fixed_x = EGGMAN_START_X << 16
	eggman_fixed_y = EGGMAN_START_Y << 16
	switch_pressed = false

	eggman_sprite = Sprite2D.new()
	eggman_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	eggman_sprite.centered = true
	add_child(eggman_sprite)

	switch_sprite = Sprite2D.new()
	switch_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	switch_sprite.centered = true
	switch_sprite.z_index = -1
	add_child(switch_sprite)
	_update_switch_sprite()
	_set_anim(0)

func begin_floor_break() -> void:
	if mode != MODE_FLOOR or floor_breaking:
		return
	floor_breaking = true
	floor_phase = 0
	floor_break_just_started = true
	var p := player()
	if p != null:
		p.clear_object_support_for(FLOOR_SUPPORT_ID, false)

func tick() -> void:
	if not alive:
		return
	if mode == MODE_FLOOR:
		_tick_false_floor()
	else:
		_tick_scrap_eggman()

func _tick_false_floor() -> void:
	var p := player()
	if not floor_breaking:
		if p != null:
			p.resolve_solid_box_contact(0x2080, FLOOR_Y, 0x80, 0x10, true, FLOOR_SUPPORT_ID)
		return

	# The floor controller was allocated before Eggman in the source OST, so the
	# frame in which Eggman writes "GO" has already executed FFloor_ChkBreak.
	# Preserve that one-frame ordering even though transient objects tick newest-first.
	if floor_break_just_started:
		floor_break_just_started = false
		if p != null:
			p.resolve_solid_box_contact(0x2080, FLOOR_Y, 0x80, 0x10, true, FLOOR_SUPPORT_ID)
		return

	# FFloor_Wait subtracts $0E from an 8-bit accumulator and breaks a block
	# on borrow. Starting at zero breaks the first block immediately, then
	# naturally produces the original alternating 18/19-frame cadence.
	var old_phase := floor_phase
	floor_phase = (floor_phase - 0x0E) & 0xFF
	if old_phase < 0x0E and floor_break_index < FLOOR_BLOCK_COUNT:
		_break_floor_block(floor_break_index)
		floor_break_index += 1

	# FFloor_Solid keeps only the still-intact right-hand portion solid.
	if p != null:
		if floor_break_index < FLOOR_BLOCK_COUNT:
			var half_width := (FLOOR_BLOCK_COUNT - floor_break_index) * 0x10
			var center_x := FLOOR_RIGHT - half_width
			p.resolve_solid_box_contact(center_x, FLOOR_Y, half_width, 0x10, true, FLOOR_SUPPORT_ID)
		else:
			p.clear_object_support_for(FLOOR_SUPPORT_ID, false)

	_tick_floor_fragments()

func _break_floor_block(index: int) -> void:
	if index < 0 or index >= floor_blocks.size():
		return
	var whole := floor_blocks[index]
	if whole != null and is_instance_valid(whole):
		whole.visible = false
	var block_x := FLOOR_BLOCK_FIRST_X + index * 0x20
	var offsets: Array[Vector2i] = [
		Vector2i(-8, -8), Vector2i(16, 0),
		Vector2i(0, 16), Vector2i(16, 16),
	]
	var initial_vy: Array[int] = [0x80, 0x00, 0x120, 0xC0]
	for i in range(4):
		var frag := Sprite2D.new()
		frag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frag.centered = true
		frag.texture = SourceObjectArt.sbz_false_floor_texture(i + 1)
		frag.position = Vector2(block_x + offsets[i].x, FLOOR_Y + offsets[i].y)
		add_child(frag)
		floor_fragments.append({
			"sprite": frag,
			"fixed_y": int(frag.position.y) << 16,
			"vy": initial_vy[i],
		})

func _tick_floor_fragments() -> void:
	for data in floor_fragments:
		var frag = data.get("sprite")
		if frag == null or not is_instance_valid(frag):
			continue
		var fixed_y := int(data.get("fixed_y", int(frag.position.y) << 16))
		var vy := int(data.get("vy", 0))
		fixed_y += vy << 8
		vy += 0x38
		data["fixed_y"] = fixed_y
		data["vy"] = vy
		frag.position.y = float(fixed_y >> 16)

func _tick_scrap_eggman() -> void:
	var p := player()
	match eggman_state:
		0:
			# SEgg_ChkSonic waits for Sonic to approach from the left within $80.
			if p != null and p.pixel_x() <= int(position.x) and int(position.x) - p.pixel_x() < 0x80:
				eggman_state = 1
				eggman_delay = 180
				_set_anim(1)
		1:
			eggman_delay -= 1
			if eggman_delay <= 0:
				eggman_state = 2
				eggman_delay = 15
				eggman_fixed_y += 4 << 16
				position.y = float(eggman_fixed_y >> 16)
				_set_anim(2)
		2:
			_tick_eggman_leap()
		3:
			pass
	_update_switch_position()
	_tick_anim()

func _tick_eggman_leap() -> void:
	if eggman_delay > 0:
		eggman_delay -= 1
		if eggman_delay > 0:
			return
		eggman_vx = -0xFC
		eggman_vy = -0x3C0

	var x_now := eggman_fixed_x >> 16
	var y_now := eggman_fixed_y >> 16
	if x_now <= 0x2132:
		eggman_vx = 0
	eggman_vy += 0x24
	if eggman_vy >= 0 and y_now >= 0x595 and not switch_pressed:
		switch_pressed = true
		_update_switch_sprite()
	if eggman_vy >= 0 and y_now >= 0x59B:
		eggman_fixed_y = 0x59B << 16
		eggman_vy = 0

	eggman_fixed_x += eggman_vx << 8
	eggman_fixed_y += eggman_vy << 8
	position = Vector2(float(eggman_fixed_x >> 16), float(eggman_fixed_y >> 16))

	if eggman_vx == 0 and eggman_vy == 0 and (eggman_fixed_y >> 16) >= 0x59B:
		if floor_object != null and is_instance_valid(floor_object):
			floor_object.begin_floor_break()
		eggman_state = 3
		_set_anim(1)

func _set_anim(new_anim: int) -> void:
	if anim_id == new_anim:
		return
	anim_id = new_anim
	anim_frame_index = 0
	anim_timer = 0
	_apply_anim_frame()

func _tick_anim() -> void:
	if eggman_sprite == null or not is_instance_valid(eggman_sprite):
		return
	var delay := 126
	if anim_id == 1:
		delay = 6
	elif anim_id == 2:
		delay = 14
	anim_timer += 1
	if anim_timer <= delay:
		return
	anim_timer = 0
	if anim_id == 1:
		anim_frame_index = (anim_frame_index + 1) % 2
	elif anim_id == 2:
		anim_frame_index = (anim_frame_index + 1) % 6
	else:
		anim_frame_index = 0
	_apply_anim_frame()

func _apply_anim_frame() -> void:
	if eggman_sprite == null or not is_instance_valid(eggman_sprite):
		return
	var frame := 0
	if anim_id == 1:
		var laugh_frames: Array[int] = [1, 2]
		frame = laugh_frames[anim_frame_index % laugh_frames.size()]
	elif anim_id == 2:
		var jump_frames: Array[int] = [3, 4, 4, 0, 0, 0]
		frame = jump_frames[anim_frame_index % jump_frames.size()]
	eggman_sprite.texture = SourceObjectArt.sbz_eggman_texture(frame)

func _update_switch_position() -> void:
	if switch_sprite == null or not is_instance_valid(switch_sprite):
		return
	# Keep the switch fixed in world space while Eggman moves.
	switch_sprite.position = Vector2(SWITCH_X - position.x, SWITCH_Y - position.y)

func _update_switch_sprite() -> void:
	if switch_sprite == null or not is_instance_valid(switch_sprite):
		return
	switch_sprite.texture = SourceObjectArt.sbz_eggman_switch_texture(switch_pressed)
	_update_switch_position()
