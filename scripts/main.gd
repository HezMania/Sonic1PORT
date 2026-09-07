extends Node2D

@onready var background_renderer: GHZBackgroundRenderer = $GHZBackgroundRenderer
@onready var renderer: GHZRenderer = $GHZRenderer
@onready var object_manager: SonicObjectManager = $ObjectManager
@onready var camera: Camera2D = $Camera2D
@onready var collision_debug: CollisionDebug = $CollisionDebug
@onready var info_label: Label = $UI/Info
@onready var sonic_effects: SonicEffects = $SonicEffects
@onready var end_card: EndCardUI = $UI/EndCard
@onready var sonic_hud: SonicHUD = $UI/SonicHUD
@onready var game_over_ui: GameOverUI = $UI/GameOverUI
@onready var level_palette_fade: GenesisPaletteFade = $LevelPaletteFade
@onready var level_title_card: LevelTitleCardUI = $LevelTitleCard

var level: GHZLevelData
var collision: GenesisCollision
var sonic_camera = SonicCamera.new()
var level_art_animator = LevelArtAnimator.new()
var level_palette_cycler = LevelPaletteCycler.new()
var collision_debug_enabled := false
var sensor_debug_enabled := false
var debug_info_enabled := false
var current_zone := LevelCatalog.ZONE_GHZ
var current_act := 1
var ui_initialized := false
var _transitioning_level := false
var death_restart_timer := -1
var ending_controller: EndingSequenceController = null
var credits_controller: CreditsSequenceController = null
var startup_controller: StartupSequenceController = null
var special_stage_controller: SpecialStageController = null
var continue_controller: ContinueScreenController = null
var intro_demo_slot := 0
var game_paused := false
var _boss_music_active := false
var _tally_music_active := false
var _s2_boss_prelude_stopped := false
# Phase 89 Hotfix 2: main-loop watchdog for the EHZ2 boss prelude.  This is
# intentionally separate from SonicCamera's DLE byte so a camera-state stall
# cannot leave the player forever in a locked, empty arena.
var _s2_ehz2_boss_gate_timer := -1
var _s2_ehz2_boss_spawn_attempts := 0
var _s2_cpz2_boss_gate_timer := -1
var _s2_cpz2_boss_spawn_attempts := 0
var _s2_arz2_boss_spawn_attempts := 0
var _s2_cnz2_boss_gate_timer := -1
var _s2_cnz2_boss_spawn_attempts := 0
var _s2_htz2_boss_gate_timer := -1
var _s2_htz2_boss_spawn_attempts := 0
var _s2_mcz2_boss_gate_timer := -1
var _s2_mcz2_boss_spawn_attempts := 0
var _s2_ooz2_boss_gate_timer := -1
var _s2_ooz2_boss_spawn_attempts := 0
var _s2_mtz3_boss_gate_timer := -1
var _s2_mtz3_boss_spawn_attempts := 0

func get_player() -> Node2D:
	return Global.players[0] as Node2D

func refresh_level_chunk(chunk_x: int, chunk_y: int) -> void:
	renderer.refresh_chunk(chunk_x, chunk_y)

func _ready() -> void:
	var player = get_player() as SonicPlayer
	sonic_effects.setup(player)
	end_card.setup(object_manager)
	sonic_hud.setup(object_manager)
	level_title_card.setup(level_palette_fade, sonic_hud)
	ui_initialized = true
	_load_level(LevelCatalog.ZONE_GHZ, 1, false)
	_start_startup_sequence(false)

func _load_level(zone: int, act: int, preserve_progress: bool = true, definition_override: Dictionary = {}) -> void:
	if _transitioning_level:
		return
	_transitioning_level = true
	game_paused = false
	SonicAudio.set_music_paused(false)
	SonicAudio.set_speed_shoes_active(false)
	_boss_music_active = false
	_tally_music_active = false
	_s2_boss_prelude_stopped = false
	_s2_ehz2_boss_gate_timer = -1
	_s2_ehz2_boss_spawn_attempts = 0
	_s2_cpz2_boss_gate_timer = -1
	_s2_cpz2_boss_spawn_attempts = 0
	_s2_arz2_boss_spawn_attempts = 0
	_s2_cnz2_boss_gate_timer = -1
	_s2_cnz2_boss_spawn_attempts = 0
	_s2_htz2_boss_gate_timer = -1
	_s2_htz2_boss_spawn_attempts = 0
	_s2_mcz2_boss_gate_timer = -1
	_s2_mcz2_boss_spawn_attempts = 0
	_s2_ooz2_boss_gate_timer = -1
	_s2_ooz2_boss_spawn_attempts = 0
	_s2_mtz3_boss_gate_timer = -1
	_s2_mtz3_boss_spawn_attempts = 0
	death_restart_timer = -1
	if special_stage_controller != null and is_instance_valid(special_stage_controller):
		special_stage_controller.teardown()
		special_stage_controller.queue_free()
		special_stage_controller = null
	if continue_controller != null and is_instance_valid(continue_controller):
		continue_controller.teardown()
		continue_controller.queue_free()
		continue_controller = null
	var keep_credits: bool = bool(definition_override.get("_keep_credits_controller", false))
	var keep_startup: bool = bool(definition_override.get("_keep_startup_controller", false))
	if ending_controller != null and is_instance_valid(ending_controller):
		ending_controller.queue_free()
		ending_controller = null
		# Ending hides the normal gameplay HUD. A debug/normal level load that
		# leaves that mode must restore it; credits keeps its own overlay hidden.
		if sonic_hud != null:
			sonic_hud.visible = true
	if credits_controller != null and is_instance_valid(credits_controller) and not keep_credits:
		credits_controller.teardown()
		credits_controller.queue_free()
		credits_controller = null
	if startup_controller != null and is_instance_valid(startup_controller) and not keep_startup:
		startup_controller.teardown()
		startup_controller.queue_free()
		startup_controller = null
	var definition = definition_override.duplicate(true) if not definition_override.is_empty() else LevelCatalog.get_level(zone, act)
	definition.erase("_keep_credits_controller")
	definition.erase("_keep_startup_controller")
	var new_level = GHZLevelData.new()
	if not new_level.load_definition("res://data/s1", definition):
		info_label.visible = true
		info_label.text = "%s data failed validation. Check the Output panel." % String(definition["display_name"])
		_transitioning_level = false
		return

	var old_score = object_manager.score
	var old_lives = object_manager.lives
	if not preserve_progress:
		old_score = 0
		old_lives = 3

	current_zone = zone
	current_act = act
	level = new_level
	collision = GenesisCollision.new(level)

	background_renderer.setup(level)
	background_renderer.reset()
	renderer.build(level)
	level_art_animator.setup(level, renderer, background_renderer)
	var water_palette_node := get_node_or_null("LZWaterPaletteLayer/LZWaterPalette")
	level_palette_cycler.setup(level, renderer, background_renderer, object_manager, water_palette_node)
	collision_debug.setup(collision)
	collision_debug.enabled = collision_debug_enabled

	var player = get_player() as SonicPlayer
	player.setup(level, collision)
	object_manager.clear_checkpoint()
	if not object_manager.setup(collision, player, "res://data/s1", definition):
		info_label.visible = true
		info_label.text = "%s object-position data failed to load." % level.display_name()
		_transitioning_level = false
		return
	object_manager.score = old_score
	object_manager.lives = old_lives
	# CPZ2 water state is established by ObjectManager.setup. Re-apply the
	# palette split configuration at that point so the presentation layer and
	# the now-active water controller begin from the same level definition.
	if water_palette_node != null and water_palette_node.has_method("configure_for_level"):
		water_palette_node.call("configure_for_level", level)

	var backdrop_index: int = int(definition.get("backdrop_palette_index", 32))
	if backdrop_index >= 0 and backdrop_index < level.palette.size():
		RenderingServer.set_default_clear_color(level.palette[backdrop_index])

	sonic_camera.configure_level(definition)
	sonic_camera.initialize(player)
	sonic_camera.apply_to(camera)
	background_renderer.set_lz_water_surface(object_manager.water_surface_y if object_manager.water_enabled else -0x10000)
	background_renderer.update(sonic_camera)
	player.refresh_visual()
	object_manager.obj_pos_load(sonic_camera.screen_x, sonic_camera.screen_y)
	end_card.reset_for_level()
	game_over_ui.visible = false
	_update_info()
	_transitioning_level = false
	_play_level_music(zone, act, keep_credits)
	# Phase 58: Object $34 level title cards. Credits/startup demos skip this
	# overlay; regular game loads use Sonic 1's source art/configuration.
	if level_title_card != null and startup_controller == null and credits_controller == null and zone != LevelCatalog.ZONE_ENDING and not bool(definition.get("skip_title_card", false)):
		level_title_card.begin(zone, act, bool(definition.get("internal_sbz3", false)), zone == LevelCatalog.ZONE_SBZ and act == 3)

