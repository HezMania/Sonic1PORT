class_name SonicObjectManager
extends Node2D

const BadnikProjectileClass = preload("res://scripts/objects/badnik_projectile.gd")
const PowerUpObjectClass = preload("res://scripts/objects/power_up_object.gd")
const ExplosionEffectClass = preload("res://scripts/effects/explosion_effect.gd")
const AnimalObjectClass = preload("res://scripts/effects/animal_object.gd")
const PointsObjectClass = preload("res://scripts/effects/points_object.gd")
const GHZBossObjectClass = preload("res://scripts/objects/ghz_boss_object.gd")
const MZGeyserColumnClass = preload("res://scripts/objects/mz_geyser_column.gd")
const MZBlockFragmentClass = preload("res://scripts/objects/mz_block_fragment.gd")
const MZBossObjectClass = preload("res://scripts/objects/mz_boss_object.gd")
const MZBossFireObjectClass = preload("res://scripts/objects/mz_boss_fire_object.gd")
const SYZBossObjectClass = preload("res://scripts/objects/syz_boss_object.gd")
const SYZBossBlockClass = preload("res://scripts/objects/syz_boss_block.gd")
const PrisonCapsuleObjectClass = preload("res://scripts/objects/prison_capsule_object.gd")
const LZBubbleObjectClass = preload("res://scripts/objects/lz_bubble_object.gd")
const LZEnemyObjectClass = preload("res://scripts/objects/lz_enemy_object.gd")
const LZNativeObjectClass = preload("res://scripts/objects/lz_native_object.gd")
const LZProgressionObjectClass = preload("res://scripts/objects/lz_progression_object.gd")
const LZOrbinautObjectClass = preload("res://scripts/objects/lz_orbinaut_object.gd")
const LZBossObjectClass = preload("res://scripts/objects/lz_boss_object.gd")
const SLZNativeObjectClass = preload("res://scripts/objects/slz_native_object.gd")
const SLZBossObjectClass = preload("res://scripts/objects/slz_boss_object.gd")
const SLZBossSpikeballClass = preload("res://scripts/objects/slz_boss_spikeball.gd")
const SBZNativeObjectClass = preload("res://scripts/objects/sbz_native_object.gd")
const SBZProgressionObjectClass = preload("res://scripts/objects/sbz_progression_object.gd")
const SBZSmallDoorObjectClass = preload("res://scripts/objects/sbz_small_door_object.gd")
const SBZTransitionObjectClass = preload("res://scripts/objects/sbz_transition_object.gd")
const FZBossObjectClass = preload("res://scripts/objects/fz_boss_object.gd")
const EndingAnimalObjectClass = preload("res://scripts/objects/ending_animal_object.gd")
const LZWaterSurfaceEffectClass = preload("res://scripts/effects/lz_water_surface_effect.gd")
const LZWaterSplashEffectClass = preload("res://scripts/effects/lz_water_splash_effect.gd")
const LZDrownNumberEffectClass = preload("res://scripts/effects/lz_drown_number_effect.gd")
const PathSwitcherClass = preload("res://scripts/objects/path_switcher_object.gd")
const S2UnsupportedObjectClass = preload("res://scripts/objects/s2_unsupported_object.gd")
const S2PlaneSwitcherObjectClass = preload("res://scripts/objects/s2_plane_switcher_object.gd")
const S2EHZSpiralPathObjectClass = preload("res://scripts/objects/s2_ehz_spiral_path_object.gd")
const S2EHZBridgeObjectClass = preload("res://scripts/objects/s2_ehz_bridge_object.gd")
const S2EHZPlatformObjectClass = preload("res://scripts/objects/s2_ehz_platform_object.gd")
const S2EHZSceneryObjectClass = preload("res://scripts/objects/s2_ehz_scenery_object.gd")
const S2SpikesObjectClass = preload("res://scripts/objects/s2_spikes_object.gd")
const S2SpringObjectClass = preload("res://scripts/objects/s2_spring_object.gd")
const S2MonitorAdapterClass = preload("res://scripts/objects/s2_monitor_adapter.gd")
const S2SignpostAdapterClass = preload("res://scripts/objects/s2_signpost_adapter.gd")
const S2EHZBadnikObjectClass = preload("res://scripts/objects/s2_ehz_badnik_object.gd")
const S2EHZProjectileClass = preload("res://scripts/objects/s2_ehz_projectile.gd")
const S2EHZWaterfallObjectClass = preload("res://scripts/objects/s2_ehz_waterfall_object.gd")
const S2EHZBossObjectClass = preload("res://scripts/objects/s2_ehz_boss_object.gd")
const S2CPZBossObjectClass = preload("res://scripts/objects/s2_cpz_boss_object.gd")
const S2ARZBossObjectClass = preload("res://scripts/objects/s2_arz_boss_object.gd")
const S2CNZBossObjectClass = preload("res://scripts/objects/s2_cnz_boss_object.gd")
const S2HTZBossObjectClass = preload("res://scripts/objects/s2_htz_boss_object.gd")
const S2MCZBossObjectClass = preload("res://scripts/objects/s2_mcz_boss_object.gd")
const S2OOZBossObjectClass = preload("res://scripts/objects/s2_ooz_boss_object.gd")
const S2MTZBossObjectClass = preload("res://scripts/objects/s2_mtz_boss_object.gd")
const S2WFZBossObjectClass = preload("res://scripts/objects/s2_wfz_boss_object.gd")
const S2DEZMechaSonicClass = preload("res://scripts/objects/s2_dez_mecha_sonic.gd")
const S2DEZEggmanRunnerClass = preload("res://scripts/objects/s2_dez_eggman_runner.gd")
const S2DEZEggRoboClass = preload("res://scripts/objects/s2_dez_egg_robo.gd")
const S2ARZEnvironmentObjectClass = preload("res://scripts/objects/s2_arz_environment_object.gd")
const S2ARZSwingObjectClass = preload("res://scripts/objects/s2_arz_swing_object.gd")
const S2ARZArrowObjectClass = preload("res://scripts/objects/s2_arz_arrow_object.gd")
const S2ARZLeafObjectClass = preload("res://scripts/objects/s2_arz_leaf_object.gd")
const S2ARZDebrisObjectClass = preload("res://scripts/objects/s2_arz_debris_object.gd")
const S2ARZBadnikObjectClass = preload("res://scripts/objects/s2_arz_badnik_object.gd")
const S2CNZTraversalObjectClass = preload("res://scripts/objects/s2_cnz_traversal_object.gd")
const S2CNZCompletionObjectClass = preload("res://scripts/objects/s2_cnz_completion_object.gd")
const S2EggPrisonObjectClass = preload("res://scripts/objects/s2_egg_prison_object.gd")
const S2CPZTraversalObjectClass = preload("res://scripts/objects/s2_cpz_traversal_object.gd")
const S2CPZHazardObjectClass = preload("res://scripts/objects/s2_cpz_hazard_object.gd")
const S2HTZObjectClass = preload("res://scripts/objects/s2_htz_object.gd")
const S2MCZObjectClass = preload("res://scripts/objects/s2_mcz_object.gd")
const S2OOZObjectClass = preload("res://scripts/objects/s2_ooz_object.gd")
const S2MTZObjectClass = preload("res://scripts/objects/s2_mtz_object.gd")
const S2SCZObjectClass = preload("res://scripts/objects/s2_scz_object.gd")
const S2WFZObjectClass = preload("res://scripts/objects/s2_wfz_object.gd")
const S2OOZProjectileClass = preload("res://scripts/objects/s2_ooz_projectile.gd")
const S2_OOZ_OIL_SUPPORT_RECORD := -0x7007
const S2_OOZ_OIL_Y := 0x758
const S2_OOZ2_BOSS_OIL_Y := 0x2D8
const S2_OOZ_OIL_WIDTH := 0x20
const S2_OOZ_OIL_MAX_SUBMERSION := 0x30
const S2CPZSpinyProjectileClass = preload("res://scripts/objects/s2_cpz_spiny_projectile.gd")

# Native equivalent of ObjPosLoad + the level-object portion of ExecuteObjects.
# Sonic 1 has 128 OST entries: 32 reserved, then 96 level-object slots. Phase 3
# mirrors the 96 level slots explicitly and executes them in slot order.

const LEVEL_SLOT_COUNT := 96
const SPAWN_LEFT := 128
const SPAWN_RIGHT := 640
const DESPAWN_LEFT := 256
const DESPAWN_RIGHT := 768
const MAX_TIME_FRAMES := (9 * 60 * 60) + (59 * 60) + 59
const TIME_BONUSES: Array[int] = [
	50000, 50000, 10000, 5000,
	4000, 4000, 3000, 3000,
	2000, 2000, 2000, 2000,
	1000, 1000, 1000, 1000,
	500, 500, 500, 500, 0,
]

var collision: GenesisCollision
var player: SonicPlayer
var records: Array[Dictionary] = []
var slots: Array = []
var active_records: Dictionary = {}
var destroyed_records: Dictionary = {}
var ring_masks: Dictionary = {}
var broken_monitors: Dictionary = {}
var rings := 0
var score := 0
var lives := 3
# Phase 49 v_continues equivalent. Awarded at 50 Special Stage rings and
# consumed only by the retail Continue game mode after GAME OVER.
var continues := 0
var item_bonus_chain := 0
var ring_life_flags := 0
var transient_objects: Array = []
var checkpoint_id := -1
var checkpoint_position := Vector2i.ZERO
var act_complete := false
var elapsed_frames := 0
var time_over := false
var time_bonus := 0
var ring_bonus := 0
var tally_finished := false
var big_ring_collected := false
var special_stage_requested := false
# Phase 127: source-seamless zone transitions (SCZ -> WFZ) bypass Object $3A's
# result-card tally just like retail ObjB2. (-1,-1) means no request.
var requested_level_transition := Vector2i(-1, -1)
var s2_wfz_fire_toggle: bool = false
# Phase 129: WFZ event-background displacement + wind-tunnel runtime bridge
# before object execution. WFZ objects must not reach through ObjectManager for a
# nonexistent camera property.
var s2_wfz_bg_x_offset: int = 0
var s2_wfz_bg_y_offset: int = 0
# Retail WindTunnel/WindTunnel_holding_flag bridge for the two WFZ airflow corridors.
var s2_wfz_wind_holding: bool = false
var s2_wfz_wind_active: bool = false
var s2_wfz_getaway_active: bool = false
var s2_wfz_rivet_busted: bool = false
var s2_wfz_layout_refresh_requested: bool = false
var s2_wfz_background_refresh_requested: bool = false
# Phase 132 Death Egg first-boss runtime bridge.
var s2_dez_mecha_spawned: bool = false
var s2_dez_mecha_defeated: bool = false
# Phase 135 final Death Egg bridge. C6 wakes C7 after Robotnik leaves; C7 owns
# the final arena lock and end-of-game white-fade handoff.
var s2_dez_c6_departed: bool = false
var s2_dez_final_boss_active: bool = false
var s2_dez_ending_active: bool = false
var emeralds := 0
# Phase 48 v_emldlist + v_lastspecial equivalents. Stage IDs are retained
# across normal level loads and cleared only when a new game begins.
var emerald_stage_ids: Array[int] = []
# Phase 67 v_emldlist equivalent: actual emerald mapping-frame IDs in the
# order collected. Stage IDs are separately retained for Special Stage selection.
var emerald_color_ids: Array[int] = []
var last_special_stage := 0
var checkpoint_frames := 0
var show_placeholders := false
var _previous_screen_block := -1
var current_screen_x := 0
var current_screen_y := 0
# Phase 126 Hotfix 1: retail Tornado_Velocity_X/Y are shared world-scroll
# velocities. SCZ moving objects add them after ObjectMove (loc_36776).
var s2_scz_scroll_vx := 0
var s2_scz_scroll_vy := 0
var end_tally_state := 0 # 0 idle, 1 pre-wait, 2 tally, 3 post-wait, 4 done
var end_tally_timer := 0
var _random_seed := 0
# Shared OscillateNumDo channels used by Object $18/$15. Values are 16-bit
# accumulators; objects read the high byte just like move.b (v_oscillate+N).
var _osc_1a_value := 0x0080
var _osc_1a_rate := 0
var _osc_1a_down := false
var _osc_0e_value := 0x0080
var _osc_0e_rate := 0
var _osc_0e_down := false
var _osc_02_value := 0x0080
var _osc_02_rate := 0
var _osc_02_down := false
var _osc_06_value := 0x0080
var _osc_06_rate := 0
var _osc_06_down := false
var _osc_0a_value := 0x0080
var _osc_0a_rate := 0
var _osc_0a_down := false
var _osc_12_value := 0x0080
var _osc_12_rate := 0
var _osc_12_down := false
var _osc_16_value := 0x0080
var _osc_16_rate := 0
var _osc_16_down := false
var _osc_1e_value := 0x0080
var _osc_1e_rate := 0
var _osc_1e_down := false
var _osc_22_value := 0x0080
var _osc_22_rate := 0
var _osc_22_down := false
var _osc_26_value := 0x50F0
var _osc_26_rate := 0x011E
var _osc_26_down := true
# Phase 91 retail Sonic 2 OscillateNum state. The S1-native oscillator helpers
# above use the subset/initial state needed by Sonic 1 objects; S2 CPZ Object
# $19 reads the exact 16-channel S2 table by byte offset.
var _s2_source_osc_pos: Array[int] = []
var _s2_source_osc_rate: Array[int] = []
var _s2_source_osc_down: Array[bool] = []
var switch_flags: Dictionary = {}
var switch_alt_flags: Dictionary = {}
# Phase 101 Casino Night shared state: only one slot cage can own Sonic, and
# Object $D8 groups share a three-target completion counter.
var cnz_slot_machine_in_use: bool = false
var cnz_saucer_break_count: Dictionary = {}
# Retail SpecialCNZBumpers: these are collision-only pseudo-objects embedded in
# the CNZ chunk art rather than ObjectPlacement/RingPlacement records.
var cnz_special_bumpers: Array[Vector3i] = []
var cnz_boss_exit_refresh_requested: bool = false
# Phase 106 Hill Top earthquake state mirrored from SonicCamera for HTZ objects.
var htz_quake_active: bool = false
var htz_bg_y_offset: int = 0
# Phase 120 retail MTZ_Platform_Cog_X shared by Object $65 subtype $04/$20.
var mtz_platform_cog_x: int = 0
# Phase 108: current retail PalCycle_HTZ frame, mirrored by LevelPaletteCycler
# so source-rendered quake lava sprites stay on the same four CRAM colors.
var htz_lava_palette_frame: int = 0
# Phase 112 retail ButtonVine_Trigger table shared by MCZ $77/$7F/$80/$81.
var mcz_button_vine_triggers: Array[int] = []
# Phase 115 Object $07 global Oil Ocean support/sinking state.
var ooz_oil_submersion: int = S2_OOZ_OIL_MAX_SUBMERSION
var ooz_control_owner_record: int = -1
# REV01 f_obj56 analogue used by the long subtype-$37 SYZ moving block.
var syz_obj56_complete := false
var level_definition: Dictionary = {}
var boss_status := 0 # 0 fighting/not spawned, 1 defeated, 2 capsule opened
var boss_limit_right := 0x2960
var boss_object = null
var boss_screen_lock := false
var syz_boss_blocks: Array = []
var syz_boss_blocks_spawned := false
var time_frozen := false
# LZWaterFeatures state. water_surface_y includes the source surface sway;
# water_actual_y is v_waterpos2 and water_target_y is v_waterpos3.
var water_enabled := false
var water_surface_y := 0
var water_actual_y := 0
var water_target_y := 0
var water_routine := 0
var s2_pipe_exit_frame := -1
# Phase 30 LZ air/drowning controller (v_air + Object $0A equivalent).
var air_seconds := 30
var air_frame_timer := 0
var drown_display_timer := 0
var drown_restart_timer := 0
var drown_extra_remaining := -1
var drown_extra_delay := 0
var drown_number_pending := -1
var lz_water_surface_effect = null
# Phase 33 LZ progression state: f_wtunneldisallow, f_conveyrev and v_obj63.
var lz_wind_blockers: Dictionary = {}
var lz3_layout_switch_f_applied := false
var lz_conveyor_reversed := false
var lz_conveyor_groups_loaded: Dictionary = {}
# Phase 42 Object $6F source-platform group residency.
var sbz_spin_groups_loaded: Dictionary = {}
# Phase 43 internal SBZ3 uses the source v_obj6B singleton gate.
var sbz3_ancient_lift_claimed := false
# Phase 43 DLE-spawned Object $83/$82 references.
var sbz_false_floor_object = null
var sbz_eggman_object = null
var sbz2_post_tally_started := false
var sbz2_post_tally_boundary_started := false
# Phase 44 Final Zone boss/event state.
var fz_end_scroll_started := false
var final_ending_requested := false

