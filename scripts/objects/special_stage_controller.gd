class_name SpecialStageController
extends Node

# Phase 48 native Special Stage runtime. Source coordinates, rotation speed,
# gravity/movement constants, collision-cell lookup, block IDs and stage data
# follow GM_Special + Object $09 from the retail REV01 disassembly.

const BLOCK_SIZE := 24
const MATRIX_SIZE := 16
const LAYOUT_SIZE := 64
const PADDING_CELLS := 32
const MATRIX_BASE := -180 # -(16-1)*24/2
const SCREEN_CENTER := Vector2(160, 112)

const MAX_INERTIA := 0x800
const ACCEL := 0x0C
const DECEL := 0x40
const JUMP_SPEED := 0x680
const GRAVITY := 0x2A
const ROTATE_BASE := 0x40
const EXIT_ROTATE_TARGET := 0x1800
const ACTION_TIMEOUT := 30
const PALETTE_FADE_FRAMES := 22

# PalCycle_SS timing table. A source time of 0 is encoded as -1 and becomes
# $1FF, producing a 512-frame hold. The animal BG mode is a byte offset into
# SS_BG_Modes: 0,2,4,6,8,$A,$C rather than a free-running animation index.
const SS_BG_TIMES: Array[int] = [
	4,4,4,4,4,4,4,4,4,4, 8,8,0,0,8,8,
	4,4,4,4,4,4,4,4,4,4, 8,8,0,0,8,8
]
const SS_BG_MODES: Array[int] = [
	0,0,0,0,0,0,0,0,0,0, 8,0xA,0xC,0xC,0xA,8,
	0,0,0,0,0,0,0,0,0,0, 2,4,6,6,4,2
]

const ID_BUMPER := 0x25
const ID_GOAL := 0x27
const ID_1UP := 0x28
const ID_UP := 0x29
const ID_DOWN := 0x2A
const ID_R := 0x2B
const ID_REDWHITE := 0x2C
const ID_GLASS_FIRST := 0x2D
const ID_GLASS_LAST := 0x30
const ID_RING := 0x3A
const ID_EMERALD_FIRST := 0x3B
const ID_EMERALD_LAST := 0x40
const ID_GHOST := 0x41
const ID_GHOST_TRIGGER := 0x4A
const ID_GLASS_ANI_FIRST := 0x4B

const STAGE_LAYOUTS: Array[String] = [
	"1.eni", "2.eni", "3.eni", "4.eni", "5 (REV01).eni", "6 (REV01).eni"
]
const START_FILES: Array[String] = ["ss1.bin", "ss2.bin", "ss3.bin", "ss4.bin", "ss5.bin", "ss6.bin"]

var host: Node
var manager: SonicObjectManager
var stage_index := 0
var demo_mode := false
var return_level := Vector2i(LevelCatalog.ZONE_GHZ, 1)
var active := false
var finished := false
var restart_startup_requested := false

var layout := PackedByteArray()
var player_pos := Vector2.ZERO
var player_vel := Vector2.ZERO
var inertia_raw := 0
var in_air := true
var stage_angle := 0
var rotate_speed := ROTATE_BASE
var frame_counter := 0
var ss_bg_timing_index := 0
var ss_bg_timer := -1
var ss_bg_mode := 0
# Exact SS_BGAnimate state. Plane A (bird/fish canvases) uses one global
# horizontal position; Plane B (bubbles/clouds) uses independent horizontal
# offsets per scanline band plus a shared vertical scroll.
var ss_bg3screenposx := 0
var ss_bgscreenposy := 0
var ss_bg_plane_clouds := true
var ss_bubble_scroll: Array[int] = [0,0,0,0,0,0,0,0,0,0]
var ss_bubble_phase: Array[int] = [0,0,0,0,0,0,0,0,0,0]
var ss_cloud_scroll_fp: Array[int] = [0,0,0,0,0,0,0]
var updown_timeout := 0
var reverse_timeout := 0
var ghost_state := 0
var jump_was_held := false
var facing_left := false
var exiting := false
var emerald_exit_timer := -1
var whiteout_timer := -1
var results_state := 0
var results_timer := 0
var result_ring_bonus := 0
var special_rings := 0
var got_emerald := false
var continue_awarded := false
var entry_fade_timer := PALETTE_FADE_FRAMES

var demo_frames_remaining := SpecialStageDemoData.FRAMES
var demo_input_index := 0
var demo_input_remaining := 0
var demo_mask := 0

var layer: CanvasLayer
var backdrop: ColorRect
var bg: Node2D
var bg_strips: Array[Sprite2D] = []
var animals_bg: Sprite2D
var field: Node2D
var block_sprites: Array[Sprite2D] = []
var sonic_sprite: Sprite2D
var white_flash: ColorRect
var hud_label: Label
var result_ui: SpecialStageResultUI
var bumper_timers: Dictionary = {}
var reverse_timers: Dictionary = {}
var glass_timers: Dictionary = {}
var collectible_timers: Dictionary = {}
var palette_fade: GenesisPaletteFade

