class_name GenesisCollision
extends RefCounted

var level: GHZLevelData

func _init(level_data: GHZLevelData) -> void:
	level = level_data

# Convenience wrappers for the four original sensor directions. These keep the
# coordinate inversions/eor masks used by Sonic Collision.asm in one place.
func find_floor_sensor(world_x: int, world_y: int, top_solid_only: bool = true, collision_path = 0) -> Dictionary:
	return find_floor(world_x, world_y, 13 if top_solid_only else 14, 16, 0, collision_path)

func find_ceiling_sensor(world_x: int, world_y: int, collision_path = 0) -> Dictionary:
	return find_floor(world_x, world_y ^ 0xF, 14, -16, 0x1000, collision_path)

func find_right_wall_sensor(world_x: int, world_y: int, collision_path = 0) -> Dictionary:
	return find_wall(world_x, world_y, 14, 16, 0, collision_path)

func find_left_wall_sensor(world_x: int, world_y: int, collision_path = 0) -> Dictionary:
	return find_wall(world_x ^ 0xF, world_y, 14, -16, 0x0800, collision_path)

# Direct translation-friendly equivalent of FindFloor / FindFloor2.
# world_x/world_y are the sensor coordinates passed to the original routine.
# solid_bit is 13 for top-solid terrain and 14 for left/right/bottom-solid terrain.
# step is +16 for floor, -16 for ceiling. flip_xor is 0 for floor, 0x1000 for ceiling.
func find_floor(world_x: int, world_y: int, solid_bit: int = 13, step: int = 16, flip_xor: int = 0, collision_path = 0) -> Dictionary:
	var sample := _floor_sample(world_x, world_y, solid_bit, step, flip_xor, collision_path, false)
	if sample.needs_neighbor > 0:
		var neighbor := _floor_sample(world_x, world_y + step, solid_bit, step, flip_xor, collision_path, true)
		neighbor.distance += 16
		_carry_angle_buffer(sample, neighbor)
		return neighbor
	if sample.needs_neighbor < 0:
		var neighbor := _floor_sample(world_x, world_y - step, solid_bit, step, flip_xor, collision_path, true)
		neighbor.distance -= 16
		_carry_angle_buffer(sample, neighbor)
		return neighbor
	return sample

# Direct translation-friendly equivalent of FindWall / FindWall2.
# step is +16 for a right wall and -16 for a left wall. flip_xor is 0 or 0x800 respectively.
func find_wall(world_x: int, world_y: int, solid_bit: int = 14, step: int = 16, flip_xor: int = 0, collision_path = 0) -> Dictionary:
	var sample := _wall_sample(world_x, world_y, solid_bit, step, flip_xor, collision_path, false)
	if sample.needs_neighbor > 0:
		var neighbor := _wall_sample(world_x + step, world_y, solid_bit, step, flip_xor, collision_path, true)
		neighbor.distance += 16
		_carry_angle_buffer(sample, neighbor)
		return neighbor
	if sample.needs_neighbor < 0:
		var neighbor := _wall_sample(world_x - step, world_y, solid_bit, step, flip_xor, collision_path, true)
		neighbor.distance -= 16
		_carry_angle_buffer(sample, neighbor)
		return neighbor
	return sample

func get_block_info(world_x: int, world_y: int, collision_path = 0) -> Dictionary:
	var word := level.get_chunk_word_at_world(world_x, world_y, collision_path)
	var block_id := word & 0x7FF
	var shape_id := level.get_collision_shape_id(block_id, collision_path)
	return {
		"word": word,
		"block_id": block_id,
		"shape_id": shape_id,
		"top_solid": (word & 0x2000) != 0,
		"all_solid": (word & 0x4000) != 0,
		"x_flip": (word & 0x0800) != 0,
		"y_flip": (word & 0x1000) != 0,
	}

