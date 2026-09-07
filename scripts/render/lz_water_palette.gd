extends ColorRect

# Native approximation of the Mega Drive LZ HBlank palette swap: everything
# below the current dynamic waterline is remapped from the dry CRAM palette to
# the original LZ underwater CRAM palette. The UI remains on the next CanvasLayer.

var object_manager: Node
var camera: Camera2D
var palette_ready := false
var dry_palette_image: Image
var wet_palette_image: Image
var dry_palette_texture: ImageTexture
var wet_palette_texture: ImageTexture
var configured_zone := -1
var configured_act := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader = load("res://scripts/render/lz_water_palette.gdshader")
	if shader == null:
		push_error("Phase 29: LZ water palette shader is missing.")
		visible = false
		return
	var mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat
	object_manager = get_tree().current_scene.get_node_or_null("ObjectManager")
	camera = get_tree().current_scene.get_node_or_null("Camera2D") as Camera2D
	palette_ready = _load_source_palettes(mat)
	visible = false

func _process(_delta: float) -> void:
	if not palette_ready or object_manager == null or camera == null:
		visible = false
		return
	# Use the level explicitly passed to configure_for_level rather than querying
	# scene globals. CPZ2 can be loaded through direct warp/progression while the
	# scene transition is still settling, which made the palette layer incorrectly
	# hide itself even though ObjectManager water physics were already active.
	if not object_manager.water_enabled:
		visible = false
		return
	# Historical condition was `zone == LevelCatalog.ZONE_S2_CPZ_TEST and act == 2`;
	# keep the same level rule using the configured level identity.
	if configured_zone != LevelCatalog.ZONE_LZ and not (configured_zone == LevelCatalog.ZONE_S2_CPZ_TEST and configured_act == 2) and configured_zone != LevelCatalog.ZONE_S2_ARZ_TEST:
		visible = false
		return
	var water_world_y = _resolve_water_world_y()
	if water_world_y == null:
		visible = false
		return
	var viewport_height = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var screen_top = camera.position.y - viewport_height * 0.5
	var waterline = float(water_world_y) - screen_top
	visible = waterline < viewport_height
	if not visible:
		return
	var mat = material as ShaderMaterial
	mat.set_shader_parameter("viewport_height", viewport_height)
	mat.set_shader_parameter("waterline_px", clampf(waterline, 0.0, viewport_height + 1.0))

func configure_for_level(level_data: GHZLevelData) -> void:
	if material == null or level_data == null:
		palette_ready = false
		configured_zone = -1
		configured_act = -1
		return
	configured_zone = level_data.zone_id
	configured_act = int(level_data.definition.get("act", 1))
	var wet_name := ""
	if level_data.zone_id == LevelCatalog.ZONE_LZ:
		wet_name = "SBZ Act 3 Underwater.bin" if int(level_data.definition.get("act", 1)) == 4 else "Labyrinth Zone Underwater.bin"
	elif level_data.zone_id == LevelCatalog.ZONE_S2_CPZ_TEST and int(level_data.definition.get("act", 1)) == 2:
		wet_name = "S2 Chemical Plant Underwater.bin"
	elif level_data.zone_id == LevelCatalog.ZONE_S2_ARZ_TEST:
		wet_name = "S2 Aquatic Ruin Underwater.bin"
	else:
		palette_ready = false
		visible = false
		return
	var wet_path = "res://data/s1/palette/" + wet_name
	if not FileAccess.file_exists(wet_path) or level_data.palette.size() < 64:
		palette_ready = false
		return
	var wet_colors = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(wet_path))
	if wet_colors.size() < 64:
		palette_ready = false
		return
	dry_palette_image = _palette_image(level_data.palette)
	wet_palette_image = _palette_image(wet_colors)
	dry_palette_texture = ImageTexture.create_from_image(dry_palette_image)
	wet_palette_texture = ImageTexture.create_from_image(wet_palette_image)
	var mat = material as ShaderMaterial
	mat.set_shader_parameter("dry_palette", dry_palette_texture)
	mat.set_shader_parameter("wet_palette", wet_palette_texture)
	palette_ready = true

