class_name S2WFZObject
extends GenesisLevelObject

# Phase 132: retail Sonic 2 Wing Fortress Zone object adapter. Carries the
# Phase131 boss/entrance work and finishes the remaining hook/getaway fidelity
# before the native Death Egg handoff.
# WFZ reuses many numeric IDs from unrelated zones, so every family here is
# selected only while the level definition advertises s2_wfz.

# ObjB2_Animate_Pilot / Tails_pilot_frames. Same source sequence used by SCZ.
const TAILS_PILOT_SEQUENCE: Array[int] = [
	0,0,0,0, 1,2,3,2,1,1,
	0,0,0,0, 1,2,3,2,1,1,
	4,4,1,1,
]

# ResourceLoader is globally cached, but repeatedly resolving/loading animated PNGs
# for four stacked giant propellers was still expensive in Godot. Share one explicit
# class cache and skip texture assignment when a sprite is already on that frame.
static var _texture_cache: Dictionary = {}

var sprite: Sprite2D
var pilot: Sprite2D
var state: int = 0
var timer: int = 0
var frame_counter: int = 0
var fixed_x: int = 0
var fixed_y: int = 0
var orig_x: int = 0
var orig_y: int = 0
var vx: int = 0
var vy: int = 0
var held: bool = false
var release_cooldown: int = 0
var motion_extent: int = 0
var motion_dir: int = 1
var platform_frame: int = 0
var cutscene_start_x: int = 0
var cutscene_start_y: int = 0
var cutscene_second_jump: bool = false
var getaway_velocity_index: int = 0
var getaway_layout_applied: bool = false
var hook_initial_extended: bool = false
var cutscene_player_x_fixed: int = 0
var cutscene_player_y_fixed: int = 0
var getaway_grabber_active: bool = false
var getaway_late_flames_spawned: bool = false
var getaway_flames: Array[Dictionary] = []
var child_items: Array[Dictionary] = []
var shots: Array[Dictionary] = []

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	fixed_x = spawn_x << 16
	fixed_y = spawn_y << 16
	match object_id:
		0x19: _init_platform()
		0x72: _init_conveyor()
		0x80: _init_hook()
		0x8B: _init_palette_switcher()
		0xAD: _init_clucker_base()
		0xAE: _init_clucker()
		0xB2: _init_tornado()
		0xB4: _init_vprop()
		0xB5: _init_hprop()
		0xB6: _init_tilt_platform()
		0xB8: _init_turret()
		0xB9: _init_laser()
		0xBA: _init_wheel()
		0xBC: _init_ship_fire()
		0xBD: _init_belt_platform_maker()
		0xBE: _init_retract_platform()
		0xC0: _init_launcher()
		0xC1: _init_break_panel()
		0xC2: _init_rivet()
		0xD9: _init_grab()

func tick() -> void:
	if not alive:
		return
	frame_counter += 1
	match object_id:
		0x19: _tick_platform()
		0x72: _tick_conveyor()
		0x80: _tick_hook()
		0x8B: _tick_palette_switcher()
		0xAD: _tick_clucker_base()
		0xAE: _tick_clucker()
		0xB2: _tick_tornado()
		0xB4: _tick_vprop()
		0xB5: _tick_hprop()
		0xB6: _tick_tilt_platform()
		0xB8: _tick_turret()
		0xB9: _tick_laser()
		0xBA: pass
		0xBC: _tick_ship_fire()
		0xBD: _tick_belt_platform_maker()
		0xBE: _tick_retract_platform()
		0xC0: _tick_launcher()
		0xC1: _tick_break_panel()
		0xC2: _tick_rivet()
		0xD9: _tick_grab()
	_tick_children()
	_tick_shots()

func central_despawn_x() -> int:
	# Source MarkObjGone3 uses the authored/original X for WFZ oscillating
	# platforms and scenery, rather than their current displaced coordinate.
	return orig_x

func suppress_central_despawn() -> bool:
	# The entrance/exit Tornado is level-event machinery and must survive the
	# usual object window while its routine is active.
	return object_id == 0xB2

func _new_sprite(folder: String, frame: int, z: int = 2) -> Sprite2D:
	var s = Sprite2D.new()
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	add_child(s)
	_set_frame(s, folder, frame)
	return s

func _set_frame(s: Sprite2D, folder: String, frame: int) -> void:
	if s == null:
		return
	var path: String = "res://assets/objects/s2_wfz/%s/%02d.png" % [folder, frame]
	if String(s.get_meta("wfz_frame_path", "")) == path:
		return
	var tex: Texture2D = _texture_cache.get(path) as Texture2D
	if tex == null and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
		if tex != null:
			_texture_cache[path] = tex
	if tex != null:
		s.texture = tex
		s.set_meta("wfz_frame_path", path)

func _player_overlap(cx: int, cy: int, hw: int, hh: int) -> bool:
	var p = player()
	if p == null or p.dead:
		return false
	return absi(p.pixel_x() - cx) <= hw + p.width_radius and absi(p.pixel_y() - cy) <= hh + p.height_radius

func _hazard(cx: int, cy: int, hw: int, hh: int) -> void:
	var p = player()
	if p == null or p.dead or p.hurt_state:
		return
	if _player_overlap(cx, cy, hw, hh):
		p.apply_hazard_hit(cx)

func _badnik_contact(cx: int, cy: int, hw: int, hh: int) -> bool:
	var p = player()
	if p == null or p.dead or not _player_overlap(cx, cy, hw, hh):
		return false
	if p.can_attack_object():
		if p.vel_y >= 0:
			p.vel_y = -maxi(0x200, absi(p.vel_y))
		manager.spawn_badnik_destruction(cx, cy, 0)
		manager.register_badnik_hit()
		request_delete(respawn_enabled)
		return true
	p.apply_hazard_hit(cx)
	return false