func _physics_process(_delta: float) -> void:
	if _transitioning_level:
		return

	# The Genesis pre-level sequence runs the title cards while the gameplay
	# loop is still blocked. Once the level palette has stepped in, gameplay
	# starts and Object $34 holds for one second before moving out.
	if level_title_card != null and level_title_card.active:
		level_title_card.tick()
		if level_title_card.blocking:
			_tick_level_art()
			_update_info()
			return

	if continue_controller != null and is_instance_valid(continue_controller):
		continue_controller.tick()
		if continue_controller.finished:
			_finish_continue_screen()
		return

	# PauseGame loops on VBlank without executing the active game-mode loop.
	# Freezing here therefore stops Sonic, objects, stage rotation, timers, camera,
	# results and Ending scripting together, without mutating their local state.
	if game_paused:
		return

	if special_stage_controller != null and is_instance_valid(special_stage_controller):
		_tick_special_stage_mode()
		return

	if startup_controller != null and is_instance_valid(startup_controller):
		if startup_controller.is_demo_active():
			if collision == null or Global.players.is_empty():
				return
			_tick_level_art()
			_tick_intro_demo(get_player() as SonicPlayer)
		else:
			startup_controller.tick_non_demo()
			if startup_controller.level_select_level_request.x >= 0:
				var request := startup_controller.level_select_level_request
				_start_level_from_level_select(request.x, request.y)
				return
			if startup_controller.level_select_special_request:
				_start_special_stage_from_level_select()
				return
			if startup_controller.start_game_requested:
				_start_new_game_from_title()
				return
			if startup_controller.demo_requested >= 0:
				_start_intro_demo(startup_controller.demo_requested)
				return
			if startup_controller.restart_requested:
				if startup_controller.demo_slot >= IntroDemoData.DEMOS.size():
					intro_demo_slot = 0
				_restart_startup_sequence()
				return
		return

	if collision == null or Global.players.is_empty():
		return

	if credits_controller != null and is_instance_valid(credits_controller):
		_tick_level_art()
		_tick_credits_mode(get_player() as SonicPlayer)
		return

	_tick_level_art()

	if game_over_ui.active:
		game_over_ui.tick()
		sonic_hud.tick()
		if game_over_ui.consume_finished():
			_finish_game_over_card()
		_update_info()
		return

	var player = get_player() as SonicPlayer
	# Sonic_ResetLevel waits one second after the death sprite has fallen below
	# the screen before restarting a level when lives remain. During this routine
	# Sonic is frozen in place while the rest of the level can continue ticking.
	if death_restart_timer >= 0:
		object_manager.execute_objects()
		_tick_level_palette()
		sonic_effects.tick()
		end_card.tick()
		sonic_hud.tick()
		player.refresh_visual()
		death_restart_timer -= 1
		if death_restart_timer <= 0:
			_complete_regular_death_restart()
		_update_info()
		return

	if current_zone == LevelCatalog.ZONE_ENDING:
		_tick_ending_mode(player)
		return

	var ghz_boss_act = current_zone == LevelCatalog.ZONE_GHZ and current_act == 3
	var mz_boss_act = current_zone == LevelCatalog.ZONE_MZ and current_act == 3
	var syz_boss_act = current_zone == LevelCatalog.ZONE_SYZ and current_act == 3
	var lz_boss_act = current_zone == LevelCatalog.ZONE_LZ and current_act == 3
	var slz_boss_act = current_zone == LevelCatalog.ZONE_SLZ and current_act == 3
	var sbz2_transition_act = current_zone == LevelCatalog.ZONE_SBZ and current_act == 2
	var fz_boss_act = current_zone == LevelCatalog.ZONE_SBZ and current_act == 3
	var s2_ehz2_boss_act = level != null and bool(level.definition.get("s2_ehz_boss", false))
	var s2_cpz2_boss_act = level != null and bool(level.definition.get("s2_cpz_boss", false))
	var s2_arz2_boss_act = level != null and bool(level.definition.get("s2_arz_boss", false))
	var s2_cnz2_boss_act = level != null and bool(level.definition.get("s2_cnz_boss", false))
	var s2_htz2_boss_act = level != null and bool(level.definition.get("s2_htz_boss", false))
	var s2_mcz2_boss_act = level != null and bool(level.definition.get("s2_mcz_boss", false))
	var s2_ooz2_boss_act = level != null and bool(level.definition.get("s2_ooz_boss", false))
	var s2_mtz3_foundation_act = level != null and bool(level.definition.get("s2_mtz3_foundation", false))
	var s2_mtz3_boss_act = level != null and bool(level.definition.get("s2_mtz_boss", false))
	var s2_wfz_boss_act = level != null and bool(level.definition.get("s2_wfz_boss", false))
	var s2_dez_act = level != null and bool(level.definition.get("s2_dez", false))
	var regular_boss_triggered = (ghz_boss_act or mz_boss_act or syz_boss_act or lz_boss_act or slz_boss_act) and sonic_camera.boss_triggered
	if regular_boss_triggered and not _boss_music_active and object_manager.boss_status < 1:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_BOSS)
	# Got_SBZ2_Boundary: after the tally, the ring-bonus element advances the
	# right camera boundary from $1E40 to $2100 at exactly 2 pixels per frame.
	if sbz2_transition_act and object_manager.sbz2_post_tally_boundary_started and sonic_camera.limit_right < 0x2100:
		sonic_camera.limit_right = mini(0x2100, sonic_camera.limit_right + 2)
	# ObjAF locks both horizontal camera boundaries at $224 when Mecha Sonic
	# leaves its wait routine. Keep that source-owned arena lock separate from the
	# later DEZ event routine, which reopens the level after the $FF defeat timer.
	if s2_dez_act and object_manager.boss_screen_lock:
		if object_manager.s2_dez_final_boss_active:
			sonic_camera.limit_left = 0x680
			sonic_camera.limit_right = 0x740
		elif object_manager.boss_status < 1:
			sonic_camera.limit_left = 0x224
			sonic_camera.limit_right = 0x224
	var boss_screen_locked = (((ghz_boss_act or mz_boss_act or syz_boss_act or slz_boss_act) and sonic_camera.boss_triggered and object_manager.boss_status < 1) or (lz_boss_act and sonic_camera.boss_triggered and object_manager.boss_screen_lock) or (fz_boss_act and sonic_camera.boss_triggered and object_manager.boss_screen_lock) or (s2_ehz2_boss_act and sonic_camera.dle_routine >= 1 and object_manager.boss_status < 1) or (s2_cpz2_boss_act and sonic_camera.dle_routine >= 1 and object_manager.boss_status < 1) or (s2_arz2_boss_act and sonic_camera.dle_routine >= 1 and object_manager.boss_status < 1) or (s2_cnz2_boss_act and sonic_camera.dle_routine >= 1 and object_manager.boss_status < 1) or (s2_htz2_boss_act and sonic_camera.dle_routine >= 0x0C and object_manager.boss_status < 1) or (s2_mcz2_boss_act and sonic_camera.dle_routine >= 4 and object_manager.boss_status < 1) or (s2_ooz2_boss_act and sonic_camera.dle_routine >= 4 and object_manager.boss_status < 1) or (s2_mtz3_boss_act and sonic_camera.dle_routine >= 6 and object_manager.boss_screen_lock) or (s2_wfz_boss_act and sonic_camera.s2_wfz_event_subroutine >= 4 and object_manager.boss_screen_lock) or (s2_dez_act and object_manager.boss_screen_lock and (object_manager.boss_status < 1 or object_manager.s2_dez_final_boss_active)) or (sbz2_transition_act and sonic_camera.sbz2_screen_locked)) and not object_manager.tally_finished and not object_manager.time_frozen
	player.set_runtime_level_bounds(sonic_camera.limit_left, sonic_camera.limit_right, boss_screen_locked)
	object_manager.update_lz_water(sonic_camera.screen_x)
	object_manager.apply_lz_water_features()
	player.simulate_tick()

	# Phase 85 Hotfix 1: keep the Sonic 2 bottom-death test at the level-loop
	# boundary rather than relying on SonicPlayer._apply_level_bounds(). Several
	# legitimate states (object-control overrides, scripted transitions, etc.) can
	# return from simulate_tick before the player-side boundary routine is reached.
	# Retail S2 compares Sonic Y against Camera_Max_Y_pos_now+$E0 every control
	# tick, so use the camera's live bottom boundary plus the dynamic viewport
	# height here. This makes bottomless death authoritative for all experimental
	# S2 levels without changing Sonic 1's established DLE/death path.
	if level != null and bool(level.definition.get("experimental_sonic2", false)) and not player.dead and not player.drowning and not player.debug_free_mode:
		var s2_bottom_death_y = sonic_camera.current_bottom + int(ProjectSettings.get_setting("display/window/size/viewport_height"))
		if player.pixel_y() > s2_bottom_death_y:
			player.kill()

	# Phase 85 Hotfix 2: Sonic 1 Sonic_LevelBound uses the live lower camera
	# boundary, not the decoded layout height. The FixBugs source takes the more
	# permissive of v_limitbtm2 (target) and v_limitbtm1 (current) while a DLE
	# boundary is moving, then adds the screen height. Crossing that line branches
	# to KillSonic, giving the normal death pose and -$700 launch arc. Keep this
	# authoritative check in the level loop so early-return player states cannot
	# bypass bottomless-pit death.
	if level != null and not bool(level.definition.get("experimental_sonic2", false)) and not player.dead and not player.drowning and not player.debug_free_mode:
		var s1_bottom_death_y = maxi(sonic_camera.target_bottom, sonic_camera.current_bottom) + int(ProjectSettings.get_setting("display/window/size/viewport_height"))
		if player.pixel_y() > s1_bottom_death_y:
			# Sonic 1's one exception is the late SBZ2 -> hidden LZ4/SBZ3 handoff.
			if sbz2_transition_act and player.pixel_x() >= 0x2000:
				object_manager.clear_checkpoint()
				_load_level(LevelCatalog.ZONE_LZ, 4, true)
				return
			player.kill()

	if level != null and bool(level.definition.get("s2_htz", false)):
		object_manager.htz_quake_active = sonic_camera.s2_htz_quake_active
		object_manager.htz_bg_y_offset = sonic_camera.s2_htz_bg_y_offset
	# SCZ objects execute before this frame's camera update, so expose the
	# current retail Tornado velocity that SwScrl_SCZ is using.
	if level != null and bool(level.definition.get("s2_scz", false)):
		object_manager.s2_scz_scroll_vx = sonic_camera.s2_scz_velocity_x
		object_manager.s2_scz_scroll_vy = sonic_camera.s2_scz_velocity_y
	else:
		object_manager.s2_scz_scroll_vx = 0
		object_manager.s2_scz_scroll_vy = 0
	# Phase 128: ObjBC ship thrust follows the source WFZ background-event offset.
	# Keep SonicCamera ownership here and expose only the values objects consume.
	if level != null and bool(level.definition.get("s2_wfz", false)):
		object_manager.s2_wfz_bg_x_offset = sonic_camera.s2_wfz_bg_x_offset
		object_manager.s2_wfz_bg_y_offset = sonic_camera.s2_wfz_bg_y_offset
		if object_manager.s2_wfz_getaway_active:
			sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 6)
	else:
		object_manager.s2_wfz_bg_x_offset = 0
		object_manager.s2_wfz_bg_y_offset = 0
	object_manager.execute_objects()
	# ObjAF defeat increments Dynamic_Resize_Routine from 2 to 4 and restores
	# Camera_Max_X=$1000. Bridge that cross-system write before this frame's
	# SonicCamera event update so the post-Mecha corridor opens immediately.
	if s2_dez_act and object_manager.s2_dez_mecha_defeated and sonic_camera.dle_routine < 4:
		sonic_camera.dle_routine = 4
		sonic_camera.limit_right = 0x1000
	# ObjC7 defeat writes Camera_Max_X_pos=$1000 before the forced-right ending
	# run. The camera event routine is already parked at state 8, so bridge the
	# object-owned Max-X write back into SonicCamera explicitly.
	if s2_dez_act and object_manager.boss_status >= 2:
		sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	if level != null and bool(level.definition.get("s2_wfz", false)) and object_manager.s2_wfz_layout_refresh_requested:
		# ObjC2 source writes $850/$950, which are Plane-A rows 8/9 in the
		# interleaved Level_Layout workspace. Rebuild only the twelve affected
		# foreground 128x128 cells so collision and art change on the same frame.
		for cy in [8, 9]:
			for cx in range(0x50, 0x56):
				renderer.refresh_chunk(cx, cy)
		object_manager.s2_wfz_layout_refresh_requested = false
	if level != null and bool(level.definition.get("s2_wfz", false)) and object_manager.s2_wfz_background_refresh_requested:
		background_renderer.refresh_s2_wfz_getaway_layout()
		object_manager.s2_wfz_background_refresh_requested = false
	if object_manager.requested_level_transition.x >= 0:
		var direct_destination:=object_manager.requested_level_transition
		_load_level(direct_destination.x,direct_destination.y,true)
		return
	_tick_level_palette()
	if (fz_boss_act or s2_dez_act) and object_manager.final_ending_requested:
		_start_ending_sequence()
		return
	sonic_effects.tick()
	end_card.tick()
	sonic_hud.tick()
	if ghz_boss_act:
		sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif mz_boss_act and sonic_camera.boss_triggered:
		if object_manager.boss_status < 1:
			# f_lockscreen freezes horizontal scrolling during the Marble boss.
			sonic_camera.limit_right = sonic_camera.screen_x
		else:
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif syz_boss_act and sonic_camera.boss_triggered:
		# SYZ stays at $2C00 until Eggman's escape routine expands the right
		# boundary toward boss_syz_end ($2D40).
		sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif lz_boss_act and sonic_camera.boss_triggered:
		# BLZ_Escape2 advances v_limitright2 toward boss_lz_end ($2030).
		sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif slz_boss_act and sonic_camera.boss_triggered:
		if object_manager.boss_status < 1:
			# DLE_SLZ3 sets f_lockscreen when Object $7A is loaded.
			sonic_camera.limit_right = sonic_camera.screen_x
		else:
			# BSLZ_Escape expands v_limitright2 by two pixels toward $2160.
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_ehz2_boss_act and sonic_camera.dle_routine >= 1:
		if object_manager.boss_status < 1:
			# LevEvents_EHZ2_Routine2 clamps the boss arena at $2940.
			sonic_camera.limit_right = mini(sonic_camera.limit_right, 0x2940)
		else:
			# Routine4 follows Camera_Min_X_pos while Obj56_FlyingOff expands the
			# right boundary two pixels per frame toward $2AB0.
			sonic_camera.limit_left = sonic_camera.screen_x
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_cpz2_boss_act and sonic_camera.dle_routine >= 1:
		if object_manager.boss_status < 1:
			# LevEvents_CPZ2_Routine2 locks both horizontal bounds at $2A20.
			if sonic_camera.dle_routine >= 2:
				sonic_camera.limit_left = 0x2A20
				sonic_camera.limit_right = 0x2A20
		else:
			# Obj5D_Main_C opens the right side toward $2C30 while Routine4
			# continually advances Camera_Min_X_pos to Camera_X_pos.
			sonic_camera.limit_left = sonic_camera.screen_x
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_arz2_boss_act and sonic_camera.dle_routine >= 1:
		if object_manager.boss_status < 1:
			if sonic_camera.dle_routine >= 2:
				sonic_camera.limit_left = 0x2A40
				sonic_camera.limit_right = 0x2A40
		else:
			sonic_camera.limit_left = sonic_camera.screen_x
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_cnz2_boss_act and sonic_camera.dle_routine >= 1:
		if object_manager.boss_status < 1:
			if sonic_camera.dle_routine >= 2:
				# LevEvents_CNZ2_Routine2 locks the authored arena to $2860..$28E0.
				sonic_camera.limit_left = 0x2860
				sonic_camera.limit_right = 0x28E0
		else:
			# Obj51's flight expands the right boundary toward $2B20. Routine4
			# begins following Camera_X after the player reaches $2A00.
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
			if sonic_camera.screen_x >= 0x2A00:
				sonic_camera.limit_left = sonic_camera.screen_x
	elif s2_htz2_boss_act and sonic_camera.dle_routine >= 0x0A:
		# LevEvents_HTZ2 Routines6-9. Before defeat Routine7/8 locks the
		# arena at $2EE0..$2F5E; afterward Obj52 expands the right boundary
		# toward $3160 while Routine9 follows Camera_X on the left.
		sonic_camera.s2_htz2_boss_defeated = object_manager.boss_status >= 1
		if object_manager.boss_status < 1:
			if sonic_camera.dle_routine >= 0x0E:
				sonic_camera.limit_left = 0x2EE0
				sonic_camera.limit_right = 0x2F5E
		else:
			sonic_camera.limit_left = sonic_camera.screen_x
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_mcz2_boss_act and sonic_camera.dle_routine >= 4:
		if object_manager.boss_status < 1:
			# LevEvents_MCZ2 Routine2/3 hard-locks both sides at $20F0.
			sonic_camera.limit_left = 0x20F0
			sonic_camera.limit_right = 0x20F0
		else:
			# Routine4 tracks Camera_X_pos while Obj57 escape opens Max_X to $2240.
			sonic_camera.limit_left = sonic_camera.screen_x
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_ooz2_boss_act and sonic_camera.dle_routine >= 4:
		if object_manager.boss_status < 1:
			# LevEvents_OOZ2 Routine2/3 locks the authored arena at $2880..$28C0.
			sonic_camera.limit_left = 0x2880
			sonic_camera.limit_right = 0x28C0
		else:
			# Routine4 follows Camera_X while Object $55 opens Max_X toward $2A20.
			sonic_camera.limit_left = sonic_camera.screen_x
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_mtz3_boss_act and sonic_camera.dle_routine >= 6:
		if object_manager.boss_screen_lock:
			# LevEvents_MTZ3 Routine3/4 holds the arena at $2AB0 through the fight.
			sonic_camera.limit_left = 0x2AB0
			sonic_camera.limit_right = 0x2AB0
		else:
			# Routine5 follows Camera_X while Obj54_MainSub12 opens Max_X to $2BF0.
			sonic_camera.limit_left = sonic_camera.screen_x
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
	elif s2_wfz_boss_act and sonic_camera.s2_wfz_event_subroutine >= 2:
		# LevEvents_WFZ secondary routine locks Camera_Min_X at $2880 on the
		# approach. Object $C5 owns the fight; after defeat the exit Tornado
		# continues right and the lower camera boundary returns to $720.
		if object_manager.boss_status < 1:
			sonic_camera.limit_left = 0x2880
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
			if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
				sonic_camera.current_bottom = 0x442
				sonic_camera.target_bottom = 0x442
		else:
			# Do not ratchet Camera_Min_X forward after the boss. Runtime testing
			# found that doing so traps Sonic at the hidden 1-up and later crops the
			# source grab-on-ship pose. Retail leaves enough room for the getaway
			# camera to follow both directions through the former arena.
			sonic_camera.limit_left = 0x2880
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
			sonic_camera.current_bottom = 0x720
			sonic_camera.target_bottom = 0x720
	elif fz_boss_act and sonic_camera.boss_triggered:
		if object_manager.fz_end_scroll_started:
			sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 4)
			sonic_camera.limit_right = maxi(sonic_camera.limit_right, object_manager.boss_limit_right)
		elif sonic_camera.dle_routine >= 3:
			# f_lockscreen holds the arena once DLE_FZ_Arena reaches $2450.
			sonic_camera.limit_right = sonic_camera.screen_x
	if s2_wfz_boss_act and object_manager.s2_wfz_rivet_busted and object_manager.boss_status < 1:
		sonic_camera.limit_left = 0x2880
	sonic_camera.update(player)
	_tick_s2_dez_mecha_start(s2_dez_act)
	if level != null and bool(level.definition.get("s2_htz", false)):
		object_manager.htz_quake_active = sonic_camera.s2_htz_quake_active
		object_manager.htz_bg_y_offset = sonic_camera.s2_htz_bg_y_offset
	if s2_cnz2_boss_act and sonic_camera.s2_cnz2_refresh_c54_requested:
		refresh_level_chunk(0x54, 0x0C)
		sonic_camera.s2_cnz2_refresh_c54_requested = false
	if s2_cnz2_boss_act and sonic_camera.s2_cnz2_refresh_c50_requested:
		refresh_level_chunk(0x50, 0x0C)
		sonic_camera.s2_cnz2_refresh_c50_requested = false
	if s2_cnz2_boss_act and object_manager.cnz_boss_exit_refresh_requested:
		refresh_level_chunk(0x54, 0x0C)
		object_manager.cnz_boss_exit_refresh_requested = false
	# LevEvents_EHZ2_Routine2 issues MusID_FadeOut when the arena locks.
	if s2_ehz2_boss_act and sonic_camera.s2_ehz2_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	# Phase 89 Hotfix 2: make the boss prelude authoritative in the main level
	# loop.  The camera still reproduces LevEvents_EHZ2, but boss creation no
	# longer depends on that helper reaching one particular routine value.
	_tick_s2_ehz2_boss_start(player, s2_ehz2_boss_act)
	# LevEvents_CPZ2_Routine2 issues the same music fade before its $5A wait.
	if s2_cpz2_boss_act and sonic_camera.s2_cpz2_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	_tick_s2_cpz2_boss_start(player, s2_cpz2_boss_act)
	if s2_arz2_boss_act and sonic_camera.s2_arz2_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	_tick_s2_arz2_boss_start(player, s2_arz2_boss_act)
	if s2_cnz2_boss_act and sonic_camera.s2_cnz2_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	if s2_cnz2_boss_act and sonic_camera.s2_cnz2_boss_palette_requested:
		level_palette_cycler.activate_s2_cnz_boss_palette()
	_tick_s2_cnz2_boss_start(player, s2_cnz2_boss_act)
	if s2_htz2_boss_act and sonic_camera.s2_htz2_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	_tick_s2_htz2_boss_start(player, s2_htz2_boss_act)
	if s2_mcz2_boss_act and sonic_camera.s2_mcz2_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	if s2_mcz2_boss_act and sonic_camera.s2_mcz2_boss_palette_requested:
		level_palette_cycler.activate_s2_mcz_boss_palette()
	_tick_s2_mcz2_boss_start(player, s2_mcz2_boss_act)
	if s2_ooz2_boss_act and sonic_camera.s2_ooz2_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	if s2_ooz2_boss_act and sonic_camera.s2_ooz2_boss_palette_requested:
		level_palette_cycler.activate_s2_ooz_boss_palette()
	_tick_s2_ooz2_boss_start(player, s2_ooz2_boss_act)
	# LevEvents_MTZ3 fades music at the $2AB0 lock, waits ScreenShift=$5A, then
	# allocates Object $54 and starts boss music.
	if s2_mtz3_boss_act and sonic_camera.s2_mtz3_music_fade_requested and not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	_tick_s2_mtz3_boss_start(player, s2_mtz3_boss_act)
	_tick_s2_wfz_boss_start(player, s2_wfz_boss_act)
	if sbz2_transition_act:
		if sonic_camera.sbz_false_floor_triggered:
			object_manager.spawn_sbz_false_floor()
		if sonic_camera.sbz_eggman_triggered:
			object_manager.spawn_sbz_eggman()
	if current_zone == LevelCatalog.ZONE_LZ and current_act == 4 and sonic_camera.sbz3_exit_triggered:
		_load_level(LevelCatalog.ZONE_SBZ, 3, true)
		return
	if ghz_boss_act and sonic_camera.boss_triggered:
		object_manager.spawn_ghz_boss()
	elif mz_boss_act and sonic_camera.boss_triggered:
		object_manager.spawn_mz_boss()
	elif syz_boss_act:
		if sonic_camera.boss_blocks_triggered:
			object_manager.spawn_syz_boss_blocks()
		if sonic_camera.boss_triggered:
			object_manager.spawn_syz_boss()
	elif lz_boss_act and sonic_camera.boss_triggered:
		object_manager.spawn_lz_boss()
	elif slz_boss_act and sonic_camera.boss_triggered:
		object_manager.spawn_slz_boss()
	elif fz_boss_act and sonic_camera.boss_triggered:
		object_manager.spawn_fz_boss()
	# SwScrl_MCZ uses Screen_Shaking_Flag to offset the foreground/background
	# camera copies through SwScrl_RippleData. Drive Camera2D.offset from the
	# active Object $57 flag so Sonic, terrain and Plane B shake together.
	sonic_camera.s2_mcz_screen_shake_active = false
	if s2_mcz2_boss_act and object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		sonic_camera.s2_mcz_screen_shake_active = bool(object_manager.boss_object.get("rumble_active"))
		sonic_camera.s2_mcz_screen_shake_phase = object_manager.elapsed_frames & 0x3F
	sonic_camera.apply_to(camera)
	background_renderer.set_lz_water_surface(object_manager.water_surface_y if object_manager.water_enabled else -0x10000)
	background_renderer.update(sonic_camera)
	if player.dead and player.pixel_y() > sonic_camera.screen_y + 0x100:
		_begin_death_restart()
		return
	player.refresh_visual()
	object_manager.obj_pos_load(sonic_camera.screen_x, sonic_camera.screen_y)

	if object_manager.act_complete and not _tally_music_active and not fz_boss_act:
		_tally_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_END_LEVEL if current_zone == LevelCatalog.ZONE_S2_TEST or current_zone == LevelCatalog.ZONE_S2_CPZ_TEST or current_zone == LevelCatalog.ZONE_S2_ARZ_TEST or current_zone == LevelCatalog.ZONE_S2_CNZ_TEST or current_zone == LevelCatalog.ZONE_S2_HTZ_TEST or current_zone == LevelCatalog.ZONE_S2_MCZ_TEST or current_zone == LevelCatalog.ZONE_S2_OOZ_TEST or current_zone == LevelCatalog.ZONE_S2_MTZ_TEST or current_zone == LevelCatalog.ZONE_S2_SCZ_TEST or current_zone == LevelCatalog.ZONE_S2_WFZ_TEST or current_zone == LevelCatalog.ZONE_S2_DEZ_TEST else SonicAudio.MUS_GOT_THROUGH, true)

	# Object $3A/LevelOrder handoff. GHZ1 -> GHZ2 -> GHZ3 now happens without
	# rebuilding the scene or changing hard-coded resource paths.
	if object_manager.tally_finished:
		# Got_ChkSS: f_bigring is tested only after Object $3A has completed
		# its move-in, wait, bonus tally, and post-tally wait. Entering the
		# giant ring therefore never skips the results card.
		if object_manager.big_ring_collected:
			_start_special_stage(false)
			return
		if sbz2_transition_act:
			# SBZ2 is the one act whose result card does not immediately LevelOrder
			# into another level. It opens the post-tally Eggman/floor corridor.
			object_manager.begin_sbz2_post_tally()
		else:
			var next = LevelCatalog.next_level(current_zone, current_act)
			_load_level(next.x, next.y, true)
			return
	_update_info()


