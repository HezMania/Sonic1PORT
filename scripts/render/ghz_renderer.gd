class_name GHZRenderer
extends Node2D

# Plane A is split into low- and high-priority tile layers so Genesis pattern
# priority can sit correctly behind/in front of Sonic. This is important for
# GHZ loops and other terrain that uses the VDP priority bit.
const MZ_MAGMA_ANIM_TILE = 0x2D2

var level: GHZLevelData
var chunk_texture_cache: Dictionary = {}
var art_range_patch_cache: Dictionary = {}
var palette_patch_cache: Dictionary = {}

# Phase 72 Hotfix 1: zones whose terrain art is static but whose CRAM changes
# frequently are stored as palette indices instead of precomposited RGBA.
# PaletteCycle can then update only a 64x1 texture, matching the VDP model and
# avoiding repeated 256x256 chunk redraw/upload work.
var palette_indexed_mode = false
var cycle_palette_image: Image
var cycle_palette_texture: ImageTexture
var cycle_palette_material: ShaderMaterial

func build(level_data: GHZLevelData) -> void:
	level = level_data
	for child in get_children():
		child.queue_free()
	chunk_texture_cache.clear()
	art_range_patch_cache.clear()
	palette_patch_cache.clear()
	palette_indexed_mode = level != null and level.zone_id in [
		LevelCatalog.ZONE_GHZ, LevelCatalog.ZONE_LZ, LevelCatalog.ZONE_SLZ,
		LevelCatalog.ZONE_SYZ, LevelCatalog.ZONE_SBZ, LevelCatalog.ZONE_ENDING,
		# Phase 90 Hotfix 1: CPZ has live CRAM cycling. Keep its 128x128
		# foreground as palette indices too, so PalCycle_CPZ updates the 64x1
		# palette texture instead of destructively re-rasterizing tile patches.
		LevelCatalog.ZONE_S2_CPZ_TEST, LevelCatalog.ZONE_S2_ARZ_TEST, LevelCatalog.ZONE_S2_CNZ_TEST, LevelCatalog.ZONE_S2_MCZ_TEST, LevelCatalog.ZONE_S2_OOZ_TEST, LevelCatalog.ZONE_S2_MTZ_TEST, LevelCatalog.ZONE_S2_WFZ_TEST, LevelCatalog.ZONE_S2_DEZ_TEST,
	]
	cycle_palette_image = null
	cycle_palette_texture = null
	cycle_palette_material = null
	if palette_indexed_mode:
		_setup_cycle_palette_material()

	for chunk_y in range(level.layout_height):
		for chunk_x in range(level.layout_width):
			var raw_chunk_id := level.get_chunk_id_at(chunk_x, chunk_y)
			var chunk_id := level.decode_layout_chunk_id(raw_chunk_id)
			if chunk_id == 0:
				continue

			var textures := _get_chunk_textures(chunk_id)
			var high_z:=_terrain_high_priority_z()
			for wrap_y in _vertical_copy_offsets():
				_add_chunk_sprite(textures["low"], chunk_x, chunk_y, 0, "Low", wrap_y)
				_add_chunk_sprite(textures["high"], chunk_x, chunk_y, high_z, "High", wrap_y)

func _terrain_high_priority_z() -> int:
	# SCZ uses shared WFZ/SCZ terrain for the distant fortress silhouettes. Those
	# pattern-priority pieces are scenery during the fly-by and must remain behind
	# Sonic and the Tornado in the native scene tree. WFZ restores ordinary VDP
	# high-priority foreground semantics when the fortress becomes playable.
	if level != null and level.zone_id == LevelCatalog.ZONE_S2_SCZ_TEST:
		return 30
	return 100

func _vertical_copy_offsets() -> Array[int]:
	if level != null and level.vertical_wrap_enabled():
		return [-0x800, 0, 0x800]
	return [0]

