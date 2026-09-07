class_name SBZSmallDoorObject
extends GenesisLevelObject

# Phase 68: Object $2A - Scrap Brain small automatic vertical door.
# Direct translation of ADoor_OpenShut + Ani_ADoor.  The door only opens for
# Sonic when he approaches from the side selected by status bit 0 / X-flip.

var sprite: Sprite2D
var door_frame := 0
var opening := false
var previous_anim := -1
var palette_act := 1

func initialize_object() -> void:
	active_width = 8 # obActWid = 16/2
	z_index = 40     # obPriority = 4 in the project object layer
	palette_act = 2 if manager != null and int(manager.level_definition.get("act", 1)) == 2 else 1
	door_frame = 0
	opening = false
	previous_anim = -1
	sprite = make_sprite("")
	sprite.texture = SourceObjectArt.sbz_small_door_texture(door_frame, palette_act)

func tick() -> void:
	var p = player()
	if p == null:
		return

	# ADoor_OpenShut uses a 64px trigger range on each side, then checks which
	# side Sonic occupies against obStatus bit 0.  Preserve the original boundary
	# asymmetry: -64 is inside, +64 is outside.
	var px = p.pixel_x()
	var wanted_open = false
	if px + 64 >= spawn_x and px - 64 < spawn_x:
		if px < spawn_x:
			wanted_open = not x_flip
		else:
			wanted_open = x_flip

	var wanted_anim = 1 if wanted_open else 0
	if wanted_anim != previous_anim:
		# AnimateSprite resets obAniFrame/obTimeFrame when obAnim changes and,
		# with Ani_ADoor delay 0, displays the first frame immediately. Closing
		# therefore starts at 8; opening starts at 0.
		previous_anim = wanted_anim
		opening = wanted_open
		_set_frame(0 if opening else 8)
	else:
		# Delay byte 0 means one mapping step per VBlank. afBack,1 holds the last
		# mapping indefinitely at frame 8 (open) or frame 0 (closed).
		if opening and door_frame < 8:
			_set_frame(door_frame + 1)
		elif not opening and door_frame > 0:
			_set_frame(door_frame - 1)

	# ADoor_Animate only calls SolidObject while obFrame == 0. The initial box is
	# 12x64 (half-width 6, half-height 32); the source's stood-on height is 33px.
	if door_frame == 0:
		# Maintain the source +1px stood-on height before entering the normal
		# collision path. This is the d3=33 value passed to MvSonicOnPtfm.
		if p.standing_on_object and p.support_record_index == record_index and not p.in_air:
			if p.resolve_platform_top(spawn_x - 6, spawn_x + 6, spawn_y - 33, record_index):
				return
		p.resolve_solid_box_contact(spawn_x, spawn_y, 6, 32, true, record_index)
	else:
		p.clear_object_support_for(record_index, false)

func _set_frame(next_frame: int) -> void:
	next_frame = clampi(next_frame, 0, 8)
	if next_frame == door_frame and sprite != null and sprite.texture != null:
		return
	door_frame = next_frame
	if sprite != null:
		sprite.texture = SourceObjectArt.sbz_small_door_texture(door_frame, palette_act)
