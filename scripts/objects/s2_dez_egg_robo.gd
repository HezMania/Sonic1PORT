class_name S2DEZEggRobo
extends GenesisLevelObject

# Sonic 2 Object $C7: Death Egg Robot final boss. The Genesis object creates a
# linked family of OST children; here those pieces remain separate Sprite2D nodes
# but follow the source state order, attack selector, collision roles and defeat.

const FOLDER: String = "s2_dez/egg_robo"
const START_X: int = 0x840
const START_Y: int = 0x19C
const ARENA_LEFT: int = 0x680
const ARENA_RIGHT: int = 0x740
const STAND_Y: int = 0x124 # $19C - $78 pixels after the retail $79 rise
const DEFEAT_FLOOR_Y: int = 0x15C
const HITS: int = 0x0C
# Raw byte_3D680 table. Retail increments angle BEFORE indexing it, so a fresh
# boss (angle=0) executes 0,2,4,2... rather than starting with attack 2.
const ATTACK_ORDER: Array[int] = [2, 0, 2, 4]

# Body deltas from ObjC7_GroupAni_3E438, in source 1/16-pixel units per tick.
# off_3E40C is the long first/recurring forward walk; off_3E42C is its recovery.
const WALK_GROUP_DX16: Array[int] = [0, -16, -8, 0, -12, 0, -16, -8, 0, -12, 0, 0]
const WALK_GROUP_DY16: Array[int] = [-4, -4, 4, 8, -4, 0, -4, 4, 8, -4, 0, 8]
const WALK_GROUP_DURATION: Array[int] = [0x20, 0x10, 0x10, 0x10, 0x20, 0x20, 0x10, 0x10, 0x10, 0x20, 0x20, 0x10]
const WALK_FORWARD_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1, 2, 3, 4, 5, 6, 7, 8]
const WALK_RECOVERY_SEQUENCE: Array[int] = [8, 7, 6, 5, 11]

# off_3E30A / ObjC7_GroupAni_3E318: the exact nine linked groups played
# after the targeting stomp hits the floor. Each group runs for 8 VBlanks.
# The torso, both forearms and upper arm share the main-object delta; both
# thighs use the smaller linked delta. Shoulder/head/jet are source parent-followers
# (loc_3E282), so they follow the moving main body while both lower legs stay put.
const SLAM_GROUP_DX16: Array[int] = [-32, -20, -8, -4, 0, 4, 12, 24, 24]
const SLAM_GROUP_DY16: Array[int] = [12, 20, 20, 12, 0, -24, -24, -12, -4]
const SLAM_THIGH_DX16: Array[int] = [-8, -6, -2, 0, 0, 2, 4, 4, 6]
const SLAM_THIGH_DY16: Array[int] = [4, 6, 4, 2, 0, -6, -4, -4, -2]
const SLAM_GROUP_FRAMES: int = 8

const S2_SFX_BEEP: int = 0x28
const S2_SFX_RUMBLING: int = 0x37
const S2_SFX_SMASH: int = 0x39
const S2_SFX_HAMMER: int = 0x3D
const S2_SFX_BOSS_EXPLOSION: int = 0x44
const S2_SFX_FIRE: int = 0x5C
const S2_SFX_RUMBLING2: int = 0x61
const S2_SFX_SPINDASH_RELEASE: int = 0x3C

const ST_WAIT_RUNNER: int = 0
const ST_FADE: int = 1
const ST_RISE: int = 2
const ST_READY_WAIT: int = 3
const ST_SELECT: int = 4
const ST_ATTACK: int = 5
const ST_DEFEAT_FALL: int = 6
const ST_DEFEAT_WAIT: int = 7
const ST_FORCE_RIGHT: int = 8
const ST_ENDING: int = 9

# Compact pose equivalents for the linked group-animation tables. The discrete
# attack state/timing comes directly from ObjC7; these values preserve the visible
# body/thigh stepping relationship without flattening the robot into one sprite.
const POSE_TABLE: Array = [
	[-2, 1, -1, 0], [-1, 1, 0, 0], [-1, 1, 0, 0], [0, 1, 0, 0],
	[0, 0, 0, 0], [0, -2, 0, 0], [1, -2, 0, 0], [2, -1, 0, 0], [2, 0, 0, 0],
]
const BREAK_SPEEDS: Array = [
	[0x200, -0x400], [-0x100, -0x100], [0x300, -0x300], [-0x100, -0x400],
	[0x180, -0x200], [-0x200, -0x300], [0, -0x400], [0x100, -0x300],
]

var body: Sprite2D
var shoulder: Sprite2D
var front_lower: Sprite2D
var front_forearm: Sprite2D
var arm: Sprite2D
var front_thigh: Sprite2D
var head: Sprite2D
var jet: Sprite2D
var back_lower: Sprite2D
var back_forearm: Sprite2D
var back_thigh: Sprite2D
var pieces: Array[Sprite2D] = []

var state: int = ST_WAIT_RUNNER
var secondary: int = 0
var timer: int = 0
var health: int = HITS
var hit_flash: int = 0
var attack_index: int = 0
var attack_kind: int = 2
var phase_counter: int = 0
var facing_left: bool = true
var x_fixed: int = START_X << 16
var y_fixed: int = START_Y << 16
var vx: int = 0
var vy: int = 0
var pose_index: int = 4
var pose_timer: int = 0
var walk_sequence_index: int = 0
var walk_group_timer: int = 0
var walk_recovery: bool = false
var slam_group_index: int = 0
var slam_group_timer: int = 0
var slam_torso_offset: Vector2 = Vector2.ZERO
var slam_thigh_offset: Vector2 = Vector2.ZERO
var target_x: int = 0
var target_sensor: Sprite2D
var target_lock: Sprite2D
var target_timer: int = 0
var target_beep: int = 0x18
var target_vx_history: Array[int] = [0, 0, 0, 0]
var target_vy_history: Array[int] = [0, 0, 0, 0]
var bombs: Array = []
var broken_parts: Array = []
var front_forearm_offset: Vector2 = Vector2.ZERO
var back_forearm_offset: Vector2 = Vector2.ZERO
var front_hand_state: int = 0
var back_hand_state: int = 0
var front_hand_timer: int = 0
var back_hand_timer: int = 0
var front_hand_vx: int = 0
var front_hand_vy: int = 0
var back_hand_vx: int = 0
var back_hand_vy: int = 0
var front_hand_saved_y: float = 0.0
var back_hand_saved_y: float = 0.0