func _release_hang(p: SonicPlayer, jump_velocity: int, horizontal: bool) -> void:
	held = false
	p.object_control_override = false
	p.hang_on_pole = false
	p.mcz_vine_hang = false
	p.in_air = true
	p.jumping = false
	p.vel_y = jump_velocity
	if horizontal:
		if p.input_left:
			p.vel_x = -0x200
		elif p.input_right:
			p.vel_x = 0x200
	release_cooldown = 0x3C if (p.input_left or p.input_right or p.input_up or p.input_down) else 0x12

# -----------------------------------------------------------------------------
# $19 - WFZ moving platform. All 16 retail placements use frame 3/width $20;
# their low nibble selects the same Oscillating_Data routines as Obj19.
# -----------------------------------------------------------------------------
func _init_platform() -> void:
	active_width = 0x20
	platform_frame = 3
	sprite = _new_sprite("platform", platform_frame, 2)
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip

func _platform_offset() -> Vector2i:
	var mode = subtype & 0x0F
	var ox = 0
	var oy = 0
	match mode:
		0:
			var v0 = manager.s2_source_osc_byte(0x08)
			ox = (v0 - 0x40) if x_flip else -v0
		2:
			var v2 = manager.s2_source_osc_byte(0x1C)
			oy = (v2 - 0x80) if x_flip else -v2
		8,9,10,11,12,13,14,15:
			# Obj19's circular families consume the position bytes of channels
			# $38/$3C. The source's subtype bits mirror/swap the two axes.
			var a: int = manager.s2_source_osc_byte(0x38)
			var b: int = manager.s2_source_osc_byte(0x3C)
			# Source uses SUBI.B then EXT.W: wrap in 8-bit space before sign extension.
			var d1: int = GenesisMath.s8((a - 0x40) & 0xFF)
			var d2: int = GenesisMath.s8((b - 0x40) & 0xFF)
			if (mode & 4) != 0:
				d1 = -d1
				d2 = -d2
			if (mode & 2) != 0:
				d1 = -d1
				var t = d1
				d1 = d2
				d2 = t
			if mode >= 0x0C:
				d1 = -d1
			ox = d1
			oy = d2
		_:
			pass
	return Vector2i(ox, oy)

func _tick_platform() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var old_x: int = int(round(position.x))
	var old_y: int = int(round(position.y))
	var standing: bool = p.standing_on_object and p.support_record_index == record_index
	# Runtime video 2 showed the circular family could briefly lose the native
	# support bit on the descending quarter of its orbit, then be re-captured by
	# PlatformObject at the same screen X. Retail never loses its standing bit at
	# this point, so also recognize Sonic whose feet are still on the old surface.
	var old_top: int = old_y - 0x11
	var feet_y: int = p.pixel_y() + p.height_radius
	var riding_old_surface: bool = standing or (p.pixel_x() >= old_x - active_width and p.pixel_x() < old_x + active_width and absi(feet_y - old_top) <= 4 and p.vel_y >= 0)
	var off: Vector2i = _platform_offset()
	position = Vector2(orig_x + off.x, orig_y + off.y)
	var nx: int = int(round(position.x))
	var ny: int = int(round(position.y))
	if riding_old_surface:
		# MvSonicOnPtfm is a direct old-word -> new-word carry. Apply both axes
		# before the fresh PlatformObject contact so horizontal circular motion can
		# never be replaced by a stationary re-capture on the next frame.
		p.force_add_pixel_offset(nx - old_x, ny - old_y)
	# Retail Obj19 calls PlatformObject, never SolidObject.
	p.resolve_platform_top(nx - active_width, nx + active_width, ny - 0x11, record_index)

# -----------------------------------------------------------------------------
# $72 - conveyor volume. Retail directly adds +/-2 pixels/frame to an upright
# character in the authored rectangle; subtype $90 gives half-height $70.
# -----------------------------------------------------------------------------
func _init_conveyor() -> void:
	visible = false
	active_width = ((subtype & 0x7F) << 4) & 0xFF
	if active_width == 0: active_width = 0x80
	motion_extent = 0x70 if (subtype & 0x80) != 0 else 0x30
	motion_dir = -1 if x_flip else 1

func _tick_conveyor() -> void:
	var p = player()
	if p == null or p.dead or p.in_air: return
	var dx = p.pixel_x() - orig_x + active_width
	if dx < 0 or dx >= active_width * 2: return
	var dy = p.pixel_y() - orig_y + motion_extent
	if dy < 0 or dy >= motion_extent: return
	p.force_set_pixel_position(p.pixel_x() + 2 * motion_dir, p.pixel_y())

# -----------------------------------------------------------------------------
# $80 - lowering hook. This is the WFZ flavor of Obj80: $A0 maximum chain,
# reduced to $60 when low subtype is nonzero; $10/$11 placements begin lowered.
# -----------------------------------------------------------------------------
func _init_hook() -> void:
	active_width = 0x10
	motion_extent = 0x60 if (subtype & 0x0F) != 0 else 0xA0
	# Retail Obj80_Init stores bit $10/$20/$40 in objoff_36 as the hook's
	# *home-state selector*. Those placements begin fully down; subtype $00
	# begins fully up. Phase131 treated that flag as a movement direction and
	# therefore made several hooks retract on their own before Sonic touched them.
	hook_initial_extended = (subtype & 0x70) != 0
	state = motion_extent if hook_initial_extended else 0
	position.y = orig_y + state
	var initial_frame: int = 0 if state == 0 else clampi((state >> 4) + 1, 1, 12)
	sprite = _new_sprite("hook", initial_frame, 2)

