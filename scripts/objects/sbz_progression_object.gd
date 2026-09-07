class_name SBZProgressionObject
extends GenesisLevelObject

# Phase 42 source-driven Scrap Brain Acts 1-2 progression objects:
# $6B stomper/sliding door, $6C vanishing platform, $6D flamethrower,
# $6E electrocuter, $6F spin-platform conveyor, $70 girder, $72 teleporter.
# Shared Object $71 remains routed through MarbleObject's native barrier path.

var sprite: Sprite2D

# -----------------------------------------------------------------------------
# $6B stomper / sliding door
# -----------------------------------------------------------------------------
var stomp_origin = Vector2.ZERO
var stomp_frame = 0
var stomp_half_width = 0
var stomp_half_height = 0
var stomp_max = 0
var stomp_action = 0
var stomp_switch = 0
var stomp_active = false
var stomp_offset = 0
var stomp_delay = 0

# -----------------------------------------------------------------------------
# $6C vanishing platform
# -----------------------------------------------------------------------------
var vanish_timer = 0
var vanish_time_len = 0
var vanish_sync_offset = 0
var vanish_sync_mask = 0
var vanish_synced = false
var vanish_anim = 0
var vanish_frame = 0
var vanish_sequence_index = 0
var vanish_anim_timer = 0
const VANISH_SEQUENCES: Array = [
	[0, 1, 2, 3],
	[3, 2, 1, 0],
]

