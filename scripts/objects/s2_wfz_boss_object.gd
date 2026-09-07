class_name S2WFZBossObject
extends Node2D

# Phase 132: Sonic 2 Object $C5 - Wing Fortress final fidelity corrections.
# Source-shaped translation of the mother case, two laser walls, moving boss
# platforms, laser shooter/beam, eight-hit lifecycle and the $EF defeat timer.

const ST_WAIT := 0
const ST_PRELUDE := 1
const ST_DESCEND := 2
const ST_PATROL := 3
const ST_OPEN := 4
const ST_SHOOTER_DOWN := 5
const ST_CHARGE := 6
const ST_LASER_EXTEND := 7
const ST_LASER_MOVE := 8
const ST_SHOOTER_UP := 9
const ST_CLOSE := 10
const ST_DEFEAT := 11

const START_X := 0x2B80
const START_Y := 0x450
const LEFT_X := START_X - 0x60
const RIGHT_X := START_X + 0x60
const WALL_OFFSET_X := 0x88
const WALL_OFFSET_Y := 0x60
const LEFT_WALL_WORLD_X := START_X - WALL_OFFSET_X
const RIGHT_WALL_WORLD_X := START_X + WALL_OFFSET_X
const WALL_WORLD_Y := START_Y + WALL_OFFSET_Y
const EGGMAN_WORLD_X := 0x2C60
const EGGMAN_START_Y := 0x4E6
const SUPPORT_BASE := -0xC500

static var _texture_cache: Dictionary = {}

var manager: SonicObjectManager
var alive: bool = true
var state: int = ST_WAIT
var hits: int = 8
var invulnerable_timer: int = 0
var timer: int = 0
var animation_timer: int = 0
var frame_counter: int = 0
var boss_x_fixed: int = START_X << 16
var boss_y_fixed: int = START_Y << 16
var vx: int = 0
var vy: int = 0
var direction: int = -1
var beam_stage: int = 0
var beam_visible: bool = false
var beam_active: bool = false
var boss_music_started: bool = false
var releaser_x_fixed: int = START_X << 16
var releaser_y_fixed: int = (START_Y + 8) << 16
var releaser_state: int = 0
var releaser_timer: int = 0
var releaser_slot: int = 0
var releaser_release_count: int = 0
var eggman_world_y: int = EGGMAN_START_Y
var eggman_defeat_timer: int = -1

var case_sprite: Sprite2D
var shooter_sprite: Sprite2D
var left_wall_sprite: Sprite2D
var right_wall_sprite: Sprite2D
var releaser_sprite: Sprite2D
var eggman_sprite: Sprite2D
var eggman_platform_sprite: Sprite2D
var laser_sprite: Sprite2D
var platforms: Array[Dictionary] = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(START_X, START_Y)
	case_sprite = _make_sprite("boss", 0, 5)
	shooter_sprite = _make_sprite("boss", 4, 4)
	left_wall_sprite = _make_sprite("boss", 12, 3)
	right_wall_sprite = _make_sprite("boss", 12, 3)
	releaser_sprite = _make_sprite("boss", 5, 4)
	eggman_sprite = _make_sprite("boss_eggman", 0, 4)
	eggman_platform_sprite = _make_sprite("boss_eggman_platform", 0, 3)
	laser_sprite = _make_sprite("boss", 13, 6)
	shooter_sprite.visible = false
	left_wall_sprite.visible = false
	right_wall_sprite.visible = false
	releaser_sprite.visible = false
	eggman_sprite.visible = false
	eggman_platform_sprite.visible = false
	laser_sprite.visible = false
	# Retail Robotnik is an independent world-space object at $2C60,$04E6;
	# the side laser walls and platform releaser are likewise spawned once and
	# do not inherit later laser-case motion.
	eggman_world_y = EGGMAN_START_Y
	releaser_x_fixed = START_X << 16
	releaser_y_fixed = (START_Y + 8) << 16
	_update_visuals()

