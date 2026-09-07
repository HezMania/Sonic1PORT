class_name SonicCamera
extends RefCounted

# Data-driven version of ScrollHoriz/ScrollVertical + LevelSizeLoad.  GHZ1-3
# dynamic bottom-boundary events are translated here; other registered zones
# currently use their LevelSizeArray bounds until their own DLE is ported.

var VIEW_WIDTH = ProjectSettings.get_setting("display/window/size/viewport_width")
var VIEW_HEIGHT = ProjectSettings.get_setting("display/window/size/viewport_height")
const DEFAULT_LOOK_SHIFT := 0x60
const MAX_LOOK_UP := 0xC8
const MAX_LOOK_DOWN := 0x08
const S2_LOOK_DELAY_FRAMES := 0x78
# SwScrl_RippleData: MCZ/HTZ screen-shake samples. The source indexes the
# 66-byte table with Timer_frames&$3F and consumes vertical, then horizontal.
const S2_MCZ_RIPPLE_DATA: Array[int] = [
	1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,
	2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3,
	1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,
	2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3,
	1,2,
]
const BOSS_FZ_X := 0x2450

var definition: Dictionary = LevelCatalog.get_level(LevelCatalog.ZONE_GHZ, 1)
var limit_left := 0
var limit_right := 0x24BF
var limit_top := 0
var base_bottom := 0x300
var dynamic_event := "ghz1"

var screen_x := 0
var screen_y := 0
var shift_x := 0
var shift_y := 0
var look_shift := DEFAULT_LOOK_SHIFT
var look_delay_counter = 0
var target_bottom := 0x300
var current_bottom := 0x300
var bottom_boundary_moving := false
var dle_routine := 0
var boss_triggered := false
var boss_blocks_triggered := false
# Phase 43 SBZ2 trap-floor/cutscene DLE flags and internal SBZ3 exit.
var sbz_false_floor_triggered := false
var sbz_eggman_triggered := false
var sbz2_screen_locked := false
var sbz3_exit_triggered := false
# Phase 89 retail S2 EHZ2 boss prelude state (ScreenShift + fade request).
var s2_ehz2_event_timer := 0
var s2_ehz2_music_fade_requested := false
# Hotfix 1: unlike the generic Sonic 1 boss flag, this request is persistent.
# The source invokes SingleObjLoad inline inside LevEvents_EHZ2; our camera and
# object manager are separate systems, so preserve the request until creation is
# acknowledged instead of relying on a one-frame cross-system flag.
var s2_ehz2_boss_spawn_requested := false
# Phase 94 retail CPZ2 boss prelude state.
var s2_cpz2_event_timer := 0
var s2_cpz2_music_fade_requested := false
var s2_cpz2_boss_spawn_requested := false
# Phase 97 retail ARZ2 boss prelude. Object $89 is allocated at the arena lock;
# boss music begins only after the source $5A-frame ScreenShift wait.
var s2_arz2_event_timer := 0
var s2_arz2_music_fade_requested := false
var s2_arz2_boss_spawn_requested := false
var s2_arz2_boss_music_requested := false
# Phase 104 retail CNZ2 boss prelude/event state.
var s2_cnz2_event_timer := 0
var s2_cnz2_music_fade_requested := false
var s2_cnz2_boss_palette_requested := false
var s2_cnz2_boss_spawn_requested := false
var s2_cnz2_refresh_c54_requested := false
var s2_cnz2_refresh_c50_requested := false
# Phase 106 retail Hill Top Act 1 earthquake/background state.
var s2_htz_quake_active := false
var s2_htz_visual_shake := false
var s2_htz_bg_y_offset := 0
var s2_htz_terrain_direction := 0
var s2_htz_terrain_delay := 0
var s2_htz_frame_counter := 0
# Phase 110 retail Hill Top Act 2 boss prelude/end state.
var s2_htz2_event_timer := 0
var s2_htz2_music_fade_requested := false
var s2_htz2_boss_spawn_requested := false
var s2_htz2_boss_defeated := false
# Phase 114 retail Mystic Cave Act 2 boss prelude/end state.
var s2_mcz2_event_timer := 0
var s2_mcz2_music_fade_requested := false
var s2_mcz2_boss_palette_requested := false
var s2_mcz2_boss_spawn_requested := false
var s2_mcz_screen_shake_active := false
var s2_mcz_screen_shake_phase := 0
# Phase 118 retail Oil Ocean Act 2 boss prelude/end state.
var s2_ooz2_event_timer := 0
var s2_ooz2_music_fade_requested := false
var s2_ooz2_boss_palette_requested := false
var s2_ooz2_boss_spawn_requested := false
# Phase 124 retail Metropolis Act 3 boss-arena prelude. Object $54 itself is
# intentionally deferred to Phase 125, so the final request is exposed only as
# a safe "boss ready" boundary rather than allocating an incomplete fight.
var s2_mtz3_event_timer := 0
var s2_mtz3_music_fade_requested := false
var s2_mtz3_boss_ready := false
# Phase 126 retail Sky Chase auto-scroll state.
var s2_scz_velocity_x := 0
var s2_scz_velocity_y := 0
var s2_scz_bg_x_fixed := 0
# Phase 127 retail Wing Fortress background/event state. LevEvents_WFZ offsets
# the Plane-B camera during the late ship transition while the foreground
# remains under ordinary Sonic camera control.
var s2_wfz_bg_x_offset := 0
var s2_wfz_bg_y_offset := 0
var s2_wfz_bg_y_speed := 0
var s2_wfz_bg_x_pos := 0
var s2_wfz_bg_y_pos := 0
var s2_wfz_event_subroutine := 0
var s2_wfz_boss_ready := false
# Phase 132 retail Death Egg LevEvents state.
var s2_dez_mecha_spawn_requested := false
var s2_dez_final_boss_ready := false