# Source group-animation local offsets. The Genesis children are independent objects,
# while our parts are Node2D children, so these store each child's motion relative
# to the main body after subtracting the main object's per-frame delta.
var front_lower_walk_offset: Vector2 = Vector2.ZERO
var front_forearm_walk_offset: Vector2 = Vector2.ZERO
var arm_walk_offset: Vector2 = Vector2.ZERO
var front_thigh_walk_offset: Vector2 = Vector2.ZERO
var back_lower_walk_offset: Vector2 = Vector2.ZERO
var back_forearm_walk_offset: Vector2 = Vector2.ZERO
var back_thigh_walk_offset: Vector2 = Vector2.ZERO
var ending_timer: int = 0
var white_layer: CanvasLayer
var white_rect: ColorRect
var head_intro_started: bool = false
var head_intro_timer: int = 0
var head_post_close_timer: int = 0

func initialize_object() -> void:
	x_fixed = spawn_x << 16
	y_fixed = spawn_y << 16
	active_width = 0x38
	_create_parts()
	_set_static_parts()
	manager.boss_limit_right = 0x1000
	manager.boss_screen_lock = false
	state = ST_WAIT_RUNNER

func suppress_central_despawn() -> bool:
	return true

func central_despawn_x() -> int:
	return x_fixed >> 16

func tick() -> void:
	if not alive or manager == null:
		return
	phase_counter += 1
	if hit_flash > 0:
		hit_flash -= 1
	match state:
		ST_WAIT_RUNNER: _tick_wait_runner()
		ST_FADE: _tick_fade()
		ST_RISE: _tick_rise()
		ST_READY_WAIT: _tick_ready_wait()
		ST_SELECT: _tick_select()
		ST_ATTACK: _tick_attack()
		ST_DEFEAT_FALL: _tick_defeat_fall()
		ST_DEFEAT_WAIT: _tick_defeat_wait()
		ST_FORCE_RIGHT: _tick_force_right()
		ST_ENDING: _tick_ending()
	_tick_bombs()
	_tick_broken_parts()
	_tick_forearms()
	position = Vector2(float(x_fixed) / 65536.0, float(y_fixed) / 65536.0)
	_update_parts()
	if state in [ST_READY_WAIT, ST_SELECT, ST_ATTACK]:
		_check_player_contact()

func _tick_wait_runner() -> void:
	# Retail head child waits for Object $C6 status bit 3, which is set when
	# Robotnik actually begins the $810 jump into the machine. Ani_objC7_a then
	# holds frame $15 for 8 entries at delay 7 (64 VBlanks), closes through
	# frames 0,1,2 for another 24 VBlanks, and only after that waits $40 before
	# setting the body's wake bit. Phase136 compressed all of that into 64 frames.
	if not manager.s2_dez_c6_departed:
		return
	if not head_intro_started:
		head_intro_started = true
		head_intro_timer = 0
		head_post_close_timer = 0x40
		_set_part_frame(head, 0x15)
		return
	if head_intro_timer < 88:
		head_intro_timer += 1
		if head_intro_timer <= 64:
			_set_part_frame(head, 0x15)
		elif head_intro_timer <= 72:
			_set_part_frame(head, 0)
		elif head_intro_timer <= 80:
			_set_part_frame(head, 1)
		else:
			_set_part_frame(head, 2)
		return
	if head_post_close_timer >= 0:
		head_post_close_timer -= 1
		return
	state = ST_FADE
	timer = 0x3C
	SonicAudio.stop_music()

func _tick_fade() -> void:
	timer -= 1
	if timer >= 0:
		return
	state = ST_RISE
	timer = 0x79
	vy = -0x100
	SonicAudio.play_music(SonicAudio.MUS_S2_END_BOSS, true)
	_set_part_frame(jet, 0x0D)

func _tick_rise() -> void:
	timer -= 1
	if timer != 0:
		if (phase_counter & 7) == 0:
			SonicAudio.play_s2_pcm_sfx(S2_SFX_RUMBLING)
		y_fixed += GenesisMath.s16(vy) << 8
		return
	vy = 0
	state = ST_READY_WAIT
	timer = 0x1F
	health = HITS
	_set_part_frame(jet, 0x0C)
	manager.boss_object = self
	manager.boss_screen_lock = true
	manager.boss_limit_right = ARENA_RIGHT
	manager.s2_dez_final_boss_active = true

func _tick_ready_wait() -> void:
	timer -= 1
	if timer < 0:
		state = ST_SELECT

func _tick_select() -> void:
	# loc_3D640: addq.b #1,angle happens before byte_3D680 is indexed.
	attack_index = (attack_index + 1) & 3
	attack_kind = ATTACK_ORDER[attack_index]
	secondary = 0
	timer = 0x20
	pose_index = 4
	walk_sequence_index = 0
	walk_group_timer = 0
	walk_recovery = false
	_reset_walk_offsets()
	_reset_slam_offsets()
	state = ST_ATTACK
	if attack_kind == 2:
		_set_part_frame(jet, 0x0D)

func _tick_attack() -> void:
	match attack_kind:
		0: _tick_walk_attack()
		2: _tick_stomp_attack()
		4: _tick_arm_attack()