# -----------------------------------------------------------------------------
# $6D flamethrower
# -----------------------------------------------------------------------------
var flame_timer = 0
var flame_fire_time = 0
var flame_pause_time = 0
var flame_hurt_frame = 0x0A
var flame_anim = 0
var flame_frame = 0
var flame_sequence_index = 0
var flame_anim_timer = 0
const FLAME_SEQUENCES: Array = [
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
	[9, 7, 5, 3, 1, 0],
	[11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
	[20, 18, 17, 15, 13, 11],
]

# -----------------------------------------------------------------------------
# $6E electrocuter
# -----------------------------------------------------------------------------
var electro_frequency = 0
var electro_anim = 0
var electro_frame = 0
var electro_sequence_index = 0
var electro_anim_timer = 0
var electro_runtime_palette: Array[Color] = []
const ELECTRO_DISCHARGE: Array[int] = [1, 1, 1, 2, 3, 3, 4, 4, 4, 5, 5, 5, 0]

# -----------------------------------------------------------------------------
# $6F spinning-platform conveyor
# -----------------------------------------------------------------------------
var spin_conveyor_spawner = false
var spin_conveyor_platform = false
var spin_conveyor_group = -1
var spin_conveyor_support_id = -1
var spin_conveyor_target_index = 0
var spin_conveyor_targets: Array[Vector2i] = []
var spin_conveyor_velocity = Vector2.ZERO
var spin_conveyor_anim = 1
var spin_conveyor_frame = 0
var spin_conveyor_sequence_index = 0
const SPIN_CONVEY_SEQUENCE: Array = [
	[0,0,0], [1,0,0], [2,0,0], [3,0,0], [4,0,0],
	[3,0,1], [2,0,1], [1,0,1], [0,0,1],
	[1,1,1], [2,1,1], [3,1,1], [4,1,1],
	[3,1,0], [2,1,0], [1,1,0], [0,0,0],
]

# -----------------------------------------------------------------------------
# $70 girder
# -----------------------------------------------------------------------------
var girder_velocity = Vector2.ZERO
var girder_time = 0
var girder_set = 0
var girder_delay = 0
const GIRDER_SETTINGS: Array = [
	[0x100, 0, 96],
	[0, 0x100, 48],
	[-0x100, -0x40, 96],
	[0, -0x100, 24],
]

# -----------------------------------------------------------------------------
# $72 teleporter
# -----------------------------------------------------------------------------
var tele_state = 0 # 0 detect, 1 pre-bump, 2 travelling
var tele_prebump = 0
var tele_targets: Array[Vector2i] = []
var tele_target_index = 0
var tele_time = 0
var tele_vel_x = 0
var tele_vel_y = 0
const TELE_TARGETS: Array = [
	[Vector2i(0x794, 0x98C)],
	[Vector2i(0x094, 0x38C)],
	[Vector2i(0x794, 0x2E8), Vector2i(0x7A4, 0x2C0), Vector2i(0x7D0, 0x2AC), Vector2i(0x858, 0x2AC), Vector2i(0x884, 0x298), Vector2i(0x894, 0x270), Vector2i(0x894, 0x190)],
	[Vector2i(0x894, 0x690)],
	[Vector2i(0x1194, 0x470), Vector2i(0x1184, 0x498), Vector2i(0x1158, 0x4AC), Vector2i(0xFD0, 0x4AC), Vector2i(0xFA4, 0x4C0), Vector2i(0xF94, 0x4E8), Vector2i(0xF94, 0x590)],
	[Vector2i(0x1294, 0x490)],
	[Vector2i(0x1594, -0x18), Vector2i(0x1584, -0x40), Vector2i(0x1560, -0x54), Vector2i(0x14D0, -0x54), Vector2i(0x14A4, -0x68), Vector2i(0x1494, -0x90), Vector2i(0x1494, -0x270)],
	[Vector2i(0x894, 0x090)],
]

func initialize_object() -> void:
	match object_id:
		0x6B:
			_init_stomper()
		0x6C:
			_init_vanishing_platform()
		0x6D:
			_init_flamethrower()
		0x6E:
			_init_electrocuter()
		0x6F:
			_init_spin_conveyor_record()
		0x70:
			_init_girder()
		0x72:
			_init_teleporter()
		_:
			request_delete(false)

func tick() -> void:
	if not alive:
		return
	match object_id:
		0x6B:
			_tick_stomper()
		0x6C:
			_tick_vanishing_platform()
		0x6D:
			_tick_flamethrower()
		0x6E:
			_tick_electrocuter()
		0x6F:
			if spin_conveyor_platform:
				_tick_spin_conveyor_platform()
		0x70:
			_tick_girder()
		0x72:
			_tick_teleporter()

func suppress_central_despawn() -> bool:
	# Group spawners stay resident to prevent duplicate transient groups. During
	# tube travel the original teleporter deliberately skips its out-of-range test.
	return spin_conveyor_spawner or (object_id == 0x72 and tele_state != 0) or (object_id == 0x6B and stomp_frame == 4)

# =============================================================================
# Object $6B - stomper and sliding horizontal door
# =============================================================================
func _init_stomper() -> void:
	stomp_origin = position
	var setup_index = (subtype >> 4) & 7
	# Sto_Var contains entries 0-4. Phase 43 enables entry 4 for the internal
	# LZ4/SBZ3 ancient lift while retaining the Acts 1-2 behavior unchanged.
	if setup_index > 4:
		request_delete(false)
		return
	var widths: Array[int] = [64, 28, 28, 28, 128]
	var heights: Array[int] = [12, 32, 32, 32, 64]
	var maximums: Array[int] = [128, 56, 64, 96, 0]
	var source_actions: Array[int] = [1, 3, 4, 4, 5]
	stomp_half_width = widths[setup_index]
	stomp_half_height = heights[setup_index]
	stomp_max = maximums[setup_index]
	stomp_frame = setup_index
	active_width = stomp_half_width
	if setup_index == 4:
		if manager == null or not bool(manager.level_definition.get("internal_sbz3", false)):
			request_delete(false)
			return
		# v_obj6B allows only one of the authored pre/post-switch lift records to
		# exist at once. The initial ObjPosLoad window reaches $A80 first.
		if manager.sbz3_ancient_lift_claimed:
			request_delete(false)
			return
		manager.sbz3_ancient_lift_claimed = true
	if (subtype & 0x80) != 0:
		stomp_switch = subtype & 0x0F
		stomp_action = source_actions[setup_index]
	else:
		stomp_action = subtype & 0x0F
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz3_ancient_lift_texture() if setup_index == 4 else SourceObjectArt.sbz_stomper_texture(stomp_frame)
	_update_stomper_position()

func _tick_stomper() -> void:
	var old = position
	match stomp_action:
		0:
			pass
		1:
			_tick_stomper_extend()
		2:
			_tick_stomper_retract()
		3:
			_tick_stomper_down_retract()
		4:
			_tick_stomper_up_down()
		5:
			_tick_ancient_lift()
	_update_stomper_position()
	var p = player()
	if p == null:
		return
	var dx = position.x - old.x
	var dy = position.y - old.y
	var left = int(round(position.x)) - stomp_half_width
	var right = int(round(position.x)) + stomp_half_width
	var top = int(round(position.y)) - stomp_half_height
	p.move_with_supported_object_fractional(record_index, dx, dy, left, right, top)
	p.resolve_solid_box_contact(int(round(position.x)), int(round(position.y)), stomp_half_width, stomp_half_height, true, record_index)

func _tick_stomper_extend() -> void:
	if not stomp_active:
		if not manager.is_switch_pressed(stomp_switch):
			return
		stomp_active = true
	if stomp_offset == stomp_max:
		stomp_action = 2
		stomp_delay = 3 * 60
		stomp_active = false
		return
	stomp_offset = mini(stomp_max, stomp_offset + 2)

func _tick_stomper_retract() -> void:
	if not stomp_active:
		stomp_delay -= 1
		if stomp_delay != 0:
			return
		stomp_active = true
	if stomp_offset == 0:
		stomp_action = 1
		stomp_active = false
		return
	stomp_offset = maxi(0, stomp_offset - 2)

func _tick_stomper_down_retract() -> void:
	if not stomp_active:
		if stomp_offset != 0:
			stomp_offset -= 1
			return
		stomp_delay -= 1
		if stomp_delay >= 0:
			return
		stomp_delay = 60
		stomp_active = true
	stomp_offset = mini(stomp_max, stomp_offset + 8)
	if stomp_offset == stomp_max:
		stomp_active = false

func _tick_stomper_up_down() -> void:
	if not stomp_active:
		if stomp_offset != 0:
			stomp_offset = maxi(0, stomp_offset - 8)
			return
		stomp_delay -= 1
		if stomp_delay >= 0:
			return
		stomp_delay = 60
		stomp_active = true
	if stomp_offset == stomp_max:
		stomp_delay -= 1
		if stomp_delay >= 0:
			return
		stomp_delay = 60
		stomp_active = false
		return
	stomp_offset = mini(stomp_max, stomp_offset + 8)

func _tick_ancient_lift() -> void:
	if not stomp_active:
		if not manager.is_switch_pressed(stomp_switch):
			return
		stomp_active = true
	# Sto_AncientLift: -1px X and +0.5px Y per frame until X reaches $980.
	if int(round(position.x)) <= 0x980:
		position.x = 0x980
		stomp_action = 0
		return
	position.x -= 1.0
	position.y += 0.5
	if position.x <= 0x980:
		position.x = 0x980
		stomp_action = 0

func _update_stomper_position() -> void:
	if stomp_action == 1 or stomp_action == 2:
		var off_x = stomp_offset
		if x_flip:
			off_x = -off_x + 128
		position = Vector2(stomp_origin.x - off_x, stomp_origin.y)
	elif stomp_action == 3 or stomp_action == 4:
		var off_y = stomp_offset
		if x_flip:
			off_y = -off_y + 56
		position = Vector2(stomp_origin.x, stomp_origin.y + off_y)

# =============================================================================
# Object $6C - vanishing platform
# =============================================================================
func _init_vanishing_platform() -> void:
	active_width = 16
	var low = (subtype & 0x0F) + 1
	var base = low << 7
	vanish_timer = base - 1
	vanish_time_len = vanish_timer
	var sync_span = base + 0x80
	vanish_sync_offset = int(((subtype & 0xF0) * sync_span) >> 8)
	vanish_sync_mask = sync_span - 1
	vanish_anim = 0
	vanish_frame = 0
	vanish_sequence_index = -1
	vanish_anim_timer = 0
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_vanishing_texture(0)

func _tick_vanishing_platform() -> void:
	if not vanish_synced:
		if ((manager.elapsed_frames - vanish_sync_offset) & vanish_sync_mask) == 0:
			vanish_synced = true
		else:
			_advance_vanishing_animation()
			_resolve_vanishing_collision()
			return

	vanish_timer -= 1
	if vanish_timer < 0:
		vanish_timer = 0x7F
		if vanish_anim != 0:
			vanish_timer = vanish_time_len
		vanish_anim = 1 - vanish_anim
		vanish_sequence_index = -1
		vanish_anim_timer = 0
	_advance_vanishing_animation()
	_resolve_vanishing_collision()

func _advance_vanishing_animation() -> void:
	var seq: Array = VANISH_SEQUENCES[vanish_anim]
	vanish_anim_timer -= 1
	if vanish_anim_timer < 0:
		vanish_anim_timer = 7
		if vanish_sequence_index < seq.size() - 1:
			vanish_sequence_index += 1
	vanish_frame = int(seq[vanish_sequence_index])
	if sprite != null:
		sprite.texture = SourceObjectArt.sbz_vanishing_texture(vanish_frame)

func _resolve_vanishing_collision() -> void:
	var p = player()
	if p == null:
		return
	# Source tests bit 1 of obFrame: frames 0/1 are solid; 2/3 are not.
	if (vanish_frame & 2) == 0:
		p.resolve_platform_top(int(position.x) - 16, int(position.x) + 16, int(position.y) - 8, record_index)
	else:
		p.clear_object_support_for(record_index, true)

# =============================================================================
# Object $6D - flamethrower
# =============================================================================
func _init_flamethrower() -> void:
	active_width = 12
	flame_fire_time = (subtype & 0xF0) * 2
	flame_timer = flame_fire_time
	flame_pause_time = (subtype & 0x0F) << 5
	flame_anim = 2 if y_flip else 0
	flame_hurt_frame = 0x15 if y_flip else 0x0A
	flame_frame = 0x0B if y_flip else 0
	flame_sequence_index = -1
	flame_anim_timer = 0
	z_index = 130
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_flamethrower_texture(flame_frame)

func _tick_flamethrower() -> void:
	flame_timer -= 1
	if flame_timer < 0:
		flame_anim ^= 1
		flame_sequence_index = -1
		flame_anim_timer = 0
		if (flame_anim & 1) != 0:
			flame_timer = flame_pause_time
		else:
			flame_timer = flame_fire_time
	_advance_flame_animation()
	if flame_frame == flame_hurt_frame:
		var p = player()
		if p != null and absi(p.pixel_x() - int(position.x)) <= 12 and absi(p.pixel_y() - int(position.y)) <= 24:
			p.apply_hazard_hit(int(position.x))

func _advance_flame_animation() -> void:
	var seq: Array = FLAME_SEQUENCES[flame_anim]
	var delay = 3 if (flame_anim & 1) == 0 else 0
	flame_anim_timer -= 1
	if flame_anim_timer < 0:
		flame_anim_timer = delay
		if flame_sequence_index < seq.size() - 1:
			flame_sequence_index += 1
		elif (flame_anim & 1) == 0:
			# afBack,2 loops the last two expansion frames indefinitely.
			flame_sequence_index = maxi(0, seq.size() - 2)
	flame_frame = int(seq[flame_sequence_index])
	if sprite != null:
		sprite.texture = SourceObjectArt.sbz_flamethrower_texture(flame_frame)

# =============================================================================
# Object $6E - electrocuter
# =============================================================================
func _init_electrocuter() -> void:
	electro_runtime_palette = []
	active_width = 40
	electro_frequency = maxi(0, (subtype << 4) - 1)
	electro_anim = 0
	electro_frame = 0
	electro_sequence_index = -1
	electro_anim_timer = 7
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_electro_texture(0)

func refresh_palette_cycle(changed_indices: Array[int], runtime_palette: Array[Color]) -> void:
	# The electrocuter top/stem uses palette line 4, including the C-E entries
	# driven by Pal_SBZCyc8. Keep that sprite on the same live CRAM state as the
	# source level instead of leaving the pre-rendered object colors frozen.
	if object_id != 0x6E or sprite == null or runtime_palette.size() < 64:
		return
	var affects_electro := false
	for index in changed_indices:
		if int(index) >= 60 and int(index) <= 62:
			affects_electro = true
			break
	if affects_electro:
		electro_runtime_palette = runtime_palette
		sprite.texture = SourceObjectArt.sbz_electro_texture(electro_frame, runtime_palette)

func _tick_electrocuter() -> void:
	if (manager.elapsed_frames & electro_frequency) == 0 and electro_anim == 0:
		electro_anim = 1
		electro_sequence_index = -1
		electro_anim_timer = 0
	if electro_anim == 1:
		electro_anim_timer -= 1
		if electro_anim_timer < 0:
			electro_anim_timer = 0
			if electro_sequence_index < ELECTRO_DISCHARGE.size() - 1:
				electro_sequence_index += 1
			else:
				electro_anim = 0
				electro_sequence_index = 0
		electro_frame = int(ELECTRO_DISCHARGE[electro_sequence_index]) if electro_anim == 1 else 0
	else:
		electro_frame = 0
	if sprite != null:
		if electro_runtime_palette.size() >= 64:
			sprite.texture = SourceObjectArt.sbz_electro_texture(electro_frame, electro_runtime_palette)
		else:
			sprite.texture = SourceObjectArt.sbz_electro_texture(electro_frame)
	if electro_frame == 4:
		var p = player()
		if p != null and absi(p.pixel_x() - int(position.x)) <= 72 and absi(p.pixel_y() - int(position.y)) <= 8:
			p.apply_hazard_hit(int(position.x))

# =============================================================================
# Object $6F - spinning platforms moving around conveyor paths
# =============================================================================
func _init_spin_conveyor_record() -> void:
	if (subtype & 0x80) != 0:
		spin_conveyor_spawner = true
		spin_conveyor_group = subtype & 0x7F
		visible = false
		manager.spawn_sbz_spin_conveyor_group(spin_conveyor_group)
		return
	# Normal SBZ objpos contains only high-bit group spawners. Moving platforms
	# are instantiated from the original custom objpos/platforms streams.
	request_delete(false)

func setup_spin_conveyor_platform(owner: SonicObjectManager, world_x: int, world_y: int, platform_subtype: int, group_id: int, child_index: int) -> void:
	manager = owner
	object_id = 0x6F
	subtype = platform_subtype & 0xFF
	spawn_x = world_x
	spawn_y = world_y
	position = Vector2(world_x, world_y)
	alive = true
	spin_conveyor_platform = true
	spin_conveyor_group = group_id
	spin_conveyor_support_id = -20000 - group_id * 100 - child_index
	record_index = spin_conveyor_support_id
	active_width = 16
	spin_conveyor_targets = _spin_conveyor_targets_for_group(group_id)
	if spin_conveyor_targets.is_empty():
		request_delete(false)
		return
	spin_conveyor_target_index = clampi(subtype & 0x0F, 0, spin_conveyor_targets.size() - 1)
	spin_conveyor_anim = 1 if spin_conveyor_target_index < 2 else 0
	spin_conveyor_sequence_index = -1
	spin_conveyor_frame = 0
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_spin_texture(0)
	_set_spin_conveyor_velocity()

func _tick_spin_conveyor_platform() -> void:
	var p = player()
	if p == null or spin_conveyor_targets.is_empty():
		return
	_advance_spin_conveyor_animation()
	var target: Vector2i = spin_conveyor_targets[spin_conveyor_target_index]
	if int(round(position.x)) == target.x and int(round(position.y)) == target.y:
		position = Vector2(target.x, target.y)
		spin_conveyor_target_index = posmod(spin_conveyor_target_index + 1, spin_conveyor_targets.size())
		if spin_conveyor_target_index == 0:
			_set_spin_conveyor_anim(1)
		elif spin_conveyor_target_index == 2:
			_set_spin_conveyor_anim(0)
		_set_spin_conveyor_velocity()
		target = spin_conveyor_targets[spin_conveyor_target_index]

	# The source's non-spinning animation is the only solid state. Evaluate this
	# after a waypoint can change the animation so the first visible spinning
	# frame cannot retain one stale frame of platform support.
	var solid_this_tick = spin_conveyor_anim == 1 and spin_conveyor_frame == 0
	var old = position
	position += spin_conveyor_velocity
	if absf(position.x - target.x) <= 1.01 and absf(position.y - target.y) <= 1.01:
		position = Vector2(target.x, target.y)
	var dx = position.x - old.x
	var dy = position.y - old.y
	var left = int(round(position.x)) - 16
	var right = int(round(position.x)) + 16
	var top = int(round(position.y)) - 7
	if solid_this_tick:
		p.move_with_supported_object_fractional(spin_conveyor_support_id, dx, dy, left, right, top)
		p.resolve_solid_box_contact(int(round(position.x)), int(round(position.y)), 16, 7, true, spin_conveyor_support_id)
	else:
		p.clear_object_support_for(spin_conveyor_support_id, true)

func _set_spin_conveyor_anim(anim: int) -> void:
	if spin_conveyor_anim == anim:
		return
	spin_conveyor_anim = anim
	spin_conveyor_sequence_index = -1
	spin_conveyor_frame = 0

func _advance_spin_conveyor_animation() -> void:
	if spin_conveyor_anim == 1:
		spin_conveyor_frame = 0
		if sprite != null:
			sprite.texture = SourceObjectArt.sbz_spin_texture(0)
			sprite.flip_h = x_flip
			sprite.flip_v = y_flip
		return
	if spin_conveyor_sequence_index < SPIN_CONVEY_SEQUENCE.size() - 1:
		spin_conveyor_sequence_index += 1
	else:
		# Ani_SpinConvey uses afEnd, so the spinning cycle loops continuously.
		spin_conveyor_sequence_index = 0
	var entry: Array = SPIN_CONVEY_SEQUENCE[spin_conveyor_sequence_index]
	spin_conveyor_frame = int(entry[0])
	if sprite != null:
		sprite.texture = SourceObjectArt.sbz_spin_texture(spin_conveyor_frame)
		sprite.flip_h = (int(entry[1]) != 0) != x_flip
		sprite.flip_v = (int(entry[2]) != 0) != y_flip

func _set_spin_conveyor_velocity() -> void:
	var target: Vector2i = spin_conveyor_targets[spin_conveyor_target_index]
	var dx = float(target.x) - position.x
	var dy = float(target.y) - position.y
	var ax = absf(dx)
	var ay = absf(dy)
	if ax < 0.001 and ay < 0.001:
		spin_conveyor_velocity = Vector2.ZERO
		return
	# LCon_ChangeDir keeps the larger axis at exactly one pixel/frame and derives
	# the smaller 8.8 component from the signed distance ratio.
	if ax >= ay:
		spin_conveyor_velocity.x = 1.0 if dx > 0.0 else -1.0
		spin_conveyor_velocity.y = 0.0 if ax == 0.0 else dy / ax
	else:
		spin_conveyor_velocity.y = 1.0 if dy > 0.0 else -1.0
		spin_conveyor_velocity.x = 0.0 if ay == 0.0 else dx / ay

func _spin_conveyor_targets_for_group(group_id: int) -> Array[Vector2i]:
	match group_id:
		0:
			return [Vector2i(0xE14, 0x370), Vector2i(0xEEF, 0x302), Vector2i(0xEEF, 0x340), Vector2i(0xE14, 0x3AE)]
		1:
			return [Vector2i(0xF14, 0x2E0), Vector2i(0xFEF, 0x272), Vector2i(0xFEF, 0x2B0), Vector2i(0xF14, 0x31E)]
		2:
			return [Vector2i(0x1014, 0x270), Vector2i(0x10EF, 0x202), Vector2i(0x10EF, 0x240), Vector2i(0x1014, 0x2AE)]
		3:
			return [Vector2i(0xF14, 0x570), Vector2i(0xFEF, 0x502), Vector2i(0xFEF, 0x540), Vector2i(0xF14, 0x5AE)]
		4:
			return [Vector2i(0x1B14, 0x670), Vector2i(0x1BEF, 0x602), Vector2i(0x1BEF, 0x640), Vector2i(0x1B14, 0x6AE)]
		5:
			return [Vector2i(0x1C14, 0x5E0), Vector2i(0x1CEF, 0x572), Vector2i(0x1CEF, 0x5B0), Vector2i(0x1C14, 0x61E)]
	return []

# =============================================================================
# Object $70 - large moving girder
# =============================================================================
func _init_girder() -> void:
	active_width = 96
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_girder_texture()
	girder_set = 0
	_change_girder_move()

func _tick_girder() -> void:
	var old = position
	if girder_delay != 0:
		girder_delay -= 1
	if girder_delay == 0:
		position += girder_velocity / 256.0
		girder_time -= 1
		if girder_time == 0:
			_change_girder_move()
	var p = player()
	if p == null:
		return
	var dx = position.x - old.x
	var dy = position.y - old.y
	var left = int(round(position.x)) - 96
	var right = int(round(position.x)) + 96
	var top = int(round(position.y)) - 24
	p.move_with_supported_object_fractional(record_index, dx, dy, left, right, top)
	p.resolve_solid_box_contact(int(round(position.x)), int(round(position.y)), 96, 24, true, record_index)

func _change_girder_move() -> void:
	var entry: Array = GIRDER_SETTINGS[girder_set & 3]
	girder_velocity = Vector2(float(int(entry[0])), float(int(entry[1])))
	girder_time = int(entry[2])
	girder_set = (girder_set + 1) & 3
	girder_delay = 7

# =============================================================================
# Object $72 - SBZ2 tube teleporter
# =============================================================================
func _init_teleporter() -> void:
	visible = false
	active_width = 16
	var type_index = clampi(subtype & 0x0F, 0, TELE_TARGETS.size() - 1)
	tele_targets.clear()
	for point_variant in TELE_TARGETS[type_index]:
		tele_targets.append(point_variant)
	tele_target_index = 0
	tele_state = 0

func _tick_teleporter() -> void:
	match tele_state:
		0:
			_tick_teleporter_detect()
		1:
			_tick_teleporter_prebump()
		2:
			_tick_teleporter_travel()

func _tick_teleporter_detect() -> void:
	var p = player()
	if p == null or p.dead or p.drowning or p.debug_free_mode or p.object_control_override:
		return
	var dx = p.pixel_x() - int(position.x)
	if x_flip:
		dx += 15
	if dx < 0 or dx >= 16:
		return
	var dy = p.pixel_y() - int(position.y) + 32
	if dy < 0 or dy >= 64:
		return
	if (subtype & 0x0F) == 7 and manager.rings < 50:
		return
	tele_state = 1
	tele_prebump = 0
	tele_target_index = 0
	p.object_control_override = true
	p.clear_object_support()
	p.rolling = true
	p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
	p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH
	p.inertia = 0x800
	p.vel_x = 0
	p.vel_y = 0
	p.pushing = false
	p.in_air = true
	p.jumping = false
	SonicAudio.play_sfx(SonicAudio.SFX_ROLL)
	p.force_set_pixel_position(int(position.x), int(position.y))

func _tick_teleporter_prebump() -> void:
	var p = player()
	if p == null:
		return
	var wave = GenesisMath.sine(tele_prebump) >> 5
	p.force_set_pixel_position(int(position.x), int(position.y) - wave)
	tele_prebump = (tele_prebump + 2) & 0xFF
	if tele_prebump == 0x80:
		SonicAudio.play_sfx(SonicAudio.SFX_TELEPORT)
		_set_teleporter_direction()
		tele_state = 2

func _tick_teleporter_travel() -> void:
	var p = player()
	if p == null or tele_targets.is_empty():
		return
	tele_time -= 1
	if tele_time < 0:
		var target: Vector2i = tele_targets[tele_target_index]
		p.force_set_pixel_position(target.x, target.y)
		tele_target_index += 1
		if tele_target_index >= tele_targets.size():
			_exit_teleporter(p)
			return
		_set_teleporter_direction()
		return
	# Direct native equivalent of SpeedToPos: update Sonic's own 16.16
	# coordinates.  Do not keep a second private copy here; ScrollVertical may
	# wrap Sonic by $800 while the teleporter is active, and that wrapped value
	# must remain authoritative on the following frame.
	p.fixed_x += tele_vel_x << 8
	p.fixed_y += tele_vel_y << 8
	# BuildSprites displays only the integer position words even while SpeedToPos
	# keeps accumulating subpixels. Keep the teleporter on that same render path.
	p.position = Vector2(float(p.pixel_x()), float(p.pixel_y()))

func _set_teleporter_direction() -> void:
	var p = player()
	if p == null or tele_target_index < 0 or tele_target_index >= tele_targets.size():
		return
	var target: Vector2i = tele_targets[tele_target_index]
	var dx = target.x - p.pixel_x()
	var dy = target.y - p.pixel_y()
	var ax = absi(dx)
	var ay = absi(dy)
	tele_vel_x = 0
	tele_vel_y = 0
	if ax > ay:
		tele_vel_x = 0x1000 if dx >= 0 else -0x1000
		tele_vel_y = 0 if ax == 0 else int((float(dy) * 4096.0) / float(ax))
		# The assembly stores (distance<<16)/$1000 as a word and decrements its
		# big-endian HIGH byte, which is exactly floor(distance/16).
		tele_time = ax >> 4
	else:
		tele_vel_y = 0x1000 if dy >= 0 else -0x1000
		tele_vel_x = 0 if ay == 0 else int((float(dx) * 4096.0) / float(ay))
		tele_time = ay >> 4
	p.vel_x = tele_vel_x
	p.vel_y = tele_vel_y

func _exit_teleporter(p: SonicPlayer) -> void:
	p.wrap_vertical_0x800()
	p.object_control_override = false
	p.vel_x = 0
	p.vel_y = 0x200
	tele_state = 0
	tele_prebump = 0
	tele_target_index = 0
	tele_time = 0