func tick() -> void:
	if not alive or manager == null:
		return
	frame_counter += 1
	if invulnerable_timer > 0:
		invulnerable_timer -= 1
	match state:
		ST_WAIT: _tick_wait()
		ST_PRELUDE: _tick_prelude()
		ST_DESCEND: _tick_descend()
		ST_PATROL: _tick_patrol()
		ST_OPEN: _tick_open()
		ST_SHOOTER_DOWN: _tick_shooter_down()
		ST_CHARGE: _tick_charge()
		ST_LASER_EXTEND: _tick_laser_extend()
		ST_LASER_MOVE: _tick_laser_move()
		ST_SHOOTER_UP: _tick_shooter_up()
		ST_CLOSE: _tick_close()
		ST_DEFEAT: _tick_defeat()
	_tick_releaser()
	_tick_platforms()
	_tick_eggman()
	_tick_walls()
	_update_visuals()
	if state > ST_SHOOTER_DOWN and state < ST_DEFEAT:
		_check_case_collision()
	_check_laser_hazard()

func _boss_x() -> int:
	return boss_x_fixed >> 16

func _boss_y() -> int:
	return boss_y_fixed >> 16

func _move_case() -> void:
	boss_x_fixed += GenesisMath.s16(vx) << 8
	boss_y_fixed += GenesisMath.s16(vy) << 8

func _tick_wait() -> void:
	var p: SonicPlayer = manager.player
	if p == null:
		return
	if absi(p.pixel_x() - _boss_x()) >= 0x20:
		return
	# ObjC5_CaseStart: create the arena machinery at their one-time world
	# positions, wait $5A and fade music. Only the shooter follows the case.
	state = ST_PRELUDE
	timer = 0x5A
	vy = 0x40
	left_wall_sprite.visible = true
	right_wall_sprite.visible = true
	shooter_sprite.visible = true
	releaser_sprite.visible = true
	eggman_sprite.visible = true
	eggman_platform_sprite.visible = true
	releaser_x_fixed = _boss_x() << 16
	releaser_y_fixed = (_boss_y() + 8) << 16
	releaser_state = 0
	releaser_timer = 0
	SonicAudio.stop_music()
	# LevEvents_WFZ used the $500 gate for the approach cutscene; once Sonic
	# actually reaches C5 he regains normal controls for the fight.
	p.control_locked = false
	p.object_control_override = false

func _tick_prelude() -> void:
	timer -= 1
	if timer >= 0:
		return
	state = ST_DESCEND
	timer = 0x60
	if not boss_music_started:
		boss_music_started = true
		SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)

func _tick_descend() -> void:
	timer -= 1
	if timer <= 0:
		state = ST_PATROL
		vy = 0
		var p: SonicPlayer = manager.player
		direction = 1 if p != null and p.pixel_x() >= _boss_x() else -1
		vx = direction * 0x100
		timer = 0x70
		# ObjC5_CaseXSpeed sets status bit 2; the independent platform releaser
		# sees it, descends for $40 frames, waits $10, then starts releasing one
		# platform every $80 frames.
		releaser_state = 1
		releaser_timer = 0x40
		return
	_move_case()

func _tick_patrol() -> void:
	timer -= 1
	_bounce_case_bounds()
	_move_case()
	if timer >= 0:
		return
	state = ST_OPEN
	animation_timer = 0
	vx = 0

func _tick_open() -> void:
	animation_timer += 1
	# Ani_objC5 animation 0 is delay 5 with 0,1,2,3,3,3,3,$FA.
	# Keep the full source hold instead of the Phase131 24-frame shortcut.
	var seq: Array[int] = [0, 1, 2, 3, 3, 3, 3]
	var index: int = mini(seq.size() - 1, int(animation_timer / 6.0))
	_set_frame(case_sprite, "boss", seq[index])
	if animation_timer < 42:
		return
	# Runtime testing showed the first sweep overtaking the releaser. Let the
	# independent mechanism finish its initial three-platform deployment before
	# starting the first laser; subsequent cycles retain the normal case timing.
	if releaser_release_count < 3:
		return
	state = ST_SHOOTER_DOWN
	timer = 0x0E

func _tick_shooter_down() -> void:
	timer -= 1
	if timer >= 0:
		shooter_sprite.position.y += 1
		return
	state = ST_CHARGE
	timer = 0x40
	beam_stage = 0
	beam_visible = true
	beam_active = false
	laser_sprite.visible = true
	_set_frame(laser_sprite, "boss", 13)

