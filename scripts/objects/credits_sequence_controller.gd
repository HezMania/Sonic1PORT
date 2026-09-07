class_name CreditsSequenceController
extends Node

# GM_Credits + credits-ending demos + Objects $8A/$8B/$8C. The normal level
# stack continues to own terrain/objects/camera while a demo is active; this
# controller owns the black credits pages, recorded controller stream, and the
# final TRY AGAIN / END screen.

const STATE_PAGE := 0
const STATE_DEMO := 1
const STATE_FINAL := 2
const STATE_COMPLETE := 3

const PAGE_FRAMES := 120
const FINAL_FRAMES := 1800
const GOOD_TANTRUM: Array[int] = [4,5,6,5,4,5,6,5,4,5,6,5,7,5,6,5]

var host: Node
var manager: SonicObjectManager
var player: SonicPlayer
var good_ending := false
var emerald_count := 0
var emerald_color_ids: Array[int] = []
var state := STATE_PAGE
var page_index := 0
var timer := PAGE_FRAMES
var exit_requested := false

var demo_index := -1
var demo_frames_remaining := 0
var demo_input_index := 0
var demo_input_remaining := 0
var demo_mask := 0

var overlay_layer: CanvasLayer
var black: ColorRect
var page_sprite: Sprite2D
var eggman_sprite: Sprite2D
var try_again_sprite: Sprite2D
var emerald_sprites: Array[Sprite2D] = []
var emerald_state: Array[Dictionary] = []
var good_anim_index := 0
var good_anim_timer := 0
var bad_stage := 0
var bad_stage_timer := 0

func setup(scene_host: Node, owner: SonicObjectManager, is_good: bool) -> void:
	host = scene_host
	manager = owner
	player = owner.player
	good_ending = is_good
	emerald_count = clampi(owner.emeralds, 0, 6)
	emerald_color_ids.clear()
	for color_variant in owner.emerald_color_ids:
		var color_id = int(color_variant)
		if color_id >= 0 and color_id < 6 and not emerald_color_ids.has(color_id):
			emerald_color_ids.append(color_id)
		if emerald_color_ids.size() >= emerald_count:
			break
	_create_overlay()
	_set_gameplay_ui(false)
	_show_page(0)

func is_demo_active() -> bool:
	return state == STATE_DEMO

func is_final_screen() -> bool:
	return state == STATE_FINAL

func current_demo_mask() -> int:
	return demo_mask if state == STATE_DEMO else 0

func begin_demo(index: int) -> void:
	demo_index = clampi(index, 0, CreditsDemoData.DEMOS.size() - 1)
	var demo: Dictionary = CreditsDemoData.DEMOS[demo_index]
	state = STATE_DEMO
	demo_frames_remaining = int(demo.get("frames", 540))
	demo_input_index = 0
	demo_input_remaining = 0
	demo_mask = 0
	black.visible = false
	page_sprite.visible = false
	eggman_sprite.visible = false
	try_again_sprite.visible = false
	_clear_final_emeralds()
	player = manager.player
	player.scripted_input_enabled = true
	player.scripted_input_mask = 0
	manager.time_frozen = false
	_load_current_demo_input()

func prepare_demo_frame() -> void:
	if state != STATE_DEMO:
		return
	player.scripted_input_enabled = true
	player.scripted_input_mask = demo_mask

func finish_demo_frame() -> void:
	if state != STATE_DEMO:
		return
	demo_frames_remaining -= 1
	demo_input_remaining -= 1
	if demo_input_remaining <= 0:
		demo_input_index += 1
		_load_current_demo_input()
	# Level_EndDemo also exits if the level has requested a restart. A native
	# player death is enough to end the showcase here instead of entering the
	# ordinary GAME OVER path.
	if demo_frames_remaining <= 0 or player.dead:
		player.scripted_input_enabled = false
		player.scripted_input_mask = 0
		manager.time_frozen = true
		_show_page(page_index + 1)

func tick_non_demo() -> void:
	if state == STATE_PAGE:
		timer -= 1
		if timer > 0:
			return
		if page_index >= 8:
			_start_final_screen()
			return
		state = STATE_DEMO
		if host != null and host.has_method("_credits_load_demo"):
			host.call("_credits_load_demo", page_index)
		return
	if state == STATE_FINAL:
		_tick_final_screen()

