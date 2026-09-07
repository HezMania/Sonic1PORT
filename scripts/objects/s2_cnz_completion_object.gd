class_name S2CNZCompletionObject
extends GenesisLevelObject

# Phase 101: remaining retail Casino Night Act 1 object families.
# Object IDs: $C8 Crawl, $D2 rectangular flashing blocks, $D6 Point Pokey /
# slot-machine cage, and $D8 three-hit bonus/drop targets.

var sprite: Sprite2D
var state: int = 0
var timer: int = 0
var frame_timer: int = 0
var cooldown: int = 0
var vel_x: int = 0
var hit_count: int = 0
var captured: bool = false
var reward_applied: bool = false
var rect_frame: int = 0
var rect_half_width: int = 8
var rect_half_height: int = 8
var slot_faces: Array[int] = [0, 0, 0]
var resume_state: int = 0

const RECT_DATA: Array[Vector4i] = [
	Vector4i(-40, 24, 8, 8), Vector4i(-40, 16, 8, 16),
	Vector4i(-40, 8, 8, 24), Vector4i(-40, 0, 8, 32),
	Vector4i(-32, 0, 16, 32), Vector4i(-24, -8, 24, 24),
	Vector4i(-16, -16, 32, 16), Vector4i(-8, -24, 40, 8),
	Vector4i(8, -24, 40, 8), Vector4i(16, -16, 32, 16),
	Vector4i(24, -8, 24, 24), Vector4i(32, 0, 16, 32),
	Vector4i(40, 0, 8, 32), Vector4i(40, 8, 8, 24),
	Vector4i(40, 16, 8, 16), Vector4i(40, 24, 8, 8),
]

const SLOT_REWARDS: Array[int] = [30, 25, -1, 150, 10, 20]
const SLOT_SEQ_1: Array[int] = [3, 0, 1, 4, 2, 5, 4, 1]
const SLOT_SEQ_2: Array[int] = [3, 0, 1, 4, 2, 5, 0, 2]
const SLOT_SEQ_3: Array[int] = [3, 0, 1, 4, 2, 5, 4, 1]

func initialize_object() -> void:
	match object_id:
		0xC8:
			_init_crawl()
		0xD2:
			_init_rect_blocks()
		0xD6:
			_init_point_pokey()
		0xD8:
			_init_bonus_block()

func tick() -> void:
	if cooldown > 0:
		cooldown -= 1
	match object_id:
		0xC8:
			_tick_crawl()
		0xD2:
			_tick_rect_blocks()
		0xD6:
			_tick_point_pokey()
		0xD8:
			_tick_bonus_block()

func suppress_central_despawn() -> bool:
	# Do not let ObjPosLoad unload a D6 cage while it owns Sonic's obj_control.
	return object_id == 0xD6 and captured

# ---------------------------------------------------------------------------
# Object $C8 - Crawl / shield badnik
# ---------------------------------------------------------------------------

func _init_crawl() -> void:
	active_width = 0x10
	sprite = make_sprite("res://assets/objects/s2_cnz/crawl/00.png", 2)
	# ObjC8_Init uses +/-$20 8.8 speed for $200 frames.
	vel_x = 0x20 if x_flip else -0x20
	timer = 0x200
	state = 0

func _tick_crawl() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		return

	# loc_3D416: switch into the shield/defence routine while the player is
	# within a $40 x $40 box. Resume the saved walk/wait routine after leaving.
	var near_player: bool = absi(p.pixel_x() - int(position.x)) < 0x40 and absi(p.pixel_y() - int(position.y)) < 0x40
	if near_player and state != 2:
		resume_state = state
		state = 2
	elif not near_player and state == 2:
		state = resume_state

	if state == 0:
		position.x += float(vel_x) / 256.0
		timer -= 1
		if timer <= 0:
			state = 1
			timer = 0x3B
	elif state == 1:
		timer -= 1
		if timer < 0:
			state = 0
			timer = 0x200
			vel_x = -vel_x
			x_flip = not x_flip
			sprite.flip_h = x_flip

	# $13 delay, frames 0/1 while walking. Defence remains on the shield frame.
	if state == 2:
		if frame_timer > 0:
			frame_timer -= 1
			set_sprite_frame(sprite, "s2_cnz/crawl", 2 if p.vel_y >= 0 else 3)
		else:
			set_sprite_frame(sprite, "s2_cnz/crawl", 0)
	else:
		set_sprite_frame(sprite, "s2_cnz/crawl", int(Engine.get_physics_frames() / 20) & 1)
	_react_crawl_to_player(p)

