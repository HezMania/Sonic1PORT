class_name S2MCZObject
extends GenesisLevelObject

# Phase 112/113: Mystic Cave's zone-local object namespace. Values and state
# transitions are translated from the retail Sonic 2 Obj15/1F/2A/6A/75/76/
# 77/7A/7F/80/81/9E/A3 routines. Phase 113 adds MCZ2 Obj15 modes and folds
# runtime-reported MCZ1 carry/collapse/Crawlton/vine fixes back into this shared
# implementation. Collision dimensions below are raw object geometry after
# removing SolidObject's Sonic-center margin where appropriate.

var sprite: Sprite2D
var aux: Array[Sprite2D] = []
var frame_counter: int = 0
var state: int = 0
var timer: int = 0
var orig_x: int = 0
var orig_y: int = 0
var fx: int = 0
var fy: int = 0
var vx: int = 0
var vy: int = 0

# $15 swing
var swing_links: Array[Sprite2D] = []
var swing_anchor: Sprite2D
var swing_angle_word: int = 0x8000
var swing_speed: int = 0
var swing_dir: int = 0
var swing_pause: int = 0
var swing_armed: bool = false
var swing_platform_old: Vector2 = Vector2.ZERO

# $1F collapsing platform
var collapse_started: bool = false
var collapse_delay: int = 7
var collapse_fragments: Array[Sprite2D] = []
var collapse_fragment_delay: Array[int] = [0x1A,0x16,0x12,0x0E,0x0A,0x02]
var collapse_fragment_fy: Array[int] = []
var collapse_fragment_vy: Array[int] = []
var collapse_support_released: bool = false
var collapse_finished: bool = false

# $2A stomper
var stomper_amount: int = 0
var stomper_retract: bool = false

# $6A three-crate assembly (all MCZ placements are subtype $18)
var crates: Array[Dictionary] = []
var crate_support_index: int = -1
const CRATE_PATH_NORMAL: Array[Vector3i] = [
	Vector3i(0,0x100,0x40),Vector3i(-0x100,0,0x80),Vector3i(0,-0x100,0x40),
	Vector3i(0x100,0,0x80),Vector3i(0x100,0,0x40)
]
const CRATE_PATH_FLIPPED: Array[Vector3i] = [
	Vector3i(0,0x100,0x40),Vector3i(0x100,0,0x80),Vector3i(0,-0x100,0x40),
	Vector3i(-0x100,0,0x80),Vector3i(-0x100,0,0x40)
]

# $75 brick / rotating chain
var brick_angle_word: int = 0
var brick_links: Array[Sprite2D] = []
var brick_anchor: Sprite2D

# $76 sliding spike block
var spike_remaining: int = 0
var spike_sliding: bool = false

# $77 gate
var gate_opening: bool = false
var gate_frame: int = 0
var gate_anim_tick: int = 0

# $7A moving platform
var platform_left: int = 0
var platform_right: int = 0
var platform_rightward: bool = true

# $7F/$80 hanging controls
var held: bool = false
var release_cooldown: int = 0
var vine_offset: int = 0
var vine_direction_down: bool = false
var vine_linked: bool = false

# $81 drawbridge
var draw_logs: Array[Sprite2D] = []
var draw_angle: int = 0
var draw_step: int = 1
var draw_moving: bool = false
var draw_settled: bool = false
var draw_center_x: int = 0
var draw_center_y: int = 0

# $9E Crawlton
var crawl_tail: Array[Sprite2D] = []
var crawl_tail_world: Array[Vector2i] = []
var crawl_returning: bool = false
const CRAWLTON_SEGMENT_THRESHOLDS: Array[int] = [0x18,0x14,0x10,0x0C,0x08,0x04,0x00]

# $A3 Flasher
var flasher_counter: int = 0
var flasher_threshold_index: int = 0
var flasher_accel: int = 2
var flasher_active: bool = false
var flasher_anim_index: int = 0
var flasher_anim_tick: int = 0
const FLASH_THRESHOLDS: Array[int] = [0x100,0x1A0,0x208,0x285,0x300,0x340,0x390,0x440]
const FLASH_TOGGLES: Array[Vector2i] = [
	Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(1,1),
	Vector2i(0,1),Vector2i(0,1),Vector2i(1,0),Vector2i(0,1)
]
const FLASH_A: Array[int] = [0,1,0,0,0,0,0,1,0,0,0,1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,2,3,4]
const FLASH_B: Array[int] = [2,0,3,0,4,0,3,0]
const FLASH_C: Array[int] = [4,3,2,1,0]

