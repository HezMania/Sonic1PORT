class_name MarbleObject
extends GenesisLevelObject

# Marble Zone environment object family used by MZ1. Keeping the shared logic in
# one class mirrors the original objects' common SolidObject/platform behavior
# while each object ID retains its own source-driven subtype state.

var sprite: Sprite2D
var extra_sprite: Sprite2D
var origin_x = 0
var origin_y = 0
var vel_x = 0
var vel_y = 0
var state = 0
var timer = 0
var nudge = 0
var grass_burning = false
var current_fixed = 0
var max_fixed = 0
var rising = false
var chain_sprite: Sprite2D
var ceiling_sprite: Sprite2D
var spike_sprites: Array[Sprite2D] = []
var glass_distance_y = 144
var glass_switch_latched = false
var push_fraction = 0
var push_last_speed = 0
var push_on_lava = false
var push_geyser_active = false
var push_sink_ticks = 0
var push_drop_state = 0 # 0 grounded, 1 ledge-snap, 2 falling
var push_x_fixed = 0
var moving_block_half_h = 8
var moving_block_slide_wait = 0
var moving_block_slide_goback = false

const GRASS_SYMMETRICAL = [
	0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,
	0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F,
	0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,
	0x2F,0x2E,0x2D,0x2C,0x2B,0x2A,0x29,0x28,0x27,0x26,0x25,0x24,0x23,0x22,0x21,
	0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,
]
const GRASS_ASYMMETRICAL = [
	0x20,0x20,0x20,0x20,0x20,0x20,
	0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F,0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F,
	0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,0x40,
	0x3F,0x3E,0x3D,0x3C,0x3B,0x3A,0x39,0x38,0x37,0x36,0x35,0x34,0x33,0x32,0x31,
	0x30,0x30,0x30,0x30,0x30,0x30,
]
const CSTOM_LENGTHS = [0x7000,0xA000,0x5000,0x7800,0x3800,0x5800,0xB800]

func initialize_object() -> void:
	origin_x = spawn_x
	origin_y = spawn_y
	match object_id:
		0x2F: _init_grass()
		0x30: _init_glass()
		0x31: _init_stomper()
		0x32: _init_button()
		0x33: _init_pushblock()
		0x46: _init_brick()
		0x52: _init_moving_block()
		0x71: _init_barrier()

func tick() -> void:
	if not alive:
		return
	match object_id:
		0x2F: _tick_grass()
		0x30: _tick_glass()
		0x31: _tick_stomper()
		0x32: _tick_button()
		0x33: _tick_pushblock()
		0x46: _tick_brick()
		0x52: _tick_moving_block()
		0x71: _tick_barrier()

# -----------------------------------------------------------------------------
# Object $2F - large grass platforms
# -----------------------------------------------------------------------------
func _init_grass() -> void:
	var shape = clampi((subtype >> 4) & 3, 0, 2)
	active_width = 64 if shape < 2 else 32
	sprite = make_sprite("res://assets/objects/mz_grass/%02d.png" % shape)

func _tick_grass() -> void:
	var p = player()
	if p == null:
		return
	var old_y = int(position.y)
	var kind = subtype & 7
	var amount = 0
	match kind:
		1: amount = manager.oscillate_02()
		2: amount = manager.oscillate_06()
		3: amount = manager.oscillate_0a()
		4: amount = manager.oscillate_0e()
		5:
			if p.standing_on_object and p.support_record_index == record_index:
				nudge = mini(0x40, nudge + 4)
			else:
				nudge = maxi(0, nudge - 2)
			amount = (GenesisMath.sine(nudge & 0xFF) >> 4)
			if nudge == 0x20 and not grass_burning:
				grass_burning = true
				manager.spawn_grass_fire(self)
	if kind >= 1 and kind <= 4 and (subtype & 8) != 0:
		var ranges = [0,0x20,0x30,0x40,0x60]
		amount = int(ranges[kind]) - amount
	# LGrass_Burnable adds its sine displacement to the origin, so Sonic's
	# weight depresses the grass downward. Oscillating types 1-4 subtract the
	# source oscillator value and therefore retain their existing direction.
	if kind == 5:
		position.y = origin_y + amount
	else:
		position.y = origin_y - amount
	var dy = int(position.y) - old_y
	if p.standing_on_object and p.support_record_index == record_index:
		var carry_half = active_width + 11
		p.move_with_supported_object(record_index, 0, dy, int(position.x)-carry_half, int(position.x)+carry_half, _grass_top_for_x(p.pixel_x()))
	_resolve_grass_surface(p)

