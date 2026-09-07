class_name S2SpringObject
extends GenesisLevelObject

# Retail Sonic 2 Object $41. EHZ uses vertical, horizontal and diagonal-up
# springs, including both $1000 red and $A00 yellow strengths.
var sprite: Sprite2D
var orientation := 0 # 0 up, 1 horizontal, 2 down, 3 diagonal-up, 4 diagonal-down
var spring_power := 0x1000
var color_name := "red"
var anim_timer := 0
var anim_step := 0

const DIAG_UP_PROFILE: Array[int] = [
	16,16,16,16,16,16,16,16,16,16,16,16,14,12,10,8,6,4,2,0,-2,-4,-4,-4,-4,-4,-4,-4
]
const DIAG_DOWN_PROFILE: Array[int] = [
	-12,-16,-16,-16,-16,-16,-16,-16,-16,-16,-16,-16,-14,-12,-10,-8,-6,-4,-2,0,2,4,4,4,4,4,4,4
]

func initialize_object() -> void:
	orientation = clampi((subtype >> 4) & 7, 0, 4)
	spring_power = 0x0A00 if (subtype & 2) != 0 else 0x1000
	color_name = "yellow" if (subtype & 2) != 0 else "red"
	active_width = 16
	var folder = _folder()
	sprite = make_sprite("res://assets/objects/s2_ehz/%s/%02d.png" % [folder, _rest_frame()])
	sprite.flip_h = x_flip
	sprite.flip_v = orientation == 2 or orientation == 4

func tick() -> void:
	var can_launch = anim_timer <= 0
	if anim_timer > 0:
		anim_timer -= 1
		var seq = _anim_frames()
		var index = mini(anim_step, seq.size()-1)
		set_sprite_frame(sprite, "s2_ehz/%s" % _folder(), seq[index])
		if (anim_timer % 4) == 0:
			anim_step += 1
		if anim_timer == 0:
			set_sprite_frame(sprite, "s2_ehz/%s" % _folder(), _rest_frame())
	var p = player()
	if p == null:
		return
	match orientation:
		0:
			# Retail Obj41_Up uses d1=$1B for the broad SolidObject shell, d2=$08
			# for fresh vertical contact, d3=$10 once already stood on, but only
			# width_pixels=$10 for RideObject_SetRide. Phase 108 incorrectly reused
			# the broad d1 reach as the launch/support width, so buried springs could
			# fire before Sonic's center was actually over the spring face.
			var landed: bool = p.resolve_s2_spring_top(spawn_x, spawn_y, 0x1B, 0x08, 0x10, 0x10, record_index)
			if landed:
				if can_launch:
					_launch(p, Vector2i(0,-1))
			else:
				# Keep the rest of the spring shell solid, but never let this broad
				# contact path create top support outside retail width_pixels.
				p.resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x08, false, record_index)
		1:
			# Horizontal Obj41 uses fresh-collision height d2=$0E.
			var c = p.resolve_solid_box_contact(spawn_x, spawn_y, 0x0A, 0x0E, true, record_index)
			var dir = -1 if x_flip else 1
			if c == (SonicPlayer.SOLID_RIGHT if dir > 0 else SonicPlayer.SOLID_LEFT) and can_launch:
				_launch(p, Vector2i(dir,0))
		2:
			# Downward springs share Obj41's d2=$08 fresh-collision height.
			var c = p.resolve_solid_box_contact(spawn_x, spawn_y, 0x12, 0x08, true, record_index)
			if c == SonicPlayer.SOLID_BOTTOM and can_launch:
				_launch(p, Vector2i(0,1))
		3:
			# Obj41_DiagonallyUp uses SlopedSolid with this exact 28-byte height
			# profile. Phase 81 treated the whole 32x32 envelope as a flat solid box,
			# making the low/inactive side of ground springs feel like an invisible
			# wall. Sample the source profile instead.
			var surface_y = _diagonal_surface_y(p.pixel_x(), DIAG_UP_PROFILE)
			if surface_y != 0x7FFFFFFF:
				var landed = p.resolve_platform_top(spawn_x - 27, spawn_x + 28, surface_y, record_index)
				var dir = -1 if x_flip else 1
				var correct_side = p.pixel_x() >= spawn_x - 4 if dir > 0 else p.pixel_x() <= spawn_x + 4
				if landed and correct_side and can_launch:
					_launch(p, Vector2i(dir, -1))
		4:
			# No diagonal-down spring is placed in EHZ1, but retain the Phase 82
			# bottom-contact fallback until that orientation receives its own bottom
			# slope resolver in a level that actually uses it.
			var c = p.resolve_solid_box_contact(spawn_x, spawn_y, 16, 16, true, record_index)
			var dir = -1 if x_flip else 1
			var correct_side = p.pixel_x() >= spawn_x - 4 if dir > 0 else p.pixel_x() <= spawn_x + 4
			if c == SonicPlayer.SOLID_BOTTOM and correct_side and can_launch:
				_launch(p, Vector2i(dir, 1))

