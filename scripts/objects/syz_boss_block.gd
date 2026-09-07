class_name SYZBossBlock
extends Node2D

# Object $76 - Spring Yard boss arena block. The event creates ten 32x32
# blocks. Eggman can grab one block, lift it, then command it to split into the
# four source 16x16 fragments.

const SUPPORT_BASE := -0x7600
const FRAGMENT_GRAVITY := SonicPlayer.GRAVITY

var manager: SonicObjectManager
var alive := true
var block_index := 0
var broken := false
var grabbed := false
var boss = null
var sprite: Sprite2D
var fragments: Array[Dictionary] = []

func setup(owner: SonicObjectManager, index: int, x: int, y: int) -> void:
	manager = owner
	block_index = index
	position = Vector2(x, y)
	sprite = _make_sprite("res://assets/boss/syz_block/00.png")

func tick() -> void:
	if not alive:
		return
	if broken:
		_tick_fragments()
		return
	if grabbed:
		if boss == null or not is_instance_valid(boss) or boss.defeated:
			break_apart()
			return
		position = Vector2(int(boss.position.x), int(boss.position.y) + 44)
		return
	if manager.player != null:
		manager.player.resolve_solid_box_contact(int(position.x), int(position.y), 16, 16, true, support_id())

func support_id() -> int:
	return SUPPORT_BASE - block_index

func grab_by(owner) -> void:
	if broken or not alive:
		return
	if manager.player != null:
		manager.player.clear_object_support_for(support_id(), true)
	grabbed = true
	boss = owner

func break_apart() -> void:
	if broken or not alive:
		return
	if manager.player != null:
		manager.player.clear_object_support_for(support_id(), true)
	broken = true
	grabbed = false
	boss = null
	if sprite != null:
		sprite.visible = false

	# BossBlock_Break source launch values and local offsets.
	var speeds = [
		Vector2i(-0x180, -0x200),
		Vector2i( 0x180, -0x200),
		Vector2i(-0x100, -0x100),
		Vector2i( 0x100, -0x100),
	]
	var offsets = [
		Vector2i(-8, -8),
		Vector2i(16, 0),
		Vector2i(0, 16),
		Vector2i(16, 16),
	]
	for i in range(4):
		var fragment = _make_sprite("res://assets/boss/syz_block/%02d.png" % (i + 1))
		fragment.position = Vector2(offsets[i].x, offsets[i].y)
		fragments.append({"sprite": fragment, "vx": speeds[i].x, "vy": speeds[i].y})

func _tick_fragments() -> void:
	if fragments.is_empty():
		alive = false
		return
	var lowest_y = -0x7FFFFFFF
	for i in range(fragments.size()):
		var data: Dictionary = fragments[i]
		var fragment: Sprite2D = data["sprite"]
		fragment.position.x += float(int(data["vx"])) / 256.0
		fragment.position.y += float(int(data["vy"])) / 256.0
		data["vy"] = GenesisMath.s16(int(data["vy"]) + FRAGMENT_GRAVITY)
		fragments[i] = data
		lowest_y = maxi(lowest_y, int(position.y + fragment.position.y))
	var view_height = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if lowest_y > manager.player.pixel_y() + view_height + 256:
		alive = false

func _make_sprite(path: String) -> Sprite2D:
	var sp = Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.texture = load(path)
	add_child(sp)
	return sp
