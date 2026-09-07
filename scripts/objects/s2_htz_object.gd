class_name S2HTZObject
extends GenesisLevelObject

# Phase 108: retail-shaped Hill Top zone-specific objects and Phase 107 runtime corrections.
# $14 see-saw, $16 diagonal lift, $2F smashable ground, $30 earthquake terrain,
# $31 lava marker, $92 Spiker, $95 Sol, $96 Rexon alias/body.

var sprite: Sprite2D
var aux_sprites: Array[Sprite2D] = []
var state: int = 0
var timer: int = 0
var frame_counter: int = 0
var vel_x: int = 0
var vel_y: int = 0
var orig_x: int = 0
var orig_y: int = 0
var fixed_x: int = 0
var fixed_y: int = 0

# Seesaw
var seesaw_tilt: int = 1
var seesaw_ball: Sprite2D
var seesaw_ball_x: int = 0
var seesaw_ball_y: int = 0
var seesaw_ball_vy: int = 0
var seesaw_ball_vx: int = 0
var seesaw_ball_fixed_x: int = 0
var seesaw_ball_fixed_y: int = 0
var seesaw_ball_angle: int = 0
var seesaw_ball_state: int = 0
var seesaw_target_tilt: int = 0
var seesaw_last_impact_vy: int = 0
const SEESAW_SLOPE: Array[int] = [
	0x14,0x14,0x16,0x18,0x1A,0x1C,0x1A,0x18,0x16,0x14,0x13,0x12,0x11,0x10,0x0F,0x0E,
	0x0D,0x0C,0x0B,0x0A,0x09,0x08,0x07,0x06,0x05,0x04,0x03,0x02,0x01,0x00,-1,-2,
	-3,-4,-5,-6,-7,-8,-9,-10,-11,-12,-13,-14,-14,-14,-14,-14,-14
]
const SEESAW_Y_OFFSETS: Array[int] = [-8, -28, -47, -28, -8]
const SMASH_DEBRIS_X: Array[float] = [-1.0,1.0,-0.875,0.875,-0.75,0.75,-0.625,0.625,-0.5,0.5]
const SMASH_DEBRIS_Y: Array[float] = [-8.0,-8.0,-7.0,-7.0,-6.0,-6.0,-5.0,-5.0,-4.0,-4.0]

# Lift
var lift_slide_frames: int = 0
var lift_rope_remnant: Sprite2D

# Spiker
var drill_sprite: Sprite2D
var drill_active: bool = false
var spiker_spent: bool = false
var drill_y: float = 0.0
var drill_vy: float = 0.0

# Sol
var sol_fireballs: Array[Sprite2D] = []
var sol_angles: Array[int] = [0x00, 0x40, 0x80, 0xC0]
var sol_orbit_dir: int = 1
var sol_attack_started: bool = false
var sol_detached: bool = false
var sol_detached_x: float = 0.0

# Rexon
var rexon_head_active: bool = false
var rexon_head: Sprite2D
var rexon_segments: Array[Sprite2D] = []
var rexon_head_y: float = 16.0
var rexon_fire_timer: int = 0
var rexon_projectile: Sprite2D
var rexon_projectile_x: float = 0.0
var rexon_head_destroyed: bool = false
var rexon_phase: int = 0
# Phase 108: source-shaped Obj97 child state. Retail Rexon is five linked
# Obj97 instances (four neck links plus the damaging head), not a sine chain.
var rexon_links: Array[Sprite2D] = []
var rexon_link_state: Array[int] = []
var rexon_link_timer: Array[int] = []
var rexon_link_vx: Array[int] = []
var rexon_link_vy: Array[int] = []
var rexon_link_fixed_x: Array[int] = []
var rexon_link_fixed_y: Array[int] = []
var rexon_link_osc_phase: Array[int] = []
var rexon_link_osc_dir: Array[int] = []
var rexon_link_tick: Array[int] = []
const REXON_WAIT: Array[int] = [0x1E, 0x18, 0x12, 0x0C, 0x06]
const REXON_RAISE: Array[int] = [0x06, 0x0C, 0x12, 0x18, 0x1E]
const REXON_NORMAL_PHASE: Array[int] = [0x24, 0x20, 0x1C, 0x1A, 0x18]
const REXON_DEATH_X: Array[int] = [0x80, -0x100, 0x100, -0x80]
const REXON_OSC: Array[Vector2i] = [
	Vector2i(0x0F,0),Vector2i(0x0F,-1),Vector2i(0x0F,-1),Vector2i(0x0F,-2),
	Vector2i(0x0F,-3),Vector2i(0x0F,-4),Vector2i(0x0E,-4),Vector2i(0x0E,-5),
	Vector2i(0x0E,-6),Vector2i(0x0E,-6),Vector2i(0x0D,-7),Vector2i(0x0D,-8),
	Vector2i(0x0C,-8),Vector2i(0x0C,-9),Vector2i(0x0C,-10),Vector2i(0x0B,-10),
	Vector2i(0x0B,-11),Vector2i(0x0A,-11),Vector2i(0x0A,-12),Vector2i(9,-12),
	Vector2i(8,-12),Vector2i(8,-13),Vector2i(7,-13),Vector2i(6,-14),
	Vector2i(6,-14),Vector2i(5,-14),Vector2i(4,-14),Vector2i(4,-15),
	Vector2i(3,-15),Vector2i(2,-15),Vector2i(1,-15),Vector2i(1,-15)
]