func configure_level(level_definition: Dictionary) -> void:
	definition = level_definition.duplicate(true)
	limit_left = int(definition.get("limit_left", 0))
	limit_right = int(definition.get("limit_right", 0x24BF))
	limit_top = int(definition.get("limit_top", 0))
	base_bottom = int(definition.get("limit_bottom", 0x300))
	dynamic_event = String(definition.get("dynamic_events", "none"))
	dle_routine = 0
	boss_triggered = false
	boss_blocks_triggered = false
	sbz_false_floor_triggered = false
	sbz_eggman_triggered = false
	sbz2_screen_locked = false
	sbz3_exit_triggered = false
	s2_ehz2_event_timer = 0
	s2_ehz2_music_fade_requested = false
	s2_ehz2_boss_spawn_requested = false
	s2_cpz2_event_timer = 0
	s2_cpz2_music_fade_requested = false
	s2_cpz2_boss_spawn_requested = false
	s2_arz2_event_timer = 0
	s2_arz2_music_fade_requested = false
	s2_arz2_boss_spawn_requested = false
	s2_arz2_boss_music_requested = false
	s2_cnz2_event_timer = 0
	s2_cnz2_music_fade_requested = false
	s2_cnz2_boss_palette_requested = false
	s2_cnz2_boss_spawn_requested = false
	s2_cnz2_refresh_c54_requested = false
	s2_cnz2_refresh_c50_requested = false
	s2_htz_quake_active = false
	s2_htz_visual_shake = false
	s2_htz_bg_y_offset = 0
	s2_htz_terrain_direction = 0
	s2_htz_terrain_delay = 0
	s2_htz_frame_counter = 0
	s2_htz2_event_timer = 0
	s2_htz2_music_fade_requested = false
	s2_htz2_boss_spawn_requested = false
	s2_htz2_boss_defeated = false
	s2_mcz2_event_timer = 0
	s2_mcz2_music_fade_requested = false
	s2_mcz2_boss_palette_requested = false
	s2_mcz2_boss_spawn_requested = false
	s2_mcz_screen_shake_active = false
	s2_mcz_screen_shake_phase = 0
	s2_ooz2_event_timer = 0
	s2_ooz2_music_fade_requested = false
	s2_ooz2_boss_palette_requested = false
	s2_ooz2_boss_spawn_requested = false
	s2_mtz3_event_timer = 0
	s2_mtz3_music_fade_requested = false
	s2_mtz3_boss_ready = false
	s2_scz_velocity_x = 0
	s2_scz_velocity_y = 0
	s2_scz_bg_x_fixed = 0
	s2_wfz_bg_x_offset = 0
	s2_wfz_bg_y_offset = 0
	s2_wfz_bg_y_speed = 0
	s2_wfz_bg_x_pos = 0
	s2_wfz_bg_y_pos = 0
	s2_wfz_event_subroutine = 0
	s2_wfz_boss_ready = false
	s2_dez_mecha_spawn_requested = false
	s2_dez_final_boss_ready = false

func initialize(player: SonicPlayer) -> void:
	var start_x = player.pixel_x() - (VIEW_WIDTH >> 1)
	start_x = clampi(start_x, limit_left, limit_right)
	screen_x = start_x

	target_bottom = _initial_bottom_for_position(screen_x, player.pixel_y())
	current_bottom = target_bottom
	var start_y = player.pixel_y() - ((VIEW_HEIGHT >> 1) - 16)
	start_y = clampi(start_y, limit_top, current_bottom)
	screen_y = start_y
	shift_x = 0
	shift_y = 0
	look_shift = DEFAULT_LOOK_SHIFT
	look_delay_counter = 0
	bottom_boundary_moving = false

func update(player: SonicPlayer) -> void:
	if player.debug_free_mode:
		_debug_follow(player)
		return
	# Drowning sets f_nobgscroll before the two-second sink, and Sonic_Death
	# keeps the camera frozen afterward. Preserve the same anchored level view.
	if player.dead or player.drowning:
		shift_x = 0
		shift_y = 0
		return
	if dynamic_event == "s2_scz":
		_update_s2_scz_camera()
		return
	_update_look_shift(player)
	_scroll_horiz(player)
	_scroll_vertical(player)
	_update_dynamic_level_events(player)

func apply_to(camera: Camera2D) -> void:
	camera.position = Vector2(float(screen_x + (VIEW_WIDTH >> 1)), float(screen_y + (VIEW_HEIGHT >> 1)))
	if s2_mcz_screen_shake_active:
		var i: int = s2_mcz_screen_shake_phase & 0x3F
		# SwScrl_MCZ adds the first byte to Y and the following byte to X.
		camera.offset = Vector2(S2_MCZ_RIPPLE_DATA[i + 1], S2_MCZ_RIPPLE_DATA[i])
	else:
		camera.offset = Vector2.ZERO

func _debug_follow(player: SonicPlayer) -> void:
	# Original debug mode follows the freely moved debug object. For testing,
	# use the full decoded level dimensions instead of the current DLE corridor
	# so inaccessible/later sections can be inspected immediately.
	var old_x = screen_x
	var old_y = screen_y
	var max_x = maxi(0, player.level.world_width_pixels() - int(VIEW_WIDTH)) if player.level != null else limit_right
	var max_y = maxi(0, player.level.world_height_pixels() - int(VIEW_HEIGHT)) if player.level != null else current_bottom
	screen_x = clampi(player.pixel_x() - (int(VIEW_WIDTH) >> 1), 0, max_x)
	screen_y = clampi(player.pixel_y() - (int(VIEW_HEIGHT) >> 1), 0, max_y)
	shift_x = (screen_x - old_x) << 8
	shift_y = (screen_y - old_y) << 8

func _update_look_shift(player: SonicPlayer) -> void:
	var can_look = not player.in_air and not player.rolling and absi(player.inertia) < 0x80

	# Retail Sonic 2 Sonic_Lookup/Sonic_Duck holds a separate counter at $78
	# frames before Camera_Y_pos_bias is allowed to move. Spindash charging then
	# follows Obj01_Spindash_ResetScr and actively recenters the camera.
	if player.sonic2_physics_enabled():
		if player.spindash_active:
			look_delay_counter = 0
			_reset_look_shift()
			return
		if can_look and player.input_up and not player.input_down:
			look_delay_counter = mini(S2_LOOK_DELAY_FRAMES, look_delay_counter + 1)
			if look_delay_counter < S2_LOOK_DELAY_FRAMES:
				_reset_look_shift()
				return
			look_shift = mini(MAX_LOOK_UP, look_shift + 2)
			return
		if can_look and player.input_down and not player.input_up:
			look_delay_counter = mini(S2_LOOK_DELAY_FRAMES, look_delay_counter + 1)
			if look_delay_counter < S2_LOOK_DELAY_FRAMES:
				_reset_look_shift()
				return
			look_shift = maxi(MAX_LOOK_DOWN, look_shift - 2)
			return
		look_delay_counter = 0
		_reset_look_shift()
		return

	# Sonic 1 has no look-delay counter: holding Up/Down shifts immediately.
	look_delay_counter = 0
	if can_look and player.input_up and not player.input_down:
		look_shift = mini(MAX_LOOK_UP, look_shift + 2)
		return
	if can_look and player.input_down and not player.input_up:
		look_shift = maxi(MAX_LOOK_DOWN, look_shift - 2)
		return
	_reset_look_shift()

