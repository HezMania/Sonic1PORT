class_name SpringObject
extends GenesisLevelObject

var sprite: Sprite2D
var sideways := false
var downward := false
var yellow := false
var spring_power := 0x1000
var anim_timer := 0
var anim_step := 0

func initialize_object() -> void:
	sideways = (subtype & 0x10) != 0
	downward = (subtype & 0x20) != 0
	yellow = (subtype & 0x02) != 0
	spring_power = 0x0A00 if yellow else 0x1000
	active_width = 16 if not sideways else 8

	var folder = ("spring_v_yellow" if yellow else "spring_v") if sideways else ("spring_h_yellow" if yellow else "spring_h")
	var frame = 3 if sideways else 0
	sprite = make_sprite("res://assets/objects/%s/%02d.png" % [folder, frame])
	if downward:
		sprite.flip_v = not sprite.flip_v

func tick() -> void:
	if not alive:
		return
	if anim_timer > 0:
		anim_timer -= 1
		var folder = ("spring_v_yellow" if yellow else "spring_v") if sideways else ("spring_h_yellow" if yellow else "spring_h")
		var sequence: Array[int]
		if sideways:
			sequence = [4, 5, 3]
		else:
			sequence = [1, 2, 0]
		var index = mini(anim_step, sequence.size() - 1)
		set_sprite_frame(sprite, folder, sequence[index])
		if (anim_timer % 4) == 0:
			anim_step += 1
		if anim_timer == 0:
			anim_step = 0
			set_sprite_frame(sprite, folder, 3 if sideways else 0)
		return

	var p = player()
	if p == null:
		return

	# Object $41 always calls SolidObject first. This is important even when the
	# active spring face is not touched: Sonic must still collide with the shell
	# Phase 12 note: a right-launching spring is struck on its RIGHT face (Sonic
	# stands to the right of the object); Phase 10 had this polarity reversed.
	# from the sides/back/bottom instead of passing through it.
	if sideways:
		var contact = p.resolve_solid_box_contact(spawn_x, spawn_y, 8, 14, true, record_index)
		var direction = -1 if x_flip else 1
		var active_contact = SonicPlayer.SOLID_RIGHT if direction > 0 else SonicPlayer.SOLID_LEFT
		if contact != active_contact:
			return
		p.spring_bounce(Vector2i(direction, 0), spring_power)
		p.lock_time = 15
		_start_animation()
		return

	var vertical_contact = p.resolve_solid_box_contact(spawn_x, spawn_y, 16, 8, true, record_index)
	if downward:
		if vertical_contact != SonicPlayer.SOLID_BOTTOM:
			return
		p.spring_bounce(Vector2i(0, 1), spring_power)
	else:
		if vertical_contact != SonicPlayer.SOLID_TOP:
			return
		p.spring_bounce(Vector2i(0, -1), spring_power)
	_start_animation()

func _start_animation() -> void:
	anim_timer = 12
	anim_step = 0
