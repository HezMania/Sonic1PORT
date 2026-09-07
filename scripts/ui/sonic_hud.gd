class_name SonicHUD
extends Control

# Native Object $21 / HUD_Update presentation. Static lettering comes from
# HUD.nem while the runtime digits come from HUD Numbers.unc and the life
# counter art. Positions match the 320x224 screen coordinates of Map_HUD.
var manager: SonicObjectManager
var tick_count = 0

var score_label: Sprite2D
var score_e: Sprite2D
var time_label: Sprite2D
var colon: Sprite2D
var rings_a: Sprite2D
var rings_s: Sprite2D
var life_icon: Sprite2D
var life_text: Sprite2D
var score_digits: Array[Sprite2D] = []
var time_digits: Array[Sprite2D] = []
var ring_digits: Array[Sprite2D] = []
var life_digits: Array[Sprite2D] = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	score_label = _sprite("scor_yellow", Vector2(16, 8))
	score_e = _sprite("score_e", Vector2(48, 8))
	for i in range(7):
		score_digits.append(_sprite("digit_0", Vector2(56 + i * 8, 8)))

	time_label = _sprite("time_yellow", Vector2(16, 24))
	time_digits.append(_sprite("digit_0", Vector2(56, 24)))
	colon = _sprite("colon", Vector2(64, 24))
	time_digits.append(_sprite("digit_0", Vector2(72, 24)))
	time_digits.append(_sprite("digit_0", Vector2(80, 24)))

	rings_a = _sprite("rings_a_yellow", Vector2(16, 40))
	rings_s = _sprite("rings_s_yellow", Vector2(48, 40))
	for i in range(3):
		ring_digits.append(_sprite("digit_0", Vector2(64 + i * 8, 40)))

	life_icon = _sprite("life_icon", Vector2(16, 200))
	life_text = _sprite("life_text", Vector2(32, 200))
	# The original map reserves the right side of the SONIC x N sprite piece
	# for the two dynamically-written 8x8 life-counter digits.
	life_digits.append(_sprite("life_digit_0", Vector2(48, 208))) # tile +9
	life_digits.append(_sprite("life_digit_0", Vector2(56, 208))) # tile +10

	_update_values()

func tick() -> void:
	if manager == null:
		return
	tick_count += 1
	visible = not manager.special_stage_requested
	_update_flash()
	_update_values()

func _update_flash() -> void:
	# HUD_Flash uses v_framebyte bit 3: labels flash every eight frames. Zero
	# rings flash RINGS red; once minute 9 is reached TIME flashes red too.
	var flash_red = (tick_count & 8) == 0
	var rings_red = manager.rings == 0 and flash_red
	var time_red = manager.time_minutes() >= 9 and flash_red
	_set_named_texture(rings_a, "rings_a_red" if rings_red else "rings_a_yellow")
	_set_named_texture(rings_s, "rings_s_red" if rings_red else "rings_s_yellow")
	_set_named_texture(time_label, "time_red" if time_red else "time_yellow")

func _update_values() -> void:
	var score_value = clampi(manager.score, 0, 9999990)
	_set_decimal(score_digits, score_value, true, 1)

	var minutes = manager.time_minutes()
	var seconds = manager.time_seconds()
	_set_digit(time_digits[0], minutes)
	_set_digit(time_digits[1], int(seconds / 10))
	_set_digit(time_digits[2], seconds % 10)

	_set_decimal(ring_digits, clampi(manager.rings, 0, 999), true, 1)
	_set_decimal(life_digits, clampi(manager.lives, 0, 99), true, 1, true)

func _set_decimal(targets: Array[Sprite2D], value: int, blank_leading: bool, minimum_digits: int, small: bool = false) -> void:
	var text = str(value).pad_zeros(targets.size())
	var first_visible = maxi(0, targets.size() - maxi(minimum_digits, str(value).length()))
	for i in range(targets.size()):
		var digit = int(text.substr(i, 1))
		targets[i].visible = not blank_leading or i >= first_visible
		if targets[i].visible:
			if small:
				_set_named_texture(targets[i], "life_digit_%d" % digit)
			else:
				_set_named_texture(targets[i], "digit_%d" % digit)

func _set_digit(target: Sprite2D, value: int) -> void:
	target.visible = true
	_set_named_texture(target, "digit_%d" % clampi(value, 0, 9))

func _sprite(asset: String, at: Vector2) -> Sprite2D:
	var s = Sprite2D.new()
	s.centered = false
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	_set_named_texture(s, asset)
	return s

func _set_named_texture(target: Sprite2D, asset: String) -> void:
	var path = "res://assets/ui/%s.png" % asset
	if ResourceLoader.exists(path):
		target.texture = load(path)