func _reset_look_shift() -> void:
	if look_shift < DEFAULT_LOOK_SHIFT:
		look_shift = mini(DEFAULT_LOOK_SHIFT, look_shift + 2)
	elif look_shift > DEFAULT_LOOK_SHIFT:
		look_shift = maxi(DEFAULT_LOOK_SHIFT, look_shift - 2)

func _scroll_horiz(player: SonicPlayer) -> void:
	var old_x = screen_x
	var d0 = player.pixel_x() - screen_x
	d0 -= (VIEW_WIDTH >> 1) - 16
	if d0 < 0:
		d0 = maxi(d0, -16)
		_set_screen_x(screen_x + d0)
	elif d0 >= 16:
		d0 -= 16
		d0 = mini(d0, 16)
		_set_screen_x(screen_x + d0)
	else:
		shift_x = 0
		return
	shift_x = (screen_x - old_x) << 8

func _set_screen_x(value: int) -> void:
	screen_x = clampi(value, limit_left, limit_right)

func _scroll_vertical(player: SonicPlayer) -> void:
	var d0 = player.pixel_y() - screen_y
	if player.rolling:
		d0 -= SonicPlayer.SONIC_HEIGHT - SonicPlayer.SONIC_ROLL_HEIGHT

	if player.in_air:
		d0 += 32
		d0 -= look_shift
		if d0 < 0:
			_scroll_vertical_with_speed(d0, 16, player)
			return
		d0 -= 64
		if d0 >= 0:
			_scroll_vertical_with_speed(d0, 16, player)
			return
		shift_y = 0
		return

	d0 -= look_shift
	if d0 == 0:
		shift_y = 0
		return
	if look_shift != DEFAULT_LOOK_SHIFT:
		_scroll_vertical_with_speed(d0, 2, player)
		return
	if absi(player.inertia) >= 0x800:
		_scroll_vertical_with_speed(d0, 16, player)
		return
	_scroll_vertical_with_speed(d0, 6, player)

func _scroll_vertical_with_speed(distance: int, max_pixels: int, player: SonicPlayer = null) -> void:
	var old_y = screen_y
	var delta_base_y = old_y
	var movement = clampi(distance, -max_pixels, max_pixels)
	var candidate = screen_y + movement
	if _vertical_wrap_enabled():
		# ScrollVertical's wrap sentinel is exactly top=-$100 / bottom=$800.
		# At either edge Sonic and foreground camera wrap modulo $800; the
		# background is naturally equivalent to modulo $400 through LZ's 1/2 Y.
		# The source also wraps the OLD camera word before calculating v_scrshifty,
		# keeping the reported per-frame delta small instead of producing a $800 jump.
		if candidate <= -0x100:
			delta_base_y = old_y & 0x7FF
			candidate &= 0x7FF
			if player != null:
				player.wrap_vertical_0x800()
		elif candidate >= 0x800:
			delta_base_y = old_y - 0x800
			candidate -= 0x800
			if player != null:
				player.wrap_vertical_0x800()
		screen_y = candidate
	else:
		screen_y = clampi(candidate, limit_top, current_bottom)
	shift_y = (screen_y - delta_base_y) << 8

func _vertical_wrap_enabled() -> bool:
	# MTZ uses the $800 wrap through the main level, but LevEvents_MTZ3 turns
	# the boss approach into an ordinary bounded camera corridor at $2530.
	# Leaving wrap active here bypassed Camera_Max_Y and prevented the retail
	# boss-area vertical camera settle/pan.
	if dynamic_event == "s2_mtz3" and dle_routine >= 2:
		return false
	return int(definition.get("limit_top", 0)) == -0x100 and int(definition.get("limit_bottom", 0)) == 0x800

func _initial_bottom_for_position(x: int, y: int) -> int:
	match dynamic_event:
		"ghz1":
			return 0x400 if x >= 0x1780 else 0x300
		"ghz2":
			if x >= 0x1D60:
				return 0x300
			if x >= 0x1600:
				return 0x400
			if x >= 0x0ED0:
				return 0x200
			return 0x300
		"ghz3":
			if x >= 0x960 and y >= 0x280 and x < 0x1380:
				return 0x4C0
			if x >= 0x380:
				return 0x310
		"mz1":
			if x >= 0x1430:
				return 0x210
			if y >= 0x340:
				return 0x500
			if x >= 0xD00:
				return 0x340
			if x >= 0x700:
				return 0x220
			return 0x1D0
		"mz2":
			return 0x200 if x >= 0x1700 else 0x520
		"syz2":
			return 0x420 if x >= 0x25A0 and y < 0x4D0 else 0x520
		"sbz1":
			if x >= 0x2000:
				return 0x2A0
			if x >= 0x1880:
				return 0x620
			return 0x720
		"sbz2":
			return 0x510 if x >= 0x1800 else 0x800
		"s2_ehz2":
			return 0x390 if x >= 0x2780 else base_bottom
		"s2_cpz2":
			return 0x450 if x >= 0x2680 else base_bottom
		"s2_arz2":
			return 0x400 if x >= 0x2810 else base_bottom
		"s2_cnz2":
			return 0x62E if x >= 0x27C0 else base_bottom
		"s2_ooz2":
			return 0x1E0 if x >= 0x2668 else base_bottom
		"s2_mtz3":
			if x >= 0x2980:
				return 0x400
			if x >= 0x2530:
				return 0x450
	return base_bottom

func _update_dynamic_level_events(player: SonicPlayer) -> void:
	match dynamic_event:
		"ghz1": _dle_ghz1()
		"ghz2": _dle_ghz2()
		"ghz3": _dle_ghz3()
		"mz1": _dle_mz1()
		"mz2": _dle_mz2()
		"mz3": _dle_mz3()
		"syz1": target_bottom = base_bottom
		"syz2": _dle_syz2(player)
		"syz3": _dle_syz3()
		"lz3": _dle_lz3()
		"slz1", "slz2": target_bottom = base_bottom
		"slz3": _dle_slz3()
		"sbz1": _dle_sbz1()
		"sbz2": _dle_sbz2()
		"sbz3": _dle_sbz3(player)
		"fz": _dle_fz()
		"s2_ehz2": _dle_s2_ehz2()
		"s2_cpz2": _dle_s2_cpz2()
		"s2_arz2": _dle_s2_arz2()
		"s2_cnz2": _dle_s2_cnz2(player)
		"s2_htz1": _dle_s2_htz1()
		"s2_htz2": _dle_s2_htz2()
		"s2_mcz2": _dle_s2_mcz2()
		"s2_ooz2": _dle_s2_ooz2()
		"s2_mtz3": _dle_s2_mtz3()
		"s2_scz": _dle_s2_scz()
		"s2_wfz": _dle_s2_wfz(player)
		"s2_dez": _dle_s2_dez()
		_:
			target_bottom = base_bottom
	_ease_bottom_boundary(player)



