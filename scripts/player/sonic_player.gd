class_name SonicPlayer
extends Node2D

# Player controller translated from:
#   _incObj/01 Sonic.asm
#   _incObj/Sonic Collision.asm
#   _incObj/Sonic AnglePos.asm
#   _incObj/sub ObjectFall & SpeedToPos.asm
# Terrain collision remains data-driven through GenesisCollision; this node does
# not use CharacterBody2D or Godot physics for level terrain.

const SONIC_WIDTH := 9
const SONIC_HEIGHT := 19
const SONIC_ROLL_WIDTH := 7
const SONIC_ROLL_HEIGHT := 14
const SONIC_QUICK_SIZE := 10

const MAX_SPEED := 0x600
const ACCELERATION := 0x0C
const DECELERATION := 0x80
const JUMP_SPEED := 0x680
const GRAVITY := 0x38

# Phase 78: the normal Sonic 1 controller remains the default.  The optional
# Sonic 2 profile is deliberately narrow: retail S2's base $600/$0C/$80
# movement constants are the same, so only source-visible behavioral
# differences (spindash and the S2 rolling details below) switch paths.
const PHYSICS_PROFILE_SONIC1 := 0
const PHYSICS_PROFILE_SONIC2 := 1

# Phase 79 presentation profile. This is intentionally independent of physics:
# players may combine S1 or S2 movement with S1, Simon Wai beta, or retail S2 art/animation.
const ANIMATION_STYLE_SONIC1 := 0
const ANIMATION_STYLE_SONIC2_BETA := 1
const ANIMATION_STYLE_SONIC2_FINAL := 2
const S2_SPINDASH_SPEEDS: Array[int] = [
	0x800, 0x880, 0x900, 0x980, 0xA00, 0xA80, 0xB00, 0xB80, 0xC00,
]

const SURFACE_FLOOR := 0x00
const SURFACE_LEFT_WALL := 0x40
const SURFACE_CEILING := 0x80
const SURFACE_RIGHT_WALL := 0xC0

# Native SolidObject contact response used by springs/spikes and future
# fully-solid objects. The original SolidObject communicates the collision
# side through return/status values; explicit constants keep that distinction
# instead of reducing every object contact to a boolean.
const SOLID_NONE := 0
const SOLID_TOP := 1
const SOLID_BOTTOM := 2
const SOLID_LEFT := 3
const SOLID_RIGHT := 4

@onready var visual: SonicVisual = $Visual

var level: GHZLevelData
var collision: GenesisCollision
var object_manager = null

# Genesis-compatible position and speed representation.
# fixed_x/fixed_y are 16.16. vel_x/vel_y/inertia use the original 8.8 scale.
var fixed_x := 0
var fixed_y := 0
var vel_x := 0
var vel_y := 0
var inertia := 0
var angle := 0

# Runtime equivalents of v_sonspeedmax/acc/dec. Speed shoes modify these.
var speed_max := MAX_SPEED
var speed_acceleration := ACCELERATION
var speed_deceleration := DECELERATION

var width_radius := SONIC_WIDTH
var height_radius := SONIC_HEIGHT

var in_air := false
var rolling := false
# Sonic 2 CNZ Object $84 pinball-mode latch. While active Sonic must remain
# rolled and cannot stop/jump out of the forced pinball state.
var pinball_mode := false
var roll_jump_lock := false
var facing_left := false
var pushing := false
var jumping := false
var skidding := false
# Phase 78 animation/controller state.  edge_balance is also used by the
# default Sonic 1 profile; the missing wobble was an animation-state omission,
# not a Sonic 2-only feature.
var edge_balance := false
var physics_profile := PHYSICS_PROFILE_SONIC1
var animation_style = ANIMATION_STYLE_SONIC1
var spindash_active := false
var spindash_counter := 0
var _spindash_duck_ready := false
var spring_pose_timer := 0
# Phase 82: S2 Object $41 subtype bit 0 drives the separate flip-angle state
# used by SonAni's tumble renderer. These are presentation state only; the
# verified Phase 81 launch velocity/collision behavior is left untouched.
var s2_twirl_active := false
var s2_twirl_angle := 0
var s2_twirl_speed := 0
var s2_twirl_remaining := 0
var s2_twirl_direction := 1
var s2_twirl_turned := false
# Phase 85: Object $06 uses flip_angle as a visual-only pathway orientation.
# Keep it separate from terrain angle so running physics remain horizontal while
# the invisible EHZ spiral pathway moves Sonic vertically.
var s2_spiral_pathway_active := false
var s2_spiral_visual_angle := 0
var object_attack_active := false
var object_attack_was_airborne := false
# Phase 56: active logical Genesis collision path. This mirrors the later
# engine's $C/$D versus $E/$F collision selectors without using Godot physics
# layers. PathSwitcher objects own transitions between the two terrain paths.
var collision_path := GHZLevelData.COLLISION_PATH_PRIMARY
var collision_path_owner := -1
var lock_time := 0
var control_locked := false
# Direction used by source-scripted control locks: -1 left, 0 neutral, +1 right.
# Most existing cutscenes use +1; Final Zone/Ending can explicitly stop or reverse Sonic.
var control_lock_direction := 1
# Phase 33 LZWaterFeatures / Object $0B state.
var object_control_override := false
# Phase 118: retail OOZ transporters keep Sonic under object control while he
# travels between spheres. Hazards cannot interrupt that scripted trajectory.
var ooz_transport_invulnerable := false
var wind_tunnel_mode := false
var water_slide_mode := false
var hang_on_pole := false
# Phase 113: marks Mystic Cave pull-switch/vine grabs so the Sonic 1 visual
# profile can use the user-supplied S2-exclusive hanging poses without
# changing the ordinary S1 pole-hang animation used elsewhere.
var mcz_vine_hang := false
# Phase 41 SBZ RunningDisc equivalent of sticktoconvex ($38).
var stick_to_convex := false

# Runtime equivalents of v_limitleft2/v_limitright2 and f_lockscreen.
# The camera owns these changing boundaries; Sonic_LevelBound uses them too.
var runtime_limit_left := 0
var runtime_limit_right := 0
var runtime_screen_locked := false
var transition_locked := false
var display_hidden := false

var input_left := false
var input_right := false
var input_up := false
var input_down := false
var jump_held := false
var jump_pressed := false
var spindash_rev_pressed := false
var _jump_was_held := false
# Phase 46 credits demos feed the original Genesis controller stream directly
# into Sonic_Modes instead of synthesizing keyboard events.
var scripted_input_enabled := false
var scripted_input_mask := 0
# End_MoveSon2 explicitly leaves Sonic on fr_Wait2 before Object $87 takes over.
# -1 returns rendering to the normal native animation state machine.
var forced_visual_frame := -1

var sensor_debug := false
# Phase 17: lightweight native equivalent of Sonic 1 DebugMode movement.
# F10 toggles this from main.gd. Terrain/object collision and hazards are ignored
# while active so the player can freely inspect later sections of a level.
var debug_free_mode := false
var debug_move_timer := 12
var debug_move_speed := 15
# Phase 4 player-state equivalents of routine 4/6 plus power-up timers.
var hurt_state := false
var dead := false
var invulnerability_timer := 0
var shield := false
var invincible_timer := 0
var shoes_timer := 0
var underwater := false
var drowning := false
var get_air_timer := 0
# Object $0A sets bit 7 of obGfx when drowning; it stays set through the
# drowning death transition and is cleared on a normal respawn/new death.
var sprite_high_priority := false

# Phase 6: native equivalent of Sonic/object standing flags (obStatus bit 3 /
# standonobject + object obSolid). Terrain sensors run before level objects in
# our explicit frame order, so this state preserves a solid object's support
# across the next player tick instead of briefly treating Sonic as airborne.
var standing_on_object := false
var support_left := 0
var support_right := 0
var support_top := 0
var support_record_index := -1
# Phase 74: object support must be re-affirmed by the owning object on every
# ExecuteObjects pass. This mirrors the OST object/platform flags: if an object
# stops executing its stood-on routine, moves away, vanishes, or changes to a
# non-solid state, Sonic cannot remain attached to a stale cached hitbox.
var support_refreshed_this_pass := false
# Phase 74 Hotfix 1: ExitPlatform can clear a stood-on relationship before the
# platform moves, but the stood-on routine still performs one final
# MvSonicOnPtfm carry that frame. Prevent the same object from immediately
# re-acquiring Sonic during its later native resolve call.
var support_exit_block_record_index := -2147483648

var _debug_queries: Array[Dictionary] = []

func _enter_tree() -> void:
	Global.register_player(self)

func _exit_tree() -> void:
	Global.unregister_player(self)

func setup(level_data: GHZLevelData, collision_engine: GenesisCollision) -> void:
	level = level_data
	collision = collision_engine
	respawn()

func respawn() -> void:
	if level == null:
		return
	fixed_x = int(level.start_position.x) << 16
	fixed_y = int(level.start_position.y) << 16
	vel_x = 0
	vel_y = 0
	inertia = 0
	angle = 0
	width_radius = SONIC_WIDTH
	height_radius = SONIC_HEIGHT
	in_air = false
	rolling = false
	pinball_mode = false
	roll_jump_lock = false
	facing_left = false
	pushing = false
	jumping = false
	skidding = false
	edge_balance = false
	spindash_active = false
	spindash_counter = 0
	_spindash_duck_ready = false
	spring_pose_timer = 0
	_clear_s2_twirl()
	s2_spiral_pathway_active = false
	s2_spiral_visual_angle = 0
	collision_path = GHZLevelData.COLLISION_PATH_PRIMARY
	collision_path_owner = -1
	lock_time = 0
	control_locked = false
	control_lock_direction = 1
	scripted_input_enabled = false
	scripted_input_mask = 0
	forced_visual_frame = -1
	object_control_override = false
	ooz_transport_invulnerable = false
	wind_tunnel_mode = false
	water_slide_mode = false
	hang_on_pole = false
	mcz_vine_hang = false
	stick_to_convex = false
	transition_locked = false
	display_hidden = false
	debug_free_mode = false
	debug_move_timer = 12
	debug_move_speed = 15
	hurt_state = false
	dead = false
	invulnerability_timer = 0
	shield = false
	invincible_timer = 0
	shoes_timer = 0
	underwater = false
	drowning = false
	get_air_timer = 0
	sprite_high_priority = false
	clear_object_support()
	speed_max = MAX_SPEED
	speed_acceleration = ACCELERATION
	speed_deceleration = DECELERATION
	_sync_position()
	# The level start coordinates are already chosen for standing Sonic. Let the
	# original ground sensors make any small alignment correction on the first tick.
	queue_redraw()

func respawn_at(world_position: Vector2i) -> void:
	respawn()
	fixed_x = world_position.x << 16
	fixed_y = world_position.y << 16
	_sync_position()

# Phase 3 moves the player into the explicit ExecuteObjects-style order owned
# by main.gd. Keeping the tick as a public method avoids Godot callback-order
# ambiguity between Sonic, level objects, camera deformation, and ObjPosLoad.
func simulate_tick() -> void:
	if collision == null:
		return

	_read_input()
	if debug_free_mode:
		object_attack_active = false
		object_attack_was_airborne = false
		pushing = false
		_debug_queries.clear()
		_mode_debug_free()
		_sync_position()
		queue_redraw()
		return
	# ReactToItem sees Sonic's rolling/jump animation from the start of the frame,
	# even if terrain landing later in this tick clears the grounded roll state.
	object_attack_active = rolling or (in_air and jumping)
	edge_balance = false
	object_attack_was_airborne = in_air and object_attack_active
	pushing = false
	_debug_queries.clear()
	_update_power_timers()
	if get_air_timer > 0:
		get_air_timer -= 1

	if transition_locked and not dead:
		vel_x = 0
		vel_y = 0
		inertia = 0
		_sync_position()
		queue_redraw()
		return

	if drowning:
		_mode_drowning()
		_sync_position()
		queue_redraw()
		return

	if dead:
		_mode_dead()
		_sync_position()
		queue_redraw()
		return

	if hurt_state:
		_mode_hurt()
		_apply_level_bounds()
		_sync_position()
		queue_redraw()
		return

	# Object $0B's f_playerctrl bit skips Sonic_Modes while raw controller input
	# is still sampled, allowing the pole object to move/release Sonic itself.
	if object_control_override:
		_update_water_state()
		_sync_position()
		queue_redraw()
		return

	_validate_object_support()

	if in_air:
		_mode_air()
	elif rolling:
		_mode_roll()
	else:
		_mode_normal()

	_update_forced_roll_chunks()
	_apply_level_bounds()
	_update_water_state()
	_sync_position()
	if sensor_debug or shield:
		queue_redraw()

