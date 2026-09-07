class_name GameOverUI
extends Control

# Object $39 - GAME OVER / TIME OVER. The two mapping objects start 48 pixels
# off either screen edge, converge on screen center at $10 px/frame, then wait
# 12 seconds or until A/B/C (mapped here to the existing jump keys) is pressed.
var active = false
var time_over = false
var finished = false
var wait_timer = 0
var left_origin_x = -48.0
var right_origin_x = 368.0
var left_word: Sprite2D
var right_word: Sprite2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func begin(show_time_over: bool) -> void:
	time_over = show_time_over
	active = true
	finished = false
	wait_timer = 0
	left_origin_x = -48.0
	right_origin_x = 368.0
	visible = true
	_clear_words()
	left_word = _make_word("time_over_word" if time_over else "game")
	right_word = _make_word("over_time" if time_over else "over_game")
	_update_positions()

func tick() -> void:
	if not active:
		return
	if left_origin_x != 160.0 or right_origin_x != 160.0:
		left_origin_x = minf(160.0, left_origin_x + 16.0)
		right_origin_x = maxf(160.0, right_origin_x - 16.0)
		_update_positions()
		if left_origin_x == 160.0 and right_origin_x == 160.0:
			wait_timer = 12 * 60
		return

	if _confirm_pressed():
		_finish()
		return
	wait_timer -= 1
	if wait_timer <= 0:
		_finish()

func consume_finished() -> bool:
	if not finished:
		return false
	finished = false
	return true

func _finish() -> void:
	active = false
	finished = true
	visible = false

func _confirm_pressed() -> bool:
	return Input.is_action_pressed("A") or Input.is_action_pressed("B") or Input.is_action_pressed("C")

func _update_positions() -> void:
	# Generated mapping canvases are 160 px wide with mapping origin at x=80.
	if left_word != null:
		left_word.position = Vector2(left_origin_x - 80.0, 96.0)
	if right_word != null:
		right_word.position = Vector2(right_origin_x - 80.0, 96.0)

func _make_word(asset: String) -> Sprite2D:
	var s = Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path = "res://assets/ui/%s.png" % asset
	if ResourceLoader.exists(path):
		s.texture = load(path)
	add_child(s)
	return s

func _clear_words() -> void:
	if left_word != null and is_instance_valid(left_word):
		left_word.queue_free()
	if right_word != null and is_instance_valid(right_word):
		right_word.queue_free()
	left_word = null
	right_word = null
