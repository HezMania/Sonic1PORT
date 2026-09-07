class_name LevelPaletteCycler
extends RefCounted

# Phase 72: source translation of _inc/PaletteCycle.asm for live retail levels.
# This mutates the level's 64-entry CRAM model, then asks the source-plane
# renderers to redraw only placements using the changed palette lines.

const ROOT := "res://data/s1/palette"
const LZ_CONVEY_SEQUENCE: Array[int] = [1, 0, 0, 1, 0, 0, 1, 0]

var level: GHZLevelData
var foreground: GHZRenderer
var background: GHZBackgroundRenderer
var manager: SonicObjectManager
var water_palette_node: Node

var pcyc_time := 0
var pcyc_num := 0
var frame_count := 0
var lz_conveyor_index := 0
var underwater_palette: Array[Color] = []

var ghz_cycle: Array[Color] = []
var lz_waterfall: Array[Color] = []
var lz_conveyor: Array[Color] = []
var lz_conveyor_uw: Array[Color] = []
var sbz3_waterfall: Array[Color] = []
var slz_lights: Array[Color] = []
var syz_blackyellow: Array[Color] = []
var syz_redwhite: Array[Color] = []
var sbz_cycles: Dictionary = {}
var s2_cpz_cycle1: Array[Color] = []
var s2_cpz_cycle2: Array[Color] = []
var s2_cpz_cycle3: Array[Color] = []
var s2_arz_water_cycle: Array[Color] = []
var s2_cnz_cycle1: Array[Color] = []
var s2_cnz_cycle3: Array[Color] = []
var s2_cnz_cycle4: Array[Color] = []
var s2_cnz_frame4 := 0
var s2_htz_lava_cycle: Array[Color] = []
var s2_mcz_lantern_cycle: Array[Color] = []
var s2_ooz_oil_cycle: Array[Color] = []
var s2_mtz_cycle1: Array[Color] = []
var s2_mtz_cycle2: Array[Color] = []
var s2_mtz_cycle3: Array[Color] = []
var s2_wfz_fire_cycle: Array[Color] = []
var s2_wfz_belt_cycle: Array[Color] = []
var s2_wfz_cycle1: Array[Color] = []
var s2_wfz_cycle2: Array[Color] = []
var s2_wfz_timer2: int = 0
var s2_wfz_timer3: int = 0
var s2_wfz_frame2: int = 0
var s2_wfz_frame3: int = 0
var s2_mtz_timer2: int = 0
var s2_mtz_timer3: int = 0
var s2_mtz_frame2: int = 0
var s2_mtz_frame3: int = 0
# Pal_OOZ_B replaces CRAM line 1 when LevEvents_OOZ2 locks the boss arena.
# Normal PalCycle_OOZ continues cycling the oil colors in line 2/3.
var s2_ooz_boss_palette: Array[Color] = []
var s2_ooz_boss_active: bool = false
# Pal_MCZ_B replaces CRAM line 1 when the Mystic Cave boss arena locks. Retail
# PalCycle_MCZ then exits early while Current_Boss_ID is non-zero, freezing the
# normal lantern color cycle for the duration of Object $57.
var s2_mcz_boss_palette: Array[Color] = []
var s2_mcz_boss_active: bool = false
const S2_HTZ_LAVA_DELAYS: Array[int] = [0xB,0xB,0xB,0xA,8,0xA,0xB,0xB,0xB,0xB,0xD,0xF,0xD,0xB,0xB,0xB]
# Retail CNZ boss loads Pal_CNZ_B into CRAM line 1 and adds three independent
# four-VBlank boss-only cycle streams while normal CNZ cycling continues.
var s2_cnz_boss_palette: Array[Color] = []
var s2_cnz_boss_cycle1: Array[Color] = []
var s2_cnz_boss_cycle2: Array[Color] = []
var s2_cnz_boss_cycle3: Array[Color] = []
var s2_cnz_boss_active: bool = false
var s2_cnz_boss_timer: int = 0
var s2_cnz_boss_frame1: int = 0
var s2_cnz_boss_frame2: int = 0
var s2_cnz_boss_frame3: int = 0
var s2_cpz_frame2 := 0
var s2_cpz_frame3 := 0
var sbz_script_timers: Array[int] = []
var sbz_script_indices: Array[int] = []

