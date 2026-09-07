class_name S2OOZObject
extends GenesisLevelObject

# Phase 117: Oil Ocean's zone-local object namespace. The state machines below
# translate the retail Sonic 2 Obj19/1C/1F/33/3D/3F/43/45/48/4A/50 routines used
# by both OOZ acts. Pattern art is reconstructed from the original mappings and
# PLC destinations rather than borrowed from objects in another zone.

var sprite: Sprite2D
var aux_sprite: Sprite2D
var frame_counter: int = 0
var state: int = 0
var timer: int = 0
var orig_x: int = 0
var orig_y: int = 0
var vel_x: int = 0
var vel_y: int = 0
var fixed_y_long: int = 0

# Obj43
var sliding_spike_partner: Sprite2D
var sliding_spike_x: Array[int] = []
var sliding_spike_dir: Array[int] = []
var sliding_spike_min_x: int = 0
var sliding_spike_max_x: int = 0

# Obj45
var pressure_home_x: int = 0
var pressure_compression: int = 0
var pressure_returning: bool = false
var pressure_player_engaged: bool = false

# Obj1F
var collapse_started: bool = false
var collapse_delay: int = 7
var collapse_fragments: Array[Sprite2D] = []
var collapse_delays: Array[int] = [0x1A,0x12,0x0A,0x02,0x16,0x0E,0x06]
var collapse_fy: Array[int] = []
var collapse_vy: Array[int] = []
var collapse_support_released: bool = false
var collapse_finished: bool = false

# Obj33
var burner_velocity: int = 0
var burner_anim_index: int = 0

# Obj3D
var launcher_broken: bool = false
var launcher_fragments: Array[Sprite2D] = []
var launcher_fx: Array[int] = []
var launcher_fy: Array[int] = []
var launcher_vx: Array[int] = []
var launcher_vy: Array[int] = []
var launcher_captured: bool = false

# Obj3F
var fan_off: bool = false
var fan_timer: int = 0
var fan_anim: int = 0
var fan_anim_timer: int = 0
var fan_slow_accum: int = 0

# Obj48
var transport_state: int = 0
var transport_base_frame: int = 0
var transport_frame: int = 0
var transport_reverse: bool = false
var transport_timer: int = 0

# Obj50
var aquis_wing: Sprite2D
var aquis_shooting: bool = false
var aquis_shots_remaining: int = 3
var aquis_wing_frame: int = 1

# Obj4A
var octus_air_anim_counter: int = 0

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	match object_id:
		0x19: _init_elevator()
		0x1C: _init_oilfall()
		0x1F: _init_collapse()
		0x33: _init_burner()
		0x3D: _init_launcher()
		0x3F: _init_fan()
		0x43: _init_sliding_spike()
		0x45: _init_pressure_spring()
		0x48: _init_transporter()
		0x4A: _init_octus()
		0x50: _init_aquis()

func tick() -> void:
	frame_counter += 1
	match object_id:
		0x19: _tick_elevator()
		0x1C: pass
		0x1F: _tick_collapse()
		0x33: _tick_burner()
		0x3D: _tick_launcher()
		0x3F: _tick_fan()
		0x43: _tick_sliding_spike()
		0x45: _tick_pressure_spring()
		0x48: _tick_transporter()
		0x4A: _tick_octus()
		0x50: _tick_aquis()

func _new_sprite(folder: String, frame: int, z: int = 0) -> Sprite2D:
	var s: Sprite2D = make_sprite("res://assets/objects/s2_ooz/%s/%02d.png" % [folder, frame], z)
	return s

func _set_frame(s: Sprite2D, folder: String, frame: int) -> void:
	if s == null:
		return
	var path: String = "res://assets/objects/s2_ooz/%s/%02d.png" % [folder, frame]
	if ResourceLoader.exists(path):
		s.texture = load(path)

func _player_on_screen(p: SonicPlayer) -> bool:
	if manager == null or p == null:
		return false
	var vw: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 320))
	var vh: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 224))
	return p.pixel_x() >= manager.current_screen_x - 32 and p.pixel_x() <= manager.current_screen_x + vw + 32 and p.pixel_y() >= manager.current_screen_y - 48 and p.pixel_y() <= manager.current_screen_y + vh + 48

func _move_player_pixels(p: SonicPlayer, dx: int, dy: int) -> void:
	p.fixed_x += dx << 16
	p.fixed_y += dy << 16
	# fixed_x/fixed_y are the authoritative 16.16 position just like obX/obY.
	# Re-derive Node2D position from them instead of adding a second independent
	# delta. This keeps repeated fan/launcher corrections phase-locked to Sonic's
	# physics subpixel state and removes the visible one-frame vertical wobble.
	p.position = Vector2(float(p.fixed_x) / 65536.0, float(p.fixed_y) / 65536.0)

func suppress_central_despawn() -> bool:
	# Retail Obj48 bypasses MarkObjGone while either character is being carried
	# between spheres. Obj3D's invisible launcher does the same while its player
	# state byte is non-zero. The authored object X can therefore leave the normal
	# ObjPosLoad window while Sonic is still controlled; central despawn must not
	# erase the controller mid-flight.
	if manager == null:
		return false
	if object_id == 0x48:
		return transport_state != 0 or manager.ooz_control_owner_record == record_index
	if object_id == 0x3D:
		return launcher_captured or manager.ooz_control_owner_record == record_index
	return false

