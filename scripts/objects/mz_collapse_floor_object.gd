class_name MZCollapseFloorObject
extends GenesisLevelObject

# Object $53 - shared MZ/SLZ/SBZ collapsing floor. MZ3 uses subtype 1, selecting
# the source shuffled eight-fragment delay table. In SLZ the original swaps to
# ArtTile_SLZ_Collapsing_Floor and Map_CFlo frames 2/3; SBZ keeps frames 0/1
# but swaps to its own ArtTile_SBZ_Collapsing_Floor stream.
const SHUFFLE_DELAYS = [0x16, 0x1E, 0x1A, 0x12, 0x06, 0x0E, 0x0A, 0x02]
const SWIPE_DELAYS = [0x1E, 0x16, 0x0E, 0x06, 0x1A, 0x12, 0x0A, 0x02]

var sprite: Sprite2D
var touched = false
var pre_timer = 7
var fragmented = false
var fragments: Array[Dictionary] = []
var slz_mode := false
var sbz_mode := false

func initialize_object() -> void:
	active_width = 32
	var zone = int(manager.level_definition.get("zone", -1)) if manager != null else -1
	slz_mode = zone == LevelCatalog.ZONE_SLZ
	sbz_mode = zone == LevelCatalog.ZONE_SBZ
	if slz_mode or sbz_mode:
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.slz_collapse_floor_texture(false) if slz_mode else SourceObjectArt.sbz_collapse_floor_texture(false)
		# Both source whole-block mappings span local Y -8..+23, so a centered
		# 64x32 source texture sits 8 pixels below the object's mapping origin.
		sprite.position.y = 8.0
	else:
		sprite = make_sprite("res://assets/objects/mz_collapsefloor/00.png")

func tick() -> void:
	if not alive:
		return
	var p = player()
	if p == null:
		return
	if not fragmented:
		var contact = p.resolve_platform_top(spawn_x - 32, spawn_x + 32, spawn_y - 8, record_index)
		if (p.standing_on_object and p.support_record_index == record_index) or contact:
			touched = true
		if touched:
			pre_timer -= 1
			if pre_timer <= 0:
				_begin_fragmentation()
		return
	_tick_fragments(p)

func _begin_fragmentation() -> void:
	SonicAudio.play_sfx(SonicAudio.SFX_COLLAPSE)
	fragmented = true
	if sprite != null:
		sprite.visible = false
	var delays = SHUFFLE_DELAYS if (subtype & 1) != 0 else SWIPE_DELAYS
	# Fragmentate_8x2Floor switches Map_CFlo from the whole frame to its
	# eight-piece fragmented frame. SLZ uses frame 3 and its own exact source
	# art; MZ keeps the already-tested decoded PNG path.
	for i in range(8):
		var sp = Sprite2D.new()
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = true
		sp.region_enabled = true
		var col = i & 3
		var row = i >> 2
		if slz_mode or sbz_mode:
			sp.texture = SourceObjectArt.slz_collapse_floor_texture(true) if slz_mode else SourceObjectArt.sbz_collapse_floor_texture(true)
			sp.region_rect = Rect2(col * 16, row * 16, 16, 16)
		else:
			sp.texture = load("res://assets/objects/mz_collapsefloor/01.png")
			sp.region_rect = Rect2(32 + col * 16, 56 + row * 16, 16, 16)
		sp.position = Vector2(-24 + col * 16, row * 16)
		add_child(sp)
		fragments.append({"sprite": sp, "delay": int(delays[i]), "vel_y": 0, "alive": true})

func _tick_fragments(p: SonicPlayer) -> void:
	# Sonic stands on the upper row. Four 16px columns cover the 64px floor.
	var support_col = clampi(int((p.pixel_x() - (spawn_x - 32)) / 16), 0, 3)
	var support_alive = false
	var any_alive = false
	for i in range(fragments.size()):
		var f = fragments[i]
		if not bool(f.get("alive", false)):
			continue
		var raw_sprite = f.get("sprite")
		if raw_sprite == null or not is_instance_valid(raw_sprite):
			f["alive"] = false
			fragments[i] = f
			continue
		var sp = raw_sprite as Sprite2D
		any_alive = true
		var delay = int(f["delay"])
		if delay > 0:
			delay -= 1
			f["delay"] = delay
			# The upper fragment beneath Sonic remains a platform until its own
			# per-piece delay expires. Other pieces simply wait visibly in place.
			if i == support_col:
				support_alive = true
		else:
			# Once this individual fragment's delay reaches zero it begins falling.
			var vy = GenesisMath.s16(int(f["vel_y"]) + 0x38)
			f["vel_y"] = vy
			sp.position.y += float(vy) / 256.0
			if sp.position.y > 320:
				sp.queue_free()
				f["alive"] = false
		fragments[i] = f
	if p.standing_on_object and p.support_record_index == record_index:
		if support_alive:
			p.resolve_platform_top(spawn_x - 32, spawn_x + 32, spawn_y - 8, record_index)
		else:
			p.clear_object_support_for(record_index, true)
	if not any_alive:
		request_delete(true)