func setup(scene_host: Node, owner: SonicObjectManager, requested_stage: int, is_demo: bool, next_level: Vector2i) -> bool:
	host = scene_host
	manager = owner
	stage_index = clampi(requested_stage, 0, 5)
	demo_mode = is_demo
	return_level = next_level
	if not _load_stage_data():
		return false
	_create_scene()
	palette_fade = GenesisPaletteFade.new()
	palette_fade.name = "SpecialStagePaletteFade"
	host.add_child(palette_fade)
	palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_IN, 0)
	entry_fade_timer = PALETTE_FADE_FRAMES
	# GM_Special calls PalCycle_SS once before PaletteWhiteIn. Timing variables
	# have just been cleared, so this selects table entry 0 and starts its
	# four-frame hold; the cycle then remains frozen during the white fade.
	_advance_ss_bg_cycle()
	_set_gameplay_visible(false)
	active = true
	manager.special_stage_requested = false
	manager.rings = 0
	manager.time_frozen = true
	if demo_mode:
		_load_demo_input()
	_render_frame()
	return true

func is_active() -> bool:
	return active

func tick() -> void:
	if not active:
		return
	# GM_Special freezes the newly built stage while PaletteWhiteIn performs
	# its 22 source VBlank steps. Keep demo timers and Object $09 frozen too.
	if entry_fade_timer > 0:
		var entry_step := PALETTE_FADE_FRAMES - entry_fade_timer
		palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_IN, entry_step)
		entry_fade_timer -= 1
		if entry_fade_timer <= 0:
			palette_fade.hide_fade()
		return
	_tick_ss_bg_cycle()
	_tick_ss_bg_motion()
	frame_counter += 1
	_tick_local_animations()
	if results_state != 0:
		_tick_results()
		return
	if whiteout_timer >= 0:
		_tick_whiteout()
		return
	if exiting:
		_tick_exit_spin()
		return
	if emerald_exit_timer >= 0:
		emerald_exit_timer -= 1
		stage_angle = (stage_angle + rotate_speed) & 0xFFFF
		if emerald_exit_timer <= 0:
			exiting = true
		_render_frame()
		return

	var mask := _current_input_mask()
	var jump_held := (mask & 0x70) != 0
	var jump_pressed := jump_held and not jump_was_held
	jump_was_held = jump_held
	_tick_control(mask, jump_pressed)
	stage_angle = (stage_angle + rotate_speed) & 0xFFFF

	if demo_mode:
		_tick_demo_stream()
		if demo_frames_remaining <= 0:
			_finish_demo()
			return
	_render_frame()

func handle_enter() -> bool:
	if not active:
		return false
	if demo_mode:
		_finish_demo()
		return true
	return false

func teardown() -> void:
	active = false
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	if palette_fade != null and is_instance_valid(palette_fade):
		palette_fade.queue_free()
	_set_gameplay_visible(true)
	if manager != null:
		manager.time_frozen = false
		manager.special_stage_requested = false

func _load_stage_data() -> bool:
	var layout_path := "res://data/s1/sslayout/" + STAGE_LAYOUTS[stage_index]
	if not FileAccess.file_exists(layout_path):
		push_error("Phase 48: missing Special Stage layout %s" % layout_path)
		return false
	layout = Enigma.decompress(FileAccess.get_file_as_bytes(layout_path))
	# Each Enigma word contains two byte-sized layout cells. The six retail
	# layouts decompress to exactly $1000 bytes = 64x64 cells.
	if layout.size() != LAYOUT_SIZE * LAYOUT_SIZE:
		push_error("Phase 48: Special Stage %d layout decoded to %d bytes, expected 4096." % [stage_index + 1, layout.size()])
		return false
	var start_path := "res://data/s1/startpos/Special Stages/" + START_FILES[stage_index]
	if not FileAccess.file_exists(start_path):
		return false
	var start := FileAccess.get_file_as_bytes(start_path)
	if start.size() < 4:
		return false
	player_pos = Vector2(_be16(start, 0), _be16(start, 2))
	player_vel = Vector2.ZERO
	inertia_raw = 0
	in_air = true
	facing_left = false
	stage_angle = 0
	rotate_speed = ROTATE_BASE
	return true

