class_name S2EHZPlatformObject
extends GenesisLevelObject

# Retail Sonic 2 Object $18, EHZ subset. EHZ1 uses movement subtypes 1, 2 and 5
# with mapping frame 0; the implementation also retains the source width table
# for future S2 acts.
const WIDTHS: Array[int] = [0x20, 0x20, 0x20, 0x40, 0x30]
var sprite: Sprite2D
var orig_x := 0
var orig_y := 0
var raw_y := 0
var nudge := 0
var motion_angle := 0x80
var use_arz_art := false
var use_htz_art := false
var full_solid := false

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	raw_y = spawn_y
	use_arz_art = manager != null and bool(manager.level_definition.get("s2_arz", false))
	use_htz_art = manager != null and bool(manager.level_definition.get("s2_htz", false))
	full_solid = (subtype & 0x80) != 0
	# Obj18 indexes its width/frame pairs with ((subtype >> 3) & $E). ARZ's
	# negative/full-solid subtypes $9A/$9B therefore select pair 1, not pair 4.
	var init_index = clampi(((subtype >> 3) & 0x0E) >> 1, 0, WIDTHS.size() - 1)
	active_width = WIDTHS[init_index]
	var visual_frame = mini(init_index, 1)
	var folder = "s2_arz/platform" if use_arz_art else ("s2_htz/platform" if use_htz_art else "s2_ehz/platform")
	sprite = make_sprite("res://assets/objects/%s/%02d.png" % [folder, visual_frame])
	# Obj18 placement flip bits steer movement/status only; Obj18_Init resets render_flags to #4.
	sprite.flip_h = false
	sprite.flip_v = false

func tick() -> void:
	var p = player()
	if p == null:
		return
	var old_x = int(position.x)
	var old_y = int(position.y)
	_update_motion()
	_update_nudge(p)
	var new_x = int(position.x)
	var new_y = int(position.y)
	if full_solid:
		# Negative Obj18 subtypes switch to routine 6 and SolidObject. ARZ uses
		# y_radius=$28 for these broad submerged platforms rather than the normal
		# PlatformObject top-only $08 surface.
		var solid_half_height: int = 0x28 if use_arz_art else 0x30
		var top_y = new_y - solid_half_height
		var support_left = new_x - active_width - p.width_radius
		var support_right = new_x + active_width + p.width_radius + 1
		p.move_with_supported_object(record_index, new_x - old_x, new_y - old_y, support_left, support_right, top_y)
		p.resolve_solid_box(new_x, new_y, active_width, solid_half_height, true, record_index)
	else:
		var top_y = new_y - 8
		p.move_with_supported_object(record_index, new_x - old_x, new_y - old_y, new_x - active_width, new_x + active_width, top_y)
		p.resolve_platform_top(new_x - active_width, new_x + active_width, top_y, record_index)

func _update_motion() -> void:
	var kind = subtype & 0x0F
	var osc = manager.s2_source_osc_byte(0x18) if use_arz_art else motion_angle
	match kind:
		1:
			position.x = orig_x + GenesisMath.s8((osc - 0x40) & 0xFF)
			raw_y = orig_y
		5:
			position.x = orig_x + GenesisMath.s8((0x40 - osc) & 0xFF)
			raw_y = orig_y
		2:
			position.x = orig_x
			raw_y = orig_y + GenesisMath.s8((osc - 0x40) & 0xFF)
		6:
			position.x = orig_x
			raw_y = orig_y + GenesisMath.s8((0x40 - osc) & 0xFF)
		0x0A:
			position.x = orig_x
			raw_y = orig_y + (GenesisMath.s8((osc - 0x40) & 0xFF) >> 1)
		0x0B:
			position.x = orig_x
			raw_y = orig_y + (GenesisMath.s8((0x40 - osc) & 0xFF) >> 1)
		_:
			position.x = orig_x
			raw_y = orig_y
	motion_angle = manager.oscillate_1a()

func _update_nudge(p: SonicPlayer) -> void:
	if p.standing_on_object and p.support_record_index == record_index:
		nudge = mini(0x40, nudge + 4)
	else:
		nudge = maxi(0, nudge - 4)
	position.y = raw_y + ((GenesisMath.sine(nudge & 0xFF) * 4) >> 8)