func _tick_hook() -> void:
	var p = player()
	if p == null: return
	if release_cooldown > 0: release_cooldown -= 1
	# Obj80_WFZ_Main: a home-down hook retracts while held and returns down
	# after release; a home-up hook lowers while held and returns up afterward.
	var wants_extend: bool = held != hook_initial_extended
	if wants_extend and state < motion_extent:
		state = mini(motion_extent, state + 2)
	elif not wants_extend and state > 0:
		state = maxi(0, state - 2)
	position.y = orig_y + state
	var hook_frame: int = 0 if state == 0 else clampi((state >> 4) + 1, 1, 12)
	_set_frame(sprite, "hook", hook_frame)
	if held:
		p.force_set_pixel_position(orig_x, int(position.y) + 0x94)
		p.vel_x = 0; p.vel_y = 0; p.inertia = 0
		if p.jump_pressed:
			_release_hang(p, -0x380, true)
		return
	if release_cooldown > 0 or p.object_control_override or p.dead or p.debug_free_mode: return
	var dx = p.pixel_x() - orig_x + 0x10
	var dy = p.pixel_y() - int(position.y) - 0x88
	if dx < 0 or dx >= 0x20 or dy < 0 or dy >= 0x18: return
	held = true
	p.clear_object_support(); p.vel_x=0; p.vel_y=0; p.inertia=0
	p.in_air=true; p.rolling=false; p.jumping=false; p.hang_on_pole=true; p.mcz_vine_hang=true; p.object_control_override=true
	p.force_set_pixel_position(orig_x, int(position.y) + 0x94)

# $8B is a palette cycling selector. The terrain/palette system owns the color
# operation; keep placement semantics without accidentally instantiating CNZ art.
func _init_palette_switcher() -> void:
	visible = false
	motion_extent = [0x20,0x40,0x80,0x100][subtype & 3]
	var p = player()
	state = 1 if p != null and p.pixel_x() >= orig_x else 0

func _tick_palette_switcher() -> void:
	var p = player(); if p == null or p.dead: return
	var now_right = p.pixel_x() >= orig_x
	if now_right == (state != 0): return
	state = 1 if now_right else 0
	if absi(p.pixel_y()-orig_y) >= motion_extent: return
	# Obj8B reverses the written toggle when crossing the object from right to
	# left. render_flags bit 0 is the placement X-flip copied by ChkLoadObj.
	manager.s2_wfz_fire_toggle = (not x_flip) if now_right else x_flip

# -----------------------------------------------------------------------------
# $AD/$AE - Clucker base and badnik.
# -----------------------------------------------------------------------------
func _init_clucker_base() -> void:
	active_width = 0x1B
	sprite = _new_sprite("clucker", 12, 3)
	sprite.flip_h = x_flip

func _tick_clucker_base() -> void:
	var p = player(); if p == null: return
	p.resolve_solid_box_contact(orig_x, orig_y, 0x1B, 8, true, record_index)

func _init_clucker() -> void:
	active_width = 0x10
	sprite = _new_sprite("clucker", 21, 2)
	sprite.flip_h = x_flip
	state = 0
	timer = 0

func _tick_clucker() -> void:
	var p = player(); if p == null: return
	if state == 0:
		if absi(p.pixel_x() - orig_x) < 0x80:
			state = 1; timer = 0
	elif state == 1:
		timer += 1
		_set_frame(sprite, "clucker", mini(7, timer >> 1))
		if timer >= 16:
			state = 2; timer = 0
	elif state == 2:
		timer += 1
		_set_frame(sprite, "clucker", 8 + ((timer >> 1) & 3))
		if timer == 12:
			_spawn_shot(orig_x + (-8 if not x_flip else 8), orig_y + 0x0B, -0x200 if not x_flip else 0x200, 0, "clucker", 13, 8, 8)
		if timer >= 0x3C: timer = 0
	_badnik_contact(orig_x, orig_y, 0x10, 0x10)

# -----------------------------------------------------------------------------
# $B2 - WFZ Tornado entrance/escape object. Phase127 implements the entrance
# landing platform exactly enough for the playable handoff. Subtype $54 is kept
# visible but does not start the late escape until the boss adapter exists.
# -----------------------------------------------------------------------------
func _init_tornado() -> void:
	active_width = 0x1B
	sprite = _new_sprite("tornado", 0, 2)
	sprite.flip_h = x_flip
	# The retail B2 mapping owns a dynamic Tails pilot piece. Use the same five
	# reconstructed pilot frames and source animation sequence as Sky Chase.
	pilot = _new_sprite("pilot", 0, 4)
	pilot.position = Vector2(-36, 0)
	if subtype == 0x52:
		timer = 0xC0; vx = 0x100
	elif subtype == 0x54:
		# Retail end Tornado waits at $2C60,$05EC until the defeated player
		# reaches the lower deck, then begins the scripted Death Egg getaway.
		state = 10
		timer = 0
	else:
		state = 20

func _tick_tornado() -> void:
	var p = player(); if p == null: return
	_set_frame(sprite, "tornado", (frame_counter >> 2) & 3)
	if pilot != null:
		var pilot_step: int = (1 + int((frame_counter - 1) / 9)) % TAILS_PILOT_SEQUENCE.size()
		_set_frame(pilot, "pilot", TAILS_PILOT_SEQUENCE[pilot_step])
	if subtype == 0x54:
		_tick_tornado_end(p)
		return
	if subtype != 0x52:
		return
	var old_x = int(round(position.x)); var old_y = int(round(position.y))
	var standing = p.standing_on_object and p.support_record_index == record_index
	if state == 0:
		fixed_x += vx << 8
		timer -= 1
		if timer < 0:
			state = 1; timer = 0x60; vx = 0x100; vy = 0x100
	elif state == 1:
		fixed_x += vx << 8; fixed_y += vy << 8
		timer -= 1
		if timer < 0: state = 2
	elif state == 2:
		fixed_x += vx << 8; fixed_y += vy << 8
	position = Vector2(float(fixed_x)/65536.0, float(fixed_y)/65536.0)
	var nx = int(round(position.x)); var ny = int(round(position.y))
	if standing:
		p.move_with_supported_object(record_index, nx-old_x, ny-old_y, nx-0x1B, nx+0x1B, ny-9)
	p.resolve_solid_box_contact(nx, ny, 0x1B, 9, true, record_index)

func _spawn_getaway_flame(world_x: int, world_y: int) -> void:
	var s: Sprite2D = _new_sprite("shipfire", 0, 4)
	getaway_flames.append({"sprite": s, "x": world_x, "y": world_y})

