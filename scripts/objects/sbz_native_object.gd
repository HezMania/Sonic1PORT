class_name SBZNativeObject
extends GenesisLevelObject

# Phase 41 source-driven Scrap Brain Zone foundation:
# $66 rotating junction, $67 running disc, $68 conveyor region,
# $69 trapdoor/spinning platform, $6A saws and pizza cutters.

var sprite: Sprite2D
var overlay: Sprite2D

# $66 junction.
var junction_frame = 0
var junction_timer = 0
var junction_direction = 1
var junction_switch_down = false
var junction_grabbed = false
var junction_grab_frame = 0
const JUNCTION_XY: Array[Vector2i] = [
	Vector2i(-0x20,0), Vector2i(-0x1E,0x0E), Vector2i(-0x18,0x18), Vector2i(-0x0E,0x1E),
	Vector2i(0,0x20), Vector2i(0x0E,0x1E), Vector2i(0x18,0x18), Vector2i(0x1E,0x0E),
	Vector2i(0x20,0), Vector2i(0x1E,-0x0E), Vector2i(0x18,-0x18), Vector2i(0x0E,-0x1E),
	Vector2i(0,-0x20), Vector2i(-0x0E,-0x1E), Vector2i(-0x18,-0x18), Vector2i(-0x1E,-0x0E),
]

# $67 running disc.
var disc_origin = Vector2.ZERO
var disc_angle = 0
var disc_angle_step = 0
var disc_radius = 0x18
var disc_trigger = 0x48
var disc_attached = false

# $68 conveyor.
var conveyor_speed = 0
var conveyor_half_width = 128

# $69 trap/spinner.
var spin_is_spinner = false
var spin_timer = 0
var spin_time_len = 0
var spin_sync_mask = 0
var spin_spinning = false
var spin_anim = 0
var spin_frame = 0
var spin_anim_timer = 0
var spin_sequence_index = 0
const SPIN_SEQUENCE: Array = [
	[0,0,0], [1,0,0], [2,0,0], [3,0,0], [4,0,0],
	[3,0,1], [2,0,1], [1,0,1], [0,0,1],
	[1,1,1], [2,1,1], [3,1,1], [4,1,1],
	[3,1,0], [2,1,0], [1,1,0], [0,0,0],
]

# $6A saw.
var saw_origin = Vector2.ZERO
var saw_shot = false
var saw_vel_x = 0
var saw_frame = 0
var saw_anim_timer = 0

func initialize_object() -> void:
	match object_id:
		0x66:
			_init_junction()
		0x67:
			_init_disc()
		0x68:
			_init_conveyor()
		0x69:
			_init_spin_platform()
		0x6A:
			_init_saw()
		_:
			request_delete(false)

func tick() -> void:
	if not alive:
		return
	match object_id:
		0x66:
			_tick_junction()
		0x67:
			_tick_disc()
		0x68:
			_tick_conveyor()
		0x69:
			_tick_spin_platform()
		0x6A:
			_tick_saw()

func suppress_central_despawn() -> bool:
	return object_id == 0x66 and junction_grabbed

# -----------------------------------------------------------------------------
# Object $66 - rotating junction
# -----------------------------------------------------------------------------
func _init_junction() -> void:
	active_width = 56
	junction_direction = 1
	junction_frame = 0
	junction_timer = 0
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_junction_texture(0)
	overlay = make_sprite("", 1)
	overlay.texture = SourceObjectArt.sbz_junction_texture(16)

func _tick_junction() -> void:
	_rotate_junction()
	_update_junction_visual()
	var p = player()
	if p == null:
		return
	if junction_grabbed:
		var release_frame = junction_frame == 4 or junction_frame == 7
		if release_frame and junction_frame != junction_grab_frame:
			_release_junction_player(p)
			return
		var off: Vector2i = JUNCTION_XY[junction_frame & 0x0F]
		p.force_set_pixel_position(int(position.x) + off.x, int(position.y) + off.y)
		return

	var contact = p.resolve_solid_box_contact(int(position.x), int(position.y), 37, 37, true, record_index)
	var needed = -1
	if contact == SonicPlayer.SOLID_LEFT:
		needed = 0x0E
	elif contact == SonicPlayer.SOLID_RIGHT:
		needed = 7
	if needed < 0 or junction_frame != needed:
		return
	junction_grabbed = true
	junction_grab_frame = needed
	p.object_control_override = true
	p.clear_object_support()
	p.in_air = true
	p.rolling = true
	p.height_radius = SonicPlayer.SONIC_ROLL_HEIGHT
	p.width_radius = SonicPlayer.SONIC_ROLL_WIDTH
	p.inertia = 0x800
	p.vel_x = 0
	p.vel_y = 0
	p.pushing = false
	var target: Vector2i = Vector2i(int(position.x), int(position.y)) + JUNCTION_XY[junction_frame]
	var mid_x = int((p.pixel_x() + target.x) / 2)
	var mid_y = int((p.pixel_y() + target.y) / 2)
	p.force_set_pixel_position(mid_x, mid_y)

