class_name LavaMakerObject
extends GenesisLevelObject

var interval = 30
var timer = 30
var ball_subtype = 0

const RATES = [30, 60, 90, 120, 150, 180]

func initialize_object() -> void:
	active_width = 8
	var rate_index = clampi((subtype >> 4) & 0x0F, 0, RATES.size() - 1)
	interval = int(RATES[rate_index])
	timer = interval
	ball_subtype = subtype & 0x0F
	visible = false

func tick() -> void:
	timer -= 1
	if timer > 0:
		return
	timer = interval
	if manager.is_world_x_on_screen(spawn_x, 32):
		manager.spawn_lava_ball(spawn_x, spawn_y, ball_subtype)