func setup(level_data: GHZLevelData, foreground_renderer: GHZRenderer, background_renderer: GHZBackgroundRenderer, object_manager: SonicObjectManager, lz_water_palette_node: Node = null) -> void:
	level = level_data
	foreground = foreground_renderer
	background = background_renderer
	manager = object_manager
	water_palette_node = lz_water_palette_node
	pcyc_time = 0
	pcyc_num = 0
	frame_count = 0
	lz_conveyor_index = 0
	underwater_palette = []
	s2_cpz_frame2 = 0
	s2_cpz_frame3 = 0
	s2_cnz_frame4 = 0
	s2_mtz_timer2 = 0
	s2_mtz_timer3 = 0
	s2_mtz_frame2 = 0
	s2_mtz_frame3 = 0
	s2_wfz_timer2 = 0
	s2_wfz_timer3 = 0
	s2_wfz_frame2 = 0
	s2_wfz_frame3 = 0
	s2_mcz_boss_active = false
	s2_ooz_boss_active = false
	s2_cnz_boss_active = false
	s2_cnz_boss_timer = 0
	s2_cnz_boss_frame1 = 0
	s2_cnz_boss_frame2 = 0
	s2_cnz_boss_frame3 = 0
	sbz_script_timers.clear()
	sbz_script_indices.clear()
	_load_cycle_data()
	if manager != null:
		manager.htz_lava_palette_frame = 0
	if water_palette_node != null and water_palette_node.has_method("configure_for_level"):
		water_palette_node.call("configure_for_level", level)
	if level != null and level.zone_id == LevelCatalog.ZONE_LZ:
		# LZ4 is the hidden Scrap Brain Act 3 corridor. The original level loader
		# selects palid_SBZ3Water here instead of palid_LZWater, including the
		# dedicated underwater Sonic line contained in that complete CRAM image.
		var wet_name := "SBZ Act 3 Underwater.bin" if int(level.definition.get("act", 1)) == 4 else "Labyrinth Zone Underwater.bin"
		var wet_path := ROOT.path_join(wet_name)
		if FileAccess.file_exists(wet_path):
			underwater_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(wet_path))
		_update_water_palette_shader()
	elif level != null and level.zone_id == LevelCatalog.ZONE_S2_CPZ_TEST and int(level.definition.get("act", 1)) == 2:
		var cpz_wet_path := ROOT.path_join("S2 Chemical Plant Underwater.bin")
		if FileAccess.file_exists(cpz_wet_path):
			underwater_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(cpz_wet_path))
		_update_water_palette_shader()
	elif level != null and level.zone_id == LevelCatalog.ZONE_S2_ARZ_TEST:
		var arz_wet_path := ROOT.path_join("S2 Aquatic Ruin Underwater.bin")
		if FileAccess.file_exists(arz_wet_path):
			underwater_palette = GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(arz_wet_path))
		_update_water_palette_shader()

