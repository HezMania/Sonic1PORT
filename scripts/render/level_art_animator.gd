class_name LevelArtAnimator
extends RefCounted

# Phase 59: native port of the source AnimateLevelGfx routines that update
# ordinary level VRAM slots. The renderer still caches 256x256 chunks; when a
# source routine writes animated tiles, only cached chunks referencing those
# tile slots are re-rasterized into their existing ImageTexture resources.

const ROOT = "res://data/s1/artunc"

const GHZ_BIG_FLOWER_TILE = 0x35C
const GHZ_SMALL_FLOWER_TILE = 0x36C
const GHZ_WATERFALL_TILE = 0x378

const MZ_MAGMA_TILE = 0x2D2
const MZ_LAVA_TILE = 0x2E2
const MZ_TORCH_TILE = 0x2F2
const SBZ_SMOKE_PUFF1_TILE = 0x448
const SBZ_SMOKE_PUFF2_TILE = 0x454
const S2_EHZ_FLOWER1_TILE = 0x394
const S2_EHZ_FLOWER2_TILE = 0x396
const S2_EHZ_FLOWER3_TILE = 0x398
const S2_EHZ_FLOWER4_TILE = 0x39A
const S2_EHZ_PULSE_TILE = 0x39C
const S2_CPZ_ANIM_BACK_TILE = 0x370
const S2_DEZ_ANIM_BACK_TILE = 0x326
const S2_CNZ_FLIP1_TILE = 0x330
const S2_CNZ_FLIP2_TILE = 0x540
const S2_OOZ_PULSE_TILE = 0x2B6
const S2_OOZ_SQUARE1_TILE = 0x2BA
const S2_OOZ_SQUARE2_TILE = 0x2BE
const S2_OOZ_OIL1_TILE = 0x2C2
const S2_OOZ_OIL2_TILE = 0x2D2
const S2_MTZ_LAVA_TILE = 0x340
const S2_MTZ_CYLINDER_TILE = 0x34C
const S2_MTZ_BACK1_TILE = 0x35C
const S2_MTZ_BACK2_TILE = 0x362
const S2_MTZ_CYLINDER_OFFSETS: Array[int] = [0x00,0x10,0x20,0x30,0x40,0x50,0x60,0x70]
const S2_MTZ_LAVA_OFFSETS: Array[int] = [0x00,0x0C,0x18,0x24,0x18,0x0C]
const S2_MTZ_BACK1_FRAMES = [[0x00,0x13],[0x06,7],[0x0C,0x13],[0x06,7]]
const S2_MTZ_BACK2_FRAMES = [[0x0C,0x13],[0x06,7],[0x00,0x13],[0x06,7]]
const S2_OOZ_PULSE_FRAMES = [[0,0x0B],[4,5],[8,9],[4,3]]
const S2_OOZ_SQUARE_FRAMES = [[0,6],[4,6],[8,6],[0x0C,6]]
const S2_OOZ_OIL_FRAMES = [[0,0x11],[0x10,0x11],[0x20,0x11],[0x30,0x11],[0x20,0x11],[0x10,0x11]]
const S2_CNZ_FLIP2_FRAMES = [[0x00,0xC7],[0x10,5],[0x20,5],[0x30,5],[0x40,0xC7],[0x50,5],[0x20,5],[0x60,5],[0x00,5],[0x10,5],[0x20,5],[0x30,5],[0x40,5],[0x50,5],[0x20,5],[0x60,5]]
const S2_CNZ_FLIP1_FRAMES = [[0x70,5],[0x80,5],[0x20,5],[0x90,5],[0xA0,5],[0xB0,5],[0x20,5],[0xC0,5],[0x70,0xC7],[0x80,5],[0x20,5],[0x90,5],[0xA0,0xC7],[0xB0,5],[0x20,5],[0xC0,5]]
const GHZ_SMALL_FLOWER_SEQUENCE = [0, 1, 2, 1]
const S2_EHZ_FLOWER1_FRAMES = [[0, 0x7F], [2, 0x13], [0, 7], [2, 7], [0, 7], [2, 7]]
const S2_EHZ_FLOWER2_FRAMES = [[2, 0x7F], [0, 0x0B], [2, 0x0B], [0, 0x0B], [2, 5], [0, 5], [2, 5], [0, 5]]
const S2_EHZ_FLOWER3_FRAMES = [[0, 7], [2, 7]]
const S2_EHZ_FLOWER4_FRAMES = [[0, 0x7F], [2, 7], [0, 7], [2, 7], [0, 7], [2, 0x0B], [0, 0x0B], [2, 0x0B]]
const S2_EHZ_PULSE_FRAMES = [[0, 0x17], [2, 9], [4, 0x0B], [6, 0x17], [4, 0x0B], [2, 9]]