func _set_player_pixel_position(p: SonicPlayer, px: int, py: int) -> void:
	p.fixed_x = (px << 16) | (p.fixed_x & 0xFFFF)
	p.fixed_y = (py << 16) | (p.fixed_y & 0xFFFF)
	p.position = Vector2(float(p.fixed_x) / 65536.0, float(p.fixed_y) / 65536.0)

func _react_badnik(hw: int = 12, hh: int = 12) -> bool:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		return false
	if absi(p.pixel_x() - int(position.x)) > hw + p.width_radius or absi(p.pixel_y() - int(position.y)) > hh + p.height_radius:
		return false
	if p.invincible_timer > 0 or p.rolling or p.object_attack_active:
		var award: int = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(int(position.x), int(position.y), award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0:
			p.vel_y = -p.vel_y
		else:
			p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
		return true
	p.apply_hazard_hit(int(position.x))
	return false

# -----------------------------------------------------------------------------
# $19 - OOZ rising elevator. OOZ1 placements are subtype $23: the broad frame
# waits for Sonic, then accelerates toward Y = spawnY-$60 and brakes to rest.
# X-flipped placements begin at spawnY-$C0, exactly like status bit 0 retail.
# -----------------------------------------------------------------------------
func _init_elevator() -> void:
	var prop: int = (subtype >> 4) & 3
	var widths: Array[int] = [0x20,0x18,0x40,0x20]
	var frames: Array[int] = [0,1,2,3]
	active_width = widths[prop]
	sprite = _new_sprite("elevator", frames[prop], 1)
	state = subtype & 0x0F
	if state == 3 and x_flip:
		position.y -= 0xC0

func _tick_elevator() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var old_x: int = int(round(position.x))
	var old_y: int = int(round(position.y))
	if state == 3:
		if p.standing_on_object and p.support_record_index == record_index:
			state = 4
	elif state == 4:
		position.y += float(vel_y) / 256.0
		var target: int = orig_y - 0x60
		vel_y = GenesisMath.s16(vel_y + (8 if target >= int(round(position.y)) else -8))
		if vel_y == 0:
			state = 5
	var nx: int = int(round(position.x))
	var ny: int = int(round(position.y))
	var top: int = ny - 0x11
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, nx-old_x, ny-old_y, nx-active_width, nx+active_width, top)
	p.resolve_platform_top(nx-active_width, nx+active_width, top, record_index)

# -----------------------------------------------------------------------------
# $1C - OOZ cascading/falling oil scenery. Retail Obj1C is intentionally static:
# the subtype selects one of the two mapping banks and then MarkObjGone handles it.
# -----------------------------------------------------------------------------
func _init_oilfall() -> void:
	active_width = 4
	if subtype >= 0x10:
		var f: int = clampi(subtype - 0x10, 0, 4)
		sprite = _new_sprite("oilfall_long", f, 1)
	else:
		var f2: int = clampi(subtype - 0x0A, 0, 5)
		sprite = _new_sprite("oilfall_short", f2, 1)

# -----------------------------------------------------------------------------
# $1F - OOZ collapsing platform. Fragment 0 retains the stood-on relationship
# until its own $1A timer expires; the remaining six pieces use the exact OOZ
# delay table. The dead placement remains an inert tombstone until normal
# offscreen teardown, avoiding immediate nearby respawn.
# -----------------------------------------------------------------------------
func _init_collapse() -> void:
	active_width = 0x40
	sprite = _new_sprite("collapse", 0, 1)

func _tick_collapse() -> void:
	var p: SonicPlayer = player()
	if p == null or collapse_finished:
		return
	var top: int = orig_y - 0x10
	if not collapse_started:
		var stood: bool = p.resolve_platform_top(orig_x-0x40, orig_x+0x40, top, record_index)
		if stood or (p.standing_on_object and p.support_record_index == record_index):
			collapse_started = true
		return
	if collapse_delay > 0:
		collapse_delay -= 1
		p.resolve_platform_top(orig_x-0x40, orig_x+0x40, top, record_index)
		return
	if collapse_fragments.is_empty():
		sprite.visible = false
		for i in range(7):
			var f: Sprite2D = _new_sprite("collapse_fragments", i, 1)
			f.flip_h = x_flip; f.flip_v = y_flip
			collapse_fragments.append(f); collapse_fy.append(0); collapse_vy.append(0)
		p.resolve_platform_top(orig_x-0x40, orig_x+0x40, top, record_index)
		return
	if not collapse_support_released and collapse_delays[0] > 0:
		p.resolve_platform_top(orig_x-0x40, orig_x+0x40, top, record_index)
	var all_far: bool = true
	for i in range(collapse_fragments.size()):
		if collapse_delays[i] > 0:
			collapse_delays[i] -= 1
			if i == 0 and collapse_delays[i] == 0 and not collapse_support_released:
				p.clear_object_support_for(record_index, true)
				collapse_support_released = true
			all_far = false
			continue
		collapse_fy[i] += collapse_vy[i]
		collapse_vy[i] = GenesisMath.s16(collapse_vy[i] + 0x38)
		collapse_fragments[i].position.y = float(collapse_fy[i] >> 8)
		if collapse_fragments[i].position.y < 0x180:
			all_far = false
	if all_far:
		for f in collapse_fragments:
			f.visible = false
		collapse_finished = true