func tick() -> void:
	if level == null:
		return
	frame_count = (frame_count + 1) & 0xFFFF
	var changed: Array[int] = []
	var wet_changed := false
	match level.zone_id:
		LevelCatalog.ZONE_GHZ, LevelCatalog.ZONE_ENDING:
			changed = _tick_ghz()
		LevelCatalog.ZONE_LZ:
			var result := _tick_lz()
			changed = result[0]
			wet_changed = bool(result[1])
		LevelCatalog.ZONE_SLZ:
			changed = _tick_slz()
		LevelCatalog.ZONE_SYZ:
			changed = _tick_syz()
		LevelCatalog.ZONE_SBZ:
			changed = _tick_sbz()
		LevelCatalog.ZONE_S2_CPZ_TEST:
			changed = _tick_s2_cpz()
			if underwater_palette.size() >= 64 and not changed.is_empty():
				for idx in changed:
					underwater_palette[int(idx)] = level.palette[int(idx)]
				wet_changed = true
		LevelCatalog.ZONE_S2_ARZ_TEST:
			changed = _tick_s2_arz()
			# The underwater CRAM bank is independent, but the HBlank-style
			# remap shader must learn the newly cycled dry colors as match keys.
			wet_changed = underwater_palette.size() >= 64 and not changed.is_empty()
		LevelCatalog.ZONE_S2_CNZ_TEST:
			changed = _tick_s2_cnz()
		LevelCatalog.ZONE_S2_HTZ_TEST:
			changed = _tick_s2_htz()
		LevelCatalog.ZONE_S2_MCZ_TEST:
			changed = _tick_s2_mcz()
		LevelCatalog.ZONE_S2_OOZ_TEST:
			changed = _tick_s2_ooz()
		LevelCatalog.ZONE_S2_MTZ_TEST:
			changed = _tick_s2_mtz()
		LevelCatalog.ZONE_S2_WFZ_TEST:
			changed = _tick_s2_wfz()
		_:
			return
	if not changed.is_empty():
		if foreground != null:
			foreground.refresh_palette_indices(changed)
		if background != null:
			background.refresh_palette_indices(changed)
		if manager != null:
			manager.refresh_palette_cycled_objects(changed, level.palette)
	if wet_changed or (not changed.is_empty() and level.zone_id == LevelCatalog.ZONE_LZ):
		_update_water_palette_shader()

func _tick_ghz() -> Array[int]:
	pcyc_time -= 1
	if pcyc_time >= 0 or ghz_cycle.size() < 16:
		return []
	pcyc_time = 6 - 1
	var frame := pcyc_num & 3
	pcyc_num = (pcyc_num + 1) & 0xFFFF
	return _write_run(level.palette, 40, ghz_cycle, frame * 4, 4)

func _tick_lz() -> Array:
	var changed: Array[int] = []
	var wet_changed := false
	pcyc_time -= 1
	if pcyc_time < 0:
		pcyc_time = 3 - 1
		var frame := pcyc_num & 3
		pcyc_num = (pcyc_num + 1) & 0xFFFF
		var source := sbz3_waterfall if int(level.definition.get("act", 1)) == 4 else lz_waterfall
		changed.append_array(_write_run(level.palette, 43, source, frame * 4, 4))
		if underwater_palette.size() >= 64:
			_write_run(underwater_palette, 43, source, frame * 4, 4)
			wet_changed = true

	# PCycLZ_ConveyorSequence is indexed by the global frame counter and advances
	# on sequence entries 0,3,6. Reversal comes from the same global flag ported
	# as manager.lz_conveyor_reversed.
	var seq_index := (frame_count - 1) & 7
	if LZ_CONVEY_SEQUENCE[seq_index] != 0 and lz_conveyor.size() >= 9:
		var direction := -1 if manager != null and manager.lz_conveyor_reversed else 1
		lz_conveyor_index = posmod(lz_conveyor_index + direction, 3)
		changed.append_array(_write_run(level.palette, 59, lz_conveyor, lz_conveyor_index * 3, 3))
		if underwater_palette.size() >= 64 and lz_conveyor_uw.size() >= 9:
			_write_run(underwater_palette, 59, lz_conveyor_uw, lz_conveyor_index * 3, 3)
			wet_changed = true
	return [changed, wet_changed]

func _tick_slz() -> Array[int]:
	pcyc_time -= 1
	if pcyc_time >= 0 or slz_lights.size() < 18:
		return []
	pcyc_time = 8 - 1
	pcyc_num += 1
	if pcyc_num >= 6:
		pcyc_num = 0
	# Source writes line-3 B, then skips C and writes D-E.
	var source_offset := pcyc_num * 3
	var changed := _write_single(level.palette, 43, slz_lights[source_offset])
	changed.append_array(_write_single(level.palette, 45, slz_lights[source_offset + 1]))
	changed.append_array(_write_single(level.palette, 46, slz_lights[source_offset + 2]))
	return changed

