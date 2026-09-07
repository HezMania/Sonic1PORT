class_name S2DEZMechaSonic
extends Node2D

# Phase 134: source-shaped Sonic 2 Object $AF - Mecha Sonic / Silver Sonic.
# This follows the final game's top-level routines and exact 16-entry attack
# selector instead of Phase 132's alternating generic dash/jump approximation.

const PH_WAIT: int = 0
const PH_PRELUDE: int = 1
const PH_FALL: int = 2
const PH_COOLDOWN: int = 3
const PH_ATTACK: int = 4
const PH_DEFEAT: int = 5

const SPAWN_X: int = 0x348
const SPAWN_Y: int = 0x0A0
const ARENA_X: int = 0x224
const HIT_X: int = 0x10
const HIT_Y: int = 0x1B
# TouchResponse low bits $1A select the retail 12x12 player-touch box.
# x_radius/y_radius above remain the object/floor geometry and are not the
# player touch-response dimensions.
const TOUCH_X: int = 0x0C
const TOUCH_Y: int = 0x0C

# byte_398B0 - exact retail secondary-routine selector.
const ATTACK_SEQUENCE: Array[int] = [
	0x06, 0x00, 0x10, 0x06,
	0x06, 0x1E, 0x00, 0x10,
	0x06, 0x06, 0x10, 0x06,
	0x00, 0x06, 0x10, 0x1E,
]

const ANIM_LOOP: int = 0
const ANIM_SECONDARY: int = 1
const ANIM_HOLD: int = 2
const ANIM_DELAYS: Array[int] = [2, 0x45, 3, 3, 2, 3]
const ANIM_ENDS: Array[int] = [ANIM_LOOP, ANIM_SECONDARY, ANIM_HOLD, ANIM_HOLD, ANIM_LOOP, ANIM_HOLD]
const ANIM_FRAMES: Array = [
	[0, 1, 2],
	[3],
	[4, 5, 4, 3],
	[3, 3, 3, 6, 6, 6, 7, 7, 7, 8, 8, 8, 6, 6, 7, 7, 8, 8, 6, 7, 8],
	[6, 7, 8],
	[8, 7, 6, 8, 8, 7, 7, 6, 6, 8, 8, 8, 7, 7, 7, 6, 6, 6, 3, 3],
]
const FLAME_FRAMES: Array = [
	[0x0B, 0x0C], # falling/hover flame
	[0x0D, 0x0E], # spin wind-up
	[0x09, 0x0A], # spin-dash thrust
]

# Obj_CreateProjectiles byte_39D92. Velocities are source 8.8 words created
# by storing these signed bytes into the high byte of x_vel/y_vel.
const SPIKE_DATA: Array = [
	[0, -24, 0x000, -0x300, 0x0F],
	[-16, -16, -0x200, -0x200, 0x10],
	[-24, 0, -0x300, 0x000, 0x11],
	[-16, 16, -0x200, 0x200, 0x12],
	[0, 24, 0x000, 0x300, 0x13],
	[16, 16, 0x200, 0x200, 0x14],
	[24, 0, 0x300, 0x000, 0x15],
	[16, -16, 0x200, -0x200, 0x16],
]

# User-supplied Sonic 2 SoundXX captures corresponding to the retail SndIDs.
const S2_SFX_SPIKE_SWITCH: int = 0x22
const S2_SFX_LASER_BEAM: int = 0x30
const S2_SFX_SPINDASH_RELEASE: int = 0x3C
const S2_SFX_FIRE: int = 0x5C
const S2_SFX_MECHA_BUZZ: int = 0x6E

static var _texture_cache: Dictionary = {}

var manager: SonicObjectManager
var alive: bool = true
var phase: int = PH_WAIT
var secondary: int = 0
var hits: int = 8
var timer: int = 0
var invulnerability_timer: int = 0
var x_fixed: int = SPAWN_X << 16
var y_fixed: int = SPAWN_Y << 16
var vx: int = 0
var vy: int = 0
var facing_left: bool = true
var direction_toggle: bool = false
var selector_index: int = 0
var repeat_count: int = 0
var spike_spawned: bool = false
var frame_counter: int = 0

var mapping_frame: int = 0
var anim_id: int = -1
var anim_next: int = -1
var anim_cursor: int = 0
var anim_duration: int = 0
var anim_just_set_frame: bool = false