func grass_surface_y(world_x: int) -> int:
	return _grass_top_for_x(world_x)

func _grass_top_for_x(world_x: int) -> int:
	var shape = clampi((subtype >> 4) & 3, 0, 2)
	# SolidObject_Heightmap adds Sonic's solid width to the platform half-width,
	# then divides the resulting X offset by two before indexing the byte table.
	# Each height byte therefore describes two horizontal pixels.
	var expanded_half = active_width + 11
	var local = (world_x - int(position.x)) + expanded_half
	if x_flip:
		local = expanded_half * 2 - 1 - local
	var index = maxi(0, local) >> 1
	var h = 0x30
	if shape == 0:
		index = clampi(index, 0, GRASS_SYMMETRICAL.size() - 1)
		h = int(GRASS_SYMMETRICAL[index])
	elif shape == 1:
		index = clampi(index, 0, GRASS_ASYMMETRICAL.size() - 1)
		h = int(GRASS_ASYMMETRICAL[index])
	return int(position.y) - h

func _resolve_grass_surface(p: SonicPlayer) -> void:
	var left = int(position.x) - active_width - 11
	var right = int(position.x) + active_width + 11
	var top = _grass_top_for_x(p.pixel_x())
	if p.standing_on_object and p.support_record_index == record_index:
		if p.pixel_x() < left - p.width_radius or p.pixel_x() > right + p.width_radius:
			p.clear_object_support_for(record_index, true)
			return
	# The source uses SolidObject_Heightmap: sloped top plus fully solid sides and
	# underside. Resolve the shaped top first, then let the box bridge handle only
	# side/bottom contacts so it cannot flatten the heightmap.
	p.resolve_platform_top(left, right, top, record_index)
	var shape = clampi((subtype >> 4) & 3, 0, 2)
	var half_h = 48 if shape == 2 else 32
	p.resolve_solid_box_contact(int(position.x), int(position.y), active_width + 11, half_h, false, record_index)

# -----------------------------------------------------------------------------
# Object $30 - green glass pillars. MZ1 uses oscillating types 1/2.
# -----------------------------------------------------------------------------
func _init_glass() -> void:
	var kind = subtype & 7
	var short_block = kind >= 3
	active_width = 32
	glass_distance_y = 144
	glass_switch_latched = false
	sprite = make_sprite("res://assets/objects/mz_glass/%02d.png" % (2 if short_block else 0))
	extra_sprite = make_sprite("res://assets/objects/mz_glass/01.png", 1)
	# Switch/stomp pillars begin glass_distanceY pixels above their destination.
	if kind == 4:
		position.y = origin_y - glass_distance_y

func _tick_glass() -> void:
	var p = player()
	if p == null:
		return
	var old_y = int(position.y)
	var kind = subtype & 7
	var offset = 0
	match kind:
		1:
			offset = manager.oscillate_12()
			position.y = origin_y - offset
		2:
			offset = 64 - manager.oscillate_12()
			position.y = origin_y - offset
		4:
			# Type 4 latches the matching switch (upper subtype nibble) and then
			# descends from -144px toward its authored destination at 2px/frame.
			if not glass_switch_latched and manager.is_switch_pressed((subtype >> 4) & 0x0F):
				glass_switch_latched = true
			if glass_switch_latched and glass_distance_y > 0:
				glass_distance_y = maxi(0, glass_distance_y - 2)
			position.y = origin_y - glass_distance_y
		_:
			position.y = origin_y
	if extra_sprite != null:
		if kind == 1 or kind == 2:
			extra_sprite.position.y = 32 - int(offset / 2)
		elif kind == 4:
			extra_sprite.position.y = 16 - manager.oscillate_12()
		else:
			extra_sprite.position.y = 0
	var half_h = 72 if kind < 3 else 56
	var top = int(position.y) - half_h
	var dy = int(position.y) - old_y
	p.move_with_supported_object(record_index, 0, dy, int(position.x)-32, int(position.x)+32, top)
	p.resolve_solid_box_contact(int(position.x), int(position.y), 32 + 11, half_h, true, record_index)