func _tick_syz() -> Array[int]:
	pcyc_time -= 1
	if pcyc_time >= 0 or syz_blackyellow.size() < 16 or syz_redwhite.size() < 8:
		return []
	pcyc_time = 6 - 1
	var frame := pcyc_num & 3
	pcyc_num = (pcyc_num + 1) & 0xFFFF
	var changed := _write_run(level.palette, 55, syz_blackyellow, frame * 4, 4)
	changed.append_array(_write_single(level.palette, 59, syz_redwhite[frame * 2]))
	changed.append_array(_write_single(level.palette, 61, syz_redwhite[frame * 2 + 1]))
	return changed

func _tick_s2_cpz() -> Array[int]:
	# Retail PalCycle_CPZ. One shared eight-VBlank timer drives three independent
	# source streams: 9x three-color frames at CRAM $78, 21x single colors at
	# $7E, and 16x single colors at $5E. Array indices are CRAM words / 2.
	pcyc_time -= 1
	if pcyc_time >= 0:
		return []
	pcyc_time = 7
	var changed: Array[int] = []
	if s2_cpz_cycle1.size() >= 27:
		var frame1 := pcyc_num % 9
		pcyc_num = (pcyc_num + 1) % 9
		changed.append_array(_write_run(level.palette, 60, s2_cpz_cycle1, frame1 * 3, 3))
	if s2_cpz_cycle2.size() >= 21:
		changed.append_array(_write_single(level.palette, 63, s2_cpz_cycle2[s2_cpz_frame2 % 21]))
		s2_cpz_frame2 = (s2_cpz_frame2 + 1) % 21
	if s2_cpz_cycle3.size() >= 16:
		changed.append_array(_write_single(level.palette, 47, s2_cpz_cycle3[s2_cpz_frame3 & 15]))
		s2_cpz_frame3 = (s2_cpz_frame3 + 1) & 15
	return changed


func _tick_s2_cnz() -> Array[int]:
	# Retail non-boss PalCycle_CNZ. One eight-VBlank timer advances all streams.
	pcyc_time -= 1
	if pcyc_time >= 0:
		return []
	pcyc_time = 7
	var changed: Array[int] = []
	var frame := pcyc_num % 3
	pcyc_num = (pcyc_num + 1) % 3
	if s2_cnz_cycle1.size() >= 18:
		var targets1: Array[int] = [37,38,39,43,44,45]
		for i in range(targets1.size()):
			changed.append_array(_write_single(level.palette, targets1[i], s2_cnz_cycle1[frame + i * 3]))
	if s2_cnz_cycle3.size() >= 9:
		for i in range(3):
			changed.append_array(_write_single(level.palette, 50 + i, s2_cnz_cycle3[frame + i * 3]))
	if s2_cnz_cycle4.size() >= 20:
		var f4: int = s2_cnz_frame4 % 18
		s2_cnz_frame4 = (s2_cnz_frame4 + 1) % 18
		changed.append_array(_write_single(level.palette, 57, s2_cnz_cycle4[f4 + 2]))
		changed.append_array(_write_single(level.palette, 58, s2_cnz_cycle4[f4 + 1]))
		changed.append_array(_write_single(level.palette, 59, s2_cnz_cycle4[f4]))
	if s2_cnz_boss_active:
		s2_cnz_boss_timer -= 1
		if s2_cnz_boss_timer < 0:
			s2_cnz_boss_timer = 3
			if s2_cnz_boss_cycle1.size() >= 9:
				var b1: int = s2_cnz_boss_frame1 % 3
				s2_cnz_boss_frame1 = (s2_cnz_boss_frame1 + 1) % 3
				changed.append_array(_write_single(level.palette, 18, s2_cnz_boss_cycle1[b1]))
				changed.append_array(_write_single(level.palette, 19, s2_cnz_boss_cycle1[3 + b1]))
				changed.append_array(_write_single(level.palette, 20, s2_cnz_boss_cycle1[6 + b1]))
			if s2_cnz_boss_cycle2.size() >= 10:
				changed.append_array(_write_single(level.palette, 30, s2_cnz_boss_cycle2[s2_cnz_boss_frame2 % 10]))
				s2_cnz_boss_frame2 = (s2_cnz_boss_frame2 + 1) % 10
			if s2_cnz_boss_cycle3.size() >= 8:
				changed.append_array(_write_single(level.palette, 31, s2_cnz_boss_cycle3[s2_cnz_boss_frame3 % 8]))
				s2_cnz_boss_frame3 = (s2_cnz_boss_frame3 + 1) % 8
	return changed


