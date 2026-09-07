class_name S2OOZBossObject
extends Node2D

# Phase 118: retail Sonic 2 Object $55 - Oil Ocean boss.
# LevEvents_OOZ2 owns the $2880 arena lock / $5A ScreenShift prelude; this node
# translates the 8-hit main vehicle, laser-shooter chain, spike-chain retaliation,
# travelling lasers / propagating floor waves, $B3 defeat timer and the exact
# two-pixel camera release toward $2A20.

const MODE_MAIN := 0
const MODE_SHOOTER := 1
const MODE_SPIKE := 2
const MODE_DEFEATED := 3

const MAIN_SURFACE := 0
const MAIN_WAIT := 1
const MAIN_DIVE_UP := 2
const MAIN_DIVE_DOWN := 3

const SHOOT_RISE := 0
const SHOOT_WAIT := 1
const SHOOT_AIM := 2
const SHOOT_LOWER := 3

const BOSS_X := 0x2940
const MAIN_START_Y := 0x2D0
const MAIN_HOVER_Y := 0x290
const MAIN_BOB_Y := 0x28C
const SHOOT_START_Y := 0x2B0
const SHOOT_TOP_Y := 0x240
const SPIKE_LEFT_X := 0x28C0
const SPIKE_RIGHT_X := 0x29C0
const SPIKE_Y := 0x2A0
const CAMERA_ESCAPE_MAX := 0x2A20
const LASER_TARGETS: Array[int] = [0x238, 0x230, 0x240, 0x25F]
const WAVE_FRAMES: Array[int] = [0x0D,0x11,0x0E,0x12,0x0F,0x13,0x10,0x14,0x14,0x10,0x13,0x0F,0x12,0x0E,0x11,0x0D]

var manager: SonicObjectManager
var alive := true
var mode := MODE_MAIN
var substate := MAIN_SURFACE
var hits := 8
var invulnerable_timer := 0
var hit_face_timer := 0
var cycle_was_hit := false
var visual_tick := 0
var sine_count := 0
var countdown := 0
var shots_remaining := 0
var used_laser_positions := 0
var target_y := SHOOT_TOP_Y
var firing_timer := 0
var flip_x := false
var boss_x_fixed := BOSS_X << 16
var boss_y_fixed := MAIN_START_Y << 16
var vel_y := -0x80
var defeat_started := false
var defeat_flag_set := false

var vehicle_sprite: Sprite2D
var face_sprite: Sprite2D
var attack_head_sprite: Sprite2D
var chain_sprites: Array[Sprite2D] = []
var lasers: Array[Dictionary] = []
var waves: Array[Dictionary] = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(BOSS_X, MAIN_START_Y)
	vehicle_sprite = _make_part(1, 2)
	face_sprite = _make_part(8, 3)
	attack_head_sprite = _make_part(5, 2)
	attack_head_sprite.visible = false
	for _i in range(8):
		var link: Sprite2D = _make_part(7, 1)
		link.visible = false
		chain_sprites.append(link)
	_enter_main()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	if invulnerable_timer > 0:
		invulnerable_timer -= 1
	if hit_face_timer > 0:
		hit_face_timer -= 1
	if firing_timer > 0:
		firing_timer -= 1

	match mode:
		MODE_MAIN: _tick_main()
		MODE_SHOOTER: _tick_shooter()
		MODE_SPIKE: _tick_spike_chain()
		MODE_DEFEATED: _tick_defeated()

	_tick_lasers()
	_tick_waves()
	_update_visuals()
	if mode == MODE_MAIN:
		_check_main_collision()
	elif mode == MODE_SHOOTER or mode == MODE_SPIKE:
		_check_attack_chain_collision()

func _enter_main() -> void:
	mode = MODE_MAIN
	substate = MAIN_SURFACE
	boss_x_fixed = BOSS_X << 16
	boss_y_fixed = MAIN_START_Y << 16
	vel_y = -0x80
	sine_count = 0
	cycle_was_hit = false
	countdown = 0
	var p: SonicPlayer = manager.player if manager != null else null
	flip_x = p != null and p.pixel_x() < 0x293A