func _tick_s2_ehz2_boss_start(player: SonicPlayer, active: bool) -> void:
	# Retail trigger: once Camera_X_pos reaches $28F0, Routine2 locks the arena,
	# fades the music, then Routine3 waits ScreenShift=$5A before SingleObjLoad.
	# Phase 89's camera translation could visibly enter the arena while the
	# cross-system DLE routine failed to reach the allocation point.  Use the
	# level definition plus observable arena state as the authority here.
	if not active:
		_s2_ehz2_boss_gate_timer = -1
		_s2_ehz2_boss_spawn_attempts = 0
		return
	if object_manager.boss_status >= 1:
		return
	if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		return

	var arena_ready = (
		sonic_camera.s2_ehz2_music_fade_requested
		or sonic_camera.dle_routine >= 2
		or sonic_camera.screen_x >= 0x28F0
		or player.pixel_x() >= 0x2990
	)
	if not arena_ready:
		return

	# If the translated camera DLE stalled in Routine1, recover to the exact
	# Routine2 lock values before counting the source $5A-frame ScreenShift.
	if sonic_camera.dle_routine < 2:
		sonic_camera.limit_left = 0x28F0
		sonic_camera.limit_right = 0x2940
		sonic_camera.target_bottom = 0x390
		sonic_camera.s2_ehz2_music_fade_requested = true
		sonic_camera.dle_routine = 2

	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()

	if _s2_ehz2_boss_gate_timer < 0:
		_s2_ehz2_boss_gate_timer = maxi(0, sonic_camera.s2_ehz2_event_timer)
	else:
		_s2_ehz2_boss_gate_timer = maxi(_s2_ehz2_boss_gate_timer, sonic_camera.s2_ehz2_event_timer)

	if _s2_ehz2_boss_gate_timer < 0x5A:
		_s2_ehz2_boss_gate_timer += 1
		sonic_camera.s2_ehz2_event_timer = maxi(sonic_camera.s2_ehz2_event_timer, _s2_ehz2_boss_gate_timer)
	if _s2_ehz2_boss_gate_timer < 0x5A:
		return

	# Keep the allocation request asserted and retry every frame until the boss
	# node is actually present.  The object manager itself is definition-gated,
	# mirroring the source SingleObjLoad retry semantics without relying on the
	# outer current_zone/current_act bookkeeping.
	sonic_camera.s2_ehz2_boss_spawn_requested = true
	sonic_camera.boss_triggered = true
	sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 3)
	_s2_ehz2_boss_spawn_attempts += 1
	if not object_manager.spawn_s2_ehz_boss():
		return
	sonic_camera.s2_ehz2_boss_spawn_requested = false
	if not _boss_music_active:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)


