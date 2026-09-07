class_name BridgeObject
extends GenesisLevelObject

# Object $11 GHZ bridge. Phase 65 replaces the early smooth approximation
# with the retail Bri_Bend table/integer path while preserving the already-
# validated native platform interaction and exact 16px log spacing.

var logs: Array[Sprite2D] = []
var log_count := 1
var nudge := 0
var current_log := -1

# Exact Bri_Data_Align table from `_incObj/11 GHZ Bridge.asm`.
# Rows are indexed by the number of logs on the relevant side of Sonic. The
# source stores `$FF` as 256 after its `addq #1`, while unused entries are zero.
const BRI_DATA_ALIGN: Array[int] = [
	0xFF,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0xB5,0xFF,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0x7E,0xDB,0xFF,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0x61,0xB5,0xEC,0xFF,0,0,0,0,0,0,0,0,0,0,0,0,
	0x4A,0x93,0xCD,0xF3,0xFF,0,0,0,0,0,0,0,0,0,0,0,
	0x3E,0x7E,0xB0,0xDB,0xF6,0xFF,0,0,0,0,0,0,0,0,0,0,
	0x38,0x6D,0x9D,0xC5,0xE4,0xF8,0xFF,0,0,0,0,0,0,0,0,0,
	0x31,0x61,0x8E,0xB5,0xD4,0xEC,0xFB,0xFF,0,0,0,0,0,0,0,0,
	0x2B,0x56,0x7E,0xA2,0xC1,0xDB,0xEE,0xFB,0xFF,0,0,0,0,0,0,0,
	0x25,0x4A,0x73,0x93,0xB0,0xCD,0xE1,0xF3,0xFC,0xFF,0,0,0,0,0,0,
	0x1F,0x44,0x67,0x88,0xA7,0xBD,0xD4,0xE7,0xF4,0xFD,0xFF,0,0,0,0,0,
	0x1F,0x3E,0x5C,0x7E,0x98,0xB0,0xC9,0xDB,0xEA,0xF6,0xFD,0xFF,0,0,0,0,
	0x19,0x38,0x56,0x73,0x8E,0xA7,0xBD,0xD1,0xE1,0xEE,0xF8,0xFE,0xFF,0,0,0,
	0x19,0x38,0x50,0x6D,0x83,0x9D,0xB0,0xC5,0xD8,0xE4,0xF1,0xF8,0xFE,0xFF,0,0,
	0x19,0x31,0x4A,0x67,0x7E,0x93,0xA7,0xBD,0xCD,0xDB,0xE7,0xF3,0xF9,0xFE,0xFF,0,
	0x19,0x31,0x4A,0x61,0x78,0x8E,0xA2,0xB5,0xC5,0xD4,0xE1,0xEC,0xF4,0xFB,0xFE,0xFF,
]

func initialize_object() -> void:
	log_count = maxi(1, subtype)
	active_width = log_count * 8
	var left = -(log_count >> 1) * 16
	for i in range(log_count):
		var log = make_sprite("res://assets/objects/bridge/00.png")
		log.position = Vector2(left + i * 16, 0)
		logs.append(log)

func tick() -> void:
	var p = player()
	if p == null:
		return
	var left_world = spawn_x - (log_count >> 1) * 16 - 8
	var right_world = left_world + log_count * 16
	var was_on = false
	if p.vel_y >= 0 and p.pixel_x() >= left_world and p.pixel_x() < right_world:
		var index = clampi((p.pixel_x() - left_world) >> 4, 0, log_count - 1)
		var top_y = spawn_y - 8 + _log_bend(index)
		if p.resolve_platform_top(left_world, right_world, top_y, record_index):
			current_log = index
			was_on = true

	if was_on:
		nudge = mini(0x40, nudge + 4)
	else:
		nudge = maxi(0, nudge - 4)
		if nudge == 0:
			current_log = -1
	_update_log_positions()

func _update_log_positions() -> void:
	var left = -(log_count >> 1) * 16
	for i in range(logs.size()):
		logs[i].position = Vector2(left + i * 16, _log_bend(i))

func _log_bend(index: int) -> int:
	if current_log < 0 or nudge <= 0 or index < 0 or index >= log_count:
		return 0

	# Bri_Data_Y_Max is the exact triangular table 2,4,6... toward the
	# currently stood-on log. Only 1-12 logs are used by retail GHZ, but the
	# source table is defined through 16 and this equivalent covers all rows.
	var max_drop = 2 * mini(current_log + 1, log_count - current_log)
	var align_row = 0
	var align_col = 0
	if index <= current_log:
		# `.loopLeftLogs`: row = bridge_currentlog, traversed forwards.
		align_row = current_log
		align_col = index
	else:
		# `.loopRightLogs`: row = number of logs to the right, traversed
		# backwards from that row's final meaningful byte.
		var right_count = log_count - current_log - 1
		align_row = right_count
		align_col = log_count - 1 - index

	var align_plus_one = BRI_DATA_ALIGN[align_row * 16 + align_col] + 1
	var sine = GenesisMath.sine(nudge & 0xFF)
	# Original 68000 path:
	#   mulu.w max_drop, align_plus_one
	#   mulu.w sine, result
	#   swap result
	# All operands are positive in Bri_Bend ($00-$40 nudge), so this is the
	# exact integer high-word result rather than a floating-point curve.
	return (align_plus_one * max_drop * sine) >> 16
