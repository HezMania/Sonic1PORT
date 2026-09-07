class_name ContinueSourceArt
extends RefCounted

const CONT_BASE := 0x500
const MINI_BASE := 0x551
const TITLE_BASE := 0x580

static var _cache: Dictionary = {}
static var _cont_raw := PackedByteArray()
static var _mini_raw := PackedByteArray()
static var _title_raw := PackedByteArray()
static var _palette: Array[Color] = []

static func text_texture() -> Texture2D:
	if _cache.has("text"):
		return _cache["text"]
	_ensure_loaded()
	var image := Image.create_empty(160, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Last mapping piece is the live two-digit countdown, redrawn separately.
	for i in range(10):
		_draw_piece(image, ContinueSourceMaps.FRAMES[0][i], CONT_BASE, 80, 8)
	var texture := ImageTexture.create_from_image(image)
	_cache["text"] = texture
	return texture

static func sonic_floor_texture(frame: int) -> Texture2D:
	frame = clampi(frame, 1, 3)
	var key := "floor_%d" % frame
	if _cache.has(key):
		return _cache[key]
	_ensure_loaded()
	var image := Image.create_empty(64, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece in ContinueSourceMaps.FRAMES[frame]:
		_draw_piece(image, piece, CONT_BASE, 32, 24)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func floor_light_texture() -> Texture2D:
	if _cache.has("light"):
		return _cache["light"]
	_ensure_loaded()
	var image := Image.create_empty(48, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece in ContinueSourceMaps.FRAMES[4]:
		var local_piece: Array = piece.duplicate()
		local_piece[1] = int(local_piece[1]) - 0x60
		_draw_piece(image, local_piece, CONT_BASE, 24, 0)
	var texture := ImageTexture.create_from_image(image)
	_cache["light"] = texture
	return texture

static func mini_sonic_texture(foot_up: bool) -> Texture2D:
	var key := "mini_up" if foot_up else "mini_down"
	if _cache.has(key):
		return _cache[key]
	_ensure_loaded()
	var image := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var frame := 7 if foot_up else 6
	for piece in ContinueSourceMaps.FRAMES[frame]:
		_draw_piece(image, piece, MINI_BASE, 0, 0)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func background_color() -> Color:
	_ensure_loaded()
	return _palette[0] if not _palette.is_empty() else Color.BLACK

static func _ensure_loaded() -> void:
	if _cont_raw.is_empty():
		_cont_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Continue Screen Sonic.nem"))
	if _mini_raw.is_empty():
		_mini_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Continue Screen Stuff.nem"))
	if _title_raw.is_empty():
		_title_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Title Cards.nem"))
	if _palette.is_empty():
		_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes("res://data/s1/palette/Special Stage Continue Bonus.bin"))

static func _draw_piece(image: Image, piece: Array, object_base: int, origin_x: int, origin_y: int) -> void:
	var px0 := int(piece[0]) + origin_x
	var py0 := int(piece[1]) + origin_y
	var wt := int(piece[2])
	var ht := int(piece[3])
	var tile_base := object_base + int(piece[4])
	var flip_x := int(piece[5]) != 0
	var flip_y := int(piece[6]) != 0
	var pal_line := int(piece[7])
	for out_tx in range(wt):
		for out_ty in range(ht):
			var source_tx := wt - 1 - out_tx if flip_x else out_tx
			var source_ty := ht - 1 - out_ty if flip_y else out_ty
			var abs_tile := tile_base + source_tx * ht + source_ty
			for yy in range(8):
				var sy := 7 - yy if flip_y else yy
				for xx in range(8):
					var sx := 7 - xx if flip_x else xx
					var ci := _absolute_tile_pixel(abs_tile, sx, sy)
					if ci == 0:
						continue
					var pi := pal_line * 16 + ci
					var dx := px0 + out_tx * 8 + xx
					var dy := py0 + out_ty * 8 + yy
					if pi >= 0 and pi < _palette.size() and dx >= 0 and dy >= 0 and dx < image.get_width() and dy < image.get_height():
						image.set_pixel(dx, dy, _palette[pi])

static func _absolute_tile_pixel(abs_tile: int, x: int, y: int) -> int:
	var raw := _cont_raw
	var index := abs_tile - CONT_BASE
	if abs_tile >= TITLE_BASE:
		raw = _title_raw
		index = abs_tile - TITLE_BASE
	elif abs_tile >= MINI_BASE:
		raw = _mini_raw
		index = abs_tile - MINI_BASE
	var offset := index * 32 + y * 4 + (x >> 1)
	if offset < 0 or offset >= raw.size():
		return 0
	var value := int(raw[offset])
	return (value >> 4) & 0x0F if (x & 1) == 0 else value & 0x0F