func setup(collision_engine: GenesisCollision, sonic: SonicPlayer, root_path: String = "res://data/s1", definition: Dictionary = {}) -> bool:
	# Rebind the manager for a new act without recreating the scene node.  This is
	# the native equivalent of clearing level OST/object-state on GM_Level load.
	reset_runtime_state(true)
	for child in get_children():
		if child is GenesisLevelObject:
			child.queue_free()
	collision = collision_engine
	player = sonic
	player.object_manager = self
	level_definition = definition.duplicate(true)
	_initialize_lz_water()
	slots.resize(LEVEL_SLOT_COUNT)
	for i in range(LEVEL_SLOT_COUNT):
		slots[i] = null
	var s2_object_path = String(level_definition.get("s2_objects", ""))
	var loaded := false
	if not s2_object_path.is_empty():
		loaded = _load_s2_objpos(root_path.path_join(s2_object_path))
	else:
		var object_path = String(level_definition.get("objects", "objpos/ghz1.bin"))
		loaded = _load_objpos(root_path.path_join(object_path))
	if not loaded and bool(level_definition.get("objects_optional", false)):
		records.clear()
		loaded = true
	# Phase 80: Sonic 2 keeps rings in a separate source-native descriptor list.
	# Parse that list directly into ordinary RingGroupObject records so collection,
	# respawn masks, HUD totals and scarce level-object slots all remain on the
	# established native runtime path. This is definition-gated to S2 test levels.
	var s2_ring_path = String(level_definition.get("s2_rings", ""))
	if loaded and not s2_ring_path.is_empty():
		loaded = _load_s2_ring_positions(root_path.path_join(s2_ring_path))
	var cnz_bumper_path: String = String(level_definition.get("s2_cnz_bumpers", ""))
	if loaded and not cnz_bumper_path.is_empty():
		loaded = _load_s2_cnz_bumpers(root_path.path_join(cnz_bumper_path))
	if loaded:
		records.sort_custom(func(a, b): return int(a["x"]) < int(b["x"]) or (int(a["x"]) == int(b["x"]) and int(a["index"]) < int(b["index"])))
		_spawn_loop_path_switchers()
	return loaded


func _load_s2_cnz_bumpers(path: String) -> bool:
	cnz_special_bumpers.clear()
	if not FileAccess.file_exists(path):
		return false
	var data: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if data.size() < 6:
		return false
	for off in range(0, data.size() - 5, 6):
		var bumper_type: int = (int(data[off]) << 8) | int(data[off + 1])
		var bx: int = (int(data[off + 2]) << 8) | int(data[off + 3])
		var by: int = (int(data[off + 4]) << 8) | int(data[off + 5])
		if bx == 0xFFFF:
			break
		# Retail CNZ2 includes the missing start-boundary sentinel as an all-zero
		# record. It is not a physical bumper.
		if bx == 0 and by == 0:
			continue
		cnz_special_bumpers.append(Vector3i(bumper_type & 0xE, bx, by))
	return true

func _tick_s2_cnz_special_bumpers() -> void:
	# Translation of Check_CNZ_bumpers. The visible triangle/diamond bumpers are
	# level-layout pixels; this pseudo-object table supplies their collision only.
	var p: SonicPlayer = player
	var sonic_left: int = p.pixel_x() - 9
	var sonic_half_y: int = maxi(1, p.height_radius - 3)
	var sonic_top: int = p.pixel_y() - sonic_half_y
	var sonic_width: int = 0x12
	var sonic_height: int = sonic_half_y * 2
	for bumper in cnz_special_bumpers:
		var bx: int = bumper.y
		if bx < current_screen_x - 0x50 or bx > current_screen_x + 0x1A0:
			continue
		var by: int = bumper.z
		var ext: Vector2i = _cnz_bumper_extent(bumper.x)
		var left: int = bx - ext.x
		var top: int = by - ext.y
		if sonic_left + sonic_width < left or sonic_left > left + ext.x * 2:
			continue
		if sonic_top + sonic_height < top or sonic_top > top + ext.y * 2:
			continue
		if _apply_s2_cnz_special_bumper(bumper.x, bx, by):
			return

func _cnz_bumper_extent(bumper_type: int) -> Vector2i:
	match bumper_type & 0xE:
		0, 2:
			return Vector2i(0x20, 0x20)
		4, 6:
			return Vector2i(0x40, 8)
		_:
			return Vector2i(8, 0x40)

func _cnz_bumper_reflect(axis_angle: int) -> void:
	var incoming: int = GenesisMath.calc_angle(player.vel_x, player.vel_y) & 0xFF
	var delta: int = GenesisMath.s8((incoming - axis_angle) & 0xFF)
	var magnitude: int = absi(delta)
	var outgoing: int = (-delta + axis_angle) & 0xFF
	if magnitude >= 0x38:
		outgoing = axis_angle & 0xFF
	player.vel_x = GenesisMath.s16((GenesisMath.cosine(outgoing) * -0xA00) >> 8)
	player.vel_y = GenesisMath.s16((GenesisMath.sine(outgoing) * -0xA00) >> 8)

func _apply_s2_cnz_special_bumper(bumper_type: int, bx: int, by: int) -> bool:
	var px: int = player.pixel_x()
	var py: int = player.pixel_y()
	match bumper_type & 0xE:
		0:
			if py - by >= 0x20:
				player.vel_y = 0xA00
			elif px - bx >= 0x20:
				player.vel_x = 0xA00
			else:
				# Retail loc_17586 clips the broad 64x64 AABB to the actual lower-right
				# diagonal face before reflecting. Sonic's center is biased down by 14.
				var diagonal_x: int = bx - px
				# Source CMP/BLO is unsigned: negative/out-of-range deltas clamp to $20.
				if diagonal_x < 0 or diagonal_x >= 0x20:
					diagonal_x = 0x20
				var face_test: int = diagonal_x + by - 8 - (py + 14)
				if face_test >= 0:
					return false
				_cnz_bumper_reflect(0x20)
		2:
			if py - by >= 0x20:
				player.vel_y = 0xA00
			elif bx - px >= 0x20:
				player.vel_x = -0xA00
			else:
				# Mirrored loc_17602 diagonal-face test. This removes the oversized
				# invisible triangle that Phase 104's rectangle-only approximation made.
				var diagonal_x: int = px - bx
				if diagonal_x < 0 or diagonal_x >= 0x20:
					diagonal_x = 0x20
				var face_test: int = diagonal_x + by - 8 - (py + 14)
				if face_test >= 0:
					return false
				_cnz_bumper_reflect(0x60)
		4:
			if py - by >= 8:
				player.vel_y = 0xA00
			elif bx - px >= 0x40:
				player.vel_x = -0xA00
			elif px - bx >= 0x40:
				player.vel_x = 0xA00
			else:
				_cnz_bumper_reflect(0x38 if px < bx else 0x48)
		6:
			if by - py >= 8:
				player.vel_y = -0xA00
			elif bx - px >= 0x40:
				player.vel_x = -0xA00
			elif px - bx >= 0x40:
				player.vel_x = 0xA00
			else:
				_cnz_bumper_reflect(0xC8 if px < bx else 0xB8)
		8:
			if px - bx >= 8:
				player.vel_x = 0xA00
			elif by - py >= 0x40:
				player.vel_y = -0xA00
			elif py - by >= 0x40:
				player.vel_x = 0xA00
			else:
				_cnz_bumper_reflect(0x08 if py < by else 0xF8)
		0xA:
			if bx - px >= 8:
				player.vel_x = 0xA00
			elif by - py >= 0x40:
				player.vel_y = -0xA00
			elif py - by >= 0x40:
				player.vel_x = 0xA00
			else:
				_cnz_bumper_reflect(0x78 if py < by else 0x88)
		_:
			return false
	player.in_air = true
	player.jumping = false
	player.clear_object_support()
	SonicAudio.play_sfx(SonicAudio.SFX_BUMPER)
	return true


func _spawn_loop_path_switchers() -> void:
	# Sonic 2 Object $03 inspired architecture: generate non-rendering path
	# switchers directly from Sonic 1's loop-marked layout chunks. The paired
	# collision surfaces remain source Sonic 1 Map256 data.
	if collision == null or collision.level == null:
		return
	var zone = collision.level.zone_id
	for cy in range(collision.level.layout_height):
		for cx in range(collision.level.layout_width):
			var raw_chunk = collision.level.get_chunk_id_at(cx, cy)
			var is_loop = (zone == LevelCatalog.ZONE_GHZ and raw_chunk == 0xB5) or (zone == LevelCatalog.ZONE_SLZ and (raw_chunk == 0xAA or raw_chunk == 0xB4))
			if not is_loop:
				continue
			var switcher = PathSwitcherClass.new()
			switcher.name = "PathSwitcher_%02X_%02d_%02d" % [raw_chunk, cx, cy]
			add_child(switcher)
			var key = 1 + (cy << 16) + cx
			switcher.setup_loop_switcher(self, cx, cy, raw_chunk, key)
			transient_objects.append(switcher)

func reset_runtime_state(clear_persistent: bool = true) -> void:
	for i in range(slots.size()):
		var obj = slots[i]
		if obj != null and is_instance_valid(obj):
			obj.queue_free()
		slots[i] = null
	active_records.clear()
	for transient in transient_objects:
		if transient != null and is_instance_valid(transient):
			transient.queue_free()
	transient_objects.clear()
	_previous_screen_block = -1
	current_screen_x = 0
	current_screen_y = 0
	_osc_1a_value = 0x0080
	_osc_1a_rate = 0
	_osc_1a_down = false
	_osc_0e_value = 0x0080
	_osc_0e_rate = 0
	_osc_0e_down = false
	_osc_02_value = 0x0080
	_osc_02_rate = 0
	_osc_02_down = false
	_osc_06_value = 0x0080
	_osc_06_rate = 0
	_osc_06_down = false
	_osc_0a_value = 0x0080
	_osc_0a_rate = 0
	_osc_0a_down = false
	_osc_12_value = 0x0080
	_osc_12_rate = 0
	_osc_12_down = false
	_osc_16_value = 0x0080
	_osc_16_rate = 0
	_osc_16_down = false
	_osc_1e_value = 0x0080
	_osc_1e_rate = 0
	_osc_1e_down = false
	_osc_22_value = 0x0080
	_osc_22_rate = 0
	_osc_22_down = false
	_osc_26_value = 0x50F0
	_osc_26_rate = 0x011E
	_osc_26_down = true
	_reset_s2_source_oscillators()
	switch_flags.clear()
	switch_alt_flags.clear()
	cnz_slot_machine_in_use = false
	cnz_saucer_break_count.clear()
	cnz_special_bumpers.clear()
	cnz_boss_exit_refresh_requested = false
	htz_quake_active = false
	htz_bg_y_offset = 0
	mtz_platform_cog_x = 0
	htz_lava_palette_frame = 0
	mcz_button_vine_triggers.resize(16)
	mcz_button_vine_triggers.fill(0)
	ooz_oil_submersion = S2_OOZ_OIL_MAX_SUBMERSION
	ooz_control_owner_record = -1
	syz_obj56_complete = false
	item_bonus_chain = 0
	act_complete = false
	requested_level_transition = Vector2i(-1, -1)
	s2_wfz_fire_toggle = false
	s2_wfz_bg_x_offset = 0
	s2_wfz_bg_y_offset = 0
	s2_wfz_wind_holding = false
	s2_wfz_wind_active = false
	s2_wfz_getaway_active = false
	s2_wfz_rivet_busted = false
	s2_wfz_layout_refresh_requested = false
	s2_wfz_background_refresh_requested = false
	s2_dez_mecha_spawned = false
	s2_dez_mecha_defeated = false
	s2_dez_c6_departed = false
	s2_dez_final_boss_active = false
	s2_dez_ending_active = false
	time_bonus = 0
	ring_bonus = 0
	tally_finished = false
	end_tally_state = 0
	end_tally_timer = 0
	big_ring_collected = false
	special_stage_requested = false
	elapsed_frames = 0
	time_over = false
	boss_status = 0
	boss_limit_right = 0x2960
	boss_object = null
	boss_screen_lock = false
	syz_boss_blocks.clear()
	syz_boss_blocks_spawned = false
	time_frozen = false
	water_enabled = false
	water_surface_y = 0
	water_actual_y = 0
	water_target_y = 0
	water_routine = 0
	s2_pipe_exit_frame = -1
	lz_wind_blockers.clear()
	lz3_layout_switch_f_applied = false
	lz_conveyor_reversed = false
	lz_conveyor_groups_loaded.clear()
	sbz_spin_groups_loaded.clear()
	sbz3_ancient_lift_claimed = false
	sbz_false_floor_object = null
	sbz_eggman_object = null
	sbz2_post_tally_started = false
	sbz2_post_tally_boundary_started = false
	fz_end_scroll_started = false
	final_ending_requested = false
	air_seconds = 30
	air_frame_timer = 0
	drown_display_timer = 0
	drown_restart_timer = 0
	drown_extra_remaining = -1
	drown_extra_delay = 0
	drown_number_pending = -1
	lz_water_surface_effect = null
	if not level_definition.is_empty():
		_initialize_lz_water()
	if clear_persistent:
		destroyed_records.clear()
		ring_masks.clear()
		broken_monitors.clear()
		rings = 0
		ring_life_flags = 0