func _spawn_initial_getaway_scenery() -> void:
	# ObjB2_Wait_Leader_position creates one invisible ship grabber at
	# $3118,$3F0 and two subtype-$58 thrust sprites at $3070,$3B0/$430.
	getaway_grabber_active = true
	_spawn_getaway_flame(0x3070, 0x3B0)
	_spawn_getaway_flame(0x3070, 0x430)

func _spawn_late_getaway_flames() -> void:
	if getaway_late_flames_spawned:
		return
	getaway_late_flames_spawned = true
	# ObjB2_Dock_on_DEZ adds three more subtype-$58 thrust pieces at $460.
	_spawn_getaway_flame(0x3090, 0x3D0)
	_spawn_getaway_flame(0x30C0, 0x3F0)
	_spawn_getaway_flame(0x3090, 0x410)

func _tick_getaway_flames() -> void:
	for item in getaway_flames:
		var raw: Variant = item.get("sprite")
		if raw == null or not is_instance_valid(raw):
			continue
		var s: Sprite2D = raw as Sprite2D
		s.position = Vector2(int(item["x"]) - int(round(position.x)), int(item["y"]) - int(round(position.y)))
		# ObjB2 subtype $58 toggles status bit 2 every frame and displays on
		# alternating frames, matching the separate ObjBC thrust flicker.
		s.visible = (frame_counter & 1) == 0

func _begin_cutscene_jump(p: SonicPlayer, jump_vx: int) -> void:
	cutscene_player_x_fixed = p.pixel_x() << 16
	cutscene_player_y_fixed = p.pixel_y() << 16
	p.clear_object_support()
	p.in_air = true
	p.rolling = true
	p.jumping = true
	p.hang_on_pole = false
	p.mcz_vine_hang = false
	p.vel_x = jump_vx
	p.vel_y = -0x680
	p.inertia = jump_vx

func _step_cutscene_jump(p: SonicPlayer) -> void:
	cutscene_player_x_fixed += GenesisMath.s16(p.vel_x) << 8
	cutscene_player_y_fixed += GenesisMath.s16(p.vel_y) << 8
	p.vel_y = GenesisMath.s16(p.vel_y + 0x38)
	p.force_set_pixel_position(cutscene_player_x_fixed >> 16, cutscene_player_y_fixed >> 16)

func _tick_tornado_end(p: SonicPlayer) -> void:
	# Retail ObjB2_Main_WFZ_End. The object-control cutscene now drives Sonic
	# with normal 8.8 jump velocities/gravity so the visible jump uses the same
	# rolling pose and ballistic shape as ordinary gameplay.
	_tick_getaway_flames()
	if state == 10:
		if manager.boss_status < 1 or p.pixel_y() < 0x5EC:
			return
		state = 11
		timer = 0
		p.control_locked = true
		p.object_control_override = true
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		return
	if state == 11:
		timer += 1
		if timer < 0x40:
			return
		state = 12
		timer = 0
		fixed_x = 0x2E58 << 16
		fixed_y = 0x66C << 16
		position = Vector2(0x2E58, 0x66C)
		_spawn_initial_getaway_scenery()
		return
	if state == 12:
		# Source presses Right here. Preserve nonzero inertia while manually
		# advancing the controlled player so SonicVisual selects Walk, not Wait.
		if p.pixel_x() < 0x2E30:
			p.in_air = false
			p.rolling = false
			p.jumping = false
			p.vel_x = 0x400
			p.vel_y = 0
			p.inertia = 0x400
			p.force_set_pixel_position(mini(0x2E30, p.pixel_x() + 4), p.pixel_y())
			return
		state = 13
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		return
	if state == 13:
		if manager.s2_wfz_bg_x_offset < 0x380:
			return
		state = 14
		timer = 0
		vx = 0x100
		vy = -0x100
		return
	if state == 14:
		timer += 1
		_step_end_tornado_motion()
		if timer < 0x30:
			return
		state = 15
		motion_extent = 0
		_begin_cutscene_jump(p, 0x280)
		return
	if state == 15:
		# ObjB2_Jump_to_plane holds Right+A for at most $38 frames. Use Sonic's
		# standard -$680 jump impulse and +$38 gravity, then land on the moving
		# PlatformObject surface as soon as the downward arc intersects it.
		timer += 1
		motion_extent += 1
		_step_end_tornado_motion()
		_step_cutscene_jump(p)
		var plane_x: int = int(round(position.x))
		var plane_top: int = int(round(position.y)) - 9 - p.height_radius
		var landed: bool = p.vel_y >= 0 and absi(p.pixel_x() - plane_x) <= 0x1B and p.pixel_y() >= plane_top
		if not landed and motion_extent < 0x48:
			return
		p.force_set_pixel_position(plane_x, plane_top)
		p.in_air = false
		p.rolling = false
		p.jumping = false
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		_apply_wfz_getaway_layout(p)
		state = 16
		return
	if state == 16:
		timer += 1
		_step_end_tornado_motion()
		_pin_player_to_tornado(p)
		if timer < 0x100:
			return
		state = 17
		getaway_velocity_index = 0
		return
	if state == 17:
		timer += 1
		_step_getaway_velocity_table()
		_step_end_tornado_motion()
		if timer < 0x437:
			_pin_player_to_tornado(p)
		elif timer < 0x460:
			if not cutscene_second_jump:
				cutscene_second_jump = true
				_begin_cutscene_jump(p, 0x100)
			_step_cutscene_jump(p)
			# The source's subtype-$56 invisible grabber is at $3118,$3F0 and
			# snaps Sonic to X-$10 with the normal Hang animation.
			if getaway_grabber_active and absi(p.pixel_x() - 0x3118) <= 0x18 and absi(p.pixel_y() - 0x3F0) <= 0x28:
				p.force_set_pixel_position(0x3108, 0x3F0)
				p.in_air = false
				p.rolling = false
				p.jumping = false
				p.hang_on_pole = true
				p.mcz_vine_hang = false
				p.vel_x = 0
				p.vel_y = 0
				p.inertia = 0
		else:
			if not manager.s2_wfz_getaway_active:
				manager.s2_wfz_getaway_active = true
				_spawn_late_getaway_flames()
			# Keep the source invisible grabber active for the long dock sequence
			# instead of pinning Sonic to the old placeholder deck coordinate.
			p.force_set_pixel_position(0x3108, 0x3F0)
			p.in_air = false
			p.rolling = false
			p.jumping = false
			p.hang_on_pole = true
			p.mcz_vine_hang = false
			p.vel_x = 0
			p.vel_y = 0
			p.inertia = 0
		if timer < 0x9C0:
			return
		state = 18
		var next_level: Vector2i = LevelCatalog.next_level(LevelCatalog.ZONE_S2_WFZ_TEST, 1)
		manager.request_level_transition(next_level.x, next_level.y)
		p.hang_on_pole = false
		p.object_control_override = false
		p.control_locked = false