func _tick_s2_cpz2_boss_start(player: SonicPlayer, active: bool) -> void:
	# Retail trigger: $2A20 locks the arena, fades CPZ music, then waits
	# ScreenShift=$5A before allocating Object $5D and starting Boss music.
	# As with EHZ2, keep the level loop authoritative so a DLE handoff cannot
	# strand Sonic in a correctly locked but empty arena.
	if not active:
		_s2_cpz2_boss_gate_timer = -1
		_s2_cpz2_boss_spawn_attempts = 0
		return
	if object_manager.boss_status >= 1:
		return
	if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		return

	var arena_ready = (
		sonic_camera.s2_cpz2_music_fade_requested
		or sonic_camera.dle_routine >= 2
		or sonic_camera.screen_x >= 0x2A20
		or player.pixel_x() >= 0x2AC0
	)
	if not arena_ready:
		return

	if sonic_camera.dle_routine < 2:
		sonic_camera.limit_left = 0x2A20
		sonic_camera.limit_right = 0x2A20
		sonic_camera.target_bottom = 0x450
		sonic_camera.s2_cpz2_music_fade_requested = true
		sonic_camera.dle_routine = 2

	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()

	if _s2_cpz2_boss_gate_timer < 0:
		_s2_cpz2_boss_gate_timer = maxi(0, sonic_camera.s2_cpz2_event_timer)
	else:
		_s2_cpz2_boss_gate_timer = maxi(_s2_cpz2_boss_gate_timer, sonic_camera.s2_cpz2_event_timer)
	if _s2_cpz2_boss_gate_timer < 0x5A:
		_s2_cpz2_boss_gate_timer += 1
		sonic_camera.s2_cpz2_event_timer = maxi(sonic_camera.s2_cpz2_event_timer, _s2_cpz2_boss_gate_timer)
	if _s2_cpz2_boss_gate_timer < 0x5A:
		return

	sonic_camera.s2_cpz2_boss_spawn_requested = true
	sonic_camera.boss_triggered = true
	sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 3)
	_s2_cpz2_boss_spawn_attempts += 1
	if not object_manager.spawn_s2_cpz_boss():
		return
	sonic_camera.s2_cpz2_boss_spawn_requested = false
	if not _boss_music_active:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)


func _tick_s2_arz2_boss_start(player: SonicPlayer, active: bool) -> void:
	# Unlike EHZ2/CPZ2, retail ARZ2 allocates Obj89 immediately at the $2A40 lock,
	# then waits $5A frames before starting boss music. Keep allocation durable.
	if not active:
		_s2_arz2_boss_spawn_attempts = 0
		return
	if object_manager.boss_status >= 1:
		return
	var arena_ready: bool = (
		sonic_camera.s2_arz2_music_fade_requested
		or sonic_camera.dle_routine >= 2
		or sonic_camera.screen_x >= 0x2A40
		or player.pixel_x() >= 0x2AE0
	)
	if not arena_ready:
		return
	if sonic_camera.dle_routine < 2:
		sonic_camera.limit_left = 0x2A40
		sonic_camera.limit_right = 0x2A40
		sonic_camera.target_bottom = 0x400
		sonic_camera.s2_arz2_music_fade_requested = true
		sonic_camera.s2_arz2_boss_spawn_requested = true
		sonic_camera.boss_triggered = true
		sonic_camera.dle_routine = 2
	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()
	var boss_present: bool = object_manager.boss_object != null and is_instance_valid(object_manager.boss_object)
	if not boss_present:
		_s2_arz2_boss_spawn_attempts += 1
		if object_manager.spawn_s2_arz_boss():
			sonic_camera.s2_arz2_boss_spawn_requested = false
			boss_present = true
	if boss_present and sonic_camera.s2_arz2_boss_music_requested and not _boss_music_active:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)


func _tick_s2_cnz2_boss_start(player: SonicPlayer, active: bool) -> void:
	# Retail CNZ2 fades the level song / loads Pal_CNZ_B at $2890, waits exactly
	# ScreenShift=$5A, then SingleObjLoad creates Object $51 and Boss music starts.
	if not active:
		_s2_cnz2_boss_gate_timer = -1
		_s2_cnz2_boss_spawn_attempts = 0
		return
	if object_manager.boss_status >= 1:
		return
	if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		return

	var arena_ready: bool = (
		sonic_camera.s2_cnz2_music_fade_requested
		or sonic_camera.dle_routine >= 2
		or sonic_camera.screen_x >= 0x2890
		or player.pixel_x() >= 0x2930
	)
	if not arena_ready:
		return
	if sonic_camera.dle_routine < 2:
		sonic_camera.limit_left = 0x2860
		sonic_camera.limit_right = 0x28E0
		sonic_camera.target_bottom = 0x62E
		sonic_camera.s2_cnz2_music_fade_requested = true
		sonic_camera.s2_cnz2_boss_palette_requested = true
		sonic_camera.dle_routine = 2
	if sonic_camera.s2_cnz2_boss_palette_requested:
		level_palette_cycler.activate_s2_cnz_boss_palette()
	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()

	if _s2_cnz2_boss_gate_timer < 0:
		_s2_cnz2_boss_gate_timer = maxi(0, sonic_camera.s2_cnz2_event_timer)
	else:
		_s2_cnz2_boss_gate_timer = maxi(_s2_cnz2_boss_gate_timer, sonic_camera.s2_cnz2_event_timer)
	if _s2_cnz2_boss_gate_timer < 0x5A:
		_s2_cnz2_boss_gate_timer += 1
		sonic_camera.s2_cnz2_event_timer = maxi(sonic_camera.s2_cnz2_event_timer, _s2_cnz2_boss_gate_timer)
	if _s2_cnz2_boss_gate_timer < 0x5A:
		return

	sonic_camera.s2_cnz2_boss_spawn_requested = true
	sonic_camera.boss_triggered = true
	sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 3)
	_s2_cnz2_boss_spawn_attempts += 1
	if not object_manager.spawn_s2_cnz_boss():
		return
	sonic_camera.s2_cnz2_boss_spawn_requested = false
	if not _boss_music_active:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)