func _add_chunk_sprite(texture: Texture2D, chunk_x: int, chunk_y: int, priority_z: int, suffix: String, wrap_y: int = 0) -> void:
	var sprite := Sprite2D.new()
	var display_chunk = level.decode_layout_chunk_id(level.get_chunk_id_at(chunk_x, chunk_y))
	sprite.name = "Chunk_%02X_%d_%d_%s_W%+d" % [display_chunk, chunk_x, chunk_y, suffix, wrap_y]
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = texture
	if palette_indexed_mode and cycle_palette_material != null:
		sprite.material = cycle_palette_material
	var chunk_size = level.chunk_pixel_size()
	sprite.position = Vector2(chunk_x * chunk_size, chunk_y * chunk_size + wrap_y)
	sprite.z_index = priority_z
	add_child(sprite)

func refresh_chunk(chunk_x: int, chunk_y: int) -> void:
	if level == null or chunk_x < 0 or chunk_y < 0 or chunk_x >= level.layout_width or chunk_y >= level.layout_height:
		return
	var world_positions: Array[Vector2] = []
	for wrap_y in _vertical_copy_offsets():
		world_positions.append(Vector2(chunk_x * level.chunk_pixel_size(), chunk_y * level.chunk_pixel_size() + wrap_y))
	for child in get_children():
		if child is Sprite2D and child.position in world_positions:
			remove_child(child)
			child.queue_free()
	var raw_chunk_id = level.get_chunk_id_at(chunk_x, chunk_y)
	var chunk_id = level.decode_layout_chunk_id(raw_chunk_id)
	if chunk_id == 0:
		return
	var textures = _get_chunk_textures(chunk_id)
	var high_z:=_terrain_high_priority_z()
	for wrap_y in _vertical_copy_offsets():
		_add_chunk_sprite(textures["low"], chunk_x, chunk_y, 0, "Low", wrap_y)
		_add_chunk_sprite(textures["high"], chunk_x, chunk_y, high_z, "High", wrap_y)

func _get_chunk_textures(chunk_id: int) -> Dictionary:
	if chunk_texture_cache.has(chunk_id):
		return chunk_texture_cache[chunk_id]

	var images = _render_chunk_index_images(chunk_id) if palette_indexed_mode else _render_chunk_images(chunk_id)
	var textures = {
		"low": ImageTexture.create_from_image(images["low"]),
		"high": ImageTexture.create_from_image(images["high"]),
		"low_image": images["low"],
		"high_image": images["high"],
	}
	chunk_texture_cache[chunk_id] = textures
	# A later dynamic layout event can introduce a chunk ID that was not present
	# during the original build. Recompute animated-range membership next time.
	art_range_patch_cache.clear()
	palette_patch_cache.clear()
	return textures


func _setup_cycle_palette_material() -> void:
	var shader = load("res://scripts/render/genesis_index_palette.gdshader")
	if shader == null:
		palette_indexed_mode = false
		return
	cycle_palette_image = Image.create_empty(64, 1, false, Image.FORMAT_RGBA8)
	cycle_palette_texture = ImageTexture.create_from_image(cycle_palette_image)
	cycle_palette_material = ShaderMaterial.new()
	cycle_palette_material.shader = shader
	cycle_palette_material.set_shader_parameter("genesis_palette", cycle_palette_texture)
	_update_cycle_palette_texture()

func _update_cycle_palette_texture() -> void:
	if cycle_palette_image == null or cycle_palette_texture == null or level == null or level.palette.size() < 64:
		return
	for i in range(64):
		cycle_palette_image.set_pixel(i, 0, level.palette[i])
	cycle_palette_texture.update(cycle_palette_image)

func _render_chunk_index_images(chunk_id: int) -> Dictionary:
	var chunk_size = level.chunk_pixel_size()
	var blocks = level.blocks_per_chunk()
	var low_image = Image.create_empty(chunk_size, chunk_size, false, Image.FORMAT_R8)
	var high_image = Image.create_empty(chunk_size, chunk_size, false, Image.FORMAT_R8)
	low_image.fill(Color(0, 0, 0, 1))
	high_image.fill(Color(0, 0, 0, 1))
	var chunk_offset = level.chunk_data_offset(chunk_id)
	for block_y in range(blocks):
		for block_x in range(blocks):
			var word_offset = chunk_offset + (block_y * blocks + block_x) * 2
			if word_offset + 1 >= level.chunks.size():
				continue
			var block_word = _be16(level.chunks, word_offset)
			_draw_block_indices(low_image, high_image, block_word, block_x * 16, block_y * 16)
	return {"low": low_image, "high": high_image}