func _step_end_tornado_motion() -> void:
	fixed_x += GenesisMath.s16(vx) << 8
	fixed_y += GenesisMath.s16(vy) << 8
	position = Vector2(float(fixed_x) / 65536.0, float(fixed_y) / 65536.0)

func _pin_player_to_tornado(p: SonicPlayer) -> void:
	var plane_x: int = int(round(position.x))
	var plane_top: int = int(round(position.y)) - 9 - p.height_radius
	p.force_set_pixel_position(plane_x, plane_top)
	p.vel_x = 0
	p.vel_y = 0
	p.inertia = 0
	p.in_air = false
	p.rolling = false
	p.jumping = false

func _step_getaway_velocity_table() -> void:
	# word_3AC16 / byte_3AC2A. Each signed source byte is the high byte of an
	# 8.8 velocity word, i.e. +/-1 or -2 pixels per frame.
	var thresholds: Array[int] = [0x1E0, 0x260, 0x2A0, 0x2C0, 0x300, 0x3A0, 0x3F0, 0x460, 0x4A0, 0x580]
	var velocities: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
		Vector2i(-2, 0), Vector2i(0, 0),
	]
	while getaway_velocity_index < thresholds.size() and timer >= thresholds[getaway_velocity_index]:
		var v: Vector2i = velocities[getaway_velocity_index]
		vx = v.x * 0x100
		vy = v.y * 0x100
		getaway_velocity_index += 1

func _apply_wfz_getaway_layout(p: SonicPlayer) -> void:
	if getaway_layout_applied or p.level == null:
		return
	getaway_layout_applied = true
	# Source writes $0D2/$1D2/$BD6/$CD6. With $100-byte interleaved rows these
	# are Plane-B rows 0/1 cols $52..$55 and rows 11/12 cols $56..$59.
	var row0: Array[int] = [0x50, 0x1F, 0x00, 0x25]
	var row1: Array[int] = [0x25, 0x00, 0x1F, 0x50]
	var changed: bool = false
	for i in range(4):
		changed = p.level.set_background_chunk_id_at(0x52 + i, 0, row0[i]) or changed
		changed = p.level.set_background_chunk_id_at(0x52 + i, 1, row1[i]) or changed
		changed = p.level.set_background_chunk_id_at(0x56 + i, 11, row0[i]) or changed
		changed = p.level.set_background_chunk_id_at(0x56 + i, 12, row1[i]) or changed
	if changed:
		manager.s2_wfz_background_refresh_requested = true

# -----------------------------------------------------------------------------
# $B4/$B5 - vertical and horizontal propellers.
# -----------------------------------------------------------------------------
func _init_vprop() -> void:
	sprite = _new_sprite("vprop", 0, 3)
	sprite.flip_h = x_flip

func _tick_vprop() -> void:
	_set_frame(sprite, "vprop", (frame_counter >> 1) % 3)
	_hazard(orig_x, orig_y, 8, 0x20)

func _init_hprop() -> void:
	sprite = _new_sprite("hprop", 0, 3)
	sprite.flip_h = x_flip

func _tick_hprop() -> void:
	_set_frame(sprite, "hprop", (frame_counter >> 1) % 6)
	var p = player(); if p == null or p.dead: return
	var dx = p.pixel_x() - orig_x + 0x40
	if dx < 0 or dx >= 0x80: return
	# ObjB5_CheckPlayer: source derives vertical force from Oscillating_Data+$14
	# and bends the character toward the propeller's airflow centerline.
	var d1 = manager.s2_source_osc_byte(0x14) + p.pixel_y() + 0x60 - orig_y
	if d1 < 0 or d1 >= 0x90: return
	d1 -= 0x60
	if d1 >= 0:
		d1 = GenesisMath.s16((~d1) & 0xFFFF)
		d1 = GenesisMath.s16(d1 + d1)
	d1 += 0x60
	d1 = -d1
	d1 >>= 4
	p.force_set_pixel_position(p.pixel_x(), p.pixel_y() + d1)
	p.in_air = true; p.vel_y = 0; p.inertia = 1

# -----------------------------------------------------------------------------
# $B6 - tilting platform. Retail has four mapping frames and two solid widths;
# timed placements key from VInt's high nibble, subtype $04 starts on contact.
# -----------------------------------------------------------------------------
func _init_tilt_platform() -> void:
	active_width = 0x23
	sprite = _new_sprite("tilt", 0, 2)
	sprite.flip_h = x_flip
	state = 0
	timer = 0
	platform_frame = 0

func _release_tilt_support(p: SonicPlayer) -> void:
	# loc_3B7BC explicitly clears the platform's standing bits and makes the
	# character airborne before the platform begins tilting.
	if p.standing_on_object and p.support_record_index == record_index:
		p.clear_object_support_for(record_index, true)

func _start_tilt_cycle(p: SonicPlayer) -> void:
	_release_tilt_support(p)
	state = 2
	timer = 0
	platform_frame = 0