func _tick_main() -> void:
	match substate:
		MAIN_SURFACE:
			_move_boss_y()
			sine_count = (sine_count + 4) & 0xFF
			if (boss_y_fixed >> 16) <= MAIN_HOVER_Y:
				boss_y_fixed = MAIN_HOVER_Y << 16
				countdown = 0xA8
				substate = MAIN_WAIT
		MAIN_WAIT:
			sine_count = (sine_count + 4) & 0xFF
			if cycle_was_hit:
				substate = MAIN_DIVE_UP
				vel_y = -0x40
			else:
				countdown -= 1
				if countdown < 0:
					substate = MAIN_DIVE_UP
					vel_y = -0x40
		MAIN_DIVE_UP:
			_move_boss_y()
			if (boss_y_fixed >> 16) <= MAIN_BOB_Y:
				boss_y_fixed = MAIN_BOB_Y << 16
				vel_y = 0x80
				substate = MAIN_DIVE_DOWN
		MAIN_DIVE_DOWN:
			_move_boss_y()
			if (boss_y_fixed >> 16) >= MAIN_START_Y:
				boss_y_fixed = MAIN_START_Y << 16
				if cycle_was_hit:
					_enter_spike_chain()
				else:
					_enter_shooter()

func _main_display_y() -> int:
	var y: int = boss_y_fixed >> 16
	if substate == MAIN_SURFACE or substate == MAIN_WAIT:
		y += GenesisMath.sine(sine_count) >> 7
	return y

func _move_boss_y() -> void:
	boss_y_fixed += GenesisMath.s16(vel_y) << 8

func _enter_shooter() -> void:
	mode = MODE_SHOOTER
	substate = SHOOT_RISE
	boss_x_fixed = BOSS_X << 16
	boss_y_fixed = SHOOT_START_Y << 16
	vel_y = -0x80
	sine_count = 0
	countdown = 0
	shots_remaining = 0
	used_laser_positions = 0
	firing_timer = 0
	_face_shooter_to_player(true)

func _tick_shooter() -> void:
	_face_shooter_to_player(false)
	match substate:
		SHOOT_RISE:
			_move_boss_y()
			if (boss_y_fixed >> 16) <= SHOOT_TOP_Y:
				boss_y_fixed = SHOOT_TOP_Y << 16
				vel_y = 0
				countdown = 0x80
				shots_remaining = 3
				substate = SHOOT_WAIT
		SHOOT_WAIT:
			countdown -= 1
			if countdown == 0:
				shots_remaining -= 1
				if shots_remaining < 0:
					vel_y = 0x80
					substate = SHOOT_LOWER
				else:
					_choose_laser_target()
					substate = SHOOT_AIM
		SHOOT_AIM:
			_move_boss_y()
			var by: int = boss_y_fixed >> 16
			if (vel_y < 0 and by <= target_y) or (vel_y >= 0 and by >= target_y):
				boss_y_fixed = target_y << 16
				vel_y = 0
				_fire_laser()
				countdown = 0x28
				substate = SHOOT_WAIT
		SHOOT_LOWER:
			_move_boss_y()
			if (boss_y_fixed >> 16) >= SHOOT_START_Y:
				boss_y_fixed = SHOOT_START_Y << 16
				vel_y = 0
				_enter_main()
	sine_count = (sine_count + 2) & 0xFF

func _choose_laser_target() -> void:
	var candidate: int = manager.next_random_word() & 3
	for _n in range(4):
		candidate = (candidate + 1) & 3
		if (used_laser_positions & (1 << candidate)) == 0:
			break
	used_laser_positions |= 1 << candidate
	target_y = LASER_TARGETS[candidate]
	vel_y = -0x80 if target_y < (boss_y_fixed >> 16) else 0x80