func _create_scene() -> void:
	layer = CanvasLayer.new()
	layer.name = "SpecialStageLayer"
	layer.layer = 200
	host.add_child(layer)

	backdrop = ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(320, 224)
	backdrop.color = Color(0.08, 0.12, 0.30, 1.0)
	layer.add_child(backdrop)

	# Plane B is line-scrolled in the original VDP. Build a small pool of
	# region sprites; _update_ss_background_render() assigns each one to a
	# source-authored bubble/cloud scanline band. Regions have texture repeat
	# enabled, so horizontal movement wraps continuously instead of stopping
	# after the Phase 48-51 64-pixel TextureRect offset.
	bg = Node2D.new()
	bg.name = "SSCloudBubbleBands"
	layer.add_child(bg)
	for i in range(16):
		var strip := Sprite2D.new()
		strip.name = "SSBGStrip%02d" % i
		strip.centered = false
		strip.region_enabled = true
		strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		strip.visible = false
		bg.add_child(strip)
		bg_strips.append(strip)

	# Plane A is the checkerboard bird/fish canvas. It has one global H-scroll
	# word, separate from Plane B's line-scroll table, and therefore gets its
	# own repeating region sprite.
	animals_bg = Sprite2D.new()
	animals_bg.name = "SSBirdFishPlane"
	animals_bg.centered = false
	animals_bg.region_enabled = true
	animals_bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	animals_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animals_bg.texture = SpecialStageArt.background_animals_texture(0)
	animals_bg.region_rect = Rect2(0, 0, 320, 224)
	animals_bg.position = Vector2.ZERO
	layer.add_child(animals_bg)

	field = Node2D.new()
	field.name = "SpecialStageField"
	layer.add_child(field)
	for i in range(MATRIX_SIZE * MATRIX_SIZE):
		var sprite := Sprite2D.new()
		sprite.centered = true
		sprite.visible = false
		field.add_child(sprite)
		block_sprites.append(sprite)

	sonic_sprite = Sprite2D.new()
	sonic_sprite.centered = true
	sonic_sprite.z_index = 80
	field.add_child(sonic_sprite)

	hud_label = Label.new()
	hud_label.position = Vector2(8, 6)
	hud_label.z_index = 100
	hud_label.text = "RINGS  0"
	layer.add_child(hud_label)

	white_flash = ColorRect.new()
	white_flash.position = Vector2.ZERO
	white_flash.size = Vector2(320, 224)
	white_flash.color = Color(1, 1, 1, 0)
	white_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white_flash.z_index = 300
	layer.add_child(white_flash)

	result_ui = SpecialStageResultUI.new()
	result_ui.name = "SpecialStageResultUI"
	result_ui.z_index = 400
	layer.add_child(result_ui)

func _set_gameplay_visible(visible: bool) -> void:
	if host == null:
		return
	for path in ["GHZBackgroundRenderer", "GHZRenderer", "ObjectManager", "SonicEffects"]:
		var node = host.get_node_or_null(path)
		if node != null and node is CanvasItem:
			node.visible = visible
	var normal_player = manager.player if manager != null else null
	if normal_player != null and normal_player is CanvasItem:
		normal_player.visible = visible
	for path in ["UI/SonicHUD", "UI/EndCard", "UI/GameOverUI"]:
		var ui = host.get_node_or_null(path)
		if ui != null and ui is CanvasItem:
			ui.visible = visible

func _current_input_mask() -> int:
	if demo_mode:
		return demo_mask
	var mask := 0
	if Input.is_action_pressed("up"): mask |= 0x01
	if Input.is_action_pressed("down"): mask |= 0x02
	if Input.is_action_pressed("left"): mask |= 0x04
	if Input.is_action_pressed("right"): mask |= 0x08
	if Input.is_action_pressed("A") or Input.is_action_pressed("B") or Input.is_action_pressed("C"): mask |= 0x20
	return mask