func _update_s2_scz_camera() -> void:
	# SwScrl_SCZ adds Tornado_Velocity_X/Y directly to Camera_X/Y rather than
	# following Sonic. Plane B advances +$80 in 8.8 whenever X camera motion is
	# non-zero, even during the brief left/down leg.
	_dle_s2_scz()
	var old_x: int = screen_x
	var old_y: int = screen_y
	screen_x = clampi(screen_x + s2_scz_velocity_x, limit_left, limit_right)
	screen_y = clampi(screen_y + s2_scz_velocity_y, limit_top, current_bottom)
	shift_x = (screen_x-old_x) << 8
	shift_y = (screen_y-old_y) << 8
	if s2_scz_velocity_x != 0:
		s2_scz_bg_x_fixed += 0x80

func _dle_s2_scz() -> void:
	# Exact LevEvents_SCZ four-stage Tornado velocity script.
	match dle_routine:
		0:
			s2_scz_velocity_x = 1; s2_scz_velocity_y = 0; dle_routine = 2
		2:
			if screen_x >= 0x1180:
				s2_scz_velocity_x = -1; s2_scz_velocity_y = 1
				current_bottom = 0x500; target_bottom = 0x500; dle_routine = 4
		4:
			if screen_y >= 0x500:
				s2_scz_velocity_x = 1; s2_scz_velocity_y = 0; dle_routine = 6
		6:
			if screen_x >= 0x1400:
				s2_scz_velocity_x = 0; s2_scz_velocity_y = 0; dle_routine = 8



func _step_s2_wfz_bg_to_target(target_x: int, target_y: int) -> void:
	# Retail ScrollBG caps Camera_BG_X/Y_pos_diff to +/-16 pixels per frame.
	# Keep an explicit Plane-B camera instead of deriving Camera-offset directly;
	# the latter skipped the streamer step and made the getaway wrap vertically.
	var dx: int = clampi(target_x - s2_wfz_bg_x_pos, -16, 16)
	var dy: int = clampi(target_y - s2_wfz_bg_y_pos, -16, 16)
	s2_wfz_bg_x_pos += dx
	s2_wfz_bg_y_pos += dy

func _dle_s2_wfz(player: SonicPlayer) -> void:
	# Exact LevEvents_WFZ shape: one background state machine plus the independent
	# boss preload/control-lock state. Plane-B motion goes through the source's
	# ScrollBG +/-16 px/frame integrator rather than jumping to Camera-offset.
	match dle_routine:
		0:
			s2_wfz_bg_x_offset = 0
			s2_wfz_bg_y_offset = 0
			s2_wfz_bg_y_speed = 0
			s2_wfz_bg_x_pos = screen_x
			s2_wfz_bg_y_pos = screen_y
			dle_routine = 2
		2:
			if screen_x >= 0x2BC0 and screen_y >= 0x580:
				dle_routine = 4
				s2_wfz_bg_y_speed = 0
		4:
			if s2_wfz_bg_x_offset < 0x800:
				s2_wfz_bg_x_offset += 2
			if s2_wfz_bg_x_offset >= 0x600:
				if s2_wfz_bg_y_speed < 0x840:
					s2_wfz_bg_y_speed = mini(0x840, s2_wfz_bg_y_speed + 4)
				s2_wfz_bg_y_offset += s2_wfz_bg_y_speed >> 8
		6:
			# ObjB2 switches Dynamic_Resize_Routine to 6 at getaway timer $460.
			if s2_wfz_bg_x_offset > -0x2C0:
				s2_wfz_bg_x_offset -= 2
			if s2_wfz_bg_y_offset != 0x1B81:
				if s2_wfz_bg_y_speed != 0:
					s2_wfz_bg_y_speed = maxi(0, s2_wfz_bg_y_speed - 4)
				s2_wfz_bg_y_offset += 1 + (s2_wfz_bg_y_speed >> 8)
				if s2_wfz_bg_y_offset > 0x1B81:
					s2_wfz_bg_y_offset = 0x1B81
	_step_s2_wfz_bg_to_target(screen_x - s2_wfz_bg_x_offset, screen_y - s2_wfz_bg_y_offset)
	match s2_wfz_event_subroutine:
		0:
			if screen_x >= 0x2880 and screen_y >= 0x400:
				s2_wfz_event_subroutine = 2
				limit_left = 0x2880
				# Retail Routine5 loads PLCID_WfzBoss here. The native C5 object is
				# allocated at this preload gate, then waits at $2B80 for Sonic.
				s2_wfz_boss_ready = true
		2:
			if screen_y >= 0x500:
				s2_wfz_event_subroutine = 4
				# Retail Routine6 locks logical control and loads the Tornado PLC.
				# The C5 adapter releases native control when the actual fight begins.
				if bool(definition.get("s2_wfz_boss_active", false)):
					player.control_locked = true

func _dle_s2_dez() -> void:
	# Retail LevEvents_DEZ. Routine 1 allocates Object $AF at CameraX $140.
	# Mecha Sonic advances the routine to 4 when its $FF defeat countdown ends.
	match dle_routine:
		0:
			if screen_x >= 0x140:
				dle_routine = 2
				s2_dez_mecha_spawn_requested = true
		2:
			pass
		4:
			limit_left = screen_x
			if screen_x >= 0x300:
				dle_routine = 6
		6:
			limit_left = screen_x
			if screen_x >= 0x680:
				dle_routine = 8
				limit_left = 0x680
				# Retail Routine4 clamps the Death Egg Robot arena to $680..$740.
				limit_right = 0x740
				s2_dez_final_boss_ready = true
		8:
			pass