func _draw_block_indices(low_image: Image, high_image: Image, chunk_word: int, target_x: int, target_y: int) -> void:
	chunk_word = level.normalize_chunk_word(chunk_word, GHZLevelData.COLLISION_PATH_PRIMARY)
	var block_id = chunk_word & 0x3FF
	var block_flip_x = (chunk_word & 0x0800) != 0
	var block_flip_y = (chunk_word & 0x1000) != 0
	for out_tile_y in range(2):
		for out_tile_x in range(2):
			var source_tile_x = 1 - out_tile_x if block_flip_x else out_tile_x
			var source_tile_y = 1 - out_tile_y if block_flip_y else out_tile_y
			var tile_word = level.get_block_tile_word(block_id, source_tile_y * 2 + source_tile_x)
			var tile_index = tile_word & 0x7FF
			var palette_line = (tile_word >> 13) & 3
			var tile_flip_x = ((tile_word & 0x0800) != 0) != block_flip_x
			var tile_flip_y = ((tile_word & 0x1000) != 0) != block_flip_y
			var target_image = high_image if (tile_word & 0x8000) != 0 else low_image
			for py in range(8):
				var sample_y = 7 - py if tile_flip_y else py
				for px in range(8):
					var sample_x = 7 - px if tile_flip_x else px
					var color_index = level.get_tile_pixel(tile_index, sample_x, sample_y)
					if color_index == 0:
						continue
					var palette_index = palette_line * 16 + color_index
					target_image.set_pixel(
						target_x + out_tile_x * 8 + px,
						target_y + out_tile_y * 8 + py,
						Color(float(palette_index) / 255.0, 0, 0, 1)
					)

func refresh_palette_indices(changed_indices: Array[int]) -> void:
	if palette_indexed_mode:
		_update_cycle_palette_texture()
		return
	# Phase 72 fallback CRAM-cycle path for GHZ/Ending, whose foreground art also
	# has live VRAM animation and therefore still uses the existing RGBA cache.
	# so recolour only source 8x8 placements that use the affected palette
	# lines and only upload chunk types currently near the camera. This keeps
	# the source palette identity exact without final-RGB guessing.
	if level == null or changed_indices.is_empty():
		return
	var lines: Array[int] = []
	for index in changed_indices:
		var line := int(index) >> 4
		if not lines.has(line):
			lines.append(line)
	lines.sort()
	var key_parts: Array[String] = []
	for line in lines:
		key_parts.append(str(line))
	var cache_key := "pal:" + ",".join(key_parts)
	if not palette_patch_cache.has(cache_key):
		var patch_map: Dictionary = {}
		for chunk_key in chunk_texture_cache.keys():
			var chunk_id := int(chunk_key)
			var patches := _collect_chunk_palette_patches(chunk_id, lines)
			if not patches.is_empty():
				patch_map[chunk_id] = patches
		palette_patch_cache[cache_key] = patch_map
	var visible_ids := _visible_foreground_chunk_ids(32)
	var patch_map: Dictionary = palette_patch_cache[cache_key]
	var tile_image_cache: Dictionary = {}
	for chunk_key in patch_map.keys():
		var chunk_id := int(chunk_key)
		if not visible_ids.has(chunk_id) or not chunk_texture_cache.has(chunk_id):
			continue
		var cached: Dictionary = chunk_texture_cache[chunk_id]
		var low_image := cached["low_image"] as Image
		var high_image := cached["high_image"] as Image
		var low_changed := false
		var high_changed := false
		for patch in patch_map[chunk_id]:
			if bool(patch["high"]):
				high_changed = true
			else:
				low_changed = true
			_redraw_tile_patch(low_image, high_image, patch, tile_image_cache)
		if low_changed:
			(cached["low"] as ImageTexture).update(low_image)
		if high_changed:
			(cached["high"] as ImageTexture).update(high_image)