func _tick_tilt_animation() -> bool:
	# Ani_objB6 animations 0 -> 1 -> 2: 1,2 (delay 3), hold 2 (delay $3F),
	# then 2,1,0 (delay 3). Return true when the cycle has fully reset.
	timer += 1
	if timer <= 4:
		platform_frame = 1
	elif timer <= 8:
		platform_frame = 2
	elif timer <= 72:
		platform_frame = 2
	elif timer <= 76:
		platform_frame = 2
	elif timer <= 80:
		platform_frame = 1
	elif timer <= 84:
		platform_frame = 0
	else:
		platform_frame = 0
		_set_frame(sprite, "tilt", 0)
		return true
	_set_frame(sprite, "tilt", platform_frame)
	return false

func _tick_tilt_platform() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var family: int = subtype & 6
	# All retail WFZ placements in this revision use family 0 (timed) or family 4
	# (stand-triggered). Both are SolidObject only while horizontal/waiting. Once
	# animation starts, collision is released until frame 0 returns.
	if state == 0:
		var contact: int = p.resolve_solid_box_contact(orig_x, orig_y, active_width, 4, true, record_index)
		if family == 4:
			if contact == SonicPlayer.SOLID_TOP or (p.standing_on_object and p.support_record_index == record_index):
				state = 1
				timer = 0x10
		else:
			if (manager.elapsed_frames & 0xF0) == (subtype & 0xF0):
				_start_tilt_cycle(p)
	elif state == 1:
		# Contact-triggered subtype waits $10 frames while remaining solid.
		p.resolve_solid_box_contact(orig_x, orig_y, active_width, 4, true, record_index)
		timer -= 1
		if timer < 0:
			# Obj_GetOrientationToPlayer: status bit 0 is set only when the
			# triggering player is to the platform's left.
			sprite.flip_h = p.pixel_x() < orig_x
			_start_tilt_cycle(p)
	elif state == 2:
		if _tick_tilt_animation():
			state = 0
			timer = 0

# -----------------------------------------------------------------------------
# $B8 - wall turret. Activate only when Sonic reaches its sector; fire the
# frame-dependent down/diagonal projectile once per $3C ticks.
# -----------------------------------------------------------------------------
func _init_turret() -> void:
	sprite = _new_sprite("turret", 0, 3)
	timer = 0

func _tick_turret() -> void:
	var p = player(); if p == null: return
	var dx = p.pixel_x() - orig_x
	var dy = p.pixel_y() - orig_y
	var f = 0
	if dx < -0x20: f = 1
	elif dx > 0x20: f = 2
	_set_frame(sprite, "turret", f)
	if absi(dx) > 0xC0 or absi(dy) > 0xC0: return
	timer -= 1
	if timer > 0: return
	timer = 0x3C
	match f:
		0: _spawn_shot(orig_x, orig_y+0x18, 0, 0x100, "turret", 3, 8, 8)
		1: _spawn_shot(orig_x-0x17, orig_y+0x10, -0x100, 0x100, "turret", 3, 8, 8)
		2: _spawn_shot(orig_x+0x17, orig_y+0x10, 0x100, 0x100, "turret", 4, 8, 8)

# $B9 - opening laser barrage. Source sends these left at -$1000 after they
# enter the display. They target the Tornado presentation, not Sonic collision.
func _init_laser() -> void:
	sprite = _new_sprite("laser", 0, 4)
	sprite.visible = false
	state = 0

func _tick_laser() -> void:
	if state == 0:
		var vw = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
		if orig_x >= manager.current_screen_x and orig_x <= manager.current_screen_x + vw:
			state = 1
			vx = -0x1000
			if sprite != null:
				sprite.visible = true
	if state == 1:
		fixed_x += vx << 8
		position.x = float(fixed_x)/65536.0
		if int(position.x) < manager.current_screen_x-0x40:
			request_delete(false)

func _init_wheel() -> void:
	sprite = _new_sprite("wheel", 0, 1)

# $BC - ship fire is tied to the event background X offset.
func _init_ship_fire() -> void:
	sprite = _new_sprite("shipfire", 0, 1)

func _tick_ship_fire() -> void:
	var off = manager.s2_wfz_bg_x_offset
	position.x = orig_x + off
	visible = off < 0x380 and ((frame_counter >> 2) & 1) == 0

# -----------------------------------------------------------------------------
# $BD - conveyor/belt platform maker. Every $40 frames it produces a finite
# moving child; subtype $7E travels upward, $80 downward.
# -----------------------------------------------------------------------------
func _init_belt_platform_maker() -> void:
	# Keep the parent CanvasItem visible: child belt-platform sprites inherit this
	# visibility. The maker has no sprite of its own.
	visible = true
	timer = 0

func _tick_belt_platform_maker() -> void:
	timer -= 1
	if timer > 0: return
	timer = 0x40
	var s: Sprite2D = _new_sprite("beltplat", 2, 2)
	var cvy: int = -0x100 if subtype == 0x7E else 0x100
	var life: int = 0xC7 if not x_flip else 0x1C7
	child_items.append({"kind":"belt","sprite":s,"xf":orig_x<<16,"yf":orig_y<<16,"vy":cvy,"life":life,"support":-3000-record_index*8-child_items.size(),"stage":0,"anim_tick":0})

# -----------------------------------------------------------------------------
# $BE - retracting platform. High nibble phase selects its trigger window.
# -----------------------------------------------------------------------------
func _init_retract_platform() -> void:
	active_width = 0x23
	sprite = _new_sprite("retract", 0, 2)
	state = 0
	timer = 0

func _tick_retract_platform() -> void:
	var p = player(); if p == null: return
	if state == 0:
		if ((manager.elapsed_frames + 3) & 0xF0) == (subtype & 0xF0):
			state = 1; timer = 0
	elif state == 1:
		timer += 1
		var f = clampi(int(timer / 5), 0, 3)
		_set_frame(sprite, "retract", f)
		if timer >= 15:
			state = 2; timer = 0xA0; _set_frame(sprite, "retract", 3)
	elif state == 2:
		p.resolve_platform_top(orig_x-0x23, orig_x+0x23, orig_y-0x19, record_index)
		timer -= 1
		if timer <= 0: state = 3; timer = 15
	elif state == 3:
		p.resolve_platform_top(orig_x-0x23, orig_x+0x23, orig_y-0x19, record_index)
		timer -= 1
		_set_frame(sprite, "retract", clampi(int(timer / 5), 0, 3))
		if timer <= 0:
			state = 4; timer = 0x40; _set_frame(sprite, "retract", 0)
	elif state == 4:
		timer -= 1
		if timer <= 0: state = 0