func _tick_s2_htz2_boss_start(player: SonicPlayer, active: bool) -> void:
	# Retail HTZ2 Routine7 locks $2EE0..$2F5E/fades music, then Routine8
	# increments ScreenShift for exactly $5A frames before SingleObjLoad Obj52.
	if not active:
		_s2_htz2_boss_gate_timer = -1
		_s2_htz2_boss_spawn_attempts = 0
		return
	if object_manager.boss_status >= 1:
		return
	if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		return

	var arena_ready: bool = (
		sonic_camera.s2_htz2_music_fade_requested
		or sonic_camera.dle_routine >= 0x0E
		or sonic_camera.screen_x >= 0x2EDF
		or player.pixel_x() >= 0x2F40
	)
	if not arena_ready:
		return
	# Recovery path uses the exact retail Routine7/8 arena values.
	if sonic_camera.dle_routine < 0x0E:
		sonic_camera.limit_left = 0x2EE0
		sonic_camera.limit_right = 0x2F5E
		sonic_camera.target_bottom = 0x480
		sonic_camera.s2_htz2_music_fade_requested = true
		sonic_camera.s2_htz2_event_timer = 0
		sonic_camera.dle_routine = 0x0E

	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()

	# The camera DLE itself is the source ScreenShift clock. Do not increment a
	# second watchdog counter here or the retail $5A wait would run twice as fast.
	_s2_htz2_boss_gate_timer = sonic_camera.s2_htz2_event_timer
	if _s2_htz2_boss_gate_timer < 0x5A:
		return

	sonic_camera.s2_htz2_boss_spawn_requested = true
	sonic_camera.boss_triggered = true
	sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 0x10)
	_s2_htz2_boss_spawn_attempts += 1
	if not object_manager.spawn_s2_htz_boss():
		return
	sonic_camera.s2_htz2_boss_spawn_requested = false
	if not _boss_music_active:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)


func _tick_s2_mcz2_boss_start(player: SonicPlayer, active: bool) -> void:
	# Retail MCZ2 locks at $20F0, loads Pal_MCZ_B and waits exactly $5A frames
	# before SingleObjLoad Object $57. Keep a main-loop recovery path so a camera
	# state handoff can never strand Sonic inside a locked but empty arena.
	if not active:
		_s2_mcz2_boss_gate_timer = -1
		_s2_mcz2_boss_spawn_attempts = 0
		return
	if object_manager.boss_status >= 1:
		return
	if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		return

	var arena_ready: bool = (
		sonic_camera.s2_mcz2_music_fade_requested
		or sonic_camera.dle_routine >= 4
		or sonic_camera.screen_x >= 0x20F0
		or player.pixel_x() >= 0x2190
	)
	if not arena_ready:
		return

	if sonic_camera.dle_routine < 4:
		sonic_camera.limit_left = 0x20F0
		sonic_camera.limit_right = 0x20F0
		sonic_camera.target_bottom = 0x5D0
		sonic_camera.s2_mcz2_music_fade_requested = true
		sonic_camera.s2_mcz2_boss_palette_requested = true
		sonic_camera.s2_mcz2_event_timer = 0
		sonic_camera.dle_routine = 4

	if sonic_camera.s2_mcz2_boss_palette_requested:
		level_palette_cycler.activate_s2_mcz_boss_palette()
	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()

	# Camera Routine3 owns the source ScreenShift byte. Synchronize to it rather
	# than running a second clock, but recover if the camera update was skipped.
	if _s2_mcz2_boss_gate_timer < 0:
		_s2_mcz2_boss_gate_timer = maxi(0, sonic_camera.s2_mcz2_event_timer)
	else:
		_s2_mcz2_boss_gate_timer = maxi(_s2_mcz2_boss_gate_timer, sonic_camera.s2_mcz2_event_timer)
	if sonic_camera.dle_routine == 4 and _s2_mcz2_boss_gate_timer < 0x5A:
		return
	if _s2_mcz2_boss_gate_timer < 0x5A:
		_s2_mcz2_boss_gate_timer += 1
		sonic_camera.s2_mcz2_event_timer = maxi(sonic_camera.s2_mcz2_event_timer, _s2_mcz2_boss_gate_timer)
	if _s2_mcz2_boss_gate_timer < 0x5A:
		return

	sonic_camera.s2_mcz2_boss_spawn_requested = true
	sonic_camera.boss_triggered = true
	sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 6)
	_s2_mcz2_boss_spawn_attempts += 1
	if not object_manager.spawn_s2_mcz_boss():
		return
	sonic_camera.s2_mcz2_boss_spawn_requested = false
	if not _boss_music_active:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)


func _tick_s2_ooz2_boss_start(player: SonicPlayer, active: bool) -> void:
	# Retail OOZ2 loads Pal_OOZ_B and waits ScreenShift=$5A before allocating
	# Object $55. As with the other S2 boss ports, retain a main-loop watchdog so
	# the cross-system camera/object handoff cannot strand Sonic in an empty arena.
	if not active:
		_s2_ooz2_boss_gate_timer = -1
		_s2_ooz2_boss_spawn_attempts = 0
		return
	if object_manager.boss_status >= 1:
		return
	if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		return

	var arena_ready: bool = (
		sonic_camera.s2_ooz2_music_fade_requested
		or sonic_camera.dle_routine >= 4
		or sonic_camera.screen_x >= 0x2880
		or player.pixel_x() >= 0x2940
	)
	if not arena_ready:
		return
	if sonic_camera.dle_routine < 4:
		sonic_camera.limit_left = 0x2880
		sonic_camera.limit_right = 0x28C0
		sonic_camera.target_bottom = 0x1E0
		sonic_camera.s2_ooz2_music_fade_requested = true
		sonic_camera.s2_ooz2_boss_palette_requested = true
		sonic_camera.s2_ooz2_event_timer = 0
		sonic_camera.dle_routine = 4
	if sonic_camera.s2_ooz2_boss_palette_requested:
		level_palette_cycler.activate_s2_ooz_boss_palette()
	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped = true
		SonicAudio.stop_music()

	if _s2_ooz2_boss_gate_timer < 0:
		_s2_ooz2_boss_gate_timer = maxi(0, sonic_camera.s2_ooz2_event_timer)
	else:
		_s2_ooz2_boss_gate_timer = maxi(_s2_ooz2_boss_gate_timer, sonic_camera.s2_ooz2_event_timer)
	if sonic_camera.dle_routine == 4 and _s2_ooz2_boss_gate_timer < 0x5A:
		return
	if _s2_ooz2_boss_gate_timer < 0x5A:
		_s2_ooz2_boss_gate_timer += 1
		sonic_camera.s2_ooz2_event_timer = maxi(sonic_camera.s2_ooz2_event_timer, _s2_ooz2_boss_gate_timer)
	if _s2_ooz2_boss_gate_timer < 0x5A:
		return

	sonic_camera.s2_ooz2_boss_spawn_requested = true
	sonic_camera.boss_triggered = true
	sonic_camera.dle_routine = maxi(sonic_camera.dle_routine, 6)
	_s2_ooz2_boss_spawn_attempts += 1
	if not object_manager.spawn_s2_ooz_boss():
		return
	sonic_camera.s2_ooz2_boss_spawn_requested = false
	if not _boss_music_active:
		_boss_music_active = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)



func _tick_s2_mtz3_boss_start(player: SonicPlayer, active: bool) -> void:
	# Retail LevEvents_MTZ3 Routine4 waits exactly ScreenShift=$5A before
	# SingleObjLoad Object $54 and MusID_Boss. Keep a main-loop watchdog like the
	# other Sonic 2 bosses so the camera/object handoff cannot strand the arena.
	if not active:
		_s2_mtz3_boss_gate_timer=-1; _s2_mtz3_boss_spawn_attempts=0; return
	if object_manager.boss_status>=1:return
	if object_manager.boss_object!=null and is_instance_valid(object_manager.boss_object):return
	var arena_ready: bool = sonic_camera.s2_mtz3_music_fade_requested or sonic_camera.dle_routine>=6 or sonic_camera.screen_x>=0x2A80 or player.pixel_x()>=0x2B50
	if not arena_ready:return
	if sonic_camera.dle_routine<6:
		sonic_camera.limit_left=0x2AB0; sonic_camera.limit_right=0x2AB0
		sonic_camera.target_bottom=0x400; sonic_camera.s2_mtz3_music_fade_requested=true
		sonic_camera.s2_mtz3_event_timer=0; sonic_camera.dle_routine=6
	if not _s2_boss_prelude_stopped:
		_s2_boss_prelude_stopped=true; SonicAudio.stop_music()
	if _s2_mtz3_boss_gate_timer<0:
		_s2_mtz3_boss_gate_timer=maxi(0,sonic_camera.s2_mtz3_event_timer)
	else:
		_s2_mtz3_boss_gate_timer=maxi(_s2_mtz3_boss_gate_timer,sonic_camera.s2_mtz3_event_timer)
	if sonic_camera.dle_routine==6 and _s2_mtz3_boss_gate_timer<0x5A:return
	if _s2_mtz3_boss_gate_timer<0x5A:
		_s2_mtz3_boss_gate_timer+=1
		sonic_camera.s2_mtz3_event_timer=maxi(sonic_camera.s2_mtz3_event_timer,_s2_mtz3_boss_gate_timer)
	if _s2_mtz3_boss_gate_timer<0x5A:return
	sonic_camera.s2_mtz3_boss_ready=true; sonic_camera.boss_triggered=true; sonic_camera.dle_routine=maxi(sonic_camera.dle_routine,8)
	_s2_mtz3_boss_spawn_attempts+=1
	if not object_manager.spawn_s2_mtz_boss():return
	if not _boss_music_active:
		_boss_music_active=true; SonicAudio.play_music(SonicAudio.MUS_S2_BOSS,true)



func _tick_s2_wfz_boss_start(player: SonicPlayer, active: bool) -> void:
	if not active:
		return
	if object_manager.boss_status >= 1:
		return
	if object_manager.boss_object != null and is_instance_valid(object_manager.boss_object):
		return
	# Retail LevEvents_WFZ Routine5 preloads the boss as soon as Camera reaches
	# $2880,$400. Object $C5 itself then waits at $2B80 until Sonic comes within
	# $20 horizontally. Phase130 incorrectly delayed allocation until the later
	# $500 control-lock gate, making the fight begin at the wrong moment.
	var preload_ready: bool = sonic_camera.s2_wfz_boss_ready or sonic_camera.s2_wfz_event_subroutine >= 2 or (sonic_camera.screen_x >= 0x2880 and sonic_camera.screen_y >= 0x400)
	if not preload_ready:
		return
	sonic_camera.s2_wfz_boss_ready = true
	object_manager.spawn_s2_wfz_boss()