func _tick_control(mask: int, jump_pressed: bool) -> void:
	if updown_timeout > 0: updown_timeout -= 1
	if reverse_timeout > 0: reverse_timeout -= 1
	if not in_air and jump_pressed:
		SonicAudio.play_sfx(SonicAudio.SFX_JUMP)
		var jump_angle := ((-(_angle_byte() & 0xFC) - 0x40) & 0xFF)
		var jr := float(jump_angle) * TAU / 256.0
		player_vel = Vector2(cos(jr), sin(jr)) * (float(JUMP_SPEED) / 256.0)
		in_air = true

	# Object $09 stores facing directly in obStatus bit 0. Left sets it and
	# right clears it; if both are held, the source executes Right second.
	if (mask & 0x04) != 0:
		facing_left = true
	if (mask & 0x08) != 0:
		facing_left = false

	if (mask & 0x04) != 0:
		if inertia_raw <= 0:
			inertia_raw = maxi(-MAX_INERTIA, inertia_raw - ACCEL)
		else:
			inertia_raw -= DECEL
	elif (mask & 0x08) != 0:
		if inertia_raw >= 0:
			inertia_raw = mini(MAX_INERTIA, inertia_raw + ACCEL)
		else:
			inertia_raw += DECEL
	else:
		if inertia_raw > 0:
			inertia_raw = maxi(0, inertia_raw - ACCEL)
		elif inertia_raw < 0:
			inertia_raw = mini(0, inertia_raw + ACCEL)

	# SonicSS_AngleSpeed: project ground inertia along the nearest 90-degree
	# stage orientation, then reject the move if it intersects a solid cell.
	var snap_angle := (-((_angle_byte() + 0x20) & 0xC0)) & 0xFF
	var sr := float(snap_angle) * TAU / 256.0
	var ground_delta := Vector2(cos(sr), sin(sr)) * (float(inertia_raw) / 256.0)
	if ground_delta.length_squared() > 0.0:
		var hit := _solid_at(player_pos + ground_delta)
		if bool(hit.get("solid", false)):
			inertia_raw = 0
			_handle_solid_action(hit)
		else:
			player_pos += ground_delta

	# SonicSS_Fall: gravity follows the rotating stage. Test X and Y separately
	# just like the source so landing on any side of a block works as gravity turns.
	var ar := float(_angle_byte() & 0xFC) * TAU / 256.0
	player_vel.x += sin(ar) * (float(GRAVITY) / 256.0)
	player_vel.y += cos(ar) * (float(GRAVITY) / 256.0)

	# SonicSS_Fall clears the in-air bit if EITHER axis probe touches a solid
	# block.  Crucially, an X-side wall contact stays grounded even when the Y
	# probe is clear; Phase 48 incorrectly set in_air back to true in that case,
	# preventing the source-allowed wall jump at several rotated stage angles.
	var touched_solid := false
	var hit_x := _solid_at(player_pos + Vector2(player_vel.x, 0))
	if bool(hit_x.get("solid", false)):
		player_vel.x = 0
		touched_solid = true
		_handle_solid_action(hit_x)
	else:
		player_pos.x += player_vel.x
	var hit_y := _solid_at(player_pos + Vector2(0, player_vel.y))
	if bool(hit_y.get("solid", false)):
		player_vel.y = 0
		touched_solid = true
		_handle_solid_action(hit_y)
	else:
		player_pos.y += player_vel.y
	# A bumper explicitly launches Sonic after contact; preserve that action.
	if touched_solid and int(hit_x.get("id", 0)) != ID_BUMPER and int(hit_y.get("id", 0)) != ID_BUMPER:
		in_air = false
	elif not touched_solid:
		in_air = true

	_handle_non_solid_item()

func _solid_at(pos: Vector2) -> Dictionary:
	var col := floori((pos.x + 20.0) / float(BLOCK_SIZE)) - PADDING_CELLS
	var row := floori((pos.y + 68.0) / float(BLOCK_SIZE)) - PADDING_CELLS
	for dy in range(2):
		for dx in range(2):
			var rr := row + dy
			var cc := col + dx
			var id := _cell(rr, cc)
			if _is_solid(id):
				return {"solid":true, "id":id, "row":rr, "col":cc}
	return {"solid":false}

func _is_solid(id: int) -> bool:
	if id == 0 or id == ID_1UP:
		return false
	if id < ID_RING:
		return true
	return id >= ID_GLASS_ANI_FIRST

func _handle_non_solid_item() -> void:
	var col := floori((player_pos.x + 32.0) / float(BLOCK_SIZE)) - PADDING_CELLS
	var row := floori((player_pos.y + 80.0) / float(BLOCK_SIZE)) - PADDING_CELLS
	var id := _cell(row, col)
	if id == 0:
		if ghost_state == 2:
			_make_ghost_solid()
		return
	match id:
		ID_RING:
			SonicAudio.play_ring_sfx()
			_start_collectible_animation(row, col, 0x42, false)
			special_rings += 1
			manager.rings = special_rings
			if special_rings == 50 and not continue_awarded and not demo_mode:
				# SonicSS_GetContinue: exactly one continue can be awarded in a
				# Special Stage when the ring counter first reaches 50.
				continue_awarded = true
				manager.continues += 1
				SonicAudio.play_sfx(SonicAudio.SFX_CONTINUE)
		ID_1UP:
			SonicAudio.play_jingle(SonicAudio.MUS_EXTRA_LIFE)
			_start_collectible_animation(row, col, 0x46, false)
			manager.lives += 1
		ID_GHOST:
			ghost_state = 1
		ID_GHOST_TRIGGER:
			if ghost_state == 1:
				ghost_state = 2
		_:
			if id >= ID_EMERALD_FIRST and id <= ID_EMERALD_LAST:
				_collect_emerald(row, col, id)

