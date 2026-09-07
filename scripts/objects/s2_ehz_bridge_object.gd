class_name S2EHZBridgeObject
extends BridgeObject

# EHZ Object $11 uses the same integer bridge-depression family as the S1 GHZ
# bridge, but with its own source art and S2 placement log counts.
func initialize_object() -> void:
	log_count = maxi(1, subtype)
	active_width = log_count * 8
	var left = -(log_count >> 1) * 16
	for i in range(log_count):
		var log = make_sprite("res://assets/objects/s2_ehz/bridge/00.png")
		log.position = Vector2(left + i * 16, 0)
		logs.append(log)
