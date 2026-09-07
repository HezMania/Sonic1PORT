class_name LevelTitleCardArt
extends RefCounted

# Phase 58: source-authored Object $34 title-card art.  These pieces are a
# direct transcription of _maps/Title Cards.asm and use the original
# Nemesis-compressed Title Cards.nem with the Sonic palette line loaded by
# GM_Level while the cards are visible.

const FRAME_GHZ := 0
const FRAME_LZ := 1
const FRAME_MZ := 2
const FRAME_SLZ := 3
const FRAME_SYZ := 4
const FRAME_SBZ := 5
const FRAME_ZONE := 6
const FRAME_ACT1 := 7
const FRAME_ACT2 := 8
const FRAME_ACT3 := 9
const FRAME_OVAL := 10
const FRAME_FZ := 11

# [x, y, width_tiles, height_tiles, tile, flip_x, flip_y]
const FRAMES := {
	FRAME_GHZ: [
		[-0x4C,-8,2,2,0x18,0,0],[-0x3C,-8,2,2,0x3A,0,0],[-0x2C,-8,2,2,0x10,0,0],[-0x1C,-8,2,2,0x10,0,0],[-0x0C,-8,2,2,0x2E,0,0],
		[0x14,-8,2,2,0x1C,0,0],[0x24,-8,1,2,0x20,0,0],[0x2C,-8,2,2,0x26,0,0],[0x3C,-8,2,2,0x26,0,0],
	],
	FRAME_LZ: [
		[-0x44,-8,2,2,0x26,0,0],[-0x34,-8,2,2,0x00,0,0],[-0x24,-8,2,2,0x04,0,0],[-0x14,-8,2,2,0x4A,0,0],[-4,-8,2,2,0x3A,0,0],
		[0x0C,-8,1,2,0x20,0,0],[0x14,-8,2,2,0x2E,0,0],[0x24,-8,2,2,0x42,0,0],[0x34,-8,2,2,0x1C,0,0],
	],
	FRAME_MZ: [
		[-0x31,-8,2,2,0x2A,0,0],[-0x20,-8,2,2,0x00,0,0],[-0x10,-8,2,2,0x3A,0,0],[0,-8,2,2,0x04,0,0],[0x10,-8,2,2,0x26,0,0],[0x20,-8,2,2,0x10,0,0],
	],
	FRAME_SLZ: [
		[-0x4C,-8,2,2,0x3E,0,0],[-0x3C,-8,2,2,0x42,0,0],[-0x2C,-8,2,2,0x00,0,0],[-0x1C,-8,2,2,0x3A,0,0],
		[4,-8,2,2,0x26,0,0],[0x14,-8,1,2,0x20,0,0],[0x1C,-8,2,2,0x18,0,0],[0x2C,-8,2,2,0x1C,0,0],[0x3C,-8,2,2,0x42,0,0],
	],
	FRAME_SYZ: [
		[-0x54,-8,2,2,0x3E,0,0],[-0x44,-8,2,2,0x36,0,0],[-0x34,-8,2,2,0x3A,0,0],[-0x24,-8,1,2,0x20,0,0],[-0x1C,-8,2,2,0x2E,0,0],[-0x0C,-8,2,2,0x18,0,0],
		[0x14,-8,2,2,0x4A,0,0],[0x24,-8,2,2,0x00,0,0],[0x34,-8,2,2,0x3A,0,0],[0x44,-8,2,2,0x0C,0,0],
	],
	FRAME_SBZ: [
		[-0x54,-8,2,2,0x3E,0,0],[-0x44,-8,2,2,0x08,0,0],[-0x34,-8,2,2,0x3A,0,0],[-0x24,-8,2,2,0x00,0,0],[-0x14,-8,2,2,0x36,0,0],
		[0x0C,-8,2,2,0x04,0,0],[0x1C,-8,2,2,0x3A,0,0],[0x2C,-8,2,2,0x00,0,0],[0x3C,-8,1,2,0x20,0,0],[0x44,-8,2,2,0x2E,0,0],
	],
	FRAME_ZONE: [[-0x20,-8,2,2,0x4E,0,0],[-0x10,-8,2,2,0x32,0,0],[0,-8,2,2,0x2E,0,0],[0x10,-8,2,2,0x10,0,0]],
	FRAME_ACT1: [[-0x14,4,4,1,0x53,0,0],[0x0C,-0x0C,1,3,0x57,0,0]],
	FRAME_ACT2: [[-0x14,4,4,1,0x53,0,0],[8,-0x0C,2,3,0x5A,0,0]],
	FRAME_ACT3: [[-0x14,4,4,1,0x53,0,0],[8,-0x0C,2,3,0x60,0,0]],
	FRAME_OVAL: [
		[-0x0C,-0x1C,4,1,0x70,0,0],[0x14,-0x1C,1,3,0x74,0,0],[-0x14,-0x14,2,1,0x77,0,0],[-0x1C,-0x0C,2,2,0x79,0,0],
		[-0x14,0x14,4,1,0x70,1,1],[-0x1C,4,1,3,0x74,1,1],[4,0x0C,2,1,0x77,1,1],[0x0C,-4,2,2,0x79,1,1],
		[-4,-0x14,3,1,0x7D,0,0],[-0x0C,-0x0C,4,1,0x7C,0,0],[-0x0C,-4,3,1,0x7C,0,0],[-0x14,4,4,1,0x7C,0,0],[-0x14,0x0C,3,1,0x7C,0,0],
	],
	FRAME_FZ: [[-0x24,-8,2,2,0x14,0,0],[-0x14,-8,1,2,0x20,0,0],[-0x0C,-8,2,2,0x2E,0,0],[4,-8,2,2,0x00,0,0],[0x14,-8,2,2,0x26,0,0]],
}

