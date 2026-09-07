class_name S2EggPrisonObject
extends GenesisLevelObject

# Retail Sonic 2 Object $3E - Egg Prison.
# The source creates four linked entries (main body, switch, flying lid and
# animal controller). Godot keeps them under one node but preserves the source
# offsets, switch timing, $1D-frame opening delay, lid launch and animal release.

const STATE_WAIT := 0
const STATE_OPEN_DELAY := 1
const STATE_RELEASE := 2
const STATE_WAIT_ANIMALS := 3
const STATE_DONE := 4

var state := STATE_WAIT
var timer := 0
var anim_tick := 0
var open_anim_tick := 0
var body_frame := 0
var button_pressed := false
var lid_active := false
var lid_x_fixed := 0
var lid_y_fixed := 0
var lid_vel_x := 0
var lid_vel_y := 0
var random_seed := 0x3E53A2D1

var body_sprite: Sprite2D
var button_sprite: Sprite2D
var lid_sprite: Sprite2D
var art_folder := "s2_ehz/egg_prison"
var requires_boss_defeat := false
var button_support_id: int = -1

func initialize_object() -> void:
	active_width = 0x23 # Phase 97: restore 8 px per side after Phase 95 over-correction
	if manager != null and bool(manager.level_definition.get("s2_cpz", false)):
		art_folder = "s2_cpz/egg_prison"
	elif manager != null and bool(manager.level_definition.get("s2_arz", false)):
		art_folder = "s2_arz/egg_prison"
	elif manager != null and bool(manager.level_definition.get("s2_cnz", false)):
		art_folder = "s2_cnz/egg_prison"
	elif manager != null and bool(manager.level_definition.get("s2_htz", false)):
		art_folder = "s2_htz/egg_prison"
	elif manager != null and bool(manager.level_definition.get("s2_mcz", false)):
		art_folder = "s2_mcz/egg_prison"
	elif manager != null and bool(manager.level_definition.get("s2_ooz", false)):
		art_folder = "s2_ooz/egg_prison"
	elif manager != null and bool(manager.level_definition.get("s2_mtz", false)):
		art_folder = "s2_mtz/egg_prison"
	requires_boss_defeat = manager != null and bool(manager.level_definition.get("s2_egg_prison_requires_boss", false))
	# Retail Obj3E models the switch as a separate linked solid entry. Give it a
	# distinct stable support id so standing on the body cannot alias the button.
	button_support_id = -0x3E00 - record_index
	body_sprite = make_sprite("res://assets/objects/%s/00.png" % art_folder, 0)
	button_sprite = make_sprite("res://assets/objects/%s/04.png" % art_folder, -2)
	lid_sprite = make_sprite("res://assets/objects/%s/05.png" % art_folder, -1)
	button_sprite.position = Vector2(0, -0x28)
	lid_sprite.position = Vector2(0, -0x18)
	lid_x_fixed = spawn_x << 16
	lid_y_fixed = (spawn_y - 0x18) << 16

func tick() -> void:
	if not alive:
		return
	if requires_boss_defeat and manager != null and manager.boss_status < 1:
		visible = false
		return
	visible = true
	anim_tick += 1
	var p = player()
	if p == null:
		return
	# Retail Obj3E_Main calls SolidObject every frame, including after the lid
	# has launched and while animals are escaping. Keep the opened capsule body
	# solid until the act-complete handoff instead of dropping collision at activation.
	p.resolve_solid_box(spawn_x, spawn_y, 0x23, 0x18, true, record_index)
	_tick_lid()
	_tick_button_collision(p)
	match state:
		STATE_WAIT:
			_tick_wait(p)
		STATE_OPEN_DELAY:
			_tick_open_delay()
		STATE_RELEASE:
			_tick_release()
		STATE_WAIT_ANIMALS:
			_tick_wait_animals()
		STATE_DONE:
			pass
	_update_body_animation()

