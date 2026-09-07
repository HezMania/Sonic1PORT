class_name FZBossObject
extends Node2D

# Objects $85/$84/$86 - Final Zone Eggman, cylinders, and plasma launcher.
# This keeps the encounter in one native controller while preserving the
# source positions, cylinder pair table, 8-hit count, plasma timing, defeat
# route, and Final Zone ending handoff.

const BOSS_X := 0x2450
const BOSS_Y := 0x0510
const BOSS_END := 0x2700

const STATE_WAIT := 0
const STATE_CRUSH := 1
const STATE_PLASMA := 2
const STATE_FALL := 3
const STATE_RUN := 4
const STATE_JUMP := 5
const STATE_SHIP := 6
const STATE_ESCAPE := 7

const CYLINDER_POSITIONS: Array[Vector2i] = [
	Vector2i(BOSS_X + 0x80, BOSS_Y + 0x110),
	Vector2i(BOSS_X + 0x100, BOSS_Y + 0x110),
	Vector2i(BOSS_X + 0x40, BOSS_Y - 0x50),
	Vector2i(BOSS_X + 0xC0, BOSS_Y - 0x50),
]
const CYLINDER_PAIRS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
]

var manager: SonicObjectManager
var alive := true
var state := STATE_WAIT
var hits := 8
var damage_timer := 0
var visual_tick := 0
var cycle_serial := 0
var active_target := -1
var active_decoy := -1
var cycle_in_progress := false
var plasma_started := false
var plasma_finished := false
# BossPlasma_Finish runs after the parent in object-slot order; preserve the
# resulting handoff gap before the next piston pair begins.
var post_plasma_delay := 0
var ending_handoff_sent := false

var eggman_x_fixed := 0
var eggman_y_fixed := 0
var vel_x := 0
var vel_y := 0

var eggman_sprite: Sprite2D
var panel_sprite: Sprite2D
var launcher_sprite: Sprite2D
var cockpit_sprite: Sprite2D
var legs_sprite: Sprite2D
var ship_sprite: Sprite2D
var face_sprite: Sprite2D
var flame_sprite: Sprite2D
var cylinders: Array = []
var plasma_balls: Array = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2.ZERO
	eggman_x_fixed = 0x100 << 16
	eggman_y_fixed = 0x100 << 16

	eggman_sprite = _new_sprite(5)
	eggman_sprite.visible = false

	panel_sprite = _new_sprite(2)
	panel_sprite.position = Vector2(BOSS_X + 0x160, BOSS_Y + 0x80)
	panel_sprite.texture = SourceObjectArt.fz_cylinder_texture(11)

	launcher_sprite = _new_sprite(3)
	launcher_sprite.position = Vector2(BOSS_X + 0x138, BOSS_Y + 0x2C)
	launcher_sprite.texture = SourceObjectArt.fz_plasma_launcher_texture(0)

	cockpit_sprite = _new_sprite(3)
	cockpit_sprite.position = Vector2(BOSS_X + 0x290, BOSS_Y + 0x86)
	cockpit_sprite.texture = SourceObjectArt.fz_eggman_texture(10) # Map_SEgg .cockpit
	cockpit_sprite.visible = false

	legs_sprite = _new_sprite(2)
	legs_sprite.position = cockpit_sprite.position
	legs_sprite.visible = false

	ship_sprite = _new_asset_sprite("res://assets/boss/eggman/00.png", 2)
	face_sprite = _new_asset_sprite("res://assets/boss/eggman/01.png", 3)
	flame_sprite = _new_asset_sprite("res://assets/boss/eggman/08.png", 1)
	ship_sprite.visible = false
	face_sprite.visible = false
	flame_sprite.visible = false

	for i in range(CYLINDER_POSITIONS.size()):
		# Genesis priorities are inverse to our local z convention here:
		# Eggman is priority 4 while Object $84 cylinders are priority 3, so the
		# piston must cover Eggman when their sprite pieces overlap.
		var spr := _new_sprite(6)
		var base: Vector2i = CYLINDER_POSITIONS[i]
		spr.position = Vector2(base.x, base.y)
		spr.flip_v = i >= 2
		spr.texture = SourceObjectArt.fz_cylinder_texture(0)
		cylinders.append({
			"sprite": spr,
			"base_x": base.x,
			"base_y": base.y,
			"offset": 0.0,
			"command": 0, # 0 idle/retract, 1 target extend, 2 decoy extend
			"selected": false,
		})

