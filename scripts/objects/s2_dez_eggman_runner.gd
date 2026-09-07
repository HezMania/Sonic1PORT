class_name S2DEZEggmanRunner
extends GenesisLevelObject

# Sonic 2 Object $C6 subtype $A6: Robotnik runner and construction-stripe door
# between Mecha Sonic and the Death Egg Robot.

const RUNNER_FOLDER: String = "s2_dez/eggman_runner"
const DOOR_FOLDER: String = "s2_dez/eggman_door"
const DOOR_X: int = 0x3F8
const DOOR_Y: int = 0x160

var sprite: Sprite2D
var door_sprite: Sprite2D
var state: int = 0
var timer: int = 0
var anim_timer: int = 0
var anim_cursor: int = 0
var vx: int = 0
var vy: int = 0
var door_state: int = 0
var door_timer: int = 0
var dust: Array = []

func initialize_object() -> void:
	active_width = 0x18
	sprite = make_sprite("res://assets/objects/%s/00.png" % RUNNER_FOLDER, 47)
	door_sprite = Sprite2D.new()
	door_sprite.name = "DEZConstructionDoor"
	door_sprite.centered = true
	door_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	door_sprite.position = Vector2(DOOR_X - spawn_x, DOOR_Y - spawn_y)
	door_sprite.z_index = 43
	add_child(door_sprite)
	_set_door_frame(0)
	_set_runner_frame(0)
	state = 0

func suppress_central_despawn() -> bool:
	return state < 5

func central_despawn_x() -> int:
	return int(round(position.x))

func tick() -> void:
	_tick_door()
	_tick_dust()
	var p: SonicPlayer = player()
	if p == null:
		return
	match state:
		0:
			# State1 creates the $A8 construction-stripe child and stores DEZ_Eggman.
			state = 1
		1:
			# Obj_GetOrientationToPlayer; +$5C then CMP #$B8 -> |dx| < $5C.
			if absi(p.pixel_x() - int(round(position.x))) < 0x5C:
				state = 2
				timer = 0x18
				_set_runner_frame(1)
		2:
			timer -= 1
			if timer < 0:
				state = 3
				vx = 0x200
				timer = 0x10
				door_state = 1
				door_timer = 0
		3:
			var wx: int = int(round(position.x))
			if wx >= 0x810:
				state = 4
				vx = 0
				_set_runner_frame(2)
				return
			if absi(p.pixel_x() - wx) < 0x50:
				position.x = p.pixel_x() + 0x50
			timer -= 1
			if timer < 0:
				timer = 0x20
				_spawn_dust()
			position.x += float(vx) / 256.0
			_tick_run_animation()
		4:
			# Retail waits until Robotnik is onscreen before the short jump/fall away.
			if int(round(position.x)) <= manager.current_screen_x + 0x180:
				state = 5
				manager.s2_dez_c6_departed = true
				vx = 0x80
				vy = -0x200
				timer = 0x50
		5:
			timer -= 1
			if timer < 0:
				request_delete(false)
				return
			vy = GenesisMath.s16(vy + 0x10)
			position.x += float(GenesisMath.s16(vx)) / 256.0
			position.y += float(GenesisMath.s16(vy)) / 256.0

func _tick_door() -> void:
	var p: SonicPlayer = player()
	if door_state == 0:
		if p != null:
			# Retail passes d1=$13 because SolidObject has already added Sonic's solid
			# width to the door's raw width_pixels=$08. resolve_solid_box_contact()
			# performs that player-radius expansion itself, so pass the authored $08.
			p.resolve_solid_box_contact(DOOR_X, DOOR_Y, 0x08, 0x20, true, record_index - 0x6000)
		return
	if door_state == 1:
		door_timer += 1
		# Ani_objC6: delay 1, frames 0,1,2,3,$FA -> 2 VBlanks per frame.
		var frame: int = mini(3, door_timer >> 1)
		_set_door_frame(frame)
		if door_timer >= 8:
			door_state = 2
			door_sprite.visible = false
			if p != null:
				p.clear_object_support_for(record_index - 0x6000, false)

func _tick_run_animation() -> void:
	anim_timer += 1
	if anim_timer < 6:
		return
	anim_timer = 0
	anim_cursor = (anim_cursor + 1) % 3
	_set_runner_frame([2, 3, 4][anim_cursor])

func _spawn_dust() -> void:
	var s: Sprite2D = Sprite2D.new()
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = 44
	add_child(s)
	var path: String = "res://assets/objects/%s/05.png" % RUNNER_FOLDER
	if ResourceLoader.exists(path):
		s.texture = load(path)
	s.position = Vector2(0, -0x18)
	dust.append({"sprite": s, "vx": -0x100, "life": 8})

func _tick_dust() -> void:
	for i in range(dust.size() - 1, -1, -1):
		var d: Dictionary = dust[i]
		var s: Sprite2D = d.get("sprite") as Sprite2D
		var life: int = int(d.get("life", 0)) - 1
		if s == null or not is_instance_valid(s) or life < 0:
			if s != null and is_instance_valid(s):
				s.queue_free()
			dust.remove_at(i)
			continue
		s.position.x += float(GenesisMath.s16(int(d.get("vx", 0)))) / 256.0
		d["life"] = life
		dust[i] = d

func _set_runner_frame(frame: int) -> void:
	if sprite == null:
		return
	var path: String = "res://assets/objects/%s/%02d.png" % [RUNNER_FOLDER, clampi(frame, 0, 7)]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func _set_door_frame(frame: int) -> void:
	if door_sprite == null:
		return
	var path: String = "res://assets/objects/%s/%02d.png" % [DOOR_FOLDER, clampi(frame, 0, 3)]
	if ResourceLoader.exists(path):
		door_sprite.texture = load(path)
