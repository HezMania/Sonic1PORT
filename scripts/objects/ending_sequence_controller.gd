class_name EndingSequenceController
extends Node2D

# GM_Ending + Objects $87/$88/$89. This controller owns only the scripted
# ending-sequence actors; terrain, camera, collision, and Object $28 animals
# continue through the normal native level stack.

const RUN_LEFT := 0
const SKID_RIGHT := 1
const REPLACE_SONIC := 2
const GOOD_STARE := 3
const GOOD_HOLD := 4
const GOOD_EMERALDS := 5
const GOOD_WHITE_OUT := 6
const GOOD_WHITE_IN := 7
const GOOD_CONFUSED := 8
const BAD_WAIT := 9
const LEAP := 10
const LOGO := 11
const CREDITS_HANDOFF := 12

const HOLD_FRAMES: Array[int] = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2]
const CONFUSED_FRAMES: Array[int] = [3, 4, 3, 4, 3, 4, 3]
const LEAP_FRAMES: Array[int] = [5, 5, 5, 6, 7]
const PALETTE_FADE_FRAMES := 22

var manager: SonicObjectManager
var player: SonicPlayer
var good_ending := false
var state := RUN_LEFT
var timer := 0
var anim_index := 0
var anim_timer := 0
var fake_sonic: Sprite2D
var emerald_sprites: Array[Sprite2D] = []
var emerald_angle_words: Array[int] = []
var emerald_radius_word := 0
var emerald_angle_speed_word := 0
var emerald_origin_y := 0
var logo: Sprite2D
var overlay_layer: CanvasLayer
var white_overlay: ColorRect
var credits_requested := false
var fake_sonic_active := false
var logo_arrived := false
var entry_fade_timer := PALETTE_FADE_FRAMES
var palette_fade: GenesisPaletteFade

func setup(owner: SonicObjectManager, is_good: bool) -> void:
	manager = owner
	player = owner.player
	good_ending = is_good
	position = Vector2.ZERO
	manager.time_frozen = true
	manager.rings = 0
	player.control_locked = true
	player.control_lock_direction = -1
	player.facing_left = true
	# Source writes -$800, with Sonic's ordinary cap immediately restricting it
	# to -$600. Begin at the effective capped speed.
	player.inertia = -0x600
	player.vel_x = -0x600
	player.shield = false
	player.invincible_timer = 0
	player.shoes_timer = 0
	player.display_hidden = false
	player.object_control_override = false

	fake_sonic = Sprite2D.new()
	fake_sonic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fake_sonic.centered = true
	fake_sonic.z_index = 52
	fake_sonic.visible = false
	add_child(fake_sonic)

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 100
	add_child(overlay_layer)
	white_overlay = ColorRect.new()
	white_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white_overlay.position = Vector2.ZERO
	white_overlay.size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	white_overlay.color = Color(1, 1, 1, 0)
	white_overlay.visible = false
	overlay_layer.add_child(white_overlay)

	palette_fade = GenesisPaletteFade.new()
	palette_fade.name = "EndingPaletteFade"
	add_child(palette_fade)
	palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, 0)
	entry_fade_timer = PALETTE_FADE_FRAMES

	var scene := get_tree().current_scene
	if scene != null:
		var hud := scene.get_node_or_null("UI/SonicHUD")
		if hud != null:
			hud.visible = false
		var end_card := scene.get_node_or_null("UI/EndCard")
		if end_card != null:
			end_card.visible = false
		var game_over := scene.get_node_or_null("UI/GameOverUI")
		if game_over != null:
			game_over.visible = false

func tick() -> void:
	# GM_Ending loads its scene, builds sprites once, then performs the standard
	# 22-frame PaletteFadeIn before End_MainLoop starts advancing Sonic.
	if entry_fade_timer > 0:
		var entry_step := PALETTE_FADE_FRAMES - entry_fade_timer
		palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, entry_step)
		entry_fade_timer -= 1
		if entry_fade_timer <= 0:
			palette_fade.hide_fade()
		return
	match state:
		RUN_LEFT:
			_tick_run_left()
		SKID_RIGHT:
			_tick_skid_right()
		REPLACE_SONIC:
			_tick_replace()
		GOOD_STARE:
			_tick_good_stare()
		GOOD_HOLD:
			_tick_good_hold()
		GOOD_EMERALDS:
			_tick_good_emeralds()
		GOOD_WHITE_OUT:
			_tick_white_out()
		GOOD_WHITE_IN:
			_tick_white_in()
		GOOD_CONFUSED:
			_tick_confused()
		BAD_WAIT:
			_tick_bad_wait()
		LEAP:
			_tick_leap()
		LOGO:
			_tick_logo()
		CREDITS_HANDOFF:
			pass