func _floor_sample(world_x: int, world_y: int, solid_bit: int, step: int, flip_xor: int, collision_path, secondary: bool) -> Dictionary:
	var word := level.get_chunk_word_at_world(world_x, world_y, collision_path)
	var block_id := word & 0x7FF
	var solid_mask := 1 << solid_bit
	var result := _empty_result(word, block_id)

	if block_id == 0 or (word & solid_mask) == 0:
		if secondary:
			result.distance = 15 - (world_y & 0xF)
			return result
		result.needs_neighbor = 1
		return result

	var shape_id := level.get_collision_shape_id(block_id, collision_path)
	result.shape_id = shape_id
	if shape_id == 0:
		if secondary:
			result.distance = 15 - (world_y & 0xF)
			return result
		result.needs_neighbor = 1
		return result

	var angle := level.get_angle_for_shape(shape_id)
	var sample_x := world_x
	if (word & 0x0800) != 0:
		sample_x = ~sample_x
		angle = (-angle) & 0xFF
	if (word & 0x1000) != 0:
		angle = (0x80 - angle) & 0xFF
	result.angle = angle
	# FindFloor writes the angle buffer as soon as it resolves a nonzero
	# collision shape, before it decides whether FindFloor2 must inspect an
	# adjacent block. That angle therefore survives if the secondary block is
	# blank. Preserve that side effect explicitly instead of treating a query
	# result as one indivisible tile sample.
	result.angle_written = true

	var height := level.get_normal_height(shape_id, sample_x & 0xF)
	var effective_word := word ^ flip_xor
	if (effective_word & 0x1000) != 0:
		height = -height
	result.height = height

	if height == 0:
		if secondary:
			result.distance = 15 - (world_y & 0xF)
			return result
		result.needs_neighbor = 1
		return result

	var local_y := world_y & 0xF
	if height < 0:
		if height + local_y >= 0:
			if secondary:
				result.distance = 15 - local_y
				return result
			result.needs_neighbor = 1
			return result
		if secondary:
			# FindFloor2 returns NOT(local_y) in this branch.
			result.distance = ~local_y
			return result
		result.needs_neighbor = -1
		return result

	if not secondary and height == 16:
		result.needs_neighbor = -1
		return result

	result.distance = 15 - (height + local_y)
	return result

func _wall_sample(world_x: int, world_y: int, solid_bit: int, step: int, flip_xor: int, collision_path, secondary: bool) -> Dictionary:
	var word := level.get_chunk_word_at_world(world_x, world_y, collision_path)
	var block_id := word & 0x7FF
	var solid_mask := 1 << solid_bit
	var result := _empty_result(word, block_id)

	if block_id == 0 or (word & solid_mask) == 0:
		if secondary:
			result.distance = 15 - (world_x & 0xF)
			return result
		result.needs_neighbor = 1
		return result

	var shape_id := level.get_collision_shape_id(block_id, collision_path)
	result.shape_id = shape_id
	if shape_id == 0:
		if secondary:
			result.distance = 15 - (world_x & 0xF)
			return result
		result.needs_neighbor = 1
		return result

	var angle := level.get_angle_for_shape(shape_id)
	var sample_y := world_y
	if (word & 0x1000) != 0:
		sample_y = ~sample_y
		angle = (0x80 - angle) & 0xFF
	if (word & 0x0800) != 0:
		angle = (-angle) & 0xFF
	result.angle = angle
	# Same persistent angle-buffer behavior as FindFloor/FindFloor2.
	result.angle_written = true

	var height := level.get_rotated_height(shape_id, sample_y & 0xF)
	var effective_word := word ^ flip_xor
	if (effective_word & 0x0800) != 0:
		height = -height
	result.height = height

	if height == 0:
		if secondary:
			result.distance = 15 - (world_x & 0xF)
			return result
		result.needs_neighbor = 1
		return result

	var local_x := world_x & 0xF
	if height < 0:
		if height + local_x >= 0:
			if secondary:
				result.distance = 15 - local_x
				return result
			result.needs_neighbor = 1
			return result
		if secondary:
			result.distance = ~local_x
			return result
		result.needs_neighbor = -1
		return result

	if not secondary and height == 16:
		result.needs_neighbor = -1
		return result

	result.distance = 15 - (height + local_x)
	return result

static func _carry_angle_buffer(primary: Dictionary, secondary: Dictionary) -> void:
	# FindFloor2/FindWall2 share the caller-provided angle-buffer pointer. If
	# the primary sample wrote an angle and the neighboring sample is blank,
	# the primary angle remains in that buffer even though the returned distance
	# comes from the neighboring block. This is important on loop seams.
	if bool(primary.get("angle_written", false)) and not bool(secondary.get("angle_written", false)):
		secondary["angle"] = int(primary["angle"]) & 0xFF
		secondary["angle_written"] = true

static func _empty_result(word: int, block_id: int) -> Dictionary:
	return {
		"distance": 15,
		"angle": 0,
		"angle_written": false,
		"height": 0,
		"word": word,
		"block_id": block_id,
		"shape_id": 0,
		"needs_neighbor": 0,
	}
