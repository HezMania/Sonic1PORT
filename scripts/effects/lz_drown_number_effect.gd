class_name LZDrownNumberEffect
extends Node2D

const WOBBLE: Array[int] = [
	0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,
	2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,
	2,2,2,2,2,2,1,1,1,1,1,0,0,0,0,0,
	0,-1,-1,-1,-1,-1,-2,-2,-2,-2,-2,-3,-3,-3,-3,-3,
	-3,-3,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,
	-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-3,
	-3,-3,-3,-3,-3,-3,-2,-2,-2,-2,-2,-1,-1,-1,-1,-1,
]
const APPEAR_SEQUENCES = [
	[0,1,2,3,4,9,13],
	[0,1,2,3,4,12,18],
	[0,1,2,3,4,12,17],
	[0,1,2,3,4,11,16],
	[0,1,2,3,4,9,15],
	[0,1,2,3,4,10,14],
]
const FULL_FRAMES = [13,18,17,16,15,14]

var manager: SonicObjectManager
var alive := true
var sprite: Sprite2D
var number := 0
var orig_x := 0
var fixed_y := 0
var vel_y := -0x88
var wobble_angle := 0
var anim_index := 0
var anim_timer := 5
var phase := 0 # 0 appearing, 1 rising, 2 held screen-fixed, 3 flashing
var phase_timer := 0
var flash_index := 0
var screen_offset := Vector2.ZERO

func setup(owner: SonicObjectManager, world_x: int, world_y: int, value: int, angle_seed: int) -> void:
	manager = owner
	number = clampi(value, 0, 5)
	orig_x = world_x
	fixed_y = world_y << 16
	wobble_angle = angle_seed & 0xFF
	# Spawned number bubbles use Map_Bub with the source Tile_Prio bit.
	z_index = 125
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	add_child(sprite)
	_set_frame(int(APPEAR_SEQUENCES[number][0]))
	position = Vector2(world_x, world_y)

func tick() -> void:
	if manager == null:
		alive = false
		return
	if phase == 0:
		_tick_appear()
	elif phase == 1:
		_tick_rise()
	elif phase == 2:
		_tick_hold()
	else:
		_tick_flash()

func _tick_appear() -> void:
	# Drown_Animate does not call SpeedToPos. The number forms in place first;
	# Ani_Drown's delay 5 means each of the seven appear frames lasts 6 ticks.
	anim_timer -= 1
	if anim_timer >= 0:
		return
	anim_timer = 5
	anim_index += 1
	var sequence = APPEAR_SEQUENCES[number]
	if anim_index < sequence.size():
		_set_frame(int(sequence[anim_index]))
		return
	phase = 1
	phase_timer = 28
	_set_frame(int(FULL_FRAMES[number]))

func _tick_rise() -> void:
	# Drown_ChkWater applies wobble + SpeedToPos while drown_numtime counts 28
	# frames. Once it expires, the object converts to screen-fixed positioning.
	var wi = wobble_angle & 0x7F
	wobble_angle = (wobble_angle + 1) & 0xFF
	position.x = orig_x + int(WOBBLE[wi])
	fixed_y += vel_y << 8
	position.y = fixed_y >> 16
	phase_timer -= 1
	if phase_timer > 0:
		return
	phase = 2
	phase_timer = 15
	vel_y = 0
	screen_offset = Vector2(position.x - manager.current_screen_x, position.y - manager.current_screen_y)
	_set_frame(int(FULL_FRAMES[number]))

func _tick_hold() -> void:
	position = Vector2(manager.current_screen_x, manager.current_screen_y) + screen_offset
	phase_timer -= 1
	if phase_timer > 0:
		return
	phase = 3
	phase_timer = 7
	flash_index = 0

func _tick_flash() -> void:
	position = Vector2(manager.current_screen_x, manager.current_screen_y) + screen_offset
	phase_timer -= 1
	if phase_timer >= 0:
		return
	phase_timer = 7
	flash_index += 1
	if flash_index >= 6:
		alive = false
		return
	_set_frame(22 if (flash_index & 1) != 0 else int(FULL_FRAMES[number]))

func _set_frame(frame_id: int) -> void:
	sprite.texture = SourceObjectArt.lz_bubble_texture(frame_id)
