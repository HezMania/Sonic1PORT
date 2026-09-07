class_name EndCardArt
extends RefCounted

# Phase 60: source-authored Object $3A results-card graphics.  The card is
# unusual because its mappings intentionally span three Genesis VRAM regions:
# Title Cards.nem at $580, HUD.nem at $6CA, and dynamically-written HUD number
# glyphs.  Reconstruct those sources directly instead of using Godot fonts.

const FRAME_SONIC_HAS := 0
const FRAME_PASSED := 1
const FRAME_SCORE := 2
const FRAME_TIME_BONUS := 3
const FRAME_RING_BONUS := 4

const ART_TITLE_BASE := 0x580
const ART_HUD_BASE := 0x6CA
const ART_HUD_DYNAMIC_E := 0x6E2

# [x, y, width_tiles, height_tiles, mapping_tile_offset, flip_x, flip_y]
# Dynamic score/bonus digit pieces are omitted here and are attached as child
# sprites by EndCardUI so they can update while the tally runs.
const FRAMES := {
	FRAME_SONIC_HAS: [
		[-0x48,-8,2,2,0x3E,0,0],[-0x38,-8,2,2,0x32,0,0],[-0x28,-8,2,2,0x2E,0,0],[-0x18,-8,1,2,0x20,0,0],[-0x10,-8,2,2,0x08,0,0],
		[0x10,-8,2,2,0x1C,0,0],[0x20,-8,2,2,0x00,0,0],[0x30,-8,2,2,0x3E,0,0],
	],
	FRAME_PASSED: [
		[-0x30,-8,2,2,0x36,0,0],[-0x20,-8,2,2,0x00,0,0],[-0x10,-8,2,2,0x3E,0,0],[0,-8,2,2,0x3E,0,0],[0x10,-8,2,2,0x10,0,0],[0x20,-8,2,2,0x0C,0,0],
	],
	FRAME_SCORE: [
		[-0x50,-8,4,2,0x14A,0,0],[-0x30,-8,1,2,0x162,0,0],
		[-0x33,-9,2,1,0x6E,0,0],[-0x33,-1,2,1,0x6E,1,1],
	],
	FRAME_TIME_BONUS: [
		[-0x50,-8,4,2,0x15A,0,0],[-0x27,-8,4,2,0x66,0,0],[-7,-8,1,2,0x14A,0,0],
		[-0x0A,-9,2,1,0x6E,0,0],[-0x0A,-1,2,1,0x6E,1,1],
	],
	FRAME_RING_BONUS: [
		[-0x50,-8,4,2,0x152,0,0],[-0x27,-8,4,2,0x66,0,0],[-7,-8,1,2,0x14A,0,0],
		[-0x0A,-9,2,1,0x6E,0,0],[-0x0A,-1,2,1,0x6E,1,1],
	],
}

static var _title_raw = PackedByteArray()
static var _hud_raw = PackedByteArray()
static var _hud_numbers_raw = PackedByteArray()
static var _palette: Array[Color] = []
static var _frame_cache: Dictionary = {}
static var _digit_cache: Dictionary = {}

static func texture_for_frame(frame: int) -> Texture2D:
	if _frame_cache.has(frame):
		return _frame_cache[frame]
	_ensure_loaded()
	var image = Image.create_empty(256, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var pieces: Array = FRAMES.get(frame, [])
	# Earlier sprite pieces have overlap priority in the Genesis SAT.  Because
	# these pieces are flattened into one texture, draw the mapping backwards so
	# the first source piece is composited last and therefore remains on top.
	for i in range(pieces.size() - 1, -1, -1):
		_draw_piece(image, pieces[i], 128, 32)
	var tex = ImageTexture.create_from_image(image)
	_frame_cache[frame] = tex
	return tex

static func digit_texture(digit: int) -> Texture2D:
	digit = clampi(digit, 0, 9)
	if _digit_cache.has(digit):
		return _digit_cache[digit]
	_ensure_loaded()
	var image = Image.create_empty(8, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for yy in range(16):
		var tile = digit * 2 + (yy >> 3)
		var py = yy & 7
		for xx in range(8):
			var ci = _tile_pixel(_hud_numbers_raw, tile, xx, py)
			if ci != 0 and ci < _palette.size():
				image.set_pixel(xx, yy, _palette[ci])
	var tex = ImageTexture.create_from_image(image)
	_digit_cache[digit] = tex
	return tex

static func _ensure_loaded() -> void:
	if _title_raw.is_empty():
		_title_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Title Cards.nem"))
	if _hud_raw.is_empty():
		_hud_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/HUD.nem"))
	if _hud_numbers_raw.is_empty():
		_hud_numbers_raw = FileAccess.get_file_as_bytes("res://data/s1/artunc/HUD Numbers.unc")
	if _palette.is_empty():
		_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes("res://data/s1/palette/Sonic.bin"))

static func _draw_piece(image: Image, piece: Array, origin_x: int, origin_y: int) -> void:
	var px0 = int(piece[0]) + origin_x
	var py0 = int(piece[1]) + origin_y
	var wt = int(piece[2])
	var ht = int(piece[3])
	var mapping_tile = int(piece[4])
	var flip_x = int(piece[5]) != 0
	var flip_y = int(piece[6]) != 0
	for out_tx in range(wt):
		for out_ty in range(ht):
			var source_tx = wt - 1 - out_tx if flip_x else out_tx
			var source_ty = ht - 1 - out_ty if flip_y else out_ty
			# Mega Drive multi-tile sprites advance vertically first.
			var absolute_tile = ART_TITLE_BASE + mapping_tile + source_tx * ht + source_ty
			for yy in range(8):
				var sy = 7 - yy if flip_y else yy
				for xx in range(8):
					var sx = 7 - xx if flip_x else xx
					var ci = _vram_tile_pixel(absolute_tile, sx, sy)
					if ci == 0 or ci >= _palette.size():
						continue
					var dx = px0 + out_tx * 8 + xx
					var dy = py0 + out_ty * 8 + yy
					if dx >= 0 and dy >= 0 and dx < image.get_width() and dy < image.get_height():
						image.set_pixel(dx, dy, _palette[ci])

static func _vram_tile_pixel(absolute_tile: int, x: int, y: int) -> int:
	if absolute_tile >= ART_TITLE_BASE and absolute_tile < ART_TITLE_BASE + (_title_raw.size() >> 5):
		return _tile_pixel(_title_raw, absolute_tile - ART_TITLE_BASE, x, y)
	if absolute_tile >= ART_HUD_BASE and absolute_tile < ART_HUD_BASE + (_hud_raw.size() >> 5):
		return _tile_pixel(_hud_raw, absolute_tile - ART_HUD_BASE, x, y)
	# Hud_Base writes the letter E from Art_Hud tiles $16/$17 to $6E2/$6E3.
	if absolute_tile >= ART_HUD_DYNAMIC_E and absolute_tile < ART_HUD_DYNAMIC_E + 2:
		return _tile_pixel(_hud_numbers_raw, 0x16 + absolute_tile - ART_HUD_DYNAMIC_E, x, y)
	return 0

static func _tile_pixel(raw: PackedByteArray, tile_index: int, x: int, y: int) -> int:
	var offset = tile_index * 32 + y * 4 + (x >> 1)
	if offset < 0 or offset >= raw.size():
		return 0
	var value = int(raw[offset])
	return (value >> 4) & 0x0F if (x & 1) == 0 else value & 0x0F
