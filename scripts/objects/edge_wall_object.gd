class_name EdgeWallObject
extends GenesisLevelObject

var sprite: Sprite2D
var frame := 0
var solid := true

func initialize_object() -> void:
	frame = subtype & 0x0F
	frame = clampi(frame, 0, 2)
	solid = (subtype & 0x10) == 0
	active_width = 8
	sprite = make_sprite("res://assets/objects/edge_wall/%02d.png" % frame)

func tick() -> void:
	if not solid:
		return
	var p = player()
	if p == null:
		return
	# Edge_Solid uses the dedicated EdgeWall_SolidWall path. Unlike SolidObject,
	# its 38-pixel width is tested against Sonic's centre and must not be expanded
	# by Sonic's horizontal radius.
	p.resolve_edge_wall(spawn_x, spawn_y, 19, 40)