func request_exit() -> void:
	if state == STATE_FINAL:
		exit_requested = true
		state = STATE_COMPLETE

func teardown() -> void:
	if player != null:
		player.scripted_input_enabled = false
		player.scripted_input_mask = 0
	_set_gameplay_ui(true)
	if overlay_layer != null and is_instance_valid(overlay_layer):
		overlay_layer.queue_free()

func _show_page(index: int) -> void:
	page_index = clampi(index, 0, 8)
	state = STATE_PAGE
	timer = PAGE_FRAMES
	black.visible = true
	page_sprite.visible = true
	page_sprite.texture = SourceObjectArt.credits_page_texture(page_index, false)
	eggman_sprite.visible = false
	try_again_sprite.visible = false
	_clear_final_emeralds()
	if player != null:
		player.scripted_input_enabled = false
		player.scripted_input_mask = 0
	manager.time_frozen = true

func _load_current_demo_input() -> void:
	if demo_index < 0 or demo_index >= CreditsDemoData.DEMOS.size():
		demo_mask = 0
		demo_input_remaining = 0x7FFFFFFF
		return
	var sequence: Array = CreditsDemoData.DEMOS[demo_index].get("inputs", [])
	if demo_input_index < 0 or demo_input_index >= sequence.size():
		demo_mask = 0
		demo_input_remaining = 0x7FFFFFFF
		return
	var pair: Array = sequence[demo_input_index]
	demo_mask = int(pair[0])
	demo_input_remaining = maxi(1, int(pair[1]))

func _start_final_screen() -> void:
	state = STATE_FINAL
	timer = FINAL_FRAMES
	black.visible = true
	page_sprite.visible = false
	eggman_sprite.visible = true
	try_again_sprite.visible = not good_ending
	try_again_sprite.texture = SourceObjectArt.credits_page_texture(9, true)
	good_anim_index = 0
	good_anim_timer = 0
	bad_stage = 0
	bad_stage_timer = 6
	if good_ending:
		eggman_sprite.texture = SourceObjectArt.end_screen_eggman_texture(GOOD_TANTRUM[0])
	else:
		eggman_sprite.texture = SourceObjectArt.end_screen_eggman_texture(0)
		_spawn_bad_ending_emeralds()
	manager.time_frozen = true

func _tick_final_screen() -> void:
	# TryAgainEnd accepts the mapped Genesis Start action during the 30-second
	# final display (Enter by default, with the user's controller binding retained).
	if Input.is_action_pressed("Start"):
		exit_requested = true
		state = STATE_COMPLETE
		return
	timer -= 1
	if timer <= 0:
		exit_requested = true
		state = STATE_COMPLETE
		return
	if good_ending:
		good_anim_timer -= 1
		if good_anim_timer <= 0:
			good_anim_timer = 8
			good_anim_index = (good_anim_index + 1) % GOOD_TANTRUM.size()
			eggman_sprite.texture = SourceObjectArt.end_screen_eggman_texture(GOOD_TANTRUM[good_anim_index])
	else:
		_tick_bad_ending()

func _tick_bad_ending() -> void:
	_tick_bad_emeralds()
	bad_stage_timer -= 1
	if bad_stage_timer > 0:
		return
	match bad_stage:
		0:
			# Ani_EEgg tryagain1 ends in EEgg_Juggle; the raised-hand frame is
			# forced immediately after the emerald motion is armed.
			_start_bad_juggle(2)
			eggman_sprite.texture = SourceObjectArt.end_screen_eggman_texture(1)
			bad_stage = 1
			bad_stage_timer = 112
		1:
			eggman_sprite.texture = SourceObjectArt.end_screen_eggman_texture(2)
			bad_stage = 2
			bad_stage_timer = 6
		2:
			_start_bad_juggle(-2)
			eggman_sprite.texture = SourceObjectArt.end_screen_eggman_texture(3)
			bad_stage = 3
			bad_stage_timer = 112
		_:
			eggman_sprite.texture = SourceObjectArt.end_screen_eggman_texture(0)
			bad_stage = 0
			bad_stage_timer = 6

