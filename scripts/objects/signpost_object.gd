class_name SignpostObject
extends GenesisLevelObject

# Object 0D - Signpost. This preserves the trigger window, three one-second
# spin cycles, the Eggman/spin/Sonic mapping frames, and the forced run after
# Sonic has landed. Phase 60 renders the source Object $3A results card/tally.

var sprite: Sprite2D
var state := 0 # 0 touch, 1 spinning, 2 forced run, 3 complete
var spin_cycle := 0
var spin_timer := 0
var anim_tick := 0

func initialize_object() -> void:
	active_width = 24
	sprite = make_sprite("res://assets/objects/signpost/00.png")

func tick() -> void:
	var p = player()
	if p == null:
		return
	match state:
		0:
			_touch_state(p)
		1:
			_spin_state(p)
		2:
			_run_state(p)
		3:
			pass

func _touch_state(p: SonicPlayer) -> void:
	var dx = p.pixel_x() - spawn_x
	if dx < 0 or dx >= 32:
		return
	SonicAudio.play_sfx(SonicAudio.SFX_SIGNPOST)
	state = 1
	spin_cycle = 0
	spin_timer = 60
	anim_tick = 0

func _spin_state(p: SonicPlayer) -> void:
	anim_tick += 1
	# spin1 uses frames 0,1,2,3; spin2 replaces 0 with frame 4.
	var phase = (anim_tick >> 1) & 3
	var frame = phase
	if spin_cycle >= 1 and phase == 0:
		frame = 4
	set_sprite_frame(sprite, "signpost", frame)

	spin_timer -= 1
	if spin_timer > 0:
		return
	spin_cycle += 1
	if spin_cycle < 3:
		spin_timer = 60
		return
	set_sprite_frame(sprite, "signpost", 4)
	state = 2
	if not p.in_air:
		p.control_locked = true

func _run_state(p: SonicPlayer) -> void:
	# Sign_SonicRun explicitly bypasses the airborne/right-edge checks once
	# Sonic has been deleted by the giant-ring flash. Our player node remains
	# allocated for the Godot level, so f_bigring/big_ring_collected is the
	# equivalent source signal. The signpost still reaches this state only after
	# all three one-second spin cycles have completed.
	if manager.big_ring_collected:
		p.control_locked = true
		manager.begin_act_complete()
		state = 3
		return
	if not p.in_air:
		p.control_locked = true
	# GHZ1's placed sign is just beyond the camera's right level boundary.
	# Once Sonic has run the original right-boundary + (320-24) threshold, expose the completed-act
	# state for the future end-card/tally transition.
	var finish_x: int = spawn_x + 135
	if p.level != null and bool(p.level.definition.get("experimental_sonic2", false)):
		# S2 Obj0D compares Sonic against Camera_Max_X_pos+$128, not against
		# signpost X. HTZ1's sign is at $2900 with Camera_Max_X=$2800, so the
		# old spawn+135 test ($2987) lay beyond Sonic_LevelBound.
		finish_x = p.runtime_limit_right + 0x128
	if p.pixel_x() >= finish_x:
		p.control_locked = false
		manager.begin_act_complete()
		state = 3
