class_name HelixObject
extends GenesisLevelObject

# Object $17 - rotating GHZ spiked-pole helix.
var spikes: Array[Sprite2D] = []
var base_frames: Array[int] = []
var spike_xs: Array[int] = []

func initialize_object() -> void:
	var count = maxi(1, subtype)
	var start_x = spawn_x - ((count >> 1) * 16)
	for i in range(count):
		var sp = make_sprite("res://assets/objects/helix/00.png")
		sp.position = Vector2(start_x + i * 16 - spawn_x, 0)
		spikes.append(sp)
		base_frames.append(i & 7)
		spike_xs.append(start_x + i * 16)

func tick() -> void:
	if not alive:
		return
	# Sync1: frame decrements once every 12 frames and wraps 0-7.
	var sync_frame = (-int(manager.elapsed_frames / 12)) & 7
	var p = player()
	for i in range(spikes.size()):
		var frame = (sync_frame + base_frames[i]) & 7
		var path = "res://assets/objects/helix/%02d.png" % frame
		if ResourceLoader.exists(path):
			spikes[i].texture = load(path)
		# Only frame 0 points straight up and receives the original hurt type.
		if frame == 0 and p != null and not p.dead:
			var dx = absi(p.pixel_x() - spike_xs[i])
			var dy = p.pixel_y() + p.height_radius - spawn_y
			if dx <= p.width_radius + 4 and dy >= -18 and dy <= 4:
				p.apply_hazard_hit(spike_xs[i])