# -----------------------------------------------------------------------------
# $33 - Burner lid + stationary flame child. Subtype 0 is the timed bouncing
# OOZ1 variant: wait $78, launch at -$96800, gravity +$3800, quarter-bounce at
# the home Y until the speed falls below $10000. The flame becomes live only
# when the fixed child is at least $14 pixels below the airborne lid.
# -----------------------------------------------------------------------------
func _init_burner() -> void:
	active_width = 0x18
	sprite = _new_sprite("burner_lid", 0, 1)
	aux_sprite = _new_sprite("burner_flame", 0, 2)
	fixed_y_long = orig_y << 16
	timer = 0x78
	state = 0

func _tick_burner() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var old_y: int = int(round(position.y))
	if state == 0:
		timer -= 1
		if timer < 0:
			timer = 0x78
			burner_velocity = -0x96800
			state = 1
	else:
		fixed_y_long += burner_velocity
		burner_velocity += 0x3800
		var iy: int = fixed_y_long >> 16
		if iy >= orig_y:
			fixed_y_long = orig_y << 16
			if burner_velocity < 0x10000:
				state = 0
			else:
				burner_velocity = -(burner_velocity >> 2)
		position.y = float(fixed_y_long) / 65536.0
	var ny: int = int(round(position.y))
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, 0, ny-old_y, orig_x-0x18, orig_x+0x18, ny-8)
	p.resolve_solid_box_contact(orig_x, ny, 0x18, 8, true, record_index)
	# Flame child is fixed at spawnY-$10 rather than riding the lid.
	aux_sprite.position = Vector2(0, float((orig_y-0x10) - position.y))
	var flame_distance: int = (orig_y - 0x10) - ny
	var flame_live: bool = flame_distance >= 0x14
	aux_sprite.visible = flame_live
	if flame_live:
		var seq: Array[int] = [2,0,2,0,2,0,1]
		burner_anim_index = int(frame_counter / 3)
		_set_frame(aux_sprite, "burner_flame", seq[burner_anim_index % seq.size()])
		var fy: int = orig_y - 0x10
		if absi(p.pixel_x()-orig_x) <= 0x10+p.width_radius and absi(p.pixel_y()-fy) <= 0x10+p.height_radius and p.invincible_timer <= 0:
			p.apply_hazard_hit(orig_x)

# -----------------------------------------------------------------------------
# $3D - breakable striped launcher. OOZ1 uses the horizontal-art/subtype-1
# version, which launches the captured rolling player vertically at -$800.
# -----------------------------------------------------------------------------
func _init_launcher() -> void:
	active_width = 0x10
	sprite = _new_sprite("launcher_vertical" if subtype == 0 else "launcher_horizontal", 0 if subtype == 0 else 2, 1)

func _tick_launcher() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if not launcher_broken:
		# Obj3D snapshots the character animation before SolidObject runs, then uses
		# d1=$1B/d2=$10/d3=$11. SolidObject's d1 includes Sonic's centre margin;
		# the native helper expands the raw object box itself, so the striped block
		# remains its actual $10 half-width. The critical retail detail is snapshotting
		# the Roll animation BEFORE collision resolution changes Sonic's state.
		var rolling_before_solid: bool = p.rolling or p.object_attack_active
		var supported_before: bool = p.standing_on_object and p.support_record_index == record_index
		var contact: int = p.resolve_solid_box_contact(orig_x, orig_y, 0x10, 0x10, true, record_index)
		var supported_after: bool = p.standing_on_object and p.support_record_index == record_index
		# Retail tests the saved Roll animation after SolidObject, and the source's
		# d1=$1B standing width is wider than the raw $10 art half-width. Accept the
		# authoritative support state or an overlapping downward rolling top hit so
		# Act 2's subtype-$01 giant launchers cannot miss the break transition, even
		# when terrain resolution has already pushed the rolling body several pixels
		# through the narrow source top-contact band before ExecuteObjects runs.
		var rolling_top_overlap: bool = rolling_before_solid and p.vel_y >= 0 and absi(p.pixel_x()-orig_x) <= 0x1B and p.pixel_y() <= orig_y and (p.pixel_y()+p.height_radius) >= (orig_y-0x28)
		if rolling_before_solid and (contact == SonicPlayer.SOLID_TOP or supported_before or supported_after or rolling_top_overlap):
			_break_launcher(p)
		return
	_update_launcher_fragments()
	if manager.ooz_control_owner_record != record_index:
		launcher_captured = false
	if not launcher_captured:
		var dx: int = p.pixel_x()-orig_x
		var dy: int = p.pixel_y()-orig_y
		var inside: bool = absi(dx) < 0x10
		if subtype == 0:
			inside = inside and dy >= 0 and dy < 0x10
		else:
			inside = inside and dy >= -0x10 and dy < 0
		if inside and not p.dead and not p.debug_free_mode:
			_capture_launcher(p)
	if launcher_captured and manager.ooz_control_owner_record == record_index:
		if not _player_on_screen(p):
			_release_ooz_control(p)
			launcher_captured = false
		else:
			_move_player_pixels(p, int(p.vel_x / 256), int(p.vel_y / 256))