# -----------------------------------------------------------------------------
# Object $31 - chained stomper
# -----------------------------------------------------------------------------
func _init_stomper() -> void:
	var low = subtype & 0x0F
	if (subtype & 0x80) != 0:
		low = 0
	max_fixed = int(CSTOM_LENGTHS[clampi(low,0,CSTOM_LENGTHS.size()-1)])
	current_fixed = max_fixed if low == 0 else 0
	var size_kind = (subtype >> 4) & 3
	if (subtype & 0x80) != 0:
		size_kind = 0
	active_width = [56,48,16][clampi(size_kind,0,2)]
	var frame = [0,8,9][clampi(size_kind,0,2)]
	sprite = make_sprite("res://assets/objects/mz_stomper/%02d.png" % frame)
	chain_sprite = make_sprite("res://assets/objects/mz_stomper/03.png", -1)
	ceiling_sprite = make_sprite("res://assets/objects/mz_stomper/02.png", -1)
	ceiling_sprite.position.y = -16
	if size_kind != 2:
		# Map_CStom frame $0B is five 1x4 tile pieces at x=-$2C,-$18,-4,$10,$24.
		# Use the exact reconstructed strip rather than scaled generic spike art.
		var sp = make_sprite("res://assets/objects/mz_stomper/spike_strip.png", 1)
		sp.position.y = 28
		spike_sprites.append(sp)

func _tick_stomper() -> void:
	var p = player()
	if p == null:
		return
	var low = subtype & 0x0F
	if (subtype & 0x80) != 0:
		low = 0
	if low == 0:
		if manager.is_switch_pressed(0):
			# When MZ1's push block is riding this stomper the original v_obj31ypos
			# high bit stops the rise at extension $10 so the block is not crushed
			# into the ceiling.
			var minimum_extension = 0x1000 if manager.mz1_push_block_on_stomper() else 0
			current_fixed = maxi(minimum_extension, current_fixed - 0x80)
			vel_y = 0
		else:
			_stomper_fall(false)
	elif low == 3 or low == 5:
		if absi(p.pixel_x() - int(position.x)) < 144:
			subtype = (subtype & 0xF0) | (low + 1)
	else:
		if rising:
			if timer > 0:
				timer -= 1
			else:
				current_fixed -= 0x80
				if current_fixed <= 0:
					current_fixed = 0
					vel_y = 0
					rising = false
		else:
			_stomper_fall(true)
	var old_y = int(position.y)
	position.y = origin_y + ((current_fixed >> 8) & 0xFF)
	var dy = int(position.y) - old_y
	var top = int(position.y) - 12
	p.move_with_supported_object(record_index, 0, dy, int(position.x)-active_width, int(position.x)+active_width, top)
	var contact = p.resolve_solid_box_contact(int(position.x), int(position.y), active_width, 12, true, record_index)
	if contact == SonicPlayer.SOLID_TOP and current_fixed < 0x1000:
		p.kill()
	_update_stomper_visuals(p)

func _stomper_fall(auto_cycle: bool) -> void:
	if current_fixed >= max_fixed:
		current_fixed = max_fixed
		if auto_cycle:
			rising = true
			timer = 60
		vel_y = 0
		return
	var old_vel = vel_y
	vel_y = GenesisMath.s16(vel_y + 0x70)
	current_fixed += old_vel
	if current_fixed >= max_fixed:
		current_fixed = max_fixed
		vel_y = 0
		if auto_cycle:
			rising = true
			timer = 60

func _update_stomper_visuals(p: SonicPlayer) -> void:
	var extension = (current_fixed >> 8) & 0xFF
	if chain_sprite != null:
		var chain_frame = 3 + clampi(extension >> 5, 0, 4)
		set_sprite_frame(chain_sprite, "mz_stomper", chain_frame)
		chain_sprite.position.y = -36
	if ceiling_sprite != null:
		ceiling_sprite.position.y = -extension - 16
	if not spike_sprites.is_empty():
		# Original spike child uses col_80x32|hurt beneath the main stomper.
		if absi(p.pixel_x() - int(position.x)) <= p.width_radius + 40 and absi(p.pixel_y() - (int(position.y) + 28)) <= p.height_radius + 16:
			p.apply_hazard_hit(int(position.x))

