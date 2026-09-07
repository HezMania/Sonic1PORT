class_name S2CNZTraversalObject
extends GenesisLevelObject

var sprite: Sprite2D
var base_sprite: Sprite2D
var state: int = 0
var timer: int = 0
var cooldown: int = 0
var frame_timer: int = 0
var compression: int = 0
var press_divider: int = 0
var launcher_flash_timer: int = 0
var launcher_flash_frame: int = 1
var captured: bool = false
var old_axis_side: int = 0
var origin_x: int = 0
var origin_y: int = 0
var object_fixed_x: int = 0
var object_fixed_y: int = 0
var object_vel_x: int = 0
var object_vel_y: int = 0
var initial_y: int = 0
var elevator_displacement: int = 0
var bumper_direction: int = 0

const FLIPPER_SLOPE_0: Array[int] = [7,7,7,7,7,7,7,8,9,10,11,10,9,8,7,6,5,4,3,2,1,0,-1,-2,-3,-4,-5,-6,-7,-8,-9,-10,-11,-12,-13,-14]
const FLIPPER_SLOPE_1: Array[int] = [6,6,6,6,6,6,7,8,9,9,9,9,9,9,8,8,8,8,8,8,7,7,7,7,6,6,6,6,5,5,4,4,4,4,4,4]
const FLIPPER_SLOPE_2: Array[int] = [5,5,5,5,5,6,7,8,9,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,17,17,16,16,16,16,16,16,16,16]
const FLIPPER_RAW_HALF_WIDTH := 0x18
const FLIPPER_SOLID_THICKNESS := 0x0C

func initialize_object() -> void:
	origin_x = spawn_x
	origin_y = spawn_y
	match object_id:
		0x44: _init_round_bumper()
		0x72: _init_conveyor()
		0x84: _init_pinball_switch()
		0x85: _init_launcher()
		0x86: _init_flipper()
		0xD4: _init_big_block()
		0xD5: _init_elevator()
		0xD7: _init_hex_bumper()

func tick() -> void:
	if cooldown > 0: cooldown -= 1
	match object_id:
		0x44: _tick_round_bumper()
		0x72: _tick_conveyor()
		0x84: _tick_pinball_switch()
		0x85: _tick_launcher()
		0x86: _tick_flipper()
		0xD4: _tick_big_block()
		0xD5: _tick_elevator()
		0xD7: _tick_hex_bumper()

func _init_round_bumper() -> void:
	active_width = 0x10
	sprite = make_sprite("res://assets/objects/s2_cnz/round_bumper/00.png", 1)

func _tick_round_bumper() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead: return
	if frame_timer > 0:
		frame_timer -= 1
		set_sprite_frame(sprite, "s2_cnz/round_bumper", 1 if ((frame_timer >> 2) & 1) == 1 else 0)
	else:
		set_sprite_frame(sprite, "s2_cnz/round_bumper", 0)
	if cooldown > 0: return
	var dx: int = p.pixel_x() - int(position.x)
	var dy: int = p.pixel_y() - int(position.y)
	if dx * dx + dy * dy > 22 * 22: return
	# Obj44 feeds (bumper - Sonic) to CalcAngle, offsets it by Timer_frames&3,
	# then applies a fixed -$700 radial impulse.
	var angle_byte: int = (GenesisMath.calc_angle(-dx, -dy) + (Engine.get_physics_frames() & 3)) & 0xFF
	p.vel_x = GenesisMath.s16((GenesisMath.cosine(angle_byte) * -0x700) >> 8)
	p.vel_y = GenesisMath.s16((GenesisMath.sine(angle_byte) * -0x700) >> 8)
	p.in_air = true
	p.jumping = false
	p.clear_object_support()
	cooldown = 8
	frame_timer = 20
	SonicAudio.play_sfx(SonicAudio.SFX_BUMPER)

func _init_conveyor() -> void:
	active_width = maxi(0x10, (subtype & 0x7F) << 4)
	visible = false

func _tick_conveyor() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead or p.in_air: return
	var half_w: int = (subtype & 0x7F) << 4
	var half_h: int = 0x70 if (subtype & 0x80) != 0 else 0x30
	if absi(p.pixel_x() - spawn_x) >= half_w: return
	if absi(p.pixel_y() - spawn_y) >= half_h: return
	var speed: int = -2 if x_flip else 2
	p.force_add_pixel_offset(speed, 0)

