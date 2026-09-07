class_name S2CPZBossObject
extends Node2D

# Retail Sonic 2 Object $5D - Chemical Plant boss.
# The original encounter is a linked group of Obj5D routines: Eggpod/Robotnik,
# upper pump, glass container, a twelve-piece suction pipe, Mega Mack and exhaust.
# This translation keeps those pieces under one Godot node while preserving the
# source arena coordinates, velocities, hit count and defeat/escape timers.

const STATE_DESCEND = 0
const STATE_MOVE_SIDE = 1
const STATE_PIPE_EXTEND = 2
const STATE_PUMP = 3
const STATE_PIPE_RETRACT = 4
const STATE_TRACK_PLAYER = 5
const STATE_GUNK_FALL = 6
const STATE_DEFEAT_EXPLODE = 7
const STATE_DEFEAT_BOUNCE = 8
const STATE_ESCAPE = 9

const START_X = 0x2B80
const START_Y = 0x4B0
const HOVER_Y = 0x4C0
const LEFT_SIDE_X = 0x2A50
const RIGHT_SIDE_X = 0x2B30
const TRACK_LEFT_X = 0x2A28
const TRACK_RIGHT_X = 0x2B70
const CAMERA_ESCAPE_MAX = 0x2C30
const PIPE_SEGMENTS = 0x0C

var manager: SonicObjectManager
var alive = true
var state = STATE_DESCEND
var timer = 0
var visual_tick = 0
var x_fixed = START_X << 16
var y_fixed = START_Y << 16
var vel_x = 0
var vel_y = 0
var facing_right = false
var side_left = false
var hits = 8
var invincibility_timer = 0
var defeated = false
var defeat_timer = 0
var boss_status_committed = false
var random_seed = 0x5D2C7A11

var pipe_visible = 0
var pipe_tick = 0
var pump_cycles_left = 0
var pump_y_offset = 0x58
var pump_delay = 0
var pump_final_hold = false
var track_drop_timer = 0

# Retail glass-container subassembly. The source keeps the palette-line-1 glass/
# arm object separate from a palette-line-3 fill object and moves the entire
# container from x=-$10 out to x=-$58 before dumping. Phase 94 reused the fill
# mapping frames as the container itself, which made the glass vanish.
var container_x_offset = -0x10
var container_fill_stage = -1
var container_fill_tick = 0
var container_spill_hold = 0

var gunk_active = false
var gunk_splash = false
var gunk_x_fixed = 0
var gunk_y_fixed = 0
var gunk_vel_x = 0
var gunk_vel_y = 0
var splash_timer = 0
var droplets: Array = []

var shell_sprite: Sprite2D
var robotnik_sprite: Sprite2D
var pump_sprite: Sprite2D
var container_sprite: Sprite2D
var container_floor_sprite: Sprite2D
var container_fill_sprite: Sprite2D
var pump_action_sprite: Sprite2D
var gunk_sprite: Sprite2D
var jets_sprite: Sprite2D
var smoke_sprite: Sprite2D
var pipe_sprites: Array[Sprite2D] = []

var last_shell_frame = -1
var last_robotnik_frame = -1
var last_pump_frame = -1
var last_container_frame = -1
var last_container_fill_frame = -1
var last_pump_action_frame = -1
var last_gunk_frame = -1
var last_jets_frame = -1
var last_smoke_frame = -1

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(START_X, START_Y)
	# Source priorities: upper pump=2, Eggpod/Robotnik=3, container/pipe=4/5.
	pump_sprite = _make_sprite(1)
	shell_sprite = _make_sprite(3)
	robotnik_sprite = _make_sprite(4)
	container_sprite = _make_sprite(5)
	container_floor_sprite = _make_sprite(5)
	container_fill_sprite = _make_sprite(5)
	pump_action_sprite = _make_sprite(5)
	gunk_sprite = _make_sprite(6)
	jets_sprite = _make_sprite(2)
	smoke_sprite = _make_sprite(2)
	for i in range(PIPE_SEGMENTS):
		var segment = _make_sprite(5)
		pipe_sprites.append(segment)
		_set_direct_texture(segment, "mechanism_pal1", 1)
		segment.visible = false
	_set_shell_frame(0)
	_set_robotnik_frame(1)
	_set_pump_frame(0)
	_set_container_frame(10)
	_set_direct_texture(container_floor_sprite, "mechanism_pal1", 11)
	_set_container_fill_frame(16)
	container_fill_sprite.visible = false
	_set_pump_action_frame(2)
	_set_gunk_frame(29)
	_set_jets_frame(0)
	_set_smoke_frame(0)
	gunk_sprite.visible = false
	pump_action_sprite.visible = false
	jets_sprite.visible = true
	smoke_sprite.visible = false
	_update_components()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	if invincibility_timer > 0:
		invincibility_timer -= 1

	if not defeated:
		_face_player()

	match state:
		STATE_DESCEND:
			_tick_descend()
		STATE_MOVE_SIDE:
			_tick_move_side()
		STATE_PIPE_EXTEND:
			_tick_pipe_extend()
		STATE_PUMP:
			_tick_pump()
		STATE_PIPE_RETRACT:
			_tick_pipe_retract()
		STATE_TRACK_PLAYER:
			_tick_track_player()
		STATE_GUNK_FALL:
			_tick_gunk_fall()
		STATE_DEFEAT_EXPLODE:
			_tick_defeat_explode()
		STATE_DEFEAT_BOUNCE:
			_tick_defeat_bounce()
		STATE_ESCAPE:
			_tick_escape()

	_tick_container_mechanism()
	_tick_droplets()
	_update_components()
	if not defeated:
		_check_boss_collision()