func refresh_visual() -> void:
	# Normal Sonic sits between low/high Plane A layers. Drowning explicitly sets
	# the Genesis sprite priority bit, so lift only that state above high terrain.
	z_index = 120 if sprite_high_priority else 50
	visual.update_from_player(self)

func _read_input() -> void:
	spindash_rev_pressed = false
	if scripted_input_enabled:
		# MoveSonicInDemo copies a Genesis controller byte into both jpadhold and
		# jpadpress. Sonic still derives the jump edge normally from the held state.
		input_up = (scripted_input_mask & 0x01) != 0
		input_down = (scripted_input_mask & 0x02) != 0
		input_left = (scripted_input_mask & 0x04) != 0
		input_right = (scripted_input_mask & 0x08) != 0
		jump_held = (scripted_input_mask & 0x70) != 0
	else:
		# Phase 69: runtime controls are resolved through ProjectSettings Input Map.
		# A/B/C are intentionally equivalent jump buttons, matching the Genesis pad.
		input_left = Input.is_action_pressed("left")
		input_right = Input.is_action_pressed("right")
		input_up = Input.is_action_pressed("up")
		input_down = Input.is_action_pressed("down")
		jump_held = Input.is_action_pressed("A") or Input.is_action_pressed("B") or Input.is_action_pressed("C")
		# Ctrl_1_Press_Logical retains separate A/B/C edges.  This lets a new B/C
		# press rev the spindash even if another jump button is still held.
		spindash_rev_pressed = Input.is_action_just_pressed("A") or Input.is_action_just_pressed("B") or Input.is_action_just_pressed("C")
	jump_pressed = jump_held and not _jump_was_held
	_jump_was_held = jump_held
	if scripted_input_enabled:
		spindash_rev_pressed = jump_pressed
	else:
		spindash_rev_pressed = spindash_rev_pressed or jump_pressed
	if drowning or get_air_timer > 0:
		input_left = false
		input_right = false
		input_up = false
		input_down = false
		jump_held = false
		jump_pressed = false
		spindash_rev_pressed = false
	if control_locked and not dead and not scripted_input_enabled:
		input_left = control_lock_direction < 0
		input_right = control_lock_direction > 0
		input_up = false
		input_down = false
		jump_held = false
		jump_pressed = false
		spindash_rev_pressed = false

func _mode_normal() -> void:
	# Sonic_MdNormal.  Retail Sonic 2 inserts Sonic_CheckSpindash before
	# Sonic_Jump.  Keeping that call behind the profile switch leaves the
	# verified Sonic 1 input path byte-for-byte equivalent in behavior.
	if physics_profile == PHYSICS_PROFILE_SONIC2 and _check_spindash():
		return
	if _try_jump():
		_spindash_duck_ready = false
		return
	_slope_resist_walk()
	_ground_move()
	_update_edge_balance()
	_try_roll(false)
	_update_spindash_duck_ready()
	_speed_to_pos()
	_angle_pos()
	_slope_repel()

func _mode_roll() -> void:
	# Sonic_MdRoll. Sonic 2 pinball_mode skips Sonic_Jump entirely.
	if not pinball_mode and _try_jump():
		return
	_slope_resist_roll()
	_roll_speed()
	_speed_to_pos()
	_angle_pos()
	_slope_repel()

func _mode_air() -> void:
	# Sonic_MdJump / Sonic_MdJump2
	_jump_height()
	_jump_direction()
	_object_fall()
	_jump_angle()
	_air_collision()

# -----------------------------------------------------------------------------
# Ground movement -- Sonic_Move / Sonic_MoveLeft / Sonic_MoveRight
# -----------------------------------------------------------------------------

func _ground_move() -> void:
	# LZWaterSlides branches directly to Sonic_AngleSpeed, bypassing walking
	# acceleration/deceleration and D-pad movement while preserving terrain flow.
	if water_slide_mode:
		skidding = false
		_angle_speed()
		_wall_speed_adjust()
		return
	# id_Stop is latched while Sonic is still sliding opposite the held input.
	# It clears once the direction changes, the button is released, or Sonic is
	# no longer on a floor-like surface.
	if skidding:
		var still_opposed = (inertia > 0 and input_left) or (inertia < 0 and input_right)
		var floor_like = ((angle + 0x20) & 0xC0) == SURFACE_FLOOR
		if not still_opposed or not floor_like:
			skidding = false
	if lock_time == 0:
		if input_left:
			_move_left()
		if input_right:
			_move_right()

	if not input_left and not input_right:
		inertia = GenesisMath.approach_zero(inertia, speed_acceleration)

	_angle_speed()
	_wall_speed_adjust()

func _move_left() -> void:
	if inertia <= 0:
		facing_left = true
		pushing = false
		skidding = false
		if physics_profile == PHYSICS_PROFILE_SONIC2:
			# S2 Sonic_MoveLeft preserves an already-over-top-speed ground inertia.
			# This is what lets CPZ boosters keep their $1000/$A00 launch speed.
			var old_inertia = inertia
			var accelerated = GenesisMath.s16(inertia - speed_acceleration)
			if accelerated <= -speed_max:
				inertia = old_inertia if old_inertia <= -speed_max else -speed_max
			else:
				inertia = accelerated
		else:
			inertia = maxi(-speed_max, inertia - speed_acceleration)
	else:
		var old_speed = inertia
		inertia -= speed_deceleration
		if inertia < 0:
			inertia = -0x80
		# Sonic_MoveLeft: on a floor, changing direction at >= $400 uses the
		# two-frame id_Stop animation while Sonic continues decelerating.
		if old_speed >= 0x400 and ((angle + 0x20) & 0xC0) == SURFACE_FLOOR:
			if not skidding:
				SonicAudio.play_sfx(SonicAudio.SFX_SKID)
			skidding = true
			facing_left = false

func _move_right() -> void:
	if inertia >= 0:
		facing_left = false
		pushing = false
		skidding = false
		if physics_profile == PHYSICS_PROFILE_SONIC2:
			# S2 Sonic_MoveRight removes this frame's acceleration and keeps the
			# old inertia if Sonic was already at/above top speed.
			var old_inertia = inertia
			var accelerated = GenesisMath.s16(inertia + speed_acceleration)
			if accelerated >= speed_max:
				inertia = old_inertia if old_inertia >= speed_max else speed_max
			else:
				inertia = accelerated
		else:
			inertia = mini(speed_max, inertia + speed_acceleration)
	else:
		var old_speed = inertia
		inertia += speed_deceleration
		if inertia > 0:
			inertia = 0x80
		if old_speed <= -0x400 and ((angle + 0x20) & 0xC0) == SURFACE_FLOOR:
			if not skidding:
				SonicAudio.play_sfx(SonicAudio.SFX_SKID)
			skidding = true
			facing_left = true

func _angle_speed() -> void:
	vel_x = GenesisMath.s16((GenesisMath.cosine(angle) * inertia) >> 8)
	vel_y = GenesisMath.s16((GenesisMath.sine(angle) * inertia) >> 8)

# Translation of Sonic_WallSpeedAdjust + Sonic_CalcRoomAhead.  The sensor is
# evaluated at Sonic's predicted next-frame position, just like the 68000 code.
func _wall_speed_adjust() -> void:
	if inertia == 0:
		return

	# Original Sonic 1 deliberately skips this push sensor on the underside of
	# curved terrain/loops.  (The disassembly's FixBugs path changes this.)
	if GenesisMath.s8((angle + 0x40) & 0xFF) < 0:
		return

	var collision_angle := (angle + (0x40 if inertia < 0 else -0x40)) & 0xFF
	var result := _calc_room_ahead(collision_angle)
	var dist := int(result["distance"])
	if dist > 0:
		return

	# A zero-distance side sensor means Sonic is already exactly flush with a
	# wall. Treat that as maintained pushing contact instead of waiting for a
	# one-pixel penetration on a later frame. This prevents the push/no-push
	# oscillation that looked like Sonic vibrating against horizontal terrain.
	var correction := dist << 8
	match (collision_angle + 0x20) & 0xC0:
		SURFACE_FLOOR:
			vel_y = GenesisMath.s16(vel_y + correction)
		SURFACE_LEFT_WALL:
			vel_x = GenesisMath.s16(vel_x - correction)
			inertia = 0
			pushing = true
		SURFACE_CEILING:
			vel_y = GenesisMath.s16(vel_y - correction)
		SURFACE_RIGHT_WALL:
			vel_x = GenesisMath.s16(vel_x + correction)
			inertia = 0
			pushing = true

func _calc_room_ahead(collision_angle: int) -> Dictionary:
	var predicted_x := int((fixed_x + (vel_x << 8)) >> 16)
	var predicted_y := int((fixed_y + (vel_y << 8)) >> 16)
	var direction := _classify_surface_exact(collision_angle)

	match direction:
		SURFACE_FLOOR:
			return _query_floor(predicted_x, predicted_y + SONIC_QUICK_SIZE, false, false, false)
		SURFACE_CEILING:
			return _query_floor(predicted_x, (predicted_y - SONIC_QUICK_SIZE) ^ 0xF, false, true, false)
		SURFACE_LEFT_WALL:
			var left_sensor_y := predicted_y + (8 if (collision_angle & 0x38) == 0 else 0)
			return _query_wall((predicted_x - SONIC_QUICK_SIZE) ^ 0xF, left_sensor_y, true, false)
		SURFACE_RIGHT_WALL:
			var right_sensor_y := predicted_y + (8 if (collision_angle & 0x38) == 0 else 0)
			return _query_wall(predicted_x + SONIC_QUICK_SIZE, right_sensor_y, false, false)

	return {"distance": 15}

# -----------------------------------------------------------------------------
# Phase 78 -- Sonic 1 balance + optional Sonic 2 spindash
# -----------------------------------------------------------------------------

func set_sonic2_physics_enabled(enabled: bool) -> void:
	physics_profile = PHYSICS_PROFILE_SONIC2 if enabled else PHYSICS_PROFILE_SONIC1
	_spindash_duck_ready = false
	if not enabled and spindash_active:
		_cancel_spindash_charge()

func toggle_sonic2_physics() -> void:
	set_sonic2_physics_enabled(physics_profile != PHYSICS_PROFILE_SONIC2)

func sonic2_physics_enabled() -> bool:
	return physics_profile == PHYSICS_PROFILE_SONIC2

func physics_profile_name() -> String:
	return "SONIC 2" if sonic2_physics_enabled() else "SONIC 1"

func cycle_animation_style() -> void:
	animation_style = (animation_style + 1) % 3
	if visual != null:
		visual.force_animation_refresh()

func animation_style_name() -> String:
	match animation_style:
		ANIMATION_STYLE_SONIC2_BETA:
			return "S2 BETA"
		ANIMATION_STYLE_SONIC2_FINAL:
			return "S2 FINAL"
		_:
			return "SONIC 1"

func _cancel_spindash_charge() -> void:
	spindash_active = false
	spindash_counter = 0
	_spindash_duck_ready = false
	vel_x = 0
	vel_y = 0
	inertia = 0