func _tick_s2_dez_mecha_start(active: bool) -> void:
	if not active or not sonic_camera.s2_dez_mecha_spawn_requested:
		return
	if object_manager.spawn_s2_dez_mecha_sonic():
		# LevEvents_DEZ issues this request only once when Camera_X reaches $140.
		# Clear it only after allocation succeeds so a full object table cannot
		# permanently lose the boss.
		sonic_camera.s2_dez_mecha_spawn_requested = false


func _tick_level_art() -> void:
	if level_art_animator == null or level == null:
		return
	level_art_animator.tick(object_manager.oscillate_0a())

func _tick_level_palette() -> void:
	if level_palette_cycler == null or level == null:
		return
	level_palette_cycler.tick()


func _start_ending_sequence() -> void:
	var good_ending = object_manager.emeralds == 6
	var ending_act = 1 if good_ending else 2
	_load_level(LevelCatalog.ZONE_ENDING, ending_act, true)
	if current_zone != LevelCatalog.ZONE_ENDING:
		return
	ending_controller = EndingSequenceController.new()
	ending_controller.name = "EndingSequenceController"
	add_child(ending_controller)
	ending_controller.setup(object_manager, good_ending)
	SonicAudio.play_music(SonicAudio.MUS_ENDING)

func _tick_ending_mode(player: SonicPlayer) -> void:
	if ending_controller == null or not is_instance_valid(ending_controller):
		ending_controller = EndingSequenceController.new()
		ending_controller.name = "EndingSequenceController"
		add_child(ending_controller)
		ending_controller.setup(object_manager, current_act == 1)

	# End_MainLoop runs End_MoveSonic before ExecuteObjects, so scripted input is
	# selected before Sonic's normal movement for this frame.
	ending_controller.tick()
	if ending_controller.credits_requested:
		_start_credits_sequence(ending_controller.good_ending)
		return
	player.set_runtime_level_bounds(sonic_camera.limit_left, sonic_camera.limit_right, false)
	player.simulate_tick()
	object_manager.execute_objects()
	_tick_level_palette()
	sonic_effects.tick()
	sonic_camera.update(player)
	sonic_camera.apply_to(camera)
	background_renderer.update(sonic_camera)
	player.refresh_visual()
	object_manager.obj_pos_load(sonic_camera.screen_x, sonic_camera.screen_y)
	_update_info()

func _start_credits_sequence(good_ending: bool) -> void:
	if credits_controller != null and is_instance_valid(credits_controller):
		return
	if ending_controller != null and is_instance_valid(ending_controller):
		ending_controller.queue_free()
		ending_controller = null
	var player = get_player() as SonicPlayer
	player.forced_visual_frame = -1
	player.display_hidden = false
	player.object_control_override = false
	player.control_locked = false
	player.control_lock_direction = 0
	credits_controller = CreditsSequenceController.new()
	credits_controller.name = "CreditsSequenceController"
	add_child(credits_controller)
	credits_controller.setup(self, object_manager, good_ending)
	SonicAudio.play_music(SonicAudio.MUS_CREDITS)

func _credits_load_demo(index: int) -> void:
	if credits_controller == null or not is_instance_valid(credits_controller):
		return
	index = clampi(index, 0, CreditsDemoData.DEMOS.size() - 1)
	var demo: Dictionary = CreditsDemoData.DEMOS[index]
	var zone: int = int(demo.get("zone", LevelCatalog.ZONE_GHZ))
	var act: int = int(demo.get("act", 1))
	var definition = LevelCatalog.get_level(zone, act)
	definition["start"] = String(demo.get("start", definition.get("start", "")))
	definition["_keep_credits_controller"] = true
	_load_level(zone, act, false, definition)
	if credits_controller == null or not is_instance_valid(credits_controller):
		return
	var player = get_player() as SonicPlayer
	# EndDemo_LampVar supplies the LZ3 credits demo's checkpoint/water state.
	if zone == LevelCatalog.ZONE_LZ and act == 3:
		object_manager.rings = 13
		object_manager.water_enabled = true
		object_manager.water_surface_y = 0x308
		object_manager.water_actual_y = 0x308
		object_manager.water_target_y = 0x308
		object_manager.water_routine = 1
		# EndDemo_LampVar also restores the exact 4th-demo camera and $800
		# lower boundary rather than recomputing them from the start point.
		sonic_camera.screen_x = 0x957
		sonic_camera.screen_y = 0x5CC
		sonic_camera.target_bottom = 0x800
		sonic_camera.current_bottom = 0x800
		sonic_camera.apply_to(camera)
		background_renderer.set_lz_water_surface(0x308)
		background_renderer.update(sonic_camera)
	credits_controller.manager = object_manager
	credits_controller.player = player
	credits_controller.begin_demo(index)

func _tick_credits_mode(player: SonicPlayer) -> void:
	if credits_controller == null or not is_instance_valid(credits_controller):
		return
	if not credits_controller.is_demo_active():
		credits_controller.tick_non_demo()
		if credits_controller.exit_requested:
			_finish_credits_sequence()
		return

	credits_controller.prepare_demo_frame()
	player.set_runtime_level_bounds(sonic_camera.limit_left, sonic_camera.limit_right, false)
	object_manager.update_lz_water(sonic_camera.screen_x)
	object_manager.apply_lz_water_features()
	player.simulate_tick()
	object_manager.execute_objects()
	_tick_level_palette()
	sonic_effects.tick()
	sonic_camera.update(player)
	sonic_camera.apply_to(camera)
	background_renderer.set_lz_water_surface(object_manager.water_surface_y if object_manager.water_enabled else -0x10000)
	background_renderer.update(sonic_camera)
	player.refresh_visual()
	object_manager.obj_pos_load(sonic_camera.screen_x, sonic_camera.screen_y)
	credits_controller.finish_demo_frame()
	_update_info()

func _finish_credits_sequence() -> void:
	# TryAgainEnd returns to GM_Sega in the retail game. Phase 47 now owns that
	# complete presentation path instead of restarting directly in GHZ1.
	if credits_controller != null and is_instance_valid(credits_controller):
		credits_controller.teardown()
		credits_controller.queue_free()
		credits_controller = null
	_load_level(LevelCatalog.ZONE_GHZ, 1, false)
	_start_startup_sequence(false)

func _start_startup_sequence(reload_ghz: bool = true) -> void:
	if level_title_card != null:
		level_title_card.cancel()
	if startup_controller != null and is_instance_valid(startup_controller):
		startup_controller.teardown()
		startup_controller.queue_free()
		startup_controller = null
	if reload_ghz and (current_zone != LevelCatalog.ZONE_GHZ or current_act != 1):
		_load_level(LevelCatalog.ZONE_GHZ, 1, false)
	startup_controller = StartupSequenceController.new()
	startup_controller.name = "StartupSequenceController"
	add_child(startup_controller)
	startup_controller.setup(self, object_manager, intro_demo_slot)
	SonicAudio.stop_music()

func _restart_startup_sequence() -> void:
	if startup_controller != null and is_instance_valid(startup_controller):
		startup_controller.teardown()
		startup_controller.queue_free()
		startup_controller = null
	_load_level(LevelCatalog.ZONE_GHZ, 1, false)
	_start_startup_sequence(false)

func _start_new_game_from_title() -> void:
	_reset_new_run_state()
	_load_level(LevelCatalog.ZONE_GHZ, 1, false)

func _reset_new_run_state() -> void:
	object_manager.emeralds = 0
	object_manager.emerald_stage_ids.clear()
	object_manager.emerald_color_ids.clear()
	object_manager.last_special_stage = 0
	object_manager.continues = 0
	object_manager.rings = 0
	object_manager.score = 0
	object_manager.lives = 3

func _start_level_from_level_select(zone: int, act: int) -> void:
	# LevSel_Level/PlayLevel starts a fresh three-life run at the selected level.
	_reset_new_run_state()
	_load_level(zone, act, false)

func _start_special_stage_from_level_select() -> void:
	# LevSel_Level_SS clears the level ID and starts Special Stage 1 with a fresh
	# three-life/zero-score state. Keep GHZ1 as the hidden return level because
	# v_zone_act is zero in the original path.
	_reset_new_run_state()
	_load_level(LevelCatalog.ZONE_GHZ, 1, false)
	if level_title_card != null:
		level_title_card.cancel()
	_start_special_stage(false, 0, true)

func _start_intro_demo(index: int) -> void:
	if startup_controller == null or not is_instance_valid(startup_controller):
		return
	if index == 3:
		intro_demo_slot = 0
		startup_controller.begin_special_demo()
		_start_special_stage(true, 0)
		if special_stage_controller == null:
			_restart_startup_sequence()
		return
	index = clampi(index, 0, IntroDemoData.DEMOS.size() - 1)
	var demo: Dictionary = IntroDemoData.DEMOS[index]
	var zone = int(demo.get("zone", LevelCatalog.ZONE_GHZ))
	var act = int(demo.get("act", 1))
	var definition = LevelCatalog.get_level(zone, act)
	definition["_keep_startup_controller"] = true
	intro_demo_slot = (index + 1) % 4
	_load_level(zone, act, false, definition)
	if startup_controller == null or not is_instance_valid(startup_controller):
		return
	object_manager.rings = 0
	object_manager.score = 0
	object_manager.lives = 3
	startup_controller.manager = object_manager
	startup_controller.player = get_player() as SonicPlayer
	startup_controller.begin_demo(index)

func _tick_intro_demo(player: SonicPlayer) -> void:
	if startup_controller == null or not is_instance_valid(startup_controller):
		return
	startup_controller.prepare_demo_frame()
	player.set_runtime_level_bounds(sonic_camera.limit_left, sonic_camera.limit_right, false)
	object_manager.update_lz_water(sonic_camera.screen_x)
	object_manager.apply_lz_water_features()
	player.simulate_tick()
	object_manager.execute_objects()
	_tick_level_palette()
	sonic_effects.tick()
	sonic_hud.tick()
	sonic_camera.update(player)
	sonic_camera.apply_to(camera)
	background_renderer.set_lz_water_surface(object_manager.water_surface_y if object_manager.water_enabled else -0x10000)
	background_renderer.update(sonic_camera)
	player.refresh_visual()
	object_manager.obj_pos_load(sonic_camera.screen_x, sonic_camera.screen_y)
	startup_controller.finish_demo_frame()
	_update_info()
	if startup_controller.restart_requested:
		_restart_startup_sequence()

func _select_special_stage() -> int:
	var candidate = posmod(object_manager.last_special_stage, 6)
	for _i in range(6):
		object_manager.last_special_stage = posmod(candidate + 1, 6)
		if object_manager.emeralds >= 6 or not object_manager.emerald_stage_ids.has(candidate):
			return candidate
		candidate = object_manager.last_special_stage
	return candidate