func initialize_object() -> void:
	orig_x = spawn_x
	orig_y = spawn_y
	fx = spawn_x << 8
	fy = spawn_y << 8
	match object_id:
		0x15: _init_swing()
		0x1F: _init_collapse()
		0x2A: _init_stomper()
		0x6A: _init_crates()
		0x75: _init_brick()
		0x76: _init_sliding_spikes()
		0x77: _init_gate()
		0x7A: _init_moving_platform()
		0x7F: _init_pull_switch()
		0x80: _init_vine()
		0x81: _init_drawbridge()
		0x9E: _init_crawlton()
		0xA3: _init_flasher()

func tick() -> void:
	frame_counter += 1
	match object_id:
		0x15: _tick_swing()
		0x1F: _tick_collapse()
		0x2A: _tick_stomper()
		0x6A: _tick_crates()
		0x75: _tick_brick()
		0x76: _tick_sliding_spikes()
		0x77: _tick_gate()
		0x7A: _tick_moving_platform()
		0x7F: _tick_pull_switch()
		0x80: _tick_vine()
		0x81: _tick_drawbridge()
		0x9E: _tick_crawlton()
		0xA3: _tick_flasher()

func _new_sprite(folder: String, frame: int, z: int = 0) -> Sprite2D:
	var s: Sprite2D = make_sprite("res://assets/objects/s2_mcz/%s/%02d.png" % [folder, frame], z)
	return s

func _trigger_index() -> int:
	return subtype & 0x0F

func _trigger_get(index: int) -> bool:
	if manager == null or index < 0 or index >= manager.mcz_button_vine_triggers.size():
		return false
	return manager.mcz_button_vine_triggers[index] != 0

func _trigger_set(index: int, value: bool) -> void:
	if manager == null or index < 0 or index >= manager.mcz_button_vine_triggers.size():
		return
	manager.mcz_button_vine_triggers[index] = 1 if value else 0

func _release_hang(p: SonicPlayer, jump_velocity: int, allow_horizontal: bool) -> void:
	held = false
	p.object_control_override = false
	p.hang_on_pole = false
	p.mcz_vine_hang = false
	p.in_air = true
	p.jumping = false
	p.vel_y = jump_velocity
	if allow_horizontal:
		if p.input_left: p.vel_x = -0x200
		elif p.input_right: p.vel_x = 0x200
	release_cooldown = 0x3C if (p.input_left or p.input_right or p.input_up or p.input_down) else 0x12

func _react_badnik(cx: int, cy: int, hw: int, hh: int, active_hazard: bool = true) -> bool:
	var p: SonicPlayer = player()
	if p == null or p.dead:
		return false
	if absi(p.pixel_x() - cx) > hw + p.width_radius or absi(p.pixel_y() - cy) > hh + p.height_radius:
		return false
	if p.invincible_timer > 0 or p.rolling or p.object_attack_active:
		var award: int = manager.register_badnik_hit()
		manager.spawn_badnik_destruction(cx, cy, award)
		request_delete(respawn_enabled)
		if p.vel_y >= 0: p.vel_y = -p.vel_y
		else: p.vel_y = GenesisMath.s16(p.vel_y + 0x100)
		return true
	if active_hazard:
		p.apply_hazard_hit(cx)
	return false

# -----------------------------------------------------------------------------
# $15 - subtype $48 MCZ swinging spike-edged platform
# -----------------------------------------------------------------------------
func _init_swing() -> void:
	active_width = 0x18
	z_index = 45
	var mode: int = subtype & 0x70
	# MCZ1 uses the special $40 spike-edged variant. MCZ2 adds the ordinary
	# $10/$30 oscillator-clamped timber platforms from the same Obj15 routine.
	sprite = _new_sprite("swing_hazard" if mode == 0x40 else "shared_platform", 0, 2)
	sprite.flip_h = false; sprite.flip_v = false
	var link_count: int = maxi(1, subtype & 0x0F)
	for i in range(link_count):
		var l: Sprite2D = _new_sprite("shared_platform", 1, 0)
		l.flip_h = false; l.flip_v = false
		swing_links.append(l)
	swing_anchor = _new_sprite("shared_platform", 2, 1)
	swing_anchor.flip_h = false; swing_anchor.flip_v = false
	_update_swing_geometry()
	swing_platform_old = sprite.position