func _load_source_palettes(mat: ShaderMaterial) -> bool:
	var root = "res://data/s1"
	var sonic_dry = root.path_join("palette/Sonic.bin")
	var lz_dry = root.path_join("palette/Labyrinth Zone.bin")
	var sonic_wet = _find_palette(root, ["Sonic - LZ Underwater.bin"])
	var lz_wet = _find_palette(root, ["Labyrinth Zone Underwater.bin"])
	if not FileAccess.file_exists(sonic_dry) or not FileAccess.file_exists(lz_dry) or sonic_wet.is_empty() or lz_wet.is_empty():
		push_error("Phase 29: exact LZ underwater palette sources are missing. Palette split disabled; no substitute colors will be invented.")
		return false
	var dry_bytes = PackedByteArray()
	dry_bytes.append_array(FileAccess.get_file_as_bytes(sonic_dry))
	dry_bytes.append_array(FileAccess.get_file_as_bytes(lz_dry))
	# `Labyrinth Zone Underwater.bin` is the complete 64-colour underwater
	# palette loaded by palid_LZWater. Its first 16 colours are the underwater
	# Sonic line and match `Sonic - LZ Underwater.bin`, which is loaded earlier
	# during level setup. Do not concatenate that 16-colour line a second time.
	var wet_bytes = FileAccess.get_file_as_bytes(lz_wet)
	var sonic_wet_bytes = FileAccess.get_file_as_bytes(sonic_wet)
	if wet_bytes.size() < 32 or sonic_wet_bytes.size() != 32 or wet_bytes.slice(0, 32) != sonic_wet_bytes:
		push_error("Phase 29: LZ underwater palette sources disagree with the disassembly's Sonic-line relationship.")
		return false
	var dry_colors = GenesisPalette.decode_cram_bytes(dry_bytes)
	var wet_colors = GenesisPalette.decode_cram_bytes(wet_bytes)
	if dry_colors.size() < 64 or wet_colors.size() < 64:
		push_error("Phase 29: LZ dry/underwater source palettes did not decode to 64 CRAM colors.")
		return false
	dry_palette_image = _palette_image(dry_colors)
	wet_palette_image = _palette_image(wet_colors)
	dry_palette_texture = ImageTexture.create_from_image(dry_palette_image)
	wet_palette_texture = ImageTexture.create_from_image(wet_palette_image)
	mat.set_shader_parameter("dry_palette", dry_palette_texture)
	mat.set_shader_parameter("wet_palette", wet_palette_texture)
	return true

func update_runtime_palettes(dry_colors: Array[Color], wet_colors: Array[Color]) -> void:
	# Phase 72 palette-cycle hook. Reuse the two tiny 64x1 palette textures so
	# waterfall/conveyor CRAM changes remain synchronized above and below water.
	if dry_colors.size() < 64 or wet_colors.size() < 64:
		return
	if dry_palette_image == null or wet_palette_image == null or dry_palette_texture == null or wet_palette_texture == null:
		return
	for i in range(64):
		dry_palette_image.set_pixel(i, 0, dry_colors[i])
		wet_palette_image.set_pixel(i, 0, wet_colors[i])
	dry_palette_texture.update(dry_palette_image)
	wet_palette_texture.update(wet_palette_image)

func _find_palette(root: String, names: Array) -> String:
	for name in names:
		var path = root.path_join("palette").path_join(String(name))
		if FileAccess.file_exists(path):
			return path
	return ""

func _palette_image(colors: Array[Color]) -> Image:
	var image = Image.create_empty(64, 1, false, Image.FORMAT_RGBA8)
	for i in range(64):
		image.set_pixel(i, 0, colors[i])
	return image

func _resolve_water_world_y():
	if object_manager.has_method("get_lz_water_y"):
		return object_manager.call("get_lz_water_y")
	for candidate in [
		"lz_water_current_y", "current_water_y", "lz_water_y", "water_surface_y",
		"waterpos1", "water_pos", "water_y", "water_level", "water_height"
	]:
		var value = _numeric_property(candidate)
		if value != null:
			return value
	# Last-resort discovery is limited to numeric properties whose names clearly
	# identify the current/surface water position. Never choose target/base state.
	var best_name = ""
	var best_score = -1000
	for item in object_manager.get_property_list():
		var name = String(item.get("name", ""))
		var lower = name.to_lower()
		if not lower.contains("water"):
			continue
		var value = object_manager.get(name)
		if not (value is int or value is float):
			continue
		var score = 0
		if lower.contains("current"): score += 8
		if lower.contains("surface"): score += 7
		if lower.ends_with("_y") or lower.contains("pos"): score += 5
		if lower.contains("target"): score -= 10
		if lower.contains("initial") or lower.contains("base"): score -= 8
		if lower.contains("state") or lower.contains("timer"): score -= 8
		if score > best_score:
			best_score = score
			best_name = name
	if not best_name.is_empty() and best_score > 0:
		return object_manager.get(best_name)
	push_error("Phase 29: could not resolve Phase 28's current LZ water-position property; palette split disabled.")
	return null

func _numeric_property(name: String):
	for item in object_manager.get_property_list():
		if String(item.get("name", "")) != name:
			continue
		var value = object_manager.get(name)
		if value is int or value is float:
			return value
	return null