var level: GHZLevelData
var foreground: GHZRenderer
var background: GHZBackgroundRenderer

var ghz_water = PackedByteArray()
var ghz_big_flower = PackedByteArray()
var ghz_small_flower = PackedByteArray()
var mz_lava_surface = PackedByteArray()
var mz_magma_source = PackedByteArray()
var mz_torch = PackedByteArray()
var sbz_smoke = PackedByteArray()
var s2_ehz_flowers1 = PackedByteArray()
var s2_ehz_flowers2 = PackedByteArray()
var s2_ehz_flowers3 = PackedByteArray()
var s2_ehz_flowers4 = PackedByteArray()
var s2_ehz_pulse = PackedByteArray()
var s2_ehz_times = [0, 0, 0, 0, 0]
var s2_ehz_frames = [0, 0, 0, 0, 0]
var s2_cpz_anim_back = PackedByteArray()
var s2_cpz_time := 0
var s2_cpz_frame := 0
var s2_dez_anim_back = PackedByteArray()
var s2_dez_time := 0
var s2_dez_frame := 0
var s2_cnz_flip = PackedByteArray()
var s2_cnz_times = [0, 0]
var s2_cnz_frames = [0, 0]
var s2_ooz_pulse = PackedByteArray()
var s2_ooz_square1 = PackedByteArray()
var s2_ooz_square2 = PackedByteArray()
var s2_ooz_oil1 = PackedByteArray()
var s2_ooz_oil2 = PackedByteArray()
var s2_ooz_times = [0, 0, 0, 0, 0]
var s2_ooz_frames = [0, 0, 0, 0, 0]
var s2_mtz_cylinder = PackedByteArray()
var s2_mtz_lava = PackedByteArray()
var s2_mtz_anim_back = PackedByteArray()
var s2_mtz_times = [0, 0, 0, 0]
var s2_mtz_frames = [0, 0, 0, 0]

# The source clears v_lani*_time/frame when a level is initialized. Keeping the
# counters as signed ints reproduces subq.b + bpl: timer 0 expires immediately,
# while a timer loaded with N-1 expires again after exactly N VBlanks.
var lani0_time = 0
var lani0_frame = 0
var lani1_time = 0
var lani1_frame = 0
var lani2_time = 0
var lani2_frame = 0
var lani3_frame = 0

