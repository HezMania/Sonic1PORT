class_name StartupSequenceController
extends Node

# Native presentation controller for GM_Sega + GM_Title and the four retail
# attract slots. Phase 48 routes slot 4 to the dedicated Special Stage runtime.

const STATE_SEGA_SCAN := 0
const STATE_SEGA_PCM := 1
const STATE_SEGA_WAIT := 2
const STATE_SONIC_TEAM := 3
const STATE_TITLE := 4
const STATE_TITLE_PREDEMO := 5
const STATE_DEMO := 6
const STATE_SEGA_FADE_OUT := 7
const STATE_TITLE_FADE_IN := 8
const STATE_LEVEL_SELECT := 9

const SEGA_SCAN_FRAMES := 76
const SEGA_PCM_FALLBACK_FRAMES := 50
const SEGA_WAIT_FRAMES := 30
const SONIC_TEAM_FRAMES := 120
const TITLE_FRAMES := 376
const TITLE_PREDEMO_FRAMES := 30
const TITLE_SONIC_DELAY := 30
const PALETTE_FADE_FRAMES := 22

var host: Node
var manager: SonicObjectManager
var player: SonicPlayer
var demo_slot := 0
var state := STATE_SEGA_SCAN
var timer := SEGA_SCAN_FRAMES
var start_game_requested := false
var demo_requested := -1
var restart_requested := false
var level_select_enabled := false
var level_select_code_index := 0
var level_select_c_count := 0
var level_select_item := 0
var level_select_sound := 0
var level_select_delay := 0
var level_select_level_request := Vector2i(-1, -1)
var level_select_special_request := false

var demo_index := -1
var demo_frames_remaining := 0
var demo_input_index := 0
var demo_input_remaining := 0
var demo_mask := 0

var overlay_layer: CanvasLayer
var backdrop: ColorRect
var sega_sprite: Sprite2D
var sega_scan_bar: ColorRect
var stp_sprite: Sprite2D
var title_emblem_low: Sprite2D
var title_sonic: Sprite2D
var title_emblem_high: Sprite2D
var press_start: Sprite2D
var trademark: Sprite2D
var level_select_sprite: Sprite2D
var audio: AudioStreamPlayer
var palette_fade: GenesisPaletteFade
var sega_palette_image: Image
var sega_palette_texture: ImageTexture
var sega_palette_fast_path := false

var title_elapsed := 0
var title_sonic_y := 94.0
var title_sonic_anim_frame := 0
var title_sonic_anim_timer := 8
var title_sonic_started := false
var title_camera := SonicCamera.new()
var title_background_phase := -1

func setup(scene_host: Node, owner: SonicObjectManager, next_demo_slot: int = 0) -> void:
	host = scene_host
	manager = owner
	player = owner.player
	demo_slot = posmod(next_demo_slot, 4)
	_create_overlay()
	palette_fade = GenesisPaletteFade.new()
	palette_fade.name = "StartupPaletteFade"
	host.add_child(palette_fade)
	_enter_sega()

func is_demo_active() -> bool:
	return state == STATE_DEMO

func is_presentation_active() -> bool:
	return state != STATE_DEMO

func current_demo_mask() -> int:
	return demo_mask if state == STATE_DEMO else 0

func tick_non_demo() -> void:
	match state:
		STATE_SEGA_SCAN:
			_tick_sega_scan()
		STATE_SEGA_PCM:
			_tick_sega_pcm()
		STATE_SEGA_WAIT:
			timer -= 1
			if timer <= 0:
				_enter_sega_fade_out()
		STATE_SEGA_FADE_OUT:
			_tick_sega_fade_out()
		STATE_TITLE_FADE_IN:
			_tick_title_fade_in()
		STATE_SONIC_TEAM:
			_tick_sonic_team()
		STATE_TITLE:
			_tick_title()
		STATE_TITLE_PREDEMO:
			_tick_title_predemo()
		STATE_LEVEL_SELECT:
			_tick_level_select()

