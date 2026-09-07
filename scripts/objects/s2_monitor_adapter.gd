class_name S2MonitorAdapter
extends MonitorObject

# Phase 82 deliberately reuses the proven Sonic 1 MonitorObject runtime. Retail
# S2 assigns different subtype numbers to the same single-player powerups, so
# translate only the subtype before entering the S1 code path. Graphics remain
# the shared S1 monitor bank for this compatibility pass.
var source_s2_subtype := 0

func setup_from_record(owner: SonicObjectManager, record: Dictionary) -> void:
	source_s2_subtype = int(record["subtype"]) & 0xFF
	var translated: Dictionary = record.duplicate(true)
	translated["subtype"] = _s1_compatible_subtype(source_s2_subtype)
	super.setup_from_record(owner, translated)

func _s1_compatible_subtype(value: int) -> int:
	match value:
		1, 2: return 2 # Sonic/Tails 1-up -> S1 extra life
		3: return 1    # Robotnik
		4: return 6    # Super Ring
		5: return 3    # Speed Shoes
		6: return 4    # Shield
		7: return 5    # Invincibility
		_: return 0    # static / unsupported 2P-only monitor types
