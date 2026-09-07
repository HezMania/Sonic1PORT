class_name S2CNZBossObject
extends Node2D

# Retail Sonic 2 Object $51 - Casino Night boss.
# This native translation preserves the source arena coordinates, $180 patrol
# speed, proximity-triggered drop/dive attacks, 8-hit health, $B3 explosion
# countdown, post-defeat bob, and the two-pixel/frame camera release to $2B20.

const STATE_PATROL := 0
const STATE_DROP_WAIT := 1
const STATE_DIVE := 2
const STATE_EXPLODING := 3
const STATE_ESCAPE_BOB := 4
const STATE_ESCAPE_RIGHT := 5

const START_X := 0x2A46
const START_Y := 0x654
const LEFT_X := 0x28C0
const RIGHT_X := 0x29C0
const DIVE_BOTTOM_Y := 0x680
const CAMERA_ESCAPE_MAX := 0x2B20

var manager: SonicObjectManager
var alive: bool = true
var state: int = STATE_PATROL
var x_fixed: int = START_X << 16
var y_fixed: int = START_Y << 16
var vel_x: int = -0x180
var vel_y: int = 0
var facing_right: bool = false
var hits: int = 8
var invincibility_timer: int = 0
var hover_phase: int = 0
var fight_counter: int = 1
var drop_attacks: int = 0
var patrol_leg: int = 0 # 0 = initial/leftward leg, 1 = rightward leg
var attack_cooldown: int = 0
var countdown: int = 0
var dive_reversing: bool = false
var defeated: bool = false
var visual_tick: int = 0
var random_seed: int = 0x51C02026
var electric_active: bool = false
var hazards: Array[Dictionary] = []

var main_sprite: Sprite2D
var left_claw_sprite: Sprite2D
var eggman_sprite: Sprite2D
var right_claw_sprite: Sprite2D
var electric_sprite: Sprite2D

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(START_X, START_Y)
	# Retail Obj51 is a four-child multi-sprite: pod frame 1, left claw frame 5,
	# Eggman frame 6, right claw frame 2. Phase 104 rendered only the pod, which
	# made Eggman and both claw assemblies invisible even though their mapping
	# frames had been reconstructed correctly. All mapping PNGs share the same
	# 192x192 source origin, so these children overlay at local (0,0).
	main_sprite = _make_sprite(0)
	left_claw_sprite = _make_sprite(1)
	eggman_sprite = _make_sprite(2)
	right_claw_sprite = _make_sprite(1)
	electric_sprite = _make_sprite(3)
	main_sprite.texture = load("res://assets/objects/s2_cnz/boss/01.png")
	left_claw_sprite.texture = load("res://assets/objects/s2_cnz/boss/05.png")
	eggman_sprite.texture = load("res://assets/objects/s2_cnz/boss/06.png")
	right_claw_sprite.texture = load("res://assets/objects/s2_cnz/boss/02.png")
	electric_sprite.visible = false
	_update_visuals()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	hover_phase = (hover_phase + 2) & 0xFF
	if invincibility_timer > 0:
		invincibility_timer -= 1
	if attack_cooldown > 0:
		attack_cooldown -= 1

	match state:
		STATE_PATROL:
			_tick_patrol()
		STATE_DROP_WAIT:
			_tick_drop_wait()
		STATE_DIVE:
			_tick_dive()
		STATE_EXPLODING:
			_tick_exploding()
		STATE_ESCAPE_BOB:
			_tick_escape_bob()
		STATE_ESCAPE_RIGHT:
			_tick_escape_right()

	_tick_hazards()
	position = Vector2(x_fixed >> 16, _display_y())
	_update_visuals()
	if state < STATE_EXPLODING:
		_check_boss_collision()
		_check_electric_collision()

func _tick_patrol() -> void:
	_move_base()
	var px: int = x_fixed >> 16
	# Obj51 starts at $2A46 moving left. The 68000 checks ONLY the destination
	# bound for the current patrol leg (objoff_38), then toggles that leg. Phase
	# 104 checked both bounds every frame; because the authored spawn is already
	# right of $29C0, it snapped the boss straight into the arena and allowed an
	# attack immediately. Preserve the source's one-sided boundary test.
	if patrol_leg == 0:
		if px <= LEFT_X:
			x_fixed = LEFT_X << 16
			vel_x = 0x180
			facing_right = true
			patrol_leg = 1
			drop_attacks = 0
	else:
		if px >= RIGHT_X:
			x_fixed = RIGHT_X << 16
			vel_x = -0x180
			facing_right = false
			patrol_leg = 0
			drop_attacks = 0

	# loc_31B46: every $40 ticks the source swaps between its two electric
	# collision/animation groups. Both are live zap phases; the mapping bank
	# supplies six authored electric-line frames ($C-$11).
	fight_counter = (fight_counter + 1) & 0xFFFF
	if (fight_counter & 0x3F) == 0:
		electric_active = true

	var p: SonicPlayer = manager.player
	if p == null or p.dead or attack_cooldown > 0:
		return
	var dx: int = p.pixel_x() - (x_fixed >> 16) + 0x10
	if dx < 0 or dx >= 0x20:
		return
	if p.pixel_y() >= 0x6B0 and drop_attacks < 3:
		drop_attacks += 1
		vel_x = 0
		countdown = 0x50
		electric_active = false
		_spawn_attached_hazard()
		state = STATE_DROP_WAIT
	elif p.pixel_y() >= 0x67C:
		vel_x = 0
		vel_y = 0x180
		dive_reversing = false
		electric_active = true
		state = STATE_DIVE