func _react_crawl_to_player(p: SonicPlayer) -> void:
	if cooldown > 0:
		return
	var dx: int = p.pixel_x() - int(position.x)
	var dy: int = p.pixel_y() - int(position.y)
	if absi(dx) > 0x10 + p.width_radius or absi(dy) > 0x0F + p.height_radius:
		return

	if p.invincible_timer > 0:
		_destroy_crawl(p)
		return

	if p.rolling:
		# The shield is on Crawl's travelling/facing side. Retail rejects a roll
		# attack from that side with a fixed -$700 bumper impulse, but permits the
		# vulnerable rear hit to destroy the badnik.
		var front_hit: bool = (vel_x < 0 and dx < 0) or (vel_x > 0 and dx > 0)
		if state == 2 and front_hit:
			var angle_byte: int = (GenesisMath.calc_angle(-dx, -dy) + (Engine.get_physics_frames() & 3)) & 0xFF
			p.vel_x = GenesisMath.s16((GenesisMath.cosine(angle_byte) * -0x700) >> 8)
			p.vel_y = GenesisMath.s16((GenesisMath.sine(angle_byte) * -0x700) >> 8)
			p.in_air = true
			p.jumping = false
			p.clear_object_support()
			frame_timer = 8
			cooldown = 8
			SonicAudio.play_sfx(SonicAudio.SFX_BUMPER)
			return
		_destroy_crawl(p)
		return

	p.apply_hazard_hit(int(position.x))
	cooldown = 12

func _destroy_crawl(p: SonicPlayer) -> void:
	var award: int = manager.register_badnik_hit()
	manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
	request_delete(respawn_enabled)
	if p.vel_y >= 0:
		p.vel_y = -p.vel_y
	else:
		p.vel_y = GenesisMath.s16(p.vel_y + 0x100)

# ---------------------------------------------------------------------------
# Object $D2 - rectangular appearing/disappearing blocks
# ---------------------------------------------------------------------------

func _init_rect_blocks() -> void:
	active_width = 0x40
	sprite = make_sprite("res://assets/objects/s2_cnz/rect_blocks/00.png", 1)
	timer = (subtype & 0xFF) << 4
	frame_timer = 0x0F
	rect_frame = 0
	visible = timer == 0
	_apply_rect_frame()

func _tick_rect_blocks() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if timer > 0:
		timer -= 1
		visible = false
		p.clear_object_support_for(record_index, timer == 0)
		return

	visible = true
	frame_timer -= 1
	if frame_timer < 0:
		frame_timer = 0x0F
		rect_frame = (rect_frame + 1) & 0x0F
		if rect_frame == 0:
			# The source inserts subtype*16 blank frames between complete cycles and
			# explicitly ejects a player who was standing on the disappearing block.
			timer = (subtype & 0xFF) << 4
			visible = timer == 0
			p.clear_object_support_for(record_index, true)
			position = Vector2(spawn_x, spawn_y)
			return
		_apply_rect_frame()

	var contact: int = p.resolve_solid_box_contact(int(position.x), int(position.y), rect_half_width + 0x0B, rect_half_height + 1, true, record_index)
	if contact == SonicPlayer.SOLID_TOP:
		p.support_refreshed_this_pass = true

func _apply_rect_frame() -> void:
	var d: Vector4i = RECT_DATA[rect_frame]
	var dx: int = d.x
	if x_flip:
		dx = -dx
	position = Vector2(spawn_x + dx, spawn_y + d.y)
	rect_half_width = d.z
	rect_half_height = d.w
	set_sprite_frame(sprite, "s2_cnz/rect_blocks", rect_frame)

# ---------------------------------------------------------------------------
# Object $D6 - Point Pokey / slot-machine cage
# ---------------------------------------------------------------------------

