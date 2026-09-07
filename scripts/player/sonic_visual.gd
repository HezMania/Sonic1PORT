class_name SonicVisual
extends Sprite2D

# Phase 79 keeps gameplay physics and presentation independent. SONIC 1 uses
# the existing S1 mapping bank; S2 BETA and S2 FINAL use frames reconstructed
# directly from their respective art + mapping + DPLC sources.
const FRAME_STAND := 0x01
const FRAME_WAIT1 := 0x02
const FRAME_WAIT2 := 0x03
const FRAME_WAIT3 := 0x04
const FRAME_LOOK_UP := 0x05
const FRAME_DUCK := 0x39
const BALANCE_SEQUENCE: Array[int] = [0x3A, 0x3B]
const SKID_SEQUENCE: Array[int] = [0x37, 0x38]
const PUSH_SEQUENCE: Array[int] = [0x45, 0x46, 0x47, 0x48]
const FRAME_SPRING := 0x40
const FRAME_DROWN := 0x4C
const FRAME_DEATH := 0x4D
const FRAME_INJURY := 0x55
const FRAME_GET_AIR := 0x56
const WALK_SEQUENCE: Array[int] = [0x08, 0x09, 0x0A, 0x0B, 0x06, 0x07]
const RUN_SEQUENCE: Array[int] = [0x1E, 0x1F, 0x20, 0x21]
const ROLL_SEQUENCE: Array[int] = [0x2E, 0x2F, 0x30, 0x31, 0x32]
const ROLL_FAST_SEQUENCE: Array[int] = [0x2E, 0x2F, 0x32, 0x30, 0x31, 0x32]
const FLOAT2_SEQUENCE: Array[int] = [0x3C, 0x3D, 0x53, 0x3E, 0x54]
const HANG_SEQUENCE: Array[int] = [0x41, 0x42]
const SLIDE_SEQUENCE: Array[int] = [0x55, 0x57]
const WAIT_SEQUENCE: Array[int] = [
	FRAME_STAND, FRAME_STAND, FRAME_STAND, FRAME_STAND, FRAME_STAND, FRAME_STAND,
	FRAME_STAND, FRAME_STAND, FRAME_STAND, FRAME_STAND, FRAME_STAND, FRAME_STAND,
	FRAME_WAIT2, FRAME_WAIT1, FRAME_WAIT1, FRAME_WAIT1, FRAME_WAIT2, FRAME_WAIT3,
]

# S1-compatible charge art supplied by the user, in the Sonic 1 palette.
const S1_COMPAT_SPINDASH_SEQUENCE: Array[int] = [0, 1, 0, 2, 0, 3, 0, 4, 0, 5]

# Simon Wai beta source animations.
const BETA_WALK: Array[int] = [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x0C, 0x0D, 0x0E, 0x0F]
const BETA_RUN: Array[int] = [0x3C, 0x3D, 0x3E, 0x3F]
const BETA_ROLL: Array[int] = [0x6C, 0x70, 0x6D, 0x70, 0x6E, 0x70, 0x6F, 0x70]
const BETA_PUSH: Array[int] = [0x77, 0x78, 0x79, 0x7A]
const BETA_WAIT: Array[int] = [0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x03, 0x03, 0x03, 0x04, 0x04, 0x05, 0x05]
const BETA_WAIT_BACK := 4
const BETA_BALANCE: Array[int] = [0x89, 0x8A]
const BETA_LOOK: Array[int] = [0x06, 0x07]
const BETA_DUCK: Array[int] = [0x7F, 0x80]
const BETA_SPINDASH: Array[int] = [0x71, 0x72, 0x71, 0x73, 0x71, 0x74, 0x71, 0x75, 0x71, 0x76, 0x71]
const BETA_SKID: Array[int] = [0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88]
const BETA_FLOAT: Array[int] = [0x91, 0x92, 0x93, 0x94, 0x95]
const BETA_HANG: Array[int] = [0x8F, 0x90]
const BETA_SLIDE: Array[int] = [0x8D, 0x8E]