# -----------------------------------------------------------------------------
# Object $32 - button/switch
# -----------------------------------------------------------------------------
func _init_button() -> void:
	active_width = 16
	position.y += 3
	sprite = make_sprite("res://assets/objects/mz_button/00.png")

func _tick_button() -> void:
	var p = player()
	if p == null:
		return
	var contact = p.resolve_solid_box_contact(int(position.x), int(position.y), 16, 5, true, record_index)
	var pressed = contact == SonicPlayer.SOLID_TOP and p.standing_on_object and p.support_record_index == record_index
	# Bit 7 marks MZ1's special block-activated switch.
	if (subtype & 0x80) != 0 and manager.has_push_block_on_button(int(position.x), int(position.y)):
		pressed = true
	manager.set_switch_pressed(subtype & 0x0F, pressed)
	set_sprite_frame(sprite, "mz_button", 1 if pressed else 0)

# -----------------------------------------------------------------------------
# Object $33 - pushable block. MZ1 uses the single block subtype.
# -----------------------------------------------------------------------------
func _init_pushblock() -> void:
	active_width = 16 if (subtype & 1) == 0 else 64
	push_x_fixed = int(round(position.x * 65536.0))
	sprite = make_sprite("res://assets/objects/mz_pushblock/%02d.png" % (0 if active_width == 16 else 1))

func _tick_pushblock() -> void:
	var p = player()
	if p == null:
		return

	if push_on_lava:
		_tick_pushblock_on_lava(p)
		return

	# PushB_SolidAction states 6 -> 4: after leaving a ledge the block keeps its
	# ±$400 horizontal push speed just long enough to cross the next 4-pixel
	# alignment threshold, snaps to a 16-pixel X boundary, then falls vertically.
	if push_drop_state != 0:
		if push_drop_state == 1:
			push_x_fixed += vel_x << 8
			position.x = float(push_x_fixed) / 65536.0
			if (int(position.x) & 0x0C) == 0:
				position.x = int(position.x) & ~0x0F
				push_x_fixed = int(position.x) << 16
				push_last_speed = vel_x
				vel_x = 0
				push_drop_state = 2
		else:
			position.y += float(vel_y) / 256.0
			vel_y = GenesisMath.s16(vel_y + 0x18)
			var floor_hit = manager.collision.find_floor(int(position.x), int(position.y) + 15, 13, 16, 0, false)
			var fd = int(floor_hit["distance"])
			if fd <= 0:
				position.y += fd
				vel_y = 0
				push_drop_state = 0
				if int(floor_hit.get("block_id", 0)) >= 0x16A:
					push_on_lava = true
					vel_x = int(push_last_speed / 8)
					push_sink_ticks = 0
					# PushB_SolidAction clears obSubpixelY when the block lands on lava.
					position.y = float(int(position.y))
					push_x_fixed = int(round(position.x * 65536.0))
		# It remains a platform during the ledge/fall states until Sonic actually
		# leaves its top, matching PushB_SolidAction/ExitPlatform.
		var falling_top = int(position.y) - 16
		p.resolve_platform_top(int(position.x) - active_width, int(position.x) + active_width, falling_top, record_index)
		return

	# MZ1 hard-coded relationship with Object $31.
	var stomper_support = manager.mz1_stomper_support(int(position.x))
	if bool(stomper_support.get("found", false)):
		position.y = int(stomper_support["y"]) - 0x1C
		vel_y = 0
	else:
		# ObjFloorDist is sampled from the block's 15px half-height. A 16px probe
		# made the block visually enter the floor before its ledge/fall state began.
		var floor_hit = manager.collision.find_floor(int(position.x), int(position.y) + 15, 13, 16, 0, false)
		var fd = int(floor_hit["distance"])
		if fd <= 4:
			position.y += fd
			vel_y = 0

	var contact = p.resolve_solid_box_contact(int(position.x), int(position.y), active_width, 16, true, record_index)
	if p.in_air:
		return
	var move_dir = 0
	if contact == SonicPlayer.SOLID_LEFT and p.input_right:
		move_dir = 1
	elif contact == SonicPlayer.SOLID_RIGHT and p.input_left:
		move_dir = -1
	if move_dir == 0:
		return
	var probe_x = int(position.x) + move_dir * active_width
	var wall = manager.collision.find_right_wall_sensor(probe_x, int(position.y), false) if move_dir > 0 else manager.collision.find_left_wall_sensor(probe_x, int(position.y), false)
	if int(wall["distance"]) < 0:
		return

	# The native collision pass runs at the project fixed tick; in the tested
	# Godot build a one-pixel move every tick made manual pushing visibly faster
	# than the source behavior. Keep the Phase 18 half-rate cadence while still
	# using the original one-pixel PushB_SolidAction step.
	push_fraction = push_fraction ^ 1
	if push_fraction != 0:
		p.inertia = move_dir * 0x40
		p.vel_x = 0
		return

	position.x += move_dir
	push_x_fixed = int(round(position.x * 65536.0))
	p.fixed_x += move_dir << 16
	p.inertia = move_dir * 0x40
	p.vel_x = 0
	p._sync_position()
	push_last_speed = move_dir * 0x400

	# Once the supporting floor is more than four pixels away, begin source state
	# 6 (snap to ledge) instead of dropping vertically on the same frame.
	if not bool(stomper_support.get("found", false)):
		var ahead_floor = manager.collision.find_floor(int(position.x), int(position.y) + 15, 13, 16, 0, false)
		if int(ahead_floor["distance"]) > 4:
			vel_x = push_last_speed
			vel_y = 0
			push_drop_state = 1