func setup(level_data: GHZLevelData, foreground_renderer: GHZRenderer, background_renderer: GHZBackgroundRenderer) -> void:
	level = level_data
	foreground = foreground_renderer
	background = background_renderer
	lani0_time = 0
	lani0_frame = 0
	lani1_time = 0
	lani1_frame = 0
	lani2_time = 0
	lani2_frame = 0
	lani3_frame = 0
	ghz_water = PackedByteArray()
	ghz_big_flower = PackedByteArray()
	ghz_small_flower = PackedByteArray()
	mz_lava_surface = PackedByteArray()
	mz_magma_source = PackedByteArray()
	mz_torch = PackedByteArray()
	sbz_smoke = PackedByteArray()
	s2_ehz_flowers1 = PackedByteArray()
	s2_ehz_flowers2 = PackedByteArray()
	s2_ehz_flowers3 = PackedByteArray()
	s2_ehz_flowers4 = PackedByteArray()
	s2_ehz_pulse = PackedByteArray()
	s2_ehz_times = [0, 0, 0, 0, 0]
	s2_ehz_frames = [0, 0, 0, 0, 0]
	s2_cpz_anim_back = PackedByteArray()
	s2_cpz_time = 0
	s2_cpz_frame = 0
	s2_dez_anim_back = PackedByteArray()
	s2_dez_time = 0
	s2_dez_frame = 0
	s2_cnz_flip = PackedByteArray()
	s2_cnz_times = [0, 0]
	s2_cnz_frames = [0, 0]
	s2_ooz_pulse = PackedByteArray()
	s2_ooz_square1 = PackedByteArray()
	s2_ooz_square2 = PackedByteArray()
	s2_ooz_oil1 = PackedByteArray()
	s2_ooz_oil2 = PackedByteArray()
	s2_ooz_times = [0, 0, 0, 0, 0]
	s2_ooz_frames = [0, 0, 0, 0, 0]
	s2_mtz_cylinder = PackedByteArray()
	s2_mtz_lava = PackedByteArray()
	s2_mtz_anim_back = PackedByteArray()
	s2_mtz_times = [0, 0, 0, 0]
	s2_mtz_frames = [0, 0, 0, 0]

	if level == null:
		return
	match level.zone_id:
		LevelCatalog.ZONE_GHZ:
			ghz_water = _read(ROOT.path_join("GHZ Waterfall.unc"))
			ghz_big_flower = _read(ROOT.path_join("GHZ Flower Large.unc"))
			ghz_small_flower = _read(ROOT.path_join("GHZ Flower Small.unc"))
		LevelCatalog.ZONE_MZ:
			mz_lava_surface = _read(ROOT.path_join("MZ Lava Surface.unc"))
			mz_magma_source = _read(ROOT.path_join("MZ Lava.unc"))
			mz_torch = _read(ROOT.path_join("MZ Background Torch.unc"))
		LevelCatalog.ZONE_SBZ:
			sbz_smoke = _read(ROOT.path_join("SBZ Background Smoke.unc"))
		LevelCatalog.ZONE_S2_TEST, LevelCatalog.ZONE_S2_HTZ_TEST:
			s2_ehz_flowers1 = _read("res://data/s1/s2test/s2_ehz_flowers1.bin")
			s2_ehz_flowers2 = _read("res://data/s1/s2test/s2_ehz_flowers2.bin")
			s2_ehz_flowers3 = _read("res://data/s1/s2test/s2_ehz_flowers3.bin")
			s2_ehz_flowers4 = _read("res://data/s1/s2test/s2_ehz_flowers4.bin")
			s2_ehz_pulse = _read("res://data/s1/s2test/s2_ehz_pulse.bin")
		LevelCatalog.ZONE_S2_CPZ_TEST:
			s2_cpz_anim_back = _read("res://data/s1/s2test/s2_cpz_anim_back.bin")
		LevelCatalog.ZONE_S2_DEZ_TEST:
			s2_dez_anim_back = _read("res://data/s1/s2test/s2_dez_anim_back.bin")
		LevelCatalog.ZONE_S2_CNZ_TEST:
			s2_cnz_flip = _read("res://data/s1/s2test/s2_cnz_flip_tiles.bin")
		LevelCatalog.ZONE_S2_OOZ_TEST:
			s2_ooz_pulse = _read("res://data/s1/s2test/ooz_pulse_ball.bin")
			s2_ooz_square1 = _read("res://data/s1/s2test/ooz_square_ball1.bin")
			s2_ooz_square2 = _read("res://data/s1/s2test/ooz_square_ball2.bin")
			s2_ooz_oil1 = _read("res://data/s1/s2test/ooz_oil1.bin")
			s2_ooz_oil2 = _read("res://data/s1/s2test/ooz_oil2.bin")
		LevelCatalog.ZONE_S2_MTZ_TEST:
			s2_mtz_cylinder = _read("res://data/s1/s2test/mtz_cylinder.bin")
			s2_mtz_lava = _read("res://data/s1/s2test/mtz_lava.bin")
			s2_mtz_anim_back = _read("res://data/s1/s2test/mtz_anim_back.bin")