func handle_input(event: InputEvent) -> bool:
	# Phase 72: title-screen controller input now owns the retail level-select
	# cheat (REV01 US: Up, Down, Left, Right) and the A+Start entry chord.
	# All actions come through the Phase 69 Input Map, so keyboard/controller
	# bindings stay data-driven.
	if state == STATE_LEVEL_SELECT:
		if event.is_action_pressed("A") or event.is_action_pressed("B") or event.is_action_pressed("C") or event.is_action_pressed("Start"):
			_activate_level_select_item()
			return true
		return event.is_action_pressed("up") or event.is_action_pressed("down") or event.is_action_pressed("left") or event.is_action_pressed("right")
	if state == STATE_SEGA_WAIT and event.is_action_pressed("Start"):
		_enter_sega_fade_out()
		return true
	if state == STATE_TITLE or state == STATE_TITLE_PREDEMO:
		_process_title_cheat_event(event)
		if event.is_action_pressed("Start"):
			if level_select_enabled and Input.is_action_pressed("A"):
				_enter_level_select()
			else:
				start_game_requested = true
			return true
		return event.is_action_pressed("up") or event.is_action_pressed("down") or event.is_action_pressed("left") or event.is_action_pressed("right") or event.is_action_pressed("C")
	if state == STATE_DEMO and event.is_action_pressed("Start"):
		# A Start press during a normal demo returns to the SEGA/title path.
		restart_requested = true
		return true
	return false

func handle_enter() -> bool:
	# Compatibility wrapper for any external callers left from pre-Input-Map
	# phases. Normal Phase 72 input is routed through handle_input().
	if state == STATE_SEGA_WAIT:
		_enter_sega_fade_out()
		return true
	if state == STATE_TITLE or state == STATE_TITLE_PREDEMO:
		if level_select_enabled and Input.is_action_pressed("A"):
			_enter_level_select()
		else:
			start_game_requested = true
		return true
	if state == STATE_DEMO:
		restart_requested = true
		return true
	return false

func begin_demo(index: int) -> void:
	demo_index = clampi(index, 0, IntroDemoData.DEMOS.size() - 1)
	var demo: Dictionary = IntroDemoData.DEMOS[demo_index]
	state = STATE_DEMO
	demo_frames_remaining = int(demo.get("frames", 1800))
	demo_input_index = 0
	demo_input_remaining = 0
	demo_mask = 0
	_hide_overlay()
	_set_gameplay_visible(true)
	player = manager.player
	player.scripted_input_enabled = true
	player.scripted_input_mask = 0
	manager.time_frozen = false
	_load_current_demo_input()

func begin_special_demo() -> void:
	state = STATE_DEMO
	demo_index = 3
	demo_frames_remaining = SpecialStageDemoData.FRAMES
	demo_input_index = 0
	demo_input_remaining = 0
	demo_mask = 0
	_hide_overlay()
	_set_gameplay_visible(false)

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
	if demo_frames_remaining <= 0 or player.dead:
		player.scripted_input_enabled = false
		player.scripted_input_mask = 0
		restart_requested = true

func teardown() -> void:
	if player != null:
		player.scripted_input_enabled = false
		player.scripted_input_mask = 0
	_set_gameplay_visible(true)
	if overlay_layer != null and is_instance_valid(overlay_layer):
		overlay_layer.queue_free()
	if palette_fade != null and is_instance_valid(palette_fade):
		palette_fade.queue_free()

func _enter_sega() -> void:
	SonicAudio.stop_music()
	state = STATE_SEGA_SCAN
	timer = SEGA_SCAN_FRAMES
	start_game_requested = false
	demo_requested = -1
	restart_requested = false
	level_select_enabled = false
	level_select_code_index = 0
	level_select_c_count = 0
	level_select_item = 0
	level_select_sound = 0
	level_select_delay = 0
	level_select_level_request = Vector2i(-1, -1)
	level_select_special_request = false
	_set_gameplay_visible(false)
	_set_background_visible(false)
	backdrop.visible = true
	backdrop.color = Color.WHITE
	sega_sprite.visible = true
	sega_sprite.modulate = Color.WHITE
	if sega_palette_fast_path:
		sega_sprite.texture = TitleSourceArt.sega_logo_index_texture()
	_set_sega_palette_step(0)
	sega_scan_bar.visible = false
	stp_sprite.visible = false
	_set_title_visible(false)
	if level_select_sprite != null:
		level_select_sprite.visible = false
	if audio.playing:
		audio.stop()

