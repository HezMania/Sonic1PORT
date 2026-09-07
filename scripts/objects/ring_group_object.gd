class_name RingGroupObject
extends GenesisLevelObject

const POS_DATA: Array[Vector2i] = [
	Vector2i(0x10, 0), Vector2i(0x18, 0), Vector2i(0x20, 0),
	Vector2i(0, 0x10), Vector2i(0, 0x18), Vector2i(0, 0x20),
	Vector2i(0x10, 0x10), Vector2i(0x18, 0x18), Vector2i(0x20, 0x20),
	Vector2i(-0x10, 0x10), Vector2i(-0x18, 0x18), Vector2i(-0x20, 0x20),
	Vector2i(0x10, 8), Vector2i(0x18, 0x10),
	Vector2i(-0x10, 8), Vector2i(-0x18, 0x10),
]

var ring_sprites: Array[Sprite2D] = []
var ring_offsets: Array[Vector2i] = []
var sparkle_sprites: Dictionary = {}
var sparkle_timers: Dictionary = {}
var frame_counter := 0

func initialize_object() -> void:
	active_width = 8
	var orientation = (subtype >> 4) & 0x0F
	var count = mini(8, (subtype & 7) + 1)
	var spacing = POS_DATA[orientation]
	var collected_mask = manager.get_ring_mask(record_index)

	for i in range(count):
		var offset = spacing * i
		ring_offsets.append(offset)
		var sprite = Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		sprite.position = Vector2(offset)
		set_sprite_frame(sprite, "rings", 0)
		sprite.visible = (collected_mask & (1 << i)) == 0
		add_child(sprite)
		ring_sprites.append(sprite)

func tick() -> void:
	if not alive:
		return
	frame_counter += 1
	_tick_sparkles()
	var frame = (frame_counter >> 3) & 3
	var collected_mask = manager.get_ring_mask(record_index)
	var remaining = 0
	var p = player()
	for i in range(ring_sprites.size()):
		var sprite = ring_sprites[i]
		if (collected_mask & (1 << i)) != 0:
			sprite.visible = false
			continue
		remaining += 1
		set_sprite_frame(sprite, "rings", frame)
		if p == null or p.dead or p.invulnerability_timer >= 90:
			continue
		var ring_world = Vector2(spawn_x + ring_offsets[i].x, spawn_y + ring_offsets[i].y)
		if absf(float(p.pixel_x()) - ring_world.x) <= 12.0 and absf(float(p.pixel_y()) - ring_world.y) <= 12.0:
			manager.collect_ring(record_index, i)
			collected_mask = manager.get_ring_mask(record_index)
			sprite.visible = false
			_start_sparkle(i)
			remaining -= 1

	# Ring_Collect advances to Ring_Sparkle rather than deleting immediately.
	# Keep this group alive until its final collected ring finishes frames 4..7.
	if remaining <= 0 and sparkle_sprites.is_empty():
		request_delete(true)

func _start_sparkle(index: int) -> void:
	if sparkle_sprites.has(index):
		return
	var sparkle = Sprite2D.new()
	sparkle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sparkle.centered = true
	sparkle.position = Vector2(ring_offsets[index])
	sparkle.z_index = 1
	set_sprite_frame(sparkle, "rings", 4)
	add_child(sparkle)
	sparkle_sprites[index] = sparkle
	sparkle_timers[index] = 0

func _tick_sparkles() -> void:
	var finished: Array = []
	for key in sparkle_sprites.keys():
		var timer = int(sparkle_timers[key]) + 1
		sparkle_timers[key] = timer
		# Ani_Ring: delay 5, frames 4,5,6,7, then afRoutine.
		var frame_index = int(timer / 6)
		var sparkle = sparkle_sprites[key] as Sprite2D
		if frame_index >= 4:
			sparkle.queue_free()
			finished.append(key)
		else:
			set_sprite_frame(sparkle, "rings", 4 + frame_index)
	for key in finished:
		sparkle_sprites.erase(key)
		sparkle_timers.erase(key)
