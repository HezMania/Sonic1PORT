class_name SLZBossSpikeball
extends Node2D

# Object $7B - Star Light boss spikeball and its explosion fragments.
# The boss drops the main ball onto one of the three subtype-$FF seesaws. It
# rests/flickers for four seconds, launches when the opposite side is depressed,
# can damage Eggman in flight, and creates four hurt fragments only when its own
# fuse expires on the seesaw.

const STATE_FALL := 0
const STATE_REST := 1
const STATE_FLIGHT := 2
const STATE_FRAGMENT := 3
const SEESAW_Y: Array[int] = [-8, -28, -47, -28, -8]

var manager: SonicObjectManager
var boss = null
var target_seesaw: SLZNativeObject = null
var alive := true
var state := STATE_FALL
var base_x := 0
var base_y := 0
var side := 0 # source obSeesawSide: 0 right, 2 left
var vel_x := 0
var vel_y := 0
var timer := 0
var flicker_delay := 10
var flicker_timer := 10
var silver := true
var sprite: Sprite2D
var fragment_tick := 0

func setup(owner: SonicObjectManager, boss_owner, seesaw: SLZNativeObject, world_x: int, world_y: int) -> void:
	manager = owner
	boss = boss_owner
	target_seesaw = seesaw
	base_x = int(seesaw.position.x)
	base_y = int(seesaw.position.y)
	position = Vector2(world_x, world_y)
	side = 2 if world_x <= base_x else 0
	z_index = 44
	sprite = _make_sprite()
	_set_ball_frame(true)

func setup_fragment(owner: SonicObjectManager, world_x: int, world_y: int, vx: int, vy: int) -> void:
	manager = owner
	state = STATE_FRAGMENT
	position = Vector2(world_x, world_y)
	vel_x = vx
	vel_y = vy
	z_index = 45
	sprite = _make_sprite()
	sprite.texture = SourceObjectArt.slz_boss_spike_fragment_texture(0)

func tick() -> void:
	if not alive:
		return
	if state != STATE_FRAGMENT and (target_seesaw == null or not is_instance_valid(target_seesaw) or not target_seesaw.alive):
		alive = false
		return
	match state:
		STATE_FALL: _tick_fall()
		STATE_REST: _tick_rest()
		STATE_FLIGHT: _tick_flight()
		STATE_FRAGMENT: _tick_fragment()
	if state != STATE_FRAGMENT:
		_react_player()

func _tick_fall() -> void:
	_object_fall()
	var landing_y = _landing_y(position.x < base_x)
	if int(position.y) < landing_y:
		return
	position.y = landing_y
	var landed_side = 2 if position.x <= base_x else 0
	timer = 240
	flicker_delay = 10
	flicker_timer = 10
	_launch_sonic_or_settle(landed_side, false)

func _tick_rest() -> void:
	var diff = absi(side - target_seesaw.seesaw_state)
	if diff != 0:
		var launch_y = -0x818
		var launch_x = -0x114
		if diff != 1:
			launch_y = -0x960
			launch_x = -0xF4
			if target_seesaw.seesaw_landing_speed >= 0x9C0:
				launch_y = -0xA20
				launch_x = -0x80
		if position.x < base_x:
			launch_x = -launch_x
		vel_x = launch_x
		vel_y = launch_y
		timer = 32
		_set_ball_frame(true)
		state = STATE_FLIGHT
		_tick_flight()
		return

	_align_to_seesaw()
	timer -= 1
	if timer <= 0:
		# The source reloads timer 32 before routine 8. That exact value is what
		# distinguishes a fuse explosion (make four fragments) from impact/return.
		_explode(true)
		return
	if timer == 120:
		flicker_delay = 5
	elif timer == 60:
		flicker_delay = 2
	flicker_timer -= 1
	if flicker_timer <= 0:
		silver = not silver
		_set_ball_frame(silver)
		flicker_timer = flicker_delay