func execute_objects() -> void:
	# Phase 74: a stood-on object must reaffirm support during this exact object
	# pass. This prevents a deleted/vanished/moved platform from leaving Sonic
	# attached to its previous-frame cached bounds.
	if player != null:
		player.begin_object_support_pass()

	# HUD_Update advances the level clock only while normal gameplay is active.
	# At 9:59:59 the original TimeOver path stops the clock and forces Sonic
	# into the ordinary death routine before the GAME/TIME OVER card is loaded.
	if not act_complete and not sbz2_post_tally_started and not special_stage_requested and not player.dead and not player.drowning and not player.debug_free_mode and not time_frozen:
		if not time_over:
			elapsed_frames += 1
			if elapsed_frames >= MAX_TIME_FRAMES:
				elapsed_frames = MAX_TIME_FRAMES
				time_over = true
				player.kill()

	if not player.dead:
		_tick_oscillators()

	if not cnz_special_bumpers.is_empty() and player != null and not player.dead:
		_tick_s2_cnz_special_bumpers()

	if bool(level_definition.get("s2_ooz", false)) and player != null and not player.dead:
		_tick_s2_ooz_oil()

	if bool(level_definition.get("s2_wfz", false)) and player != null and not player.dead:
		_tick_s2_wfz_wind_tunnel()

	if water_enabled:
		# Sonic 2 creates the same generic Obj04 water-surface objects for CPZ2.
		# Phase 93 only instantiated them for LZ, leaving CPZ water physically active
		# but visually unmarked. The effect selects zone-correct art internally.
		_ensure_lz_water_surface()
		_tick_lz_air_controller()

	for i in range(slots.size()):
		var obj = slots[i]
		if obj == null:
			continue
		if not is_instance_valid(obj):
			slots[i] = null
			continue
		if bool(level_definition.get("s2_mtz", false)):
			_wrap_object_to_camera_image(obj)
		if not obj.alive:
			active_records.erase(obj.record_index)
			obj.queue_free()
			slots[i] = null
			continue
		obj.tick()
		if not obj.alive:
			active_records.erase(obj.record_index)
			obj.queue_free()
			slots[i] = null

	for i in range(transient_objects.size() - 1, -1, -1):
		var transient = transient_objects[i]
		if transient == null or not is_instance_valid(transient):
			transient_objects.remove_at(i)
			continue
		if transient.has_method("tick"):
			transient.tick()
		if not transient.alive:
			if transient == boss_object:
				boss_object = null
			transient.queue_free()
			transient_objects.remove_at(i)

	if act_complete and not tally_finished:
		_tick_end_tally()

	if player != null:
		player.end_object_support_pass()


func _tick_s2_wfz_wind_tunnel() -> void:
	# NonWaterEffects -> WindTunnel. The final game has two authored rectangles:
	# $1510,$0400..$1AF0,$0580 and $20F0,$0618..$2500,$0680. While Sonic is
	# inside, the routine subtracts four pixels from X every frame, forces -$400
	# X velocity/zero Y velocity, and allows one-pixel Up/Down steering. ObjC1 can
	# set WindTunnel_holding_flag while Sonic is hanging from a breakaway panel.
	var p: SonicPlayer = player
	if p == null or p.dead or p.debug_free_mode:
		s2_wfz_wind_active = false
		return
	if s2_wfz_wind_holding:
		s2_wfz_wind_active = false
		return
	var px: int = p.pixel_x()
	var py: int = p.pixel_y()
	var inside: bool = (px >= 0x1510 and px < 0x1AF0 and py >= 0x0400 and py < 0x0580) or (px >= 0x20F0 and px < 0x2500 and py >= 0x0618 and py < 0x0680)
	if not inside:
		s2_wfz_wind_active = false
		return
	s2_wfz_wind_active = true
	p.clear_object_support()
	var target_y: int = py
	if p.input_up:
		target_y -= 1
	if p.input_down:
		target_y += 1
	p.force_set_pixel_position(px - 4, target_y)
	p.vel_x = -0x400
	p.vel_y = 0
	p.inertia = 1
	p.in_air = true
	p.rolling = false
	p.jumping = false

func _tick_s2_ooz_oil() -> void:
	# Retail Object $07 is created globally by GM_Level for OOZ rather than from
	# ObjectPlacement. It centers its $20-wide PlatformObject under Sonic every
	# frame, so the oil acts as an effectively continuous surface. objoff_38
	# starts at $30, decrements while Sonic owns the oil's standing bit, and is
	# passed as d3 (platform half-height): support therefore sinks one pixel per
	# frame from Y=$728 toward the object's Y=$758. Reaching zero kills Sonic.
	var p: SonicPlayer = player
	if p == null or p.debug_free_mode or p.dead:
		return
	var was_standing: bool = p.standing_on_object and p.support_record_index == S2_OOZ_OIL_SUPPORT_RECORD
	if was_standing:
		if ooz_oil_submersion <= 0:
			p.clear_object_support_for(S2_OOZ_OIL_SUPPORT_RECORD, false)
			p.kill()
			return
		ooz_oil_submersion -= 1
	elif ooz_oil_submersion < S2_OOZ_OIL_MAX_SUBMERSION:
		ooz_oil_submersion += 1
	var px: int = p.pixel_x()
	# LevEvents_OOZ2 moves the global Oil object from $758 to $2D8 once the
	# camera reaches $2668. The camera's new minimum X prevents backtracking, so
	# the screen-X threshold is a stable native equivalent of that one-time write.
	var oil_y: int = S2_OOZ_OIL_Y
	if int(level_definition.get("act", 1)) == 2 and current_screen_x >= 0x2668:
		oil_y = S2_OOZ2_BOSS_OIL_Y
	var top_y: int = oil_y - ooz_oil_submersion
	var left_x: int = px - S2_OOZ_OIL_WIDTH
	var right_x: int = px + S2_OOZ_OIL_WIDTH
	if was_standing:
		p.snap_supported_slope(left_x, right_x, top_y, S2_OOZ_OIL_SUPPORT_RECORD)
	else:
		p.resolve_platform_top(left_x, right_x, top_y, S2_OOZ_OIL_SUPPORT_RECORD)


func _tick_oscillators() -> void:
	_tick_s2_source_oscillators()
	var a = _osc_step(_osc_1a_value, _osc_1a_rate, _osc_1a_down, 8, 0x40)
	_osc_1a_value = int(a[0])
	_osc_1a_rate = int(a[1])
	_osc_1a_down = bool(a[2])
	var b = _osc_step(_osc_0e_value, _osc_0e_rate, _osc_0e_down, 2, 0x30)
	_osc_0e_value = int(b[0])
	_osc_0e_rate = int(b[1])
	_osc_0e_down = bool(b[2])
	var c = _osc_step(_osc_02_value, _osc_02_rate, _osc_02_down, 2, 0x10)
	_osc_02_value = int(c[0]); _osc_02_rate = int(c[1]); _osc_02_down = bool(c[2])
	var d = _osc_step(_osc_06_value, _osc_06_rate, _osc_06_down, 2, 0x18)
	_osc_06_value = int(d[0]); _osc_06_rate = int(d[1]); _osc_06_down = bool(d[2])
	var e = _osc_step(_osc_0a_value, _osc_0a_rate, _osc_0a_down, 2, 0x20)
	_osc_0a_value = int(e[0]); _osc_0a_rate = int(e[1]); _osc_0a_down = bool(e[2])
	var f = _osc_step(_osc_12_value, _osc_12_rate, _osc_12_down, 4, 0x20)
	_osc_12_value = int(f[0]); _osc_12_rate = int(f[1]); _osc_12_down = bool(f[2])
	var g = _osc_step(_osc_16_value, _osc_16_rate, _osc_16_down, 8, 0x08)
	_osc_16_value = int(g[0]); _osc_16_rate = int(g[1]); _osc_16_down = bool(g[2])
	var h = _osc_step(_osc_1e_value, _osc_1e_rate, _osc_1e_down, 4, 0x40)
	_osc_1e_value = int(h[0]); _osc_1e_rate = int(h[1]); _osc_1e_down = bool(h[2])
	var i22 = _osc_step(_osc_22_value, _osc_22_rate, _osc_22_down, 2, 0x50)
	_osc_22_value = int(i22[0]); _osc_22_rate = int(i22[1]); _osc_22_down = bool(i22[2])
	var i26 = _osc_step(_osc_26_value, _osc_26_rate, _osc_26_down, 2, 0x50)
	_osc_26_value = int(i26[0]); _osc_26_rate = int(i26[1]); _osc_26_down = bool(i26[2])

func _reset_s2_source_oscillators() -> void:
	# Exact Osc_Data copied by Sonic 2 OscillateNumInit.
	_s2_source_osc_pos = [0x0080,0x0080,0x0080,0x0080,0x0080,0x0080,0x0080,0x0080,0x0080,0x3848,0x2080,0x3080,0x5080,0x7080,0x0080,0x4000]
	_s2_source_osc_rate = [0,0,0,0,0,0,0,0,0,0x00EE,0x00B4,0x010E,0x01C2,0x0276,0,0x00FE]
	_s2_source_osc_down.clear()
	var control = 0x007D
	for i in range(16):
		# OscillateNumDo walks channels forward while DBF counts bits 15->0.
		_s2_source_osc_down.append((control & (1 << (15 - i))) != 0)

func _tick_s2_source_oscillators() -> void:
	if _s2_source_osc_pos.size() != 16:
		_reset_s2_source_oscillators()
	var accel: Array[int] = [2,2,2,2,4,8,8,4,2,2,2,3,5,7,2,2]
	var midpoint: Array[int] = [0x10,0x18,0x20,0x30,0x20,0x08,0x40,0x40,0x38,0x38,0x20,0x30,0x50,0x70,0x40,0x40]
	for i in range(16):
		var pos = _s2_source_osc_pos[i]
		var rate = _s2_source_osc_rate[i]
		var down = _s2_source_osc_down[i]
		if down:
			rate = GenesisMath.s16(rate - accel[i])
		else:
			rate = GenesisMath.s16(rate + accel[i])
		pos = (pos + rate) & 0xFFFF
		var public_byte = (pos >> 8) & 0xFF
		if down:
			if public_byte < midpoint[i]:
				down = false
		else:
			if public_byte >= midpoint[i]:
				down = true
		_s2_source_osc_pos[i] = pos
		_s2_source_osc_rate[i] = rate
		_s2_source_osc_down[i] = down

func s2_source_osc_byte(offset: int) -> int:
	if _s2_source_osc_pos.size() != 16:
		_reset_s2_source_oscillators()
	var channel = clampi(offset >> 2, 0, 15)
	return (_s2_source_osc_pos[channel] >> 8) & 0xFF

func s2_source_osc_word(offset: int) -> int:
	if _s2_source_osc_pos.size() != 16:
		_reset_s2_source_oscillators()
	var channel = clampi(offset >> 2, 0, 15)
	if (offset & 2) != 0:
		return _s2_source_osc_rate[channel]
	return _s2_source_osc_pos[channel]

func _osc_step(value: int, rate: int, down: bool, frequency: int, midpoint: int) -> Array:
	# Translation of one OscillateNumDo channel. The public byte is the high
	# byte of the 16-bit position accumulator; acceleration reverses at the
	# midpoint, which naturally carries the position through to both extremes.
	if down:
		rate = GenesisMath.s16(rate - frequency)
	else:
		rate = GenesisMath.s16(rate + frequency)
	value = (value + rate) & 0xFFFF
	var public_byte = (value >> 8) & 0xFF
	if down:
		# OscillateNumDo uses BLS while descending, so equality with the
		# midpoint remains in the down phase; it flips only once below it.
		if public_byte < midpoint:
			down = false
	else:
		if public_byte >= midpoint:
			down = true
	return [value, rate, down]

func oscillate_1a() -> int:
	return (_osc_1a_value >> 8) & 0xFF

func oscillate_0e() -> int:
	return (_osc_0e_value >> 8) & 0xFF

func oscillate_02() -> int:
	return (_osc_02_value >> 8) & 0xFF

func oscillate_06() -> int:
	return (_osc_06_value >> 8) & 0xFF

func oscillate_0a() -> int:
	return (_osc_0a_value >> 8) & 0xFF