func _tick_run_left() -> void:
	# End_MoveSonic script 0: keep holding left until Sonic passes $90.
	if player.pixel_x() < 0x90:
		state = SKID_RIGHT
		player.control_lock_direction = 1

func _tick_skid_right() -> void:
	# Script 2: simulated right input makes Sonic skid and turn back toward $A0.
	if player.pixel_x() >= 0xA0:
		player.control_lock_direction = 0
		player.inertia = 0
		player.vel_x = 0
		player.vel_y = 0
		player.force_set_pixel_position(0xA0, player.pixel_y())
		# End_MoveSon2: obFrame=fr_Wait2 (3), id_Wait, obTimeFrame=3.
		player.forced_visual_frame = 3
		state = REPLACE_SONIC
		timer = 1

func _tick_replace() -> void:
	# End_MoveSon3 runs on the next frame and replaces the real Sonic OST entry.
	timer -= 1
	if timer > 0:
		return
	player.force_set_pixel_position(0xA0, player.pixel_y())
	player.control_lock_direction = 0
	player.inertia = 0
	player.vel_x = 0
	player.vel_y = 0
	if good_ending:
		_start_fake_sonic(0)
		state = GOOD_STARE
		timer = 80
	else:
		# The bad-ending fake object retains the ordinary Sonic render fields until
		# ESon_BadEnding's 216-frame timer expires, so keep native Sonic visible.
		state = BAD_WAIT
		timer = 216

func _start_fake_sonic(frame: int) -> void:
	player.forced_visual_frame = -1
	player.object_control_override = true
	player.display_hidden = true
	player.refresh_visual()
	fake_sonic_active = true
	fake_sonic.visible = true
	fake_sonic.position = Vector2(0xA0, player.pixel_y())
	_set_fake_frame(frame)

func _tick_good_stare() -> void:
	timer -= 1
	if timer > 0:
		return
	state = GOOD_HOLD
	anim_index = 0
	anim_timer = 0

func _tick_good_hold() -> void:
	if _advance_script(HOLD_FRAMES, 3):
		# Emerald objects exist from the start of the hold animation but remain
		# undisplayed until Sonic reaches its final frame 2. Spawn them there.
		if emerald_sprites.is_empty():
			_spawn_emeralds()
		state = GOOD_EMERALDS

func _tick_good_emeralds() -> void:
	_update_emeralds()
	if emerald_radius_word >= 0x2000:
		state = GOOD_WHITE_OUT
		timer = 90
		white_overlay.visible = false
		palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_OUT, 0)

func _tick_white_out() -> void:
	_update_emeralds()
	# End_AllEmlds sets v_palchgspeed=0, then WhiteOut_ToWhite once every
	# three frames while the 90-frame emerald flash continues. The shader is
	# driven by those discrete CRAM steps instead of a linear white overlay.
	var elapsed := 90 - timer
	var step := mini(GenesisPaletteFade.SOURCE_STEPS, 1 + int(elapsed / 3))
	palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_OUT, step)
	timer -= 1
	if timer > 0:
		return
	_delete_emeralds()
	_apply_good_ending_flowers()
	state = GOOD_WHITE_IN
	timer = PALETTE_FADE_FRAMES
	palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_IN, 0)

func _tick_white_in() -> void:
	var step := PALETTE_FADE_FRAMES - timer
	palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_IN, step)
	timer -= 1
	if timer > 0:
		return
	palette_fade.hide_fade()
	state = GOOD_CONFUSED
	anim_index = 0
	anim_timer = 0

func _tick_confused() -> void:
	if timer > 0:
		timer -= 1
		if timer <= 0:
			_start_leap()
		return
	if _advance_script(CONFUSED_FRAMES, 5):
		timer = 60

