class_name GHZLevelData
extends RefCounted

# The class keeps its original Phase-1 name for source compatibility, but Phase
# 11 makes it a generic Sonic 1 level-data container driven by LevelCatalog.

const TILE_BYTES := 32
const MAX_LEVEL_TILES := 0x800
const CHUNK_BYTES := 512 # Sonic 1 256x256 compatibility constant
const S2_CHUNK_BYTES := 128
const BLOCK_BYTES := 8

# Phase 56: Sonic 2-style logical collision paths. These are not Godot
# physics layers; every Genesis terrain sensor selects one of these paths.
const COLLISION_PATH_PRIMARY := 0
const COLLISION_PATH_SECONDARY := 1

var definition: Dictionary = {}
var zone_id := LevelCatalog.ZONE_GHZ
var act := 1
var zone_code := "GHZ"
var zone_name := "GREEN HILL ZONE"

var art := PackedByteArray()
var blocks := PackedByteArray()
var chunks := PackedByteArray()
var layout := PackedByteArray()
var layout_width: int = 0
var layout_height: int = 0
var background_layout := PackedByteArray()
var background_width := 0
var background_height := 0

var collision_index_primary := PackedByteArray()
var collision_index_secondary := PackedByteArray()
# Compatibility alias for older object/debug code that only needs the source
# Sonic 1 collision-index table.
var collision_index := PackedByteArray()
var collision_normal := PackedByteArray()
var collision_rotated := PackedByteArray()
var angle_map := PackedByteArray()

var palette: Array[Color] = []
var start_position := Vector2i.ZERO

func load_from(root_path: String = "res://data/s1", requested_zone: int = 0, requested_act: int = 1) -> bool:
	return load_definition(root_path, LevelCatalog.get_level(requested_zone, requested_act))

func load_definition(root_path: String, level_definition: Dictionary) -> bool:
	definition = level_definition.duplicate(true)
	zone_id = int(definition.get("zone", 0))
	act = int(definition.get("act", 1))
	zone_code = String(definition.get("zone_code", "GHZ"))
	zone_name = String(definition.get("zone_name", "GREEN HILL ZONE"))

	art.resize(MAX_LEVEL_TILES * TILE_BYTES)
	art.fill(0)
	for entry in definition.get("art_loads", []):
		var path = root_path.path_join(String(entry.get("path", "")))
		var source = _read(path)
		var compression = String(entry.get("compression", "nemesis"))
		if compression == "nemesis":
			source = Nemesis.decompress(source)
		var source_offset = int(entry.get("source_offset", 0))
		var count = int(entry.get("bytes", source.size() - source_offset))
		var destination = int(entry.get("tile", 0)) * TILE_BYTES
		_copy_range_into(art, source, source_offset, count, destination)

	var map16_source = _read(root_path.path_join(String(definition["map16"])))
	blocks = map16_source if String(definition.get("map16_compression", "enigma")) == "raw" else Enigma.decompress(map16_source, 0)
	# Phase 77: `chunk_map` is the generic terrain mapping key. Existing Sonic 1
	# definitions continue to fall back to `map256`; native Sonic 2 test levels
	# point it at their decoded 128x128 mapping bank.
	var chunk_map_path = String(definition.get("chunk_map", definition.get("map256", "")))
	var chunk_compression = String(definition.get("chunk_map_compression", definition.get("map256_compression", "kosinski")))
	var chunk_source = _read(root_path.path_join(chunk_map_path))
	chunks = chunk_source if chunk_compression == "raw" else Kosinski.decompress(chunk_source)
	if blocks.is_empty() or chunks.is_empty():
		push_error("%s mappings failed to decode" % display_name())
		return false

	if not _load_layout_file(root_path.path_join(String(definition["layout"])), false):
		return false
	var bg_path = String(definition.get("background_layout", ""))
	if not bg_path.is_empty():
		_load_layout_file(root_path.path_join(bg_path), true)
	else:
		background_layout = PackedByteArray()
		background_width = 0
		background_height = 0

	collision_index_primary = _read(root_path.path_join(String(definition["collision"])))
	# Sonic 1 has one collision-index table; Sonic 2 formalizes independent
	# primary/secondary indices. Phase 64 lets a converted S2 level provide the
	# second table without changing the accepted Sonic 1 dual-path behavior.
	var secondary_collision_path = String(definition.get("collision_secondary", ""))
	collision_index_secondary = _read(root_path.path_join(secondary_collision_path)) if not secondary_collision_path.is_empty() else collision_index_primary.duplicate()
	collision_index = collision_index_primary
	var normal_path = String(definition.get("collision_normal", "collide/Collision Array (Normal).bin"))
	var rotated_path = String(definition.get("collision_rotated", "collide/Collision Array (Rotated).bin"))
	var angle_path = String(definition.get("angle_map", "collide/Angle Map.bin"))
	collision_normal = _read(root_path.path_join(normal_path))
	collision_rotated = _read(root_path.path_join(rotated_path))
	angle_map = _read(root_path.path_join(angle_path))
	var line0_palette_path = String(definition.get("palette_line0", "palette/Sonic.bin"))
	palette = GenesisPalette.load_sonic_and_zone(root_path, String(definition["palette"]), line0_palette_path)

	var start_data = _read(root_path.path_join(String(definition["start"])))
	if start_data.size() >= 4:
		start_position = Vector2i(_be16(start_data, 0), _be16(start_data, 2))
	else:
		push_error("Missing start position for %s" % display_name())
		return false

	return not collision_index_primary.is_empty() and palette.size() >= 64

