class_name LevelCatalog
extends RefCounted

# Phase 11 data-driven level registry.  The first three GHZ acts are fully
# integrated with the existing renderer/object/camera stack.  The remaining
# zones are registered too so the same loader can decode their foreground,
# collision, start position and object-placement data without another engine
# rewrite; zone-specific backgrounds/events/objects can be layered on later.

const ZONE_GHZ := 0
const ZONE_LZ := 1
const ZONE_MZ := 2
const ZONE_SLZ := 3
const ZONE_SYZ := 4
const ZONE_SBZ := 5
const ZONE_ENDING := 6
const ZONE_S2_TEST := 7 # Phase 64 retail Sonic 2 Emerald Hill import slot
const ZONE_S2_HPZ_TEST := 8 # Phase 76 Simon Wai Hidden Palace import slot
const ZONE_S2_CPZ_TEST := 9 # Phase 90/93 retail Sonic 2 Chemical Plant Acts 1-2
const ZONE_S2_ARZ_TEST := 10 # Phase 95/96 retail Sonic 2 Aquatic Ruin Acts 1-2
const ZONE_S2_CNZ_TEST := 11 # Phase 98/103 retail Sonic 2 Casino Night Acts 1-2
const ZONE_S2_HTZ_TEST := 12 # Phase 105 retail Sonic 2 Hill Top Zone
const ZONE_S2_MCZ_TEST := 13 # Phase 111 retail Sonic 2 Mystic Cave Zone
const ZONE_S2_OOZ_TEST := 14 # Phase 115 retail Sonic 2 Oil Ocean Zone
const ZONE_S2_MTZ_TEST := 15 # Phase 119 retail Sonic 2 Metropolis Zone
const ZONE_S2_SCZ_TEST := 16 # Phase 126 retail Sonic 2 Sky Chase Zone
const ZONE_S2_WFZ_TEST := 17 # Phase 127 retail Sonic 2 Wing Fortress Zone
const ZONE_S2_DEZ_TEST := 18 # Phase 132 retail Sonic 2 Death Egg Zone

const ZONE_NAMES := [
	"GREEN HILL ZONE",
	"LABYRINTH ZONE",
	"MARBLE ZONE",
	"STAR LIGHT ZONE",
	"SPRING YARD ZONE",
	"SCRAP BRAIN ZONE",
	"ENDING",
]

const ZONE_CODES := ["GHZ", "LZ", "MZ", "SLZ", "SYZ", "SBZ", "END"]