func _face_shooter_to_player(force: bool) -> void:
	var p: SonicPlayer = manager.player
	if p == null:
		return
	var dx: int = p.pixel_x() - _shooter_head_world_position().x
	if force or dx >= 8:
		flip_x = dx >= 0
	elif dx <= -8:
		flip_x = false

func _fire_laser() -> void:
	firing_timer = 8
	var head: Vector2i = _shooter_head_world_position()
	var vx: int = 0x400 if flip_x else -0x400
	var xoff: int = 0x20 if flip_x else -0x20
	var s: Sprite2D = _make_part(0x0C, 4)
	s.flip_h = flip_x
	lasers.append({"xf": (head.x + xoff) << 16, "y": head.y, "vx": vx, "sprite": s, "wave": false})
	# S2's dedicated LaserBurst/LaserFloor SMPS effects are not yet separate IDs
	# in the Sonic 1 audio adapter; Electric is the closest existing one-shot.
	SonicAudio.play_sfx(SonicAudio.SFX_ELECTRIC)

func _enter_spike_chain() -> void:
	mode = MODE_SPIKE
	substate = 0
	var p: SonicPlayer = manager.player
	if p != null and p.pixel_x() >= 0x293A:
		boss_x_fixed = SPIKE_RIGHT_X << 16
		flip_x = true
	else:
		boss_x_fixed = SPIKE_LEFT_X << 16
		flip_x = false
	boss_y_fixed = SPIKE_Y << 16
	sine_count = 0

func _tick_spike_chain() -> void:
	if sine_count >= 0xFE:
		_enter_shooter()
		return
	sine_count += 1

func _spike_points() -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var phase: int = (sine_count + 0x40) & 0xFF
	for i in range(9):
		var cosv: int = GenesisMath.cosine(phase)
		var sinv: int = GenesisMath.sine(phase)
		var dx: int = (cosv * 0x68) >> 8
		if not flip_x:
			dx = -dx
		pts.append(Vector2i((boss_x_fixed >> 16) + dx, (boss_y_fixed >> 16) + ((sinv * 0x68) >> 8)))
		phase = (phase - 6) & 0xFF
	return pts

func _spike_head_frame() -> int:
	var c: int = sine_count & 0xFF
	if c < 0x52:
		return 0x15
	if c < 0x6B:
		return 3
	if c < 0x92:
		return 2
	return 4

func _shooter_points() -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var base_x: int = boss_x_fixed >> 16
	var base_y: int = boss_y_fixed >> 16
	var phase: int = sine_count & 0xFF
	# Main shooter head.
	pts.append(Vector2i(base_x + (GenesisMath.cosine(phase) >> 4), base_y + (GenesisMath.sine(phase) >> 6)))
	var line_y: int = base_y
	for _i in range(8):
		line_y += 0x0F
		phase = (phase - 0x10) & 0xFF
		pts.append(Vector2i(base_x + (GenesisMath.cosine(phase) >> 4), line_y + (GenesisMath.sine(phase) >> 6)))
	return pts

func _shooter_head_world_position() -> Vector2i:
	if mode != MODE_SHOOTER:
		return Vector2i(boss_x_fixed >> 16, boss_y_fixed >> 16)
	return _shooter_points()[0]

func _tick_lasers() -> void:
	for i in range(lasers.size() - 1, -1, -1):
		var l: Dictionary = lasers[i]
		var s: Sprite2D = l["sprite"] as Sprite2D
		if s == null or not is_instance_valid(s):
			lasers.remove_at(i)
			continue
		var old_x: int = int(l["xf"]) >> 16
		l["xf"] = int(l["xf"]) + (GenesisMath.s16(int(l["vx"])) << 8)
		var x: int = int(l["xf"]) >> 16
		var y: int = int(l["y"])
		if not bool(l["wave"]) and y >= 0x250:
			if int(l["vx"]) > 0 and old_x < 0x2980 and x >= 0x297C:
				_spawn_wave(0x2988, 0x250, 1)
				l["wave"] = true
			elif int(l["vx"]) < 0 and old_x >= 0x2900 and x < 0x2904:
				_spawn_wave(0x28F8, 0x250, -1)
				l["wave"] = true
		s.position = Vector2(x - int(position.x), y - int(position.y))
		_check_hazard(x, y, 0x10, 3)
		lasers[i] = l
		if x < 0x2870 or x >= 0x2A10:
			s.queue_free()
			lasers.remove_at(i)