# -----------------------------------------------------------------------------
# $C0 - launcher. subtype*16 is source travel distance; placement X flip sets
# direction. Stand on it to accelerate toward its stop, then inherit velocity
# and a -$400 vertical launch before the platform returns.
# -----------------------------------------------------------------------------
func _init_launcher() -> void:
	active_width = 0x10
	motion_extent = (subtype & 0x7F) << 4
	# ObjC0_Init negates subtype travel when status bit 0 is clear.
	motion_dir = 1 if x_flip else -1
	sprite = _new_sprite("launcher", 0, 2)
	sprite.flip_h = x_flip
	vx = 0

func _tick_launcher() -> void:
	var p = player(); if p == null: return
	var old_x = int(round(position.x)); var old_y = int(round(position.y))
	var standing = p.standing_on_object and p.support_record_index == record_index
	if state == 0:
		p.resolve_platform_top(old_x-0x10, old_x+0x10, old_y-0x11, record_index)
		if standing:
			state = 1; vx = 0x0C00 * motion_dir
	elif state == 1:
		vx += 0x80 * motion_dir
		fixed_x += vx << 8
		var target = orig_x + motion_extent * motion_dir
		var nx = fixed_x >> 16
		if (motion_dir > 0 and nx >= target) or (motion_dir < 0 and nx <= target):
			nx = target; fixed_x = nx << 16
			position.x = nx
			if standing:
				p.move_with_supported_object(record_index, nx-old_x, 0, nx-0x10, nx+0x10, orig_y-0x11)
				p.vel_x = vx; p.vel_y = -0x400; p.in_air = true; p.clear_object_support()
			state = 2; timer = 0x10
		else:
			position.x = nx
			if standing: p.move_with_supported_object(record_index, nx-old_x, 0, nx-0x10, nx+0x10, orig_y-0x11)
			p.resolve_platform_top(nx-0x10, nx+0x10, orig_y-0x11, record_index)
	elif state == 2:
		timer -= 1
		if timer <= 0: state = 3
	elif state == 3:
		var nx2 = int(round(position.x)) - 4 * motion_dir
		if (motion_dir > 0 and nx2 <= orig_x) or (motion_dir < 0 and nx2 >= orig_x):
			nx2 = orig_x; state = 0; vx = 0
		position.x = nx2; fixed_x = nx2 << 16

# $C1 - breakable ship panel. Phase127 preserves its authored foreground sprite
# and lets an attacking Sonic break it; the later boss pass can add the original
# hanging/ship transition side effects without blocking traversal now.
func _init_break_panel() -> void:
	active_width = 0x20
	sprite = _new_sprite("breakpanel", 0, 2)
	timer = (subtype & 0xFF) * 0x3C
	held = false

func _break_wfz_panel(p: SonicPlayer) -> void:
	if held:
		held = false
		manager.s2_wfz_wind_holding = false
		p.object_control_override = false
		p.hang_on_pole = false
		p.mcz_vine_hang = false
		p.in_air = true
	manager.spawn_badnik_destruction(orig_x, orig_y, 0)
	request_delete(respawn_enabled)

func _tick_break_panel() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if held:
		manager.s2_wfz_wind_holding = true
		var hang_y: int = p.pixel_y()
		if p.input_up:
			hang_y -= 1
		if p.input_down:
			hang_y += 1
		hang_y = clampi(hang_y, orig_y - 0x18, orig_y + 0x18)
		p.force_set_pixel_position(orig_x - 0x14, hang_y)
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		p.in_air = true
		timer -= 1
		if p.jump_pressed or timer <= 0:
			_break_wfz_panel(p)
		return
	# ObjC1 is not a conventional SolidObject. Wind pushes Sonic into its touch
	# rectangle; it then pins him at X-=$14 until jump or subtype*$3C expires.
	if p.dead or p.debug_free_mode or p.object_control_override:
		return
	var dx: int = p.pixel_x() - orig_x
	var dy: int = p.pixel_y() - orig_y
	if dx > -0x14 and dx < 0x30 and absi(dy) <= 0x20:
		if p.can_attack_object():
			_break_wfz_panel(p)
			return
		held = true
		manager.s2_wfz_wind_holding = true
		p.clear_object_support()
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0
		p.in_air = true
		p.rolling = false
		p.jumping = false
		p.hang_on_pole = true
		p.mcz_vine_hang = true
		p.object_control_override = true
		p.force_set_pixel_position(orig_x - 0x14, p.pixel_y())

# $C2 - boss-area rivet / destroyable ship entrance. Retail only busts when
# Sonic is standing on the $1B x 9 solid while using animation 2 (roll/jump).
# The bust permanently removes the object, locks Camera_Min_X to $2880 and
# rewrites six Plane-A/foreground chunks on rows 8/9. Sonic 2 Level_Layout is
# interleaved in $100-byte rows: +$00..+$7F Plane A, +$80..+$FF Plane B, so
# source addresses $850/$950 are foreground row 8/9, columns $50..$55.
func _init_rivet() -> void:
	active_width = 0x1B
	sprite = _new_sprite("rivet", 0, 2)