func _tick_s2_mtz() -> Array[int]:
	# Retail PalCycle_MTZ has three completely independent source timers.
	# Stream 1: one CRAM word at line3+$0A, six frames, every $12 VBlanks.
	# Stream 2: three overlapping words at line3+$02, three frames, every 3.
	# Stream 3: one word at line3+$1E, ten frames, every 10.
	var changed: Array[int] = []
	pcyc_time -= 1
	if pcyc_time < 0 and s2_mtz_cycle1.size() >= 6:
		pcyc_time = 0x11
		changed.append_array(_write_single(level.palette, 37, s2_mtz_cycle1[pcyc_num % 6]))
		pcyc_num = (pcyc_num + 1) % 6
	s2_mtz_timer2 -= 1
	if s2_mtz_timer2 < 0 and s2_mtz_cycle2.size() >= 5:
		s2_mtz_timer2 = 2
		var start2: int = s2_mtz_frame2 % 3
		changed.append_array(_write_run(level.palette, 33, s2_mtz_cycle2, start2, 3))
		s2_mtz_frame2 = (s2_mtz_frame2 + 1) % 3
	s2_mtz_timer3 -= 1
	if s2_mtz_timer3 < 0 and s2_mtz_cycle3.size() >= 10:
		s2_mtz_timer3 = 9
		changed.append_array(_write_single(level.palette, 47, s2_mtz_cycle3[s2_mtz_frame3 % 10]))
		s2_mtz_frame3 = (s2_mtz_frame3 + 1) % 10
	return changed


func _tick_s2_htz() -> Array[int]:
	# Retail PalCycle_HTZ: CyclingPal_Lava is 16 frames of four colors. Each
	# frame writes two colors to CRAM line 2+$06 and two to line 2+$1C, with a
	# frame-specific delay byte rather than a constant cadence.
	pcyc_time -= 1
	if pcyc_time >= 0 or s2_htz_lava_cycle.size() < 64:
		return []
	var frame: int = pcyc_num & 0x0F
	pcyc_num = (pcyc_num + 1) & 0xFFFF
	pcyc_time = S2_HTZ_LAVA_DELAYS[frame]
	var src: int = frame * 4
	if manager != null:
		manager.htz_lava_palette_frame = frame
	var changed: Array[int] = _write_run(level.palette, 19, s2_htz_lava_cycle, src, 2)
	changed.append_array(_write_run(level.palette, 30, s2_htz_lava_cycle, src + 2, 2))
	return changed


func _tick_s2_mcz() -> Array[int]:
	# Retail PalCycle_MCZ checks Current_Boss_ID first. Once the Object $57 boss
	# prelude loads Pal_MCZ_B, normal lantern cycling stops entirely.
	if s2_mcz_boss_active:
		return []
	# Otherwise every two VBlanks select one of four CyclingPal_Lantern colors
	# and write Normal_palette_line2+$16 (absolute CRAM index 27).
	pcyc_time -= 1
	if pcyc_time >= 0 or s2_mcz_lantern_cycle.size() < 4:
		return []
	pcyc_time = 1
	var frame: int = pcyc_num & 3
	pcyc_num = (pcyc_num + 1) & 0xFFFF
	return _write_single(level.palette, 27, s2_mcz_lantern_cycle[frame])


func _tick_s2_ooz() -> Array[int]:
	# Retail PalCycle_OOZ: every eight VBlanks PalCycle_Frame advances by one
	# CRAM word (source byte offsets 0,2,4,6). Four consecutive colors are
	# copied into Normal_palette_line3+$14, absolute CRAM indices 42..45.
	pcyc_time -= 1
	if pcyc_time >= 0 or s2_ooz_oil_cycle.size() < 8:
		return []
	pcyc_time = 7
	var start: int = pcyc_num & 3
	pcyc_num = (pcyc_num + 1) & 0xFFFF
	var changed: Array[int] = []
	for i in range(4):
		changed.append_array(_write_single(level.palette, 42 + i, s2_ooz_oil_cycle[start + i]))
	return changed


