class_name ContinueScreenController
extends Node

const TOTAL_FRAMES := 659
const SONIC_START_Y := -64.0
const SONIC_LAND_Y := 160.0
const SONIC_FALL_SPEED := 4.0
const SONIC_EXIT_X := 384.0
const PALETTE_FADE_FRAMES := 22
const MINI_X_WORDS: Array[int] = [0x116,0x12A,0x102,0x13E,0xEE,0x152,0xDA,0x166,0xC6,0x17A,0xB2,0x18E,0x9E,0x1A2,0x8A]
const FLOAT3_FRAMES: Array[int] = [0x3C,0x3D,0x53,0x3E,0x54]
const WALK_FRAMES: Array[int] = [0x08,0x09,0x0A,0x0B,0x06,0x07]
const RUN_FRAMES: Array[int] = [0x1E,0x1F,0x20,0x21]

var host: Node = null
var manager = null
var layer: CanvasLayer
var sonic_normal: SonicVisual
var sonic_floor: Sprite2D
var text_sprite: Sprite2D
var floor_light: Sprite2D
var tens_sprite: Sprite2D
var ones_sprite: Sprite2D
var mini_sonics: Array[Sprite2D] = []
var timer := TOTAL_FRAMES
var sonic_y := SONIC_START_Y
var sonic_x := 160.0
var landed := false
var used_continue := false
var finished := false
var timed_out := false
var run_inertia := 0
var run_anim_tick := 0
var walkrun_frame_index := -1
var walkrun_frame_timer := 0
var anim_tick := 0
var floor_anim_tick := 0
var _enter_was_held := false
var fade_in_timer := PALETTE_FADE_FRAMES
var palette_fade: GenesisPaletteFade

func setup(host_node: Node, object_manager) -> void:
	host = host_node
	manager = object_manager
	_set_gameplay_visible(false)
	_create_scene()
	palette_fade = GenesisPaletteFade.new()
	palette_fade.name = "ContinuePaletteFade"
	host.add_child(palette_fade)
	palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, 0)
	fade_in_timer = PALETTE_FADE_FRAMES
	_update_countdown(10)

func teardown() -> void:
	_set_gameplay_visible(true)
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	if palette_fade != null and is_instance_valid(palette_fade):
		palette_fade.queue_free()

func tick() -> void:
	if finished:
		return
	# GM_Continue builds the objects once, then PaletteFadeIn runs for 22
	# VBlanks before the Continue main loop begins. Freeze countdown/Sonic here.
	if fade_in_timer > 0:
		var fade_step := PALETTE_FADE_FRAMES - fade_in_timer
		palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, fade_step)
		fade_in_timer -= 1
		if fade_in_timer <= 0:
			palette_fade.hide_fade()
		return
	anim_tick += 1
	var enter_held := Input.is_action_pressed("Start")
	var enter_pressed := enter_held and not _enter_was_held
	_enter_was_held = enter_held

	if not landed:
		sonic_y += SONIC_FALL_SPEED
		sonic_normal.position = Vector2(sonic_x, sonic_y)
		sonic_normal._set_frame(FLOAT3_FRAMES[int(anim_tick / 4) % FLOAT3_FRAMES.size()])
		if sonic_y >= SONIC_LAND_Y:
			sonic_y = SONIC_LAND_Y
			landed = true
			floor_anim_tick = 0
			sonic_normal.visible = false
			sonic_floor.visible = true
			_update_floor_animation()
	else:
		if used_continue:
			_tick_run_out()
		else:
			_update_floor_animation()
			floor_anim_tick += 1
			if enter_pressed:
				used_continue = true
				run_inertia = 0
				run_anim_tick = 0
				walkrun_frame_index = -1
				walkrun_frame_timer = 0
				sonic_floor.visible = false
				sonic_normal.visible = true
				sonic_normal.position = Vector2(sonic_x, SONIC_LAND_Y - 8.0)
				sonic_normal._set_frame(0x3C) # SonAni_Float4: fr_Float1, then id_Walk.

	if not used_continue:
		timer -= 1
		var seconds := clampi(int(timer / 60), 0, 10)
		_update_countdown(seconds)
		if timer <= 0:
			timed_out = true
			finished = true
	_update_minis()

func _create_scene() -> void:
	layer = CanvasLayer.new()
	layer.name = "ContinueScreenLayer"
	layer.layer = 400
	host.add_child(layer)

	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(320, 224)
	bg.color = ContinueSourceArt.background_color()
	layer.add_child(bg)

	text_sprite = Sprite2D.new()
	text_sprite.centered = false
	text_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	text_sprite.texture = ContinueSourceArt.text_texture()
	text_sprite.position = Vector2(80, 56)
	layer.add_child(text_sprite)

	floor_light = Sprite2D.new()
	floor_light.centered = false
	floor_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_light.texture = ContinueSourceArt.floor_light_texture()
	floor_light.position = Vector2(136, 160)
	floor_light.z_index = 1
	layer.add_child(floor_light)

	sonic_normal = SonicVisual.new()
	sonic_normal.position = Vector2(sonic_x, sonic_y)
	sonic_normal.z_index = 3
	layer.add_child(sonic_normal)
	sonic_normal._set_frame(FLOAT3_FRAMES[0])

	sonic_floor = Sprite2D.new()
	sonic_floor.centered = false
	sonic_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sonic_floor.position = Vector2(128, 136)
	sonic_floor.z_index = 3
	sonic_floor.visible = false
	layer.add_child(sonic_floor)

	tens_sprite = _make_digit_sprite()
	ones_sprite = _make_digit_sprite()
	tens_sprite.position = Vector2(152, 118)
	ones_sprite.position = Vector2(160, 118)
	layer.add_child(tens_sprite)
	layer.add_child(ones_sprite)

	_create_minis()

