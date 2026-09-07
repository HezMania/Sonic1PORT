class_name SYZObject
extends GenesisLevelObject

# Native Spring Yard object family (Phase 22 foundation; Phase 25 runtime fixes).
# $12 search light, $43 Roller, $47 bumper, $50 Yadrin,
# $56 floating blocks, $57 spike-ball chain, $58 giant spike ball.

var sprite: Sprite2D
var state := 0
var timer := 0
var frame_tick := 0
var vel_x := 0
var vel_y := 0
var direction := -1
var grounded := false
var orig_x := 0
var orig_y := 0
var angle_word := 0
var hit_cooldown := 0
var attackable := true
var has_unfolded := false
var ledge_seen := false
var child_sprites: Array[Sprite2D] = []
var child_radii: Array[int] = []
var child_hazard: Array[bool] = []
var block_half_w := 16
var block_half_h := 16
var fblock_kind := 0
var fblock_switch_index := 0
var fblock_height := 0
var fblock_latched := false
var fblock_travel := 0

const ROLLER_ROLL_FRAMES = [3, 4, 2]

const FBLOCK_SIZES = [
	Vector2i(16,16), Vector2i(32,32), Vector2i(16,32), Vector2i(32,26),
	Vector2i(16,39), Vector2i(16,16), Vector2i(8,32), Vector2i(64,16),
]

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	match object_id:
		0x12: _init_searchlight()
		0x43: _init_roller()
		0x47: _init_bumper()
		0x50: _init_yadrin()
		0x56: _init_floating_block()
		0x57: _init_spike_chain()
		0x58: _init_big_spikeball()

func suppress_central_despawn() -> bool:
	# Roller does not use the normal RememberState/out_of_range path at all.
	# Its waiting state skips the Roll_Action tail entirely, and its active states
	# use a custom CURRENT-X right-side range test instead. Keep the central object
	# manager away from Roller for its whole lifetime and reproduce that test in
	# _tick_roller().
	if object_id == 0x43:
		return true
	# REV01 Object $56 subtype $37 remains resident once switch $F starts its
	# long tunnel-block travel, matching the source's out-of-range exception.
	return object_id == 0x56 and fblock_kind == 7 and fblock_latched

func tick() -> void:
	if not alive:
		return
	frame_tick += 1
	if hit_cooldown > 0:
		hit_cooldown -= 1
	match object_id:
		0x12: _tick_searchlight()
		0x43: _tick_roller()
		0x47: _tick_bumper()
		0x50: _tick_yadrin()
		0x56: _tick_floating_block()
		0x57: _tick_spike_chain()
		0x58: _tick_big_spikeball()

# -----------------------------------------------------------------------------
# Object $12 - SYZ spinning light
# -----------------------------------------------------------------------------
func _init_searchlight() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/syz_searchlight/00.png", -20)

func _tick_searchlight() -> void:
	set_sprite_frame(sprite, "syz_searchlight", int(frame_tick / 8) % 6)

# -----------------------------------------------------------------------------
# Object $43 - Roller
# -----------------------------------------------------------------------------
func _init_roller() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/roller/00.png")
	sprite.visible = false
	grounded = false
	vel_y = 0
	state = 0
	attackable = true