func _tick_descend() -> void:
	# Obj5D_Main_0: +$100 Y velocity until the internal position reaches $4C0.
	vel_y = 0x100
	_move_internal()
	if (y_fixed >> 16) >= HOVER_Y:
		y_fixed = HOVER_Y << 16
		vel_y = 0
		state = STATE_MOVE_SIDE

func _tick_move_side() -> void:
	# Obj5D_Main_2 alternates between $2B30 and $2A50 at +/-$300.
	var target = LEFT_SIDE_X if side_left else RIGHT_SIDE_X
	var px = x_fixed >> 16
	if absi(target - px) <= 3:
		x_fixed = target << 16
		vel_x = 0
		side_left = not side_left
		pipe_visible = 0
		pipe_tick = 0
		container_fill_stage = -1
		container_fill_tick = 0
		container_spill_hold = 0
		state = STATE_PIPE_EXTEND
		return
	vel_x = 0x300 if target > px else -0x300
	_move_internal()

func _tick_pipe_extend() -> void:
	# Obj5D_Pipe_2_Load creates one of the twelve pipe segments per frame.
	pipe_tick += 1
	if pipe_visible < PIPE_SEGMENTS:
		pipe_visible += 1
	if pipe_visible < PIPE_SEGMENTS:
		return
	pump_cycles_left = 2
	pump_y_offset = 0x58
	pump_delay = 0x12
	pump_final_hold = false
	state = STATE_PUMP

func _tick_pump() -> void:
	# Obj5D_Pipe_Pump uses two complete $58->0 contractions. Each eight-pixel
	# step is separated by an $12-frame timer, with a $0C hold at the last step.
	pump_delay -= 1
	if pump_delay > 0:
		return
	if pump_final_hold:
		pump_y_offset = -8
		pump_final_hold = false
		pump_cycles_left -= 1
		if pump_cycles_left > 0:
			pump_y_offset = 0x58
			pump_delay = 6
			return
		pipe_tick = 0
		state = STATE_PIPE_RETRACT
		return
	pump_y_offset -= 8
	if pump_y_offset > 0:
		pump_delay = 0x12
		return
	if pump_y_offset == 0:
		pump_final_hold = true
		pump_delay = 0x0C
		return

func _tick_pipe_retract() -> void:
	# Obj5D_Pipe_Retract deletes one segment at a time from the bottom upward.
	if pipe_visible > 0:
		pipe_visible -= 1
		return
	track_drop_timer = 0
	container_spill_hold = 0
	state = STATE_TRACK_PLAYER

func _tick_track_player() -> void:
	# Obj5D_Main_6 tracks Sonic+=$4C, one pixel/frame, clamped to $2A28..$2B70.
	var target = x_fixed >> 16
	if manager.player != null:
		target = clampi(manager.player.pixel_x() + 0x4C, TRACK_LEFT_X, TRACK_RIGHT_X)
	var px = x_fixed >> 16
	if target > px:
		x_fixed += 1 << 16
	elif target < px:
		x_fixed -= 1 << 16

	# The source container independently reaches x=-$58 before loc_2E3F2 can
	# initiate the dump. Hold for the source $12 ticks once fully extended; do
	# not spill while the glass is still tucked beside the Eggpod.
	if container_x_offset > -0x58:
		return
	container_spill_hold += 1
	if container_spill_hold >= 0x12:
		_spawn_gunk()
		state = STATE_GUNK_FALL