func _start_special_stage(demo: bool, stage_override: int = -1, debug_return_same_level: bool = false) -> void:
	if special_stage_controller != null and is_instance_valid(special_stage_controller):
		return
	if not demo and startup_controller != null and is_instance_valid(startup_controller):
		startup_controller.teardown()
		startup_controller.queue_free()
		startup_controller = null
	var stage = clampi(stage_override, 0, 5) if stage_override >= 0 else _select_special_stage()
	var next = Vector2i(current_zone, current_act) if debug_return_same_level else LevelCatalog.next_level(current_zone, current_act)
	special_stage_controller = SpecialStageController.new()
	special_stage_controller.name = "SpecialStageController"
	add_child(special_stage_controller)
	if not special_stage_controller.setup(self, object_manager, stage, demo, next):
		special_stage_controller.queue_free()
		special_stage_controller = null
		object_manager.special_stage_requested = false
		return
	SonicAudio.play_sfx(SonicAudio.SFX_ENTER_SS)
	SonicAudio.play_music(SonicAudio.MUS_SPECIAL_STAGE)

func _tick_special_stage_mode() -> void:
	if special_stage_controller == null or not is_instance_valid(special_stage_controller):
		return
	var controller = special_stage_controller
	controller.tick()
	if not controller.finished:
		return
	var demo = controller.demo_mode
	var restart_startup = controller.restart_startup_requested
	var next = controller.return_level
	controller.teardown()
	controller.queue_free()
	special_stage_controller = null
	object_manager.rings = 0
	object_manager.special_stage_requested = false
	if demo or restart_startup:
		_restart_startup_sequence()
		return
	_load_level(next.x, next.y, true)

func _debug_warp(zone: int, act: int = 1, ending_good: bool = false) -> void:
	# Debug-only direct level entry. It deliberately bypasses normal LevelOrder
	# and checkpoint state but leaves score/lives/emerald progress intact.
	if zone == LevelCatalog.ZONE_ENDING:
		if ending_good:
			object_manager.emeralds = 6
		_load_level(LevelCatalog.ZONE_ENDING, 1 if ending_good else 2, true)
		if current_zone == LevelCatalog.ZONE_ENDING:
			ending_controller = EndingSequenceController.new()
			ending_controller.name = "EndingSequenceController"
			add_child(ending_controller)
			ending_controller.setup(object_manager, ending_good)
		return
	_load_level(zone, act, true)
	# Phase 133: a direct debug warp must finish the same camera/background
	# priming pass used by the death-respawn path. This matters for DEZ because
	# its fixed $C8 camera/BG-Y state is consumed immediately by SwScrl_DEZ.
	if current_zone == zone and current_act == act and level != null:
		var debug_player = get_player() as SonicPlayer
		_reset_view_after_respawn(debug_player)

func _unhandled_input(event: InputEvent) -> void:
	# Phase 69: Genesis pad-facing controls are routed through ProjectSettings'
	# Input Map so keyboard/controller bindings stay data-driven.  The historical
	# PC-only warp/diagnostic shortcuts below remain explicit keys.
	var pressed := false
	var echo := false
	if event is InputEventKey:
		pressed = event.pressed
		echo = event.echo
	elif event is InputEventJoypadButton:
		pressed = event.pressed
	else:
		return
	if not pressed or echo:
		return

	# Continue polls Start from held state itself. Do not let an underlying
	# startup/title controller consume the same mapped press.
	if continue_controller != null and is_instance_valid(continue_controller):
		return

	# GM_Title owns D-pad/C cheat entry as well as A+Start level-select entry.
	# Let it see all Input-Map actions before ordinary gameplay pause/debug paths.
	if startup_controller != null and is_instance_valid(startup_controller):
		if startup_controller.handle_input(event):
			return

	if event.is_action_pressed("Start"):
		if special_stage_controller != null and is_instance_valid(special_stage_controller):
			if special_stage_controller.handle_enter():
				return
		if startup_controller != null and is_instance_valid(startup_controller):
			if startup_controller.handle_enter():
				return
		if _can_toggle_pause():
			game_paused = not game_paused
			SonicAudio.set_music_paused(game_paused)
			_update_info()
			return

	if event.is_action_pressed("Debug"):
		var mapped_player = get_player() as SonicPlayer
		mapped_player.set_debug_free_mode(not mapped_player.debug_free_mode)
		_update_info()
		return

	# Remaining shortcuts are intentionally PC/debug-only and are not Genesis-pad
	# actions, so only keyboard events participate in this block.
	if not (event is InputEventKey):
		return
	# Godot can report NumPad keys differently through logical keycode depending
	# on NumLock/platform. Prefer the physical KP code for the dedicated S2 test
	# warps so KP_2 can never alias the historical top-row KEY_2 Marble warp.
	var debug_key: int = int(event.keycode)
	if event.physical_keycode in [KEY_KP_0, KEY_KP_1, KEY_KP_2]:
		debug_key = int(event.physical_keycode)
	match debug_key:
		KEY_0:
			# Phase 49 debug shortcut: preview GM_Continue without deliberately
			# burning through three lives first.
			object_manager.continues = maxi(1, object_manager.continues)
			_start_continue_screen()
		KEY_1:
			_debug_warp(LevelCatalog.ZONE_GHZ, 1)
		KEY_2:
			_debug_warp(LevelCatalog.ZONE_MZ, 1)
		KEY_3:
			_debug_warp(LevelCatalog.ZONE_SYZ, 1)
		KEY_4:
			_debug_warp(LevelCatalog.ZONE_LZ, 1)
		KEY_5:
			_debug_warp(LevelCatalog.ZONE_SLZ, 1)
		KEY_6:
			_debug_warp(LevelCatalog.ZONE_SBZ, 1)
		KEY_7:
			_debug_warp(LevelCatalog.ZONE_SBZ, 3)
		KEY_8:
			_debug_warp(LevelCatalog.ZONE_ENDING, 1, true)
		KEY_9:
			_start_special_stage(false, 0, true)
		KEY_H:
			# Retail Sonic 2 Emerald Hill Act 1.
			_debug_warp(LevelCatalog.ZONE_S2_TEST, 1)
		KEY_I:
			# Phase 88 direct Emerald Hill Act 2 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_TEST, 2)
		KEY_J:
			# Phase 76 experimental Simon Wai Hidden Palace import slot.
			_debug_warp(LevelCatalog.ZONE_S2_HPZ_TEST, 1)
		KEY_M:
			# Retail Chemical Plant Act 1.
			_debug_warp(LevelCatalog.ZONE_S2_CPZ_TEST, 1)
		KEY_N:
			# Phase 93 direct retail Chemical Plant Act 2 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_CPZ_TEST, 2)
		KEY_O:
			# Phase 95 direct retail Aquatic Ruin Act 1 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_ARZ_TEST, 1)
		KEY_P:
			# Phase 96 direct retail Aquatic Ruin Act 2 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_ARZ_TEST, 2)
		KEY_Q:
			# Phase 98 direct retail Casino Night Act 1 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_CNZ_TEST, 1)
		KEY_T:
			# Phase 103 direct retail Casino Night Act 2 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_CNZ_TEST, 2)
		KEY_Y:
			# Phase 105 direct retail Hill Top Act 1 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_HTZ_TEST, 1)
		KEY_Z:
			# Phase 109 direct retail Hill Top Act 2 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_HTZ_TEST, 2)
		KEY_X:
			# Phase 111 direct retail Mystic Cave Act 1 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_MCZ_TEST, 1)
		KEY_V:
			# Phase 115 direct retail Oil Ocean Act 1 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_OOZ_TEST, 1)
		KEY_B:
			# Phase 117 direct retail Oil Ocean Act 2 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_OOZ_TEST, 2)
		KEY_G:
			# Phase 119 direct retail Metropolis Act 1 test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 1)
		KEY_C:
			# Phase 123 direct retail Metropolis Act 2 completion test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 2)
		KEY_F8:
			# Phase 125 direct retail Metropolis Act 3 boss/end test shortcut.
			_debug_warp(LevelCatalog.ZONE_S2_MTZ_TEST, 3)
		KEY_KP_0:
			# Phase 126 Hotfix 1: keep F10 available for debug; test zones use NumPad.
			_debug_warp(LevelCatalog.ZONE_S2_SCZ_TEST, 1)
		KEY_KP_1:
			# Phase 127 direct Wing Fortress test warp.
			_debug_warp(LevelCatalog.ZONE_S2_WFZ_TEST, 1)
		KEY_KP_2:
			# Phase 133 direct Death Egg / Mecha Sonic test warp.
			_debug_warp(LevelCatalog.ZONE_S2_DEZ_TEST, 1)
		KEY_K:
			# Phase 78 optional retail Sonic 2 movement/spindash profile.
			var physics_player = get_player() as SonicPlayer
			physics_player.toggle_sonic2_physics()
			_update_info()
		KEY_L:
			# Phase 79 independent Sonic animation/presentation selector.
			var animation_player = get_player() as SonicPlayer
			animation_player.cycle_animation_style()
			_update_info()
		KEY_F1:
			collision_debug_enabled = not collision_debug_enabled
			collision_debug.enabled = collision_debug_enabled
			collision_debug.queue_redraw()
		KEY_F2:
			sensor_debug_enabled = not sensor_debug_enabled
			var player = get_player() as SonicPlayer
			player.sensor_debug = sensor_debug_enabled
			player.queue_redraw()
		KEY_F3:
			object_manager.show_placeholders = not object_manager.show_placeholders
			for child in object_manager.get_children():
				child.queue_redraw()
		KEY_F4:
			debug_info_enabled = not debug_info_enabled
			_update_info()
		KEY_F5:
			object_manager.elapsed_frames = SonicObjectManager.MAX_TIME_FRAMES - 120
			object_manager.time_over = false
		KEY_F6:
			_load_level(current_zone, 3 if current_act <= 1 else current_act - 1, true)
		KEY_F7:
			_load_level(current_zone, 1 if current_act >= 3 else current_act + 1, true)
		KEY_U:
			SonicAudio.toggle_output_mode()
			_update_info()
		KEY_PAGEDOWN:
			_load_level(LevelCatalog.next_zone(current_zone), 1, true)
		KEY_F9:
			_load_level(LevelCatalog.ZONE_GHZ, 1, true)
		KEY_R:
			_reset_level_runtime()

func _can_toggle_pause() -> bool:
	# PauseGame refuses to start with zero lives. Startup/title/attract and the
	# Continue screen own Start for their respective game modes; credits also
	# retains its existing Start-to-skip final-screen behavior.
	if object_manager == null or object_manager.lives <= 0:
		return false
	if continue_controller != null and is_instance_valid(continue_controller):
		return false
	if startup_controller != null and is_instance_valid(startup_controller):
		return false
	if credits_controller != null and is_instance_valid(credits_controller):
		# Credits gameplay demos run through the normal level loop and therefore
		# retain PauseGame. The static credits pages/final END screen do not.
		return credits_controller.is_demo_active()
	return true

func _reset_level_runtime() -> void:
	death_restart_timer = -1
	var player = get_player() as SonicPlayer
	object_manager.clear_checkpoint()
	object_manager.reset_runtime_state(true)
	player.respawn()
	_reset_view_after_respawn(player)