func tick() -> void:
	if not alive:
		return
	visual_tick += 1
	if damage_timer > 0:
		damage_timer -= 1

	_tick_cylinders()
	_tick_launcher_solid()
	_tick_plasma_balls()

	match state:
		STATE_WAIT:
			_tick_wait()
		STATE_CRUSH:
			_tick_crush()
		STATE_PLASMA:
			_tick_plasma()
		STATE_FALL:
			_tick_fall()
		STATE_RUN:
			_tick_run()
		STATE_JUMP:
			_tick_jump()
		STATE_SHIP:
			_tick_ship()
		STATE_ESCAPE:
			_tick_escape()

	_update_visuals()

func _tick_wait() -> void:
	# BossFinal_Eggman_Wait starts the encounter when the camera reaches $2450
	# after the boss PLC has completed.
	if manager.current_screen_x < BOSS_X:
		return
	state = STATE_CRUSH
	_begin_crush_cycle()

func _begin_crush_cycle() -> void:
	cycle_serial += 1
	var random_word := manager.next_random_word()
	var pair_index := (random_word >> 2) & 3
	var pair: Vector2i = CYLINDER_PAIRS[pair_index]
	active_target = pair.x
	active_decoy = pair.y
	# The original may swap which member of the selected pair contains Eggman.
	if (random_word & 0x8000) != 0:
		var swap := active_target
		active_target = active_decoy
		active_decoy = swap
	cycle_in_progress = true
	for i in range(cylinders.size()):
		var c: Dictionary = cylinders[i]
		c["selected"] = i == active_target or i == active_decoy
		c["command"] = 1 if i == active_target else (2 if i == active_decoy else 0)
		cylinders[i] = c
	eggman_sprite.visible = true

func _tick_crush() -> void:
	if not cycle_in_progress:
		if hits <= 0:
			manager.add_score(100)
			manager.set_boss_defeated()
			state = STATE_FALL
			eggman_x_fixed = (BOSS_X + 0x170) << 16
			eggman_y_fixed = (BOSS_Y + 0x2C) << 16
			vel_x = 0
			vel_y = 0
			# The Eggmobile waiting at the right side is a separate source composite:
			# Map_Eggman frame 0 body + Map_SEgg frame $A empty cockpit + legs.
			# Do not substitute the post-hit Map_FZDamaged cockpit here.
			cockpit_sprite.texture = SourceObjectArt.fz_eggman_texture(10)
			cockpit_sprite.visible = true
			legs_sprite.texture = SourceObjectArt.fz_legs_texture(0)
			legs_sprite.visible = true
			ship_sprite.position = Vector2(BOSS_X + 0x290, BOSS_Y + 0x86)
			ship_sprite.visible = true
			face_sprite.visible = false
			flame_sprite.visible = false
			return
		state = STATE_PLASMA
		plasma_started = false
		plasma_finished = false
		post_plasma_delay = 0
		return

	_follow_target_cylinder()
	_check_eggman_solid_hit()

func _tick_plasma() -> void:
	if not plasma_started:
		plasma_started = true
		plasma_finished = false
		post_plasma_delay = 0
		_spawn_plasma_set()
		return
	if plasma_finished:
		# In the 68000 object list the launcher notices the last ball after the
		# parent has already run, then the parent changes routine on the following
		# frame. Keep those two frame boundaries instead of immediately extending.
		if post_plasma_delay < 2:
			post_plasma_delay += 1
			return
		state = STATE_CRUSH
		_begin_crush_cycle()

func _tick_fall() -> void:
	# BossFinal_Eggman_Fall: frame 6, gravity $10, land at boss_y+$8C.
	_move_8_8()
	vel_y = GenesisMath.s16(vel_y + 0x10)
	_expand_final_boundary()
	if (eggman_y_fixed >> 16) >= BOSS_Y + 0x8C:
		eggman_y_fixed = (BOSS_Y + 0x8C) << 16
		state = STATE_RUN
		vel_x = 0x100
		vel_y = -0x100
		manager.boss_screen_lock = false
		manager.fz_end_scroll_started = true
	_check_escape_barrier()

