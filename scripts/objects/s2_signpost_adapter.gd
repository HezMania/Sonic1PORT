class_name S2SignpostAdapter
extends SignpostObject

# Retail S2 Obj0D is normally single-player active only on Act 1, with the
# explicit Metropolis Act 2 exception present in the source. Keep that exception
# while reusing the proven native signpost/tally implementation.
func setup_from_record(owner: SonicObjectManager, record: Dictionary) -> void:
	super.setup_from_record(owner, record)
	var act: int = int(owner.level_definition.get("act", 1))
	var mtz2_exception: bool = bool(owner.level_definition.get("s2_mtz", false)) and act == 2
	if act != 1 and not mtz2_exception:
		request_delete(false)