func _tick_walk_attack() -> void:
	match secondary:
		0:
			# byte_3D680 attack 0 begins with the common $20 wait.
			timer -= 1
			if timer < 0:
				secondary = 1
				_begin_source_walk(false)
		1:
			# off_3E40C / ObjC7_GroupAni_3E438. The source moves the body via
			# 1/16-pixel animation deltas rather than a conventional x_vel.
			if _tick_source_walk():
				secondary = 2
				timer = 0x40
				pose_index = 4
		2:
			timer -= 1
			if timer < 0:
				secondary = 3
				_begin_source_walk(true)
		3:
			# off_3E42C reverses frames 8,7,6,5, then applies frame $B.
			if _tick_source_walk():
				pose_index = 4
				_finish_attack()

func _begin_source_walk(recovery: bool) -> void:
	walk_recovery = recovery
	walk_sequence_index = 0
	var group: int = int(WALK_FORWARD_SEQUENCE[0])
	if recovery:
		group = int(WALK_RECOVERY_SEQUENCE[0])
	walk_group_timer = int(WALK_GROUP_DURATION[group])

func _tick_source_walk() -> bool:
	var sequence: Array[int]
	if walk_recovery:
		sequence = WALK_RECOVERY_SEQUENCE
	else:
		sequence = WALK_FORWARD_SEQUENCE
	if walk_sequence_index >= sequence.size():
		return true
	var group: int = int(sequence[walk_sequence_index])
	var dx16: int = int(WALK_GROUP_DX16[group])
	var dy16: int = int(WALK_GROUP_DY16[group])
	# $88/$87/$86/$85 in off_3E42C set d4, negating both deltas.
	if walk_recovery and walk_sequence_index < 4:
		dx16 = -dx16
		dy16 = -dy16
	# render_flags bit 0 mirrors only X. Our semantic flag is true when the
	# unflipped retail artwork faces left, so right-facing motion is mirrored.
	# Apply exact objC7_c per-child deltas. The helper converts their world-space
	# Genesis deltas into local offsets because our pieces inherit the parent body.
	_apply_walk_group_limb_deltas(group, walk_recovery and walk_sequence_index < 4)
	if not facing_left:
		dx16 = -dx16
	x_fixed += dx16 * 0x1000
	y_fixed += dy16 * 0x1000
	pose_index = 4
	walk_group_timer -= 1
	if walk_group_timer > 0:
		return false
	walk_sequence_index += 1
	if not walk_recovery and walk_sequence_index in [4, 9, 14, 19]:
		SonicAudio.play_s2_pcm_sfx(S2_SFX_HAMMER)
	if walk_sequence_index >= sequence.size():
		if walk_recovery:
			SonicAudio.play_s2_pcm_sfx(S2_SFX_HAMMER)
		return true
	group = int(sequence[walk_sequence_index])
	walk_group_timer = int(WALK_GROUP_DURATION[group])
	return false

func _tick_stomp_attack() -> void:
	match secondary:
		0:
			timer -= 1
			if timer < 0:
				secondary = 1
				timer = 0x80
				vy = -0x200
				pose_index = 4
		1:
			timer -= 1
			if timer >= 0:
				if (phase_counter & 0x1F) == 0:
					SonicAudio.play_s2_pcm_sfx(S2_SFX_FIRE)
				y_fixed += GenesisMath.s16(vy) << 8
				return
			vy = 0
			secondary = 2
			_start_target_sensor()
		2:
			_tick_target_sensor()
			if target_timer > 0:
				return
			secondary = 3
			x_fixed = target_x << 16
			facing_left = target_x >= 0x780
			vy = 0x800
			timer = 0x20
			_clear_target_sensor()
		3:
			timer -= 1
			if timer >= 0:
				y_fixed += GenesisMath.s16(vy) << 8
				return
			vy = 0
			y_fixed = STAND_Y << 16
			secondary = 4
			_begin_slam_recovery()
			SonicAudio.play_s2_pcm_sfx(S2_SFX_SMASH)
			_set_part_frame(jet, 0x0C)
		4:
			# Retail loc_3D7F0 runs off_3E30A here, not a stationary delay.
			# The linked torso lurches forward/down over groups 0..3 and returns
			# through groups 5..8 before the player-facing/bomb decision.
			if not _tick_slam_recovery():
				return
			var p: SonicPlayer = player()
			if p != null:
				var boss_faces_player: bool = (p.pixel_x() < (x_fixed >> 16)) == facing_left
				if not boss_faces_player:
					_spawn_bombs()
					timer = 0x60
					secondary = 5
					return
			_finish_attack()
		5:
			timer -= 1
			if timer < 0:
				_finish_attack()

func _begin_slam_recovery() -> void:
	slam_group_index = 0
	slam_group_timer = SLAM_GROUP_FRAMES
	_reset_slam_offsets()

func _tick_slam_recovery() -> bool:
	if slam_group_index >= SLAM_GROUP_DX16.size():
		_reset_slam_offsets()
		return true
	var body_dx16: int = int(SLAM_GROUP_DX16[slam_group_index])
	var body_dy16: int = int(SLAM_GROUP_DY16[slam_group_index])
	var thigh_dx16: int = int(SLAM_THIGH_DX16[slam_group_index])
	var thigh_dy16: int = int(SLAM_THIGH_DY16[slam_group_index])
	# Genesis render_flags bit 0 mirrors X only. In this adapter that is the
	# right-facing case (facing_left == false).
	if not facing_left:
		body_dx16 = -body_dx16
		thigh_dx16 = -thigh_dx16
	slam_torso_offset += Vector2(float(body_dx16) / 16.0, float(body_dy16) / 16.0)
	slam_thigh_offset += Vector2(float(thigh_dx16) / 16.0, float(thigh_dy16) / 16.0)
	slam_group_timer -= 1
	if slam_group_timer > 0:
		return false
	slam_group_index += 1
	if slam_group_index >= SLAM_GROUP_DX16.size():
		# off_3E30A terminates with $C0; loc_3D7F0 then calls
		# ObjC7_PositionChildren, snapping every child back to its base delta.
		_reset_slam_offsets()
		return true
	slam_group_timer = SLAM_GROUP_FRAMES
	return false