# Smash-ground debris
var smash_fragments: Array[Sprite2D] = []
var smash_fragment_velocity: Array[Vector2] = []

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	fixed_x = spawn_x << 8
	fixed_y = spawn_y << 8
	match object_id:
		0x14: _init_seesaw()
		0x16: _init_lift()
		0x1C: _init_htz_scenery()
		0x2F: _init_smash_ground()
		0x30: _init_quake_terrain()
		0x31: _init_lava_marker()
		0x92: _init_spiker()
		0x95: _init_sol()
		0x96: _init_rexon()

func tick() -> void:
	frame_counter += 1
	match object_id:
		0x14: _tick_seesaw()
		0x16: _tick_lift()
		0x1C: _tick_htz_scenery()
		0x2F: _tick_smash_ground()
		0x30: _tick_quake_terrain()
		0x31: _tick_lava_marker()
		0x92: _tick_spiker()
		0x95: _tick_sol()
		0x96: _tick_rexon()

# -----------------------------------------------------------------------------
# Object $14 - HTZ seesaw
# -----------------------------------------------------------------------------
func _init_seesaw() -> void:
	active_width = 0x30
	# Placement status bit 0 selects the initial angle; Obj14 does not directly
	# flip the complete sprite from that bit.
	seesaw_tilt = 2 if x_flip else 0
	seesaw_target_tilt = seesaw_tilt
	sprite = make_sprite("res://assets/objects/s2_htz/seesaw/%02d.png" % seesaw_tilt, 2)
	sprite.flip_h = seesaw_tilt == 2
	sprite.flip_v = false
	seesaw_ball = make_sprite("res://assets/objects/s2_htz/seesaw_ball/00.png", 3)
	seesaw_ball_angle = seesaw_tilt
	seesaw_ball_state = 0
	seesaw_ball_x = -0x28 if x_flip else 0x28
	seesaw_ball_y = _seesaw_ball_rest_y(seesaw_ball_x, seesaw_tilt)
	seesaw_ball_fixed_x = seesaw_ball_x << 8
	seesaw_ball_fixed_y = seesaw_ball_y << 8
	seesaw_ball.position = Vector2(seesaw_ball_x, seesaw_ball_y)

func _seesaw_ball_rest_y(local_ball_x: int, board_frame: int) -> int:
	var idx: int = board_frame + (2 if local_ball_x < 0 else 0)
	return 0x10 + SEESAW_Y_OFFSETS[clampi(idx, 0, 4)]