func _tick_sega_scan() -> void:
	var elapsed := SEGA_SCAN_FRAMES - timer
	# Run the actual REV01 PalCycle_Sega palette state for this VBlank. The
	# logo starts all-white/invisible against the white background, the six-
	# color light band scans across it for 51 frames, then the four source
	# Sega2 palette steps settle over the following 25 frames.
	_set_sega_palette_step(elapsed)
	sega_sprite.modulate = Color.WHITE
	sega_scan_bar.visible = false
	timer -= 1
	if timer > 0:
		return
	_set_sega_palette_step(SEGA_SCAN_FRAMES)
	state = STATE_SEGA_PCM
	timer = SEGA_PCM_FALLBACK_FRAMES
	var stream = load("res://data/s1/sound/sega.wav")
	if stream != null:
		audio.stream = stream
		audio.play()

func _tick_sega_pcm() -> void:
	if audio.stream != null:
		if audio.playing:
			return
	else:
		timer -= 1
		if timer > 0:
			return
	state = STATE_SEGA_WAIT
	timer = SEGA_WAIT_FRAMES

func _enter_sega_fade_out() -> void:
	state = STATE_SEGA_FADE_OUT
	timer = PALETTE_FADE_FRAMES
	_set_sega_palette_step(SEGA_SCAN_FRAMES)
	sega_sprite.modulate = Color.WHITE
	backdrop.visible = true
	backdrop.color = Color.WHITE
	palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_OUT, 0)

func _tick_sega_fade_out() -> void:
	# PaletteFadeOut transfers the untouched palette first, then decreases red,
	# green and blue one Genesis CRAM step at a time over the 22 VBlanks.
	var step := PALETTE_FADE_FRAMES - timer
	palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_OUT, step)
	timer -= 1
	if timer <= 0:
		palette_fade.hide_fade()
		_enter_sonic_team()

func _enter_sonic_team() -> void:
	state = STATE_SONIC_TEAM
	timer = SONIC_TEAM_FRAMES
	backdrop.visible = true
	backdrop.color = Color.BLACK
	sega_sprite.visible = false
	sega_scan_bar.visible = false
	stp_sprite.visible = true
	stp_sprite.modulate = Color.WHITE
	palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, 0)
	_set_title_visible(false)
	_set_background_visible(false)

func _tick_sonic_team() -> void:
	var elapsed := SONIC_TEAM_FRAMES - timer
	# GM_Title fades SONIC TEAM PRESENTS in from black, keeps it displayed while
	# loading the title assets, then uses the same 22-frame PaletteFadeOut.
	if elapsed < PALETTE_FADE_FRAMES:
		palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, elapsed)
	elif timer <= PALETTE_FADE_FRAMES:
		palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_OUT, PALETTE_FADE_FRAMES - timer)
	else:
		palette_fade.hide_fade()
	timer -= 1
	if timer <= 0:
		palette_fade.hide_fade()
		_enter_title()

func _enter_title() -> void:
	SonicAudio.play_music(SonicAudio.MUS_TITLE)
	state = STATE_TITLE_FADE_IN
	timer = PALETTE_FADE_FRAMES
	title_elapsed = 0
	title_sonic_y = 94.0
	title_sonic_anim_frame = 0
	title_sonic_anim_timer = 8
	title_sonic_started = false
	level_select_code_index = 0
	level_select_c_count = 0
	level_select_enabled = false
	backdrop.visible = false
	sega_sprite.visible = false
	stp_sprite.visible = false
	_set_background_visible(true)
	_reset_title_background()
	_set_title_visible(true)
	title_sonic.visible = false
	title_sonic.position = Vector2(120, title_sonic_y)
	title_sonic.texture = TitleSourceArt.title_sonic_texture(0, int(title_sonic_y), false)
	press_start.visible = false

func _tick_title_fade_in() -> void:
	# The title objects are built once, then remain frozen while PaletteFadeIn
	# advances blue, green and red toward the title palette over 22 VBlanks.
	var step := PALETTE_FADE_FRAMES - timer
	palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, step)
	timer -= 1
	if timer <= 0:
		palette_fade.hide_fade()
		state = STATE_TITLE
		timer = TITLE_FRAMES

