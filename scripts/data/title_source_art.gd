class_name TitleSourceArt
extends RefCounted

# Runtime compositor for the original REV01 SEGA and Sonic 1 title-screen
# assets. Art and tilemaps remain in their original compressed formats in
# data/s1; this class only expands them into nearest-filtered Godot textures.

static var _cache: Dictionary = {}
static var _sega_raw := PackedByteArray()
static var _sega_words: Array[int] = []
static var _sega_palette_states: Array = []
static var _title_sonic_raw := PackedByteArray()

static func sega_logo_texture(palcycle_steps: int = 76) -> Texture2D:
	palcycle_steps = clampi(palcycle_steps, 0, 76)
	var key := "sega_logo_%d" % palcycle_steps
	if _cache.has(key):
		return _cache[key]
	var art_path := "res://data/s1/artnem/Sega Logo (REV01).nem"
	var map_path := "res://data/s1/tilemaps/Sega Logo (REV01).eni"
	if not FileAccess.file_exists(art_path) or not FileAccess.file_exists(map_path):
		push_error("Phase 47 hotfix: original REV01 SEGA logo source files are missing.")
		return null
	if _sega_raw.is_empty():
		_sega_raw = Nemesis.decompress(FileAccess.get_file_as_bytes(art_path))
	if _sega_words.is_empty():
		_sega_words = _words_from_be(Enigma.decompress(FileAccess.get_file_as_bytes(map_path), 0))
	var raw := _sega_raw
	var words: Array[int] = _sega_words
	if raw.is_empty() or words.size() < 192 + 40 * 28:
		push_error("Phase 47 hotfix: SEGA logo source data failed to decompress.")
		return null
	var palette := _sega_palette_after_steps(palcycle_steps)
	var image := Image.create_empty(320, 224, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# GM_Sega first copies a 24x8 animated color block to Plane B at $510
	# (tile coordinate 8,10 on the 64-cell plane), then overlays the 40x28
	# Plane A cutout. Rendering both with the palette after N PalCycle_Sega
	# calls reproduces the real traveling-light reveal instead of alpha-fading
	# an already-complete SEGA logo.
	_render_tilemap(image, raw, palette, words, 0, 24, 8, 64, 80, 0, -1)
	_render_tilemap(image, raw, palette, words, 192, 40, 28, 0, 0, 0, -1)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func sega_logo_index_texture() -> Texture2D:
	# Phase 66 cold-start path: the SEGA planes never change during PalCycle_Sega;
	# only CRAM does. Build the 6-bit palette-index image once and let a tiny
	# 64x1 palette texture change each VBlank instead of rebuilding 77 full
	# 320x224 RGBA textures on the first attract cycle.
	var key = "sega_logo_indices"
	if _cache.has(key):
		return _cache[key]
	var art_path = "res://data/s1/artnem/Sega Logo (REV01).nem"
	var map_path = "res://data/s1/tilemaps/Sega Logo (REV01).eni"
	if not FileAccess.file_exists(art_path) or not FileAccess.file_exists(map_path):
		push_error("Phase 66: original REV01 SEGA logo source files are missing.")
		return null
	if _sega_raw.is_empty():
		_sega_raw = Nemesis.decompress(FileAccess.get_file_as_bytes(art_path))
	if _sega_words.is_empty():
		_sega_words = _words_from_be(Enigma.decompress(FileAccess.get_file_as_bytes(map_path), 0))
	if _sega_raw.is_empty() or _sega_words.size() < 192 + 40 * 28:
		push_error("Phase 66: SEGA logo source data failed to decompress.")
		return null
	var image = Image.create_empty(320, 224, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_render_tilemap_indices(image, _sega_raw, _sega_words, 0, 24, 8, 64, 80, 0)
	_render_tilemap_indices(image, _sega_raw, _sega_words, 192, 40, 28, 0, 0, 0)
	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func sega_palette_colors(step_count: int) -> Array[Color]:
	return _sega_palette_after_steps(clampi(step_count, 0, 76))

static func title_emblem_texture(high_priority: bool) -> Texture2D:
	var key := "title_emblem_high" if high_priority else "title_emblem_low"
	if _cache.has(key):
		return _cache[key]
	var art_path := "res://data/s1/artnem/Title Screen Foreground.nem"
	var map_path := "res://data/s1/tilemaps/Title Screen.eni"
	if not FileAccess.file_exists(art_path) or not FileAccess.file_exists(map_path):
		push_error("Phase 47: original title foreground source files are missing.")
		return null
	var raw := Nemesis.decompress(FileAccess.get_file_as_bytes(art_path))
	var words := _words_from_be(Enigma.decompress(FileAccess.get_file_as_bytes(map_path), 0))
	var palette := _title_palette()
	if raw.is_empty() or words.size() < 34 * 22 or palette.is_empty():
		return null
	var image := Image.create_empty(272, 176, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_render_tilemap(image, raw, palette, words, 0, 34, 22, 0, 0, 0x200, 1 if high_priority else 0)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func title_sonic_texture(frame: int, screen_y: int = 22, press_start_visible: bool = false) -> Texture2D:
	frame = clampi(frame, 0, TitleSourceMaps.SONIC_FRAMES.size() - 1)
	var key := "title_sonic_%d_y%d_ps%d" % [frame, screen_y, 1 if press_start_visible else 0]
	if _cache.has(key):
		return _cache[key]
	var art_path := "res://data/s1/artnem/Title Screen Sonic.nem"
	if not FileAccess.file_exists(art_path):
		push_error("Phase 47 hotfix: original title Sonic Nemesis art is missing.")
		return null
	if _title_sonic_raw.is_empty():
		_title_sonic_raw = Nemesis.decompress(FileAccess.get_file_as_bytes(art_path))
	var raw := _title_sonic_raw
	var palette := _title_palette()
	var image := Image.create_empty(96, 104, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_title_sonic_frame(image, raw, palette, TitleSourceMaps.SONIC_FRAMES[frame], screen_y, press_start_visible)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func press_start_texture() -> Texture2D:
	if _cache.has("press_start"):
		return _cache["press_start"]
	var raw := Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Title Screen Foreground.nem"))
	var palette := _title_palette()
	var image := Image.create_empty(152, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece in TitleSourceMaps.PRESS_START:
		_draw_piece(image, raw, palette, int(piece[4]), int(piece[2]), int(piece[3]), int(piece[0]), int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, int(piece[7]))
	var texture := ImageTexture.create_from_image(image)
	_cache["press_start"] = texture
	return texture

static func trademark_texture() -> Texture2D:
	if _cache.has("title_tm"):
		return _cache["title_tm"]
	var raw := Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Title Screen TM.nem"))
	var palette := _title_palette()
	var image := Image.create_empty(16, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece in TitleSourceMaps.TRADEMARK:
		_draw_piece(image, raw, palette, int(piece[4]), int(piece[2]), int(piece[3]), 8 + int(piece[0]), 4 + int(piece[1]), int(piece[5]) != 0, int(piece[6]) != 0, 1 + int(piece[7]))
	var texture := ImageTexture.create_from_image(image)
	_cache["title_tm"] = texture
	return texture

static func title_background_texture(phase: int) -> Texture2D:
	var path := "res://assets/title_background_%d.png" % (phase & 3)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func title_background_color() -> Color:
	var palette := _title_palette()
	return palette[32] if palette.size() > 32 else Color.BLACK

static func title_water_cycle_palette(phase: int) -> Array[Color]:
	var palette := _title_palette().duplicate()
	var path := "res://data/s1/palette/Cycle - Title Screen Water.bin"
	if palette.size() < 64 or not FileAccess.file_exists(path):
		return palette
	var cyc := GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(path))
	if cyc.size() < 16:
		return palette
	var base := (phase & 3) * 4
	for i in range(4):
		palette[2 * 16 + 8 + i] = cyc[base + i]
	return palette

static func _title_palette() -> Array[Color]:
	var path := "res://data/s1/palette/Title Screen.bin"
	if not FileAccess.file_exists(path):
		push_error("Phase 47: original Title Screen palette is missing.")
		return []
	return GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(path))

static func _sega_palette_after_steps(step_count: int) -> Array[Color]:
	_ensure_sega_palette_states()
	if _sega_palette_states.is_empty():
		return []
	return _sega_palette_states[clampi(step_count, 0, 76)]

static func _ensure_sega_palette_states() -> void:
	if not _sega_palette_states.is_empty():
		return
	var base_path = "res://data/s1/palette/Sega Background.bin"
	var scan_path = "res://data/s1/palette/Sega1.bin"
	var fade_path = "res://data/s1/palette/Sega2.bin"
	var palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(base_path))
	var scan = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(scan_path))
	var fade = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(fade_path))
	if palette.size() < 64 or scan.size() < 6 or fade.size() < 24:
		return

	# State 0 is the untouched Sega background palette. Each following entry is
	# the exact palette after one additional PalCycle_Sega VBlank.
	_sega_palette_states.append(palette.duplicate())
	var pcyc_num = -10
	var scanning = true
	var fade_delay = 4
	for _step in range(76):
		if scanning:
			var source_index = 0
			var colors_left = 6
			var draw_offset = pcyc_num
			while draw_offset < 0 and colors_left > 0:
				source_index += 1
				colors_left -= 1
				draw_offset += 2
			for _color in range(colors_left):
				if (draw_offset & 0x1E) == 0:
					draw_offset += 2
				if draw_offset < 0x60 and source_index < scan.size():
					var palette_index = 16 + int(draw_offset / 2)
					if palette_index >= 0 and palette_index < palette.size():
						palette[palette_index] = scan[source_index]
				draw_offset += 2
				source_index += 1

			var next_offset = pcyc_num + 2
			if (next_offset & 0x1E) == 0:
				next_offset += 2
			if next_offset >= 0x64:
				scanning = false
				fade_delay = 4
				pcyc_num = -12
			else:
				pcyc_num = next_offset
		else:
			fade_delay -= 1
			if fade_delay < 0:
				fade_delay = 4
				var next_fade = pcyc_num + 12
				if next_fade < 48:
					pcyc_num = next_fade
					var fade_start = int(pcyc_num / 2)
					for i in range(5):
						palette[2 + i] = fade[fade_start + i]
					var fill = fade[fade_start + 5]
					for line in range(1, 4):
						for color in range(1, 16):
							palette[line * 16 + color] = fill
		_sega_palette_states.append(palette.duplicate())

static func _sega_final_palette() -> Array[Color]:
	return _sega_palette_after_steps(76)

static func _draw_title_sonic_frame(image: Image, raw: PackedByteArray, palette: Array[Color], pieces: Array, screen_y: int, press_start_visible: bool) -> void:
	# Object $0F frame 2 places ten 4x4 (32px-wide) sprites on each scanline
	# from Y=104..199. The Mega Drive H40 sprite-pixel budget is 320 pixels,
	# so those ten sprites deliberately exhaust the entire line before the
	# lower-priority-queue Title Sonic is processed. This is the retail trick
	# that lets the plane banner cover Sonic's lower torso.
	var used_sprites := PackedInt32Array()
	var used_pixels := PackedInt32Array()
	used_sprites.resize(image.get_height())
	used_pixels.resize(image.get_height())
	for local_y in range(image.get_height()):
		var global_y := screen_y + local_y
		if global_y >= 104 and global_y < 200:
			used_sprites[local_y] = 10
			used_pixels[local_y] = 320
		else:
			# Static TM and visible PRESS START precede Sonic too. They do not
			# affect the final banner band, but retaining their scanline costs
			# keeps the rising title animation faithful as well.
			if global_y >= 116 and global_y < 124:
				used_sprites[local_y] += 1
				used_pixels[local_y] += 16
			if press_start_visible and global_y >= 176 and global_y < 184:
				used_sprites[local_y] += 6
				used_pixels[local_y] += 128

	for piece_variant in pieces:
		var piece: Array = piece_variant
		var piece_y := int(piece[1])
		var piece_height := int(piece[3]) * 8
		var piece_width := int(piece[2]) * 8
		var allowed := PackedByteArray()
		allowed.resize(piece_height)
		for py in range(piece_height):
			var local_y := piece_y + py
			if local_y < 0 or local_y >= image.get_height():
				continue
			if used_sprites[local_y] >= 20 or used_pixels[local_y] + piece_width > 320:
				continue
			allowed[py] = 1
			used_sprites[local_y] += 1
			used_pixels[local_y] += piece_width
		_draw_title_piece_preserve(image, raw, palette, piece, allowed)

static func _draw_title_piece_preserve(image: Image, raw: PackedByteArray, palette: Array[Color], piece: Array, allowed_rows: PackedByteArray) -> void:
	var tile_base := int(piece[4])
	var width_tiles := int(piece[2])
	var height_tiles := int(piece[3])
	var target_x := int(piece[0])
	var target_y := int(piece[1])
	var flip_x := int(piece[5]) != 0
	var flip_y := int(piece[6]) != 0
	var palette_line := 1 + int(piece[7])
	for out_tx in range(width_tiles):
		for out_ty in range(height_tiles):
			var source_tx := width_tiles - 1 - out_tx if flip_x else out_tx
			var source_ty := height_tiles - 1 - out_ty if flip_y else out_ty
			var tile_index := tile_base + source_tx * height_tiles + source_ty
			for py in range(8):
				var piece_row := out_ty * 8 + py
				if piece_row < 0 or piece_row >= allowed_rows.size() or allowed_rows[piece_row] == 0:
					continue
				var sample_y := 7 - py if flip_y else py
				for px in range(8):
					var sample_x := 7 - px if flip_x else px
					var ci := _tile_pixel(raw, tile_index, sample_x, sample_y)
					if ci == 0:
						continue
					var pi := palette_line * 16 + ci
					var dx := target_x + out_tx * 8 + px
					var dy := target_y + out_ty * 8 + py
					if pi < 0 or pi >= palette.size() or dx < 0 or dy < 0 or dx >= image.get_width() or dy >= image.get_height():
						continue
					# Earlier Genesis sprite entries win overlap priority. The mapping
					# file is already in sprite-table order, so do not overwrite them.
					if image.get_pixel(dx, dy).a > 0.0:
						continue
					image.set_pixel(dx, dy, palette[pi])

static func _words_from_be(data: PackedByteArray) -> Array[int]:
	var out: Array[int] = []
	for i in range(0, data.size() - 1, 2):
		out.append((int(data[i]) << 8) | int(data[i + 1]))
	return out


static func _render_tilemap_indices(image: Image, raw: PackedByteArray, words: Array[int], start_word: int, width: int, height: int, target_x: int, target_y: int, tile_bias: int) -> void:
	for ty in range(height):
		for tx in range(width):
			var index = start_word + ty * width + tx
			if index < 0 or index >= words.size():
				continue
			var word = int(words[index])
			var tile = word & 0x7FF
			if tile < tile_bias:
				continue
			var palette_line = (word >> 13) & 3
			_draw_piece_indices(image, raw, tile - tile_bias, 1, 1, target_x + tx * 8, target_y + ty * 8, (word & 0x0800) != 0, (word & 0x1000) != 0, palette_line)

static func _draw_piece_indices(image: Image, raw: PackedByteArray, tile_base: int, width_tiles: int, height_tiles: int, target_x: int, target_y: int, flip_x: bool, flip_y: bool, palette_line: int) -> void:
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
					var palette_index = palette_line * 16 + ci
					var dx = target_x + out_tx * 8 + px
					var dy = target_y + out_ty * 8 + py
					if dx < 0 or dy < 0 or dx >= image.get_width() or dy >= image.get_height():
						continue
					# Store the exact CRAM index in the red byte. Alpha preserves the
					# sprite/tile transparency that the old RGBA compositor used.
					image.set_pixel(dx, dy, Color(float(palette_index) / 255.0, 0.0, 0.0, 1.0))

static func _render_tilemap(image: Image, raw: PackedByteArray, palette: Array[Color], words: Array[int], start_word: int, width: int, height: int, target_x: int, target_y: int, tile_bias: int, priority_filter: int) -> void:
	for ty in range(height):
		for tx in range(width):
			var index := start_word + ty * width + tx
			if index < 0 or index >= words.size():
				continue
			var word := int(words[index])
			var tile := word & 0x7FF
			if tile < tile_bias:
				continue
			var priority := 1 if (word & 0x8000) != 0 else 0
			if priority_filter >= 0 and priority != priority_filter:
				continue
			var palette_line := (word >> 13) & 3
			_draw_piece(image, raw, palette, tile - tile_bias, 1, 1, target_x + tx * 8, target_y + ty * 8, (word & 0x0800) != 0, (word & 0x1000) != 0, palette_line)

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
	return (value >> 4) & 0x0F if (x & 1) == 0 else value & 0x0F