func _tick_button_collision(p: SonicPlayer) -> void:
	# Obj3E switch remains a separate solid child even after activation. Keep the
	# source d1=$1B,d2=d3=8 collision envelope while the visual button stays behind
	# the main prison body. Only the WAIT state is allowed to trigger opening.
	var button_y: int = spawn_y - (0x20 if button_pressed else 0x28)
	var contact = p.resolve_solid_box_contact(spawn_x, button_y, 0x1B, 8, true, button_support_id)
	if state == STATE_WAIT and contact == SonicPlayer.SOLID_TOP and p.standing_on_object and p.support_record_index == button_support_id:
		button_pressed = true
		button_sprite.position.y = -0x20
		_activate()

func _tick_wait(_p: SonicPlayer) -> void:
	pass

func _activate() -> void:
	if state != STATE_WAIT:
		return
	manager.spawn_monitor_explosion(spawn_x, spawn_y - 0x18)
	# Obj3E switch clears Update_HUD_timer as soon as Sonic depresses it.
	manager.time_frozen = true
	lid_active = true
	lid_vel_y = -0x400
	lid_vel_x = 0x800
	timer = 0x1D
	state = STATE_OPEN_DELAY

func _tick_open_delay() -> void:
	timer -= 1
	if timer >= 0:
		return
	open_anim_tick = 0
	_set_body_frame(0)
	# Obj3E spawns eight animals immediately, 7px apart, with delays $9A..$62.
	var xoff = -0x1C
	var delay = 0x9A
	for i in range(8):
		manager.spawn_prison_animal(spawn_x + xoff, spawn_y, delay)
		xoff += 7
		delay -= 8
	timer = 0xB4
	state = STATE_RELEASE

func _tick_release() -> void:
	# The fourth linked entry creates another animal every eight VBlanks for $B4
	# frames before advancing to the wait-for-empty routine.
	if (anim_tick & 7) == 0:
		var xoff = _random_release_x()
		manager.spawn_prison_animal(spawn_x + xoff, spawn_y, 12)
	timer -= 1
	if timer <= 0:
		state = STATE_WAIT_ANIMALS

func _tick_wait_animals() -> void:
	if manager.prison_animals_alive():
		return
	manager.begin_act_complete()
	state = STATE_DONE

func _tick_lid() -> void:
	if not lid_active:
		return
	lid_x_fixed += lid_vel_x << 8
	lid_y_fixed += lid_vel_y << 8
	lid_vel_y = GenesisMath.s16(lid_vel_y + 0x38)
	lid_sprite.position = Vector2((lid_x_fixed >> 16) - spawn_x, (lid_y_fixed >> 16) - spawn_y)
	if int(position.x + lid_sprite.position.x) > manager.current_screen_x + int(ProjectSettings.get_setting("display/window/size/viewport_width")) + 96:
		lid_sprite.visible = false
		lid_active = false

func _update_body_animation() -> void:
	if state < STATE_RELEASE:
		return
	# The raw AnimateSprite script cycles 1..3 while the controller exists. In the
	# port each mapping frame is a complete precomposited prison body, so repeating
	# that script visually re-closes the opened doors. Play the opening once and
	# hold the fully-open source frame while animals finish leaving.
	open_anim_tick += 1
	var phase := mini(3, int(open_anim_tick / 4))
	_set_body_frame(phase)

func _set_body_frame(frame: int) -> void:
	frame = clampi(frame, 0, 3)
	if frame == body_frame and body_sprite.texture != null:
		return
	body_frame = frame
	body_sprite.texture = load("res://assets/objects/%s/%02d.png" % [art_folder, frame])

func _random_release_x() -> int:
	random_seed = int((random_seed * 1103515245 + 12345) & 0x7FFFFFFF)
	var x = (random_seed & 0x1F) - 6
	if ((random_seed >> 12) & 1) != 0:
		x = -x
	return x