func _init_pinball_switch() -> void:
	active_width = 0x10
	visible = false
	var p: SonicPlayer = player()
	if p == null: return
	old_axis_side = _pinball_axis_side(p)

func _pinball_axis_side(p: SonicPlayer) -> int:
	if (subtype & 4) != 0:
		return 1 if p.pixel_y() >= spawn_y else -1
	return 1 if p.pixel_x() >= spawn_x else -1

func _tick_pinball_switch() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead: return
	var side: int = _pinball_axis_side(p)
	if old_axis_side == 0:
		old_axis_side = side
		return
	if side == old_axis_side: return
	var spans: Array[int] = [0x20, 0x40, 0x80, 0x100]
	var span: int = spans[subtype & 3]
	var within: bool
	if (subtype & 4) != 0:
		within = absi(p.pixel_x() - spawn_x) < span
	else:
		within = absi(p.pixel_y() - spawn_y) < span
	if within:
		# With normal orientation, crossing negative->positive enables pinball mode;
		# x-flipped switches reverse that meaning exactly like Obj84.
		var positive_crossing: bool = old_axis_side < side
		var enable: bool = positive_crossing != x_flip
		p.set_s2_pinball_mode(enable)
	old_axis_side = side

func _init_launcher() -> void:
	active_width = 0x23
	var diagonal: bool = subtype != 0
	var folder: String = "s2_cnz/launcher_diagonal" if diagonal else "s2_cnz/launcher_vertical"
	sprite = make_sprite("res://assets/objects/%s/01.png" % folder, 1)
	base_sprite = make_sprite("res://assets/objects/%s/02.png" % folder, 0)
	if diagonal:
		base_sprite.position = Vector2.ZERO
	else:
		base_sprite.position.y = 0x20

func _launcher_diagonal() -> bool:
	return subtype != 0

func _tick_launcher() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead: return
	var diagonal: bool = _launcher_diagonal()
	var folder: String = "s2_cnz/launcher_diagonal" if diagonal else "s2_cnz/launcher_vertical"
	var offset: int = compression >> 1 if diagonal else compression
	sprite.position = Vector2(float(-offset if diagonal else 0), float(offset))
	set_sprite_frame(base_sprite, folder, 3 if compression >= 0x10 else 2)
	set_sprite_frame(sprite, folder, launcher_flash_frame if captured else 1)

	if captured:
		if diagonal:
			p.force_set_pixel_position(int(position.x) + 0x13 - offset, int(position.y) - 0x13 + offset)
		else:
			p.force_set_pixel_position(int(position.x), int(position.y) - 0x2E + offset)
		p.vel_x = 0; p.vel_y = 0; p.inertia = 0
		if p.jump_held:
			press_divider += 1
			var cap: int = 0x1C if diagonal else 0x20
			if press_divider >= 4:
				press_divider = 0
				compression = mini(cap, compression + 1)

			# Obj85 objoff_33: flash cadence is derived from remaining travel.
			# The interval falls from $10/$E frames at no compression toward zero
			# at full compression, so the yellow flash visibly accelerates.
			launcher_flash_timer -= 1
			if launcher_flash_timer < 0:
				launcher_flash_timer = (cap - compression) >> 1
				launcher_flash_frame = 1 if launcher_flash_frame == 5 else 5
			else:
				# loc_2ADF8/loc_2AFF8 force normal mapping frame 1 between flashes.
				launcher_flash_frame = 1
		elif compression > 0:
			_release_launcher(p, diagonal)
		else:
			launcher_flash_frame = 1
		return

	# Unloaded plungers relax four pixels per frame in the source.
	compression = maxi(0, compression - 4)
	launcher_flash_timer = 0
	launcher_flash_frame = 1
	if p.vel_y < 0: return
	var contact: int
	if diagonal:
		contact = p.resolve_solid_box_contact(int(position.x) - offset, int(position.y) + offset, 0x23, 8, true, record_index)
	else:
		contact = SonicPlayer.SOLID_TOP if p.resolve_platform_top(int(position.x)-0x23, int(position.x)+0x23, int(position.y)-0x20+offset, record_index) else SonicPlayer.SOLID_NONE
	if contact == SonicPlayer.SOLID_NONE: return
	captured = true
	launcher_flash_timer = 0
	launcher_flash_frame = 1
	p.object_control_override = true
	if not p.rolling:
		p.rolling = true
		p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
		p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH
	p.vel_x = 0; p.vel_y = 0; p.inertia = 0