func _tick_title() -> void:
	title_elapsed += 1
	_tick_title_background()
	_tick_title_cheat_terminator()
	press_start.visible = (int(title_elapsed / 32) & 1) != 0
	_tick_title_sonic()
	timer -= 1
	if timer <= 0:
		state = STATE_TITLE_PREDEMO
		timer = TITLE_PREDEMO_FRAMES

func _tick_title_predemo() -> void:
	title_elapsed += 1
	_tick_title_background()
	_tick_title_cheat_terminator()
	press_start.visible = (int(title_elapsed / 32) & 1) != 0
	_tick_title_sonic()
	timer -= 1
	if timer > 0:
		return
	# Slots 0-2 are normal levels; slot 3 is the retail Special Stage 1 demo.
	# main.gd routes the latter into SpecialStageController.
	demo_requested = demo_slot

func _process_title_cheat_event(event: InputEvent) -> void:
	# REV01 US code: Up, Down, Left, Right, then a zero terminator in ROM.
	# A successful sequence sets f_levselcheat and plays the ring sound. Keep
	# the source's useful retry behavior where another Up starts a new attempt.
	if event.is_action_pressed("C"):
		level_select_c_count += 1
		return
	var direction := ""
	for action in ["up", "down", "left", "right"]:
		if event.is_action_pressed(action):
			direction = action
			break
	if direction.is_empty():
		return
	const CODE := ["up", "down", "left", "right"]
	# Index 4 represents the source code's trailing zero byte. If another
	# direction is pressed before the following zero-input VBlank, the cheat
	# fails exactly as Tit_EnterCheat does.
	if level_select_code_index >= CODE.size():
		level_select_code_index = 1 if direction == CODE[0] else 0
		return
	if direction == CODE[level_select_code_index]:
		level_select_code_index += 1
		return
	level_select_code_index = 1 if direction == CODE[0] else 0

func _tick_title_cheat_terminator() -> void:
	# LevSelCode_US ends in a zero byte. The cheat is therefore activated on
	# the first VBlank after Right where no new D-pad direction was pressed.
	if level_select_enabled or level_select_code_index != 4:
		return
	if Input.is_action_just_pressed("up") or Input.is_action_just_pressed("down") or Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right"):
		return
	level_select_enabled = true
	level_select_code_index = 0
	SonicAudio.play_ring_sfx()

func _enter_level_select() -> void:
	state = STATE_LEVEL_SELECT
	timer = 0
	level_select_item = 0
	level_select_sound = 0
	level_select_delay = 0
	level_select_level_request = Vector2i(-1, -1)
	level_select_special_request = false
	_set_background_visible(false)
	_set_title_visible(false)
	backdrop.visible = true
	backdrop.color = LevelSelectArt.background_color()
	if level_select_sprite != null:
		level_select_sprite.visible = true
		_refresh_level_select_texture()

func _tick_level_select() -> void:
	# LevSelControls: new Up/Down presses move immediately; a held direction
	# repeats every 12 VBlanks. Left/right change the sound-test byte only on
	# new presses, matching the source routine.
	var immediate_ud := Input.is_action_just_pressed("up") or Input.is_action_just_pressed("down")
	if immediate_ud:
		level_select_delay = 12 - 1
		_move_level_select(Input.is_action_pressed("up"), Input.is_action_pressed("down"))
	else:
		level_select_delay -= 1
		if level_select_delay < 0:
			level_select_delay = 12 - 1
			var up_held := Input.is_action_pressed("up")
			var down_held := Input.is_action_pressed("down")
			if up_held or down_held:
				_move_level_select(up_held, down_held)
	if level_select_item == LevelSelectArt.SOUND_ROW:
		var changed := false
		if Input.is_action_just_pressed("left"):
			level_select_sound = posmod(level_select_sound - 1, 0x50) # retail $80-$CF
			changed = true
		if Input.is_action_just_pressed("right"):
			level_select_sound = posmod(level_select_sound + 1, 0x50)
			changed = true
		if changed:
			_refresh_level_select_texture()

func _move_level_select(up_held: bool, down_held: bool) -> void:
	var old := level_select_item
	if up_held:
		level_select_item = posmod(level_select_item - 1, LevelSelectArt.LINE_COUNT)
	if down_held:
		level_select_item = posmod(level_select_item + 1, LevelSelectArt.LINE_COUNT)
	if level_select_item != old:
		_refresh_level_select_texture()