func tick(oscillate_0a: int) -> void:
	if level == null:
		return
	match level.zone_id:
		LevelCatalog.ZONE_GHZ:
			_tick_ghz()
		LevelCatalog.ZONE_MZ:
			_tick_mz(oscillate_0a & 0xFF)
		LevelCatalog.ZONE_SBZ:
			_tick_sbz()
		LevelCatalog.ZONE_S2_TEST, LevelCatalog.ZONE_S2_HTZ_TEST:
			_tick_s2_ehz()
		LevelCatalog.ZONE_S2_CPZ_TEST:
			_tick_s2_cpz()
		LevelCatalog.ZONE_S2_DEZ_TEST:
			_tick_s2_dez()
		LevelCatalog.ZONE_S2_CNZ_TEST:
			_tick_s2_cnz()
		LevelCatalog.ZONE_S2_OOZ_TEST:
			_tick_s2_ooz()
		LevelCatalog.ZONE_S2_MTZ_TEST:
			_tick_s2_mtz()

func _tick_ghz() -> void:
	# AniArt_GHZ_Waterfall: 8 tiles, two frames, six VBlanks each.
	lani0_time -= 1
	if lani0_time < 0:
		lani0_time = 6 - 1
		var water_frame = lani0_frame & 1
		lani0_frame = (lani0_frame + 1) & 0xFF
		_copy_frame(GHZ_WATERFALL_TILE, ghz_water, water_frame * 8 * GHZLevelData.TILE_BYTES, 8)

	# AniArt_GHZ_Bigflower: 16 tiles, two frames, sixteen VBlanks each.
	lani1_time -= 1
	if lani1_time < 0:
		lani1_time = 16 - 1
		var big_flower_frame = lani1_frame & 1
		lani1_frame = (lani1_frame + 1) & 0xFF
		_copy_frame(GHZ_BIG_FLOWER_TILE, ghz_big_flower, big_flower_frame * 16 * GHZLevelData.TILE_BYTES, 16)

	# AniArt_GHZ_Smallflower: source sequence 0,1,2,1. Frames 0 and 2 stay
	# for 128 VBlanks; frame 1 stays for eight.
	lani2_time -= 1
	if lani2_time < 0:
		lani2_time = 8 - 1
		var small_flower_frame = int(GHZ_SMALL_FLOWER_SEQUENCE[lani2_frame & 3])
		lani2_frame = (lani2_frame + 1) & 0xFF
		if (small_flower_frame & 1) == 0:
			lani2_time = 128 - 1
		_copy_frame(GHZ_SMALL_FLOWER_TILE, ghz_small_flower, small_flower_frame * 12 * GHZLevelData.TILE_BYTES, 12)

func _tick_mz(oscillate_0a: int) -> void:
	# AniArt_MZ_Lava: 8 tiles, three-frame cycle. The source increments the
	# frame before copying, so the seeded frame 0 becomes frame 1 on VBlank 1.
	lani0_time -= 1
	if lani0_time < 0:
		lani0_time = 20 - 1
		lani0_frame += 1
		if lani0_frame == 3:
			lani0_frame = 0
		_copy_frame(MZ_LAVA_TILE, mz_lava_surface, lani0_frame * 8 * GHZLevelData.TILE_BYTES, 8)

	# AniArt_MZ_Magma: update every two VBlanks. Art_MzLava2 stores each
	# 32x32 source frame as 32 linear 16-byte scanlines. The 68000's sixteen
	# tiny copy routines are exactly a circular byte shift of each scanline,
	# selected by (v_oscillate+$A)&$0F, then written as four 8x32 tile columns.
	lani1_time -= 1
	if lani1_time < 0:
		lani1_time = 2 - 1
		lani1_frame = (lani1_frame + 1) & 0xFF # incremented by source, otherwise unused
		var magma = _build_mz_magma_frame(lani0_frame, oscillate_0a & 0x0F)
		_copy_bytes_to_art(MZ_MAGMA_TILE, magma, 0, 16 * GHZLevelData.TILE_BYTES)
		_notify_art_change(MZ_MAGMA_TILE, 16)

	# AniArt_MZ_Torch: four source frames, six tiles each, eight VBlanks.
	lani2_time -= 1
	if lani2_time < 0:
		lani2_time = 8 - 1
		var torch_frame = lani3_frame & 3
		lani3_frame = (lani3_frame + 1) & 3
		_copy_frame(MZ_TORCH_TILE, mz_torch, torch_frame * 6 * GHZLevelData.TILE_BYTES, 6)



