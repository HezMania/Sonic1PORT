class_name Kosinski
extends RefCounted

static func decompress(data: PackedByteArray) -> PackedByteArray:
	var output := PackedByteArray()
	if data.size() < 2:
		return output

	var source := 2
	var descriptor := data[0] | (data[1] << 8) # Kosinski descriptor words are read LSB-first.
	var bits_left := 16

	while source < data.size():
		var first := _get_bit(data, source, descriptor, bits_left)
		source = first.source
		descriptor = first.descriptor
		bits_left = first.bits_left

		if first.bit != 0:
			if source >= data.size():
				break
			output.append(data[source])
			source += 1
			continue

		var second := _get_bit(data, source, descriptor, bits_left)
		source = second.source
		descriptor = second.descriptor
		bits_left = second.bits_left

		var displacement := 0
		var length := 0

		if second.bit == 0:
			var count_high := _get_bit(data, source, descriptor, bits_left)
			source = count_high.source
			descriptor = count_high.descriptor
			bits_left = count_high.bits_left

			var count_low := _get_bit(data, source, descriptor, bits_left)
			source = count_low.source
			descriptor = count_low.descriptor
			bits_left = count_low.bits_left

			length = ((count_high.bit << 1) | count_low.bit) + 2
			if source >= data.size():
				break
			# The original code starts d2 at -1 and replaces only its low byte.
			displacement = int(data[source]) - 0x100
			source += 1
		else:
			if source + 1 >= data.size():
				break
			var low := int(data[source])
			var high := int(data[source + 1])
			source += 2

			var encoded := 0xE000 | ((high & 0xF8) << 5) | low
			displacement = encoded - 0x10000

			var short_length := high & 7
			if short_length != 0:
				length = short_length + 2
			else:
				if source >= data.size():
					break
				var extra := int(data[source])
				source += 1
				if extra == 0:
					break # End marker.
				if extra == 1:
					continue # No copy; continue with the descriptor stream.
				length = extra + 1

		for _i in range(length):
			var copy_index := output.size() + displacement
			if copy_index < 0 or copy_index >= output.size():
				push_error("Kosinski: invalid back-reference")
				return output
			output.append(output[copy_index])

	return output

static func _get_bit(data: PackedByteArray, source: int, descriptor: int, bits_left: int) -> Dictionary:
	var bit := descriptor & 1
	descriptor >>= 1
	bits_left -= 1

	# The 68000 routine fetches the next descriptor immediately after consuming
	# the 16th bit, before command payload bytes are read.
	if bits_left == 0:
		if source + 1 < data.size():
			descriptor = data[source] | (data[source + 1] << 8)
			source += 2
			bits_left = 16

	return {
		"bit": bit,
		"source": source,
		"descriptor": descriptor,
		"bits_left": bits_left,
	}
