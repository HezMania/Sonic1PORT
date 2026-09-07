class_name WaterfallTriggerObject
extends GenesisLevelObject

# Object 49 - invisible GHZ waterfall sound trigger. The original queues the
# waterfall SFX every 64 frames while this object is active. Phase 54 restores
# $D0 through SonicAudio's source-derived special-PCM path.

var pulse_counter := 0
var waterfall_pulse := false

func initialize_object() -> void:
	active_width = 16
	visible = false

func tick() -> void:
	waterfall_pulse = false
	pulse_counter = (pulse_counter + 1) & 0x3F
	if pulse_counter == 0:
		waterfall_pulse = true
		if SonicAudio.waterfall_sfx_enabled():
			SonicAudio.play_sfx(SonicAudio.SFX_WATERFALL)