static var _raw := PackedByteArray()
static var _palette: Array[Color] = []
static var _cache: Dictionary = {}

static func texture_for_frame(frame: int) -> Texture2D:
	if _cache.has(frame):
		return _cache[frame]
	_ensure_loaded()
	var image := Image.create_empty(256, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for piece in FRAMES.get(frame, []):
		_draw_piece(image, piece, 128, 32)
	var tex := ImageTexture.create_from_image(image)
	_cache[frame] = tex
	return tex

static func _ensure_loaded() -> void:
	if _raw.is_empty():
		_raw = Nemesis.decompress(FileAccess.get_file_as_bytes("res://data/s1/artnem/Title Cards.nem"))
	if _palette.is_empty():
		_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes("res://data/s1/palette/Sonic.bin"))

static func _draw_piece(image: Image, piece: Array, origin_x: int, origin_y: int) -> void:
	var px0 := int(piece[0]) + origin_x
	var py0 := int(piece[1]) + origin_y
	var wt := int(piece[2])
	var ht := int(piece[3])
	var tile_base := int(piece[4])
	var flip_x := int(piece[5]) != 0
	var flip_y := int(piece[6]) != 0
	for out_tx in range(wt):
		for out_ty in range(ht):
			var source_tx := wt - 1 - out_tx if flip_x else out_tx
			var source_ty := ht - 1 - out_ty if flip_y else out_ty
			var tile := tile_base + source_tx * ht + source_ty
			for yy in range(8):
				var sy := 7 - yy if flip_y else yy
				for xx in range(8):
					var sx := 7 - xx if flip_x else xx
					var ci := _tile_pixel(tile, sx, sy)
					if ci == 0 or ci >= _palette.size():
						continue
					var dx := px0 + out_tx * 8 + xx
					var dy := py0 + out_ty * 8 + yy
					if dx >= 0 and dy >= 0 and dx < image.get_width() and dy < image.get_height():
						image.set_pixel(dx, dy, _palette[ci])

static func _tile_pixel(tile: int, x: int, y: int) -> int:
	var offset := tile * 32 + y * 4 + (x >> 1)
	if offset < 0 or offset >= _raw.size():
		return 0
	var value := int(_raw[offset])
	return (value >> 4) & 0x0F if (x & 1) == 0 else value & 0x0F
