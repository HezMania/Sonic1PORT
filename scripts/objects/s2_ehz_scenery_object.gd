class_name S2EHZSceneryObject
extends GenesisLevelObject

# Retail Sonic 2 Object $1C is zone-dependent. Every EHZ1 placement in the
# supplied source uses subtype $02: the stationary bridge stake, which reuses
# EHZ bridge mappings frame 1 and the same Nemesis bridge art as Object $11.
var sprite: Sprite2D

func initialize_object() -> void:
	active_width = 4
	if subtype == 0x02:
		sprite = make_sprite("res://assets/objects/s2_ehz/bridge/01.png")
	else:
		# Do not guess another zone's Object $1C interpretation.
		visible = false