func _break_launcher(p: SonicPlayer) -> void:
	launcher_broken = true
	sprite.visible = false
	p.clear_object_support_for(record_index, true)
	# The retail break routine first forces the standing rolling character into
	# airborne Roll, then clones the invisible launcher. On the next object pass
	# that altered radius/position is already inside the $10-pixel capture strip.
	# Native solid resolution restores standing geometry sooner, so capture the
	# subtype-$01 giant vertical launcher from the same confirmed rolling top hit.
	if subtype != 0 and not p.dead and not p.debug_free_mode:
		_capture_launcher(p)
	var folder: String = "launcher_vertical_fragments" if subtype == 0 else "launcher_horizontal_fragments"
	var vels: Array[Vector2i] = [
		Vector2i(-0x400,-0x400),Vector2i(-0x200,-0x400),Vector2i(0x200,-0x400),Vector2i(0x400,-0x400),
		Vector2i(-0x3C0,-0x200),Vector2i(-0x1C0,-0x200),Vector2i(0x1C0,-0x200),Vector2i(0x3C0,-0x200),
		Vector2i(-0x380,0x200),Vector2i(-0x180,0x200),Vector2i(0x180,0x200),Vector2i(0x380,0x200),
		Vector2i(-0x340,0x400),Vector2i(-0x140,0x400),Vector2i(0x140,0x400),Vector2i(0x340,0x400)]
	for i in range(16):
		var f: Sprite2D = _new_sprite(folder, i, 1)
		launcher_fragments.append(f); launcher_fx.append(0); launcher_fy.append(0); launcher_vx.append(vels[i].x); launcher_vy.append(vels[i].y)


func _capture_launcher(p: SonicPlayer) -> void:
	launcher_captured = true
	manager.ooz_control_owner_record = record_index
	p.clear_object_support()
	p.object_control_override = true
	p.rolling = true
	p.in_air = true
	p.jumping = false
	p.inertia = 0x800
	if subtype == 0:
		_set_player_pixel_position(p, p.pixel_x(), orig_y)
		p.vel_x = 0x800
		p.vel_y = 0
	else:
		_set_player_pixel_position(p, orig_x, p.pixel_y())
		p.vel_x = 0
		p.vel_y = -0x800
	SonicAudio.play_sfx(SonicAudio.SFX_ROLL)

func _update_launcher_fragments() -> void:
	for i in range(launcher_fragments.size()):
		launcher_fx[i] += launcher_vx[i]
		launcher_fy[i] += launcher_vy[i]
		launcher_vy[i] = GenesisMath.s16(launcher_vy[i] + 0x18)
		launcher_fragments[i].position = Vector2(float(launcher_fx[i])/256.0, float(launcher_fy[i])/256.0)

func _release_ooz_control(p: SonicPlayer) -> void:
	if manager.ooz_control_owner_record == record_index:
		manager.ooz_control_owner_record = -1
		p.ooz_transport_invulnerable = false
	p.object_control_override = false
	p.in_air = true
	p.jumping = false

# -----------------------------------------------------------------------------
# $3F - horizontal/vertical OOZ fan. Bit 7 selects vertical; bit 1 makes it
# permanently active. Otherwise retail starts with $78 frames off then $B4 on.
# -----------------------------------------------------------------------------
func _init_fan() -> void:
	active_width = 0x10
	var vertical: bool = (subtype & 0x80) != 0
	sprite = _new_sprite("fan_vertical" if vertical else "fan_horizontal", 0, 1)
	fan_timer = 0
	fan_off = false

func _tick_fan() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return

	# Obj3F uses a two-state timer only when subtype bit 1 is clear. The source
	# begins with timer 0 / state 0, so the first tick enters the $78-frame
	# slow/off phase; the following active phase lasts $B4 frames. objoff_34 is
	# reset at each transition and drives the deliberately decelerating fan art.
	if (subtype & 2) == 0:
		fan_timer -= 1
		if fan_timer < 0:
			fan_slow_accum = 0
			fan_off = not fan_off
			fan_timer = 0x78 if fan_off else 0xB4

	if not fan_off:
		if (subtype & 0x80) != 0:
			_apply_vertical_fan(p)
		else:
			_apply_horizontal_fan(p)

	# Retail animation timing is not a fixed "slow" speed. While the fan is
	# off, the delay grows by $2A each time a frame advances (up to $400); only
	# the low byte is loaded into anim_frame_duration. While active, duration 0
	# makes the six mapping frames advance every VBlank.
	fan_anim_timer -= 1
	var advance_frame: bool = false
	if fan_anim_timer < 0:
		if fan_off:
			if fan_slow_accum < 0x400:
				fan_slow_accum += 0x2A
				fan_anim_timer = fan_slow_accum & 0xFF
				advance_frame = true
		else:
			fan_anim_timer = 0
			advance_frame = true
	if advance_frame:
		fan_anim = (fan_anim + 1) % 6
	var base: int = 5 if (subtype & 1) != 0 else 0
	_set_frame(sprite, "fan_vertical" if (subtype & 0x80) != 0 else "fan_horizontal", base + fan_anim)