func _dle_s2_mtz3() -> void:
	# Exact LevEvents_MTZ3 through the retail $5A ScreenShift gate. The source
	# then allocates Object $54 and starts boss music; main.gd performs that
	# cross-system handoff in Phase 125.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x2530:
				# Retail writes Camera_Max_Y_pos_now=$500 immediately, then eases
				# Camera_Max_Y_pos toward $450.
				current_bottom = 0x500
				target_bottom = 0x450
				dle_routine = 2
		2:
			target_bottom = 0x450
			if screen_x >= 0x2980:
				limit_left = screen_x
				target_bottom = 0x400
				dle_routine = 4
		4:
			target_bottom = 0x400
			limit_left = screen_x
			if screen_x >= 0x2A80:
				limit_left = 0x2AB0
				limit_right = 0x2AB0
				s2_mtz3_event_timer = 0
				s2_mtz3_music_fade_requested = true
				dle_routine = 6
		6:
			target_bottom = 0x400
			limit_left = 0x2AB0
			limit_right = 0x2AB0
			if screen_y >= 0x400:
				limit_top = 0x400
			s2_mtz3_event_timer += 1
			if s2_mtz3_event_timer >= 0x5A:
				s2_mtz3_boss_ready = true
				dle_routine = 8
		_:
			# Retail Routine5 follows Camera_X after Object $54 is spawned. main.gd
			# bridges Boss_defeated_flag/boss_screen_lock and the boss's $2BF0 Max-X.
			target_bottom = 0x400
			if screen_y >= 0x400:
				limit_top = 0x400


func _dle_s2_ooz2() -> void:
	# Exact retail LevEvents_OOZ2. Routine 0 moves the oil/camera boundary at
	# $2668. Routine 2 locks $2880..$28C0, fades music, loads Pal_OOZ_B and
	# clears ScreenShift. Routine 4 increments that byte for exactly $5A frames
	# before requesting Object $55; Routine 6 follows Camera_X after defeat.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x2668:
				limit_left = screen_x
				target_bottom = 0x1E0
				dle_routine = 2
		2:
			target_bottom = 0x1E0
			limit_left = screen_x
			if screen_x >= 0x2880:
				limit_left = 0x2880
				limit_right = 0x28C0
				s2_ooz2_event_timer = 0
				s2_ooz2_music_fade_requested = true
				s2_ooz2_boss_palette_requested = true
				dle_routine = 4
		4:
			target_bottom = 0x1E0
			limit_left = 0x2880
			limit_right = 0x28C0
			if screen_y >= 0x1D8:
				limit_top = 0x1D8
			s2_ooz2_event_timer += 1
			if s2_ooz2_event_timer >= 0x5A:
				s2_ooz2_boss_spawn_requested = true
				boss_triggered = true
				dle_routine = 6
		_:
			target_bottom = 0x1E0
			if screen_y >= 0x1D8:
				limit_top = 0x1D8
			# Retail Routine4 changes Camera_Min_X only after Boss_defeated_flag.
			# main.gd supplies that cross-system flag and keeps the pre-defeat lock.


func _dle_s2_mcz2() -> void:
	# Exact LevEvents_MCZ2 handoff: $2080 raises the lower boundary target,
	# $20F0 hard-locks the arena / fades music / loads Pal_MCZ_B, Routine3 then
	# waits ScreenShift=$5A before Object $57 is allocated and Boss music begins.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x2080:
				limit_left = screen_x
				target_bottom = 0x5D0
				dle_routine = 2
		2:
			target_bottom = 0x5D0
			limit_left = screen_x
			if screen_x >= 0x20F0:
				limit_left = 0x20F0
				limit_right = 0x20F0
				s2_mcz2_event_timer = 0
				s2_mcz2_music_fade_requested = true
				s2_mcz2_boss_palette_requested = true
				dle_routine = 4
		4:
			target_bottom = 0x5D0
			limit_left = 0x20F0
			limit_right = 0x20F0
			if screen_y >= 0x5C8:
				limit_top = 0x5C8
			s2_mcz2_event_timer += 1
			if s2_mcz2_event_timer >= 0x5A:
				s2_mcz2_boss_spawn_requested = true
				boss_triggered = true
				dle_routine = 6
		_:
			target_bottom = 0x5D0
			if screen_y >= 0x5C8:
				limit_top = 0x5C8
			# LevEvents_MCZ2_Routine4 continually follows Camera_X_pos after defeat.
			limit_left = screen_x


func _dle_s2_htz1() -> void:
	# Retail LevEvents_HTZ, Act 1. The earthquake corridor begins only after
	# CameraY >= $400 and CameraX >= $1800. Camera_BG_Y_offset then alternates
	# between $140 and $E0, changing one pixel every four frames with a $78-frame
	# pause whenever an endpoint is reached.
	target_bottom = base_bottom
	match dle_routine:
		0:
			if screen_y < 0x400 or screen_x < 0x1800:
				_reset_s2_htz_quake()
				return
			_start_s2_htz_quake()
			dle_routine = 2
		2:
			if screen_x < 0x1800:
				_reset_s2_htz_quake()
				dle_routine = 0
				return
			if screen_x >= 0x1F00:
				_reset_s2_htz_quake()
				dle_routine = 4
				return
			s2_htz_quake_active = true
			if screen_x >= 0x1E00:
				s2_htz_visual_shake = false
				return
			if screen_x < 0x1978:
				return

			var at_endpoint: bool = (s2_htz_terrain_direction == 0 and s2_htz_bg_y_offset >= 0x140) or (s2_htz_terrain_direction != 0 and s2_htz_bg_y_offset <= 0xE0)
			if at_endpoint:
				s2_htz_visual_shake = false
				s2_htz_terrain_delay -= 1
				if s2_htz_terrain_delay < 0:
					s2_htz_terrain_delay = 0x78
					s2_htz_terrain_direction ^= 1
					s2_htz_visual_shake = true
				return

			# Timer_frames & 3: terrain shifts only every fourth VBlank.
			s2_htz_frame_counter = (s2_htz_frame_counter + 1) & 0xFFFF
			if (s2_htz_frame_counter & 3) != 0:
				return
			if s2_htz_terrain_direction == 0:
				s2_htz_bg_y_offset = mini(0x140, s2_htz_bg_y_offset + 1)
			else:
				s2_htz_bg_y_offset = maxi(0xE0, s2_htz_bg_y_offset - 1)
		4:
			if screen_x < 0x1F00:
				_start_s2_htz_quake()
				dle_routine = 2