# Retail Sonic 2 source animations.
const FINAL_WALK: Array[int] = [0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x0D, 0x0E]
const FINAL_RUN: Array[int] = [0x2D, 0x2E, 0x2F, 0x30]
const FINAL_ROLL: Array[int] = [0x3D, 0x41, 0x3E, 0x41, 0x3F, 0x41, 0x40, 0x41]
const FINAL_PUSH: Array[int] = [0x48, 0x49, 0x4A, 0x4B]
const FINAL_WAIT: Array[int] = [0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x03, 0x03, 0x03, 0x03, 0x03, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x07, 0x08, 0x08, 0x08, 0x09, 0x09, 0x09]
const FINAL_WAIT_BACK := 6
const FINAL_BALANCE: Array[int] = [0xCC, 0xCD, 0xCE, 0xCD]
const FINAL_LOOK: Array[int] = [0x0B, 0x0C]
const FINAL_DUCK: Array[int] = [0x4C, 0x4D]
const FINAL_SPINDASH: Array[int] = [0x42, 0x43, 0x42, 0x44, 0x42, 0x45, 0x42, 0x46, 0x42, 0x47]
const FINAL_SKID: Array[int] = [0xD2, 0xD3, 0xD4, 0xD5]
const FINAL_FLOAT: Array[int] = [0x54, 0x55, 0x56, 0x57, 0x58]
const FINAL_HANG: Array[int] = [0x50, 0x51]
const FINAL_HANG2: Array[int] = [0x6B, 0x6C]
const FINAL_SLIDE: Array[int] = [0x4E, 0x4F]

var _texture_cache: Dictionary = {}
var _source_texture_cache: Dictionary = {}
var _s1_spindash_texture_cache: Dictionary = {}
var _s1_tumble_texture_cache: Dictionary = {}
var _s1_vine_hang_texture_cache: Dictionary = {}
var _anim_index = 0
var _anim_timer = 0
var _last_mode = -1
var _last_style = -1

func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_set_frame(FRAME_STAND)

func force_animation_refresh() -> void:
	_last_mode = -1
	_last_style = -1
	_anim_index = 0
	_anim_timer = 0

func update_from_player(player) -> void:
	visible = not player.display_hidden and not (player.invulnerability_timer > 0 and not player.hurt_state and not player.dead and ((player.invulnerability_timer >> 2) & 1) == 0)
	if player.forced_visual_frame >= 0:
		flip_h = player.facing_left
		flip_v = false
		_set_frame(player.forced_visual_frame)
		_last_mode = -1
		return

	var mode = 0
	if player.dead:
		mode = 5
	elif player.drowning:
		mode = 10
	elif player.hurt_state:
		mode = 4
	elif player.get_air_timer > 0:
		mode = 11
	elif player.hang_on_pole:
		mode = 12
	elif player.wind_tunnel_mode:
		mode = 13
	elif player.water_slide_mode:
		mode = 14
	# Object $06's EHZ spiral writes flip_angle directly every frame, which
	# diverts Sonic into SAnim_Tumble in Sonic 2. The S1 presentation now has a
	# user-supplied compatible 12-frame bank for this S2-only state. Keep the
	# earlier preference that S1-styled subtype-bit-0 springs use the normal S1
	# spring pose; those springs do not set s2_twirl_active in S1 mode.
	elif player.s2_spiral_pathway_active:
		mode = 17
	elif player.s2_twirl_active and player.animation_style != SonicPlayer.ANIMATION_STYLE_SONIC1:
		mode = 17
	elif player.spring_pose_timer > 0:
		mode = 9
	elif player.spindash_active:
		mode = 15
	elif player.rolling:
		mode = 2
	elif player.edge_balance and not player.in_air:
		mode = 16
	elif player.skidding and not player.in_air:
		mode = 6
	elif player.pushing and not player.in_air:
		mode = 8
	elif not player.in_air and player.input_up and not player.input_down and absi(player.inertia) < 0x80:
		mode = 7
	elif not player.in_air and player.input_down and absi(player.inertia) < 0x80:
		mode = 3
	elif player.inertia != 0 or (player.in_air and player.vel_x != 0):
		mode = 1

	var style_changed = player.animation_style != _last_style
	var mode_changed = mode != _last_mode or style_changed
	if mode_changed:
		_anim_index = 0
		_anim_timer = 0
		_last_mode = mode
		_last_style = player.animation_style

	if player.animation_style == SonicPlayer.ANIMATION_STYLE_SONIC1:
		_update_s1(player, mode, mode_changed)
	else:
		var beta = player.animation_style == SonicPlayer.ANIMATION_STYLE_SONIC2_BETA
		_update_s2_style(player, mode, mode_changed, beta)