func _launch(p: SonicPlayer, dir: Vector2i) -> void:
	SonicAudio.play_sfx(SonicAudio.SFX_SPRING)
	# The 68000 spring routines deliberately move Sonic INTO the compressed
	# spring immediately before applying velocity: 8 px on axial springs and
	# 6 px on diagonal springs.  Omitting this made several partly buried EHZ
	# springs activate from the wrong visual position.
	var launch_inset = 6 if dir.x != 0 and dir.y != 0 else 8
	p.force_add_pixel_offset(-dir.x * launch_inset, -dir.y * launch_inset)
	if dir.x != 0 and dir.y == 0:
		p.vel_x = dir.x * spring_power
		p.inertia = p.vel_x
		p.lock_time = 15
		p.pushing = false
		# Obj41_Horizontal's negative subtype flag kills transverse Y speed.
		if (subtype & 0x80) != 0:
			p.vel_y = 0
	elif dir.x == 0:
		p.clear_object_support()
		p.vel_y = dir.y * spring_power
		# Up/down springs use the same negative subtype flag to clear X speed.
		if (subtype & 0x80) != 0:
			p.vel_x = 0
		p.in_air = true
		p.pushing = false
		p.jumping = false
	else:
		p.clear_object_support()
		p.vel_x = dir.x * spring_power
		p.vel_y = dir.y * spring_power
		p.inertia = p.vel_x
		p.in_air = true
		p.pushing = false
		p.jumping = false
	# Phase 82: presentation is selected independently from physics. Sonic 1
	# presentation always uses its classic spring pose; S2 Beta/Final honor
	# Object $41 subtype bit 0 and use the source tumble/twirl state instead.
	p.begin_s2_spring_visual(subtype, orientation)

	# Obj41 bits 2/3 explicitly select C/D or E/F collision solidity after launch.
	match subtype & 0x0C:
		0x04: p.set_collision_path(GHZLevelData.COLLISION_PATH_PRIMARY)
		0x08: p.set_collision_path(GHZLevelData.COLLISION_PATH_SECONDARY, 0x410000 + record_index)
	anim_timer = 12
	anim_step = 0

func _folder() -> String:
	var orient = "vertical" if orientation in [0,2] else "horizontal" if orientation == 1 else "diagonal"
	return "spring_%s_%s" % [orient, color_name]

func _rest_frame() -> int:
	return 0 if orientation in [0,2] else 3 if orientation == 1 else 7

func _anim_frames() -> Array[int]:
	# Godot 4 does not retain Array[int] through the chained ternary used in
	# Phase 81. Return explicitly typed locals, matching the earlier S1/SBZ fix.
	if orientation in [0, 2]:
		var vertical_frames: Array[int] = [1, 2, 0]
		return vertical_frames
	if orientation == 1:
		var horizontal_frames: Array[int] = [4, 5, 3]
		return horizontal_frames
	var diagonal_frames: Array[int] = [8, 9, 7]
	return diagonal_frames

func _diagonal_surface_y(world_x: int, profile: Array[int]) -> int:
	# SlopedSolid_cont: d0 = SonicX-objectX+$1B, mirror with `not.w` when
	# X-flipped, then halve to index the 28-entry byte profile.
	var d0 = world_x - spawn_x + 27
	if d0 < 0 or d0 > 54:
		return 0x7FFFFFFF
	var sample = 53 - d0 if x_flip else d0
	var index = clampi(sample >> 1, 0, 27)
	# MvSonicOnSlope uses objectY - signed_profile[index].  Phase 83 instead
	# subtracted profile[0] first, shifting the whole diagonal spring surface
	# downward by 16 pixels and making buried springs miss Sonic.
	return spawn_y - int(profile[index])
