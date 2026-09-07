class_name PowerUpObject
extends Node2D

# Native Object $2E monitor contents. The icon rises at -$300, slows by $18
# per frame, awards the item when upward speed reaches zero, then remains for
# 30 frames before deletion.
var manager: SonicObjectManager
var subtype := 0
var velocity_y := -0x300
var awarded := false
var wait_frames := 0
var alive := true
var sprite: Sprite2D

func setup(owner: SonicObjectManager, world_x: int, world_y: int, item_subtype: int) -> void:
	manager = owner
	subtype = item_subtype
	position = Vector2(world_x, world_y)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path = "res://assets/objects/powerup/%02d.png" % clampi(subtype, 1, 8)
	sprite.texture = load(path)
	add_child(sprite)

func tick() -> void:
	if not alive:
		return
	if not awarded:
		if velocity_y < 0:
			position.y += float(velocity_y) / 256.0
			velocity_y += 0x18
			return
		awarded = true
		wait_frames = 30
		var p = manager.player
		if p != null and is_instance_valid(p):
			p.grant_power_up(subtype)
		return
	wait_frames -= 1
	if wait_frames <= 0:
		alive = false
