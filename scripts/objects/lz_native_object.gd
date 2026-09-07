class_name LZNativeObject
extends GenesisLevelObject

# Phase 32 source-driven Labyrinth families:
#   $61 multi-variant blocks
#   $62 gargoyle head / fireball
#   $65 decorative waterfalls / splashes

var sprite: Sprite2D

# $61 block state.
var block_frame := 0
var block_type := 0
var block_half_w := 16
var block_half_h := 16
var block_orig_x := 0
var block_orig_y := 0
var block_timer := 0
var block_untouched := false
var block_nudge := 0
var block_vel_y := 0

# $62 gargoyle state.
var gargoyle_fireball := false
var gargoyle_delay := 0
var gargoyle_timer := 0
var fire_vel_x := 0
var fire_frame := 2

# $65 waterfall state.
var waterfall_frame := 0
var waterfall_anim_timer := 5
var waterfall_runtime_palette: Array[Color] = []

func initialize_object() -> void:
	match object_id:
		0x61:
			_init_lz_block()
		0x62:
			_init_gargoyle_head()
		0x65:
			_init_waterfall()
		_:
			request_delete(false)

func tick() -> void:
	if not alive:
		return
	if gargoyle_fireball:
		_tick_gargoyle_fireball()
		return
	match object_id:
		0x61:
			_tick_lz_block()
		0x62:
			_tick_gargoyle_head()
		0x65:
			_tick_waterfall()

# -----------------------------------------------------------------------------
# Object $61 - Labyrinth multi-variant blocks
# -----------------------------------------------------------------------------
func _init_lz_block() -> void:
	block_orig_x = spawn_x
	block_orig_y = spawn_y
	block_frame = (subtype >> 4) & 3
	block_type = subtype & 0x0F
	match block_frame:
		0:
			block_half_w = 16
			block_half_h = 16
		1:
			block_half_w = 32
			block_half_h = 12
		2, 3:
			block_half_w = 16
			block_half_h = 16
	active_width = block_half_w
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.lz_block_texture(block_frame)
	# LBlk_Main sets the untouched/nudge flag for the delayed sink/rise variants,
	# but deliberately excludes stationary blocks and the water-floating cork.
	block_untouched = block_type != 0 and block_type != 7

func _tick_lz_block() -> void:
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)

	match block_type:
		0:
			pass
		1, 3:
			_tick_block_wait_for_stand(p)
		2, 6:
			_tick_block_sink()
		4:
			_tick_block_rise()
		5:
			# The source changes this variant to sink after a side touch. No final
			# LZ placement uses type 5, but retain the path for debug/source parity.
			pass
		7:
			_tick_block_on_water()

	_tick_block_nudge(p)

	var dx = int(position.x) - old_x
	var dy = int(position.y) - old_y
	var top_y = int(position.y) - block_half_h
	p.move_with_supported_object(record_index, dx, dy, int(position.x) - block_half_w, int(position.x) + block_half_w, top_y)
	var contact = p.resolve_solid_box_contact(int(position.x), int(position.y), block_half_w, block_half_h, true, record_index)
	if block_type == 5 and (contact == SonicPlayer.SOLID_LEFT or contact == SonicPlayer.SOLID_RIGHT):
		block_type = 6
		block_untouched = false

func _tick_block_wait_for_stand(p: SonicPlayer) -> void:
	if block_timer == 0:
		if p.standing_on_object and p.support_record_index == record_index:
			block_timer = 30
		return
	block_timer -= 1
	if block_timer > 0:
		return
	# Type 1 -> 2 (sink), type 3 -> 4 (rise), matching addq.b #1,obSubtype.
	block_type += 1
	block_untouched = false

func _tick_block_sink() -> void:
	position.y += float(block_vel_y) / 256.0
	block_vel_y = GenesisMath.s16(block_vel_y + 8)
	var hit = manager.collision.find_floor_sensor(int(position.x), int(position.y) + block_half_h, true, false)
	var distance = int(hit.get("distance", 0))
	if distance < 0:
		position.y += distance + 1
		block_vel_y = 0
		block_type = 0

func _tick_block_rise() -> void:
	position.y += float(block_vel_y) / 256.0
	block_vel_y = GenesisMath.s16(block_vel_y - 8)
	var hit = manager.collision.find_ceiling_sensor(int(position.x), int(position.y) - block_half_h, false)
	var distance = int(hit.get("distance", 0))
	if distance < 0:
		position.y -= distance
		block_vel_y = 0
		block_type = 0

func _tick_block_on_water() -> void:
	if not manager.water_enabled:
		return
	var delta = manager.water_surface_y - int(position.y)
	if delta == 0:
		return
	var step = clampi(delta, -2, 2)
	position.y += step
	if step < 0:
		var ceiling = manager.collision.find_ceiling_sensor(int(position.x), int(position.y) - block_half_h, false)
		var cd = int(ceiling.get("distance", 0))
		if cd < 0:
			position.y -= cd
	else:
		var floor_hit = manager.collision.find_floor_sensor(int(position.x), int(position.y) + block_half_h, true, false)
		var fd = int(floor_hit.get("distance", 0))
		if fd < 0:
			position.y += fd + 1

func _tick_block_nudge(p: SonicPlayer) -> void:
	if not block_untouched:
		return
	var stood = p.standing_on_object and p.support_record_index == record_index
	if stood:
		block_nudge = mini(0x40, block_nudge + 4)
	elif block_nudge > 0:
		block_nudge = maxi(0, block_nudge - 4)
	else:
		return
	var sine = GenesisMath.sine(block_nudge & 0xFF)
	var offset = (sine * 0x400) >> 16
	position.y = block_orig_y + offset