func _tick_swing() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var mode: int = subtype & 0x70
	if mode == 0x40:
		# Retail special MCZ swing: arm by proximity, accelerate to each endpoint,
		# pause $3C frames, then reverse.
		if not swing_armed and absi(p.pixel_x() - orig_x) < 0x20 and not p.debug_free_mode:
			swing_armed = true
		if swing_armed:
			if swing_pause > 0:
				swing_pause -= 1
			elif swing_dir == 0:
				swing_speed = GenesisMath.s16(swing_speed - 8)
				swing_angle_word = (swing_angle_word + swing_speed) & 0xFFFF
				if swing_speed <= -0x200:
					swing_speed = 0; swing_angle_word = 0x4000; swing_dir = 1; swing_pause = 0x3C
			else:
				swing_speed = GenesisMath.s16(swing_speed + 8)
				swing_angle_word = (swing_angle_word + swing_speed) & 0xFFFF
				if swing_speed >= 0x200:
					swing_speed = 0; swing_angle_word = 0x8000; swing_dir = 0; swing_pause = 0x3C
	else:
		# sub_FE70 reads Oscillating_Data+$18. Subtype $10 clamps values below
		# $40 up to $40; subtype $30 clamps values above $40 down to $40.
		var source_angle: int = manager.s2_source_osc_byte(0x18)
		if mode == 0x10 and source_angle < 0x40:
			source_angle = 0x40
		elif mode == 0x30 and source_angle > 0x40:
			source_angle = 0x40
		swing_angle_word = (source_angle & 0xFF) << 8

	var old: Vector2 = sprite.position
	_update_swing_geometry()
	var wx: int = orig_x + int(round(sprite.position.x))
	var wy: int = orig_y + int(round(sprite.position.y))
	var dx: int = int(round(sprite.position.x - old.x))
	var dy: int = int(round(sprite.position.y - old.y))
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, dx, dy, wx - 0x18, wx + 0x18, wy - 8)
	p.resolve_platform_top(wx - 0x18, wx + 0x18, wy - 8, record_index)
	# Only subtype mode $40 switches Obj15 to collision type $A7. Ordinary
	# MCZ2 swinging platforms are safe timber platforms.
	if mode == 0x40 and absi(p.pixel_x() - wx) <= 0x20 + p.width_radius and absi(p.pixel_y() - wy) <= 2 + p.height_radius:
		p.apply_hazard_hit(wx)

func _update_swing_geometry() -> void:
	var a: int = (swing_angle_word >> 8) & 0xFF
	if x_flip: a = (0x80 - a) & 0xFF
	var sx: int = GenesisMath.cosine(a)
	var sy: int = GenesisMath.sine(a)
	for i in range(swing_links.size()):
		var length: int = (i + 1) * 16
		swing_links[i].position = Vector2(float((sx * length) >> 8), float((sy * length) >> 8))
	# Retail parent is a half-link beyond the eight 16px chain steps.
	swing_anchor.position = Vector2.ZERO
	sprite.position = Vector2(float((sx * 136) >> 8), float((sy * 136) >> 8))

# -----------------------------------------------------------------------------
# $1F - MCZ collapsing platform
# -----------------------------------------------------------------------------
func _init_collapse() -> void:
	active_width = 0x20
	sprite = _new_sprite("collapse", 0, 1)

