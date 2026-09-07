class_name MZGeyserColumn
extends Node2D

# Native Object $4D. Subtype 1 is the ceiling lavafall used by MZ2/3.

var manager: SonicObjectManager
var alive := true
var subtype := 1
var origin_y := 0
var top_y_fixed := 0
var vel_y := 0
var frame_tick := 0
var tip: Sprite2D
var column: Sprite2D
var bottom_tip: Sprite2D
var pool_bubble: Sprite2D
var pool_bubble_tick = -1

func setup(owner: SonicObjectManager, x: int, y: int, kind: int) -> void:
	manager = owner
	subtype = kind
	origin_y = y
	position.x = x
	if subtype == 0:
		top_y_fixed = y << 16
		vel_y = -0x500
	else:
		# Geyser_Main moves a lavafall top $250 px above its maker.
		top_y_fixed = (y - 0x250) << 16
		vel_y = 0
	tip = _make_sprite("res://assets/objects/mz_geyser/06.png", 2)
	column = _make_sprite("res://assets/objects/mz_geyser/08.png", 1)
	bottom_tip = _make_sprite("res://assets/objects/mz_geyser/06.png", 3)
	pool_bubble = _make_sprite("res://assets/objects/mz_geyser/00.png", 4)
	# The third/bottom end-cap exists only for subtype 1 lavafalls. Native
	# subtype-0 geysers have only the moving top and the vertical wall.
	bottom_tip.visible = subtype == 1
	# The impact/bubble mapping is foreground-priority at the pool surface. The
	# high-priority lava terrain is z=100 in the native renderer, so make only
	# this child absolute/foreground while the falling column remains behind it.
	pool_bubble.z_as_relative = false
	pool_bubble.z_index = 110
	pool_bubble.visible = false
	SonicAudio.play_sfx(SonicAudio.SFX_BURNING)
	_update_parts()

func tick() -> void:
	if not alive:
		return
	frame_tick += 1
	vel_y = GenesisMath.s16(vel_y + 0x18)
	top_y_fixed += vel_y << 8
	var top_y = top_y_fixed >> 16
	# Both source types delete after the moving tip passes its original Y.
	if top_y > origin_y:
		alive = false
		return
	_update_parts()
	_update_pool_bubble(top_y)
	_react_player(top_y)

func _update_parts() -> void:
	var top_y = top_y_fixed >> 16
	position.y = top_y
	var rise = maxi(0, origin_y - top_y)
	var base_frame = 0x0B
	if rise >= 0x80:
		base_frame = 0x0E
	elif rise >= 0x40:
		base_frame = 0x08
	var frame = base_frame + ((frame_tick >> 3) & 1)
	var path = "res://assets/objects/mz_geyser/%02d.png" % frame
	if ResourceLoader.exists(path):
		column.texture = load(path)
	column.position.y = 0x60
	# Object $4D selects a different moving-tip animation by subtype.
	# - subtype $00 geyser: Ani_Geyser .bubble4 -> mapping $11/$12
	# - subtype $01 lavafall: Ani_Geyser .end     -> mapping $06/$07
	# Phase 69 incorrectly used the lavafall .end cap for both, which removed
	# the wide bubbling crest visible around the rising push block.
	var tip_frame = (0x11 if subtype == 0 else 0x06) + (int(frame_tick / 3) & 1)
	var tip_path = "res://assets/objects/mz_geyser/%02d.png" % tip_frame
	if ResourceLoader.exists(tip_path):
		tip.texture = load(tip_path)
	# The third/bottom child exists only for subtype $01 and always uses .end.
	if subtype == 1:
		var bottom_frame = 0x06 + (int(frame_tick / 3) & 1)
		var bottom_path = "res://assets/objects/mz_geyser/%02d.png" % bottom_frame
		if ResourceLoader.exists(bottom_path):
			bottom_tip.texture = load(bottom_path)
	tip.position.y = 0
	bottom_tip.position.y = 0x100
	# The lower end is its own source child and is deleted when it reaches the
	# pool; it does not remain attached below the falling column afterward.
	bottom_tip.visible = subtype == 1 and top_y + 0x100 <= origin_y

func _update_pool_bubble(top_y: int) -> void:
	if pool_bubble == null:
		return
	# For a lavafall, the third/bottom tip reaching the original maker Y changes
	# the maker from blank to Ani_Geyser .bubble1: 0,1,0,1,4,5,4,5 (delay 2).
	if subtype == 1 and pool_bubble_tick < 0 and top_y + 0x100 > origin_y:
		pool_bubble_tick = 0
	if pool_bubble_tick < 0:
		return
	var sequence = [0, 1, 0, 1, 4, 5, 4, 5]
	var index = int(pool_bubble_tick / 3)
	if index >= sequence.size():
		pool_bubble.visible = false
		return
	pool_bubble.visible = true
	pool_bubble.position = Vector2(0, origin_y - top_y)
	var path = "res://assets/objects/mz_geyser/%02d.png" % sequence[index]
	if ResourceLoader.exists(path):
		pool_bubble.texture = load(path)
	pool_bubble_tick += 1

func _react_player(top_y: int) -> void:
	var p = manager.player
	if p == null or p.dead:
		return
	# The original big wall uses col_64x224|hurt.
	var cx = int(position.x)
	var center_y = top_y + 0x70
	if absi(p.pixel_x() - cx) <= p.width_radius + 32 and absi(p.pixel_y() - center_y) <= p.height_radius + 112:
		p.apply_hazard_hit(cx)

func _make_sprite(path: String, z: int) -> Sprite2D:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.z_index = z
	if ResourceLoader.exists(path):
		sp.texture = load(path)
	add_child(sp)
	return sp