static func get_level(zone: int, act: int) -> Dictionary:
	# Phase 64 proof-of-concept: a converted Sonic 2 retail-format level lives
	# outside Sonic 1's progression and is reachable only by the H debug key.
	# Keeping it in the catalog makes death/reload deterministic without folding
	# it into normal LevelOrder.
	if zone == ZONE_S2_TEST:
		return _get_sonic2_ehz_test(act)
	if zone == ZONE_S2_HPZ_TEST:
		return _get_sonic2_hpz_test()
	if zone == ZONE_S2_CPZ_TEST:
		return _get_sonic2_cpz_test(act)
	if zone == ZONE_S2_ARZ_TEST:
		return _get_sonic2_arz_test(act)
	if zone == ZONE_S2_CNZ_TEST:
		return _get_sonic2_cnz_test(act)
	if zone == ZONE_S2_HTZ_TEST:
		return _get_sonic2_htz_test(act)
	if zone == ZONE_S2_MCZ_TEST:
		return _get_sonic2_mcz_test(act)
	if zone == ZONE_S2_OOZ_TEST:
		return _get_sonic2_ooz_test(act)
	if zone == ZONE_S2_MTZ_TEST:
		return _get_sonic2_mtz_test(act)
	if zone == ZONE_S2_SCZ_TEST:
		return _get_sonic2_scz_test()
	if zone == ZONE_S2_WFZ_TEST:
		return _get_sonic2_wfz_test()
	if zone == ZONE_S2_DEZ_TEST:
		return _get_sonic2_dez_test()
	zone = clampi(zone, ZONE_GHZ, ZONE_ENDING)
	# Sonic 1 has one deliberately hidden fourth Labyrinth act: LZ4 is the
	# flooded Scrap Brain Act 3 corridor entered from the SBZ2 trap floor.
	# Keep all public/ordinary zones clamped to three acts while permitting
	# that exact internal level ID.
	if zone == ZONE_LZ and act == 4:
		act = 4
	elif zone == ZONE_ENDING:
		act = clampi(act, 1, 2)
	else:
		act = clampi(act, 1, 3)
	var code: String = ZONE_CODES[zone]
	var d := {
		"zone": zone,
		"act": act,
		"zone_code": code,
		"zone_name": ZONE_NAMES[zone],
		"display_name": "%s ACT %d" % [ZONE_NAMES[zone], act],
		"layout": "levels/%s%d.bin" % [code.to_lower(), act],
		"background_layout": "",
		"objects": "objpos/%s%d.bin" % [code.to_lower(), act],
		"start": "startpos/%s%d.bin" % [code.to_lower(), act],
		"map16": "map16/%s.eni" % code,
		"map256": "map256/%s.kos" % code,
		"collision": "collide/%s.bin" % code,
		"palette": "palette/Green Hill Zone.bin",
		"art_loads": [],
		"limit_left": 0,
		"limit_right": 0,
		"limit_top": 0,
		"limit_bottom": 0,
		"background_mode": "none",
		"dynamic_events": "none",
		"full_gameplay_support": false,
	}

	match zone:
		ZONE_GHZ:
			d["background_layout"] = "levels/ghzbg.bin"
			d["palette"] = "palette/Green Hill Zone.bin"
			d["art_loads"] = [
				{"path": "artnem/8x8 - GHZ1.nem", "tile": 0x000, "compression": "nemesis"},
				{"path": "artnem/8x8 - GHZ2.nem", "tile": 0x1CD, "compression": "nemesis"},
				{"path": "artnem/GHZ Flower Stalk.nem", "tile": 0x358, "compression": "nemesis"},
				{"path": "artunc/GHZ Flower Large.unc", "tile": 0x35C, "compression": "raw", "bytes": 16 * 32},
				{"path": "artunc/GHZ Flower Small.unc", "tile": 0x36C, "compression": "raw", "bytes": 12 * 32},
				{"path": "artunc/GHZ Waterfall.unc", "tile": 0x378, "compression": "raw", "bytes": 8 * 32},
			]
			d["limit_right"] = [0x24BF, 0x1EBF, 0x2960][act - 1]
			d["limit_bottom"] = 0x300
			d["background_mode"] = "ghz"
			d["dynamic_events"] = "ghz%d" % act
			d["full_gameplay_support"] = true
		ZONE_LZ:
			d["full_gameplay_support"] = true
			d["background_layout"] = "levels/lzbg.bin"
			d["art_loads"] = [{"path": "artnem/8x8 - LZ.nem", "tile": 0, "compression": "nemesis"}]
			d["background_mode"] = "lz"
			if act == 4:
				# Internal id_LZ_act4 is the real Scrap Brain Act 3 corridor. The source
				# deliberately reuses Labyrinth terrain/collision with the dedicated SBZ3
				# layout, objects, start position and palette.
				d["zone_name"] = "SCRAP BRAIN ZONE"
				d["display_name"] = "SCRAP BRAIN ZONE ACT 3"
				d["layout"] = "levels/sbz3.bin"
				d["objects"] = "objpos/sbz3.bin"
				d["start"] = "startpos/sbz3.bin"
				d["map16"] = "map16/LZ.eni"
				d["map256"] = "map256/LZ.kos"
				d["collision"] = "collide/LZ.bin"
				d["palette"] = "palette/SBZ Act 3.bin"
				d["limit_right"] = 0x20BF
				d["limit_top"] = 0
				d["limit_bottom"] = 0x720
				d["dynamic_events"] = "sbz3"
				d["internal_sbz3"] = true
			else:
				# Phase 30 keeps the normal Labyrinth acts selectable/progressable.
				d["palette"] = "palette/Labyrinth Zone.bin"
				d["limit_right"] = [0x19BF, 0x10AF, 0x202F][act - 1]
				d["limit_top"] = [0, 0, -0x100][act - 1]
				d["limit_bottom"] = [0x530, 0x720, 0x800][act - 1]
				d["dynamic_events"] = "lz%d" % act
		ZONE_MZ:
			d["background_layout"] = "levels/mz%dbg.bin" % act
			d["palette"] = "palette/Marble Zone.bin"
			d["map256"] = "map256/MZ (REV01).kos"
			d["art_loads"] = [
				{"path": "artnem/8x8 - MZ.nem", "tile": 0, "compression": "nemesis"},
				# Phase 14 seeds the first source frames of Marble's dynamic terrain.
				# AnimateLevelGfx can replace these slots in a later animation pass.
				{"path": "artunc/MZ Magma Frame 0.bin", "tile": 0x2D2, "compression": "raw", "bytes": 16 * 32},
				{"path": "artunc/MZ Lava Surface.unc", "tile": 0x2E2, "compression": "raw", "bytes": 8 * 32},
				{"path": "artunc/MZ Background Torch.unc", "tile": 0x2F2, "compression": "raw", "bytes": 6 * 32},
			]
			d["limit_right"] = [0x17BF, 0x17BF, 0x1800][act - 1]
			d["limit_bottom"] = [0x1D0, 0x520, 0x720][act - 1]
			d["background_mode"] = "mz"
			d["dynamic_events"] = "mz%d" % act
			# Phase 14 promotes MZ1 from terrain preview to native gameplay. Acts
			# 2/3 share the loader/background/DLE now, but their additional object
			# families and boss remain later Marble phases.
			d["full_gameplay_support"] = true
		ZONE_SLZ:
			d["background_layout"] = "levels/slzbg.bin"
			d["palette"] = "palette/Star Light Zone.bin"
			d["art_loads"] = [{"path": "artnem/8x8 - SLZ.nem", "tile": 0, "compression": "nemesis"}]
			d["limit_right"] = [0x1FBF, 0x1FBF, 0x2000][act - 1]
			d["limit_bottom"] = [0x640, 0x640, 0x6C0][act - 1]
			d["background_mode"] = "slz"
			d["dynamic_events"] = "slz%d" % act
			# Phase 36 promotes SLZ into the normal routing path for source-driven
			# playtesting. Act 3's boss remains a later SLZ phase.
			d["full_gameplay_support"] = true
		ZONE_SYZ:
			d["background_layout"] = "levels/syzbg (REV01).bin"
			d["palette"] = "palette/Spring Yard Zone.bin"
			d["art_loads"] = [{"path": "artnem/8x8 - SYZ.nem", "tile": 0, "compression": "nemesis"}]
			d["limit_right"] = [0x22C0, 0x28C0, 0x2C00][act - 1]
			d["limit_bottom"] = [0x420, 0x520, 0x620][act - 1]
			d["background_mode"] = "syz"
			d["dynamic_events"] = "syz%d" % act
			# Phase 27 completes the Act 3 dynamic boss/block event, so all three
			# Spring Yard acts now participate in normal gameplay progression.
			d["full_gameplay_support"] = true
		ZONE_SBZ:
			# Internally SBZ act 3 is Final Zone. The flooded "SBZ3" corridor remains
			# the hidden LZ act 4 level ID and Phase 43 reaches it through the source
			# SBZ2 post-tally/bottom-boundary transition rather than labeling it here.
			if act == 3:
				d["display_name"] = "FINAL ZONE"
				d["layout"] = "levels/sbz2.bin"
				d["background_layout"] = "levels/sbz2bg.bin"
				d["objects"] = "objpos/fz.bin"
				d["start"] = "startpos/fz.bin"
				d["map16"] = "map16/SBZ.eni"
				d["map256"] = "map256/SBZ (REV01).kos"
				d["collision"] = "collide/SBZ.bin"
				d["palette"] = "palette/SBZ Act 2.bin"
				d["art_loads"] = [{"path": "artnem/8x8 - SBZ.nem", "tile": 0, "compression": "nemesis"}]
				d["limit_left"] = 0x2080
				d["limit_right"] = 0x2460
				d["limit_top"] = 0x510
				d["limit_bottom"] = 0x510
				d["background_mode"] = "sbz"
				d["dynamic_events"] = "fz"
				d["full_gameplay_support"] = true
			else:
				d["background_layout"] = "levels/sbz%dbg.bin" % act
				d["palette"] = "palette/SBZ Act %d.bin" % act
				d["map256"] = "map256/SBZ (REV01).kos"
				d["art_loads"] = [{"path": "artnem/8x8 - SBZ.nem", "tile": 0, "compression": "nemesis"}]
				d["limit_right"] = [0x21C0, 0x1E40][act - 1]
				d["limit_top"] = [0, -0x100][act - 1]
				d["limit_bottom"] = [0x720, 0x800][act - 1]
				d["background_mode"] = "sbz"
				d["dynamic_events"] = "sbz%d" % act
				# Phase 41 promotes Scrap Brain Acts 1-2 into the normal playtest
				# route. Final Zone remains separate until its source encounter pass.
				d["full_gameplay_support"] = true

		ZONE_ENDING:
			# GM_Ending uses the dedicated 600/601 level IDs: the same ending
			# foreground for both routes, GHZ background/terrain/collision, and
			# separate start positions/scroll limits for good vs. bad endings.
			d["zone_name"] = "ENDING"
			d["display_name"] = "ENDING - GOOD" if act == 1 else "ENDING - BAD"
			d["layout"] = "levels/ending.bin"
			# The original 32-byte ending.bin declares a 15x3 layout but stores only
			# two rows. The 68000 loader naturally reads a final all-zero row from
			# adjacent ROM bytes (Level_EndUnk + the zero prefix of Art_BigRing).
			d["layout_zero_fill_to_header"] = true
			d["background_layout"] = "levels/ghzbg.bin"
			d["objects"] = "objpos/ending.bin"
			d["start"] = "startpos/end%d.bin" % act
			d["map16"] = "map16/GHZ.eni"
			d["map256"] = "map256/GHZ.kos"
			d["collision"] = "collide/GHZ.bin"
			d["palette"] = "palette/Ending.bin"
			d["art_loads"] = [
				{"path": "artnem/8x8 - GHZ1.nem", "tile": 0x000, "compression": "nemesis"},
				{"path": "artnem/8x8 - GHZ2.nem", "tile": 0x1CD, "compression": "nemesis"},
				{"path": "artnem/GHZ Flower Stalk.nem", "tile": 0x358, "compression": "nemesis"},
				{"path": "artnem/Ending - Flowers.nem", "tile": 0x3A0, "compression": "nemesis"},
			]
			d["limit_left"] = 0
			d["limit_right"] = 0x500 if act == 1 else 0xDC0
			d["limit_top"] = 0x110
			d["limit_bottom"] = 0x110
			d["background_mode"] = "ghz"
			d["dynamic_events"] = "ending"
			d["ending_sequence"] = true
			d["full_gameplay_support"] = true

	# Revision-selected source names in the supplied disassembly.
	var obj_name: String = String(d["objects"])
	match obj_name:
		"objpos/ghz3.bin": d["objects"] = "objpos/ghz3 (REV01).bin"
		"objpos/lz1.bin": d["objects"] = "objpos/lz1 (REV01).bin"
		"objpos/lz3.bin": d["objects"] = "objpos/lz3 (REV01).bin"
		"objpos/mz1.bin": d["objects"] = "objpos/mz1 (REV01).bin"
		"objpos/syz3.bin": d["objects"] = "objpos/syz3 (REV01).bin"
		"objpos/sbz1.bin": d["objects"] = "objpos/sbz1 (REV01).bin"

	return d