func _tick_roller() -> void:
	var p = player()
	if p == null:
		return
	var was_waiting = grounded and state == 0
	if not grounded:
		position.y += float(vel_y) / 256.0
		vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
		var floor = manager.collision.find_floor(int(position.x), int(position.y) + 14, 13, 16, 0, false)
		if int(floor["distance"]) < 0:
			position.y += int(floor["distance"])
			vel_y = 0
			grounded = true
			# Roll_Action_FromLeft deliberately skips DisplaySprite while waiting.
			# Keep the grounded Roller invisible until Sonic actually activates it.
			sprite.visible = false
		return

	match state:
		0: # wait until Sonic is at least $100 to the right
			_set_roller_frame(0)
			if p.pixel_x() >= int(position.x) + 0x100:
				state = 2
				vel_x = 0x700
				attackable = false
				sprite.visible = true
				_set_roller_frame(3)
		2: # rolling
			position.x += float(vel_x) / 256.0
			_set_roller_frame(int(ROLLER_ROLL_FRAMES[(frame_tick >> 2) % 3]))
			if not has_unfolded and p.pixel_x() - int(position.x) <= 48 and p.pixel_x() >= int(position.x):
				has_unfolded = true
				state = 1
				timer = 120
				vel_x = 0
				attackable = true
				_set_roller_frame(1)
				return
			var floor = manager.collision.find_floor(int(position.x), int(position.y) + 14, 13, 16, 0, false)
			var d = int(floor["distance"])
			if d < -8 or d >= 12:
				state = 3
				if ledge_seen:
					vel_y = -0x600
				ledge_seen = true
			else:
				position.y += d
		1: # unfolded / destroyable
			timer -= 1
			_set_roller_frame(0 if timer > 96 else 1)
			if timer <= 0:
				state = 2
				vel_x = 0x700
				attackable = false
		3: # airborne rolling
			position.x += float(vel_x) / 256.0
			position.y += float(vel_y) / 256.0
			vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
			_set_roller_frame(int(ROLLER_ROLL_FRAMES[(frame_tick >> 2) % 3]))
			if vel_y >= 0:
				var floor = manager.collision.find_floor(int(position.x), int(position.y) + 14, 13, 16, 0, false)
				if int(floor["distance"]) < 0:
					position.y += int(floor["distance"])
					vel_y = 0
					state = 2
	# Roll_Action uses Roller's CURRENT X rather than its placement X and only
	# deletes once the active Roller is more than $280 beyond the aligned
	# (screenX-$80) block. The activation frame itself skips this tail in source.
	if not was_waiting and state != 0 and _roller_source_out_of_range():
		request_delete(false)
		return
	_react_roller(p)

func _roller_source_out_of_range() -> bool:
	var roller_block = int(position.x) & 0xFF80
	var screen_block = (manager.current_screen_x - 0x80) & 0xFF80
	return roller_block - screen_block > 0x280

func _set_roller_frame(frame: int) -> void:
	set_sprite_frame(sprite, "roller", clampi(frame, 0, 4))

func _react_roller(p: SonicPlayer) -> void:
	if not sprite.visible or absi(p.pixel_x() - int(position.x)) > p.width_radius + 14 or absi(p.pixel_y() - int(position.y)) > p.height_radius + 14:
		return
	if attackable and p.can_attack_object():
		_destroy_badnik(p)
		return
	if p.invincible_timer > 0:
		_destroy_badnik(p)
		return
	p.apply_hazard_hit(int(position.x))

# -----------------------------------------------------------------------------
# Object $47 - bumper
# -----------------------------------------------------------------------------
func _init_bumper() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/syz_bumper/00.png", 60)

func _tick_bumper() -> void:
	var p = player()
	if p == null or p.dead:
		return
	if hit_cooldown > 0:
		# Ani_Bump.touched: speed 3, frames 1,2,1,2, then return idle.
		var touched_frames = [1, 2, 1, 2]
		var touched_index = clampi((16 - hit_cooldown) >> 2, 0, 3)
		set_sprite_frame(sprite, "syz_bumper", int(touched_frames[touched_index]))
		return
	set_sprite_frame(sprite, "syz_bumper", 0)
	var dx = int(position.x) - p.pixel_x()
	var dy = int(position.y) - p.pixel_y()
	# ReactToItem uses the bumper's 16x16 rectangular hitbox (8px extents),
	# expanded by Sonic's current collision radii. The old 26px radial test
	# could trigger early from a corner and produce odd bounce/landing offsets.
	if absi(dx) > p.width_radius + 8 or absi(dy) > p.height_radius + 8:
		return
	var ang = GenesisMath.calc_angle(dx, dy)
	p.clear_object_support()
	p.vel_x = GenesisMath.s16((GenesisMath.cosine(ang) * -0x700) >> 8)
	p.vel_y = GenesisMath.s16((GenesisMath.sine(ang) * -0x700) >> 8)
	p.in_air = true
	p.pushing = false
	p.jumping = false
	# Bump_Hit clears the roll-jump flag, but deliberately does NOT clear
	# obStatus bit 2 (rolling). Keeping it preserves Sonic's spinning sprite
	# and 14px rolling radius through the bounce.
	p.roll_jump_lock = false
	manager.add_score(10)
	manager.spawn_points_popup(int(position.x), int(position.y), 10)
	hit_cooldown = 16
	set_sprite_frame(sprite, "syz_bumper", 1)