func _load_layout_file(path: String, background: bool) -> bool:
	var packed_layout = _read(path)
	if packed_layout.size() < 2:
		push_error("Level layout is missing or truncated: %s" % path)
		return false
	var width = int(packed_layout[0]) + 1
	var height = int(packed_layout[1]) + 1
	var count = width * height
	if packed_layout.size() < count + 2:
		# Sonic 1's Ending layout is a deliberate ROM adjacency quirk: the
		# source file contains only two of its three declared 15-chunk rows.
		# The original loader overreads 15 adjacent zero bytes for row 3. Keep
		# the retained source file exact and reproduce that zero-filled row here.
		if not background and bool(definition.get("layout_zero_fill_to_header", false)):
			while packed_layout.size() < count + 2:
				packed_layout.append(0)
		else:
			push_error("Layout data is shorter than its header declares: %s" % path)
			return false
	if background:
		background_width = width
		background_height = height
		background_layout = packed_layout.slice(2, 2 + count)
	else:
		layout_width = width
		layout_height = height
		layout = packed_layout.slice(2, 2 + count)
	return true



func chunk_pixel_size() -> int:
	return int(definition.get("chunk_pixel_size", 256))

func chunk_shift() -> int:
	return 7 if chunk_pixel_size() == 128 else 8

func chunk_mask() -> int:
	return chunk_pixel_size() - 1

func blocks_per_chunk() -> int:
	return chunk_pixel_size() >> 4

func chunk_record_bytes() -> int:
	var blocks = blocks_per_chunk()
	return blocks * blocks * 2

func chunk_data_offset(chunk_id: int) -> int:
	# S1 Map256 banks omit the layout's zero/blank chunk, so ID 1 starts at
	# offset 0. Sonic 2 Map128 banks contain a real all-zero chunk 0, so native
	# S2 storage indexes directly by the layout byte.
	if bool(definition.get("chunk_storage_includes_zero", false)):
		return chunk_id * chunk_record_bytes()
	return (chunk_id - 1) * chunk_record_bytes()

func world_width_pixels() -> int:
	return layout_width * chunk_pixel_size()

func world_height_pixels() -> int:
	return layout_height * chunk_pixel_size()

func vertical_wrap_enabled() -> bool:
	# Sonic 1 marks vertical-wrapping levels with the exact LevelSizeArray
	# pair top=-$100, bottom=$800 (LZ3 and later SBZ2).
	return int(definition.get("limit_top", 0)) == -0x100 and int(definition.get("limit_bottom", 0)) == 0x800