func _handle_solid_action(hit: Dictionary) -> void:
	var id := int(hit.get("id", 0))
	var row := int(hit.get("row", -1))
	var col := int(hit.get("col", -1))
	match id:
		ID_BUMPER:
			SonicAudio.play_sfx(SonicAudio.SFX_BUMPER)
			var center := _cell_center(row, col)
			var away := player_pos - center
			if away.length_squared() < 0.001:
				away = Vector2.UP
			player_vel = away.normalized() * (float(0x700) / 256.0)
			in_air = true
			var bkey := _cell_key(row, col)
			if not bumper_timers.has(bkey):
				bumper_timers[bkey] = {"timer":40, "row":row, "col":col}
				_set_cell(row, col, 0x32)
		ID_GOAL:
			SonicAudio.play_sfx(SonicAudio.SFX_SS_GOAL)
			exiting = true
		ID_UP:
			if updown_timeout <= 0:
				SonicAudio.play_sfx(SonicAudio.SFX_SS_ITEM)
				updown_timeout = ACTION_TIMEOUT
				if absi(rotate_speed) < ROTATE_BASE * 2:
					rotate_speed *= 2
					_set_cell(row, col, ID_DOWN)
		ID_DOWN:
			if updown_timeout <= 0:
				SonicAudio.play_sfx(SonicAudio.SFX_SS_ITEM)
				updown_timeout = ACTION_TIMEOUT
				if absi(rotate_speed) > ROTATE_BASE:
					rotate_speed = int(rotate_speed / 2)
					_set_cell(row, col, ID_UP)
		ID_R:
			if reverse_timeout <= 0:
				SonicAudio.play_sfx(SonicAudio.SFX_SS_ITEM)
				reverse_timeout = ACTION_TIMEOUT
				rotate_speed = -rotate_speed
				var rkey := _cell_key(row, col)
				reverse_timers[rkey] = {"timer":40, "row":row, "col":col}
		_:
			if id >= ID_GLASS_FIRST and id <= ID_GLASS_LAST:
				SonicAudio.play_sfx(SonicAudio.SFX_SS_GLASS)
				var key := _cell_key(row, col)
				if not glass_timers.has(key):
					glass_timers[key] = {"timer":18, "target":0 if id == ID_GLASS_LAST else id + 1, "row":row, "col":col}
					_set_cell(row, col, ID_GLASS_ANI_FIRST)

func _collect_emerald(row: int, col: int, id: int) -> void:
	if got_emerald:
		return
	SonicAudio.play_music(SonicAudio.MUS_GET_EMERALD)
	got_emerald = true
	_start_collectible_animation(row, col, 0x46, true)
	if manager.emeralds < 6:
		manager.emeralds += 1
		if not manager.emerald_stage_ids.has(stage_index):
			manager.emerald_stage_ids.append(stage_index)
		# SonicSS_GetEmerald stores the emerald block ID minus $3B into
		# v_emldlist. Preserve that actual color/frame ID independently of
		# the stage number so Object $7F can display collection order exactly.
		manager.emerald_color_ids.append(clampi(id - ID_EMERALD_FIRST, 0, 5))
	emerald_exit_timer = 25


func _start_collectible_animation(row: int, col: int, first_id: int, emerald: bool) -> void:
	var key := _cell_key(row, col)
	if collectible_timers.has(key):
		return
	_set_cell(row, col, first_id)
	collectible_timers[key] = {"timer":6, "frame":0, "base":first_id, "row":row, "col":col, "emerald":emerald}

func _make_ghost_solid() -> void:
	for i in range(layout.size()):
		if int(layout[i]) == ID_GHOST:
			layout[i] = ID_REDWHITE
	ghost_state = 0

func _tick_exit_spin() -> void:
	rotate_speed += ROTATE_BASE
	stage_angle = (stage_angle + rotate_speed) & 0xFFFF
	if rotate_speed == EXIT_ROTATE_TARGET or rotate_speed > EXIT_ROTATE_TARGET:
		whiteout_timer = 60
		palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_OUT, 0)
		white_flash.color = Color(1, 1, 1, 0)
		_render_frame()

func _tick_whiteout() -> void:
	# SS_FinLoop lasts 60 frames and calls WhiteOut_ToWhite immediately, then
	# once every three frames via v_palchgspeed=2. Preserve that staircase
	# instead of the Phase 48/49 linear alpha-to-white approximation.
	var elapsed := 60 - whiteout_timer
	var step := mini(GenesisPaletteFade.SOURCE_STEPS, 1 + int(elapsed / 3))
	palette_fade.show_step(GenesisPaletteFade.MODE_WHITE_OUT, step)
	whiteout_timer -= 1
	stage_angle = (stage_angle + rotate_speed) & 0xFFFF
	_render_frame()
	if whiteout_timer <= 0:
		palette_fade.hide_fade()
		if demo_mode:
			_finish_demo()
		else:
			_begin_results()

func _begin_results() -> void:
	# GM_Special clears the playfield, loads Pal_SSResult/PLC_SSResult, starts
	# Got Through music, then creates Object $7E.  The native renderer already
	# has all source assets resident, so build the same screen directly.
	results_state = 1 # SSR_Move
	results_timer = 0
	result_ring_bonus = special_rings
	white_flash.color = Color(1, 1, 1, 0)
	field.visible = false
	bg.visible = false
	if animals_bg != null:
		animals_bg.visible = false
	backdrop.visible = false
	hud_label.visible = false
	SonicAudio.play_music(SonicAudio.MUS_GOT_THROUGH)
	if result_ui != null:
		result_ui.begin(manager.emeralds, manager.emerald_color_ids, special_rings >= 50, manager.score, result_ring_bonus * 100)