var flame_anim: int = 0
var flame_cursor: int = 0
var flame_duration: int = 0
var sprite: Sprite2D
var flame_sprite: Sprite2D
var projectiles: Array = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(SPAWN_X, SPAWN_Y)

	flame_sprite = Sprite2D.new()
	flame_sprite.name = "MechaFlame"
	flame_sprite.centered = true
	flame_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flame_sprite.z_index = 45
	add_child(flame_sprite)

	sprite = Sprite2D.new()
	sprite.name = "MechaSonic"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 46
	add_child(sprite)

	mapping_frame = 0
	_set_frame(mapping_frame)
	_set_flame_animation(0, true)
	manager.boss_limit_right = 0x1000
	manager.boss_screen_lock = false

func tick() -> void:
	if not alive or manager == null:
		return
	frame_counter += 1
	if invulnerability_timer > 0:
		invulnerability_timer -= 1

	match phase:
		PH_WAIT:
			_tick_wait()
		PH_PRELUDE:
			_tick_prelude()
		PH_FALL:
			_tick_fall()
		PH_COOLDOWN:
			_tick_cooldown()
		PH_ATTACK:
			_tick_attack()
		PH_DEFEAT:
			_tick_defeat()

	_tick_projectiles()
	position = Vector2(float(x_fixed) / 65536.0, float(y_fixed) / 65536.0)
	_update_visual()
	if phase == PH_COOLDOWN or phase == PH_ATTACK:
		_check_player_contact()

func _tick_wait() -> void:
	# ObjAF is allocated at Camera X $140, but routine 2 only advances at $224.
	# Main mapping frame remains zero: the pre-landing spines are static.
	mapping_frame = 0
	if manager.current_screen_x < ARENA_X:
		return
	phase = PH_PRELUDE
	timer = 0x3C
	vy = 0x100
	manager.boss_screen_lock = true
	manager.boss_limit_right = ARENA_X
	SonicAudio.stop_music()

func _tick_prelude() -> void:
	mapping_frame = 0
	timer -= 1
	if timer >= 0:
		return
	SonicAudio.play_music(SonicAudio.MUS_S2_BOSS, true)
	phase = PH_FALL

func _tick_fall() -> void:
	mapping_frame = 0
	# loc_397FE keys the fire sound from Vint_runcount & $1F.
	if (manager.elapsed_frames & 0x1F) == 0:
		SonicAudio.play_s2_pcm_sfx(S2_SFX_FIRE)
	var distance: int = _floor_distance()
	if distance < 0:
		y_fixed += distance << 16
		vy = 0
		_enter_cooldown()
		return
	_move_main()

func _enter_cooldown() -> void:
	phase = PH_COOLDOWN
	secondary = 0
	timer = 0x64
	vx = 0
	vy = 0
	spike_spawned = false
	_set_animation(0)
	_set_flame_visible(false)
	_snap_to_floor()
	SonicAudio.play_s2_pcm_sfx(S2_SFX_MECHA_BUZZ)

func _tick_cooldown() -> void:
	_snap_to_floor()
	_animate_checked()
	timer -= 1
	if timer == 0x32:
		SonicAudio.play_s2_pcm_sfx(S2_SFX_MECHA_BUZZ)
	if timer != 0:
		return
	secondary = ATTACK_SEQUENCE[selector_index & 0x0F]
	selector_index = (selector_index + 1) & 0x0F
	spike_spawned = false
	phase = PH_ATTACK

func _tick_attack() -> void:
	_tick_secondary()
	# Object AF calls ObjectMove after its secondary routine. A branch back to
	# loc_399D6 (cooldown) tail-exits instead, so do not move after that change.
	if phase == PH_ATTACK:
		_move_main()

func _tick_secondary() -> void:
	match secondary:
		0x00:
			_spin_setup()
		0x02:
			_spin_windup()
		0x04:
			_spin_dash()
		0x06, 0x10, 0x1E:
			_common_pose_setup()
		0x08, 0x12, 0x20:
			_common_pose_wait()
		0x0A:
			_ground_charge()
		0x0C:
			_ground_dash()
		0x0E:
			_close_animation()
		0x14, 0x22:
			_jump_charge()
		0x16, 0x24:
			_jump_runup()
		0x18:
			_jump_air(false)
		0x1A:
			_jump_ground_wait()
		0x1C:
			_close_animation()
		0x26:
			_jump_air(true)
		0x28:
			_jump_ground_wait()
		0x2A:
			_close_animation()