func _spawn_gunk() -> void:
	gunk_active = true
	gunk_splash = false
	# Obj5D_Container_Extend becomes the Mega Mack object in place, so the
	# falling chemical begins at the fully-extended glass-container origin.
	var container_x: int = -container_x_offset if facing_right else container_x_offset
	gunk_x_fixed = ((x_fixed >> 16) + container_x) << 16
	gunk_y_fixed = ((y_fixed >> 16) - 0x38) << 16
	gunk_vel_x = 0
	gunk_vel_y = 0
	splash_timer = 0
	container_fill_stage = -1
	_set_gunk_frame(29)
	gunk_sprite.visible = true

func _tick_gunk_fall() -> void:
	if not gunk_active:
		state = STATE_MOVE_SIDE
		return
	if not gunk_splash:
		gunk_vel_y = GenesisMath.s16(gunk_vel_y + 0x38)
		gunk_x_fixed += gunk_vel_x << 8
		gunk_y_fixed += gunk_vel_y << 8
		_check_gunk_collision()
		var gx = gunk_x_fixed >> 16
		var gy = gunk_y_fixed >> 16
		var floor_y = _floor_surface_y(gx, gy + 0x20)
		if (floor_y >= 0 and gy + 0x20 >= floor_y) or gy >= 0x518:
			if floor_y >= 0:
				gunk_y_fixed = (floor_y - 0x20) << 16
			_begin_gunk_splash()
			# Source sends the main vehicle immediately back to Obj5D_Main_2.
			state = STATE_MOVE_SIDE

func _begin_gunk_splash() -> void:
	gunk_splash = true
	splash_timer = 32
	_set_gunk_frame(37)
	_spawn_splash_droplets()

func _tick_container_mechanism() -> void:
	if defeated:
		return

	# Obj5D_Dripper raises status2 bit 1 roughly every 19 ticks. The separate
	# palette-line-3 extension object advances through animations $C..$17,
	# mapping directly to fill frames $10..$1B (16..27).
	if state == STATE_PUMP and container_fill_stage < 11:
		container_fill_tick += 1
		if container_fill_tick >= 19:
			container_fill_tick = 0
			container_fill_stage += 1

	# Once the container is full, loc_2E4CE extends its signed X offset from
	# -$10 to -$58 one pixel at a time. It remains fully extended through the
	# tracking/dump phase. After the chemical is released it retracts likewise.
	if container_fill_stage >= 11 and state in [STATE_PUMP, STATE_PIPE_RETRACT, STATE_TRACK_PLAYER]:
		container_x_offset = maxi(-0x58, container_x_offset - 1)
	elif state in [STATE_GUNK_FALL, STATE_MOVE_SIDE, STATE_PIPE_EXTEND] and container_fill_stage < 0:
		container_x_offset = mini(-0x10, container_x_offset + 1)

func _tick_droplets() -> void:
	if gunk_active and gunk_splash:
		splash_timer -= 1
		var frame = 37 + clampi(int((32 - maxi(0, splash_timer)) / 9), 0, 2)
		_set_gunk_frame(frame)
		if splash_timer <= 0:
			gunk_active = false
			gunk_sprite.visible = false
	for entry in droplets:
		if not bool(entry.get("alive", false)):
			continue
		entry["vy"] = GenesisMath.s16(int(entry["vy"]) + 0x38)
		entry["x"] = int(entry["x"]) + (int(entry["vx"]) << 8)
		entry["y"] = int(entry["y"]) + (int(entry["vy"]) << 8)
		var sprite = entry["sprite"] as Sprite2D
		var wx = int(entry["x"]) >> 16
		var wy = int(entry["y"]) >> 16
		sprite.position = Vector2(wx - (x_fixed >> 16), wy - (y_fixed >> 16))
		if wy > 0x560:
			entry["alive"] = false
			sprite.visible = false

func _spawn_splash_droplets() -> void:
	for entry in droplets:
		var old_sprite = entry.get("sprite") as Sprite2D
		if old_sprite != null:
			old_sprite.queue_free()
	droplets.clear()
	for i in range(4):
		var sprite = _make_sprite(6)
		_set_direct_texture(sprite, "mechanism_pal3", 9)
		var vx = [-0x180, -0x80, 0x80, 0x180][i]
		var vy = [-0x480, -0x3C0, -0x420, -0x500][i]
		droplets.append({"sprite":sprite, "x":gunk_x_fixed, "y":gunk_y_fixed + (0x18 << 16), "vx":vx, "vy":vy, "alive":true})