func _tick_charge() -> void:
	timer -= 1
	# Source laser flicker slows as it charges. Keep the same visual idea while
	# preserving the exact $40 wait owned by the mother case.
	laser_sprite.visible = ((frame_counter >> maxi(0, mini(4, timer >> 4))) & 1) == 0
	if timer >= 0:
		return
	laser_sprite.visible = true
	state = ST_LASER_EXTEND
	beam_stage = 0
	timer = 0

func _tick_laser_extend() -> void:
	timer += 1
	if timer < 4:
		return
	timer = 0
	beam_stage += 1
	if beam_stage <= 4:
		_set_frame(laser_sprite, "boss", 14 + beam_stage)
		return
	beam_stage = 4
	beam_active = true
	state = ST_LASER_MOVE
	timer = 0x80
	var p: SonicPlayer = manager.player
	direction = 1 if p != null and p.pixel_x() >= _boss_x() else -1
	vx = direction * 0x80

func _tick_laser_move() -> void:
	timer -= 1
	_bounce_case_bounds()
	_move_case()
	if timer >= 0:
		return
	beam_active = false
	beam_visible = false
	laser_sprite.visible = false
	state = ST_SHOOTER_UP
	timer = 0x0E
	vx = 0

func _tick_shooter_up() -> void:
	timer -= 1
	if timer >= 0:
		shooter_sprite.position.y -= 1
		return
	state = ST_CLOSE
	animation_timer = 0

func _tick_close() -> void:
	animation_timer += 1
	# Ani_objC5 animation 1: 3,2,1,0,0.
	var frame: int = maxi(0, 3 - int(animation_timer / 4.0))
	_set_frame(case_sprite, "boss", frame)
	if animation_timer < 16:
		return
	state = ST_PATROL
	timer = 0x70
	var p: SonicPlayer = manager.player
	direction = 1 if p != null and p.pixel_x() >= _boss_x() else -1
	vx = direction * 0x100

func _bounce_case_bounds() -> void:
	var bx: int = _boss_x()
	if vx > 0 and bx >= RIGHT_X:
		boss_x_fixed = RIGHT_X << 16
		vx = -absi(vx)
	elif vx < 0 and bx <= LEFT_X:
		boss_x_fixed = LEFT_X << 16
		vx = absi(vx)

func _check_case_collision() -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = _boss_x()
	var by: int = _boss_y()
	if absi(p.pixel_x() - bx) > 0x20 + p.width_radius or absi(p.pixel_y() - by) > 0x18 + p.height_radius:
		return
	if not p.can_attack_object():
		p.apply_hazard_hit(bx)
		return
	_rebound_player(p)
	if invulnerable_timer > 0:
		return
	hits -= 1
	invulnerable_timer = 0x20
	SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
	if hits <= 0:
		_begin_defeat()

func _rebound_player(p: SonicPlayer) -> void:
	if p.vel_y >= 0:
		p.vel_y = -maxi(0x200, absi(p.vel_y))
	else:
		p.vel_y = GenesisMath.s16(-p.vel_y)

func _begin_defeat() -> void:
	state = ST_DEFEAT
	timer = 0xEF
	vx = 0
	vy = 0
	beam_active = false
	beam_visible = false
	laser_sprite.visible = false
	manager.add_score(1000)
	eggman_defeat_timer = 0xC0
	releaser_state = 4
	for item in platforms:
		item["destroying"] = true

func _tick_defeat() -> void:
	timer -= 1
	if timer >= 0:
		if (frame_counter & 7) == 0:
			var ex: int = _boss_x() + int(manager.next_random_word() & 0x3F) - 0x20
			var ey: int = _boss_y() + int((manager.next_random_word() >> 3) & 0x3F) - 0x20
			manager.spawn_boss_explosion(ex, ey)
		return
	# ObjC5_End restores WFZ music and Camera_Max_Y_pos=$720. The retail end
	# Tornado ($B2 subtype $54) owns the subsequent Death Egg handoff.
	SonicAudio.play_music(SonicAudio.MUS_S2_WFZ, true)
	manager.boss_screen_lock = false
	manager.boss_limit_right = maxi(manager.boss_limit_right, 0x2E80)
	manager.set_boss_defeated()
	alive = false
	queue_free()

