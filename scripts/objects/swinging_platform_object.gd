class_name SwingingPlatformObject
extends GenesisLevelObject

# Object $15 - swinging platforms (GHZ/MZ/SLZ), spiked chain ball in SBZ. Child chain links are native
# Sprite2Ds owned by this object instead of consuming separate OST slots, but
# their positions use the original radius/sine/cosine math. Phase 40 restores
# the source SLZ half-spike platform art/mappings instead of reusing GHZ art.

var platform_sprite: Sprite2D
var link_sprites: Array[Sprite2D] = []
var link_radii: Array[int] = []
var orig_x := 0
var orig_y := 0
var platform_radius := 8
var is_slz := false
var is_sbz := false
var platform_half_width := 24
var platform_half_height := 8

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	var zone = int(manager.level_definition.get("zone", -1)) if manager != null else -1
	is_slz = zone == LevelCatalog.ZONE_SLZ
	is_sbz = zone == LevelCatalog.ZONE_SBZ
	platform_half_width = 32 if is_slz else 24
	platform_half_height = 16 if is_slz else (24 if is_sbz else 8)
	active_width = platform_half_width
	platform_sprite = make_sprite("res://assets/objects/swing_ghz/00.png", 1)
	if is_slz:
		platform_sprite.texture = SourceObjectArt.slz_swing_texture(0)
	elif is_sbz:
		# SBZ replaces the GHZ/MZ platform with Map_BBall + the shared SYZ large
		# spikeball stream. It is a hurt object only, never a standable platform.
		platform_sprite.texture = SourceObjectArt.sbz_swing_texture(0)
	var link_count = subtype & 0x0F
	platform_radius = link_count * 16 + 8
	# Swing_Main creates radii count*16 ... 0, with radius 0 using anchor art.
	for i in range(link_count + 1):
		var radius = (link_count - i) * 16
		var frame = 2 if radius == 0 else 1
		var sp = make_sprite("res://assets/objects/swing_ghz/%02d.png" % frame, -1 if frame == 1 else 0)
		if is_slz:
			sp.texture = SourceObjectArt.slz_swing_texture(frame)
		elif is_sbz:
			sp.texture = SourceObjectArt.sbz_swing_texture(frame)
		link_sprites.append(sp)
		link_radii.append(radius)
	_update_positions(false)

func tick() -> void:
	if not alive:
		return
	_update_positions(not is_sbz)
	var p = player()
	if p == null:
		return
	if is_sbz:
		# Swing_Swinging (routine $C) explicitly bypasses all platform logic.
		p.clear_object_support_for(record_index, true)
		_tick_sbz_hurt_box(p)
		return
	var top_y = int(position.y) - platform_half_height
	p.resolve_platform_top(
		int(position.x) - platform_half_width,
		int(position.x) + platform_half_width,
		top_y,
		record_index
	)
	if is_slz:
		_tick_slz_hurt_box(p)

func _update_positions(carry_player: bool) -> void:
	var old_x = int(position.x)
	var old_y = int(position.y)
	var a = manager.oscillate_1a() & 0xFF
	if x_flip:
		a = (0x80 - a) & 0xFF
	var sn = GenesisMath.sine(a)
	var cs = GenesisMath.cosine(a)
	var px = orig_x + ((cs * platform_radius) >> 8)
	var py = orig_y + ((sn * platform_radius) >> 8)
	position = Vector2(px, py)
	for i in range(link_sprites.size()):
		var radius = link_radii[i]
		var wx = orig_x + ((cs * radius) >> 8)
		var wy = orig_y + ((sn * radius) >> 8)
		link_sprites[i].position = Vector2(wx - px, wy - py)
	if carry_player:
		var p = player()
		if p != null:
			var dx = px - old_x
			var dy = py - old_y
			p.move_with_supported_object(
				record_index, dx, dy,
				px - platform_half_width, px + platform_half_width,
				py - platform_half_height
			)

func _tick_slz_hurt_box(p: SonicPlayer) -> void:
	# col_64x16|col_hurt: 32px horizontal and 8px vertical radii. Sonic
	# standing on the 16px-tall platform remains above this box; touching the
	# half-spike body from the sides/below hurts exactly like the source.
	if p.dead or p.invulnerability_timer > 0:
		return
	if abs(p.pixel_x() - int(position.x)) >= 32 + 9:
		return
	if abs(p.pixel_y() - int(position.y)) >= 8 + p.height_radius:
		return
	p.apply_hazard_hit(int(position.x))

func _tick_sbz_hurt_box(p: SonicPlayer) -> void:
	# col_32x32|col_hurt: 16px radii around the visible 48px spikeball mapping.
	if p.dead or p.invulnerability_timer > 0:
		return
	if abs(p.pixel_x() - int(position.x)) >= 16 + p.width_radius:
		return
	if abs(p.pixel_y() - int(position.y)) >= 16 + p.height_radius:
		return
	p.apply_hazard_hit(int(position.x))