func _update_s1(player, mode: int, mode_changed: bool) -> void:
	match mode:
		0:
			_update_wait(player, mode_changed)
		1:
			_update_walk_run(player)
		2:
			_update_roll(player)
		3:
			_set_s1_static(FRAME_DUCK, player)
		4:
			_set_s1_static(FRAME_INJURY, player)
		5:
			_set_s1_static(FRAME_DEATH, player)
		6:
			_update_skid(player)
		7:
			_set_s1_static(FRAME_LOOK_UP, player)
		8:
			_update_push(player)
		9:
			_set_s1_static(FRAME_SPRING, player)
		10:
			_set_s1_static(FRAME_DROWN, player)
		11:
			_set_s1_static(FRAME_GET_AIR, player)
		12:
			if player.mcz_vine_hang:
				_update_s1_mcz_vine_hang(player, mode_changed)
			else:
				_tick_animation(HANG_SEQUENCE.size(), 4)
				_set_frame(HANG_SEQUENCE[_anim_index % HANG_SEQUENCE.size()])
				flip_h = false
				flip_v = false
		13:
			_tick_animation(FLOAT2_SEQUENCE.size(), 7)
			_set_frame(FLOAT2_SEQUENCE[_anim_index % FLOAT2_SEQUENCE.size()])
			flip_h = player.facing_left
			flip_v = false
		14:
			_tick_animation(SLIDE_SEQUENCE.size(), 7)
			_set_frame(SLIDE_SEQUENCE[_anim_index % SLIDE_SEQUENCE.size()])
			flip_h = player.facing_left
			flip_v = false
		15:
			_update_s1_compat_spindash(player, mode_changed)
		16:
			_update_balance(player, mode_changed)
		17:
			_update_s1_compat_tumble(player)

func _update_s2_style(player, mode: int, mode_changed: bool, beta: bool) -> void:
	match mode:
		0:
			if beta:
				_update_source_loop(player, BETA_WAIT, 7, BETA_WAIT_BACK, true, mode_changed)
			else:
				_update_source_loop(player, FINAL_WAIT, 5, FINAL_WAIT_BACK, false, mode_changed)
		1:
			_update_source_walk_run(player, beta, mode_changed)
		2:
			_update_source_roll(player, beta, mode_changed)
		3:
			if beta:
				_update_source_hold(player, BETA_DUCK, 5, true, mode_changed)
			else:
				_update_source_hold(player, FINAL_DUCK, 5, false, mode_changed)
		4:
			_set_source_frame(0x8D if beta else 0x4E, beta, player.facing_left, false)
		5:
			_set_source_frame(0x98 if beta else 0x5C, beta, player.facing_left, false)
		6:
			if beta:
				_update_source_loop(player, BETA_SKID, 3, 2, true, mode_changed)
			else:
				_update_source_loop(player, FINAL_SKID, 5, 1, false, mode_changed)
		7:
			if beta:
				_update_source_hold(player, BETA_LOOK, 5, true, mode_changed)
			else:
				_update_source_hold(player, FINAL_LOOK, 5, false, mode_changed)
		8:
			_update_source_push(player, beta, mode_changed)
		9:
			_set_source_frame(0x7E if beta else 0x5B, beta, player.facing_left, false)
		10:
			_set_source_frame(0x99 if beta else 0x5D, beta, player.facing_left, false)
		11:
			# Sonic 2 SonAni_Bubble begins on the source get-air/breath pose.
			_set_source_frame(0x97 if beta else 0x5A, beta, player.facing_left, false)
		12:
			if beta:
				# Simon Wai has only the S1-style pole hang animation.
				_update_source_loop(player, BETA_HANG, 5, BETA_HANG.size(), true, mode_changed, false)
			elif player.mcz_vine_hang:
				# Retail Obj7F/80 explicitly request SonAni_Hang2: $13,$6B,$6C.
				_update_source_loop(player, FINAL_HANG2, 0x13, FINAL_HANG2.size(), false, mode_changed, false)
			else:
				_update_source_loop(player, FINAL_HANG, 1, FINAL_HANG.size(), false, mode_changed, false)
		13:
			if beta:
				_update_source_loop(player, BETA_FLOAT, 7, BETA_FLOAT.size(), true, mode_changed)
			else:
				_update_source_loop(player, FINAL_FLOAT, 7, FINAL_FLOAT.size(), false, mode_changed)
		14:
			if beta:
				_update_source_loop(player, BETA_SLIDE, 9, BETA_SLIDE.size(), true, mode_changed)
			else:
				_update_source_loop(player, FINAL_SLIDE, 9, FINAL_SLIDE.size(), false, mode_changed)
		15:
			_update_source_spindash(player, beta, mode_changed)
		16:
			if beta:
				_update_source_loop(player, BETA_BALANCE, 7, BETA_BALANCE.size(), true, mode_changed)
			else:
				_update_source_loop(player, FINAL_BALANCE, 9, FINAL_BALANCE.size(), false, mode_changed)
		17:
			_update_source_tumble(player, beta)