func _reset_slam_offsets() -> void:
	slam_torso_offset = Vector2.ZERO
	slam_thigh_offset = Vector2.ZERO

func _start_target_sensor() -> void:
	var p: SonicPlayer = player()
	if p == null:
		target_x = x_fixed >> 16
		target_timer = 0
		return
	target_sensor = Sprite2D.new()
	target_sensor.centered = true
	target_sensor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target_sensor.z_as_relative = false
	target_sensor.z_index = 55
	add_child(target_sensor)
	_set_part_frame(target_sensor, 0x10)
	target_sensor.global_position = Vector2(p.pixel_x(), p.pixel_y())
	target_timer = 0xE0 # $A0 tracking + $40 target-lock window
	target_beep = 0x18
	target_vx_history = [GenesisMath.s16(p.vel_x), 0, 0, 0]
	target_vy_history = [GenesisMath.s16(p.vel_y), 0, 0, 0]

func _tick_target_sensor() -> void:
	if target_sensor == null or not is_instance_valid(target_sensor):
		target_timer = 0
		return
	var p: SonicPlayer = player()
	target_timer -= 1
	if target_timer > 0x40 and p != null:
		# Retail shifts the player's x/y velocity through objoff_30→34→38→3C
		# and moves the sensor with the oldest value. This makes the reticle trail
		# acceleration by a few frames. Phase136 instead added velocity/32 directly
		# to player position, producing a large forward lead.
		var delayed_vx: int = int(target_vx_history[3])
		var delayed_vy: int = int(target_vy_history[3])
		var current_vx: int = GenesisMath.s16(p.vel_x)
		var current_vy: int = GenesisMath.s16(p.vel_y)
		for i in range(3, 0, -1):
			target_vx_history[i] = target_vx_history[i - 1]
			target_vy_history[i] = target_vy_history[i - 1]
		target_vx_history[0] = current_vx
		target_vy_history[0] = current_vy
		if current_vx == 0:
			target_sensor.global_position.x = p.pixel_x()
		if current_vy == 0:
			target_sensor.global_position.y = p.pixel_y()
		target_sensor.global_position.x += float(GenesisMath.s16(delayed_vx)) / 256.0
		target_sensor.global_position.y += float(GenesisMath.s16(delayed_vy)) / 256.0
		var seq: Array[int] = [0x13, 0x12, 0x11, 0x10, 0x16]
		_set_part_frame(target_sensor, seq[(phase_counter >> 2) % seq.size()])
	else:
		if target_lock == null:
			target_lock = Sprite2D.new()
			target_lock.centered = true
			target_lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			target_lock.z_as_relative = false
			target_lock.z_index = 54
			add_child(target_lock)
			_set_part_frame(target_lock, 0x14)
			target_lock.global_position = target_sensor.global_position
			target_x = int(round(target_sensor.global_position.x))
			target_sensor.global_position = target_lock.global_position
		if target_lock != null:
			target_lock.visible = ((target_timer >> 2) & 1) == 0
	if target_timer > 0:
		target_beep -= 1
		if target_beep < 0:
			target_beep = maxi(4, target_timer >> 4)
			SonicAudio.play_s2_pcm_sfx(S2_SFX_BEEP)

func _clear_target_sensor() -> void:
	if target_sensor != null and is_instance_valid(target_sensor):
		target_sensor.queue_free()
	if target_lock != null and is_instance_valid(target_lock):
		target_lock.queue_free()
	target_sensor = null
	target_lock = null

func _tick_arm_attack() -> void:
	# Attack 4 triggers the two independent forearm children in sequence. Retail
	# sets parent status bit 4, waits $40, then bit 5; each child runs its own
	# $10 drop + $20 launch + $20 reverse + $20 recovery state machine.
	match secondary:
		0:
			timer -= 1
			if timer < 0:
				secondary = 1
				timer = 0x40
				var p: SonicPlayer = player()
				if p != null:
					var player_left: bool = p.pixel_x() < (x_fixed >> 16)
					if player_left != facing_left:
						facing_left = player_left
				_trigger_front_hand()
		1:
			timer -= 1
			if timer < 0:
				secondary = 2
				timer = 0x40
				_trigger_back_hand()
		2:
			timer -= 1
			if timer < 0:
				secondary = 3
				timer = 0x40
		3:
			timer -= 1
			if timer < 0:
				_finish_attack()

func _trigger_front_hand() -> void:
	if front_hand_state != 0:
		return
	front_hand_state = 1
	front_hand_timer = 0x10
	front_hand_vx = 0
	front_hand_vy = 0
	front_hand_saved_y = front_forearm_offset.y

func _trigger_back_hand() -> void:
	if back_hand_state != 0:
		return
	back_hand_state = 1
	back_hand_timer = 0x10
	back_hand_vx = 0
	back_hand_vy = 0
	back_hand_saved_y = back_forearm_offset.y

func _choose_hand_launch_y(hand_global_y: float) -> int:
	var p: SonicPlayer = player()
	if p == null:
		return 0
	var dy: int = p.pixel_y() - int(round(hand_global_y))
	var sign_y: int = 1 if dy >= 0 else -1
	var ady: int = mini(0xFF, absi(dy))
	var band: int = (ady & 0xC0) >> 6
	var speeds: Array[int] = [0x200, 0x100, 0x80, 0]
	return sign_y * speeds[clampi(band, 0, 3)]

func _tick_forearms() -> void:
	_tick_one_forearm(true)
	_tick_one_forearm(false)

