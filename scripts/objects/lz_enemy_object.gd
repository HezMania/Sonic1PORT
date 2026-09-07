class_name LZEnemyObject
extends GenesisLevelObject

# Phase 31 source-driven Labyrinth object family:
#   $16 Harpoon
#   $2C Jaws
#   $2D Burrobot
# Positions/speeds/timers remain in Sonic 1's integer / 8.8 conventions.

var sprite: Sprite2D
var frame_tick := 0

# Shared enemy movement state.
var vel_x := 0
var vel_y := 0
var direction := -1 # -1 = source/default left, +1 = horizontally flipped/right

# Harpoon ($16).
var harp_state := 0 # 0 animating, 1 waiting
var harp_anim := 0
var harp_anim_index := -1
var harp_anim_timer := 0
var harp_wait_timer := 60
var harp_frame := 0

# Jaws ($2C).
var jaws_turn_timer := 0
var jaws_turn_base := 0
var jaws_anim_index := 0
var jaws_anim_timer := 0

# Burrobot ($2D).
var burro_state := 3 # 0 turn, 1 move, 2 jump, 3 check Sonic
var burro_timer := 0
var burro_check_toggle := false
var burro_anim := 2
var burro_anim_last := -1
var burro_anim_index := 0
var burro_anim_timer := 0

func initialize_object() -> void:
	match object_id:
		0x16:
			_init_harpoon()
		0x2C:
			_init_jaws()
		0x2D:
			_init_burrobot()
		_:
			request_delete(false)

func tick() -> void:
	if not alive:
		return
	frame_tick += 1
	match object_id:
		0x16:
			_tick_harpoon()
		0x2C:
			_tick_jaws()
		0x2D:
			_tick_burrobot()

# -----------------------------------------------------------------------------
# Object $16 - LZ Harpoon
# -----------------------------------------------------------------------------
func _init_harpoon() -> void:
	active_width = 20
	sprite = make_sprite("")
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip
	harp_anim = subtype & 3
	harp_wait_timer = 60
	harp_state = 0
	harp_anim_index = 0
	harp_anim_timer = 3
	# Harp_Main falls directly into AnimateSprite; the first visible source frame
	# is the middle extension frame (1 horizontal / 4 vertical).
	_set_harpoon_frame(1 if harp_anim < 2 else 4)

func _tick_harpoon() -> void:
	if harp_state == 0:
		_tick_harpoon_animation()
	else:
		harp_wait_timer -= 1
		if harp_wait_timer < 0:
			harp_wait_timer = 60
			harp_state = 0
			harp_anim ^= 1
			harp_anim_index = -1
	_react_harpoon()

func _tick_harpoon_animation() -> void:
	var sequence: Array[int] = []
	match harp_anim:
		0:
			sequence = [1, 2]
		1:
			sequence = [1, 0]
		2:
			sequence = [4, 5]
		_:
			sequence = [4, 3]

	if harp_anim_index < 0:
		harp_anim_index = 0
		harp_anim_timer = 3
		_set_harpoon_frame(sequence[0])
		return

	harp_anim_timer -= 1
	if harp_anim_timer >= 0:
		return
	harp_anim_timer = 3
	harp_anim_index += 1
	if harp_anim_index >= sequence.size():
		harp_state = 1
		harp_anim_index = -1
		return
	_set_harpoon_frame(sequence[harp_anim_index])

func _set_harpoon_frame(frame: int) -> void:
	harp_frame = clampi(frame, 0, 5)
	sprite.texture = SourceObjectArt.lz_harpoon_texture(harp_frame)

func _react_harpoon() -> void:
	var p = player()
	if p == null or p.dead or p.drowning:
		return
	# React_Sizes stores half-extents for col_16/48/80x8 and the vertical forms.
	var half_w = 4
	var half_h = 4
	match harp_frame:
		0:
			half_w = 8
			half_h = 4
		1:
			half_w = 24
			half_h = 4
		2:
			half_w = 40
			half_h = 4
		3:
			half_w = 4
			half_h = 8
		4:
			half_w = 4
			half_h = 24
		5:
			half_w = 4
			half_h = 40
	if _source_react_overlap(p, half_w, half_h):
		p.apply_hazard_hit(int(position.x))

# -----------------------------------------------------------------------------
# Object $2C - Jaws
# -----------------------------------------------------------------------------
func _init_jaws() -> void:
	active_width = 24 # REV01 FixBugs value: 48/2
	sprite = make_sprite("")
	direction = 1 if x_flip else -1
	vel_x = direction * 0x40
	jaws_turn_base = (subtype << 6) - 1
	jaws_turn_timer = jaws_turn_base
	jaws_anim_index = 0
	jaws_anim_timer = 0
	_set_jaws_frame(0)
	_update_facing()

func _tick_jaws() -> void:
	jaws_turn_timer -= 1
	if jaws_turn_timer < 0:
		jaws_turn_timer = jaws_turn_base
		vel_x = -vel_x
		direction = -direction
		jaws_anim_index = 0
		jaws_anim_timer = 0
		_update_facing()

	_tick_jaws_animation()
	position.x += float(vel_x) / 256.0
	_react_badnik(16, 12)

func _tick_jaws_animation() -> void:
	var sequence: Array[int] = [0, 1, 2, 3]
	jaws_anim_timer -= 1
	if jaws_anim_timer >= 0:
		return
	jaws_anim_timer = 7
	_set_jaws_frame(sequence[jaws_anim_index])
	jaws_anim_index = (jaws_anim_index + 1) % sequence.size()

