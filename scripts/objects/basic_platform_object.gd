class_name BasicPlatformObject
extends GenesisLevelObject

# Object $18 - basic platforms (GHZ/SYZ/SLZ).
# Phase 12 ports the GHZ movement subtypes instead of pinning every platform
# to its placement coordinate.

var sprite: Sprite2D
var orig_x := 0
var orig_y := 0
var raw_y := 0
var raw_y_fixed := 0
var nudge := 0
var delay := 0
var fall_vel_y := 0
var motion_angle := 0x00

func initialize_object() -> void:
	active_width = 32
	orig_x = spawn_x
	orig_y = spawn_y
	raw_y = spawn_y
	raw_y_fixed = spawn_y << 16
	var zone = int(manager.level_definition.get("zone", LevelCatalog.ZONE_GHZ))
	if zone == LevelCatalog.ZONE_SYZ:
		sprite = make_sprite("res://assets/objects/syz_platform/00.png")
	else:
		var frame = 1 if (subtype & 0x0F) == 0x0A else 0
		sprite = make_sprite("res://assets/objects/platform/%02d.png" % frame)

func tick() -> void:
	if not alive:
		return
	var p = player()
	if p == null:
		return

	var old_x = int(position.x)
	var old_y = int(position.y)
	_update_motion(p)
	_update_nudge(p)
	var new_x = int(position.x)
	var new_y = int(position.y)
	var dx = new_x - old_x
	var dy = new_y - old_y
	var zone = int(manager.level_definition.get("zone", LevelCatalog.ZONE_GHZ))
	var top_offset = 10 if zone == LevelCatalog.ZONE_SYZ else 12
	var top_y = new_y - top_offset

	# MvSonicOnPtfm2: a player who was already standing on this object is moved
	# by the exact platform delta before the fresh platform-top test.
	p.move_with_supported_object(record_index, dx, dy, new_x - active_width, new_x + active_width, top_y)
	p.resolve_platform_top(new_x - active_width, new_x + active_width, top_y, record_index)

func _update_motion(p: SonicPlayer) -> void:
	var kind = subtype & 0x0F
	var osc = motion_angle
	var slow = manager.oscillate_0e()
	match kind:
		0, 9:
			position.x = orig_x
			raw_y = orig_y
		1: # right then left
			position.x = orig_x + GenesisMath.s8((osc - 0x40) & 0xFF)
			raw_y = orig_y
		5: # left then right
			position.x = orig_x + GenesisMath.s8((0x40 - osc) & 0xFF)
			raw_y = orig_y
		2: # down then up
			position.x = orig_x
			raw_y = orig_y + GenesisMath.s8((osc - 0x40) & 0xFF)
		6: # up then down
			position.x = orig_x
			raw_y = orig_y + GenesisMath.s8((0x40 - osc) & 0xFF)
		0x0A: # GHZ2 large vertical platform: half range
			position.x = orig_x
			raw_y = orig_y + (GenesisMath.s8((osc - 0x40) & 0xFF) >> 1)
		0x0B: # slow down/up
			position.x = orig_x
			raw_y = orig_y + GenesisMath.s8((slow - 0x30) & 0xFF)
		0x0C: # slow up/down
			position.x = orig_x
			raw_y = orig_y + GenesisMath.s8((0x30 - slow) & 0xFF)
		3: # wait half a second after Sonic stands on it
			position.x = orig_x
			raw_y = orig_y
			if delay == 0:
				if p.standing_on_object and p.support_record_index == record_index:
					delay = 30
			else:
				delay -= 1
				if delay <= 0:
					subtype = (subtype & 0xF0) | 4
					delay = 32
					fall_vel_y = 0
					raw_y_fixed = raw_y << 16
		4: # falling platform; keep Sonic attached for 32 frames
			position.x = orig_x
			raw_y_fixed += fall_vel_y << 8
			raw_y = raw_y_fixed >> 16
			fall_vel_y = GenesisMath.s16(fall_vel_y + 0x38)
			if delay > 0:
				delay -= 1
				if delay == 0 and p.standing_on_object and p.support_record_index == record_index:
					p.clear_object_support_for(record_index, true)
					p.vel_y = fall_vel_y
			# The original deletes after falling below the current screen boundary.
			if raw_y > manager.player.pixel_y() + 0x300:
				request_delete(false)
		7: # SYZ1: wait one second after the upper-nibble switch is pressed
			position.x = orig_x
			if delay == 0:
				if manager.is_switch_pressed((subtype >> 4) & 0x0F):
					delay = 60
			else:
				delay -= 1
				if delay <= 0:
					subtype = (subtype & 0xF0) | 8
			raw_y = orig_y
		8: # rise 2px/frame and stop exactly $200px above the placement Y
			position.x = orig_x
			raw_y -= 2
			var stop_y = orig_y - 0x200
			if raw_y <= stop_y:
				raw_y = stop_y
				subtype = 0
				orig_y = stop_y
		_:
			position.x = orig_x
			raw_y = orig_y
	# Plat_ChangeMotion happens after movement and feeds next frame's obAngle.
	motion_angle = manager.oscillate_1a()

func _update_nudge(p: SonicPlayer) -> void:
	# Plat_Nudge depresses a platform by up to 4px with a sine curve while Sonic
	# stands on it. This is visual/physical together because obY is the platform.
	if p.standing_on_object and p.support_record_index == record_index:
		nudge = mini(0x40, nudge + 4)
	elif nudge > 0:
		nudge = maxi(0, nudge - 4)
	var nudge_y = (GenesisMath.sine(nudge & 0xFF) * 4) >> 8
	position.y = raw_y + nudge_y