func _update_spindash_duck_ready() -> void:
	if physics_profile != PHYSICS_PROFILE_SONIC2:
		_spindash_duck_ready = false
		return
	# Sonic_CheckSpindash tests whether the previous animation is id_Duck.
	# Requiring this one-frame grounded crouch reproduces the source ordering:
	# pressing Down+Jump simultaneously from idle still jumps instead of dashing.
	_spindash_duck_ready = (
		not in_air
		and not rolling
		and not edge_balance
		and not pushing
		and inertia == 0
		and ((angle + 0x20) & 0xC0) == SURFACE_FLOOR
		and input_down
		and not input_left
		and not input_right
	)

func _check_spindash() -> bool:
	if spindash_active:
		edge_balance = false
		if not input_down:
			_release_spindash()
		else:
			# Sonic_ChargingSpindash: the charge decays by 1/32 every frame,
			# and each new A/B/C press contributes $200 up to $800.
			if spindash_counter != 0:
				spindash_counter -= spindash_counter >> 5
				spindash_counter = maxi(0, spindash_counter)
			if spindash_rev_pressed:
				spindash_counter = mini(0x800, spindash_counter + 0x200)
				# The S2 rev sample is not yet part of the S1 native SFX bank.
				# Use the existing roll sample for the event rather than inventing
				# synthesis data; the movement/charge values are source-exact.
				SonicAudio.play_sfx(SonicAudio.SFX_ROLL)
		_angle_pos()
		return true

	if not _spindash_duck_ready or not jump_pressed:
		return false

	# Sonic_CheckSpindash initialization.  The first button press starts the
	# charge at zero; later presses are what raise spindash_counter.
	spindash_active = true
	spindash_counter = 0
	_spindash_duck_ready = false
	edge_balance = false
	skidding = false
	pushing = false
	inertia = 0
	vel_x = 0
	vel_y = 0
	SonicAudio.play_sfx(SonicAudio.SFX_ROLL)
	_angle_pos()
	return true

func _release_spindash() -> void:
	spindash_active = false
	_spindash_duck_ready = false
	var speed_index = clampi((spindash_counter >> 8) & 0xFF, 0, S2_SPINDASH_SPEEDS.size() - 1)
	spindash_counter = 0
	rolling = true
	height_radius = SONIC_ROLL_HEIGHT
	width_radius = SONIC_ROLL_WIDTH
	_add_pixel_y(SONIC_HEIGHT - SONIC_ROLL_HEIGHT)
	inertia = S2_SPINDASH_SPEEDS[speed_index]
	if facing_left:
		inertia = -inertia
	# Sonic_UpdateSpindash writes inertia and skips the rest of MdNormal; the
	# rolling routine derives X/Y velocity from inertia on the following tick.
	vel_x = 0
	vel_y = 0
	SonicAudio.play_sfx(SonicAudio.SFX_ROLL)

func _update_edge_balance() -> void:
	# Sonic 1's Sonic_Move checks this only while motionless on a flat floor.
	# The port previously jumped straight from standing to look/duck animation,
	# so fr_Balance1/$3A and fr_Balance2/$3B were never selected.
	edge_balance = false
	if in_air or rolling or inertia != 0 or pushing:
		return
	if ((angle + 0x20) & 0xC0) != SURFACE_FLOOR:
		return

	var x = pixel_x()
	if standing_on_object:
		# The OST check compares Sonic's center against the supporting object's
		# physical edges.  support_left/right already store those source-style
		# center-X bounds, so no Sonic-width expansion belongs here.
		if x < support_left + 4:
			facing_left = true
			edge_balance = true
		elif x >= support_right - 4:
			facing_left = false
			edge_balance = true
		return

	var y = pixel_y()
	# ObjFloorDist first requires at least 12 px of empty space below Sonic's
	# center before the angle-buffer edge sentinels are accepted.
	var center = collision.find_floor(x, y + height_radius, 13, 16, 0, collision_path)
	if int(center.get("distance", 0)) < 12:
		return
	var right = collision.find_floor(x + width_radius, y + height_radius, 13, 16, 0, collision_path)
	var left = collision.find_floor(x - width_radius, y + height_radius, 13, 16, 0, collision_path)
	var right_blank = not bool(right.get("angle_written", false))
	var left_blank = not bool(left.get("angle_written", false))
	if right_blank and not left_blank:
		facing_left = false
		edge_balance = true
	elif left_blank and not right_blank:
		facing_left = true
		edge_balance = true

# -----------------------------------------------------------------------------
# Rolling -- Sonic_Roll / Sonic_RollSpeed / Sonic_RollLeft / Sonic_RollRight
# -----------------------------------------------------------------------------

func _try_roll(force: bool) -> void:
	if water_slide_mode:
		return
	if rolling:
		return
	if not force:
		if absi(inertia) < 0x80:
			return
		if input_left or input_right or not input_down:
			return
	_start_roll()

func _start_roll() -> void:
	SonicAudio.play_sfx(SonicAudio.SFX_ROLL)
	rolling = true
	height_radius = SONIC_ROLL_HEIGHT
	width_radius = SONIC_ROLL_WIDTH
	_add_pixel_y(SONIC_HEIGHT - SONIC_ROLL_HEIGHT)
	if inertia == 0:
		inertia = 0x200

func _roll_speed() -> void:
	# Sonic_RollSpeed uses the same slide-mode short path as Sonic_Move: no roll
	# steering/drag, only angle-derived velocity followed by wall response.
	if water_slide_mode:
		vel_y = clampi(GenesisMath.s16((GenesisMath.sine(angle) * inertia) >> 8), -0x1000, 0x1000)
		vel_x = clampi(GenesisMath.s16((GenesisMath.cosine(angle) * inertia) >> 8), -0x1000, 0x1000)
		_wall_speed_adjust()
		return
	# Sonic_RollSpeed loads v_sonspeedmax*2 into d6, but retail Sonic 1 never
	# consumes d6 to clamp obInertia. Downhill rolling is therefore allowed to
	# build beyond $C00; only the angle-derived X/Y velocity components are
	# capped to +/-$1000 below.
	var roll_acc := speed_acceleration >> 1
	# Retail S2 Sonic hardcodes $20 here.  S1 derives deceleration/4, which
	# matters underwater because the runtime deceleration becomes $40.
	var roll_dec := 0x20 if physics_profile == PHYSICS_PROFILE_SONIC2 else (speed_deceleration >> 2)

	if lock_time == 0:
		if input_left:
			if inertia <= 0:
				facing_left = true
			else:
				inertia -= roll_dec
				if inertia < 0:
					inertia = -0x80
		if input_right:
			if inertia >= 0:
				facing_left = false
			else:
				inertia += roll_dec
				if inertia > 0:
					inertia = 0x80

	# Sonic 1 applies constant rolling drag even without direction input. Keep
	# the full 16-bit ground inertia: there is deliberately no +/-$C00 clamp.
	inertia = GenesisMath.approach_zero(inertia, roll_acc)
	inertia = GenesisMath.s16(inertia)

	if inertia == 0:
		if pinball_mode:
			# Retail Sonic 2 forces +/-$400 when a pinball-mode roll would stop.
			inertia = -0x400 if facing_left else 0x400
		else:
			rolling = false
			height_radius = SONIC_HEIGHT
			width_radius = SONIC_WIDTH
			_add_pixel_y(-(SONIC_HEIGHT - SONIC_ROLL_HEIGHT))

	var roll_vel_y = GenesisMath.s16((GenesisMath.sine(angle) * inertia) >> 8)
	# Sonic 1 caps both roll components to +/-$1000.  Sonic 2 only caps X.
	vel_y = roll_vel_y if physics_profile == PHYSICS_PROFILE_SONIC2 else clampi(roll_vel_y, -0x1000, 0x1000)
	vel_x = clampi(GenesisMath.s16((GenesisMath.cosine(angle) * inertia) >> 8), -0x1000, 0x1000)
	_wall_speed_adjust()

# -----------------------------------------------------------------------------
# Jumping and air movement -- Sonic_Jump / JumpHeight / JumpDirection / ObjectFall
# -----------------------------------------------------------------------------

func _try_jump() -> bool:
	if not jump_pressed:
		return false
	if _headroom_distance() < 6:
		return false

	var jump_angle := (angle - 0x40) & 0xFF
	var jump_speed := 0x380 if underwater else JUMP_SPEED
	vel_x = GenesisMath.s16(vel_x + ((GenesisMath.cosine(jump_angle) * jump_speed) >> 8))
	vel_y = GenesisMath.s16(vel_y + ((GenesisMath.sine(jump_angle) * jump_speed) >> 8))
	# Sonic_Jump sets the airborne bit but deliberately leaves the platform
	# status bit set until the owning object's ExitPlatform runs later in the
	# same frame. That object then performs one final MvSonicOnPtfm carry.
	skidding = false
	in_air = true
	pushing = false
	jumping = true

	if rolling:
		roll_jump_lock = true
	else:
		rolling = true
		height_radius = SONIC_ROLL_HEIGHT
		width_radius = SONIC_ROLL_WIDTH
		_add_pixel_y(SONIC_HEIGHT - SONIC_ROLL_HEIGHT)
	SonicAudio.play_sfx(SonicAudio.SFX_JUMP)
	return true

func _jump_height() -> void:
	if jumping:
		var release_cap := -0x200 if underwater else -0x400
		if vel_y < release_cap and not jump_held:
			vel_y = release_cap
	else:
		# Sonic 2 pinball_mode bypasses Sonic_UpVelCap for object-launched rolls.
		if not pinball_mode:
			vel_y = clampi(vel_y, -0xFC0, 0xFC0)

func _jump_direction() -> void:
	if not roll_jump_lock:
		var air_acc := speed_acceleration << 1
		if input_left:
			facing_left = true
			vel_x = maxi(-speed_max, vel_x - air_acc)
		if input_right:
			facing_left = false
			vel_x = mini(speed_max, vel_x + air_acc)

	# Sonic_AirDrag: only near the upward apex of a jump.
	if vel_y < 0 and vel_y >= -0x400:
		var drag := vel_x >> 5
		if drag != 0:
			vel_x = GenesisMath.approach_zero(vel_x, absi(drag))

func _object_fall() -> void:
	# Exact order from ObjectFall: move using current velocity, then gravity is
	# stored for the next frame.
	fixed_x += vel_x << 8
	fixed_y += vel_y << 8
	vel_y = GenesisMath.s16(vel_y + (0x10 if underwater else GRAVITY))

func _speed_to_pos() -> void:
	fixed_x += vel_x << 8
	fixed_y += vel_y << 8

func _jump_angle() -> void:
	var signed_angle := GenesisMath.s8(angle)
	if signed_angle > 0:
		signed_angle = maxi(0, signed_angle - 2)
	elif signed_angle < 0:
		signed_angle = mini(0, signed_angle + 2)
	angle = signed_angle & 0xFF
	# Retail S2 falls straight through from Sonic_JumpAngle into Sonic_JumpFlip.
	_update_s2_twirl_angle()

# -----------------------------------------------------------------------------
# Slope force and surface attachment -- Sonic_SlopeResist* / Sonic_AnglePos
# -----------------------------------------------------------------------------

func _slope_resist_walk() -> void:
	if ((angle + 0x60) & 0xFF) >= 0xC0 or inertia == 0:
		return
	var force := (GenesisMath.sine(angle) * 0x20) >> 8
	inertia = GenesisMath.s16(inertia + force)

func _slope_resist_roll() -> void:
	if ((angle + 0x60) & 0xFF) >= 0xC0:
		return
	var force := (GenesisMath.sine(angle) * 0x50) >> 8
	if inertia >= 0:
		if force < 0:
			force >>= 2
	else:
		if force >= 0:
			force >>= 2
	inertia = GenesisMath.s16(inertia + force)