func _tick_seesaw() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var supported_before: bool = p.standing_on_object and p.support_record_index == record_index

	# Obj14 mirrors the working SLZ seesaw path: a character already owned by the
	# platform follows SlopeObject_AssumeStoodOn directly. Re-running the fresh
	# landing penetration test while the board changes mapping is what caused
	# Sonic to remain floating at the previous sampled Y.
	if supported_before:
		var dx: int = spawn_x - p.pixel_x()
		var target: int = 2
		if dx < 0:
			dx = -dx
			target = 0
		if dx < 8:
			target = 1
		seesaw_target_tilt = target
	else:
		# The loose Sol ball can request a new board angle. With no rider the
		# board moves toward that stored target and snapshots incoming Y speed.
		seesaw_last_impact_vy = p.vel_y

	if seesaw_tilt != seesaw_target_tilt:
		seesaw_tilt += 1 if seesaw_target_tilt > seesaw_tilt else -1
		set_sprite_frame(sprite, "s2_htz/seesaw", seesaw_tilt)
		sprite.flip_h = seesaw_tilt == 2

	var top_y: int = _seesaw_top_y_for(p.pixel_x())
	if top_y == 0x7FFFFFFF:
		if supported_before:
			p.clear_object_support_for(record_index, false)
	else:
		if supported_before:
			p.snap_supported_slope(spawn_x - 0x30, spawn_x + 0x30, top_y, record_index)
		else:
			p.resolve_platform_top(spawn_x - 0x30, spawn_x + 0x30, top_y, record_index)

	# Obj14_Ball_Main launches only while its stored angle differs from the
	# parent's requested angle.
	if seesaw_ball_state == 0 and seesaw_ball_angle != seesaw_target_tilt:
		var diff: int = absi(seesaw_ball_angle - seesaw_target_tilt)
		seesaw_ball_vy = -0x818 if diff == 1 else -0xAF0
		seesaw_ball_vx = -0x114 if diff == 1 else -0xCC
		if diff != 1 and seesaw_last_impact_vy >= 0xA00:
			seesaw_ball_vy = -0xE00
			seesaw_ball_vx = -0xA0
		if seesaw_ball_x < 0:
			seesaw_ball_vx = -seesaw_ball_vx
		seesaw_ball_fixed_x = seesaw_ball_x << 8
		seesaw_ball_fixed_y = seesaw_ball_y << 8
		seesaw_ball_state = 1

	if seesaw_ball_state == 1:
		_tick_seesaw_ball_flight(p)
	else:
		seesaw_ball_y = _seesaw_ball_rest_y(seesaw_ball_x, seesaw_tilt)
		seesaw_ball_fixed_y = seesaw_ball_y << 8
	seesaw_ball.position = Vector2(seesaw_ball_x, seesaw_ball_y)

func _seesaw_top_y_for(world_x: int) -> int:
	var local_x: int = world_x - (spawn_x - 0x30)
	if local_x < 0 or local_x >= 0x60:
		return 0x7FFFFFFF
	var index: int = clampi(local_x >> 1, 0, 48)
	if seesaw_tilt == 2:
		index = 48 - index
	var height: int = 5 if seesaw_tilt == 1 else SEESAW_SLOPE[index]
	return spawn_y - height

func _seesaw_ball_move_and_fall() -> void:
	seesaw_ball_fixed_x += seesaw_ball_vx
	seesaw_ball_fixed_y += seesaw_ball_vy
	seesaw_ball_vy = GenesisMath.s16(seesaw_ball_vy + 0x38)
	seesaw_ball_x = seesaw_ball_fixed_x >> 8
	seesaw_ball_y = seesaw_ball_fixed_y >> 8

func _tick_seesaw_ball_flight(p: SonicPlayer) -> void:
	# ObjectFall is intentionally invoked twice on part of the upward arc.
	if seesaw_ball_vy < 0:
		_seesaw_ball_move_and_fall()
		if seesaw_ball_y >= -0x2F:
			_seesaw_ball_move_and_fall()
		return

	_seesaw_ball_move_and_fall()
	var left_side: bool = seesaw_ball_x < 0
	var landing_y: int = _seesaw_ball_rest_y(-0x28 if left_side else 0x28, seesaw_tilt)
	if seesaw_ball_y < landing_y:
		return
	seesaw_ball_y = landing_y
	seesaw_ball_fixed_y = landing_y << 8
	var target: int = 2 if seesaw_ball_vx < 0 else 0
	seesaw_target_tilt = target
	seesaw_ball_angle = target
	if target != seesaw_tilt and p.standing_on_object and p.support_record_index == record_index:
		p.clear_object_support()
		p.vel_y = -seesaw_ball_vy
		p.in_air = true
		p.jumping = false
		p.pushing = false
		p.spring_pose_timer = 48
		# The working SLZ seesaw bridge synchronizes immediately after the source
		# launch write; do the same here so the native render/physics transform cannot
		# retain the previous supported Y for an extra frame.
		p._sync_position()
	seesaw_ball_vx = 0
	seesaw_ball_vy = 0
	seesaw_ball_state = 0

# -----------------------------------------------------------------------------
# Object $16 - diagonal zip-line lift
# -----------------------------------------------------------------------------
func _init_lift() -> void:
	active_width = 0x20
	z_index = 55 # retail priority 1: in front of normal Sonic
	# Phase 108 uses source-rendered mirrored mapping canvases for status-bit-0
	# lifts. This avoids relying on a late Sprite2D flip after texture swapping and
	# makes the left-going vine/rope hooks visibly match the retail render flag.
	var lift_folder: String = "s2_htz/lift_flipped" if x_flip else "s2_htz/lift"
	sprite = make_sprite("res://assets/objects/%s/00.png" % lift_folder, 2)
	sprite.flip_h = false
	sprite.flip_v = false
	lift_slide_frames = subtype << 3
	state = 0