func _tick_s2_ehz() -> void:
	# Retail S2 Dynamic_Normal. Hotfix 1 batches the five adjacent EHZ DMA
	# slots into one renderer notification per VBlank. The VRAM writes and
	# source timers are unchanged; duration N remains for N+1 VBlanks; only the expensive renderer refresh is merged.
	var changed := false
	changed = _tick_s2_ehz_slot(0, S2_EHZ_FLOWER1_TILE, s2_ehz_flowers1, S2_EHZ_FLOWER1_FRAMES) or changed
	changed = _tick_s2_ehz_slot(1, S2_EHZ_FLOWER2_TILE, s2_ehz_flowers2, S2_EHZ_FLOWER2_FRAMES) or changed
	changed = _tick_s2_ehz_slot(2, S2_EHZ_FLOWER3_TILE, s2_ehz_flowers3, S2_EHZ_FLOWER3_FRAMES) or changed
	changed = _tick_s2_ehz_slot(3, S2_EHZ_FLOWER4_TILE, s2_ehz_flowers4, S2_EHZ_FLOWER4_FRAMES) or changed
	changed = _tick_s2_ehz_slot(4, S2_EHZ_PULSE_TILE, s2_ehz_pulse, S2_EHZ_PULSE_FRAMES) or changed
	if changed:
		_notify_art_change(S2_EHZ_FLOWER1_TILE, 10)

func _tick_s2_ehz_slot(slot: int, destination_tile: int, source: PackedByteArray, script: Array) -> bool:
	s2_ehz_times[slot] = int(s2_ehz_times[slot]) - 1
	if int(s2_ehz_times[slot]) >= 0 or script.is_empty():
		return false
	var frame_index := int(s2_ehz_frames[slot]) % script.size()
	var entry: Array = script[frame_index]
	s2_ehz_frames[slot] = (frame_index + 1) % script.size()
	s2_ehz_times[slot] = int(entry[1])
	var source_tile := int(entry[0])
	return _copy_bytes_to_art(destination_tile, source, source_tile * GHZLevelData.TILE_BYTES, 2 * GHZLevelData.TILE_BYTES)

func _tick_s2_cnz() -> void:
	# Retail Animated_CNZ: two independent 16-tile Dynamic_Normal streams.
	if s2_cnz_flip.size() < 0xD0 * GHZLevelData.TILE_BYTES:
		return
	var destinations: Array[int] = [S2_CNZ_FLIP1_TILE, S2_CNZ_FLIP2_TILE]
	var scripts: Array = [S2_CNZ_FLIP1_FRAMES, S2_CNZ_FLIP2_FRAMES]
	for slot in range(2):
		s2_cnz_times[slot] = int(s2_cnz_times[slot]) - 1
		if int(s2_cnz_times[slot]) >= 0:
			continue
		var script: Array = scripts[slot]
		var frame_index := int(s2_cnz_frames[slot]) % script.size()
		var entry: Array = script[frame_index]
		s2_cnz_frames[slot] = (frame_index + 1) % script.size()
		s2_cnz_times[slot] = int(entry[1])
		_copy_frame(destinations[slot], s2_cnz_flip, int(entry[0]) * GHZLevelData.TILE_BYTES, 0x10)


