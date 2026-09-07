class_name GHZBackgroundRenderer
extends Node2D

# Zone background/deformation renderer. GHZ keeps the original scanline-group
# port. Phase 14 adds Marble Zone's separate background plane and the source
# 3/4 horizontal + thresholded vertical parallax foundation.

const SOURCE_WRAP_WIDTH := 8192
const MAX_STRIPS := 32

var texture: Texture2D
var strips: Array[Sprite2D] = []
var bg2_x_fixed = 0
var bg3_x_fixed = 0
var cloud1_fixed = 0
var cloud2_fixed = 0
var cloud3_fixed = 0
var level: GHZLevelData
var mode = "none"
var lz_water_surface_y := -0x10000

# Phase 72 GHZ background palette path. The background layout/pattern pixels are
# static; PalCycle_GHZ only changes CRAM. Store source palette indices in R8 and
# update a 64x1 palette texture, avoiding an 8192x256 RGBA upload every six VBlanks.
var ghz_index_texture: ImageTexture
var ghz_palette_image: Image
var ghz_palette_texture: ImageTexture
var ghz_palette_material: ShaderMaterial

# MZ uses the original Deform_MZ 16-pixel H-scroll bands. The Sonic 2 proof
# retains the older root-plane path separately so Phase 64 remains isolated.
var mz_roots: Array[Node2D] = []
var mz_strips: Array[Sprite2D] = []
var mz_chunk_cache: Dictionary = {}
var mz_art_range_patch_cache: Dictionary = {}
var mz_plane_width = 0
var mz_plane_height = 0
var mz_bg1_x_fixed = 0
var mz_bg2_x_fixed = 0
var mz_bg3_x_fixed = 0
var mz_last_camera_x = 0
var mz_scroll_initialized := false

# Phase 87 retail EHZ Plane B. EHZ uses a 512x256 VRAM plane with per-scanline
# horizontal scroll and no vertical BG camera movement in one-player mode.
var s2_ehz_plane_texture: ImageTexture
var s2_ehz_plane_image: Image
var s2_ehz_strips: Array[Sprite2D] = []
var s2_ehz_plane_width := 0
var s2_ehz_plane_height := 0
var s2_ehz_hscroll: Array[int] = []
var s2_ehz_vint_counter := 0
var s2_ehz_ripple_phase := 0
var s2_htz_cloud_counter := 0
# Phase 109 retail Dynamic_HTZ mountain DMA source. PatchHTZTiles expands the
# source cliff art into a sparse low-RAM image; Dynamic_HTZ selects six $80-byte
# pieces from that RAM image as CameraX advances and writes them to tiles $500-$517.
var s2_htz_mountain_ram := PackedByteArray()
var s2_htz_mountain_dma_offsets := PackedByteArray()
var s2_htz_mountain_key := -1
var s2_ehz_art_range_patch_cache: Dictionary = {}
const S2_EHZ_MAX_STRIPS := 96
const S2_EHZ_RIPPLE: Array[int] = [
	1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,
	2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3,
	1,2,1,3,1,2,2,1,2,3,1,2,1,2,0,0,
	2,0,3,2,2,3,2,2,1,3,0,0,1,0,1,3,1,2
]

# Phase 95/96 retail Aquatic Ruin one-player SwScrl_ARZ row deformation.
const S2_ARZ_ROW_HEIGHTS: Array[int] = [0xB0,0x70,0x30,0x60,0x15,0x0C,0x0E,0x06,0x0C,0x1F,0x30,0xC0,0xF0,0xF0,0xF0,0xF0]
const S2_ARZ_ROW_NUMERATORS: Array[int] = [0,0,0,1,3,4,5,6,7,8,9,0,0,0,0,0]
var s2_arz_bg_x := 0
var s2_arz_initialized := false
# Phase 127 SwScrl_WFZ keeps three persistent 16.16 cloud-layer positions.
var s2_wfz_cloud_large_fixed := 0
var s2_wfz_cloud_medium_fixed := 0
var s2_wfz_cloud_small_fixed := 0
var s2_wfz_cloud_initialized := false
# Phase 132 retail DEZ star-band scroll state. TempArray_LayerDef holds 36
# independent word positions; most increment by small integer speeds each frame.
var s2_dez_layer_x: Array[int] = []
const S2_DEZ_ROW_HEIGHTS: Array[int] = [0x80,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,3,5,8,0x10,0x80,0x80,0x80]
const S2_DEZ_STAR_SPEEDS: Array[int] = [3,2,4,1,2,4,3,4,2,6,3,4,1,2,4,3,2,3,4,1,3,4,2]

# Phase 111 retail Mystic Cave one-player SwScrl_MCZ. The 24 source row
# heights sum to exactly $200 scanlines and are paired with the authored
# TempArray_LayerDef X fractions reconstructed from the 68000 assignments.
const S2_MCZ_ROW_HEIGHTS: Array[int] = [0x25,0x17,0x12,7,7,2,2,0x30,0x0D,0x13,0x20,0x40,0x20,0x13,0x0D,0x30,2,2,7,7,0x20,0x12,0x17,0x25]
const S2_MCZ_ROW_NUMERATORS: Array[int] = [9,8,7,5,4,3,2,1,5,7,8,9,8,7,5,1,2,3,4,5,6,7,8,9]

# REV01 SYZ uses a 33-entry, 16-pixel-band horizontal scroll buffer.  Rather
# than duplicating the whole background plane for every band, Phase 26 renders
# the source plane once into a repeatable texture and exposes only the visible
# 16-pixel slices through these sprites.
var syz_plane_texture: Texture2D
var syz_plane_image: Image
var syz_strips: Array[Sprite2D] = []
var syz_plane_width := 0
var syz_plane_height := 0
var syz_repeat_chunks := Vector2i.ZERO

# REV01 SLZ uses a 68-word, 16-pixel-band parallax table: 28 star bands,
# 5 distant-building bands, 5 near-building bands, then 30 lower bands.
var slz_plane_texture: Texture2D
var slz_plane_image: Image
var slz_strips: Array[Sprite2D] = []
var slz_plane_width := 0
var slz_plane_height := 0
var slz_repeat_chunks := Vector2i.ZERO

# REV01 SBZ1 uses 16-pixel deformation bands while SBZ2 uses a uniform
# 1/4-X, 1/8-Y background. Both consume the exact source background plane.
var sbz_plane_texture: Texture2D
var sbz_plane_image: Image
var sbz_strips: Array[Sprite2D] = []
var sbz_plane_width := 0
var sbz_plane_height := 0
var sbz_repeat_chunks := Vector2i.ZERO
var sbz_art_range_patch_cache: Dictionary = {}

# REV01 LZ uses per-scanline background ripple at/below v_waterpos1.
var lz_plane_texture: Texture2D
var lz_plane_image: Image
var lz_strips: Array[Sprite2D] = []
var lz_plane_width := 0
var lz_plane_height := 0
var lz_repeat_chunks := Vector2i.ZERO
var lz_deform_accum := 0
var background_palette_patch_cache: Dictionary = {}
const LZ_WOBBLE_BASE: Array[int] = [
	0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,
	2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,
	2,2,2,2,2,2,1,1,1,1,1,0,0,0,0,0,
	0,-1,-1,-1,-1,-1,-2,-2,-2,-2,-2,-3,-3,-3,-3,-3,
	-3,-3,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,
	-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-3,
	-3,-3,-3,-3,-3,-3,-2,-2,-2,-2,-2,-1,-1,-1,-1,-1,
]

func setup(level_data: GHZLevelData = null) -> void:
	level = level_data
	texture = null
	mode = "none" if level == null else String(level.definition.get("background_mode", "none"))
	for child in get_children():
		child.queue_free()
	strips.clear()
	mz_roots.clear()
	mz_strips.clear()
	mz_chunk_cache.clear()
	mz_art_range_patch_cache.clear()
	mz_plane_width = 0
	mz_plane_height = 0
	mz_bg1_x_fixed = 0
	mz_bg2_x_fixed = 0
	mz_bg3_x_fixed = 0
	mz_last_camera_x = 0
	mz_scroll_initialized = false
	s2_ehz_strips.clear()
	s2_ehz_plane_texture = null
	s2_ehz_plane_image = null
	s2_ehz_plane_width = 0
	s2_ehz_plane_height = 0
	s2_ehz_hscroll.clear()
	s2_ehz_vint_counter = 0
	s2_ehz_ripple_phase = 0
	s2_htz_cloud_counter = 0
	s2_htz_mountain_ram = PackedByteArray()
	s2_htz_mountain_dma_offsets = PackedByteArray()
	s2_htz_mountain_key = -1
	s2_ehz_art_range_patch_cache.clear()
	s2_arz_bg_x = 0
	s2_arz_initialized = false
	s2_wfz_cloud_large_fixed = 0
	s2_wfz_cloud_medium_fixed = 0
	s2_wfz_cloud_small_fixed = 0
	s2_wfz_cloud_initialized = false
	s2_dez_layer_x.clear()
	syz_strips.clear()
	syz_plane_texture = null
	syz_plane_image = null
	syz_plane_width = 0
	syz_plane_height = 0
	syz_repeat_chunks = Vector2i.ZERO
	slz_strips.clear()
	slz_plane_texture = null
	slz_plane_image = null
	slz_plane_width = 0
	slz_plane_height = 0
	slz_repeat_chunks = Vector2i.ZERO
	sbz_strips.clear()
	sbz_plane_texture = null
	sbz_plane_image = null
	sbz_plane_width = 0
	sbz_plane_height = 0
	sbz_repeat_chunks = Vector2i.ZERO
	sbz_art_range_patch_cache.clear()
	lz_strips.clear()
	lz_plane_texture = null
	lz_plane_image = null
	lz_plane_width = 0
	lz_plane_height = 0
	lz_repeat_chunks = Vector2i.ZERO
	lz_deform_accum = 0
	background_palette_patch_cache.clear()
	ghz_index_texture = null
	ghz_palette_image = null
	ghz_palette_texture = null
	ghz_palette_material = null
	visible = mode == "ghz" or mode == "mz" or mode == "syz" or mode == "slz" or mode == "sbz" or mode == "lz" or mode == "s2test" or mode == "s2cpz" or mode == "s2arz" or mode == "s2cnz" or mode == "s2htz" or mode == "s2mcz" or mode == "s2ooz" or mode == "s2mtz" or mode == "s2scz" or mode == "s2wfz" or mode == "s2dez"
	if mode == "ghz":
		_setup_ghz()
	elif mode == "syz":
		_setup_syz()
	elif mode == "slz":
		_setup_slz()
	elif mode == "sbz":
		_setup_sbz()
	elif mode == "lz":
		_setup_lz()
	elif mode == "mz":
		_setup_mz()
	elif mode == "s2test":
		_setup_s2test()
	elif mode == "s2cpz":
		# CPZ uses the same indexed/raster-run renderer as EHZ, but caches a
		# six-chunk x seven-row source repeat for the two-section SwScrl_CPZ path.
		_setup_s2test()
	elif mode == "s2arz":
		# ARZ uses the same batched indexed-strip draw path but samples a much
		# wider prebuilt source plane according to SwScrl_ARZ's 16 row bands.
		_setup_s2test()
	elif mode == "s2cnz":
		# CNZ uses the same indexed Plane-B cache with its source ten-layer
		# SwScrl_CNZ row model and retail 16-line ripple band.
		_setup_s2test()
	elif mode == "s2htz":
		# Hill Top shares the indexed S2 Plane-B path. Keep all 16 source rows in
		# the cache because the authored background is taller than EHZ/CNZ.
		_setup_s2test()
		s2_htz_mountain_ram = FileAccess.get_file_as_bytes("res://data/s1/s2test/s2_htz_mountain_ram.bin") if FileAccess.file_exists("res://data/s1/s2test/s2_htz_mountain_ram.bin") else PackedByteArray()
		s2_htz_mountain_dma_offsets = FileAccess.get_file_as_bytes("res://data/s1/s2test/s2_htz_mountain_dma_offsets.bin") if FileAccess.file_exists("res://data/s1/s2test/s2_htz_mountain_dma_offsets.bin") else PackedByteArray()
	elif mode == "s2mcz":
		# MCZ Plane B is a source-authored four-chunk-wide by four-row $200px
		# repeat. SwScrl_MCZ selects among 24 horizontal bands inside that repeat.
		_setup_s2test()
	elif mode == "s2ooz":
		# Oil Ocean uses the shared indexed S2 Plane-B path. Cache one complete
		# six-chunk horizontal repeat and four rows for SwScrl_OOZ's cloud/oil bands.
		_setup_s2test()
	elif mode == "s2mtz":
		# Metropolis uses InitCam_Std and one uniform SwScrl_MTZ value.
		_setup_s2test()
	elif mode == "s2scz":
		# Sky Chase repeats the same WFZ/SCZ Plane-B through a uniform scroll.
		_setup_s2test()
	elif mode == "s2wfz":
		# Wing Fortress uses the entire authored 128x16 Plane-B layout.
		_setup_s2test()
	elif mode == "s2dez":
		# Death Egg uses the full interleaved Plane-B source and a 35-band star scroll.
		_setup_s2test()