func _set_s1_static(frame_id: int, player) -> void:
	_set_frame(frame_id)
	flip_h = player.facing_left
	flip_v = false


func _update_s1_mcz_vine_hang(player, mode_changed: bool) -> void:
	# Sonic 1 has no equivalent for Sonic 2's SonAni_Hang2 poses. Phase 113
	# uses the two S1-palette-compatible frames supplied for Mystic Cave only,
	# with retail SonAni_Hang2's $13 animation delay.
	if mode_changed:
		_anim_index = 0
		_anim_timer = 0x13
	else:
		_tick_animation(2, 0x13)
	var frame_id: int = _anim_index & 1
	if not _s1_vine_hang_texture_cache.has(frame_id):
		_s1_vine_hang_texture_cache[frame_id] = load("res://assets/sonic/s2_exclusive_s1_compat/vine_hang/%02d.png" % frame_id)
	texture = _s1_vine_hang_texture_cache[frame_id]
	flip_h = false
	flip_v = false

func _update_s1_compat_spindash(player, mode_changed: bool) -> void:
	if mode_changed:
		_anim_index = 0
		_anim_timer = 0
	else:
		_tick_animation(S1_COMPAT_SPINDASH_SEQUENCE.size(), 0)
	var frame_id = S1_COMPAT_SPINDASH_SEQUENCE[_anim_index % S1_COMPAT_SPINDASH_SEQUENCE.size()]
	if not _s1_spindash_texture_cache.has(frame_id):
		_s1_spindash_texture_cache[frame_id] = load("res://assets/sonic/spindash_s1_compat/%02d.png" % frame_id)
	texture = _s1_spindash_texture_cache[frame_id]
	flip_h = player.facing_left
	flip_v = false


func _tumble_angle(player) -> int:
	# EHZ Object $06 writes flip_angle from its 52-byte pathway table rather than
	# running the spring flip counter. Both paths feed the same SAnim_Tumble code.
	return (player.s2_spiral_visual_angle if player.s2_spiral_pathway_active else player.s2_twirl_angle) & 0xFF

func _tumble_render_state(player) -> Dictionary:
	var angle_work = _tumble_angle(player)
	var render_flip_h = false
	var render_flip_v = false
	if player.facing_left:
		if player.s2_twirl_turned:
			render_flip_h = true
			angle_work = (angle_work + 0x0B) & 0xFF
		else:
			render_flip_h = true
			render_flip_v = true
			angle_work = (((-angle_work) & 0xFF) + 0x8F) & 0xFF
	else:
		angle_work = (angle_work + 0x0B) & 0xFF
	return {
		"frame": clampi(int(angle_work / 0x16), 0, 11),
		"flip_h": render_flip_h,
		"flip_v": render_flip_v,
	}

func _update_s1_compat_tumble(player) -> void:
	# Twelve user-supplied 64x64 frames match retail S2's $5F-$6A tumble
	# silhouettes exactly, but are recoloured for the Sonic 1 presentation.
	var state := _tumble_render_state(player)
	var frame_id := int(state["frame"])
	if not _s1_tumble_texture_cache.has(frame_id):
		_s1_tumble_texture_cache[frame_id] = load("res://assets/sonic/s2_exclusive_s1_compat/tumble/%02d.png" % frame_id)
	texture = _s1_tumble_texture_cache[frame_id]
	flip_h = bool(state["flip_h"])
	flip_v = bool(state["flip_v"])