func _tick_results() -> void:
	# Object $7F alternates each emerald between its real frame and blank every
	# VBlank once the Ring Bonus controller has reached its target.
	if result_ui != null and results_state >= 2:
		# Only the Ring Bonus element advances to SSR_Wait.  The other $7E
		# elements remain in SSR_Move until they independently reach X=$120.
		result_ui.tick_move_in()
		result_ui.tick_emerald_flash(manager.emeralds)

	match results_state:
		1: # SSR_Move
			if result_ui != null and result_ui.tick_move_in():
				result_ui.show_emeralds(manager.emeralds)
				results_state = 2 # SSR_Wait
				results_timer = 3 * 60
		2: # three-second wait before tally
			results_timer -= 1
			if results_timer <= 0:
				results_state = 3 # SSR_RingBonus
		3:
			if result_ring_bonus > 0:
				result_ring_bonus -= 1
				manager.add_score(100)
				if result_ui != null:
					result_ui.update_values(manager.score, result_ring_bonus * 100)
				if (frame_counter & 3) == 0:
					SonicAudio.play_sfx(SonicAudio.SFX_SWITCH)
			else:
				SonicAudio.play_sfx(SonicAudio.SFX_CASH)
				results_state = 4
				# Retail uses one second before the Continue animation when 50+
				# rings were collected, otherwise the normal three-second exit wait.
				results_timer = 1 * 60 if special_rings >= 50 else 3 * 60
		4:
			results_timer -= 1
			if results_timer <= 0:
				if special_rings >= 50:
					if result_ui != null:
						result_ui.activate_continue()
					SonicAudio.play_sfx(SonicAudio.SFX_CONTINUE)
					results_state = 5
					results_timer = 6 * 60
				else:
					_finish_results_screen()
		5:
			if result_ui != null:
				result_ui.tick_continue_animation(frame_counter & 0xFF)
			results_timer -= 1
			if results_timer <= 0:
				_finish_results_screen()

func _finish_results_screen() -> void:
	# SS_NormalExit queues the same enter-Special-Stage sound on the way back
	# to the level.  Keep the already-runtime-confirmed transition mechanism
	# intact; only restore the source sound trigger here.
	SonicAudio.play_sfx(SonicAudio.SFX_ENTER_SS)
	finished = true
	active = false

func _tick_local_animations() -> void:
	for key in collectible_timers.keys():
		var state: Dictionary = collectible_timers[key]
		var t := int(state.get("timer", 0)) - 1
		var frame := int(state.get("frame", 0))
		var base := int(state.get("base", 0))
		var row := int(state.get("row", -1))
		var col := int(state.get("col", -1))
		if t <= 0:
			frame += 1
			if frame >= 4:
				_set_cell(row, col, 0)
				collectible_timers.erase(key)
			else:
				state["timer"] = 6
				state["frame"] = frame
				_set_cell(row, col, base + frame)
				collectible_timers[key] = state
		else:
			state["timer"] = t
			collectible_timers[key] = state
	for key in bumper_timers.keys():
		var state: Dictionary = bumper_timers[key]
		var t := int(state.get("timer", 0)) - 1
		var row := int(state.get("row", -1))
		var col := int(state.get("col", -1))
		if t <= 0:
			_set_cell(row, col, ID_BUMPER)
			bumper_timers.erase(key)
		else:
			state["timer"] = t
			var phase := clampi(int((40 - t) / 8), 0, 3)
			_set_cell(row, col, 0x32 if (phase & 1) == 0 else 0x33)
			bumper_timers[key] = state
	for key in reverse_timers.keys():
		var state: Dictionary = reverse_timers[key]
		var t := int(state.get("timer", 0)) - 1
		var row := int(state.get("row", -1))
		var col := int(state.get("col", -1))
		if t <= 0:
			_set_cell(row, col, ID_R)
			reverse_timers.erase(key)
		else:
			state["timer"] = t
			var phase := clampi(int((40 - t) / 8), 0, 3)
			_set_cell(row, col, ID_R if (phase & 1) == 0 else 0x31)
			reverse_timers[key] = state
	for key in glass_timers.keys():
		var state: Dictionary = glass_timers[key]
		var t := int(state.get("timer", 0)) - 1
		var row := int(state.get("row", -1))
		var col := int(state.get("col", -1))
		if t <= 0:
			_set_cell(row, col, int(state.get("target", 0)))
			glass_timers.erase(key)
		else:
			state["timer"] = t
			var elapsed := 18 - t
			var phase := clampi(int(elapsed / 2), 0, 7)
			_set_cell(row, col, ID_GLASS_ANI_FIRST + (phase & 3))
			glass_timers[key] = state

