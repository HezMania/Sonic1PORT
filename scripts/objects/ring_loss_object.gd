class_name RingLossObject
extends Node2D

# Native high-level translation of Object 37 (RingLoss). The original uses one
# OST slot per spilled ring; this PC port keeps the same velocities/8.8 motion
# but stores the particles under one transient object so level placement slots
# remain deterministic.

const RING_VELOCITIES: Array[Vector2i] = [
	Vector2i(-196, -1004), Vector2i(196, -1004),
	Vector2i(-568, -848), Vector2i(568, -848),
	Vector2i(-848, -568), Vector2i(848, -568),
	Vector2i(-1004, -196), Vector2i(1004, -196),
	Vector2i(-1004, 196), Vector2i(1004, 196),
	Vector2i(-848, 568), Vector2i(848, 568),
	Vector2i(-568, 848), Vector2i(568, 848),
	Vector2i(-196, 1004), Vector2i(196, 1004),
	Vector2i(-98, -502), Vector2i(98, -502),
	Vector2i(-284, -424), Vector2i(284, -424),
	Vector2i(-424, -284), Vector2i(424, -284),
	Vector2i(-502, -98), Vector2i(502, -98),
	Vector2i(-502, 98), Vector2i(502, 98),
	Vector2i(-424, 284), Vector2i(424, 284),
	Vector2i(-284, 424), Vector2i(284, 424),
	Vector2i(-98, 502), Vector2i(98, 502),
]

var manager: SonicObjectManager
var alive := true
var fixed_x: Array[int] = []
var fixed_y: Array[int] = []
var vel_x: Array[int] = []
var vel_y: Array[int] = []
var timers: Array[int] = []
var active: Array[bool] = []
var sparkle_timers: Array[int] = []
var sprites: Array[Sprite2D] = []
var frame_counter := 0

func setup(owner: SonicObjectManager, x: int, y: int, count: int) -> void:
	manager = owner
	count = clampi(count, 1, 32)
	for i in range(count):
		fixed_x.append(x << 16)
		fixed_y.append(y << 16)
		vel_x.append(RING_VELOCITIES[i].x)
		vel_y.append(RING_VELOCITIES[i].y)
		timers.append(255)
		active.append(true)
		sparkle_timers.append(-1)
		var sprite = Sprite2D.new()
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_set_frame(sprite, 0)
		sprite.position = Vector2(x, y)
		add_child(sprite)
		sprites.append(sprite)

func tick() -> void:
	if not alive or manager == null:
		return
	frame_counter += 1
	var frame = (frame_counter >> 3) & 3
	var remaining = 0
	for i in range(active.size()):
		if not active[i]:
			continue
		remaining += 1
		if sparkle_timers[i] >= 0:
			sparkle_timers[i] += 1
			var sparkle_frame = int(sparkle_timers[i] / 6)
			if sparkle_frame >= 4:
				_remove_ring(i)
			else:
				_set_frame(sprites[i], 4 + sparkle_frame)
			continue
		timers[i] -= 1
		if timers[i] <= 0:
			_remove_ring(i)
			continue

		fixed_x[i] += vel_x[i] << 8
		fixed_y[i] += vel_y[i] << 8
		vel_y[i] = GenesisMath.s16(vel_y[i] + 0x18)

		var px = fixed_x[i] >> 16
		var py = fixed_y[i] >> 16
		if vel_y[i] >= 0:
			var floor_hit = manager.collision.find_floor_sensor(px, py + 8, true, false)
			var distance = int(floor_hit["distance"])
			if distance < 0 and distance >= -16:
				fixed_y[i] += distance << 16
				var bounce = vel_y[i]
				bounce -= bounce >> 2
				vel_y[i] = -bounce
				py = fixed_y[i] >> 16

		sprites[i].position = Vector2(px, py)
		_set_frame(sprites[i], frame)

		# ReactToItem blocks lost-ring pickup for the first 30 hurt frames:
		# flashtime starts at 120 and collection is allowed below 90.
		var p = manager.player
		if p != null and p.invulnerability_timer < 90:
			if absi(p.pixel_x() - px) <= 12 and absi(p.pixel_y() - py) <= 12:
				manager.add_rings(1)
				_begin_sparkle(i)

	if remaining <= 0:
		alive = false

func _begin_sparkle(index: int) -> void:
	if index < 0 or index >= active.size() or not active[index]:
		return
	sparkle_timers[index] = 0
	vel_x[index] = 0
	vel_y[index] = 0
	_set_frame(sprites[index], 4)

func _remove_ring(index: int) -> void:
	if index < 0 or index >= active.size() or not active[index]:
		return
	active[index] = false
	sprites[index].visible = false

func _set_frame(sprite: Sprite2D, frame: int) -> void:
	var path = "res://assets/objects/rings/%02d.png" % clampi(frame, 0, 7)
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