func _platform_slot_active(slot: int) -> bool:
	for item in platforms:
		if int(item.get("slot", -1)) == slot and not bool(item.get("destroying", false)):
			var raw = item.get("sprite")
			if raw != null and is_instance_valid(raw):
				return true
	return false

func _spawn_released_platform(slot: int) -> void:
	if _platform_slot_active(slot):
		return
	var sp: Sprite2D = _make_sprite("boss", 7, 3)
	var px: int = releaser_x_fixed >> 16
	var py: int = releaser_y_fixed >> 16
	releaser_release_count += 1
	platforms.append({
		"sprite": sp,
		"xf": px << 16,
		"yf": py << 16,
		"vx": 0,
		"vy": 0x100,
		"base_y": py,
		"timer": 0x60,
		"phase": 0,
		"slot": slot,
		"destroying": false,
	})

func _tick_releaser() -> void:
	if state < ST_PRELUDE:
		return
	if releaser_state == 0:
		return
	if releaser_state == 1:
		# ObjC5_PlatformReleaserDown: $40 frames at Y velocity $40 (8.8).
		releaser_timer -= 1
		if releaser_timer <= 0:
			releaser_state = 2
			releaser_timer = 0x10
			return
		releaser_y_fixed += 0x40 << 8
		return
	if releaser_state == 2:
		releaser_timer -= 1
		if releaser_timer > 0:
			return
		releaser_state = 3
		releaser_timer = 0
	if releaser_state == 3:
		releaser_timer -= 1
		if releaser_timer > 0:
			return
		# The visible release cadence in the native 60 Hz loop was one cycle too
		# slow during the initial deployment. Use $40 until all three first slots
		# are present, then return to the retail $80 replacement cadence.
		releaser_timer = 0x40 if releaser_release_count < 3 else 0x80
		# Source increments objoff_2E before selecting slot: 1,2,0.
		releaser_slot = (releaser_slot + 1) % 3
		_spawn_released_platform(releaser_slot)

func _tick_eggman() -> void:
	if eggman_defeat_timer < 0:
		return
	if eggman_defeat_timer == 0:
		eggman_sprite.visible = false
		eggman_platform_sprite.visible = false
		eggman_defeat_timer = -1
		return
	eggman_defeat_timer -= 1
	eggman_world_y += 1

func _tick_platforms() -> void:
	var p: SonicPlayer = manager.player
	for item in platforms:
		var sp: Sprite2D = item["sprite"] as Sprite2D
		if sp == null or not is_instance_valid(sp):
			continue
		if bool(item.get("destroying", false)):
			sp.visible = ((frame_counter >> 2) & 1) == 0
			continue
		var old_x: int = int(item["xf"]) >> 16
		var old_y: int = int(item["yf"]) >> 16
		var tm: int = int(item["timer"]) - 1
		item["timer"] = tm
		if int(item["phase"]) == 0:
			if tm <= 0:
				item["phase"] = 1
				item["timer"] = 0x60
				item["vx"] = -0x100
				item["base_y"] = old_y
		else:
			if tm <= 0:
				item["timer"] = 0xC0
				item["vx"] = -int(item["vx"])
			var dvy: int = 4 if old_y < int(item["base_y"]) else -4
			item["vy"] = GenesisMath.s16(int(item["vy"]) + dvy)
		item["xf"] = int(item["xf"]) + (GenesisMath.s16(int(item["vx"])) << 8)
		item["yf"] = int(item["yf"]) + (GenesisMath.s16(int(item["vy"])) << 8)
		var px: int = int(item["xf"]) >> 16
		var py: int = int(item["yf"]) >> 16
		var pi: int = int(item["slot"])
		var support_id: int = SUPPORT_BASE - pi
		if p != null and p.standing_on_object and p.support_record_index == support_id:
			p.move_with_supported_object(support_id, px - old_x, py - old_y, px - 0x10, px + 0x10, py - 8)
		if p != null:
			p.resolve_platform_top(px - 0x10, px + 0x10, py - 8, support_id)
		# Platform animation 3 cycles frames 7..11 at delay 3.
		_set_frame(sp, "boss", 7 + ((frame_counter >> 2) % 5))
		sp.position = Vector2(px - _boss_x(), py - _boss_y())
		# The spiked underside is a separate source child object.
		if p != null and not p.dead and not p.hurt_state:
			if absi(p.pixel_x() - px) <= 0x10 + p.width_radius and p.pixel_y() > py + 4 and p.pixel_y() < py + 0x18:
				p.apply_hazard_hit(px)