func _spin_setup() -> void:
	secondary = 0x02
	mapping_frame = 3
	repeat_count = 2
	timer = 0x20
	_set_flame_animation(1, true)

func _spin_windup() -> void:
	timer -= 1
	if timer >= 0:
		return
	secondary = 0x04
	timer = 0x40
	_set_animation(1)
	_set_alternating_speed(0x800)
	_set_flame_animation(2, true)
	SonicAudio.play_s2_pcm_sfx(S2_SFX_SPINDASH_RELEASE)

func _spin_dash() -> void:
	timer -= 1
	if timer < 0:
		repeat_count -= 1
		if repeat_count == 0:
			_enter_cooldown()
			return
		secondary = 0x02
		vx = 0
		timer = 0x20
		_set_flame_animation(1, true)
		return
	if timer == 0x20:
		_set_animation(2)
		_set_flame_visible(false)
	_decelerate_x()
	_animate_checked()
	# The source flips render_flags once when animation 2 reaches its second
	# authored frame. Across the two spin passes this flips twice.
	if anim_id == 2 and anim_just_set_frame and anim_cursor == 2 and anim_duration == 3:
		facing_left = not facing_left

func _common_pose_setup() -> void:
	secondary += 2
	mapping_frame = 3
	_set_animation(3)

func _common_pose_wait() -> void:
	if not _animate_checked():
		return
	secondary += 2
	timer = 0x20
	_set_animation(4)
	SonicAudio.play_s2_pcm_sfx(S2_SFX_LASER_BEAM)

func _ground_charge() -> void:
	timer -= 1
	if timer >= 0:
		_animate_checked()
		return
	secondary = 0x0C
	timer = 0x40
	_set_alternating_speed(0x800)

func _ground_dash() -> void:
	timer -= 1
	if timer < 0:
		_close_from_current()
		return
	_decelerate_x()
	_animate_checked()

func _jump_charge() -> void:
	timer -= 1
	if timer >= 0:
		_animate_checked()
		return
	secondary += 2
	timer = 0x40
	_set_alternating_speed(0x400)

func _jump_runup() -> void:
	timer -= 1
	if timer == 0x3C:
		secondary += 2
		vy = -0x600
	_animate_checked()

func _jump_air(with_spikes: bool) -> void:
	timer -= 1
	if timer < 0:
		_close_from_current()
		return
	if with_spikes and not spike_spawned and vy >= 0:
		spike_spawned = true
		_spawn_radial_spikes()
		SonicAudio.play_s2_pcm_sfx(S2_SFX_SPIKE_SWITCH)
	var distance: int = _floor_distance()
	if distance < 0:
		secondary += 2
		y_fixed += distance << 16
		vy = 0
	else:
		vy = GenesisMath.s16(vy + 0x38)
	_animate_checked()

func _jump_ground_wait() -> void:
	timer -= 1
	if timer < 0:
		_close_from_current()
		return
	_snap_to_floor()
	_animate_checked()

func _close_from_current() -> void:
	secondary += 2
	_set_animation(5)
	facing_left = not facing_left
	vx = 0
	vy = 0

func _close_animation() -> void:
	if _animate_checked():
		_enter_cooldown()

func _set_alternating_speed(speed: int) -> void:
	# loc_39D60: first call negates d0; each subsequent call alternates.
	vx = speed if direction_toggle else -speed
	direction_toggle = not direction_toggle

func _decelerate_x() -> void:
	if vx < 0:
		vx = GenesisMath.s16(vx + 0x20)
	else:
		vx = GenesisMath.s16(vx - 0x20)

func _move_main() -> void:
	x_fixed += GenesisMath.s16(vx) << 8
	y_fixed += GenesisMath.s16(vy) << 8

func _set_animation(new_anim: int) -> void:
	if anim_id == new_anim:
		return
	anim_id = new_anim
	anim_next = -1
	anim_cursor = 0
	anim_duration = 0