func _dle_s2_htz2() -> void:
	# Retail LevEvents_HTZ2. Routines 0-$08 are the earthquake traversal;
	# $0A-$10 are the exact boss-camera sequence. LevEvents_HTZ2_Prepare
	# forces routine $0A once CameraX reaches $2B00.
	if screen_x >= 0x2B00 and dle_routine < 0x0A:
		_reset_s2_htz_quake()
		dle_routine = 0x0A

	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x < 0x14C0:
				_reset_s2_htz_quake()
				return
			if screen_y >= 0x380:
				_start_s2_htz2_quake(0x300)
				dle_routine = 8
			else:
				_start_s2_htz2_quake(0x2C0)
				dle_routine = 2
		2:
			target_bottom = base_bottom
			if screen_x < 0x14C0:
				_reset_s2_htz_quake()
				dle_routine = 0
				return
			if screen_x >= 0x1B00:
				_reset_s2_htz_quake()
				dle_routine = 4
				return
			_tick_s2_htz2_quake_motion(0x2C0, 0x1678, 0x1A00)
		4:
			target_bottom = base_bottom
			if screen_x < 0x1B00:
				_start_s2_htz2_quake(0x2C0)
				dle_routine = 2
			else:
				_reset_s2_htz_quake()
		6:
			target_bottom = base_bottom
			if screen_x < 0x14C0:
				_reset_s2_htz_quake()
				dle_routine = 0
				return
			if screen_x >= 0x1B00:
				_reset_s2_htz_quake()
				dle_routine = 8
				return
			_tick_s2_htz2_quake_motion(0x300, 0x15F0, 0x1AC0)
		8:
			target_bottom = base_bottom
			if screen_x < 0x1B00:
				_start_s2_htz2_quake(0x300)
				dle_routine = 6
			else:
				_reset_s2_htz_quake()
		0x0A:
			target_bottom = 0x480
			if screen_x >= 0x2C50:
				limit_left = screen_x
				dle_routine = 0x0C
		0x0C:
			target_bottom = 0x480
			limit_left = screen_x
			if screen_x >= 0x2EDF:
				limit_left = 0x2EE0
				limit_right = 0x2F5E
				s2_htz2_event_timer = 0
				s2_htz2_music_fade_requested = true
				dle_routine = 0x0E
		0x0E:
			target_bottom = 0x480
			limit_left = 0x2EE0
			limit_right = 0x2F5E
			if screen_y >= 0x478:
				limit_top = 0x478
			s2_htz2_event_timer += 1
			if s2_htz2_event_timer >= 0x5A:
				s2_htz2_boss_spawn_requested = true
				boss_triggered = true
				dle_routine = 0x10
		0x10:
			if not s2_htz2_boss_defeated:
				target_bottom = 0x480
				return
			limit_left = screen_x
			if screen_x >= 0x30E0:
				if limit_top >= 0x428:
					limit_top -= 2
				if target_bottom >= 0x430:
					target_bottom -= 2
			else:
				target_bottom = 0x480
		_:
			target_bottom = base_bottom


func _start_s2_htz2_quake(max_offset: int) -> void:
	s2_htz_quake_active = true
	s2_htz_visual_shake = true
	s2_htz_bg_y_offset = max_offset
	s2_htz_terrain_direction = 0
	s2_htz_terrain_delay = 0


func _tick_s2_htz2_quake_motion(max_offset: int, motion_start_x: int, shake_stop_x: int) -> void:
	s2_htz_quake_active = true
	if screen_x >= shake_stop_x:
		s2_htz_visual_shake = false
	if screen_x < motion_start_x:
		return
	var at_endpoint: bool = (s2_htz_terrain_direction == 0 and s2_htz_bg_y_offset >= max_offset) or (s2_htz_terrain_direction != 0 and s2_htz_bg_y_offset <= 0)
	if at_endpoint:
		s2_htz_visual_shake = false
		s2_htz_terrain_delay -= 1
		if s2_htz_terrain_delay < 0:
			s2_htz_terrain_delay = 0x78
			s2_htz_terrain_direction ^= 1
			s2_htz_visual_shake = true
		return
	s2_htz_frame_counter = (s2_htz_frame_counter + 1) & 0xFFFF
	if (s2_htz_frame_counter & 3) != 0:
		return
	if s2_htz_terrain_direction == 0:
		s2_htz_bg_y_offset = mini(max_offset, s2_htz_bg_y_offset + 1)
	else:
		s2_htz_bg_y_offset = maxi(0, s2_htz_bg_y_offset - 1)


func _start_s2_htz_quake() -> void:
	s2_htz_quake_active = true
	s2_htz_visual_shake = true
	s2_htz_bg_y_offset = 0x140
	s2_htz_terrain_direction = 0
	s2_htz_terrain_delay = 0


func _reset_s2_htz_quake() -> void:
	s2_htz_quake_active = false
	s2_htz_visual_shake = false
	s2_htz_bg_y_offset = 0
	s2_htz_terrain_direction = 0
	s2_htz_terrain_delay = 0


func _dle_s2_ehz2() -> void:
	# Retail Sonic 2 LevEvents_EHZ2. Dynamic_Resize_Routine advances through
	# the entrance lock, arena lock/PLC+music fade, the $5A-frame ScreenShift
	# wait, then the post-defeat left-bound follow state.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x2780:
				limit_left = screen_x
				target_bottom = 0x390
				dle_routine = 1
		1:
			target_bottom = 0x390
			if screen_x >= 0x28F0:
				limit_left = 0x28F0
				limit_right = 0x2940
				s2_ehz2_event_timer = 0
				s2_ehz2_music_fade_requested = true
				dle_routine = 2
		2:
			target_bottom = 0x390
			if screen_y >= 0x388:
				limit_top = 0x388
			s2_ehz2_event_timer += 1
			if s2_ehz2_event_timer >= 0x5A:
				# Retail Routine3 calls SingleObjLoad and only advances when a slot
				# is available. Keep a durable request rather than relying on the
				# generic boss_triggered edge to be observed in the same frame.
				s2_ehz2_boss_spawn_requested = true
				boss_triggered = true
				dle_routine = 3
		_:
			target_bottom = 0x390
			# LevEvents_EHZ2_Routine4 sets Camera_Min_X_pos to Camera_X_pos after
			# Boss_defeated_flag. main.gd applies this once manager status changes.

