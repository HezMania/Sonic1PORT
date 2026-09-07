class_name SpikesObject
extends GenesisLevelObject

const WIDTHS: Array[int] = [20, 16, 4, 28, 64, 16]
var sprite: Sprite2D
var frame = 0
var hurt_cooldown = 0
var origin_x = 0
var origin_y = 0
var movement_type = 0
var move_pos_fixed = 0
var move_direction = 0
var move_delay = 0

func initialize_object() -> void:
	frame = clampi((subtype >> 4) & 0x0F, 0, 5)
	movement_type = subtype & 0x0F
	active_width = WIDTHS[frame]
	origin_x = spawn_x
	origin_y = spawn_y
	sprite = make_sprite("res://assets/objects/spikes/%02d.png" % frame)
	# Spikes use the placement status flip bits to choose the pointed face.
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip

func tick() -> void:
	if hurt_cooldown > 0:
		hurt_cooldown -= 1
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)
	_update_movement()
	var dx = int(position.x) - old_x
	var dy = int(position.y) - old_y

	var sideways = frame == 1 or frame == 5
	var half_h = 16
	if sideways:
		half_h = 20 if frame == 1 else 4
	else:
		half_h = 16
	# Moving spikes are still SolidObject platforms. Carry Sonic before resolving
	# the new contact so an $x1 vertical spike cannot move out from under him.
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, dx, dy, int(position.x) - active_width, int(position.x) + active_width, int(position.y) - half_h)

	var contact: int
	var point_contact: int
	if sideways:
		contact = p.resolve_solid_box_contact(int(position.x), int(position.y), 16, half_h, true, record_index)
		# FixBugs spike-backside behavior: unflipped sideways spikes point left;
		# X-flipped spikes point right.
		point_contact = SonicPlayer.SOLID_RIGHT if x_flip else SonicPlayer.SOLID_LEFT
	else:
		contact = p.resolve_solid_box_contact(int(position.x), int(position.y), active_width, 16, true, record_index)
		point_contact = SonicPlayer.SOLID_BOTTOM if y_flip else SonicPlayer.SOLID_TOP

	if contact == SonicPlayer.SOLID_NONE or contact != point_contact or hurt_cooldown > 0:
		return
	if p.apply_hazard_hit(int(position.x)):
		SonicAudio.play_sfx(SonicAudio.SFX_SPIKES)
		hurt_cooldown = 30

func _update_movement() -> void:
	# Spikes_Move: lower subtype 0 = static, 1 = vertical, 2 = horizontal.
	if movement_type != 1 and movement_type != 2:
		return
	if move_delay > 0:
		move_delay -= 1
	else:
		if move_direction != 0:
			move_pos_fixed -= 8 * 0x100
			if move_pos_fixed <= 0:
				move_pos_fixed = 0
				move_direction = 0
				move_delay = 60
		else:
			move_pos_fixed += 8 * 0x100
			if move_pos_fixed >= 32 * 0x100:
				move_pos_fixed = 32 * 0x100
				move_direction = 1
				move_delay = 60
	var pixel_offset = (move_pos_fixed >> 8) & 0xFF
	if movement_type == 1:
		position.y = origin_y + pixel_offset
	else:
		position.x = origin_x + pixel_offset