func _slope_repel() -> void:
	if lock_time > 0:
		lock_time -= 1
		return
	if ((angle + 0x20) & 0xC0) == SURFACE_FLOOR:
		return
	if absi(inertia) >= 0x280:
		return
	inertia = 0
	clear_object_support()
	in_air = true
	pushing = false
	lock_time = 30

func _angle_pos() -> void:
	# The original Sonic_AnglePos exits immediately while Sonic is standing on
	# an OST platform (obStatus bit 3). Preserve the same distinction here so
	# terrain beneath a rock/monitor does not toggle Sonic into AIR every tick.
	if standing_on_object:
		# Sonic_AnglePos does nothing except clear its angle hot-spots while
		# obStatus bit 3 says Sonic is on a platform. ExitPlatform belongs to
		# the platform object's later ExecuteObjects pass; Sonic_AnglePos does
		# not expand the platform by obWidth, re-test X, or re-snap Y here.
		return

	match _surface_quadrant():
		SURFACE_FLOOR:
			_attach_floor()
		SURFACE_LEFT_WALL:
			_attach_left_wall()
		SURFACE_CEILING:
			_attach_ceiling()
		SURFACE_RIGHT_WALL:
			_attach_right_wall()

func _attach_floor() -> void:
	var x := pixel_x()
	var y := pixel_y()
	var previous_angle = angle
	var right := _query_floor(x + width_radius, y + height_radius, true, false, true)
	var left := _query_floor(x - width_radius, y + height_radius, true, false, true)
	var hit := _choose_ground_sensor(right, left)
	angle = int(hit["resolved_angle"])
	var distance = int(hit["distance"])
	if _rolling_convex_floor_snap(previous_angle, angle, distance):
		# SLZ3's steep downhill transition around source X $400 changes from
		# angle $20 to $38 in one 16x16 seam. Depending on the 16.16 subpixel
		# phase, the native update can sample 15-21px below Sonic for one frame
		# and falsely enter AIR even though both sensors selected continuous solid
		# terrain. Preserve rolling contact for this one-frame convex transition.
		_add_pixel_y(distance)
		return
	_resolve_ground_distance(distance, Vector2i(0, 1))

func _rolling_convex_floor_snap(previous_angle: int, new_angle: int, distance: int) -> bool:
	# Phase 39: the authored SLZ3 downhill seam around X $400 spans several
	# sensor frames, not only the first $20->$38 angle-change frame. The 68000
	# velocity/position order carries Sonic farther down the convex face before
	# Sonic_AnglePos samples it; the native 16.16 order can leave the chosen
	# ground sensor 15-28px above the same continuous floor for a frame or two.
	# Keep this compatibility bridge local to the reported seam and only while
	# rolling downhill on floor-class surfaces.
	if object_manager == null:
		return false
	var level_definition = object_manager.level_definition
	if int(level_definition.get("zone", -1)) != LevelCatalog.ZONE_SLZ or int(level_definition.get("act", 0)) != 3:
		return false
	var world_x = pixel_x()
	if world_x < 0x3E8 or world_x > 0x418:
		return false
	if not rolling or distance <= 14 or distance > 28:
		return false
	if _classify_surface_exact(previous_angle) != SURFACE_FLOOR or _classify_surface_exact(new_angle) != SURFACE_FLOOR:
		return false
	# Do not bridge onto a flat/blank sentinel. The authored transition is the
	# $20/$38 downhill pair; accepting either angle also covers the later frame
	# where the angle has already become $38 but the sensor gap still exists.
	var resolved = new_angle & 0xFF
	if resolved != 0x20 and resolved != 0x38:
		return false
	return GenesisMath.sine(resolved) * inertia > 0

func _attach_right_wall() -> void:
	var x := pixel_x()
	var y := pixel_y()
	var upper := _query_wall(x + height_radius, y - width_radius, false, true)
	var lower := _query_wall(x + height_radius, y + width_radius, false, true)
	var hit := _choose_ground_sensor(upper, lower)
	angle = int(hit["resolved_angle"])
	_resolve_ground_distance(int(hit["distance"]), Vector2i(1, 0))

func _attach_ceiling() -> void:
	var x := pixel_x()
	var y := pixel_y()
	var right := _query_floor(x + width_radius, (y - height_radius) ^ 0xF, true, true, true)
	var left := _query_floor(x - width_radius, (y - height_radius) ^ 0xF, true, true, true)
	var hit := _choose_ground_sensor(right, left)
	angle = int(hit["resolved_angle"])
	_resolve_ground_distance(int(hit["distance"]), Vector2i(0, -1))

func _attach_left_wall() -> void:
	var x := pixel_x()
	var y := pixel_y()
	var upper := _query_wall((x - height_radius) ^ 0xF, y - width_radius, true, true)
	var lower := _query_wall((x - height_radius) ^ 0xF, y + width_radius, true, true)
	var hit := _choose_ground_sensor(upper, lower)
	angle = int(hit["resolved_angle"])
	_resolve_ground_distance(int(hit["distance"]), Vector2i(-1, 0))

func _resolve_ground_distance(distance: int, surface_normal: Vector2i) -> void:
	if distance < -14:
		# Matches the original dead-code guard for being deeply inside terrain.
		return
	if distance > 14:
		# SBZ Object $67 sets sticktoconvex while Sonic is running around a gear.
		# Sonic_AnglePos then deliberately accepts floor/wall/ceiling distances
		# greater than 14px instead of detaching from the convex surface.
		if stick_to_convex:
			_add_pixel_x(surface_normal.x * distance)
			_add_pixel_y(surface_normal.y * distance)
			return
		in_air = true
		pushing = false
		return
	_add_pixel_x(surface_normal.x * distance)
	_add_pixel_y(surface_normal.y * distance)

# -----------------------------------------------------------------------------
# Air collision -- Sonic_Floor and the four directional branches
# -----------------------------------------------------------------------------

func _air_collision() -> void:
	var movement_angle := GenesisMath.calc_angle(vel_x, vel_y)
	var direction := ((movement_angle - 0x20) & 0xFF) & 0xC0
	match direction:
		SURFACE_FLOOR:
			_air_down()
		SURFACE_LEFT_WALL:
			_air_left()
		SURFACE_CEILING:
			_air_up()
		SURFACE_RIGHT_WALL:
			_air_right()

func _air_down() -> void:
	_hit_quick_left_wall()
	_hit_quick_right_wall()
	var floor_hit := _find_floor_full()
	if int(floor_hit["distance"]) < 0 and _floor_depth_is_valid(floor_hit):
		_land_from_down(floor_hit)

func _air_left() -> void:
	if _hit_quick_left_wall():
		inertia = vel_y
		return
	_hit_ceiling(false)
	if vel_y >= 0:
		var floor_hit := _find_floor_full()
		if int(floor_hit["distance"]) < 0 and _floor_depth_is_valid(floor_hit):
			_land_flat_from_side(floor_hit)

func _air_right() -> void:
	if _hit_quick_right_wall():
		inertia = vel_y
		return
	_hit_ceiling(false)
	if vel_y >= 0:
		var floor_hit := _find_floor_full()
		if int(floor_hit["distance"]) < 0 and _floor_depth_is_valid(floor_hit):
			_land_flat_from_side(floor_hit)

func _air_up() -> void:
	_hit_quick_left_wall()
	_hit_quick_right_wall()
	var ceiling_hit := _find_ceiling_full()
	if int(ceiling_hit["distance"]) >= 0:
		return
	_add_pixel_y(-int(ceiling_hit["distance"]))
	_clear_subpixel_y()
	var hit_angle := int(ceiling_hit["resolved_angle"])
	if ((hit_angle + 0x20) & 0x40) == 0:
		if vel_y < 0:
			vel_y = 0
		return
	angle = hit_angle
	_reset_on_floor()
	inertia = vel_y
	if GenesisMath.s8(hit_angle) < 0:
		inertia = -inertia

func _hit_quick_left_wall() -> bool:
	var result := _query_wall((pixel_x() - SONIC_QUICK_SIZE) ^ 0xF, pixel_y(), true, false)
	var dist := int(result["distance"])
	if dist >= 0:
		return false
	_add_pixel_x(-dist)
	_clear_subpixel_x()
	vel_x = 0
	return true

func _hit_quick_right_wall() -> bool:
	var result := _query_wall(pixel_x() + SONIC_QUICK_SIZE, pixel_y(), false, false)
	var dist := int(result["distance"])
	if dist >= 0:
		return false
	_add_pixel_x(dist)
	_clear_subpixel_x()
	vel_x = 0
	return true

func _hit_ceiling(allow_attach: bool) -> bool:
	var hit := _find_ceiling_full()
	var dist := int(hit["distance"])
	if dist >= 0:
		return false
	_add_pixel_y(-dist)
	_clear_subpixel_y()
	if vel_y < 0:
		vel_y = 0
	if allow_attach:
		angle = int(hit["resolved_angle"])
	return true

func _find_floor_full() -> Dictionary:
	var x := pixel_x()
	var y := pixel_y() + height_radius
	var right := _query_floor(x + width_radius, y, true, false, false)
	var left := _query_floor(x - width_radius, y, true, false, false)
	return _choose_air_sensor(right, left, SURFACE_FLOOR)

func _find_ceiling_full() -> Dictionary:
	var x := pixel_x()
	var y := (pixel_y() - height_radius) ^ 0xF
	var right := _query_floor(x + width_radius, y, false, true, false)
	var left := _query_floor(x - width_radius, y, false, true, false)
	return _choose_air_sensor(right, left, SURFACE_CEILING)

func _floor_depth_is_valid(hit: Dictionary) -> bool:
	if (int(hit["word"]) & 0x4000) != 0:
		return true
	var max_penetration := (maxi(0, vel_y) >> 8) + 8
	return int(hit["distance"]) >= -max_penetration

func _land_from_down(hit: Dictionary) -> void:
	var dist := int(hit["distance"])
	_add_pixel_y(dist)
	_clear_subpixel_y()
	var landing_angle := int(hit["resolved_angle"])
	angle = landing_angle
	_reset_on_floor()

	var slope := _slope_magnitude(landing_angle)
	if slope < 0x11:
		vel_y = 0
		inertia = vel_x
	elif slope < 0x20:
		vel_y >>= 1
		inertia = vel_y
		if GenesisMath.s8(landing_angle) < 0:
			inertia = -inertia
	else:
		vel_x = 0
		vel_y = mini(vel_y, 0xFC0)
		inertia = vel_y
		if GenesisMath.s8(landing_angle) < 0:
			inertia = -inertia

func _land_flat_from_side(hit: Dictionary) -> void:
	_add_pixel_y(int(hit["distance"]))
	_clear_subpixel_y()
	angle = int(hit["resolved_angle"])
	_reset_on_floor()
	vel_y = 0
	inertia = vel_x

func _reset_on_floor() -> void:
	clear_object_support()
	skidding = false
	edge_balance = false
	spindash_active = false
	spindash_counter = 0
	_spindash_duck_ready = false
	_clear_s2_twirl()
	pushing = false
	in_air = false
	roll_jump_lock = false
	if rolling and not pinball_mode:
		rolling = false
		height_radius = SONIC_HEIGHT
		width_radius = SONIC_WIDTH
		_add_pixel_y(-(SONIC_HEIGHT - SONIC_ROLL_HEIGHT))
	jumping = false
	if object_manager != null:
		object_manager.reset_item_bonus()

# -----------------------------------------------------------------------------
# Collision wrappers and headroom
# -----------------------------------------------------------------------------

func _headroom_distance() -> int:
	match _surface_quadrant():
		SURFACE_FLOOR:
			return int(_find_ceiling_full()["distance"])
		SURFACE_LEFT_WALL:
			return int(_find_right_wall_full()["distance"])
		SURFACE_CEILING:
			return int(_find_floor_full()["distance"])
		SURFACE_RIGHT_WALL:
			return int(_find_left_wall_full()["distance"])
	return 15

