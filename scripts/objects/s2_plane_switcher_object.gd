class_name S2PlaneSwitcherObject
extends GenesisLevelObject

# Retail Sonic 2 Object $03. The source object has X- and Y-oriented variants,
# four half-extents ($20/$40/$80/$100), and separate crossing-direction bits.
# Our terrain already has native S2 primary/secondary collision indices, so the
# C/D vs E/F selection maps directly onto SonicPlayer.collision_path.
const HALF_EXTENTS: Array[int] = [0x20, 0x40, 0x80, 0x100]

var previous_side := 0
var vertical_switch := false
var half_extent := 0x20
var switcher_key := -1

func initialize_object() -> void:
	visible = false
	vertical_switch = (subtype & 0x04) != 0
	half_extent = HALF_EXTENTS[subtype & 3]
	switcher_key = 0x200000 + record_index
	var p = player()
	if p != null:
		previous_side = 1 if ((p.pixel_y() if vertical_switch else p.pixel_x()) > (spawn_y if vertical_switch else spawn_x)) else 0

func tick() -> void:
	var p = player()
	if p == null or p.debug_free_mode:
		return
	var axis = p.pixel_y() if vertical_switch else p.pixel_x()
	var origin = spawn_y if vertical_switch else spawn_x
	var side = 1 if axis > origin else 0
	if side == previous_side:
		return
	var perp = p.pixel_x() if vertical_switch else p.pixel_y()
	var perp_origin = spawn_x if vertical_switch else spawn_y
	previous_side = side
	if perp < perp_origin - half_extent or perp >= perp_origin + half_extent:
		return
	# Obj03 ignores collision-plane changes when placement X-flip is set. That
	# variant only changes sprite priority in the original renderer.
	if x_flip:
		return
	# A negative subtype in Obj03 means collision-plane changes are suppressed
	# while the character is airborne. This is the source `bpl` / status bit 1
	# guard used on both crossing directions.
	if (subtype & 0x80) != 0 and p.in_air:
		return
	var choose_secondary := false
	if side == 1:
		# Crossing from left->right or top->bottom uses subtype bit 3.
		choose_secondary = (subtype & 0x08) != 0
	else:
		# Crossing from right->left or bottom->top uses subtype bit 4.
		choose_secondary = (subtype & 0x10) != 0
	p.set_collision_path(GHZLevelData.COLLISION_PATH_SECONDARY if choose_secondary else GHZLevelData.COLLISION_PATH_PRIMARY, switcher_key if choose_secondary else -1)