func _tick_drop_wait() -> void:
	countdown -= 1
	if countdown == 0:
		_release_attached_hazards()
	if countdown > -0x14:
		return
	countdown = -1
	attack_cooldown = 0x40
	vel_x = 0x180 if facing_right else -0x180
	state = STATE_PATROL

func _tick_dive() -> void:
	_move_base()
	var py: int = y_fixed >> 16
	if not dive_reversing:
		if py < DIVE_BOTTOM_Y:
			return
		y_fixed = DIVE_BOTTOM_Y << 16
		vel_y = -0x180
		dive_reversing = true
		return
	if py >= START_Y:
		return
	y_fixed = START_Y << 16
	vel_y = 0
	vel_x = 0x180 if facing_right else -0x180
	electric_active = true
	state = STATE_PATROL

func _tick_exploding() -> void:
	if (visual_tick & 7) == 0:
		var off: Vector2i = _random_explosion_offset()
		manager.spawn_boss_explosion((x_fixed >> 16) + off.x, _display_y() + off.y)
	countdown -= 1
	if countdown >= 0:
		return
	# loc_31D7E restores Level_Layout+$C54 from the temporary $F9 boss-wall
	# chunk to $DD before Eggman begins the escape bob. This opens the route to
	# the Egg Prison; Phase 104 omitted the layout write and left the wall shut.
	manager.open_s2_cnz_boss_exit_wall()
	vel_x = 0
	vel_y = 0
	countdown = -0x12
	facing_right = true
	state = STATE_ESCAPE_BOB

func _tick_escape_bob() -> void:
	# loc_31DCC: -$12..0 accelerates down, 1..$17 accelerates up, $18
	# stops and restores level music, then $20 advances to flight.
	countdown += 1
	if countdown < 0:
		vel_y = GenesisMath.s16(vel_y + 0x18)
	elif countdown == 0:
		vel_y = 0
	elif countdown < 0x18:
		vel_y = GenesisMath.s16(vel_y - 8)
	elif countdown == 0x18:
		vel_y = 0
		manager.set_boss_defeated()
		SonicAudio.play_music(SonicAudio.MUS_S2_CNZ, true)
	elif countdown >= 0x20:
		vel_x = 0x400
		vel_y = -0x40
		state = STATE_ESCAPE_RIGHT
	_move_base()

func _tick_escape_right() -> void:
	_move_base()
	manager.unlock_s2_cnz_boss_right_boundary()
	var view_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= CAMERA_ESCAPE_MAX and (x_fixed >> 16) > manager.current_screen_x + view_width + 96:
		alive = false

func _move_base() -> void:
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8

func _display_y() -> int:
	if state >= STATE_EXPLODING:
		return y_fixed >> 16
	var phase: float = float(hover_phase) * TAU / 256.0
	return (y_fixed >> 16) + int(round(sin(phase) * 4.0))

func _check_boss_collision() -> void:
	if invincibility_timer > 0:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = x_fixed >> 16
	var by: int = _display_y()
	if absi(p.pixel_x() - bx) > 0x22 + p.width_radius:
		return
	if absi(p.pixel_y() - by) > 0x18 + p.height_radius:
		return
	if p.can_attack_object():
		p.vel_x = GenesisMath.s16(-int(p.vel_x / 2))
		p.vel_y = GenesisMath.s16(-int(p.vel_y / 2))
		hits -= 1
		invincibility_timer = 0x30
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			_begin_defeat()
		return
	p.apply_hazard_hit(bx)

func _check_electric_collision() -> void:
	if not electric_active or state >= STATE_EXPLODING:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = x_fixed >> 16
	var by: int = _display_y() + 0x22
	# Frames $C-$11 are the wide electric rail directly below the pod.
	if absi(p.pixel_x() - bx) <= 0x48 + p.width_radius and absi(p.pixel_y() - by) <= 7 + p.height_radius:
		p.apply_hazard_hit(bx)

func _begin_defeat() -> void:
	if defeated:
		return
	defeated = true
	electric_active = false
	manager.add_score(1000)
	countdown = 0xB3
	vel_x = 0
	vel_y = 0
	state = STATE_EXPLODING
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		h["attached"] = false
		hazards[i] = h