func _init_point_pokey() -> void:
	active_width = 0x23
	# ObjD6 uses source priority 1 while Sonic uses priority 2, so the cage is
	# queued in front of the player. The native object parent is z=40 and Sonic
	# is normally z=50; this child offset reproduces that front-layer result.
	sprite = make_sprite("res://assets/objects/s2_cnz/point_pokey/00.png", 20)
	state = 0
	timer = 0

func _tick_point_pokey() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		_release_pokey_player(p, false)
		return

	if state == 0:
		set_sprite_frame(sprite, "s2_cnz/point_pokey", 0)
		if p.object_control_override:
			return
		if subtype != 0 and manager.cnz_slot_machine_in_use:
			return
		var contact: int = p.resolve_solid_box_contact(spawn_x, spawn_y, 0x23, 0x11, true, record_index)
		if contact == SonicPlayer.SOLID_TOP:
			_capture_pokey_player(p)
		return

	if state == 1:
		# ObjD6 pins the character to the cage centre while obj_control is set.
		p.force_set_pixel_position(spawn_x, spawn_y)
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		set_sprite_frame(sprite, "s2_cnz/point_pokey", 1 if ((Engine.get_physics_frames() >> 1) & 1) == 1 else 0)
		timer -= 1
		if subtype == 0:
			if timer >= 0 and (timer & 0x0F) == 0:
				manager.add_score(10)
			if timer < 0:
				_release_pokey_player(p, true)
		else:
			if timer == 0 and not reward_applied:
				_apply_slot_reward()
				reward_applied = true
				timer = 0x30
			elif reward_applied and timer < 0:
				_release_pokey_player(p, true)
		return

	# Retail waits $1E after ejecting before the cage becomes capturable again.
	timer -= 1
	if timer < 0:
		state = 0
		reward_applied = false

func _capture_pokey_player(p: SonicPlayer) -> void:
	state = 1
	captured = true
	reward_applied = false
	p.object_control_override = true
	p.clear_object_support()
	p.force_set_pixel_position(spawn_x, spawn_y)
	p.vel_x = 0
	p.vel_y = 0
	p.inertia = 0
	p.in_air = false
	p.rolling = true
	p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
	p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH
	set_sprite_frame(sprite, "s2_cnz/point_pokey", 1)
	if subtype == 0:
		timer = 0x78
	else:
		manager.cnz_slot_machine_in_use = true
		timer = 0x90
		_roll_slot_faces()

func _release_pokey_player(p: SonicPlayer, eject: bool) -> void:
	if captured and p != null:
		p.object_control_override = false
		p.clear_object_support()
		if eject and not p.dead:
			p.in_air = true
			p.vel_y = 0x400
	captured = false
	if subtype != 0:
		manager.cnz_slot_machine_in_use = false
	if state == 1:
		state = 2
		timer = 0x1E

func _roll_slot_faces() -> void:
	# The retail reel sequences are retained; use the manager's deterministic
	# level RNG to pick a sequence index for each reel. Rendering the rotating
	# VRAM strip is outside the object sprite, but the resulting gameplay reward
	# follows SlotMachine_ChooseReward.
	var r: int = manager.next_random_word()
	slot_faces[0] = SLOT_SEQ_1[r & 7]
	slot_faces[1] = SLOT_SEQ_2[(r >> 3) & 7]
	slot_faces[2] = SLOT_SEQ_3[(r >> 6) & 7]

func _apply_slot_reward() -> void:
	var a: int = slot_faces[0]
	var b: int = slot_faces[1]
	var c: int = slot_faces[2]
	var reward: int = 0
	if a == b and a == c:
		reward = SLOT_REWARDS[a]
	elif a == b:
		if b == 3:
			reward = SLOT_REWARDS[c] * 4
		elif c == 3:
			reward = SLOT_REWARDS[b] * 2
	elif a == c:
		if c == 3:
			reward = SLOT_REWARDS[b] * 4
		elif b == 3:
			reward = SLOT_REWARDS[c] * 2
	elif b == c:
		if a == 3:
			reward = SLOT_REWARDS[b] * 2
		elif b == 3:
			reward = SLOT_REWARDS[a] * 4

	if reward == 0:
		# Any non-jackpot unmatched result falls through to the source bar check.
		if a == 5:
			reward += 2
		if b == 5:
			reward += 2
		if c == 5:
			reward += 2

	if reward < 0:
		# Sonic-head/bomb loss result. Retail emits delayed bomb-prize objects
		# that remove rings individually; apply the same capped ring loss directly.
		manager.add_rings(-mini(manager.rings, 10))
	else:
		manager.add_rings(reward)