static func _get_sonic2_ehz_test(requested_act: int = 1) -> Dictionary:
	var act := clampi(requested_act, 1, 2)
	var suffix := "ehz%d" % act
	return {
		"zone": ZONE_S2_TEST,
		"act": act,
		"zone_code": "S2EHZ",
		"zone_name": "EMERALD HILL ZONE",
		"display_name": "SONIC 2 IMPORT TEST - EMERALD HILL ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % suffix,
		"background_layout": "s2test/%s_bg128.bin" % suffix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % suffix,
		"s2_rings": "s2test/%s_rings.bin" % suffix,
		"start": "s2test/%s_start.bin" % suffix,
		"map16": "s2test/ehz1_map16.bin",
		"map16_compression": "raw",
		"chunk_map": "s2test/ehz1_map128.bin",
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/ehz1_collision_primary.bin",
		"collision_secondary": "s2test/ehz1_collision_secondary.bin",
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Emerald Hill Zone.bin",
		"art_loads": [
			{"path": "s2test/ehz1_art.bin", "tile": 0, "compression": "raw"},
		],
		"limit_left": 0,
		"limit_right": 0x29A0 if act == 1 else 0x2940,
		"limit_top": 0,
		"limit_bottom": 0x320 if act == 1 else 0x420,
		"background_mode": "s2test",
		"dynamic_events": "s2_ehz2" if act == 2 else "none",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_ehz": true,
		"s2_ehz_boss": act == 2,
		"skip_title_card": true,
		"music_mode": "s2_ehz",
	}