func start_lava_geyser_launch() -> void:
	# GMake_MakeLava sets status bit 1 on its parent block and writes -$580 to
	# obVelY.  The block remains in PushB_OnLava, retaining its horizontal lava
	# speed while the geyser throws it upward.
	if not alive or not push_on_lava:
		return
	push_geyser_active = true
	vel_y = -0x580

func _tick_pushblock_on_lava(p: SonicPlayer) -> void:
	var old_x = position.x
	var old_y = position.y

	if push_geyser_active:
		# PushB_OnLava still executes SpeedToPos before testing the geyser status
		# bit, so both the existing lava X-speed and the new upward Y-speed apply.
		position.x += float(vel_x) / 256.0
		position.y += float(vel_y) / 256.0
		push_x_fixed = int(round(position.x * 65536.0))
		vel_y = GenesisMath.s16(vel_y + 0x18)

		# ObjFloorDist is sampled at the push block's 15px half-height. The source
		# considers only a negative distance a landing during the geyser arc.
		var floor_hit = manager.collision.find_floor(int(position.x), int(position.y) + 15, 13, 16, 0, false)
		var fd = int(floor_hit["distance"])
		if fd < 0:
			position.y += fd
			vel_y = 0
			push_geyser_active = false
			if int(floor_hit.get("block_id", 0)) >= 0x16A:
				# Restore the original pre-fall push velocity divided by eight and
				# clear obSubpixelY exactly as PushB_OnLava does on a lava landing.
				vel_x = int(push_last_speed / 8)
				push_on_lava = true
				push_sink_ticks = 0
				position.y = float(int(position.y))
	elif vel_x != 0:
		# SpeedToPos: $80 in 8.8 is 0.5px/frame. Preserve that fraction both on
		# the block and on Sonic rather than truncating it to whole-pixel carry.
		position.x += float(vel_x) / 256.0
		push_x_fixed = int(round(position.x * 65536.0))
		var probe_x = int(position.x) + (active_width if vel_x > 0 else -active_width)
		var wall = manager.collision.find_right_wall_sensor(probe_x, int(position.y), false) if vel_x > 0 else manager.collision.find_left_wall_sensor(probe_x, int(position.y), false)
		if int(wall["distance"]) < 0:
			position.x += int(wall["distance"]) if vel_x > 0 else -int(wall["distance"])
			push_x_fixed = int(round(position.x * 65536.0))
			vel_x = 0
	else:
		position.y += 0.125
		push_sink_ticks += 1
		if push_sink_ticks >= 160:
			request_delete(true)
			return

	var dx = position.x - old_x
	var dy = position.y - old_y
	var top = int(position.y) - 16
	p.move_with_supported_object_fractional(record_index, dx, dy, int(position.x) - active_width, int(position.x) + active_width, top)
	p.resolve_solid_box_contact(int(position.x), int(position.y), active_width, 16, true, record_index)

	# PushB_LavaPlatform calls this every frame, including while the block is in
	# a geyser arc. These positions are intentionally hard-coded in Sonic 1.
	_spawn_pushblock_lava_geysers()