func oscillate_12() -> int:
	return (_osc_12_value >> 8) & 0xFF

func oscillate_16() -> int:
	return (_osc_16_value >> 8) & 0xFF

func oscillate_1e() -> int:
	return (_osc_1e_value >> 8) & 0xFF

func oscillate_22() -> int:
	return (_osc_22_value >> 8) & 0xFF

func oscillate_26() -> int:
	return (_osc_26_value >> 8) & 0xFF

func mark_s2_pipe_exit_frame() -> void:
	s2_pipe_exit_frame = elapsed_frames

func s2_pipe_exit_blocked_this_frame() -> bool:
	# Obj7B proximity animation begins with mapping frame 1, and Obj7B_Main skips
	# SolidObject for that frame. It lasts six VBlanks, giving a character released
	# from Obj1E time to emerge through the cover before it becomes solid again.
	# Object-slot order can make Obj7B run before Obj1E on the release VBlank, so
	# preserve that six-frame non-solid window explicitly instead of only blocking
	# the exact release frame. This prevents the underside from resolving as a side
	# hit and nudging Sonic left/right as he pops out in a ball.
	if s2_pipe_exit_frame < 0:
		return false
	var age = elapsed_frames - s2_pipe_exit_frame
	return age >= 0 and age <= 6

func set_switch_pressed(index: int, pressed: bool) -> void:
	if pressed:
		switch_flags[index & 0x0F] = true
	else:
		switch_flags.erase(index & 0x0F)

func is_switch_pressed(index: int) -> bool:
	return bool(switch_flags.get(index & 0x0F, false))

func set_switch_alt(index: int, enabled: bool) -> void:
	if enabled:
		switch_alt_flags[index & 0x0F] = true
	else:
		switch_alt_flags.erase(index & 0x0F)

func is_switch_alt(index: int) -> bool:
	return bool(switch_alt_flags.get(index & 0x0F, false))

func set_lz_wind_blocker(key: int, blocked: bool) -> void:
	if blocked:
		lz_wind_blockers[key] = true
	else:
		lz_wind_blockers.erase(key)

func is_lz_wind_disallowed() -> bool:
	return not lz_wind_blockers.is_empty()

func apply_lz_water_features() -> void:
	# Source LZWaterFeatures executes before ExecuteObjects/Sonic. Keep that order
	# so tunnels use the prior sampled jpadhold2 state and slides can set inertia
	# before Sonic_Modes runs.
	if not water_enabled or player == null:
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_LZ:
		return
	_apply_lz_wind_tunnels()
	_apply_lz_water_slides()

func _apply_lz_wind_tunnels() -> void:
	if player.debug_free_mode:
		return
	var act = clampi(int(level_definition.get("act", 1)), 1, 4)
	var regions: Array[Rect2i] = []
	match act:
		1:
			regions = [Rect2i(0xA80, 0x300, 0xC10 - 0xA80, 0x380 - 0x300), Rect2i(0xF80, 0x100, 0x1410 - 0xF80, 0x180 - 0x100)]
		2:
			regions = [Rect2i(0x460, 0x400, 0x710 - 0x460, 0x480 - 0x400)]
		3:
			regions = [Rect2i(0xA20, 0x600, 0x1610 - 0xA20, 0x6E0 - 0x600)]
		4:
			regions = [Rect2i(0xC80, 0x600, 0x13D0 - 0xC80, 0x680 - 0x600)]
	var px := player.pixel_x()
	var py := player.pixel_y()
	var active_region: Rect2i
	var found := false
	for region in regions:
		if px >= region.position.x and px < region.position.x + region.size.x and py >= region.position.y and py < region.position.y + region.size.y:
			active_region = region
			found = true
			break
	if not found:
		if player.wind_tunnel_mode:
			player.wind_tunnel_mode = false
		return
	# The original returns immediately while disabled; if the tunnel was already
	# active its mode flag is intentionally left untouched until normal exit.
	if is_lz_wind_disallowed():
		return
	if player.hurt_state or player.dead or player.drowning:
		player.wind_tunnel_mode = false
		return
	player.wind_tunnel_mode = true
	if px < active_region.position.x + 128:
		player.force_add_pixel_offset(0, -2 if act == 2 else 2)
	player.force_add_pixel_offset(4, 0)
	player.vel_x = 0x400
	player.vel_y = 0
	player.in_air = true
	player.roll_jump_lock = false
	if player.input_up and player.pixel_y() > active_region.position.y:
		player.force_add_pixel_offset(0, -1)
	if player.input_down:
		player.force_add_pixel_offset(0, 1)

func _apply_lz_water_slides() -> void:
	if player.in_air:
		if player.water_slide_mode:
			player.lock_time = 5
			player.water_slide_mode = false
		return
	var chunk_id = player.level.get_chunk_id_at(player.pixel_x() >> 8, player.pixel_y() >> 8) if player.level != null else -1
	var chunks: Array[int] = [2, 7, 3, 0x4C, 0x4B, 8, 4]
	var speeds: Array[int] = [0xA00, -0xB00, 0xA00, -0xA00, -0xB00, -0xC00, 0xB00]
	var slide_index := chunks.find(chunk_id)
	if slide_index < 0:
		if player.water_slide_mode:
			player.lock_time = 5
			player.water_slide_mode = false
		return
	player.inertia = speeds[slide_index]
	player.facing_left = player.inertia < 0
	player.water_slide_mode = true

func spawn_lz_conveyor_group(group_id: int) -> void:
	if group_id < 0 or group_id > 5 or lz_conveyor_groups_loaded.has(group_id):
		return
	lz_conveyor_groups_loaded[group_id] = true
	var names: Array[String] = ["lz1pf1.bin", "lz1pf2.bin", "lz2pf1.bin", "lz2pf2.bin", "lz3pf1.bin", "lz3pf2.bin"]
	var path = "res://data/s1/objpos/platforms/" + names[group_id]
	if not FileAccess.file_exists(path):
		push_error("Phase 33: missing original LZ conveyor platform data: %s" % path)
		return
	var data = FileAccess.get_file_as_bytes(path)
	if data.size() < 2:
		return
	var count = ((int(data[0]) << 8) | int(data[1])) + 1
	var offset = 2
	for child_index in range(count):
		if offset + 5 >= data.size():
			break
		var world_x = (int(data[offset]) << 8) | int(data[offset + 1])
		var world_y = (int(data[offset + 2]) << 8) | int(data[offset + 3])
		var platform_subtype = (int(data[offset + 4]) << 8) | int(data[offset + 5])
		offset += 6
		var platform = LZProgressionObjectClass.new()
		platform.name = "LZConveyor_%d_%02d" % [group_id, child_index]
		add_child(platform)
		platform.setup_conveyor_platform(self, world_x, world_y, platform_subtype, group_id, child_index)
		transient_objects.append(platform)

func spawn_sbz_spin_conveyor_group(group_id: int) -> void:
	if group_id < 0 or group_id > 5 or sbz_spin_groups_loaded.has(group_id):
		return
	sbz_spin_groups_loaded[group_id] = true
	var path = "res://data/s1/objpos/platforms/sbz1pf%d.bin" % (group_id + 1)
	if not FileAccess.file_exists(path):
		push_error("Phase 42: missing original SBZ spin-conveyor platform data: %s" % path)
		return
	var data = FileAccess.get_file_as_bytes(path)
	if data.size() < 2:
		return
	var count = ((int(data[0]) << 8) | int(data[1])) + 1
	var offset = 2
	for child_index in range(count):
		if offset + 5 >= data.size():
			break
		var world_x = (int(data[offset]) << 8) | int(data[offset + 1])
		var world_y = (int(data[offset + 2]) << 8) | int(data[offset + 3])
		var platform_subtype = (int(data[offset + 4]) << 8) | int(data[offset + 5])
		offset += 6
		var platform = SBZProgressionObjectClass.new()
		platform.name = "SBZSpinConveyor_%d_%02d" % [group_id, child_index]
		add_child(platform)
		platform.setup_spin_conveyor_platform(self, world_x, world_y, platform_subtype, group_id, child_index)
		transient_objects.append(platform)

func _initialize_lz_water() -> void:
	var zone = int(level_definition.get("zone", -1))
	var cpz2_water = bool(level_definition.get("s2_cpz_water", false))
	var s2_static_water = int(level_definition.get("s2_static_water_y", -1))
	water_enabled = zone == LevelCatalog.ZONE_LZ or cpz2_water or s2_static_water >= 0
	water_routine = 0
	if not water_enabled:
		water_surface_y = 0
		water_actual_y = 0
		water_target_y = 0
		return
	if cpz2_water:
		# Retail WaterHeight: CPZ2 begins at $710 and DynamicWaterCPZ2
		# changes Water_Level_3 to $510 once Camera_X_pos reaches $1DE0.
		water_surface_y = 0x710
		water_actual_y = 0x710
		water_target_y = 0x710
		return
	if s2_static_water >= 0:
		# Retail ARZ uses DynamicWaterNull: WaterHeight supplies the level's fixed
		# surface ($410 in Act 1) and the normal underwater controller consumes it.
		water_surface_y = s2_static_water
		water_actual_y = s2_static_water
		water_target_y = s2_static_water
		return
	var act = clampi(int(level_definition.get("act", 1)), 1, 4)
	var initial = [0x0B8, 0x328, 0x900, 0x228][act - 1]
	water_surface_y = initial
	water_actual_y = initial
	water_target_y = initial

func get_lz_water_y():
	return water_surface_y if water_enabled else null

func update_lz_water(screen_x: int) -> void:
	# LZWaterFeatures/LZDynamicWater runs before Sonic each frame. The target is
	# hard-coded per act; v_waterpos2 approaches it by one pixel per frame, and
	# v_waterpos1 adds half of oscillation channel $02 for the visible surface.
	if not water_enabled or player == null:
		return
	if bool(level_definition.get("s2_cpz_water", false)):
		water_target_y = 0x510 if screen_x >= 0x1DE0 else 0x710
		if water_actual_y < water_target_y:
			water_actual_y += 1
		elif water_actual_y > water_target_y:
			water_actual_y -= 1
		water_surface_y = water_actual_y + (s2_source_osc_byte(0x00) >> 1)
		return
	var s2_static_water = int(level_definition.get("s2_static_water_y", -1))
	if s2_static_water >= 0:
		water_target_y = s2_static_water
		water_actual_y = s2_static_water
		water_surface_y = s2_static_water
		return
	var act = clampi(int(level_definition.get("act", 1)), 1, 4)
	match act:
		1: _update_lz1_water_target(screen_x, player.pixel_y())
		2: _update_lz2_water_target(screen_x)
		3:
			_update_lz3_water_target(screen_x, player.pixel_y())
			_update_lz3_layout_mutation()
		4:
			# DynWater_SBZ3: high water until camera X $F00, then lower it.
			water_target_y = 0x4C8 if screen_x >= 0xF00 else 0x228
	if water_actual_y < water_target_y:
		water_actual_y += 1
	elif water_actual_y > water_target_y:
		water_actual_y -= 1
	water_surface_y = water_actual_y + (oscillate_02() >> 1)

func _update_lz1_water_target(screen_x: int, sonic_y: int) -> void:
	if water_routine == 0:
		var target := 0x0B8
		if screen_x >= 0x600:
			target = 0x108
			if sonic_y < 0x200:
				if screen_x >= 0xC80:
					target = 0x0E8
				if screen_x >= 0x1500:
					target = 0x108
			else:
				if screen_x >= 0xC00:
					target = 0x318
				if screen_x >= 0x1080:
					# DynWater_LZ1 writes $80 to switch 5 to close the $1118/$5A0
					# door after Sonic has passed it. Guard the original camera threshold
					# with the authored door X so native viewport behavior cannot close it
					# immediately while Sonic is still approaching from the left.
					if player.pixel_x() >= 0x1118:
						set_switch_pressed(5, false)
						set_switch_alt(5, true)
					target = 0x5C8
				if screen_x >= 0x1380:
					target = 0x3A8
					if water_actual_y == target:
						water_routine = 1
		water_target_y = target
		return
	if water_routine == 1:
		if sonic_y >= 0x2E0:
			return
		water_target_y = 0x3A8
		if screen_x >= 0x1300:
			water_target_y = 0x108
			water_routine = 2

func _update_lz2_water_target(screen_x: int) -> void:
	var target := 0x328
	if screen_x >= 0x500:
		target = 0x3C8
	if screen_x >= 0xB00:
		target = 0x428
	water_target_y = target

func _update_lz3_water_target(screen_x: int, sonic_y: int) -> void:
	# REV01 dynamic-water state machine. The one foreground-layout mutation at
	# row 2/column 6 is left to the level-data mutation pass; water timing itself
	# follows the source values here.
	match water_routine:
		0:
			var target := 0x900
			if screen_x >= 0x600 and sonic_y >= 0x3C0 and sonic_y < 0x600:
				target = 0x4C8
				water_routine = 1
			water_target_y = target
			water_actual_y = target
		1:
			var target := 0x4C8
			if screen_x >= 0x770:
				target = 0x308
			if screen_x >= 0x1400:
				var enter_end := water_target_y == 0x508 or sonic_y >= 0x600 or sonic_y < 0x280
				if enter_end:
					target = 0x508
					water_actual_y = target
					if screen_x >= 0x1770:
						water_routine = 2
			water_target_y = target
		2:
			var target := 0x508
			if screen_x >= 0x1860:
				target = 0x188
			if screen_x >= 0x1AF0 or water_actual_y == 0x188:
				water_routine = 3
			water_target_y = target
		3:
			var target := 0x188
			if screen_x >= 0x1AF0:
				target = 0x900
			if screen_x >= 0x1BC0:
				water_routine = 4
				water_target_y = 0x608
				water_actual_y = 0x7C0
				set_switch_pressed(8, true)
				return
			water_target_y = target
			water_actual_y = target
		4:
			# REV01 (without the optional FixBugs build flag) uses $1E00.
			if screen_x >= 0x1E00:
				water_target_y = 0x128