func _refresh_level_select_texture() -> void:
	if level_select_sprite != null:
		level_select_sprite.texture = LevelSelectArt.texture(level_select_item, 0x80 + level_select_sound)

func _activate_level_select_item() -> void:
	if level_select_item == LevelSelectArt.SOUND_ROW:
		var sound_id := 0x80 + level_select_sound
		if sound_id >= SonicAudio.MUS_GHZ and sound_id <= SonicAudio.MUS_GET_EMERALD:
			SonicAudio.play_music(sound_id, true)
		elif sound_id >= SonicAudio.SFX_JUMP and sound_id <= 0xCF:
			SonicAudio.play_sfx(sound_id)
		return
	if level_select_item == 19:
		level_select_special_request = true
		return
	const TARGETS := [
		Vector2i(LevelCatalog.ZONE_GHZ, 1), Vector2i(LevelCatalog.ZONE_GHZ, 2), Vector2i(LevelCatalog.ZONE_GHZ, 3),
		Vector2i(LevelCatalog.ZONE_MZ, 1), Vector2i(LevelCatalog.ZONE_MZ, 2), Vector2i(LevelCatalog.ZONE_MZ, 3),
		Vector2i(LevelCatalog.ZONE_SYZ, 1), Vector2i(LevelCatalog.ZONE_SYZ, 2), Vector2i(LevelCatalog.ZONE_SYZ, 3),
		Vector2i(LevelCatalog.ZONE_LZ, 1), Vector2i(LevelCatalog.ZONE_LZ, 2), Vector2i(LevelCatalog.ZONE_LZ, 3),
		Vector2i(LevelCatalog.ZONE_SLZ, 1), Vector2i(LevelCatalog.ZONE_SLZ, 2), Vector2i(LevelCatalog.ZONE_SLZ, 3),
		Vector2i(LevelCatalog.ZONE_SBZ, 1), Vector2i(LevelCatalog.ZONE_SBZ, 2), Vector2i(LevelCatalog.ZONE_LZ, 4),
		Vector2i(LevelCatalog.ZONE_SBZ, 3),
	]
	if level_select_item >= 0 and level_select_item < TARGETS.size():
		level_select_level_request = TARGETS[level_select_item]

func _reset_title_background() -> void:
	title_camera.screen_x = 0
	title_camera.screen_y = 0
	title_camera.shift_x = 0
	title_camera.shift_y = 0
	title_background_phase = -1
	_apply_title_background_phase(0)
	RenderingServer.set_default_clear_color(TitleSourceArt.title_background_color())
	var bg = host.get_node_or_null("GHZBackgroundRenderer") if host != null else null
	if bg != null:
		bg.reset()
		bg.update(title_camera)
	var cam = host.get_node_or_null("Camera2D") if host != null else null
	if cam != null and cam is Camera2D:
		title_camera.apply_to(cam)

func _tick_title_background() -> void:
	var phase := int(maxi(0, title_elapsed - 1) / 6.0) & 3
	_apply_title_background_phase(phase)
	# GM_Title increments the cleared player object's X position by 2 every
	# frame, then DeformLayers/ScrollHoriz follows it. LevelSizeLoad explicitly
	# seeds that dummy v_player X to $0050 on the title screen. DeformLayers runs
	# BEFORE the +2 each loop, so scrolling first becomes visible on title tick
	# 42, when the prior loop has advanced the dummy from $A0 to $A2.
	var dummy_player_x = 0x50 + maxi(0, title_elapsed - 1) * 2
	var desired_x = maxi(0, dummy_player_x - 0xA0)
	title_camera.shift_x = (desired_x - title_camera.screen_x) << 8
	title_camera.shift_y = 0
	title_camera.screen_x = desired_x
	var bg = host.get_node_or_null("GHZBackgroundRenderer") if host != null else null
	if bg != null:
		bg.update(title_camera)
	var cam = host.get_node_or_null("Camera2D") if host != null else null
	if cam != null and cam is Camera2D:
		title_camera.apply_to(cam)