func _update_source_tumble(player, beta: bool) -> void:
	# SAnim_Tumble maps flip_angle directly to one of twelve source frames.
	# Simon Wai uses mapping base $9B; retail S2 uses $5F.
	var state := _tumble_render_state(player)
	var frame_base = 0x9B if beta else 0x5F
	_set_source_frame(
		frame_base + int(state["frame"]),
		beta,
		bool(state["flip_h"]),
		bool(state["flip_v"])
	)

func _update_source_spindash(player, beta: bool, mode_changed: bool) -> void:
	var sequence = BETA_SPINDASH if beta else FINAL_SPINDASH
	if mode_changed:
		_anim_index = 0
		_anim_timer = 0
	else:
		_tick_animation(sequence.size(), 0)
	_set_source_frame(sequence[_anim_index % sequence.size()], beta, player.facing_left, false)

func _update_source_hold(player, sequence: Array[int], delay: int, beta: bool, mode_changed: bool) -> void:
	if mode_changed:
		_anim_index = 0
		_anim_timer = delay
	elif _anim_index < sequence.size() - 1:
		_anim_timer -= 1
		if _anim_timer < 0:
			_anim_timer = delay
			_anim_index += 1
	_set_source_frame(sequence[_anim_index], beta, player.facing_left, false)

func _update_source_loop(player, sequence: Array[int], delay: int, loop_back: int, beta: bool, mode_changed: bool, use_facing: bool = true) -> void:
	if mode_changed:
		_anim_index = 0
		_anim_timer = delay
	else:
		_anim_timer -= 1
		if _anim_timer < 0:
			_anim_timer = delay
			_anim_index += 1
			if _anim_index >= sequence.size():
				_anim_index = maxi(0, sequence.size() - loop_back)
	var hflip = player.facing_left if use_facing else false
	_set_source_frame(sequence[_anim_index], beta, hflip, false)

func _update_source_walk_run(player, beta: bool, mode_changed: bool) -> void:
	var speed = absi(player.inertia)
	var sequence: Array[int]
	var interval: int
	if beta:
		sequence = BETA_RUN if speed >= 0x600 else BETA_WALK
		interval = maxi(0, (0x800 - speed) >> 9)
	else:
		sequence = FINAL_RUN if speed >= 0x600 else FINAL_WALK
		interval = maxi(0, (0x800 - speed) >> 8)
	if mode_changed:
		_anim_index = 0
		_anim_timer = interval
	else:
		_tick_animation(sequence.size(), interval)

	var angle_work = player.animation_surface_angle() & 0xFF
	if not beta and GenesisMath.s8(angle_work) > 0:
		angle_work = (angle_work - 1) & 0xFF
	var render_flip_x = player.facing_left
	if not render_flip_x:
		angle_work = (~angle_work) & 0xFF
	angle_work = (angle_work + 0x10) & 0xFF
	var invert_both = GenesisMath.s8(angle_work) < 0
	var octant_modifier = (angle_work >> 4) & 6
	var frame_modifier = 0
	if beta:
		frame_modifier = (octant_modifier + (octant_modifier >> 1)) * 4
	elif speed >= 0x600:
		frame_modifier = octant_modifier * 2
	else:
		frame_modifier = octant_modifier * 4
	_set_source_frame(sequence[_anim_index % sequence.size()] + frame_modifier, beta, render_flip_x != invert_both, invert_both)

func _update_source_roll(player, beta: bool, mode_changed: bool) -> void:
	var sequence = BETA_ROLL if beta else FINAL_ROLL
	var interval = maxi(0, (0x400 - absi(player.inertia)) >> 8)
	if mode_changed:
		_anim_index = 0
		_anim_timer = interval
	else:
		_tick_animation(sequence.size(), interval)
	_set_source_frame(sequence[_anim_index % sequence.size()], beta, player.facing_left, false)

func _update_source_push(player, beta: bool, mode_changed: bool) -> void:
	var sequence = BETA_PUSH if beta else FINAL_PUSH
	var interval = maxi(0, (0x800 - absi(player.inertia)) >> 6)
	if mode_changed:
		_anim_index = 0
		_anim_timer = interval
	else:
		_tick_animation(sequence.size(), interval)
	_set_source_frame(sequence[_anim_index % sequence.size()], beta, player.facing_left, false)

