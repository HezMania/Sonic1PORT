class_name SpecialStageResultArt
extends RefCounted

# Phase 67: source-authored Objects $7E/$7F Special Stage result art.
# Map_SSR deliberately addresses several VRAM regions relative to
# ArtTile_Title_Card ($580): title-card letters, HUD text, Continue graphics,
# dynamically written HUD digits, and the separate result-emerald stream.

const ART_RESULT_EMERALDS = 0x541
const ART_MINI_SONIC = 0x551
const ART_TITLE = 0x580
const ART_HUD = 0x6CA
const ART_HUD_DYNAMIC_E = 0x6E2

const FRAME_CHAOS = 0
const FRAME_SCORE = 1
const FRAME_RING = 2
const FRAME_OVAL = 3
const FRAME_CONT_SONIC_DOWN = 4
const FRAME_CONT_SONIC_UP = 5
const FRAME_CONTINUE = 6
const FRAME_SPECIAL_STAGE = 7
const FRAME_GOT_ALL = 8

# [x, y, width_tiles, height_tiles, mapping_tile_offset, flip_x, flip_y, palette_line]
# The live score/ring number pieces are omitted from frames 1/2 and rendered as
# child digit sprites by SpecialStageResultUI, mirroring Hud_End exactly.
const FRAMES = {
	FRAME_CHAOS: [
		[-0x70,-8,2,2,0x08,0,0,0],[-0x60,-8,2,2,0x1C,0,0,0],[-0x50,-8,2,2,0x00,0,0,0],[-0x40,-8,2,2,0x32,0,0,0],[-0x30,-8,2,2,0x3E,0,0,0],
		[-0x10,-8,2,2,0x10,0,0,0],[0,-8,2,2,0x2A,0,0,0],[0x10,-8,2,2,0x10,0,0,0],[0x20,-8,2,2,0x3A,0,0,0],[0x30,-8,2,2,0x00,0,0,0],[0x40,-8,2,2,0x26,0,0,0],[0x50,-8,2,2,0x0C,0,0,0],[0x60,-8,2,2,0x3E,0,0,0],
	],
	FRAME_SCORE: [
		[-0x50,-8,4,2,0x14A,0,0,0],[-0x30,-8,1,2,0x162,0,0,0],
		[-0x33,-9,2,1,0x6E,0,0,0],[-0x33,-1,2,1,0x6E,1,1,0],
	],
	FRAME_RING: [
		[-0x50,-8,4,2,0x152,0,0,0],[-0x27,-8,4,2,0x66,0,0,0],[-7,-8,1,2,0x14A,0,0,0],
		[-0x0A,-9,2,1,0x6E,0,0,0],[-0x0A,-1,2,1,0x6E,1,1,0],
	],
	FRAME_OVAL: [
		[-0x0C,-0x1C,4,1,0x70,0,0,0],[0x14,-0x1C,1,3,0x74,0,0,0],[-0x14,-0x14,2,1,0x77,0,0,0],[-0x1C,-0x0C,2,2,0x79,0,0,0],
		[-0x14,0x14,4,1,0x70,1,1,0],[-0x1C,4,1,3,0x74,1,1,0],[4,0x0C,2,1,0x77,1,1,0],[0x0C,-4,2,2,0x79,1,1,0],
		[-4,-0x14,3,1,0x7D,0,0,0],[-0x0C,-0x0C,4,1,0x7C,0,0,0],[-0x0C,-4,3,1,0x7C,0,0,0],[-0x14,4,4,1,0x7C,0,0,0],[-0x14,0x0C,3,1,0x7C,0,0,0],
	],
	FRAME_CONT_SONIC_DOWN: [
		[-0x50,-8,4,2,-0x2F,0,0,0],[-0x30,-8,4,2,-0x27,0,0,0],[-0x10,-8,1,2,-0x1F,0,0,0],[0x40,-8,2,3,-0x1D,0,0,1],
	],
	FRAME_CONT_SONIC_UP: [
		[-0x50,-8,4,2,-0x2F,0,0,0],[-0x30,-8,4,2,-0x27,0,0,0],[-0x10,-8,1,2,-0x1F,0,0,0],[0x40,-8,2,3,-0x17,0,0,1],
	],
	FRAME_CONTINUE: [
		[-0x50,-8,4,2,-0x2F,0,0,0],[-0x30,-8,4,2,-0x27,0,0,0],[-0x10,-8,1,2,-0x1F,0,0,0],
	],
	FRAME_SPECIAL_STAGE: [
		[-0x64,-8,2,2,0x3E,0,0,0],[-0x54,-8,2,2,0x36,0,0,0],[-0x44,-8,2,2,0x10,0,0,0],[-0x34,-8,2,2,0x08,0,0,0],[-0x24,-8,1,2,0x20,0,0,0],[-0x1C,-8,2,2,0x00,0,0,0],[-0x0C,-8,2,2,0x26,0,0,0],
		[0x14,-8,2,2,0x3E,0,0,0],[0x24,-8,2,2,0x42,0,0,0],[0x34,-8,2,2,0x00,0,0,0],[0x44,-8,2,2,0x18,0,0,0],[0x54,-8,2,2,0x10,0,0,0],
	],
	FRAME_GOT_ALL: [
		[-0x78,-8,2,2,0x3E,0,0,0],[-0x68,-8,2,2,0x32,0,0,0],[-0x58,-8,2,2,0x2E,0,0,0],[-0x48,-8,1,2,0x20,0,0,0],[-0x40,-8,2,2,0x08,0,0,0],
		[-0x28,-8,2,2,0x18,0,0,0],[-0x18,-8,2,2,0x32,0,0,0],[-8,-8,2,2,0x42,0,0,0],
		[0x10,-8,2,2,0x42,0,0,0],[0x20,-8,2,2,0x1C,0,0,0],[0x30,-8,2,2,0x10,0,0,0],[0x40,-8,2,2,0x2A,0,0,0],
		[0x58,-8,2,2,0x00,0,0,0],[0x68,-8,2,2,0x26,0,0,0],[0x78,-8,2,2,0x26,0,0,0],
	],
}

