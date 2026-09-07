class_name MZGeyserObject
extends GenesisLevelObject

# Object $4C - Marble Zone lava geyser/lavafall maker.
#
# Retail placements in MZ2/3 use subtype 1 (lavafall). Phase 69 also restores
# the subtype-0 makers created dynamically by Object $33 PushB_SpawnLavaGeysers.

const BUBBLE1: Array[int] = [0, 1, 0, 1, 4, 5, 4, 5]
const BUBBLE2: Array[int] = [2, 3]
const BUBBLE3: Array[int] = [2, 3, 0, 1, 0, 1]

var timer := 0
var interval := 120
var active_column = null
var sprite: Sprite2D
var anim_tick := 0

var pushblock_mode := false
var pushblock_parent = null
var pushblock_state := 0
var pushblock_anim_tick := 0

func initialize_object() -> void:
	active_width = 56
	sprite = make_sprite("res://assets/objects/mz_geyser/00.png")
	# GMake_Main sets Tile_Prio on the maker.  For the transient subtype-$00
	# push-block geyser this fixed bubbling origin must therefore remain in front
	# of the non-priority $4D lava column, matching the Genesis composition.
	if pushblock_mode:
		sprite.z_as_relative = false
		sprite.z_index = 110
	# Lavafall makers are mostly a bubbling origin; keep the visible tip hidden.
	# Dynamic subtype-0 makers also begin hidden until GMake_Wait is triggered.
	if subtype != 0 or pushblock_mode:
		sprite.visible = false

func setup_pushblock_maker(owner: SonicObjectManager, parent_block, x: int, y: int) -> void:
	manager = owner
	record_index = -1
	object_id = 0x4C
	subtype = 0
	respawn_enabled = false
	x_flip = false
	y_flip = false
	spawn_x = x
	spawn_y = y
	position = Vector2(x, y)
	pushblock_mode = true
	pushblock_parent = parent_block
	pushblock_state = 0
	pushblock_anim_tick = 0
	timer = 0
	initialize_object()

func tick() -> void:
	if not alive:
		return
	if pushblock_mode:
		_tick_pushblock_maker()
		return

	# Existing placed subtype-1 lavafall behavior stays unchanged.
	anim_tick += 1
	if sprite != null and sprite.visible:
		set_sprite_frame(sprite, "mz_geyser", int(anim_tick / 8) % 2)
	if active_column != null and is_instance_valid(active_column) and active_column.alive:
		return
	active_column = null
	if timer > 0:
		timer -= 1
		return
	timer = interval
	var p = player()
	if p == null:
		return
	# GMake_Wait: Sonic must be above the maker but no more than $170 px above.
	var dy = spawn_y - p.pixel_y()
	if dy <= 0 or dy > 0x170:
		return
	active_column = manager.spawn_mz_geyser_column(spawn_x, spawn_y, subtype)

func _tick_pushblock_maker() -> void:
	match pushblock_state:
		0:
			# GMake_Wait starts with a zero timer, so the first check happens
			# immediately. Later failed checks repeat on the source 120-frame timer.
			if timer > 0:
				timer -= 1
				return
			timer = interval
			var p = player()
			if p == null:
				return
			var dy = spawn_y - p.pixel_y()
			if dy <= 0 or dy > 0x170:
				return
			pushblock_state = 1
			pushblock_anim_tick = 0
			sprite.visible = true
			set_sprite_frame(sprite, "mz_geyser", BUBBLE1[0])
		1:
			# Ani_Geyser .bubble1 uses delay 2, i.e. each mapping persists for
			# three VBlanks before afRoutine advances the maker to routine 6.
			var index = int(pushblock_anim_tick / 3)
			if index >= BUBBLE1.size():
				pushblock_state = 2
				return
			set_sprite_frame(sprite, "mz_geyser", BUBBLE1[index])
			pushblock_anim_tick += 1
		2:
			# GMake_MakeLava creates Object $4D, switches the pool animation to
			# .bubble2, then sets parent status bit 1 and obVelY=-$580.
			active_column = manager.spawn_mz_geyser_column(spawn_x, spawn_y, 0)
			if pushblock_parent != null and is_instance_valid(pushblock_parent) and pushblock_parent.alive:
				pushblock_parent.start_lava_geyser_launch()
			pushblock_state = 3
			pushblock_anim_tick = 0
			sprite.visible = true
			set_sprite_frame(sprite, "mz_geyser", BUBBLE2[0])
		3:
			if active_column == null or not is_instance_valid(active_column) or not active_column.alive:
				# Geyser_Type00 changes the maker to Ani_Geyser .bubble3 when
				# the moving tip falls back below its original Y.
				pushblock_state = 4
				pushblock_anim_tick = 0
				return
			set_sprite_frame(sprite, "mz_geyser", BUBBLE2[int(pushblock_anim_tick / 3) % BUBBLE2.size()])
			pushblock_anim_tick += 1
		4:
			var index = int(pushblock_anim_tick / 3)
			if index >= BUBBLE3.size():
				alive = false
				visible = false
				return
			set_sprite_frame(sprite, "mz_geyser", BUBBLE3[index])
			pushblock_anim_tick += 1