func _tick_one_forearm(front: bool) -> void:
	var hstate: int = front_hand_state if front else back_hand_state
	if hstate == 0:
		return
	var htimer: int = front_hand_timer if front else back_hand_timer
	var hvx: int = front_hand_vx if front else back_hand_vx
	var hvy: int = front_hand_vy if front else back_hand_vy
	var hoff: Vector2 = front_forearm_offset if front else back_forearm_offset
	var saved_y: float = front_hand_saved_y if front else back_hand_saved_y

	if hstate == 1:
		htimer -= 1
		if htimer >= 0:
			hvy = GenesisMath.s16(hvy + 0x20)
			hoff.y += float(GenesisMath.s16(hvy)) / 256.0
		else:
			hstate = 2
			htimer = 0x20
			var base_y: float = float(y_fixed >> 16) + 8.0 + hoff.y
			hvy = _choose_hand_launch_y(base_y)
			hvx = -0x800 if facing_left else 0x800
			SonicAudio.play_s2_pcm_sfx(S2_SFX_SPINDASH_RELEASE)
	elif hstate == 2:
		htimer -= 1
		if htimer >= 0:
			hoff.x += float(GenesisMath.s16(hvx)) / 256.0
			hoff.y += float(GenesisMath.s16(hvy)) / 256.0
		else:
			hstate = 3
			htimer = 0x20
			hvx = GenesisMath.s16(-hvx)
			hvy = GenesisMath.s16(int(round((saved_y - hoff.y) * 8.0)))
	elif hstate == 3:
		htimer -= 1
		if htimer >= 0:
			hoff.x += float(GenesisMath.s16(hvx)) / 256.0
			hoff.y += float(GenesisMath.s16(hvy)) / 256.0
		else:
			hstate = 0
			htimer = 0
			hvx = 0
			hvy = 0
			hoff = Vector2(0.0, saved_y)

	if front:
		front_hand_state = hstate
		front_hand_timer = htimer
		front_hand_vx = hvx
		front_hand_vy = hvy
		front_forearm_offset = hoff
	else:
		back_hand_state = hstate
		back_hand_timer = htimer
		back_hand_vx = hvx
		back_hand_vy = hvy
		back_forearm_offset = hoff

func _finish_attack() -> void:
	state = ST_SELECT
	secondary = 0
	timer = 0
	pose_index = 4
	_reset_walk_offsets()
	_reset_slam_offsets()


func _reset_walk_offsets() -> void:
	front_lower_walk_offset = Vector2.ZERO
	front_forearm_walk_offset = Vector2.ZERO
	arm_walk_offset = Vector2.ZERO
	front_thigh_walk_offset = Vector2.ZERO
	back_lower_walk_offset = Vector2.ZERO
	back_forearm_walk_offset = Vector2.ZERO
	back_thigh_walk_offset = Vector2.ZERO

func _apply_walk_limb_delta(part: int, dx16: int, dy16: int, body_dx16: int, body_dy16: int, reverse_both: bool) -> void:
	var pdx: int = dx16
	var pdy: int = dy16
	var bdx: int = body_dx16
	var bdy: int = body_dy16
	if not facing_left:
		pdx = -pdx
		bdx = -bdx
	if reverse_both:
		pdx = -pdx
		pdy = -pdy
		bdx = -bdx
		bdy = -bdy
	var delta: Vector2 = Vector2(float(pdx - bdx) / 16.0, float(pdy - bdy) / 16.0)
	match part:
		0: front_lower_walk_offset += delta
		1: front_forearm_walk_offset += delta
		2: arm_walk_offset += delta
		3: front_thigh_walk_offset += delta
		4: back_lower_walk_offset += delta
		5: back_forearm_walk_offset += delta
		6: back_thigh_walk_offset += delta

func _apply_walk_group_limb_deltas(group: int, reverse_both: bool) -> void:
	# Exact ObjC7_GroupAni_3E438 entries. Missing child entries have zero world
	# delta, so their local delta is the negative of the main body's movement.
	var bdx: int = int(WALK_GROUP_DX16[group])
	var bdy: int = int(WALK_GROUP_DY16[group])
	var fl: Vector2i = Vector2i.ZERO
	var ff: Vector2i = Vector2i.ZERO
	var aa: Vector2i = Vector2i.ZERO
	var ft: Vector2i = Vector2i.ZERO
	var bl: Vector2i = Vector2i.ZERO
	var bf: Vector2i = Vector2i.ZERO
	var bt: Vector2i = Vector2i.ZERO
	match group:
		0:
			ft = Vector2i(-8, -8)
			fl = Vector2i(-8, -8)
			ff = Vector2i(4, -5)
			aa = Vector2i(3, -5)
			bf = Vector2i(-4, -5)
			bt = Vector2i(0, -2)
		1:
			ft = Vector2i(-16, -4)
			fl = Vector2i(-16, -4)
			ff = Vector2i(-12, -5)
			aa = Vector2i(-13, -5)
			bf = Vector2i(-20, -5)
			bt = Vector2i(-8, 0)
		2:
			ft = Vector2i(-8, 4)
			fl = Vector2i(-8, 4)
			ff = Vector2i(-4, 3)
			aa = Vector2i(-5, 3)
			bf = Vector2i(-12, 3)
		3:
			ft = Vector2i(-4, 16)
			fl = Vector2i(-8, 16)
			ff = Vector2i(-8, 10)
			aa = Vector2i(-6, 10)
			bf = Vector2i(8, 10)
			bt = Vector2i(0, 8)
		4:
			ft = Vector2i(-2, -2)
			ff = Vector2i(-16, -3)
			aa = Vector2i(-15, -3)
			bf = Vector2i(-8, -3)
			bt = Vector2i(-20, -6)
			bl = Vector2i(-24, -4)
		5:
			bt = Vector2i(-8, -4)
			bl = Vector2i(-8, -4)
			ff = Vector2i(-4, -1)
			aa = Vector2i(-3, -1)
			bf = Vector2i(4, -1)
		6:
			bt = Vector2i(-16, -4)
			bl = Vector2i(-16, -4)
			ff = Vector2i(-20, -5)
			aa = Vector2i(-19, -5)
			bf = Vector2i(-12, -5)
			ft = Vector2i(-8, 0)
		7:
			bt = Vector2i(-8, 4)
			bl = Vector2i(-8, 4)
			ff = Vector2i(-12, 3)
			aa = Vector2i(-11, 3)
			bf = Vector2i(-4, 3)
		8:
			bt = Vector2i(-4, 16)
			bl = Vector2i(-8, 16)
			ff = Vector2i(8, 10)
			aa = Vector2i(6, 10)
			bf = Vector2i(-8, 10)
			ft = Vector2i(0, 8)
		9:
			bt = Vector2i(-2, -2)
			ff = Vector2i(-8, -3)
			aa = Vector2i(-9, -3)
			bf = Vector2i(-15, -3)
			ft = Vector2i(-20, -6)
			fl = Vector2i(-24, -4)
		10:
			ft = Vector2i(-8, -4)
			fl = Vector2i(-8, -4)
			ff = Vector2i(4, -1)
			aa = Vector2i(3, -1)
			bf = Vector2i(-4, -1)
		11:
			bt = Vector2i(0, 8)
			bl = Vector2i(0, 8)
			ff = Vector2i(0, 8)
			aa = Vector2i(0, 8)
			bf = Vector2i(0, 8)
			ft = Vector2i(0, 8)
	_apply_walk_limb_delta(0, fl.x, fl.y, bdx, bdy, reverse_both)
	_apply_walk_limb_delta(1, ff.x, ff.y, bdx, bdy, reverse_both)
	_apply_walk_limb_delta(2, aa.x, aa.y, bdx, bdy, reverse_both)
	_apply_walk_limb_delta(3, ft.x, ft.y, bdx, bdy, reverse_both)
	_apply_walk_limb_delta(4, bl.x, bl.y, bdx, bdy, reverse_both)
	_apply_walk_limb_delta(5, bf.x, bf.y, bdx, bdy, reverse_both)
	_apply_walk_limb_delta(6, bt.x, bt.y, bdx, bdy, reverse_both)