func _release_launcher(p: SonicPlayer, diagonal: bool) -> void:
	captured = false
	p.object_control_override = false
	p.clear_object_support()
	p.in_air = true
	if diagonal:
		var power: int = (compression + 4) << 7
		p.vel_x = power
		p.vel_y = -power
		p.inertia = 0x800
		if GenesisMath.s8(subtype) < 0:
			# Retail $81 plungers leave Sonic attached to the -$20 surface angle.
			p.inertia = power
			p.facing_left = false
			p.in_air = false
			p.angle = 0xE0
	else:
		var power: int = (compression + 0x10) << 7
		p.vel_x = 0
		p.vel_y = -power
		p.inertia = 0x800
	compression = 0
	press_divider = 0
	launcher_flash_timer = 0
	launcher_flash_frame = 1
	cooldown = 6

func _init_flipper() -> void:
	active_width = 0x23
	sprite = make_sprite("res://assets/objects/s2_cnz/flipper/%02d.png" % (4 if subtype != 0 else 0), 1)

func _tick_flipper() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		if captured and p != null:
			p.object_control_override = false
		captured = false
		return
	if timer > 0:
		timer -= 1
		if subtype == 0:
			var f: int = 2 if timer > 6 else (1 if timer > 2 else 0)
			set_sprite_frame(sprite, "s2_cnz/flipper", f)
		else:
			var f: int = 5 if timer > 6 else (3 if timer > 2 else 4)
			set_sprite_frame(sprite, "s2_cnz/flipper", f)
	if subtype != 0:
		var contact: int = p.resolve_solid_box_contact(spawn_x, spawn_y, 0x13, 0x18, true, record_index)
		if cooldown == 0 and (contact == SonicPlayer.SOLID_LEFT or contact == SonicPlayer.SOLID_RIGHT):
			p.vel_x = -0x1000 if contact == SonicPlayer.SOLID_LEFT else 0x1000
			p.inertia = p.vel_x
			p.lock_time = 0x0F
			if not p.rolling:
				p.rolling = true
				p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
				p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH
			p.in_air = false
			timer = 10; cooldown = 12
		return

	# Obj86_UpwardsType calls SlopedSolid with d1=$23 and a 36-byte height
	# profile. SlopedSolid converts the 70-pixel-wide local X span to a profile
	# index with LSR #1, so each source height byte covers two horizontal pixels.
	# Phase 100 indexed the table one byte per pixel and clamped the whole right
	# half to entry 35, which made Sonic stick instead of following the flipper.
	var slope: Array[int] = FLIPPER_SLOPE_0
	if timer > 6:
		slope = FLIPPER_SLOPE_2
	elif timer > 2:
		slope = FLIPPER_SLOPE_1
	# SlopedSolid's source d1=$23 is a Sonic-center reach and includes the
	# character margin. The flipper itself is width_pixels=$18. Using $23 as a
	# raw platform half-width made adjacent flippers bridge their visible gap.
	var left_x: int = spawn_x - FLIPPER_RAW_HALF_WIDTH
	var right_x: int = spawn_x + FLIPPER_RAW_HALF_WIDTH
	var top_y: int = _flipper_surface_y(p.pixel_x(), slope)
	var stood: bool = false
	if top_y != 0x7FFFFFFF:
		if p.standing_on_object and p.support_record_index == record_index:
			stood = p.snap_supported_slope(left_x, right_x, top_y, record_index)
		else:
			stood = p.resolve_platform_top(left_x, right_x, top_y, record_index)

	if not stood:
		# Retail SlopedSolid is solid from below as well as walkable from above.
		# Use the same authored slope and d2=6 thickness (12 px total) for an
		# underside ceiling test, but keep the raw $18 body width so gaps stay open.
		if top_y != 0x7FFFFFFF and p.in_air and p.vel_y < 0 and p.pixel_x() >= left_x and p.pixel_x() <= right_x:
			var underside_y: int = top_y + FLIPPER_SOLID_THICKNESS
			var head_y: int = p.pixel_y() - p.height_radius
			var penetration: int = underside_y - head_y
			if penetration > 0 and penetration <= 0x12:
				p.force_add_pixel_offset(0, penetration)
				p.vel_y = 0
				p.clear_object_support()
		if captured:
			captured = false
			p.object_control_override = false
		return

	if not p.rolling:
		p.rolling = true
		p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
		p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH

	# loc_2B20A/loc_2B254: once Sonic is stood on an upward flipper, Obj86 takes
	# object control and forces him toward the low end. At rest mapping_frame=0,
	# therefore d1=(frame-1)=-1 px/frame, mirrored for an X-flipped flipper.
	captured = true
	p.object_control_override = true
	if cooldown == 0 and p.jump_pressed:
		_launch_upward_flipper(p)
		return

	var mapping_frame: int = 2 if timer > 6 else (1 if timer > 2 else 0)
	var slide_pixels: int = mapping_frame - 1
	# loc_2B254 negates d1 only when the flipper itself is NOT X-flipped.
	# Phase 101 mirrored this condition, which drove Sonic toward the high end.
	if not x_flip:
		slide_pixels = -slide_pixels
	if slide_pixels != 0:
		p.force_add_pixel_offset(slide_pixels, 0)
	p.vel_x = slide_pixels << 8
	p.inertia = p.vel_x
	p.vel_y = 0

