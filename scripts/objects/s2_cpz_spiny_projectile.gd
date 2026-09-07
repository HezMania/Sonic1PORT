class_name S2CPZSpinyProjectile
extends GenesisLevelObject

var sprite: Sprite2D
var vel_x := 0
var vel_y := 0
var frame_tick := 0
var life := 0

func setup_spiny(owner: SonicObjectManager, x: int, y: int, horizontal_velocity: int, vertical_velocity: int, face_left: bool) -> void:
	manager = owner
	record_index = -925000 - owner.elapsed_frames - owner.transient_objects.size()
	object_id = 0x98
	alive = true
	position = Vector2(x, y)
	vel_x = horizontal_velocity
	vel_y = vertical_velocity
	active_width = 8
	# Obj98 projectile must sort behind the parent Spiny body. The body uses
	# z=1 in this renderer; a later-created projectile at the same z was being
	# drawn over it.
	sprite = make_sprite("res://assets/objects/s2_cpz/spiny/06.png", 0)
	sprite.flip_h = face_left

func tick() -> void:
	frame_tick += 1
	life += 1
	# Obj98_SpinyShotFall applies +$20 gravity before ObjectMove.
	vel_y = GenesisMath.s16(vel_y + 0x20)
	position.x += float(vel_x) / 256.0
	position.y += float(vel_y) / 256.0
	set_sprite_frame(sprite, "s2_cpz/spiny", 6 + ((frame_tick >> 2) & 1))
	_hurt_player()
	if life > 600 or absi(int(position.x) - manager.current_screen_x) > 640 or int(position.y) > manager.current_screen_y + 512:
		request_delete(false)

func _hurt_player() -> void:
	var p = player()
	if p == null or p.dead:
		return
	if absi(p.pixel_x() - int(position.x)) <= 8 + p.width_radius and absi(p.pixel_y() - int(position.y)) <= 8 + p.height_radius:
		p.apply_hazard_hit(int(position.x))