func _apply_horizontal_fan(p: SonicPlayer) -> void:
	if p.dead or p.object_control_override:
		return
	var d0: int = p.pixel_x() - orig_x
	if not x_flip:
		d0 = -d0
	d0 += 0x50
	if (d0 & 0xFFFF) >= 0xF0:
		return
	var d1: int = p.pixel_y() + 0x60 - orig_y
	if d1 < 0 or d1 >= 0x70:
		return
	d0 -= 0x50
	if d0 < 0:
		d0 = (~d0) & 0xFFFF
		d0 = (d0 + d0) & 0xFFFF
	d0 = (d0 + 0x60) & 0xFFFF
	if not x_flip:
		d0 = (-GenesisMath.s16(d0)) & 0xFFFF
	var low: int = d0 & 0xFF
	low = (-low) & 0xFF
	d0 = (d0 & 0xFF00) | low
	d0 = GenesisMath.s16(d0) >> 4
	if (subtype & 1) != 0:
		d0 = -d0
	_move_player_pixels(p, d0, 0)

func _apply_vertical_fan(p: SonicPlayer) -> void:
	if p.dead or p.object_control_override:
		return
	var d0: int = p.pixel_x() - orig_x + 0x40
	if d0 < 0 or d0 >= 0x80:
		return
	var d1: int = manager.s2_source_osc_byte(0x14) + p.pixel_y() + 0x60 - orig_y
	if d1 < 0 or d1 >= 0x90:
		return
	d1 -= 0x60
	if d1 < 0:
		d1 = (~d1) & 0xFFFF
		d1 = (d1 + d1) & 0xFFFF
	d1 = GenesisMath.s16((d1 + 0x60) & 0xFFFF)
	# The 68000 applies the force to a word-position game, but Sonic's native PC
	# position is 16.16. Preserve the four discarded source bits as subpixels so
	# the vertical fan envelope does not jump a whole pixel whenever d1 crosses a
	# >>4 boundary. The integer trajectory remains the same at frame scale.
	var fan_delta_fixed: int = -d1 << 12
	p.fixed_y += fan_delta_fixed
	# Sonic's gameplay position may retain the extra four fixed-point bits, but
	# Genesis sprite coordinates are whole pixels. Rendering the fractional value
	# directly made Sonic shimmer between pixel rows under a vertical fan. Keep the
	# accumulator and present its integer word, matching the VDP/object position.
	p.position = Vector2(float(p.pixel_x()), float(p.pixel_y()))
	p.in_air = true
	p.vel_y = 0
	p.inertia = 1
	# Obj3F seeds Sonic's flip-angle tumble only when it is not already active:
	# flip_angle=1, flips_remaining=$7F, flip_speed=8. The port's S2 tumble
	# presentation fields are the direct native equivalent of those OST bytes.
	if not p.s2_twirl_active:
		p.s2_twirl_active = true
		p.s2_twirl_angle = 1
		p.s2_twirl_speed = 8
		p.s2_twirl_remaining = 0x7F
		p.s2_twirl_direction = 1
		p.s2_twirl_turned = false

# -----------------------------------------------------------------------------
# $43 - OOZ sliding spike obstacle. Subtype selects one of the three retail
# byte_23E54 configurations. A single placement may own one or two visible
# spike heads; each head advances exactly one pixel per frame and reverses at
# the shared source limits. Paired heads also reverse when their 24px radii
# cross at the source's exact $30-pixel centre separation test.
# -----------------------------------------------------------------------------
func _init_sliding_spike() -> void:
	active_width = 0x18
	sprite = _new_sprite("sliding_spike", 0, 70)
	# Source priority 4 is above the high-priority foreground patterns used here.
	# Use an absolute canvas Z so a sibling foreground renderer cannot cover it.
	sprite.z_as_relative = false
	sprite.z_index = 120
	var travel: int = 0x68
	var offsets: Array[int] = [0]
	match subtype & 0xFF:
		0x06:
			travel = 0xE8
			offsets = [-0x18, 0x18]
		0x0C:
			travel = 0xA8
			offsets = [-0x58, -0x28]
		_:
			travel = 0x68
			offsets = [0]
	sliding_spike_min_x = orig_x - travel
	sliding_spike_max_x = orig_x + travel
	sliding_spike_x.clear()
	sliding_spike_dir.clear()
	for i in range(offsets.size()):
		sliding_spike_x.append(orig_x + offsets[i])
		# Parent starts moving left (objoff_36=0); the generated child starts
		# moving right (objoff_36=1).
		sliding_spike_dir.append(-1 if i == 0 else 1)
	if offsets.size() > 1:
		sliding_spike_partner = _new_sprite("sliding_spike", 0, 70)
		sliding_spike_partner.z_as_relative = false
		sliding_spike_partner.z_index = 120
	_update_sliding_spike_sprites()