func _find_right_wall_full() -> Dictionary:
	var x := pixel_x() + height_radius
	var upper := _query_wall(x, pixel_y() - width_radius, false, false)
	var lower := _query_wall(x, pixel_y() + width_radius, false, false)
	return _choose_air_sensor(upper, lower, SURFACE_RIGHT_WALL)

func _find_left_wall_full() -> Dictionary:
	var x := (pixel_x() - height_radius) ^ 0xF
	var upper := _query_wall(x, pixel_y() - width_radius, true, false)
	var lower := _query_wall(x, pixel_y() + width_radius, true, false)
	return _choose_air_sensor(upper, lower, SURFACE_LEFT_WALL)

func _query_floor(x: int, y: int, top_solid: bool, ceiling: bool, ground_surface: bool) -> Dictionary:
	var result: Dictionary
	if ceiling:
		result = collision.find_floor(x, y, 13 if top_solid else 14, -16, 0x1000, collision_path)
	else:
		result = collision.find_floor(x, y, 13 if top_solid else 14, 16, 0, collision_path)

	# Sonic_AnglePos preloads v_anglebuffer/v_anglebuffer2 with $03 before
	# running the two ground sensors. FindFloor only overwrites that byte when
	# it actually finds a collision shape. Keeping $03 for a blank/non-solid
	# neighbor is critical around the GHZ loop: bit 0 marks it as a sentinel,
	# so Sonic_Angle snaps from Sonic's previous angle instead of incorrectly
	# resetting the surface angle to flat $00.
	if ground_surface and not bool(result.get("angle_written", false)):
		result["angle"] = 0x03

	# The 68000 passes an XOR-$F coordinate to upward sensors so FindFloor can
	# traverse 16px tiles in the negative direction.  That aligned coordinate is
	# an implementation detail, not the physical sensor ball.  Drawing it
	# directly made the F2 top sensors jump in 16px-looking steps.
	var debug_y = (y ^ 0x0F) if ceiling else y
	_record_query(Vector2(x, debug_y), result, Vector2.UP if ceiling else Vector2.DOWN, ground_surface)
	return result

func _query_wall(x: int, y: int, left: bool, top_solid: bool) -> Dictionary:
	var result: Dictionary
	if left:
		result = collision.find_wall(x, y, 13 if top_solid else 14, -16, 0x0800, collision_path)
	else:
		result = collision.find_wall(x, y, 13 if top_solid else 14, 16, 0, collision_path)

	# Grounded wall/ceiling attachment uses the same $03 angle-buffer preload
	# as the floor path above. Quick all-solid wall probes intentionally keep
	# their own cardinal-angle behavior and therefore do not use this fallback.
	if top_solid and not bool(result.get("angle_written", false)):
		result["angle"] = 0x03

	# Left-facing FindWall calls likewise receive X ^ $F for the negative tile
	# traversal. Recover the logical sensor origin for F2 so its orange ball
	# remains attached to Sonic instead of appearing to sweep/jitter horizontally.
	var debug_x = (x ^ 0x0F) if left else x
	_record_query(Vector2(debug_x, y), result, Vector2.LEFT if left else Vector2.RIGHT, top_solid)
	return result

# Grounded Sonic_Angle. d0 is the first sensor distance and d1 is the
# second sensor distance. The 68000 keeps d1 when distances are equal.
# Odd/$03 angle-buffer values snap from Sonic's PREVIOUS ground angle.
func _choose_ground_sensor(d0_result: Dictionary, d1_result: Dictionary) -> Dictionary:
	var chosen: Dictionary = d1_result if int(d1_result["distance"]) <= int(d0_result["distance"]) else d0_result
	var result := chosen.duplicate()
	var resolved := int(chosen["angle"]) & 0xFF
	if (resolved & 1) != 0:
		resolved = (angle + 0x20) & 0xC0
	result["resolved_angle"] = resolved
	return result

# Airborne Sonic_FindSmaller. This is deliberately NOT Sonic_Angle: when the
# selected collision angle has bit 0 set, the original copies d2 (the cardinal
# direction of the collision query) into d3. Carrying Sonic's old loop angle
# here made him re-land tilted after a momentary loop detachment.
func _choose_air_sensor(d0_result: Dictionary, d1_result: Dictionary, snap_angle: int) -> Dictionary:
	var chosen: Dictionary = d1_result if int(d1_result["distance"]) <= int(d0_result["distance"]) else d0_result
	var result := chosen.duplicate()
	var resolved := int(chosen["angle"]) & 0xFF
	if (resolved & 1) != 0:
		resolved = snap_angle & 0xFF
	result["resolved_angle"] = resolved
	return result

func _record_query(point: Vector2, result: Dictionary, direction: Vector2, ground_surface: bool) -> void:
	if not sensor_debug:
		return
	_debug_queries.append({
		"point": point,
		"target": point + direction * float(int(result["distance"])),
		"ground": ground_surface,
	})

# -----------------------------------------------------------------------------
# Level-object interaction bridge -- SolidObject/Springs/ReactToItem groundwork
# -----------------------------------------------------------------------------

func begin_s2_spring_visual(source_subtype: int, spring_orientation: int) -> void:
	# Phase 83: preserve Object $41's orientation-specific animation behavior.
	# Retail S2 explicitly assigns the Spring animation only for upward and
	# diagonally-up launches. Horizontal, downward, and diagonally-down springs do
	# not force that pose. This also prevents an S1-style Sonic from showing the
	# spring frame when a horizontal spring hits him from the side.
	_clear_s2_twirl()
	var source_uses_spring_pose = spring_orientation == 0 or spring_orientation == 3

	if animation_style == ANIMATION_STYLE_SONIC1:
		# Keep the user-selected S1-compatible spring presentation for vertical
		# and angled launches, but horizontal springs are a side shove in the
		# source and must not force the airborne spring frame.
		spring_pose_timer = 0 if spring_orientation == 1 else 48
		return

	# Object $41 bit 0 enables S2's flip_angle/flips_remaining path. Beta/Final
	# animation profiles honor that tumble on every orientation; otherwise they
	# only force the spring pose on the two source orientations that actually set
	# AniIDSonAni_Spring.
	if (source_subtype & 1) != 0:
		spring_pose_timer = 0
		s2_twirl_active = true
		s2_twirl_speed = 4 if spring_orientation in [0, 2] else 8
		if spring_orientation in [0, 2]:
			s2_twirl_remaining = 0 if (source_subtype & 2) != 0 else 1
		else:
			s2_twirl_remaining = 1 if (source_subtype & 2) != 0 else 3
		s2_twirl_direction = -1 if facing_left else 1
		s2_twirl_angle = 0xFF if facing_left else 1
		s2_twirl_turned = false
	else:
		spring_pose_timer = 48 if source_uses_spring_pose else 0

func _update_s2_twirl_angle() -> void:
	if not s2_twirl_active:
		return
	var old_angle = s2_twirl_angle & 0xFF
	var advanced = 0
	if s2_twirl_direction >= 0:
		advanced = old_angle + s2_twirl_speed
		s2_twirl_angle = advanced & 0xFF
		if advanced > 0xFF:
			s2_twirl_remaining -= 1
	else:
		advanced = old_angle - s2_twirl_speed
		s2_twirl_angle = advanced & 0xFF
		if advanced < 0:
			s2_twirl_remaining -= 1
	if s2_twirl_remaining < 0:
		_clear_s2_twirl()

func _clear_s2_twirl() -> void:
	s2_twirl_active = false
	s2_twirl_angle = 0
	s2_twirl_speed = 0
	s2_twirl_remaining = 0
	s2_twirl_direction = 1
	s2_twirl_turned = false

func spring_bounce(direction: Vector2i, power: int) -> void:
	_clear_s2_twirl()
	SonicAudio.play_sfx(SonicAudio.SFX_SPRING)
	if direction.x != 0:
		# Spring_LR only writes obVelX/obInertia, flips Sonic's orientation, and
		# clears pushing. It deliberately does NOT set the airborne bit. This is
		# essential for the X-flipped LZ2 spring at $05F8,$01F0: Sonic must stay
		# attached to the terrain instead of being launched sideways into freefall.
		vel_x = direction.x * power
		inertia = vel_x
		spring_pose_timer = 0
		facing_left = not facing_left
		pushing = false
		_sync_position()
		return

	clear_object_support()
	vel_y = direction.y * power
	# Spring_Up explicitly selects id_Spring ($10). Spring_Down does not.
	# The script holds fr_Spring ($40) for 48 ticks before id_Walk.
	spring_pose_timer = 48 if direction.y < 0 else 0
	in_air = true
	pushing = false
	jumping = false
	roll_jump_lock = false
	_sync_position()

func _validate_object_support() -> void:
	# The 68000 Sonic object does not run ExitPlatform itself. While obStatus
	# bit 3 is set, Sonic_AnglePos simply returns; the owning platform gets the
	# chance to run ExitPlatform later in ExecuteObjects. Keep this hook limited
	# to states that cannot legally retain object support at frame start.
	if not standing_on_object:
		return
	if dead or hurt_state:
		clear_object_support()

func clear_object_support() -> void:
	standing_on_object = false
	s2_spiral_pathway_active = false
	s2_spiral_visual_angle = 0
	support_left = 0
	support_right = 0
	support_top = 0
	support_record_index = -1
	support_refreshed_this_pass = false

func begin_s2_spiral_pathway(record_index: int, left_x: int, right_x: int) -> void:
	# RideObject_SetRide: transfer support ownership, flatten the physical angle,
	# zero Y velocity, and seed inertia from current horizontal velocity. Obj06
	# only calls this for grounded Sonic, but keep the reset branch source-safe.
	clear_object_support()
	angle = 0
	vel_y = 0
	inertia = vel_x
	if in_air:
		_reset_on_floor()
	_set_object_support(left_x, right_x, pixel_y() + height_radius, record_index)
	s2_spiral_pathway_active = true
	s2_spiral_visual_angle = 0
	_sync_position()

func update_s2_spiral_pathway(record_index: int, left_x: int, right_x: int, center_y: int, visual_angle: int) -> void:
	if not standing_on_object or support_record_index != record_index or dead:
		return
	# Obj06 writes integer y_pos directly and leaves horizontal movement under
	# Sonic_MdNormal. Preserve the subpixel word while replacing the integer Y.
	fixed_y = (center_y << 16) | (fixed_y & 0xFFFF)
	support_left = left_x
	support_right = right_x
	support_top = center_y + height_radius
	support_refreshed_this_pass = true
	s2_spiral_pathway_active = true
	s2_spiral_visual_angle = visual_angle & 0xFF
	_sync_position()

func end_s2_spiral_pathway(record_index: int) -> void:
	if standing_on_object and support_record_index == record_index:
		clear_object_support()

func animation_surface_angle() -> int:
	return s2_spiral_visual_angle if s2_spiral_pathway_active else angle

func begin_object_support_pass() -> void:
	# Called immediately before ExecuteObjects. A valid stood-on object must call
	# resolve_platform_top/snap_supported_slope/move_with_supported_object during
	# this pass, just as the 68000 object's stood-on routine owns obStatus bit 3.
	support_refreshed_this_pass = false
	support_exit_block_record_index = -2147483648

func end_object_support_pass() -> void:
	if standing_on_object and not support_refreshed_this_pass:
		clear_object_support()

func clear_object_support_for(record_index: int, become_airborne: bool = false) -> void:
	if standing_on_object and support_record_index == record_index:
		clear_object_support()
		if become_airborne and not dead and not hurt_state:
			in_air = true
			pushing = false