func _rotate_junction() -> void:
	var pressed = manager.is_switch_pressed(subtype)
	if pressed:
		if not junction_switch_down:
			junction_direction = -junction_direction
			junction_switch_down = true
	else:
		junction_switch_down = false
	junction_timer -= 1
	if junction_timer >= 0:
		return
	junction_timer = 7
	junction_frame = (junction_frame + junction_direction) & 0x0F

func _update_junction_visual() -> void:
	if sprite != null:
		sprite.texture = SourceObjectArt.sbz_junction_texture(junction_frame)

func _release_junction_player(p: SonicPlayer) -> void:
	junction_grabbed = false
	p.object_control_override = false
	p.rolling = false
	p.height_radius = SonicPlayer.SONIC_HEIGHT
	p.width_radius = SonicPlayer.SONIC_WIDTH
	p.in_air = true
	p.vel_x = 0
	p.vel_y = 0x800
	if junction_frame == 7:
		p.vel_x = 0x800
	p.inertia = 0x800

# -----------------------------------------------------------------------------
# Object $67 - running disc / gear controller
# -----------------------------------------------------------------------------
func _init_disc() -> void:
	active_width = 8
	disc_origin = position
	disc_radius = 0x18 if (subtype & 0x0F) == 0 else 0x10
	disc_trigger = 0x48 if (subtype & 0x0F) == 0 else 0x38
	disc_angle = (0x40 if x_flip else 0) + (0x80 if y_flip else 0)
	disc_angle_step = int(GenesisMath.s8(subtype & 0xF0) / 32)
	z_index = 120
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_running_disc_texture()

func _tick_disc() -> void:
	var p = player()
	if p == null:
		return
	var in_range = absi(p.pixel_x() - int(disc_origin.x)) < disc_trigger and absi(p.pixel_y() - int(disc_origin.y)) < disc_trigger
	if not in_range or p.in_air:
		if disc_attached:
			disc_attached = false
			p.stick_to_convex = false
	else:
		if not disc_attached:
			disc_attached = true
			p.stick_to_convex = true
			p.pushing = false
		var clockwise = disc_angle_step >= 0
		if clockwise:
			p.inertia = clampi(p.inertia, 0x400, 0xF00)
		else:
			p.inertia = clampi(p.inertia, -0xF00, -0x400)

	disc_angle = (disc_angle + disc_angle_step) & 0xFF
	var dx = int(GenesisMath.cosine(disc_angle) * disc_radius / 256.0)
	var dy = int(GenesisMath.sine(disc_angle) * disc_radius / 256.0)
	position = disc_origin + Vector2(dx, dy)

# -----------------------------------------------------------------------------
# Object $68 - invisible conveyor push region
# -----------------------------------------------------------------------------
func _init_conveyor() -> void:
	visible = false
	active_width = 128
	conveyor_half_width = 128 if (subtype & 0x0F) == 0 else 56
	conveyor_speed = GenesisMath.s8(subtype & 0xF0) >> 4

func _tick_conveyor() -> void:
	var p = player()
	if p == null or p.in_air or p.dead or p.debug_free_mode:
		return
	if absi(p.pixel_x() - int(position.x)) >= conveyor_half_width:
		return
	var dy = p.pixel_y() - int(position.y)
	if dy < -48 or dy >= 0:
		return
	p.force_add_pixel_offset(conveyor_speed, 0)

# -----------------------------------------------------------------------------
# Object $69 - trapdoors and stationary spinning platforms
# -----------------------------------------------------------------------------
func _init_spin_platform() -> void:
	spin_is_spinner = (subtype & 0x80) != 0
	spin_frame = 0
	spin_anim_timer = 0
	if spin_is_spinner:
		active_width = 16
		spin_time_len = (subtype & 0x0F) * 6
		spin_timer = spin_time_len
		spin_sync_mask = ((((subtype & 0x70) + 0x10) << 2) - 1) & 0xFFFF
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.sbz_spin_texture(0)
		spin_anim_timer = 1
	else:
		active_width = 64
		spin_time_len = (subtype & 0x0F) * 60
		spin_timer = 0
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.sbz_trapdoor_texture(0)

func _tick_spin_platform() -> void:
	if spin_is_spinner:
		_tick_spinner()
	else:
		_tick_trapdoor()