static func _get_sonic2_cpz_test(act: int) -> Dictionary:
	# Phase 93 extends the native Chemical Plant path to retail Act 2 while
	# sharing CPZ art, Map16/Map128, collision, palette cycles and music.
	act = clampi(act, 1, 2)
	var prefix := "cpz%d" % act
	return {
		"zone": ZONE_S2_CPZ_TEST,
		"act": act,
		"zone_code": "S2CPZ",
		"zone_name": "CHEMICAL PLANT ZONE",
		"display_name": "SONIC 2 IMPORT TEST - CHEMICAL PLANT ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % prefix,
		"background_layout": "s2test/%s_bg128.bin" % prefix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % prefix,
		"s2_rings": "s2test/%s_rings.bin" % prefix,
		"start": "s2test/%s_start.bin" % prefix,
		"map16": "s2test/cpz1_map16.bin",
		"map16_compression": "raw",
		"chunk_map": "s2test/cpz1_map128.bin",
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/cpz1_collision_primary.bin",
		"collision_secondary": "s2test/cpz1_collision_secondary.bin",
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Chemical Plant Zone.bin",
		"art_loads": [{"path": "s2test/cpz1_art.bin", "tile": 0, "compression": "raw"}],
		"limit_left": 0,
		"limit_right": 0x2780 if act == 1 else 0x2A80,
		"limit_top": 0,
		"limit_bottom": 0x720,
		"background_mode": "s2cpz",
		"dynamic_events": "s2_cpz2" if act == 2 else "none",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_cpz": true,
		"s2_cpz_water": act == 2,
		"s2_cpz_boss": act == 2,
		"s2_egg_prison_requires_boss": act == 2,
		"skip_title_card": true,
		"music_mode": "s2_cpz",
	}


static func _get_sonic2_arz_test(act: int) -> Dictionary:
	# Phase 95/96: native retail Aquatic Ruin Acts 1-2. Both acts share ARZ
	# terrain/art/collision/palette; Act 2 has its own layout, placements,
	# $510 water height, camera limits and half-speed vertical Plane-B model.
	act = clampi(act, 1, 2)
	var prefix := "arz%d" % act
	return {
		"zone": ZONE_S2_ARZ_TEST,
		"act": act,
		"zone_code": "S2ARZ",
		"zone_name": "AQUATIC RUIN ZONE",
		"display_name": "SONIC 2 IMPORT TEST - AQUATIC RUIN ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % prefix,
		"background_layout": "s2test/%s_bg128.bin" % prefix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % prefix,
		"s2_rings": "s2test/%s_rings.bin" % prefix,
		"start": "s2test/%s_start.bin" % prefix,
		# ARZ resident terrain/collision data is shared by both retail acts.
		"map16": "s2test/arz1_map16.bin",
		"map16_compression": "raw",
		"chunk_map": "s2test/arz1_map128.bin",
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/arz1_collision_primary.bin",
		"collision_secondary": "s2test/arz1_collision_secondary.bin",
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Aquatic Ruin Zone.bin",
		"art_loads": [{"path": "s2test/arz1_art.bin", "tile": 0, "compression": "raw"}],
		"limit_left": 0,
		"limit_right": 0x28C0 if act == 1 else 0x3FFF,
		"limit_top": 0x200 if act == 1 else 0x180,
		"limit_bottom": 0x600 if act == 1 else 0x710,
		"background_mode": "s2arz",
		# Phase 97: retail LevEvents_ARZ2 and Object $89 boss/end flow.
		"dynamic_events": "s2_arz2" if act == 2 else "none",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_arz": true,
		"s2_arz_boss": act == 2,
		"s2_egg_prison_requires_boss": act == 2,
		"s2_static_water_y": 0x410 if act == 1 else 0x510,
		"s2_arz_water": true,
		"s2_background_indices": "s2test/%s_bg_indices.bin" % prefix,
		"s2_background_index_width": 16384,
		"s2_background_index_height": 1536,
		"skip_title_card": true,
		"music_mode": "s2_arz",
	}