# -----------------------------------------------------------------------------
# Object $62 - Gargoyle head / fireball
# -----------------------------------------------------------------------------
func _init_gargoyle_head() -> void:
	active_width = 16
	z_index = 40
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.lz_gargoyle_texture(0)
	var rates: Array[int] = [30, 60, 90, 120, 150, 180, 210, 240]
	var rate_index = clampi(subtype & 0x0F, 0, rates.size() - 1)
	gargoyle_delay = rates[rate_index]
	gargoyle_timer = gargoyle_delay

func _tick_gargoyle_head() -> void:
	gargoyle_timer -= 1
	if gargoyle_timer != 0:
		return
	gargoyle_timer = gargoyle_delay
	if not manager.is_world_x_on_screen(int(position.x), 32):
		return
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if int(position.y) < manager.current_screen_y - 32 or int(position.y) >= manager.current_screen_y + viewport_height + 32:
		return
	var fire = LZNativeObject.new()
	fire.name = "LZGargoyleFireball"
	manager.add_child(fire)
	fire.setup_gargoyle_fireball(manager, int(position.x), int(position.y), x_flip)
	manager.transient_objects.append(fire)

func setup_gargoyle_fireball(owner: SonicObjectManager, world_x: int, world_y: int, facing_right: bool) -> void:
	manager = owner
	object_id = 0x62
	gargoyle_fireball = true
	alive = true
	position = Vector2(world_x, world_y + 8)
	x_flip = facing_right
	active_width = 8
	z_index = 30
	sprite = make_sprite("")
	fire_frame = 2
	sprite.texture = SourceObjectArt.lz_gargoyle_texture(fire_frame)
	fire_vel_x = 0x200 if facing_right else -0x200

func _tick_gargoyle_fireball() -> void:
	if (manager.elapsed_frames & 7) == 0:
		fire_frame = 3 if fire_frame == 2 else 2
		sprite.texture = SourceObjectArt.lz_gargoyle_texture(fire_frame)
	position.x += float(fire_vel_x) / 256.0

	var hit: Dictionary
	if fire_vel_x < 0:
		hit = manager.collision.find_left_wall_sensor(int(position.x) - 8, int(position.y), false)
	else:
		hit = manager.collision.find_right_wall_sensor(int(position.x) + 8, int(position.y), false)
	if int(hit.get("distance", 0)) < 0:
		request_delete(false)
		return

	var p = player()
	if p != null and not p.dead and not p.drowning:
		if absi(p.pixel_x() - int(position.x)) <= p.width_radius + 4 and absi(p.pixel_y() - int(position.y)) <= p.height_radius + 4:
			p.apply_hazard_hit(int(position.x))

# -----------------------------------------------------------------------------
# Object $65 - decorative waterfalls / splashes
# -----------------------------------------------------------------------------
func _init_waterfall() -> void:
	waterfall_runtime_palette = []
	active_width = 24
	waterfall_frame = subtype & 0x0F
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.lz_waterfall_texture(clampi(waterfall_frame, 0, 11))
	# Standard waterfall priority 1 is above Sonic but still behind high-priority
	# Plane A. Subtype bit 7 supplies Tile_Prio, except the special $A9 splash
	# clears it until the LZ3 layout mutation occurs.
	var source_high_priority = (subtype & 0x80) != 0 and (subtype & 0x20) == 0
	z_index = 130 if source_high_priority else (70 if waterfall_frame == 9 else 60)
	waterfall_anim_timer = 5

func refresh_palette_cycle(changed_indices: Array[int], runtime_palette: Array[Color]) -> void:
	# PalCycle_LZ changes palette line 3 colors B-E. Object $65 waterfalls are
	# sprites using that same palette line, so their precomposited Godot texture
	# must be rebuilt from the current CRAM colors just as the VDP would display it.
	if object_id != 0x65 or sprite == null or runtime_palette.size() < 64:
		return
	var affects_waterfall := false
	for index in changed_indices:
		if int(index) >= 43 and int(index) <= 46:
			affects_waterfall = true
			break
	if affects_waterfall:
		waterfall_runtime_palette = runtime_palette
		sprite.texture = SourceObjectArt.lz_waterfall_texture(clampi(waterfall_frame, 0, 11), runtime_palette)

func _tick_waterfall() -> void:
	if waterfall_frame != 9:
		return
	if (subtype & 0x40) != 0 and manager.water_enabled:
		# Subtype $49 follows v_waterpos1 and is positioned 16px above the surface.
		position.y = manager.water_surface_y - 16
	if (subtype & 0x20) != 0:
		# WFall_Priority clears Tile_Prio until DLE_LZ3 changes foreground
		# row 2/column 6 to chunk $07, then reveals the hidden splash above it.
		var layout_open = player() != null and player().level != null and player().level.get_chunk_id_at(6, 2) == 0x07
		z_index = 130 if layout_open else 60
	waterfall_anim_timer -= 1
	if waterfall_anim_timer < 0:
		waterfall_anim_timer = 5
		waterfall_frame += 1
		if waterfall_frame > 11:
			waterfall_frame = 9
		if waterfall_runtime_palette.size() >= 64:
			sprite.texture = SourceObjectArt.lz_waterfall_texture(waterfall_frame, waterfall_runtime_palette)
		else:
			sprite.texture = SourceObjectArt.lz_waterfall_texture(waterfall_frame)
