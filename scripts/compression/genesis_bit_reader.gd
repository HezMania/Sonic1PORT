class_name GenesisBitReader
extends RefCounted

var data: PackedByteArray
var bit_position: int = 0
var zero_pad: bool = false

func _init(bytes: PackedByteArray, allow_zero_padding: bool = false) -> void:
	data = bytes
	zero_pad = allow_zero_padding

func read_bits(count: int) -> int:
	var value := 0
	for _i in range(count):
		value = (value << 1) | _read_bit()
	return value

func peek_bits(count: int) -> int:
	var old_position := bit_position
	var value := read_bits(count)
	bit_position = old_position
	return value

func _read_bit() -> int:
	var byte_index := bit_position >> 3
	if byte_index >= data.size():
		if zero_pad:
			bit_position += 1
			return 0
		push_error("GenesisBitReader: attempted to read beyond the source buffer")
		return 0
	var bit_index := 7 - (bit_position & 7)
	var value := (data[byte_index] >> bit_index) & 1
	bit_position += 1
	return value