func _set_source_frame(frame_id: int, beta: bool, hflip: bool, vflip: bool) -> void:
	var style_key = "beta" if beta else "final"
	var cache_key = style_key + ":" + str(frame_id)
	if not _source_texture_cache.has(cache_key):
		_source_texture_cache[cache_key] = load("res://assets/sonic2/%s/frames/%03d.png" % [style_key, frame_id])
	texture = _source_texture_cache[cache_key]
	flip_h = hflip
	flip_v = vflip

func _update_balance(player, mode_changed: bool) -> void:
	if mode_changed:
		_anim_index = 0
		_anim_timer = 31
	else:
		_tick_animation(BALANCE_SEQUENCE.size(), 31)
	_set_frame(BALANCE_SEQUENCE[_anim_index % BALANCE_SEQUENCE.size()])
	flip_h = player.facing_left
	flip_v = false

func _update_wait(player, mode_changed: bool) -> void:
	if mode_changed:
		_anim_index = 0
		_anim_timer = 23
	else:
		_anim_timer -= 1
		if _anim_timer < 0:
			_anim_timer = 23
			if _anim_index < WAIT_SEQUENCE.size() - 1:
				_anim_index += 1
			else:
				_anim_index = WAIT_SEQUENCE.size() - 2
	_set_frame(WAIT_SEQUENCE[_anim_index])
	flip_h = player.facing_left
	flip_v = false

func _update_walk_run(player) -> void:
	var speed = absi(player.inertia)
	var sequence = RUN_SEQUENCE if speed >= 0x600 else WALK_SEQUENCE
	var interval = maxi(0, (0x800 - speed) >> 8)
	_tick_animation(sequence.size(), interval)

	var angle_work = player.animation_surface_angle() & 0xFF
	if GenesisMath.s8(angle_work) > 0:
		angle_work = (angle_work - 1) & 0xFF
	var render_flip_x = player.facing_left
	if not render_flip_x:
		angle_work = (~angle_work) & 0xFF
	angle_work = (angle_work + 0x10) & 0xFF
	var invert_both = GenesisMath.s8(angle_work) < 0
	var octant_modifier = (angle_work >> 4) & 6
	var frame_modifier: int
	if speed >= 0x600:
		frame_modifier = octant_modifier * 2
	else:
		frame_modifier = (octant_modifier + (octant_modifier >> 1)) * 2

	var base_frame = sequence[_anim_index % sequence.size()]
	_set_frame(base_frame + frame_modifier)
	flip_h = render_flip_x != invert_both
	flip_v = invert_both

func _update_skid(player) -> void:
	_tick_animation(SKID_SEQUENCE.size(), 7)
	_set_frame(SKID_SEQUENCE[_anim_index % SKID_SEQUENCE.size()])
	flip_h = player.facing_left
	flip_v = false

func _update_push(player) -> void:
	var speed = absi(player.inertia)
	var interval = maxi(0, (0x800 - speed) >> 6)
	_tick_animation(PUSH_SEQUENCE.size(), interval)
	_set_frame(PUSH_SEQUENCE[_anim_index % PUSH_SEQUENCE.size()])
	flip_h = player.facing_left
	flip_v = false

func _update_roll(player) -> void:
	var speed = absi(player.inertia)
	var sequence = ROLL_FAST_SEQUENCE if speed >= 0x600 else ROLL_SEQUENCE
	var interval = maxi(0, (0x400 - speed) >> 8)
	_tick_animation(sequence.size(), interval)
	_set_frame(sequence[_anim_index % sequence.size()])
	flip_h = player.facing_left
	flip_v = false

func _tick_animation(frame_count: int, interval: int) -> bool:
	if frame_count <= 0:
		return false
	_anim_timer -= 1
	if _anim_timer >= 0:
		return false
	_anim_timer = interval
	_anim_index = (_anim_index + 1) % frame_count
	return true

func _set_frame(frame_id: int) -> void:
	frame_id = clampi(frame_id, 0, 87)
	if not _texture_cache.has(frame_id):
		_texture_cache[frame_id] = load("res://assets/sonic/frames/%02d.png" % frame_id)
	texture = _texture_cache[frame_id]
