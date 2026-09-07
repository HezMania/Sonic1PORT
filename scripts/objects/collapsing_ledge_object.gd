class_name CollapsingLedgeObject
extends GenesisLevelObject

# Object 1A - GHZ collapsing ledge.
# Ported from "1A, 53 Collapsing Ledges and Floors.asm". The ledge uses the
# original 48-sample slope heightmap, seven-frame trigger delay, 25 mapped
# fragments, and the original per-fragment fall-delay table.

const HALF_WIDTH := 48
const INITIAL_COLLAPSE_DELAY := 7
const FRAGMENT_DELAYS: Array[int] = [
	0x1C, 0x18, 0x14, 0x10,
	0x1A, 0x16, 0x12, 0x0E, 0x0A, 0x06,
	0x18, 0x14, 0x10, 0x0C, 0x08, 0x04,
	0x16, 0x12, 0x0E, 0x0A, 0x06, 0x02,
	0x14, 0x10, 0x0C,
]
const FRAGMENT_OFFSETS: Array[Vector2] = [
	Vector2(40, -44), Vector2(24, -44), Vector2(8, -40), Vector2(-8, -40),
	Vector2(40, -24), Vector2(24, -24), Vector2(8, -24), Vector2(-8, -24),
	Vector2(-24, -28), Vector2(-40, -28),
	Vector2(40, -8), Vector2(24, -8), Vector2(8, -8), Vector2(-8, -8), Vector2(-24, -8), Vector2(-40, -8),
	Vector2(40, 8), Vector2(24, 8), Vector2(8, 8), Vector2(-8, 8), Vector2(-24, 8), Vector2(-40, 8),
	Vector2(40, 24), Vector2(24, 24), Vector2(8, 24),
]

var sprite: Sprite2D
var collapse_started := false
var collapse_delay := INITIAL_COLLAPSE_DELAY
var fragmented := false
var fragment_sprites: Array[Sprite2D] = []
var fragment_delays: Array[int] = []
var fragment_vel_y: Array[int] = []
var fragments_alive := 0
var support_release_delay := 0

func initialize_object() -> void:
	active_width = HALF_WIDTH
	var frame = clampi(subtype & 1, 0, 1)
	sprite = make_sprite("res://assets/objects/ledge/%02d.png" % frame)

func tick() -> void:
	if fragmented:
		_tick_fragments()
		return
	var p = player()
	if p == null:
		return

	var standing = _resolve_slope_top(p)
	if standing and not collapse_started:
		collapse_started = true
	if collapse_started:
		if collapse_delay <= 0:
			_fragmentate()
			return
		collapse_delay -= 1

func _resolve_slope_top(p: SonicPlayer) -> bool:
	if p.in_air and p.vel_y < 0:
		return false
	var dx = p.pixel_x() - spawn_x
	if dx < -HALF_WIDTH or dx >= HALF_WIDTH:
		return false
	var sample = (dx + HALF_WIDTH) >> 1
	if x_flip:
		sample = 47 - sample
	var height = _slope_height(sample)
	var top_y = spawn_y - height
	return p.resolve_platform_top(spawn_x - HALF_WIDTH, spawn_x + HALF_WIDTH, top_y, record_index)

func _slope_height(sample: int) -> int:
	sample = clampi(sample, 0, 47)
	if sample < 8:
		return 0x20
	if sample < 38:
		return 0x21 + ((sample - 8) >> 1)
	return 0x30

func _fragmentate() -> void:
	# Fragmentate_GHZLedge converts the parent into the first fragment. The
	# original first fragment keeps running Ledge_WalkOff while its own $1C
	# delay counts down, so Sonic remains supported while the ledge visibly
	# crumbles beneath him instead of dropping the instant fragmentation starts.
	support_release_delay = FRAGMENT_DELAYS[0]
	fragmented = true
	sprite.visible = false
	fragments_alive = FRAGMENT_OFFSETS.size()
	fragment_delays.clear()
	fragment_vel_y.clear()
	var variant = "right" if (subtype & 1) != 0 else "left"
	for i in range(FRAGMENT_OFFSETS.size()):
		var frag = Sprite2D.new()
		frag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frag.centered = true
		frag.texture = load("res://assets/objects/ledge_frag_%s/%02d.png" % [variant, i])
		var offset = FRAGMENT_OFFSETS[i]
		if x_flip:
			offset.x = -offset.x
			frag.flip_h = true
		frag.position = offset
		frag.z_index = sprite.z_index
		add_child(frag)
		fragment_sprites.append(frag)
		fragment_delays.append(FRAGMENT_DELAYS[i])
		fragment_vel_y.append(0)

func _tick_fragments() -> void:
	var p = player()
	if support_release_delay > 0:
		# Keep the original full slope collision until the root/first fragment
		# reaches its fall delay. Sonic may still walk off normally during this.
		if p != null:
			_resolve_slope_top(p)
		support_release_delay -= 1
		if support_release_delay == 0 and p != null:
			p.clear_object_support_for(record_index, true)
	var any_visible = false
	for i in range(fragment_sprites.size()):
		var frag = fragment_sprites[i]
		if frag == null or not is_instance_valid(frag) or not frag.visible:
			continue
		any_visible = true
		if fragment_delays[i] > 0:
			fragment_delays[i] -= 1
			continue
		var vy = fragment_vel_y[i]
		frag.position.y += float(vy) / 256.0
		vy += SonicPlayer.GRAVITY
		fragment_vel_y[i] = vy
		if spawn_y + frag.position.y > manager.player.pixel_y() + 512:
			frag.visible = false
	if not any_visible:
		request_delete(true)