func _tick_bad_wait() -> void:
	timer -= 1
	if timer > 0:
		return
	_start_fake_sonic(5)
	_start_leap()

func _start_leap() -> void:
	state = LEAP
	anim_index = 0
	anim_timer = 0
	_spawn_logo()

func _tick_leap() -> void:
	# Object $89 begins moving on the same frame the leap animation starts.
	_tick_logo()
	if _advance_script(LEAP_FRAMES, 3):
		# afBack,1 leaves the final dramatic frame displayed while the logo runs.
		_set_fake_frame(7)
		state = LOGO

func _spawn_logo() -> void:
	if logo != null:
		return
	logo = Sprite2D.new()
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.centered = true
	logo.texture = SourceObjectArt.ending_logo_texture()
	logo.position = Vector2(-160, 88)
	logo.z_index = 10
	overlay_layer.add_child(logo)

func _tick_logo() -> void:
	if logo == null:
		return
	if not logo_arrived:
		logo.position.x = minf(64.0, logo.position.x + 16.0)
		if logo.position.x < 64:
			return
		logo_arrived = true
		timer = 300
		return
	timer -= 1
	if timer < 0:
		credits_requested = true
		state = CREDITS_HANDOFF
		manager.time_frozen = true

func _advance_script(frames: Array[int], delay: int) -> bool:
	if anim_index >= frames.size():
		return true
	if anim_timer <= 0:
		_set_fake_frame(frames[anim_index])
		# AnimateSprite delay byte N keeps a frame for N+1 VBlanks.
		anim_timer = delay + 1
		anim_index += 1
	anim_timer -= 1
	return anim_index >= frames.size() and anim_timer <= 0

func _set_fake_frame(frame: int) -> void:
	fake_sonic.texture = SourceObjectArt.ending_sonic_texture(frame)

func _spawn_emeralds() -> void:
	emerald_origin_y = int(fake_sonic.position.y)
	emerald_radius_word = 0
	emerald_angle_speed_word = 0
	for i in range(6):
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		spr.z_index = 53
		spr.texture = SourceObjectArt.ending_emerald_texture(i + 1)
		add_child(spr)
		emerald_sprites.append(spr)
		emerald_angle_words.append(((i * int(0x100 / 6)) & 0xFF) << 8)
	_update_emerald_positions()

func _update_emeralds() -> void:
	if emerald_sprites.is_empty():
		return
	for i in range(emerald_angle_words.size()):
		emerald_angle_words[i] = (emerald_angle_words[i] + emerald_angle_speed_word) & 0xFFFF
	if emerald_radius_word < 0x2000:
		emerald_radius_word = mini(0x2000, emerald_radius_word + 0x20)
	if emerald_angle_speed_word < 0x2000:
		emerald_angle_speed_word = mini(0x2000, emerald_angle_speed_word + 0x20)
	if emerald_origin_y > 0x140:
		emerald_origin_y -= 1
	_update_emerald_positions()

func _update_emerald_positions() -> void:
	var radius := float((emerald_radius_word >> 8) & 0xFF)
	for i in range(emerald_sprites.size()):
		var angle_byte := (emerald_angle_words[i] >> 8) & 0xFF
		var radians := float(angle_byte) * TAU / 256.0
		emerald_sprites[i].position = Vector2(
			fake_sonic.position.x + cos(radians) * radius,
			float(emerald_origin_y) + sin(radians) * radius
		)

func _delete_emeralds() -> void:
	for spr in emerald_sprites:
		if is_instance_valid(spr):
			spr.queue_free()
	emerald_sprites.clear()
	emerald_angle_words.clear()

func _apply_good_ending_flowers() -> void:
	# End_AllEmlds swaps row 1 / columns 0-1 from $28/$29 to $2E/$2F after
	# the white flash. The retained source map256 data supplies those variants.
	if player.level == null:
		return
	player.level.set_chunk_id_at(0, 1, 0x2E)
	player.level.set_chunk_id_at(1, 1, 0x2F)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("refresh_level_chunk"):
		scene.call("refresh_level_chunk", 0, 1)
		scene.call("refresh_level_chunk", 1, 1)