static func _get_sonic2_cnz_test(requested_act: int = 1) -> Dictionary:
	# Phase 104: both retail Casino Night acts use source-native terrain, rings,
	# ordinary placements and the separate SpecialCNZBumpers pseudo-object table.
	# Act 2 additionally enables the retail LevEvents_CNZ2/Object $51 boss flow.
	var act: int = clampi(requested_act, 1, 2)
	var prefix: String = "cnz%d" % act
	return {
		"zone": ZONE_S2_CNZ_TEST,
		"act": act,
		"zone_code": "S2CNZ",
		"zone_name": "CASINO NIGHT ZONE",
		"display_name": "SONIC 2 IMPORT TEST - CASINO NIGHT ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % prefix,
		"background_layout": "s2test/%s_bg128.bin" % prefix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % prefix,
		"s2_rings": "s2test/%s_rings.bin" % prefix,
		"s2_cnz_bumpers": "s2test/%s_bumpers.bin" % prefix,
		"start": "s2test/%s_start.bin" % prefix,
		"map16": "s2test/%s_map16.bin" % prefix,
		"map16_compression": "raw",
		"chunk_map": "s2test/%s_map128.bin" % prefix,
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/%s_collision_primary.bin" % prefix,
		"collision_secondary": "s2test/%s_collision_secondary.bin" % prefix,
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Casino Night Zone.bin",
		"art_loads": [{"path": "s2test/%s_art.bin" % prefix, "tile": 0, "compression": "raw"}],
		"limit_left": 0,
		"limit_right": 0x27A0 if act == 1 else 0x2A80,
		"limit_top": 0,
		"limit_bottom": 0x720,
		"background_mode": "s2cnz",
		"dynamic_events": "s2_cnz2" if act == 2 else "none",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_cnz": true,
		"s2_cnz_boss": act == 2,
		"s2_egg_prison_requires_boss": act == 2,
		"skip_title_card": true,
		"music_mode": "s2_cnz",
	}


static func _get_sonic2_htz_test(requested_act: int = 1) -> Dictionary:
	# Phase 109 carries the fully corrected HTZ1 runtime forward and imports the
	# complete retail Act 2 terrain/rings/placement stream on the same zone art.
	var act: int = clampi(requested_act, 1, 2)
	var prefix: String = "htz2" if act == 2 else "htz1"
	return {
		"zone": ZONE_S2_HTZ_TEST,
		"act": act,
		"zone_code": "S2HTZ",
		"zone_name": "HILL TOP ZONE",
		"display_name": "SONIC 2 IMPORT TEST - HILL TOP ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % prefix,
		"background_layout": "s2test/%s_bg128.bin" % prefix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % prefix,
		"s2_rings": "s2test/%s_rings.bin" % prefix,
		"start": "s2test/%s_start.bin" % prefix,
		"map16": "s2test/%s_map16.bin" % prefix,
		"map16_compression": "raw",
		"chunk_map": "s2test/%s_map128.bin" % prefix,
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/%s_collision_primary.bin" % prefix,
		"collision_secondary": "s2test/%s_collision_secondary.bin" % prefix,
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Hill Top Zone.bin",
		"art_loads": [{"path":"s2test/%s_art.bin" % prefix,"tile":0,"compression":"raw"}],
		"limit_left": 0,
		"limit_right": 0x3280 if act == 2 else 0x2800,
		"limit_top": 0,
		"limit_bottom": 0x720,
		"background_mode": "s2htz",
		"dynamic_events": "s2_htz2" if act == 2 else "s2_htz1",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_htz": true,
		"s2_htz_boss": act == 2,
		"s2_egg_prison_requires_boss": act == 2,
		"skip_title_card": true,
		"music_mode": "s2_htz",
	}


static func _get_sonic2_mcz_test(requested_act: int = 1) -> Dictionary:
	# Phase 113 promotes Mystic Cave Act 2 to the same retail-first data path as
	# Act 1. Both acts share MCZ terrain art/mappings/collision; their source
	# layout, background, object, ring and start streams remain act-specific.
	var act: int = clampi(requested_act, 1, 2)
	var prefix: String = "mcz%d" % act
	return {
		"zone": ZONE_S2_MCZ_TEST,
		"act": act,
		"zone_code": "S2MCZ",
		"zone_name": "MYSTIC CAVE ZONE",
		"display_name": "SONIC 2 IMPORT TEST - MYSTIC CAVE ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % prefix,
		"background_layout": "s2test/%s_bg128.bin" % prefix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % prefix,
		"s2_rings": "s2test/%s_rings.bin" % prefix,
		"start": "s2test/%s_start.bin" % prefix,
		"map16": "s2test/%s_map16.bin" % prefix,
		"map16_compression": "raw",
		"chunk_map": "s2test/%s_map128.bin" % prefix,
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/%s_collision_primary.bin" % prefix,
		"collision_secondary": "s2test/%s_collision_secondary.bin" % prefix,
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Mystic Cave Zone.bin",
		"art_loads": [{"path":"s2test/%s_art.bin" % prefix,"tile":0,"compression":"raw"}],
		# Retail LevelSize / startpos: MCZ1 $0000..$2380/$03C0..$0720;
		# MCZ2 $0000..$3FFF/$0060..$0720.
		"limit_left": 0x0000,
		"limit_right": 0x3FFF if act == 2 else 0x2380,
		"limit_top": 0x0060 if act == 2 else 0x03C0,
		"limit_bottom": 0x0720,
		"background_mode": "s2mcz",
		"backdrop_palette_index": 48,
		"dynamic_events": "s2_mcz2" if act == 2 else "none",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_mcz": true,
		"s2_mcz_boss": act == 2,
		# The retail Act 2 capsule at $22E0,$0660 stays hidden/disabled until the
		# Object $57 defeat handoff marks the boss complete.
		"s2_egg_prison_requires_boss": act == 2,
		"skip_title_card": true,
		"music_mode": "s2_mcz",
	}