func _set_lift_frame(frame: int) -> void:
	var lift_folder: String = "s2_htz/lift_flipped" if x_flip else "s2_htz/lift"
	set_sprite_frame(sprite, lift_folder, frame)
	sprite.flip_h = false

func _spawn_lift_rope_remnant() -> void:
	if manager == null or lift_rope_remnant != null:
		return
	lift_rope_remnant = Sprite2D.new()
	lift_rope_remnant.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lift_folder: String = "s2_htz/lift_flipped" if x_flip else "s2_htz/lift"
	lift_rope_remnant.texture = load("res://assets/objects/%s/01.png" % lift_folder)
	lift_rope_remnant.flip_h = false
	lift_rope_remnant.position = position
	lift_rope_remnant.z_index = 44
	manager.add_child(lift_rope_remnant)

func _tick_lift() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var old_x: int = int(position.x)
	var old_y: int = int(position.y)
	if state == 0:
		var top_y: int = int(position.y) + 0x28
		p.resolve_platform_top(int(position.x) - 0x20, int(position.x) + 0x20, top_y, record_index)
		if p.standing_on_object and p.support_record_index == record_index:
			state = 1
			vel_x = -0x200 if x_flip else 0x200
			vel_y = 0x100
	elif state == 1:
		fixed_x += vel_x
		fixed_y += vel_y
		position.x = fixed_x / 256.0
		position.y = fixed_y / 256.0
		lift_slide_frames -= 1
		if lift_slide_frames <= 0:
			state = 2
			vel_x = 0
			vel_y = 0
			_set_lift_frame(2)
			_spawn_lift_rope_remnant()
	else:
		vel_y = GenesisMath.s16(vel_y + 0x38)
		fixed_x += vel_x
		fixed_y += vel_y
		position.x = fixed_x / 256.0
		position.y = fixed_y / 256.0

	# PlatformObject remains active during Obj16_Fall. This is what lets the
	# stripped platform take Sonic down with it instead of vanishing underneath him.
	var top: int = int(position.y) + 0x28
	p.move_with_supported_object(record_index, int(position.x) - old_x, int(position.y) - old_y, int(position.x) - 0x20, int(position.x) + 0x20, top)
	p.resolve_platform_top(int(position.x) - 0x20, int(position.x) + 0x20, top, record_index)

func _init_htz_scenery() -> void:
	active_width = 8
	var folder: String = "s2_htz/lift"
	var frame: int = 3
	match subtype:
		4: frame = 3
		5: frame = 4
		6: frame = 1
		7:
			folder = "s2_htz/lift_stake"
			frame = 0
		8:
			folder = "s2_htz/lift_stake"
			frame = 1
		_:
			visible = false
			return
	sprite = make_sprite("res://assets/objects/%s/%02d.png" % [folder, frame], 5)
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip

func _tick_htz_scenery() -> void:
	pass

# -----------------------------------------------------------------------------
# Object $2F - smashable ground stack
# -----------------------------------------------------------------------------
func _init_smash_ground() -> void:
	active_width = 0x10
	var frame: int = clampi(subtype & 0x0E, 0, 8)
	sprite = make_sprite("res://assets/objects/s2_htz/smash_ground/%02d.png" % frame, 2)
	state = 0

func _spawn_smash_debris() -> void:
	# byte_234F2 is ten (x_vel,y_vel) 8.8 pairs, two pieces per row.
	# Use its exact source velocities instead of the weak Phase-106 approximation.
	var rows: int = maxi(1, 5 - ((subtype & 0x0E) >> 1))
	for row in range(rows):
		for side in range(2):
			var frag: Sprite2D = make_sprite("res://assets/objects/s2_htz/smash_fragment/%02d.png" % mini(2, row), 3)
			frag.position = Vector2(-8 if side == 0 else 8, -8 - row * 16)
			smash_fragments.append(frag)
			var velocity_index: int = row * 2 + side
			smash_fragment_velocity.append(Vector2(SMASH_DEBRIS_X[velocity_index], SMASH_DEBRIS_Y[velocity_index]))