func _tick_run() -> void:
	_move_8_8()
	vel_y = GenesisMath.s16(vel_y + 0x10)
	if (eggman_y_fixed >> 16) >= BOSS_Y + 0x93:
		vel_y = -0x40

	var p := manager.player
	vel_x = 0x400
	if p != null:
		var d := (eggman_x_fixed >> 16) - p.pixel_x()
		if d < 0:
			vel_x = 0x500
		elif d >= 0x70:
			vel_x -= 0x100
			if d >= 0x78:
				vel_x -= 0x100
			if d >= 0x80:
				vel_x -= 0x80
			if d >= 0x88:
				vel_x -= 0x80
			if d >= 0x90:
				vel_x -= 0x80
			if d >= 0xC8:
				vel_x = 0

	if (eggman_x_fixed >> 16) >= BOSS_X + 0x250:
		eggman_x_fixed = (BOSS_X + 0x250) << 16
		vel_x = 0x240
		vel_y = -0x4C0
		state = STATE_JUMP
	_expand_final_boundary()
	_check_escape_barrier()

func _tick_jump() -> void:
	_move_8_8()
	if (eggman_x_fixed >> 16) >= BOSS_X + 0x290:
		eggman_x_fixed = (BOSS_X + 0x290) << 16
		vel_x = 0
	vel_y = GenesisMath.s16(vel_y + 0x34)
	if vel_y >= 0 and (eggman_y_fixed >> 16) >= BOSS_Y + 0x82:
		eggman_y_fixed = (BOSS_Y + 0x82) << 16
		vel_y = 0
	if vel_x == 0 and vel_y == 0:
		state = STATE_SHIP
		vel_y = -0x180
		hits = 1
		eggman_sprite.visible = false
		cockpit_sprite.visible = false
		legs_sprite.visible = false
		ship_sprite.visible = true
		face_sprite.visible = true
		flame_sprite.visible = true
	_expand_final_boundary()
	_check_escape_barrier()

func _tick_ship() -> void:
	_move_8_8()
	if (eggman_y_fixed >> 16) < BOSS_Y + 0x34:
		vel_x = 0x180
		vel_y = -0x18
		state = STATE_ESCAPE
		damage_timer = 0
	_expand_final_boundary()

func _tick_escape() -> void:
	_move_8_8()
	_expand_final_boundary()
	_check_escape_hit()

	var p := manager.player
	if p != null and p.pixel_x() >= BOSS_END + 0x90:
		p.control_locked = true
		p.control_lock_direction = 0
		p.inertia = 0
		if p.pixel_x() >= BOSS_END + 0xE0:
			p.force_set_pixel_position(BOSS_END + 0xE0, p.pixel_y())

	if (eggman_x_fixed >> 16) >= BOSS_END + 0x200:
		if not ending_handoff_sent:
			ending_handoff_sent = true
			manager.request_final_ending()
		alive = false