func _make_digit_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 4
	return sprite

func _create_minis() -> void:
	var count := clampi(int(manager.continues) - 1, 0, 15)
	if count <= 0:
		return
	var shift := -10 if ((count - 1) & 1) != 0 else 0
	for i in range(count):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(float(MINI_X_WORDS[i] - 0x80 + shift), 80.0)
		sprite.texture = ContinueSourceArt.mini_sonic_texture(false)
		sprite.z_index = 5
		layer.add_child(sprite)
		mini_sonics.append(sprite)

func _update_minis() -> void:
	var foot_up := ((anim_tick >> 4) & 1) != 0
	for i in range(mini_sonics.size()):
		var sprite := mini_sonics[i]
		if used_continue and manager.continues <= 15 and i == mini_sonics.size() - 1:
			if sonic_x > 160.0:
				sprite.visible = false
			else:
				sprite.visible = (anim_tick & 1) != 0
		else:
			sprite.visible = true
		sprite.texture = ContinueSourceArt.mini_sonic_texture(foot_up)

func _update_floor_animation() -> void:
	# Ani_CSon: delay 4, frames 1,1,1,1,2,2,2,3,3, afEnd.
	# AnimateSprite's afEnd ($FF) RESTARTS the animation from frame 0; it does
	# not hold the final mapping. Phase 51 stopped at frame 3, so Sonic only
	# completed one hand tap. Loop the exact nine-entry source script forever.
	const SOURCE_SCRIPT: Array[int] = [1, 1, 1, 1, 2, 2, 2, 3, 3]
	var script_index := int(floor_anim_tick / 5) % SOURCE_SCRIPT.size()
	sonic_floor.texture = ContinueSourceArt.sonic_floor_texture(SOURCE_SCRIPT[script_index])

func _tick_run_out() -> void:
	# CSon_RunRight raises obInertia by $20 every frame. Sonic_Animate first
	# finishes SonAni_Float4 (fr_Float1 -> id_Walk), then the normal special
	# Walk handler selects SonAni_Run automatically once |inertia| >= $600.
	run_anim_tick += 1
	if run_inertia < 0x800:
		run_inertia = mini(0x800, run_inertia + 0x20)
		_update_run_out_animation()
		return

	# On the frame after inertia reaches $800, the source assigns obVelX=$1000
	# and SpeedToPos finally moves Sonic offscreen.
	sonic_x += 16.0
	sonic_normal.position.x = sonic_x
	_update_run_out_animation()
	if sonic_x >= SONIC_EXIT_X:
		finished = true

func _update_run_out_animation() -> void:
	# SonAni_Float4 has delay 3 and one visible fr_Float1 before afChange to
	# id_Walk, so retain it for the first four CSon_RunRight animation calls.
	if run_anim_tick <= 4:
		sonic_normal._set_frame(0x3C)
		return

	var frames: Array[int] = WALK_FRAMES
	if absi(run_inertia) >= 0x600:
		frames = RUN_FRAMES
	# Sonic_Animate special walk/run timing: (0x800-|inertia|)>>8. At $600
	# this is 2; at $800 it is 0, producing the rapid source running cadence.
	walkrun_frame_timer -= 1
	if walkrun_frame_timer < 0:
		walkrun_frame_index = (walkrun_frame_index + 1) % frames.size()
		walkrun_frame_timer = maxi(0, (0x800 - mini(0x800, absi(run_inertia))) >> 8)
	sonic_normal._set_frame(frames[walkrun_frame_index % frames.size()])

func _update_countdown(seconds: int) -> void:
	seconds = clampi(seconds, 0, 10)
	var tens := int(seconds / 10)
	var ones := seconds % 10
	tens_sprite.texture = load("res://assets/ui/digit_%d.png" % tens)
	ones_sprite.texture = load("res://assets/ui/digit_%d.png" % ones)

func _set_gameplay_visible(show: bool) -> void:
	if host == null:
		return
	for path in ["GHZBackgroundRenderer", "GHZRenderer", "ObjectManager", "SonicEffects"]:
		var node = host.get_node_or_null(path)
		if node != null and node is CanvasItem:
			node.visible = show
	if manager != null and manager.player != null and manager.player is CanvasItem:
		manager.player.visible = show
	for path in ["UI/SonicHUD", "UI/EndCard", "UI/GameOverUI"]:
		var ui = host.get_node_or_null(path)
		if ui != null and ui is CanvasItem:
			ui.visible = show