func _tick_walls() -> void:
	if state < ST_PRELUDE or state >= ST_DEFEAT:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead:
		return
	p.resolve_solid_box_contact(LEFT_WALL_WORLD_X, WALL_WORLD_Y, 0x0B, 0x40, true, SUPPORT_BASE - 10)
	p.resolve_solid_box_contact(RIGHT_WALL_WORLD_X, WALL_WORLD_Y, 0x0B, 0x40, true, SUPPORT_BASE - 11)

func _check_laser_hazard() -> void:
	if not beam_active:
		return
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx: int = _boss_x()
	var top: int = _boss_y() + 0x20
	var bottom: int = top + 0x80
	if absi(p.pixel_x() - bx) <= 0x0C + p.width_radius and p.pixel_y() >= top - p.height_radius and p.pixel_y() <= bottom + p.height_radius:
		p.apply_hazard_hit(bx)

func _update_visuals() -> void:
	var bx: int = _boss_x()
	var by: int = _boss_y()
	position = Vector2(bx, by)
	case_sprite.position = Vector2.ZERO
	shooter_sprite.position.x = 0
	# These children were allocated from the case but then own independent world
	# coordinates in the 68000 OST. Counter-transform them against this Node so
	# the case/beam can patrol without dragging the arena machinery with it.
	left_wall_sprite.position = Vector2(LEFT_WALL_WORLD_X - bx, WALL_WORLD_Y - by)
	right_wall_sprite.position = Vector2(RIGHT_WALL_WORLD_X - bx, WALL_WORLD_Y - by)
	releaser_sprite.position = Vector2((releaser_x_fixed >> 16) - bx, (releaser_y_fixed >> 16) - by)
	eggman_sprite.position = Vector2(EGGMAN_WORLD_X - bx, eggman_world_y - by)
	eggman_platform_sprite.position = Vector2(EGGMAN_WORLD_X - bx, eggman_world_y + 0x26 - by)
	# Source walls flicker every other frame until the defeated cleanup.
	var walls_enabled: bool = state >= ST_PRELUDE and state < ST_DEFEAT
	releaser_sprite.visible = state >= ST_PRELUDE and state < ST_DEFEAT
	var wall_on: bool = walls_enabled and (frame_counter & 1) == 0
	left_wall_sprite.visible = wall_on
	right_wall_sprite.visible = wall_on
	if beam_visible:
		laser_sprite.position = Vector2(0, 0x0D + beam_stage * 0x10)
	var alpha: float = 0.45 if invulnerable_timer > 0 and (frame_counter & 2) == 0 else 1.0
	var c: Color = case_sprite.modulate
	c.a = alpha
	case_sprite.modulate = c
	# Ani_objC5_objC6 animation 1 is delay 5, frames 6,7,$FF. Frames 0/1
	# are unrelated Robotnik poses and caused the hurt/laugh alternation.
	if eggman_sprite != null:
		_set_frame(eggman_sprite, "boss_eggman", 6 + ((int(frame_counter / 6.0)) & 1))

func _make_sprite(folder: String, frame: int, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	add_child(s)
	_set_frame(s, folder, frame)
	return s

func _set_frame(s: Sprite2D, folder: String, frame: int) -> void:
	if s == null:
		return
	var path: String = "res://assets/objects/s2_wfz/%s/%02d.png" % [folder, frame]
	if String(s.get_meta("wfz_boss_frame", "")) == path:
		return
	var tex: Texture2D = _texture_cache.get(path) as Texture2D
	if tex == null and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
		if tex != null:
			_texture_cache[path] = tex
	if tex != null:
		s.texture = tex
		s.set_meta("wfz_boss_frame", path)
