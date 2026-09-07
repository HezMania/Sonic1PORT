class_name GenesisPaletteFade
extends CanvasLayer

# Phase 51 Hotfix 1: reliable rendered-frame presentation of Sonic 1's
# full-screen palette fades. Phase 50/51 used a screen-texture shader whose
# source capture was backend dependent in the GL compatibility renderer and
# could collapse to an abrupt white frame. This helper deliberately uses an
# opaque overlay whose alpha changes only once per source VBlank step. The
# source callers still supply the original 22-step timing (and the Special
# Stage/Ending three-frame slow-white cadence), so the transition is visibly
# stepped over real rendered frames on every renderer backend.
#
# This is presentation-safe rather than a claim of per-color CRAM emulation:
# exact channel-staggered CRAM ranges remain a later VDP palette-buffer task.

const MODE_OFF := 0
const MODE_BLACK_IN := 1
const MODE_BLACK_OUT := 2
const MODE_WHITE_IN := 3
const MODE_WHITE_OUT := 4
const SOURCE_STEPS := 21
const SOURCE_FRAMES := 22

var rect: ColorRect

func _ready() -> void:
	layer = 4095
	rect = ColorRect.new()
	rect.name = "GenesisPaletteFadeRect"
	rect.position = Vector2.ZERO
	rect.size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 320)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 224))
	)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	hide_fade()

func show_step(mode: int, step: int) -> void:
	if rect == null:
		return
	var clamped_mode := clampi(mode, MODE_OFF, MODE_WHITE_OUT)
	var s := clampi(step, 0, SOURCE_STEPS)
	if clamped_mode == MODE_OFF:
		hide_fade()
		return

	# FadeIn routines remove an opaque black/white screen over 21 source
	# channel steps; FadeOut routines add it. Quantizing alpha to the same 21
	# increments guarantees a visible frame-by-frame staircase instead of a
	# single backend-dependent post-process jump.
	var progress := float(s) / float(SOURCE_STEPS)
	var alpha := progress
	var base := Color.BLACK
	if clamped_mode == MODE_BLACK_IN:
		alpha = 1.0 - progress
		base = Color.BLACK
	elif clamped_mode == MODE_BLACK_OUT:
		alpha = progress
		base = Color.BLACK
	elif clamped_mode == MODE_WHITE_IN:
		alpha = 1.0 - progress
		base = Color.WHITE
	elif clamped_mode == MODE_WHITE_OUT:
		alpha = progress
		base = Color.WHITE

	visible = true
	rect.color = Color(base.r, base.g, base.b, clampf(alpha, 0.0, 1.0))

func hide_fade() -> void:
	visible = false
	if rect != null:
		rect.color = Color(0, 0, 0, 0)