func _check_player_contact() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead or p.hurt_state:
		return
	var base_bx: int = (x_fixed >> 16) + int(POSE_TABLE[clampi(pose_index, 0, POSE_TABLE.size() - 1)][0])
	var base_by: int = (y_fixed >> 16) + int(POSE_TABLE[clampi(pose_index, 0, POSE_TABLE.size() - 1)][1])
	var bx: int = base_bx + int(round(slam_torso_offset.x))
	var by: int = base_by + int(round(slam_torso_offset.y))
	# Retail body/head collision flags are the attackable surfaces. ObjC7_Head
	# is a loc_3E282 parent-follower, so it tracks the main object's slam lurch even
	# though it is not explicitly listed in ObjC7_GroupAni_3E318.
	var body_hit: bool = absi(p.pixel_x() - bx) <= p.width_radius + 0x18 and absi(p.pixel_y() - by) <= p.height_radius + 0x18
	var head_hit: bool = absi(p.pixel_x() - bx) <= p.width_radius + 0x12 and absi(p.pixel_y() - (by - 0x34)) <= p.height_radius + 0x12
	if (body_hit or head_hit) and hit_flash <= 0 and p.can_attack_object():
		p.vel_x = GenesisMath.s16(-p.vel_x)
		p.vel_y = GenesisMath.s16(-p.vel_y)
		health -= 1
		hit_flash = 0x3C
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if health <= 0:
			_begin_defeat()
		return
	for pos in _hazard_centers():
		if absi(p.pixel_x() - pos.x) <= p.width_radius + 0x0C and absi(p.pixel_y() - pos.y) <= p.height_radius + 0x0C:
			p.apply_hazard_hit(bx)
			return

func _hazard_centers() -> Array[Vector2i]:
	var pose: Array = POSE_TABLE[clampi(pose_index, 0, POSE_TABLE.size() - 1)]
	var base_x: int = (x_fixed >> 16) + int(pose[0])
	var base_y: int = (y_fixed >> 16) + int(pose[1])
	var torso_x: int = base_x + int(round(slam_torso_offset.x))
	var torso_y: int = base_y + int(round(slam_torso_offset.y))
	var thigh_x: int = base_x + int(round(slam_thigh_offset.x))
	var thigh_y: int = base_y + int(round(slam_thigh_offset.y))
	var sx: int = 1 if facing_left else -1
	return [
		# Shoulder follows the moving main object through loc_3E282; lower legs are
		# omitted from the group and have no parent-follow routine, so they stay put.
		Vector2i(torso_x + sx * 12, torso_y - 20), Vector2i(base_x - sx * 4, base_y + 60),
		Vector2i(torso_x - sx * 12 + int(front_forearm_offset.x), torso_y + 8 + int(front_forearm_offset.y)),
		Vector2i(torso_x - sx * 12 + int(back_forearm_offset.x), torso_y + 8 + int(back_forearm_offset.y)),
		Vector2i(torso_x + sx * 12, torso_y - 8), Vector2i(thigh_x + sx * 4, thigh_y + 36),
	]

func _spawn_bombs() -> void:
	for pair in [[0x60, -0x800], [0xC0, -0xA00]]:
		var s: Sprite2D = Sprite2D.new()
		s.centered = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_as_relative = false
		s.z_index = 49
		add_child(s)
		_set_part_frame(s, 0x0E)
		var sx: int = 1 if facing_left else -1
		bombs.append({"sprite": s, "x": x_fixed, "y": y_fixed, "vx": sx * int(pair[0]), "vy": int(pair[1]), "state": 0, "timer": 0})