func _dle_s2_cpz2() -> void:
	# Retail LevEvents_CPZ2. At $2680 the lower camera boundary tightens to
	# $450 and the left edge begins following the camera. $2A20 locks the
	# arena, fades music and begins the $5A-frame ScreenShift/PLC wait.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x2680:
				limit_left = screen_x
				target_bottom = 0x450
				dle_routine = 1
		1:
			target_bottom = 0x450
			limit_left = screen_x
			if screen_x >= 0x2A20:
				limit_left = 0x2A20
				limit_right = 0x2A20
				s2_cpz2_event_timer = 0
				s2_cpz2_music_fade_requested = true
				dle_routine = 2
		2:
			target_bottom = 0x450
			if screen_y >= 0x448:
				limit_top = 0x448
			s2_cpz2_event_timer += 1
			if s2_cpz2_event_timer >= 0x5A:
				s2_cpz2_boss_spawn_requested = true
				boss_triggered = true
				dle_routine = 3
		_:
			target_bottom = 0x450
			# Routine4 continuously advances Camera_Min_X_pos to Camera_X_pos.
			limit_left = screen_x

func _dle_s2_arz2() -> void:
	# Retail LevEvents_ARZ2. $2810 tightens the lower boundary and begins following
	# Camera_Min_X_pos. $2A40 locks both horizontal bounds, fades level music and
	# allocates Obj89 immediately. Routine3 then waits ScreenShift=$5A before Boss BGM.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x2810:
				limit_left = screen_x
				target_bottom = 0x400
				dle_routine = 1
		1:
			target_bottom = 0x400
			limit_left = screen_x
			if screen_x >= 0x2A40:
				limit_left = 0x2A40
				limit_right = 0x2A40
				s2_arz2_event_timer = 0
				s2_arz2_music_fade_requested = true
				s2_arz2_boss_spawn_requested = true
				boss_triggered = true
				dle_routine = 2
		2:
			target_bottom = 0x400
			if screen_y >= 0x3F8:
				limit_top = 0x3F8
			s2_arz2_event_timer += 1
			if s2_arz2_event_timer >= 0x5A:
				s2_arz2_boss_music_requested = true
				dle_routine = 3
		_:
			target_bottom = 0x400
			limit_left = screen_x


func _dle_s2_cnz2(player: SonicPlayer) -> void:
	# Retail LevEvents_CNZ2. The two $F9 writes alter the foreground chunk layout
	# immediately before/inside the boss arena; our imported layout is 128 bytes
	# wide, so source offsets $C54/$C50 map directly to row $C, columns $54/$50.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x27C0:
				limit_left = screen_x
				target_bottom = 0x62E
				if player != null and player.level != null:
					if player.level.set_chunk_id_at(0x54, 0x0C, 0xF9):
						s2_cnz2_refresh_c54_requested = true
				dle_routine = 1
		1:
			target_bottom = 0x62E
			limit_left = screen_x
			if screen_x >= 0x2890:
				if player != null and player.level != null:
					if player.level.set_chunk_id_at(0x50, 0x0C, 0xF9):
						s2_cnz2_refresh_c50_requested = true
				limit_left = 0x2860
				limit_right = 0x28E0
				s2_cnz2_event_timer = 0
				s2_cnz2_music_fade_requested = true
				s2_cnz2_boss_palette_requested = true
				dle_routine = 2
		2:
			target_bottom = 0x62E
			if screen_y >= 0x4E0:
				limit_top = 0x4E0
			s2_cnz2_event_timer += 1
			if s2_cnz2_event_timer >= 0x5A:
				s2_cnz2_boss_spawn_requested = true
				boss_triggered = true
				dle_routine = 3
		_:
			# Routine4 does not loosen the vertical limit until the camera has
			# actually crossed $2A00 on the post-boss route.
			target_bottom = 0x62E
			if screen_x >= 0x2A00:
				target_bottom = 0x5D0
				limit_left = screen_x

func _dle_fz() -> void:
	# DLE_FZ. From $2148 onward the left boundary follows the camera; at
	# $2300 Object $85 is created and f_lockscreen is set. The boss itself
	# releases the wait state after its defeat fall and opens toward $2700.
	target_bottom = 0x510
	match dle_routine:
		0:
			if screen_x >= BOSS_FZ_X - 0x308:
				dle_routine = 1
			limit_left = screen_x
		1:
			if screen_x >= BOSS_FZ_X - 0x150:
				boss_triggered = true
				dle_routine = 2
			limit_left = screen_x
		2:
			if screen_x >= BOSS_FZ_X:
				dle_routine = 3
			limit_left = screen_x
		3:
			pass
		_:
			limit_left = screen_x

func _dle_sbz1() -> void:
	# REV01 DLE_SBZ1: the lower camera boundary rises in two authored steps.
	target_bottom = 0x720
	if screen_x >= 0x2000:
		target_bottom = 0x2A0
	elif screen_x >= 0x1880:
		target_bottom = 0x620

func _dle_sbz2() -> void:
	# REV01 DLE_SBZ2. The routine first raises the lower boundary, then creates
	# Object $83 at $1EB0 and Object $82 at $1F60. From the Eggman trigger until
	# the camera reaches boss_sbz2_x ($2050), v_limitleft2 follows the camera.
	target_bottom = 0x510 if screen_x >= 0x1800 else 0x800
	match dle_routine:
		0:
			if screen_x >= 0x1E00:
				dle_routine = 1
		1:
			if screen_x >= 0x1EB0:
				sbz_false_floor_triggered = true
				dle_routine = 2
		2:
			if screen_x >= 0x1F60:
				sbz_eggman_triggered = true
				sbz2_screen_locked = true
				dle_routine = 3
			limit_left = screen_x
		_:
			if screen_x < 0x2050:
				limit_left = screen_x

func _dle_sbz3(player: SonicPlayer) -> void:
	# DLE_SBZ3: internal LZ4 exits to Final Zone only after the camera has
	# reached $D00 and Sonic climbs above Y $18. The level reload itself is
	# performed by main.gd, mirroring f_restart + id_FZ.
	target_bottom = base_bottom
	if screen_x >= 0xD00 and player.pixel_y() < 0x18:
		sbz3_exit_triggered = true

func _dle_slz3() -> void:
	# DLE_SLZ3 from the REV01 source. $1E70 tightens the lower boundary to
	# boss_slz_y ($210). At boss_slz_x ($2000), Object $7A is requested and
	# f_lockscreen is set. The final DLE state continuously advances the left
	# bound to the current screen position so Sonic cannot backtrack.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x >= 0x1E70:
				target_bottom = 0x210
				dle_routine = 1
		1:
			target_bottom = 0x210
			if screen_x >= 0x2000:
				boss_triggered = true
				dle_routine = 2
		2:
			target_bottom = 0x210
			limit_left = screen_x