# ---------------------------------------------------------------------------
# Object $D8 - three-hit bonus/drop target
# ---------------------------------------------------------------------------

func _init_bonus_block() -> void:
	active_width = 0x10
	var rest: int = _bonus_rest_frame()
	sprite = make_sprite("res://assets/objects/s2_cnz/bonus_block_p2/%02d.png" % rest, 2)
	hit_count = 0
	state = 0

func _bonus_rest_frame() -> int:
	return (subtype >> 6) & 3

func _bonus_palette_folder() -> String:
	# Retail ObjD8 starts on palette line 2. Each successful hit executes
	# `subi.w #palette_line_1,art_tile(a0)`: green -> yellow -> red. The
	# third subtraction underflows, leaves palette line 0, and destroys it.
	var palette_line: int = maxi(0, 2 - mini(hit_count, 2))
	return "s2_cnz/bonus_block_p%d" % palette_line

func _tick_bonus_block() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		return
	var rest: int = _bonus_rest_frame()
	var bonus_folder: String = _bonus_palette_folder()
	if frame_timer > 0:
		frame_timer -= 1
		var phase: int = (frame_timer >> 2) & 1
		set_sprite_frame(sprite, bonus_folder, rest + 3 if phase == 1 else rest)
		if frame_timer == 0 and state == 1:
			request_delete(respawn_enabled)
			return
	else:
		set_sprite_frame(sprite, bonus_folder, rest)

	if cooldown > 0 or state == 1:
		return
	var dx: int = p.pixel_x() - int(position.x)
	var dy: int = p.pixel_y() - int(position.y)
	# collision_flags=$D7 -> Touch_Sizes index $17 -> 8x8 object half-size.
	if absi(dx) > 8 + p.width_radius or absi(dy) > 8 + p.height_radius:
		return
	_bonus_rebound(p, rest, dx, dy)
	cooldown = 4
	frame_timer = 12
	hit_count += 1
	var group: int = subtype & 0x3F
	var points: int = 10
	if hit_count >= 3:
		state = 1
		var broken: int = int(manager.cnz_saucer_break_count.get(group, 0)) + 1
		manager.cnz_saucer_break_count[group] = broken
		if broken >= 3:
			points = 50
	manager.add_score(points)
	SonicAudio.play_sfx(SonicAudio.SFX_BUMPER)

func _bonus_rebound(p: SonicPlayer, rest: int, dx: int, dy: int) -> void:
	if rest == 0 or rest == 3:
		p.vel_y = -0x700 if dy <= 0 else 0x700
	elif rest == 1:
		# loc_2C77A mirrors the incoming angle around $60 (normal) or $20
		# (x-flipped), with a small clamp near the cardinal boundaries.
		var d3: int = 0x20 if x_flip else 0x60
		var incoming: int = GenesisMath.calc_angle(p.vel_x, p.vel_y) & 0xFF
		var d0: int = (incoming - d3) & 0xFF
		var d1: int = absi(GenesisMath.s8(d0))
		d0 = (-GenesisMath.s8(d0) + d3) & 0xFF
		if d1 < 0x40:
			if d1 >= 0x38:
				d0 = d3
		else:
			var wrapped: int = absi(GenesisMath.s8((d1 - 0x80) & 0xFF))
			if wrapped >= 0x38:
				d0 = (d3 + 0x80) & 0xFF
		p.vel_x = GenesisMath.s16((GenesisMath.cosine(d0) * -0x700) >> 8)
		p.vel_y = GenesisMath.s16((GenesisMath.sine(d0) * -0x700) >> 8)
	else:
		p.vel_x = -0x700 if dx <= 0 else 0x700
	p.in_air = true
	p.jumping = false
	p.clear_object_support()