func _update_lz3_layout_mutation() -> void:
	if lz3_layout_switch_f_applied or player == null or player.level == null:
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_LZ or int(level_definition.get("act", 0)) != 3:
		return
	if not is_switch_pressed(0x0F):
		return
	# DLE_LZ3 changes foreground row 2 / column 6 to chunk $07 when switch $F
	# is pressed. Collision and rendering must change together.
	player.level.set_chunk_id_at(6, 2, 0x07)
	lz3_layout_switch_f_applied = true
	var scene = get_tree().current_scene
	if scene != null and scene.has_method("refresh_level_chunk"):
		scene.call("refresh_level_chunk", 6, 2)

func has_push_block_on_button(x: int, y: int) -> bool:
	# But_MZBlock compares the 16x16 push-block radius against a 32x16 region
	# beginning at button (x-16,y-8). Use the equivalent rectangle overlap so
	# the MZ1 block reliably presses the special subtype-$80 switch.
	var button_left = x - 16
	var button_right = x + 16
	# The 68000 overlap helper treats edge/carry cases inclusively. The native
	# block/platform alignment can stop a few pixels shy of the rendered button,
	# so include a four-pixel vertical tolerance while preserving the source
	# 32x16 detection footprint.
	var button_top = y - 12
	var button_bottom = y + 12
	for obj in slots:
		if obj == null or not is_instance_valid(obj) or not obj.alive or obj.object_id != 0x33:
			continue
		var half_w = int(obj.active_width)
		var block_left = int(obj.position.x) - half_w
		var block_right = int(obj.position.x) + half_w
		var block_top = int(obj.position.y) - 16
		var block_bottom = int(obj.position.y) + 16
		if block_right >= button_left and block_left <= button_right and block_bottom >= button_top and block_top <= button_bottom:
			return true
	return false

func mz1_stomper_support(world_x: int) -> Dictionary:
	# Original PushB_Action special case: the MZ1 block rides the active spiked
	# stomper while its X coordinate is within $A20..$AA0. v_obj31ypos is the
	# main stomper block's current Y; here we recover it from the native slot.
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_MZ or int(level_definition.get("act", -1)) != 1:
		return {"found": false}
	if world_x < 0xA20 or world_x >= 0xAA1:
		return {"found": false}
	for obj in slots:
		if obj == null or not is_instance_valid(obj) or not obj.alive:
			continue
		if obj.object_id == 0x31:
			return {"found": true, "y": int(obj.position.y)}
	return {"found": false}

func mz1_push_block_on_stomper() -> bool:
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_MZ or int(level_definition.get("act", -1)) != 1:
		return false
	for obj in slots:
		if obj == null or not is_instance_valid(obj) or not obj.alive or obj.object_id != 0x33:
			continue
		var x = int(obj.position.x)
		if x >= 0xA20 and x < 0xAA1:
			return true
	return false

func obj_pos_load(screen_x: int, screen_y: int = 0) -> void:
	current_screen_x = screen_x
	current_screen_y = screen_y
	# Original OPL only reevaluates when v_screenposx crosses a $80 boundary.
	var screen_block: int = screen_x & 0xFF80
	if screen_block != _previous_screen_block:
		var previous_block: int = _previous_screen_block
		_previous_screen_block = screen_block
		var left: int = maxi(0, screen_block - int(SPAWN_LEFT))
		var right: int = screen_block + int(SPAWN_RIGHT)
		# Retail ObjectsManager advances left/right placement pointers and only
		# considers records that crossed a spawn edge. Re-scanning the complete
		# current window made moving SCZ badniks reappear at their authored X as
		# soon as their moving instance deleted behind the screen. Use directional
		# edge loading for auto-scroll zones (SCZ and WFZ), while preserving the
		# long-established full-window path for earlier ported zones.
		if bool(level_definition.get("s2_directional_objpos", false)) and previous_block >= 0:
			if screen_block > previous_block:
				left = previous_block + SPAWN_RIGHT
				right = screen_block + SPAWN_RIGHT
			elif screen_block < previous_block:
				left = maxi(0, screen_block - SPAWN_LEFT)
				right = maxi(0, previous_block - SPAWN_LEFT)
		for record in records:
			var x = int(record["x"])
			if x < left:
				continue
			if x >= right:
				break
			var index = int(record["index"])
			if active_records.has(index) or is_record_destroyed(index):
				continue
			_spawn_record(record)

	# Object-specific RememberState/out_of_range calls are represented centrally
	# here so scarce 96-slot behavior remains testable while objects are ported.
	var despawn_left = screen_x - DESPAWN_LEFT
	var despawn_right = screen_x + DESPAWN_RIGHT
	for i in range(slots.size()):
		var obj = slots[i]
		if obj == null or not is_instance_valid(obj):
			continue
		# Object $4E explicitly suppresses out_of_range deletion after the lava
		# wall starts advancing; otherwise ObjPosLoad could erase the hazard mid-chase.
		if obj is MZLavaWallObject and (obj as MZLavaWallObject).moving:
			continue
		# A few source routines intentionally skip RememberState.  Most notably,
		# Roller waits invisibly for Sonic to pass its $100 activation distance;
		# unloading it by the generic record window here makes that impossible.
		if obj.suppress_central_despawn():
			continue
		# PushB_Display checks the block's CURRENT X first.  Using only the authored
		# object-placement X caused an Act 2 lava-riding block to despawn midway
		# through its ride even though the moved block was still beside the camera.
		var range_x = obj.central_despawn_x()
		if obj is MarbleObject and obj.object_id == 0x33:
			range_x = int(obj.position.x)
		if range_x < despawn_left or range_x >= despawn_right:
			active_records.erase(obj.record_index)
			obj.queue_free()
			slots[i] = null

func mark_record_destroyed(index: int) -> void:
	destroyed_records[index] = true

func is_record_destroyed(index: int) -> bool:
	return destroyed_records.has(index)

func mark_monitor_broken(index: int) -> void:
	broken_monitors[index] = true

func is_monitor_broken(index: int) -> bool:
	return broken_monitors.has(index)

func get_ring_mask(index: int) -> int:
	return int(ring_masks.get(index, 0))

func collect_ring(index: int, bit_index: int) -> void:
	var mask = get_ring_mask(index)
	var bit = 1 << bit_index
	if (mask & bit) != 0:
		return
	ring_masks[index] = mask | bit
	add_rings(1)

func add_rings(amount: int) -> void:
	if amount > 0:
		SonicAudio.play_ring_sfx()
	rings = clampi(rings + amount, 0, 999)
	_update_ring_life_awards()

func spill_player_rings(x: int, y: int) -> void:
	if rings <= 0:
		return
	var count = mini(rings, 32)
	var spill = RingLossObject.new()
	spill.name = "RingLoss"
	spill.z_index = 45
	add_child(spill)
	spill.setup(self, x, y, count)
	transient_objects.append(spill)
	rings = 0
	ring_life_flags = 0

func add_score(points: int) -> void:
	# AddPoints caps the visible Sonic 1 score at 9,999,990.
	score = clampi(score + points, 0, 9999990)

func register_badnik_hit() -> int:
	var award: int
	match mini(item_bonus_chain, 3):
		0:
			award = 100
		1:
			award = 200
		2:
			award = 500
		_:
			award = 1000
	item_bonus_chain += 1
	if item_bonus_chain >= 16:
		award = 10000
	add_score(award)
	return award

func reset_item_bonus() -> void:
	item_bonus_chain = 0

func _update_ring_life_awards() -> void:
	if rings >= 100 and (ring_life_flags & 0x02) == 0:
		ring_life_flags |= 0x02
		lives += 1
		SonicAudio.play_jingle(SonicAudio.MUS_EXTRA_LIFE)
	if rings >= 200 and (ring_life_flags & 0x04) == 0:
		ring_life_flags |= 0x04
		lives += 1
		SonicAudio.play_jingle(SonicAudio.MUS_EXTRA_LIFE)


func activate_checkpoint(lamp_id: int, x: int, y: int) -> void:
	if lamp_id <= checkpoint_id:
		return
	checkpoint_id = lamp_id
	SonicAudio.play_sfx(SonicAudio.SFX_LAMPPOST)
	checkpoint_position = Vector2i(x, y)
	checkpoint_frames = elapsed_frames

func has_checkpoint() -> bool:
	return checkpoint_id >= 0

func clear_checkpoint() -> void:
	checkpoint_id = -1
	checkpoint_position = Vector2i.ZERO
	checkpoint_frames = 0

func begin_sbz2_post_tally() -> void:
	# Object $3A's SBZ2 branch first sends every card element back toward its
	# original off-screen X.  Control/FZ music/boundary motion begin only after
	# the ring-bonus controller reaches its final X.
	if sbz2_post_tally_started:
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SBZ or int(level_definition.get("act", 0)) != 2:
		return
	sbz2_post_tally_started = true
	sbz2_post_tally_boundary_started = false
	act_complete = false
	tally_finished = false
	end_tally_state = 0
	end_tally_timer = 0

func complete_sbz2_card_move_out() -> void:
	if not sbz2_post_tally_started or sbz2_post_tally_boundary_started:
		return
	sbz2_post_tally_boundary_started = true
	SonicAudio.play_music(SonicAudio.MUS_FINAL_ZONE)
	if player != null:
		player.control_locked = false

func request_level_transition(zone: int, act: int) -> void:
	if requested_level_transition.x >= 0:
		return
	requested_level_transition = Vector2i(zone, act)

func begin_act_complete() -> void:
	if act_complete:
		return
	act_complete = true
	var total_seconds = elapsed_frames / 60
	var bonus_index = mini(20, int(total_seconds / 15))
	time_bonus = TIME_BONUSES[bonus_index]
	ring_bonus = rings * 100
	tally_finished = false
	# The three-second Object $3A wait starts when the RING BONUS sprite reaches
	# its main X-position, not when the signpost first creates the card.
	end_tally_state = 0
	end_tally_timer = 0

func begin_end_tally_wait() -> void:
	if not act_complete or end_tally_state != 0:
		return
	end_tally_state = 1
	end_tally_timer = 3 * 60

func _tick_end_tally() -> void:
	match end_tally_state:
		1:
			end_tally_timer -= 1
			if end_tally_timer <= 0:
				end_tally_state = 2
		2:
			var award = 0
			if time_bonus > 0:
				var amount = mini(100, time_bonus)
				time_bonus -= amount
				award += amount
			if ring_bonus > 0:
				var amount = mini(100, ring_bonus)
				ring_bonus -= amount
				award += amount
			if award > 0:
				add_score(award)
				# Got_Bonus plays the switch blip on v_vblank_byte & 3 == 0.
				if (Engine.get_physics_frames() & 3) == 0:
					SonicAudio.play_sfx(SonicAudio.SFX_SWITCH)
			else:
				SonicAudio.play_sfx(SonicAudio.SFX_CASH)
				end_tally_state = 3
				end_tally_timer = 3 * 60
		3:
			end_tally_timer -= 1
			if end_tally_timer <= 0:
				end_tally_state = 4
				tally_finished = true
		4:
			tally_finished = true

func _wrap_object_to_camera_image(obj: GenesisLevelObject) -> void:
	# Sonic 2 MTZ uses the same top=-$100/bottom=$800 toroidal Y space as the
	# collision/camera code. ObjPosLoad is horizontal-only, so without this step
	# records authored near $7xx (for example the bolt/spikes beside $1340) stay
	# physically at the bottom while terrain is being viewed through its top copy.
	var vh: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var center_y: int = current_screen_y + (vh >> 1)
	var oy: int = int(round(obj.position.y))
	var delta_y: int = 0
	while oy + delta_y - center_y > 0x400:
		delta_y -= 0x800
	while oy + delta_y - center_y < -0x400:
		delta_y += 0x800
	if delta_y != 0:
		obj.apply_vertical_wrap_shift(delta_y)

func is_world_x_on_screen(world_x: int, margin: int = 32) -> bool:
	return world_x >= current_screen_x - margin and world_x < current_screen_x + ProjectSettings.get_setting("display/window/size/viewport_width") + margin

func is_world_point_on_screen(world_x: int, world_y: int, margin: int = 32) -> bool:
	# OPL itself is intentionally horizontal just like Sonic 2, but many enemy
	# routines gate attack/animation work on render_flags. This helper recreates
	# that visible-screen test for native adapters without changing object loading.
	var vw: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	return world_x >= current_screen_x-margin and world_x < current_screen_x+vw+margin and world_y >= current_screen_y-margin and world_y < current_screen_y+vh+margin



func _ensure_lz_water_surface() -> void:
	if lz_water_surface_effect != null and is_instance_valid(lz_water_surface_effect) and lz_water_surface_effect.alive:
		return
	var surface = LZWaterSurfaceEffectClass.new()
	surface.name = "LZWaterSurface"
	add_child(surface)
	surface.setup(self)
	transient_objects.append(surface)
	lz_water_surface_effect = surface

func spawn_lz_splash(world_x: int) -> void:
	if not water_enabled or int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_LZ:
		return
	var splash = LZWaterSplashEffectClass.new()
	splash.name = "LZWaterSplash"
	add_child(splash)
	splash.setup(self, world_x)
	transient_objects.append(splash)

func spawn_lz_bubble(world_x: int, world_y: int, type_id: int, angle_seed: int = -1) -> void:
	if not water_enabled:
		return
	var bubble = LZBubbleObjectClass.new()
	bubble.name = "LZBubble"
	bubble.z_index = 125
	add_child(bubble)
	bubble.setup_bubble(self, world_x, world_y, type_id, angle_seed)
	transient_objects.append(bubble)

func spawn_lz_drown_number(value: int, angle_seed: int = -1) -> void:
	if player == null:
		return
	var number = LZDrownNumberEffectClass.new()
	number.name = "LZDrownNumber_%d" % value
	var x_offset = -6 if player.facing_left else 6
	var source_angle = angle_seed if angle_seed >= 0 else (0x40 if player.facing_left else 0)
	add_child(number)
	number.setup(self, player.pixel_x() + x_offset, player.pixel_y(), value, source_angle)
	transient_objects.append(number)

