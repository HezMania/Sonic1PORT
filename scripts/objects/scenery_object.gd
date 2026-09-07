class_name SceneryObject
extends GenesisLevelObject

var sprite: Sprite2D

func initialize_object() -> void:
	var zone = int(manager.level_definition.get("zone", LevelCatalog.ZONE_GHZ)) if manager != null else LevelCatalog.ZONE_GHZ
	if zone == LevelCatalog.ZONE_SLZ:
		# Object $1C in SLZ is the decorative fireball launcher paired with the
		# nearby invisible Object $13 maker. Source Scen_Values uses the original
		# SLZ Cannon art on palette line 2 (Tile_Pal3).
		active_width = 8
		z_index = 20
		sprite = make_sprite("")
		sprite.texture = SourceObjectArt.slz_fire_launcher_texture()
		return
	# All GHZ1 Object $1C records use subtype 3: the bridge stump mapping.
	if subtype == 3:
		active_width = 16
		sprite = make_sprite("res://assets/objects/bridge/01.png")
	else:
		queue_redraw()

func _draw() -> void:
	if sprite != null or subtype == 3:
		return
	if manager != null and manager.show_placeholders:
		draw_rect(Rect2(-4, -4, 8, 8), Color(1.0, 0.2, 0.8, 0.85), false, 1.0)
