class_name Enigma
extends RefCounted

static func decompress(data: PackedByteArray, base_art_tile: int = 0) -> PackedByteArray:
	var output := PackedByteArray()
	if data.size() < 6:
		return output

	var source := 0
	var inline_bits := int(data[source])
	source += 1
	var flags := int(data[source])
	source += 1
	var incremental_word := _read_be16(data, source) + base_art_tile
	source += 2
	var literal_word := _read_be16(data, source) + base_art_tile
	source += 2

	var stream := data.slice(source)
	var reader := GenesisBitReader.new(stream)

	while true:
		var peek := reader.peek_bits(7)
		var entry := 0
		var repeat_field := 0

		if peek < 0x40:
			reader.read_bits(6)
			entry = peek
			repeat_field = peek >> 1
		else:
			reader.read_bits(7)
			entry = peek
			repeat_field = peek

		var repeat_count := (repeat_field & 0xF) + 1
		var operation := entry >> 4

		match operation:
			0, 1:
				for _i in range(repeat_count):
					_append_be16(output, incremental_word)
					incremental_word = (incremental_word + 1) & 0xFFFF
			2, 3:
				for _i in range(repeat_count):
					_append_be16(output, literal_word)
			4:
				var repeat_value := _read_inline_value(reader, inline_bits, flags, base_art_tile)
				for _i in range(repeat_count):
					_append_be16(output, repeat_value)
			5:
				var increment_value := _read_inline_value(reader, inline_bits, flags, base_art_tile)
				for _i in range(repeat_count):
					_append_be16(output, increment_value)
					increment_value = (increment_value + 1) & 0xFFFF
			6:
				var decrement_value := _read_inline_value(reader, inline_bits, flags, base_art_tile)
				for _i in range(repeat_count):
					_append_be16(output, decrement_value)
					decrement_value = (decrement_value - 1) & 0xFFFF
			7:
				if (repeat_field & 0xF) == 0xF:
					break
				for _i in range(repeat_count):
					_append_be16(output, _read_inline_value(reader, inline_bits, flags, base_art_tile))

	return output

static func _read_inline_value(reader: GenesisBitReader, inline_bits: int, flags: int, base_art_tile: int) -> int:
	var word := base_art_tile
	var flag_to_tile_bit := [
		Vector2i(4, 15), # priority
		Vector2i(3, 14), # palette high
		Vector2i(2, 13), # palette low
		Vector2i(1, 12), # vertical flip
		Vector2i(0, 11), # horizontal flip
	]

	for pair in flag_to_tile_bit:
		if (flags & (1 << pair.x)) != 0 and reader.read_bits(1) != 0:
			word |= 1 << pair.y

	word = (word + reader.read_bits(inline_bits)) & 0xFFFF
	return word

static func _read_be16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])

static func _append_be16(output: PackedByteArray, value: int) -> void:
	output.append((value >> 8) & 0xFF)
	output.append(value & 0xFF)
