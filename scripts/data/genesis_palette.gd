class_name GenesisPalette
extends RefCounted

static func load_sonic_and_ghz(root_path: String) -> Array[Color]:
	return load_sonic_and_zone(root_path, "palette/Green Hill Zone.bin")

static func load_sonic_and_zone(root_path: String, zone_palette_path: String, sonic_palette_path: String = "palette/Sonic.bin") -> Array[Color]:
	var sonic = FileAccess.get_file_as_bytes(root_path.path_join(sonic_palette_path))
	var zone = FileAccess.get_file_as_bytes(root_path.path_join(zone_palette_path))
	var combined = PackedByteArray()
	if zone.size() >= 128:
		# Most level palettes contain only CRAM lines 1-3 (96 bytes), but the
		# Ending palette is a complete 64-colour CRAM image. GM_Ending loads that
		# full palette and then overlays Sonic's 16 colours into line 0.
		combined = zone.slice(0, 128)
		for i in range(mini(32, sonic.size())):
			combined[i] = sonic[i]
	else:
		combined.append_array(sonic)
		combined.append_array(zone)
	return decode_cram_bytes(combined)

static func decode_cram_bytes(data: PackedByteArray) -> Array[Color]:
	var colors: Array[Color] = []
	for offset in range(0, data.size() - 1, 2):
		var word = (int(data[offset]) << 8) | int(data[offset + 1])
		var red = float((word >> 1) & 7) / 7.0
		var green = float((word >> 5) & 7) / 7.0
		var blue = float((word >> 9) & 7) / 7.0
		colors.append(Color(red, green, blue, 1.0))
	return colors
