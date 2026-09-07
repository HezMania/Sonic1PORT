class_name SpecialStageArt
extends RefCounted

# Phase 48 source-driven Special Stage block/background renderer. All art comes
# from the retained retail Nemesis/Enigma streams in data/s1; generated textures
# are cached in memory after first use.

static var _cache: Dictionary = {}
static var _raw_cache: Dictionary = {}
static var _palette_cache: Array[Color] = []

static func block_texture(block_id: int, angle_frame: int = 0, anim_frame: int = 0):
	block_id &= 0xFF
	angle_frame &= 0x0F
	anim_frame &= 7
	if block_id == 0 or block_id > 0x4E:
		return null
	if block_id >= 0x01 and block_id <= 0x24:
		var group := int((block_id - 1) / 9)
		var within := (block_id - 1) % 9
		return _wall_texture(group, angle_frame, within, anim_frame & 7)
	match block_id:
		0x25, 0x32, 0x33:
			var bump_frame := 0
			if block_id == 0x32:
				bump_frame = 1
			elif block_id == 0x33:
				bump_frame = 2
			return _bumper_texture(bump_frame)
		0x27:
			return _shared_texture("goal", "Special GOAL.nem", anim_frame & 1, 0)
		0x28:
			return _shared_texture("1up", "Special 1UP.nem", 0, 0)
		0x29:
			return _updown_texture(true, anim_frame & 1)
		0x2A:
			return _updown_texture(false, anim_frame & 1)
		0x2B, 0x31:
			# $31 is the touched R variant; it changes palette line, not art frame.
			return _shared_texture("reverse", "Special R.nem", 0, 0 if block_id == 0x31 else 1)
		0x2C:
			return _glass_like_texture("redwhite", "Special Red-White.nem", anim_frame & 3, 0)
		0x2D, 0x2E, 0x2F, 0x30:
			var palette_line = [0, 3, 1, 2][block_id - 0x2D]
			return _glass_like_texture("glass_%02X" % block_id, "Special Glass.nem", anim_frame & 3, palette_line)
		0x3A:
			return _ring_texture(anim_frame)
		0x42, 0x43, 0x44, 0x45:
			return _ring_sparkle_texture(block_id - 0x42)
		0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40:
			return _emerald_texture(block_id - 0x3B, anim_frame & 1)
		0x41:
			return _shared_texture("ghost", "Special Ghost.nem", 0, 0)
		0x46, 0x47, 0x48, 0x49:
			# Emerald/1UP sparkle animation IDs share the special emerald twinkle art.
			return _twinkle_texture(block_id - 0x46)
		0x4B, 0x4C, 0x4D, 0x4E:
			var flash_palette = [0, 3, 1, 2][block_id - 0x4B]
			return _glass_like_texture("glassani_%02X" % block_id, "Special Glass.nem", 0, flash_palette)
	return null