func _tick_collapse() -> void:
	var p: SonicPlayer = player()
	if p == null or collapse_finished: return
	if not collapse_started:
		var supported: bool = p.resolve_platform_top(orig_x - 0x20, orig_x + 0x20, orig_y - 0x10, record_index)
		if supported or (p.standing_on_object and p.support_record_index == record_index):
			collapse_started = true
		return
	if collapse_delay > 0:
		collapse_delay -= 1
		p.resolve_platform_top(orig_x - 0x20, orig_x + 0x20, orig_y - 0x10, record_index)
		return
	if collapse_fragments.is_empty():
		# Obj1F_CreateFragments reuses the parent as fragment zero. Sonic remains
		# stood on that top fragment until its MCZ delay ($1A) expires.
		sprite.visible = false
		for i in range(6):
			var f: Sprite2D = _new_sprite("collapse_fragments", i, 1)
			f.flip_h = x_flip; f.flip_v = y_flip
			collapse_fragments.append(f); collapse_fragment_fy.append(0); collapse_fragment_vy.append(0)
		# Native support is explicitly refreshed each object pass; preserve the
		# source stood-on bit across the CreateFragments frame.
		p.resolve_platform_top(orig_x - 0x20, orig_x + 0x20, orig_y - 0x10, record_index)
		return

	# Obj1F_Fragment calls PlatformObject before decrementing the first fragment's
	# delay while the stood-on flag is set. Release support exactly when that
	# fragment reaches zero, not when breakup begins.
	if not collapse_support_released and collapse_fragment_delay[0] > 0:
		p.resolve_platform_top(orig_x - 0x20, orig_x + 0x20, orig_y - 0x10, record_index)

	var all_far: bool = true
	for i in range(collapse_fragments.size()):
		if collapse_fragment_delay[i] > 0:
			collapse_fragment_delay[i] -= 1
			if i == 0 and collapse_fragment_delay[i] == 0 and not collapse_support_released:
				if p.standing_on_object and p.support_record_index == record_index:
					p.clear_object_support_for(record_index, true)
				collapse_support_released = true
			all_far = false
			continue
		collapse_fragment_fy[i] += collapse_fragment_vy[i]
		collapse_fragment_vy[i] = GenesisMath.s16(collapse_fragment_vy[i] + 0x38)
		collapse_fragments[i].position.y = float(collapse_fragment_fy[i] >> 8)
		if collapse_fragments[i].position.y < 0x180: all_far = false
	if all_far:
		# Do not request immediate deletion. The Genesis object-position loader does
		# not re-read this nearby non-remembered placement on the next frame. Keep
		# an inert tombstone until normal central offscreen teardown occurs.
		for f in collapse_fragments: f.visible = false
		collapse_finished = true

# -----------------------------------------------------------------------------
# $2A - MCZ stomper
# -----------------------------------------------------------------------------
func _init_stomper() -> void:
	active_width = 0x10
	sprite = _new_sprite("stomper", 0, 1)

func _tick_stomper() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var old_y: int = int(position.y)
	if not stomper_retract:
		stomper_amount += 1
		if stomper_amount >= 0x60:
			stomper_amount = 0x60; stomper_retract = true
	else:
		stomper_amount -= 8
		if stomper_amount <= 0:
			stomper_amount = 0; stomper_retract = false
	position.y = float(orig_y - stomper_amount)
	var cy: int = int(position.y)
	var dy: int = cy - old_y
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index, 0, dy, orig_x - 0x10, orig_x + 0x10, cy - 0x40)
	p.resolve_solid_box(orig_x, cy, 0x10, 0x40, true, record_index)

# -----------------------------------------------------------------------------
# $6A - MCZ moving crate trio
# -----------------------------------------------------------------------------
func _init_crates() -> void:
	active_width = 0x20
	var starts: Array[Vector2i] = [Vector2i(0,0),Vector2i(0x40,0x40),Vector2i(-0x40,0x40)]
	var stages: Array[int] = [4, 2 if x_flip else 1, 1 if x_flip else 2]
	for i in range(3):
		var s: Sprite2D = _new_sprite("crate",0,1)
		s.flip_h = x_flip; s.flip_v = false
		var d: Dictionary = {"sprite":s,"fx":(orig_x+starts[i].x)<<8,"fy":(orig_y+starts[i].y)<<8,"stage":stages[i],"timer":0,"vx":0,"vy":0,"oldx":orig_x+starts[i].x,"oldy":orig_y+starts[i].y}
		_crate_load_stage(d)
		crates.append(d)

func _crate_load_stage(c: Dictionary) -> void:
	var table: Array[Vector3i] = CRATE_PATH_FLIPPED if x_flip else CRATE_PATH_NORMAL
	var st: int = int(c["stage"])
	var v: Vector3i = table[st]
	c["vx"] = v.x; c["vy"] = v.y; c["timer"] = v.z
	st += 1
	if st >= 4: st = 0
	c["stage"] = st