func _tick_smash_ground() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if state == 1:
		for i in range(smash_fragments.size()):
			var frag: Sprite2D = smash_fragments[i]
			if frag == null or not is_instance_valid(frag):
				continue
			var v: Vector2 = smash_fragment_velocity[i]
			frag.position += v
			v.y += 0.09375 # $18 in 8.8 fixed point
			smash_fragment_velocity[i] = v
		return
	var was_rolling: bool = p.rolling
	var contact: int = p.resolve_solid_box_contact(spawn_x, spawn_y, 0x10, 0x20, true, record_index)
	if contact == SonicPlayer.SOLID_TOP and was_rolling:
		# Retail Obj2F breaks without reversing Sonic's Y velocity. Phase 106's
		# forced -$300 bounce was what kicked Sonic back out around loops.
		p.rolling = true
		p.object_attack_active = true
		p.in_air = true
		p.clear_object_support()
		SonicAudio.play_sfx(SonicAudio.SFX_WALL_SMASH)
		if manager != null:
			manager.mark_record_destroyed(record_index)
		_spawn_smash_debris()
		sprite.visible = false
		state = 1

# -----------------------------------------------------------------------------
# Object $30 - earthquake/rising-lava terrain collision
# -----------------------------------------------------------------------------
func _init_quake_terrain() -> void:
	# Retail Obj30 passes Sonic-centre reaches $CB/$EB into SolidObject_Always.
	# The native resolver already adds Sonic's $0B width, so the authored raw
	# object half-widths are $C0 and (for HTZ2 subtype 6) $E0.
	active_width = 0xE0 if subtype == 6 else 0xC0
	var lava_frame: int = manager.htz_lava_palette_frame if manager != null else 0
	if subtype == 4:
		# HTZ1 rising face reconstructed from its exact Plane-B rectangle.
		sprite = make_sprite("res://assets/objects/s2_htz/quake_lava/%02d.png" % lava_frame, -1)
	elif subtype == 6:
		# HTZ2's damaging lower-route platforms use d1=$EB,d2=$78 and the
		# level event's -$680 BG-X offset. Two authored placements therefore
		# resolve to two exact 448x240 Plane-B source crops.
		var folder: String = "quake_lava_act2_a" if orig_x < 0x1800 else "quake_lava_act2_b"
		sprite = make_sprite("res://assets/objects/s2_htz/%s/%02d.png" % [folder, lava_frame], -1)
	else:
		# Other Obj30 subtypes are collision controllers whose visible face is
		# supplied by the normal level planes.
		visible = false

func _tick_quake_terrain() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	position.y = orig_y + manager.htz_bg_y_offset
	if sprite != null:
		if subtype == 4:
			set_sprite_frame(sprite, "s2_htz/quake_lava", manager.htz_lava_palette_frame & 0x0F)
		elif subtype == 6:
			var folder: String = "quake_lava_act2_a" if orig_x < 0x1800 else "quake_lava_act2_b"
			set_sprite_frame(sprite, "s2_htz/%s" % folder, manager.htz_lava_palette_frame & 0x0F)

	# Exact Obj30 solid dimensions. Subtype 4 is NOT damaging in retail;
	# subtype 6 alone calls Obj30_HurtSupportedPlayers after DropOnFloor.
	var half_w: int = 0xE0 if subtype == 6 else 0xC0
	var half_h: int = 0x78 if subtype == 4 or subtype == 6 else 0x80
	var contact: int = p.resolve_solid_box_contact(orig_x, int(position.y), half_w, half_h, true, record_index)
	if subtype == 6 and contact == SonicPlayer.SOLID_TOP and p.standing_on_object and p.support_record_index == record_index:
		p.apply_hazard_hit(orig_x)

# -----------------------------------------------------------------------------
# Object $31 - invisible lava collision markers
# -----------------------------------------------------------------------------
func _init_lava_marker() -> void:
	visible = false
	active_width = [0x20, 0x40, 0x80, 0][clampi(subtype, 0, 3)]

func _tick_lava_marker() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead or active_width <= 0:
		return
	if absi(p.pixel_x() - spawn_x) <= active_width + p.width_radius and absi(p.pixel_y() - spawn_y) <= 0x20 + p.height_radius:
		p.apply_hazard_hit(spawn_x)

# -----------------------------------------------------------------------------
# Object $92 - Spiker
# -----------------------------------------------------------------------------
func _init_spiker() -> void:
	active_width = 0x10
	sprite = make_sprite("res://assets/objects/s2_htz/spiker/00.png", 2)
	timer = 0x40
	vel_x = 0x80
	if not x_flip:
		vel_x = -vel_x
	sprite.flip_h = vel_x > 0
	spiker_spent = false
	state = 0

