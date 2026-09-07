class_name EndCardUI
extends Control

# Phase 60: native Object $3A "SONIC HAS PASSED" results card.  All seven
# source sprite elements use the original mappings/art and move independently
# in Genesis screen coordinates (which include the +$80 hardware sprite bias).

const SCREEN_BIAS := 0x80
const MOVE_IN_SPEED := 0x10
const MOVE_OUT_SPEED := 0x20

# Got_ItemData source values, in object-RAM order:
# SONIC HAS, PASSED, ACT, SCORE, TIME BONUS, RING BONUS, blue oval.
const START_X: Array[int] = [0x004, -0x120, 0x40C, 0x520, 0x540, 0x560, 0x20C]
const TARGET_X: Array[int] = [0x124, 0x120, 0x14C, 0x120, 0x120, 0x120, 0x14C]
const ITEM_Y: Array[int] = [0xBC, 0xD0, 0xD6, 0xEC, 0xFC, 0x10C, 0xCC]
const RING_BONUS_ITEM := 5

var manager: SonicObjectManager
var item_nodes: Array[Node2D] = []
var source_x: Array[int] = []
var score_digits: Array[Sprite2D] = []
var time_digits: Array[Sprite2D] = []
var ring_digits: Array[Sprite2D] = []
var appeared := false
var tally_wait_started := false
var sbz2_move_out_complete := false

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_card()
	reset_for_level()

func _build_card() -> void:
	if not item_nodes.is_empty():
		return
	for i in range(7):
		var node = Node2D.new()
		node.name = "ResultItem%d" % i
		# Earlier Genesis SAT entries win overlapping sprite priority.  Godot's
		# sibling order is the reverse, so preserve the source order explicitly.
		node.z_index = 7 - i
		add_child(node)
		item_nodes.append(node)

		var art = Sprite2D.new()
		art.centered = false
		art.position = Vector2(-128, -32)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.add_child(art)
		match i:
			0:
				art.texture = EndCardArt.texture_for_frame(EndCardArt.FRAME_SONIC_HAS)
			1:
				art.texture = EndCardArt.texture_for_frame(EndCardArt.FRAME_PASSED)
			2:
				art.texture = LevelTitleCardArt.texture_for_frame(LevelTitleCardArt.FRAME_ACT1)
			3:
				art.texture = EndCardArt.texture_for_frame(EndCardArt.FRAME_SCORE)
			4:
				art.texture = EndCardArt.texture_for_frame(EndCardArt.FRAME_TIME_BONUS)
			5:
				art.texture = EndCardArt.texture_for_frame(EndCardArt.FRAME_RING_BONUS)
			6:
				art.texture = LevelTitleCardArt.texture_for_frame(LevelTitleCardArt.FRAME_OVAL)

	# Map_Got places seven live score digits at +$18 and five bonus digits at
	# +$28.  The source updates these VRAM glyphs during the tally; child sprites
	# reproduce the same result without rebuilding the card textures.
	for i in range(7):
		score_digits.append(_make_digit(item_nodes[3], Vector2(0x18 + i * 8, -8)))
	for i in range(5):
		time_digits.append(_make_digit(item_nodes[4], Vector2(0x28 + i * 8, -8)))
		ring_digits.append(_make_digit(item_nodes[5], Vector2(0x28 + i * 8, -8)))

func _make_digit(parent: Node2D, at: Vector2) -> Sprite2D:
	var s = Sprite2D.new()
	s.centered = false
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	return s

func reset_for_level() -> void:
	visible = false
	appeared = false
	tally_wait_started = false
	sbz2_move_out_complete = false
	source_x.clear()
	for value in START_X:
		source_x.append(value)
	for i in range(item_nodes.size()):
		_update_item_position(i)
	if item_nodes.size() > 2 and manager != null:
		var act = clampi(int(manager.level_definition.get("act", 1)), 1, 3)
		var art = item_nodes[2].get_child(0) as Sprite2D
		art.texture = LevelTitleCardArt.texture_for_frame(LevelTitleCardArt.FRAME_ACT1 + act - 1)
	_update_values()

func tick() -> void:
	if manager == null:
		return

	if manager.sbz2_post_tally_started:
		_tick_sbz2_move_out()
		return

	if not manager.act_complete:
		if appeared:
			reset_for_level()
		return

	if not appeared:
		appeared = true
		visible = true
		var act = clampi(int(manager.level_definition.get("act", 1)), 1, 3)
		var art = item_nodes[2].get_child(0) as Sprite2D
		art.texture = LevelTitleCardArt.texture_for_frame(LevelTitleCardArt.FRAME_ACT1 + act - 1)

	var ring_was_at_target = source_x[RING_BONUS_ITEM] == TARGET_X[RING_BONUS_ITEM]
	for i in range(item_nodes.size()):
		source_x[i] = _approach(source_x[i], TARGET_X[i], MOVE_IN_SPEED)
		_update_item_position(i)
	_update_values()

	# In Object $3A only the RING BONUS element advances to Got_Wait and starts
	# the three-second pre-tally delay after it reaches its target.
	if not tally_wait_started and not ring_was_at_target and source_x[RING_BONUS_ITEM] == TARGET_X[RING_BONUS_ITEM]:
		tally_wait_started = true
		manager.begin_end_tally_wait()
	elif not tally_wait_started and ring_was_at_target:
		tally_wait_started = true
		manager.begin_end_tally_wait()

func _tick_sbz2_move_out() -> void:
	if sbz2_move_out_complete:
		visible = false
		return
	visible = true
	appeared = true
	var all_gone = true
	for i in range(item_nodes.size()):
		source_x[i] = _approach(source_x[i], START_X[i], MOVE_OUT_SPEED)
		if source_x[i] != START_X[i]:
			all_gone = false
		_update_item_position(i)
	_update_values()
	if all_gone:
		sbz2_move_out_complete = true
		visible = false
		manager.complete_sbz2_card_move_out()

func _update_item_position(i: int) -> void:
	if i < 0 or i >= item_nodes.size() or i >= source_x.size():
		return
	item_nodes[i].position = Vector2(float(source_x[i] - SCREEN_BIAS), float(ITEM_Y[i] - SCREEN_BIAS))

func _update_values() -> void:
	if manager == null:
		return
	_set_decimal(score_digits, clampi(manager.score, 0, 9999990), 1)
	_set_decimal(time_digits, clampi(manager.time_bonus, 0, 99999), 1)
	_set_decimal(ring_digits, clampi(manager.ring_bonus, 0, 99999), 1)

func _set_decimal(targets: Array[Sprite2D], value: int, minimum_digits: int) -> void:
	var text = str(value).pad_zeros(targets.size())
	var first_visible = maxi(0, targets.size() - maxi(minimum_digits, str(value).length()))
	for i in range(targets.size()):
		targets[i].visible = i >= first_visible
		if targets[i].visible:
			var digit = int(text.substr(i, 1))
			targets[i].texture = EndCardArt.digit_texture(digit)

func _approach(value: int, target: int, speed: int) -> int:
	if value < target:
		return mini(value + speed, target)
	if value > target:
		return maxi(value - speed, target)
	return value
