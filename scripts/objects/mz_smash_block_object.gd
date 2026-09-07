class_name MZSmashBlockObject
extends GenesisLevelObject

# Object $51 - smashable green block. Unlike GHZ's side-wall object, these
# break when Sonic lands on top while in the rolling/jumping animation.

var sprite: Sprite2D
var broken := false

func initialize_object() -> void:
	active_width = 16
	sprite = make_sprite("res://assets/objects/mz_smashblock/00.png")

func tick() -> void:
	if not alive or broken:
		return
	var p = player()
	if p == null:
		return
	var was_attack = p.can_attack_object()
	var contact = p.resolve_solid_box_contact(spawn_x, spawn_y, 16, 16, true, record_index)
	if contact == SonicPlayer.SOLID_TOP and was_attack:
		_smash(p)

func _smash(p: SonicPlayer) -> void:
	broken = true
	manager.mark_record_destroyed(record_index)
	p.clear_object_support_for(record_index, true)
	p.rolling = true
	p.in_air = true
	p.vel_y = -0x300
	# Smab_Scores uses the same escalating item-bonus chain concept.
	var points = manager.register_badnik_hit()
	manager.add_score(points)
	manager.spawn_points_popup(spawn_x, spawn_y, points)
	manager.spawn_mz_block_fragments(spawn_x, spawn_y)
	request_delete(false)