func _animate_checked() -> bool:
	anim_just_set_frame = false
	if anim_id < 0 or anim_id >= ANIM_FRAMES.size():
		return false
	if anim_next != anim_id:
		anim_next = anim_id
		anim_cursor = 0
		anim_duration = 0
	anim_duration -= 1
	if anim_duration >= 0:
		return false
	anim_duration = ANIM_DELAYS[anim_id]
	var frames: Array = ANIM_FRAMES[anim_id]
	if anim_cursor < frames.size():
		mapping_frame = int(frames[anim_cursor])
		anim_cursor += 1
		anim_just_set_frame = true
		return false
	var end_mode: int = ANIM_ENDS[anim_id]
	if end_mode == ANIM_LOOP:
		anim_cursor = 0
		mapping_frame = int(frames[0])
		anim_cursor = 1
		anim_just_set_frame = true
		return true
	if end_mode == ANIM_SECONDARY:
		secondary += 2
		return true
	# $FC: force duration to 1 and remain on the final mapping.
	anim_duration = 1
	return true

func _set_flame_animation(new_anim: int, make_visible: bool = true) -> void:
	flame_anim = clampi(new_anim, 0, FLAME_FRAMES.size() - 1)
	flame_cursor = 0
	flame_duration = 0
	if flame_sprite != null:
		flame_sprite.visible = make_visible
		_set_flame_frame(int((FLAME_FRAMES[flame_anim] as Array)[0]))

func _set_flame_visible(value: bool) -> void:
	if flame_sprite != null:
		flame_sprite.visible = value

func _tick_flame_animation() -> void:
	if flame_sprite == null or not flame_sprite.visible:
		return
	flame_duration -= 1
	if flame_duration >= 0:
		return
	flame_duration = 1
	var frames: Array = FLAME_FRAMES[flame_anim]
	_set_flame_frame(int(frames[flame_cursor]))
	flame_cursor = (flame_cursor + 1) % frames.size()

func _spawn_radial_spikes() -> void:
	for data_value in SPIKE_DATA:
		var data: Array = data_value
		var projectile_sprite: Sprite2D = Sprite2D.new()
		projectile_sprite.centered = true
		projectile_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		projectile_sprite.z_index = 44
		add_child(projectile_sprite)
		var frame: int = int(data[4])
		var path: String = "res://assets/objects/s2_dez/mecha/%02d.png" % frame
		if not _texture_cache.has(path):
			_texture_cache[path] = load(path)
		projectile_sprite.texture = _texture_cache[path] as Texture2D
		var px_fixed: int = (_x() + int(data[0])) << 16
		var py_fixed: int = (_y() + int(data[1])) << 16
		var item: Dictionary = {
			"sprite": projectile_sprite,
			"x_fixed": px_fixed,
			"y_fixed": py_fixed,
			"vx": int(data[2]),
			"vy": int(data[3]),
			"life": 300,
		}
		projectiles.append(item)

func _tick_projectiles() -> void:
	var p: SonicPlayer = manager.player if manager != null else null
	for i in range(projectiles.size() - 1, -1, -1):
		var item: Dictionary = projectiles[i]
		var projectile_sprite: Sprite2D = item.get("sprite") as Sprite2D
		if projectile_sprite == null or not is_instance_valid(projectile_sprite):
			projectiles.remove_at(i)
			continue
		var px_fixed: int = int(item.get("x_fixed", 0)) + (GenesisMath.s16(int(item.get("vx", 0))) << 8)
		var py_fixed: int = int(item.get("y_fixed", 0)) + (GenesisMath.s16(int(item.get("vy", 0))) << 8)
		var life: int = int(item.get("life", 0)) - 1
		item["x_fixed"] = px_fixed
		item["y_fixed"] = py_fixed
		item["life"] = life
		projectiles[i] = item
		var px: int = px_fixed >> 16
		var py: int = py_fixed >> 16
		projectile_sprite.position = Vector2(px - _x(), py - _y())
		if p != null and not p.dead and not p.hurt_state:
			if absi(p.pixel_x() - px) <= p.width_radius + 5 and absi(p.pixel_y() - py) <= p.height_radius + 4:
				p.apply_hazard_hit(px)
		if life <= 0 or px < manager.current_screen_x - 0x180 or px > manager.current_screen_x + 0x400 or py < manager.current_screen_y - 0x180 or py > manager.current_screen_y + 0x300:
			projectile_sprite.queue_free()
			projectiles.remove_at(i)