func activate_s2_ooz_boss_palette() -> void:
	if level == null or level.zone_id != LevelCatalog.ZONE_S2_OOZ_TEST or s2_ooz_boss_active:
		return
	if s2_ooz_boss_palette.size() < 16:
		return
	var changed: Array[int] = _write_run(level.palette, 16, s2_ooz_boss_palette, 0, 16)
	s2_ooz_boss_active = true
	if not changed.is_empty():
		if foreground != null:
			foreground.refresh_palette_indices(changed)
		if background != null:
			background.refresh_palette_indices(changed)
		if manager != null:
			manager.refresh_palette_cycled_objects(changed, level.palette)


func activate_s2_mcz_boss_palette() -> void:
	if level == null or level.zone_id != LevelCatalog.ZONE_S2_MCZ_TEST or s2_mcz_boss_active:
		return
	if s2_mcz_boss_palette.size() < 16:
		return
	# PalLoad_Now Pal_MCZ_B targets Normal_palette_line2: exactly CRAM 16..31.
	var changed: Array[int] = _write_run(level.palette, 16, s2_mcz_boss_palette, 0, 16)
	s2_mcz_boss_active = true
	if not changed.is_empty():
		if foreground != null:
			foreground.refresh_palette_indices(changed)
		if background != null:
			background.refresh_palette_indices(changed)
		if manager != null:
			manager.refresh_palette_cycled_objects(changed, level.palette)


func activate_s2_cnz_boss_palette() -> void:
	if level == null or level.zone_id != LevelCatalog.ZONE_S2_CNZ_TEST or s2_cnz_boss_active:
		return
	if s2_cnz_boss_palette.size() < 16:
		return
	var changed: Array[int] = _write_run(level.palette, 16, s2_cnz_boss_palette, 0, 16)
	s2_cnz_boss_active = true
	s2_cnz_boss_timer = 0
	s2_cnz_boss_frame1 = 0
	s2_cnz_boss_frame2 = 0
	s2_cnz_boss_frame3 = 0
	if not changed.is_empty():
		if foreground != null:
			foreground.refresh_palette_indices(changed)
		if background != null:
			background.refresh_palette_indices(changed)
		if manager != null:
			manager.refresh_palette_cycled_objects(changed, level.palette)


func _tick_s2_arz() -> Array[int]:
	# Retail PalCycle_ARZ. Every six VBlanks, four colors from
	# CyclingPal_EHZ_ARZ_Water replace Normal_palette_line3+4 (indices 34-37).
	# The dedicated underwater CRAM bank remains independent in the source.
	pcyc_time -= 1
	if pcyc_time >= 0 or s2_arz_water_cycle.size() < 16:
		return []
	pcyc_time = 5
	var frame := pcyc_num & 3
	pcyc_num = (pcyc_num + 1) & 0xFFFF
	return _write_run(level.palette, 34, s2_arz_water_cycle, frame * 4, 4)

func _tick_sbz() -> Array[int]:
	var changed: Array[int] = []
	var act := int(level.definition.get("act", 1))
	var scripts := _sbz_scripts_for_act(act)
	if sbz_script_timers.size() != scripts.size():
		sbz_script_timers.resize(scripts.size())
		sbz_script_indices.resize(scripts.size())
		for i in range(scripts.size()):
			sbz_script_timers[i] = 0
			sbz_script_indices[i] = 0
	for i in range(scripts.size()):
		var script: Dictionary = scripts[i]
		sbz_script_timers[i] -= 1
		if sbz_script_timers[i] >= 0:
			continue
		sbz_script_timers[i] = int(script["duration"]) - 1
		var count := int(script["count"])
		sbz_script_indices[i] += 1
		if sbz_script_indices[i] >= count:
			sbz_script_indices[i] = 0
		var colors: Array[Color] = sbz_cycles.get(String(script["file"]), [])
		var source_index := int(script.get("offset", 0)) + sbz_script_indices[i]
		if source_index >= 0 and source_index < colors.size():
			changed.append_array(_write_single(level.palette, int(script["target"]), colors[source_index]))

	# Conveyor colors are a 3-color moving window over six source colors.
	pcyc_time -= 1
	if pcyc_time < 0:
		var file := "Cycle - SBZ 4.bin" if act == 1 else "Cycle - SBZ 10.bin"
		pcyc_time = (2 - 1) if act == 1 else (1 - 1)
		var direction := -1 # f_conveyrev is clear in retail SBZ entry
		pcyc_num = posmod((pcyc_num & 3) + direction, 3)
		var convey: Array[Color] = sbz_cycles.get(file, [])
		if convey.size() >= pcyc_num + 3:
			changed.append_array(_write_run(level.palette, 44, convey, pcyc_num, 3))
	return changed