func _begin_death_restart() -> void:
	# Sonic_HandleDeath deducts the life when Sonic passes 0x100 below the
	# screen, then routine 8 waits 60 frames before setting f_restart. GAME/TIME
	# OVER remain immediate, just like the source.
	object_manager.lives -= 1
	if object_manager.lives <= 0:
		SonicAudio.play_music(SonicAudio.MUS_GAME_OVER)
		game_over_ui.begin(false)
		return
	if object_manager.time_over:
		game_over_ui.begin(true)
		return
	death_restart_timer = 60
	object_manager.time_frozen = true
	var player = get_player() as SonicPlayer
	player.vel_x = 0
	player.vel_y = 0
	player.inertia = 0

func _complete_regular_death_restart() -> void:
	death_restart_timer = -1
	# Re-entering the level-start path also clears boss/results music state. This
	# is essential for the EHZ2 starpost at $2770: a death during/after the boss
	# prelude must be able to fade EHZ and start Boss music again on the retry.
	_boss_music_active = false
	_tally_music_active = false
	_s2_boss_prelude_stopped = false
	_s2_ehz2_boss_gate_timer = -1
	_s2_ehz2_boss_spawn_attempts = 0
	_s2_cpz2_boss_gate_timer = -1
	_s2_cpz2_boss_spawn_attempts = 0
	_s2_cnz2_boss_gate_timer = -1
	_s2_cnz2_boss_spawn_attempts = 0
	_s2_htz2_boss_gate_timer = -1
	_s2_htz2_boss_spawn_attempts = 0
	# Sonic 2 re-enters Level on an ordinary death, which reloads the mutable
	# CNZ2 layout RAM. Restore both temporary $F9 arena chunks before resetting
	# objects/camera so a death inside the closed arena can be retried normally.
	if current_zone == LevelCatalog.ZONE_S2_CNZ_TEST and current_act == 2 and level != null:
		if level.set_chunk_id_at(0x50, 0x0C, 0xDD):
			refresh_level_chunk(0x50, 0x0C)
		if level.set_chunk_id_at(0x54, 0x0C, 0xDD):
			refresh_level_chunk(0x54, 0x0C)
	object_manager.reset_runtime_state(true)
	var player = get_player() as SonicPlayer
	if object_manager.has_checkpoint():
		player.respawn_at(object_manager.checkpoint_position)
		object_manager.elapsed_frames = object_manager.checkpoint_frames
	else:
		player.respawn()
	_reset_view_after_respawn(player)
	_restart_level_presentation_after_death()

func _restart_level_presentation_after_death() -> void:
	# Both Sonic 1 GM_Level and Sonic 2 Level re-enter the level-start path after
	# an ordinary death. That restarts the BGM and runs Object $34 again. Earlier
	# native phases only reset Sonic/objects/camera, leaving music at its old song
	# position and omitting the title card entirely.
	_play_level_music(current_zone, current_act, false)
	if level_title_card == null or level == null:
		return
	var definition: Dictionary = level.definition
	if bool(definition.get("skip_title_card", false)):
		return
	if startup_controller != null or credits_controller != null or current_zone == LevelCatalog.ZONE_ENDING:
		return
	level_title_card.begin(current_zone, current_act, bool(definition.get("internal_sbz3", false)), current_zone == LevelCatalog.ZONE_SBZ and current_act == 3)

func _finish_game_over_card() -> void:
	death_restart_timer = -1
	var was_time_over = game_over_ui.time_over
	var player = get_player() as SonicPlayer
	if was_time_over and object_manager.lives > 0:
		# Object $39 TIME OVER always restarts the current level while lives remain.
		object_manager.reset_runtime_state(true)
		if object_manager.has_checkpoint():
			player.respawn_at(object_manager.checkpoint_position)
		else:
			player.respawn()
		_reset_view_after_respawn(player)
		return
	# Object $39 enters GM_Continue only when v_continues is non-zero; otherwise
	# GAME OVER returns directly to the SEGA screen.
	if object_manager.continues > 0:
		_start_continue_screen()
	else:
		_restart_startup_sequence()

func _start_continue_screen() -> void:
	object_manager.rings = 0
	if continue_controller != null and is_instance_valid(continue_controller):
		return
	if startup_controller != null and is_instance_valid(startup_controller):
		startup_controller.teardown()
		startup_controller.queue_free()
		startup_controller = null
	continue_controller = ContinueScreenController.new()
	continue_controller.name = "ContinueScreenController"
	add_child(continue_controller)
	continue_controller.setup(self, object_manager)
	SonicAudio.play_music(SonicAudio.MUS_CONTINUE)

func _finish_continue_screen() -> void:
	if continue_controller == null or not is_instance_valid(continue_controller):
		return
	var used = continue_controller.used_continue and not continue_controller.timed_out
	continue_controller.teardown()
	continue_controller.queue_free()
	continue_controller = null
	if not used:
		_restart_startup_sequence()
		return
	# Cont_GotoLevel: use one continue, restore three lives, and clear the run's
	# rings/time/score/lamppost state before reloading the same act.
	object_manager.continues = maxi(0, object_manager.continues - 1)
	object_manager.lives = 3
	object_manager.rings = 0
	object_manager.elapsed_frames = 0
	object_manager.score = 0
	object_manager.ring_life_flags = 0
	object_manager.clear_checkpoint()
	_load_level(current_zone, current_act, true)

func _reset_view_after_respawn(player: SonicPlayer) -> void:
	sonic_camera.configure_level(level.definition)
	sonic_camera.initialize(player)
	sonic_camera.apply_to(camera)
	background_renderer.reset()
	background_renderer.set_lz_water_surface(object_manager.water_surface_y if object_manager.water_enabled else -0x10000)
	background_renderer.update(sonic_camera)
	player.refresh_visual()
	object_manager.obj_pos_load(sonic_camera.screen_x, sonic_camera.screen_y)
	_update_info()


func _play_level_music(zone: int, act: int, keep_credits: bool = false) -> void:
	if level != null and String(level.definition.get("music_mode", "")) == "none":
		SonicAudio.stop_music()
		return
	if keep_credits:
		SonicAudio.play_music(SonicAudio.MUS_CREDITS)
		return
	if zone == LevelCatalog.ZONE_ENDING:
		SonicAudio.play_music(SonicAudio.MUS_ENDING, true)
		return
	if zone == LevelCatalog.ZONE_S2_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_EHZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_CPZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_CPZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_ARZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_ARZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_CNZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_CNZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_HTZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_HTZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_MCZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_MCZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_OOZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_OOZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_MTZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_MTZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_SCZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_SCZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_WFZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_WFZ, true)
		return
	if zone == LevelCatalog.ZONE_S2_DEZ_TEST:
		SonicAudio.play_music(SonicAudio.MUS_S2_DEZ, true)
		return
	if zone == LevelCatalog.ZONE_GHZ:
		SonicAudio.play_music(SonicAudio.MUS_GHZ, true)
	elif zone == LevelCatalog.ZONE_MZ:
		SonicAudio.play_music(SonicAudio.MUS_MZ, true)
	elif zone == LevelCatalog.ZONE_SYZ:
		SonicAudio.play_music(SonicAudio.MUS_SYZ, true)
	elif zone == LevelCatalog.ZONE_LZ:
		# Sonic 1 stores the flooded Scrap Brain Act 3 corridor as hidden LZ4,
		# but GM_Level explicitly overrides its playlist index to Scrap Brain.
		# Do not inherit Labyrinth music merely because the internal zone id is LZ.
		SonicAudio.play_music(SonicAudio.MUS_SBZ if act == 4 else SonicAudio.MUS_LZ, true)
	elif zone == LevelCatalog.ZONE_SLZ:
		SonicAudio.play_music(SonicAudio.MUS_SLZ, true)
	elif zone == LevelCatalog.ZONE_SBZ:
		SonicAudio.play_music(SonicAudio.MUS_FINAL_ZONE if act == 3 else SonicAudio.MUS_SBZ, true)

func _update_info() -> void:
	if collision == null or Global.players.is_empty():
		return
	var player = get_player() as SonicPlayer
	info_label.visible = (debug_info_enabled or player.debug_free_mode) and not object_manager.act_complete and not game_over_ui.active
	var mouse = get_global_mouse_position()
	var mx = floori(mouse.x)
	var my = floori(mouse.y)
	var block = collision.get_block_info(mx, my, player.collision_path)
	var transition = "SPECIAL STAGE REQUESTED" if object_manager.special_stage_requested else ""
	var support = "S2 IMPORT TEST" if bool(level.definition.get("experimental_sonic2", false)) else ("LZ PLAYTEST" if current_zone == LevelCatalog.ZONE_LZ else ("SLZ PLAYTEST" if current_zone == LevelCatalog.ZONE_SLZ else ("SBZ PLAYTEST" if current_zone == LevelCatalog.ZONE_SBZ and current_act < 3 else ("FULL" if bool(level.definition.get("full_gameplay_support", false)) else "TERRAIN PREVIEW"))))
	var water_text = ""
	if object_manager.water_enabled:
		water_text = "  water:%03X/%03X target:%03X r:%d uw:%s air:%d" % [object_manager.water_surface_y, object_manager.water_actual_y, object_manager.water_target_y, object_manager.water_routine, str(player.underwater), object_manager.air_seconds]
	info_label.text = (
		# Regression markers retained for historical validation suites.
		# Native Sonic 1 Phase 97
		# Native Sonic 1 Phase 100
		# Native Sonic 1 Phase 101
		"Native Sonic 1 Phase 139 | %s | %s | Audio:%s\n" % [level.display_name(), support, SonicAudio.output_mode_name()]
		+ "1 GHZ  2 MZ  3 SYZ  4 LZ  5 SLZ  6 SBZ  7 FZ  8 Ending  9 SS1 | Enter PAUSE | F6/F7 act  Num0 SCZ  Num1 WFZ  Num2 DEZ\n"
		+ "PageDown next zone  F9 GHZ1  H EHZ1  I EHZ2  J HPZ  M CPZ1  N CPZ2  G MTZ1  C MTZ2  F8 MTZ3  K S1/S2 physics  L S1/Beta/Final anim  F1 collision  F2 sensors  F3 unsupported  F4 debug  U audio mode\n"
		+ player.state_text() + "  rings:%d lives:%d score:%d time:%s%s\n" % [object_manager.rings, object_manager.lives, object_manager.score, object_manager.level_time_text(), water_text]
		+ "shield:%s inv:%d shoes:%d hurt:%s dead:%s act:%s %s\n" % [str(player.shield), player.invincible_timer, player.shoes_timer, str(player.hurt_state), str(player.dead), str(object_manager.act_complete), transition]
		+ sonic_camera.state_text() + "  objects:%d/%d records:%d\n" % [object_manager.active_count(), SonicObjectManager.LEVEL_SLOT_COUNT, object_manager.records.size()]
		+ "mouse:(%d,%d) block:$%03X shape:$%02X top:%s all:%s" % [
			mx, my, int(block["block_id"]), int(block["shape_id"]),
			str(block["top_solid"]), str(block["all_solid"])
		]
	)
