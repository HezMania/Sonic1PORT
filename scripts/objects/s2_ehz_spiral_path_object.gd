class_name S2EHZSpiralPathObject
extends GenesisLevelObject

# Phase 85: retail Sonic 2 Object $06, EHZ twisting pathway. The object itself
# is invisible; it temporarily owns Sonic's platform/ride bit while his center X
# moves across the authored 0x1A0-pixel path. Vertical displacement and the
# animation-only flip angle are copied from Obj06_CosineTable /
# Obj06_FlipAngleTable in the retail S2 source.
const COSINE_TABLE: Array[int] = [
	32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
	32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 31, 31,
	31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 30, 30, 30,
	30, 30, 30, 30, 30, 30, 29, 29, 29, 29, 29, 28, 28, 28, 28, 27,
	27, 27, 27, 26, 26, 26, 25, 25, 25, 24, 24, 24, 23, 23, 22, 22,
	21, 21, 20, 20, 19, 18, 18, 17, 16, 16, 15, 14, 14, 13, 12, 12,
	11, 10, 10, 9, 8, 8, 7, 6, 6, 5, 4, 4, 3, 2, 2, 1,
	0, -1, -2, -2, -3, -4, -4, -5, -6, -7, -7, -8, -9, -9, -10, -10,
	-11, -11, -12, -12, -13, -14, -14, -15, -15, -16, -16, -17, -17, -18, -18, -19,
	-19, -19, -20, -21, -21, -22, -22, -23, -23, -24, -24, -25, -25, -26, -26, -27,
	-27, -28, -28, -28, -29, -29, -30, -30, -30, -31, -31, -31, -32, -32, -32, -33,
	-33, -33, -33, -34, -34, -34, -35, -35, -35, -35, -35, -35, -35, -35, -36, -36,
	-36, -36, -36, -36, -36, -36, -36, -37, -37, -37, -37, -37, -37, -37, -37, -37,
	-37, -37, -37, -37, -37, -37, -37, -37, -37, -37, -37, -37, -37, -37, -37, -37,
	-37, -37, -37, -37, -36, -36, -36, -36, -36, -36, -36, -35, -35, -35, -35, -35,
	-35, -35, -35, -34, -34, -34, -33, -33, -33, -33, -32, -32, -32, -31, -31, -31,
	-30, -30, -30, -29, -29, -28, -28, -28, -27, -27, -26, -26, -25, -25, -24, -24,
	-23, -23, -22, -22, -21, -21, -20, -19, -19, -18, -18, -17, -16, -16, -15, -14,
	-14, -13, -12, -11, -11, -10, -9, -8, -7, -7, -6, -5, -4, -3, -2, -1,
	0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 9, 10, 10, 11, 12, 13,
	13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21,
	21, 22, 22, 23, 23, 24, 24, 24, 25, 25, 25, 25, 26, 26, 26, 26,
	27, 27, 27, 27, 28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29,
	29, 30, 30, 30, 30, 30, 30, 30, 31, 31, 31, 31, 31, 31, 31, 31,
	31, 31, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
	32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
]

const FLIP_ANGLE_TABLE: Array[int] = [
	0x00, 0x00, 0x01, 0x01, 0x16, 0x16, 0x16, 0x16, 0x2C, 0x2C, 0x2C, 0x2C, 0x42,
	0x42, 0x42, 0x42, 0x58, 0x58, 0x58, 0x58, 0x6E, 0x6E, 0x6E, 0x6E, 0x84, 0x84,
	0x84, 0x84, 0x9A, 0x9A, 0x9A, 0x9A, 0xB0, 0xB0, 0xB0, 0xB0, 0xC6, 0xC6, 0xC6,
	0xC6, 0xDC, 0xDC, 0xDC, 0xDC, 0xF2, 0xF2, 0xF2, 0xF2, 0x01, 0x01, 0x00, 0x00,
]

func initialize_object() -> void:
	visible = false
	active_width = 0xD0

func suppress_central_despawn() -> bool:
	var p = player()
	return p != null and p.standing_on_object and p.support_record_index == record_index

func tick() -> void:
	var p = player()
	if p == null or p.dead or p.drowning or p.debug_free_mode:
		_detach(p)
		return

	# status(a0) p1_standing_bit: once this pathway owns Sonic, source Obj06
	# requires |inertia| >= $600, grounded status, and X+0xD0 inside [0,$1A0).
	if p.standing_on_object and p.support_record_index == record_index:
		var offset = p.pixel_x() - spawn_x + 0xD0
		if absi(p.inertia) < 0x600 or p.in_air or offset < 0 or offset >= 0x1A0:
			_detach(p)
			return
		var path_y = spawn_y + COSINE_TABLE[offset] - (p.height_radius - 0x13)
		var flip_index = (offset >> 3) & 0x3F
		# The source table only contains 52 meaningful entries because the path
		# exits before later indices are needed. Clamp defensively without inventing
		# any new angle values.
		flip_index = mini(flip_index, FLIP_ANGLE_TABLE.size() - 1)
		p.update_s2_spiral_pathway(record_index, spawn_x - 0xD0, spawn_x + 0xD0, path_y, FLIP_ANGLE_TABLE[flip_index])
		return

	# Initial RideObject_SetRide capture. Obj06 has a slightly narrower window
	# when Sonic is already standing on another object ($B0..$C0 instead of
	# $C0..$D0). Airborne Sonic cannot be captured.
	if p.in_air or p.object_control_override or p.hurt_state:
		return
	var dx = p.pixel_x() - spawn_x
	var near_min = 0xB0 if p.standing_on_object else 0xC0
	var near_max = 0xC0 if p.standing_on_object else 0xD0
	var in_x_window = false
	if p.vel_x < 0:
		in_x_window = dx >= near_min and dx <= near_max
	else:
		in_x_window = dx >= -near_max and dx <= -near_min
	if not in_x_window:
		return
	var dy = p.pixel_y() - spawn_y - 0x10
	if dy < 0 or dy >= 0x30:
		return
	p.begin_s2_spiral_pathway(record_index, spawn_x - 0xD0, spawn_x + 0xD0)

func _detach(p: SonicPlayer) -> void:
	if p == null:
		return
	if p.standing_on_object and p.support_record_index == record_index:
		p.end_s2_spiral_pathway(record_index)