func _collect_chunk_palette_patches(chunk_id: int, palette_lines: Array[int]) -> Array:
	var patches: Array = []
	var blocks = level.blocks_per_chunk()
	var chunk_offset = level.chunk_data_offset(chunk_id)
	for block_y in range(blocks):
		for block_x in range(blocks):
			var word_offset = chunk_offset + (block_y * blocks + block_x) * 2
			if word_offset + 1 >= level.chunks.size():
				continue
			var chunk_word := level.normalize_chunk_word(_be16(level.chunks, word_offset), GHZLevelData.COLLISION_PATH_PRIMARY)
			var block_id := chunk_word & 0x3FF
			var block_flip_x := (chunk_word & 0x0800) != 0
			var block_flip_y := (chunk_word & 0x1000) != 0
			for out_tile_y in range(2):
				for out_tile_x in range(2):
					var source_tile_x := 1 - out_tile_x if block_flip_x else out_tile_x
					var source_tile_y := 1 - out_tile_y if block_flip_y else out_tile_y
					var tile_word := level.get_block_tile_word(block_id, source_tile_y * 2 + source_tile_x)
					var palette_line := (tile_word >> 13) & 3
					if not palette_lines.has(palette_line):
						continue
					patches.append({
						"x": block_x * 16 + out_tile_x * 8,
						"y": block_y * 16 + out_tile_y * 8,
						"tile": tile_word & 0x7FF,
						"palette": palette_line,
						"flip_x": ((tile_word & 0x0800) != 0) != block_flip_x,
						"flip_y": ((tile_word & 0x1000) != 0) != block_flip_y,
						"high": (tile_word & 0x8000) != 0,
					})
	return patches

func refresh_art_range(first_tile: int, tile_count: int) -> void:
	# Phase 59 HF1: MZ magma is the one genuinely hot animation path. Some of
	# its 256x256 chunks contain 1024 animated 8x8 placements, and the original
	# Phase 59 pass updated every cached chunk of that type every two VBlanks.
	# Keep the exact VRAM animation, but only refresh chunk types near the camera
	# and collapse the four magma tiles in each 16x16 block into one native blit.
	if level == null or tile_count <= 0:
		return
	if level.zone_id == LevelCatalog.ZONE_MZ and first_tile == MZ_MAGMA_ANIM_TILE and tile_count == 16:
		_refresh_mz_magma_visible(first_tile, tile_count)
		return

	# Lower-frequency GHZ/MZ animation retains the Phase 59 tile patch path.
	var range_key = "%d:%d" % [first_tile, tile_count]
	if not art_range_patch_cache.has(range_key):
		var patch_map: Dictionary = {}
		for key in chunk_texture_cache.keys():
			var chunk_id = int(key)
			var patches = _collect_chunk_tile_patches(chunk_id, first_tile, first_tile + tile_count - 1)
			if not patches.is_empty():
				patch_map[chunk_id] = patches
		art_range_patch_cache[range_key] = patch_map

	var patch_map: Dictionary = art_range_patch_cache[range_key]
	var tile_image_cache: Dictionary = {}
	# Phase 87 Hotfix 1: EHZ's native-128 chunk cache grows quickly while the
	# player traverses the act. Animated VRAM DMA only needs to redraw chunks
	# that can currently be seen; updating every previously cached chunk causes
	# progressively worse stalls as the level continues.
	var limit_to_visible := level.zone_id == LevelCatalog.ZONE_S2_TEST or level.zone_id == LevelCatalog.ZONE_S2_CNZ_TEST or level.zone_id == LevelCatalog.ZONE_S2_OOZ_TEST or level.zone_id == LevelCatalog.ZONE_S2_MTZ_TEST
	var visible_ids: Dictionary = _visible_foreground_chunk_ids(32) if limit_to_visible else {}
	for chunk_key in patch_map.keys():
		var chunk_id = int(chunk_key)
		if limit_to_visible and not visible_ids.has(chunk_id):
			continue
		if not chunk_texture_cache.has(chunk_id):
			continue
		var cached: Dictionary = chunk_texture_cache[chunk_id]
		var low_image = cached["low_image"] as Image
		var high_image = cached["high_image"] as Image
		var low_changed = false
		var high_changed = false
		for patch in patch_map[chunk_id]:
			if bool(patch["high"]):
				high_changed = true
			else:
				low_changed = true
			_redraw_tile_patch(low_image, high_image, patch, tile_image_cache)
		if low_changed:
			var low_texture = cached["low"] as ImageTexture
			low_texture.update(low_image)
		if high_changed:
			var high_texture = cached["high"] as ImageTexture
			high_texture.update(high_image)