static func background_clouds_texture():
	const KEY := "ss_background_clouds"
	if _cache.has(KEY):
		return _cache[KEY]
	var raw := _raw("Special Clouds.nem")
	var palette := _palette()
	var path := "res://data/s1/tilemaps/SS Background 2.eni"
	if raw.is_empty() or palette.is_empty() or not FileAccess.file_exists(path):
		_cache[KEY] = null
		return null
	# Eni_SSBg2 is a 64x64 tilemap. The source adds Tile_Pal3; keep relative
	# tile indices at zero because this standalone raw stream starts at tile 0.
	var map_bytes := Enigma.decompress(FileAccess.get_file_as_bytes(path), 2 << 13)
	if map_bytes.size() < 64 * 64 * 2:
		_cache[KEY] = null
		return null
	var image := Image.create_empty(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(palette[32] if palette.size() > 32 else Color.BLACK)
	for ty in range(64):
		for tx in range(64):
			var off := (ty * 64 + tx) * 2
			var word := (int(map_bytes[off]) << 8) | int(map_bytes[off + 1])
			var tile := word & 0x7FF
			var pal_line := (word >> 13) & 3
			var flip_x := (word & 0x0800) != 0
			var flip_y := (word & 0x1000) != 0
			_draw_piece(image, raw, palette, tile, 1, 1, tx * 8, ty * 8, flip_x, flip_y, pal_line)
	var texture := ImageTexture.create_from_image(image)
	_cache[KEY] = texture
	return texture

static func background_bubbles_texture():
	const KEY := "ss_background_bubbles"
	if _cache.has(KEY):
		return _cache[KEY]
	var clouds = background_clouds_texture()
	if clouds == null:
		_cache[KEY] = null
		return null
	# SS_BGLoad copies the first 64x32 cells of Eni_SSBg2 to Plane 5 for
	# bubbles, while Plane 6 receives the full 64x64 map for clouds. Rebuild
	# the 512x256 Plane-5 image directly from the same retained source stream.
	var raw := _raw("Special Clouds.nem")
	var palette := _palette()
	var path := "res://data/s1/tilemaps/SS Background 2.eni"
	var map_bytes := Enigma.decompress(FileAccess.get_file_as_bytes(path), 2 << 13)
	var image := Image.create_empty(512, 256, false, Image.FORMAT_RGBA8)
	image.fill(palette[32] if palette.size() > 32 else Color.BLACK)
	for ty in range(32):
		for tx in range(64):
			var off := (ty * 64 + tx) * 2
			var word := (int(map_bytes[off]) << 8) | int(map_bytes[off + 1])
			var tile := word & 0x7FF
			var pal_line := (word >> 13) & 3
			var flip_x := (word & 0x0800) != 0
			var flip_y := (word & 0x1000) != 0
			_draw_piece(image, raw, palette, tile, 1, 1, tx * 8, ty * 8, flip_x, flip_y, pal_line)
	var texture := ImageTexture.create_from_image(image)
	_cache[KEY] = texture
	return texture

# Compatibility for any older caller retained in the project.
static func background_texture():
	return background_clouds_texture()

static func background_animals_texture(frame: int):
	frame = clampi(frame, 0, 6)
	var key := "ss_background_animals_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("Special Birds & Fish.nem")
	var palette := _palette()
	var path := "res://data/s1/tilemaps/SS Background 1.eni"
	if raw.is_empty() or palette.is_empty() or not FileAccess.file_exists(path):
		_cache[key] = null
		return null
	var map_bytes := Enigma.decompress(FileAccess.get_file_as_bytes(path), 2 << 13)
	if map_bytes.size() < 8 * 8 * 8 * 2:
		_cache[key] = null
		return null
	var image := Image.create_empty(512, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var first_active := frame < 4
	for square_y in range(4):
		for square_x in range(8):
			var active_square := ((square_x + square_y) & 1) == 0
			if not first_active:
				active_square = not active_square
			var canvas := frame + 1 if active_square else (0 if frame == 0 else -1)
			if canvas < 0:
				continue
			for ty in range(8):
				for tx in range(8):
					var word_off := (canvas * 64 + ty * 8 + tx) * 2
					var word := (int(map_bytes[word_off]) << 8) | int(map_bytes[word_off + 1])
					var tile := word & 0x7FF
					var pal_line := (word >> 13) & 3
					var flip_x := (word & 0x0800) != 0
					var flip_y := (word & 0x1000) != 0
					_draw_piece(image, raw, palette, tile, 1, 1, square_x * 64 + tx * 8, square_y * 64 + ty * 8, flip_x, flip_y, pal_line)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _wall_texture(palette_line: int, frame: int, within: int, palette_phase: int):
	# SS_Wall_Palettes_VRAM: the zero-orientation wall in each colour group is
	# stable; the other eight walls run the source nBnnnnnB/nBnnnnnB blink wave.
	var effective_palette := palette_line
	if within > 0:
		var sequence := [false, true, false, false, false, false, false, true, false, true, false, false, false, false, false, true]
		var seq_index := clampi(palette_phase + within - 1, 0, 15)
		if sequence[seq_index]:
			effective_palette = posmod(palette_line - 1, 4)
	var key := "ss_wall_%d_%02d" % [effective_palette, frame]
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("Special Walls.nem")
	var palette := _palette()
	if raw.is_empty() or palette.is_empty():
		return null
	var size := 24 if frame == 0 else 32
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if frame == 0:
		_draw_piece(image, raw, palette, 0, 3, 3, 0, 0, false, false, effective_palette)
	else:
		_draw_piece(image, raw, palette, 9 + (frame - 1) * 16, 4, 4, 0, 0, false, false, effective_palette)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _bumper_texture(frame: int):
	var key := "ss_bumper_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("SYZ Bumper.nem")
	var palette := _palette()
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match frame:
		0:
			_draw_piece(image, raw, palette, 0, 2, 4, 0, 0, false, false, 0)
			_draw_piece(image, raw, palette, 0, 2, 4, 16, 0, true, false, 0)
		1:
			_draw_piece(image, raw, palette, 8, 2, 3, 4, 4, false, false, 0)
			_draw_piece(image, raw, palette, 8, 1, 3, 20, 4, true, false, 0)
		_:
			_draw_piece(image, raw, palette, 0x0E, 2, 4, 0, 0, false, false, 0)
			_draw_piece(image, raw, palette, 0x0E, 2, 4, 16, 0, true, false, 0)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _shared_texture(key_name: String, art_name: String, frame: int, palette_line: int):
	var key := "ss_shared_%s_%d" % [key_name, frame]
	if _cache.has(key):
		return _cache[key]
	var raw := _raw(art_name)
	var palette := _palette()
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_piece(image, raw, palette, 9 if frame != 0 else 0, 3, 3, 0, 0, false, false, palette_line)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _updown_texture(up: bool, frame: int):
	var key := "ss_%s_%d" % ["up" if up else "down", frame]
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("Special UP-DOWN.nem")
	var palette := _palette()
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var tile := 0 if up else 9
	if frame != 0:
		tile = 0x12
	_draw_piece(image, raw, palette, tile, 3, 3, 0, 0, false, false, 0)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _glass_like_texture(key_name: String, art_name: String, frame: int, palette_line: int):
	var key := "ss_%s_%d_%d" % [key_name, frame, palette_line]
	if _cache.has(key):
		return _cache[key]
	var raw := _raw(art_name)
	var palette := _palette()
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var flip_x := frame == 1 or frame == 2
	var flip_y := frame == 2 or frame == 3
	_draw_piece(image, raw, palette, 0, 3, 3, 0, 0, flip_x, flip_y, palette_line)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _ring_texture(frame: int):
	var key := "ss_ring_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("Rings.nem")
	var palette := _palette()
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var f := frame & 3
	if f == 0:
		_draw_piece(image, raw, palette, 0, 2, 2, 4, 4, false, false, 1)
	elif f == 1:
		_draw_piece(image, raw, palette, 4, 2, 2, 4, 4, false, false, 1)
	elif f == 2:
		_draw_piece(image, raw, palette, 8, 1, 2, 8, 4, false, false, 1)
	else:
		_draw_piece(image, raw, palette, 4, 2, 2, 4, 4, true, false, 1)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _emerald_texture(index: int, frame: int):
	var key := "ss_emerald_%d_%d" % [index, frame]
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("Special Emeralds.nem")
	var palette := _palette()
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var tile := 8
	var pal_line := 0
	match index:
		0: tile = 8; pal_line = 0
		1: tile = 8; pal_line = 1
		2: tile = 8; pal_line = 2
		3: tile = 8; pal_line = 3
		4: tile = 0; pal_line = 0
		5: tile = 4; pal_line = 0
	if frame != 0:
		tile = 0x0C
	_draw_piece(image, raw, palette, tile, 2, 2, 4, 4, false, false, pal_line)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _ring_sparkle_texture(frame: int):
	frame &= 3
	var key := "ss_ring_sparkle_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("Rings.nem")
	var palette := _palette()
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Map_Ring frames 4-7 all use tile $A and rotate the sparkle through flips.
	var flip_x := frame == 1 or frame == 2
	var flip_y := frame == 1 or frame == 3
	_draw_piece(image, raw, palette, 0x0A, 2, 2, 4, 4, flip_x, flip_y, 1)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _twinkle_texture(frame: int):
	frame &= 3
	var key := "ss_twinkle_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var raw := _raw("Special Emerald Twinkle.nem")
	var palette := _palette()
	var image := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# IDs $46-$49 use Map_SS_Glass frames 0-3: one 3x3 tile block
	# with X/Y flips, not four consecutive tile ranges.
	var flip_x := frame == 1 or frame == 2
	var flip_y := frame == 2 or frame == 3
	_draw_piece(image, raw, palette, 0, 3, 3, 0, 0, flip_x, flip_y, 1)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _raw(name: String) -> PackedByteArray:
	if _raw_cache.has(name):
		return _raw_cache[name]
	var path := "res://data/s1/artnem/" + name
	if not FileAccess.file_exists(path):
		push_error("Phase 48: missing retained Special Stage art: %s" % path)
		_raw_cache[name] = PackedByteArray()
		return PackedByteArray()
	var raw := Nemesis.decompress(FileAccess.get_file_as_bytes(path))
	_raw_cache[name] = raw
	return raw

static func _palette() -> Array[Color]:
	if not _palette_cache.is_empty():
		return _palette_cache
	var path := "res://data/s1/palette/Special Stage.bin"
	if not FileAccess.file_exists(path):
		return []
	_palette_cache = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(path))
	return _palette_cache

static func _draw_piece(image: Image, raw: PackedByteArray, palette: Array[Color], tile_base: int, width_tiles: int, height_tiles: int, target_x: int, target_y: int, flip_x: bool, flip_y: bool, palette_line: int) -> void:
	for out_tx in range(width_tiles):
		for out_ty in range(height_tiles):
			var source_tx := width_tiles - 1 - out_tx if flip_x else out_tx
			var source_ty := height_tiles - 1 - out_ty if flip_y else out_ty
			var tile_index := tile_base + source_tx * height_tiles + source_ty
			for py in range(8):
				var sample_y := 7 - py if flip_y else py
				for px in range(8):
					var sample_x := 7 - px if flip_x else px
					var ci := _tile_pixel(raw, tile_index, sample_x, sample_y)
					if ci == 0:
						continue
					var pi := palette_line * 16 + ci
					var dx := target_x + out_tx * 8 + px
					var dy := target_y + out_ty * 8 + py
					if pi >= 0 and pi < palette.size() and dx >= 0 and dy >= 0 and dx < image.get_width() and dy < image.get_height():
						image.set_pixel(dx, dy, palette[pi])

static func _tile_pixel(raw: PackedByteArray, tile_index: int, x: int, y: int) -> int:
	var offset := tile_index * 32 + y * 4 + (x >> 1)
	if offset < 0 or offset >= raw.size():
		return 0
	var value := int(raw[offset])
	return (value >> 4) & 0xF if (x & 1) == 0 else value & 0xF