func _tick_rivet() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	# ObjC2 stores MainCharacter+anim before SolidObject because contact can
	# alter the player's post-collision state. Preserve that ordering natively.
	var attacking_before_solid: bool = p.can_attack_object()
	var contact: int = p.resolve_solid_box_contact(orig_x, orig_y, 0x1B, 9, true, record_index)
	var standing: bool = contact == SonicPlayer.SOLID_TOP or (p.standing_on_object and p.support_record_index == record_index)
	if not standing or not attacking_before_solid:
		return
	manager.s2_wfz_rivet_busted = true
	p.clear_object_support_for(record_index, true)
	var changed: bool = false
	if p.level != null:
		var upper: Array[int] = [0x8A, 0x70, 0x71, 0x72, 0x73, 0x74]
		var lower: Array[int] = [0x6E, 0x78, 0x79, 0x78, 0x78, 0x7A]
		for i in range(6):
			changed = p.level.set_chunk_id_at(0x50 + i, 8, upper[i]) or changed
			changed = p.level.set_chunk_id_at(0x50 + i, 9, lower[i]) or changed
	if changed:
		manager.s2_wfz_layout_refresh_requested = true
	manager.spawn_badnik_destruction(orig_x, orig_y, 0)
	request_delete(true)

# -----------------------------------------------------------------------------
# $D9 - invisible grab point. Source rectangle is +/-$18 X and 0..$0F below
# the point; release gives -$300 and a 12/60 frame recapture cooldown.
# -----------------------------------------------------------------------------
func _init_grab() -> void:
	visible = false
	active_width = 0x18

func _tick_grab() -> void:
	var p = player(); if p == null: return
	if release_cooldown > 0: release_cooldown -= 1
	if held:
		p.force_set_pixel_position(orig_x, orig_y)
		p.vel_x=0; p.vel_y=0; p.inertia=0
		if p.jump_pressed:
			_release_hang(p, -0x300, false)
		return
	if release_cooldown > 0 or p.object_control_override or p.dead or p.debug_free_mode: return
	var dx = p.pixel_x() - orig_x + 0x18
	var dy = p.pixel_y() - orig_y
	if dx < 0 or dx >= 0x30 or dy < 0 or dy >= 0x10: return
	held=true; p.clear_object_support(); p.vel_x=0; p.vel_y=0; p.inertia=0
	p.in_air=true; p.rolling=false; p.jumping=false; p.hang_on_pole=true; p.mcz_vine_hang=true; p.object_control_override=true
	p.force_set_pixel_position(orig_x, orig_y)

# -----------------------------------------------------------------------------
# Runtime child/projectile helpers.
# -----------------------------------------------------------------------------
func _spawn_shot(x: int, y: int, svx: int, svy: int, folder: String, frame: int, hw: int, hh: int) -> void:
	var s = _new_sprite(folder, frame, 4)
	s.position = Vector2(x-position.x, y-position.y)
	shots.append({"sprite":s,"xf":x<<16,"yf":y<<16,"vx":svx,"vy":svy,"hw":hw,"hh":hh,"folder":folder,"frame":frame})

func _tick_shots() -> void:
	for i in range(shots.size()-1, -1, -1):
		var q = shots[i]
		var raw = q.get("sprite")
		if raw == null or not is_instance_valid(raw):
			shots.remove_at(i); continue
		var s: Sprite2D = raw
		q["xf"] = int(q["xf"]) + (GenesisMath.s16(int(q["vx"])) << 8)
		q["yf"] = int(q["yf"]) + (GenesisMath.s16(int(q["vy"])) << 8)
		var x = int(q["xf"]) >> 16; var y = int(q["yf"]) >> 16
		s.position = Vector2(x-position.x, y-position.y)
		_hazard(x, y, int(q["hw"]), int(q["hh"]))
		if x < manager.current_screen_x-0x100 or x > manager.current_screen_x+0x300 or y < manager.current_screen_y-0x100 or y > manager.current_screen_y+0x300:
			s.queue_free(); shots.remove_at(i); continue
		shots[i] = q

func _tick_children() -> void:
	var p: SonicPlayer = player()
	for i in range(child_items.size() - 1, -1, -1):
		var q: Dictionary = child_items[i]
		var raw: Variant = q.get("sprite")
		if raw == null or not is_instance_valid(raw):
			child_items.remove_at(i)
			continue
		var s: Sprite2D = raw as Sprite2D
		var stage: int = int(q.get("stage", 1))
		var anim_tick: int = int(q.get("anim_tick", 0))
		var support: int = int(q["support"])
		if stage == 0:
			# Ani_objBD 0: delay 3, frames 2 -> 1 -> 0, then routine advance.
			anim_tick += 1
			if anim_tick < 4:
				_set_frame(s, "beltplat", 2)
			elif anim_tick < 8:
				_set_frame(s, "beltplat", 1)
			elif anim_tick < 12:
				_set_frame(s, "beltplat", 0)
			else:
				stage = 1
				anim_tick = 0
				_set_frame(s, "beltplat", 0)
			q["stage"] = stage
			q["anim_tick"] = anim_tick
			child_items[i] = q
			continue
		if stage == 1:
			var old_y: int = int(q["yf"]) >> 16
			q["yf"] = int(q["yf"]) + (GenesisMath.s16(int(q["vy"])) << 8)
			q["life"] = int(q["life"]) - 1
			var x: int = int(q["xf"]) >> 16
			var y: int = int(q["yf"]) >> 16
			s.position = Vector2(x - position.x, y - position.y)
			if p != null:
				var standing: bool = p.standing_on_object and p.support_record_index == support
				if standing:
					p.move_with_supported_object(support, 0, y - old_y, x - 0x23, x + 0x23, y - 5)
				p.resolve_platform_top(x - 0x23, x + 0x23, y - 5, support)
			if int(q["life"]) < 0:
				if p != null:
					p.clear_object_support_for(support, true)
				q["stage"] = 2
				q["anim_tick"] = 0
			child_items[i] = q
			continue
		# Ani_objBD 1: delay 1, frames 0 -> 1 -> 2, then delete.
		anim_tick += 1
		if anim_tick < 2:
			_set_frame(s, "beltplat", 0)
		elif anim_tick < 4:
			_set_frame(s, "beltplat", 1)
		elif anim_tick < 6:
			_set_frame(s, "beltplat", 2)
		else:
			if p != null:
				p.clear_object_support_for(support, true)
			s.queue_free()
			child_items.remove_at(i)
			continue
		q["anim_tick"] = anim_tick
		child_items[i] = q