func _tick_cylinders() -> void:
	var all_selected_idle := true
	for i in range(cylinders.size()):
		var c: Dictionary = cylinders[i]
		var selected: bool = bool(c.get("selected", false))
		var command: int = int(c.get("command", 0))
		var offset: float = float(c.get("offset", 0.0))
		var top := i >= 2

		if selected and command != 0:
			# EggmanCylinder_Move accelerates after the first 16 pixels:
			# 0.5 px/frame initially, then 3 px/frame to the 160px endpoint.
			var magnitude := absf(offset)
			var step := 0.5 if magnitude < 16.0 else 3.0
			offset += step if top else -step
			if (top and offset >= 160.0) or (not top and offset <= -160.0):
				offset = 160.0 if top else -160.0
				command = 0
		elif selected and absf(offset) > 0.0:
			# Normal retraction is 2 px/frame. Once Eggman has no hits left, the
			# source adds an opposing $10000 before the $20000 retract step, giving
			# a net 1 px/frame while BossDefeated emits explosions every 8 frames.
			var retract_step := 1.0 if hits <= 0 else 2.0
			if hits <= 0 and (visual_tick & 7) == 0:
				_spawn_defeat_explosion(int(c.get("base_x", 0)), int(c.get("base_y", 0)) + int(round(offset)))
			if top:
				offset = maxf(0.0, offset - retract_step)
			else:
				offset = minf(0.0, offset + retract_step)
		elif selected:
			c["selected"] = false

		c["offset"] = offset
		c["command"] = command
		cylinders[i] = c
		_update_cylinder_sprite(i)
		if bool(c.get("selected", false)) or absf(offset) > 0.01:
			all_selected_idle = false

		# Each cylinder remains a source SolidObject throughout its movement.
		var p := manager.player
		if p != null:
			var base_x: int = int(c.get("base_x", 0))
			var base_y: int = int(c.get("base_y", 0))
			p.resolve_solid_box_contact(base_x, base_y + int(round(offset)), 0x20, 0x60, true, -850 - i)

	if cycle_in_progress and all_selected_idle:
		cycle_in_progress = false
		active_target = -1
		active_decoy = -1

func _update_cylinder_sprite(index: int) -> void:
	var c: Dictionary = cylinders[index]
	var spr = c.get("sprite")
	if spr == null or not is_instance_valid(spr):
		return
	var offset: float = float(c.get("offset", 0.0))
	spr.position = Vector2(int(c.get("base_x", 0)), int(c.get("base_y", 0)) + offset)
	var magnitude := absf(offset)
	var frame := 0
	if index >= 2:
		# Top cylinders use source threshold $27 before the first extension frame.
		if magnitude >= 0x27:
			frame = 1 + int((magnitude - 0x27) / 16.0)
	else:
		# Bottom cylinders negate the offset then subtract 8.
		if magnitude >= 8.0:
			frame = 1 + int((magnitude - 8.0) / 16.0)
	frame = clampi(frame, 0, 10)
	spr.texture = SourceObjectArt.fz_cylinder_texture(frame)

func _follow_target_cylinder() -> void:
	if active_target < 0 or active_target >= cylinders.size():
		return
	var c: Dictionary = cylinders[active_target]
	var x: int = int(c.get("base_x", 0))
	var y: int = int(c.get("base_y", 0)) + int(round(float(c.get("offset", 0.0))))
	eggman_x_fixed = x << 16
	eggman_y_fixed = (y + (14 if active_target >= 2 else -10)) << 16

func _check_eggman_solid_hit() -> void:
	var p := manager.player
	if p == null or p.dead or p.drowning or p.hurt_state:
		return
	var ex := eggman_x_fixed >> 16
	var ey := eggman_y_fixed >> 16
	if absi(p.pixel_x() - ex) > p.width_radius + 32 or absi(p.pixel_y() - ey) > p.height_radius + 20:
		return
	if not p.can_attack_object():
		p.resolve_solid_box_contact(ex, ey, 32, 20, true, -844)
		return
	# Source BossFinal_Crush only accepts the Roll animation and gives a fixed
	# +/-$300 horizontal rebound.
	p.vel_x = 0x300 if p.pixel_x() >= ex else -0x300
	p.inertia = 0
	p.in_air = true
	p.clear_object_support()
	p._sync_position()
	if damage_timer > 0 or hits <= 0:
		return
	hits -= 1
	SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
	damage_timer = 0x64

func _spawn_defeat_explosion(x: int, y: int) -> void:
	# BossDefeated randomizes roughly +/-32 X and a downward-biased Y offset.
	var r := manager.next_random_word()
	var dx := ((r & 0xFF) >> 2) - 0x20
	var dy := ((r >> 8) & 0xFF) >> 3
	manager.spawn_boss_explosion(x + dx, y + dy)

func _tick_launcher_solid() -> void:
	var p := manager.player
	if p == null:
		return
	# BossPlasma_Generator uses SolidObject with an 8px half-width and 17px
	# lower extent. Keep the generator physically present between volleys.
	p.resolve_solid_box_contact(BOSS_X + 0x138, BOSS_Y + 0x2C, 8, 17, true, -846)