func _set_object_support(left_x: int, right_x: int, top_y: int, record_index: int = -1) -> void:
	standing_on_object = true
	support_left = left_x
	support_right = right_x
	support_top = top_y
	support_record_index = record_index
	support_refreshed_this_pass = true

func move_with_supported_object(record_index: int, delta_x: int, delta_y: int, left_x: int, right_x: int, top_y: int) -> void:
	# Source order for stood-on moving platforms is ExitPlatform -> move object ->
	# MvSonicOnPtfm. ExitPlatform tests Sonic's CENTER against the platform's
	# previous-frame bounds. Even when that test exits (including a jump), the
	# current routine still performs one final MvSonicOnPtfm carry before the
	# object's routine change takes effect next frame.
	if not standing_on_object or support_record_index != record_index or dead:
		return
	var exited = in_air or pixel_x() < support_left or pixel_x() >= support_right
	fixed_x += delta_x << 16
	fixed_y += delta_y << 16
	if exited:
		# Do not let the fresh resolve later in this same native object tick
		# re-capture Sonic. This is the Godot equivalent of obRoutine having been
		# changed by ExitPlatform before Swing_Move/MvSonicOnPtfm execute.
		support_exit_block_record_index = record_index
		clear_object_support()
	else:
		support_refreshed_this_pass = true
		support_left = left_x
		support_right = right_x
		support_top = top_y
	# MvSonicOnPtfm writes only integer obX/obY; our 16.16 addition preserves
	# Sonic's existing subpixel words while applying the integer object delta.
	_sync_position()

func move_with_supported_object_fractional(record_index: int, delta_x: float, delta_y: float, left_x: int, right_x: int, top_y: int) -> void:
	# Fractional native objects use the same ExitPlatform ownership/order as the
	# integer path, but retain their subpixel displacement in the Godot bridge.
	if not standing_on_object or support_record_index != record_index or dead:
		return
	var exited = in_air or pixel_x() < support_left or pixel_x() >= support_right
	fixed_x += int(round(delta_x * 65536.0))
	fixed_y += int(round(delta_y * 65536.0))
	if exited:
		support_exit_block_record_index = record_index
		clear_object_support()
	else:
		support_refreshed_this_pass = true
		support_left = left_x
		support_right = right_x
		support_top = top_y
	_sync_position()

func resolve_platform_top(left_x: int, right_x: int, top_y: int, record_index: int = -1) -> bool:
	# SolidObject ignores Sonic once routine >= 6 (death). This prevents a
	# dying Sonic from being captured by a platform/monitor/rock on the way down.
	if dead or debug_free_mode:
		return false
	# ExitPlatform already rejected this exact owner earlier in the current
	# object tick. The source routine cannot run PlatformObject again until the
	# next frame, so do not allow an immediate native re-capture here.
	if record_index == support_exit_block_record_index:
		return false
	if in_air and vel_y < 0:
		return false
	var x = pixel_x()
	# PlatformObject uses Sonic's center X and treats the right edge as exclusive.
	if x < left_x or x >= right_x:
		return false
	var feet = pixel_y() + height_radius
	var penetration = feet - top_y
	# Permit exact standing contact as well as the shallow crossing used by
	# PlatformObject. This is important because objects execute after Sonic.
	if penetration < -2 or penetration > 16:
		return false
	_add_pixel_y(-penetration)
	# PlatformObject corrects obY's integer word and leaves obSubpixelY intact.
	vel_y = 0
	if in_air:
		inertia = vel_x
		_reset_on_floor()
	angle = 0
	_set_object_support(left_x, right_x, top_y, record_index)
	_sync_position()
	return true


# Source equivalent of SlopeObject_AssumeStoodOn for an object that already
# owns Sonic's platform-support flag. Unlike PlatformObject/SlopeObject, this
# does not perform a fresh vertical penetration test every frame; it simply
# follows the sampled slope height until ExitPlatform says Sonic walked off.
func snap_supported_slope(left_x: int, right_x: int, top_y: int, record_index: int) -> bool:
	if dead or debug_free_mode or in_air:
		clear_object_support_for(record_index, false)
		return false
	if not standing_on_object or support_record_index != record_index:
		return false
	var x = pixel_x()
	# ExitPlatform compares Sonic's center against the platform half-width,
	# with the right edge exclusive.
	if x < left_x or x >= right_x:
		clear_object_support_for(record_index, false)
		return false
	_add_pixel_y((top_y - height_radius) - pixel_y())
	# SlopeObject_AssumeStoodOn follows the integer top without clearing subpixel.
	vel_y = 0
	angle = 0
	support_left = left_x
	support_right = right_x
	support_top = top_y
	support_refreshed_this_pass = true
	_sync_position()
	return true

# Retail Sonic 2 SolidObject top-contact path used by Object $41 springs.
# Unlike the generic native box helper, S2 SolidObject uses d1 as a broad
# Sonic-CENTER contact reach, then performs a second, narrower width_pixels
# test before RideObject_SetRide can set the standing bit. Keeping those two
# ranges distinct is important for buried HTZ springs: the shell may be near
# Sonic without the active spring face being under his center yet.
func resolve_s2_spring_top(center_x: int, center_y: int, contact_center_reach: int, jump_half_height: int, walk_half_height: int, landing_half_width: int, record_index: int = -1) -> bool:
	if dead or drowning or debug_free_mode or (in_air and vel_y < 0):
		return false
	if record_index == support_exit_block_record_index:
		return false

	# SolidObject_Always_SingleCharacter's already-stood-on path uses d3 and
	# MvSonicOnPtfm directly. The spring normally launches immediately, but this
	# path matters while its animation cooldown is still active.
	if standing_on_object and support_record_index == record_index:
		return snap_supported_slope(center_x - landing_half_width, center_x + landing_half_width, center_y - walk_half_height, record_index)

	var x: int = pixel_x()
	var y: int = pixel_y()
	# Exact source X envelope: d0 = SonicX - ObjectX + d1, unsigned 0..2*d1.
	var x_from_left: int = x - center_x + contact_center_reach
	if x_from_left < 0 or x_from_left > contact_center_reach * 2:
		return false

	# Exact source Y transform. d2 is object half-height for fresh/jumping
	# collision; Sonic's y_radius and the original +4 bias are added internally.
	var d2_total: int = jump_half_height + height_radius
	var y_from_top: int = y - center_y + 4 + d2_total
	if y_from_top < 0 or y_from_top >= d2_total * 2:
		return false

	# SolidObject chooses the nearest axis before entering its top/bottom branch.
	var horizontal_pen: int = x_from_left
	if x_from_left > contact_center_reach:
		horizontal_pen = contact_center_reach * 2 - x_from_left
	var signed_vertical: int = y_from_top
	var vertical_pen: int = y_from_top
	if y_from_top > d2_total:
		signed_vertical = y_from_top - 4 - d2_total * 2
		vertical_pen = -signed_vertical
	if horizontal_pen <= vertical_pen:
		return false

	# loc_19AEE/loc_19B56: only the upper $10-pixel vertical band can become
	# standing contact, and upward velocity rejects the ride transition.
	if signed_vertical < 0 or signed_vertical >= 0x10 or vel_y < 0:
		return false

	# RideObject_SetRide performs a second X test using width_pixels(a0), NOT d1.
	# Right edge is exclusive in the source compare.
	if x < center_x - landing_half_width or x >= center_x + landing_half_width:
		return false

	# loc_19B56 snaps to objectY-d2-y_radius-1 before Obj41's launch routine
	# pushes Sonic eight pixels into the compressed spring.
	var target_y: int = center_y - jump_half_height - height_radius - 1
	_add_pixel_y(target_y - y)
	vel_y = 0
	if in_air:
		inertia = vel_x
		_reset_on_floor()
	angle = 0
	_set_object_support(center_x - landing_half_width, center_x + landing_half_width, center_y - jump_half_height - 1, record_index)
	_sync_position()
	return true

func resolve_solid_box(center_x: int, center_y: int, half_width: int, half_height: int, allow_top: bool = true, record_index: int = -1) -> bool:
	return resolve_solid_box_contact(center_x, center_y, half_width, half_height, allow_top, record_index) != SOLID_NONE

func resolve_edge_wall(center_x: int, center_y: int, half_width: int = 19, half_height: int = 40) -> bool:
	# Object $44 uses EdgeWall_SolidWall rather than the shared SolidObject
	# routine. Its horizontal test is unusual: Sonic's CENTER is compared
	# directly with the wall envelope. obWidth is deliberately not added.
	# Reusing resolve_solid_box() therefore made each side 9 pixels too wide.
	if dead or drowning or debug_free_mode or control_locked:
		return false

	var dx = pixel_x() - center_x
	if dx < -half_width or dx > half_width:
		return false

	# EdgeWall_ChkCollision adds Sonic's current obHeight only vertically.
	var total_half_height = half_height + height_radius
	var dy = pixel_y() - center_y
	if dy < -total_half_height or dy >= total_half_height:
		return false

	# Translate the 68000 routine's signed edge corrections. Positive X
	# correction means Sonic is inside the left half; negative means the right.
	var x_correction = dx + half_width if dx <= 0 else dx - half_width
	var y_correction = dy + total_half_height if dy <= 0 else dy - total_half_height
	var x_penetration = absi(x_correction)
	var y_penetration = absi(y_correction)

	# EdgeWall_ChkCollision returns top/bottom only when that penetration is
	# shallower than the side penetration. Falling onto the top is intentionally
	# ignored; only an upward hit against the underside is resolved.
	if x_penetration > y_penetration:
		if vel_y < 0 and y_correction < 0:
			_add_pixel_y(-y_correction)
			# EdgeWall corrects the integer obY word only.
			vel_y = 0
			clear_object_support()
			_sync_position()
			return true
		return false

	# Side collision: the source only pushes Sonic out when he is moving toward
	# the wall's centre. Moving away leaves his position untouched. At exact
	# contact x_correction is zero but the grounded pushing state still applies.
	if x_correction > 0:
		if vel_x >= 0:
			_add_pixel_x(-x_correction)
			# EdgeWall_SolidWall corrects only obX's integer word; preserve subpixel.
			vel_x = 0
			inertia = 0
	elif x_correction < 0:
		if vel_x < 0:
			_add_pixel_x(-x_correction)
			# EdgeWall_SolidWall corrects only obX's integer word; preserve subpixel.
			vel_x = 0
			inertia = 0

	if not in_air:
		pushing = true
	_sync_position()
	return true