func _clear_projectiles() -> void:
	for item_value in projectiles:
		var item: Dictionary = item_value
		var projectile_sprite: Sprite2D = item.get("sprite") as Sprite2D
		if projectile_sprite != null and is_instance_valid(projectile_sprite):
			projectile_sprite.queue_free()
	projectiles.clear()

func _check_player_contact() -> void:
	var p: SonicPlayer = manager.player
	if p == null or p.dead or p.hurt_state:
		return
	# Retail TouchResponse uses collision_flags low bits $1A, whose table entry
	# is 12x12. ObjAF's x/y radii ($10/$1B) are separate object geometry.
	if absi(p.pixel_x() - _x()) > TOUCH_X + p.width_radius or absi(p.pixel_y() - _y()) > TOUCH_Y + p.height_radius:
		return

	# loc_39D24 changes collision_flags from $1A to $9A specifically for
	# mapping frames 6/7/8. The high bit routes TouchResponse to Touch_ChkHurt,
	# so Mecha Sonic's ball/spine frames hurt Sonic and cannot be damaged.
	if mapping_frame == 6 or mapping_frame == 7 or mapping_frame == 8:
		p.apply_hazard_hit(_x())
		return

	# After a successful boss hit the retail Touch_Enemy path clears
	# collision_flags. ObjAF only restores it after its $20-frame hit flash, so
	# there must be no repeated rebound/contact while the sprites still overlap.
	if invulnerability_timer > 0:
		return

	if p.can_attack_object():
		# Touch_Enemy_Part2 negates both velocity words. This is important for
		# horizontal/spindash contacts and prevents Sonic from hanging inside the
		# boss while repeatedly registering hits.
		p.vel_x = GenesisMath.s16(-p.vel_x)
		p.vel_y = GenesisMath.s16(-p.vel_y)
		hits -= 1
		invulnerability_timer = 0x20
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits <= 0:
			_begin_defeat()
		return
	p.apply_hazard_hit(_x())

func _begin_defeat() -> void:
	phase = PH_DEFEAT
	timer = 0xFF
	vx = 0
	vy = 0
	_set_flame_visible(false)
	_clear_projectiles()
	manager.add_score(100)
	manager.boss_status = 1
	manager.boss_screen_lock = false
	manager.boss_limit_right = 0x1000

func _tick_defeat() -> void:
	timer -= 1
	if (timer & 7) == 0:
		var rx: int = int(manager.next_random_word() & 0x3F) - 0x20
		var ry: int = int((manager.next_random_word() >> 4) & 0x3F) - 0x20
		manager.spawn_boss_explosion(_x() + rx, _y() + ry)
	if timer >= 0:
		return
	manager.s2_dez_mecha_defeated = true
	alive = false

func _update_visual() -> void:
	if sprite == null:
		return
	sprite.flip_h = not facing_left
	if flame_sprite != null:
		flame_sprite.flip_h = not facing_left
	_tick_flame_animation()
	if phase == PH_DEFEAT:
		sprite.visible = (frame_counter & 1) == 0
	else:
		sprite.visible = invulnerability_timer == 0 or (frame_counter & 1) == 0
	_set_frame(mapping_frame)

func _set_frame(frame: int) -> void:
	if sprite == null:
		return
	var f: int = clampi(frame, 0, 22)
	var path: String = "res://assets/objects/s2_dez/mecha/%02d.png" % f
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path)
	var tex: Texture2D = _texture_cache[path] as Texture2D
	if tex != null and sprite.texture != tex:
		sprite.texture = tex

func _set_flame_frame(frame: int) -> void:
	if flame_sprite == null:
		return
	var f: int = clampi(frame, 0, 22)
	var path: String = "res://assets/objects/s2_dez/mecha/%02d.png" % f
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path)
	var tex: Texture2D = _texture_cache[path] as Texture2D
	if tex != null and flame_sprite.texture != tex:
		flame_sprite.texture = tex

func _floor_distance() -> int:
	if manager == null or manager.collision == null:
		return 0x7FFF
	var probe_y: int = _y() + HIT_Y
	var hit: Dictionary = manager.collision.find_floor(_x(), probe_y, 13, 16, 0, false)
	return int(hit.get("distance", 0x7FFF))

func _snap_to_floor() -> void:
	var distance: int = _floor_distance()
	if distance > -0x40 and distance < 0x40:
		y_fixed += distance << 16

func _x() -> int:
	return x_fixed >> 16

func _y() -> int:
	return y_fixed >> 16