func _tick_s2_mtz() -> void:
	# Exact Dynamic_Normal MTZ scripts. Global duration byte 0 means the
	# 16-tile cylinder advances every VBlank; $0D means each lava frame lasts
	# 14 VBlanks because Dynamic_Normal decrements before testing carry. The two
	# background slots use their per-frame source duration bytes.
	if s2_mtz_cylinder.size() >= 0x80 * GHZLevelData.TILE_BYTES:
		s2_mtz_times[0] = int(s2_mtz_times[0]) - 1
		if int(s2_mtz_times[0]) < 0:
			s2_mtz_times[0] = 0
			var fi0: int = int(s2_mtz_frames[0]) % S2_MTZ_CYLINDER_OFFSETS.size()
			s2_mtz_frames[0] = (fi0 + 1) % S2_MTZ_CYLINDER_OFFSETS.size()
			_copy_frame(S2_MTZ_CYLINDER_TILE, s2_mtz_cylinder, S2_MTZ_CYLINDER_OFFSETS[fi0] * GHZLevelData.TILE_BYTES, 0x10)
	if s2_mtz_lava.size() >= 0x30 * GHZLevelData.TILE_BYTES:
		s2_mtz_times[1] = int(s2_mtz_times[1]) - 1
		if int(s2_mtz_times[1]) < 0:
			s2_mtz_times[1] = 0x0D
			var fi1: int = int(s2_mtz_frames[1]) % S2_MTZ_LAVA_OFFSETS.size()
			s2_mtz_frames[1] = (fi1 + 1) % S2_MTZ_LAVA_OFFSETS.size()
			_copy_frame(S2_MTZ_LAVA_TILE, s2_mtz_lava, S2_MTZ_LAVA_OFFSETS[fi1] * GHZLevelData.TILE_BYTES, 0x0C)
	_tick_s2_mtz_per_frame_slot(2, S2_MTZ_BACK1_TILE, S2_MTZ_BACK1_FRAMES)
	_tick_s2_mtz_per_frame_slot(3, S2_MTZ_BACK2_TILE, S2_MTZ_BACK2_FRAMES)

func _tick_s2_mtz_per_frame_slot(slot: int, destination_tile: int, script: Array) -> void:
	if s2_mtz_anim_back.size() < 0x12 * GHZLevelData.TILE_BYTES:
		return
	s2_mtz_times[slot] = int(s2_mtz_times[slot]) - 1
	if int(s2_mtz_times[slot]) >= 0:
		return
	var fi: int = int(s2_mtz_frames[slot]) % script.size()
	var entry: Array = script[fi]
	s2_mtz_frames[slot] = (fi + 1) % script.size()
	s2_mtz_times[slot] = int(entry[1])
	_copy_frame(destination_tile, s2_mtz_anim_back, int(entry[0]) * GHZLevelData.TILE_BYTES, 6)


func _tick_s2_ooz() -> void:
	# Retail Animated_OOZ. All five Dynamic_Normal slots retain their original
	# destination tiles, source offsets and duration bytes. Notify only each slot
	# that actually changed; the pulsing ball updates much more often than the
	# 16-tile oil surfaces, so refreshing the whole $2B6-$2E1 span would waste work.
	if _tick_s2_ooz_slot(0, S2_OOZ_PULSE_TILE, s2_ooz_pulse, S2_OOZ_PULSE_FRAMES, 4):
		_notify_art_change(S2_OOZ_PULSE_TILE, 4)
	if _tick_s2_ooz_slot(1, S2_OOZ_SQUARE1_TILE, s2_ooz_square1, S2_OOZ_SQUARE_FRAMES, 4):
		_notify_art_change(S2_OOZ_SQUARE1_TILE, 4)
	if _tick_s2_ooz_slot(2, S2_OOZ_SQUARE2_TILE, s2_ooz_square2, S2_OOZ_SQUARE_FRAMES, 4):
		_notify_art_change(S2_OOZ_SQUARE2_TILE, 4)
	if _tick_s2_ooz_slot(3, S2_OOZ_OIL1_TILE, s2_ooz_oil1, S2_OOZ_OIL_FRAMES, 0x10):
		_notify_art_change(S2_OOZ_OIL1_TILE, 0x10)
	if _tick_s2_ooz_slot(4, S2_OOZ_OIL2_TILE, s2_ooz_oil2, S2_OOZ_OIL_FRAMES, 0x10):
		_notify_art_change(S2_OOZ_OIL2_TILE, 0x10)

func _tick_s2_ooz_slot(slot: int, destination_tile: int, source: PackedByteArray, script: Array, tile_count: int) -> bool:
	s2_ooz_times[slot] = int(s2_ooz_times[slot]) - 1
	if int(s2_ooz_times[slot]) >= 0 or script.is_empty():
		return false
	var frame_index: int = int(s2_ooz_frames[slot]) % script.size()
	var entry: Array = script[frame_index]
	s2_ooz_frames[slot] = (frame_index + 1) % script.size()
	s2_ooz_times[slot] = int(entry[1])
	return _copy_bytes_to_art(destination_tile, source, int(entry[0]) * GHZLevelData.TILE_BYTES, tile_count * GHZLevelData.TILE_BYTES)