func _tick_crates() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if p.standing_on_object and p.support_record_index == record_index and crate_support_index < 0:
		var best: int = 0x7FFFFFFF
		for i in range(crates.size()):
			var cx0: int = int(crates[i]["fx"]) >> 8; var cy0: int = int(crates[i]["fy"]) >> 8
			var dist: int = absi(p.pixel_x()-cx0) + absi((p.pixel_y()+p.height_radius)-(cy0-0x20))
			if dist < best: best=dist; crate_support_index=i
	for i in range(crates.size()):
		var c: Dictionary = crates[i]
		var oldx: int = int(c["fx"]) >> 8; var oldy: int = int(c["fy"]) >> 8
		c["fx"] = int(c["fx"]) + int(c["vx"]); c["fy"] = int(c["fy"]) + int(c["vy"])
		c["timer"] = int(c["timer"]) - 1
		if int(c["timer"]) <= 0: _crate_load_stage(c)
		var cx: int = int(c["fx"]) >> 8; var cy: int = int(c["fy"]) >> 8
		var cs: Sprite2D = c["sprite"] as Sprite2D; cs.position = Vector2(cx-orig_x,cy-orig_y)
		if crate_support_index == i and p.standing_on_object and p.support_record_index == record_index:
			p.move_with_supported_object(record_index,cx-oldx,cy-oldy,cx-0x20,cx+0x20,cy-0x20)
		var contact: int = p.resolve_solid_box_contact(cx,cy,0x20,0x20,true,record_index)
		if contact == SonicPlayer.SOLID_TOP: crate_support_index=i
		crates[i]=c
	if not p.standing_on_object or p.support_record_index != record_index: crate_support_index=-1

# -----------------------------------------------------------------------------
# $75 - stationary brick / rotating chain endpoint
# -----------------------------------------------------------------------------
func _init_brick() -> void:
	active_width = 0x10
	if (subtype & 0x0F) == 0x0F:
		sprite = _new_sprite("brick",2,1)
		return
	brick_anchor = _new_sprite("brick",0,0)
	for i in range(subtype & 0x0F): brick_links.append(_new_sprite("brick",1,0))
	sprite = _new_sprite("brick",0,1)
	brick_angle_word = (0x40 if x_flip else 0) | (0x80 if y_flip else 0)
	brick_angle_word <<= 8

func _tick_brick() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if (subtype & 0x0F) == 0x0F:
		p.resolve_solid_box(orig_x,orig_y,0x10,0x10,true,record_index)
		return
	var high: int = GenesisMath.s8(subtype & 0xF0)
	brick_angle_word = (brick_angle_word + (high << 3)) & 0xFFFF
	var a: int = (brick_angle_word >> 8) & 0xFF
	var sx: int = GenesisMath.sine(a); var sy: int = GenesisMath.cosine(a)
	for i in range(brick_links.size()):
		var radius: int = i*16
		brick_links[i].position = Vector2(float((sy*radius)>>8),float((sx*radius)>>8))
	var end_radius: int = brick_links.size()*16
	sprite.position = Vector2(float((sy*end_radius)>>8),float((sx*end_radius)>>8))
	var ex: int = orig_x+int(sprite.position.x); var ey: int=orig_y+int(sprite.position.y)
	if absi(p.pixel_x()-ex)<=0x0C+p.width_radius and absi(p.pixel_y()-ey)<=0x0C+p.height_radius: p.apply_hazard_hit(ex)

# -----------------------------------------------------------------------------
# $76 - sliding wall spikes
# -----------------------------------------------------------------------------
func _init_sliding_spikes() -> void:
	active_width = 0x40
	sprite = _new_sprite("sliding_spikes",0,1)

func _tick_sliding_spikes() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if not spike_sliding and not p.in_air:
		var dx: int = p.pixel_x()-int(position.x)+0xC0
		if x_flip: dx-=0x100
		var dy: int = p.pixel_y()-orig_y+0x10
		if dx>=0 and dx<0x80 and dy>=0 and dy<0x20:
			spike_sliding=true; spike_remaining=0x80
	var old_x: int = int(position.x)
	if spike_remaining>0:
		spike_remaining-=1; position.x += 1.0 if x_flip else -1.0
	var new_x: int = int(position.x)
	# Retail Obj76 saves old x_pos before movement and then calls SolidObject; its
	# standing path performs the same MvSonicOnPtfm carry as other moving solids.
	if p.standing_on_object and p.support_record_index == record_index:
		p.move_with_supported_object(record_index,new_x-old_x,0,new_x-0x40,new_x+0x40,orig_y-0x10)
	var contact: int = p.resolve_solid_box_contact(new_x,orig_y,0x40,0x10,true,record_index)
	if contact==SonicPlayer.SOLID_LEFT or contact==SonicPlayer.SOLID_RIGHT: p.apply_hazard_hit(new_x)

