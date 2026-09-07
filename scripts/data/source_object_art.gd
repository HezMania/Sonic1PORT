class_name SourceObjectArt
extends RefCounted

# Phase 29 source-art-only object renderer.
# If the original disassembly asset is absent, return null and report it.
# There is deliberately no drawn/reconstructed fallback.

static var _cache: Dictionary = {}

static func lz_door_texture(frame: int):
	var key = "lz_door_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var texture = null
	if frame == 6:
		texture = _build_lz_vertical_door()
	elif frame == 7:
		texture = _build_lz_horizontal_door()
	_cache[key] = texture
	return texture

static func lz_spike_chain_texture(frame: int):
	var key = "lz_spike_chain_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Spiked Ball & Chain.nem", "LZ Spiked Ball & Chain.bin"])
	if source_path.is_empty():
		push_error("Phase 29: original LZ Spiked Ball & Chain Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	match frame:
		0:
			image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0, 2, 2, 0, 0, false, false, 0)
		1:
			image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 4, 4, 4, 0, 0, false, false, 0)
		2:
			image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x14, 2, 2, 0, 0, false, false, 0)
		_:
			return null
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_water_surface_texture(frame: int):
	frame = posmod(frame, 3)
	var key = "lz_water_surface_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Water Surface.nem", "LZ Water Surface.bin"])
	if source_path.is_empty():
		push_error("Phase 30: original LZ Water Surface Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(160, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var tile_base = 8 if frame == 1 else 0
	var flip_x = frame == 2
	# Map_Surf normal frames: three 4x2 pieces at X -$60, -$20 and +$20.
	for x in [0, 64, 128]:
		_draw_piece(image, raw, palette, tile_base, 4, 2, x, 0, flip_x, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_water_splash_texture(frame: int):
	frame = clampi(frame, 0, 2)
	var key = "lz_water_splash_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Water & Splashes.nem", "LZ Water & Splashes.bin"])
	if source_path.is_empty():
		push_error("Phase 30: original LZ Water & Splashes Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# All three source frames fit the common local bounds X -$10..+$10,
	# Y -$1E..+2. Keeping a fixed canvas preserves the original piece offsets.
	var image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match frame:
		0:
			_draw_piece(image, raw, palette, 0x6D, 2, 1, 8, 16, false, false, 2)
			_draw_piece(image, raw, palette, 0x6F, 4, 1, 0, 24, false, false, 2)
		1:
			_draw_piece(image, raw, palette, 0x73, 1, 1, 8, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x74, 4, 3, 0, 8, false, false, 2)
		2:
			_draw_piece(image, raw, palette, 0x80, 4, 4, 0, 0, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_bubble_texture(frame: int):
	frame = clampi(frame, 0, 22)
	var key = "lz_bubble_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Bubbles & Countdown.nem", "LZ Bubbles & Countdown.bin"])
	if source_path.is_empty():
		push_error("Phase 30: original LZ Bubbles & Countdown Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	match frame:
		0, 1, 2:
			image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, frame, 1, 1, 0, 0, false, false, 0)
		3, 4:
			image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 3 if frame == 3 else 7, 2, 2, 0, 0, false, false, 0)
		5:
			image = Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x0B, 3, 3, 0, 0, false, false, 0)
		6:
			image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x14, 4, 4, 0, 0, false, false, 0)
		7, 8:
			image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			var burst_tile = 0x24 if frame == 7 else 0x28
			_draw_piece(image, raw, palette, burst_tile, 2, 2, 0, 0, false, false, 0)
			_draw_piece(image, raw, palette, burst_tile, 2, 2, 16, 0, true, false, 0)
			_draw_piece(image, raw, palette, burst_tile, 2, 2, 0, 16, false, true, 0)
			_draw_piece(image, raw, palette, burst_tile, 2, 2, 16, 16, true, true, 0)
		9, 10, 11, 12:
			image = Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			var small_tiles = [0x2C, 0x32, 0x38, 0x3E]
			_draw_piece(image, raw, palette, small_tiles[frame - 9], 2, 3, 0, 0, false, false, 0)
		13, 14, 15, 16, 17, 18:
			image = Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			var full_tiles = [0x44, 0x4A, 0x50, 0x56, 0x5C, 0x62]
			# Map_Bub's final mapping arguments are x-flip, y-flip, palette, priority.
			# Phase 30 accidentally treated palette=1 as y-flip=1, turning the
			# completed countdown numbers upside down. The original numbers are
			# unflipped and use palette line 1.
			_draw_piece(image, raw, palette, full_tiles[frame - 13], 2, 3, 0, 0, false, false, 1)
		19, 20, 21:
			image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			var maker_tiles = [0x68, 0x6C, 0x70]
			_draw_piece(image, raw, palette, maker_tiles[frame - 19], 2, 2, 0, 0, false, false, 0)
		_:
			image = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func lz_harpoon_texture(frame: int):
	frame = clampi(frame, 0, 5)
	var key = "lz_harpoon_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Harpoon.nem", "LZ Harpoon.bin"])
	if source_path.is_empty():
		push_error("Phase 31: original LZ Harpoon Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# Fixed canvas centered on the OST origin preserves the asymmetric source
	# mapping offsets while still letting Godot flip the whole object from the
	# placement render flags.
	var image = Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 48
	var oy = 48
	match frame:
		0:
			_draw_piece(image, raw, palette, 0, 2, 1, ox - 8, oy - 4, false, false, 0)
		1:
			_draw_piece(image, raw, palette, 2, 4, 1, ox - 8, oy - 4, false, false, 0)
		2:
			_draw_piece(image, raw, palette, 6, 3, 1, ox - 8, oy - 4, false, false, 0)
			_draw_piece(image, raw, palette, 3, 3, 1, ox + 0x10, oy - 4, false, false, 0)
		3:
			_draw_piece(image, raw, palette, 9, 1, 2, ox - 4, oy - 8, false, false, 0)
		4:
			_draw_piece(image, raw, palette, 0x0B, 1, 4, ox - 4, oy - 0x18, false, false, 0)
		5:
			_draw_piece(image, raw, palette, 0x0B, 1, 3, ox - 4, oy - 0x28, false, false, 0)
			_draw_piece(image, raw, palette, 0x0F, 1, 3, ox - 4, oy - 0x10, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_jaws_texture(frame: int):
	frame = clampi(frame, 0, 3)
	var key = "lz_jaws_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Enemy Jaws.nem", "Enemy Jaws.bin"])
	if source_path.is_empty():
		push_error("Phase 31: original Jaws Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(64, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 32
	var oy = 24
	var body_tile = 0 if frame == 0 or frame == 2 else 0x0C
	var tail_tile = 0x18 if frame == 0 or frame == 2 else 0x1C
	var tail_flip_y = frame >= 2
	_draw_piece(image, raw, palette, body_tile, 4, 3, ox - 0x10, oy - 0x0C, false, false, 1)
	_draw_piece(image, raw, palette, tail_tile, 2, 2, ox + 0x10, oy - 0x0B, false, tail_flip_y, 1)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_burrobot_texture(frame: int):
	frame = clampi(frame, 0, 6)
	var key = "lz_burrobot_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Enemy Burrobot.nem", "Enemy Burrobot.bin"])
	if source_path.is_empty():
		push_error("Phase 31: original Burrobot Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 32
	var oy = 32
	match frame:
		0:
			_draw_piece(image, raw, palette, 0, 3, 3, ox - 0x10, oy - 0x14, false, false, 0)
			_draw_piece(image, raw, palette, 9, 3, 2, ox - 0x0C, oy + 4, false, false, 0)
		1:
			_draw_piece(image, raw, palette, 0x0F, 3, 3, ox - 0x10, oy - 0x14, false, false, 0)
			_draw_piece(image, raw, palette, 0x18, 3, 2, ox - 0x0C, oy + 4, false, false, 0)
		2:
			_draw_piece(image, raw, palette, 0x1E, 3, 3, ox - 0x0C, oy - 0x18, false, false, 0)
			_draw_piece(image, raw, palette, 0x27, 3, 3, ox - 0x0C, oy, false, false, 0)
		3:
			_draw_piece(image, raw, palette, 0x30, 3, 3, ox - 0x0C, oy - 0x18, false, false, 0)
			_draw_piece(image, raw, palette, 0x39, 3, 3, ox - 0x0C, oy, false, false, 0)
		4:
			_draw_piece(image, raw, palette, 0x0F, 3, 3, ox - 0x10, oy - 0x18, false, false, 0)
			_draw_piece(image, raw, palette, 0x42, 3, 3, ox - 0x0C, oy, false, false, 0)
		5:
			_draw_piece(image, raw, palette, 0x4B, 2, 3, ox - 0x18, oy - 0x0C, false, false, 0)
			_draw_piece(image, raw, palette, 0x51, 3, 3, ox - 8, oy - 0x0C, false, false, 0)
		6:
			_draw_piece(image, raw, palette, 0x0F, 3, 3, ox - 0x10, oy - 0x14, false, false, 0)
			_draw_piece(image, raw, palette, 9, 3, 2, ox - 0x0C, oy + 4, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_block_texture(frame: int):
	frame = clampi(frame, 0, 3)
	var key = "lz_block_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_name := ""
	match frame:
		0:
			# Map_LBlock frame 0 is based at ArtTile_LZ_Blocks ($3E6), the same
			# VRAM address used by the source LZ Horizontal Door stream.
			source_name = "LZ Horizontal Door.nem"
		1:
			source_name = "LZ Rising Platform.nem"
		2:
			source_name = "LZ Cork.nem"
		_:
			source_name = "LZ 32x32 Block.nem"
	var source_path = _find_source_file("artnem", [source_name, source_name.replace(".nem", ".bin")])
	if source_path.is_empty():
		push_error("Phase 32: original %s is missing; no Labyrinth block art will be invented." % source_name)
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	match frame:
		0, 2, 3:
			image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0, 4, 4, 0, 0, false, false, 2)
		1:
			image = Image.create_empty(64, 24, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0, 4, 3, 0, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x0C, 4, 3, 32, 0, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_gargoyle_texture(frame: int):
	frame = clampi(frame, 0, 3)
	var key = "lz_gargoyle_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Gargoyle & Fireball.nem", "LZ Gargoyle & Fireball.bin"])
	if source_path.is_empty():
		push_error("Phase 32: original LZ Gargoyle & Fireball Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	if frame <= 1:
		image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		# Map_Gar .head. The head uses Tile_Pal3 (palette line 2).
		_draw_piece(image, raw, palette, 0, 2, 1, 16, 0, false, false, 2)
		_draw_piece(image, raw, palette, 2, 4, 2, 0, 8, false, false, 2)
		_draw_piece(image, raw, palette, 0x0A, 3, 1, 8, 24, false, false, 2)
	else:
		image = Image.create_empty(16, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		# Fireballs deliberately omit Tile_Pal3 in Gar_FireBall and therefore use
		# palette line 0, exactly as the source object does.
		_draw_piece(image, raw, palette, 0x0D if frame == 2 else 0x0F, 2, 1, 0, 0, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _runtime_palette_signature(palette: Array[Color], indices: Array[int]) -> String:
	var parts: Array[String] = []
	for index in indices:
		if index < 0 or index >= palette.size():
			parts.append("00000000")
			continue
		var color = palette[index]
		parts.append("%02X%02X%02X%02X" % [
			clampi(int(round(color.r * 255.0)), 0, 255),
			clampi(int(round(color.g * 255.0)), 0, 255),
			clampi(int(round(color.b * 255.0)), 0, 255),
			clampi(int(round(color.a * 255.0)), 0, 255),
		])
	return "_".join(parts)

static func lz_waterfall_texture(frame: int, palette_override: Array[Color] = []):
	frame = clampi(frame, 0, 11)
	var use_runtime_palette := not palette_override.is_empty()
	var key = "lz_waterfall_%d" % frame
	if use_runtime_palette:
		key += "_pal_" + _runtime_palette_signature(palette_override, [43, 44, 45, 46])
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Water & Splashes.nem", "LZ Water & Splashes.bin"])
	if source_path.is_empty():
		push_error("Phase 32: original LZ Water & Splashes Nemesis art is missing; no waterfall art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = palette_override if use_runtime_palette else _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		if not use_runtime_palette:
			_cache[key] = null
		return null
	# A fixed origin-centered canvas preserves all Map_WFall piece offsets.
	var image = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 32
	var oy = 32
	match frame:
		0:
			_draw_piece(image, raw, palette, 0x00, 2, 4, ox - 8, oy - 16, false, false, 2)
		1:
			_draw_piece(image, raw, palette, 0x08, 2, 1, ox - 4, oy - 8, false, false, 2)
			_draw_piece(image, raw, palette, 0x0A, 3, 1, ox - 12, oy, false, false, 2)
		2, 4:
			_draw_piece(image, raw, palette, 0x08, 1, 1, ox, oy - 8, false, false, 2)
			_draw_piece(image, raw, palette, 0x0D, 2, 1, ox - 8, oy, false, false, 2)
		3:
			_draw_piece(image, raw, palette, 0x0F, 1, 2, ox, oy - 8, false, false, 2)
		5:
			_draw_piece(image, raw, palette, 0x11, 1, 2, ox, oy - 8, false, false, 2)
		6:
			_draw_piece(image, raw, palette, 0x13, 1, 2, ox, oy - 8, false, false, 2)
		7:
			_draw_piece(image, raw, palette, 0x15, 2, 4, ox - 8, oy - 16, false, false, 2)
		8:
			_draw_piece(image, raw, palette, 0x1D, 4, 1, ox - 10, oy - 8, false, false, 2)
			_draw_piece(image, raw, palette, 0x21, 4, 1, ox - 24, oy, false, false, 2)
		9:
			_draw_piece(image, raw, palette, 0x25, 3, 4, ox - 24, oy - 16, false, false, 2)
			_draw_piece(image, raw, palette, 0x31, 3, 4, ox, oy - 16, false, false, 2)
		10:
			_draw_piece(image, raw, palette, 0x3D, 3, 4, ox - 24, oy - 16, false, false, 2)
			_draw_piece(image, raw, palette, 0x49, 3, 4, ox, oy - 16, false, false, 2)
		11:
			_draw_piece(image, raw, palette, 0x55, 3, 4, ox - 24, oy - 16, false, false, 2)
			_draw_piece(image, raw, palette, 0x61, 3, 4, ox, oy - 16, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _build_lz_vertical_door():
	var source_path = _find_source_file("artnem", ["LZ Vertical Door.nem", "LZ Vertical Door.bin"])
	if source_path.is_empty():
		push_error("Phase 29: original LZ Vertical Door Nemesis art is missing; no replacement art will be invented.")
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		return null
	var image = Image.create_empty(16, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Map_FBlock .lzvert: top 2x4 piece, then the same 2x4 piece V-flipped.
	_draw_piece(image, raw, palette, 0, 2, 4, 0, 0, false, false, 2)
	_draw_piece(image, raw, palette, 0, 2, 4, 0, 32, false, true, 2)
	return ImageTexture.create_from_image(image)

static func _build_lz_horizontal_door():
	var source_path = _find_source_file("artnem", ["LZ Horizontal Door.nem", "LZ Horizontal Door.bin"])
	if source_path.is_empty():
		push_error("Phase 29: original LZ Horizontal Door Nemesis art is missing; no replacement art will be invented.")
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		return null
	var image = Image.create_empty(128, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Map_FBlock .lzhoriz uses four copies of the same 4x4 source piece.
	# The source mapping's $22 is the VRAM delta between LZ Door1 and Door2;
	# this standalone Door2 Nemesis stream begins at local tile 0.
	for x in [0, 32, 64, 96]:
		_draw_piece(image, raw, palette, 0, 4, 4, x, 0, false, false, 2)
	return ImageTexture.create_from_image(image)


static func lz_breakable_pole_texture(frame: int):
	frame = clampi(frame, 0, 1)
	var key = "lz_breakable_pole_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Breakable Pole.nem", "LZ Breakable Pole.bin"])
	if source_path.is_empty():
		push_error("Phase 33: original LZ Breakable Pole Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 40
	var oy = 40
	if frame == 0:
		_draw_piece(image, raw, palette, 0, 1, 4, ox - 4, oy - 0x20, false, false, 2)
		_draw_piece(image, raw, palette, 0, 1, 4, ox - 4, oy, false, true, 2)
	else:
		_draw_piece(image, raw, palette, 0, 1, 2, ox - 4, oy - 0x20, false, false, 2)
		_draw_piece(image, raw, palette, 4, 2, 2, ox - 4, oy - 0x10, false, false, 2)
		_draw_piece(image, raw, palette, 4, 2, 2, ox - 4, oy, false, true, 2)
		_draw_piece(image, raw, palette, 0, 1, 2, ox - 4, oy + 0x10, false, true, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_flapping_door_texture(frame: int):
	frame = clampi(frame, 0, 2)
	var key = "lz_flapping_door_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Flapping Door.nem", "LZ Flapping Door.bin"])
	if source_path.is_empty():
		push_error("Phase 33: original LZ Flapping Door Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 48
	var oy = 48
	match frame:
		0:
			_draw_piece(image, raw, palette, 0, 2, 4, ox - 8, oy - 0x20, false, false, 2)
			_draw_piece(image, raw, palette, 0, 2, 4, ox - 8, oy, false, true, 2)
		1:
			_draw_piece(image, raw, palette, 8, 4, 4, ox - 5, oy - 0x26, false, false, 2)
			_draw_piece(image, raw, palette, 8, 4, 4, ox - 5, oy + 6, false, true, 2)
		2:
			_draw_piece(image, raw, palette, 0x18, 4, 2, ox, oy - 0x28, false, false, 2)
			_draw_piece(image, raw, palette, 0x18, 4, 2, ox, oy + 0x18, false, true, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_conveyor_texture(frame: int, platform_palette: bool = false):
	frame = clampi(frame, 0, 4)
	var palette_line = 2 if platform_palette else 0
	var key = "lz_conveyor_%d_%d" % [frame, palette_line]
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Wheel.nem", "LZ Wheel.bin"])
	if source_path.is_empty():
		push_error("Phase 33: original LZ Wheel Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	if frame < 4:
		image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_draw_piece(image, raw, palette, frame * 0x10, 4, 4, 0, 0, false, false, 0)
	else:
		image = Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_draw_piece(image, raw, palette, 0x40, 4, 2, 0, 0, false, false, palette_line)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_orbinaut_texture(frame: int):
	frame = clampi(frame, 0, 3)
	var key = "lz_orbinaut_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Enemy Orbinaut.nem", "Enemy Orbinaut.bin"])
	if source_path.is_empty():
		push_error("Phase 34: original Enemy Orbinaut Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	if frame < 3:
		image = Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var tile_bases = [0x00, 0x09, 0x12]
		var palette_lines = [0, 1, 0]
		_draw_piece(image, raw, palette, tile_bases[frame], 3, 3, 0, 0, false, false, palette_lines[frame])
	else:
		image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_draw_piece(image, raw, palette, 0x1B, 2, 2, 0, 0, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_orbinaut_texture(frame: int):
	frame = clampi(frame, 0, 3)
	var key = "slz_orbinaut_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Enemy Orbinaut.nem", "Enemy Orbinaut.bin"])
	if source_path.is_empty():
		push_error("Phase 36: original Enemy Orbinaut Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	if frame < 3:
		image = Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var tile_bases = [0x00, 0x09, 0x12]
		# ArtTile_SLZ_Orbinaut carries Tile_Pal2, so every mapping uses
		# palette line 1 regardless of its local palette flag.
		_draw_piece(image, raw, palette, tile_bases[frame], 3, 3, 0, 0, false, false, 1)
	else:
		image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_draw_piece(image, raw, palette, 0x1B, 2, 2, 0, 0, false, false, 1)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func lz_moving_block_texture():
	var key = "lz_moving_block"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ 32x16 Block.nem", "LZ 32x16 Block.bin"])
	if source_path.is_empty():
		push_error("Phase 34: original LZ 32x16 Moving Block Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_lz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Map_MBlockLZ frame 0: one 4x2 piece, palette line 2 from Tile_Pal3.
	_draw_piece(image, raw, palette, 0, 4, 2, 0, 0, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _load_lz_palette() -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		push_error("Phase 29: could not locate the Sonic 1 source-data root for the LZ palette.")
		return []
	var sonic_path = root.path_join("palette/Sonic.bin")
	var zone_path = root.path_join("palette/Labyrinth Zone.bin")
	if not FileAccess.file_exists(sonic_path) or not FileAccess.file_exists(zone_path):
		push_error("Phase 29: original Sonic/Labyrinth palettes are missing; source object art cannot be rendered exactly.")
		return []
	var combined = PackedByteArray()
	combined.append_array(FileAccess.get_file_as_bytes(sonic_path))
	combined.append_array(FileAccess.get_file_as_bytes(zone_path))
	return GenesisPalette.decode_cram_bytes(combined)

static func _find_data_root() -> String:
	var root = "res://data/s1"
	return root if DirAccess.dir_exists_absolute(root) else ""

static func _find_source_file(folder: String, names: Array) -> String:
	var root = _find_data_root()
	if root.is_empty():
		return ""
	for name in names:
		var path = root.path_join(folder).path_join(String(name))
		if FileAccess.file_exists(path):
			return path
	return ""

static func _draw_piece(image: Image, raw: PackedByteArray, palette: Array[Color], tile_base: int, width_tiles: int, height_tiles: int, target_x: int, target_y: int, flip_x: bool, flip_y: bool, palette_line: int) -> void:
	# Mega Drive multi-tile sprites advance vertically first, then horizontally.
	for out_tx in range(width_tiles):
		for out_ty in range(height_tiles):
			var source_tx = width_tiles - 1 - out_tx if flip_x else out_tx
			var source_ty = height_tiles - 1 - out_ty if flip_y else out_ty
			var tile_index = tile_base + source_tx * height_tiles + source_ty
			for py in range(8):
				var sample_y = 7 - py if flip_y else py
				for px in range(8):
					var sample_x = 7 - px if flip_x else px
					var ci = _tile_pixel(raw, tile_index, sample_x, sample_y)
					if ci == 0:
						continue
					var pi = palette_line * 16 + ci
					var p_x := target_x + out_tx * 8 + px
					var p_y := target_y + out_ty * 8 + py
					if pi >= 0 and pi < palette.size() and p_x >= 0 and p_y >= 0 and p_x < image.get_width() and p_y < image.get_height():
						image.set_pixel(p_x, p_y, palette[pi])

static func _tile_pixel(raw: PackedByteArray, tile_index: int, x: int, y: int) -> int:
	var offset = tile_index * 32 + y * 4 + (x >> 1)
	if offset < 0 or offset >= raw.size():
		return 0
	var value = int(raw[offset])
	return (value >> 4) & 0x0F if (x & 1) == 0 else value & 0x0F

# -----------------------------------------------------------------------------
# Phase 36 - Star Light Zone source-art helpers
# -----------------------------------------------------------------------------
static func slz_level_object_texture(kind: String):
	var key = "slz_level_%s" % kind
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["8x8 - SLZ.nem"])
	if source_path.is_empty():
		push_error("Phase 36: original SLZ level Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	match kind:
		"elevator":
			image = Image.create_empty(80, 32, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x41, 4, 4, 0, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x41, 4, 4, 32, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x41, 2, 4, 64, 0, false, false, 2)
		"circle":
			image = Image.create_empty(48, 16, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x51, 3, 2, 0, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x51, 3, 2, 24, 0, true, false, 2)
		"stair":
			image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x21, 4, 4, 0, 0, false, false, 2)
		_:
			return null
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_fan_texture(frame: int):
	frame = clampi(frame, 0, 4)
	var key = "slz_fan_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Fan.nem"])
	if source_path.is_empty():
		push_error("Phase 36: original SLZ Fan Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match frame:
		0, 4:
			_draw_piece(image, raw, palette, 0x00, 3, 2, 8, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x06, 4, 2, 0, 16, false, false, 2)
		1, 3:
			_draw_piece(image, raw, palette, 0x0E, 4, 2, 0, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x16, 4, 2, 0, 16, false, false, 2)
		2:
			_draw_piece(image, raw, palette, 0x1E, 4, 2, 0, 0, false, false, 2)
			_draw_piece(image, raw, palette, 0x26, 3, 2, 8, 16, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_bomb_texture(frame: int):
	frame = clampi(frame, 0, 11)
	var key = "slz_bomb_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Enemy Bomb.nem"])
	if source_path.is_empty():
		push_error("Phase 36: original Enemy Bomb Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 16
	var oy = 26
	match frame:
		0:
			_draw_piece(image, raw, palette, 0x00, 3, 3, ox - 12, oy - 15, false, false, 0)
			_draw_piece(image, raw, palette, 0x12, 3, 1, ox - 12, oy + 9, false, false, 0)
			_draw_piece(image, raw, palette, 0x21, 1, 2, ox - 4, oy - 25, false, false, 0)
		1:
			_draw_piece(image, raw, palette, 0x09, 3, 3, ox - 12, oy - 15, false, false, 0)
			_draw_piece(image, raw, palette, 0x12, 3, 1, ox - 12, oy + 9, false, false, 0)
			_draw_piece(image, raw, palette, 0x21, 1, 2, ox - 4, oy - 25, false, false, 0)
		2:
			_draw_piece(image, raw, palette, 0x00, 3, 3, ox - 12, oy - 16, false, false, 0)
			_draw_piece(image, raw, palette, 0x15, 3, 1, ox - 12, oy + 8, false, false, 0)
			_draw_piece(image, raw, palette, 0x21, 1, 2, ox - 4, oy - 26, false, false, 0)
		3:
			_draw_piece(image, raw, palette, 0x09, 3, 3, ox - 12, oy - 15, false, false, 0)
			_draw_piece(image, raw, palette, 0x18, 3, 1, ox - 12, oy + 9, false, false, 0)
			_draw_piece(image, raw, palette, 0x21, 1, 2, ox - 4, oy - 25, false, false, 0)
		4:
			_draw_piece(image, raw, palette, 0x00, 3, 3, ox - 12, oy - 16, false, false, 0)
			_draw_piece(image, raw, palette, 0x1B, 3, 1, ox - 12, oy + 8, false, false, 0)
			_draw_piece(image, raw, palette, 0x21, 1, 2, ox - 4, oy - 26, false, false, 0)
		5:
			_draw_piece(image, raw, palette, 0x09, 3, 3, ox - 12, oy - 15, false, false, 0)
			_draw_piece(image, raw, palette, 0x1E, 3, 1, ox - 12, oy + 9, false, false, 0)
			_draw_piece(image, raw, palette, 0x21, 1, 2, ox - 4, oy - 25, false, false, 0)
		6:
			_draw_piece(image, raw, palette, 0x00, 3, 3, ox - 12, oy - 15, false, false, 0)
			_draw_piece(image, raw, palette, 0x12, 3, 1, ox - 12, oy + 9, false, false, 0)
		7:
			_draw_piece(image, raw, palette, 0x09, 3, 3, ox - 12, oy - 15, false, false, 0)
			_draw_piece(image, raw, palette, 0x12, 3, 1, ox - 12, oy + 9, false, false, 0)
		8:
			_draw_piece(image, raw, palette, 0x23, 1, 2, ox - 4, oy - 25, false, false, 0)
		9:
			_draw_piece(image, raw, palette, 0x25, 1, 2, ox - 4, oy - 25, false, false, 0)
		10:
			_draw_piece(image, raw, palette, 0x27, 1, 1, ox - 4, oy - 4, false, false, 0)
		11:
			_draw_piece(image, raw, palette, 0x28, 1, 1, ox - 4, oy - 4, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture



# Phase 38 - Object $53 Star Light collapsing-floor source art.  Object $53 is
# shared with MZ/SBZ, but the original switches to ArtTile_SLZ_Collapsing_Floor
# and mapping frames 2/3 while v_zone == SLZ.
static func slz_collapse_floor_texture(fragmented: bool = false):
	var key = "slz_collapse_floor_frag" if fragmented else "slz_collapse_floor_whole"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ 32x32 Block.nem"])
	if source_path.is_empty():
		push_error("Phase 38: original SLZ 32x32 Block Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if not fragmented:
		# Map_CFlo frame 2 (.leftsmash): two repeated 32x16 top pieces from
		# tile 0 and two repeated bottom pieces from tile 8.
		_draw_piece(image, raw, palette, 0x00, 4, 2, 0, 0, false, false, 2)
		_draw_piece(image, raw, palette, 0x08, 4, 2, 0, 16, false, false, 2)
		_draw_piece(image, raw, palette, 0x00, 4, 2, 32, 0, false, false, 2)
		_draw_piece(image, raw, palette, 0x08, 4, 2, 32, 16, false, false, 2)
	else:
		# Map_CFlo frame 3 (.rightsmash): eight independent 16x16 source
		# pieces.  Keeping them in one atlas lets the collapsing-object class
		# slice the exact source pieces while preserving the mapping order.
		var tile_bases: Array[int] = [0x00, 0x04, 0x00, 0x04, 0x08, 0x0C, 0x08, 0x0C]
		for i in range(8):
			var col = i & 3
			var row = i >> 2
			_draw_piece(image, raw, palette, tile_bases[i], 2, 2, col * 16, row * 16, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

# Phase 39 - Object $3C Star Light breakable wall. The SLZ PLC loads
# `SLZ Breakable Wall.nem` at ArtTile_GHZ_SLZ_Smashable_Wall+4, while every
# authored SLZ wall uses Map_Smash frame 1 (.middle), whose eight 16x16 pieces
# all reference mapping tile 4. Therefore local source tile 0 is repeated across
# the 32x64 wall and is also the exact fragment graphic after smashing.
static func slz_smash_wall_texture(fragment: bool = false):
	var key = "slz_smash_wall_fragment" if fragment else "slz_smash_wall_whole"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Breakable Wall.nem"])
	if source_path.is_empty():
		push_error("Phase 39: original SLZ Breakable Wall Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	if fragment:
		image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_draw_piece(image, raw, palette, 0, 2, 2, 0, 0, false, false, 2)
	else:
		image = Image.create_empty(32, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		for row in range(4):
			for col in range(2):
				_draw_piece(image, raw, palette, 0, 2, 2, col * 16, row * 16, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


# Phase 39 - Star Light boss weapon/source-art helpers.
static func slz_boss_pipe_texture():
	var key = "slz_boss_pipe"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Boss - Weapons.nem"])
	if source_path.is_empty():
		push_error("Phase 39: original Boss - Weapons Nemesis art is missing; no replacement boss pipe will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# Map_BossItems frame 3 (.widepipe): spritePiece -$C,$14, 3x2, tile $07.
	# ArtTile_Eggman_Weapons carries Tile_Pal2 => palette line 1. Keep the
	# mapping offset in the texture itself so the pipe sits at Eggman's source origin.
	var image = Image.create_empty(32, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Center is (16,36), so top-left (4,56) reproduces mapping offset (-12,+20).
	_draw_piece(image, raw, palette, 0x07, 3, 2, 4, 56, false, false, 1)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_boss_spike_fragment_texture(frame: int):
	frame = clampi(frame, 0, 1)
	var key = "slz_boss_spike_frag_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Little Spikeball.nem"])
	if source_path.is_empty():
		push_error("Phase 39: original SLZ Little Spikeball Nemesis art is missing; no replacement boss fragments will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# Map_BSBall frames use one 8x8 tile, $27/$28, at local origin -4,-4.
	var image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_piece(image, raw, palette, 0x27 + frame, 1, 1, 0, 0, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

# -----------------------------------------------------------------------------
# Phase 37 - Star Light Zone fire / pylon / seesaw source-art helpers
# -----------------------------------------------------------------------------
static func slz_fireball_texture(frame: int):
	frame = clampi(frame, 0, 5)
	var key = "slz_fireball_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Fireballs.nem"])
	if source_path.is_empty():
		push_error("Phase 37: original Fireballs Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match frame:
		0:
			_draw_piece(image, raw, palette, 0x00, 2, 4, 16, 0, false, false, 0)
		1:
			_draw_piece(image, raw, palette, 0x08, 2, 4, 16, 0, false, false, 0)
		2:
			_draw_piece(image, raw, palette, 0x10, 2, 3, 16, 8, false, false, 0)
		3:
			_draw_piece(image, raw, palette, 0x16, 4, 2, 0, 16, false, false, 0)
		4:
			_draw_piece(image, raw, palette, 0x1E, 4, 2, 0, 16, false, false, 0)
		5:
			_draw_piece(image, raw, palette, 0x26, 3, 2, 8, 16, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_fire_launcher_texture():
	var key = "slz_fire_launcher"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Cannon.nem"])
	if source_path.is_empty():
		push_error("Phase 37: original SLZ Cannon Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(16, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_piece(image, raw, palette, 0x00, 2, 4, 0, 0, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_pylon_texture():
	var key = "slz_pylon"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Pylon.nem"])
	if source_path.is_empty():
		push_error("Phase 37: original SLZ Pylon Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# Map_Pylon is a nine-piece foreground column spanning local Y -$80..$9F.
	# Keep the mapping origin at the texture center (Y=160) so the object can be
	# placed using the original screen-space coordinates without ad-hoc offsets.
	var image = Image.create_empty(32, 320, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ys: Array[int] = [-0x80, -0x60, -0x40, -0x20, 0, 0x20, 0x40, 0x60, 0x7F]
	for i in range(ys.size()):
		_draw_piece(image, raw, palette, 0x00, 4, 4, 0, 160 + ys[i], false, (i & 1) != 0 and i < 8, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_seesaw_texture(flat: bool):
	var key = "slz_seesaw_flat" if flat else "slz_seesaw_slope"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Seesaw.nem"])
	if source_path.is_empty():
		push_error("Phase 37: original SLZ Seesaw Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(128, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 64
	var oy = 48
	if flat:
		_draw_piece(image, raw, palette, 0x1D, 3, 3, ox - 0x30, oy - 0x1A, false, false, 0)
		_draw_piece(image, raw, palette, 0x23, 3, 3, ox - 0x18, oy - 0x1A, false, false, 0)
		_draw_piece(image, raw, palette, 0x23, 3, 3, ox + 0x00, oy - 0x1A, true, false, 0)
		_draw_piece(image, raw, palette, 0x1D, 3, 3, ox + 0x18, oy - 0x1A, true, false, 0)
	else:
		_draw_piece(image, raw, palette, 0x00, 2, 3, ox - 0x2D, oy - 0x2C, false, false, 0)
		_draw_piece(image, raw, palette, 0x06, 2, 3, ox - 0x1D, oy - 0x24, false, false, 0)
		_draw_piece(image, raw, palette, 0x0C, 2, 1, ox - 0x0D, oy - 0x1C, false, false, 0)
		_draw_piece(image, raw, palette, 0x0E, 4, 2, ox - 0x0D, oy - 0x14, false, false, 0)
		_draw_piece(image, raw, palette, 0x16, 3, 1, ox - 0x05, oy - 0x04, false, false, 0)
		_draw_piece(image, raw, palette, 0x06, 2, 3, ox + 0x13, oy - 0x0C, false, false, 0)
		_draw_piece(image, raw, palette, 0x19, 2, 2, ox + 0x23, oy - 0x04, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

# Phase 40 - Object $15 Star Light swinging half-spike platform.
# The original switches from the GHZ/MZ mapping/art to Map_Swing_SLZ and
# `SLZ Swinging Platform.nem` while v_zone == SLZ.  Keep the mapping origin
# centered in each returned texture so the swing radius math remains exact.
static func slz_swing_texture(frame: int):
	frame = clampi(frame, 0, 2)
	var key = "slz_swing_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Swinging Platform.nem"])
	if source_path.is_empty():
		push_error("Phase 40: original SLZ Swinging Platform Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image: Image
	match frame:
		0:
			# Map_Swing_SLZ .block spans X -$30..+$30 and Y -$10..+$20.
			# Use a 96x64 canvas with mapping origin at (48,32).
			image = Image.create_empty(96, 64, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x04, 4, 4, 16, 16, false, false, 2)
			_draw_piece(image, raw, palette, 0x04, 4, 4, 48, 16, true, false, 2)
			_draw_piece(image, raw, palette, 0x14, 2, 2, 0, 16, false, false, 2)
			_draw_piece(image, raw, palette, 0x14, 2, 2, 80, 16, true, false, 2)
			_draw_piece(image, raw, palette, 0x18, 2, 1, 16, 48, false, false, 2)
			_draw_piece(image, raw, palette, 0x18, 2, 1, 64, 48, true, false, 2)
			_draw_piece(image, raw, palette, 0x1A, 1, 2, 40, 48, false, false, 2)
			_draw_piece(image, raw, palette, 0x1A, 1, 2, 48, 48, true, false, 2)
		1:
			image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			# Child setup clears the base palette bit and the mapping adds Pal3;
			# the resulting displayed chain is palette line 2 (zero-based).
			_draw_piece(image, raw, palette, 0x00, 2, 2, 0, 0, false, false, 2)
		2:
			image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw_piece(image, raw, palette, 0x1C, 2, 2, 0, 0, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func slz_seesaw_ball_texture(silver: bool):
	var key = "slz_seesaw_ball_%d" % (1 if silver else 0)
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SLZ Little Spikeball.nem"])
	if source_path.is_empty():
		push_error("Phase 37: original SLZ Little Spikeball Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_slz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_piece(image, raw, palette, 0x09 if silver else 0x00, 3, 3, 0, 0, false, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _load_slz_palette() -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		push_error("Phase 36: could not locate the Sonic 1 source-data root for the SLZ palette.")
		return []
	var sonic_path = root.path_join("palette/Sonic.bin")
	var zone_path = root.path_join("palette/Star Light Zone.bin")
	if not FileAccess.file_exists(sonic_path) or not FileAccess.file_exists(zone_path):
		push_error("Phase 36: original Sonic/Star Light palettes are missing; source object art cannot be rendered exactly.")
		return []
	var combined = PackedByteArray()
	combined.append_array(FileAccess.get_file_as_bytes(sonic_path))
	combined.append_array(FileAccess.get_file_as_bytes(zone_path))
	return GenesisPalette.decode_cram_bytes(combined)

# -----------------------------------------------------------------------------
# Phase 68 - Scrap Brain Object $2A small automatic door
# -----------------------------------------------------------------------------
static func sbz_small_door_texture(frame: int, act: int = 1):
	frame = clampi(frame, 0, 8)
	var palette_act = 2 if act == 2 else 1
	var key = "sbz_small_door_a%d_f%d" % [palette_act, frame]
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SBZ Small Vertical Door.nem"])
	if source_path.is_empty():
		push_error("Phase 68: original SBZ Small Vertical Door Nemesis art is missing; no replacement art will be invented.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_sbz_object_palette(palette_act)
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# Map_ADoor has two identical 2x4 pieces using local tile 0 with Y-flip.
	# Each animation frame separates the halves by four pixels in opposite
	# directions. A fixed 16x128 canvas preserves the source origin across all
	# nine mapping frames ($00-$08).
	var image = Image.create_empty(16, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var separation = frame * 4
	_draw_piece(image, raw, palette, 0, 2, 4, 0, 32 - separation, false, true, 3)
	_draw_piece(image, raw, palette, 0, 2, 4, 0, 64 + separation, false, true, 3)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _load_sbz_object_palette(act: int) -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		return []
	var sonic_path = root.path_join("palette/Sonic.bin")
	var zone_name = "SBZ Act 2.bin" if act == 2 else "SBZ Act 1.bin"
	var zone_path = root.path_join("palette").path_join(zone_name)
	if not FileAccess.file_exists(sonic_path) or not FileAccess.file_exists(zone_path):
		push_error("Phase 68: original Sonic/SBZ palette is missing for the small door.")
		return []
	var combined = PackedByteArray()
	combined.append_array(FileAccess.get_file_as_bytes(sonic_path))
	combined.append_array(FileAccess.get_file_as_bytes(zone_path))
	return GenesisPalette.decode_cram_bytes(combined)

# -----------------------------------------------------------------------------
# Phase 41 - Scrap Brain Zone source-art helpers
# -----------------------------------------------------------------------------
static func sbz_junction_texture(frame: int):
	frame = clampi(frame, 0, 16)
	return _sbz_mapped_texture(
		"sbz_junction_%d" % frame,
		["SBZ Junction Wheel.nem"],
		SBZSourceMaps.JUNCTION[frame],
		Vector2i(128, 128), Vector2i(64, 64), 2
	)

static func sbz_running_disc_texture():
	return _sbz_mapped_texture(
		"sbz_running_disc",
		["SBZ Running Disc.nem"],
		SBZSourceMaps.DISC[0],
		Vector2i(32, 32), Vector2i(16, 16), 2
	)

static func sbz_trapdoor_texture(frame: int):
	frame = clampi(frame, 0, 2)
	return _sbz_mapped_texture(
		"sbz_trap_%d" % frame,
		["SBZ Trapdoor.nem"],
		SBZSourceMaps.TRAP[frame],
		Vector2i(192, 112), Vector2i(96, 56), 2
	)

static func sbz_spin_texture(frame: int):
	frame = clampi(frame, 0, 4)
	return _sbz_mapped_texture(
		"sbz_spin_%d" % frame,
		["SBZ Spinning Platform.nem"],
		SBZSourceMaps.SPIN[frame],
		Vector2i(64, 64), Vector2i(32, 32), 0
	)

static func sbz_saw_texture(frame: int):
	frame = clampi(frame, 0, 3)
	return _sbz_mapped_texture(
		"sbz_saw_%d" % frame,
		["SBZ Pizza Cutter.nem"],
		SBZSourceMaps.SAW[frame],
		Vector2i(96, 128), Vector2i(48, 64), 2
	)

# -----------------------------------------------------------------------------
# Phase 42 - remaining Scrap Brain Acts 1-2 source-art helpers
# -----------------------------------------------------------------------------
static func sbz_stomper_texture(frame: int):
	frame = clampi(frame, 0, 4)
	if frame == 0:
		# Map_Stomp's door pieces are addressed relative to the SBZ moving-block
		# base ($2C0), while Nem_SbzDoor2 is loaded at $46F.  $46F-$2C0=$1AF.
		return _sbz_mapped_texture(
			"sbz_stomper_door", ["SBZ Large Horizontal Door.nem"],
			SBZSourceMaps.STOMP[0], Vector2i(192, 96), Vector2i(96, 48), 2, 0x1AF
		)
	if frame >= 1 and frame <= 3:
		return _sbz_mapped_texture(
			"sbz_stomper_%d" % frame, ["SBZ Stomper.nem"],
			SBZSourceMaps.STOMP[frame], Vector2i(96, 96), Vector2i(48, 48), 2
		)
	# Frame 4 is the ancient SBZ3/LZ4 lift and uses level-pattern art rather than
	# a standalone Nemesis object stream.  That transition remains deliberately
	# outside the Acts 1-2 Phase 42 scope.
	return null

static func sbz_vanishing_texture(frame: int):
	frame = clampi(frame, 0, 3)
	return _sbz_mapped_texture(
		"sbz_vanishing_%d" % frame, ["SBZ Vanishing Block.nem"],
		SBZSourceMaps.VANISH[frame], Vector2i(64, 64), Vector2i(32, 32), 3
	)

static func sbz_flamethrower_texture(frame: int):
	frame = clampi(frame, 0, 21)
	var key := "sbz_flame_v45_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SBZ Flaming Pipe.nem"])
	if source_path.is_empty():
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_sbz_palette()
	if raw.is_empty() or palette.is_empty():
		return null
	var image = Image.create_empty(64, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var pieces: Array = SBZSourceMaps.FLAME[frame]
	# The pipe/valve piece is the palette-line-2 piece. Draw that base first,
	# then the palette-line-0 flame pieces so upward fire remains visibly in
	# front of the mouth exactly as the VDP's earlier sprite entries do.
	for pass_index in range(2):
		for piece_variant in pieces:
			var piece: Array = piece_variant
			var is_base := int(piece[7]) == 2
			if (pass_index == 0) != is_base:
				continue
			_draw_piece(image, raw, palette, int(piece[4]), int(piece[2]), int(piece[3]), 32 + int(piece[0]), 64 + int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, int(piece[7]))
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func sbz_electro_texture(frame: int, palette_override: Array[Color] = []):
	frame = clampi(frame, 0, 5)
	return _sbz_mapped_texture(
		"sbz_electro_%d" % frame, ["SBZ Electrocuter.nem"],
		SBZSourceMaps.ELECTRO[frame], Vector2i(160, 64), Vector2i(80, 32), 0, 0, false, palette_override
	)

static func sbz_girder_texture():
	return _sbz_mapped_texture(
		"sbz_girder", ["SBZ Crushing Girder.nem"],
		SBZSourceMaps.GIRDER[0], Vector2i(192, 64), Vector2i(96, 32), 3
	)

static func _sbz_mapped_texture(key: String, source_names: Array, pieces: Array, canvas_size: Vector2i, origin: Vector2i, base_palette_line: int, tile_bias: int = 0, reverse_piece_order: bool = false, palette_override: Array[Color] = []):
	var use_runtime_palette := not palette_override.is_empty()
	if use_runtime_palette:
		key += "_pal_" + _runtime_palette_signature(palette_override, [60, 61, 62])
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", source_names)
	if source_path.is_empty():
		push_error("Phase 41: original Scrap Brain source art is missing for %s; no replacement art will be invented." % key)
		if not use_runtime_palette:
			_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = palette_override if use_runtime_palette else _load_sbz_palette()
	if raw.is_empty() or palette.is_empty():
		if not use_runtime_palette:
			_cache[key] = null
		return null
	var image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var draw_pieces: Array = pieces.duplicate()
	# Genesis sprite entries earlier in the mapping list win pixel priority when
	# pieces overlap. Image compositing is painter's-order, so selected compound
	# sprites need the source list reversed to preserve that hardware ordering.
	if reverse_piece_order:
		draw_pieces.reverse()
	for piece_variant in draw_pieces:
		var piece: Array = piece_variant
		if piece.size() < 9:
			continue
		_draw_piece(
			image, raw, palette,
			int(piece[4]) - tile_bias, int(piece[2]), int(piece[3]),
			origin.x + int(piece[0]), origin.y + int(piece[1]),
			int(piece[5]) != 0, int(piece[6]) != 0,
			base_palette_line + int(piece[7])
		)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


# Phase 61 - Object $52 Scrap Brain moving blocks and Object $1E/$20 Ball Hog.
static func sbz_moving_block_texture(long_red: bool):
	if long_red:
		var long_pieces: Array = [
			[-0x40, -8, 4, 3, 0x00, 0, 0, 0, 0],
			[-0x20, -8, 4, 3, 0x03, 0, 0, 0, 0],
			[ 0x00, -8, 4, 3, 0x03, 0, 0, 0, 0],
			[ 0x20, -8, 4, 3, 0x00, 1, 0, 0, 0],
		]
		return _sbz_mapped_texture(
			"sbz_mblock_long", ["SBZ Sliding Floor Trap.nem"], long_pieces,
			Vector2i(144, 48), Vector2i(72, 24), 2
		)
	var short_pieces: Array = [
		[-0x20, -8, 4, 1, 0x00, 0, 0, 1, 0],
		[-0x20,  0, 4, 2, 0x04, 0, 0, 0, 0],
		[ 0x00, -8, 4, 1, 0x00, 0, 0, 1, 0],
		[ 0x00,  0, 4, 2, 0x04, 0, 0, 0, 0],
	]
	return _sbz_mapped_texture(
		"sbz_mblock_short", ["SBZ Stomper.nem"], short_pieces,
		Vector2i(80, 48), Vector2i(40, 24), 1
	)

static func ball_hog_texture(frame: int):
	frame = clampi(frame, 0, 5)
	var maps: Array = [
		[[-0x0C, -0x11, 3, 2, 0x00, 0, 0, 0, 0], [-0x0C, -1,    3, 3, 0x06, 0, 0, 0, 0]],
		[[-0x0C, -0x11, 3, 2, 0x00, 0, 0, 0, 0], [-0x0C, -1,    3, 3, 0x0F, 0, 0, 0, 0]],
		[[-0x0C, -0x0C, 3, 2, 0x00, 0, 0, 0, 0], [-0x0C,  4,    3, 2, 0x18, 0, 0, 0, 0]],
		[[-0x0C, -0x1C, 3, 2, 0x00, 0, 0, 0, 0], [-0x0C, -0x0C, 3, 3, 0x1E, 0, 0, 0, 0]],
		[[-8, -8, 2, 2, 0x27, 0, 0, 0, 0]],
		[[-8, -8, 2, 2, 0x2B, 0, 0, 0, 0]],
	]
	return _sbz_mapped_texture(
		"ball_hog_%d" % frame, ["Enemy Ball Hog.nem"], maps[frame],
		Vector2i(64, 64), Vector2i(32, 32), 1, 0, true
	)

# -----------------------------------------------------------------------------
# Phase 43 - SBZ2 trap-floor cutscene, shared SBZ art corrections, and SBZ3 lift
# -----------------------------------------------------------------------------
static func sbz_collapse_floor_texture(fragmented: bool = false):
	var key = "sbz_collapse_floor_frag" if fragmented else "sbz_collapse_floor_whole"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SBZ Collapsing Floor.nem"])
	if source_path.is_empty():
		push_error("Phase 43: original SBZ Collapsing Floor Nemesis art is missing.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_sbz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# PLC_SBZ loads Nem_SbzFloor at ArtTile_SBZ_Collapsing_Floor and PLC_SBZ2
	# loads the same four-tile stream again at +4. Map_CFlo frame 0 is 8 tiles,
	# so reproduce the resulting contiguous VRAM block before drawing it.
	var doubled_raw := PackedByteArray()
	doubled_raw.append_array(raw)
	doubled_raw.append_array(raw)
	raw = doubled_raw
	var image = Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if not fragmented:
		# Map_CFlo frame 0: four repeated 32x16 pieces from local tile 0.
		for row in range(2):
			for col in range(2):
				_draw_piece(image, raw, palette, 0, 4, 2, col * 32, row * 16, false, false, 2)
	else:
		# Map_CFlo frame 1: eight repeated 16x16 pieces, again local tile 0.
		for row in range(2):
			for col in range(4):
				_draw_piece(image, raw, palette, 0, 2, 2, col * 16, row * 16, false, false, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func sbz_swing_texture(frame: int):
	frame = clampi(frame, 0, 2)
	var key = "sbz_swing_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["SYZ Large Spikeball.nem"])
	if source_path.is_empty():
		push_error("Phase 43: original SYZ Large Spikeball Nemesis art used by SBZ Object $15 is missing.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_sbz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ox = 32
	var oy = 32
	match frame:
		0:
			# Map_BBall .ball.
			_draw_piece(image, raw, palette, 0x00, 2, 1, ox - 8, oy - 0x18, false, false, 0)
			_draw_piece(image, raw, palette, 0x02, 4, 4, ox - 0x10, oy - 0x10, false, false, 0)
			_draw_piece(image, raw, palette, 0x12, 1, 2, ox - 0x18, oy - 8, false, false, 0)
			_draw_piece(image, raw, palette, 0x14, 1, 2, ox + 0x10, oy - 8, false, false, 0)
			_draw_piece(image, raw, palette, 0x16, 2, 1, ox - 8, oy + 0x10, false, false, 0)
		1:
			# Map_BBall .chain. Source child logic forces the gray palette line.
			_draw_piece(image, raw, palette, 0x20, 2, 2, ox - 8, oy - 8, false, false, 0)
		2:
			# Map_BBall .anchor.
			_draw_piece(image, raw, palette, 0x18, 4, 2, ox - 0x10, oy - 8, false, false, 2)
			_draw_piece(image, raw, palette, 0x18, 4, 2, ox - 0x10, oy - 0x18, false, true, 2)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func sbz_eggman_texture(frame: int):
	frame = clampi(frame, 0, 4)
	var maps: Array = [
		[[-0x18,-4,1,1,0x8F,0,0,0,0],[-0x10,-0x18,4,3,0,0,0,0,0],[-0x10,0,4,4,0x6F,0,0,0,0]],
		[[-0x10,-0x18,4,2,0x0E,0,0,0,0],[-0x10,-0x18,4,3,0,0,0,0,0],[-0x10,0,4,4,0x6F,0,0,0,0],[-0x18,-4,1,1,0x8F,0,0,0,0]],
		[[-0x10,-0x17,4,2,0x0E,0,0,0,0],[-0x10,-0x17,4,3,0,0,0,0,0],[-0x10,1,4,4,0x7F,0,0,0,0],[-0x18,-3,1,1,0x8F,0,0,0,0]],
		[[-0x10,-0x0C,4,4,0x20,1,0,0,0],[0x10,-0x0B,2,1,0x30,1,0,0,0],[-0x10,8,3,2,0x4E,1,0,0,0],[-0x10,-0x14,4,3,0,0,0,0,0]],
		[[-0x10,-0x10,4,4,0x20,1,0,0,0],[0x10,-0x0F,2,1,0x30,1,0,0,0],[-8,8,2,3,0x3E,1,0,0,0],[-0x10,-0x18,4,3,0,0,0,0,0]],
	]
	return _sbz_mapped_texture(
		"sbz_eggman_%d" % frame, ["Boss - Eggman in SBZ2 & FZ.nem"], maps[frame],
		Vector2i(96, 96), Vector2i(48, 48), 0, 0, true
	)

static func sbz_false_floor_texture(frame: int):
	frame = clampi(frame, 0, 4)
	var maps: Array = [
		[[-0x10,-0x10,4,4,0,0,0,0,0]],
		[[-8,-8,1,2,0,0,0,0,0],[0,-8,1,2,4,0,0,0,0]],
		[[-8,-8,1,2,8,0,0,0,0],[0,-8,1,2,0x0C,0,0,0,0]],
		[[-8,-8,1,2,2,0,0,0,0],[0,-8,1,2,6,0,0,0,0]],
		[[-8,-8,1,2,0x0A,0,0,0,0],[0,-8,1,2,0x0E,0,0,0,0]],
	]
	return _sbz_mapped_texture(
		"sbz_false_floor_%d" % frame, ["SBZ Vanishing Block.nem"], maps[frame],
		Vector2i(48, 48), Vector2i(24, 24), 2
	)

static func sbz_eggman_switch_texture(pressed: bool):
	var key = "sbz_eggman_switch_%d" % (1 if pressed else 0)
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Switch.nem"])
	if source_path.is_empty():
		push_error("Phase 43: original Switch Nemesis art is missing.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_sbz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(40, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# ArtTile_Button_Main is ArtTile_Button+4 specifically to skip the unused
	# red-top tiles. Map_Button then selects local +0 (up) or +4 (down).
	var tile = 8 if pressed else 4
	_draw_piece(image, raw, palette, tile, 2, 2, 4, 5, false, false, 0)
	_draw_piece(image, raw, palette, tile, 2, 2, 20, 5, true, false, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func sbz3_ancient_lift_texture():
	var key = "sbz3_ancient_lift"
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["LZ Blocks.nem"])
	if source_path.is_empty():
		push_error("Phase 43: original LZ Blocks Nemesis art for the SBZ3 ancient lift is missing.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_sbz3_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(256, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece_variant in SBZSourceMaps.STOMP[4]:
		var piece: Array = piece_variant
		_draw_piece(
			image, raw, palette, int(piece[4]), int(piece[2]), int(piece[3]),
			128 + int(piece[0]), 64 + int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, 2
		)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _load_sbz3_palette() -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		return []
	var sonic_path = root.path_join("palette/Sonic.bin")
	var zone_path = root.path_join("palette/SBZ Act 3.bin")
	if not FileAccess.file_exists(sonic_path) or not FileAccess.file_exists(zone_path):
		return []
	var combined = PackedByteArray()
	combined.append_array(FileAccess.get_file_as_bytes(sonic_path))
	combined.append_array(FileAccess.get_file_as_bytes(zone_path))
	return GenesisPalette.decode_cram_bytes(combined)

static func _load_sbz_palette() -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		push_error("Phase 41: could not locate the Sonic 1 source-data root for the SBZ palette.")
		return []
	var sonic_path = root.path_join("palette/Sonic.bin")
	var zone_path = root.path_join("palette/SBZ Act 1.bin")
	if not FileAccess.file_exists(sonic_path) or not FileAccess.file_exists(zone_path):
		push_error("Phase 41: original Sonic/Scrap Brain palettes are missing; source object art cannot be rendered exactly.")
		return []
	var combined = PackedByteArray()
	combined.append_array(FileAccess.get_file_as_bytes(sonic_path))
	combined.append_array(FileAccess.get_file_as_bytes(zone_path))
	return GenesisPalette.decode_cram_bytes(combined)

static func _load_fz_palette() -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		return []
	var sonic_path = root.path_join("palette/Sonic.bin")
	var zone_path = root.path_join("palette/SBZ Act 2.bin")
	if not FileAccess.file_exists(sonic_path) or not FileAccess.file_exists(zone_path):
		return []
	var combined = PackedByteArray()
	combined.append_array(FileAccess.get_file_as_bytes(sonic_path))
	combined.append_array(FileAccess.get_file_as_bytes(zone_path))
	return GenesisPalette.decode_cram_bytes(combined)

static func _fz_mapped_texture(key: String, source_names: Array, pieces: Array, canvas_size: Vector2i, origin: Vector2i, base_palette_line: int, tile_bias: int = 0, reverse_piece_order: bool = false):
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", source_names)
	if source_path.is_empty():
		push_error("Phase 45: original Final Zone source art is missing for %s." % key)
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_fz_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var draw_pieces: Array = pieces.duplicate()
	if reverse_piece_order:
		draw_pieces.reverse()
	for piece_variant in draw_pieces:
		var piece: Array = piece_variant
		if piece.size() < 9:
			continue
		_draw_piece(image, raw, palette, int(piece[4]) - tile_bias, int(piece[2]), int(piece[3]), origin.x + int(piece[0]), origin.y + int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, base_palette_line + int(piece[7]))
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

# -----------------------------------------------------------------------------
# Phase 44 - Final Zone boss source-art helpers
# -----------------------------------------------------------------------------
static func fz_eggman_texture(frame: int):
	frame = clampi(frame, 0, 10)
	# Frame 9 mixes the cylinder stream through wrapped VDP tile arithmetic.
	# The native boss uses the standalone cylinders around Eggman instead, so
	# no caller should request that mixed frame.
	if frame == 9:
		return null
	return _fz_mapped_texture(
		"fz_eggman_%d" % frame, ["Boss - Eggman in SBZ2 & FZ.nem"],
		FZSourceMaps.SEGG[frame], Vector2i(112, 112), Vector2i(56, 56), 0, 0, true
	)

static func fz_cylinder_texture(frame: int):
	frame = clampi(frame, 0, 11)
	return _fz_mapped_texture(
		"fz_cylinder_%d" % frame, ["Boss - Final Zone.nem"],
		# Frames 5+ extend through mapping Y +$58 with a 4-tile-tall piece,
		# requiring a full +120px below origin. A 240px centred canvas keeps
		# every source pixel in bounds while preserving mapping coordinates.
		FZSourceMaps.CYLINDER[frame], Vector2i(96, 240), Vector2i(48, 120), 0, 0, true
	)

static func fz_plasma_launcher_texture(frame: int):
	frame = clampi(frame, 0, 3)
	return _fz_mapped_texture(
		"fz_launcher_%d" % frame, ["Boss - Final Zone.nem"],
		FZSourceMaps.PLAUNCH[frame], Vector2i(48, 48), Vector2i(24, 24), 0, 0, true
	)

static func fz_plasma_ball_texture(frame: int):
	frame = clampi(frame, 0, 10)
	return _fz_mapped_texture(
		"fz_plasma_%d" % frame, ["Boss - Final Zone.nem"],
		FZSourceMaps.PLASMA[frame], Vector2i(64, 64), Vector2i(32, 32), 2, 0, true
	)

static func fz_damaged_ship_texture(frame: int):
	frame = clampi(frame, 0, 1)
	return _fz_mapped_texture(
		"fz_damaged_%d" % frame, ["Boss - Eggman after FZ Fight.nem"],
		FZSourceMaps.DAMAGED[frame], Vector2i(96, 96), Vector2i(48, 48), 0, 0, true
	)

static func fz_legs_texture(frame: int):
	frame = clampi(frame, 0, 2)
	return _fz_mapped_texture(
		"fz_legs_%d" % frame, ["Boss - Eggman after FZ Fight.nem"],
		FZSourceMaps.LEGS[frame], Vector2i(96, 112), Vector2i(48, 48), 0, 0, true
	)

# -----------------------------------------------------------------------------
# Phase 45 - Ending sequence source-art helpers
# -----------------------------------------------------------------------------
static func _load_ending_palette() -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		return []
	var ending_path = root.path_join("palette/Ending.bin")
	var sonic_path = root.path_join("palette/Sonic.bin")
	if not FileAccess.file_exists(ending_path) or not FileAccess.file_exists(sonic_path):
		return []
	var ending_raw := FileAccess.get_file_as_bytes(ending_path)
	var sonic_raw := FileAccess.get_file_as_bytes(sonic_path)
	# GM_Ending loads palid_Ending through LevelDataLoad, then overlays palid_Sonic
	# into CRAM line 0 for the actual Sonic/ending-object render pass.
	for i in range(mini(32, mini(ending_raw.size(), sonic_raw.size()))):
		ending_raw[i] = sonic_raw[i]
	return GenesisPalette.decode_cram_bytes(ending_raw)

static func _ending_mapped_texture(key: String, source_names: Array, pieces: Array, canvas_size: Vector2i, origin: Vector2i, base_palette_line: int = 0):
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", source_names)
	if source_path.is_empty():
		push_error("Phase 45: original Ending source art is missing for %s." % key)
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_ending_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece_variant in pieces:
		var piece: Array = piece_variant
		if piece.size() < 9:
			continue
		_draw_piece(image, raw, palette, int(piece[4]), int(piece[2]), int(piece[3]), origin.x + int(piece[0]), origin.y + int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, base_palette_line + int(piece[7]))
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func ending_sonic_texture(frame: int):
	frame = clampi(frame, 0, 7)
	return _ending_mapped_texture("ending_sonic_%d" % frame, ["Ending - Sonic.nem"], EndingSourceMaps.SONIC[frame], Vector2i(320, 320), Vector2i(160, 160), 0)

static func ending_emerald_texture(frame: int):
	frame = clampi(frame, 0, 6)
	return _ending_mapped_texture("ending_emerald_%d" % frame, ["Ending - Emeralds.nem"], EndingSourceMaps.EMERALD[frame], Vector2i(32, 32), Vector2i(16, 16), 0)

static func ending_logo_texture():
	return _ending_mapped_texture("ending_sth_logo", ["Ending - StH Logo.nem"], EndingSourceMaps.LOGO[0], Vector2i(112, 48), Vector2i(56, 24), 0)

static func ending_animal_texture(subtype: int, frame: int):
	frame = clampi(frame, 0, 2)
	var stream := "Animal Flicky.nem"
	var maps: Array = EndingSourceMaps.ANIMAL2
	match subtype:
		0x0A, 0x0B, 0x0C:
			stream = "Animal Flicky.nem"
			maps = EndingSourceMaps.ANIMAL2
		0x0D, 0x0E:
			stream = "Animal Rabbit.nem"
			maps = EndingSourceMaps.ANIMAL1
		0x0F, 0x10:
			stream = "Animal Penguin.nem"
			maps = EndingSourceMaps.ANIMAL1
		0x11:
			stream = "Animal Seal.nem"
			maps = EndingSourceMaps.ANIMAL2
		0x12:
			stream = "Animal Pig.nem"
			maps = EndingSourceMaps.ANIMAL3
		0x13:
			stream = "Animal Chicken.nem"
			maps = EndingSourceMaps.ANIMAL2
		0x14:
			stream = "Animal Squirrel.nem"
			maps = EndingSourceMaps.ANIMAL3
	return _ending_mapped_texture("ending_animal_%02X_%d" % [subtype, frame], [stream], maps[frame], Vector2i(40, 40), Vector2i(20, 20), 0)

# -----------------------------------------------------------------------------
# Phase 46 - Credits and TRY AGAIN / END source-art helpers
# -----------------------------------------------------------------------------
static func _load_credits_palette() -> Array[Color]:
	var root = _find_data_root()
	if root.is_empty():
		return []
	var sonic_path = root.path_join("palette/Sonic.bin")
	if not FileAccess.file_exists(sonic_path):
		push_error("Phase 46: original Sonic palette is missing; credits text cannot be rendered exactly.")
		return []
	return GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(sonic_path))

static func credits_page_texture(frame: int, ending_palette: bool = false):
	frame = clampi(frame, 0, 10)
	var key := "credits_page_%d_%s" % [frame, "end" if ending_palette else "credits"]
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Ending - Credits.nem"])
	if source_path.is_empty():
		push_error("Phase 46: original Ending - Credits Nemesis art is missing.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_ending_palette() if ending_palette else _load_credits_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	# Object $8A is centred at source screen position ($A0,$70). Render the
	# complete 320x224 source frame so the mapping coordinates remain literal.
	var image = Image.create_empty(320, 224, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece_variant in CreditsSourceMaps.CREDITS[frame]:
		var piece: Array = piece_variant
		_draw_piece(image, raw, palette, int(piece[4]), int(piece[2]), int(piece[3]), 160 + int(piece[0]), 112 + int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, int(piece[7]))
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func end_screen_eggman_texture(frame: int):
	frame = clampi(frame, 0, 7)
	var key := "end_screen_eggman_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var source_path = _find_source_file("artnem", ["Ending - Try Again.nem"])
	if source_path.is_empty():
		push_error("Phase 46: original Ending - Try Again Nemesis art is missing.")
		_cache[key] = null
		return null
	var raw = Nemesis.decompress(FileAccess.get_file_as_bytes(source_path))
	var palette = _load_ending_palette()
	if raw.is_empty() or palette.is_empty():
		_cache[key] = null
		return null
	var image = Image.create_empty(112, 144, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece_variant in CreditsSourceMaps.END_EGGMAN[frame]:
		var piece: Array = piece_variant
		_draw_piece(image, raw, palette, int(piece[4]), int(piece[2]), int(piece[3]), 56 + int(piece[0]), 72 + int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, int(piece[7]))
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