func _check_gunk_collision() -> void:
	var p = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var gx = gunk_x_fixed >> 16
	var gy = gunk_y_fixed >> 16
	if absi(p.pixel_x() - gx) <= 0x10 + p.width_radius and absi(p.pixel_y() - gy) <= 0x20 + p.height_radius:
		p.apply_hazard_hit(gx)

func _tick_defeat_explode() -> void:
	defeat_timer -= 1
	if (visual_tick & 7) == 0:
		var off = _random_explosion_offset()
		manager.spawn_boss_explosion((x_fixed >> 16) + off.x, (y_fixed >> 16) + off.y)
	if defeat_timer >= 0:
		return
	facing_right = true
	vel_x = 0
	defeat_timer = -0x26
	state = STATE_DEFEAT_BOUNCE

func _tick_defeat_bounce() -> void:
	# Obj5D_Main_A: fall for $26 ticks, reverse into a short rise, then pause.
	defeat_timer += 1
	if defeat_timer < 0:
		vel_y = GenesisMath.s16(vel_y + 0x18)
	elif defeat_timer == 0:
		vel_y = 0
	elif defeat_timer < 0x30:
		vel_y = GenesisMath.s16(vel_y - 8)
	elif defeat_timer == 0x30:
		vel_y = 0
		if not boss_status_committed:
			boss_status_committed = true
			manager.set_boss_defeated()
			SonicAudio.play_music(SonicAudio.MUS_S2_CPZ, true)
	elif defeat_timer >= 0x38:
		vel_x = 0x400
		vel_y = -0x40
		state = STATE_ESCAPE
	_move_internal()

func _tick_escape() -> void:
	# Obj5D_Main_C: $400 X, -$40 Y and open Camera_Max_X_pos by two each frame.
	_move_internal()
	manager.unlock_s2_cpz_boss_right_boundary()
	var view_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if manager.boss_limit_right >= CAMERA_ESCAPE_MAX and (x_fixed >> 16) > manager.current_screen_x + view_width + 96:
		alive = false

func _move_internal() -> void:
	x_fixed += vel_x << 8
	y_fixed += vel_y << 8

func _face_player() -> void:
	if manager.player == null:
		return
	facing_right = manager.player.pixel_x() > (x_fixed >> 16)

func _check_boss_collision() -> void:
	if invincibility_timer > 0:
		return
	var p = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	var bx = x_fixed >> 16
	var by = y_fixed >> 16
	if absi(p.pixel_x() - bx) > 0x20 + p.width_radius:
		return
	if absi(p.pixel_y() - by) > 0x18 + p.height_radius:
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

func _begin_defeat() -> void:
	if defeated:
		return
	defeated = true
	manager.add_score(1000)
	pipe_visible = 0
	pump_action_sprite.visible = false
	container_sprite.visible = false
	container_floor_sprite.visible = false
	container_fill_sprite.visible = false
	gunk_active = false
	gunk_sprite.visible = false
	for entry in droplets:
		var sprite = entry.get("sprite") as Sprite2D
		if sprite != null:
			sprite.visible = false
	defeat_timer = 0xB3
	vel_x = 0
	vel_y = 0
	state = STATE_DEFEAT_EXPLODE
	_set_robotnik_frame(6)

