class_name PathSwitcherObject
extends GenesisLevelObject

# Phase 56 synthetic collision-plane switcher.
#
# Sonic 2 formalizes this concept as Object $03: Sonic owns a primary/secondary
# collision selector and a level object changes it as he crosses a switching
# region. Sonic 1's loop maps already contain paired collision chunks, so this
# object applies the same architecture while retaining Sonic 1's exact
# Sonic_Loops thresholds for deciding which path is active.

var chunk_x := 0
var chunk_y := 0
var raw_loop_chunk := 0
var switcher_key := -1
var was_inside := false

func setup_loop_switcher(owner: SonicObjectManager, source_chunk_x: int, source_chunk_y: int, raw_chunk: int, key: int) -> void:
	manager = owner
	chunk_x = source_chunk_x
	chunk_y = source_chunk_y
	raw_loop_chunk = raw_chunk & 0xFF
	switcher_key = key
	spawn_x = chunk_x * 256 + 128
	spawn_y = chunk_y * 256 + 128
	position = Vector2(spawn_x, spawn_y)
	visible = false
	alive = true

func tick() -> void:
	var sonic = player()
	if sonic == null or sonic.level == null:
		return

	var inside = (sonic.pixel_x() >> 8) == chunk_x and (sonic.pixel_y() >> 8) == chunk_y
	if not inside:
		# A switcher owns only the secondary path it selected. This prevents an
		# old loop trigger from resetting a neighboring trigger that Sonic has
		# already entered later in the same ExecuteObjects pass.
		if was_inside and sonic.collision_path_owner == switcher_key:
			sonic.set_collision_path(GHZLevelData.COLLISION_PATH_PRIMARY)
		was_inside = false
		return

	was_inside = true

	# Sonic_Loops type 2 (.chkifinair) explicitly returns to the front path
	# while airborne. In the retail Sonic 1 table this is SLZ chunk $B4.
	if raw_loop_chunk == 0xB4 and sonic.in_air:
		sonic.set_collision_path(GHZLevelData.COLLISION_PATH_PRIMARY)
		return

	# The 68000 intentionally compares only the low byte of obX.
	var local_x = sonic.pixel_x() & 0xFF
	var desired_path = sonic.collision_path
	if local_x < 44:
		desired_path = GHZLevelData.COLLISION_PATH_PRIMARY
	elif local_x >= 224:
		desired_path = GHZLevelData.COLLISION_PATH_SECONDARY
	else:
		var loop_angle = sonic.angle & 0xFF
		if desired_path == GHZLevelData.COLLISION_PATH_PRIMARY:
			if loop_angle != 0 and loop_angle <= 0x80:
				desired_path = GHZLevelData.COLLISION_PATH_SECONDARY
		elif loop_angle > 0x80:
			desired_path = GHZLevelData.COLLISION_PATH_PRIMARY

	sonic.set_collision_path(desired_path, switcher_key if desired_path == GHZLevelData.COLLISION_PATH_SECONDARY else -1)