func _tick_trapdoor() -> void:
	spin_timer -= 1
	if spin_timer < 0:
		spin_timer = spin_time_len
		spin_anim = 1 - spin_anim
		spin_sequence_index = 0
		spin_anim_timer = 3
	_update_trap_animation()
	var p = player()
	if p == null:
		return
	if spin_frame == 0:
		p.resolve_solid_box_contact(int(position.x), int(position.y), 64, 12, true, record_index)
	else:
		p.clear_object_support_for(record_index, true)

func _update_trap_animation() -> void:
	# Godot 4.6 infers a generic Array from an inline conditional expression;
	# assign the typed array in two steps so this remains Array[int].
	var seq: Array[int] = [0, 1, 2]
	if spin_anim != 0:
		seq = [2, 1, 0]
	spin_anim_timer -= 1
	if spin_anim_timer < 0:
		spin_anim_timer = 3
		if spin_sequence_index < seq.size() - 1:
			spin_sequence_index += 1
	spin_frame = seq[spin_sequence_index]
	sprite.texture = SourceObjectArt.sbz_trapdoor_texture(spin_frame)

func _tick_spinner() -> void:
	if (manager.elapsed_frames & spin_sync_mask) == 0:
		spin_spinning = true
	if spin_spinning:
		spin_timer -= 1
		if spin_timer < 0:
			spin_timer = spin_time_len
			spin_spinning = false
			spin_anim = 1 - spin_anim
			spin_sequence_index = 0
			spin_anim_timer = 1
	if spin_sequence_index < SPIN_SEQUENCE.size() - 1:
		spin_anim_timer -= 1
		if spin_anim_timer < 0:
			spin_anim_timer = 1
			spin_sequence_index += 1
	var entry: Array = SPIN_SEQUENCE[spin_sequence_index]
	spin_frame = int(entry[0])
	sprite.texture = SourceObjectArt.sbz_spin_texture(spin_frame)
	sprite.flip_h = (int(entry[1]) != 0) != x_flip
	sprite.flip_v = (int(entry[2]) != 0) != y_flip
	var p = player()
	if p == null:
		return
	if spin_frame == 0:
		p.resolve_solid_box_contact(int(position.x), int(position.y), 16, 7, true, record_index)
	else:
		p.clear_object_support_for(record_index, true)

# -----------------------------------------------------------------------------
# Object $6A - saws and pizza cutters
# -----------------------------------------------------------------------------
func _init_saw() -> void:
	active_width = 32
	saw_origin = position
	saw_frame = 0
	saw_anim_timer = 0
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_saw_texture(0)
	if subtype >= 3:
		visible = false

func _tick_saw() -> void:
	match subtype & 7:
		0:
			pass
		1:
			var off_x = int(manager.oscillate_0e())
			if x_flip:
				off_x = -off_x + 0x60
			position.x = saw_origin.x - off_x
			_animate_saw(false)
		2:
			var off_y = int(manager.oscillate_06())
			if x_flip:
				off_y = -off_y + 0x80
			position.y = saw_origin.y - off_y
			_animate_saw(false)
		3:
			_tick_speeding_saw(true)
		4:
			_tick_speeding_saw(false)
		_:
			pass
	if visible:
		_hurt_with_saw()

func _animate_saw(speeding: bool) -> void:
	saw_anim_timer -= 1
	if saw_anim_timer < 0:
		saw_anim_timer = 2
		saw_frame ^= 1
	var base = 2 if speeding else 0
	sprite.texture = SourceObjectArt.sbz_saw_texture(base + saw_frame)

func _tick_speeding_saw(from_left: bool) -> void:
	var p = player()
	if p == null:
		return
	if not saw_shot:
		var horizontal_ok = false
		if from_left:
			horizontal_ok = p.pixel_x() >= int(saw_origin.x) + 192
		else:
			horizontal_ok = p.pixel_x() <= int(saw_origin.x) - 224
		var vertical_ok = absi(p.pixel_y() - int(saw_origin.y)) < 128
		if not horizontal_ok or not vertical_ok:
			return
		saw_shot = true
		saw_vel_x = 0x600 if from_left else -0x600
		saw_frame = 0
		visible = true
		sprite.texture = SourceObjectArt.sbz_saw_texture(2)
	position.x += float(saw_vel_x) / 256.0
	saw_origin.x = position.x
	_animate_saw(true)

func _hurt_with_saw() -> void:
	var p = player()
	if p == null:
		return
	if absi(p.pixel_x() - int(position.x)) <= 24 and absi(p.pixel_y() - int(position.y)) <= 24:
		p.apply_hazard_hit(int(position.x))
