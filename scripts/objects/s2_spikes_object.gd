class_name S2SpikesObject
extends GenesisLevelObject

# Retail Sonic 2 Object $36. Upper nibble selects size/orientation; lower nibble
# selects static/vertical/horizontal retract behavior.
const WIDTHS: Array[int] = [0x10,0x20,0x30,0x40,0x10,0x10,0x10,0x10]
const HEIGHTS: Array[int] = [0x10,0x10,0x10,0x10,0x10,0x20,0x30,0x40]
var sprite: Sprite2D
var frame := 0
var movement_type := 0
var origin_x := 0
var origin_y := 0
var move_offset := 0
var move_state := 0
var move_delay := 0
var hurt_cooldown := 0

func initialize_object() -> void:
	frame = clampi((subtype >> 4) & 0x0F, 0, 7)
	movement_type = subtype & 0x0F
	active_width = WIDTHS[frame]
	origin_x = spawn_x
	origin_y = spawn_y
	sprite = make_sprite("res://assets/objects/s2_ehz/spikes/%02d.png" % frame)
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip

func apply_vertical_wrap_shift(delta_y: int) -> void:
	position.y += delta_y
	spawn_y += delta_y
	origin_y += delta_y

func tick() -> void:
	if hurt_cooldown > 0:
		hurt_cooldown -= 1
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)
	_update_movement()
	var half_w = WIDTHS[frame]
	var half_h = HEIGHTS[frame]
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, int(position.x)-old_x, int(position.y)-old_y, int(position.x)-half_w, int(position.x)+half_w, int(position.y)-half_h)
	var contact = p.resolve_solid_box_contact(int(position.x), int(position.y), half_w, half_h, true, record_index)
	var sideways = frame >= 4
	var dangerous_contact := false
	if sideways:
		# Retail Obj36 masks the SolidObject result with touch_side_mask and
		# calls Touch_ChkHurt2 for either lateral face. Placement X-flip changes
		# the drawing, not which SolidObject side is hazardous.
		dangerous_contact = contact == SonicPlayer.SOLID_LEFT or contact == SonicPlayer.SOLID_RIGHT
	elif y_flip:
		dangerous_contact = contact == SonicPlayer.SOLID_BOTTOM
	else:
		dangerous_contact = contact == SonicPlayer.SOLID_TOP
	if dangerous_contact and hurt_cooldown <= 0:
		if p.apply_hazard_hit(int(position.x)):
			SonicAudio.play_sfx(SonicAudio.SFX_SPIKES)
			hurt_cooldown = 30

func _update_movement() -> void:
	if movement_type != 1 and movement_type != 2:
		return
	if move_delay > 0:
		move_delay -= 1
	else:
		if move_state != 0:
			move_offset -= 8
			if move_offset <= 0:
				move_offset = 0
				move_state = 0
				move_delay = 60
		else:
			move_offset += 8
			if move_offset >= 32:
				move_offset = 32
				move_state = 1
				move_delay = 60
	if movement_type == 1:
		position.y = origin_y + move_offset
	else:
		position.x = origin_x + move_offset