func _dle_lz3() -> void:
	# DLE_LZ3: Object $77 loads when camera X >= boss_lz_x-$140 ($1CA0)
	# while camera Y is above boss_lz_y+$540 ($600). The layout mutation for
	# switch $F remains in SonicObjectManager where it can refresh collision/render.
	target_bottom = base_bottom
	if dle_routine != 0:
		return
	if screen_x < 0x1CA0 or screen_y >= 0x600:
		return
	boss_triggered = true
	dle_routine = 2

func _dle_syz3() -> void:
	# REV01 DLE_SYZ3. At $2AC0 the ten Object $76 arena blocks are created.
	# At boss_syz_x ($2C00), the lower boundary tightens to $4CC, horizontal
	# backtracking is locked, and Object $75 is requested.
	match dle_routine:
		0:
			target_bottom = base_bottom
			if screen_x < 0x2AC0:
				return
			boss_blocks_triggered = true
			dle_routine = 1
		1:
			target_bottom = base_bottom
			if screen_x < 0x2C00:
				return
			target_bottom = 0x4CC
			limit_left = screen_x
			boss_triggered = true
			dle_routine = 2
		_:
			target_bottom = 0x4CC
			limit_left = screen_x

func _dle_syz2(player: SonicPlayer) -> void:
	# REV01 DLE_SYZ2: near the late lower route the floor boundary depends on
	# Sonic's Y position. Act 1 has no dynamic boundary event.
	target_bottom = 0x520
	if screen_x >= 0x25A0 and player.pixel_y() < 0x4D0:
		target_bottom = 0x420

func _dle_ghz1() -> void:
	target_bottom = 0x400 if screen_x >= 0x1780 else 0x300

func _dle_ghz2() -> void:
	target_bottom = 0x300
	if screen_x >= 0x0ED0:
		target_bottom = 0x200
	if screen_x >= 0x1600:
		target_bottom = 0x400
	if screen_x >= 0x1D60:
		target_bottom = 0x300

func _dle_ghz3() -> void:
	# DLE_GHZ3_Main including the boss-area lockscreen trigger at boss_ghz_x ($2960).
	if dle_routine == 0:
		target_bottom = 0x300
		if screen_x < 0x380:
			return
		target_bottom = 0x310
		if screen_x < 0x960:
			return
		if screen_y < 0x280:
			target_bottom = 0x300
			dle_routine = 1
			return
		target_bottom = 0x400
		if screen_x < 0x1380:
			target_bottom = 0x4C0
			current_bottom = 0x4C0
			return
		if screen_x >= 0x1700:
			target_bottom = 0x300
			dle_routine = 1
		return
	if dle_routine == 1:
		if screen_x < 0x960:
			dle_routine = 0
			return
		target_bottom = 0x300
		# boss_ghz_x is $2960. Lock the left boundary and request Object $3D.
		if screen_x >= 0x2960:
			limit_left = screen_x
			boss_triggered = true
			dle_routine = 2
		return
	target_bottom = 0x300

func _dle_mz1() -> void:
	# Exact REV01 DLE_MZ1 route. The top boundary changes immediately except
	# for the routine-6 return path, which rises by 2px/frame in the original.
	match dle_routine:
		0:
			target_bottom = 0x1D0
			limit_top = 0
			if screen_x >= 0x700:
				target_bottom = 0x220
			if screen_x >= 0xD00:
				target_bottom = 0x340
			if screen_x >= 0xD00 and screen_y >= 0x340:
				dle_routine = 1
		1:
			if screen_y < 0x340:
				dle_routine = 0
				return
			limit_top = 0
			target_bottom = 0x340
			if screen_x < 0xE00:
				limit_top = 0x340
				if screen_x < 0xA90:
					target_bottom = 0x500
					if screen_y >= 0x370:
						dle_routine = 2
		2:
			if screen_y < 0x370:
				dle_routine = 1
				return
			target_bottom = 0x500
			if screen_y >= 0x500 and screen_x >= 0xB80:
				limit_top = 0x500
				dle_routine = 3
		3:
			target_bottom = 0x500
			if screen_x < 0xB80:
				if limit_top != 0x340:
					limit_top = maxi(0x340, limit_top - 2)
				return
			if limit_top != 0x500 and screen_y >= 0x500:
				limit_top = 0x500
			if screen_x >= 0xE70:
				limit_top = 0
				target_bottom = 0x500
			if screen_x >= 0x1430:
				target_bottom = 0x210

func _dle_mz2() -> void:
	target_bottom = 0x200 if screen_x >= 0x1700 else 0x520

func _dle_mz3() -> void:
	# DLE_MZ3_Boss: lower the arena floor at $1560, then request Object $73
	# when the camera reaches $17F0 and lock the screen for the fight.
	target_bottom = 0x720
	if screen_x >= 0x1560:
		target_bottom = 0x210
	if dle_routine == 0 and screen_x >= 0x17F0:
		# DLE_MZ3 triggers at $17F0, then DLE_MZ3_End locks v_limitleft2
		# on the following frame. With the source camera's 16px step the stable
		# arena screen is $1800; locking immediately at $17F0 shifted it left.
		screen_x = 0x1800
		limit_left = 0x1800
		limit_right = 0x1800
		boss_triggered = true
		dle_routine = 1

func _ease_bottom_boundary(player: SonicPlayer) -> void:
	bottom_boundary_moving = current_bottom != target_bottom
	if not bottom_boundary_moving:
		return
	if target_bottom < current_bottom:
		if screen_y > target_bottom:
			current_bottom = screen_y & ~1
		current_bottom = maxi(target_bottom, current_bottom - 2)
		return
	var step = 2
	if screen_y + 8 >= current_bottom and player.in_air:
		step = 8
	current_bottom = mini(target_bottom, current_bottom + step)

func state_text() -> String:
	var base := "camera:(%d,%d) shift:(%d,%d) look:$%02X bottom:$%03X->$%03X" % [
		screen_x, screen_y, shift_x, shift_y, look_shift & 0xFF, current_bottom, target_bottom
	]
	if dynamic_event == "s2_ehz2":
		base += " EHZ2dle:%d evt:%d req:%s" % [dle_routine, s2_ehz2_event_timer, str(s2_ehz2_boss_spawn_requested)]
	elif dynamic_event == "s2_cpz2":
		base += " CPZ2dle:%d evt:%d req:%s" % [dle_routine, s2_cpz2_event_timer, str(s2_cpz2_boss_spawn_requested)]
	elif dynamic_event == "s2_mtz3":
		base += " MTZ3dle:%d evt:%d ready:%s" % [dle_routine, s2_mtz3_event_timer, str(s2_mtz3_boss_ready)]
	return base