func _spawn_pushblock_lava_geysers() -> void:
	if manager == null:
		return
	if int(manager.level_definition.get("zone", -1)) != LevelCatalog.ZONE_MZ:
		return
	var act = int(manager.level_definition.get("act", 0))
	var x = int(position.x)
	var offset_x = 0
	var trigger = false
	if act == 2:
		offset_x = -32
		trigger = x == 0xDD0 or x == 0xCC0 or x == 0xBA0
	elif act == 3:
		offset_x = 32
		trigger = x == 0x560 or x == 0x5C0
	if not trigger:
		return
	manager.spawn_mz_pushblock_geyser(self, x + offset_x, int(position.y) + 16)

# -----------------------------------------------------------------------------
# Object $46 - Marble bricks
# -----------------------------------------------------------------------------
func _init_brick() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/mz_brick/00.png")

func _tick_brick() -> void:
	var p = player()
	if p == null:
		return
	var kind = subtype & 7
	if kind == 2 and absi(p.pixel_x() - int(position.x)) < 0x90:
		subtype = (subtype & 0xF8) | 3
		kind = 3
	if kind == 1 or kind == 2:
		var o = manager.oscillate_16()
		if (subtype & 8) != 0:
			o = 0x10 - o
		position.y = origin_y - o
	elif kind == 3:
		position.y += float(vel_y) / 256.0
		vel_y = GenesisMath.s16(vel_y + 0x18)
		var hit = manager.collision.find_floor(int(position.x), int(position.y) + 16, 13, 16, 0, false)
		if int(hit["distance"]) < 0:
			position.y += int(hit["distance"])
			vel_y = 0
			origin_y = int(position.y)
			# REV01 Brick_Type03 only enters slow wobble when the supporting
			# 16x16 block is in MZ's lava range ($16A and above).
			if int(hit.get("block_id", 0)) >= 0x16A:
				subtype = (subtype & 0xF8) | 4
			else:
				subtype = subtype & 0xF8
	elif kind == 4:
		position.y = origin_y - (manager.oscillate_12() >> 3)
	p.resolve_solid_box_contact(int(position.x), int(position.y), 16, 16, true, record_index)

# -----------------------------------------------------------------------------
# Object $52 - MZ moving block. MZ1 uses triple-width subtype $41.
# -----------------------------------------------------------------------------
func _init_moving_block() -> void:
	var size_kind = clampi((subtype >> 4) & 7, 0, 4)
	var frame_map = {0:0, 1:1, 4:2}
	var widths = {0:16, 1:32, 2:32, 3:64, 4:48}
	active_width = int(widths.get(size_kind, 16))
	var zone = int(manager.level_definition.get("zone", -1))
	var is_lz = zone == LevelCatalog.ZONE_LZ
	var is_sbz = zone == LevelCatalog.ZONE_SBZ
	if is_lz:
		# MovingBlock selects Map_MBlockLZ / ArtTile_LZ_Moving_Block|Tile_Pal3
		# and an LZ-specific 7px half-height. The only final LZ placement is the
		# secret Act 1 raft at $09C0,$0108 subtype $07.
		active_width = 16
		moving_block_half_h = 7
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.lz_moving_block_texture()
		if (subtype & 0x0F) == 7:
			sprite.visible = false
	elif is_sbz:
		# Object $52 is shared with SBZ.  Subtype $28 uses the short striped
		# platform; every other SBZ placement uses the long red sliding floor.
		moving_block_half_h = 8
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.sbz_moving_block_texture((subtype & 0xFF) != 0x28)
	else:
		moving_block_half_h = 8
		sprite = make_sprite("res://assets/objects/mz_movingblock/%02d.png" % int(frame_map.get(size_kind,0)))