func _flipper_surface_y(world_x: int, slope: Array[int]) -> int:
	var d0: int = world_x - spawn_x + 0x23
	if d0 < 0 or d0 >= 0x46:
		return 0x7FFFFFFF
	var sample: int = d0
	if x_flip:
		# `not.w d5 ; add.w d3,d5` with d3=$46 => $45-d0.
		sample = 0x45 - d0
	var index: int = clampi(sample >> 1, 0, 35)
	return spawn_y - int(slope[index])

func _launch_upward_flipper(p: SonicPlayer) -> void:
	# loc_2B290: launch strength and angle depend on distance from the hinge.
	var d0: int = p.pixel_x() - spawn_x
	if x_flip:
		d0 = -d0
	d0 += 0x23
	var magnitude: int = -((mini(d0, 0x40) << 5) + 0x800)
	var angle_byte: int = ((d0 >> 2) + 0x40) & 0xFF
	p.vel_y = GenesisMath.s16((GenesisMath.sine(angle_byte) * magnitude) >> 8)
	p.vel_x = GenesisMath.s16((GenesisMath.cosine(angle_byte) * magnitude) >> 8)
	if x_flip:
		p.vel_x = -p.vel_x
	p.in_air = true
	p.jumping = false
	p.clear_object_support()
	p.object_control_override = false
	captured = false
	timer = 12
	cooldown = 10

func _init_big_block() -> void:
	active_width = 0x2B
	sprite = make_sprite("res://assets/objects/s2_cnz/big_block/00.png", 1)
	var sx: int = spawn_x
	var sy: int = spawn_y
	if subtype == 0:
		sx += 0x60 if x_flip else -0x60
	else:
		sy += 0x60 if y_flip else -0x60
	object_fixed_x = (sx << 16) | 0x8000
	object_fixed_y = (sy << 16) | 0x8000
	position = Vector2(sx, sy)

func _tick_big_block() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var old_x: int = int(object_fixed_x >> 16)
	var old_y: int = int(object_fixed_y >> 16)
	if subtype == 0:
		object_vel_x = GenesisMath.s16(object_vel_x + (4 if origin_x > old_x else -4))
	else:
		object_vel_y = GenesisMath.s16(object_vel_y + (4 if origin_y > old_y else -4))
	object_fixed_x += object_vel_x << 8
	object_fixed_y += object_vel_y << 8
	var new_x: int = int(object_fixed_x >> 16)
	var new_y: int = int(object_fixed_y >> 16)
	position = Vector2(new_x, new_y)
	# Retail passes d1=$2B because original SolidObject compares Sonic's center
	# and that value already includes the fixed $0B player margin around the
	# block's true $20 half-width. The native solid bridge expands player extents
	# itself, so passing $2B double-counted the margin.
	p.move_with_supported_object(record_index, new_x-old_x, new_y-old_y, new_x-0x20, new_x+0x20, new_y-0x20)
	p.resolve_solid_box(new_x, new_y, 0x20, 0x20, true, record_index)