func _apply_title_background_phase(phase: int) -> void:
	phase &= 3
	if title_background_phase == phase:
		return
	title_background_phase = phase
	var texture := TitleSourceArt.title_background_texture(phase)
	if texture == null or host == null:
		return
	var bg = host.get_node_or_null("GHZBackgroundRenderer")
	if bg == null:
		return
	for child in bg.get_children():
		if child is Sprite2D:
			# Phase 72 HF1: title_background_texture() is already a finished RGBA
			# image. The gameplay GHZ strips carry an R8 palette-index shader,
			# which must not interpret the title image's red channel as a CRAM index.
			child.material = null
			child.texture = texture

func _tick_title_sonic() -> void:
	if title_elapsed <= TITLE_SONIC_DELAY:
		return
	if not title_sonic_started:
		# TSon_Delay expires by displaying frame 0 once at the authored Y=94
		# position. TSon_Move does not subtract 8 pixels until the next object
		# execution. Keeping that one display frame prevents the pop-up sequence
		# from arriving a frame early and preserves the source stop/animation handoff.
		title_sonic_started = true
		title_sonic.visible = true
		title_sonic.position.y = title_sonic_y
		title_sonic.texture = TitleSourceArt.title_sonic_texture(0, int(title_sonic_y), press_start.visible)
		return
	if title_sonic_y > 22.0:
		title_sonic_y = maxf(22.0, title_sonic_y - 8.0)
		title_sonic.position.y = title_sonic_y
		# The source hardware masking sprites are scanline-dependent, so the
		# composited frame must follow Sonic's changing screen Y while he rises.
		title_sonic.texture = TitleSourceArt.title_sonic_texture(title_sonic_anim_frame, int(title_sonic_y), press_start.visible)
		return
	title_sonic_anim_timer -= 1
	if title_sonic_anim_timer <= 0:
		title_sonic_anim_timer = 8
		if title_sonic_anim_frame < 7:
			title_sonic_anim_frame += 1
		else:
			title_sonic_anim_frame = 6
	# Earlier source mapping pieces now retain Genesis sprite overlap priority,
	# and the Object $0F line-limit mask lets the banner cover Sonic correctly.
	title_sonic.texture = TitleSourceArt.title_sonic_texture(title_sonic_anim_frame, int(title_sonic_y), press_start.visible)

func _load_current_demo_input() -> void:
	if demo_index < 0 or demo_index >= IntroDemoData.DEMOS.size():
		demo_mask = 0
		demo_input_remaining = 0x7FFFFFFF
		return
	var sequence: Array = IntroDemoData.DEMOS[demo_index].get("inputs", [])
	if demo_input_index < 0 or demo_input_index >= sequence.size():
		demo_mask = 0
		demo_input_remaining = 0x7FFFFFFF
		return
	var pair: Array = sequence[demo_input_index]
	demo_mask = int(pair[0])
	demo_input_remaining = maxi(1, int(pair[1]))