# -----------------------------------------------------------------------------
# $77 - trigger bridge/gate
# -----------------------------------------------------------------------------
func _init_gate() -> void:
	active_width=0x40; sprite=_new_sprite("gate",0,1)

func _tick_gate() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if not gate_opening and _trigger_get(_trigger_index()): gate_opening=true
	if gate_opening and gate_frame<4:
		gate_anim_tick+=1
		if gate_anim_tick>=4:
			gate_anim_tick=0; gate_frame+=1; set_sprite_frame(sprite,"s2_mcz/gate",gate_frame)
	if gate_frame==0:
		p.resolve_solid_box(orig_x,orig_y,0x40,8,true,record_index)
	elif p.standing_on_object and p.support_record_index==record_index:
		p.clear_object_support_for(record_index,true)

# -----------------------------------------------------------------------------
# $7A - MCZ horizontal platform; placed subtypes are $00/$12
# -----------------------------------------------------------------------------
func _init_moving_platform() -> void:
	active_width=0x18; sprite=_new_sprite("shared_platform",0,1); sprite.flip_h=false; sprite.flip_v=false
	platform_left=orig_x-0x68; platform_right=orig_x+0x68
	if subtype==0x12:
		position.x=float(orig_x+0x67); platform_rightward=true
	else:
		position.x=float(orig_x-0x68); platform_rightward=true

func _tick_moving_platform() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var oldx:int=int(position.x)
	if platform_rightward:
		position.x+=1.0
		if int(position.x)>=platform_right: position.x=float(platform_right); platform_rightward=false
	else:
		position.x-=1.0
		if int(position.x)<=platform_left: position.x=float(platform_left); platform_rightward=true
	var cx:int=int(position.x); var top:int=orig_y-8
	if p.standing_on_object and p.support_record_index==record_index:
		p.move_with_supported_object(record_index,cx-oldx,0,cx-0x18,cx+0x18,top)
	p.resolve_platform_top(cx-0x18,cx+0x18,top,record_index)

# -----------------------------------------------------------------------------
# $7F - hanging pull switch
# -----------------------------------------------------------------------------
func _init_pull_switch() -> void:
	active_width=8; sprite=_new_sprite("pull_switch",0,1)

func _tick_pull_switch() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if release_cooldown>0: release_cooldown-=1
	if held:
		p.force_set_pixel_position(orig_x,orig_y+0x30); p.vel_x=0; p.vel_y=0; p.inertia=0
		if p.jump_pressed:
			_release_hang(p,-0x300,false); _trigger_set(_trigger_index(),false); set_sprite_frame(sprite,"s2_mcz/pull_switch",0)
		return
	if release_cooldown>0 or p.object_control_override or p.dead or p.debug_free_mode:return
	if p.pixel_x()-orig_x+0x0C<0 or p.pixel_x()-orig_x+0x0C>=0x18:return
	if p.pixel_y()-orig_y-0x28<0 or p.pixel_y()-orig_y-0x28>=0x10:return
	held=true; p.clear_object_support(); p.vel_x=0;p.vel_y=0;p.inertia=0;p.in_air=true;p.rolling=false;p.jumping=false;p.hang_on_pole=true;p.mcz_vine_hang=true;p.object_control_override=true
	p.force_set_pixel_position(orig_x,orig_y+0x30); _trigger_set(_trigger_index(),true); set_sprite_frame(sprite,"s2_mcz/pull_switch",1)

# -----------------------------------------------------------------------------
# $80 - lowering/hanging vine
# -----------------------------------------------------------------------------
func _init_vine() -> void:
	active_width=0x10; sprite=_new_sprite("vine",0,1)
	vine_linked=(subtype&0x80)!=0
	vine_direction_down=false
	if (subtype&0x70)!=0:
		vine_offset=0xB0; vine_direction_down=true; position.y=float(orig_y+vine_offset); set_sprite_frame(sprite,"s2_mcz/vine",(vine_offset>>5)+1)

