class_name SonicEffects
extends Node2D

# Native Object $38 - shield and four invincibility-star objects.
# Stars use Sonic's recent position history, with the same four staggered lag
# bands and the six-frame lag jitter used by the original tracking buffer.
var player: SonicPlayer
var shield_sprite: Sprite2D
var stars: Array[Sprite2D] = []
var history: Array[Vector2] = []
var tick_count := 0
var lag_phase := 0

const STAR_BASE_LAG: Array[int] = [1, 7, 13, 19]
const STAR_SEQ_1: Array[int] = [0, 1, 2, 3]
const STAR_SEQ_2: Array[int] = [0, 0, -1, 0, 0, -1, 1, 1, -1, 1, 1, -1, 2, 2, -1, 2, 2, -1, 3, 3, -1, 3, 3, -1]
const STAR_SEQ_3: Array[int] = [0, 0, -1, 0, -1, -1, 1, 1, -1, 1, -1, -1, 2, 2, -1, 2, -1, -1, 3, 3, -1, 3, -1, -1]
const STAR_SEQ_4: Array[int] = [0, -1, -1, 0, -1, -1, 1, -1, -1, 1, -1, -1, 2, -1, -1, 2, -1, -1, 3, -1, -1, 3, -1, -1]

func setup(sonic: SonicPlayer) -> void:
	player = sonic
	shield_sprite = Sprite2D.new()
	shield_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shield_sprite.z_index = 2
	add_child(shield_sprite)
	for i in range(4):
		var star = Sprite2D.new()
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.z_index = 2
		add_child(star)
		stars.append(star)
	for _i in range(64):
		history.append(player.global_position)
	_update_visibility()

func tick() -> void:
	if player == null or not is_instance_valid(player):
		return
	tick_count += 1
	history.push_front(player.global_position)
	if history.size() > 64:
		history.pop_back()

	global_position = player.global_position
	_update_shield()
	_update_stars()

func _update_shield() -> void:
	var show = player.shield and player.invincible_timer <= 0 and not player.dead
	shield_sprite.visible = show
	if not show:
		return
	# Ani_Shield: 1,0,2,0,3,0 with speed byte 1. Mapping frame 0 is blank.
	var seq: Array[int] = [0, -1, 1, -1, 2, -1]
	var index = int(tick_count / 2) % seq.size()
	var frame = seq[index]
	shield_sprite.visible = frame >= 0
	if frame >= 0:
		shield_sprite.texture = load("res://assets/effects/shield/%02d.png" % frame)
	shield_sprite.flip_h = player.facing_left
	shield_sprite.flip_v = false

func _update_stars() -> void:
	var enabled = player.invincible_timer > 0 and not player.dead
	if not enabled:
		for star in stars:
			star.visible = false
		return
	# Original stars_lag advances by one recorded position each frame and wraps
	# every six positions. Each of the four objects starts six positions apart.
	lag_phase = (lag_phase + 1) % 6
	for i in range(4):
		var star = stars[i]
		var sample = mini(history.size() - 1, STAR_BASE_LAG[i] + lag_phase)
		star.position = history[sample] - player.global_position
		var frame = _star_frame(i)
		star.visible = frame >= 0
		if frame >= 0:
			star.texture = load("res://assets/effects/stars/%02d.png" % frame)
		star.flip_h = player.facing_left

func _star_frame(index: int) -> int:
	match index:
		0:
			return STAR_SEQ_1[int(tick_count / 6) % STAR_SEQ_1.size()]
		1:
			return STAR_SEQ_2[tick_count % STAR_SEQ_2.size()]
		2:
			return STAR_SEQ_3[tick_count % STAR_SEQ_3.size()]
		_:
			return STAR_SEQ_4[tick_count % STAR_SEQ_4.size()]

func _update_visibility() -> void:
	shield_sprite.visible = false
	for star in stars:
		star.visible = false
