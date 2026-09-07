class_name S2HTZBossObject
extends Node2D

# Retail Sonic 2 Object $52 - Hill Top boss.
# Source-shaped translation of the two lava-well positions, $E0 raise/lower
# velocity, 8-hit body, attached flamethrower collision, free flame, twin lava
# balls, spreading floor fire, $B3 defeat countdown, and $3160 camera release.

const STATE_RAISE := 0
const STATE_FLAME := 1
const STATE_BEGIN_LOWER := 2
const STATE_LOWER := 3
const STATE_DEFEATED := 4
const STATE_FLEE := 5

const LEFT_X := 0x2F40
const RIGHT_X := 0x3040
const LEFT_BOTTOM_Y := 0x5A0
const RIGHT_BOTTOM_Y := 0x580
const LEFT_TOP_Y := 0x518
const RIGHT_TOP_Y := 0x4FC
const LEFT_BALL_Y := 0x538
const RIGHT_BALL_Y := 0x548
const CAMERA_ESCAPE_MAX := 0x3160
const FLAME_X_OFFSETS: Array[int] = [0x1C,0x20,0x28,0x34,0x3C,0x44,0x60,0x70]
const FLAME_Y_RADII: Array[int] = [4,4,8,0x0C,0x14,0x1C,0x24,8]
const FLOOR_FIRE_ANIM: Array[int] = [4,5,2,3,0,1,0,1,2,3,4,5]

var manager: SonicObjectManager
var alive: bool = true
var state: int = STATE_RAISE
var x_fixed: int = RIGHT_X << 16
var y_fixed: int = RIGHT_BOTTOM_Y << 16
var boss_y_vel: int = -0xE0
var side_right: bool = true
var facing_right: bool = false
var hits: int = 8
var invincibility_timer: int = 0
var state_timer: int = 0
var hover_phase: int = 4
var visual_tick: int = 0
var lava_ball_created: bool = false
var defeat_countdown: int = 0
var defeated_flag_sent: bool = false
var random_seed: int = 0x52A11026
var attached_flame_active: bool = false
var attached_flame_frame: int = 2
var attached_anim_tick: int = 0
var attached_anim_step: int = 0
var moving_flames: Array[Dictionary] = []
var lava_balls: Array[Dictionary] = []
var ground_fires: Array[Dictionary] = []
var smokes: Array[Dictionary] = []

var main_sprite: Sprite2D
var attached_flame_sprite: Sprite2D

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(RIGHT_X, RIGHT_BOTTOM_Y)
	main_sprite = _make_sprite(0)
	attached_flame_sprite = _make_sprite(1)
	main_sprite.texture = load("res://assets/objects/s2_htz/boss/main/01.png")
	attached_flame_sprite.visible = false
	_update_visuals()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	if invincibility_timer > 0:
		invincibility_timer -= 1

	match state:
		STATE_RAISE:
			_tick_raise()
		STATE_FLAME:
			_tick_flame()
		STATE_BEGIN_LOWER:
			_tick_begin_lower()
		STATE_LOWER:
			_tick_lower()
		STATE_DEFEATED:
			_tick_defeated()
		STATE_FLEE:
			_tick_flee()

	_tick_moving_flames()
	_tick_lava_balls()
	_tick_ground_fires()
	_tick_smokes()
	position = Vector2(x_fixed >> 16, _display_y())
	_update_visuals()
	if state < STATE_DEFEATED:
		_check_boss_collision()
		_check_attached_flame_collision()

func _tick_raise() -> void:
	_move_vertical()
	var target_y: int = RIGHT_TOP_Y if side_right else LEFT_TOP_Y
	if (y_fixed >> 16) > target_y:
		return
	y_fixed = target_y << 16
	boss_y_vel = 0
	state_timer = 0x3C
	hover_phase = 4
	state = STATE_FLAME

