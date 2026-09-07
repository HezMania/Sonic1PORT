class_name LZWaterSurfaceEffect
extends Node2D

# Shared water-surface presentation. Sonic 1 LZ keeps its established source art;
# Sonic 2 CPZ2 uses retail Obj04 frames rendered from obj04_a.bin and the
# "Top of water in HPZ and CNZ" Nemesis stream.

const S2_WATER_SEQUENCE: Array[int] = [
	0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,
	1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,
	2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,
	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,
]

var manager: SonicObjectManager
var alive := true
var frame := 0
var frame_timer := 0
var s2_sequence_index := 0
var use_s2_surface := false
var use_s2_arz_surface := false
var surface_sprites: Array[Sprite2D] = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	use_s2_surface = manager != null and bool(manager.level_definition.get("s2_cpz_water", false))
	use_s2_arz_surface = manager != null and bool(manager.level_definition.get("s2_arz_water", false))
	# ArtTile water surface carries tile priority in both engines.
	z_index = 130
	var viewport_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var surface_count = maxi(2, int(ceil(float(viewport_width) / float(0xC0))))
	for i in range(surface_count):
		var sp = Sprite2D.new()
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = false
		sp.texture = _surface_texture(0)
		add_child(sp)
		surface_sprites.append(sp)

func _surface_texture(wanted_frame: int):
	if use_s2_arz_surface:
		var arz_path = "res://assets/objects/s2_arz/water_surface/%02d.png" % clampi(wanted_frame, 0, 1)
		return load(arz_path) if ResourceLoader.exists(arz_path) else null
	if use_s2_surface:
		var path = "res://assets/objects/s2_cpz/water_surface/%02d.png" % clampi(wanted_frame, 0, 2)
		return load(path) if ResourceLoader.exists(path) else null
	return SourceObjectArt.lz_water_surface_texture(wanted_frame)

func tick() -> void:
	if manager == null or not manager.water_enabled:
		alive = false
		return
	if use_s2_arz_surface:
		# ARZ takes Obj04_Action2: two frames, each held for six VBlanks.
		frame_timer -= 1
		if frame_timer < 0:
			frame_timer = 5
			frame = (frame + 1) & 1
			var arz_texture = _surface_texture(frame)
			for sp in surface_sprites:
				sp.texture = arz_texture
	elif use_s2_surface:
		# Obj04 indexes its 64-byte custom animation table every VBlank.
		frame = S2_WATER_SEQUENCE[s2_sequence_index & 0x3F]
		s2_sequence_index = (s2_sequence_index + 1) & 0x3F
		var texture = _surface_texture(frame)
		for sp in surface_sprites:
			sp.texture = texture
	else:
		frame_timer -= 1
		if frame_timer < 0:
			frame_timer = 7
			frame = (frame + 1) % 3
			var texture = _surface_texture(frame)
			for sp in surface_sprites:
				sp.texture = texture

	var base_x = manager.current_screen_x & 0xFFE0
	for i in range(surface_sprites.size()):
		var source_orig_x = 0x60 + i * 0xC0
		if use_s2_arz_surface:
			# Phase 96: ARZ's obj04_b frames are retained on the 192x192 mapping
			# canvas produced by render_mapping(), whose Genesis object origin is
			# exactly (96,96). Position that origin at Water_Level_1. The previous
			# -8 assumption treated the full canvas like CPZ's cropped surface strip
			# and rendered the visible line about 86 pixels below the gameplay water.
			surface_sprites[i].position = Vector2(base_x + source_orig_x - 0x60, manager.water_surface_y - 0x60)
		elif use_s2_surface:
			# CPZ surface frames are tightly cropped 160x16 strips.
			surface_sprites[i].position = Vector2(base_x + source_orig_x - 0x60, manager.water_surface_y - 8)
		else:
			var flicker = 0x20 if (manager.elapsed_frames & 1) != 0 else 0
			surface_sprites[i].position = Vector2(base_x + source_orig_x + flicker - 0x60, manager.water_surface_y - 3)