func _sbz_scripts_for_act(act: int) -> Array[Dictionary]:
	if act == 1:
		return [
			{"duration":8, "count":8, "file":"Cycle - SBZ 1.bin", "target":40},
			{"duration":14, "count":8, "file":"Cycle - SBZ 2.bin", "target":41},
			{"duration":15, "count":8, "file":"Cycle - SBZ 3.bin", "target":55},
			{"duration":12, "count":8, "file":"Cycle - SBZ 5.bin", "target":56},
			{"duration":8, "count":8, "file":"Cycle - SBZ 6.bin", "target":57},
			{"duration":29, "count":16, "file":"Cycle - SBZ 7.bin", "target":63},
			{"duration":4, "count":3, "file":"Cycle - SBZ 8.bin", "target":60, "offset":0},
			{"duration":4, "count":3, "file":"Cycle - SBZ 8.bin", "target":61, "offset":1},
			{"duration":4, "count":3, "file":"Cycle - SBZ 8.bin", "target":62, "offset":2},
		]
	return [
		{"duration":8, "count":8, "file":"Cycle - SBZ 1.bin", "target":40},
		{"duration":14, "count":8, "file":"Cycle - SBZ 2.bin", "target":41},
		{"duration":10, "count":8, "file":"Cycle - SBZ 9.bin", "target":56},
		{"duration":8, "count":8, "file":"Cycle - SBZ 6.bin", "target":57},
		{"duration":4, "count":3, "file":"Cycle - SBZ 8.bin", "target":60, "offset":0},
		{"duration":4, "count":3, "file":"Cycle - SBZ 8.bin", "target":61, "offset":1},
		{"duration":4, "count":3, "file":"Cycle - SBZ 8.bin", "target":62, "offset":2},
	]

func _write_run(destination: Array[Color], target: int, source: Array[Color], source_offset: int, count: int) -> Array[int]:
	var changed: Array[int] = []
	for i in range(count):
		var dst := target + i
		var src := source_offset + i
		if dst < 0 or dst >= destination.size() or src < 0 or src >= source.size():
			continue
		if destination[dst] != source[src]:
			destination[dst] = source[src]
			changed.append(dst)
	return changed

func _write_single(destination: Array[Color], target: int, color: Color) -> Array[int]:
	if target < 0 or target >= destination.size() or destination[target] == color:
		return []
	destination[target] = color
	return [target]

func _tick_s2_wfz() -> Array[int]:
	# Exact PalCycle_WFZ timing. Sonic 2's Normal_palette_line3 is the *third*
	# CRAM line (indices 32-47), not the fourth. Source therefore writes
	# line3+$E => indices 39-42, line3+$1C => 46, line3+$1E => 47.
	var changed: Array[int] = []
	pcyc_time -= 1
	if pcyc_time < 0:
		var belt = manager != null and manager.s2_wfz_fire_toggle
		pcyc_time = 5 if belt else 1
		var source = s2_wfz_belt_cycle if belt else s2_wfz_fire_cycle
		if source.size() >= 16:
			var source_offset = (pcyc_num & 3) * 4
			changed.append_array(_write_run(level.palette, 39, source, source_offset, 4))
		pcyc_num = (pcyc_num + 1) & 3
	s2_wfz_timer2 -= 1
	if s2_wfz_timer2 < 0:
		s2_wfz_timer2 = 3
		if s2_wfz_cycle1.size() >= 34:
			changed.append_array(_write_single(level.palette, 46, s2_wfz_cycle1[s2_wfz_frame2 % 34]))
			s2_wfz_frame2 = (s2_wfz_frame2 + 1) % 34
	s2_wfz_timer3 -= 1
	if s2_wfz_timer3 < 0:
		s2_wfz_timer3 = 5
		if s2_wfz_cycle2.size() >= 12:
			changed.append_array(_write_single(level.palette, 47, s2_wfz_cycle2[s2_wfz_frame3 % 12]))
			s2_wfz_frame3 = (s2_wfz_frame3 + 1) % 12
	return changed