func _tick_flame() -> void:
	state_timer -= 1
	_tick_hover_phase()
	if state_timer >= 0:
		return
	if not attached_flame_active:
		attached_flame_active = true
		attached_anim_tick = 0
		attached_anim_step = 0
		attached_flame_frame = 2
	# Source creates the travelling flame at objoff_3E == -$18 and then
	# reloads the timer to $2F before the child animation finishes.
	if state_timer == -0x18:
		_spawn_moving_flame()
		state_timer = 0x2F
	_tick_attached_flame_animation()

func _tick_attached_flame_animation() -> void:
	if not attached_flame_active:
		return
	# Ani_obj52 scripts 0..4 form one expanding pass: 2/3, 4/5, 6/7,
	# 8/9, A/B. Preserve each authored frame duration (2,3,4,5,6 ticks).
	var pairs: Array[Array] = [[2,3],[4,5],[6,7],[8,9],[10,11]]
	var durations: Array[int] = [2,3,4,5,6]
	var pair_index: int = mini(4, attached_anim_step >> 1)
	var pair: Array = pairs[pair_index]
	attached_flame_frame = int(pair[attached_anim_step & 1])
	attached_anim_tick += 1
	if attached_anim_tick < durations[pair_index]:
		return
	attached_anim_tick = 0
	attached_anim_step += 1
	if attached_anim_step < 10:
		return
	# byte_302AC ends with $FE: advance the parent's angle to BeginLower.
	attached_flame_frame = 11
	attached_flame_active = false
	# AnimateBoss $FE advances the parent into BeginLower with the shared
	# countdown ready to expire on the next subtraction.
	state_timer = 1
	state = STATE_BEGIN_LOWER

func _tick_begin_lower() -> void:
	attached_flame_active = false
	state_timer -= 1
	_tick_hover_phase()
	if state_timer != 0:
		return
	boss_y_vel = 0xE0
	state = STATE_LOWER

func _tick_lower() -> void:
	_move_vertical()
	var py: int = y_fixed >> 16
	var ball_y: int = RIGHT_BALL_Y if side_right else LEFT_BALL_Y
	if not lava_ball_created and py >= ball_y:
		lava_ball_created = true
		_spawn_lava_balls()
	var bottom_y: int = RIGHT_BOTTOM_Y if side_right else LEFT_BOTTOM_Y
	if py < bottom_y:
		return
	y_fixed = bottom_y << 16
	boss_y_vel = -0xE0
	lava_ball_created = false
	# loc_2FE7C chooses the next well directly from Sonic X-$2FC0.
	var p: SonicPlayer = manager.player
	if p != null and p.pixel_x() >= 0x2FC0:
		side_right = true
		x_fixed = RIGHT_X << 16
		y_fixed = RIGHT_BOTTOM_Y << 16
	else:
		side_right = false
		x_fixed = LEFT_X << 16
		y_fixed = LEFT_BOTTOM_Y << 16
	facing_right = p != null and (x_fixed >> 16) <= p.pixel_x()
	state = STATE_RAISE

func _tick_defeated() -> void:
	attached_flame_active = false
	defeat_countdown -= 1
	if defeat_countdown >= 0:
		if (visual_tick & 7) == 0:
			var off: Vector2i = _random_explosion_offset()
			manager.spawn_boss_explosion((x_fixed >> 16) + off.x, _display_y() + off.y)
		if defeat_countdown <= 0x1E and (visual_tick & 0x1F) == 0:
			_spawn_smoke()
		return
	if (visual_tick & 0x1F) == 0:
		_spawn_smoke()
	if defeat_countdown > -0x3C:
		return
	if not defeated_flag_sent:
		defeated_flag_sent = true
		manager.set_boss_defeated()
		SonicAudio.play_music(SonicAudio.MUS_S2_HTZ, true)
	state = STATE_FLEE

func _tick_flee() -> void:
	y_fixed += 2 << 16
	manager.unlock_s2_htz_boss_right_boundary()
	var delete_y: int = 0x588 if side_right else 0x578
	if manager.boss_limit_right >= CAMERA_ESCAPE_MAX and (y_fixed >> 16) > delete_y:
		alive = false

func _move_vertical() -> void:
	y_fixed += boss_y_vel << 8