func _tick_sliding_spike() -> void:
	if sliding_spike_x.is_empty():
		return
	for i in range(sliding_spike_x.size()):
		var nx: int = sliding_spike_x[i] + sliding_spike_dir[i]
		if nx <= sliding_spike_min_x:
			nx = sliding_spike_min_x
			sliding_spike_dir[i] = 1
		elif nx >= sliding_spike_max_x:
			nx = sliding_spike_max_x
			sliding_spike_dir[i] = -1
		sliding_spike_x[i] = nx
	# loc_23FB0 reverses the paired heads at a $30-pixel centre separation.
	# Compare the crossing as well as equality: native object scheduling can put
	# one head one pixel past the exact word equality before its partner executes.
	if sliding_spike_x.size() == 2 and sliding_spike_dir[0] > 0 and sliding_spike_dir[1] < 0:
		# loc_23FB0 compares (child_x-$18) with (parent_x+$18), i.e. the
		# generated right-hand child reaches exactly $30 pixels from the parent.
		# The old inequality compared the operands backwards, so the pair could
		# overlap and pass through one another without ever reversing. Snap to the
		# source contact separation if native scheduling crosses it by one pixel.
		if sliding_spike_x[1] - 0x18 <= sliding_spike_x[0] + 0x18:
			var midpoint: int = int((sliding_spike_x[0] + sliding_spike_x[1]) / 2)
			sliding_spike_x[0] = midpoint - 0x18
			sliding_spike_x[1] = midpoint + 0x18
			sliding_spike_dir[0] = -1
			sliding_spike_dir[1] = 1
	_update_sliding_spike_sprites()
	var p: SonicPlayer = player()
	if p == null or p.dead or p.invincible_timer > 0:
		return
	for sx in sliding_spike_x:
		if absi(p.pixel_x() - sx) <= 0x18 + p.width_radius and absi(p.pixel_y() - orig_y) <= 0x28 + p.height_radius:
			p.apply_hazard_hit(sx)
			return

func _update_sliding_spike_sprites() -> void:
	if sprite != null and not sliding_spike_x.is_empty():
		sprite.position = Vector2(sliding_spike_x[0] - orig_x, 0)
	if sliding_spike_partner != null and sliding_spike_x.size() > 1:
		sliding_spike_partner.position = Vector2(sliding_spike_x[1] - orig_x, 0)

# -----------------------------------------------------------------------------
# $45 - OOZ pressure spring. OOZ2 uses the horizontal $10/$30 subtypes. The
# source shifts the spring one pixel into its housing while Sonic pushes it,
# stores that displacement in mapping frames $A..$13, and on release converts
# (compression+$A)<<7 into horizontal launch speed before the spring returns
# home four pixels per frame.
# -----------------------------------------------------------------------------
func _init_pressure_spring() -> void:
	active_width = 0x14
	pressure_home_x = orig_x
	pressure_compression = 0
	pressure_player_engaged = false
	sprite = _new_sprite("pressure_spring", 0x0A, 1)

func _tick_pressure_spring() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	var inertia_before: int = p.inertia
	# Retail passes d1=$1F,d2=$0C,d3=$0D to SolidObject_Always. As with
	# Obj3D, d1 includes Sonic's centre margin; the native helper wants the
	# object's raw $14 half-width and $0C half-height.
	var contact: int = p.resolve_solid_box_contact(int(round(position.x)), orig_y, 0x14, 0x0C, true, record_index)
	var exposed_contact: bool = contact == (SonicPlayer.SOLID_LEFT if x_flip else SonicPlayer.SOLID_RIGHT)
	var pushing_toward: bool
	if x_flip:
		pushing_toward = p.input_right or inertia_before > 0
	else:
		pushing_toward = p.input_left or inertia_before < 0
	var valid_push: bool = exposed_contact and pushing_toward and not p.in_air and not p.dead

	if valid_push:
		pressure_player_engaged = true
		pressure_returning = false
		if pressure_compression < 0x12:
			pressure_compression += 1
			var step: int = 1 if x_flip else -1
			position.x += step
			_move_player_pixels(p, step, 0)
			p.vel_x = 0
			p.inertia = 0x40 if x_flip else -0x40
		_set_frame(sprite, "pressure_spring", 0x0A + pressure_compression)
		return

	if pressure_player_engaged:
		pressure_player_engaged = false
		if pressure_compression > 0:
			var launch_mag: int = (pressure_compression + 0x0A) << 7
			p.clear_object_support_for(record_index, true)
			p.pushing = false
			p.skidding = false
			p.vel_x = -launch_mag if x_flip else launch_mag
			p.inertia = p.vel_x
			p.facing_left = x_flip
			SonicAudio.play_sfx(SonicAudio.SFX_SPRING)
		pressure_returning = true

	if pressure_compression > 0:
		var step_back: int = mini(4, pressure_compression)
		pressure_compression -= step_back
		var return_dx: int = -step_back if x_flip else step_back
		position.x += return_dx
		if pressure_compression == 0:
			position.x = pressure_home_x
			pressure_returning = false
		_set_frame(sprite, "pressure_spring", 0x0A + pressure_compression)