func _setup_ghz() -> void:
	# Phase 72 replaces the old precomposited PNG with the exact source-layout
	# palette-index image generated from GHZ Map16/Map256/8x8 data. This keeps
	# background reflections on the same PalCycle_GHZ CRAM entries as waterfalls.
	var index_path := "res://data/s1/generated/ghz_background_indices.bin"
	var index_bytes := FileAccess.get_file_as_bytes(index_path) if FileAccess.file_exists(index_path) else PackedByteArray()
	if index_bytes.size() == SOURCE_WRAP_WIDTH * 256:
		var shader = load("res://scripts/render/genesis_index_palette.gdshader")
		if shader != null:
			var index_image := Image.create_from_data(SOURCE_WRAP_WIDTH, 256, false, Image.FORMAT_R8, index_bytes)
			ghz_index_texture = ImageTexture.create_from_image(index_image)
			texture = ghz_index_texture
			_ensure_index_palette_material(shader)
	if texture == null:
		# Defensive fallback only; the generated index stream is validated in the package.
		texture = load("res://assets/ghz_background.png")
	for i in range(MAX_STRIPS):
		var sprite = Sprite2D.new()
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		if ghz_palette_material != null:
			sprite.material = ghz_palette_material
		sprite.visible = false
		sprite.z_index = -100
		add_child(sprite)
		strips.append(sprite)

func _ensure_index_palette_material(shader_override = null) -> void:
	if ghz_palette_material != null and ghz_palette_texture != null and ghz_palette_image != null:
		_update_ghz_palette_texture()
		return
	var shader = shader_override if shader_override != null else load("res://scripts/render/genesis_index_palette.gdshader")
	if shader == null:
		return
	ghz_palette_image = Image.create_empty(64, 1, false, Image.FORMAT_RGBA8)
	ghz_palette_texture = ImageTexture.create_from_image(ghz_palette_image)
	ghz_palette_material = ShaderMaterial.new()
	ghz_palette_material.shader = shader
	ghz_palette_material.set_shader_parameter("genesis_palette", ghz_palette_texture)
	_update_ghz_palette_texture()

func _update_ghz_palette_texture() -> void:
	if ghz_palette_image == null or ghz_palette_texture == null or level == null or level.palette.size() < 64:
		return
	for i in range(64):
		ghz_palette_image.set_pixel(i, 0, level.palette[i])
	ghz_palette_texture.update(ghz_palette_image)

func _setup_s2test() -> void:
	if level == null or level.background_width <= 0 or level.background_height <= 0:
		return
	# EHZ can be represented by the resident 512x256 Plane-B window because its
	# one-player BG Y is fixed and the source repeats every four native chunks.
	# CPZ's streamer uses two independent X camera sections and seven authored
	# 128px background rows. Cache one complete six-chunk horizontal repeat and
	# all seven authored rows so SwScrl_CPZ can sample the real source instead of
	# the old Phase-90 half-speed whole-plane approximation.
	if mode == "s2cpz":
		s2_ehz_plane_width = 6 * 128
		s2_ehz_plane_height = 7 * 128
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	elif mode == "s2arz":
		s2_ehz_plane_width = int(level.definition.get("s2_background_index_width", 16384))
		s2_ehz_plane_height = int(level.definition.get("s2_background_index_height", 1536))
		var index_rel := String(level.definition.get("s2_background_indices", ""))
		var index_path := "res://data/s1/" + index_rel
		var index_bytes := FileAccess.get_file_as_bytes(index_path) if not index_rel.is_empty() and FileAccess.file_exists(index_path) else PackedByteArray()
		if index_bytes.size() == s2_ehz_plane_width * s2_ehz_plane_height:
			s2_ehz_plane_image = Image.create_from_data(s2_ehz_plane_width, s2_ehz_plane_height, false, Image.FORMAT_R8, index_bytes)
		else:
			push_error("Phase 95/96: ARZ background index plane is missing or the wrong size: %s" % index_path)
			s2_ehz_plane_image = null
	elif mode == "s2htz":
		s2_ehz_plane_width = 512
		s2_ehz_plane_height = 16 * 128
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	elif mode == "s2mcz":
		s2_ehz_plane_width = 4 * 128
		s2_ehz_plane_height = 4 * 128
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	elif mode == "s2ooz":
		s2_ehz_plane_width = 6 * 128
		s2_ehz_plane_height = 4 * 128
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	elif mode == "s2mtz":
		# MTZ_1 Plane B is authored as an exact nine-chunk horizontal by four-row
		# repeat (the 128-column layout repeats that motif until its end guards).
		s2_ehz_plane_width = 9 * 128
		s2_ehz_plane_height = 4 * 128
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	elif mode == "s2wfz":
		s2_ehz_plane_width = 128 * 128
		s2_ehz_plane_height = 16 * 128
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	elif mode == "s2dez":
		# DEZ's authored Plane-B data occupies only 36 chunk columns by six
		# rows. The level camera never samples beyond that ($1000 max X +
		# viewport < 36*$80), so do not allocate/upload a 16384x2048 R8
		# texture full of unused zero chunks on every direct level entry.
		s2_ehz_plane_width = 36 * 128
		s2_ehz_plane_height = 6 * 128
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	else:
		s2_ehz_plane_width = 512
		s2_ehz_plane_height = 256
		s2_ehz_plane_image = _build_s2_ehz_plane_index_image()
	if s2_ehz_plane_image == null:
		return
	s2_ehz_plane_texture = ImageTexture.create_from_image(s2_ehz_plane_image)
	_ensure_index_palette_material()
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	s2_ehz_hscroll.resize(maxi(224, viewport_height + 1))
	s2_ehz_hscroll.fill(0)
	# Hotfix 1: do not allocate one CanvasItem per scanline. SwScrl_EHZ has
	# long runs with identical H-scroll values; a 96-item pool is enough for
	# every source-shaped run while cutting the normal frame from 224 draw
	# items/property updates to roughly 20-62.
	for i in range(S2_EHZ_MAX_STRIPS):
		var sprite := Sprite2D.new()
		sprite.name = "S2EHZScanline_%03d" % i
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture = s2_ehz_plane_texture
		if ghz_palette_material != null:
			sprite.material = ghz_palette_material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.visible = false
		sprite.z_index = -100
		add_child(sprite)
		s2_ehz_strips.append(sprite)

