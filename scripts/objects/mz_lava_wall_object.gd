class_name MZLavaWallObject
extends GenesisLevelObject

# Object $4E - the single advancing lava wall in MZ2.

var sprite: Sprite2D
var back_sprite: Sprite2D
var moving := false
var armed := false
var vel_x := 0
var anim_tick := 0

func initialize_object() -> void:
	active_width = 80
	sprite = make_sprite("res://assets/objects/mz_lavawall/00.png", 4)
	# Frame 4 is the separate 128px back child from LWall_BackChild. Keep it at
	# the same high object priority as the front so foreground terrain cannot
	# hide the magma body while leaving only the leading edge visible.
	back_sprite = make_sprite("res://assets/objects/mz_lavawall/04.png", 4)
	back_sprite.position.x = -128

func tick() -> void:
	if not alive:
		return
	var p = player()
	if p == null:
		return
	anim_tick += 1
	if not armed:
		if absi(p.pixel_x() - int(position.x)) < 192 and absi(p.pixel_y() - int(position.y)) < 96:
			armed = true
	elif not moving:
		moving = true
		vel_x = 0x180
	if moving and not p.hurt_state and not p.dead:
		position.x += float(vel_x) / 256.0
		if int(position.x) >= 0x6A0:
			position.x = 0x6A0
			vel_x = 0
			moving = false
	var frame = (anim_tick >> 3) & 3
	set_sprite_frame(sprite, "mz_lavawall", frame)
	# SolidObject + hurt collision: it cannot be passed through, and touching lava hurts.
	p.resolve_solid_box_contact(int(position.x) - 16, int(position.y), 64, 24, true, record_index)
	if absi(p.pixel_x() - (int(position.x) - 16)) <= p.width_radius + 64 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 32:
		p.apply_hazard_hit(int(position.x))
