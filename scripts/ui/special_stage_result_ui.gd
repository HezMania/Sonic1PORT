class_name SpecialStageResultUI
extends Control

# Phase 67: native Objects $7E/$7F result presentation.
const SCREEN_BIAS = 0x80
const MOVE_IN_SPEED = 0x10
const EMERALD_X: Array[int] = [0x110,0x128,0x0F8,0x140,0x0E0,0x158]
const EMERALD_Y = 0x0F0

# Header, SCORE, RING BONUS, oval, optional CONTINUE.
const BASE_START_X: Array[int] = [0x020,0x320,0x360,0x1EC,0x3A0]
const BASE_TARGET_X: Array[int] = [0x120,0x120,0x120,0x11C,0x120]
const ITEM_Y: Array[int] = [0x0C4,0x118,0x128,0x0C4,0x138]
const RING_ITEM = 2

var background: ColorRect
var item_nodes: Array[Node2D] = []
var item_art: Array[Sprite2D] = []
var score_digits: Array[Sprite2D] = []
var ring_digits: Array[Sprite2D] = []
var emerald_sprites: Array[Sprite2D] = []
var source_x: Array[int] = []
var target_x: Array[int] = []
var has_continue = false
var emeralds_visible = false
var flash_visible = false
var continue_foot_up = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

func _build() -> void:
	background = ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(320,224)
	background.color = SpecialStageResultArt.background_color()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -10
	add_child(background)
	for i in range(5):
		var node = Node2D.new()
		node.name = "SSRItem%d" % i
		# Earlier object-RAM entries win Genesis SAT overlap priority.
		node.z_index = 10 - i
		add_child(node)
		item_nodes.append(node)
		var art = Sprite2D.new()
		art.centered = false
		art.position = Vector2(-160,-32)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.add_child(art)
		item_art.append(art)
	item_art[1].texture = SpecialStageResultArt.texture_for_frame(SpecialStageResultArt.FRAME_SCORE)
	item_art[2].texture = SpecialStageResultArt.texture_for_frame(SpecialStageResultArt.FRAME_RING)
	item_art[3].texture = SpecialStageResultArt.texture_for_frame(SpecialStageResultArt.FRAME_OVAL)
	item_art[4].texture = SpecialStageResultArt.texture_for_frame(SpecialStageResultArt.FRAME_CONTINUE)
	for i in range(7):
		score_digits.append(_make_digit(item_nodes[1], Vector2(0x18 + i * 8, -8)))
	for i in range(5):
		ring_digits.append(_make_digit(item_nodes[2], Vector2(0x28 + i * 8, -8)))
	for i in range(6):
		var e = Sprite2D.new()
		e.centered = true
		e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		e.visible = false
		e.z_index = 2
		add_child(e)
		emerald_sprites.append(e)

func _make_digit(parent: Node2D, at: Vector2) -> Sprite2D:
	var s = Sprite2D.new()
	s.centered = false
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	return s

func begin(emerald_count: int, emerald_order: Array[int], continue_item: bool, score: int, ring_bonus: int) -> void:
	has_continue = continue_item
	emeralds_visible = false
	flash_visible = false
	continue_foot_up = false
	source_x.clear()
	target_x.clear()
	for value in BASE_START_X:
		source_x.append(value)
	for value in BASE_TARGET_X:
		target_x.append(value)
	var header_frame = SpecialStageResultArt.FRAME_SPECIAL_STAGE
	if emerald_count > 0:
		header_frame = SpecialStageResultArt.FRAME_CHAOS
	if emerald_count >= 6:
		header_frame = SpecialStageResultArt.FRAME_GOT_ALL
		source_x[0] = 0x018
		target_x[0] = 0x118
	item_art[0].texture = SpecialStageResultArt.texture_for_frame(header_frame)
	item_art[4].texture = SpecialStageResultArt.texture_for_frame(SpecialStageResultArt.FRAME_CONTINUE)
	for i in range(5):
		item_nodes[i].visible = i < 4 or has_continue
		_update_item_position(i)
	for i in range(6):
		emerald_sprites[i].visible = false
		if i < emerald_order.size():
			var frame = clampi(int(emerald_order[i]), 0, 5)
			emerald_sprites[i].texture = SpecialStageResultArt.emerald_texture(frame)
			emerald_sprites[i].position = Vector2(float(EMERALD_X[i] - SCREEN_BIAS), float(EMERALD_Y - SCREEN_BIAS))
	_update_values(score, ring_bonus)
	visible = true

func tick_move_in() -> bool:
	var ring_was = source_x[RING_ITEM] == target_x[RING_ITEM]
	for i in range(5):
		if i == 4 and not has_continue:
			continue
		source_x[i] = _approach(source_x[i], target_x[i], MOVE_IN_SPEED)
		_update_item_position(i)
	return (not ring_was and source_x[RING_ITEM] == target_x[RING_ITEM]) or ring_was

func show_emeralds(count: int) -> void:
	emeralds_visible = true
	flash_visible = false
	for i in range(emerald_sprites.size()):
		emerald_sprites[i].visible = false if i >= count else flash_visible

func tick_emerald_flash(count: int) -> void:
	if not emeralds_visible:
		return
	flash_visible = not flash_visible
	for i in range(emerald_sprites.size()):
		emerald_sprites[i].visible = i < count and flash_visible

func activate_continue() -> void:
	if not has_continue:
		return
	continue_foot_up = false
	item_art[4].texture = SpecialStageResultArt.texture_for_frame(SpecialStageResultArt.FRAME_CONT_SONIC_DOWN)

func tick_continue_animation(vblank_byte: int) -> void:
	if not has_continue:
		return
	if (vblank_byte & 0x0F) != 0:
		return
	continue_foot_up = not continue_foot_up
	item_art[4].texture = SpecialStageResultArt.texture_for_frame(
		SpecialStageResultArt.FRAME_CONT_SONIC_UP if continue_foot_up else SpecialStageResultArt.FRAME_CONT_SONIC_DOWN
	)

func update_values(score: int, ring_bonus: int) -> void:
	_update_values(score, ring_bonus)

func _update_values(score: int, ring_bonus: int) -> void:
	_set_decimal(score_digits, clampi(score, 0, 9999999), 1)
	_set_decimal(ring_digits, clampi(ring_bonus, 0, 99999), 1)

func _set_decimal(targets: Array[Sprite2D], value: int, minimum_digits: int) -> void:
	var text = str(value).pad_zeros(targets.size())
	var first_visible = maxi(0, targets.size() - maxi(minimum_digits, str(value).length()))
	for i in range(targets.size()):
		targets[i].visible = i >= first_visible
		if targets[i].visible:
			targets[i].texture = SpecialStageResultArt.digit_texture(int(text.substr(i,1)))

func _update_item_position(i: int) -> void:
	item_nodes[i].position = Vector2(float(source_x[i] - SCREEN_BIAS), float(ITEM_Y[i] - SCREEN_BIAS))

func _approach(value: int, target: int, speed: int) -> int:
	if value < target:
		return mini(value + speed, target)
	if value > target:
		return maxi(value - speed, target)
	return value