func _build_s2_ehz_plane_index_image() -> Image:
	if level == null:
		return null
	var chunk_size := level.chunk_pixel_size()
	if chunk_size != 128:
		return null
	var image := Image.create_empty(s2_ehz_plane_width, s2_ehz_plane_height, false, Image.FORMAT_R8)
	# Sky Chase/WFZ use palette-line-2 sky for empty Plane-B cells. DEZ uses
	# black behind its stars. Encode DEZ with an *opaque* known-black CRAM entry
	# (line 1, colour 1 = combined index 17) rather than transparent index 0 so
	# the starfield cannot reveal a stale/blue viewport clear behind the strips.
	# Authored nonzero DEZ pixels (including the blue/white horizon) are preserved.
	var plane_clear_index: int = 32 if mode in ["s2scz", "s2wfz"] else (17 if mode == "s2dez" else 0)
	image.fill(Color(float(plane_clear_index) / 255.0, 0, 0, 1))
	var chunks_x := int(s2_ehz_plane_width / chunk_size)
	var chunks_y := int(s2_ehz_plane_height / chunk_size)
	var blocks := level.blocks_per_chunk()
	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var chunk_id := level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset := level.chunk_data_offset(chunk_id)
			for by in range(blocks):
				for bx in range(blocks):
					var off := chunk_offset + (by * blocks + bx) * 2
					if off + 1 >= level.chunks.size():
						continue
					var word := (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					_draw_mz_block_indices(image, word, cx * chunk_size + bx * 16, cy * chunk_size + by * 16)
	return image

func _setup_mz() -> void:
	if level == null or level.background_width <= 0 or level.background_height <= 0:
		return
	var background_chunk_size = level.chunk_pixel_size() if mode == "s2test" else 256
	mz_plane_width = level.background_width * background_chunk_size
	mz_plane_height = level.background_height * background_chunk_size

	if mode == "s2test":
		# Preserve Phase 64's deliberately simple Sonic 2 proof renderer.
		for copy in range(-1, 2):
			var root = Node2D.new()
			root.name = "S2TestBackground_%d" % copy
			root.z_index = -100
			root.set_meta("copy", copy)
			add_child(root)
			mz_roots.append(root)
			for cy in range(level.background_height):
				for cx in range(level.background_width):
					var chunk_id = level.get_background_chunk_id_at(cx, cy)
					if chunk_id == 0:
						continue
					var sp = Sprite2D.new()
					sp.centered = false
					sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					sp.texture = _mz_chunk_texture(chunk_id)
					sp.position = Vector2(cx * background_chunk_size, cy * background_chunk_size)
					root.add_child(sp)
		return

	# Deform_MZ changes Plane B's H-scroll every 16 scanlines. Keep a small
	# visible-region sprite pool whose regions point directly at the cached
	# source chunk textures. This preserves Phase 59 animated-torch texture
	# updates without flattening/uploading the full 5-11 MiB background plane.
	var viewport_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var vertical_segments = int(ceil(float(viewport_height + 15) / 16.0)) + 2
	var horizontal_segments = int(ceil(float(viewport_width + 255) / 256.0)) + 2
	var strip_count = vertical_segments * horizontal_segments
	for i in range(strip_count):
		var sprite = Sprite2D.new()
		sprite.name = "MZBandSegment_%03d" % i
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
		sprite.z_index = -100
		add_child(sprite)
		mz_strips.append(sprite)


func _setup_lz() -> void:
	if level == null or level.background_width <= 0 or level.background_height <= 0:
		return
	lz_repeat_chunks = _background_repeat_period()
	lz_plane_width = lz_repeat_chunks.x * 256
	lz_plane_height = lz_repeat_chunks.y * 256
	lz_plane_image = _build_background_repeat_index_image(lz_repeat_chunks)
	if lz_plane_image == null:
		return
	lz_plane_texture = ImageTexture.create_from_image(lz_plane_image)
	_ensure_index_palette_material()
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	for i in range(viewport_height + 1):
		var sprite := Sprite2D.new()
		sprite.name = "LZScanline_%03d" % i
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture = lz_plane_texture
		if ghz_palette_material != null:
			sprite.material = ghz_palette_material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.visible = false
		sprite.z_index = -100
		add_child(sprite)
		lz_strips.append(sprite)

func _setup_syz() -> void:
	if level == null or level.background_width <= 0 or level.background_height <= 0:
		return
	syz_repeat_chunks = _background_repeat_period()
	syz_plane_width = syz_repeat_chunks.x * 256
	syz_plane_height = syz_repeat_chunks.y * 256
	syz_plane_image = _build_background_repeat_index_image(syz_repeat_chunks)
	if syz_plane_image == null:
		return
	syz_plane_texture = ImageTexture.create_from_image(syz_plane_image)
	_ensure_index_palette_material()
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var strip_count := int(ceil(float(viewport_height + 15) / 16.0)) + 1
	for i in range(strip_count):
		var sprite := Sprite2D.new()
		sprite.name = "SYZBand_%02d" % i
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture = syz_plane_texture
		if ghz_palette_material != null:
			sprite.material = ghz_palette_material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.visible = false
		sprite.z_index = -100
		add_child(sprite)
		syz_strips.append(sprite)

func _setup_slz() -> void:
	if level == null or level.background_width <= 0 or level.background_height <= 0:
		return
	slz_repeat_chunks = _background_repeat_period()
	slz_plane_width = slz_repeat_chunks.x * 256
	slz_plane_height = slz_repeat_chunks.y * 256
	slz_plane_image = _build_background_repeat_index_image(slz_repeat_chunks)
	if slz_plane_image == null:
		return
	slz_plane_texture = ImageTexture.create_from_image(slz_plane_image)
	_ensure_index_palette_material()
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var strip_count = int(ceil(float(viewport_height + 15) / 16.0)) + 1
	for i in range(strip_count):
		var sprite = Sprite2D.new()
		sprite.name = "SLZBand_%02d" % i
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture = slz_plane_texture
		if ghz_palette_material != null:
			sprite.material = ghz_palette_material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.visible = false
		sprite.z_index = -100
		add_child(sprite)
		slz_strips.append(sprite)

func _setup_sbz() -> void:
	if level == null or level.background_width <= 0 or level.background_height <= 0:
		return

	# Phase 63: both retail SBZ background layouts are exact repeating chunk
	# patterns (REV01 SBZ1 = 5x2 chunks, SBZ2/FZ = 3x2). Keep only the
	# minimal source-authored period instead of flattening the full 30x2 or
	# 60x6 layout. This makes the original animated smoke VRAM slots cheap to
	# patch without reintroducing Phase 59-style large texture updates.
	sbz_repeat_chunks = _sbz_background_repeat_period()
	if sbz_repeat_chunks.x <= 0 or sbz_repeat_chunks.y <= 0:
		return
	sbz_plane_width = sbz_repeat_chunks.x * 256
	sbz_plane_height = sbz_repeat_chunks.y * 256
	sbz_plane_image = _build_background_repeat_index_image(sbz_repeat_chunks)
	if sbz_plane_image == null:
		return
	sbz_plane_texture = ImageTexture.create_from_image(sbz_plane_image)
	_ensure_index_palette_material()
	sbz_art_range_patch_cache.clear()

	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var strip_count = int(ceil(float(viewport_height + 15) / 16.0)) + 1
	for i in range(strip_count):
		var sprite = Sprite2D.new()
		sprite.name = "SBZBand_%02d" % i
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture = sbz_plane_texture
		if ghz_palette_material != null:
			sprite.material = ghz_palette_material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.visible = false
		sprite.z_index = -100
		add_child(sprite)
		sbz_strips.append(sprite)

func _sbz_background_repeat_period() -> Vector2i:
	return _background_repeat_period()

func _background_repeat_period() -> Vector2i:
	if level == null:
		return Vector2i.ZERO
	var width = level.background_width
	var height = level.background_height
	var period_x = width
	var period_y = height
	for candidate_x in range(1, width + 1):
		if width % candidate_x != 0:
			continue
		var matches_x = true
		for y in range(height):
			for x in range(width):
				if level.get_background_chunk_id_at(x, y) != level.get_background_chunk_id_at(x % candidate_x, y):
					matches_x = false
					break
			if not matches_x:
				break
		if matches_x:
			period_x = candidate_x
			break
	for candidate_y in range(1, height + 1):
		if height % candidate_y != 0:
			continue
		var matches_y = true
		for y in range(height):
			for x in range(width):
				if level.get_background_chunk_id_at(x, y) != level.get_background_chunk_id_at(x, y % candidate_y):
					matches_y = false
					break
			if not matches_y:
				break
		if matches_y:
			period_y = candidate_y
			break
	return Vector2i(period_x, period_y)

func _build_background_repeat_index_image(period: Vector2i) -> Image:
	if level == null or period.x <= 0 or period.y <= 0:
		return null
	var image = Image.create_empty(period.x * 256, period.y * 256, false, Image.FORMAT_R8)
	image.fill(Color(0, 0, 0, 1))
	for cy in range(period.y):
		for cx in range(period.x):
			var chunk_id = level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset = (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
			for by in range(16):
				for bx in range(16):
					var off = chunk_offset + (by * 16 + bx) * 2
					if off + 1 >= level.chunks.size():
						continue
					var word = (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					_draw_mz_block_indices(image, word, cx * 256 + bx * 16, cy * 256 + by * 16)
	return image

func _build_background_repeat_image(period: Vector2i) -> Image:
	if level == null or period.x <= 0 or period.y <= 0:
		return null
	var image := Image.create_empty(period.x * 256, period.y * 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for cy in range(period.y):
		for cx in range(period.x):
			var chunk_id := level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset := (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
			for by in range(16):
				for bx in range(16):
					var off := chunk_offset + (by * 16 + bx) * 2
					if off + 1 >= level.chunks.size():
						continue
					var word := (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					_draw_mz_block(image, word, cx * 256 + bx * 16, cy * 256 + by * 16)
	return image

func _build_sbz_repeat_image() -> Image:
	if level == null or sbz_repeat_chunks.x <= 0 or sbz_repeat_chunks.y <= 0:
		return null
	var image = Image.create_empty(sbz_repeat_chunks.x * 256, sbz_repeat_chunks.y * 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for cy in range(sbz_repeat_chunks.y):
		for cx in range(sbz_repeat_chunks.x):
			var chunk_id = level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset = (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
			for by in range(16):
				for bx in range(16):
					var off = chunk_offset + (by * 16 + bx) * 2
					if off + 1 >= level.chunks.size():
						continue
					var word = (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					_draw_mz_block(image, word, cx * 256 + bx * 16, cy * 256 + by * 16)
	return image

func _build_background_plane_texture() -> Texture2D:
	if level == null or level.background_width <= 0 or level.background_height <= 0:
		return null
	var plane_width := level.background_width * 256
	var plane_height := level.background_height * 256
	var image := Image.create_empty(plane_width, plane_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for cy in range(level.background_height):
		for cx in range(level.background_width):
			var chunk_id := level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset := (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
			for by in range(16):
				for bx in range(16):
					var off := chunk_offset + (by * 16 + bx) * 2
					if off + 1 >= level.chunks.size():
						continue
					var word := (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					_draw_mz_block(image, word, cx * 256 + bx * 16, cy * 256 + by * 16)
	return ImageTexture.create_from_image(image)

func reset() -> void:
	bg2_x_fixed = 0
	bg3_x_fixed = 0
	cloud1_fixed = 0
	cloud2_fixed = 0
	cloud3_fixed = 0
	mz_bg1_x_fixed = 0
	mz_bg2_x_fixed = 0
	mz_bg3_x_fixed = 0
	mz_last_camera_x = 0
	mz_scroll_initialized = false
	s2_ehz_vint_counter = 0
	s2_ehz_ripple_phase = 0
	for i in range(s2_ehz_hscroll.size()):
		s2_ehz_hscroll[i] = 0
	lz_deform_accum = 0

func set_lz_water_surface(world_y: int) -> void:
	lz_water_surface_y = world_y

func update(camera_model: SonicCamera) -> void:
	if not visible:
		return
	if mode == "mz":
		_update_mz(camera_model)
		return
	if mode == "s2test":
		_update_s2test(camera_model)
		return
	if mode == "s2cpz":
		_update_s2cpz(camera_model)
		return
	if mode == "s2arz":
		_update_s2arz(camera_model)
		return
	if mode == "s2cnz":
		_update_s2cnz(camera_model)
		return
	if mode == "s2htz":
		_update_s2htz(camera_model)
		return
	if mode == "s2mcz":
		_update_s2mcz(camera_model)
		return
	if mode == "s2ooz":
		_update_s2ooz(camera_model)
		return
	if mode == "s2mtz":
		_update_s2mtz(camera_model)
		return
	if mode == "s2scz":
		_update_s2scz(camera_model)
		return
	if mode == "s2wfz":
		_update_s2wfz(camera_model)
		return
	if mode == "s2dez":
		_update_s2dez(camera_model)
		return
	if mode == "lz":
		_update_lz(camera_model)
		return
	if mode == "syz":
		_update_syz(camera_model)
		return
	if mode == "slz":
		_update_slz(camera_model)
		return
	if mode == "sbz":
		_update_sbz(camera_model)
		return
	if mode != "ghz" or texture == null:
		return
	_update_ghz(camera_model)

func _update_mz(camera_model: SonicCamera) -> void:
	# Exact REV01 Deform_MZ presentation path:
	#   BG1 dungeon interior = 3/4 camera delta
	#   BG2 bushes/buildings = 1/2 camera delta
	#   BG3 mountains = 1/4 camera delta
	# plus the five source cloud interpolation bands. MZ's background X
	# positions are 16.16 fixed-point accumulators updated from v_scrshiftx.
	# Retail MZ starts with foreground camera X=0, so reconstructing those
	# accumulators from camera X also keeps checkpoint/debug entry deterministic.
	if mz_strips.is_empty() or mz_plane_width <= 0 or mz_plane_height <= 0:
		return
	var camera_x = int(camera_model.screen_x)
	var camera_y = int(camera_model.screen_y)
	if not mz_scroll_initialized:
		mz_bg1_x_fixed = camera_x * 0xC000
		mz_bg2_x_fixed = camera_x * 0x8000
		mz_bg3_x_fixed = camera_x * 0x4000
		mz_last_camera_x = camera_x
		mz_scroll_initialized = true
	else:
		var delta_x = camera_x - mz_last_camera_x
		mz_bg1_x_fixed += delta_x * 0xC000
		mz_bg2_x_fixed += delta_x * 0x8000
		mz_bg3_x_fixed += delta_x * 0x4000
		mz_last_camera_x = camera_x

	# Deform_MZ starts Plane B at Y=512. After camera Y 456 it follows at
	# exactly 3/4 speed using the 68000's integer (3*difference)>>2 path.
	var bg_y = 512
	if camera_y >= 456:
		bg_y += ((camera_y - 456) * 3) >> 2

	var scroll_buffer = _mz_scroll_buffer(camera_x)
	var y_offset = clampi(bg_y - 512, 0, 0x100)
	var start_band = (y_offset & 0x1F0) >> 4
	var sub_y = bg_y & 0x0F
	var viewport_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))

	for sprite in mz_strips:
		sprite.visible = false

	var pool_index = 0
	var screen_y = 0
	while screen_y < viewport_height:
		var logical_line = sub_y + screen_y
		var band_index = mini(scroll_buffer.size() - 1, start_band + (logical_line >> 4))
		var band_remaining = 16 - (logical_line & 0x0F)
		var source_world_y = posmod(bg_y + screen_y, mz_plane_height)
		var source_chunk_y = source_world_y >> 8
		var source_in_chunk_y = source_world_y & 0xFF
		var vertical_remaining = 256 - source_in_chunk_y
		var segment_h = mini(viewport_height - screen_y, mini(band_remaining, vertical_remaining))
		var source_world_x = posmod(-int(scroll_buffer[band_index]), mz_plane_width)
		var screen_x = 0

		while screen_x < viewport_width:
			var source_chunk_x = source_world_x >> 8
			var source_in_chunk_x = source_world_x & 0xFF
			var segment_w = mini(viewport_width - screen_x, 256 - source_in_chunk_x)
			var chunk_id = level.get_background_chunk_id_at(source_chunk_x, source_chunk_y)
			if chunk_id != 0 and pool_index < mz_strips.size():
				var sprite = mz_strips[pool_index]
				pool_index += 1
				sprite.texture = _mz_chunk_texture(chunk_id)
				sprite.position = Vector2(camera_x + screen_x, camera_y + screen_y)
				sprite.region_rect = Rect2(source_in_chunk_x, source_in_chunk_y, segment_w, segment_h)
				sprite.visible = true
			screen_x += segment_w
			source_world_x = posmod(source_world_x + segment_w, mz_plane_width)

		screen_y += segment_h

func _mz_scroll_buffer(camera_x: int) -> Array[int]:
	var values: Array[int] = []

	# Deform_MZ cloudLoop. This intentionally mirrors the source's swapped
	# 16.16 accumulator and signed DIVS truncation instead of replacing it with
	# a floating-point interpolation.
	var d2 = _mz_s16(-camera_x)
	var d0 = _mz_s16((_mz_s16(d2) >> 2) - d2)
	var increment = _mz_s32(d0 << 3)
	increment = _mz_s16(_mz_divs_trunc(increment, 5))
	increment = _mz_s32(increment << 12)
	var d3 = d2 & 0xFFFF
	d3 = (_mz_s16(d3) >> 1) & 0xFFFF
	for i in range(5):
		values.append(_mz_s16(d3))
		d3 = _mz_swap32(d3)
		d3 = (d3 + increment) & 0xFFFFFFFF
		d3 = _mz_swap32(d3)

	var mountain = -_mz_s16(mz_bg3_x_fixed >> 16)
	for i in range(2):
		values.append(mountain)
	var bushes = -_mz_s16(mz_bg2_x_fixed >> 16)
	for i in range(9):
		values.append(bushes)
	var interior = -_mz_s16(mz_bg1_x_fixed >> 16)
	for i in range(16):
		values.append(interior)
	return values

func _mz_divs_trunc(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0
	var quotient = absi(value) / divisor
	return -int(quotient) if value < 0 else int(quotient)

func _mz_swap32(value: int) -> int:
	value &= 0xFFFFFFFF
	return ((value & 0xFFFF) << 16) | ((value >> 16) & 0xFFFF)

func _mz_s16(value: int) -> int:
	value &= 0xFFFF
	return value - 0x10000 if value >= 0x8000 else value

func _mz_s32(value: int) -> int:
	value &= 0xFFFFFFFF
	return value - 0x100000000 if value >= 0x80000000 else value



func _update_s2test(camera_model: SonicCamera) -> void:
	if s2_ehz_plane_texture == null or s2_ehz_plane_width <= 0 or s2_ehz_plane_height <= 0:
		return
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	_build_s2_ehz_hscroll(int(camera_model.screen_x))

	# Phase 87 originally represented every raster line with its own Sprite2D.
	# That is a faithful data model but an expensive Godot draw model. Merge
	# consecutive lines that share the same source H-scroll into one region.
	# The visual sampling is identical because source Y remains consecutive.
	for sprite in s2_ehz_strips:
		sprite.visible = false
	var pool_index := 0
	var line := 0
	while line < viewport_height and pool_index < s2_ehz_strips.size():
		var scroll_value := int(s2_ehz_hscroll[line]) if line < s2_ehz_hscroll.size() else 0
		var run_end := line + 1
		while run_end < viewport_height:
			var next_scroll := int(s2_ehz_hscroll[run_end]) if run_end < s2_ehz_hscroll.size() else 0
			if next_scroll != scroll_value:
				break
			run_end += 1
		var source_x := posmod(-scroll_value, s2_ehz_plane_width)
		var source_y := line % s2_ehz_plane_height
		var run_height := run_end - line
		# The viewport is 224 high and Plane B is 256 high, so a run does not
		# wrap vertically in the current one-player EHZ source path.
		var sprite := s2_ehz_strips[pool_index]
		pool_index += 1
		sprite.visible = true
		sprite.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		sprite.region_rect = Rect2(source_x, source_y, viewport_width, run_height)
		line = run_end

func _update_s2arz(camera_model: SonicCamera) -> void:
	# Retail SwScrl_ARZ one-player path. InitCam_ARZ uses CameraY-$180 for Act 1
	# and (CameraY-$E0)/2 for Act 2. SwScrl_ARZ then preserves those respective
	# 1:1 and 1:2 vertical rates from Camera_Y_pos_diff.
	# Camera_ARZ_BG_X_pos targets FG_X*$119/$100; Camera_BG_X_pos chases that
	# target by at most $10 pixels per VBlank. Rows 4-11 use the source's
	# 1/10,3/10,...9/10 foreground ratios; rows 1-3 and 12-16 use BG X.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for sprite in s2_ehz_strips:
		sprite.visible = false
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var camera_x := int(camera_model.screen_x)
	var target_bg_x := int((camera_x * 0x119) / 256.0)
	if not s2_arz_initialized:
		s2_arz_bg_x = target_bg_x
		s2_arz_initialized = true
	else:
		s2_arz_bg_x += clampi(target_bg_x - s2_arz_bg_x, -0x10, 0x10)
	var act := clampi(int(level.definition.get("act", 1)), 1, 2) if level != null else 1
	var bg_y := int(camera_model.screen_y) - 0x180 if act == 1 else (int(camera_model.screen_y) - 0xE0) >> 1

	# Determine the source row and the offset inside it for the top scanline,
	# exactly mirroring the subtract-until-borrow loop in SwScrl_ARZ.
	var logical_y := maxi(0, bg_y)
	var row_index := 0
	var row_start := 0
	while row_index < S2_ARZ_ROW_HEIGHTS.size() - 1 and logical_y >= row_start + S2_ARZ_ROW_HEIGHTS[row_index]:
		row_start += S2_ARZ_ROW_HEIGHTS[row_index]
		row_index += 1
	var row_remaining := S2_ARZ_ROW_HEIGHTS[row_index] - (logical_y - row_start)

	var pool_index := 0
	var line := 0
	while line < viewport_height and pool_index < s2_ehz_strips.size():
		var numerator := S2_ARZ_ROW_NUMERATORS[row_index]
		var source_x := s2_arz_bg_x if numerator == 0 else int((camera_x * numerator) / 10.0)
		var source_y := posmod(logical_y, s2_ehz_plane_height)
		var run_height := mini(row_remaining, viewport_height - line)
		run_height = mini(run_height, s2_ehz_plane_height - source_y)
		if run_height <= 0:
			break
		var sprite := s2_ehz_strips[pool_index]
		pool_index += 1
		sprite.visible = true
		sprite.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		sprite.region_rect = Rect2(posmod(source_x, s2_ehz_plane_width), source_y, viewport_width, run_height)
		line += run_height
		logical_y += run_height
		row_remaining -= run_height
		if row_remaining <= 0:
			row_index = mini(row_index + 1, S2_ARZ_ROW_HEIGHTS.size() - 1)
			row_remaining = S2_ARZ_ROW_HEIGHTS[row_index]

func _update_s2cnz(camera_model: SonicCamera) -> void:
	# Retail one-player SwScrl_CNZ. Plane B Y is CameraY/64. sub_D160 builds
	# ten horizontal layers at 64,57,50,43,36,29,22,4,4,8 / 64 of FG X.
	# RowHeights reserves only one 16-line zero-height ripple row at logical Y $80;
	# the final 1/8-speed band starts immediately at $90.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for sprite in s2_ehz_strips:
		sprite.visible = false
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var camera_x := int(camera_model.screen_x)
	var bg_y := int(camera_model.screen_y) >> 6
	s2_ehz_vint_counter = (s2_ehz_vint_counter + 1) & 0xFF
	if (s2_ehz_vint_counter & 7) == 0:
		s2_ehz_ripple_phase = (s2_ehz_ripple_phase - 1) & 0xFFFF
	var numerators: Array[int] = [64,57,50,43,36,29,22,4,4,8]
	if s2_ehz_hscroll.size() < viewport_height:
		s2_ehz_hscroll.resize(viewport_height)
	for line_index in range(viewport_height):
		var logical_y := bg_y + line_index
		var numerator := 8
		var ripple := 0
		if logical_y < 128:
			numerator = numerators[clampi(logical_y >> 4, 0, 7)]
		elif logical_y < 144:
			numerator = numerators[8]
			var ri := (s2_ehz_ripple_phase + (logical_y - 128)) & 0x1F
			ripple = S2_EHZ_RIPPLE[ri]
		else:
			numerator = numerators[9]
		s2_ehz_hscroll[line_index] = ((camera_x * numerator) >> 6) - ripple

	var pool_index := 0
	var line := 0
	while line < viewport_height and pool_index < s2_ehz_strips.size():
		var source_x := int(s2_ehz_hscroll[line])
		var source_y := posmod(bg_y + line, s2_ehz_plane_height)
		var run_end := line + 1
		while run_end < viewport_height:
			if int(s2_ehz_hscroll[run_end]) != source_x:
				break
			if source_y + (run_end - line) >= s2_ehz_plane_height:
				break
			run_end += 1
		var strip := s2_ehz_strips[pool_index]
		pool_index += 1
		strip.visible = true
		strip.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		strip.region_rect = Rect2(posmod(source_x, s2_ehz_plane_width), source_y, viewport_width, run_end - line)
		line = run_end




func _update_s2scz(camera_model: SonicCamera) -> void:
	# SwScrl_SCZ repeats one H-scroll pair over every scanline. Plane B moves
	# +1/2 pixel on every frame with horizontal foreground motion and keeps its
	# initial Y while the camera performs the $1180 downward leg.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for child in s2_ehz_strips:
		child.visible = false
	var viewport_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var strip = s2_ehz_strips[0] as Sprite2D
	strip.visible = true
	strip.position = Vector2(camera_model.screen_x, camera_model.screen_y)
	strip.region_rect = Rect2(posmod(camera_model.s2_scz_bg_x_fixed >> 8, s2_ehz_plane_width), 0, viewport_width, viewport_height)


const S2_WFZ_TRANSITION_SEGMENTS: Array[Vector2i] = [
	Vector2i(0xC0,0),Vector2i(0xC0,0),Vector2i(0x80,0),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x80,4),Vector2i(0x80,4),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0xC0,0),Vector2i(0xC0,0),Vector2i(0x80,0),
]
const S2_WFZ_NORMAL_SEGMENTS: Array[Vector2i] = [
	Vector2i(0xC0,0),Vector2i(0xC0,0),Vector2i(0x80,0),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0x20,8),Vector2i(0x30,12),Vector2i(0x30,16),Vector2i(0xC0,0),Vector2i(0xC0,0),Vector2i(0x80,0),
]

func _update_s2wfz(camera_model: SonicCamera) -> void:
	# Retail SwScrl_WFZ. LevEvents_WFZ targets Plane B at Camera-offset, while
	# TempArray_LayerDef retains three autonomous cloud-layer 16.16 positions.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():return
	for strip in s2_ehz_strips:strip.visible=false
	var viewport_width:=int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height:=int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var bg_x: int = camera_model.s2_wfz_bg_x_pos
	var bg_y: int = camera_model.s2_wfz_bg_y_pos
	if not s2_wfz_cloud_initialized:
		s2_wfz_cloud_large_fixed=bg_x<<16; s2_wfz_cloud_medium_fixed=bg_x<<16; s2_wfz_cloud_small_fixed=bg_x<<16
		s2_wfz_cloud_initialized=true
	s2_wfz_cloud_large_fixed+=0x8000
	s2_wfz_cloud_medium_fixed+=0x4000
	s2_wfz_cloud_small_fixed+=0x2000
	var layer_x:Array[int]=[bg_x,bg_x,s2_wfz_cloud_large_fixed>>16,s2_wfz_cloud_medium_fixed>>16,s2_wfz_cloud_small_fixed>>16]
	var segments:=S2_WFZ_TRANSITION_SEGMENTS if camera_model.screen_x>=0x2700 else S2_WFZ_NORMAL_SEGMENTS
	# The Genesis VDP name table wraps while the level streamer replaces rows.
	# Our native cache contains the full static 16-row Plane-B layout, so applying
	# posmod during the long getaway would visibly replay that whole layout every
	# $800 pixels. Clamp the cache read only in Routine4/getaway while retaining
	# the retail low-11-bit segment selector below.
	var sampled_bg_y: int = bg_y
	if camera_model.dle_routine >= 6:
		sampled_bg_y = clampi(bg_y, 0, maxi(0, s2_ehz_plane_height - viewport_height))
	var logical_y:=posmod(bg_y,0x800)
	var seg_index:=0; var seg_start:=0
	while seg_index<segments.size()-1 and logical_y>=seg_start+segments[seg_index].x:
		seg_start+=segments[seg_index].x; seg_index+=1
	var seg_remaining:=segments[seg_index].x-(logical_y-seg_start)
	var line:=0; var pool:=0
	while line<viewport_height and pool<s2_ehz_strips.size():
		var idx:=clampi(segments[seg_index].y>>2,0,4)
		var source_x:=layer_x[idx]
		var source_y: int = sampled_bg_y + line if camera_model.dle_routine >= 6 else posmod(bg_y + line, s2_ehz_plane_height)
		var run:=mini(seg_remaining,viewport_height-line)
		run=mini(run,s2_ehz_plane_height-source_y)
		if run<=0:break
		var strip:=s2_ehz_strips[pool];pool+=1
		strip.visible=true; strip.position=Vector2(camera_model.screen_x,camera_model.screen_y+line)
		strip.region_rect=Rect2(posmod(source_x,s2_ehz_plane_width),source_y,viewport_width,run)
		line+=run; seg_remaining-=run
		if seg_remaining<=0:
			seg_index=(seg_index+1)%segments.size(); seg_remaining=segments[seg_index].x

func _update_s2dez(camera_model: SonicCamera) -> void:
	# Retail SwScrl_DEZ. Row 0 and the final full-speed rows follow foreground X;
	# the intervening star bands advance independently by their source word rates.
	if s2_ehz_plane_texture == null or s2_ehz_plane_width <= 0 or s2_ehz_plane_height <= 0:
		return
	if s2_dez_layer_x.size() != 36:
		s2_dez_layer_x.resize(36)
		s2_dez_layer_x.fill(0)
	var cam_x: int = camera_model.screen_x
	s2_dez_layer_x[0] = cam_x
	for i in range(S2_DEZ_STAR_SPEEDS.size()):
		s2_dez_layer_x[i + 1] = GenesisMath.s16(int(s2_dez_layer_x[i + 1]) + int(S2_DEZ_STAR_SPEEDS[i]))
	s2_dez_layer_x[24] = GenesisMath.s16(int(s2_dez_layer_x[24]) + 1)
	var slow_word: int = int(s2_dez_layer_x[24]) & 0xFFFF
	s2_dez_layer_x[25] = slow_word >> 1
	s2_dez_layer_x[26] = GenesisMath.s16(int(s2_dez_layer_x[26]) + 3)
	s2_dez_layer_x[27] = GenesisMath.s16(int(s2_dez_layer_x[27]) + 2)
	s2_dez_layer_x[28] = GenesisMath.s16(int(s2_dez_layer_x[28]) + 4)
	s2_dez_layer_x[29] = int((slow_word * 5) >> 3)
	s2_dez_layer_x[30] = int((slow_word * 6) >> 3)
	s2_dez_layer_x[31] = int((slow_word * 7) >> 3)
	s2_dez_layer_x[32] = GenesisMath.s16(int(s2_dez_layer_x[32]) + 1)
	s2_dez_layer_x[33] = cam_x
	s2_dez_layer_x[34] = cam_x
	s2_dez_layer_x[35] = cam_x

	var viewport_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	for strip in s2_ehz_strips:
		strip.visible = false
	# LevelSizeLoad seeds Camera_BG_Y_pos from the already-clamped camera Y
	# before InitCam_Null3. DEZ therefore begins at $C8, not zero. Using the
	# native camera value keeps the black starfield/interior bands aligned from
	# the first rendered frame instead of catching up only after a restart.
	var logical_y: int = camera_model.screen_y
	var row_index: int = 0
	var row_start: int = 0
	while row_index < S2_DEZ_ROW_HEIGHTS.size() - 1 and logical_y >= row_start + S2_DEZ_ROW_HEIGHTS[row_index]:
		row_start += S2_DEZ_ROW_HEIGHTS[row_index]
		row_index += 1
	var row_remaining: int = S2_DEZ_ROW_HEIGHTS[row_index] - (logical_y - row_start)
	var line: int = 0
	var pool: int = 0
	while line < viewport_height and pool < s2_ehz_strips.size():
		var run: int = mini(row_remaining, viewport_height - line)
		var source_y: int = posmod(logical_y + line, s2_ehz_plane_height)
		run = mini(run, s2_ehz_plane_height - source_y)
		if run <= 0:
			break
		var strip: Sprite2D = s2_ehz_strips[pool]
		pool += 1
		strip.visible = true
		strip.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		strip.region_rect = Rect2(posmod(int(s2_dez_layer_x[row_index]), s2_ehz_plane_width), source_y, viewport_width, run)
		line += run
		row_remaining -= run
		if row_remaining <= 0:
			row_index = mini(row_index + 1, S2_DEZ_ROW_HEIGHTS.size() - 1)
			row_remaining = S2_DEZ_ROW_HEIGHTS[row_index]

func _update_s2mtz(camera_model: SonicCamera) -> void:
	# Retail InitCam_Std starts Plane B at CameraX/8, CameraY/4. SwScrl_MTZ
	# integrates later camera deltas at exactly those ratios and writes one
	# identical H-scroll pair for every scanline, so the complete one-player
	# deformation is a single repeating region from the indexed Plane-B cache.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for strip in s2_ehz_strips:
		strip.visible = false
	var viewport_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var source_x: int = int(camera_model.screen_x) >> 3
	var source_y: int = int(camera_model.screen_y) >> 2
	var strip = s2_ehz_strips[0] as Sprite2D
	strip.visible = true
	strip.position = Vector2(camera_model.screen_x, camera_model.screen_y)
	strip.region_rect = Rect2(posmod(source_x, s2_ehz_plane_width), posmod(source_y, s2_ehz_plane_height), viewport_width, viewport_height)


func _update_s2ooz(camera_model: SonicCamera) -> void:
	# Retail one-player SwScrl_OOZ. Camera_BG is initialized to (CameraY/8)+$50
	# and tracks both foreground axes at 1/8 speed. The H-scroll table is emitted
	# backwards from its bottom, mixing base, 1/4, 1/8, 1/16 cloud rates and the
	# 33-line autonomous ripple segment. Store the source H-scroll signs here and
	# sample with -scroll below, matching the Genesis VDP convention.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for sprite in s2_ehz_strips:
		sprite.visible = false
	var viewport_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var source_lines: int = mini(224, viewport_height)
	if source_lines <= 0:
		return
	var camera_x: int = int(camera_model.screen_x)
	var camera_y: int = int(camera_model.screen_y)
	var bg_x: int = camera_x >> 3
	var bg_y: int = (camera_y >> 3) + 0x50
	var base_scroll: int = -bg_x

	# TempArray_LayerDef is decremented once every eight VBlanks.
	s2_ehz_vint_counter = (s2_ehz_vint_counter + 1) & 0xFF
	if (s2_ehz_vint_counter & 7) == 0:
		s2_ehz_ripple_phase = (s2_ehz_ripple_phase - 1) & 0x1F

	var scrolls: Array[int] = []
	scrolls.resize(source_lines)
	scrolls.fill(base_scroll)
	var cursor: int = source_lines - 1

	# d1=(BGY-$50)-$B0; values >=$B0 are clamped to zero before +$DF.
	# DBF makes the actual first run d1+1 lines: 48+CameraY/8 until it reaches 224.
	var y_term: int = maxi(0, bg_y - 0x50)
	var first_count: int = 224 if y_term >= 0xB0 else 48 + y_term
	cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll, first_count)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 3, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 4, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 2, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 4, 7)
	if cursor >= 0:
		for i in range(33):
			if cursor < 0:
				break
			# move.b + ext.w produces a positive signed word for the retail 0..3 table.
			var ripple: int = S2_EHZ_RIPPLE[(s2_ehz_ripple_phase + i) % S2_EHZ_RIPPLE.size()]
			cursor = _s2ooz_write_bottom(scrolls, cursor, ripple, 1)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 3, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 4, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 2, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 4, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll >> 3, 8)
	if cursor >= 0: cursor = _s2ooz_write_bottom(scrolls, cursor, base_scroll, 72)

	# Merge adjacent equal scroll values just like the other S2 indexed renderers.
	# Split at vertical texture wrap so each RegionRect remains contiguous.
	var pool_index: int = 0
	var line: int = 0
	while line < viewport_height and pool_index < s2_ehz_strips.size():
		var canonical_line: int = mini(line, source_lines - 1)
		var scroll_value: int = int(scrolls[canonical_line])
		var source_x: int = posmod(-scroll_value, s2_ehz_plane_width)
		var source_y: int = posmod(bg_y + line, s2_ehz_plane_height)
		var run_end: int = line + 1
		while run_end < viewport_height:
			var next_canonical: int = mini(run_end, source_lines - 1)
			if int(scrolls[next_canonical]) != scroll_value:
				break
			if source_y + (run_end - line) >= s2_ehz_plane_height:
				break
			run_end += 1
		var strip: Sprite2D = s2_ehz_strips[pool_index]
		pool_index += 1
		strip.visible = true
		strip.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		strip.region_rect = Rect2(source_x, source_y, viewport_width, run_end - line)
		line = run_end



func _s2ooz_write_bottom(scrolls: Array[int], cursor: int, scroll_value: int, count: int) -> int:
	var n: int = maxi(0, count)
	var out_cursor: int = cursor
	while n > 0 and out_cursor >= 0:
		scrolls[out_cursor] = scroll_value
		out_cursor -= 1
		n -= 1
	return out_cursor


func _update_s2mcz(camera_model: SonicCamera) -> void:
	# Exact one-player SwScrl_MCZ Act 1 model. Camera_BG_Y is CameraY/3-$140.
	# TempArray_LayerDef contains 24 X rates expressed as tenths of CameraX;
	# SwScrl_MCZ_RowHeights selects the active rate by BG Y and emits $380 words.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for sprite in s2_ehz_strips:
		sprite.visible = false
	var viewport_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var camera_x: int = int(camera_model.screen_x)
	var bg_y: int = int(camera_model.screen_y / 3) - 0x140
	var logical_y: int = posmod(bg_y, 0x200)
	# Retail builds the ten horizontal rates through a fixed-point base:
	#   CameraX << 4; DIVS #$A; EXT.L; << 12
	# and then repeatedly adds that 16.16 value. Preserve the intermediate
	# quotient instead of simplifying to CameraX*n/10, which can differ by a
	# pixel at the source's quantization boundaries. Camera X is non-negative
	# inside MCZ's retail limits, so integer floor is the 68000 DIVS quotient.
	var tenth_base_q4: int = int((camera_x << 4) / 10)

	# Find the first source row band exactly like the subtract-until-borrow loop.
	var row_index: int = 0
	var row_offset: int = logical_y
	while row_index < S2_MCZ_ROW_HEIGHTS.size() - 1 and row_offset >= S2_MCZ_ROW_HEIGHTS[row_index]:
		row_offset -= S2_MCZ_ROW_HEIGHTS[row_index]
		row_index += 1
	var row_remaining: int = S2_MCZ_ROW_HEIGHTS[row_index] - row_offset
	var pool_index: int = 0
	var line: int = 0
	while line < viewport_height and pool_index < s2_ehz_strips.size():
		var numerator: int = S2_MCZ_ROW_NUMERATORS[row_index]
		var layer_x: int = (tenth_base_q4 * numerator) >> 4
		var source_x: int = posmod(layer_x, s2_ehz_plane_width)
		var source_y: int = posmod(bg_y + line, s2_ehz_plane_height)
		var run_height: int = mini(row_remaining, viewport_height - line)
		run_height = mini(run_height, s2_ehz_plane_height - source_y)
		if run_height <= 0:
			break
		var strip: Sprite2D = s2_ehz_strips[pool_index]
		pool_index += 1
		strip.visible = true
		strip.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		strip.region_rect = Rect2(source_x, source_y, viewport_width, run_height)
		line += run_height
		row_remaining -= run_height
		if row_remaining <= 0:
			row_index = (row_index + 1) % S2_MCZ_ROW_HEIGHTS.size()
			row_remaining = S2_MCZ_ROW_HEIGHTS[row_index]

func _update_s2htz_dynamic_mountains(camera_x: int) -> void:
	# Exact one-player Dynamic_HTZ selection. 68000 word operations wrap before
	# DIVU, so preserve the unsigned 16-bit dividend and use its remainder mod $30.
	if level == null or s2_htz_mountain_ram.size() < 0x4980 or s2_htz_mountain_dma_offsets.size() < 96 * 2:
		return
	var neg_x_asr3: int = _mz_s16((-camera_x) & 0xFFFF) >> 3
	var selector_word: int = (((camera_x & 0xFFFF) >> 4) + neg_x_asr3 - 0x10) & 0xFFFF
	var remainder: int = selector_word % 0x30
	if remainder == s2_htz_mountain_key:
		return
	s2_htz_mountain_key = remainder
	# Source offset math after DIVU/SWAP: ((rem&7)*$18)+((rem&$38)>>2)
	# bytes into word_3FD9C, i.e. word index (rem&7)*12 + ((rem&$38)>>3).
	var word_index: int = (remainder & 7) * 12 + ((remainder & 0x38) >> 3)
	for i in range(6):
		var o: int = (word_index + i) * 2
		var source_address: int = (int(s2_htz_mountain_dma_offsets[o]) << 8) | int(s2_htz_mountain_dma_offsets[o + 1])
		var destination: int = (0x500 + i * 4) * GHZLevelData.TILE_BYTES
		for j in range(0x80):
			level.art[destination + j] = s2_htz_mountain_ram[source_address + j]
	# These 24 tiles are background-only. Patch the cached Plane B placements in
	# one texture upload, matching the six source DMA writes without rebuilding it.
	refresh_s2test_art_range(0x500, 0x18)


func _update_s2htz(camera_model: SonicCamera) -> void:
	# Retail one-player SwScrl_HTZ. H-scroll values below are kept in the same
	# sign as the Genesis H-scroll table; sampling therefore uses -scroll. The
	# first $80 scanlines are CameraX/8 in source-space. The lower 96 lines use
	# the exact 16.16 interpolation generated from TempArray_LayerDef+$22, whose
	# autonomous +4/frame phase is what makes the cloud layers drift independently.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for sprite in s2_ehz_strips:
		sprite.visible = false
	var viewport_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var camera_x: int = int(camera_model.screen_x)
	_update_s2htz_dynamic_mountains(camera_x)
	if camera_model.dynamic_event in ["s2_htz1", "s2_htz2"] and camera_model.s2_htz_quake_active:
		# HTZ_Screen_Shake replaces the layered cloud H-scroll with foreground/BG
		# camera words. With Camera_BG_X_offset=0 both converge on CameraX; the BG
		# vertical target is CameraY-Camera_BG_Y_offset.
		var shake_x: int = 0
		var shake_y: int = 0
		if camera_model.s2_htz_visual_shake:
			var si: int = (s2_ehz_vint_counter * 2) % 64
			shake_y = S2_EHZ_RIPPLE[si]
			shake_x = S2_EHZ_RIPPLE[(si + 1) % 64]
		s2_ehz_vint_counter = (s2_ehz_vint_counter + 1) & 0xFF
		var quake_source_x: int = posmod(camera_x + shake_x, s2_ehz_plane_width)
		var quake_bg_y: int = int(camera_model.screen_y) - int(camera_model.s2_htz_bg_y_offset) + shake_y
		var qpool: int = 0
		var qline: int = 0
		while qline < viewport_height and qpool < s2_ehz_strips.size():
			var qsource_y: int = posmod(quake_bg_y + qline, s2_ehz_plane_height)
			var qrun: int = mini(viewport_height - qline, s2_ehz_plane_height - qsource_y)
			var qstrip: Sprite2D = s2_ehz_strips[qpool]
			qpool += 1
			qstrip.visible = true
			qstrip.position = Vector2(camera_model.screen_x, camera_model.screen_y + qline)
			qstrip.region_rect = Rect2(quake_source_x, qsource_y, viewport_width, qrun)
			qline += qrun
		return
	if s2_ehz_hscroll.size() < viewport_height:
		s2_ehz_hscroll.resize(viewport_height)

	# The source counter is a signed 16-bit word and advances by four every VBlank.
	var old_cloud_counter: int = _mz_s16(s2_htz_cloud_counter)
	s2_htz_cloud_counter = (s2_htz_cloud_counter + 4) & 0xFFFF
	var d2: int = _mz_s16((-camera_x) & 0xFFFF)
	d2 = _mz_s16((d2 - old_cloud_counter) & 0xFFFF)
	var d1: int = d2 >> 4
	var delta: int = (d2 >> 1) - (d2 >> 4)
	var q: int = _mz_divs_trunc(delta << 8, 0x70)
	q = _mz_s16(q)
	var step_fixed: int = q << 8
	var base_fixed: int = d1 << 16
	# SwScrl_HTZ has already advanced d3 by 17 interpolation steps when it
	# begins emitting the lower 96 scanlines. Subsequent source additions are
	# +4,+4,+8,+8,+12,+12,+16,+16 steps.
	var lower_lengths: Array[int] = [3,5,7,8,10,15,16,16,16]
	var lower_steps: Array[int] = [17,21,25,33,41,53,65,81,97]
	var lower_scroll: Array[int] = []
	for m in lower_steps:
		lower_scroll.append(_mz_s16((base_fixed + m * step_fixed) >> 16))

	for y in range(viewport_height):
		if y < 128:
			s2_ehz_hscroll[y] = _mz_s16((-camera_x) & 0xFFFF) >> 3
		else:
			var rem: int = y - 128
			var band: int = lower_lengths.size() - 1
			for i in range(lower_lengths.size()):
				if rem < lower_lengths[i]:
					band = i
					break
				rem -= lower_lengths[i]
			s2_ehz_hscroll[y] = lower_scroll[band]

	var bg_y: int = int(camera_model.s2_htz_bg_y_offset) if camera_model.dynamic_event in ["s2_htz1", "s2_htz2"] else 0
	var pool_index: int = 0
	var line: int = 0
	while line < viewport_height and pool_index < s2_ehz_strips.size():
		var scroll_value: int = int(s2_ehz_hscroll[line])
		var source_x: int = posmod(-scroll_value, s2_ehz_plane_width)
		var source_y: int = posmod(bg_y + line, s2_ehz_plane_height)
		var run_end: int = line + 1
		while run_end < viewport_height:
			if int(s2_ehz_hscroll[run_end]) != scroll_value:
				break
			if source_y + (run_end - line) >= s2_ehz_plane_height:
				break
			run_end += 1
		var strip: Sprite2D = s2_ehz_strips[pool_index]
		pool_index += 1
		strip.visible = true
		strip.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		strip.region_rect = Rect2(source_x, source_y, viewport_width, run_end - line)
		line = run_end


func _update_s2cpz(camera_model: SonicCamera) -> void:
	# Retail SwScrl_CPZ. Camera_BG_X_pos advances at 1/8 foreground X,
	# Camera_BG2_X_pos at 1/2 X, and Camera_BG_Y_pos at 1/4 Y. Source row $12
	# is the 16-line ripple seam between those two horizontal camera sections.
	# Keep the Phase-87 performance lesson: equal-scroll scanlines are batched
	# into region runs rather than represented by 224 permanent draw items.
	if s2_ehz_plane_texture == null or s2_ehz_strips.is_empty():
		return
	for sprite in s2_ehz_strips:
		sprite.visible = false
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if s2_ehz_hscroll.size() < viewport_height:
		s2_ehz_hscroll.resize(viewport_height)

	# SwScrl_CPZ decrements TempArray_LayerDef once every eight VBlanks.
	s2_ehz_vint_counter = (s2_ehz_vint_counter + 1) & 0xFF
	if (s2_ehz_vint_counter & 7) == 0:
		s2_ehz_ripple_phase = (s2_ehz_ripple_phase - 1) & 0xFFFF

	var bg_y := int(camera_model.screen_y) >> 2
	var slow_scroll := -(int(camera_model.screen_x) >> 3)
	var fast_scroll := -(int(camera_model.screen_x) >> 1)
	var ripple_offset := 0
	var in_ripple := false
	for line in range(viewport_height):
		var source_world_y := bg_y + line
		var source_row := (source_world_y & 0x3FF) >> 4
		var scroll_value := slow_scroll
		if source_row > 0x12:
			scroll_value = fast_scroll
		elif source_row == 0x12:
			if not in_ripple:
				ripple_offset = 0
			in_ripple = true
			var ri := (s2_ehz_ripple_phase + ripple_offset) & 0x1F
			scroll_value = slow_scroll + S2_EHZ_RIPPLE[ri]
			ripple_offset += 1
		else:
			in_ripple = false
		s2_ehz_hscroll[line] = scroll_value

	var pool_index := 0
	var line := 0
	while line < viewport_height and pool_index < s2_ehz_strips.size():
		var scroll_value := int(s2_ehz_hscroll[line])
		var source_y := posmod(bg_y + line, s2_ehz_plane_height)
		var run_end := line + 1
		while run_end < viewport_height:
			if int(s2_ehz_hscroll[run_end]) != scroll_value:
				break
			# Do not let one region cross the cached source plane's vertical wrap.
			if source_y + (run_end - line) >= s2_ehz_plane_height:
				break
			run_end += 1
		var strip := s2_ehz_strips[pool_index]
		pool_index += 1
		strip.visible = true
		strip.position = Vector2(camera_model.screen_x, camera_model.screen_y + line)
		strip.region_rect = Rect2(posmod(-scroll_value, s2_ehz_plane_width), source_y, viewport_width, run_end - line)
		line = run_end


func _build_s2_ehz_hscroll(camera_x: int) -> void:
	# Direct translation of retail SwScrl_EHZ's Plane-B halfwords. The first 222
	# scanlines are authored; the original routine accidentally leaves the final
	# two H-scroll entries (8 bytes) untouched, so we deliberately preserve them.
	s2_ehz_vint_counter = (s2_ehz_vint_counter + 1) & 0xFF
	if (s2_ehz_vint_counter & 7) == 0:
		s2_ehz_ripple_phase = (s2_ehz_ripple_phase - 1) & 0xFFFF
	var d2 := -camera_x
	var values: Array[int] = []
	for _i in range(22):
		values.append(0)
	var slow := d2 >> 6
	for _i in range(58):
		values.append(slow)
	var ripple_start := s2_ehz_ripple_phase & 0x1F
	for i in range(21):
		values.append(slow + S2_EHZ_RIPPLE[(ripple_start + i) % S2_EHZ_RIPPLE.size()])
	for _i in range(11):
		values.append(0)
	var near := d2 >> 4
	for _i in range(16):
		values.append(near)
	var near_mid := near + (near >> 1)
	for _i in range(16):
		values.append(near_mid)
	var target := (d2 >> 1) - (d2 >> 3)
	# 68000 sequence: (target<<8) DIVS $30, sign-extend quotient, <<8.
	var quotient := int(float(target << 8) / 48.0)
	var step_fixed := quotient << 8
	var grad_fixed := (d2 >> 3) << 16
	for _i in range(15):
		values.append(grad_fixed >> 16)
		grad_fixed += step_fixed
	for _i in range(9):
		var pair_value := grad_fixed >> 16
		values.append(pair_value)
		values.append(pair_value)
		grad_fixed += step_fixed * 2
	for _i in range(15):
		var triple_value := grad_fixed >> 16
		values.append(triple_value)
		values.append(triple_value)
		values.append(triple_value)
		grad_fixed += step_fixed * 3
	var authored := mini(values.size(), s2_ehz_hscroll.size())
	for i in range(authored):
		s2_ehz_hscroll[i] = values[i]



func _update_lz(camera_model: SonicCamera) -> void:
	# REV01 Deform_LZ base scroll is 1/2 X and 1/2 Y. At/below the true
	# waterline, the background half of the hscroll table adds Drown_WobbleData.
	if lz_plane_texture == null or lz_plane_width <= 0 or lz_plane_height <= 0:
		return
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var base_x := int(camera_model.screen_x * 0.5)
	var base_y := int(camera_model.screen_y * 0.5)
	var deform_phase := (lz_deform_accum >> 8) & 0xFF
	lz_deform_accum = (lz_deform_accum + 0x80) & 0xFFFF
	for i in range(lz_strips.size()):
		var sprite := lz_strips[i]
		if i >= viewport_height:
			sprite.visible = false
			continue
		var world_y := camera_model.screen_y + i
		var ripple := 0
		if world_y >= lz_water_surface_y:
			var wobble_index := (deform_phase + base_y + i) & 0xFF
			ripple = LZ_WOBBLE_BASE[wobble_index & 0x7F]
		var source_x := posmod(base_x - ripple, lz_plane_width)
		var source_y := posmod(base_y + i, lz_plane_height)
		sprite.visible = true
		sprite.position = Vector2(camera_model.screen_x, world_y)
		sprite.region_rect = Rect2(source_x, source_y, viewport_width, 1)

func _update_slz(camera_model: SonicCamera) -> void:
	# REV01 Deform_SLZ. BG Y follows camera Y at 1/2 speed. Horizontal
	# deformation is consumed in 16-pixel bands from a 68-word table. The
	# table pointer is ((bg_y-$C0)&$3F0)/16; values after the first 38 bands
	# are the common 1/2-speed lower background rate.
	if slz_plane_texture == null or slz_plane_width <= 0 or slz_plane_height <= 0:
		return
	for sprite in slz_strips:
		sprite.visible = false
	var viewport_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var bg_y = int(camera_model.screen_y * 0.5)
	var sub_y = posmod(bg_y, 16)
	var aligned_bg_y = bg_y - sub_y
	var start_band = (((bg_y - 0xC0) & 0x3F0) >> 4)
	var needed = int(ceil(float(viewport_height + sub_y) / 16.0))
	needed = mini(needed, slz_strips.size())
	for i in range(needed):
		var table_band = start_band + i
		var source_x = posmod(_slz_source_x_for_band(table_band, camera_model.screen_x), slz_plane_width)
		var source_y = posmod(aligned_bg_y + i * 16, slz_plane_height)
		var sprite = slz_strips[i]
		sprite.visible = true
		sprite.position = Vector2(camera_model.screen_x, camera_model.screen_y + i * 16 - sub_y)
		sprite.region_rect = Rect2(source_x, source_y, viewport_width, 16)

func _slz_source_x_for_band(band: int, foreground_x: int) -> int:
	# Deform_SLZ stores negative VDP scroll words. Region sampling uses the
	# corresponding positive source displacement.
	if band < 28:
		# Stars interpolate from 1.0x at band 0 to 5/32x at band 27.
		return int(foreground_x * (32 - band) / 32.0)
	if band < 33:
		return int(foreground_x * 3.0 / 16.0)
	if band < 38:
		return int(foreground_x / 4.0)
	return int(foreground_x / 2.0)

func refresh_palette_indices(changed_indices: Array[int]) -> void:
	# Phase 72: source CRAM cycles for source-plane backgrounds. GHZ is kept as
	# a palette-index texture, so its long 8192px background needs only a 64x1
	# palette upload. Other zones patch their compact RGBA repeat units.
	if level == null or changed_indices.is_empty():
		return
	if mode in ["ghz", "lz", "syz", "slz", "sbz", "s2test", "s2arz", "s2cnz", "s2htz", "s2mcz", "s2ooz", "s2mtz", "s2scz", "s2wfz", "s2dez"] and ghz_palette_material != null:
		_update_ghz_palette_texture()
		return
	if mode == "s2cpz" and ghz_palette_material != null:
		_update_ghz_palette_texture()
		return
	var image: Image = null
	var tex: ImageTexture = null
	var period := Vector2i.ZERO
	match mode:
		"lz":
			image = lz_plane_image
			tex = lz_plane_texture as ImageTexture
			period = lz_repeat_chunks
		"syz":
			image = syz_plane_image
			tex = syz_plane_texture as ImageTexture
			period = syz_repeat_chunks
		"slz":
			image = slz_plane_image
			tex = slz_plane_texture as ImageTexture
			period = slz_repeat_chunks
		"sbz":
			image = sbz_plane_image
			tex = sbz_plane_texture as ImageTexture
			period = sbz_repeat_chunks
		_:
			return
	if image == null or tex == null or period.x <= 0 or period.y <= 0:
		return

	var lines: Array[int] = []
	for index in changed_indices:
		var line := int(index) >> 4
		if not lines.has(line):
			lines.append(line)
	lines.sort()
	var parts: Array[String] = []
	for line in lines:
		parts.append(str(line))
	var key := "%s:pal:%s" % [mode, ",".join(parts)]
	if not background_palette_patch_cache.has(key):
		background_palette_patch_cache[key] = _collect_background_palette_patches(period, lines)
	var patches: Array = background_palette_patch_cache[key]
	if patches.is_empty():
		return
	var tile_image_cache: Dictionary = {}
	for patch in patches:
		var tile_image := _mz_animated_tile_image(patch, tile_image_cache)
		image.blit_rect(tile_image, Rect2i(0, 0, 8, 8), Vector2i(int(patch["x"]), int(patch["y"])))
	tex.update(image)

func _collect_background_palette_patches(period: Vector2i, palette_lines: Array[int]) -> Array:
	var patches: Array = []
	if level == null:
		return patches
	for cy in range(period.y):
		for cx in range(period.x):
			var chunk_id := level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset := (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
			for block_y in range(16):
				for block_x in range(16):
					var off := chunk_offset + (block_y * 16 + block_x) * 2
					if off + 1 >= level.chunks.size():
						continue
					var chunk_word := (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					var block_id := chunk_word & 0x3FF
					var block_flip_x := (chunk_word & 0x0800) != 0
					var block_flip_y := (chunk_word & 0x1000) != 0
					for out_tile_y in range(2):
						for out_tile_x in range(2):
							var source_tile_x := 1 - out_tile_x if block_flip_x else out_tile_x
							var source_tile_y := 1 - out_tile_y if block_flip_y else out_tile_y
							var tile_word := level.get_block_tile_word(block_id, source_tile_y * 2 + source_tile_x)
							var palette_line := (tile_word >> 13) & 3
							if not palette_lines.has(palette_line):
								continue
							patches.append({
								"x": cx * 256 + block_x * 16 + out_tile_x * 8,
								"y": cy * 256 + block_y * 16 + out_tile_y * 8,
								"tile": tile_word & 0x7FF,
								"palette": palette_line,
								"flip_x": ((tile_word & 0x0800) != 0) != block_flip_x,
								"flip_y": ((tile_word & 0x1000) != 0) != block_flip_y,
							})
	return patches

func refresh_sbz_art_range(first_tile: int, tile_count: int) -> void:
	if level == null or mode != "sbz" or sbz_plane_image == null or sbz_plane_texture == null or tile_count <= 0:
		return
	var range_key = "%d:%d" % [first_tile, tile_count]
	if not sbz_art_range_patch_cache.has(range_key):
		sbz_art_range_patch_cache[range_key] = _collect_sbz_plane_tile_patches(first_tile, first_tile + tile_count - 1)
	var patches: Array = sbz_art_range_patch_cache[range_key]
	if patches.is_empty():
		return
	var tile_image_cache: Dictionary = {}
	var indexed = sbz_plane_image.get_format() == Image.FORMAT_R8
	for patch in patches:
		var tile_image = _indexed_tile_image(patch, tile_image_cache) if indexed else _mz_animated_tile_image(patch, tile_image_cache)
		sbz_plane_image.blit_rect(tile_image, Rect2i(0, 0, 8, 8), Vector2i(int(patch["x"]), int(patch["y"])))
	# The compact source period is at most 1280x512 (SBZ1) and 768x512
	# (SBZ2), so one batched upload per changed VBlank remains small.
	sbz_plane_texture.update(sbz_plane_image)

func _collect_sbz_plane_tile_patches(first_tile: int, last_tile: int) -> Array:
	var patches: Array = []
	if level == null:
		return patches
	for cy in range(sbz_repeat_chunks.y):
		for cx in range(sbz_repeat_chunks.x):
			var chunk_id = level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset = (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
			for block_y in range(16):
				for block_x in range(16):
					var off = chunk_offset + (block_y * 16 + block_x) * 2
					if off + 1 >= level.chunks.size():
						continue
					var chunk_word = (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					var block_id = chunk_word & 0x3FF
					var block_flip_x = (chunk_word & 0x0800) != 0
					var block_flip_y = (chunk_word & 0x1000) != 0
					for out_tile_y in range(2):
						for out_tile_x in range(2):
							var source_tile_x = 1 - out_tile_x if block_flip_x else out_tile_x
							var source_tile_y = 1 - out_tile_y if block_flip_y else out_tile_y
							var tile_word = level.get_block_tile_word(block_id, source_tile_y * 2 + source_tile_x)
							var tile_index = tile_word & 0x7FF
							if tile_index < first_tile or tile_index > last_tile:
								continue
							patches.append({
								"x": cx * 256 + block_x * 16 + out_tile_x * 8,
								"y": cy * 256 + block_y * 16 + out_tile_y * 8,
								"tile": tile_index,
								"palette": (tile_word >> 13) & 3,
								"flip_x": ((tile_word & 0x0800) != 0) != block_flip_x,
								"flip_y": ((tile_word & 0x1000) != 0) != block_flip_y,
							})
	return patches

func _update_sbz(camera_model: SonicCamera) -> void:
	if sbz_plane_texture == null or sbz_plane_width <= 0 or sbz_plane_height <= 0:
		return
	for sprite in sbz_strips:
		sprite.visible = false
	var viewport_width = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var act = int(level.definition.get("act", 1))
	var bg_y = int(camera_model.screen_y / 8.0)
	var sub_y = posmod(bg_y, 16)
	var aligned_y = bg_y - sub_y
	var needed = int(ceil(float(viewport_height + sub_y) / 16.0))
	needed = mini(needed, sbz_strips.size())
	for i in range(needed):
		var logical_band = int(floor(float(aligned_y) / 16.0)) + i
		var source_x = 0
		if act == 1:
			var table_band = posmod(logical_band, 32)
			source_x = _sbz1_source_x_for_band(table_band, camera_model.screen_x)
		else:
			source_x = int(camera_model.screen_x / 4.0)
		var source_y = posmod(aligned_y + i * 16, sbz_plane_height)
		var sprite = sbz_strips[i]
		sprite.visible = true
		sprite.position = Vector2(camera_model.screen_x, camera_model.screen_y + i * 16 - sub_y)
		sprite.region_rect = Rect2(posmod(source_x, sbz_plane_width), source_y, viewport_width, 16)

func _sbz1_source_x_for_band(band: int, foreground_x: int) -> int:
	# REV01 SBZ1 32-entry scroll table: four cloud bands gradually slower than
	# 1/4, ten distant-building bands at 1/4, seven upper-building bands at
	# 3/8, and eleven lower-building bands at 1/2.
	if band < 4:
		return int(foreground_x * float(16 - band) / 64.0)
	if band < 14:
		return int(foreground_x / 4.0)
	if band < 21:
		return int(foreground_x * 3.0 / 8.0)
	return int(foreground_x / 2.0)

func _update_syz(camera_model: SonicCamera) -> void:
	# REV01 Deform_SYZ: background Y advances by $30/$100 (3/16), then
	# BGScroll_X consumes 16-pixel rows from a 33-entry horizontal scroll table.
	# The table is 8 cloud rows, 5 mountain rows, 6 building rows and 14 bush
	# rows.  This reproduces those bands directly instead of moving one plane.
	if syz_plane_texture == null or syz_plane_width <= 0 or syz_plane_height <= 0:
		return
	for sprite in syz_strips:
		sprite.visible = false

	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var source_y := int(camera_model.screen_y * 3.0 / 16.0)
	var sub_y := posmod(source_y, 16)
	var first_row := int(floor(float(source_y) / 16.0))
	var needed := int(ceil(float(viewport_height + sub_y) / 16.0))
	needed = mini(needed, syz_strips.size())

	for i in range(needed):
		var logical_row := first_row + i
		var source_row := posmod(logical_row, maxi(1, int(syz_plane_height / 16)))
		var source_x := _syz_source_x_for_row(logical_row, camera_model.screen_x)
		source_x = posmod(source_x, syz_plane_width)
		var sprite := syz_strips[i]
		sprite.visible = true
		sprite.position = Vector2(camera_model.screen_x, camera_model.screen_y + i * 16 - sub_y)
		sprite.region_rect = Rect2(source_x, source_row * 16, viewport_width, 16)

func _syz_source_x_for_row(row: int, foreground_x: int) -> int:
	# Magnitudes of the negative VDP background scroll values generated by
	# REV01's fixed-point loops.  Keeping the calculation in rational form
	# avoids accumulating floating-point drift as the camera travels right.
	row = clampi(row, 0, 32)
	if row < 8:
		# 1/2, then 7/128 less foreground contribution per 16-pixel cloud row.
		return int((foreground_x * (64 - row * 7)) / 128.0)
	if row < 13:
		return int(foreground_x / 8.0)
	if row < 19:
		return int(foreground_x / 4.0)
	# Bush rows start at 1/2 and gain 1/28 foreground contribution each row.
	var bush_row := row - 19
	return int(foreground_x * (14 + bush_row) / 28.0)

func _update_ghz(camera_model: SonicCamera) -> void:
	bg3_x_fixed += camera_model.shift_x * 96
	bg2_x_fixed += camera_model.shift_x * 128
	cloud1_fixed += 0x10000
	cloud2_fixed += 0x0C000
	cloud3_fixed += 0x08000

	for sprite in strips:
		sprite.visible = false

	var source_y_start = 32 - ((camera_model.screen_y & 0x7FF) >> 5)
	if source_y_start < 0:
		source_y_start = 0
	var source_y_end = source_y_start + int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var strip_index = 0
	var source_y = source_y_start
	while source_y < source_y_end and strip_index < strips.size():
		var band_end = _next_band_end(source_y)
		var target_end = mini(source_y_end, band_end)
		if source_y >= 152:
			target_end = mini(target_end, source_y + 8)
		var height = target_end - source_y
		if height <= 0:
			break
		var source_x = _source_x_for_line(source_y, camera_model.screen_x)
		_configure_strip(strips[strip_index], camera_model.screen_x, camera_model.screen_y + (source_y - source_y_start), source_x, source_y, height)
		strip_index += 1
		source_y = target_end

func _next_band_end(source_y: int) -> int:
	if source_y < 32: return 32
	if source_y < 48: return 48
	if source_y < 64: return 64
	if source_y < 112: return 112
	if source_y < 152: return 152
	return 256

func _source_x_for_line(source_y: int, foreground_x: int) -> int:
	var bg3 = bg3_x_fixed >> 16
	var bg2 = bg2_x_fixed >> 16
	var result: int
	if source_y < 32:
		result = bg3 + (cloud1_fixed >> 16)
	elif source_y < 48:
		result = bg3 + (cloud2_fixed >> 16)
	elif source_y < 64:
		result = bg3 + (cloud3_fixed >> 16)
	elif source_y < 112:
		result = bg3
	elif source_y < 152:
		result = bg2
	else:
		var water_line = source_y - 152
		result = bg2 + int(((foreground_x - bg2) * water_line) / 104.0)
	result %= SOURCE_WRAP_WIDTH
	if result < 0: result += SOURCE_WRAP_WIDTH
	return result

func _configure_strip(sprite: Sprite2D, world_x: int, world_y: int, source_x: int, source_y: int, height: int) -> void:
	sprite.visible = true
	sprite.position = Vector2(world_x, world_y)
	sprite.region_rect = Rect2(source_x, source_y, ProjectSettings.get_setting("display/window/size/viewport_width"), height)

func _mz_chunk_texture(chunk_id: int) -> Texture2D:
	if mz_chunk_cache.has(chunk_id):
		var cached: Dictionary = mz_chunk_cache[chunk_id]
		return cached["texture"] as Texture2D
	var image = _render_mz_chunk_image(chunk_id)
	var tex = ImageTexture.create_from_image(image)
	mz_chunk_cache[chunk_id] = {"texture": tex, "image": image}
	mz_art_range_patch_cache.clear()
	return tex

func refresh_s2_wfz_getaway_layout() -> void:
	# ObjB2_Jump_to_plane patches four Plane-B strips in the interleaved retail
	# Level_Layout workspace: $0D2/$1D2 and $BD6/$CD6. In the native split
	# layout those are background rows 0/1 cols $52..$55 and rows 11/12 cols
	# $56..$59. Patch only those sixteen 128x128 cells and upload once.
	if level == null or mode != "s2wfz" or s2_ehz_plane_image == null or s2_ehz_plane_texture == null:
		return
	var chunk_size: int = level.chunk_pixel_size()
	if chunk_size != 128:
		return
	var blocks: int = level.blocks_per_chunk()
	var clear_color := Color(32.0 / 255.0, 0, 0, 1)
	var cells: Array[Vector2i] = []
	for cx in range(0x52, 0x56):
		cells.append(Vector2i(cx, 0))
		cells.append(Vector2i(cx, 1))
	for cx in range(0x56, 0x5A):
		cells.append(Vector2i(cx, 11))
		cells.append(Vector2i(cx, 12))
	for cell in cells:
		var cx: int = cell.x
		var cy: int = cell.y
		var dst := Rect2i(cx * chunk_size, cy * chunk_size, chunk_size, chunk_size)
		s2_ehz_plane_image.fill_rect(dst, clear_color)
		var chunk_id: int = level.get_background_chunk_id_at(cx, cy)
		if chunk_id == 0:
			continue
		var chunk_offset: int = level.chunk_data_offset(chunk_id)
		for by in range(blocks):
			for bx in range(blocks):
				var off: int = chunk_offset + (by * blocks + bx) * 2
				if off + 1 >= level.chunks.size():
					continue
				var word: int = (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
				_draw_mz_block_indices(s2_ehz_plane_image, word, cx * chunk_size + bx * 16, cy * chunk_size + by * 16)
	s2_ehz_plane_texture.update(s2_ehz_plane_image)

func refresh_s2test_art_range(first_tile: int, tile_count: int) -> void:
	# Hotfix 1: animated EHZ VRAM writes previously rebuilt/rasterized all of
	# Plane B for every changed two-tile slot. Patch only the 8x8 placements
	# that actually reference the changed VRAM range, then upload once.
	if level == null or not (mode in ["s2test", "s2cpz", "s2cnz", "s2htz", "s2ooz", "s2mtz", "s2scz", "s2wfz", "s2dez"]) or s2_ehz_plane_image == null or s2_ehz_plane_texture == null or tile_count <= 0:
		return
	var range_key := "%d:%d" % [first_tile, tile_count]
	if not s2_ehz_art_range_patch_cache.has(range_key):
		s2_ehz_art_range_patch_cache[range_key] = _collect_s2_ehz_plane_tile_patches(first_tile, first_tile + tile_count - 1)
	var patches: Array = s2_ehz_art_range_patch_cache[range_key]
	if patches.is_empty():
		return
	var tile_image_cache: Dictionary = {}
	for patch in patches:
		var tile_image := _indexed_tile_image(patch, tile_image_cache)
		s2_ehz_plane_image.blit_rect(tile_image, Rect2i(0, 0, 8, 8), Vector2i(int(patch["x"]), int(patch["y"])))
	s2_ehz_plane_texture.update(s2_ehz_plane_image)

func _collect_s2_ehz_plane_tile_patches(first_tile: int, last_tile: int) -> Array:
	var patches: Array = []
	if level == null:
		return patches
	var chunk_size := level.chunk_pixel_size()
	var blocks := level.blocks_per_chunk()
	if chunk_size != 128 or blocks != 8:
		return patches
	var chunks_x := int(s2_ehz_plane_width / chunk_size)
	var chunks_y := int(s2_ehz_plane_height / chunk_size)
	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var chunk_id := level.get_background_chunk_id_at(cx, cy)
			if chunk_id == 0:
				continue
			var chunk_offset := level.chunk_data_offset(chunk_id)
			for block_y in range(blocks):
				for block_x in range(blocks):
					var off := chunk_offset + (block_y * blocks + block_x) * 2
					if off + 1 >= level.chunks.size():
						continue
					var chunk_word := (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
					chunk_word = level.normalize_chunk_word(chunk_word, GHZLevelData.COLLISION_PATH_PRIMARY)
					var block_id := chunk_word & 0x3FF
					var block_flip_x := (chunk_word & 0x0800) != 0
					var block_flip_y := (chunk_word & 0x1000) != 0
					for out_tile_y in range(2):
						for out_tile_x in range(2):
							var source_tile_x := 1 - out_tile_x if block_flip_x else out_tile_x
							var source_tile_y := 1 - out_tile_y if block_flip_y else out_tile_y
							var tile_word := level.get_block_tile_word(block_id, source_tile_y * 2 + source_tile_x)
							var tile_index := tile_word & 0x7FF
							if tile_index < first_tile or tile_index > last_tile:
								continue
							patches.append({
								"x": cx * chunk_size + block_x * 16 + out_tile_x * 8,
								"y": cy * chunk_size + block_y * 16 + out_tile_y * 8,
								"tile": tile_index,
								"palette": (tile_word >> 13) & 3,
								"flip_x": ((tile_word & 0x0800) != 0) != block_flip_x,
								"flip_y": ((tile_word & 0x1000) != 0) != block_flip_y,
							})
	return patches

func refresh_mz_art_range(first_tile: int, tile_count: int) -> void:
	# Phase 59 updates only the 8x8 placements whose animated VRAM slots
	# changed, then uploads each affected unique background chunk once.
	if level == null or mode != "mz" or tile_count <= 0:
		return
	var range_key = "%d:%d" % [first_tile, tile_count]
	if not mz_art_range_patch_cache.has(range_key):
		var patch_map: Dictionary = {}
		for key in mz_chunk_cache.keys():
			var chunk_id = int(key)
			var patches = _collect_mz_chunk_tile_patches(chunk_id, first_tile, first_tile + tile_count - 1)
			if not patches.is_empty():
				patch_map[chunk_id] = patches
		mz_art_range_patch_cache[range_key] = patch_map
	var patch_map: Dictionary = mz_art_range_patch_cache[range_key]
	var tile_image_cache: Dictionary = {}
	for chunk_key in patch_map.keys():
		var chunk_id = int(chunk_key)
		if not mz_chunk_cache.has(chunk_id):
			continue
		var cached: Dictionary = mz_chunk_cache[chunk_id]
		var image = cached["image"] as Image
		for patch in patch_map[chunk_id]:
			var tile_image = _mz_animated_tile_image(patch, tile_image_cache)
			image.blit_rect(tile_image, Rect2i(0, 0, 8, 8), Vector2i(int(patch["x"]), int(patch["y"])))
		var chunk_texture = cached["texture"] as ImageTexture
		chunk_texture.update(image)

func _collect_mz_chunk_tile_patches(chunk_id: int, first_tile: int, last_tile: int) -> Array:
	var patches: Array = []
	var chunk_offset = (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
	for block_y in range(16):
		for block_x in range(16):
			var off = chunk_offset + (block_y * 16 + block_x) * 2
			if off + 1 >= level.chunks.size():
				continue
			var chunk_word = (int(level.chunks[off]) << 8) | int(level.chunks[off + 1])
			var block_id = chunk_word & 0x3FF
			var block_flip_x = (chunk_word & 0x0800) != 0
			var block_flip_y = (chunk_word & 0x1000) != 0
			for out_tile_y in range(2):
				for out_tile_x in range(2):
					var source_tile_x = 1 - out_tile_x if block_flip_x else out_tile_x
					var source_tile_y = 1 - out_tile_y if block_flip_y else out_tile_y
					var tile_word = level.get_block_tile_word(block_id, source_tile_y * 2 + source_tile_x)
					var tile_index = tile_word & 0x7FF
					if tile_index < first_tile or tile_index > last_tile:
						continue
					patches.append({
						"x": block_x * 16 + out_tile_x * 8,
						"y": block_y * 16 + out_tile_y * 8,
						"tile": tile_index,
						"palette": (tile_word >> 13) & 3,
						"flip_x": ((tile_word & 0x0800) != 0) != block_flip_x,
						"flip_y": ((tile_word & 0x1000) != 0) != block_flip_y,
					})
	return patches

func _mz_animated_tile_image(patch: Dictionary, tile_image_cache: Dictionary) -> Image:
	var tile_index = int(patch["tile"])
	var palette_line = int(patch["palette"])
	var flip_x = bool(patch["flip_x"])
	var flip_y = bool(patch["flip_y"])
	var cache_key = "%d:%d:%d:%d" % [tile_index, palette_line, int(flip_x), int(flip_y)]
	if tile_image_cache.has(cache_key):
		return tile_image_cache[cache_key] as Image
	var image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for py in range(8):
		var sample_y = 7 - py if flip_y else py
		for px in range(8):
			var sample_x = 7 - px if flip_x else px
			var color_index = level.get_tile_pixel(tile_index, sample_x, sample_y)
			if color_index == 0:
				continue
			var palette_index = palette_line * 16 + color_index
			if palette_index >= 0 and palette_index < level.palette.size():
				image.set_pixel(px, py, level.palette[palette_index])
	tile_image_cache[cache_key] = image
	return image

func _render_mz_chunk_image(chunk_id: int) -> Image:
	var chunk_size = level.chunk_pixel_size() if mode == "s2test" else 256
	var blocks = chunk_size >> 4
	var image = Image.create_empty(chunk_size, chunk_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	var chunk_offset = level.chunk_data_offset(chunk_id) if mode == "s2test" else (chunk_id - 1) * GHZLevelData.CHUNK_BYTES
	for by in range(blocks):
		for bx in range(blocks):
			var off = chunk_offset + (by * blocks + bx) * 2
			if off + 1 >= level.chunks.size():
				continue
			var word = (int(level.chunks[off]) << 8) | int(level.chunks[off+1])
			_draw_mz_block(image, word, bx*16, by*16)
	return image

func _draw_mz_block_indices(image: Image, chunk_word: int, target_x: int, target_y: int) -> void:
	chunk_word = level.normalize_chunk_word(chunk_word, GHZLevelData.COLLISION_PATH_PRIMARY)
	var block_id = chunk_word & 0x3FF
	var block_flip_x = (chunk_word & 0x0800) != 0
	var block_flip_y = (chunk_word & 0x1000) != 0
	for oy in range(2):
		for ox in range(2):
			var sx_slot = 1 - ox if block_flip_x else ox
			var sy_slot = 1 - oy if block_flip_y else oy
			var tile_word = level.get_block_tile_word(block_id, sy_slot * 2 + sx_slot)
			var tile_index = tile_word & 0x7FF
			var palette_line = (tile_word >> 13) & 3
			var flip_x = ((tile_word & 0x0800) != 0) != block_flip_x
			var flip_y = ((tile_word & 0x1000) != 0) != block_flip_y
			for py in range(8):
				var sample_y = 7 - py if flip_y else py
				for px in range(8):
					var sample_x = 7 - px if flip_x else px
					var color_index = level.get_tile_pixel(tile_index, sample_x, sample_y)
					# Genesis pattern pen 0 is transparent on the scroll planes. Keep the
					# prefilled backdrop index instead of overwriting it. In SCZ that
					# backdrop is the retail sky blue (combined palette index 32).
					if color_index == 0:
						continue
					var palette_index = palette_line * 16 + color_index
					image.set_pixel(
						target_x + ox * 8 + px, target_y + oy * 8 + py,
						Color(float(palette_index) / 255.0, 0, 0, 1)
					)

func _indexed_tile_image(patch: Dictionary, cache: Dictionary) -> Image:
	var tile_index = int(patch["tile"])
	var palette_line = int(patch["palette"])
	var flip_x = bool(patch["flip_x"])
	var flip_y = bool(patch["flip_y"])
	var cache_key = "%d:%d:%d:%d" % [tile_index, palette_line, int(flip_x), int(flip_y)]
	if cache.has(cache_key):
		return cache[cache_key] as Image
	var image = Image.create_empty(8, 8, false, Image.FORMAT_R8)
	image.fill(Color(0, 0, 0, 1))
	for py in range(8):
		var sample_y = 7 - py if flip_y else py
		for px in range(8):
			var sample_x = 7 - px if flip_x else px
			var color_index = level.get_tile_pixel(tile_index, sample_x, sample_y)
			if color_index == 0:
				continue
			var palette_index = palette_line * 16 + color_index
			image.set_pixel(px, py, Color(float(palette_index) / 255.0, 0, 0, 1))
	cache[cache_key] = image
	return image

func _draw_mz_block(image: Image, chunk_word: int, target_x: int, target_y: int) -> void:
	chunk_word = level.normalize_chunk_word(chunk_word, GHZLevelData.COLLISION_PATH_PRIMARY)
	var block_id = chunk_word & 0x3FF
	var block_flip_x = (chunk_word & 0x0800) != 0
	var block_flip_y = (chunk_word & 0x1000) != 0
	for oy in range(2):
		for ox in range(2):
			var sx_slot = 1-ox if block_flip_x else ox
			var sy_slot = 1-oy if block_flip_y else oy
			var tile_word = level.get_block_tile_word(block_id, sy_slot*2+sx_slot)
			var tile_index = tile_word & 0x7FF
			var palette_line = (tile_word >> 13) & 3
			var flip_x = ((tile_word & 0x0800) != 0) != block_flip_x
			var flip_y = ((tile_word & 0x1000) != 0) != block_flip_y
			for py in range(8):
				var sample_y = 7-py if flip_y else py
				for px in range(8):
					var sample_x = 7-px if flip_x else px
					var ci = level.get_tile_pixel(tile_index, sample_x, sample_y)
					if ci == 0:
						continue
					var pi = palette_line*16 + ci
					if pi < level.palette.size():
						image.set_pixel(target_x+ox*8+px, target_y+oy*8+py, level.palette[pi])