func _tick_bombs() -> void:
	var p: SonicPlayer = player()
	for i in range(bombs.size() - 1, -1, -1):
		var b: Dictionary = bombs[i]
		var s: Sprite2D = b.get("sprite") as Sprite2D
		if s == null or not is_instance_valid(s):
			bombs.remove_at(i)
			continue
		var bstate: int = int(b.get("state", 0))
		if state >= ST_DEFEAT_FALL:
			bstate = 2
		if bstate == 0:
			b["x"] = int(b["x"]) + (GenesisMath.s16(int(b["vx"])) << 8)
			b["y"] = int(b["y"]) + (GenesisMath.s16(int(b["vy"])) << 8)
			b["vy"] = GenesisMath.s16(int(b["vy"]) + 0x38)
			if (int(b["y"]) >> 16) >= 0x170:
				b["y"] = 0x170 << 16
				bstate = 1
				b["timer"] = 0x40
		elif bstate == 1:
			b["timer"] = int(b["timer"]) - 1
			if int(b["timer"]) < 0:
				bstate = 2
		if bstate == 2:
			SonicAudio.play_s2_pcm_sfx(S2_SFX_BOSS_EXPLOSION)
			manager.spawn_boss_explosion(int(b["x"]) >> 16, int(b["y"]) >> 16)
			s.queue_free()
			bombs.remove_at(i)
			continue
		b["state"] = bstate
		bombs[i] = b
		var wx: int = int(b["x"]) >> 16
		var wy: int = int(b["y"]) >> 16
		s.global_position = Vector2(wx, wy)
		if p != null and not p.dead and not p.hurt_state and absi(p.pixel_x() - wx) <= p.width_radius + 8 and absi(p.pixel_y() - wy) <= p.height_radius + 8:
			p.apply_hazard_hit(wx)

func _begin_defeat() -> void:
	manager.add_score(100)
	manager.boss_status = 2
	manager.boss_screen_lock = false
	manager.s2_dez_final_boss_active = false
	state = ST_DEFEAT_FALL
	secondary = 0
	vx = 0
	vy = 0
	pose_index = 4
	_reset_slam_offsets()
	_clear_target_sensor()
	_break_children()
	_set_part_frame(jet, 0x0D)
	jet.visible = false

func _break_children() -> void:
	var candidates: Array[Sprite2D] = [shoulder, front_lower, front_forearm, arm, front_thigh, back_lower, back_forearm, back_thigh]
	for i in range(candidates.size()):
		var original: Sprite2D = candidates[i]
		if original == null:
			continue
		var s: Sprite2D = Sprite2D.new()
		s.centered = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Preserve the fight-time front/back order after reparenting the fragment
		# out of the boss Node. Phase137 flattened every fragment to Z=50.
		s.z_as_relative = false
		s.z_index = original.z_index
		s.texture = original.texture
		s.flip_h = original.flip_h
		get_parent().add_child(s)
		s.global_position = original.global_position
		broken_parts.append({"sprite": s, "vx": int(BREAK_SPEEDS[i][0]), "vy": int(BREAK_SPEEDS[i][1]), "life": 0x80})
		original.visible = false

func _tick_broken_parts() -> void:
	for i in range(broken_parts.size() - 1, -1, -1):
		var d: Dictionary = broken_parts[i]
		var s: Sprite2D = d.get("sprite") as Sprite2D
		if s == null or not is_instance_valid(s):
			broken_parts.remove_at(i)
			continue
		var life: int = int(d["life"]) - 1
		if life < 0:
			s.queue_free()
			broken_parts.remove_at(i)
			continue
		var vx0: int = GenesisMath.s16(int(d["vx"]))
		var vy0: int = GenesisMath.s16(int(d["vy"]))
		s.position.x += float(vx0) / 256.0
		s.position.y += float(vy0) / 256.0
		d["vy"] = GenesisMath.s16(vy0 + 0x38)
		d["life"] = life
		broken_parts[i] = d

func _tick_defeat_fall() -> void:
	if (phase_counter & 7) == 0:
		_spawn_random_explosion()
	vy = GenesisMath.s16(vy + 0x38)
	y_fixed += GenesisMath.s16(vy) << 8
	if (y_fixed >> 16) < DEFEAT_FLOOR_Y:
		return
	y_fixed = DEFEAT_FLOOR_Y << 16
	if vy >= 0x100:
		vy = GenesisMath.s16(-(vy >> 2))
		return
	vy = 0
	state = ST_DEFEAT_WAIT
	timer = 0x40

func _tick_defeat_wait() -> void:
	if (phase_counter & 7) == 0:
		_spawn_random_explosion()
	timer -= 1
	if timer >= 0:
		return
	state = ST_FORCE_RIGHT
	manager.boss_limit_right = 0x1000
	manager.boss_screen_lock = false
	var p: SonicPlayer = player()
	if p != null:
		p.control_locked = true
		p.control_lock_direction = 1

func _tick_force_right() -> void:
	var p: SonicPlayer = player()
	if p != null and not p.dead:
		p.control_locked = true
		p.control_lock_direction = 1
		if not p.in_air:
			p.inertia = maxi(p.inertia, 0x600)
			p.vel_x = maxi(p.vel_x, 0x600)
	if manager.current_screen_x < 0x840:
		return
	state = ST_ENDING
	ending_timer = 0x20
	# Routine $20 (ObjC7_SetupEnding) never calls DisplaySprite: the remaining
	# midsection/head stay behind rather than becoming a camera-following shell.
	if body != null:
		body.visible = false
	if head != null:
		head.visible = false
	manager.s2_dez_ending_active = true