func _refresh_mz_magma_visible(first_tile: int, tile_count: int) -> void:
	var range_key = "magma_blocks:%d:%d" % [first_tile, tile_count]
	if not art_range_patch_cache.has(range_key):
		var patch_map: Dictionary = {}
		for key in chunk_texture_cache.keys():
			var chunk_id = int(key)
			var patches = _collect_chunk_block_patches(chunk_id, first_tile, first_tile + tile_count - 1)
			if not patches.is_empty():
				patch_map[chunk_id] = patches
		art_range_patch_cache[range_key] = patch_map

	var patch_map: Dictionary = art_range_patch_cache[range_key]
	var visible_ids = _visible_foreground_chunk_ids(32)
	var block_image_cache: Dictionary = {}
	for chunk_key in patch_map.keys():
		var chunk_id = int(chunk_key)
		if not visible_ids.has(chunk_id) or not chunk_texture_cache.has(chunk_id):
			continue
		var cached: Dictionary = chunk_texture_cache[chunk_id]
		var low_image = cached["low_image"] as Image
		var high_image = cached["high_image"] as Image
		var low_changed = false
		var high_changed = false
		for patch in patch_map[chunk_id]:
			var changed = _redraw_block_patch(low_image, high_image, patch, block_image_cache)
			low_changed = low_changed or (changed & 1) != 0
			high_changed = high_changed or (changed & 2) != 0
		if low_changed:
			var low_texture = cached["low"] as ImageTexture
			low_texture.update(low_image)
		if high_changed:
			var high_texture = cached["high"] as ImageTexture
			high_texture.update(high_image)

func _visible_foreground_chunk_ids(pixel_margin: int) -> Dictionary:
	var result: Dictionary = {}
	if level == null:
		return result
	var current_scene = get_tree().current_scene
	var camera: Camera2D = null
	if current_scene != null:
		camera = current_scene.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		# Conservative fallback for unusual test scenes: retain the Phase 59
		# behavior rather than risking a missing animation.
		for key in chunk_texture_cache.keys():
			result[int(key)] = true
		return result
	var viewport_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var screen_x = int(camera.position.x) - (viewport_width >> 1)
	var screen_y = int(camera.position.y) - (viewport_height >> 1)
	var shift = level.chunk_shift()
	var left = maxi(0, (screen_x - pixel_margin) >> shift)
	var top = maxi(0, (screen_y - pixel_margin) >> shift)
	var right = mini(level.layout_width - 1, (screen_x + viewport_width - 1 + pixel_margin) >> shift)
	var bottom = mini(level.layout_height - 1, (screen_y + viewport_height - 1 + pixel_margin) >> shift)
	for chunk_y in range(top, bottom + 1):
		for chunk_x in range(left, right + 1):
			var chunk_id = level.decode_layout_chunk_id(level.get_chunk_id_at(chunk_x, chunk_y))
			if chunk_id != 0:
				result[chunk_id] = true
	return result

func _collect_chunk_block_patches(chunk_id: int, first_tile: int, last_tile: int) -> Array:
	var patches: Array = []
	var blocks = level.blocks_per_chunk()
	var chunk_offset = level.chunk_data_offset(chunk_id)
	for block_y in range(blocks):
		for block_x in range(blocks):
			var word_offset = chunk_offset + (block_y * blocks + block_x) * 2
			if word_offset + 1 >= level.chunks.size():
				continue
			var chunk_word = _be16(level.chunks, word_offset)
			var block_id = chunk_word & 0x3FF
			var affected = false
			for tile_slot in range(4):
				var tile_index = level.get_block_tile_word(block_id, tile_slot) & 0x7FF
				if tile_index >= first_tile and tile_index <= last_tile:
					affected = true
					break
			if affected:
				patches.append({
					"x": block_x * 16,
					"y": block_y * 16,
					"word": chunk_word,
				})
	return patches