func _create_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 220
	host.add_child(overlay_layer)
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	backdrop = ColorRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
	overlay_layer.add_child(backdrop)

	sega_sprite = Sprite2D.new()
	sega_sprite.centered = false
	sega_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sega_sprite.texture = TitleSourceArt.sega_logo_index_texture()
	sega_sprite.position = Vector2.ZERO
	sega_sprite.z_index = 2
	var sega_shader = load("res://scripts/render/sega_palette_sprite.gdshader")
	if sega_sprite.texture != null and sega_shader != null:
		sega_palette_image = Image.create_empty(64, 1, false, Image.FORMAT_RGBA8)
		sega_palette_texture = ImageTexture.create_from_image(sega_palette_image)
		var sega_material = ShaderMaterial.new()
		sega_material.shader = sega_shader
		sega_material.set_shader_parameter("sega_palette", sega_palette_texture)
		sega_sprite.material = sega_material
		sega_palette_fast_path = true
	else:
		# Keep the old compositor only as a failure-safe path if the new shader
		# cannot be created. Normal Phase 66 startup never enters this branch.
		sega_sprite.texture = TitleSourceArt.sega_logo_texture(0)
		sega_palette_fast_path = false
	overlay_layer.add_child(sega_sprite)
	_set_sega_palette_step(0)

	sega_scan_bar = ColorRect.new()
	sega_scan_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sega_scan_bar.size = Vector2(56, viewport_size.y)
	sega_scan_bar.color = Color(1, 1, 1, 0.58)
	sega_scan_bar.z_index = 3
	overlay_layer.add_child(sega_scan_bar)

	stp_sprite = Sprite2D.new()
	stp_sprite.centered = false
	stp_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stp_sprite.texture = SourceObjectArt.credits_page_texture(10, false)
	stp_sprite.position = Vector2.ZERO
	stp_sprite.z_index = 2
	overlay_layer.add_child(stp_sprite)

	title_emblem_low = Sprite2D.new()
	title_emblem_low.centered = false
	title_emblem_low.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_emblem_low.texture = TitleSourceArt.title_emblem_texture(false)
	title_emblem_low.position = Vector2(32, 32)
	title_emblem_low.z_index = 10
	overlay_layer.add_child(title_emblem_low)

	title_sonic = Sprite2D.new()
	title_sonic.centered = false
	title_sonic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_sonic.position = Vector2(120, 94)
	title_sonic.z_index = 11
	overlay_layer.add_child(title_sonic)

	title_emblem_high = Sprite2D.new()
	title_emblem_high.centered = false
	title_emblem_high.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_emblem_high.texture = TitleSourceArt.title_emblem_texture(true)
	title_emblem_high.position = Vector2(32, 32)
	title_emblem_high.z_index = 12
	overlay_layer.add_child(title_emblem_high)

	press_start = Sprite2D.new()
	press_start.centered = false
	press_start.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	press_start.texture = TitleSourceArt.press_start_texture()
	press_start.position = Vector2(88, 176)
	press_start.z_index = 13
	overlay_layer.add_child(press_start)

	trademark = Sprite2D.new()
	trademark.centered = false
	trademark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trademark.texture = TitleSourceArt.trademark_texture()
	trademark.position = Vector2(240, 116)
	trademark.z_index = 13
	overlay_layer.add_child(trademark)

	level_select_sprite = Sprite2D.new()
	level_select_sprite.centered = false
	level_select_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	level_select_sprite.position = (viewport_size - Vector2(LevelSelectArt.WIDTH, LevelSelectArt.HEIGHT)) * 0.5
	level_select_sprite.z_index = 30
	level_select_sprite.visible = false
	overlay_layer.add_child(level_select_sprite)

	audio = AudioStreamPlayer.new()
	overlay_layer.add_child(audio)

func _set_sega_palette_step(step: int) -> void:
	step = clampi(step, 0, SEGA_SCAN_FRAMES)
	if not sega_palette_fast_path or sega_palette_image == null or sega_palette_texture == null:
		sega_sprite.texture = TitleSourceArt.sega_logo_texture(step)
		return
	var colors = TitleSourceArt.sega_palette_colors(step)
	if colors.size() < 64:
		return
	for i in range(64):
		sega_palette_image.set_pixel(i, 0, colors[i])
	sega_palette_texture.update(sega_palette_image)

func _set_title_visible(show: bool) -> void:
	title_emblem_low.visible = show
	title_sonic.visible = show and title_sonic_started
	title_emblem_high.visible = show
	press_start.visible = show
	trademark.visible = show

func _hide_overlay() -> void:
	backdrop.visible = false
	sega_sprite.visible = false
	sega_scan_bar.visible = false
	stp_sprite.visible = false
	_set_title_visible(false)

func _set_background_visible(show: bool) -> void:
	if host == null:
		return
	var bg = host.get_node_or_null("GHZBackgroundRenderer")
	if bg != null:
		bg.visible = show

func _set_gameplay_visible(show: bool) -> void:
	if host == null:
		return
	for path in ["GHZRenderer", "ObjectManager", "SonicPlayer", "SonicEffects", "CollisionDebug"]:
		var node = host.get_node_or_null(path)
		if node != null and node is CanvasItem:
			node.visible = show
	var water_layer = host.get_node_or_null("LZWaterPaletteLayer")
	if water_layer != null:
		water_layer.visible = show
	var hud = host.get_node_or_null("UI/SonicHUD")
	if hud != null:
		hud.visible = show
	var info = host.get_node_or_null("UI/Info")
	if info != null and not show:
		info.visible = false
	var end_card = host.get_node_or_null("UI/EndCard")
	if end_card != null and not show:
		end_card.visible = false
	var game_over = host.get_node_or_null("UI/GameOverUI")
	if game_over != null and not show:
		game_over.visible = false