func _spawn_attached_hazard() -> void:
	var sprite: Sprite2D = _make_sprite(2)
	sprite.texture = load("res://assets/objects/s2_cnz/boss/18.png")
	hazards.append({
		"x": x_fixed >> 16,
		"y": _display_y() + 0x30,
		"offset": 0,
		"vx": 0,
		"vy": 0,
		"attached": true,
		"split": false,
		"anim": 0,
		"sprite": sprite,
	})

func _release_attached_hazards() -> void:
	for i in range(hazards.size()):
		var h: Dictionary = hazards[i]
		if bool(h.get("attached", false)):
			h["attached"] = false
			h["vx"] = 0
			h["vy"] = 0
			hazards[i] = h

func _tick_hazards() -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		var sprite: Sprite2D = h["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			hazards.remove_at(i)
			continue
		if bool(h.get("attached", false)):
			var off: int = mini(0x2E, int(h.get("offset", 0)) + 1)
			h["offset"] = off
			h["x"] = x_fixed >> 16
			h["y"] = _display_y() + off
		else:
			h["x"] = int(h["x"]) + int(int(h["vx"]) / 0x100)
			h["y"] = int(h["y"]) + int(int(h["vy"]) / 0x100)
			h["vy"] = GenesisMath.s16(int(h["vy"]) + 0x38)
			if not bool(h.get("split", false)):
				var floor_y: int = _floor_surface_y(int(h["x"]), int(h["y"]) + 8)
				if floor_y >= 0 and int(h["y"]) + 8 >= floor_y and int(h["vy"]) >= 0:
					SonicAudio.play_sfx(SonicAudio.SFX_BOMB)
					var base_x: int = int(h["x"])
					var base_y: int = floor_y - 8
					h["x"] = base_x
					h["y"] = base_y
					h["vx"] = -0x100
					h["vy"] = -0x300
					h["split"] = true
					h["anim"] = 0
					_spawn_split_hazard(base_x, base_y, 0x100)
			else:
				h["anim"] = int(h.get("anim", 0)) + 1
				sprite.texture = load("res://assets/objects/s2_cnz/boss/%02d.png" % (19 + ((int(h["anim"]) >> 2) & 1)))
		_check_hazard_collision(h)
		sprite.position = Vector2(int(h["x"]) - (x_fixed >> 16), int(h["y"]) - _display_y())
		hazards[i] = h
		if int(h["y"]) >= 0x705:
			sprite.queue_free()
			hazards.remove_at(i)

func _spawn_split_hazard(x: int, y: int, vx: int) -> void:
	var sprite: Sprite2D = _make_sprite(2)
	sprite.texture = load("res://assets/objects/s2_cnz/boss/19.png")
	hazards.append({"x":x,"y":y,"offset":0,"vx":vx,"vy":-0x300,"attached":false,"split":true,"anim":0,"sprite":sprite})

func _check_hazard_collision(h: Dictionary) -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var hx: int = int(h["x"])
	var hy: int = int(h["y"])
	if absi(p.pixel_x() - hx) <= 8 + p.width_radius and absi(p.pixel_y() - hy) <= 8 + p.height_radius:
		p.apply_hazard_hit(hx)

func _floor_surface_y(world_x: int, probe_y: int) -> int:
	if manager.collision == null:
		return -1
	var hit: Dictionary = manager.collision.find_floor(world_x, probe_y, 13, 16, 0, false)
	return probe_y + int(hit.get("distance", 0))

func _update_visuals() -> void:
	var flash_alpha: float = 0.35 if invincibility_timer > 0 and (invincibility_timer & 2) == 0 else 1.0
	for child_sprite in [main_sprite, left_claw_sprite, eggman_sprite, right_claw_sprite]:
		if child_sprite != null:
			child_sprite.flip_h = facing_right
			child_sprite.modulate = Color(1, 1, 1, flash_alpha)
	# Eggman's authored child has six face/body animation frames. Keep the idle
	# cycle modest during patrol/attacks while preserving frame 6 during defeat.
	if eggman_sprite != null:
		var egg_frame: int = 6 if state >= STATE_EXPLODING else 6 + ((visual_tick >> 3) % 6)
		eggman_sprite.texture = load("res://assets/objects/s2_cnz/boss/%02d.png" % egg_frame)
	electric_sprite.visible = electric_active and state < STATE_EXPLODING
	if electric_sprite.visible:
		var electric_frame: int = 12 + ((visual_tick >> 1) % 6)
		electric_sprite.texture = load("res://assets/objects/s2_cnz/boss/%02d.png" % electric_frame)
		electric_sprite.flip_h = facing_right
		if (visual_tick & 0x1F) == 0:
			SonicAudio.play_sfx(SonicAudio.SFX_ELECTRIC)

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var rx: int = ((random_seed >> 8) & 0x3F) - 0x20
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var ry: int = ((random_seed >> 8) & 0x2F) - 0x18
	return Vector2i(rx, ry)

func _make_sprite(local_z: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.centered = true
	sprite.z_index = local_z
	add_child(sprite)
	return sprite