func _tick_hover_phase() -> void:
	hover_phase = (hover_phase + 4) & 0xFF

func _display_y() -> int:
	if state == STATE_FLAME or state == STATE_BEGIN_LOWER:
		var phase: float = float(hover_phase) * TAU / 256.0
		return (y_fixed >> 16) + int(round(sin(phase) * 2.0))
	return y_fixed >> 16

func _check_boss_collision() -> void:
	if invincibility_timer > 0:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = x_fixed >> 16
	var by: int = _display_y()
	# Touch_Sizes collision ID $32: retail body radius $20 x $1C.
	if absi(p.pixel_x() - bx) > 0x20 + p.width_radius or absi(p.pixel_y() - by) > 0x1C + p.height_radius:
		return
	if p.can_attack_object():
		p.vel_x = GenesisMath.s16(-int(p.vel_x / 2))
		p.vel_y = GenesisMath.s16(-int(p.vel_y / 2))
		hits -= 1
		invincibility_timer = 0x20
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			_begin_defeat()
		return
	p.apply_hazard_hit(bx)

func _check_attached_flame_collision() -> void:
	if not attached_flame_active or attached_flame_frame < 2 or attached_flame_frame > 9:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var idx: int = attached_flame_frame - 2
	var offset: int = FLAME_X_OFFSETS[idx]
	var fx: int = (x_fixed >> 16) + (offset if facing_right else -offset)
	var fy: int = _display_y() - 0x1C
	if absi(p.pixel_x() - fx) <= 4 + p.width_radius and absi(p.pixel_y() - fy) <= FLAME_Y_RADII[idx] + p.height_radius:
		p.apply_hazard_hit(fx)

func _begin_defeat() -> void:
	if state >= STATE_DEFEATED:
		return
	manager.add_score(1000)
	defeat_countdown = 0xB3
	boss_y_vel = 0
	attached_flame_active = false
	state = STATE_DEFEATED

func _spawn_moving_flame() -> void:
	var s: Sprite2D = _make_sprite(2)
	s.texture = load("res://assets/objects/s2_htz/boss/projectile/12.png")
	var dir: int = 1 if facing_right else -1
	moving_flames.append({"x":(x_fixed >> 16) + dir * 0x70,"y":_display_y()-0x1C,"vx":dir * 4,"age":0,"sprite":s})

func _tick_moving_flames() -> void:
	for i in range(moving_flames.size()-1,-1,-1):
		var h: Dictionary = moving_flames[i]
		var s: Sprite2D = h["sprite"] as Sprite2D
		if s == null or not is_instance_valid(s):
			moving_flames.remove_at(i); continue
		h["x"] = int(h["x"]) + int(h["vx"])
		h["age"] = int(h["age"]) + 1
		var frame: int = 12 + ((int(h["age"]) >> 2) & 1)
		s.texture = load("res://assets/objects/s2_htz/boss/projectile/%02d.png" % frame)
		_check_small_hazard(int(h["x"]), int(h["y"]), 4, 4)
		s.position = Vector2(int(h["x"]) - (x_fixed >> 16), int(h["y"]) - _display_y())
		moving_flames[i] = h
		if int(h["age"]) > 180:
			s.queue_free(); moving_flames.remove_at(i)

func _spawn_lava_balls() -> void:
	SonicAudio.play_sfx(SonicAudio.SFX_FIREBALL)
	for side in range(2):
		var s: Sprite2D = _make_sprite(2)
		s.texture = load("res://assets/objects/s2_htz/boss/projectile/14.png")
		var vx: int = -0x1C00 if side == 0 else 0x1C00
		var vy: int = -0x5400 if (x_fixed >> 16) == LEFT_X else -0x6400
		lava_balls.append({"xf":x_fixed,"yf":y_fixed,"vx":vx,"vy":vy,"age":0,"sprite":s})