func replenish_lz_air() -> void:
	if SonicAudio.current_music_id() == SonicAudio.MUS_DROWNING:
		_resume_music_after_drowning_countdown()
	air_seconds = 30
	air_frame_timer = 59
	drown_display_timer = 0
	drown_restart_timer = 0
	drown_extra_remaining = -1
	drown_extra_delay = 0
	drown_number_pending = -1

func _tick_lz_air_controller() -> void:
	if player == null:
		return
	_tick_drown_extra_bubbles()
	if player.dead:
		return
	if player.drowning:
		drown_restart_timer -= 1
		if drown_restart_timer <= 0:
			player.finish_drowning_death()
		return
	if not player.underwater:
		if air_seconds != 30 or air_frame_timer != 0:
			replenish_lz_air()
			# The source controller is recreated on the next water entry.
			air_frame_timer = 0
		return
	air_frame_timer -= 1
	if air_frame_timer >= 0:
		return
	air_frame_timer = 59

	# Object $0A checks current v_air, schedules countdown bubbles, then
	# decrements it once per second. Its subtype is $81 in Sonic_Water.
	var show_number = false
	# Drown_Countdown compares v_air before reducing it. The retail driver plays
	# warning chimes at 25/20/15 and starts Mus92 exactly at 12 seconds.
	if air_seconds == 25 or air_seconds == 20 or air_seconds == 15:
		SonicAudio.play_sfx(SonicAudio.SFX_DROWN_WARNING)
	elif air_seconds == 12:
		SonicAudio.play_music(SonicAudio.MUS_DROWNING)
	if air_seconds <= 12:
		drown_display_timer -= 1
		if drown_display_timer < 0:
			drown_display_timer = 1
			show_number = true
	air_seconds -= 1

	# Source spawns one or two mouth bubbles each second.
	drown_extra_remaining = next_random_word() & 1
	drown_extra_delay = 0
	if show_number and air_seconds >= 0:
		drown_number_pending = clampi(air_seconds >> 1, 0, 5)

	if air_seconds >= 0:
		return
	drown_restart_timer = 2 * 60
	drown_extra_remaining = 10 # source value spawns entries 10 through 0
	drown_extra_delay = 0
	_resume_music_after_drowning_countdown()
	SonicAudio.play_sfx(SonicAudio.SFX_DROWN_DEATH)
	player.begin_drowning()

func _resume_music_after_drowning_countdown() -> void:
	# ResumeMusic selects the active override first, then boss music, otherwise
	# LZ (or SBZ for the hidden LZ4/SBZ3 corridor).
	if player != null and player.invincible_timer > 0:
		SonicAudio.play_music(SonicAudio.MUS_INVINCIBLE)
	elif boss_object != null and is_instance_valid(boss_object) and boss_status < 1:
		SonicAudio.play_music(SonicAudio.MUS_BOSS)
	elif bool(level_definition.get("internal_sbz3", false)):
		SonicAudio.play_music(SonicAudio.MUS_SBZ)
	else:
		SonicAudio.play_music(SonicAudio.MUS_LZ)

func _tick_drown_extra_bubbles() -> void:
	if drown_extra_remaining < 0 or player == null:
		return
	drown_extra_delay -= 1
	if drown_extra_delay >= 0:
		return
	drown_extra_delay = next_random_word() & (7 if player.drowning else 15)
	var x_offset = -6 if player.facing_left else 6
	var bubble_y = player.pixel_y() - (12 if player.drowning else 0)

	# Drown_Countdown uses the same 1-2 extra-bubble group for number bubbles.
	# Each member gets a 1/4 chance to become the number, with a forced fallback
	# on the final member so exactly one countdown number appears when requested.
	if not player.drowning and drown_number_pending >= 0:
		if (next_random_word() & 3) == 0 or drown_extra_remaining == 0:
			var number_angle = 0x40 if player.facing_left else 0
			spawn_lz_drown_number(drown_number_pending, number_angle)
			drown_number_pending = -1
			drown_extra_remaining -= 1
			return

	var type_id = 0
	var angle_seed = 0x40 if player.facing_left else 0
	if player.drowning:
		angle_seed = next_random_word() & 0xFF
		if (elapsed_frames & 3) == 0:
			type_id = 1
	spawn_lz_bubble(player.pixel_x() + x_offset, bubble_y, type_id, angle_seed)
	drown_extra_remaining -= 1

func spawn_monitor_explosion(x: int, y: int) -> void:
	_spawn_explosion(x, y)

func spawn_boss_explosion(x: int, y: int) -> void:
	_spawn_explosion(x, y)

func spawn_boss_explosion_front(x: int, y: int) -> void:
	# Object $58 uses the Genesis high-priority art bit. Normal terrain high
	# priority is project Z=100, so C7's defeat explosions need to clear it.
	_spawn_explosion_at_z(x, y, 130)

func spawn_badnik_destruction(x: int, y: int, points: int) -> void:
	# ExItem_Animal: enemy explosions create an animal. The animal in turn creates
	# Object $29 points using the combo frame carried through Object $27.
	_spawn_explosion(x, y)
	var animal = AnimalObjectClass.new()
	animal.name = "Animal"
	animal.z_index = 35
	add_child(animal)
	animal.setup(self, x, y, _next_zone_animal_id())
	transient_objects.append(animal)
	var popup = PointsObjectClass.new()
	popup.name = "Points"
	popup.z_index = 56
	add_child(popup)
	popup.setup(x, y, points)
	transient_objects.append(popup)

func _spawn_explosion(x: int, y: int) -> void:
	_spawn_explosion_at_z(x, y, 56)

func _spawn_explosion_at_z(x: int, y: int, draw_z: int) -> void:
	var explosion = ExplosionEffectClass.new()
	explosion.name = "Explosion"
	explosion.z_index = draw_z
	add_child(explosion)
	explosion.setup(x, y)
	transient_objects.append(explosion)

func next_random_word() -> int:
	# Sonic 1 RandomNumber. Return d0's low word and preserve the 32-bit seed.
	var d1 = _random_seed & 0xFFFFFFFF
	if d1 == 0:
		d1 = 0x2A6D365A
	var d0 = d1
	d1 = ((d1 << 2) + d0) & 0xFFFFFFFF
	d1 = ((d1 << 3) + d0) & 0xFFFFFFFF
	d0 = ((d1 & 0xFFFF) + ((d1 >> 16) & 0xFFFF)) & 0xFFFF
	d1 = ((d0 << 16) | (d1 & 0xFFFF)) & 0xFFFFFFFF
	_random_seed = d1
	return d0

func _next_zone_animal_id() -> int:
	# Anml_FromEnemy uses d0 bit 0 from the shared RandomNumber sequence.
	var d0 = next_random_word()
	# Anml_VarIndex: GHZ 0/5, LZ 2/3, MZ 6/3, SLZ 4/5, SYZ 4/1, SBZ 0/1.
	var zone = int(level_definition.get("zone", LevelCatalog.ZONE_GHZ))
	var animal_pairs = [[0,5], [2,3], [6,3], [4,5], [4,1], [0,1]]
	var pair = animal_pairs[clampi(zone, 0, animal_pairs.size() - 1)]
	return int(pair[d0 & 1])

func spawn_monitor_powerup(x: int, y: int, subtype: int) -> void:
	var powerup = PowerUpObjectClass.new()
	powerup.name = "MonitorPowerUp"
	powerup.z_index = 55
	add_child(powerup)
	powerup.setup(self, x, y, subtype)
	transient_objects.append(powerup)

func spawn_ball_hog_cannonball(x: int, y: int, horizontal_velocity: int, seconds: int) -> void:
	var projectile = BadnikProjectileClass.new()
	projectile.name = "BallHogCannonball"
	projectile.z_index = 43
	add_child(projectile)
	projectile.setup_ball_hog(self, x, y, horizontal_velocity, seconds)
	transient_objects.append(projectile)

func spawn_plain_explosion(x: int, y: int) -> void:
	_spawn_explosion(x, y)

func spawn_crab_projectile(x: int, y: int, horizontal_velocity: int) -> void:
	var projectile = BadnikProjectileClass.new()
	projectile.name = "CrabProjectile"
	projectile.z_index = 42
	add_child(projectile)
	projectile.setup_crab(self, x, y, horizontal_velocity)
	transient_objects.append(projectile)

func spawn_buzz_missile(x: int, y: int, horizontal_velocity: int, parent: GenesisLevelObject) -> void:
	var projectile = BadnikProjectileClass.new()
	projectile.name = "BuzzMissile"
	projectile.z_index = 42
	add_child(projectile)
	projectile.setup_buzz(self, x, y, horizontal_velocity, parent)
	transient_objects.append(projectile)

func spawn_newtron_missile(x: int, y: int, horizontal_velocity: int) -> void:
	var projectile = BadnikProjectileClass.new()
	projectile.name = "NewtronMissile"
	projectile.z_index = 42
	add_child(projectile)
	projectile.setup_newtron(self, x, y, horizontal_velocity)
	transient_objects.append(projectile)

func spawn_s2_buzzer_projectile(x: int, y: int, horizontal_velocity: int, face_left: bool) -> void:
	var projectile = S2EHZProjectileClass.new()
	projectile.name = "S2BuzzerProjectile"
	projectile.z_index = 42
	add_child(projectile)
	projectile.setup_buzzer(self, x, y, horizontal_velocity, face_left)
	transient_objects.append(projectile)

func spawn_s2_coconut_projectile(x: int, y: int, horizontal_velocity: int, face_left: bool) -> void:
	var projectile = S2EHZProjectileClass.new()
	projectile.name = "S2CoconutProjectile"
	projectile.z_index = 42
	add_child(projectile)
	projectile.setup_coconut(self, x, y, horizontal_velocity, face_left)
	transient_objects.append(projectile)

func spawn_s2_arz_debris(world_x: int, world_y: int, texture_path: String, vx: int, vy: int, gravity_value: int = 0x38, delay_frames: int = 0, z: int = 2) -> void:
	var debris = S2ARZDebrisObjectClass.new()
	add_child(debris)
	debris.setup(self, world_x, world_y, texture_path, vx, vy, gravity_value, delay_frames, z)
	transient_objects.append(debris)

func spawn_s2_ooz_projectile(x: int, y: int, folder: String, frames: Array[int], frame_delay: int, horizontal_velocity: int, vertical_velocity: int, startup_delay: int = 0, face_left: bool = false) -> void:
	var projectile = S2OOZProjectileClass.new()
	projectile.name = "S2OOZProjectile"
	# Normal OOZ objects live at parent z=40 and their bodies at local z=2.
	# Octus's bullet is source-layered behind its parent, so it needs a lower
	# *parent* z; changing only the projectile child Sprite2D was ineffective.
	projectile.z_index = 39 if folder == "octus" else 42
	if folder == "octus":
		# Phase 119: make the source-behind-parent priority absolute. The projectile
		# lives in a separate transient subtree, so relative Z alone was not reliable
		# against the Octus object subtree.
		projectile.z_as_relative = false
		projectile.z_index = 30
	add_child(projectile)
	projectile.setup(self, x, y, folder, frames, frame_delay, horizontal_velocity, vertical_velocity, startup_delay, face_left)
	transient_objects.append(projectile)

func spawn_s2_arz_arrow(x: int, y: int, horizontal_velocity: int, face_left: bool) -> void:
	var projectile = S2ARZArrowObjectClass.new()
	projectile.name = "S2ARZArrow"
	projectile.z_index = 42
	add_child(projectile)
	projectile.setup_projectile(self, x, y, horizontal_velocity, face_left)
	transient_objects.append(projectile)

func spawn_s2_arz_leaf(x: int, y: int, horizontal_velocity: int, vertical_velocity: int, frame: int) -> void:
	var leaf = S2ARZLeafObjectClass.new()
	leaf.name = "S2ARZLeaf"
	leaf.z_index = 41
	add_child(leaf)
	leaf.setup(self, x, y, horizontal_velocity, vertical_velocity, frame)
	transient_objects.append(leaf)

func spawn_s2_cpz_spiny_projectile(x: int, y: int, horizontal_velocity: int, vertical_velocity: int, face_left: bool) -> void:
	var projectile = S2CPZSpinyProjectileClass.new()
	projectile.name = "S2CPZSpinyProjectile"
	projectile.z_index = 42
	add_child(projectile)
	projectile.setup_spiny(self, x, y, horizontal_velocity, vertical_velocity, face_left)
	transient_objects.append(projectile)


func spawn_mz_geyser_column(x: int, y: int, kind: int):
	var column = MZGeyserColumnClass.new()
	column.name = "MZGeyserColumn"
	column.z_index = 47
	add_child(column)
	column.setup(self, x, y, kind)
	transient_objects.append(column)
	return column

func spawn_mz_pushblock_geyser(parent_block, x: int, y: int):
	# Object $33 creates Object $4C directly from its hard-coded MZ2/MZ3 X
	# thresholds. Keep it transient: it has no ObjPos/RememberState record.
	var maker = MZGeyserObject.new()
	maker.name = "MZPushBlockGeyserMaker"
	maker.z_index = 47
	add_child(maker)
	maker.setup_pushblock_maker(self, parent_block, x, y)
	transient_objects.append(maker)
	return maker

func spawn_points_popup(x: int, y: int, points: int) -> void:
	var popup = PointsObjectClass.new()
	popup.name = "Points"
	popup.z_index = 56
	add_child(popup)
	popup.setup(x, y, points)
	transient_objects.append(popup)

func spawn_mz_block_fragments(x: int, y: int) -> void:
	var speeds = [[-0x200,-0x200],[-0x100,-0x100],[0x200,-0x200],[0x100,-0x100]]
	for i in range(4):
		var fragment = MZBlockFragmentClass.new()
		fragment.name = "MZBlockFragment"
		fragment.z_index = 44
		add_child(fragment)
		fragment.setup(self, x, y, int(speeds[i][0]), int(speeds[i][1]), i)
		transient_objects.append(fragment)

func spawn_lava_ball(x: int, y: int, ball_subtype: int) -> void:
	var ball = LavaBallObject.new()
	ball.name = "LavaBall"
	ball.z_index = 43
	add_child(ball)
	ball.setup(self, x, y, ball_subtype)
	transient_objects.append(ball)