func _tick_spiker() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if drill_active:
		drill_y += drill_vy
		drill_sprite.position.y = drill_y
		if absi(p.pixel_x() - int(position.x)) <= 8 + p.width_radius and absi(p.pixel_y() - int(position.y + drill_y)) <= 12 + p.height_radius:
			p.apply_hazard_hit(int(position.x))
		if absi(drill_y) > 0xA0:
			drill_sprite.queue_free()
			drill_active = false

	var dx: int = p.pixel_x() - int(position.x)
	var dy: int = p.pixel_y() - int(position.y)
	var player_in_drill_band: bool = absi(dx) < 0x20 and absi(dy) < 0x80
	if state == 0:
		if player_in_drill_band and not drill_active and not spiker_spent:
			state = 2
			timer = 0x10
		else:
			fixed_x += vel_x
			position.x = fixed_x / 256.0
			set_sprite_frame(sprite, "s2_htz/spiker", (2 if spiker_spent else 0) + (int(frame_counter / 10) & 1))
			timer -= 1
			if timer < 0:
				state = 1
				timer = 0x10
	elif state == 1:
		timer -= 1
		if timer < 0:
			vel_x = -vel_x
			sprite.flip_h = vel_x > 0
			timer = 0x40
			state = 0
	else:
		timer -= 1
		if timer == 8 and not drill_active and not spiker_spent:
			spiker_spent = true
			set_sprite_frame(sprite, "s2_htz/spiker", 2)
			_spawn_spiker_drill()
		if timer < 0:
			state = 0
			timer = 0x40
	_react_badnik(int(position.x), int(position.y), 0x10, 0x12)

func _spawn_spiker_drill() -> void:
	drill_sprite = make_sprite("res://assets/objects/s2_htz/spiker/04.png", 3)
	drill_sprite.flip_v = y_flip
	drill_y = 0.0
	drill_vy = 2.0 if y_flip else -2.0
	drill_active = true

# -----------------------------------------------------------------------------
# Object $95 - Sol
# -----------------------------------------------------------------------------
func _init_sol() -> void:
	active_width = 0x0C
	sprite = make_sprite("res://assets/objects/s2_htz/sol/00.png", 2)
	vel_x = 0x40 if x_flip else -0x40
	sprite.flip_h = x_flip
	sol_orbit_dir = -1 if x_flip else 1
	for i in range(4):
		var fire: Sprite2D = make_sprite("res://assets/objects/s2_htz/sol/03.png", 3)
		sol_fireballs.append(fire)
	_update_sol_fireballs()

func _tick_sol() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	fixed_x += vel_x
	position.x = fixed_x / 256.0
	if not sol_attack_started and absi(p.pixel_x() - int(position.x)) < 0xA0 and absi(p.pixel_y() - int(position.y)) < 0x50:
		sol_attack_started = true
		timer = 0x30
	if sol_attack_started:
		timer -= 1
		set_sprite_frame(sprite, "s2_htz/sol", 1 + ((frame_counter >> 4) & 1))
		if timer <= 0 and not sol_detached:
			sol_detached = true
			sol_detached_x = sol_fireballs[1].position.x
	else:
		set_sprite_frame(sprite, "s2_htz/sol", 0)
	for i in range(sol_angles.size()):
		sol_angles[i] = (sol_angles[i] + sol_orbit_dir) & 0xFF
	_update_sol_fireballs()
	if sol_detached:
		sol_detached_x += 2.0 if x_flip else -2.0
		sol_fireballs[1].position.x = sol_detached_x
	_react_badnik(int(position.x), int(position.y), 8, 8)
	for fire in sol_fireballs:
		var wx: int = int(position.x + fire.position.x)
		var wy: int = int(position.y + fire.position.y)
		if absi(p.pixel_x() - wx) <= 8 + p.width_radius and absi(p.pixel_y() - wy) <= 8 + p.height_radius:
			p.apply_hazard_hit(wx)

func _update_sol_fireballs() -> void:
	for i in range(sol_fireballs.size()):
		if sol_detached and i == 1:
			continue
		var a: int = sol_angles[i] & 0xFF
		sol_fireballs[i].position = Vector2((GenesisMath.cosine(a) * 16) >> 8, (GenesisMath.sine(a) * 16) >> 8)
		set_sprite_frame(sol_fireballs[i], "s2_htz/sol", 3 + (int(frame_counter / 6) & 1))