# -----------------------------------------------------------------------------
# Object $50 - Yadrin
# -----------------------------------------------------------------------------
func _init_yadrin() -> void:
	active_width = 20
	sprite = make_sprite("res://assets/objects/yadrin/00.png")
	sprite.visible = false
	grounded = false
	vel_y = 0
	state = 0
	direction = 1

func _tick_yadrin() -> void:
	var p = player()
	if p == null:
		return
	if not grounded:
		position.y += float(vel_y) / 256.0
		vel_y = GenesisMath.s16(vel_y + SonicPlayer.GRAVITY)
		var floor = manager.collision.find_floor(int(position.x), int(position.y) + 17, 13, 16, 0, false)
		if int(floor["distance"]) < 0:
			position.y += int(floor["distance"])
			vel_y = 0
			grounded = true
			sprite.visible = true
			_start_yadrin_move()
		return

	if state == 0:
		timer -= 1
		set_sprite_frame(sprite, "yadrin", 0)
		if timer < 0:
			_start_yadrin_move()
	else:
		position.x += float(vel_x) / 256.0
		var floor = manager.collision.find_floor(int(position.x), int(position.y) + 17, 13, 16, 0, false)
		var d = int(floor["distance"])
		var wall_d = 1
		if direction > 0:
			wall_d = int(manager.collision.find_right_wall_sensor(int(position.x) + 8, int(position.y), false)["distance"])
		else:
			wall_d = int(manager.collision.find_left_wall_sensor(int(position.x) - 8, int(position.y), false)["distance"])
		if d < -8 or d >= 12 or wall_d < 0:
			state = 0
			timer = 59
			vel_x = 0
			set_sprite_frame(sprite, "yadrin", 0)
		else:
			position.y += d
			var walk_seq = [0, 3, 1, 4, 0, 3, 2, 5]
			set_sprite_frame(sprite, "yadrin", int(walk_seq[(frame_tick >> 3) % walk_seq.size()]))
	sprite.flip_h = direction > 0
	_react_yadrin(p)

func _start_yadrin_move() -> void:
	state = 1
	direction = -direction
	vel_x = direction * 0x100
	sprite.flip_h = direction > 0

func _react_yadrin(p: SonicPlayer) -> void:
	if not sprite.visible or p.dead:
		return

	# ReactToItem collision type $CC uses the source table entry 20x16 and a
	# fixed 16-pixel Sonic reaction width. Vertically, ReactToItem trims three
	# pixels from Sonic's current height before doing the overlap test.
	var sonic_half_h = maxi(1, p.height_radius - 3)
	var sonic_left = p.pixel_x() - 8
	var sonic_right = p.pixel_x() + 8
	var sonic_top = p.pixel_y() - sonic_half_h
	var sonic_bottom = p.pixel_y() + sonic_half_h
	var object_left = int(position.x) - 20
	var object_right = int(position.x) + 20
	var object_top = int(position.y) - 16
	var object_bottom = int(position.y) + 16
	if sonic_right < object_left or sonic_left > object_right or sonic_bottom < object_top or sonic_top > object_bottom:
		return

	# The $CC special case is only hazardous during a shallow (<8px) top
	# penetration, and only over Yadrin's 24px spike strip. The strip shifts
	# with obStatus bit 0 (the same bit used by the walking direction/facing).
	var top_penetration = sonic_bottom - object_top
	if top_penetration >= 0 and top_penetration < 8:
		var spike_left = int(position.x) - (20 if sprite.flip_h else 4)
		var spike_right = spike_left + 24
		if sonic_right >= spike_left and sonic_left <= spike_right:
			p.apply_hazard_hit(int(position.x))
			return

	# Contacts outside the spike strip fall back to the ordinary enemy path.
	if p.can_attack_object():
		_destroy_badnik(p)
	else:
		p.apply_hazard_hit(int(position.x))