func spawn_grass_fire(platform: MarbleObject) -> void:
	spawn_grass_fire_child(platform, 0, true)

func spawn_grass_fire_child(platform: MarbleObject, local_x: int, root_flame: bool = false) -> void:
	var flame = GrassFireObject.new()
	flame.name = "GrassFire"
	flame.z_index = 46
	add_child(flame)
	flame.setup(self, platform, local_x, root_flame)
	transient_objects.append(flame)



func spawn_sbz_false_floor() -> void:
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SBZ or int(level_definition.get("act", 0)) != 2:
		return
	if sbz_false_floor_object != null and is_instance_valid(sbz_false_floor_object) and sbz_false_floor_object.alive:
		return
	var floor = SBZTransitionObjectClass.new()
	floor.name = "SBZFalseFloor"
	add_child(floor)
	floor.setup_false_floor(self)
	sbz_false_floor_object = floor
	transient_objects.append(floor)

func spawn_sbz_eggman() -> void:
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SBZ or int(level_definition.get("act", 0)) != 2:
		return
	if sbz_eggman_object != null and is_instance_valid(sbz_eggman_object) and sbz_eggman_object.alive:
		return
	spawn_sbz_false_floor()
	var eggman = SBZTransitionObjectClass.new()
	eggman.name = "SBZScrapEggman"
	add_child(eggman)
	eggman.setup_scrap_eggman(self, sbz_false_floor_object)
	sbz_eggman_object = eggman
	transient_objects.append(eggman)

func spawn_s2_ehz_boss() -> bool:
	# Retail Sonic 2 LevEvents_EHZ2 calls SingleObjLoad after the 90-frame
	# ScreenShift/PLC wait. In the original this allocation happens inline inside
	# the level-event routine. Here the camera and object manager run separately,
	# so return an acknowledgement and let main retain the request until creation.
	if boss_status >= 1:
		return false
	if boss_object != null and is_instance_valid(boss_object):
		return true
	# Hotfix 2: gate this from the loaded level definition itself.  The EHZ2
	# event is data-driven (s2_ehz_boss=true), so boss allocation should not be
	# able to fail because outer debug/progression zone bookkeeping is stale.
	if not bool(level_definition.get("s2_ehz_boss", false)):
		return false
	boss_limit_right = 0x2940
	boss_screen_lock = true
	var boss = S2EHZBossObjectClass.new()
	boss.name = "S2EHZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_ehz_boss_right_boundary() -> void:
	# Obj56_FlyingOff expands Camera_Max_X_pos by two pixels per frame to $2AB0.
	boss_screen_lock = false
	boss_limit_right = mini(0x2AB0, boss_limit_right + 2)

func spawn_s2_cpz_boss() -> bool:
	# Retail LevEvents_CPZ2 loads Object $5D after ScreenShift reaches $5A.
	# Keep allocation idempotent so the main-loop watchdog can retry every frame.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_cpz_boss", false)):
		return false
	boss_limit_right = 0x2A20
	boss_screen_lock = true
	var boss = S2CPZBossObjectClass.new()
	boss.name = "S2CPZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_cpz_boss_right_boundary() -> void:
	# Obj5D_Main_C expands Camera_Max_X_pos two pixels/frame toward $2C30.
	boss_screen_lock = false
	boss_limit_right = mini(0x2C30, boss_limit_right + 2)

func spawn_s2_arz_boss() -> bool:
	# Retail LevEvents_ARZ2 allocates Object $89 immediately when the camera reaches
	# $2A40, then waits ScreenShift=$5A before starting boss music.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_arz_boss", false)):
		return false
	boss_limit_right = 0x2A40
	boss_screen_lock = true
	var boss = S2ARZBossObjectClass.new()
	boss.name = "S2ARZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_arz_boss_right_boundary() -> void:
	# Obj89_Main_SubC expands Camera_Max_X_pos by two pixels per frame to $2C00.
	boss_screen_lock = false
	boss_limit_right = mini(0x2C00, boss_limit_right + 2)

func spawn_s2_cnz_boss() -> bool:
	# Retail LevEvents_CNZ2 allocates Object $51 after ScreenShift reaches $5A.
	# Keep this idempotent so main can retry the cross-system allocation.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_cnz_boss", false)):
		return false
	boss_limit_right = 0x28E0
	boss_screen_lock = true
	var boss = S2CNZBossObjectClass.new()
	boss.name = "S2CNZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func open_s2_cnz_boss_exit_wall() -> void:
	# Retail Obj51 defeat restores Level_Layout+$C54 to chunk $DD. The level
	# renderer keeps a chunk cache, so also request a focused visual refresh.
	if player == null or player.level == null:
		return
	if player.level.set_chunk_id_at(0x54, 0x0C, 0xDD):
		cnz_boss_exit_refresh_requested = true


func unlock_s2_cnz_boss_right_boundary() -> void:
	# Obj51 loc_31E2A expands Camera_Max_X_pos by two pixels/frame to $2B20.
	boss_screen_lock = false
	boss_limit_right = mini(0x2B20, boss_limit_right + 2)

func spawn_s2_htz_boss() -> bool:
	# Retail LevEvents_HTZ2 Routine8 allocates Object $52 when ScreenShift=$5A.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_htz_boss", false)):
		return false
	boss_limit_right = 0x2F5E
	boss_screen_lock = true
	var boss = S2HTZBossObjectClass.new()
	boss.name = "S2HTZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_htz_boss_right_boundary() -> void:
	# Obj52_Mobile_Flee expands Camera_Max_X_pos by two pixels per frame to $3160.
	boss_screen_lock = false
	boss_limit_right = mini(0x3160, boss_limit_right + 2)

func spawn_s2_mcz_boss() -> bool:
	# Retail LevEvents_MCZ2 Routine3 allocates Object $57 after the exact
	# ScreenShift=$5A arena wait. Keep this idempotent so main can retry the
	# cross-system allocation until the object actually exists.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_mcz_boss", false)):
		return false
	boss_limit_right = 0x20F0
	boss_screen_lock = true
	var boss = S2MCZBossObjectClass.new()
	boss.name = "S2MCZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_mcz_boss_right_boundary() -> void:
	# Obj57 escape expands Camera_Max_X_pos by two pixels per frame to $2240.
	boss_screen_lock = false
	boss_limit_right = mini(0x2240, boss_limit_right + 2)

func spawn_s2_ooz_boss() -> bool:
	# Retail LevEvents_OOZ2 Routine3 allocates Object $55 after ScreenShift=$5A.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_ooz_boss", false)):
		return false
	boss_limit_right = 0x28C0
	boss_screen_lock = true
	var boss = S2OOZBossObjectClass.new()
	boss.name = "S2OOZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_ooz_boss_right_boundary() -> void:
	# Obj55_ReleaseCamera expands Camera_Max_X_pos by exactly two pixels per
	# frame until $2A20 after Boss_defeated_flag becomes non-zero.
	boss_screen_lock = false
	boss_limit_right = mini(0x2A20, boss_limit_right + 2)

func spawn_s2_mtz_boss() -> bool:
	# Retail LevEvents_MTZ3 Routine4 allocates Object $54 at ScreenShift=$5A.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_mtz_boss", false)):
		return false
	boss_limit_right = 0x2AB0
	boss_screen_lock = true
	var boss = S2MTZBossObjectClass.new()
	boss.name = "S2MTZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_mtz_boss_right_boundary() -> void:
	# Obj54_MainSub12 expands Camera_Max_X_pos exactly 2 pixels/frame to $2BF0.
	boss_screen_lock = false
	boss_limit_right = mini(0x2BF0, boss_limit_right + 2)

func spawn_s2_wfz_boss() -> bool:
	# Retail WFZ stores Object $C5 in the object list at $2B80,$0450, while
	# LevEvents_WFZ gates the fight once Camera reaches $2880/$400 and Sonic
	# falls to the $500 approach. Spawn the native adapter at that event gate.
	if boss_status >= 1:
		return true
	if boss_object != null and is_instance_valid(boss_object):
		return true
	if not bool(level_definition.get("s2_wfz_boss", false)):
		return false
	boss_limit_right = 0x2C60
	boss_screen_lock = true
	var boss = S2WFZBossObjectClass.new()
	boss.name = "S2WFZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	return true

func unlock_s2_wfz_boss_right_boundary() -> void:
	boss_screen_lock = false
	boss_limit_right = mini(0x2E80, boss_limit_right + 2)

func spawn_s2_dez_mecha_sonic() -> bool:
	if s2_dez_mecha_spawned:
		return true
	if not bool(level_definition.get("s2_dez", false)):
		return false
	var boss = S2DEZMechaSonicClass.new()
	boss.name = "S2DEZMechaSonic"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)
	s2_dez_mecha_spawned = true
	return true

func spawn_ghz_boss() -> void:
	if boss_status >= 1:
		return
	if boss_object != null and is_instance_valid(boss_object):
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_GHZ or int(level_definition.get("act", 0)) != 3:
		return
	boss_limit_right = 0x2960
	var boss = GHZBossObjectClass.new()
	boss.name = "GHZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self, 0x2A60, 0x280)
	boss_object = boss
	transient_objects.append(boss)

func spawn_mz_boss() -> void:
	if boss_status >= 1:
		return
	if boss_object != null and is_instance_valid(boss_object):
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_MZ or int(level_definition.get("act", 0)) != 3:
		return
	boss_limit_right = 0x1800
	var boss = MZBossObjectClass.new()
	boss.name = "MZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self, 0x19F0, 0x22C)
	boss_object = boss
	transient_objects.append(boss)

func spawn_syz_boss_blocks() -> void:
	if syz_boss_blocks_spawned:
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SYZ or int(level_definition.get("act", 0)) != 3:
		return
	syz_boss_blocks_spawned = true
	syz_boss_blocks.clear()
	for i in range(10):
		var block = SYZBossBlockClass.new()
		block.name = "SYZBossBlock%02d" % i
		block.z_index = 42
		add_child(block)
		block.setup(self, i, 0x2C10 + i * 0x20, 0x582)
		syz_boss_blocks.append(block)
		transient_objects.append(block)

func get_syz_boss_block(index: int):
	if index < 0 or index >= syz_boss_blocks.size():
		return null
	var block = syz_boss_blocks[index]
	if block == null or not is_instance_valid(block) or not block.alive or block.broken:
		return null
	return block

func spawn_syz_boss() -> void:
	if boss_status >= 1:
		return
	if boss_object != null and is_instance_valid(boss_object):
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SYZ or int(level_definition.get("act", 0)) != 3:
		return
	spawn_syz_boss_blocks()
	boss_limit_right = 0x2C00
	var boss = SYZBossObjectClass.new()
	boss.name = "SYZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self, 0x2DB0, 0x4DA)
	boss_object = boss
	transient_objects.append(boss)

func get_slz_boss_seesaws() -> Array:
	var result: Array = []
	for obj in slots:
		if obj == null or not is_instance_valid(obj) or not obj.alive:
			continue
		if obj is SLZNativeObject and obj.object_id == 0x5E and obj.subtype != 0:
			result.append(obj)
	# The authored SLZ3 boss seesaws are left-to-right at $203C/$20A0/$2104.
	result.sort_custom(func(a, b): return int(a.position.x) < int(b.position.x))
	return result

func slz_boss_seesaw_has_ball(seesaw: SLZNativeObject) -> bool:
	for transient in transient_objects:
		if transient == null or not is_instance_valid(transient):
			continue
		if transient is SLZBossSpikeball and transient.alive and transient.state != SLZBossSpikeball.STATE_FRAGMENT and transient.target_seesaw == seesaw:
			return true
	return false

func spawn_fz_boss() -> void:
	if boss_object != null and is_instance_valid(boss_object):
		return
	if boss_status >= 1:
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SBZ or int(level_definition.get("act", 0)) != 3:
		return
	boss_limit_right = 0x2460
	boss_screen_lock = true
	var boss = FZBossObjectClass.new()
	boss.name = "FZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)

func request_final_ending() -> void:
	final_ending_requested = true
	time_frozen = true
	if player != null:
		player.control_locked = true
		player.inertia = 0

func spawn_slz_boss() -> void:
	if boss_object != null and is_instance_valid(boss_object):
		return
	if boss_status >= 1:
		return
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SLZ or int(level_definition.get("act", 0)) != 3:
		return
	boss_limit_right = 0x2000
	boss_screen_lock = true
	var boss = SLZBossObjectClass.new()
	boss.name = "SLZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)

func spawn_slz_boss_spikeball(boss, seesaw: SLZNativeObject, world_x: int, world_y: int) -> void:
	if seesaw == null or not is_instance_valid(seesaw):
		return
	var ball = SLZBossSpikeballClass.new()
	ball.name = "SLZBossSpikeball"
	add_child(ball)
	ball.setup(self, boss, seesaw, world_x, world_y)
	transient_objects.append(ball)

func spawn_slz_boss_spike_fragment(world_x: int, world_y: int, vx: int, vy: int) -> void:
	var frag = SLZBossSpikeballClass.new()
	frag.name = "SLZBossSpikeFragment"
	add_child(frag)
	frag.setup_fragment(self, world_x, world_y, vx, vy)
	transient_objects.append(frag)

func unlock_slz_boss_right_boundary() -> void:
	boss_screen_lock = false
	boss_limit_right = mini(0x2160, boss_limit_right + 2)

func spawn_lz_boss() -> void:
	if boss_object != null and is_instance_valid(boss_object):
		return
	if boss_status >= 1:
		return
	boss_limit_right = 0x202F
	boss_screen_lock = true
	var boss = LZBossObjectClass.new()
	boss.name = "LZBoss"
	boss.z_index = 46
	add_child(boss)
	boss.setup(self)
	boss_object = boss
	transient_objects.append(boss)

func release_lz_boss_screen_lock() -> void:
	boss_screen_lock = false

func unlock_lz_boss_right_boundary() -> void:
	boss_limit_right = mini(0x2030, boss_limit_right + 2)