func _spawn_bad_ending_emeralds() -> void:
	_clear_final_emeralds()
	# Object $8C / TCha_LoadEmeralds walks color IDs 0..5 and skips every ID
	# present in v_emldlist. Phase 67 began retaining that exact color history,
	# so the TRY AGAIN screen can now reproduce the real missing-color set.
	var missing_count := maxi(0, 6 - emerald_count)
	var missing_colors: Array[int] = []
	for color_id in range(6):
		if emerald_color_ids.has(color_id):
			continue
		missing_colors.append(color_id)
		if missing_colors.size() >= missing_count:
			break

	for i in range(missing_colors.size()):
		var color_id: int = missing_colors[i]
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		spr.z_index = 4
		# Map_ECha frame 0 is the white flash; frames 1..6 are color IDs 0..5.
		spr.texture = SourceObjectArt.ending_emerald_texture(color_id + 1)
		overlay_layer.add_child(spr)
		emerald_sprites.append(spr)
		emerald_state.append({"angle": 0x80, "dir": 0, "delay": i * 10, "rest": i * 10})
		_update_bad_emerald_position(i)

func _start_bad_juggle(direction: int) -> void:
	for i in range(emerald_state.size()):
		var e: Dictionary = emerald_state[i]
		e["dir"] = direction
		e["angle"] = (int(e.get("angle", 0x80)) + direction * 8) & 0xFF
		emerald_state[i] = e

func _tick_bad_emeralds() -> void:
	for i in range(emerald_state.size()):
		var e: Dictionary = emerald_state[i]
		var direction: int = int(e.get("dir", 0))
		var delay: int = int(e.get("delay", 0))
		var angle: int = int(e.get("angle", 0x80)) & 0xFF
		if direction != 0:
			if delay > 0:
				delay -= 1
			else:
				angle = (angle + direction) & 0xFF
				if angle == 0 or angle == 0x80:
					direction = 0
					delay = int(e.get("rest", 0))
		e["dir"] = direction
		e["delay"] = delay
		e["angle"] = angle
		emerald_state[i] = e
		_update_bad_emerald_position(i)

func _update_bad_emerald_position(index: int) -> void:
	if index < 0 or index >= emerald_state.size() or index >= emerald_sprites.size():
		return
	# TCha_JuggleEmeralds uses CalcSine, radius $1C, MULS and ASR.L #8.
	# Keep the exact integer coordinate result instead of a floating sin/cos orbit.
	var angle: int = int(emerald_state[index].get("angle", 0x80)) & 0xFF
	var x_offset: int = (GenesisMath.cosine(angle) * 0x1C) >> 8
	var y_offset: int = (GenesisMath.sine(angle) * 0x1C) >> 8
	var centre := _screen_centre() + Vector2(0, -4)
	emerald_sprites[index].position = centre + Vector2(x_offset, y_offset)

func _clear_final_emeralds() -> void:
	for spr in emerald_sprites:
		if is_instance_valid(spr):
			spr.queue_free()
	emerald_sprites.clear()
	emerald_state.clear()

func _create_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 220
	host.add_child(overlay_layer)
	black = ColorRect.new()
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.position = Vector2.ZERO
	black.size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	black.color = Color.BLACK
	overlay_layer.add_child(black)

	page_sprite = Sprite2D.new()
	page_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	page_sprite.centered = true
	page_sprite.position = _screen_centre()
	page_sprite.z_index = 2
	overlay_layer.add_child(page_sprite)

	eggman_sprite = Sprite2D.new()
	eggman_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	eggman_sprite.centered = true
	eggman_sprite.position = _screen_centre() + Vector2(0, 4)
	eggman_sprite.z_index = 3
	eggman_sprite.visible = false
	overlay_layer.add_child(eggman_sprite)

	try_again_sprite = Sprite2D.new()
	try_again_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	try_again_sprite.centered = true
	try_again_sprite.position = _screen_centre()
	try_again_sprite.z_index = 2
	try_again_sprite.visible = false
	overlay_layer.add_child(try_again_sprite)

func _screen_centre() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")) * 0.5,
		float(ProjectSettings.get_setting("display/window/size/viewport_height")) * 0.5
	)

func _set_gameplay_ui(visible_state: bool) -> void:
	if host == null:
		return
	var hud := host.get_node_or_null("UI/SonicHUD")
	if hud != null:
		hud.visible = visible_state
	var end_card := host.get_node_or_null("UI/EndCard")
	if end_card != null and not visible_state:
		end_card.visible = false
	var game_over := host.get_node_or_null("UI/GameOverUI")
	if game_over != null:
		game_over.visible = false