func _spawn_wave(x: int, y: int, direction: int, count: int = 7) -> void:
	var s: Sprite2D = _make_part(0x0D, 2)
	s.flip_h = direction < 0
	waves.append({"x": x, "y": y, "dir": direction, "count": count, "delay": 5, "anim": 0, "sprite": s, "propagated": false})
	SonicAudio.play_sfx(SonicAudio.SFX_ELECTRIC)

func _tick_waves() -> void:
	var additions: Array[Dictionary] = []
	for i in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		var s: Sprite2D = w["sprite"] as Sprite2D
		if s == null or not is_instance_valid(s):
			waves.remove_at(i)
			continue
		w["delay"] = int(w["delay"]) - 1
		if int(w["delay"]) < 0 and not bool(w["propagated"]):
			w["propagated"] = true
			if int(w["count"]) > 0:
				var ns: Sprite2D = _make_part(0x0D, 2)
				ns.flip_h = int(w["dir"]) < 0
				additions.append({"x": int(w["x"]) + int(w["dir"]) * 0x10, "y": int(w["y"]), "dir": int(w["dir"]), "count": int(w["count"]) - 1, "delay": 5, "anim": 0, "sprite": ns, "propagated": false})
		w["anim"] = int(w["anim"]) + 1
		var ai: int = int(w["anim"]) >> 1
		if ai >= WAVE_FRAMES.size():
			s.queue_free()
			waves.remove_at(i)
			continue
		_set_part_texture(s, WAVE_FRAMES[ai])
		s.position = Vector2(int(w["x"]) - int(position.x), int(w["y"]) - int(position.y))
		_check_hazard(int(w["x"]), int(w["y"]), 8, 0x10)
		waves[i] = w
	for nw in additions:
		waves.append(nw)

func _check_main_collision() -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = boss_x_fixed >> 16
	var by: int = _main_display_y()
	if absi(p.pixel_x() - bx) > 0x18 + p.width_radius or absi(p.pixel_y() - by) > 0x18 + p.height_radius:
		return
	if p.can_attack_object():
		# Boss_HandleHits ignores additional damage during boss_invulnerable_time,
		# but Sonic still rebounds from the solid touch.
		if p.vel_y >= 0:
			p.vel_y = -maxi(0x200, absi(p.vel_y))
		else:
			p.vel_y = GenesisMath.s16(-p.vel_y)
		if invulnerable_timer > 0:
			return
		hits -= 1
		invulnerable_timer = 0x20
		hit_face_timer = 0x20
		cycle_was_hit = true
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			_begin_defeat()
		return
	p.apply_hazard_hit(bx)

func _check_attack_chain_collision() -> void:
	var pts: Array[Vector2i] = _shooter_points() if mode == MODE_SHOOTER else _spike_points()
	for pt in pts:
		_check_hazard(pt.x, pt.y, 8, 8)

func _check_hazard(x: int, y: int, hw: int, hh: int) -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	if absi(p.pixel_x() - x) <= hw + p.width_radius and absi(p.pixel_y() - y) <= hh + p.height_radius:
		p.apply_hazard_hit(x)

func _begin_defeat() -> void:
	if defeat_started:
		return
	defeat_started = true
	mode = MODE_DEFEATED
	countdown = 0xB3
	manager.add_score(1000)
	for l in chain_sprites:
		l.visible = false
	attack_head_sprite.visible = false
	vehicle_sprite.visible = true
	face_sprite.visible = true