func display_name() -> String:
	return String(definition.get("display_name", "%s ACT %d" % [zone_name, act]))

func get_chunk_id_at(chunk_x: int, chunk_y: int) -> int:
	if chunk_x < 0 or chunk_y < 0 or chunk_x >= layout_width or chunk_y >= layout_height:
		return 0
	return int(layout[chunk_y * layout_width + chunk_x])

func set_chunk_id_at(chunk_x: int, chunk_y: int, chunk_id: int) -> bool:
	if chunk_x < 0 or chunk_y < 0 or chunk_x >= layout_width or chunk_y >= layout_height:
		return false
	var index = chunk_y * layout_width + chunk_x
	var value = chunk_id & 0xFF
	if int(layout[index]) == value:
		return false
	layout[index] = value
	return true

func get_background_chunk_id_at(chunk_x: int, chunk_y: int) -> int:
	if chunk_x < 0 or chunk_y < 0 or chunk_x >= background_width or chunk_y >= background_height:
		return 0
	return int(background_layout[chunk_y * background_width + chunk_x])

func set_background_chunk_id_at(chunk_x: int, chunk_y: int, chunk_id: int) -> bool:
	if chunk_x < 0 or chunk_y < 0 or chunk_x >= background_width or chunk_y >= background_height:
		return false
	var index: int = chunk_y * background_width + chunk_x
	var value: int = chunk_id & 0xFF
	if int(background_layout[index]) == value:
		return false
	background_layout[index] = value
	return true

# Sonic 1 stores a special routing flag in layout bit 7, so its physical chunk
# number is seven bits. The experimental Sonic 2 imports use the layout byte as
# an ordinary 0..255 chunk ID. Keep that distinction at the data boundary so
# no Sonic 1 loop/special-chunk behavior changes.
func decode_layout_chunk_id(raw_chunk_id: int) -> int:
	if String(definition.get("chunk_word_format", "s1")) == "s2":
		return raw_chunk_id & 0xFF
	return raw_chunk_id & 0x7F

func layout_chunk_has_special_flag(raw_chunk_id: int) -> bool:
	if String(definition.get("chunk_word_format", "s1")) == "s2":
		return false
	return (raw_chunk_id & 0x80) != 0

func get_chunk_word_at_world(world_x: int, world_y: int, collision_path = COLLISION_PATH_PRIMARY) -> int:
	if world_x < 0:
		return 0
	# FindNearestTile derives its layout row with (Y >> 1) & $380, which is
	# exactly an 8-row/$800px wrap. Apply that only to levels whose source
	# LevelSizeArray explicitly enables vertical wrapping.
	if vertical_wrap_enabled():
		world_y = posmod(world_y, 0x800)
	elif world_y < 0:
		return 0
	var shift = chunk_shift()
	var chunk_x = world_x >> shift
	var chunk_y = world_y >> shift
	var raw_chunk_id = get_chunk_id_at(chunk_x, chunk_y)
	if raw_chunk_id == 0:
		return 0

	var path = COLLISION_PATH_SECONDARY if int(collision_path) != 0 else COLLISION_PATH_PRIMARY
	var has_special_flag = layout_chunk_has_special_flag(raw_chunk_id)
	var chunk_id = decode_layout_chunk_id(raw_chunk_id)

	# Phase 56 dual-path loop geometry. Sonic 1's Map256 data already contains
	# complementary versions of its loop chunks; the old Phase-55 loop flag
	# changed state but never selected these actual alternate surfaces. Route the
	# secondary path to the paired source chunks while preserving the ordinary
	# primary path exactly.
	if path == COLLISION_PATH_SECONDARY:
		match zone_id:
			LevelCatalog.ZONE_GHZ:
				if raw_chunk_id == 0xB5:
					chunk_id = 0x36
			LevelCatalog.ZONE_SLZ:
				if raw_chunk_id == 0xAA:
					chunk_id = 0x2B
				elif raw_chunk_id == 0xB4:
					chunk_id = 0x35

		# Retain Sonic 1 FindNearestTile's source special-chunk alternate. This
		# is zone-agnostic in the 68000 routine and now naturally belongs to the
		# secondary logical collision path.
		if has_special_flag and chunk_id == 0x28:
			chunk_id = 0x51

	if chunk_id <= 0:
		return 0
	var blocks = blocks_per_chunk()
	var block_x = (world_x & chunk_mask()) >> 4
	var block_y = (world_y & chunk_mask()) >> 4
	var byte_offset = chunk_data_offset(chunk_id) + (block_y * blocks + block_x) * 2
	if byte_offset < 0 or byte_offset + 1 >= chunks.size():
		return 0
	return normalize_chunk_word(_be16(chunks, byte_offset), path)

