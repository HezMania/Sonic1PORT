class_name LamppostObject
extends GenesisLevelObject

# Object 79 - Lamppost. Stores the latest checkpoint ID/position and reproduces
# the blue -> twirl -> red visual transition. Phase 4 restores position/camera
# on death; time/DLE/water snapshots are left for the zone-general pass.

var base_sprite: Sprite2D
var twirl_sprite: Sprite2D
var activated := false
var twirl_timer := 0
var twirl_angle := 0

func initialize_object() -> void:
	active_width = 8
	activated = manager.checkpoint_id >= (subtype & 0x7F)
	base_sprite = make_sprite("res://assets/objects/lamppost/03.png" if activated else "res://assets/objects/lamppost/00.png")

func tick() -> void:
	if activated:
		_update_twirl()
		return
	var p = player()
	if p == null or p.dead:
		return
	var dx = p.pixel_x() - spawn_x
	var dy = p.pixel_y() - spawn_y
	if dx < -8 or dx > 7 or dy < -64 or dy > 39:
		return

	activated = true
	manager.activate_checkpoint(subtype & 0x7F, spawn_x, spawn_y)
	set_sprite_frame(base_sprite, "lamppost", 1)
	twirl_sprite = make_sprite("res://assets/objects/lamppost/02.png", 1)
	twirl_timer = 32
	twirl_angle = 0
	_update_twirl()

func _update_twirl() -> void:
	if twirl_sprite == null or not is_instance_valid(twirl_sprite):
		if activated:
			set_sprite_frame(base_sprite, "lamppost", 3)
		return
	if twirl_timer <= 0:
		twirl_sprite.queue_free()
		twirl_sprite = null
		set_sprite_frame(base_sprite, "lamppost", 3)
		return

	twirl_timer -= 1
	twirl_angle = (twirl_angle - 0x10) & 0xFF
	# Lamp_Twirl uses a 12-pixel radius around (origX, origY-$18).
	var angle_work = (twirl_angle - 0x40) & 0xFF
	var x_offset = (GenesisMath.cosine(angle_work) * 12) >> 8
	var y_offset = (GenesisMath.sine(angle_work) * 12) >> 8
	twirl_sprite.position = Vector2(x_offset, -24 + y_offset)