# -----------------------------------------------------------------------------
# $48 - OOZ round transporter. The exact property table controls the initial
# mapping frame/flips, then the sphere winds to its opposite frame and launches
# at $1000 in one of the four cardinal directions. Negative subtypes release
# Sonic immediately; ordinary ones keep object control between transporters.
# -----------------------------------------------------------------------------
func _init_transporter() -> void:
	active_width = 0x28
	var props: Array[Vector2i] = [Vector2i(4,0),Vector2i(6,7),Vector2i(7,0),Vector2i(5,7),Vector2i(5,0),Vector2i(4,7),Vector2i(6,0),Vector2i(7,7)]
	var pi: int = (subtype & 0x0F) + (4 if x_flip else 0)
	pi = clampi(pi, 0, 7)
	var pr: Vector2i = props[pi]
	transport_base_frame = pr.y
	transport_frame = transport_base_frame
	transport_reverse = transport_base_frame == 7
	sprite = _new_sprite("transporter", transport_frame, 1)
	sprite.flip_h = (pr.x & 1) != 0
	sprite.flip_v = (pr.x & 2) != 0

func _tick_transporter() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if transport_state == 0:
		if not p.dead and not p.debug_free_mode and absi(p.pixel_x()-orig_x) < 0x10 and absi(p.pixel_y()-orig_y) < 0x10:
			_capture_transporter(p)
	elif transport_state == 1:
		transport_timer -= 1
		if transport_timer < 0:
			transport_timer = 7
			transport_frame += -1 if transport_reverse else 1
			transport_frame = clampi(transport_frame,0,7)
			_set_frame(sprite,"transporter",transport_frame)
			if transport_frame == (0 if transport_reverse else 7):
				_launch_transporter(p)
	elif transport_state == 2:
		if manager.ooz_control_owner_record != record_index:
			transport_state = 0; transport_frame = transport_base_frame; _set_frame(sprite,"transporter",transport_frame)
			return
		if not _player_on_screen(p):
			_release_ooz_control(p); transport_state = 0
			return
		_move_player_pixels(p, int(p.vel_x/256), int(p.vel_y/256))
		transport_timer -= 1
		if transport_timer < 0:
			transport_timer = 1
			if transport_reverse and transport_frame < 7: transport_frame += 1
			elif not transport_reverse and transport_frame > 0: transport_frame -= 1
			_set_frame(sprite,"transporter",transport_frame)
	else:
		transport_timer -= 1
		if transport_timer < 0:
			transport_state = 0

func _capture_transporter(p: SonicPlayer) -> void:
	manager.ooz_control_owner_record = record_index
	transport_state = 1; transport_timer = 7; transport_frame = transport_base_frame
	_set_player_pixel_position(p, orig_x, orig_y)
	p.clear_object_support(); p.object_control_override = true; p.ooz_transport_invulnerable = true; p.rolling = true; p.in_air = true; p.jumping = false
	p.inertia = 0x1000; p.vel_x = 0; p.vel_y = 0
	_set_frame(sprite,"transporter",transport_frame)

func _launch_transporter(p: SonicPlayer) -> void:
	var direction: int = ((subtype & 0xFF) + 1 - (2 if x_flip else 0)) & 3
	var dirs: Array[Vector2i] = [Vector2i(0,-0x1000),Vector2i(0x1000,0),Vector2i(0,0x1000),Vector2i(-0x1000,0)]
	p.vel_x = dirs[direction].x; p.vel_y = dirs[direction].y
	transport_timer = 3
	if (subtype & 0x80) != 0:
		_release_ooz_control(p); transport_state = 3; transport_timer = 7
	else:
		transport_state = 2

# -----------------------------------------------------------------------------
# $4A - Octus. Falls to floor, waits for Sonic within $80, delays $20, rises,
# fires at the apex, hovers $3C, then returns to its exact original floor Y.
# -----------------------------------------------------------------------------
func _init_octus() -> void:
	active_width = 0x10
	sprite = _new_sprite("octus", 1, 2)
	state = -1; vel_y = 0

func _tick_octus() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if state == -1:
		position.y += float(vel_y)/256.0; vel_y = GenesisMath.s16(vel_y + 0x38)
		var hit: Dictionary = manager.collision.find_floor_sensor(int(position.x), int(position.y)+0x0B, true, false)
		var d: int = int(hit.get("distance",0x7FFF))
		if d < 0:
			position.y += d; vel_y = 0; orig_y = int(round(position.y)); state = 0; sprite.flip_h = p.pixel_x() > int(position.x)
	else:
		match state:
			0:
				_set_frame(sprite,"octus",1 if int(frame_counter/16)%2==0 else 0)
				if absi(p.pixel_x()-int(position.x)) <= 0x80:
					state = 1; timer = 0x20; _set_frame(sprite,"octus",4)
			1:
				timer -= 1
				if timer < 0:
					state = 2; vel_y = -0x200; timer = 0; octus_air_anim_counter = 0
					_set_frame(sprite,"octus",0)
					position.y += float(vel_y)/256.0
			2:
				_update_octus_air_animation()
				vel_y = GenesisMath.s16(vel_y + 0x10)
				if vel_y < 0:
					position.y += float(vel_y)/256.0
				else:
					state = 3; timer = 0x3C; _spawn_octus_bullet(); vel_y = 0
			3:
				_update_octus_air_animation()
				timer -= 1
				if timer < 0: state = 4
			4:
				_update_octus_air_animation()
				vel_y = GenesisMath.s16(vel_y + 0x10)
				position.y += float(vel_y)/256.0
				if int(position.y) >= orig_y:
					position.y = orig_y; vel_y = 0; state = 0; _set_frame(sprite,"octus",1)
	if alive:
		_react_badnik(8,0x0B)

