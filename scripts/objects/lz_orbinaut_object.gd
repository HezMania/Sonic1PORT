class_name LZOrbinautObject
extends GenesisLevelObject

# Object $60 - Orbinaut (LZ/SLZ shared source object).
# The four spikeballs remain in this node so fired balls can outlive a destroyed
# parent, matching the source child routines without consuming native objpos slots.

var sprite: Sprite2D
var slz_mode := false
var direction := -1
var vel_x := 0
var circle_dir := 1
var parent_frame := 0
var angry := false
var angry_anim_timer := 15
var parent_moving := false
var parent_gone := false

var ball_sprites: Array[Sprite2D] = []
var ball_angles: Array[int] = []
var ball_fired: Array[bool] = []
var ball_alive: Array[bool] = []
var ball_world: Array[Vector2] = []
var ball_vel_x: Array[int] = []
var attached_count := 4

func initialize_object() -> void:
	active_width = 12
	slz_mode = manager != null and int(manager.level_definition.get("zone", -1)) == LevelCatalog.ZONE_SLZ
	direction = 1 if x_flip else -1
	vel_x = 0x40 if x_flip else -0x40
	circle_dir = -1 if x_flip else 1
	# SLZ placements all use subtype $02. Orb_Main copies subtype to routine and
	# advances by 2, entering Orb_DisplayAndMove immediately; LZ subtype $00
	# instead enters Orb_CheckSonic and remains stationary until all balls fire.
	parent_moving = slz_mode and subtype == 2
	sprite = make_sprite("")
	sprite.flip_h = x_flip
	_set_parent_frame(0)
	for angle in [0x00, 0x40, 0x80, 0xC0]:
		var ball = make_sprite("")
		ball.texture = _orb_texture(3)
		ball_sprites.append(ball)
		ball_angles.append(angle)
		ball_fired.append(false)
		ball_alive.append(true)
		ball_world.append(position)
		ball_vel_x.append(0)
	_update_attached_ball_positions(false)

func suppress_central_despawn() -> bool:
	# Orbinaut has custom parent/child offscreen teardown in the source.
	return true

func tick() -> void:
	if not alive:
		return

	if not parent_gone:
		_tick_parent()
	_tick_balls()

	if parent_gone and not _has_live_ball():
		request_delete(false)

func _tick_parent() -> void:
	var p = player()
	if not slz_mode and p != null and not angry and not p.dead and not p.debug_free_mode:
		if absi(p.pixel_x() - int(position.x)) < 160 and absi(p.pixel_y() - int(position.y)) < 80:
			angry = true
			angry_anim_timer = 16
			_set_parent_frame(1)

	if angry and parent_frame == 1:
		# Ani_Orb.angry = delay 15, frames 1,2, afBack,1. AnimateSprite's
		# afBack subtracts one script index, so after reaching frame 2 it loops
		# back onto frame 2 itself; it does NOT alternate 1/2 indefinitely.
		angry_anim_timer -= 1
		if angry_anim_timer < 0:
			_set_parent_frame(2)

	if parent_moving:
		position.x += float(vel_x) / 256.0

	_react_parent()
	if parent_gone:
		return

	# Orb_DisplayNoMove / Orb_DisplayAndMove both use the parent object's current
	# X for the source out-of-range test and delete only still-attached balls.
	if not manager.is_world_x_on_screen(int(position.x), 128):
		_remove_parent(false)

func _tick_balls() -> void:
	for i in range(ball_sprites.size()):
		if not ball_alive[i]:
			continue
		if not ball_fired[i]:
			if parent_gone:
				_remove_ball(i)
				continue
			var angle = ball_angles[i] & 0xFF
			# Orb_CircleSpikeball checks the current angle before advancing it.
			if parent_frame == 2 and angle == 0x40:
				_fire_ball(i)
			else:
				var c = GenesisMath.cosine(angle)
				var s = GenesisMath.sine(angle)
				ball_world[i] = Vector2(
					int(position.x) + (c >> 4),
					int(position.y) + (s >> 4)
				)
				ball_angles[i] = (angle + circle_dir) & 0xFF
		else:
			var fired_world = ball_world[i]
			fired_world.x += float(ball_vel_x[i]) / 256.0
			ball_world[i] = fired_world
			if not manager.is_world_x_on_screen(int(ball_world[i].x), 32):
				_remove_ball(i)
				continue

		ball_sprites[i].position = ball_world[i] - position
		_react_spikeball(i)

func _update_attached_ball_positions(advance: bool) -> void:
	for i in range(ball_sprites.size()):
		if not ball_alive[i] or ball_fired[i]:
			continue
		var angle = ball_angles[i] & 0xFF
		ball_world[i] = Vector2(int(position.x) + (GenesisMath.cosine(angle) >> 4), int(position.y) + (GenesisMath.sine(angle) >> 4))
		ball_sprites[i].position = ball_world[i] - position
		if advance:
			ball_angles[i] = (angle + circle_dir) & 0xFF

func _fire_ball(index: int) -> void:
	ball_fired[index] = true
	attached_count = maxi(0, attached_count - 1)
	ball_vel_x[index] = 0x200 if x_flip else -0x200
	if attached_count == 0:
		parent_moving = true

func _orb_texture(frame: int):
	return SourceObjectArt.slz_orbinaut_texture(frame) if slz_mode else SourceObjectArt.lz_orbinaut_texture(frame)

func _set_parent_frame(frame: int) -> void:
	parent_frame = clampi(frame, 0, 2)
	if sprite != null:
		sprite.texture = _orb_texture(parent_frame)

func _react_parent() -> void:
	var p = player()
	if p == null or p.dead or p.drowning:
		return
	if absi(p.pixel_x() - int(position.x)) > p.width_radius + 16 or absi(p.pixel_y() - int(position.y)) > p.height_radius + 16:
		return
	if p.invincible_timer > 0 or p.can_attack_object():
		var award = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
		manager.mark_record_destroyed(record_index)
		_remove_parent(true)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	else:
		p.apply_hazard_hit(int(position.x))

func _react_spikeball(index: int) -> void:
	var p = player()
	if p == null or p.dead or p.drowning or not ball_alive[index]:
		return
	var world = ball_world[index]
	if absi(p.pixel_x() - int(world.x)) <= p.width_radius + 8 and absi(p.pixel_y() - int(world.y)) <= p.height_radius + 8:
		p.apply_hazard_hit(int(world.x))

func _remove_parent(destroyed: bool) -> void:
	if parent_gone:
		return
	parent_gone = true
	if sprite != null:
		sprite.visible = false
	for i in range(ball_sprites.size()):
		if ball_alive[i] and not ball_fired[i]:
			_remove_ball(i)
	if not destroyed:
		# Offscreen teardown allows the remembered placement to spawn again.
		attached_count = 0

func _remove_ball(index: int) -> void:
	if index < 0 or index >= ball_alive.size() or not ball_alive[index]:
		return
	ball_alive[index] = false
	ball_sprites[index].visible = false

func _has_live_ball() -> bool:
	for flag in ball_alive:
		if flag:
			return true
	return false