func _tick_moving_block() -> void:
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)
	var kind = subtype & 0x0F

	# LZ1 subtype $07 is the hidden shortcut raft. It is neither displayed nor
	# solid until switch 2 is pressed; the source then changes it to type $04,
	# and normal platform interaction begins on the following frame.
	if int(manager.level_definition.get("zone", -1)) == LevelCatalog.ZONE_LZ and kind == 7:
		if not manager.is_switch_pressed(2):
			sprite.visible = false
			return
		subtype = (subtype & 0xF0) | 4
		sprite.visible = true
		return

	# Types 2/4 are dormant until PlatformObject has actually put Sonic on top.
	# MZ2's lower-route platform is subtype $02 and must not move before this.
	if kind == 2 or kind == 4 or kind == 9:
		if p.standing_on_object and p.support_record_index == record_index:
			kind += 1
			subtype = (subtype & 0xF0) | kind
	elif kind == 1:
		var amount = manager.oscillate_0e()
		if x_flip:
			amount = 0x60 - amount
		position.x = origin_x - amount
	elif kind == 3 or kind == 5:
		# Source moves right at exactly 1px/frame and updates mblock_origX so the
		# normal out-of-range test follows it. Type 3 stops on wall; type 5 falls.
		var wall = manager.collision.find_right_wall_sensor(int(position.x) + active_width, int(position.y), false)
		if int(wall["distance"]) < 0:
			if kind == 3:
				subtype = subtype & 0xF0
			else:
				subtype = (subtype & 0xF0) | 6
				vel_y = 0
		else:
			position.x += 1
			origin_x = int(position.x)
	elif kind == 6:
		position.y += float(vel_y) / 256.0
		vel_y = GenesisMath.s16(vel_y + 0x18)
		var floor_hit = manager.collision.find_floor(int(position.x), int(position.y) + moving_block_half_h, 13, 16, 0, false)
		if int(floor_hit["distance"]) <= 0:
			position.y += int(floor_hit["distance"])
			vel_y = 0
			subtype = subtype & 0xF0
	elif kind == 8:
		var amount = manager.oscillate_1e()
		if x_flip:
			amount = 0x80 - amount
		position.y = origin_y - amount
	elif kind == 0x0A:
		# MBlock_SlideFast: travel exactly one platform width at 8px/frame,
		# wait five seconds, then return at the same speed. X-flipped records
		# travel left instead of right. mblock_origX remains the spawn origin.
		var step = -8 if x_flip else 8
		var target_delta = -active_width * 2 if x_flip else active_width * 2
		var delta_from_origin = int(position.x) - origin_x
		if not moving_block_slide_goback:
			if delta_from_origin == target_delta:
				moving_block_slide_wait -= 1
				if moving_block_slide_wait == 0:
					moving_block_slide_goback = true
			else:
				position.x += step
				moving_block_slide_wait = 5 * 60
		else:
			if delta_from_origin == 0:
				moving_block_slide_goback = false
				subtype = (subtype & 0xF0) | 9
			else:
				position.x -= step

	var dx = int(position.x) - old_x
	var dy = int(position.y) - old_y
	var top = int(position.y) - moving_block_half_h
	p.move_with_supported_object(record_index, dx, dy, int(position.x)-active_width, int(position.x)+active_width, top)
	# Object $52 uses PlatformObject: top-solid only.
	p.resolve_platform_top(int(position.x) - active_width, int(position.x) + active_width, top, record_index)

# -----------------------------------------------------------------------------
# Object $71 - invisible barrier
# -----------------------------------------------------------------------------
func _init_barrier() -> void:
	active_width = (((subtype & 0xF0) + 0x10) >> 1)
	visible = false

func _tick_barrier() -> void:
	var p = player()
	if p == null:
		return
	var half_h = ((subtype & 0x0F) + 1) * 8
	p.resolve_solid_box_contact(spawn_x, spawn_y, active_width, half_h, true, record_index)