func _tick_s2_cpz() -> void:
	# Retail Animated_CPZ: two tiles at VRAM $370, eight frames
	# (source tiles 0,2,...,$E), duration byte 4. S2's animation timer
	# expires after N+1 VBlanks, so each frame remains for five ticks.
	#
	# Phase 90 Hotfix 1: CPZ1's exact Map16/Map128 data proves $370-$371
	# are referenced only by background block $2FF; no foreground block uses
	# either tile. Update the shared VRAM bytes exactly, but notify Plane B only.
	# This also prevents a background-only DMA from entering the foreground
	# chunk refresh path.
	s2_cpz_time -= 1
	if s2_cpz_time >= 0 or s2_cpz_anim_back.size() < 16 * GHZLevelData.TILE_BYTES:
		return
	s2_cpz_time = 4
	var source_tile := (s2_cpz_frame & 7) * 2
	s2_cpz_frame = (s2_cpz_frame + 1) & 7
	if _copy_bytes_to_art(S2_CPZ_ANIM_BACK_TILE, s2_cpz_anim_back, source_tile * GHZLevelData.TILE_BYTES, 2 * GHZLevelData.TILE_BYTES):
		if background != null:
			background.refresh_s2test_art_range(S2_CPZ_ANIM_BACK_TILE, 2)


func _tick_s2_dez() -> void:
	# Retail Animated_DEZ reuses the eight-frame CPZ/DEZ two-tile source, but
	# targets VRAM tile $326. Duration byte 4 means one frame every five VBlanks.
	s2_dez_time -= 1
	if s2_dez_time >= 0 or s2_dez_anim_back.size() < 16 * GHZLevelData.TILE_BYTES:
		return
	s2_dez_time = 4
	var source_tile: int = (s2_dez_frame & 7) * 2
	s2_dez_frame = (s2_dez_frame + 1) & 7
	if _copy_bytes_to_art(S2_DEZ_ANIM_BACK_TILE, s2_dez_anim_back, source_tile * GHZLevelData.TILE_BYTES, 2 * GHZLevelData.TILE_BYTES):
		if background != null:
			background.refresh_s2test_art_range(S2_DEZ_ANIM_BACK_TILE, 2)

func _tick_sbz() -> void:
	# AniArt_SBZ_Pollution. Two independent 12-tile smoke puffs share the
	# same seven source frames. Frame ID 0 is the blank/wait state; visible
	# frames advance every eight VBlanks, then puff 1 waits three seconds and
	# puff 2 waits two seconds before starting again.
	var changed = false

	# v_lani2_frame is the primary-puff inter-cycle counter.
	if lani2_frame != 0:
		lani2_frame = (lani2_frame - 1) & 0xFF
	else:
		lani0_time -= 1
		if lani0_time < 0:
			lani0_time = 8 - 1
			var frame1 = lani0_frame & 7
			lani0_frame = (lani0_frame + 1) & 0xFF
			if frame1 == 0:
				lani2_frame = 3 * 60
				changed = _write_sbz_blank(SBZ_SMOKE_PUFF1_TILE) or changed
			else:
				changed = _write_sbz_smoke_frame(SBZ_SMOKE_PUFF1_TILE, frame1 - 1) or changed

	# v_lani2_time is the secondary-puff inter-cycle counter.
	if lani2_time != 0:
		lani2_time = (lani2_time - 1) & 0xFF
	else:
		lani1_time -= 1
		if lani1_time < 0:
			lani1_time = 8 - 1
			var frame2 = lani1_frame & 7
			lani1_frame = (lani1_frame + 1) & 0xFF
			if frame2 == 0:
				lani2_time = 2 * 60
				changed = _write_sbz_blank(SBZ_SMOKE_PUFF2_TILE) or changed
			else:
				changed = _write_sbz_smoke_frame(SBZ_SMOKE_PUFF2_TILE, frame2 - 1) or changed

	# Both slots are contiguous ($448-$45F). Batch any same-VBlank changes into
	# one background refresh/texture upload.
	if changed:
		_notify_sbz_art_change()

