class_name Nemesis
extends RefCounted

static func decompress(data: PackedByteArray) -> PackedByteArray:
	var output := PackedByteArray()
	if data.size() < 3:
		return output

	var header := _read_be16(data, 0)
	var xor_mode := (header & 0x8000) != 0
	var pattern_count := header & 0x7FFF
	var target_rows := pattern_count * 8

	# Each logical table entry encodes: code length in bits 8..15,
	# repeat count in bits 4..6, and pixel/palette nibble in bits 0..3.
	var code_table := PackedInt32Array()
	code_table.resize(256)

	var source := 2
	var marker := int(data[source])
	source += 1

	while marker != 0xFF and source < data.size():
		var palette_index := marker & 0xF
		while source < data.size():
			marker = int(data[source])
			source += 1
			if marker >= 0x80:
				break

			var code_length := marker & 0xF
			var repeat_field := (marker >> 4) & 7
			if source >= data.size():
				break
			var code := int(data[source])
			source += 1

			var table_value := (code_length << 8) | (repeat_field << 4) | palette_index
			if code_length == 8:
				code_table[code] = table_value
			else:
				var shift := 8 - code_length
				var first_index := code << shift
				var fill_count := 1 << shift
				for i in range(fill_count):
					code_table[first_index + i] = table_value

	var compressed := data.slice(source)
	# Standalone .nem files may end in the middle of the last 16-bit fetch. The
	# original ROM routine naturally sees following/padding bytes. Zero padding
	# reproduces the intended final row and is truncated to pattern_count below.
	compressed.append(0)
	compressed.append(0)
	var reader := GenesisBitReader.new(compressed, true)

	var row_value := 0
	var pixels_in_row := 0
	var rows_written := 0
	var previous_row := 0

	while rows_written < target_rows:
		var repeat_count := 0
		var pixel := 0

		if reader.peek_bits(6) == 0x3F:
			reader.read_bits(6)
			var inline_value := reader.read_bits(7)
			repeat_count = ((inline_value >> 4) & 7) + 1
			pixel = inline_value & 0xF
		else:
			var table_index := reader.peek_bits(8)
			var table_value := int(code_table[table_index])
			var code_length := (table_value >> 8) & 0xFF
			if code_length == 0:
				push_error("Nemesis: invalid prefix code")
				return output
			reader.read_bits(code_length)
			repeat_count = ((table_value >> 4) & 7) + 1
			pixel = table_value & 0xF

		for _i in range(repeat_count):
			if rows_written >= target_rows:
				break
			row_value = (row_value << 4) | pixel
			pixels_in_row += 1
			if pixels_in_row == 8:
				var write_value := row_value
				if xor_mode:
					write_value ^= previous_row
					previous_row = write_value
				_append_be32(output, write_value)
				rows_written += 1
				pixels_in_row = 0
				row_value = 0

	return output

static func _read_be16(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])

static func _append_be32(output: PackedByteArray, value: int) -> void:
	output.append((value >> 24) & 0xFF)
	output.append((value >> 16) & 0xFF)
	output.append((value >> 8) & 0xFF)
	output.append(value & 0xFF)
