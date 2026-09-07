class_name GenesisLevelObject
extends Node2D

# Common PC-side equivalent of a 64-byte Sonic 1 OST entry. The fields used by
# Phase 3 retain the original names/meaning, while Godot Nodes own rendering.

var manager: SonicObjectManager
var record_index := -1
var object_id := 0
var subtype := 0
var respawn_enabled := false
var x_flip := false
var y_flip := false
var spawn_x := 0
var spawn_y := 0
var routine := 0
var alive := true
var active_width := 16

func setup_from_record(owner: SonicObjectManager, record: Dictionary) -> void:
	manager = owner
	record_index = int(record["index"])
	object_id = int(record["id"])
	subtype = int(record["subtype"])
	respawn_enabled = bool(record["remember"])
	x_flip = bool(record["x_flip"])
	y_flip = bool(record["y_flip"])
	spawn_x = int(record["x"])
	spawn_y = int(record["y"])
	position = Vector2(spawn_x, spawn_y)
	initialize_object()

func initialize_object() -> void:
	pass

func tick() -> void:
	pass

# Some original object routines intentionally skip RememberState/offscreen deletion
# for part of their lifetime (Roller is the important SYZ example).  The central
# native ObjPosLoad layer asks this before applying its generic despawn window.
func suppress_central_despawn() -> bool:
	return false

# Source objects sometimes update the coordinate used by MarkObjGone while they
# travel. Default to the authored placement X; adapters may override it.
func central_despawn_x() -> int:
	return spawn_x

# Vertical-wrapping stages (MTZ/LZ-style top=-$100,bottom=$800) render and
# collide with the nearest $800-pixel image of each object. Adapters that cache
# their own source-space Y anchors override this hook and shift those anchors too.
func apply_vertical_wrap_shift(delta_y: int) -> void:
	position.y += delta_y
	spawn_y += delta_y

func request_delete(mark_destroyed: bool = false) -> void:
	if not alive:
		return
	alive = false
	visible = false
	if mark_destroyed and manager != null:
		manager.mark_record_destroyed(record_index)

func player() -> SonicPlayer:
	return manager.player if manager != null else null

func make_sprite(texture_path: String, frame_z: int = 0) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.flip_h = x_flip
	sprite.flip_v = y_flip
	sprite.z_index = frame_z
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	add_child(sprite)
	return sprite

func set_sprite_frame(sprite: Sprite2D, folder: String, frame: int) -> void:
	var path = "res://assets/objects/%s/%02d.png" % [folder, frame]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