# -----------------------------------------------------------------------------
# Object $96 - Rexon body/head system (Obj94 alias in retail placement table)
# -----------------------------------------------------------------------------
func _init_rexon() -> void:
	active_width = 0x10
	sprite = make_sprite("res://assets/objects/s2_htz/rexon/02.png", 2)
	timer = 0
	rexon_fire_timer = 0x7F
	rexon_head_destroyed = false
	rexon_phase = 0

func _tick_rexon() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	# Rexon's cup/body remains a SolidObject even after the head is destroyed.
	p.resolve_solid_box_contact(spawn_x, spawn_y, 0x10, 8, true, record_index)
	if not rexon_head_active and not rexon_head_destroyed and absi(p.pixel_x() - spawn_x) < 0x60:
		_create_rexon_head(p.pixel_x() >= spawn_x)
	if rexon_head_active:
		_tick_rexon_links()
		if rexon_head != null and is_instance_valid(rexon_head):
			var hx: int = int(position.x + rexon_head.position.x)
			var hy: int = int(position.y + rexon_head.position.y)
			_react_rexon_head(hx, hy)
	elif rexon_head_destroyed and rexon_links.size() == 5:
		# Continue the source Obj97_DeathDrop motion for surviving neck links.
		_tick_rexon_links()
	if rexon_projectile != null and is_instance_valid(rexon_projectile):
		rexon_projectile_x += 1.0 if x_flip else -1.0
		rexon_projectile.position.x = rexon_projectile_x
		var px: int = int(position.x + rexon_projectile.position.x)
		var py: int = int(position.y + rexon_projectile.position.y)
		if absi(p.pixel_x() - px) <= 8 + p.width_radius and absi(p.pixel_y() - py) <= 8 + p.height_radius:
			p.apply_hazard_hit(px)
		if absi(rexon_projectile_x) > 0xA0:
			rexon_projectile.queue_free()
			rexon_projectile = null

func _create_rexon_head(face_right: bool) -> void:
	rexon_head_active = true
	x_flip = face_right
	rexon_links.clear()
	rexon_segments.clear()
	rexon_link_state.clear()
	rexon_link_timer.clear()
	rexon_link_vx.clear()
	rexon_link_vy.clear()
	rexon_link_fixed_x.clear()
	rexon_link_fixed_y.clear()
	rexon_link_osc_phase.clear()
	rexon_link_osc_dir.clear()
	rexon_link_tick.clear()
	var initial_x: int = 0x28 if face_right else -0x18
	for i in range(5):
		var part: Sprite2D
		if i < 4:
			part = make_sprite("res://assets/objects/s2_htz/rexon/01.png", 3)
			rexon_segments.append(part)
		else:
			part = make_sprite("res://assets/objects/s2_htz/rexon/00.png", 4)
			rexon_head = part
		part.flip_h = face_right
		rexon_links.append(part)
		rexon_link_state.append(0) # Obj97_InitialWait
		rexon_link_timer.append(REXON_WAIT[i])
		rexon_link_vx.append(0)
		rexon_link_vy.append(0)
		rexon_link_fixed_x.append(initial_x << 8)
		rexon_link_fixed_y.append(0x10 << 8)
		rexon_link_osc_phase.append(REXON_NORMAL_PHASE[i])
		rexon_link_osc_dir.append(1)
		rexon_link_tick.append(i)
		part.position = Vector2(initial_x, 0x10)
	rexon_fire_timer = 0x20