func _advance_ss_bg_cycle() -> void:
	var idx := ss_bg_timing_index & 0x1F
	var source_time := SS_BG_TIMES[idx]
	ss_bg_mode = SS_BG_MODES[idx]
	# SS_Timing_Values entries 0-15 point BG nametable at Plane 6 (the
	# 64x64 cloud map); entries 16-31 point it at Plane 5 (the 64x32 bubble
	# map). This switch is independent of the bird/fish morph mode.
	ss_bg_plane_clouds = idx < 16
	ss_bg_timer = 0x1FF if source_time == 0 else source_time - 1
	ss_bg_timing_index = (idx + 1) & 0x1F

func _tick_ss_bg_cycle() -> void:
	# VBlank_SpecialStage calls PalCycle_SS before the main-loop render.
	ss_bg_timer -= 1
	if ss_bg_timer < 0:
		_advance_ss_bg_cycle()

func _tick_ss_bg_motion() -> void:
	# Direct translation of SS_BGAnimate's background state. Mode 0 resets the
	# Plane-B vertical scroll. Fish mode 6 pans Plane A right and Plane B down;
	# bird mode $C pans Plane A left. Bubble and cloud line-scroll buffers keep
	# updating in their respective mode families exactly as the 68000 does.
	if ss_bg_mode == 0:
		ss_bgscreenposy = 0

	if ss_bg_mode < 8:
		if ss_bg_mode == 6:
			ss_bg3screenposx += 1
			ss_bgscreenposy = (ss_bgscreenposy + 1) & 0xFFFF
		_tick_ss_bubble_scroll()
	else:
		if ss_bg_mode == 0x0C:
			ss_bg3screenposx -= 1
			var rate_fp := 0x18000
			for i in range(7):
				ss_cloud_scroll_fp[i] -= rate_fp
				rate_fp -= 0x2000

func _tick_ss_bubble_scroll() -> void:
	const AMPLITUDES: Array[int] = [8,4,2,8,4,2,8,4,2,2]
	const PHASE_SPEEDS: Array[int] = [2,-1,3,-1,2,3,-3,2,3,-1]
	for i in range(10):
		var angle := ss_bubble_phase[i] & 0xFF
		# CalcSine returns approximately +/-$100. Using a rounded 256-scale
		# sine produces the same pixel-range wobble after the source >>8.
		var sine_value := roundi(sin(float(angle) * TAU / 256.0) * 256.0)
		ss_bubble_scroll[i] = (sine_value * AMPLITUDES[i]) >> 8
		ss_bubble_phase[i] = (ss_bubble_phase[i] + PHASE_SPEEDS[i]) & 0xFFFF

func _signed_high_word(value: int) -> int:
	var word := (value >> 16) & 0xFFFF
	return word - 0x10000 if word >= 0x8000 else word

func _ss_bg_band_index(logical_y: int, heights: Array[int]) -> Dictionary:
	var y := posmod(logical_y, 256)
	var cursor := 0
	for i in range(heights.size()):
		var h := heights[i]
		if y < cursor + h:
			return {"index":i, "within":y - cursor, "remain":cursor + h - y}
		cursor += h
	return {"index":heights.size() - 1, "within":0, "remain":heights[heights.size() - 1]}

func _update_ss_background_render() -> void:
	if bg == null or animals_bg == null:
		return

	# Plane A: one globally scrolling, horizontally repeating bird/fish canvas.
	var animal_frame := clampi(ss_bg_mode >> 1, 0, 6)
	animals_bg.texture = SpecialStageArt.background_animals_texture(animal_frame)
	var animal_y := 1 if ss_bg_mode == 0 or ss_bg_mode == 4 or ss_bg_mode == 8 or ss_bg_mode == 0x0C else 0
	animals_bg.region_rect = Rect2(float(ss_bg3screenposx), float(animal_y), 320.0, 224.0)
	animals_bg.position = Vector2.ZERO

	# Plane B: source H-scroll table has 10 bubble bands or 7 cloud bands,
	# each totaling exactly 256 scanlines. Split the visible 224 lines at the
	# authored band boundaries (including vertical-wrap boundaries) and assign
	# a repeating region to each segment.
	var heights: Array[int] = [40,24,16,40,24,16,48,24,8,16]
	var texture = SpecialStageArt.background_bubbles_texture()
	var plane_height := 256
	if ss_bg_plane_clouds:
		heights = [48,48,48,40,24,24,24]
		texture = SpecialStageArt.background_clouds_texture()
		plane_height = 512

	for strip in bg_strips:
		strip.visible = false

	var screen_y := 0
	var strip_index := 0
	while screen_y < 224 and strip_index < bg_strips.size():
		var logical_y := posmod(screen_y + ss_bgscreenposy, 256)
		var info := _ss_bg_band_index(logical_y, heights)
		var segment_h := mini(int(info["remain"]), 224 - screen_y)
		var band := int(info["index"])
		var hscroll := 0
		if ss_bg_plane_clouds:
			hscroll = _signed_high_word(ss_cloud_scroll_fp[band])
		else:
			hscroll = ss_bubble_scroll[band]

		var strip := bg_strips[strip_index]
		strip.texture = texture
		strip.position = Vector2(0, screen_y)
		# VDP H-scroll moves the plane by hscroll; a sampled texture moves the
		# opposite way, so negate it in the source region coordinate. Texture
		# repeat provides unlimited panning regardless of accumulated scroll.
		var source_y := posmod(screen_y + ss_bgscreenposy, plane_height)
		strip.region_rect = Rect2(float(-hscroll), float(source_y), 320.0, float(segment_h))
		strip.visible = texture != null

		screen_y += segment_h
		strip_index += 1