func _set_jaws_frame(frame: int) -> void:
	sprite.texture = SourceObjectArt.lz_jaws_texture(frame)

# -----------------------------------------------------------------------------
# Object $2D - Burrobot
# -----------------------------------------------------------------------------
func _init_burrobot() -> void:
	active_width = 12
	sprite = make_sprite("")
	direction = 1 if x_flip else -1
	burro_state = 3
	burro_anim = 2
	burro_anim_last = -1
	burro_timer = 0
	vel_x = 0
	vel_y = 0
	_update_facing()
	_tick_burro_animation()

func _tick_burrobot() -> void:
	match burro_state:
		0:
			_burro_turn_around()
		1:
			_burro_move()
		2:
			_burro_jump()
		_:
			_burro_check_sonic()
	_tick_burro_animation()
	_react_badnik(12, 18)

func _burro_turn_around() -> void:
	burro_timer -= 1
	if burro_timer >= 0:
		return
	burro_state = 1
	burro_timer = 255
	burro_anim = 1
	direction = -direction
	vel_x = direction * 0x80
	_update_facing()

func _burro_move() -> void:
	burro_timer -= 1
	if burro_timer < 0:
		_burro_move_next_action()
		return

	position.x += float(vel_x) / 256.0
	var old_toggle = burro_check_toggle
	burro_check_toggle = not burro_check_toggle
	# BCHG branches to floor alignment when the bit was previously set. The first
	# movement frame therefore checks the ledge ahead, the next aligns to floor.
	if old_toggle:
		_burro_align_to_floor()
		return

	var ahead_x = int(position.x) + (12 if direction > 0 else -12)
	var hit = manager.collision.find_floor(ahead_x, int(position.y) + 19, 13, 16, 0, false)
	if int(hit.get("distance", 0)) >= 12:
		_burro_move_next_action()

func _burro_align_to_floor() -> void:
	var hit = manager.collision.find_floor(int(position.x), int(position.y) + 19, 13, 16, 0, false)
	position.y += int(hit.get("distance", 0))

func _burro_move_next_action() -> void:
	# Source uses bit 2 of v_vblank_byte: clear -> jump again, set -> stop and turn.
	if (frame_tick & 4) == 0:
		burro_state = 2
		vel_y = -0x400
		burro_anim = 2
		return
	burro_state = 0
	burro_timer = 59
	vel_x = 0
	burro_anim = 0

func _burro_jump() -> void:
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + 0x18)
	if vel_y < 0:
		return
	burro_anim = 3
	var hit = manager.collision.find_floor(int(position.x), int(position.y) + 19, 13, 16, 0, false)
	var distance = int(hit.get("distance", 0))
	if distance >= 0:
		return
	position.y += distance
	vel_y = 0
	burro_anim = 1
	burro_timer = 255
	burro_state = 1
	_burro_face_sonic()

func _burro_check_sonic() -> void:
	var p = player()
	if p == null or p.dead or p.debug_free_mode:
		return
	_burro_face_sonic()
	var dx = absi(p.pixel_x() - int(position.x))
	if dx >= 96:
		return
	var dy = p.pixel_y() - int(position.y)
	if dy >= 0 or dy < -128:
		return
	burro_state = 2
	vel_x = direction * 0x80
	vel_y = -0x400
	burro_anim = 2

func _burro_face_sonic() -> void:
	var p = player()
	if p == null:
		return
	direction = 1 if p.pixel_x() >= int(position.x) else -1
	_update_facing()

func _tick_burro_animation() -> void:
	if burro_anim != burro_anim_last:
		burro_anim_last = burro_anim
		burro_anim_index = 0
		burro_anim_timer = 0

	var sequence: Array[int] = []
	match burro_anim:
		0:
			sequence = [0, 6]
		1:
			sequence = [0, 1]
		2:
			sequence = [2, 3]
		_:
			sequence = [4]

	burro_anim_timer -= 1
	if burro_anim_timer >= 0:
		return
	burro_anim_timer = 3
	sprite.texture = SourceObjectArt.lz_burrobot_texture(sequence[burro_anim_index])
	burro_anim_index = (burro_anim_index + 1) % sequence.size()

# -----------------------------------------------------------------------------
# Shared source-style object collision helpers
# -----------------------------------------------------------------------------
func _update_facing() -> void:
	if sprite != null:
		sprite.flip_h = direction > 0

func _source_react_overlap(p: SonicPlayer, object_half_w: int, object_half_h: int) -> bool:
	# Sonic 1 ReactToItem always uses an 8px horizontal reaction radius and the
	# current vertical radius minus three pixels.
	var sonic_half_w = 8
	var sonic_half_h = maxi(1, p.height_radius - 3)
	return (
		absi(p.pixel_x() - int(position.x)) <= object_half_w + sonic_half_w
		and absi(p.pixel_y() - int(position.y)) <= object_half_h + sonic_half_h
	)

func _react_badnik(half_w: int, half_h: int) -> void:
	var p = player()
	if p == null or p.dead or p.drowning:
		return
	if not _source_react_overlap(p, half_w, half_h):
		return
	if p.invincible_timer > 0 or p.can_attack_object():
		var award = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(int(position.x))