func resolve_solid_box_contact(center_x: int, center_y: int, half_width: int, half_height: int, allow_top: bool = true, record_index: int = -1) -> int:
	# Original SolidObject exits immediately for Sonic_Death (routine 6+).
	if dead or drowning or debug_free_mode:
		return SOLID_NONE
	var left = center_x - half_width
	var right = center_x + half_width
	var top = center_y - half_height
	var bottom = center_y + half_height
	# SolidObject callers normally include sonic_solid_width in d1. Our native
	# callers pass the object's raw half-width, so expand ONLY the SolidObject
	# stood-on range here. FixBugs SolidObject keeps its right edge inclusive, so
	# add one more pixel before passing it to resolve_platform_top's exclusive
	# right bound. PlatformObject callers use resolve_platform_top() directly and
	# remain center-X-only.
	var solid_support_left = left - width_radius
	var solid_support_right = right + width_radius + 1

	# Maintain a known stood-on relationship first, but do not treat merely
	# touching the side of a spring/monitor as top contact. Phase 10 allowed a
	# fresh side approach to enter this branch because Sonic's feet happened to
	# lie within top+16.
	if allow_top and standing_on_object and support_record_index == record_index and not (in_air and vel_y < 0):
		if resolve_platform_top(solid_support_left, solid_support_right, top, record_index):
			return SOLID_TOP

	var x = pixel_x()
	var y = pixel_y()
	var player_left = x - width_radius
	var player_right = x + width_radius
	var player_top = y - height_radius
	var player_bottom = y + height_radius
	if player_right <= left or player_left >= right or player_bottom <= top or player_top >= bottom:
		# A downward crossing may stop exactly on the top edge without overlap.
		if allow_top and not (in_air and vel_y < 0) and player_right >= left and player_left <= right:
			var feet_delta = player_bottom - top
			if feet_delta >= -2 and feet_delta <= 2:
				return SOLID_TOP if resolve_platform_top(solid_support_left, solid_support_right, top, record_index) else SOLID_NONE
		# Maintain exact side contact after the previous frame pushed Sonic flush
		# with the box. Without this, the left face alternated between collision
		# and no collision and the push animation flickered.
		var vertical_overlap = player_bottom > top and player_top < bottom
		if vertical_overlap and not in_air:
			if player_right == left and input_right:
				vel_x = mini(vel_x, 0)
				inertia = mini(inertia, 0)
				pushing = true
				facing_left = false
				return SOLID_LEFT
			if player_left == right and input_left:
				vel_x = maxi(vel_x, 0)
				inertia = maxi(inertia, 0)
				pushing = true
				facing_left = true
				return SOLID_RIGHT
		return SOLID_NONE

	var left_pen = player_right - left
	var right_pen = right - player_left
	var top_pen = player_bottom - top
	var bottom_pen = bottom - player_top

	# SolidObject resolves an intentional grounded lateral push as a side hit
	# before its platform-top path. Without this, approaching the object's left
	# face while holding Right could occasionally choose the shallow top overlap
	# and nudge Sonic upward, producing the one-sided bounce reported in Phase 13.
	var deep_vertical_overlap = player_bottom > top + 4 and player_top < bottom
	if not in_air and deep_vertical_overlap:
		if input_right and left_pen >= 0 and left_pen <= 8 and player_left < left:
			_add_pixel_x(-left_pen)
			vel_x = mini(vel_x, 0)
			inertia = mini(inertia, 0)
			pushing = true
			facing_left = false
			clear_object_support()
			# SolidObject subtracts from obX's integer word and leaves obX+2 intact.
			_sync_position()
			return SOLID_LEFT
		if input_left and right_pen >= 0 and right_pen <= 8 and player_right > right:
			_add_pixel_x(right_pen)
			vel_x = maxi(vel_x, 0)
			inertia = maxi(inertia, 0)
			pushing = true
			facing_left = true
			clear_object_support()
			# SolidObject subtracts from obX's integer word and leaves obX+2 intact.
			_sync_position()
			return SOLID_RIGHT

	# Pick the nearest valid face for a NEW collision. This mirrors the intent of
	# SolidObject far better than always trying top first and fixes vertical
	# springs firing when Sonic runs into their side.
	var best = 0x7FFFFFFF
	var contact = SOLID_NONE
	if allow_top and not (in_air and vel_y < 0) and top_pen >= 0 and top_pen <= 16:
		best = top_pen
		contact = SOLID_TOP
	if in_air and vel_y < 0 and bottom_pen >= 0 and bottom_pen <= 16 and bottom_pen < best:
		best = bottom_pen
		contact = SOLID_BOTTOM
	if left_pen >= 0 and left_pen < best:
		best = left_pen
		contact = SOLID_LEFT
	if right_pen >= 0 and right_pen < best:
		contact = SOLID_RIGHT

	match contact:
		SOLID_TOP:
			return SOLID_TOP if resolve_platform_top(solid_support_left, solid_support_right, top, record_index) else SOLID_NONE
		SOLID_BOTTOM:
			_add_pixel_y(bottom_pen)
			# SolidObject's vertical correction preserves obSubpixelY.
			vel_y = 0
			clear_object_support()
			_sync_position()
			return SOLID_BOTTOM
		SOLID_LEFT:
			_add_pixel_x(-left_pen)
			if vel_x > 0:
				vel_x = 0
			if not in_air and inertia > 0:
				inertia = 0
			pushing = not in_air and input_right
			if pushing:
				facing_left = false
			clear_object_support()
			# Preserve Sonic's horizontal subpixel exactly like sub.w d0,obX(a1).
			_sync_position()
			return SOLID_LEFT
		SOLID_RIGHT:
			_add_pixel_x(right_pen)
			if vel_x < 0:
				vel_x = 0
			if not in_air and inertia < 0:
				inertia = 0
			pushing = not in_air and input_left
			if pushing:
				facing_left = true
			clear_object_support()
			# Preserve Sonic's horizontal subpixel exactly like sub.w d0,obX(a1).
			_sync_position()
			return SOLID_RIGHT
	return SOLID_NONE

func can_attack_object() -> bool:
	if debug_free_mode or drowning:
		return false
	return invincible_timer > 0 or rolling or object_attack_active

func preserve_monitor_rebound_attack() -> void:
	# React_Monitor negates Sonic's Y velocity without changing id_Roll. If the
	# terrain pass happened to clear our rolling state immediately before the
	# monitor object executes (notably with vertically stacked boxes), restore the
	# airborne ball state that existed at the start of the frame. This lets the
	# rebound break a second monitor exactly as the original obAnim check can.
	if dead or drowning or hurt_state or not object_attack_was_airborne:
		return
	clear_object_support()
	if not rolling:
		rolling = true
		height_radius = SONIC_ROLL_HEIGHT
		width_radius = SONIC_ROLL_WIDTH
		_add_pixel_y(SONIC_HEIGHT - SONIC_ROLL_HEIGHT)
	in_air = true
	jumping = false
	pushing = false
	skidding = false
	_sync_position()

func apply_hazard_hit(source_x: int) -> bool:
	# React_ChkHurt / HurtSonic. Invincibility and post-hit flashing suppress
	# damage. A shield absorbs one hit; otherwise rings spill, and zero rings
	# transitions to Sonic_Death.
	if debug_free_mode or dead or drowning or hurt_state or ooz_transport_invulnerable or invincible_timer > 0 or invulnerability_timer > 0:
		return false

	if shield:
		shield = false
	elif object_manager != null and object_manager.rings > 0:
		SonicAudio.play_sfx(SonicAudio.SFX_RING_LOSS)
		object_manager.spill_player_rings(pixel_x(), pixel_y())
	else:
		kill()
		return true

	_begin_hurt(source_x)
	return true

func _begin_hurt(source_x: int) -> void:
	hurt_state = true
	dead = false
	_reset_on_floor()
	in_air = true
	# HurtSonic uses half-strength knockback underwater: -$200 Y / -$100 X
	# instead of the dry -$400 / -$200 launch. Keep the status-bit check here,
	# before direction reversal, just like the 68000 routine.
	vel_y = -0x200 if underwater else -0x400
	vel_x = -0x100 if underwater else -0x200
	if pixel_x() >= source_x:
		vel_x = -vel_x
	inertia = 0
	invulnerability_timer = 2 * 60
	_sync_position()

func _update_water_state() -> void:
	# Sonic_Water runs after the movement mode each frame. Entering LZ water
	# halves X velocity, quarters Y velocity, and halves max/accel/decel. Exiting
	# doubles Y velocity again and caps very fast upward exits at -$1000.
	# Water_flag is level data in Sonic 2 as well (not an LZ-only concept).
	# CPZ2 therefore shares the same underwater movement/drowning path.
	var has_water := object_manager != null and bool(object_manager.water_enabled)
	if not has_water:
		if underwater:
			underwater = false
			_restore_surface_speed_constants()
		if object_manager != null:
			object_manager.replenish_lz_air()
		return
	var should_be_underwater := pixel_y() > int(object_manager.water_surface_y)
	if should_be_underwater == underwater:
		return
	underwater = should_be_underwater
	if underwater:
		speed_max = MAX_SPEED >> 1
		speed_acceleration = ACCELERATION >> 1
		speed_deceleration = DECELERATION >> 1
		vel_x = GenesisMath.s16(vel_x >> 1)
		vel_y = GenesisMath.s16(vel_y >> 2)
		if vel_y != 0 and object_manager != null:
			object_manager.spawn_lz_splash(pixel_x())
	else:
		_restore_surface_speed_constants()
		vel_y = GenesisMath.s16(vel_y << 1)
		if vel_y <= -0x1000:
			vel_y = -0x1000
		if object_manager != null:
			object_manager.replenish_lz_air()
			if vel_y != 0:
				object_manager.spawn_lz_splash(pixel_x())

func _restore_surface_speed_constants() -> void:
	if shoes_timer > 0:
		speed_max = MAX_SPEED * 2
		speed_acceleration = ACCELERATION * 2
		speed_deceleration = DECELERATION
	else:
		speed_max = MAX_SPEED
		speed_acceleration = ACCELERATION
		speed_deceleration = DECELERATION

func receive_air_bubble() -> void:
	if not underwater or drowning or dead:
		return
	vel_x = 0
	vel_y = 0
	inertia = 0
	jumping = false
	pushing = false
	roll_jump_lock = false
	get_air_timer = 35
	if rolling:
		rolling = false
		height_radius = SONIC_HEIGHT
		width_radius = SONIC_WIDTH
		_add_pixel_y(-(SONIC_HEIGHT - SONIC_ROLL_HEIGHT))

func begin_drowning() -> void:
	if dead or drowning:
		return
	drowning = true
	sprite_high_priority = true
	hurt_state = false
	get_air_timer = 0
	clear_object_support()
	in_air = true
	jumping = false
	pushing = false
	roll_jump_lock = false
	if rolling:
		rolling = false
		height_radius = SONIC_HEIGHT
		width_radius = SONIC_WIDTH
		_add_pixel_y(-(SONIC_HEIGHT - SONIC_ROLL_HEIGHT))
	vel_x = 0
	vel_y = 0
	inertia = 0

func _mode_drowning() -> void:
	# Object $0A moves Sonic with SpeedToPos and adds $10 Y velocity while the
	# two-second drowning restart timer is active. Terrain collision is skipped.
	_speed_to_pos()
	vel_y = GenesisMath.s16(vel_y + 0x10)

func finish_drowning_death() -> void:
	if dead:
		return
	SonicAudio.set_speed_shoes_active(false)
	drowning = false
	dead = true
	hurt_state = false
	get_air_timer = 0
	clear_object_support()
	in_air = true
	vel_x = 0
	inertia = 0
	# Preserve the downward drowning velocity: the source switches directly to
	# Sonic_Death instead of applying the normal -$700 death launch.

func kill() -> void:
	if debug_free_mode or dead:
		return
	SonicAudio.set_speed_shoes_active(false)
	SonicAudio.play_sfx(SonicAudio.SFX_DEATH)
	dead = true
	drowning = false
	sprite_high_priority = false
	get_air_timer = 0
	hurt_state = false
	spring_pose_timer = 0
	invincible_timer = 0
	shield = false
	_reset_on_floor()
	in_air = true
	vel_y = -0x700
	vel_x = 0
	inertia = 0
	_sync_position()

func grant_power_up(monitor_subtype: int) -> void:
	match monitor_subtype:
		1:
			# With FixBugs the Eggman monitor behaves like a damaging object.
			apply_hazard_hit(pixel_x())
		2:
			if object_manager != null:
				object_manager.lives += 1
			SonicAudio.play_jingle(SonicAudio.MUS_EXTRA_LIFE)
		3:
			shoes_timer = 20 * 60
			SonicAudio.set_speed_shoes_active(true)
			if underwater:
				# Keep the REV01 underwater movement constants; the optional source
				# FixBugs build changes this interaction, but REV01 itself does not.
				speed_max = MAX_SPEED >> 1
				speed_acceleration = ACCELERATION >> 1
				speed_deceleration = DECELERATION >> 1
			else:
				speed_max = MAX_SPEED * 2
				speed_acceleration = ACCELERATION * 2
				speed_deceleration = DECELERATION
		4:
			shield = true
			SonicAudio.play_sfx(SonicAudio.SFX_SHIELD)
		5:
			invincible_timer = 20 * 60
			SonicAudio.play_override_music(SonicAudio.MUS_INVINCIBLE)
		6:
			if object_manager != null:
				object_manager.add_rings(10)
		_:
			pass
	queue_redraw()