func _tick_vine() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if release_cooldown>0:release_cooldown-=1
	var wants_down: bool = (not held) if vine_direction_down else held
	# Retail Obj80 movement is driven by its held flag and initial direction.
	# The high-bit subtype only links the grab/release to ButtonVine_Trigger; it
	# does not feed that trigger back into the vine movement itself.
	if wants_down and vine_offset<0xB0: vine_offset=mini(0xB0,vine_offset+2)
	elif not wants_down and vine_offset>0: vine_offset=maxi(0,vine_offset-2)
	position.y=float(orig_y+vine_offset)
	var vf:int=0 if vine_offset==0 else (vine_offset>>5)+1; vf=clampi(vf,0,6); set_sprite_frame(sprite,"s2_mcz/vine",vf)
	if held:
		p.force_set_pixel_position(orig_x,int(position.y)+0x94);p.vel_x=0;p.vel_y=0;p.inertia=0
		if p.jump_pressed:
			_release_hang(p,-0x380,true)
			if vine_linked:_trigger_set(_trigger_index(),false)
		return
	if release_cooldown>0 or p.object_control_override or p.dead or p.debug_free_mode:return
	var dx:int=p.pixel_x()-orig_x+0x10;var dy:int=p.pixel_y()-int(position.y)-0x88
	if dx<0 or dx>=0x20 or dy<0 or dy>=0x18:return
	held=true;p.clear_object_support();p.vel_x=0;p.vel_y=0;p.inertia=0;p.in_air=true;p.rolling=false;p.jumping=false;p.hang_on_pole=true;p.mcz_vine_hang=true;p.object_control_override=true
	p.force_set_pixel_position(orig_x,int(position.y)+0x94)
	if vine_linked:_trigger_set(_trigger_index(),true)

# -----------------------------------------------------------------------------
# $81 - trigger drawbridge, eight $10px log segments
# -----------------------------------------------------------------------------
func _init_drawbridge() -> void:
	active_width=8; z_index=35
	for i in range(8):
		var l:Sprite2D=_new_sprite("gate_log",0,0);l.flip_h=false;l.flip_v=false;draw_logs.append(l)
	draw_angle=0x40 if y_flip else 0xC0
	draw_step=-1 if x_flip else 1
	draw_center_x=orig_x; draw_center_y=orig_y + (0x48 if y_flip else -0x48)
	_update_draw_logs()

func _tick_drawbridge() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	if not draw_moving and not draw_settled and _trigger_get(_trigger_index()):draw_moving=true
	if draw_moving:
		draw_angle=(draw_angle+draw_step)&0xFF
		if draw_angle==0 or draw_angle==0x80:
			draw_moving=false;draw_settled=true;draw_center_x=orig_x+(-0x48 if draw_angle==0x80 else 0x48);draw_center_y=orig_y
		_update_draw_logs()
	if draw_settled:
		p.resolve_solid_box(draw_center_x,draw_center_y,0x40,8,true,record_index)
	else:
		var horizontal:bool=draw_angle==0 or (draw_angle!=0x40 and draw_angle<0xC0)
		p.resolve_solid_box(draw_center_x,draw_center_y,0x40 if horizontal else 8,8 if horizontal else 0x40,true,record_index)

func _update_draw_logs() -> void:
	var sx:int=GenesisMath.cosine(draw_angle);var sy:int=GenesisMath.sine(draw_angle)
	for i in range(draw_logs.size()):
		var r:int=(i+1)*16;draw_logs[i].position=Vector2(float((sx*r)>>8),float((sy*r)>>8))

# -----------------------------------------------------------------------------
# $9E - Crawlton: 16f wait, 28f charge, 32f wait, 28f return; 7 delayed links
# -----------------------------------------------------------------------------
func _init_crawlton() -> void:
	active_width=0x80;sprite=_new_sprite("crawlton",0,2)
	for i in range(7):
		var seg: Sprite2D = _new_sprite("crawlton",2,1)
		crawl_tail.append(seg)
		crawl_tail_world.append(Vector2i(orig_x,orig_y))

func _crawl_set_velocity_to_player() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var dx:int=p.pixel_x()-int(position.x);var dy:int=p.pixel_y()-int(position.y)
	vx=GenesisMath.s16((dx<<3)&0xFF00);vy=GenesisMath.s16((dy<<3)&0xFF00)
	sprite.flip_h=vx>0