func _tick_lava_balls() -> void:
	for i in range(lava_balls.size()-1,-1,-1):
		var b: Dictionary = lava_balls[i]
		var s: Sprite2D = b["sprite"] as Sprite2D
		if s == null or not is_instance_valid(s):
			lava_balls.remove_at(i); continue
		# Obj52_LavaBall_Move uses 12.4-like custom accumulation: velocity << 4.
		b["xf"] = int(b["xf"]) + (GenesisMath.s16(int(b["vx"])) << 4)
		b["yf"] = int(b["yf"]) + (GenesisMath.s16(int(b["vy"])) << 4)
		b["vy"] = GenesisMath.s16(int(b["vy"]) + 0x380)
		b["age"] = int(b["age"]) + 1
		var bx: int = int(b["xf"]) >> 16
		var by: int = int(b["yf"]) >> 16
		var frame: int = 14 + ((int(b["age"]) >> 2) & 1)
		s.texture = load("res://assets/objects/s2_htz/boss/projectile/%02d.png" % frame)
		_check_small_hazard(bx,by,8,8)
		var floor_y: int = _floor_surface_y(bx, by + 8)
		if floor_y >= 0 and by + 8 >= floor_y and GenesisMath.s16(int(b["vy"])) >= 0:
			_spawn_ground_fire(bx, floor_y - 8, -1 if GenesisMath.s16(int(b["vx"])) < 0 else 1)
			SonicAudio.play_sfx(SonicAudio.SFX_FLAMETHROWER)
			s.queue_free(); lava_balls.remove_at(i); continue
		s.position = Vector2(bx - (x_fixed >> 16), by - _display_y())
		lava_balls[i] = b
		if by > manager.current_screen_y + int(ProjectSettings.get_setting("display/window/size/viewport_height")) + 96:
			s.queue_free(); lava_balls.remove_at(i)

func _spawn_ground_fire(x: int, y: int, direction: int, spread_count: int = 3) -> void:
	# Retail conversion target is Object $20 routine $A. The lava ball keeps its
	# signed X velocity, so the floor-fire chain always propagates outward in that
	# same direction. objoff_32 starts at 9 and objoff_36 at 3.
	var s: Sprite2D = _make_sprite(2)
	s.texture = load("res://assets/objects/s2_htz/boss/fire/04.png")
	ground_fires.append({
		"x": x, "y": y, "timer": 9, "spread": spread_count,
		"dir": direction, "anim_step": 0, "anim_timer": 5, "sprite": s
	})

func _tick_ground_fires() -> void:
	# Exact Obj20 loc_231D2 + Ani_obj20 animation 2 semantics. The animation
	# script ends in $FC, which increments routine from $A to $C; routine $C is
	# DeleteObject. Phase 110 accidentally treated $FC as a loop, so each flame
	# survived forever and got another chance to spawn every $80 frames. Retail
	# flames live only through the 12 authored frames (delay 5 = six ticks each),
	# so each node can spawn at most one child. With objoff_36 starting at 3 the
	# chain is finite: four flames per lava ball, never an unbounded tree.
	for i in range(ground_fires.size() - 1, -1, -1):
		var f: Dictionary = ground_fires[i]
		var s: Sprite2D = f["sprite"] as Sprite2D
		if s == null or not is_instance_valid(s):
			ground_fires.remove_at(i)
			continue

		var anim_step: int = int(f["anim_step"])
		if anim_step < 0 or anim_step >= FLOOR_FIRE_ANIM.size():
			s.queue_free()
			ground_fires.remove_at(i)
			continue
		var frame: int = FLOOR_FIRE_ANIM[anim_step]
		s.texture = load("res://assets/objects/s2_htz/boss/fire/%02d.png" % frame)
		_check_small_hazard(int(f["x"]), int(f["y"]), 8, 8)

		# objoff_32: first propagation after ten frames, then reset to $7F. The
		# $7F interval is longer than this object's remaining animation lifetime,
		# exactly preventing a second propagation from the same flame.
		f["timer"] = int(f["timer"]) - 1
		if int(f["timer"]) < 0:
			f["timer"] = 0x7F
			f["spread"] = int(f["spread"]) - 1
			if int(f["spread"]) >= 0:
				var dir: int = -1 if int(f["dir"]) < 0 else 1
				var nx: int = int(f["x"]) + dir * 0x0E
				var floor_y: int = _floor_surface_y(nx, int(f["y"]) + 8)
				if floor_y >= 0:
					_spawn_ground_fire(nx, floor_y - 8, dir, int(f["spread"]))

		# AnimateSprite delay byte 5: hold every mapping frame for six ticks.
		f["anim_timer"] = int(f["anim_timer"]) - 1
		if int(f["anim_timer"]) < 0:
			f["anim_timer"] = 5
			f["anim_step"] = anim_step + 1
			if int(f["anim_step"]) >= FLOOR_FIRE_ANIM.size():
				s.queue_free()
				ground_fires.remove_at(i)
				continue

		s.position = Vector2(int(f["x"]) - (x_fixed >> 16), int(f["y"]) - _display_y())
		ground_fires[i] = f

