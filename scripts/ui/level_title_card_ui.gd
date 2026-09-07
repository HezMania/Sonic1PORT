class_name LevelTitleCardUI
extends CanvasLayer

# Phase 58: Object $34 presentation.  Source coordinates for screen-positioned
# sprites use the Genesis +$80 sprite bias, so UI coordinates are source-128.

const MOVE_IN_SPEED := 0x10
const MOVE_OUT_SPEED := 0x20
const HOLD_FRAMES := 60
const FADE_FRAMES := 22
const SCREEN_BIAS := 0x80

# Card_ConData: [name start,target, zone start,target, act start,target, oval start,target]
const CONFIGS := {
	0: [0x000,0x120, -0x104,0x13C, 0x414,0x154, 0x214,0x154], # GHZ
	1: [0x000,0x120, -0x10C,0x134, 0x40C,0x14C, 0x20C,0x14C], # LZ
	2: [0x000,0x120, -0x120,0x120, 0x3F8,0x138, 0x1F8,0x138], # MZ
	3: [0x000,0x120, -0x104,0x13C, 0x414,0x154, 0x214,0x154], # SLZ
	4: [0x000,0x120, -0x0FC,0x144, 0x41C,0x15C, 0x21C,0x15C], # SYZ
	5: [0x000,0x120, -0x0FC,0x144, 0x41C,0x15C, 0x21C,0x15C], # SBZ
	6: [0x000,0x120, -0x11C,0x124, 0x3EC,0x3EC, 0x1EC,0x12C], # FZ
}
const ITEM_Y := [0xD0, 0xE4, 0xEA, 0xE0]

enum State { OFF, MOVE_IN, FADE_IN, HOLD, MOVE_OUT }

var state := State.OFF
var state_timer := 0
var active := false
var blocking := false
var source_x: Array[int] = []
var start_x: Array[int] = []
var target_x: Array[int] = []
var sprites: Array[Sprite2D] = []
var palette_fade: GenesisPaletteFade
var hud: CanvasItem

func _ready() -> void:
	layer = 4096
	visible = false
	for i in range(4):
		var s := Sprite2D.new()
		s.centered = false
		s.position = Vector2(-128, -32)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Sonic 1 queues the four Object $34 elements in object-RAM order:
		# level name, ZONE, ACT, then oval. Earlier Mega Drive sprite-table
		# entries win overlap priority; Godot sibling draw order is the
		# opposite, so preserve the source ordering explicitly with z_index.
		s.z_index = 4 - i
		add_child(s)
		sprites.append(s)

func setup(fade: GenesisPaletteFade, hud_node: CanvasItem) -> void:
	palette_fade = fade
	hud = hud_node

func begin(zone: int, act: int, internal_sbz3: bool = false, final_zone: bool = false) -> void:
	var config_id := 6 if final_zone else (5 if internal_sbz3 else clampi(zone, 0, 5))
	var c: Array = CONFIGS[config_id]
	start_x.clear()
	target_x.clear()
	source_x.clear()
	for i in range(4):
		start_x.append(int(c[i * 2]))
		target_x.append(int(c[i * 2 + 1]))
		source_x.append(start_x[i])

	var name_frame := LevelTitleCardArt.FRAME_FZ if final_zone else (LevelTitleCardArt.FRAME_SBZ if internal_sbz3 else clampi(zone, 0, 5))
	var act_frame := LevelTitleCardArt.FRAME_ACT1 + clampi(act, 1, 3) - 1
	if internal_sbz3:
		act_frame = LevelTitleCardArt.FRAME_ACT3
	sprites[0].texture = LevelTitleCardArt.texture_for_frame(name_frame)
	sprites[1].texture = LevelTitleCardArt.texture_for_frame(LevelTitleCardArt.FRAME_ZONE)
	sprites[2].texture = LevelTitleCardArt.texture_for_frame(act_frame)
	sprites[3].texture = LevelTitleCardArt.texture_for_frame(LevelTitleCardArt.FRAME_OVAL)
	for i in range(4):
		sprites[i].position = Vector2(float(source_x[i] - SCREEN_BIAS - 128), float(ITEM_Y[i] - SCREEN_BIAS - 32))

	active = true
	blocking = true
	visible = true
	state = State.MOVE_IN
	state_timer = 0
	if hud != null:
		hud.visible = false
	if palette_fade != null:
		palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, 0)

func cancel() -> void:
	active = false
	blocking = false
	state = State.OFF
	visible = false
	if palette_fade != null:
		palette_fade.hide_fade()
	if hud != null:
		hud.visible = true

func tick() -> void:
	if not active:
		return
	match state:
		State.MOVE_IN:
			var all_arrived := true
			for i in range(4):
				source_x[i] = _approach(source_x[i], target_x[i], MOVE_IN_SPEED)
				if source_x[i] != target_x[i]:
					all_arrived = false
				_update_sprite_pos(i)
			if all_arrived:
				state = State.FADE_IN
				state_timer = 0
		State.FADE_IN:
			if palette_fade != null:
				palette_fade.show_step(GenesisPaletteFade.MODE_BLACK_IN, state_timer)
			state_timer += 1
			if state_timer >= FADE_FRAMES:
				if palette_fade != null:
					palette_fade.hide_fade()
				if hud != null:
					hud.visible = true
				blocking = false
				state = State.HOLD
				state_timer = HOLD_FRAMES
		State.HOLD:
			state_timer -= 1
			if state_timer <= 0:
				state = State.MOVE_OUT
		State.MOVE_OUT:
			var all_gone := true
			for i in range(4):
				source_x[i] = _approach(source_x[i], start_x[i], MOVE_OUT_SPEED)
				if source_x[i] != start_x[i]:
					all_gone = false
				_update_sprite_pos(i)
			if all_gone:
				cancel()

func _update_sprite_pos(i: int) -> void:
	# The texture itself has mapping origin at (128,32).
	sprites[i].position = Vector2(float(source_x[i] - SCREEN_BIAS - 128), float(ITEM_Y[i] - SCREEN_BIAS - 32))

func _approach(value: int, target: int, speed: int) -> int:
	if value < target:
		return mini(value + speed, target)
	if value > target:
		return maxi(value - speed, target)
	return value