# Map_SSRC: [tile offset, palette line]
const EMERALD_FRAMES = [[4,1],[0,0],[4,2],[4,3],[8,1],[0x0C,1]]

static var _title_raw = PackedByteArray()
static var _hud_raw = PackedByteArray()
static var _hud_numbers_raw = PackedByteArray()
static var _continue_raw = PackedByteArray()
static var _emerald_raw = PackedByteArray()
static var _palette: Array[Color] = []
static var _frame_cache: Dictionary = {}
static var _digit_cache: Dictionary = {}
static var _emerald_cache: Dictionary = {}

static func texture_for_frame(frame: int) -> Texture2D:
	if _frame_cache.has(frame):
		return _frame_cache[frame]
	_ensure_loaded()
	var image = Image.create_empty(320, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	var pieces: Array = FRAMES.get(frame, [])
	# First Genesis mapping piece wins sprite overlap, so flatten backwards.
	for i in range(pieces.size() - 1, -1, -1):
		_draw_piece(image, pieces[i], ART_TITLE, 160, 32)
	var tex = ImageTexture.create_from_image(image)
	_frame_cache[frame] = tex
	return tex

static func digit_texture(digit: int) -> Texture2D:
	digit = clampi(digit, 0, 9)
	if _digit_cache.has(digit):
		return _digit_cache[digit]
	_ensure_loaded()
	var image = Image.create_empty(8, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for yy in range(16):
		var tile = digit * 2 + (yy >> 3)
		var py = yy & 7
		for xx in range(8):
			var ci = _tile_pixel(_hud_numbers_raw, tile, xx, py)
			if ci != 0:
				image.set_pixel(xx, yy, _palette[ci])
	var tex = ImageTexture.create_from_image(image)
	_digit_cache[digit] = tex
	return tex

static func emerald_texture(frame: int) -> Texture2D:
	frame = clampi(frame, 0, 5)
	if _emerald_cache.has(frame):
		return _emerald_cache[frame]
	_ensure_loaded()
	var spec: Array = EMERALD_FRAMES[frame]
	var image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	var piece = [-8,-8,2,2,int(spec[0]),0,0,int(spec[1])]
	_draw_piece(image, piece, ART_RESULT_EMERALDS, 8, 8)
	var tex = ImageTexture.create_from_image(image)
	_emerald_cache[frame] = tex
	return tex

static func background_color() -> Color:
	_ensure_loaded()
	return _palette[0] if not _palette.is_empty() else Color.WHITE

static func _ensure_loaded() -> void:
	if _title_raw.is_empty():
		_title_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Title Cards.nem"))
	if _hud_raw.is_empty():
		_hud_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/HUD.nem"))
	if _hud_numbers_raw.is_empty():
		_hud_numbers_raw = FileAccess.get_file_as_bytes("res://data/s1/artunc/HUD Numbers.unc")
	if _continue_raw.is_empty():
		_continue_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Continue Screen Stuff.nem"))
	if _emerald_raw.is_empty():
		_emerald_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Special Result Emeralds.nem"))
	if _palette.is_empty():
		_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes("res://data/s1/palette/Special Stage Results.bin"))

static func _draw_piece(image: Image, piece: Array, object_base: int, origin_x: int, origin_y: int) -> void:
	var px0 = int(piece[0]) + origin_x
	var py0 = int(piece[1]) + origin_y
	var wt = int(piece[2])
	var ht = int(piece[3])
	var tile_base = object_base + int(piece[4])
	var flip_x = int(piece[5]) != 0
	var flip_y = int(piece[6]) != 0
	var pal_line = int(piece[7])
	for out_tx in range(wt):
		for out_ty in range(ht):
			var source_tx = wt - 1 - out_tx if flip_x else out_tx
			var source_ty = ht - 1 - out_ty if flip_y else out_ty
			var abs_tile = tile_base + source_tx * ht + source_ty
			for yy in range(8):
				var sy = 7 - yy if flip_y else yy
				for xx in range(8):
					var sx = 7 - xx if flip_x else xx
					var ci = _absolute_tile_pixel(abs_tile, sx, sy)
					if ci == 0:
						continue
					var pi = pal_line * 16 + ci
					var dx = px0 + out_tx * 8 + xx
					var dy = py0 + out_ty * 8 + yy
					if pi >= 0 and pi < _palette.size() and dx >= 0 and dy >= 0 and dx < image.get_width() and dy < image.get_height():
						image.set_pixel(dx, dy, _palette[pi])

static func _absolute_tile_pixel(abs_tile: int, x: int, y: int) -> int:
	var raw = PackedByteArray()
	var index = -1
	if abs_tile >= ART_HUD and abs_tile < ART_HUD + (_hud_raw.size() >> 5):
		raw = _hud_raw
		index = abs_tile - ART_HUD
	elif abs_tile >= ART_HUD_DYNAMIC_E and abs_tile < ART_HUD_DYNAMIC_E + 2:
		raw = _hud_numbers_raw
		index = 0x16 + abs_tile - ART_HUD_DYNAMIC_E
	elif abs_tile >= ART_TITLE and abs_tile < ART_TITLE + (_title_raw.size() >> 5):
		raw = _title_raw
		index = abs_tile - ART_TITLE
	elif abs_tile >= ART_MINI_SONIC and abs_tile < ART_MINI_SONIC + (_continue_raw.size() >> 5):
		raw = _continue_raw
		index = abs_tile - ART_MINI_SONIC
	elif abs_tile >= ART_RESULT_EMERALDS and abs_tile < ART_RESULT_EMERALDS + (_emerald_raw.size() >> 5):
		raw = _emerald_raw
		index = abs_tile - ART_RESULT_EMERALDS
	if index < 0:
		return 0
	return _tile_pixel(raw, index, x, y)

static func _tile_pixel(raw: PackedByteArray, tile_index: int, x: int, y: int) -> int:
	var offset = tile_index * 32 + y * 4 + (x >> 1)
	if offset < 0 or offset >= raw.size():
		return 0
	var value = int(raw[offset])
	return (value >> 4) & 0x0F if (x & 1) == 0 else value & 0x0F
