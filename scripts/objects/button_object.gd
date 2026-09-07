class_name ButtonObject
extends GenesisLevelObject

# Object $32 - shared MZ/SYZ/LZ/SBZ floor switch. Phase 22 moves this out of
# MarbleObject so Spring Yard can use the same switch table without inheriting
# MZ-specific art/logic.

var sprite: Sprite2D
var pressed := false
var switch_index := 0

func initialize_object() -> void:
	active_width = 16
	switch_index = subtype & 0x0F
	# But_Main adds 3px to obY before collision/display.
	position.y += 3
	var zone = int(manager.level_definition.get("zone", LevelCatalog.ZONE_GHZ))
	if zone == LevelCatalog.ZONE_MZ:
		sprite = make_sprite("res://assets/objects/mz_button/00.png")
	else:
		sprite = make_sprite("res://assets/objects/syz_button/00.png")

func tick() -> void:
	if not alive:
		return
	var p = player()
	if p == null:
		return

	var was_pressed := pressed
	var contact = p.resolve_solid_box_contact(int(position.x), int(position.y), 16, 5, true, record_index)
	pressed = contact == SonicPlayer.SOLID_TOP or (p.standing_on_object and p.support_record_index == record_index)

	# Only MZ interprets bit 7 as the special push-block switch. Several SYZ/LZ
	# layout records also have bit 7 set for unrelated reasons (the REV01 fix).
	var zone = int(manager.level_definition.get("zone", LevelCatalog.ZONE_GHZ))
	if zone == LevelCatalog.ZONE_MZ and (subtype & 0x80) != 0:
		pressed = pressed or manager.has_push_block_on_button(int(position.x), int(position.y))

	if pressed and not was_pressed:
		SonicAudio.play_sfx(SonicAudio.SFX_SWITCH)
	manager.set_switch_pressed(switch_index, pressed)
	if zone == LevelCatalog.ZONE_MZ:
		set_sprite_frame(sprite, "mz_button", 1 if pressed else 0)
	else:
		set_sprite_frame(sprite, "syz_button", 1 if pressed else 0)