static func _get_sonic2_ooz_test(requested_act: int = 1) -> Dictionary:
	# Phase 117 extends the retail Oil Ocean import through Act 2 while keeping
	# both acts on the same exact OOZ 128x128 terrain/art/collision bank.
	var act: int = clampi(requested_act, 1, 2)
	var prefix: String = "ooz%d" % act
	return {
		"zone": ZONE_S2_OOZ_TEST,
		"act": act,
		"zone_code": "S2OOZ",
		"zone_name": "OIL OCEAN ZONE",
		"display_name": "SONIC 2 IMPORT TEST - OIL OCEAN ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % prefix,
		"background_layout": "s2test/%s_bg128.bin" % prefix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % prefix,
		"s2_rings": "s2test/%s_rings.bin" % prefix,
		"start": "s2test/%s_start.bin" % prefix,
		"map16": "s2test/%s_map16.bin" % prefix,
		"map16_compression": "raw",
		"chunk_map": "s2test/%s_map128.bin" % prefix,
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/%s_collision_primary.bin" % prefix,
		"collision_secondary": "s2test/%s_collision_secondary.bin" % prefix,
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Oil Ocean Zone.bin",
		"art_loads": [{"path":"s2test/%s_art.bin" % prefix,"tile":0,"compression":"raw"}],
		# Retail LevelSize/StartPos: OOZ1 X $0000..$2F80, start $0060,$06AC;
		# OOZ2 X $0000..$2D00, start $0060,$056C. Both use Y $0000..$0680.
		"limit_left": 0x0000,
		"limit_right": 0x2D00 if act == 2 else 0x2F80,
		"limit_top": 0x0000,
		"limit_bottom": 0x0680,
		"background_mode": "s2ooz",
		"backdrop_palette_index": 48,
		# Phase 118 completes retail LevEvents_OOZ2 and Object $55.
		"dynamic_events": "s2_ooz2" if act == 2 else "none",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_ooz": true,
		"s2_ooz_boss": act == 2,
		"s2_egg_prison_requires_boss": act == 2,
		"skip_title_card": true,
		"music_mode": "s2_ooz",
	}


static func _get_sonic2_mtz_test(requested_act: int = 1) -> Dictionary:
	# Phase 124 extends the retail Metropolis sequence through Act 3. All three
	# acts retain their exact source layouts, object/ring streams and starts.
	var act: int = clampi(requested_act, 1, 3)
	var prefix: String = "mtz%d" % act
	var right_limit: int = 0x2280
	if act == 2:
		right_limit = 0x1E80
	elif act == 3:
		right_limit = 0x2A80
	return {
		"zone": ZONE_S2_MTZ_TEST,
		"act": act,
		"zone_code": "S2MTZ",
		"zone_name": "METROPOLIS ZONE",
		"display_name": "SONIC 2 IMPORT TEST - METROPOLIS ACT %d" % act,
		"layout": "s2test/%s_layout128.bin" % prefix,
		"background_layout": "s2test/%s_bg128.bin" % prefix,
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_objects": "s2test/%s_objects.bin" % prefix,
		"s2_rings": "s2test/%s_rings.bin" % prefix,
		"start": "s2test/%s_start.bin" % prefix,
		"map16": "s2test/%s_map16.bin" % prefix,
		"map16_compression": "raw",
		"chunk_map": "s2test/%s_map128.bin" % prefix,
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/%s_collision_primary.bin" % prefix,
		"collision_secondary": "s2test/%s_collision_secondary.bin" % prefix,
		"collision_normal": "s2test/collision_normal.bin",
		"collision_rotated": "s2test/collision_rotated.bin",
		"angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Metropolis Zone.bin",
		"art_loads": [{"path":"s2test/%s_art.bin" % prefix,"tile":0,"compression":"raw"}],
		# Retail LevelSize/StartPos: MTZ1 $2280/$028C, MTZ2 $1E80/$05EC,
		# MTZ3 $2A80/$020C. All three use Y -$0100..$0800.
		"limit_left": 0x0000,
		"limit_right": right_limit,
		"limit_top": -0x0100,
		"limit_bottom": 0x0800,
		"background_mode": "s2mtz",
		"backdrop_palette_index": 0,
		"dynamic_events": "s2_mtz3" if act == 3 else "none",
		"full_gameplay_support": true,
		"experimental_sonic2": true,
		"s2_mtz": true,
		# Phase 125 completes retail Object $54 and keeps the authored Act-3 Egg
		# Prison gated until Boss_defeated_flag becomes non-zero.
		"s2_mtz3_foundation": act == 3,
		"s2_mtz_boss": act == 3,
		"s2_egg_prison_requires_boss": act == 3,
		"skip_title_card": true,
		"music_mode": "s2_mtz",
	}




static func _get_sonic2_scz_test() -> Dictionary:
	return {
		"zone": ZONE_S2_SCZ_TEST, "act": 1, "zone_code": "S2SCZ",
		"zone_name": "SKY CHASE ZONE", "display_name": "SONIC 2 IMPORT - SKY CHASE ZONE",
		"layout": "s2test/scz1_layout128.bin", "background_layout": "s2test/scz1_bg128.bin",
		"objects": "s2test/empty_objects.bin", "objects_optional": true,
		"s2_objects": "s2test/scz1_objects.bin", "s2_rings": "s2test/scz1_rings.bin", "start": "s2test/scz1_start.bin",
		"map16": "s2test/scz1_map16.bin", "map16_compression": "raw",
		"chunk_map": "s2test/scz1_map128.bin", "chunk_map_compression": "raw",
		"chunk_pixel_size": 128, "chunk_storage_includes_zero": true, "chunk_word_format": "s2",
		"collision": "s2test/scz1_collision_primary.bin", "collision_secondary": "s2test/scz1_collision_secondary.bin",
		"collision_normal": "s2test/collision_normal.bin", "collision_rotated": "s2test/collision_rotated.bin", "angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Sky Chase Zone.bin", "art_loads": [{"path":"s2test/scz1_art.bin","tile":0,"compression":"raw"}],
		"limit_left": 0x0000, "limit_right": 0x3FFF, "limit_top": 0x0000, "limit_bottom": 0x0500,
		"background_mode": "s2scz", "backdrop_palette_index": 32, "dynamic_events": "s2_scz",
		"full_gameplay_support": true, "experimental_sonic2": true, "s2_scz": true,
		"s2_directional_objpos": true,
		"skip_title_card": true, "music_mode": "s2_scz",
	}