func _tick_rexon_links() -> void:
	if rexon_links.size() != 5:
		return
	for i in range(5):
		var part: Sprite2D = rexon_links[i]
		if part == null or not is_instance_valid(part):
			continue
		match rexon_link_state[i]:
			0: # Obj97_InitialWait
				rexon_link_timer[i] -= 1
				if rexon_link_timer[i] < 0:
					rexon_link_state[i] = 1
					rexon_link_vx[i] = -0x120
					rexon_link_vy[i] = -0x200
					rexon_link_timer[i] = REXON_RAISE[i]
			1: # Obj97_RaiseHead
				rexon_link_vx[i] = GenesisMath.s16(rexon_link_vx[i] + 0x10)
				rexon_link_timer[i] -= 1
				if rexon_link_timer[i] < 0:
					rexon_link_state[i] = 2
					rexon_link_vx[i] = 0
					rexon_link_vy[i] = 0
					rexon_link_timer[i] = 0x20
					rexon_link_osc_phase[i] = REXON_NORMAL_PHASE[i]
				else:
					rexon_link_fixed_x[i] += rexon_link_vx[i]
					rexon_link_fixed_y[i] += rexon_link_vy[i]
			2: # Obj97_Normal
				if i == 4:
					rexon_link_timer[i] -= 1
					if rexon_link_timer[i] < 0:
						rexon_link_timer[i] = 0x7F
						_spawn_rexon_projectile()
				rexon_link_tick[i] = (rexon_link_tick[i] + 1) & 0xFF
				if (rexon_link_tick[i] & 3) == 0:
					_rexon_advance_oscillator(i)
					if i < 4:
						_rexon_place_next_link(i)
			3: # Obj97_DeathDrop
				rexon_link_fixed_x[i] += rexon_link_vx[i]
				rexon_link_fixed_y[i] += rexon_link_vy[i]
				rexon_link_vy[i] = GenesisMath.s16(rexon_link_vy[i] + 0x38)
		part.position = Vector2(rexon_link_fixed_x[i] / 256.0, rexon_link_fixed_y[i] / 256.0)

func _rexon_advance_oscillator(i: int) -> void:
	var phase: int = (rexon_link_osc_phase[i] + rexon_link_osc_dir[i]) & 0x7F
	rexon_link_osc_phase[i] = phase
	if phase <= 0x18 or phase >= 0x28:
		rexon_link_osc_dir[i] = -rexon_link_osc_dir[i]

func _rexon_osc_vector(phase: int) -> Vector2i:
	var p: int = phase & 0x7F
	var v: Vector2i = REXON_OSC[p & 0x1F]
	match (p >> 4) & 6:
		2:
			return Vector2i(v.y, -v.x)
		4:
			return Vector2i(-v.x, -v.y)
		6:
			return Vector2i(-v.y, v.x)
	return v

func _rexon_place_next_link(i: int) -> void:
	var v: Vector2i = _rexon_osc_vector(rexon_link_osc_phase[i])
	# Obj97 writes the next child's integer coordinates from this link.
	var next_x: int = (rexon_link_fixed_x[i] >> 8) + v.x
	var next_y: int = (rexon_link_fixed_y[i] >> 8) + v.y
	# Obj97_Oscillate writes the next child's integer x word and only the low
	# byte of its integer y word; it does not clear the child's subpixel bytes.
	# Keeping those fractions is important to the characteristic staggered neck
	# motion after each link's independent raise phase.
	rexon_link_fixed_x[i + 1] = (next_x << 8) | (rexon_link_fixed_x[i + 1] & 0xFF)
	rexon_link_fixed_y[i + 1] = (next_y << 8) | (rexon_link_fixed_y[i + 1] & 0xFF)

func _update_rexon_chain() -> void:
	# Compatibility entry point retained for older callers.
	_tick_rexon_links()

func _react_rexon_head(cx: int, cy: int) -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead or not rexon_head_active:
		return
	if absi(p.pixel_x() - cx) > 8 + p.width_radius or absi(p.pixel_y() - cy) > 12 + p.height_radius:
		return
	if p.invincible_timer > 0 or p.rolling or p.object_attack_active:
		var award: int = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(cx, cy, award)
		if rexon_head != null and is_instance_valid(rexon_head):
			rexon_head.queue_free()
		# Retail keeps the cup/body solid and lets the four Obj97 neck links fall
		# away with their authored horizontal velocities.
		for i in range(mini(4, rexon_links.size())):
			rexon_link_state[i] = 3
			rexon_link_vx[i] = REXON_DEATH_X[i]
			rexon_link_vy[i] = 0
		rexon_head_active = false
		rexon_head_destroyed = true
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(cx)

func _spawn_rexon_projectile() -> void:
	if rexon_projectile != null and is_instance_valid(rexon_projectile):
		return
	rexon_projectile = make_sprite("res://assets/objects/s2_htz/rexon/03.png", 4)
	rexon_projectile_x = rexon_head.position.x + (16 if x_flip else -16)
	rexon_projectile.position = Vector2(rexon_projectile_x, rexon_head.position.y + 4)

# -----------------------------------------------------------------------------
func _react_badnik(cx: int, cy: int, hw: int, hh: int) -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - cx) > hw + p.width_radius or absi(p.pixel_y() - cy) > hh + p.height_radius:
		return
	if p.invincible_timer > 0 or p.rolling or p.object_attack_active:
		var award: int = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(cx, cy, award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(cx)