func _spawn_octus_bullet() -> void:
	# Octus' source art faces left unflipped; status/render bit 0 is set when
	# Sonic is to its right, and that exact bit negates the default -$200 shot.
	var source_flip: bool = sprite.flip_h
	manager.spawn_s2_ooz_projectile(int(position.x), int(position.y), "octus", [5,6], 3, 0x200 if source_flip else -0x200, 0, 0x0F, source_flip)

func _update_octus_air_animation() -> void:
	# Retail anim 4 is `7,0,1,$FD,1`: after frames 0/1 it switches to anim 1,
	# whose `3,1,2,3,$FF` loop is the spinning-leg presentation. Preserve that
	# visible sequence for the entire rise/hover/fall instead of freezing frame 0.
	octus_air_anim_counter += 1
	if octus_air_anim_counter < 16:
		_set_frame(sprite,"octus",0 if octus_air_anim_counter < 8 else 1)
	else:
		_set_frame(sprite,"octus",1 + (int((octus_air_anim_counter - 16) / 4) % 3))

# -----------------------------------------------------------------------------
# $50 - Aquis. Compound body/wing badnik: activation, player-following capped at
# $100, timed shot phases, and the retail final leftward retreat are preserved.
# -----------------------------------------------------------------------------
func _init_aquis() -> void:
	active_width = 0x10
	sprite = _new_sprite("aquis",0,2)
	aquis_wing = _new_sprite("aquis",1,3)
	# Phase 119: force the animated fin/wing into an absolute sprite layer above
	# the body. Relative child Z values were still being sorted behind the parent
	# body in the runtime tree on some frames.
	aquis_wing.z_as_relative = false
	aquis_wing.z_index = 60
	vel_x = -0x100; vel_y = 0; state = 0; timer = 0; aquis_shots_remaining = 3
	_update_aquis_facing()
	_update_aquis_wing()

func _tick_aquis() -> void:
	var p: SonicPlayer = player()
	if p == null:
		return
	if state == 0:
		if _player_on_screen(p): state = 1; timer = 0
	elif state == 1:
		timer -= 1
		if timer < 0:
			state = 2; timer = 0x20; vel_x = 0; vel_y = 0; aquis_shooting = false
		else:
			_update_aquis_facing()
			vel_x = clampi(vel_x + (-0x10 if p.pixel_x() < int(position.x) else 0x10), -0x100, 0x100)
			vel_y = clampi(vel_y + (-0x10 if p.pixel_y() < int(position.y) else 0x10), -0x100, 0x100)
			position.x += float(vel_x)/256.0; position.y += float(vel_y)/256.0
	elif state == 2:
		if not aquis_shooting:
			aquis_shooting = true
			_update_aquis_facing()
			if p.pixel_y() >= int(position.y): _spawn_aquis_bullet()
		timer -= 1
		if timer < 0:
			aquis_shots_remaining -= 1
			if aquis_shots_remaining < 0:
				state = 3; vel_x = -0x200; vel_y = 0
			else:
				state = 1; timer = 0x80; vel_y = -0x100; aquis_shooting = false
	else:
		position.x += float(vel_x)/256.0
	_set_frame(sprite,"aquis",0)
	if frame_counter % 4 == 0:
		aquis_wing_frame = 2 if aquis_wing_frame == 1 else 1
		_set_frame(aquis_wing,"aquis",aquis_wing_frame)
	_update_aquis_wing()
	if alive:
		_react_badnik(12,16)

func _update_aquis_facing() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	# Obj50 status bit 0 is SET when the target is to the left. The reconstructed
	# source mapping itself faces left, however, so Godot's image flip is the
	# inverse of that status bit. The old code used the status bit directly as
	# Sprite2D.flip_h and made Aquis visibly face away from Sonic.
	var status_faces_left: bool = p.pixel_x() < int(position.x)
	sprite.flip_h = not status_faces_left
	if aquis_wing != null: aquis_wing.flip_h = not status_faces_left
	set_meta("aquis_status_faces_left", status_faces_left)

func _update_aquis_wing() -> void:
	if aquis_wing == null: return
	var status_faces_left: bool = bool(get_meta("aquis_status_faces_left", false))
	aquis_wing.position = Vector2(10 if status_faces_left else -10, -6)

func _spawn_aquis_bullet() -> void:
	# Obj50 copies status bit 0 to the bullet, then starts from d1=$10 and
	# d2=-$300. If the parent status bit is set, both are negated before d1 is
	# SUBTRACTED from X. Preserve that slightly counter-intuitive source result.
	var source_status_left: bool = bool(get_meta("aquis_status_faces_left", false))
	var bullet_x: int = int(position.x) + (0x10 if source_status_left else -0x10)
	var bullet_vx: int = 0x300 if source_status_left else -0x300
	# The generated projectile frame has the same default-facing convention as
	# the parent bank, so render flip is inverse while velocity still follows the
	# source status bit exactly.
	manager.spawn_s2_ooz_projectile(bullet_x, int(position.y)-0x0A, "aquis", [5,6,7,6], 4, bullet_vx, 0x200, 0, not source_status_left)