func _tick_flight() -> void:
	if vel_y < 0:
		_object_fall()
		if int(position.y) >= base_y - 47:
			_object_fall()
	else:
		_object_fall()

	if _check_boss_collision():
		_explode(false)
		return

	if vel_y < 0:
		return
	var landing_y = _landing_y(position.x < base_x)
	if int(position.y) < landing_y:
		return
	position.y = landing_y
	var landed_side = 2 if vel_x < 0 else 0
	# A returned boss ball explodes immediately after updating the seesaw/launching
	# Sonic. It does not create the four timed-fuse fragments.
	_launch_sonic_or_settle(landed_side, true)
	_explode(false)

func _tick_fragment() -> void:
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + 0x18)
	fragment_tick += 1
	if sprite != null:
		sprite.texture = SourceObjectArt.slz_boss_spike_fragment_texture((fragment_tick >> 2) & 1)
	_react_player()
	var vw = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if int(position.x) < manager.current_screen_x - 64 or int(position.x) > manager.current_screen_x + vw + 64 or int(position.y) > manager.current_screen_y + vh + 96:
		alive = false

func _object_fall() -> void:
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	vel_y = GenesisMath.s16(vel_y + 0x38)

func _landing_y(left_side: bool) -> int:
	var frame = clampi(target_seesaw.seesaw_frame, 0, 2)
	var index = frame + (2 if left_side else 0)
	return base_y + SEESAW_Y[index]

func _align_to_seesaw() -> void:
	var left_side = side == 2
	position.x = base_x + (-40 if left_side else 40)
	position.y = _landing_y(left_side)
	vel_x = 0
	vel_y = 0

func _launch_sonic_or_settle(new_side: int, returning: bool) -> void:
	var old_frame = target_seesaw.seesaw_frame
	target_seesaw.seesaw_state = new_side
	side = new_side
	if new_side == old_frame:
		state = STATE_REST
		_align_to_seesaw()
		return
	var p = manager.player
	if p != null and p.standing_on_object and p.support_record_index == target_seesaw.record_index:
		p.clear_object_support()
		var launch_y = -vel_y
		if not returning:
			launch_y = -vel_y
		if old_frame == 1:
			launch_y = GenesisMath.s16(launch_y >> 1)
		p.vel_y = launch_y
		p.in_air = true
		p.jumping = false
		p.pushing = false
		# Sonic_ChkRoll: if he was not already rolling, force the normal roll body.
		if not p.rolling:
			p.rolling = true
			p.height_radius = 14
			p.width_radius = 7
		p.clear_object_support()
		p._sync_position()
	state = STATE_REST
	_align_to_seesaw()

func _check_boss_collision() -> bool:
	if boss == null or not is_instance_valid(boss) or not boss.alive or not boss.is_hittable():
		return false
	# Source hitboxes: boss -24..+24 and ball -8..+8.
	if absi(int(position.x) - int(boss.position.x)) > 32 or absi(int(position.y) - int(boss.position.y)) > 32:
		return false
	boss.hit_by_spikeball()
	vel_x = 0
	vel_y = 0
	return true

func _react_player() -> void:
	var p = manager.player
	if p == null or p.dead:
		return
	var radius = 8 if state == STATE_FRAGMENT else 12
	if absi(p.pixel_x() - int(position.x)) <= p.width_radius + radius and absi(p.pixel_y() - int(position.y)) <= p.height_radius + radius:
		p.apply_hazard_hit(int(position.x))

func _explode(make_fragments: bool) -> void:
	if make_fragments:
		var speeds: Array[Vector2i] = [
			Vector2i(-0x100, -0x340), Vector2i(-0xA0, -0x240),
			Vector2i(0x100, -0x340), Vector2i(0xA0, -0x240),
		]
		for speed in speeds:
			manager.spawn_slz_boss_spike_fragment(int(position.x), base_y, speed.x, speed.y)
	manager.spawn_monitor_explosion(int(position.x), int(position.y))
	alive = false

func _set_ball_frame(use_silver: bool) -> void:
	silver = use_silver
	if sprite != null:
		sprite.texture = SourceObjectArt.slz_seesaw_ball_texture(use_silver)

func _make_sprite() -> Sprite2D:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	add_child(sp)
	return sp