static func _get_sonic2_wfz_test() -> Dictionary:
	return {
		"zone": ZONE_S2_WFZ_TEST, "act": 1, "zone_code": "S2WFZ",
		"zone_name": "WING FORTRESS ZONE", "display_name": "SONIC 2 IMPORT - WING FORTRESS ZONE",
		"layout": "s2test/wfz1_layout128.bin", "background_layout": "s2test/wfz1_bg128.bin",
		"objects": "s2test/empty_objects.bin", "objects_optional": true,
		"s2_objects": "s2test/wfz1_objects.bin", "s2_rings": "s2test/wfz1_rings.bin", "start": "s2test/wfz1_start.bin",
		"map16": "s2test/wfz1_map16.bin", "map16_compression": "raw",
		"chunk_map": "s2test/wfz1_map128.bin", "chunk_map_compression": "raw",
		"chunk_pixel_size": 128, "chunk_storage_includes_zero": true, "chunk_word_format": "s2",
		"collision": "s2test/wfz1_collision_primary.bin", "collision_secondary": "s2test/wfz1_collision_secondary.bin",
		"collision_normal": "s2test/collision_normal.bin", "collision_rotated": "s2test/collision_rotated.bin", "angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Wing Fortress Zone.bin", "palette_line0": "palette/S2 Sonic and Tails.bin", "art_loads": [{"path":"s2test/wfz1_art.bin","tile":0,"compression":"raw"}],
		# Retail LevelSize WFZ: X $0000..$3FFF, Y $0000..$0720.
		"limit_left": 0x0000, "limit_right": 0x3FFF, "limit_top": 0x0000, "limit_bottom": 0x0720,
		"background_mode": "s2wfz", "backdrop_palette_index": 32, "dynamic_events": "s2_wfz",
		"full_gameplay_support": true, "experimental_sonic2": true, "s2_wfz": true,
		"s2_wfz_boss": true, "s2_wfz_boss_active": true,
		"s2_directional_objpos": true, "skip_title_card": true, "music_mode": "s2_wfz",
	}

static func _get_sonic2_dez_test() -> Dictionary:
	return {
		"zone": ZONE_S2_DEZ_TEST, "act": 1, "zone_code": "S2DEZ",
		"zone_name": "DEATH EGG ZONE", "display_name": "SONIC 2 IMPORT - DEATH EGG ZONE",
		"layout": "s2test/dez1_layout128.bin", "background_layout": "s2test/dez1_bg128.bin",
		"objects": "s2test/empty_objects.bin", "objects_optional": true,
		"s2_objects": "s2test/dez1_objects.bin", "s2_rings": "s2test/dez1_rings.bin", "start": "s2test/dez1_start.bin",
		"map16": "s2test/dez1_map16.bin", "map16_compression": "raw",
		"chunk_map": "s2test/dez1_map128.bin", "chunk_map_compression": "raw",
		"chunk_pixel_size": 128, "chunk_storage_includes_zero": true, "chunk_word_format": "s2",
		"collision": "s2test/dez1_collision_primary.bin", "collision_secondary": "s2test/dez1_collision_secondary.bin",
		"collision_normal": "s2test/collision_normal.bin", "collision_rotated": "s2test/collision_rotated.bin", "angle_map": "s2test/angle_map.bin",
		"palette": "palette/S2 Death Egg Zone.bin", "palette_line0": "palette/S2 Sonic and Tails.bin",
		"art_loads": [{"path":"s2test/dez1_art.bin","tile":0,"compression":"raw"}],
		# Retail LevelSize DEZ: X $0000..$1000, fixed camera Y $00C8.
		"limit_left": 0x0000, "limit_right": 0x1000, "limit_top": 0x00C8, "limit_bottom": 0x00C8,
		# DEZ's backdrop is black. Combined palette index 17 is the exact black
		# entry in the retail DEZ zone palette and remains opaque in the indexed
		# background path (index 0 is reserved as shader transparency).
		"background_mode": "s2dez", "backdrop_palette_index": 17, "dynamic_events": "s2_dez",
		"full_gameplay_support": true, "experimental_sonic2": true, "s2_dez": true,
		"s2_directional_objpos": true, "skip_title_card": true, "music_mode": "s2_dez",
	}

