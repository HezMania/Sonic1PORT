class_name HiddenBonusObject
extends GenesisLevelObject

# Object 7D - invisible end-of-act score markers.
# Subtypes 1/2/3 award 10000/1000/100 points and display for 120 frames.

const BONUS_POINTS: Array[int] = [0, 10000, 1000, 100]
var sprite: Sprite2D
var triggered := false
var display_timer := 0

func initialize_object() -> void:
	active_width = 16
	# Frame 0 is blank, matching the invisible initial routine.
	sprite = make_sprite("res://assets/objects/hidden_bonus/00.png")
	sprite.visible = false

func tick() -> void:
	if triggered:
		display_timer -= 1
		if display_timer < 0:
			request_delete(false)
		return
	var p = player()
	if p == null or p.dead or manager.big_ring_collected:
		return
	if absi(p.pixel_x() - spawn_x) >= 16 or absi(p.pixel_y() - spawn_y) >= 16:
		return
	triggered = true
	display_timer = 119
	var frame = clampi(subtype, 1, 3)
	set_sprite_frame(sprite, "hidden_bonus", frame)
	sprite.visible = true
	manager.add_score(BONUS_POINTS[frame])
