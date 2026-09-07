class_name MonitorObject
extends GenesisLevelObject

# Object 26 - Monitor. Phase 6 keeps the original animated shell/icon mapping,
# stable SolidObject-style standing support, and lets a rolling/jumping Sonic
# break the monitor from above instead of being converted into a platform first.

var sprite: Sprite2D
var broken := false
var anim_tick := 0
var secondary_state := 0 # 0 normal, 2 stood on, 4 falling
var fall_velocity := 0

func initialize_object() -> void:
	active_width = 15
	broken = manager.is_monitor_broken(record_index)
	sprite = make_sprite("res://assets/objects/monitor/11.png" if broken else "res://assets/objects/monitor/00.png")

func tick() -> void:
	if broken:
		return

	anim_tick += 1
	_update_monitor_animation()
	if secondary_state == 4:
		_tick_fall()

	var p = player()
	if p == null or p.dead:
		return

	# ReactToItem uses col_32x32 for monitors: an exact 16px object radius.
	# Sonic's item-reaction box is independent from his terrain-solid width:
	# 8px horizontally, and obHeight-3 vertically. Keeping these distinct is
	# important at monitor edges, where the wider SolidObject support box must
	# not win one frame before the attack/item hitbox can break the monitor.
	var item_left = int(position.x) - 16
	var item_right = int(position.x) + 16
	var item_top = int(position.y) - 16
	var item_bottom = int(position.y) + 16
	var react_half_height = maxi(0, p.height_radius - 3)
	var react_left = p.pixel_x() - 8
	var react_right = p.pixel_x() + 8
	var react_top = p.pixel_y() - react_half_height
	var react_bottom = p.pixel_y() + react_half_height
	var overlaps = react_right >= item_left and react_left <= item_right and react_bottom >= item_top and react_top <= item_bottom

	# ReactToItem happens before monitor SolidObject handling in the original
	# ExecuteObjects pass. If Sonic is in his ball state and overlaps the item
	# hitbox, break it first. The old center-distance test missed top impacts
	# because Sonic's center is ~29px above the monitor while touching it.
	# React_Monitor checks Sonic's ball animation, not generic invincibility.
	# object_attack_active preserves that start-of-frame jump/roll state across
	# terrain landing, matching the animation value ReactToItem would have seen.
	var attacking = not p.hurt_state and (p.rolling or p.object_attack_active)
	if overlaps and attacking and p.vel_y >= 0:
		_break_monitor(p)
		return

	# Monitor SolidObject itself is 30x30 (15px radius), separate from the
	# 32x32 ReactToItem box above.
	var left = int(position.x) - 15
	var right = int(position.x) + 15
	var top = int(position.y) - 15
	var bottom = int(position.y) + 15
	var player_left = p.pixel_x() - p.width_radius
	var player_right = p.pixel_x() + p.width_radius
	var player_top = p.pixel_y() - p.height_radius

	# React_Monitor: upward hit from below reverses Sonic and can knock the box
	# loose so it falls back to the terrain.
	if p.in_air and p.vel_y < 0 and player_right >= left and player_left <= right:
		var bottom_pen = bottom - player_top
		if p.pixel_y() >= int(position.y) and bottom_pen >= 0 and bottom_pen <= 16:
			p.vel_y = -p.vel_y
			p.clear_object_support()
			if secondary_state == 0:
				secondary_state = 4
				fall_velocity = -0x180
			return

	# Mon_Solid deliberately ignores its solid collision result when Sonic is
	# descending in the Roll animation. This prevents the wider 30x30 solid box
	# from catching him as a platform just outside the smaller ReactToItem box;
	# on the next movement step he enters the item box and breaks it.
	if attacking and p.vel_y >= 0:
		if secondary_state == 2:
			secondary_state = 0
		return

	# Mon_SolidSides / platform maintenance.
	if p.resolve_solid_box(int(position.x), int(position.y), 15, 15, true, record_index):
		if p.standing_on_object and p.support_top == top:
			secondary_state = 2
	else:
		if secondary_state == 2:
			secondary_state = 0

func _break_monitor(p: SonicPlayer) -> void:
	if p.vel_y > 0:
		p.vel_y = -p.vel_y
	elif p.vel_y < 0:
		p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
	p.clear_object_support()
	p.preserve_monitor_rebound_attack()
	broken = true
	SonicAudio.play_sfx(SonicAudio.SFX_BREAK_ITEM)
	secondary_state = 0
	set_sprite_frame(sprite, "monitor", 11)
	manager.mark_monitor_broken(record_index)
	manager.spawn_monitor_explosion(int(position.x), int(position.y))
	manager.spawn_monitor_powerup(int(position.x), int(position.y), subtype)

func _tick_fall() -> void:
	position.y += float(fall_velocity) / 256.0
	fall_velocity += SonicPlayer.GRAVITY
	var hit = manager.collision.find_floor(int(position.x), int(position.y) + 15, 13, 16, 0, false)
	var distance = int(hit["distance"])
	if distance < 0:
		position.y += distance
		fall_velocity = 0
		secondary_state = 0

func _update_monitor_animation() -> void:
	# Ani_Monitor: delay 1 -> each listed frame lasts two ticks.
	var icon_frame = clampi(subtype + 2, 3, 10)
	var step = anim_tick >> 1
	if subtype <= 0:
		set_sprite_frame(sprite, "monitor", step % 3)
		return
	var sequence: Array[int] = [0, icon_frame, icon_frame, 1, icon_frame, icon_frame, 2, icon_frame, icon_frame]
	set_sprite_frame(sprite, "monitor", sequence[step % sequence.size()])