func _update_components() -> void:
	var hover = int(round(sin(float((visual_tick * 2) & 0xFF) * TAU / 256.0) * 4.0))
	position = Vector2(x_fixed >> 16, (y_fixed >> 16) + hover)
	var flip = facing_right
	shell_sprite.flip_h = flip
	robotnik_sprite.flip_h = flip
	pump_sprite.flip_h = flip
	container_sprite.flip_h = flip
	container_floor_sprite.flip_h = flip
	container_fill_sprite.flip_h = flip
	pump_action_sprite.flip_h = flip
	jets_sprite.flip_h = flip
	smoke_sprite.flip_h = flip

	_set_shell_frame(0)
	var robotnik_frame = 1 + ((visual_tick >> 3) & 1)
	if defeated:
		robotnik_frame = 6
	elif invincibility_timer > 0:
		robotnik_frame = 5
	elif manager.player != null and (manager.player.hurt_state or manager.player.dead):
		robotnik_frame = 3 + ((visual_tick >> 3) & 1)
	_set_robotnik_frame(robotnik_frame)
	_set_pump_frame(0)

	# Retail container is three linked objects, not one animation replacement:
	# palette-line-1 glass/arm + its small floor piece + palette-line-3 chemical.
	# Keeping those layers separate prevents the gray fill mappings from replacing
	# the glass shell and lets frames $A/$1C/$1E shorten the arm behind the boss
	# as its x offset extends from -$10 to -$58.
	var container_local_x: int = -container_x_offset if facing_right else container_x_offset
	var container_pos := Vector2(container_local_x, -0x38)
	container_sprite.position = container_pos
	container_floor_sprite.position = container_pos
	container_fill_sprite.position = container_pos
	var shell_frame := 10
	if container_x_offset < -0x40:
		shell_frame = 30
	elif container_x_offset < -0x28:
		shell_frame = 28
	_set_container_frame(shell_frame)
	container_sprite.visible = not defeated
	container_floor_sprite.visible = not defeated
	container_fill_sprite.visible = not defeated and container_fill_stage >= 0
	if container_fill_stage >= 0:
		_set_container_fill_frame(16 + clampi(container_fill_stage, 0, 11))

	for i in range(pipe_sprites.size()):
		var segment = pipe_sprites[i]
		segment.visible = (not defeated) and i < pipe_visible
		segment.flip_h = flip
		segment.position = Vector2(0, 0x18 + i * 8)

	pump_action_sprite.visible = (not defeated) and state == STATE_PUMP
	pump_action_sprite.position = Vector2(0, 0x18 + maxi(0, pump_y_offset))
	_set_pump_action_frame(3 if pump_y_offset == 0 else 2)

	jets_sprite.visible = not defeated or state == STATE_ESCAPE
	_set_jets_frame((visual_tick >> 1) & 1)
	jets_sprite.position = Vector2.ZERO
	smoke_sprite.visible = state == STATE_ESCAPE
	if state == STATE_ESCAPE:
		_set_smoke_frame(int(visual_tick / 6) & 3)
		smoke_sprite.position = Vector2(-0x28 if facing_right else 0x28, 4)

	if gunk_active:
		gunk_sprite.position = Vector2((gunk_x_fixed >> 16) - (x_fixed >> 16), (gunk_y_fixed >> 16) - (y_fixed >> 16) - hover)

func _floor_surface_y(world_x: int, probe_y: int) -> int:
	if manager.collision == null:
		return -1
	var hit = manager.collision.find_floor(world_x, probe_y, 13, 16, 0, false)
	return probe_y + int(hit.get("distance", 0))

func _random_explosion_offset() -> Vector2i:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	return Vector2i((random_seed & 0x3F) - 32, ((random_seed >> 8) & 0x3F) - 32)

func _make_sprite(order: int) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = order
	add_child(sprite)
	return sprite

func _set_direct_texture(sprite: Sprite2D, folder: String, frame: int) -> void:
	sprite.texture = load("res://assets/objects/s2_cpz/boss/%s/%02d.png" % [folder, frame])

func _set_shell_frame(frame: int) -> void:
	if last_shell_frame == frame:
		return
	last_shell_frame = frame
	_set_direct_texture(shell_sprite, "eggpod_pal1", frame)

func _set_robotnik_frame(frame: int) -> void:
	if last_robotnik_frame == frame:
		return
	last_robotnik_frame = frame
	_set_direct_texture(robotnik_sprite, "eggpod_pal0", frame)

func _set_pump_frame(frame: int) -> void:
	if last_pump_frame == frame:
		return
	last_pump_frame = frame
	_set_direct_texture(pump_sprite, "mechanism_pal1", frame)

func _set_container_frame(frame: int) -> void:
	if last_container_frame == frame:
		return
	last_container_frame = frame
	_set_direct_texture(container_sprite, "mechanism_pal1", frame)

func _set_container_fill_frame(frame: int) -> void:
	if last_container_fill_frame == frame:
		return
	last_container_fill_frame = frame
	_set_direct_texture(container_fill_sprite, "mechanism_pal3", clampi(frame, 16, 27))

func _set_pump_action_frame(frame: int) -> void:
	if last_pump_action_frame == frame:
		return
	last_pump_action_frame = frame
	_set_direct_texture(pump_action_sprite, "mechanism_pal1", frame)

func _set_gunk_frame(frame: int) -> void:
	if last_gunk_frame == frame:
		return
	last_gunk_frame = frame
	_set_direct_texture(gunk_sprite, "mechanism_pal3", frame)

func _set_jets_frame(frame: int) -> void:
	if last_jets_frame == frame:
		return
	last_jets_frame = frame
	_set_direct_texture(jets_sprite, "jets", clampi(frame, 0, 1))

func _set_smoke_frame(frame: int) -> void:
	if last_smoke_frame == frame:
		return
	last_smoke_frame = frame
	_set_direct_texture(smoke_sprite, "smoke", clampi(frame, 0, 3))