func _spawn_plasma_set() -> void:
	launcher_sprite.texture = SourceObjectArt.fz_plasma_launcher_texture(2)
	for i in range(4):
		var spr := _new_sprite(4)
		var start_x := BOSS_X + 0x138
		var start_y := BOSS_Y + 0x2C
		spr.position = Vector2(start_x, start_y)
		spr.texture = SourceObjectArt.fz_plasma_ball_texture(0)
		var target_x := BOSS_X + 0x128 - (i * 0x59)
		target_x += (manager.next_random_word() & 0x1F) - 0x10
		plasma_balls.append({
			"sprite": spr,
			"x": float(start_x),
			"y": float(start_y),
			"vx": float(target_x - start_x) / 16.0,
			"vy": 0.0,
			"target_x": float(target_x),
			"state": 0,
			"timer": 16,
			"life": 0xB4,
			"index": i,
		})

func _tick_plasma_balls() -> void:
	if plasma_balls.is_empty():
		if state == STATE_PLASMA and plasma_started:
			plasma_finished = true
			launcher_sprite.texture = SourceObjectArt.fz_plasma_launcher_texture(0)
		return

	for i in range(plasma_balls.size() - 1, -1, -1):
		var b: Dictionary = plasma_balls[i]
		var spr = b.get("sprite")
		if spr == null or not is_instance_valid(spr):
			plasma_balls.remove_at(i)
			continue
		var bstate: int = int(b.get("state", 0))
		var x: float = float(b.get("x", 0.0))
		var y: float = float(b.get("y", 0.0))
		var timer: int = int(b.get("timer", 0))
		var life: int = int(b.get("life", 0))

		if bstate == 0:
			x += float(b.get("vx", 0.0))
			timer -= 1
			if timer <= 0:
				x = float(b.get("target_x", x))
				bstate = 1
				# obSubtype=$B4 starts in Spread, so the 16-frame horizontal
				# separation is part of the 180-frame drop countdown.
				timer = 0xB4 - 16
		elif bstate == 1:
			timer -= 1
			if timer <= 0:
				bstate = 2
				var p := manager.player
				b["vx"] = float((p.pixel_x() if p != null else int(x)) - x) / 256.0
				b["vy"] = 1.25
				life = 0xB4
		else:
			x += float(b.get("vx", 0.0))
			y += float(b.get("vy", 1.25))
			life -= 1
			var p := manager.player
			if p != null and absi(p.pixel_x() - int(x)) <= p.width_radius + 12 and absi(p.pixel_y() - int(y)) <= p.height_radius + 12:
				p.apply_hazard_hit(int(x))
			if y >= BOSS_Y + 0xD0 or life <= 0:
				spr.queue_free()
				plasma_balls.remove_at(i)
				continue

		b["x"] = x
		b["y"] = y
		b["state"] = bstate
		b["timer"] = timer
		b["life"] = life
		plasma_balls[i] = b
		spr.position = Vector2(x, y)
		var frame := 0
		if bstate <= 1:
			# Ani_Plasma.full, delay 1.
			var full_frames: Array[int] = [0,10,8,10,1,10,9,10,6,10,7,10,0,10,8,10,1,10,9,10,6,10,7,10,2,10,3,10,4,10,5]
			frame = full_frames[(int(visual_tick / 2) + int(b.get("index", 0))) % full_frames.size()]
		else:
			# Ani_Plasma.short, delay 0.
			var short_frames: Array[int] = [6,5,1,5,7,5,1,5]
			frame = short_frames[(visual_tick + int(b.get("index", 0))) % short_frames.size()]
		spr.texture = SourceObjectArt.fz_plasma_ball_texture(frame)

func _check_escape_hit() -> void:
	if state != STATE_ESCAPE or damage_timer > 0:
		return
	var p := manager.player
	if p == null or p.dead or p.drowning:
		return
	var ex := eggman_x_fixed >> 16
	var ey := eggman_y_fixed >> 16
	if absi(p.pixel_x() - ex) > p.width_radius + 24 or absi(p.pixel_y() - ey) > p.height_radius + 24:
		return
	if not p.can_attack_object():
		return
	hits = 0
	damage_timer = 0x1E
	vel_y = 0x60 if vel_y < 0 else vel_y
	p.vel_x = -p.vel_x
	p._sync_position()