static func _get_sonic2_hpz_test() -> Dictionary:
	# Phase 77: source-native 128x128 terrain/collision path from the user-supplied
	# Simon Wai prototype disassembly. Objects, rings, music, scanline deformation
	# and live animated-orb DMA remain intentionally deferred.
	return {
		"zone": ZONE_S2_HPZ_TEST,
		"act": 1,
		"zone_code": "S2HPZ",
		"zone_name": "HIDDEN PALACE ZONE",
		"display_name": "SIMON WAI IMPORT TEST - HIDDEN PALACE ACT 1",
		"layout": "s2test/hpz1_layout128.bin",
		"background_layout": "s2test/hpz1_bg128.bin",
		"objects": "s2test/empty_objects.bin",
		"objects_optional": true,
		"s2_rings": "s2test/hpz1_rings.bin",
		"start": "s2test/hpz1_start.bin",
		"map16": "s2test/hpz1_map16.bin",
		"map16_compression": "raw",
		"chunk_map": "s2test/hpz1_map128.bin",
		"chunk_map_compression": "raw",
		"chunk_pixel_size": 128,
		"chunk_storage_includes_zero": true,
		"chunk_word_format": "s2",
		"collision": "s2test/hpz1_collision_primary.bin",
		"collision_secondary": "s2test/hpz1_collision_secondary.bin",
		"collision_normal": "s2test/hpz_collision_normal.bin",
		"collision_rotated": "s2test/hpz_collision_rotated.bin",
		"angle_map": "s2test/hpz_angle_map.bin",
		"palette": "palette/S2 Simon Wai Hidden Palace Zone.bin",
		"art_loads": [
			{"path": "s2test/hpz1_art.bin", "tile": 0, "compression": "raw"},
		],
		# Simon Wai LevelSize entry: X 0000..3FFF, Y 0000..0720.
		"limit_left": 0,
		"limit_right": 0x3FFF,
		"limit_top": 0,
		"limit_bottom": 0x720,
		"background_mode": "s2test",
		"dynamic_events": "none",
		"full_gameplay_support": false,
		"experimental_sonic2": true,
		"simon_wai_hpz": true,
		"skip_title_card": true,
		"music_mode": "none",
	}


static func next_zone(zone: int) -> int:
	# Debug-zone cycling follows Sonic 1's real progression instead of the
	# internal enum order. It also skips zones that are still terrain-preview
	# only, preventing a debug shortcut from entering unfinished runtime paths.
	var order = [ZONE_GHZ, ZONE_MZ, ZONE_SYZ, ZONE_LZ, ZONE_SLZ, ZONE_SBZ]
	var index = order.find(zone)
	if index < 0:
		index = 0
	for step in range(1, order.size() + 1):
		var candidate = int(order[(index + step) % order.size()])
		if bool(get_level(candidate, 1).get("full_gameplay_support", false)):
			return candidate
	return ZONE_GHZ

static func next_level(zone: int, act: int) -> Vector2i:
	# Original LevelOrder for the normal progression through GHZ, then MZ.
	if zone == ZONE_S2_TEST:
		# Phase 90 continues retail S2 progression from EHZ1 -> EHZ2 -> CPZ1.
		return Vector2i(ZONE_S2_TEST, 2) if act < 2 else Vector2i(ZONE_S2_CPZ_TEST, 1)
	if zone == ZONE_S2_CPZ_TEST:
		# Phase 95 continues retail progression from CPZ2 into Aquatic Ruin Act 1.
		return Vector2i(ZONE_S2_CPZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_ARZ_TEST, 1)
	if zone == ZONE_S2_ARZ_TEST:
		return Vector2i(ZONE_S2_ARZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_CNZ_TEST, 1)
	if zone == ZONE_S2_CNZ_TEST:
		return Vector2i(ZONE_S2_CNZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_HTZ_TEST, 1)
	if zone == ZONE_S2_HTZ_TEST:
		# Phase 111 continues the retail sequence out of the completed HTZ2 boss.
		return Vector2i(ZONE_S2_HTZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_MCZ_TEST, 1)
	if zone == ZONE_S2_MCZ_TEST:
		# Phase 115 continues the retail sequence out of the completed MCZ2 boss.
		return Vector2i(ZONE_S2_MCZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_OOZ_TEST, 1)
	if zone == ZONE_S2_OOZ_TEST:
		# Phase 119 continues the completed OOZ2 boss/end into Metropolis Act 1.
		return Vector2i(ZONE_S2_OOZ_TEST, 2) if act < 2 else Vector2i(ZONE_S2_MTZ_TEST, 1)
	if zone == ZONE_S2_MTZ_TEST:
		return Vector2i(ZONE_S2_MTZ_TEST, act + 1) if act < 3 else Vector2i(ZONE_S2_SCZ_TEST, 1)
	if zone == ZONE_S2_SCZ_TEST:
		return Vector2i(ZONE_S2_WFZ_TEST, 1)
	if zone == ZONE_S2_WFZ_TEST:
		return Vector2i(ZONE_S2_DEZ_TEST, 1)
	if zone == ZONE_S2_DEZ_TEST:
		# Phase 132 completes the Mecha Sonic half; the final Death Egg Robot is next.
		return Vector2i(ZONE_GHZ, 1)
	if zone == ZONE_GHZ:
		if act < 3:
			return Vector2i(ZONE_GHZ, act + 1)
		return Vector2i(ZONE_MZ, 1)
	if zone == ZONE_MZ:
		if act < 3:
			return Vector2i(ZONE_MZ, act + 1)
		return Vector2i(ZONE_SYZ, 1)
	if zone == ZONE_SYZ:
		if act < 3:
			return Vector2i(ZONE_SYZ, act + 1)
		return Vector2i(ZONE_LZ, 1)
	if zone == ZONE_LZ:
		# LZ4/SBZ3 is not part of normal Labyrinth progression. Its top exit is
		# handled by DLE_SBZ3 and restarts into Final Zone directly.
		if act == 4:
			return Vector2i(ZONE_SBZ, 3)
		if act < 3:
			return Vector2i(ZONE_LZ, act + 1)
		return Vector2i(ZONE_SLZ, 1)
	if zone == ZONE_SLZ:
		if act < 3:
			return Vector2i(ZONE_SLZ, act + 1)
		return Vector2i(ZONE_SBZ, 1)
	if zone == ZONE_SBZ and act < 3:
		return Vector2i(ZONE_SBZ, act + 1)
	return Vector2i(ZONE_GHZ, 1)