func _render_frame() -> void:
	if field == null:
		return
	var cam_x := maxi(0, floori(player_pos.x) - 160)
	var cam_y := maxi(0, floori(player_pos.y) - 112)
	var base_col_padded := floori(float(cam_x) / BLOCK_SIZE)
	var base_row_padded := floori(float(cam_y) / BLOCK_SIZE)
	var rem_x := posmod(cam_x, BLOCK_SIZE)
	var rem_y := posmod(cam_y, BLOCK_SIZE)
	var radians := float(_angle_byte() & 0xFC) * TAU / 256.0
	var wall_frame := (_angle_byte() >> 2) & 0x0F
	var wall_palette_phase := (7 - int(frame_counter / 8)) & 7
	var two_frame := (frame_counter >> 3) & 1
	var ring_frame := (frame_counter >> 3) & 3
	var sprite_index := 0
	for r in range(MATRIX_SIZE):
		for c in range(MATRIX_SIZE):
			var rr := base_row_padded + r - PADDING_CELLS
			var cc := base_col_padded + c - PADDING_CELLS
			var id := _cell(rr, cc)
			var sprite := block_sprites[sprite_index]
			sprite_index += 1
			if id == 0 or id > 0x4E:
				sprite.visible = false
				continue
			var local := Vector2(MATRIX_BASE - rem_x + c * BLOCK_SIZE, MATRIX_BASE - rem_y + r * BLOCK_SIZE)
			var screen_pos := SCREEN_CENTER + local.rotated(radians)
			if screen_pos.x < -24 or screen_pos.x > 344 or screen_pos.y < -24 or screen_pos.y > 248:
				sprite.visible = false
				continue
			var anim := wall_palette_phase if id >= 0x01 and id <= 0x24 else two_frame
			if id == ID_RING:
				anim = ring_frame
			var texture = SpecialStageArt.block_texture(id, wall_frame, anim)
			sprite.texture = texture
			sprite.position = screen_pos
			sprite.visible = texture != null

	var sonic_frame := 0x2E + (int(frame_counter / 4) % 5)
	sonic_sprite.texture = load("res://assets/sonic/frames/%02d.png" % sonic_frame)
	sonic_sprite.position = Vector2(player_pos.x - cam_x, player_pos.y - cam_y)
	sonic_sprite.rotation = 0
	sonic_sprite.flip_h = facing_left
	hud_label.text = "RINGS  %d    EMERALDS  %d" % [special_rings, manager.emeralds]
	_update_ss_background_render()

func _cell(row: int, col: int) -> int:
	if row < 0 or col < 0 or row >= LAYOUT_SIZE or col >= LAYOUT_SIZE:
		return 0
	return int(layout[row * LAYOUT_SIZE + col])

func _set_cell(row: int, col: int, value: int) -> void:
	if row < 0 or col < 0 or row >= LAYOUT_SIZE or col >= LAYOUT_SIZE:
		return
	layout[row * LAYOUT_SIZE + col] = value & 0xFF

func _cell_center(row: int, col: int) -> Vector2:
	# Inverse of Object $09's item lookup: (x+32)/24 and (y+80)/24 into
	# the padded $80-byte rows. This is the logical centre used for bumper force.
	return Vector2(col * BLOCK_SIZE + 748.0, row * BLOCK_SIZE + 700.0)

func _cell_key(row: int, col: int) -> int:
	return row * LAYOUT_SIZE + col

func _angle_byte() -> int:
	return (stage_angle >> 8) & 0xFF

func _tick_demo_stream() -> void:
	demo_frames_remaining -= 1
	demo_input_remaining -= 1
	if demo_input_remaining <= 0:
		demo_input_index += 1
		_load_demo_input()

func _load_demo_input() -> void:
	if demo_input_index < 0 or demo_input_index >= SpecialStageDemoData.INPUTS.size():
		demo_mask = 0
		demo_input_remaining = 0x7FFF
		return
	var entry: Array = SpecialStageDemoData.INPUTS[demo_input_index]
	demo_mask = int(entry[0])
	demo_input_remaining = int(entry[1])

func _finish_demo() -> void:
	finished = true
	active = false
	restart_startup_requested = true

static func _be16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])