func _spawn_smoke() -> void:
	var s: Sprite2D = _make_sprite(1)
	s.texture = load("res://assets/objects/s2_htz/boss/smoke/00.png")
	smokes.append({"xf":x_fixed,"yf":(_display_y()-0x28)<<16,"vx":-0x60,"vy":-0xC0,"frame":0,"timer":0x11,"sprite":s})

func _tick_smokes() -> void:
	for i in range(smokes.size()-1,-1,-1):
		var h: Dictionary = smokes[i]
		var s: Sprite2D = h["sprite"] as Sprite2D
		if s == null or not is_instance_valid(s):
			smokes.remove_at(i); continue
		h["xf"] = int(h["xf"]) + (GenesisMath.s16(int(h["vx"])) << 8)
		h["yf"] = int(h["yf"]) + (GenesisMath.s16(int(h["vy"])) << 8)
		h["timer"] = int(h["timer"]) - 1
		if int(h["timer"]) < 0:
			h["timer"] = 0x11
			h["frame"] = int(h["frame"]) + 1
			if int(h["frame"]) >= 4:
				s.queue_free(); smokes.remove_at(i); continue
			s.texture = load("res://assets/objects/s2_htz/boss/smoke/%02d.png" % int(h["frame"]))
		s.position = Vector2((int(h["xf"])>>16)-(x_fixed>>16),(int(h["yf"])>>16)-_display_y())
		smokes[i] = h

func _check_small_hazard(hx: int, hy: int, hw: int, hh: int) -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	if absi(p.pixel_x()-hx) <= hw+p.width_radius and absi(p.pixel_y()-hy) <= hh+p.height_radius:
		p.apply_hazard_hit(hx)

func _floor_surface_y(world_x: int, probe_y: int) -> int:
	if manager.collision == null:
		return -1
	var hit: Dictionary = manager.collision.find_floor(world_x, probe_y, 13, 16, 0, false)
	return probe_y + int(hit.get("distance", 0))

func _update_visuals() -> void:
	var alpha: float = 0.35 if invincibility_timer > 0 and (invincibility_timer & 2) == 0 else 1.0
	if main_sprite != null:
		main_sprite.flip_h = facing_right
		main_sprite.modulate = Color(1,1,1,alpha)
		main_sprite.texture = load("res://assets/objects/s2_htz/boss/main/%02d.png" % (16 if state >= STATE_DEFEATED else 1))
	if attached_flame_sprite != null:
		attached_flame_sprite.visible = attached_flame_active and state < STATE_DEFEATED
		attached_flame_sprite.flip_h = facing_right
		if attached_flame_sprite.visible:
			attached_flame_sprite.texture = load("res://assets/objects/s2_htz/boss/flame/%02d.png" % clampi(attached_flame_frame,2,11))

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var rx: int = ((random_seed >> 8) & 0x3F) - 0x20
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var ry: int = ((random_seed >> 8) & 0x2F) - 0x18
	return Vector2i(rx,ry)

func _make_sprite(local_z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.centered = true
	s.z_index = local_z
	add_child(s)
	return s