func _tick_defeated() -> void:
	countdown -= 1
	if countdown >= 0:
		if countdown >= 0x1E and (visual_tick & 7) == 0:
			var rx: int = (manager.next_random_word() & 0x3F) - 0x20
			var ry: int = ((manager.next_random_word() >> 3) & 0x3F) - 0x20
			manager.spawn_boss_explosion((boss_x_fixed >> 16) + rx, (boss_y_fixed >> 16) + ry)
		return
	if not defeat_flag_set:
		defeat_flag_set = true
		manager.set_boss_defeated()
		SonicAudio.play_music(SonicAudio.MUS_S2_OOZ, true)
	manager.unlock_s2_ooz_boss_right_boundary()
	boss_y_fixed += 1 << 16
	if manager.boss_limit_right >= CAMERA_ESCAPE_MAX and (boss_y_fixed >> 16) >= MAIN_START_Y:
		alive = false
		queue_free()

func _update_visuals() -> void:
	var bx: int = boss_x_fixed >> 16
	var by: int = boss_y_fixed >> 16
	position = Vector2(bx, by)
	if mode == MODE_MAIN:
		vehicle_sprite.visible = true
		face_sprite.visible = true
		attack_head_sprite.visible = false
		for l in chain_sprites:
			l.visible = false
		vehicle_sprite.position = Vector2(0, _main_display_y() - by)
		face_sprite.position = vehicle_sprite.position
		vehicle_sprite.flip_h = flip_x
		face_sprite.flip_h = flip_x
		if hit_face_timer > 0:
			_set_part_texture(face_sprite, 0x0A)
		else:
			_set_part_texture(face_sprite, 8 if int(visual_tick / 10) % 8 < 4 else 9)
	elif mode == MODE_SHOOTER:
		vehicle_sprite.visible = false
		face_sprite.visible = false
		attack_head_sprite.visible = true
		_set_part_texture(attack_head_sprite, 6 if firing_timer > 0 else 5)
		var pts: Array[Vector2i] = _shooter_points()
		attack_head_sprite.position = Vector2(pts[0].x - bx, pts[0].y - by)
		attack_head_sprite.flip_h = flip_x
		for i in range(chain_sprites.size()):
			chain_sprites[i].visible = true
			chain_sprites[i].position = Vector2(pts[i+1].x - bx, pts[i+1].y - by)
	elif mode == MODE_SPIKE:
		vehicle_sprite.visible = false
		face_sprite.visible = false
		attack_head_sprite.visible = true
		_set_part_texture(attack_head_sprite, _spike_head_frame())
		var pts2: Array[Vector2i] = _spike_points()
		attack_head_sprite.position = Vector2(pts2[0].x - bx, pts2[0].y - by)
		attack_head_sprite.flip_h = flip_x
		for i in range(chain_sprites.size()):
			chain_sprites[i].visible = true
			chain_sprites[i].position = Vector2(pts2[i+1].x - bx, pts2[i+1].y - by)
	elif mode == MODE_DEFEATED:
		vehicle_sprite.visible = true
		face_sprite.visible = true
		vehicle_sprite.position = Vector2.ZERO
		face_sprite.position = Vector2.ZERO
		_set_part_texture(vehicle_sprite, 1)
		_set_part_texture(face_sprite, 0x0B if countdown < 0x1E else (0x0A if (visual_tick & 4) == 0 else 8))
		vehicle_sprite.flip_h = flip_x
		face_sprite.flip_h = flip_x
		attack_head_sprite.visible = false
		for l in chain_sprites:
			l.visible = false

func _make_part(frame: int, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.z_index = z
	add_child(s)
	_set_part_texture(s, frame)
	return s

func _set_part_texture(s: Sprite2D, frame: int) -> void:
	if s == null:
		return
	var path: String = "res://assets/objects/s2_ooz/boss/parts/%02d.png" % frame
	if ResourceLoader.exists(path):
		s.texture = load(path)