func _redraw_block_patch(low_image: Image, high_image: Image, patch: Dictionary, block_image_cache: Dictionary) -> int:
	var chunk_word = int(patch["word"])
	if not block_image_cache.has(chunk_word):
		var block_low = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		var block_high = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		block_low.fill(Color(0, 0, 0, 0))
		block_high.fill(Color(0, 0, 0, 0))
		_draw_block(block_low, block_high, chunk_word, 0, 0)
		var block_id = chunk_word & 0x3FF
		var has_low = false
		var has_high = false
		for tile_slot in range(4):
			var tile_word = level.get_block_tile_word(block_id, tile_slot)
			if (tile_word & 0x8000) != 0:
				has_high = true
			else:
				has_low = true
		block_image_cache[chunk_word] = {
			"low": block_low,
			"high": block_high,
			"has_low": has_low,
			"has_high": has_high,
		}
	var block: Dictionary = block_image_cache[chunk_word]
	var block_low = block["low"] as Image
	var block_high = block["high"] as Image
	var target = Vector2i(int(patch["x"]), int(patch["y"]))
	var changed = 0
	if bool(block["has_low"]):
		low_image.blit_rect(block_low, Rect2i(0, 0, 16, 16), target)
		changed |= 1
	if bool(block["has_high"]):
		high_image.blit_rect(block_high, Rect2i(0, 0, 16, 16), target)
		changed |= 2
	return changed

func _collect_chunk_tile_patches(chunk_id: int, first_tile: int, last_tile: int) -> Array:
	var patches: Array = []
	var blocks = level.blocks_per_chunk()
	var chunk_offset = level.chunk_data_offset(chunk_id)
	for block_y in range(blocks):
		for block_x in range(blocks):
			var word_offset = chunk_offset + (block_y * blocks + block_x) * 2
			if word_offset + 1 >= level.chunks.size():
				continue
			var chunk_word = level.normalize_chunk_word(_be16(level.chunks, word_offset), GHZLevelData.COLLISION_PATH_PRIMARY)
			var block_id = chunk_word & 0x3FF
			var block_flip_x = (chunk_word & 0x0800) != 0
			var block_flip_y = (chunk_word & 0x1000) != 0
			for out_tile_y in range(2):
				for out_tile_x in range(2):
					var source_tile_x = 1 - out_tile_x if block_flip_x else out_tile_x
					var source_tile_y = 1 - out_tile_y if block_flip_y else out_tile_y
					var tile_slot = source_tile_y * 2 + source_tile_x
					var tile_word = level.get_block_tile_word(block_id, tile_slot)
					var tile_index = tile_word & 0x7FF
					if tile_index < first_tile or tile_index > last_tile:
						continue
					patches.append({
						"x": block_x * 16 + out_tile_x * 8,
						"y": block_y * 16 + out_tile_y * 8,
						"tile": tile_index,
						"palette": (tile_word >> 13) & 3,
						"flip_x": ((tile_word & 0x0800) != 0) != block_flip_x,
						"flip_y": ((tile_word & 0x1000) != 0) != block_flip_y,
						"high": (tile_word & 0x8000) != 0,
					})
	return patches

func _redraw_tile_patch(low_image: Image, high_image: Image, patch: Dictionary, tile_image_cache: Dictionary) -> void:
	var target_image = high_image if bool(patch["high"]) else low_image
	var target_x = int(patch["x"])
	var target_y = int(patch["y"])
	var tile_image = _animated_tile_index_image(patch, tile_image_cache) if target_image.get_format() == Image.FORMAT_R8 else _animated_tile_image(patch, tile_image_cache)
	# blit_rect copies alpha too, so transparent color-index 0 correctly erases
	# pixels that were opaque in the previous animation frame. The copy runs in
	# native Image code instead of 64 GDScript set_pixel calls per placement.
	target_image.blit_rect(tile_image, Rect2i(0, 0, 8, 8), Vector2i(target_x, target_y))

func _animated_tile_index_image(patch: Dictionary, tile_image_cache: Dictionary) -> Image:
	var tile_index = int(patch["tile"])
	var palette_line = int(patch["palette"])
	var flip_x = bool(patch["flip_x"])
	var flip_y = bool(patch["flip_y"])
	var cache_key = "idx:%d:%d:%d:%d" % [tile_index, palette_line, int(flip_x), int(flip_y)]
	if tile_image_cache.has(cache_key):
		return tile_image_cache[cache_key] as Image
	var image = Image.create_empty(8, 8, false, Image.FORMAT_R8)
	image.fill(Color(0, 0, 0, 1))
	for py in range(8):
		var sample_y = 7 - py if flip_y else py
		for px in range(8):
			var sample_x = 7 - px if flip_x else px
			var color_index = level.get_tile_pixel(tile_index, sample_x, sample_y)
			if color_index == 0:
				continue
			var palette_index = palette_line * 16 + color_index
			image.set_pixel(px, py, Color(float(palette_index) / 255.0, 0, 0, 1))
	tile_image_cache[cache_key] = image
	return image