func _tick_ending() -> void:
	if (phase_counter & 0x1F) == 0:
		SonicAudio.play_s2_pcm_sfx(S2_SFX_RUMBLING2)
		ending_timer -= 1
	var p: SonicPlayer = player()
	if p == null:
		return
	# SetupEnding keeps the exploding shell objoff_2A pixels behind Sonic.
	x_fixed = (p.pixel_x() - ending_timer) << 16
	y_fixed = p.pixel_y() << 16
	if (phase_counter & 3) == 0:
		_spawn_random_explosion()
	if p.pixel_x() < 0xEC0:
		p.control_locked = true
		p.control_lock_direction = 1
		p.inertia = maxi(p.inertia, 0x600)
		p.vel_x = maxi(p.vel_x, 0x600)
		return
	if white_rect == null:
		_create_white_fade()
		timer = 0x16
		return
	if timer > 0:
		timer -= 1
		white_rect.color = Color(1, 1, 1, 1.0 - float(timer) / 22.0)
		return
	SonicAudio.stop_music()
	manager.request_final_ending()
	alive = false

func _create_white_fade() -> void:
	white_layer = CanvasLayer.new()
	white_layer.layer = 120
	add_child(white_layer)
	white_rect = ColorRect.new()
	white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white_rect.position = Vector2.ZERO
	white_rect.size = Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")), float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	white_rect.color = Color(1, 1, 1, 0)
	white_layer.add_child(white_rect)

func _spawn_random_explosion() -> void:
	var rx: int = int(manager.next_random_word() & 0x5F) - 0x30
	var ry: int = int((manager.next_random_word() >> 5) & 0x5F) - 0x30
	# Retail Boss_LoadExplosion creates Object $58 with the high-priority art bit.
	# Keep C7 defeat/ending explosions above Plane-A high-priority terrain.
	manager.spawn_boss_explosion_front((x_fixed >> 16) + rx, (y_fixed >> 16) + ry)
	if (phase_counter & 0x0F) == 0:
		SonicAudio.play_s2_pcm_sfx(S2_SFX_BOSS_EXPLOSION)

func _create_parts() -> void:
	# Object $C7 is itself spawned at project Z=40. These are absolute canvas
	# depths (not relative child depths): retail Sonic priority 2 must remain in
	# front of C7 priority 4/5 pieces, while the robot's own front/back ordering
	# is preserved. The values retain Phase137's internal ordering, shifted below
	# normal Sonic's Z=50.
	back_lower = _new_part("BackLower", 0x0B, 41)
	back_forearm = _new_part("BackForearm", 0x06, 41)
	back_thigh = _new_part("BackThigh", 0x0A, 41)
	jet = _new_part("Jet", 0x0C, 42)
	body = _new_part("Body", 0x03, 44)
	arm = _new_part("Arm", 0x05, 45)
	front_thigh = _new_part("FrontThigh", 0x0A, 45)
	front_lower = _new_part("FrontLower", 0x0B, 46)
	front_forearm = _new_part("FrontForearm", 0x06, 47)
	shoulder = _new_part("Shoulder", 0x04, 48)
	head = _new_part("Head", 0x15, 49)
	pieces = [body, shoulder, front_lower, front_forearm, arm, front_thigh, head, jet, back_lower, back_forearm, back_thigh]

func _new_part(label: String, frame: int, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = label
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_as_relative = false
	s.z_index = z
	add_child(s)
	_set_part_frame(s, frame)
	return s

func _set_static_parts() -> void:
	pose_index = 4
	_update_parts()

func _body_pose_x() -> int:
	return int(POSE_TABLE[clampi(pose_index, 0, POSE_TABLE.size() - 1)][0])

func _body_pose_y() -> int:
	return int(POSE_TABLE[clampi(pose_index, 0, POSE_TABLE.size() - 1)][1])

func _update_parts() -> void:
	if body == null:
		return
	var pose: Array = POSE_TABLE[clampi(pose_index, 0, POSE_TABLE.size() - 1)]
	var bdx: int = int(pose[0])
	var bdy: int = int(pose[1])
	var tdx: int = int(pose[2])
	var tdy: int = int(pose[3])
	var sx: int = 1 if facing_left else -1
	body.position = Vector2(bdx, bdy) + slam_torso_offset
	# In retail these three children execute loc_3E282 every frame, rebuilding
	# their position from the moving ObjC7 main object. Because this port models
	# the group animation as a local main-body offset, add that same offset here.
	shoulder.position = Vector2(bdx + sx * 12, bdy - 20) + slam_torso_offset
	front_lower.position = Vector2(bdx - sx * 4, bdy + 60) + front_lower_walk_offset
	front_forearm.position = Vector2(bdx - sx * 12, bdy + 8) + front_forearm_walk_offset + front_forearm_offset + slam_torso_offset
	arm.position = Vector2(bdx + sx * 12, bdy - 8) + arm_walk_offset + slam_torso_offset
	front_thigh.position = Vector2(bdx + sx * (4 + tdx), bdy + 36 + tdy) + front_thigh_walk_offset + slam_thigh_offset
	head.position = Vector2(bdx, bdy - 52) + slam_torso_offset
	jet.position = Vector2(bdx + sx * 56, bdy + 24) + slam_torso_offset
	back_lower.position = Vector2(bdx - sx * 4, bdy + 60) + back_lower_walk_offset
	back_forearm.position = Vector2(bdx - sx * 12, bdy + 8) + back_forearm_walk_offset + back_forearm_offset + slam_torso_offset
	back_thigh.position = Vector2(bdx + sx * (4 + tdx), bdy + 36 + tdy) + back_thigh_walk_offset + slam_thigh_offset
	for s in pieces:
		if s != null:
			s.flip_h = not facing_left
	var show_parts: bool = hit_flash == 0 or ((hit_flash >> 1) & 1) == 0
	for s in pieces:
		if s != null and s != jet:
			s.modulate = Color.WHITE if show_parts else Color(0.55, 0.55, 0.55, 1)
	if jet != null and jet.visible:
		_set_part_frame(jet, 0x0C if ((phase_counter >> 1) & 1) == 0 else 0x0D)

func _set_part_frame(s: Sprite2D, frame: int) -> void:
	if s == null:
		return
	var path: String = "res://assets/objects/%s/%02d.png" % [FOLDER, clampi(frame, 0, 22)]
	if ResourceLoader.exists(path):
		s.texture = load(path)
