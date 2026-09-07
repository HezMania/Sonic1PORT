class_name LZBubbleObject
extends GenesisLevelObject

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
const BUBBLE_TYPES: Array[int] = [0,1,0,0,0,0,1,0,0,0,0,1,0,1,0,0,1,0]
const FORM_SEQUENCES = [
	[0,1,2],
	[1,2,3,4],
	[2,3,4,5,6],
]

var sprite: Sprite2D
var is_maker := false
var bubble_type := 0
var orig_x := 0
var fixed_y := 0
var vel_y := -0x88
var wobble_angle := 0
var state := 0 # 0 forming, 1 floating, 2 bursting
var anim_index := 0
var anim_timer := 0
var inhalable := false

# Bubble-maker state.
var maker_time := 0
var maker_timebase := 0
var maker_random_time := 0
var maker_spawning := false
var maker_mini_count := -1
var maker_type_start := 0
var maker_allow_large := false
var maker_large_spawned := false
var maker_anim_index := 0
var maker_anim_timer := 0

func initialize_object() -> void:
	active_width = 16
	if (subtype & 0x80) != 0:
		_init_maker()
	else:
		_init_bubble(subtype & 0x7F, manager.next_random_word() & 0xFF)

func setup_bubble(owner: SonicObjectManager, world_x: int, world_y: int, type_id: int, angle_seed: int = -1) -> void:
	manager = owner
	record_index = -1
	object_id = 0x64
	subtype = type_id & 0x7F
	spawn_x = world_x
	spawn_y = world_y
	position = Vector2(world_x, world_y)
	active_width = 16
	var seed = angle_seed if angle_seed >= 0 else (manager.next_random_word() & 0xFF)
	_init_bubble(subtype, seed)

func _init_maker() -> void:
	is_maker = true
	# Source obPriority=1: bubble makers render above Sonic just like free bubbles.
	# ArtTile_LZ_Bubbles carries Tile_Prio and priority 1 (above Sonic).
	z_index = 125
	maker_timebase = subtype & 0x7F
	maker_time = maker_timebase
	maker_random_time = 0
	maker_anim_timer = 0
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.lz_bubble_texture(19)

func _init_bubble(type_id: int, angle_seed: int) -> void:
	is_maker = false
	bubble_type = clampi(type_id, 0, 2)
	orig_x = int(position.x)
	fixed_y = int(position.y) << 16
	wobble_angle = angle_seed & 0xFF
	state = 0
	anim_index = 0
	anim_timer = 14
	inhalable = false
	sprite = make_sprite("")
	_set_bubble_frame(int(FORM_SEQUENCES[bubble_type][0]))

func tick() -> void:
	if not alive:
		return
	if is_maker:
		_tick_maker()
	else:
		_tick_bubble()

func _tick_maker() -> void:
	var underwater_here = manager.water_enabled and manager.water_surface_y < int(position.y)
	sprite.visible = underwater_here
	_tick_maker_animation()
	if not underwater_here or not manager.is_world_x_on_screen(int(position.x), 32):
		return
	maker_random_time -= 1
	if maker_random_time >= 0:
		return
	if not maker_spawning:
		_begin_spawn_group()
	_spawn_group_bubble()

func _begin_spawn_group() -> void:
	maker_spawning = true
	var random_word = manager.next_random_word()
	maker_mini_count = random_word & 7
	while maker_mini_count >= 6:
		random_word = manager.next_random_word()
		maker_mini_count = random_word & 7
	maker_type_start = random_word & 0x0C
	maker_time -= 1
	maker_allow_large = maker_time < 0
	maker_large_spawned = false
	if maker_allow_large:
		maker_time = maker_timebase

func _spawn_group_bubble() -> void:
	maker_random_time = manager.next_random_word() & 0x1F
	var type_index = clampi(maker_type_start + maker_mini_count, 0, BUBBLE_TYPES.size() - 1)
	var type_id = int(BUBBLE_TYPES[type_index])
	if maker_allow_large and not maker_large_spawned:
		if (manager.next_random_word() & 3) == 0 or maker_mini_count == 0:
			type_id = 2
			maker_large_spawned = true
	var x_offset = (manager.next_random_word() & 0x0F) - 8
	manager.spawn_lz_bubble(int(position.x) + x_offset, int(position.y), type_id)
	maker_mini_count -= 1
	if maker_mini_count >= 0:
		return
	maker_spawning = false
	maker_random_time += (manager.next_random_word() & 0x7F) + 0x80

func _tick_maker_animation() -> void:
	maker_anim_timer -= 1
	if maker_anim_timer >= 0:
		return
	maker_anim_timer = 15
	maker_anim_index = (maker_anim_index + 1) % 3
	sprite.texture = SourceObjectArt.lz_bubble_texture(19 + maker_anim_index)

func _tick_bubble() -> void:
	if state == 2:
		_tick_burst()
		return
	if manager.water_surface_y >= int(position.y):
		if bubble_type == 2:
			_start_burst()
		else:
			request_delete(false)
		return
	_update_wobble_and_float()
	if state == 0:
		_tick_form_animation()
	if bubble_type == 2 and inhalable:
		_try_give_air()

func _update_wobble_and_float() -> void:
	var wobble_index = wobble_angle & 0x7F
	wobble_angle = (wobble_angle + 1) & 0xFF
	position.x = orig_x + int(WOBBLE[wobble_index])
	fixed_y += vel_y << 8
	position.y = fixed_y >> 16

func _tick_form_animation() -> void:
	anim_timer -= 1
	if anim_timer >= 0:
		return
	anim_timer = 14
	anim_index += 1
	var sequence = FORM_SEQUENCES[bubble_type]
	if anim_index >= sequence.size():
		anim_index = sequence.size() - 1
		state = 1
		if bubble_type == 2:
			inhalable = true
		return
	_set_bubble_frame(int(sequence[anim_index]))
	if bubble_type == 2 and int(sequence[anim_index]) == 6:
		inhalable = true

func _try_give_air() -> void:
	var p = player()
	if p == null or p.debug_free_mode or p.drowning:
		return
	var px = p.pixel_x()
	var py = p.pixel_y()
	var bx = int(position.x)
	var by = int(position.y)
	if px <= bx - 16 or px >= bx + 16:
		return
	if py <= by or py >= by + 16:
		return
	manager.replenish_lz_air()
	p.receive_air_bubble()
	_start_burst()

func _start_burst() -> void:
	state = 2
	inhalable = false
	anim_index = 0
	anim_timer = 4
	_set_bubble_frame(6)

func _tick_burst() -> void:
	anim_timer -= 1
	if anim_timer >= 0:
		return
	anim_timer = 4
	anim_index += 1
	var burst_frames = [6, 7, 8]
	if anim_index >= burst_frames.size():
		request_delete(false)
		return
	_set_bubble_frame(int(burst_frames[anim_index]))

func _set_bubble_frame(frame_id: int) -> void:
	if sprite != null:
		sprite.texture = SourceObjectArt.lz_bubble_texture(frame_id)