# Sonic 2 128x128 chunk words use bits 10/11 for X/Y flip and carry two
# solidity pairs: C/D for the primary path and E/F for the secondary path.
# The established Sonic1PC collision engine consumes the Sonic 1-style
# normalized word (X=$0800, Y=$1000, top=$2000, all=$4000), so translate only
# at the query/render boundary while retaining the exact S2 words in data.
func normalize_chunk_word(word: int, collision_path = COLLISION_PATH_PRIMARY) -> int:
	if String(definition.get("chunk_word_format", "s1")) != "s2":
		return word
	var normalized = word & 0x03FF
	if (word & 0x0400) != 0:
		normalized |= 0x0800
	if (word & 0x0800) != 0:
		normalized |= 0x1000
	var secondary = int(collision_path) != COLLISION_PATH_PRIMARY
	var top_mask = 0x4000 if secondary else 0x1000
	var all_mask = 0x8000 if secondary else 0x2000
	if (word & top_mask) != 0:
		normalized |= 0x2000
	if (word & all_mask) != 0:
		normalized |= 0x4000
	return normalized

func get_block_tile_word(block_id: int, tile_slot: int) -> int:
	var offset = block_id * BLOCK_BYTES + tile_slot * 2
	if offset < 0 or offset + 1 >= blocks.size():
		return 0
	return _be16(blocks, offset)

func get_tile_pixel(tile_index: int, x: int, y: int) -> int:
	var offset = tile_index * TILE_BYTES + y * 4 + (x >> 1)
	if offset < 0 or offset >= art.size():
		return 0
	var value = int(art[offset])
	if (x & 1) == 0:
		return (value >> 4) & 0xF
	return value & 0xF

func get_collision_shape_id(block_id: int, collision_path = COLLISION_PATH_PRIMARY) -> int:
	var table = collision_index_secondary if int(collision_path) != 0 else collision_index_primary
	if block_id < 0 or block_id >= table.size():
		return 0
	return int(table[block_id])

func get_angle_for_shape(shape_id: int) -> int:
	if shape_id < 0 or shape_id >= angle_map.size():
		return 0
	return int(angle_map[shape_id])

func get_normal_height(shape_id: int, local_x: int) -> int:
	return _signed_collision_byte(collision_normal, shape_id * 16 + (local_x & 0xF))

func get_rotated_height(shape_id: int, local_y: int) -> int:
	return _signed_collision_byte(collision_rotated, shape_id * 16 + (local_y & 0xF))

func _signed_collision_byte(table: PackedByteArray, index: int) -> int:
	if index < 0 or index >= table.size():
		return 0
	var value = int(table[index])
	return value - 256 if value >= 128 else value

static func _read(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		push_error("Missing Sonic 1 data file: %s" % path)
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)

static func _copy_into(destination: PackedByteArray, source: PackedByteArray, destination_offset: int) -> void:
	var copy_count = mini(source.size(), destination.size() - destination_offset)
	for i in range(maxi(copy_count, 0)):
		destination[destination_offset + i] = source[i]

static func _copy_range_into(destination: PackedByteArray, source: PackedByteArray, source_offset: int, count: int, destination_offset: int) -> void:
	var available = mini(count, source.size() - source_offset)
	available = mini(available, destination.size() - destination_offset)
	for i in range(maxi(available, 0)):
		destination[destination_offset + i] = source[source_offset + i]

static func _be16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])