func _load_cycle_data() -> void:
	ghz_cycle = _read_palette("Cycle - GHZ.bin")
	lz_waterfall = _read_palette("Cycle - LZ Waterfall.bin")
	lz_conveyor = _read_palette("Cycle - LZ Conveyor Belt.bin")
	lz_conveyor_uw = _read_palette("Cycle - LZ Conveyor Belt Underwater.bin")
	sbz3_waterfall = _read_palette("Cycle - SBZ3 Waterfall.bin")
	slz_lights = _read_palette("Cycle - SLZ.bin")
	syz_blackyellow = _read_palette("Cycle - SYZ1.bin")
	syz_redwhite = _read_palette("Cycle - SYZ2.bin")
	s2_cpz_cycle1 = _read_palette("S2 CPZ Cycle 1.bin")
	s2_cpz_cycle2 = _read_palette("S2 CPZ Cycle 2.bin")
	s2_cpz_cycle3 = _read_palette("S2 CPZ Cycle 3.bin")
	s2_arz_water_cycle = _read_palette("S2 EHZ ARZ Water Cycle.bin")
	s2_cnz_cycle1 = _read_palette("S2 CNZ Cycle 1.bin")
	s2_cnz_cycle3 = _read_palette("S2 CNZ Cycle 3.bin")
	s2_cnz_cycle4 = _read_palette("S2 CNZ Cycle 4.bin")
	s2_htz_lava_cycle = _read_palette("S2 Hill Top Lava Cycle.bin")
	s2_mcz_lantern_cycle = _read_palette("S2 Mystic Cave Lantern Cycle.bin")
	s2_ooz_oil_cycle = _read_palette("S2 Oil Ocean Oil Cycle.bin")
	s2_mtz_cycle1 = _read_palette("S2 MTZ Cycle 1.bin")
	s2_mtz_cycle2 = _read_palette("S2 MTZ Cycle 2.bin")
	s2_mtz_cycle3 = _read_palette("S2 MTZ Cycle 3.bin")
	s2_wfz_fire_cycle = _read_palette("S2 WFZ Fire Cycle.bin")
	s2_wfz_belt_cycle = _read_palette("S2 WFZ Conveyor Cycle.bin")
	s2_wfz_cycle1 = _read_palette("S2 WFZ Cycle 1.bin")
	s2_wfz_cycle2 = _read_palette("S2 WFZ Cycle 2.bin")
	s2_ooz_boss_palette = _read_palette("S2 OOZ Boss.bin")
	s2_mcz_boss_palette = _read_palette("S2 MCZ Boss.bin")
	s2_cnz_boss_palette = _read_palette("S2 CNZ Boss.bin")
	s2_cnz_boss_cycle1 = _read_palette("S2 CNZ Boss Cycle 1.bin")
	s2_cnz_boss_cycle2 = _read_palette("S2 CNZ Boss Cycle 2.bin")
	s2_cnz_boss_cycle3 = _read_palette("S2 CNZ Boss Cycle 3.bin")
	sbz_cycles.clear()
	for i in range(1, 11):
		var name := "Cycle - SBZ %d.bin" % i
		sbz_cycles[name] = _read_palette(name)

func _read_palette(name: String) -> Array[Color]:
	var path := ROOT.path_join(name)
	if not FileAccess.file_exists(path):
		return []
	return GenesisPalette.decode_cram_bytes(FileAccess.get_file_as_bytes(path))

func _update_water_palette_shader() -> void:
	if water_palette_node != null and water_palette_node.has_method("update_runtime_palettes") and level != null and underwater_palette.size() >= 64:
		water_palette_node.call("update_runtime_palettes", level.palette, underwater_palette)