func _update_power_timers() -> void:
	if spring_pose_timer > 0:
		spring_pose_timer -= 1
	if invulnerability_timer > 0:
		invulnerability_timer -= 1
	if invincible_timer > 0:
		invincible_timer -= 1
		if invincible_timer == 0:
			SonicAudio.resume_override_music()
	if shoes_timer > 0:
		shoes_timer -= 1
		if shoes_timer == 0:
			SonicAudio.set_speed_shoes_active(false)
			if underwater:
				speed_max = MAX_SPEED >> 1
				speed_acceleration = ACCELERATION >> 1
				speed_deceleration = DECELERATION >> 1
			else:
				_restore_surface_speed_constants()

func _mode_hurt() -> void:
	# Sonic_Hurt: SpeedToPos, then gravity-$08, then Sonic_Floor.
	_speed_to_pos()
	vel_y = GenesisMath.s16(vel_y + (0x10 if underwater else (GRAVITY - 8)))
	_air_collision()
	if not in_air:
		vel_x = 0
		vel_y = 0
		inertia = 0
		hurt_state = false

func _mode_dead() -> void:
	# Sonic_Death applies the standard ObjectFall gravity but ignores terrain.
	_object_fall()

# -----------------------------------------------------------------------------
# Debug free-move mode -- movement portion of Sonic 1 DebugMode.asm
# -----------------------------------------------------------------------------

func set_debug_free_mode(enabled: bool) -> void:
	if debug_free_mode == enabled:
		return
	debug_free_mode = enabled
	debug_move_timer = 12
	debug_move_speed = 15
	vel_x = 0
	vel_y = 0
	inertia = 0
	pushing = false
	skidding = false
	edge_balance = false
	spindash_active = false
	spindash_counter = 0
	_spindash_duck_ready = false
	spring_pose_timer = 0
	_clear_s2_twirl()
	clear_object_support()
	if enabled:
		hurt_state = false
		dead = false
		in_air = false
		rolling = false
		jumping = false
		width_radius = SONIC_WIDTH
		height_radius = SONIC_HEIGHT
	else:
		# Exiting original debug mode clears subpixels and returns Sonic to his
		# ordinary object. Starting airborne here is useful for native testing:
		# Sonic falls and reattaches cleanly to whatever terrain is underneath.
		_clear_subpixel_x()
		_clear_subpixel_y()
		in_air = true
		angle = 0
	_sync_position()
	queue_redraw()

func _mode_debug_free() -> void:
	vel_x = 0
	vel_y = 0
	inertia = 0
	clear_object_support()
	in_air = false
	rolling = false
	jumping = false
	angle = 0

	var direction_mask = 0
	if input_up:
		direction_mask |= 1
	if input_down:
		direction_mask |= 2
	if input_left:
		direction_mask |= 4
	if input_right:
		direction_mask |= 8

	if direction_mask == 0:
		debug_move_timer = 12
		debug_move_speed = 15
		return

	# DebugMode.asm starts at 15, waits 12 held frames, then increments toward
	# $FF. (speed+1)/16 is the pixel delta, represented here in 16.16.
	debug_move_timer -= 1
	if debug_move_timer <= 0:
		debug_move_timer = 1
		debug_move_speed = mini(0xFF, debug_move_speed + 1)
	var delta_fixed = (debug_move_speed + 1) << 12
	if input_up:
		fixed_y -= delta_fixed
	if input_down:
		fixed_y += delta_fixed
	if input_left:
		fixed_x -= delta_fixed
		facing_left = true
	if input_right:
		fixed_x += delta_fixed
		facing_left = false

	# The FixBugs version of the original debug mode clamps to active level
	# boundaries. Use the complete native layout here so testers can reach any
	# section even when a zone's DynamicLevelEvents have not fired yet.
	if level != null:
		var max_x = maxi(0, level.world_width_pixels() - 1)
		var max_y = maxi(0, level.world_height_pixels() - 1)
		fixed_x = clampi(fixed_x, 0, max_x << 16)
		fixed_y = clampi(fixed_y, 0, max_y << 16)

# -----------------------------------------------------------------------------
# GHZ special chunks, bounds, fixed point helpers
# -----------------------------------------------------------------------------

func set_collision_path(path: int, owner: int = -1) -> void:
	collision_path = GHZLevelData.COLLISION_PATH_SECONDARY if path != 0 else GHZLevelData.COLLISION_PATH_PRIMARY
	collision_path_owner = owner if collision_path == GHZLevelData.COLLISION_PATH_SECONDARY else -1


func _update_forced_roll_chunks() -> void:
	# Sonic_Loops also owns GHZ's two forced-roll tunnel chunks. Collision-plane
	# selection moved to Phase-56 PathSwitcher objects, but this independent
	# source behavior remains player-side.
	if level == null or level.zone_id != LevelCatalog.ZONE_GHZ:
		return
	var raw_chunk = level.get_chunk_id_at(pixel_x() >> 8, pixel_y() >> 8)
	if raw_chunk == 0x1F or raw_chunk == 0x20:
		_try_roll(true)


func set_runtime_level_bounds(left_boundary: int, right_boundary: int, screen_locked: bool) -> void:
	runtime_limit_left = left_boundary
	runtime_limit_right = right_boundary
	runtime_screen_locked = screen_locked

func _apply_level_bounds() -> void:
	if level == null:
		return
	# Sonic_LevelBound predicts the next integer X position, then clamps it to
	# v_limitleft2+16 and v_limitright2+screen_width-24. Outside a locked
	# boss arena it grants another 64px of right-side leeway. Using the same
	# dynamic camera boundaries prevents Sonic leaving a locked boss screen.
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var min_x = runtime_limit_left + 16
	var right_base = runtime_limit_right if runtime_limit_right > 0 else maxi(0, level.world_width_pixels() - view_width)
	var max_x = right_base + view_width - 24
	if not runtime_screen_locked:
		max_x += 64
	var predicted_x = pixel_x() # movement already ran this native tick; this is the Genesis predicted position
	if predicted_x < min_x:
		fixed_x = min_x << 16
		vel_x = 0
		inertia = 0
	elif predicted_x >= max_x:
		fixed_x = max_x << 16
		vel_x = 0
		inertia = 0
	# Retain a conservative absolute-layout guard for preview zones whose DLE
	# boundaries are not ported yet.
	var absolute_max_x = level.world_width_pixels() - 1
	if pixel_x() > absolute_max_x:
		fixed_x = absolute_max_x << 16
		vel_x = 0
		inertia = 0
	# Phase 85: Sonic 2's Sonic_LevelBound kills at Camera_Max_Y_pos_now+$E0,
	# not at the padded height of the imported layout. The experimental S2 levels
	# already carry their source Camera_Max_Y boundary in limit_bottom. This fixes
	# EHZ's bottomless pits without changing the established Sonic 1 DLE path.
	var bottom_death_y = level.world_height_pixels() + level.chunk_pixel_size()
	if bool(level.definition.get("experimental_sonic2", false)):
		bottom_death_y = int(level.definition.get("limit_bottom", bottom_death_y)) + int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if pixel_y() > bottom_death_y and not dead:
		kill()

func _surface_quadrant() -> int:
	return _classify_surface_exact(angle)

# Exact branch thresholds used by Sonic_AnglePos/Sonic_CalcRoomAhead.  The
# +/-1 adjustments around signed-byte boundaries are intentional.
func _classify_surface_exact(value: int) -> int:
	var original := value & 0xFF
	var rotated := (original + 0x20) & 0xFF
	var work := original
	if GenesisMath.s8(rotated) >= 0:
		if GenesisMath.s8(work) < 0:
			work = (work + 1) & 0xFF
		work = (work + 0x1F) & 0xFF
	else:
		if GenesisMath.s8(work) < 0:
			work = (work - 1) & 0xFF
		work = (work + 0x20) & 0xFF
	return work & 0xC0

func _slope_magnitude(value: int) -> int:
	var a := value & 0xFF
	if a >= 0x80:
		a = 0x100 - a
	if a > 0x40:
		a = 0x80 - a
	return absi(a)

func wrap_vertical_0x800() -> void:
	# ScrollVertical masks only Sonic's integer obY word with $7FF. Preserve
	# the native 16.16 subpixel fraction while wrapping the integer coordinate.
	var fractional := fixed_y & 0xFFFF
	var wrapped_y := pixel_y() & 0x7FF
	fixed_y = (wrapped_y << 16) | fractional
	_sync_position()

func set_s2_pinball_mode(enabled: bool) -> void:
	pinball_mode = enabled
	if not enabled:
		return
	if not rolling:
		rolling = true
		height_radius = SONIC_ROLL_HEIGHT
		width_radius = SONIC_ROLL_WIDTH
		_add_pixel_y(SONIC_HEIGHT - SONIC_ROLL_HEIGHT)
		SonicAudio.play_sfx(SonicAudio.SFX_ROLL)
	if inertia == 0:
		inertia = -0x400 if facing_left else 0x400
	_sync_position()

func force_set_pixel_position(world_x: int, world_y: int) -> void:
	fixed_x = world_x << 16
	fixed_y = world_y << 16
	_sync_position()

func force_add_pixel_offset(dx: int, dy: int) -> void:
	fixed_x += dx << 16
	fixed_y += dy << 16
	_sync_position()

func pixel_x() -> int:
	return int(fixed_x >> 16)

func pixel_y() -> int:
	return int(fixed_y >> 16)

func _add_pixel_x(amount: int) -> void:
	fixed_x += amount << 16

func _add_pixel_y(amount: int) -> void:
	fixed_y += amount << 16

func _clear_subpixel_x() -> void:
	fixed_x = (fixed_x >> 16) << 16

func _clear_subpixel_y() -> void:
	fixed_y = (fixed_y >> 16) << 16

func _sync_position() -> void:
	# BuildSprites reads only obX/obY (the high integer words of the Genesis
	# 16.16 positions). Keep fixed_x/fixed_y subpixels for physics, but never
	# expose those fractions to Sprite2D rendering. This prevents subpixel creep
	# while pushing against a solid without changing the underlying motion state.
	position = Vector2(float(pixel_x()), float(pixel_y()))

func state_text() -> String:
	var mode := "DEBUG" if debug_free_mode else ("SPINDASH" if spindash_active else ("AIR" if in_air else ("ROLL" if rolling else "GROUND")))
	return "%s  pos:(%d,%d)  vel:(%d,%d)  inertia:%d  angle:$%02X  obj:%s skid:%s bal:%s path:%s phys:%s anim:%s" % [
		mode, pixel_x(), pixel_y(), vel_x, vel_y, inertia, angle & 0xFF, str(standing_on_object), str(skidding), str(edge_balance), "S" if collision_path != 0 else "P", physics_profile_name(), animation_style_name()
	]

func _draw() -> void:
	# Shield/invincibility are rendered by native Object $38 effects in Phase 9.
	if not sensor_debug:
		return
	var body_color := Color(0.2, 0.8, 1.0, 0.9)
	draw_circle(Vector2.ZERO, 2.0, body_color)
	var normal := Vector2(-float(GenesisMath.sine(angle)) / 256.0, float(GenesisMath.cosine(angle)) / 256.0)
	draw_line(Vector2.ZERO, normal * float(height_radius), body_color, 1.0)
	for query in _debug_queries:
		var p := to_local(query["point"])
		var t := to_local(query["target"])
		var color := Color(0.2, 1.0, 0.3, 0.9) if bool(query["ground"]) else Color(1.0, 0.7, 0.2, 0.9)
		draw_circle(p, 1.5, color)
		draw_line(p, t, color, 1.0)