# -----------------------------------------------------------------------------
# Object $56 - SYZ floating blocks / switch doors
# -----------------------------------------------------------------------------
func _init_floating_block() -> void:
	var frame = (subtype >> 4) & 7
	var size: Vector2i = FBLOCK_SIZES[frame]
	block_half_w = size.x
	block_half_h = size.y
	active_width = block_half_w
	var is_lz = int(manager.level_definition.get("zone", -1)) == LevelCatalog.ZONE_LZ
	if is_lz and (frame == 6 or frame == 7):
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.lz_door_texture(frame)
	else:
		sprite = make_sprite("res://assets/objects/syz_fblock/%02d.png" % frame)

	fblock_kind = subtype & 0x0F
	fblock_switch_index = fblock_kind
	fblock_height = block_half_h * 2
	fblock_latched = false
	fblock_travel = 0

	# Negative/high-bit subtypes are not oscillator IDs. FBlock_Main stores the
	# low nibble as fb_type (switch index) and changes the active motion routine
	# to type $05, or $0C for the wide frame-7 horizontal-door form.
	if (subtype & 0x80) != 0:
		fblock_switch_index = subtype & 0x0F
		fblock_kind = 0x0C if frame == 7 else 5
		if frame == 7:
			fblock_height = 0x80
		# FBlock_Main executes the movement routine immediately after setup, so the
		# switch-door must begin at its offset position before its first display.
		if fblock_kind == 5:
			position.y = orig_y + (-fblock_height if x_flip else fblock_height)
		else:
			position.x = orig_x + ((-fblock_height + 0x80) if x_flip else fblock_height)
	elif fblock_kind == 7:
		# REV01's long moving block is hard-wired to switch $F. The source has
		# two subtype-$37 records: $1BB8 is the moving source position, while the
		# later record is an alternate stationary target used after f_obj56 is set.
		fblock_switch_index = 0x0F
		fblock_height = 0
		if spawn_x == 0x1BB8:
			if manager.syz_obj56_complete:
				request_delete(false)
		else:
			fblock_kind = 0
			if not manager.syz_obj56_complete:
				request_delete(false)

