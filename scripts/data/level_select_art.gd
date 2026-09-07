class_name LevelSelectArt
extends RefCounted

# Source-faithful renderer for GM_Title's hidden level-select screen.
# The 41-tile font is the original uncompressed Art_Text stream and the menu
# strings mirror REV01 LevelMenuText (21 rows x 24 characters).

const WIDTH := 320
const HEIGHT := 224
const START_X := 8 * 8
const START_Y := 4 * 8
const LINE_CHARS := 24
const LINE_COUNT := 21
const SOUND_ROW := 20
const SOUND_COL := 16

const MENU_LINES: Array[String] = [
	"GREEN HILL ZONE  STAGE 1",
	"                 STAGE 2",
	"                 STAGE 3",
	"MARBLE ZONE      STAGE 1",
	"                 STAGE 2",
	"                 STAGE 3",
	"SPRING YARD ZONE STAGE 1",
	"                 STAGE 2",
	"                 STAGE 3",
	"LABYRINTH ZONE   STAGE 1",
	"                 STAGE 2",
	"                 STAGE 3",
	"STAR LIGHT ZONE  STAGE 1",
	"                 STAGE 2",
	"                 STAGE 3",
	"SCRAP BRAIN ZONE STAGE 1",
	"                 STAGE 2",
	"                 STAGE 3",
	"FINAL ZONE              ",
	"SPECIAL STAGE           ",
	"SOUND SELECT            ",
]

static var _font := PackedByteArray()
static var _palette: Array[Color] = []
static var _cache: Dictionary = {}

static func texture(selected_row: int, sound_number: int) -> Texture2D:
	selected_row = clampi(selected_row, 0, LINE_COUNT - 1)
	sound_number &= 0xFF
	var key := "%02d:%02X" % [selected_row, sound_number]
	if _cache.has(key):
		return _cache[key]
	_ensure_source()
	if _font.is_empty() or _palette.size() < 64:
		return null
	var image := Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(_palette[0])
	for row in range(LINE_COUNT):
		var palette_line := 2 if row == selected_row else 3 # Tile_Pal3 yellow / Tile_Pal4 white
		var line := MENU_LINES[row]
		for col in range(LINE_CHARS):
			_draw_char(image, line[col], START_X + col * 8, START_Y + row * 8, palette_line)
	var sound_palette_line := 2 if selected_row == SOUND_ROW else 3
	_draw_hex_digit(image, (sound_number >> 4) & 0xF, START_X + SOUND_COL * 8, START_Y + SOUND_ROW * 8, sound_palette_line)
	_draw_hex_digit(image, sound_number & 0xF, START_X + (SOUND_COL + 1) * 8, START_Y + SOUND_ROW * 8, sound_palette_line)
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex

static func background_color() -> Color:
	_ensure_source()
	return _palette[0] if not _palette.is_empty() else Color.BLACK

static func _ensure_source() -> void:
	if _font.is_empty():
		var path := "res://data/s1/artunc/Level Select & Debug Text.unc"
		if FileAccess.file_exists(path):
			_font = FileAccess.get_file_as_bytes(path)
	if _palette.is_empty():
		var path := "res://data/s1/palette/Level Select.bin"
		if FileAccess.file_exists(path):
			_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(path))

static func _draw_char(image: Image, character: String, x: int, y: int, palette_line: int) -> void:
	var code := _tile_for_char(character)
	if code < 0:
		return
	_draw_tile(image, code, x, y, palette_line)

static func _draw_hex_digit(image: Image, digit: int, x: int, y: int, palette_line: int) -> void:
	digit &= 0xF
	var tile := digit if digit < 10 else digit + 7 # A-F begin at Art_Text tile $11
	_draw_tile(image, tile, x, y, palette_line)

static func _tile_for_char(character: String) -> int:
	if character == " ":
		return -1
	var code := character.unicode_at(0)
	if code >= 48 and code <= 57:
		return code - 48
	match character:
		"$": return 0x0A
		"-": return 0x0B
		"=": return 0x0C
		">": return 0x0D
		"Y": return 0x0F
		"Z": return 0x10
	if code >= 65 and code <= 88: # A-X
		return 0x11 + code - 65
	return -1

static func _draw_tile(image: Image, tile_index: int, target_x: int, target_y: int, palette_line: int) -> void:
	var base := tile_index * 32
	if base < 0 or base + 32 > _font.size():
		return
	for py in range(8):
		for px in range(8):
			var byte := int(_font[base + py * 4 + (px >> 1)])
			var color_index := ((byte >> 4) & 0xF) if (px & 1) == 0 else (byte & 0xF)
			if color_index == 0:
				continue
			var palette_index := palette_line * 16 + color_index
			if palette_index >= 0 and palette_index < _palette.size():
				image.set_pixel(target_x + px, target_y + py, _palette[palette_index])