func _init_elevator() -> void:
	active_width = 0x10
	sprite = make_sprite("res://assets/objects/s2_cnz/elevator/00.png", 1)
	elevator_displacement = (subtype & 0xFF) << 2
	initial_y = spawn_y + elevator_displacement if x_flip else spawn_y - elevator_displacement
	object_fixed_y = (initial_y << 16) | 0x8000
	position.y = initial_y
	state = 0

func _tick_elevator() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var old_y: int = int(object_fixed_y >> 16)
	# ObjD5 calls ObjectMove before its state routine. States 1 and 3 therefore
	# move using the previous 8.8 velocity, then add +/-8 toward the center.
	if state == 1 or state == 3:
		object_fixed_y += object_vel_y << 8
	var y: int = int(object_fixed_y >> 16)
	if state == 0:
		_elevator_platform_top(p, y)
		if p.standing_on_object and p.support_record_index == record_index:
			state = 1
			object_vel_y = 0
	elif state == 1:
		object_vel_y = GenesisMath.s16(object_vel_y + (8 if origin_y >= y else -8))
		if object_vel_y == 0:
			var far_y: int = origin_y - elevator_displacement if x_flip else origin_y + elevator_displacement
			object_fixed_y = far_y << 16
			y = far_y
			state = 2
	elif state == 2:
		if not (p.standing_on_object and p.support_record_index == record_index):
			state = 3
			object_vel_y = 0
	else:
		object_vel_y = GenesisMath.s16(object_vel_y + (8 if origin_y >= y else -8))
		if object_vel_y == 0:
			object_fixed_y = initial_y << 16
			y = initial_y
			state = 0
	var new_y: int = int(object_fixed_y >> 16)
	position.y = new_y
	if state < 3:
		p.move_with_supported_object(record_index, 0, new_y-old_y, spawn_x-0x10, spawn_x+0x10, new_y-9)
		_elevator_platform_top(p, new_y)

func _elevator_platform_top(p: SonicPlayer, platform_y: int) -> bool:
	# PlatformObjectD5 intentionally does nothing when the character is already
	# standing on some OTHER object. Preserve that ownership rule at the entrance.
	if p.standing_on_object and p.support_record_index != record_index:
		return false
	return p.resolve_platform_top(spawn_x-0x10, spawn_x+0x10, platform_y-9, record_index)

func _init_hex_bumper() -> void:
	active_width = 0x10
	sprite = make_sprite("res://assets/objects/s2_cnz/hex_bumper/00.png", 1)
	bumper_direction = -1 if x_flip else 1

func _tick_hex_bumper() -> void:
	var p: SonicPlayer = player()
	if p == null or p.dead: return
	if timer > 0:
		timer -= 1
		set_sprite_frame(sprite, "s2_cnz/hex_bumper", 1 if state == 1 else 2)
	else:
		set_sprite_frame(sprite, "s2_cnz/hex_bumper", 0)
		state = 0
	if subtype != 0:
		position.x += bumper_direction
		if position.x <= origin_x - 0x60:
			position.x = origin_x - 0x60; bumper_direction = 1
		elif position.x >= origin_x + 0x60:
			position.x = origin_x + 0x60; bumper_direction = -1
	if cooldown > 0: return
	var dx: int = p.pixel_x() - int(position.x)
	var dy: int = p.pixel_y() - int(position.y)
	if absi(dx) > 20 or absi(dy) > 20: return
	var a: int = (GenesisMath.calc_angle(-dx, -dy) + 0x20) & 0xC0
	if a == 0x00:
		p.vel_x = -0x800; state = 2
	elif a == 0x40:
		p.vel_x = GenesisMath.s16(p.vel_x + (0x200 if dx > 0 else -0x200))
		p.vel_y = -0x800; state = 1
	elif a == 0x80:
		p.vel_x = 0x800; state = 2
	else:
		p.vel_x = GenesisMath.s16(p.vel_x + (0x200 if dx > 0 else -0x200))
		p.vel_y = 0x800; state = 1
	p.in_air = true
	p.jumping = false
	p.clear_object_support()
	cooldown = 8; timer = 16
	SonicAudio.play_sfx(SonicAudio.SFX_BUMPER)