func _tick_crawlton() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	var moved_this_frame: bool = false
	match state:
		0:
			if absi(p.pixel_x()-int(position.x))<0x80 and absi(p.pixel_y()-int(position.y))<0x80:
				_crawl_set_velocity_to_player();state=1;timer=0x10
		1:
			timer-=1
			if timer<0:state=2;timer=0x1C;crawl_returning=false
		2,4:
			# loc_37EB6 decrements first and does not ObjectMove on the zero frame.
			timer-=1
			if timer<=0:
				if state==2:state=3;timer=0x20
				else:state=0
			else:
				fx+=vx;fy+=vy;position=Vector2(fx>>8,fy>>8);moved_this_frame=true
		3:
			timer-=1
			if timer<=0:vx=-vx;vy=-vy;state=4;timer=0x1C;crawl_returning=true

	# Retail Crawlton's seven body sprites are independent absolute positions.
	# While the head is in routine 6, each segment begins moving only when the
	# parent's $1C countdown passes $18,$14,$10,$0C,$08,$04; the seventh/root
	# segment never moves. This makes the creature extend/retract instead of
	# dragging its whole body behind the head.
	if moved_this_frame:
		var step_x: int = GenesisMath.s16(vx) >> 8
		var step_y: int = GenesisMath.s16(vy) >> 8
		for i in range(crawl_tail_world.size()):
			if timer < CRAWLTON_SEGMENT_THRESHOLDS[i]:
				crawl_tail_world[i] += Vector2i(step_x,step_y)
	for i in range(crawl_tail.size()):
		crawl_tail[i].position = Vector2(crawl_tail_world[i].x-int(position.x),crawl_tail_world[i].y-int(position.y))
		crawl_tail[i].flip_h = sprite.flip_h
	_react_badnik(int(position.x),int(position.y),8,8,true)

# -----------------------------------------------------------------------------
# $A3 - Flasher
# -----------------------------------------------------------------------------
func _init_flasher() -> void:
	active_width=0x10;sprite=_new_sprite("flasher",0,2);timer=0x40

func _tick_flasher() -> void:
	var p: SonicPlayer = player()
	if p == null: return
	match state:
		0:
			timer-=1
			if timer<0:
				state=1;timer=0x80;vx=-0x100;vy=0x40;flasher_accel=2
		1:
			timer-=1
			if timer<0:
				state=2;flasher_active=true;flasher_anim_index=0;flasher_anim_tick=0
			else:
				flasher_counter=GenesisMath.s16(flasher_counter+1)
				if flasher_counter<0:request_delete(respawn_enabled);return
				if flasher_threshold_index<FLASH_THRESHOLDS.size() and flasher_counter>=FLASH_THRESHOLDS[flasher_threshold_index]:
					var tg:Vector2i=FLASH_TOGGLES[flasher_threshold_index];if tg.x!=0:flasher_accel=-flasher_accel;if tg.y!=0:vy=-vy;flasher_threshold_index+=1
				vx=GenesisMath.s16(vx+flasher_accel);fx+=vx;fy+=vy;position=Vector2(fx>>8,fy>>8);sprite.flip_h=vx>0
		2:
			if flasher_anim_index<FLASH_A.size():set_sprite_frame(sprite,"s2_mcz/flasher",FLASH_A[flasher_anim_index]);flasher_anim_index+=1
			else:state=3;timer=0x80;flasher_anim_index=0;set_sprite_frame(sprite,"s2_mcz/flasher",3)
		3:
			timer-=1;set_sprite_frame(sprite,"s2_mcz/flasher",FLASH_B[frame_counter%FLASH_B.size()])
			if timer<0:state=4;flasher_anim_index=0;flasher_anim_tick=0
		4:
			flasher_anim_tick+=1
			if flasher_anim_tick>=4:
				flasher_anim_tick=0
				if flasher_anim_index<FLASH_C.size():set_sprite_frame(sprite,"s2_mcz/flasher",FLASH_C[flasher_anim_index]);flasher_anim_index+=1
				else:state=1;timer=0x80;flasher_active=false;set_sprite_frame(sprite,"s2_mcz/flasher",0)
	# ObjA3 ORs $80 into collision_flags while lit. That changes TouchResponse
	# from ordinary enemy collision ($06) to hurt-only ($86), so a rolling Sonic
	# cannot destroy it during the bright phase.
	if flasher_active:
		if absi(p.pixel_x() - int(position.x)) <= 0x10 + p.width_radius and absi(p.pixel_y() - int(position.y)) <= 0x10 + p.height_radius:
			p.apply_hazard_hit(int(position.x))
	else:
		_react_badnik(int(position.x),int(position.y),0x10,0x10,true)