func _tick_floating_block() -> void:
	if not alive:
		return
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)
	var kind = fblock_kind

	# FBlock_LZSmallDoor_Open has one hard-coded Labyrinth Act 1 exception:
	# switch 3's door ($B08,$2E0) disables f_wtunneldisallow while Sonic is
	# still on its left side. Pressing the switch clears the blocker so the
	# current can carry Sonic through the newly opening door. Phase 33 only
	# modeled Object $0C blockers, which let this current grab Sonic too early.
	var is_lz1_wind_door = (
		int(manager.level_definition.get("zone", -1)) == LevelCatalog.ZONE_LZ
		and int(manager.level_definition.get("act", 0)) == 1
		and fblock_switch_index == 3
		and (subtype & 0x80) != 0
	)
	var blocks_lz1_wind = (
		is_lz1_wind_door
		and kind == 5
		and not fblock_latched
		and p.pixel_x() < int(position.x)
		and not manager.is_switch_pressed(3)
	)
	manager.set_lz_wind_blocker(0x560000 + record_index, blocks_lz1_wind)

	var amount = 0
	var full_range = 0
	match kind:
		1, 3:
			amount = manager.oscillate_0a()
			full_range = 0x40
		2, 4:
			amount = manager.oscillate_1e()
			full_range = 0x80
		_:
			amount = 0
	if kind == 1 or kind == 2:
		if x_flip:
			amount = -amount + full_range
		position.x = orig_x - amount
	elif kind == 3 or kind == 4:
		if x_flip:
			amount = -amount + full_range
		position.y = orig_y - amount
	elif kind == 5:
		# Switch-driven vertical door/block. It begins one full block-height away
		# from fb_origY and, once its selected switch is pressed, closes the offset
		# by exactly 2 pixels per frame until it reaches the authored coordinate.
		if not fblock_latched and manager.is_switch_pressed(fblock_switch_index):
			fblock_latched = true
		if fblock_latched and fblock_height > 0:
			fblock_height = maxi(0, fblock_height - 2)
		var y_offset = -fblock_height if x_flip else fblock_height
		position.y = orig_y + y_offset
		if fblock_latched and fblock_height == 0:
			fblock_kind = 6
			fblock_latched = false
	elif kind == 6:
		# FBlock_LZSmallDoor_Close reacts only to the alternate (bit-7) switch
		# state. LZ1's dynamic water routine hard-codes this for switch 5.
		if not fblock_latched and manager.is_switch_alt(fblock_switch_index):
			fblock_latched = true
		var full_height := block_half_h * 2
		if fblock_latched and fblock_height < full_height:
			fblock_height = mini(full_height, fblock_height + 2)
		var y_offset = -fblock_height if x_flip else fblock_height
		position.y = orig_y + y_offset
		if fblock_latched and fblock_height == full_height:
			fblock_kind = 5
			fblock_latched = false
	elif kind == 7:
		# REV01 subtype $37 waits specifically for switch $F, then advances right
		# one pixel per frame for $380 pixels. Source updates fb_origX alongside X
		# and suppresses normal offscreen deletion while the move is active.
		if not fblock_latched and manager.is_switch_pressed(0x0F):
			fblock_latched = true
			fblock_travel = 0
		if fblock_latched:
			position.x += 1
			orig_x = int(position.x)
			fblock_travel += 1
			if fblock_travel >= 0x380:
				manager.syz_obj56_complete = true
				fblock_latched = false
				fblock_kind = 0
	elif kind == 0x0C:
		# Frame-7 variant of the same switch-door setup moves horizontally.
		if not fblock_latched and manager.is_switch_pressed(fblock_switch_index):
			fblock_latched = true
		if fblock_latched and fblock_height > 0:
			fblock_height = maxi(0, fblock_height - 2)
		var x_offset = (-fblock_height + 0x80) if x_flip else fblock_height
		position.x = orig_x + x_offset
		if fblock_latched and fblock_height == 0:
			fblock_kind = 0x0D
			fblock_latched = false
	elif kind == 0x0D:
		# Horizontal type $0D has the same alternate-bit close path. It is unused
		# by final placements, but keeping it source-complete avoids a special case.
		if not fblock_latched and manager.is_switch_alt(fblock_switch_index):
			fblock_latched = true
		if fblock_latched and fblock_height < 0x80:
			fblock_height = mini(0x80, fblock_height + 2)
		var x_offset = (-fblock_height + 0x80) if x_flip else fblock_height
		position.x = orig_x + x_offset
		if fblock_latched and fblock_height == 0x80:
			fblock_kind = 0x0C
			fblock_latched = false

	var dx = int(position.x) - old_x
	var dy = int(position.y) - old_y
	var top_y = int(position.y) - block_half_h
	p.move_with_supported_object(record_index, dx, dy, int(position.x)-block_half_w, int(position.x)+block_half_w, top_y)
	p.resolve_solid_box_contact(int(position.x), int(position.y), block_half_w, block_half_h, true, record_index)

# -----------------------------------------------------------------------------
# Object $57 - small spiked-ball chain
# -----------------------------------------------------------------------------
func _init_spike_chain() -> void:
	active_width = 8
	child_sprites.clear()
	child_radii.clear()
	child_hazard.clear()
	var initial_angle = (0x40 if x_flip else 0) | (0x80 if y_flip else 0)
	angle_word = (initial_angle & 0xFF) << 8
	var count = subtype & 7
	var parent_radius = count * 16
	var child_count = count
	if (subtype & 8) != 0:
		child_count = maxi(0, child_count - 1)
	var is_lz = int(manager.level_definition.get("zone", -1)) == LevelCatalog.ZONE_LZ
	for i in range(child_count):
		var radius = parent_radius - 16 * (i + 1)
		var sp: Sprite2D
		if is_lz:
			sp = make_sprite("")
			# The zero-radius LZ child is the distinct wall/base mapping frame.
			sp.texture = SourceObjectArt.lz_spike_chain_texture(2 if radius == 0 else 0)
			child_hazard.append(false)
		else:
			sp = make_sprite("res://assets/objects/syz_small_spikeball/00.png")
			child_hazard.append(true)
		child_sprites.append(sp)
		child_radii.append(radius)
	if is_lz:
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.lz_spike_chain_texture(1)
		child_hazard.append(true)
	else:
		sprite = make_sprite("res://assets/objects/syz_small_spikeball/00.png")
		child_hazard.append(true)
	child_sprites.append(sprite)
	child_radii.append(parent_radius)

