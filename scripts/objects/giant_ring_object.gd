class_name GiantRingObject
extends GenesisLevelObject

# Object 4B plus the essential Object 7C flash sequence. The special-stage
# engine itself remains a separate phase, but the native GHZ1 game now reaches
# the correct special-stage transition request when Sonic enters with 50 rings.

var sprite: Sprite2D
var flash: Sprite2D
var anim_tick := 0
var collecting := false
var flash_frame := -1
var flash_delay := 0
var player_hidden := false

func initialize_object() -> void:
	active_width = 64
	sprite = make_sprite("res://assets/objects/giant_ring/00.png")
	sprite.visible = false
	flash = make_sprite("res://assets/objects/giant_flash/00.png", 1)
	flash.visible = false

func tick() -> void:
	var p = player()
	if p == null:
		return
	if collecting:
		_tick_flash(p)
		return

	# The original only enables/displays the ring when Sonic has >= 50 rings
	# and has not collected all six emeralds.
	var enabled = manager.rings >= 50 and manager.emeralds < 6
	sprite.visible = enabled
	if not enabled:
		return

	anim_tick += 1
	set_sprite_frame(sprite, "giant_ring", (anim_tick >> 3) & 3)
	if p.dead or p.hurt_state:
		return
	if absi(p.pixel_x() - spawn_x) < 16 and absi(p.pixel_y() - spawn_y) < 32:
		SonicAudio.play_sfx(SonicAudio.SFX_GIANT_RING)
		collecting = true
		flash.visible = true
		flash_frame = -1
		flash_delay = 0
		p.transition_locked = true
		p.vel_x = 0
		p.vel_y = 0
		p.inertia = 0

func _tick_flash(p: SonicPlayer) -> void:
	flash_delay -= 1
	if flash_delay >= 0:
		return
	flash_delay = 1 # each flash frame is displayed for two ticks
	flash_frame += 1
	if flash_frame >= 8:
		# Object $7C deletes Sonic after the flash, but does NOT enter the
		# Special Stage here. f_bigring is consumed later by Object $3A
		# Got_NextLevel, after the complete results-card/tally sequence.
		request_delete(false)
		return
	set_sprite_frame(flash, "giant_flash", flash_frame)
	if flash_frame == 3 and not player_hidden:
		player_hidden = true
		sprite.visible = false
		manager.big_ring_collected = true
		p.invincible_timer = 0
		p.shield = false
		p.display_hidden = true
		p.visual.visible = false