func _write_sbz_smoke_frame(destination_tile: int, frame: int) -> bool:
	const TILES_PER_FRAME = 12
	var source_offset = clampi(frame, 0, 6) * TILES_PER_FRAME * GHZLevelData.TILE_BYTES
	return _copy_bytes_to_art(destination_tile, sbz_smoke, source_offset, TILES_PER_FRAME * GHZLevelData.TILE_BYTES)

func _write_sbz_blank(destination_tile: int) -> bool:
	# The source's .clearSky routine copies the first six (blank) tiles twice,
	# once into each half of the 12-tile puff slot.
	var half_bytes = 6 * GHZLevelData.TILE_BYTES
	if sbz_smoke.size() < half_bytes:
		return false
	var a = _copy_bytes_to_art(destination_tile, sbz_smoke, 0, half_bytes)
	var b = _copy_bytes_to_art(destination_tile + 6, sbz_smoke, 0, half_bytes)
	return a and b

func _notify_sbz_art_change() -> void:
	if background != null:
		background.refresh_sbz_art_range(SBZ_SMOKE_PUFF1_TILE, 24)

func _build_mz_magma_frame(surface_frame: int, byte_shift: int) -> PackedByteArray:
	var output = PackedByteArray()
	output.resize(16 * GHZLevelData.TILE_BYTES)
	output.fill(0)
	if mz_magma_source.size() < 3 * 0x200:
		return output
	var source_base = clampi(surface_frame, 0, 2) * 0x200
	var shift = byte_shift & 0x0F
	# VRAM destination order is column-major: four vertically adjacent tiles
	# are written before advancing to the next 8-pixel column.
	for column in range(4):
		for tile_y in range(4):
			var tile_index = column * 4 + tile_y
			for pixel_row in range(8):
				var source_y = tile_y * 8 + pixel_row
				for byte_in_row in range(4):
					var source_x_byte = (shift + column * 4 + byte_in_row) & 0x0F
					var src = source_base + source_y * 16 + source_x_byte
					var dst = tile_index * GHZLevelData.TILE_BYTES + pixel_row * 4 + byte_in_row
					output[dst] = mz_magma_source[src]
	return output

func _copy_frame(destination_tile: int, source: PackedByteArray, source_offset: int, tile_count: int) -> void:
	var byte_count = tile_count * GHZLevelData.TILE_BYTES
	if _copy_bytes_to_art(destination_tile, source, source_offset, byte_count):
		_notify_art_change(destination_tile, tile_count)

func _copy_bytes_to_art(destination_tile: int, source: PackedByteArray, source_offset: int, byte_count: int) -> bool:
	if level == null or source_offset < 0 or source_offset + byte_count > source.size():
		return false
	var destination = destination_tile * GHZLevelData.TILE_BYTES
	if destination < 0 or destination + byte_count > level.art.size():
		return false
	for i in range(byte_count):
		level.art[destination + i] = source[source_offset + i]
	return true

func _notify_art_change(first_tile: int, tile_count: int) -> void:
	if foreground != null:
		foreground.refresh_art_range(first_tile, tile_count)
	if background != null and level != null:
		if level.zone_id == LevelCatalog.ZONE_MZ:
			background.refresh_mz_art_range(first_tile, tile_count)
		elif level.zone_id == LevelCatalog.ZONE_S2_TEST or level.zone_id == LevelCatalog.ZONE_S2_HTZ_TEST or level.zone_id == LevelCatalog.ZONE_S2_CPZ_TEST or level.zone_id == LevelCatalog.ZONE_S2_CNZ_TEST or level.zone_id == LevelCatalog.ZONE_S2_OOZ_TEST or level.zone_id == LevelCatalog.ZONE_S2_MTZ_TEST or level.zone_id == LevelCatalog.ZONE_S2_DEZ_TEST:
			# CNZ's Sonic/Tails/star/moon flipping panels share mutable art between
			# planes. Refresh Plane B too so cached chunks cannot retain mixed frames.
			background.refresh_s2test_art_range(first_tile, tile_count)

static func _read(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		push_error("Phase 59: missing retained animated level art: %s" % path)
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)
