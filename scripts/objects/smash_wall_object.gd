class_name SmashWallObject
extends GenesisLevelObject

# Object $3C - shared GHZ / SLZ smashable wall.
var wall_sprite: Sprite2D
var smashed := false
var fragments: Array[Sprite2D] = []
var fragment_velocities: Array[Vector2i] = []

const SPEEDS_RIGHT: Array[Vector2i] = [
	Vector2i(0x400,-0x500), Vector2i(0x600,-0x100), Vector2i(0x600,0x100), Vector2i(0x400,0x500),
	Vector2i(0x600,-0x600), Vector2i(0x800,-0x200), Vector2i(0x800,0x200), Vector2i(0x600,0x600),
]
const SPEEDS_LEFT: Array[Vector2i] = [
	Vector2i(-0x600,-0x600), Vector2i(-0x800,-0x200), Vector2i(-0x800,0x200), Vector2i(-0x600,0x600),
	Vector2i(-0x400,-0x500), Vector2i(-0x600,-0x100), Vector2i(-0x600,0x100), Vector2i(-0x400,0x500),
]

func initialize_object() -> void:
	active_width = 16
	var frame = clampi(subtype & 0x0F, 0, 2)
	if _is_slz():
		wall_sprite = make_sprite("")
		wall_sprite.texture = SourceObjectArt.slz_smash_wall_texture(false)
	else:
		wall_sprite = make_sprite("res://assets/objects/smash_wall/%02d.png" % frame)

func tick() -> void:
	if smashed:
		_tick_fragments()
		return
	var p = player()
	if p == null or p.dead:
		return
	var saved_vx = p.vel_x
	var contact = p.resolve_solid_box_contact(spawn_x, spawn_y, 16, 32, true, record_index)
	if contact != SonicPlayer.SOLID_LEFT and contact != SonicPlayer.SOLID_RIGHT:
		return
	# Smash_Solid only reaches .chkroll when SolidObject has set the pushing
	# status bit. An airborne jump uses the roll animation too, but it does not
	# count as pushing, so jumping into the wall must not smash it.
	# SolidObject sets the source pushing bits for any grounded lateral side
	# collision; it does not require the direction button to still be held. The
	# native generic box helper makes `pushing` input-dependent, so using that
	# flag here prevented a fast coasting roll from smashing the wall. A grounded
	# side contact plus the source roll/speed checks is the faithful condition.
	if p.in_air or not p.rolling or absi(saved_vx) < 0x480:
		return
	p.vel_x = saved_vx
	p.inertia = saved_vx
	if contact == SonicPlayer.SOLID_LEFT:
		p.fixed_x += 4 << 16
		_smash(true)
	else:
		p.fixed_x -= 4 << 16
		_smash(false)
	p.pushing = false
	p._sync_position()

func _smash(to_right: bool) -> void:
	smashed = true
	wall_sprite.visible = false
	manager.mark_record_destroyed(record_index)
	var frame = clampi(subtype & 0x0F, 0, 2)
	var groups: Array[int]
	if frame == 0:
		groups = [0,0,0,0,1,1,1,1]
	elif frame == 1:
		groups = [1,1,1,1,1,1,1,1]
	else:
		groups = [1,1,1,1,2,2,2,2]
	var offsets = [Vector2(-8,-24),Vector2(-8,-8),Vector2(-8,8),Vector2(-8,24),Vector2(8,-24),Vector2(8,-8),Vector2(8,8),Vector2(8,24)]
	var speeds = SPEEDS_RIGHT if to_right else SPEEDS_LEFT
	for i in range(8):
		var sp: Sprite2D
		if _is_slz():
			sp = make_sprite("", 1)
			sp.texture = SourceObjectArt.slz_smash_wall_texture(true)
		else:
			sp = make_sprite("res://assets/objects/smash_fragment/%02d.png" % groups[i], 1)
		sp.position = offsets[i]
		fragments.append(sp)
		fragment_velocities.append(speeds[i])

func _tick_fragments() -> void:
	var remaining = 0
	for i in range(fragments.size()):
		var sp = fragments[i]
		if not sp.visible:
			continue
		var v = fragment_velocities[i]
		sp.position += Vector2(float(v.x) / 256.0, float(v.y) / 256.0)
		v.y = GenesisMath.s16(v.y + 0x70)
		fragment_velocities[i] = v
		if absi(int(sp.position.x)) > 512 or int(sp.position.y) > 384:
			sp.visible = false
		else:
			remaining += 1
	if remaining == 0:
		request_delete(false)

func _is_slz() -> bool:
	return manager != null and int(manager.level_definition.get("zone", -1)) == LevelCatalog.ZONE_SLZ