func spawn_mz_boss_fire(x: int, y: int) -> void:
	var fire = MZBossFireObjectClass.new()
	fire.name = "MZBossFire"
	# BossFire uses priority 5 while Eggman uses priority 4; in the native
	# painter this means the dropped/spreading fire belongs BEHIND the boss.
	fire.z_index = 45
	add_child(fire)
	fire.setup(self, x, y)
	transient_objects.append(fire)

func unlock_mz_boss_right_boundary() -> void:
	boss_limit_right = mini(0x1960, boss_limit_right + 2)

func unlock_syz_boss_right_boundary() -> void:
	boss_limit_right = mini(0x2D40, boss_limit_right + 2)

func set_boss_defeated() -> void:
	boss_status = maxi(boss_status, 1)

func unlock_boss_right_boundary() -> void:
	boss_limit_right = mini(0x2AC0, boss_limit_right + 2)

func spawn_prison_animal(x: int, y: int, delay: int) -> void:
	var animal = AnimalObjectClass.new()
	animal.name = "PrisonAnimal"
	animal.z_index = 44
	add_child(animal)
	animal.setup_prison(self, x, y, _next_zone_animal_id(), delay)
	transient_objects.append(animal)

func prison_animals_alive() -> bool:
	for transient in transient_objects:
		if transient != null and is_instance_valid(transient) and transient is AnimalObject and transient.is_prison_animal and transient.alive:
			return true
	return false

func time_minutes() -> int:
	return mini(9, int(elapsed_frames / (60 * 60)))

func time_seconds() -> int:
	return mini(59, int(elapsed_frames / 60) % 60)

func level_time_text() -> String:
	return "%d:%02d" % [time_minutes(), time_seconds()]

func refresh_palette_cycled_objects(changed_indices: Array[int], runtime_palette: Array[Color]) -> void:
	# Genesis sprites read CRAM at draw time; our source-object textures are
	# precomposited RGBA. Notify the small set of objects whose sprite palette
	# entries are part of the retail level palette-cycle tables.
	if changed_indices.is_empty() or runtime_palette.size() < 64:
		return
	for obj in slots:
		if obj != null and is_instance_valid(obj) and obj.has_method("refresh_palette_cycle"):
			obj.call("refresh_palette_cycle", changed_indices, runtime_palette)
	for obj in transient_objects:
		if obj != null and is_instance_valid(obj) and obj.has_method("refresh_palette_cycle"):
			obj.call("refresh_palette_cycle", changed_indices, runtime_palette)

func active_count() -> int:
	return active_records.size()

func supported_count() -> int:
	var total = 0
	for obj in slots:
		if obj != null and is_instance_valid(obj) and not (obj is StaticSpriteObject):
			total += 1
	return total

func _spawn_record(record: Dictionary) -> void:
	var slot = _find_free_slot()
	if slot < 0:
		return
	var obj = _make_object_for_id(int(record["id"]))
	obj.name = "Obj_%02X_%03d" % [int(record["id"]), int(record["index"])]
	obj.z_index = 40
	add_child(obj)
	obj.setup_from_record(self, record)
	slots[slot] = obj
	active_records[int(record["index"])] = slot

func _find_free_slot() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

func _make_object_for_id(id: int) -> GenesisLevelObject:
	# Phase 81: Sonic 2 object IDs are a separate namespace. Never let an
	# unsupported S2 ID fall through to an unrelated Sonic 1 object that happens
	# to share the same number (for example S2 $4B Buzzer vs S1 $4B Giant Ring).
	if bool(level_definition.get("experimental_sonic2", false)):
		# Phase 124: all retail Metropolis traversal families through Act 3 are now
		# routed through the zone-local adapter, including $6A/$6E introduced in MTZ3.
		if bool(level_definition.get("s2_scz", false)) and id in [0x99,0x9A,0xAC,0xB2,0xB3,0xB4,0xB5]:
			return S2SCZObjectClass.new()
		if bool(level_definition.get("s2_wfz", false)) and id in [0x19,0x72,0x80,0x8B,0xAD,0xAE,0xB2,0xB4,0xB5,0xB6,0xB8,0xB9,0xBA,0xBC,0xBD,0xBE,0xC0,0xC1,0xC2,0xD9]:
			return S2WFZObjectClass.new()
		if bool(level_definition.get("s2_dez", false)) and id == 0xC6:
			return S2DEZEggmanRunnerClass.new()
		if bool(level_definition.get("s2_dez", false)) and id == 0xC7:
			return S2DEZEggRoboClass.new()
		if bool(level_definition.get("s2_mtz", false)) and id in [0x06,0x1C,0x2D,0x31,0x42,0x47,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x70,0x71,0x72,0x74,0x9F,0xA1,0xA4]:
			return S2MTZObjectClass.new()
		# Phase 117: OOZ's overlapping numeric IDs are a zone-local namespace.
		# Route every OOZ-specific placement through the retail-derived OOZ
		# adapter before the earlier CPZ/ARZ/EHZ families can claim the same IDs.
		if bool(level_definition.get("s2_ooz", false)) and id in [0x19,0x1C,0x1F,0x33,0x3D,0x3F,0x43,0x45,0x48,0x4A,0x50]:
			return S2OOZObjectClass.new()
		# Phase 112: MCZ's overlapping numeric IDs are a zone-local namespace.
		# Route them before the earlier ARZ/CPZ adapters so the exact retail MCZ
		# art, geometry and ButtonVine_Trigger semantics are used.
		if bool(level_definition.get("s2_mcz", false)) and id in [0x15,0x1F,0x2A,0x6A,0x75,0x76,0x77,0x7A,0x7F,0x80,0x81,0x9E,0xA3]:
			return S2MCZObjectClass.new()
		if bool(level_definition.get("s2_htz", false)) and id in [0x14, 0x16, 0x1C, 0x2F, 0x30, 0x31, 0x92, 0x95, 0x96]:
			return S2HTZObjectClass.new()
		match id:
			0x15, 0x83: return S2ARZSwingObjectClass.new()
			0x1F, 0x23, 0x24, 0x2B, 0x2C, 0x82: return S2ARZEnvironmentObjectClass.new()
			0x22: return S2ARZArrowObjectClass.new()
			0x8C, 0x8D, 0x8E, 0x91: return S2ARZBadnikObjectClass.new()
			0x03: return S2PlaneSwitcherObjectClass.new()
			0x06: return S2EHZSpiralPathObjectClass.new()
			0x0B, 0x19, 0x1B, 0x1E, 0x2D, 0x32, 0x40, 0x6B, 0x74, 0x78, 0x7A, 0x7B: return S2CPZTraversalObjectClass.new()
			0x1D, 0xA5, 0xA6, 0xA7: return S2CPZHazardObjectClass.new()
			0x0D: return S2SignpostAdapterClass.new()
			0x11: return S2EHZBridgeObjectClass.new()
			0x18: return S2EHZPlatformObjectClass.new()
			0x1C: return S2EHZSceneryObjectClass.new()
			0x25: return RingGroupObject.new()
			0x26: return S2MonitorAdapterClass.new()
			0x36: return S2SpikesObjectClass.new()
			0x3E: return S2EggPrisonObjectClass.new()
			0x41: return S2SpringObjectClass.new()
			0x49: return S2EHZWaterfallObjectClass.new()
			0x4B, 0x5C, 0x9D: return S2EHZBadnikObjectClass.new()
			0x79: return LamppostObject.new()
			0x44, 0x72, 0x84, 0x85, 0x86, 0xD4, 0xD5, 0xD7: return S2CNZTraversalObjectClass.new()
			0xC8, 0xD2, 0xD6, 0xD8: return S2CNZCompletionObjectClass.new()
			_: return S2UnsupportedObjectClass.new()
	match id:
		0x11:
			return BridgeObject.new()
		0x25:
			return RingGroupObject.new()
		0x28:
			if bool(level_definition.get("ending_sequence", false)):
				return EndingAnimalObjectClass.new()
			return StaticSpriteObject.new()
		0x2A:
			return SBZSmallDoorObjectClass.new()
		0x41:
			return SpringObject.new()
		0x36:
			return SpikesObject.new()
		0x3B:
			return PurpleRockObject.new()
		0x26:
			return MonitorObject.new()
		0x18:
			return BasicPlatformObject.new()
		0x15:
			return SwingingPlatformObject.new()
		0x17:
			return HelixObject.new()
		0x3C:
			return SmashWallObject.new()
		0x3E:
			return PrisonCapsuleObjectClass.new()
		0x1C:
			return SceneryObject.new()
		0x1E, 0x1F, 0x22, 0x2B, 0x40, 0x42:
			return BadnikObject.new()
		0x44:
			return EdgeWallObject.new()
		0x79:
			return LamppostObject.new()
		0x0D:
			return SignpostObject.new()
		0x1A:
			return CollapsingLedgeObject.new()
		0x4B:
			return GiantRingObject.new()
		0x7D:
			return HiddenBonusObject.new()
		0x49:
			return WaterfallTriggerObject.new()
		0x13:
			return LavaMakerObject.new()
		0x4C:
			return MZGeyserObject.new()
		0x4E:
			return MZLavaWallObject.new()
		0x51:
			return MZSmashBlockObject.new()
		0x53:
			return MZCollapseFloorObject.new()
		0x32:
			return ButtonObject.new()
		0x12, 0x43, 0x47, 0x50, 0x56, 0x57, 0x58:
			return SYZObject.new()
		0x16, 0x2C, 0x2D:
			return LZEnemyObjectClass.new()
		0x60:
			return LZOrbinautObjectClass.new()
		0x61, 0x62, 0x65:
			return LZNativeObjectClass.new()
		0x0B, 0x0C, 0x63:
			return LZProgressionObjectClass.new()
		0x64:
			return LZBubbleObjectClass.new()
		0x2F, 0x30, 0x31, 0x33, 0x46, 0x52, 0x71:
			return MarbleObject.new()
		0x54:
			return LavaTagObject.new()
		0x55, 0x78:
			return MZBadnikObject.new()
		0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F:
			return SLZNativeObjectClass.new()
		0x66, 0x67, 0x68, 0x69, 0x6A:
			return SBZNativeObjectClass.new()
		0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x72:
			return SBZProgressionObjectClass.new()
		_:
			return StaticSpriteObject.new()


func _load_s2_objpos(path: String) -> bool:
	# Retail Sonic 2 object layouts are raw six-byte records with no S1-style
	# $FFFF terminator. The object byte is the full 8-bit ID: bit 7 is NOT the
	# Sonic 1 RememberState flag (EHZ legitimately contains Object $9D Coconuts).
	if not FileAccess.file_exists(path):
		push_error("Missing Sonic 2 object placement data: %s" % path)
		return false
	var data = FileAccess.get_file_as_bytes(path)
	if (data.size() % 6) != 0:
		push_error("Sonic 2 object placement length is not six-byte aligned: %s" % path)
		return false
	records.clear()
	var index := 0
	for offset in range(0, data.size(), 6):
		var x = (int(data[offset]) << 8) | int(data[offset + 1])
		var y_flags = (int(data[offset + 2]) << 8) | int(data[offset + 3])
		records.append({
			"index": index,
			"x": x,
			"y": y_flags & 0x0FFF,
			# ChkLoadObj masks Y to 12 bits, then `rol.w #3` copies original
			# Y-word bits 13/14 into render/status X/Y flip bits 0/1. Bit 15
			# is the S2 respawn-table flag and is independent of the object ID.
			"x_flip": (y_flags & 0x2000) != 0,
			"y_flip": (y_flags & 0x4000) != 0,
			"remember": (y_flags & 0x8000) != 0,
			"id": int(data[offset + 4]),
			"subtype": int(data[offset + 5]),
		})
		index += 1
	return records.size() > 0

func _load_s2_ring_positions(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Missing Sonic 2 ring placement data: %s" % path)
		return false
	var data = FileAccess.get_file_as_bytes(path)
	var offset = 0
	var next_index = 0
	for record in records:
		next_index = maxi(next_index, int(record["index"]) + 1)
	var loaded_groups = 0
	var found_terminator = false
	while offset + 1 < data.size():
		var world_x = (int(data[offset]) << 8) | int(data[offset + 1])
		offset += 2
		# RingsMgr_Setup terminates when the X word is negative.
		if (world_x & 0x8000) != 0:
			found_terminator = true
			break
		if offset + 1 >= data.size():
			push_error("Truncated Sonic 2 ring descriptor in %s" % path)
			return false
		var y_descriptor = (int(data[offset]) << 8) | int(data[offset + 1])
		offset += 2
		var vertical = (y_descriptor & 0x8000) != 0
		var count_minus_one = (y_descriptor >> 12) & 7
		var world_y = y_descriptor & 0x0FFF
		# RingGroupObject POS_DATA index 1 is +$18 X and index 4 is +$18 Y,
		# exactly matching RingsMgr_NextRingInRow/Col. Preserve the source group
		# count in the low three subtype bits, including the valid 8-ring case.
		var orientation = 4 if vertical else 1
		records.append({
			"index": next_index,
			"x": world_x,
			"y": world_y,
			"x_flip": false,
			"y_flip": false,
			"remember": false,
			"id": 0x25,
			"subtype": (orientation << 4) | count_minus_one,
		})
		next_index += 1
		loaded_groups += 1
	if not found_terminator:
		push_error("Sonic 2 ring placement list has no negative-X terminator: %s" % path)
		return false
	return loaded_groups > 0

func _load_objpos(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Missing level object placement data: %s" % path)
		return false
	var data = FileAccess.get_file_as_bytes(path)
	records.clear()
	var offset = 0
	var index = 0
	while offset + 5 < data.size():
		var x = (int(data[offset]) << 8) | int(data[offset + 1])
		if x == 0xFFFF:
			break
		var y_flags = (int(data[offset + 2]) << 8) | int(data[offset + 3])
		var raw_id = int(data[offset + 4])
		var record = {
			"index": index,
			"x": x,
			"y": y_flags & 0x0FFF,
			"x_flip": (y_flags & 0x4000) != 0,
			"y_flip": (y_flags & 0x8000) != 0,
			"remember": (raw_id & 0x80) != 0,
			"id": raw_id & 0x7F,
			"subtype": int(data[offset + 5]),
		}
		records.append(record)
		offset += 6
		index += 1
	return records.size() > 0