func _tick_spike_chain() -> void:
	var speed = GenesisMath.s8(subtype & 0xF0) * 8
	angle_word = (angle_word + speed) & 0xFFFF
	# add.w speed,obAngle stores the visible angle in the high byte; the low
	# byte is the fractional phase.
	var ang = (angle_word >> 8) & 0xFF
	var s = GenesisMath.sine(ang)
	var c = GenesisMath.cosine(ang)
	var p = player()
	var is_lz = int(manager.level_definition.get("zone", -1)) == LevelCatalog.ZONE_LZ
	for i in range(child_sprites.size()):
		var radius = child_radii[i]
		var wx = orig_x + ((c * radius) >> 8)
		var wy = orig_y + ((s * radius) >> 8)
		var sp = child_sprites[i]
		sp.position = Vector2(wx - position.x, wy - position.y)
		if p == null or p.dead or i >= child_hazard.size() or not child_hazard[i]:
			continue
		# LZ source children are col_none; only the parent tip uses
		# col_16x16|col_hurt. SYZ keeps its existing small-chain hazard behavior.
		var hazard_half = 8 if is_lz else 6
		if absi(p.pixel_x() - wx) <= p.width_radius + hazard_half and absi(p.pixel_y() - wy) <= p.height_radius + hazard_half:
			p.apply_hazard_hit(wx)
func _init_big_spikeball() -> void:
	active_width = 24
	sprite = make_sprite("res://assets/objects/syz_big_spikeball/00.png")
	var initial_angle = (0x40 if x_flip else 0) | (0x80 if y_flip else 0)
	angle_word = (initial_angle & 0xFF) << 8

func _tick_big_spikeball() -> void:
	var kind = subtype & 7
	match kind:
		1:
			var d = manager.oscillate_0e()
			if x_flip:
				d = -d + 0x60
			position.x = orig_x - d
		2:
			var d = manager.oscillate_0e()
			# Source checks status bit 0 here as well (despite the Y-motion comment).
			if x_flip:
				d = -d + 0x80
			position.y = orig_y - d
		3:
			var speed = GenesisMath.s8(subtype & 0xF0) * 8
			angle_word = (angle_word + speed) & 0xFFFF
			var ang = (angle_word >> 8) & 0xFF
			position.x = orig_x + ((GenesisMath.cosine(ang) * 0x50) >> 8)
			position.y = orig_y + ((GenesisMath.sine(ang) * 0x50) >> 8)
	var p = player()
	if p != null and not p.dead and absi(p.pixel_x()-int(position.x)) <= p.width_radius + 20 and absi(p.pixel_y()-int(position.y)) <= p.height_radius + 20:
		p.apply_hazard_hit(int(position.x))

# -----------------------------------------------------------------------------
# Shared badnik response
# -----------------------------------------------------------------------------
func _react_standard_badnik(p: SonicPlayer, half_w: int, half_h: int) -> void:
	if not sprite.visible:
		return
	if absi(p.pixel_x() - int(position.x)) > p.width_radius + half_w or absi(p.pixel_y() - int(position.y)) > p.height_radius + half_h:
		return
	if p.can_attack_object():
		_destroy_badnik(p)
	else:
		p.apply_hazard_hit(int(position.x))

func _destroy_badnik(p: SonicPlayer) -> void:
	var award = manager.register_badnik_hit()
	manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
	request_delete(respawn_enabled)
	if p.vel_y >= 0:
		p.vel_y = -absi(p.vel_y)