func _check_escape_barrier() -> void:
	# Until Eggman reaches the ship routine, the source treats his 32x224
	# column as a solid barrier so Sonic cannot pass through him.
	var p := manager.player
	if p == null:
		return
	p.resolve_solid_box_contact(eggman_x_fixed >> 16, eggman_y_fixed >> 16, 16, 112, true, -845)

func _expand_final_boundary() -> void:
	manager.boss_limit_right = mini(BOSS_END, manager.boss_limit_right + 2)

func _move_8_8() -> void:
	eggman_x_fixed += vel_x << 8
	eggman_y_fixed += vel_y << 8

func _update_visuals() -> void:
	var ex := eggman_x_fixed >> 16
	var ey := eggman_y_fixed >> 16

	if eggman_sprite.visible:
		eggman_sprite.position = Vector2(ex, ey)
		eggman_sprite.flip_h = state >= STATE_FALL
		var frame := 1 + (int(visual_tick / 7) & 1)
		if damage_timer > 0:
			frame = 5
		if state == STATE_FALL:
			frame = 6
		elif state == STATE_RUN:
			var run_frames: Array[int] = [7, 4, 8, 4]
			frame = run_frames[int(visual_tick / 7) % run_frames.size()]
		elif state == STATE_JUMP:
			var jump_frames: Array[int] = [4, 3, 3]
			frame = jump_frames[int(visual_tick / 16) % jump_frames.size()]
		eggman_sprite.texture = SourceObjectArt.fz_eggman_texture(frame)

	if cockpit_sprite.visible:
		cockpit_sprite.flip_h = true
		# BossFinal_Cockpit holds Map_SEgg frame $A while the separate
		# Eggmobile waits for Eggman: this is the authored empty cockpit.
		cockpit_sprite.texture = SourceObjectArt.fz_eggman_texture(10)
	if legs_sprite.visible:
		legs_sprite.flip_h = true
		legs_sprite.texture = SourceObjectArt.fz_legs_texture(0)

	if ship_sprite.visible:
		ship_sprite.flip_h = true
		face_sprite.flip_h = true
		flame_sprite.flip_h = true
		# Before STATE_SHIP this is the separate empty vehicle waiting at the
		# landing point. Only after Eggman boards does the craft follow his object.
		if state >= STATE_SHIP:
			var world_pos := Vector2(ex, ey)
			ship_sprite.position = world_pos
			face_sprite.position = world_pos
			flame_sprite.position = world_pos
		var face_frame := 1
		if damage_timer > 0:
			face_frame = 5
		elif state == STATE_ESCAPE:
			face_frame = 6
		face_sprite.texture = load("res://assets/boss/eggman/%02d.png" % face_frame)
		var flame_frame := 8 + (int(visual_tick / 4) & 1)
		if state == STATE_ESCAPE and vel_x != 0:
			var escape_flames: Array[int] = [11, 12, 11, 12, 9, 8]
			flame_frame = escape_flames[int(visual_tick / 4) % escape_flames.size()]
		flame_sprite.texture = load("res://assets/boss/eggman/%02d.png" % flame_frame)

	if panel_sprite.visible and manager.player != null:
		if manager.player.pixel_x() >= BOSS_X + 0x160 and manager.current_screen_x > BOSS_X + 0x160:
			panel_sprite.visible = false

	launcher_sprite.texture = SourceObjectArt.fz_plasma_launcher_texture(2 + (int(visual_tick / 2) & 1)) if state == STATE_PLASMA and plasma_started and not plasma_finished else SourceObjectArt.fz_plasma_launcher_texture(0)

func _new_sprite(local_z: int) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.z_index = local_z
	add_child(spr)
	return spr

func _new_asset_sprite(path: String, local_z: int) -> Sprite2D:
	var spr := _new_sprite(local_z)
	spr.texture = load(path)
	return spr
