class_name PrisonCapsuleObject
extends GenesisLevelObject

# Object $3E - boss prison capsule. GHZ3 contains two placements at the same X:
# subtype 0 is the body and subtype 1 is the switch.

var sprite: Sprite2D
var state := 0
var timer := 0
var anim_tick := 0
var random_seed := 0x3E00C0DE

func initialize_object() -> void:
	active_width = 32 if subtype == 0 else 12
	var frame = 0 if subtype == 0 else 1
	sprite = make_sprite("res://assets/boss/prison/%02d.png" % frame)

func tick() -> void:
	if not alive:
		return
	if subtype == 0:
		_tick_body()
	else:
		_tick_switch()

func _tick_body() -> void:
	var p = player()
	if p == null:
		return
	if manager.boss_status >= 2:
		_set_frame(2)
		# Body opened while Sonic was standing on it: release support exactly as
		# Pri_BodyMain clears the standing bit and sets Sonic airborne.
		p.clear_object_support_for(record_index, true)
		return
	p.resolve_solid_box(spawn_x, spawn_y, 32, 24, true, record_index)

func _tick_switch() -> void:
	var p = player()
	if p == null:
		return
	anim_tick += 1
	match state:
		0:
			# Ani_Pri: delay 2, frames 1/3.
			_set_frame(1 if (int(anim_tick / 3) & 1) == 0 else 3)
			var contact = p.resolve_solid_box_contact(spawn_x, spawn_y, 12, 8, true, record_index)
			if manager.boss_status >= 1 and contact == SonicPlayer.SOLID_TOP and p.standing_on_object and p.support_record_index == record_index:
				_activate(p)
		1:
			_tick_explosions()
		2:
			_tick_animals()
		3:
			if not manager.prison_animals_alive():
				p.control_locked = false
				manager.time_frozen = false
				manager.begin_act_complete()
				state = 4
		4:
			pass

func _activate(p: SonicPlayer) -> void:
	state = 1
	timer = 60
	position.y = spawn_y + 8
	manager.time_frozen = true
	p.control_locked = true
	p.clear_object_support_for(record_index, true)

func _tick_explosions() -> void:
	if (timer & 7) == 0:
		var off = _random_offset()
		manager.spawn_monitor_explosion(spawn_x + off.x, int(position.y) + off.y)
	timer -= 1
	if timer > 0:
		return
	manager.boss_status = 2
	sprite.visible = false
	# Pri_SpawnAnimals: eight animals with staggered delays and 7px spacing.
	var xoff = -28
	var delay = (2 * 60) + 34
	for i in range(8):
		manager.spawn_prison_animal(spawn_x + xoff, spawn_y + 32, delay)
		xoff += 7
		delay -= 8
	state = 2
	timer = (2 * 60) + 30

func _tick_animals() -> void:
	if (timer & 7) == 0:
		var off = _random_offset()
		manager.spawn_prison_animal(spawn_x + off.x, spawn_y + 32, 12)
	timer -= 1
	if timer <= 0:
		state = 3

func _random_offset() -> Vector2i:
	random_seed = int((random_seed * 1664525 + 1013904223) & 0x7FFFFFFF)
	var x = (random_seed & 0x1F) - 6
	if ((random_seed >> 12) & 1) != 0:
		x = -x
	var y = (random_seed >> 8) & 0x1F
	return Vector2i(x, y)

func _set_frame(frame: int) -> void:
	var path = "res://assets/boss/prison/%02d.png" % clampi(frame, 0, 6)
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