func _animated_tile_image(patch: Dictionary, tile_image_cache: Dictionary) -> Image:
	var tile_index = int(patch["tile"])
	var palette_line = int(patch["palette"])
	var flip_x = bool(patch["flip_x"])
	var flip_y = bool(patch["flip_y"])
	var cache_key = "%d:%d:%d:%d" % [tile_index, palette_line, int(flip_x), int(flip_y)]
	if tile_image_cache.has(cache_key):
		return tile_image_cache[cache_key] as Image
	var image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for py in range(8):
		var sample_y = 7 - py if flip_y else py
		for px in range(8):
			var sample_x = 7 - px if flip_x else px
			var color_index = level.get_tile_pixel(tile_index, sample_x, sample_y)
			if color_index == 0:
				continue
			var palette_index = palette_line * 16 + color_index
			if palette_index >= 0 and palette_index < level.palette.size():
				image.set_pixel(px, py, level.palette[palette_index])
	tile_image_cache[cache_key] = image
	return image

func _render_chunk_images(chunk_id: int) -> Dictionary:
	var chunk_size = level.chunk_pixel_size()
	var blocks = level.blocks_per_chunk()
	var low_image = Image.create_empty(chunk_size, chunk_size, false, Image.FORMAT_RGBA8)
	var high_image = Image.create_empty(chunk_size, chunk_size, false, Image.FORMAT_RGBA8)
	low_image.fill(Color(0, 0, 0, 0))
	high_image.fill(Color(0, 0, 0, 0))
	var chunk_offset = level.chunk_data_offset(chunk_id)

	for block_y in range(blocks):
		for block_x in range(blocks):
			var word_offset = chunk_offset + (block_y * blocks + block_x) * 2
			if word_offset + 1 >= level.chunks.size():
				continue
			var block_word = _be16(level.chunks, word_offset)
			_draw_block(low_image, high_image, block_word, block_x * 16, block_y * 16)
	return {"low": low_image, "high": high_image}

func _draw_block(low_image: Image, high_image: Image, chunk_word: int, target_x: int, target_y: int) -> void:
	chunk_word = level.normalize_chunk_word(chunk_word, GHZLevelData.COLLISION_PATH_PRIMARY)
	var block_id := chunk_word & 0x3FF
	var block_flip_x := (chunk_word & 0x0800) != 0
	var block_flip_y := (chunk_word & 0x1000) != 0

	for out_tile_y in range(2):
		for out_tile_x in range(2):
			var source_tile_x := 1 - out_tile_x if block_flip_x else out_tile_x
			var source_tile_y := 1 - out_tile_y if block_flip_y else out_tile_y
			var tile_slot := source_tile_y * 2 + source_tile_x
			var tile_word := level.get_block_tile_word(block_id, tile_slot)
			var tile_index := tile_word & 0x7FF
			var palette_line := (tile_word >> 13) & 3
			var tile_flip_x := ((tile_word & 0x0800) != 0) != block_flip_x
			var tile_flip_y := ((tile_word & 0x1000) != 0) != block_flip_y
			var target_image := high_image if (tile_word & 0x8000) != 0 else low_image

			for py in range(8):
				var sample_y := 7 - py if tile_flip_y else py
				for px in range(8):
					var sample_x := 7 - px if tile_flip_x else px
					var color_index := level.get_tile_pixel(tile_index, sample_x, sample_y)
					if color_index == 0:
						continue
					var palette_index := palette_line * 16 + color_index
					if palette_index >= 0 and palette_index < level.palette.size():
						target_image.set_pixel(
							target_x + out_tile_x * 8 + px,
							target_y + out_tile_y * 8 + py,
							level.palette[palette_index]
						)

static func _be16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])
