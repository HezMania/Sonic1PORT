extends Node

# Phase 54 - SFX fidelity/completion on the frozen Phase 53 Hotfix 3 music core.
#
# The sequencer consumes a mechanically compiled representation of the original
# Sonic 1 SMPS music/SFX ASM. Audio is produced by a lightweight native Godot
# software synth: four-operator FM-style voices for YM2612 tracks, hardware-shaped
# SN76489 PSG voices/noise, and the original kick/snare/timpani PCM DAC samples.
#
# This keeps event/timing/voice data source-driven while avoiding a platform-
# specific GDExtension. Phase 53 keeps Hotfix 10 sequencing, corrects the PSG
# divisor/noise path, refines envelope timing, and adds output presentation modes.

const MIX_RATE := 22050.0
const BUFFER_LENGTH := 0.16
const DRIVER_HZ := 60.0
const FM_ENVELOPE_HZ := 960.0
const KIND_FM := 0
const KIND_PSG := 1
const KIND_DAC := 2
const FM_SOURCE_SAMPLE_RATE := 53267.04
const FM_SOURCE_FNUM_SCALE := 2097152.0 / FM_SOURCE_SAMPLE_RATE
const FM_SOURCE_BASE_FREQUENCIES := [15.39, 16.35, 17.34, 18.36, 19.45, 20.64, 21.84, 23.13, 24.51, 25.98, 27.53, 29.15]
const YM_KEY_CODE_CLASS := [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 3, 3, 3]
const YM_DETUNE_LOOKUP := [
	[[0,0,1,2],[0,0,1,2],[0,0,1,2],[0,0,1,2]],
	[[0,1,2,2],[0,1,2,3],[0,1,2,3],[0,1,2,3]],
	[[0,1,2,4],[0,1,3,4],[0,1,3,4],[0,1,3,5]],
	[[0,2,4,5],[0,2,4,6],[0,2,4,6],[0,2,5,7]],
	[[0,2,5,8],[0,3,6,8],[0,3,6,9],[0,3,7,10]],
	[[0,4,8,11],[0,4,8,12],[0,4,9,13],[0,5,10,14]],
	[[0,5,11,16],[0,6,12,17],[0,6,13,19],[0,7,14,20]],
	[[0,8,16,22],[0,8,16,22],[0,8,16,22],[0,8,16,22]]
]
# The S1 smpsVc* macros expose operators in logical SMPS order, but the
# emitted 68k voice bytes are written to the YM2612 in the reverse logical
# order. The compiled JSON intentionally preserves the macro argument order.
# For the music FM renderer, the YM register scrambling resolves this to
# hardware operators 1..4 receiving source macro entries 4..1.
# (The known-good Hotfix 5 live-SFX fallback stays untouched; Phase 54 routes $D0 to PCM before it.)
const SMPS_MUSIC_OPERATOR_MAP := [3, 2, 1, 0]
const TWO_PI := TAU
const MAX_SFX_INSTANCES := 6
const MAX_GENERATED_FRAMES_PER_PROCESS := 1024
const SINE_TABLE_SIZE := 16384
const SINE_TABLE_MASK := SINE_TABLE_SIZE - 1
const FM_MIX_BOOST := 1.65
const FM_OPERATOR_MOD_RADIANS := 2.5
const FM_MUSIC_PHASE_MOD_TABLE_SCALE := float(SINE_TABLE_SIZE) * 4.0
const PCM_SFX_OUTPUT_GAIN := 0.55
const PCM_SFX_DIR := "res://assets/audio/sfx_pcm"
const PSG_MIX_BOOST := 0.24
const DAC_MIX_GAIN := 0.72
const AUTHENTIC_SYNTH_LOWPASS_ALPHA := 0.50
const CLEAN_SYNTH_LOWPASS_ALPHA := 1.00
const AUTHENTIC_OUTPUT_SATURATION := 0.35
const CLEAN_OUTPUT_SATURATION := 0.12
const OUTPUT_MODE_AUTHENTIC := 0
const OUTPUT_MODE_CLEAN := 1
const PSG_SAMPLE_RATE := 223721.56
# Exact Sonic 1 PSGFrequencies table after MakePSGFrequency rounds each authored
# source frequency into the 10-bit SN76489 tone-divisor domain.
const PSG_SOURCE_DIVISORS := [
	854, 806, 761, 718, 677, 640, 604, 570, 538, 507, 479, 452,
	427, 403, 381, 359, 339, 320, 302, 285, 269, 254, 239, 226,
	214, 201, 190, 180, 169, 160, 151, 143, 135, 127, 120, 113,
	107, 101, 95, 90, 85, 80, 75, 71, 67, 64, 60, 57,
	54, 51, 48, 45, 43, 40, 38, 36, 34, 32, 31, 29,
	27, 26, 24, 23, 22, 21, 19, 18, 17, 1
]
# Four-bit SN76489 attenuation ladder. Register level $F is true silence.
const PSG_LEVEL_TABLE := [
	0x1FFF, 0x196A, 0x1430, 0x1009, 0x0CBD, 0x0A1E, 0x0809, 0x0662,
	0x0512, 0x0407, 0x0333, 0x028A, 0x0204, 0x019A, 0x0146, 0x0000
]
const RAD_TO_PHASE := float(SINE_TABLE_SIZE) / TAU
const SPEED_SHOES_TEMPOS := {
	0x81: 0x07, 0x82: 0x72, 0x83: 0x73, 0x84: 0x26,
	0x85: 0x15, 0x86: 0x08, 0x87: 0xFF, 0x88: 0x05
}

# Original Sonic 1 sound IDs.
const MUS_GHZ := 0x81
const MUS_LZ := 0x82
const MUS_MZ := 0x83
const MUS_SLZ := 0x84
const MUS_SYZ := 0x85
const MUS_SBZ := 0x86
const MUS_INVINCIBLE := 0x87
const MUS_EXTRA_LIFE := 0x88
const MUS_SPECIAL_STAGE := 0x89
const MUS_TITLE := 0x8A
const MUS_ENDING := 0x8B
const MUS_BOSS := 0x8C
const MUS_FINAL_ZONE := 0x8D
const MUS_GOT_THROUGH := 0x8E
const MUS_GAME_OVER := 0x8F
const MUS_CONTINUE := 0x90
const MUS_CREDITS := 0x91
const MUS_DROWNING := 0x92
const MUS_GET_EMERALD := 0x93
# Port-local ID for the retail Sonic 2 Emerald Hill song. Keep it outside the
# one-byte S1 ID range so it cannot collide with LZ ($82).
const MUS_S2_EHZ := 0x194
const MUS_S2_BOSS := 0x195
const MUS_S2_END_LEVEL := 0x196
const MUS_S2_CPZ := 0x197
const MUS_S2_ARZ := 0x198
const MUS_S2_CNZ := 0x199
const MUS_S2_HTZ := 0x19A
const MUS_S2_MCZ := 0x19B
const MUS_S2_OOZ := 0x19C
const MUS_S2_MTZ := 0x19D
const MUS_S2_SCZ := 0x19E
const MUS_S2_WFZ := 0x19F
const MUS_S2_DEZ := 0x1A0
const MUS_S2_END_BOSS := 0x1A1

const SFX_JUMP := 0xA0
const SFX_LAMPPOST := 0xA1
const SFX_DEATH := 0xA3
const SFX_SKID := 0xA4
const SFX_SPIKES := 0xA6
const SFX_PUSH := 0xA7
const SFX_SS_GOAL := 0xA8
const SFX_SS_ITEM := 0xA9
const SFX_SPLASH := 0xAA
const SFX_HIT_BOSS := 0xAC
const SFX_BUBBLE := 0xAD
const SFX_FIREBALL := 0xAE
const SFX_SHIELD := 0xAF
const SFX_SAW := 0xB0
const SFX_ELECTRIC := 0xB1
const SFX_DROWN_DEATH := 0xB2
const SFX_FLAMETHROWER := 0xB3
const SFX_BUMPER := 0xB4
const SFX_RING := 0xB5
const SFX_SPIKES_MOVE := 0xB6
const SFX_RUMBLE := 0xB7
const SFX_COLLAPSE := 0xB9
const SFX_SS_GLASS := 0xBA
const SFX_DOOR := 0xBB
const SFX_TELEPORT := 0xBC
const SFX_CHAIN_STOMP := 0xBD
const SFX_ROLL := 0xBE
const SFX_CONTINUE := 0xBF
const SFX_BASARAN := 0xC0
const SFX_BREAK_ITEM := 0xC1
const SFX_DROWN_WARNING := 0xC2
const SFX_GIANT_RING := 0xC3
const SFX_BOMB := 0xC4
const SFX_CASH := 0xC5
const SFX_RING_LOSS := 0xC6
const SFX_CHAIN_RISE := 0xC7
const SFX_BURNING := 0xC8
const SFX_HIDDEN_BONUS := 0xC9
const SFX_ENTER_SS := 0xCA
const SFX_WALL_SMASH := 0xCB
const SFX_SPRING := 0xCC
const SFX_SWITCH := 0xCD
const SFX_RING_LEFT := 0xCE
const SFX_SIGNPOST := 0xCF
const SFX_WATERFALL := 0xD0

class ChannelState:
	var song: Dictionary = {}
	var kind := "FM"
	var kind_code := 0
	var label := ""
	var hw_slot := ""
	var hw_bit := 0
	var is_sfx := false
	var pc := 0
	var active := true
	var duration := 1
	var saved_duration := 1
	var transpose := 0
	var volume := 0
	var voice_index := 0
	var psg_voice := 0
	var pan_left := 1.0
	var pan_right := 1.0
	var note := -1
	var frequency := 0.0
	var note_age := 0.0
	var note_on := false
	var no_attack_next := false
	var note_fill := 0
	var note_fill_counter := 0
	var tempo_div := 1
	var call_stack: Array = []
	var loops: Dictionary = {}
	var phase := [0.0, 0.0, 0.0, 0.0]
	var phase_step := [0.0, 0.0, 0.0, 0.0]
	var fm_render_step := [0.0, 0.0, 0.0, 0.0]
	var feedback_sample := 0.0
	var feedback_sample_2 := 0.0
	var fm_algorithm := 7
	var fm_feedback := 0.0
	var fm_feedback_scale := 0.0
	var fm_modulation_scale := FM_MUSIC_PHASE_MOD_TABLE_SCALE
	var fm_op_amp := [1.0, 1.0, 1.0, 1.0]
	var fm_render_amp := [0.0, 0.0, 0.0, 0.0]
	var fm_env_level := [0.0, 0.0, 0.0, 0.0]
	var fm_env_stage := [0, 0, 0, 0]
	var fm_attack_inc := [1.0, 1.0, 1.0, 1.0]
	var fm_decay1_mul := [1.0, 1.0, 1.0, 1.0]
	var fm_decay2_mul := [1.0, 1.0, 1.0, 1.0]
	var fm_sustain_amp := [1.0, 1.0, 1.0, 1.0]
	var fm_release_mul := [0.99, 0.99, 0.99, 0.99]
	var fm_detune_ratio := [1.0, 1.0, 1.0, 1.0]
	var fm_track_gain := 1.0
	var fm_tail_active := false
	var fm_cache_voice := -9999
	var fm_cache_volume := -9999
	var fm_cache_key_code := -9999
	var fm_key_code := 0
	var fm_source_word := 0
	var detune_raw := 0
	var fm_base_fnum := 1.0
	var psg_base_divisor := 1.0
	var mod_enabled := false
	var mod_wait := 0
	var mod_wait_master := 0
	var mod_speed := 1
	var mod_speed_master := 1
	var mod_delta := 0
	var mod_delta_master := 0
	var mod_steps := 0
	var mod_steps_master := 0
	var mod_value := 0
	var psg_env_pos := 0
	var psg_amp := 0.18
	var psg_step := 0.0
	var psg_render_step := 0.0
	var pitch_factor := 1.0
	var psg_noise := false
	var psg_noise_control := 0xE7
	var noise_lfsr := 1
	var noise_output_bit := 0
	var dac_sample := -1
	var dac_pos := 0.0

class SFXInstance:
	var sound_id := 0
	var tracks: Array = []
	var age := 0

class PCMSFXInstance:
	var sound_id := 0
	var hw_mask := 0
	var player: AudioStreamPlayer = null
	var is_special := false

var _database: Dictionary = {}
var _music_tracks: Array = []
var _sfx_instances: Array = []
var _pcm_sfx_instances: Array = []
var _pcm_sfx_cache: Dictionary = {}
var _pcm_sfx_players: Array = []
var _music_song: Dictionary = {}
var _music_tempo_mod := 1
var _music_tempo_counter := 1
var _music_driver_mode := "s1"
var _music_s2_tempo := 0
var _music_s2_accum := 0
var _sample_tick_accum := 0.0
var _fm_envelope_tick_accum := 0.0
var _current_music_id := -1
var _music_paused := false
var _speed_shoes_active := false
var _resume_music_id := -1
var _jingle_active := false
var _jingle_backup: Dictionary = {}
var _ring_pan_toggle := false
var _override_resume_music_id := -1
var _master_gain := 0.55
var _music_gain := 0.72
var _sfx_gain := 0.85
var _output_mode := OUTPUT_MODE_AUTHENTIC
var _waterfall_sfx_enabled := true

var _stream_player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _dac_buffers: Array = []
var _s2_ehz_dac_buffers: Dictionary = {}
var _sine_table := PackedFloat32Array()
var _sfx_override_mask := 0
var _regular_sfx_override_mask := 0
var _synth_lp_l := 0.0
var _synth_lp_r := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_database()
	_load_output_mode_setting()
	_waterfall_sfx_enabled = bool(ProjectSettings.get_setting("audio/sonic/waterfall_sfx_enabled", true))
	_build_sine_table()
	_load_dac_samples()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = MIX_RATE
	_generator.buffer_length = BUFFER_LENGTH
	_stream_player = AudioStreamPlayer.new()
	_stream_player.name = "SMPSNativeAudio"
	_stream_player.stream = _generator
	add_child(_stream_player)
	_stream_player.play()
	_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback
	for i in range(MAX_SFX_INSTANCES):
		var pcm_player := AudioStreamPlayer.new()
		pcm_player.name = "PCM_SFX_Player_%d" % i
		pcm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		pcm_player.volume_db = linear_to_db(PCM_SFX_OUTPUT_GAIN)
		add_child(pcm_player)
		_pcm_sfx_players.append(pcm_player)

func _build_sine_table() -> void:
	_sine_table.resize(SINE_TABLE_SIZE)
	for i in range(SINE_TABLE_SIZE):
		_sine_table[i] = sin(TWO_PI * float(i) / float(SINE_TABLE_SIZE))

func _process(_delta: float) -> void:
	_update_pcm_sfx_instances()
	if _playback == null:
		if _stream_player != null and _stream_player.playing:
			_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback
		return
	# Never try to refill the entire generator buffer in one rendered game frame.
	# If synthesis ever falls behind, Phase 52's unbounded catch-up loop could
	# spend several milliseconds generating thousands of samples and collapse
	# gameplay FPS exactly when an SFX added more channels. 1024 frames is still
	# almost three 60 Hz frames of audio at 22.05 kHz, so it has ample headroom.
	var available := mini(_playback.get_frames_available(), MAX_GENERATED_FRAMES_PER_PROCESS)
	while available > 0:
		var count := mini(available, 1024)
		var frames := PackedVector2Array()
		frames.resize(count)
		for i in range(count):
			_sample_tick_accum += DRIVER_HZ / MIX_RATE
			while _sample_tick_accum >= 1.0:
				_sample_tick_accum -= 1.0
				_tick_driver()
			_fm_envelope_tick_accum += FM_ENVELOPE_HZ / MIX_RATE
			while _fm_envelope_tick_accum >= 1.0:
				_fm_envelope_tick_accum -= 1.0
				_tick_fm_envelopes()
			var lr := Vector2.ZERO
			if not _music_paused:
				lr = _render_mix_sample()
			frames[i] = Vector2(clampf(lr.x * _master_gain, -1.0, 1.0), clampf(lr.y * _master_gain, -1.0, 1.0))
		_playback.push_buffer(frames)
		available -= count

func _load_output_mode_setting() -> void:
	var configured = String(ProjectSettings.get_setting("audio/sonic/output_mode", "authentic")).strip_edges().to_lower()
	_output_mode = OUTPUT_MODE_CLEAN if configured == "clean" else OUTPUT_MODE_AUTHENTIC

func set_output_mode(mode: int) -> void:
	var next_mode = OUTPUT_MODE_CLEAN if mode == OUTPUT_MODE_CLEAN else OUTPUT_MODE_AUTHENTIC
	if _output_mode == next_mode:
		return
	_output_mode = next_mode
	# Switching profiles is deliberately non-destructive: do not restart SMPS.
	_synth_lp_l = 0.0
	_synth_lp_r = 0.0

func set_output_mode_name(mode_name: String) -> void:
	set_output_mode(OUTPUT_MODE_CLEAN if mode_name.strip_edges().to_lower() == "clean" else OUTPUT_MODE_AUTHENTIC)

func toggle_output_mode() -> void:
	set_output_mode(OUTPUT_MODE_AUTHENTIC if _output_mode == OUTPUT_MODE_CLEAN else OUTPUT_MODE_CLEAN)

func output_mode() -> int:
	return _output_mode

func output_mode_name() -> String:
	return "Clean" if _output_mode == OUTPUT_MODE_CLEAN else "Authentic"

func waterfall_sfx_enabled() -> bool:
	return _waterfall_sfx_enabled

func set_waterfall_sfx_enabled(value: bool) -> void:
	_waterfall_sfx_enabled = value
	if not value:
		_stop_special_pcm_sfx(SFX_WATERFALL)

func play_music(sound_id: int, restart: bool = false, from_jingle: bool = false) -> void:
	if _jingle_active and not from_jingle:
		_jingle_active = false
		_jingle_backup = {}
		_resume_music_id = -1
	if sound_id == _current_music_id and not restart and not _music_tracks.is_empty():
		return
	var songs: Dictionary = _database.get("music", {})
	var key := str(sound_id)
	if not songs.has(key):
		return
	_music_song = songs[key]
	_current_music_id = sound_id
	_music_tracks.clear()
	if restart and not from_jingle:
		_reset_music_render_state()
	var header: Dictionary = _music_song.get("header", {})
	_music_driver_mode = String(header.get("driver_mode", "s1"))
	_music_tempo_mod = maxi(1, int(header.get("tempo_mod", 1)))
	if _music_driver_mode == "s2":
		_music_s2_tempo = int(header.get("speed_tempo", _music_tempo_mod)) if _speed_shoes_active else _music_tempo_mod
		_music_s2_tempo &= 0xFF
		# Retail S2 initializes both CurrentTempo and TempoTimeout from the header.
		_music_s2_accum = _music_s2_tempo
		_music_tempo_counter = 1
	else:
		if _speed_shoes_active and SPEED_SHOES_TEMPOS.has(sound_id):
			_music_tempo_mod = int(SPEED_SHOES_TEMPOS[sound_id])
		_music_tempo_counter = _music_tempo_mod
	for spec_value in header.get("channels", []):
		var spec: Dictionary = spec_value
		_music_tracks.append(_create_track(_music_song, spec, false))

func play_override_music(sound_id: int) -> void:
	if sound_id == _current_music_id:
		return
	_override_resume_music_id = _current_music_id
	play_music(sound_id, true)

func resume_override_music() -> void:
	if _override_resume_music_id < 0:
		return
	var resume := _override_resume_music_id
	_override_resume_music_id = -1
	play_music(resume, true)

func play_jingle(sound_id: int) -> void:
	if sound_id == _current_music_id or _jingle_active:
		return
	# Sound_PlayBGM backs up the complete music RAM before Mus88. Keeping the
	# ChannelState objects themselves reproduces that key behavior: the level
	# song resumes at the exact event position rather than restarting.
	_jingle_backup = {
		"tracks": _music_tracks.duplicate(),
		"song": _music_song,
		"music_id": _current_music_id,
		"tempo_mod": _music_tempo_mod,
		"tempo_counter": _music_tempo_counter,
		"driver_mode": _music_driver_mode,
		"s2_tempo": _music_s2_tempo,
		"s2_accum": _music_s2_accum
	}
	_resume_music_id = _current_music_id
	_jingle_active = true
	play_music(sound_id, true, true)

func play_ring_sfx() -> void:
	_ring_pan_toggle = not _ring_pan_toggle
	play_sfx(SFX_RING_LEFT if _ring_pan_toggle else SFX_RING)

func stop_music() -> void:
	_music_tracks.clear()
	_music_song = {}
	_current_music_id = -1
	_resume_music_id = -1
	_jingle_active = false
	_jingle_backup = {}
	_music_driver_mode = "s1"
	_music_s2_tempo = 0
	_music_s2_accum = 0
	_reset_music_render_state()

func current_music_id() -> int:
	return _current_music_id

func set_music_paused(value: bool) -> void:
	_music_paused = value
	for inst_value in _pcm_sfx_instances:
		var inst: PCMSFXInstance = inst_value
		if inst.player != null and is_instance_valid(inst.player):
			inst.player.stream_paused = value


func set_speed_shoes_active(value: bool) -> void:
	if _speed_shoes_active == value:
		return
	_speed_shoes_active = value
	if _current_music_id < 0 or _music_song.is_empty():
		return
	var header: Dictionary = _music_song.get("header", {})
	if _music_driver_mode == "s2":
		_music_s2_tempo = int(header.get("speed_tempo", header.get("tempo_mod", 1))) if value else int(header.get("tempo_mod", 1))
		_music_s2_tempo &= 0xFF
		# Change CurrentTempo only. S2 leaves TempoTimeout/accumulator running.
		return
	if value and SPEED_SHOES_TEMPOS.has(_current_music_id):
		_music_tempo_mod = int(SPEED_SHOES_TEMPOS[_current_music_id])
	else:
		_music_tempo_mod = maxi(1, int(header.get("tempo_mod", 1)))
	_music_tempo_counter = _music_tempo_mod

func play_sfx(sound_id: int) -> void:
	# $D0 is Sound_PlaySpecial in the retail driver, with lower priority than
	# ordinary FM4 SFX. Phase 54 uses a source-derived high-rate PCM render so
	# the MUL=15/feedback=7 voice cannot alias in the 22.05 kHz live synth.
	if sound_id == SFX_WATERFALL:
		_play_waterfall_special_pcm_sfx()
		return
	# Hotfix 8: use the user-supplied, pre-rendered Genesis SFX bank whenever
	# that retail ID is present. Streams are loaded on first use rather than
	# preloading all WAVs at startup.
	if _play_pcm_sfx(sound_id):
		return
	var songs: Dictionary = _database.get("sfx", {})
	var key := str(sound_id)
	if not songs.has(key):
		return
	var song: Dictionary = songs[key]
	var inst := SFXInstance.new()
	inst.sound_id = sound_id
	var header: Dictionary = song.get("header", {})
	var new_mask := 0
	for spec_value in header.get("channels", []):
		var track := _create_track(song, spec_value, true)
		inst.tracks.append(track)
		new_mask |= track.hw_bit
	if inst.tracks.is_empty():
		return
	_replace_sfx_slots(new_mask)
	_sfx_instances.append(inst)
	while _sfx_instances.size() > MAX_SFX_INSTANCES:
		_sfx_instances.pop_front()
	_rebuild_sfx_override_mask()

func _play_waterfall_special_pcm_sfx() -> void:
	# Sound_PlaySpecial ignores new starts while the 1-up jingle owns the driver.
	# Fade-in/out gates are not separately represented by this native driver.
	if not _waterfall_sfx_enabled or _jingle_active:
		return
	var stream = _load_pcm_sfx(SFX_WATERFALL)
	if stream == null:
		push_error("Phase 54 Waterfall PCM is missing; refusing to fall back to the aliased live $D0 renderer.")
		return
	_stop_special_pcm_sfx(SFX_WATERFALL)
	var player := _acquire_special_pcm_player()
	if player == null:
		# Special SFX are lower priority than ordinary SFX; never steal a normal
		# PCM player just to make the Waterfall audible.
		return
	var inst := PCMSFXInstance.new()
	inst.sound_id = SFX_WATERFALL
	inst.hw_mask = _sfx_hw_mask(SFX_WATERFALL)
	inst.player = player
	inst.is_special = true
	player.stream = stream
	player.stream_paused = _music_paused
	player.volume_db = linear_to_db(PCM_SFX_OUTPUT_GAIN)
	player.play()
	_pcm_sfx_instances.append(inst)
	_rebuild_sfx_override_mask()

func _stop_special_pcm_sfx(sound_id: int) -> void:
	var changed := false
	for i in range(_pcm_sfx_instances.size() - 1, -1, -1):
		var inst: PCMSFXInstance = _pcm_sfx_instances[i]
		if inst.is_special and inst.sound_id == sound_id:
			_stop_pcm_instance(inst)
			_pcm_sfx_instances.remove_at(i)
			changed = true
	if changed:
		_rebuild_sfx_override_mask()

func _acquire_special_pcm_player() -> AudioStreamPlayer:
	for player_value in _pcm_sfx_players:
		var player: AudioStreamPlayer = player_value
		if not player.playing:
			return player
	return null

func _pcm_sfx_path(sound_id: int) -> String:
	return "%s/S1_%02X.wav" % [PCM_SFX_DIR, sound_id & 0xFF]

func _load_pcm_sfx(sound_id: int):
	if _pcm_sfx_cache.has(sound_id):
		return _pcm_sfx_cache[sound_id]
	var path := _pcm_sfx_path(sound_id)
	if not ResourceLoader.exists(path):
		return null
	var stream = load(path)
	if stream is AudioStream:
		_pcm_sfx_cache[sound_id] = stream
		return stream
	return null

# Phase 133: selected retail Sonic 2 SFX supplied as Genesis captures.
# sample_id is the Z80 SoundXX number (for example $6E Mecha Sonic buzz), not
# the high-level SndID byte. Keep these separate from the S1 PCM cache/IDs.
func play_s2_pcm_sfx(sample_id: int) -> bool:
	var sid: int = sample_id & 0xFF
	var cache_key: int = 0x200 | sid
	var stream = null
	if _pcm_sfx_cache.has(cache_key):
		stream = _pcm_sfx_cache[cache_key]
	else:
		var path: String = "%s/S2_%02X.wav" % [PCM_SFX_DIR, sid]
		if not ResourceLoader.exists(path):
			return false
		stream = load(path)
		if stream is AudioStream:
			_pcm_sfx_cache[cache_key] = stream
		else:
			return false
	var player: AudioStreamPlayer = _acquire_pcm_player()
	if player == null:
		return false
	player.stream = stream
	player.stream_paused = _music_paused
	player.volume_db = linear_to_db(PCM_SFX_OUTPUT_GAIN)
	player.play()
	var inst := PCMSFXInstance.new()
	inst.sound_id = cache_key
	inst.hw_mask = 0
	inst.player = player
	_pcm_sfx_instances.append(inst)
	return true

func _sfx_hw_mask(sound_id: int) -> int:
	var songs: Dictionary = _database.get("sfx", {})
	var key := str(sound_id)
	if not songs.has(key):
		return 0
	var song: Dictionary = songs[key]
	var header: Dictionary = song.get("header", {})
	var mask := 0
	for spec_value in header.get("channels", []):
		var spec: Dictionary = spec_value
		var kind := String(spec.get("kind", "FM"))
		var label := String(spec.get("label", ""))
		var slot := _resolve_hw_slot(spec, kind, label)
		mask |= _hw_slot_bit(slot)
	return mask

func _play_pcm_sfx(sound_id: int) -> bool:
	var stream = _load_pcm_sfx(sound_id)
	if stream == null:
		return false
	var mask := _sfx_hw_mask(sound_id)
	_replace_sfx_slots(mask)
	var player: AudioStreamPlayer = _acquire_pcm_player()
	if player == null:
		return false
	player.stream = stream
	player.stream_paused = _music_paused
	player.volume_db = linear_to_db(PCM_SFX_OUTPUT_GAIN)
	player.play()
	var inst := PCMSFXInstance.new()
	inst.sound_id = sound_id
	inst.hw_mask = mask
	inst.player = player
	_pcm_sfx_instances.append(inst)
	_rebuild_sfx_override_mask()
	return true

func _acquire_pcm_player() -> AudioStreamPlayer:
	for player_value in _pcm_sfx_players:
		var player: AudioStreamPlayer = player_value
		if not player.playing:
			return player
	# Ordinary SFX are higher priority than other ordinary SFX, but the retail
	# special-FM4 Waterfall must keep sequencing underneath them. If the PCM
	# pool is saturated, recycle the oldest *ordinary* PCM instance and never
	# take the player's stream away from a special instance.
	for i in range(_pcm_sfx_instances.size()):
		var oldest: PCMSFXInstance = _pcm_sfx_instances[i]
		if oldest.is_special:
			continue
		var player: AudioStreamPlayer = oldest.player
		_stop_pcm_instance(oldest)
		_pcm_sfx_instances.remove_at(i)
		_rebuild_sfx_override_mask()
		return player
	return null

func _replace_sfx_slots(mask: int) -> void:
	if mask == 0:
		return
	for inst_value in _sfx_instances:
		var inst: SFXInstance = inst_value
		for track_value in inst.tracks:
			var track: ChannelState = track_value
			if track.active and (track.hw_bit & mask) != 0:
				track.active = false
	for i in range(_pcm_sfx_instances.size() - 1, -1, -1):
		var pcm: PCMSFXInstance = _pcm_sfx_instances[i]
		# Retail special SFX are lower priority than ordinary SFX. Keep the
		# Waterfall stream advancing; _refresh_special_pcm_mutes() silences it
		# while a normal FM4 SFX owns the hardware channel.
		if pcm.is_special:
			continue
		if (pcm.hw_mask & mask) != 0:
			_stop_pcm_instance(pcm)
			_pcm_sfx_instances.remove_at(i)

func _stop_pcm_instance(inst: PCMSFXInstance) -> void:
	if inst.player != null and is_instance_valid(inst.player):
		inst.player.stop()
		inst.player.stream = null
		inst.player.volume_db = linear_to_db(PCM_SFX_OUTPUT_GAIN)

func _update_pcm_sfx_instances() -> void:
	var changed := false
	for i in range(_pcm_sfx_instances.size() - 1, -1, -1):
		var inst: PCMSFXInstance = _pcm_sfx_instances[i]
		if inst.player == null or not is_instance_valid(inst.player) or not inst.player.playing:
			if inst.player != null and is_instance_valid(inst.player):
				inst.player.stream = null
			_pcm_sfx_instances.remove_at(i)
			changed = true
	if changed:
		_rebuild_sfx_override_mask()

func silence_all() -> void:
	stop_music()
	_sfx_instances.clear()
	for inst_value in _pcm_sfx_instances:
		_stop_pcm_instance(inst_value)
	_pcm_sfx_instances.clear()
	_sfx_override_mask = 0
	_regular_sfx_override_mask = 0

func _load_database() -> void:
	var file := FileAccess.open("res://data/s1/sound/smps_source.json", FileAccess.READ)
	if file == null:
		push_error("Phase 52 SMPS source table is missing")
		_database = {"music": {}, "sfx": {}, "psg_envelopes": []}
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_database = parsed
	else:
		push_error("Phase 52 SMPS source table failed to parse")
		_database = {"music": {}, "sfx": {}, "psg_envelopes": []}
		return
	# Phase 87 keeps retail S2 songs in a separate generated table, then merges
	# only their port-local music IDs into the established Sonic 1 database.
	var s2_path := "res://data/s1/sound/s2_ehz_smps.json"
	if FileAccess.file_exists(s2_path):
		var s2_file := FileAccess.open(s2_path, FileAccess.READ)
		var s2_parsed = JSON.parse_string(s2_file.get_as_text()) if s2_file != null else null
		if s2_parsed is Dictionary:
			var s2_database: Dictionary = s2_parsed
			var s2_music: Dictionary = s2_database.get("music", {})
			var music: Dictionary = _database.get("music", {})
			for s2_key in s2_music.keys():
				music[s2_key] = s2_music[s2_key]
			_database["music"] = music

func _load_dac_samples() -> void:
	_dac_buffers = [
		_load_pcm16("res://data/s1/sound/kick.pcm"),
		_load_pcm16("res://data/s1/sound/snare.pcm"),
		_load_pcm16("res://data/s1/sound/timpani.pcm")
	]
	_s2_ehz_dac_buffers = {
		0: _load_pcm16("res://data/s1/sound/s2_ehz_dac_00.pcm"),
		1: _load_pcm16("res://data/s1/sound/s2_ehz_dac_01.pcm"),
		2: _load_pcm16("res://data/s1/sound/s2_ehz_dac_02.pcm"),
		7: _load_pcm16("res://data/s1/sound/s2_ehz_dac_07.pcm"),
		8: _load_pcm16("res://data/s1/sound/s2_ehz_dac_08.pcm"),
		9: _load_pcm16("res://data/s1/sound/s2_ehz_dac_09.pcm"),
		10: _load_pcm16("res://data/s1/sound/s2_ehz_dac_10.pcm"),
		11: _load_pcm16("res://data/s1/sound/s2_ehz_dac_11.pcm"),
		12: _load_pcm16("res://data/s1/sound/s2_ehz_dac_12.pcm"),
		13: _load_pcm16("res://data/s1/sound/s2_ehz_dac_13.pcm"),
	}

func _load_pcm16(path: String) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var bytes := file.get_buffer(file.get_length())
	var samples := bytes.size() / 2
	result.resize(samples)
	for i in range(samples):
		result[i] = float(bytes.decode_s16(i * 2)) / 32768.0
	return result

func _create_track(song: Dictionary, spec_value, is_sfx: bool = false) -> ChannelState:
	var spec: Dictionary = spec_value
	var t := ChannelState.new()
	t.song = song
	t.is_sfx = is_sfx
	t.kind = String(spec.get("kind", "FM"))
	match t.kind:
		"PSG":
			t.kind_code = KIND_PSG
		"DAC":
			t.kind_code = KIND_DAC
		_:
			t.kind_code = KIND_FM
	t.label = String(spec.get("label", ""))
	t.hw_slot = _resolve_hw_slot(spec, t.kind, t.label)
	t.hw_bit = _hw_slot_bit(t.hw_slot)
	t.transpose = int(spec.get("transpose", 0))
	t.volume = int(spec.get("volume", 0))
	t.psg_voice = int(spec.get("psg_voice", 0))
	t.tempo_div = maxi(1, int(song.get("header", {}).get("tempo_div", 1)))
	var hw := String(spec.get("hw", ""))
	if hw.contains("Noise"):
		t.psg_noise = true
		t.psg_noise_control = 0xE7
		t.noise_lfsr = 1
		t.noise_output_bit = 0
	return t

func _resolve_hw_slot(spec: Dictionary, kind: String, label: String) -> String:
	var explicit := String(spec.get("hw", ""))
	if not explicit.is_empty():
		if explicit.begins_with("cFM"):
			return explicit.trim_prefix("c")
		if explicit.begins_with("cPSG"):
			return explicit.trim_prefix("c")
		if explicit.contains("Noise"):
			return "PSG3"
	if kind == "DAC":
		return "DAC"
	for slot in ["FM1", "FM2", "FM3", "FM4", "FM5", "PSG1", "PSG2", "PSG3"]:
		if label.ends_with("_" + slot):
			return slot
	return ""

func _hw_slot_bit(slot: String) -> int:
	match slot:
		"FM1": return 1 << 0
		"FM2": return 1 << 1
		"FM3": return 1 << 2
		"FM4": return 1 << 3
		"FM5": return 1 << 4
		"PSG1": return 1 << 5
		"PSG2": return 1 << 6
		"PSG3": return 1 << 7
		_: return 0

func _rebuild_sfx_override_mask() -> void:
	_sfx_override_mask = 0
	_regular_sfx_override_mask = 0
	for inst in _sfx_instances:
		for track in inst.tracks:
			if track.active:
				_sfx_override_mask |= track.hw_bit
				_regular_sfx_override_mask |= track.hw_bit
	for inst_value in _pcm_sfx_instances:
		var pcm: PCMSFXInstance = inst_value
		_sfx_override_mask |= pcm.hw_mask
		if not pcm.is_special:
			_regular_sfx_override_mask |= pcm.hw_mask
	_refresh_special_pcm_mutes()

func _refresh_special_pcm_mutes() -> void:
	for inst_value in _pcm_sfx_instances:
		var pcm: PCMSFXInstance = inst_value
		if not pcm.is_special or pcm.player == null or not is_instance_valid(pcm.player):
			continue
		var blocked := pcm.hw_mask != 0 and (_regular_sfx_override_mask & pcm.hw_mask) != 0
		pcm.player.volume_db = -80.0 if blocked else linear_to_db(PCM_SFX_OUTPUT_GAIN)

func _tick_driver() -> void:
	if _music_paused:
		return
	# Sonic 1's main tempo timer delays all music tracks by one UpdateMusic call
	# whenever it expires. SFX are updated independently and are not delayed.
	var hold_music := false
	if not _music_tracks.is_empty():
		if _music_driver_mode == "s2":
			# S2 TempoWait is an 8-bit accumulator. Tracks advance only when
			# CurrentTempo + TempoTimeout carries past $FF.
			var tempo_sum := _music_s2_accum + _music_s2_tempo
			_music_s2_accum = tempo_sum & 0xFF
			hold_music = tempo_sum <= 0xFF
		else:
			_music_tempo_counter -= 1
			if _music_tempo_counter <= 0:
				_music_tempo_counter = maxi(1, _music_tempo_mod)
				hold_music = true
	if not hold_music:
		for t in _music_tracks:
			_tick_track(t)
	if _jingle_active and not _music_tracks.is_empty():
		var music_alive := false
		for mt in _music_tracks:
			if mt.active:
				music_alive = true
				break
		if not music_alive:
			var resume := _resume_music_id
			_jingle_active = false
			_resume_music_id = -1
			if not _jingle_backup.is_empty():
				_music_tracks = _jingle_backup.get("tracks", [])
				_music_song = _jingle_backup.get("song", {})
				_current_music_id = int(_jingle_backup.get("music_id", resume))
				_music_tempo_mod = int(_jingle_backup.get("tempo_mod", 1))
				_music_tempo_counter = int(_jingle_backup.get("tempo_counter", _music_tempo_mod))
				_music_driver_mode = String(_jingle_backup.get("driver_mode", "s1"))
				_music_s2_tempo = int(_jingle_backup.get("s2_tempo", 0))
				_music_s2_accum = int(_jingle_backup.get("s2_accum", 0))
				_jingle_backup = {}
			elif resume >= 0:
				play_music(resume, true)
	for inst in _sfx_instances:
		inst.age += 1
		for t in inst.tracks:
			_tick_track(t)
	for i in range(_sfx_instances.size() - 1, -1, -1):
		var inst: SFXInstance = _sfx_instances[i]
		var any_active := false
		for t in inst.tracks:
			if t.active:
				any_active = true
				break
		if not any_active or inst.age > 1800:
			_sfx_instances.remove_at(i)
	_rebuild_sfx_override_mask()

func _tick_track(t: ChannelState) -> void:
	if not t.active:
		return
	# Match FMUpdateTrack/PSGUpdateTrack ordering: duration is decremented
	# first. If it expires, the driver processes the next timed event and does
	# NOT run note-fill, PSG envelope, or modulation for the old note on that
	# same 60 Hz update. Phase 52 previously advanced those one extra frame.
	t.duration -= 1
	if t.duration <= 0:
		_process_until_timed_event(t)
		return
	if t.note_fill_counter > 0:
		t.note_fill_counter -= 1
		if t.note_fill_counter <= 0:
			if t.kind == "FM":
				_begin_fm_release(t)
			else:
				t.note_on = false
	if t.kind == "PSG" and t.note_on:
		t.psg_env_pos += 1
		_refresh_psg_amp(t)
	if t.mod_enabled:
		_advance_modulation(t)
	_refresh_pitch_factor(t)

func _process_until_timed_event(t: ChannelState) -> void:
	var guard := 0
	while t.active and guard < 2048:
		guard += 1
		var inst = _next_instruction(t)
		if inst == null:
			t.active = false
			return
		if not (inst is Array) or inst.is_empty():
			continue
		var op := String(inst[0])
		match op:
			"note":
				var n := int(inst[1])
				var next = _peek_instruction(t)
				if next is Array and not next.is_empty() and String(next[0]) == "duration":
					_next_instruction(t)
					t.saved_duration = maxi(1, int(next[1]) * t.tempo_div)
				_start_note(t, n, t.no_attack_next)
				t.no_attack_next = false
				t.duration = t.saved_duration
				return
			"dac":
				var d := int(inst[1])
				var next = _peek_instruction(t)
				if next is Array and not next.is_empty() and String(next[0]) == "duration":
					_next_instruction(t)
					t.saved_duration = maxi(1, int(next[1]) * t.tempo_div)
				_start_dac(t, d)
				t.duration = t.saved_duration
				return
			"duration":
				t.saved_duration = maxi(1, int(inst[1]) * t.tempo_div)
				# A bare duration in SMPS retriggers the current FM/PSG note or
				# repeats the current DAC sample.
				if t.kind == "DAC" and t.dac_sample >= 0:
					_start_dac(t, t.dac_sample)
				elif t.note >= 0:
					_start_note(t, t.note, t.no_attack_next)
				t.no_attack_next = false
				t.duration = t.saved_duration
				return
			"no_attack":
				t.no_attack_next = true
			"set_voice":
				t.voice_index = int(inst[1])
				t.fm_cache_voice = -9999
				_refresh_fm_cache(t)
			"psg_voice":
				t.psg_voice = int(inst[1])
				t.psg_env_pos = 0
				_refresh_psg_amp(t)
			"psg_form":
				t.psg_noise = true
				t.psg_noise_control = int(inst[1]) if inst.size() > 1 else 0xE7
				# A write to the SN76489 noise register resets its shift register.
				# Sonic 1 uses $E7: white noise clocked from PSG tone channel 3.
				t.noise_lfsr = 1
				t.noise_output_bit = 0
			"pan":
				_set_pan(t, String(inst[1]))
			"alter_vol":
				t.volume += int(inst[1])
				t.fm_cache_volume = -9999
				_refresh_fm_cache(t)
				_refresh_psg_amp(t)
			"alter_pitch":
				t.transpose += int(inst[1])
			"alter_note":
				# cfDetune/cfAlterNotes stores the byte; it is not cumulative.
				# This matters in GHZ and several later tracks which use $00 to
				# explicitly clear a prior detune value.
				t.detune_raw = int(inst[1])
				_refresh_pitch_factor(t)
			"note_fill":
				t.note_fill = maxi(0, int(inst[1]) * t.tempo_div)
			"mod_set":
				t.mod_enabled = true
				t.mod_wait_master = maxi(0, int(inst[1])) if inst.size() > 1 else 0
				t.mod_speed_master = maxi(1, int(inst[2])) if inst.size() > 2 else 1
				t.mod_delta_master = _signed_byte(int(inst[3])) if inst.size() > 3 else 0
				t.mod_steps_master = maxi(1, int(inst[4]) >> 1) if inst.size() > 4 else 1
				_reset_modulation_for_attack(t)
				_refresh_pitch_factor(t)
			"mod_off":
				t.mod_enabled = false
				t.mod_value = 0
				_refresh_pitch_factor(t)
			"tempo_mod":
				if _music_driver_mode == "s2":
					_music_s2_tempo = int(inst[1]) & 0xFF
				else:
					_music_tempo_mod = maxi(1, int(inst[1]))
					_music_tempo_counter = _music_tempo_mod
			"tempo_div":
				t.tempo_div = maxi(1, int(inst[1]))
			"tempo_div_all":
				var div := maxi(1, int(inst[1]))
				for mt in _music_tracks:
					mt.tempo_div = div
			"call":
				if inst.size() > 1:
					t.call_stack.append([t.label, t.pc])
					t.label = String(inst[1])
					t.pc = 0
			"return":
				if t.call_stack.is_empty():
					t.active = false
				else:
					var ret: Array = t.call_stack.pop_back()
					t.label = String(ret[0])
					t.pc = int(ret[1])
			"jump":
				if inst.size() > 1:
					t.label = String(inst[1])
					t.pc = 0
			"loop":
				_handle_loop(t, inst)
			"stop":
				t.active = false
				t.note_on = false
				return
			"fade":
				# The full driver fades TL/PSG attenuation over many frames. The
				# first source-driven audio phase keeps playback active; screen/game
				# mode transitions issue explicit music changes.
				pass
			_:
				pass
	if guard >= 2048:
		push_warning("SMPS command guard tripped in %s" % String(t.song.get("name", "song")))
		t.active = false

func _signed_byte(value: int) -> int:
	var b := value & 0xFF
	return b - 0x100 if b >= 0x80 else b

func _handle_loop(t: ChannelState, inst: Array) -> void:
	if inst.size() < 4:
		return
	var slot := str(int(inst[1]))
	var count := maxi(1, int(inst[2]))
	var target := String(inst[3])
	if not t.loops.has(slot):
		t.loops[slot] = count
	var left := int(t.loops[slot]) - 1
	if left > 0:
		t.loops[slot] = left
		t.label = target
		t.pc = 0
	else:
		t.loops.erase(slot)

func _next_instruction(t: ChannelState):
	var labels: Dictionary = t.song.get("labels", {})
	var guard := 0
	while guard < 32:
		guard += 1
		if not labels.has(t.label):
			return null
		var seq: Array = labels[t.label]
		if t.pc < seq.size():
			var result = seq[t.pc]
			t.pc += 1
			return result
		var falls: Dictionary = t.song.get("fallthrough", {})
		if not falls.has(t.label):
			return null
		t.label = String(falls[t.label])
		t.pc = 0
	return null

func _peek_instruction(t: ChannelState):
	var save_label := t.label
	var save_pc := t.pc
	var result = _next_instruction(t)
	t.label = save_label
	t.pc = save_pc
	return result

func _start_note(t: ChannelState, note_value: int, no_attack: bool) -> void:
	t.note = note_value
	if note_value < 0:
		if t.kind == "FM":
			_begin_fm_release(t)
		else:
			t.note_on = false
			t.frequency = 0.0
		return
	var semitone := float(note_value + t.transpose)
	# Keep the now-correct SFX path untouched, but music FM notes use the exact
	# discrete S1 FMFrequencies table geometry (B..A# rows plus $800 blocks).
	# This also provides the YM key code used by per-operator rate scaling.
	if t.kind == "FM" and not t.is_sfx:
		var fm_info := _source_fm_note_info(note_value + t.transpose)
		t.fm_source_word = int(fm_info[0])
		t.fm_key_code = int(fm_info[1])
		t.frequency = float(fm_info[2])
	elif t.kind == "PSG":
		var psg_info = _source_psg_note_info(note_value + t.transpose)
		t.psg_base_divisor = float(psg_info[0])
		t.frequency = float(psg_info[1])
	else:
		t.frequency = 16.351597831287414 * pow(2.0, semitone / 12.0)
		if t.kind == "FM":
			t.fm_key_code = 0
	if not no_attack:
		t.note_age = 0.0
		t.psg_env_pos = 0
		t.feedback_sample = 0.0
		t.feedback_sample_2 = 0.0
		t.fm_tail_active = false
		for i in range(4):
			t.phase[i] = 0.0
			t.fm_env_level[i] = 0.0
			t.fm_env_stage[i] = 0
		if t.mod_enabled:
			_reset_modulation_for_attack(t)
		if t.note_fill > 0:
			t.note_fill_counter = t.note_fill
		else:
			t.note_fill_counter = 0
		t.note_on = true
	else:
		# smpsNoAttack skips FM key-off and FinishTrackUpdate's note-fill /
		# modulation resets. The frequency may change, but the live envelope,
		# PSG volume-envelope index and modulation accumulator continue.
		t.note_on = true
	_refresh_frequency_cache(t)
	_refresh_fm_cache(t)
	_refresh_pitch_factor(t)
	_refresh_psg_amp(t)
	if t.kind == "FM" and not no_attack:
		_step_fm_envelopes(t)

func _begin_fm_release(t: ChannelState) -> void:
	if t.kind != "FM":
		t.note_on = false
		return
	var had_level := false
	for i in range(4):
		if float(t.fm_env_level[i]) > 0.00001:
			t.fm_env_stage[i] = 3
			had_level = true
	t.note_on = false
	t.fm_tail_active = had_level

func _start_dac(t: ChannelState, sample_id: int) -> void:
	t.dac_sample = sample_id
	t.dac_pos = 0.0
	t.note_on = sample_id >= 0

func _set_pan(t: ChannelState, pan: String) -> void:
	match pan:
		"left":
			t.pan_left = 1.0
			t.pan_right = 0.0
		"right":
			t.pan_left = 0.0
			t.pan_right = 1.0
		_:
			t.pan_left = 1.0
			t.pan_right = 1.0

func _render_mix_sample() -> Vector2:
	var synth_mix := Vector2.ZERO
	var dac_mix := Vector2.ZERO
	# Hotfix 9 flattens the render dispatch into this hot loop. Earlier builds
	# called _render_track() for every active channel on every 22.05 kHz sample,
	# repeatedly performing String kind comparisons and creating an intermediate
	# Vector2. Track kind is now cached as an integer at construction.
	for t in _music_tracks:
		if not t.active:
			continue
		if t.kind_code != KIND_DAC and t.hw_bit != 0 and (_sfx_override_mask & t.hw_bit) != 0:
			continue
		if t.kind_code == KIND_DAC:
			dac_mix += _render_dac(t) * _music_gain
			continue
		if t.frequency <= 0.0:
			continue
		if t.kind_code == KIND_FM:
			if not t.note_on and not t.fm_tail_active:
				continue
			var fm_mono: float = _render_fm(t) * _music_gain
			synth_mix.x += fm_mono * t.pan_left
			synth_mix.y += fm_mono * t.pan_right
		else:
			if not t.note_on:
				continue
			var psg_mono: float = _render_psg(t) * _music_gain
			synth_mix.x += psg_mono * t.pan_left
			synth_mix.y += psg_mono * t.pan_right

	# The PCM bank now handles $A0-$D0 outside this generator. This loop remains
	# available for any future/debug source-synth fallback without changing music.
	for inst in _sfx_instances:
		for t in inst.tracks:
			if not t.active or t.frequency <= 0.0:
				continue
			if t.kind_code == KIND_FM:
				if not t.note_on and not t.fm_tail_active:
					continue
				var fm_sfx: float = _render_fm(t) * _sfx_gain
				synth_mix.x += fm_sfx * t.pan_left
				synth_mix.y += fm_sfx * t.pan_right
			elif t.kind_code == KIND_PSG:
				if not t.note_on:
					continue
				var psg_sfx: float = _render_psg(t) * _sfx_gain
				synth_mix.x += psg_sfx * t.pan_left
				synth_mix.y += psg_sfx * t.pan_right

	# The modes share identical source sequencing and instrument state. Authentic
	# retains Hotfix 10's darker filter/compression profile; Clean raises the
	# cutoff and reduces presentation saturation for a clearer digital output.
	var lp_alpha = AUTHENTIC_SYNTH_LOWPASS_ALPHA if _output_mode == OUTPUT_MODE_AUTHENTIC else CLEAN_SYNTH_LOWPASS_ALPHA
	var saturation = AUTHENTIC_OUTPUT_SATURATION if _output_mode == OUTPUT_MODE_AUTHENTIC else CLEAN_OUTPUT_SATURATION
	_synth_lp_l += (synth_mix.x - _synth_lp_l) * lp_alpha
	_synth_lp_r += (synth_mix.y - _synth_lp_r) * lp_alpha
	var mix := Vector2(_synth_lp_l, _synth_lp_r) + dac_mix
	mix.x = mix.x / (1.0 + absf(mix.x) * saturation)
	mix.y = mix.y / (1.0 + absf(mix.y) * saturation)
	return mix

func _source_fm_note_info(note_index: int) -> Array:
	# S1 FMFrequencies is indexed one entry before nC0: each 12-entry row is
	# B, C, C#, ... A#. Normal nC0 therefore uses table index 1.
	var table_index := note_index + 1
	var block := clampi(floori(float(table_index) / 12.0), 0, 7)
	var slot := posmod(table_index, 12)
	var base_hz := float(FM_SOURCE_BASE_FREQUENCIES[slot])
	var fnum := clampi(roundi(base_hz * FM_SOURCE_FNUM_SCALE), 1, 0x7FF)
	var word := fnum | (block << 11)
	var key_code := word >> 9
	var actual_hz := (float(fnum) / FM_SOURCE_FNUM_SCALE) * pow(2.0, float(block))
	return [word, key_code, actual_hz]

func _source_psg_note_info(note_index: int) -> Array:
	# PSGSetFreq masks the note index to 7 bits. Retail Sonic 1 authored notes
	# stay within the stored table; the fallback only protects debug transposes.
	var index = note_index & 0x7F
	var divisor = 1
	if index < PSG_SOURCE_DIVISORS.size():
		divisor = int(PSG_SOURCE_DIVISORS[index])
	else:
		var fallback_hz = 130.98 * pow(2.0, float(index) / 12.0)
		divisor = clampi(int(round(PSG_SAMPLE_RATE / maxf(1.0, fallback_hz * 2.0))), 1, 0x3FF)
	var actual_hz = PSG_SAMPLE_RATE / (float(divisor) * 2.0)
	return [divisor, actual_hz]

func _ym_effective_rate(raw_rate: int, rate_scale: int, key_code: int, is_release: bool) -> int:
	var source_rate := ((raw_rate << 1) | 1) if is_release else raw_rate
	if source_rate <= 0:
		return 0
	var shift := 3 - clampi(rate_scale, 0, 3)
	return mini(0x3F, source_rate * 2 + (key_code >> shift))

func _ym_rate_average_attenuation_delta(rate: int) -> float:
	if rate <= 1:
		return 0.0
	if rate <= 5:
		return 0.5
	if rate <= 7:
		return 0.75
	if rate < 48:
		match rate & 3:
			0: return 0.5
			1: return 0.625
			2: return 0.75
			_: return 0.875
	if rate < 52:
		return 1.0 + 0.25 * float(rate - 48)
	if rate < 56:
		return 2.0 + 0.5 * float(rate - 52)
	if rate < 60:
		return 4.0 + float(rate - 56)
	return 8.0

func _ym_attenuation_units_per_second(rate: int) -> float:
	if rate <= 1:
		return 0.0
	var gate_shift := maxi(0, 11 - (rate >> 2))
	var event_rate := FM_SOURCE_SAMPLE_RATE / 3.0 / pow(2.0, float(gate_shift))
	return event_rate * _ym_rate_average_attenuation_delta(rate)

func _ym_attenuation_mul(rate: int) -> float:
	var units_per_second := _ym_attenuation_units_per_second(rate)
	if units_per_second <= 0.0:
		return 1.0
	# One YM envelope attenuation unit is 1/64 of a binary amplitude octave.
	var units_per_tick := units_per_second / FM_ENVELOPE_HZ
	return pow(2.0, -units_per_tick / 64.0)

func _ym_attack_seconds(rate: int) -> float:
	if rate <= 0:
		return 9999.0
	# Source-shaped approximation of the YM attack-rate curve. At the high
	# rates used by most S1 music voices this resolves to an immediate 240 Hz
	# attack, while lower rates retain their much slower exponential onset.
	return maxf(1.0 / FM_ENVELOPE_HZ, 20.67 * pow(2.0, -0.25067 * float(rate)))

func _music_voice_source_index(hw_operator: int) -> int:
	return int(SMPS_MUSIC_OPERATOR_MAP[clampi(hw_operator, 0, 3)])

func _fm_operator_is_carrier(algorithm: int, hw_operator: int) -> bool:
	match algorithm:
		0, 1, 2, 3:
			return hw_operator == 3
		4:
			return hw_operator == 1 or hw_operator == 3
		5, 6:
			return hw_operator == 1 or hw_operator == 2 or hw_operator == 3
		_:
			return true

func _reset_music_render_state() -> void:
	# InitMusicPlayback clears the music-driver RAM before loading a new BGM.
	# Our software renderer also owns state that does not exist in that RAM
	# (resampler phase, bounded envelope-clock phase, and the output filter).
	# Reset it on an explicit music restart so a level always begins from the
	# same audible state regardless of the previously loaded zone.
	_sample_tick_accum = 0.0
	_fm_envelope_tick_accum = 0.0
	_synth_lp_l = 0.0
	_synth_lp_r = 0.0

func _refresh_fm_cache(t: ChannelState) -> void:
	if t.kind != "FM":
		return
	if t.fm_cache_voice == t.voice_index and t.fm_cache_volume == t.volume and t.fm_cache_key_code == t.fm_key_code:
		return
	var voices: Array = t.song.get("voices", [])
	var voice: Dictionary = voices[clampi(t.voice_index, 0, voices.size() - 1)] if not voices.is_empty() else {}
	var tls: Array = voice.get("total_level", [24, 24, 24, 24])
	var attacks: Array = voice.get("attack", [31, 31, 31, 31])
	var rate_scales: Array = voice.get("rate_scale", [0, 0, 0, 0])
	var decay1: Array = voice.get("decay1", [4, 4, 4, 4])
	var decay2: Array = voice.get("decay2", [0, 0, 0, 0])
	var levels: Array = voice.get("decay_level", [15, 15, 15, 15])
	var releases: Array = voice.get("release", [15, 15, 15, 15])
	t.fm_algorithm = int(voice.get("algorithm", 7))
	t.fm_feedback = float(int(voice.get("feedback", 0)))
	t.fm_modulation_scale = FM_OPERATOR_MOD_RADIANS * RAD_TO_PHASE if t.is_sfx else FM_MUSIC_PHASE_MOD_TABLE_SCALE
	var feedback_index := int(t.fm_feedback)
	t.fm_feedback_scale = 0.0
	if feedback_index > 0:
		if t.is_sfx:
			# Preserve the Hotfix 5 live-SFX approximation for the $D0 fallback.
			t.fm_feedback_scale = 0.08 * pow(2.0, float(feedback_index - 1)) / FM_OPERATOR_MOD_RADIANS
		else:
			# YM feedback takes the previous two OP1 14-bit samples, shifts by
			# (9-feedback), and the operator halves phase modulation. With our
			# normalized operator output and 2048-step full-wave table, this is
			# equivalent to average_sample * 2^(5+feedback) table steps.
			t.fm_feedback_scale = pow(2.0, float(feedback_index - 8))
	for i in range(4):
		# The compiled voice arrays retain smpsVc* macro order. S1's 68k voice
		# writer emits op4/op3/op2/op1 into the YM operator registers, so music
		# must reverse the source array when feeding the hardware algorithm.
		# Preserve Hotfix 5's FM-SFX path exactly for now.
		var source_i := _music_voice_source_index(i) if not t.is_sfx else i
		var tl := float(int(tls[source_i])) if source_i < tls.size() else 24.0
		# The S1 driver adds track Volume only to carrier TL registers. Applying
		# it as a post-synthesis gain (Hotfixes 1-6) changed the modulation index
		# and therefore the instrument timbre.
		if not t.is_sfx and _fm_operator_is_carrier(t.fm_algorithm, i):
			tl = clampf(tl + maxf(0.0, float(t.volume)), 0.0, 127.0)
		t.fm_op_amp[i] = pow(10.0, -(tl * 0.75) / 20.0)
		t.fm_render_amp[i] = float(t.fm_op_amp[i]) * float(t.fm_env_level[i])
		var ar := int(attacks[source_i]) if source_i < attacks.size() else 31
		var rs := int(rate_scales[source_i]) if source_i < rate_scales.size() else 0
		var d1 := int(decay1[source_i]) if source_i < decay1.size() else 4
		var d2 := int(decay2[source_i]) if source_i < decay2.size() else 0
		var sl := int(levels[source_i]) if source_i < levels.size() else 15
		var rr := int(releases[source_i]) if source_i < releases.size() else 15
		var sustain_att := 0x3E0 if sl >= 15 else sl * 0x20
		t.fm_sustain_amp[i] = pow(2.0, -float(sustain_att) / 64.0)
		if not t.is_sfx:
			# YM2612 rates are key-scaled per operator. Hotfix 5 ignored RS, and
			# its linear D2/RR timing made many music voices lose body too soon.
			var eff_ar := _ym_effective_rate(ar, rs, t.fm_key_code, false)
			var eff_d1 := _ym_effective_rate(d1, rs, t.fm_key_code, false)
			var eff_d2 := _ym_effective_rate(d2, rs, t.fm_key_code, false)
			var eff_rr := _ym_effective_rate(rr, rs, t.fm_key_code, true)
			var attack_seconds := _ym_attack_seconds(eff_ar)
			t.fm_attack_inc[i] = 0.0 if eff_ar <= 0 else 1.0 / maxf(1.0, attack_seconds * FM_ENVELOPE_HZ)
			t.fm_decay1_mul[i] = _ym_attenuation_mul(eff_d1)
			t.fm_decay2_mul[i] = _ym_attenuation_mul(eff_d2)
			t.fm_release_mul[i] = _ym_attenuation_mul(eff_rr)
		else:
			# Preserve Hotfix 5 SFX envelopes verbatim; Jump/Skid are now known-good.
			var attack_seconds := lerpf(2.0, 0.0025, clampf(float(ar) / 31.0, 0.0, 1.0))
			t.fm_attack_inc[i] = 1.0 / maxf(1.0, attack_seconds * FM_ENVELOPE_HZ)
			if d1 <= 0:
				t.fm_decay1_mul[i] = 1.0
			else:
				var d1_seconds := lerpf(7.0, 0.020, clampf(float(d1) / 31.0, 0.0, 1.0))
				t.fm_decay1_mul[i] = exp(log(0.001) / maxf(1.0, d1_seconds * FM_ENVELOPE_HZ))
			if d2 <= 0:
				t.fm_decay2_mul[i] = 1.0
			else:
				var d2_seconds := lerpf(14.0, 0.050, clampf(float(d2) / 31.0, 0.0, 1.0))
				t.fm_decay2_mul[i] = exp(log(0.001) / maxf(1.0, d2_seconds * FM_ENVELOPE_HZ))
			var release_seconds := lerpf(3.0, 0.025, clampf(float(rr) / 15.0, 0.0, 1.0))
			t.fm_release_mul[i] = exp(log(0.001) / maxf(1.0, release_seconds * FM_ENVELOPE_HZ))
	# Music track attenuation is already applied to carrier TL above, exactly
	# where the S1 driver applies it. Keep the old post-voice gain only for the
	# deliberately frozen Hotfix 5 SFX branch.
	t.fm_track_gain = pow(10.0, -(float(t.volume) * 0.75) / 20.0) if t.is_sfx else 1.0
	t.fm_cache_voice = t.voice_index
	t.fm_cache_volume = t.volume
	t.fm_cache_key_code = t.fm_key_code
	_refresh_frequency_cache(t)

func _refresh_frequency_cache(t: ChannelState) -> void:
	if t.frequency <= 0.0:
		t.psg_step = 0.0
		t.fm_base_fnum = 1.0
		t.psg_base_divisor = 1.0
		return
	t.psg_step = t.frequency / MIX_RATE
	# PSG notes already entered through Sonic 1's exact stored divisor table.
	# Keep that integer period so signed detune/modulation operates in the same
	# domain as PSGUpdateFreq instead of re-quantizing an equal-tempered pitch.
	if t.kind == "PSG":
		t.psg_base_divisor = clampf(t.psg_base_divisor, 1.0, 1023.0)
		return
	if t.kind != "FM":
		return
	var voices: Array = t.song.get("voices", [])
	var voice: Dictionary = voices[clampi(t.voice_index, 0, voices.size() - 1)] if not voices.is_empty() else {}
	var muls: Array = voice.get("mul", [1, 1, 1, 1])
	var detunes: Array = voice.get("detune", [0, 0, 0, 0])
	if not t.is_sfx:
		var word := t.fm_source_word
		if word == 0 and t.note >= 0:
			var info := _source_fm_note_info(t.note + t.transpose)
			word = int(info[0])
			t.fm_source_word = word
			t.fm_key_code = int(info[1])
		var block := (word >> 11) & 7
		var fnum := word & 0x7FF
		t.fm_base_fnum = maxf(1.0, float(fnum))
		for i in range(4):
			var source_i := _music_voice_source_index(i)
			var mul_raw := int(muls[source_i]) if source_i < muls.size() else 1
			var mul_factor := 0.5 if mul_raw == 0 else float(mul_raw)
			var dt := (int(detunes[source_i]) & 7) if source_i < detunes.size() else 0
			var detune_units := _ym_detune_units(block, fnum, dt)
			# YM phase detune is added before the frequency multiplier. Its base
			# phase-step domain uses F-number * 2^(block-1); Hotfix 6/9 used
			# 2^block here and therefore made authored DT roughly half-strength.
			var base_internal := maxf(0.5, float(fnum) * pow(2.0, float(block - 1)))
			var detuned_internal := base_internal + detune_units
			var ratio := maxf(0.01, detuned_internal / base_internal)
			t.fm_detune_ratio[i] = ratio
			t.phase_step[i] = float(SINE_TABLE_SIZE) * t.frequency * mul_factor * ratio / MIX_RATE
	else:
		# Preserve the already-tested Hotfix 5 FM-SFX tuning.
		var semitone_index = posmod(t.note + t.transpose, 12)
		var base_hz = 16.351597831287414 * pow(2.0, float(semitone_index) / 12.0)
		t.fm_base_fnum = maxf(1.0, round(base_hz * 2097152.0 / 53267.04))
		var detune_cents_table := [0.0, 2.8, 5.6, 8.4, 0.0, -2.8, -5.6, -8.4]
		for i in range(4):
			var mul := float(int(muls[i])) if i < muls.size() else 1.0
			if mul <= 0.0:
				mul = 0.5
			var dt := (int(detunes[i]) & 7) if i < detunes.size() else 0
			var ratio := pow(2.0, float(detune_cents_table[dt]) / 1200.0)
			t.fm_detune_ratio[i] = ratio
			t.phase_step[i] = float(SINE_TABLE_SIZE) * t.frequency * mul * ratio / MIX_RATE

func _ym_detune_units(block: int, fnum: int, detune: int) -> float:
	# ClownMDEmu's YM2612 core uses this hardware detune lookup indexed by
	# block, a key-code class derived from F-number, and DT magnitude.
	var key_class := int(YM_KEY_CODE_CLASS[clampi(fnum >> 7, 0, 15)])
	var magnitude := float(YM_DETUNE_LOOKUP[clampi(block, 0, 7)][key_class][detune & 3])
	return -magnitude if (detune & 4) != 0 else magnitude

func _step_fm_operator_envelope(t: ChannelState, op_index: int) -> float:
	var level := float(t.fm_env_level[op_index])
	var stage := int(t.fm_env_stage[op_index])
	match stage:
		0:
			level += float(t.fm_attack_inc[op_index])
			if level >= 1.0:
				level = 1.0
				stage = 1
		1:
			level *= float(t.fm_decay1_mul[op_index])
			if level <= float(t.fm_sustain_amp[op_index]):
				level = float(t.fm_sustain_amp[op_index])
				stage = 2
		2:
			level *= float(t.fm_decay2_mul[op_index])
			if level < 0.00001:
				level = 0.0
				stage = 4
		3:
			level *= float(t.fm_release_mul[op_index])
			if level < 0.00001:
				level = 0.0
				stage = 4
		_:
			level = 0.0
	t.fm_env_level[op_index] = level
	t.fm_env_stage[op_index] = stage
	return level

func _step_fm_envelopes(t: ChannelState) -> void:
	var any_tail := false
	for i in range(4):
		_step_fm_operator_envelope(t, i)
		t.fm_render_amp[i] = float(t.fm_op_amp[i]) * float(t.fm_env_level[i])
		if int(t.fm_env_stage[i]) != 4:
			any_tail = true
	if not t.note_on:
		t.fm_tail_active = any_tail

func _tick_fm_envelopes() -> void:
	if _music_paused:
		return
	# Keep envelope work bounded to a small fixed-rate clock instead of the
	# 22.05 kHz output loop. Phase 53 uses 960 Hz so YM envelope transitions are
	# four times finer than Hotfix 10 while still avoiding the per-sample envelope
	# state-machine work that caused the early Phase 52 slowdown. Muted BGM hardware slots remain frozen while an SFX
	# owns the channel, matching the existing takeover renderer semantics.
	for t in _music_tracks:
		if not t.active or t.kind != "FM":
			continue
		if t.hw_bit != 0 and (_sfx_override_mask & t.hw_bit) != 0:
			continue
		if t.note_on or t.fm_tail_active:
			_step_fm_envelopes(t)
	for inst in _sfx_instances:
		for t in inst.tracks:
			if t.active and t.kind == "FM" and (t.note_on or t.fm_tail_active):
				_step_fm_envelopes(t)

func _reset_modulation_for_attack(t: ChannelState) -> void:
	t.mod_wait = t.mod_wait_master
	t.mod_speed = t.mod_speed_master
	t.mod_delta = t.mod_delta_master
	t.mod_steps = t.mod_steps_master
	t.mod_value = 0

func _advance_modulation(t: ChannelState) -> void:
	# Direct translation of Sonic 1 DoModulation: delay first, then count the
	# speed byte, accumulate signed frequency deltas for half the configured
	# steps, restore the step count and negate the delta, and repeat.
	if not t.mod_enabled:
		return
	if t.mod_wait > 0:
		t.mod_wait -= 1
		return
	t.mod_speed -= 1
	if t.mod_speed > 0:
		return
	t.mod_speed = maxi(1, t.mod_speed_master)
	if t.mod_steps <= 0:
		t.mod_steps = maxi(1, t.mod_steps_master)
		t.mod_delta = -t.mod_delta
		return
	t.mod_steps -= 1
	t.mod_value += t.mod_delta

func _refresh_pitch_factor(t: ChannelState) -> void:
	if t.frequency <= 0.0:
		t.pitch_factor = 1.0
		_refresh_render_step_cache(t)
		return
	var raw_delta = t.detune_raw + (t.mod_value if t.mod_enabled else 0)
	if t.kind == "PSG":
		# PSG stores a period/divisor: larger values LOWER pitch. This is the
		# inverse of FM F-number behavior and is why Jump's $F8 (-8) delta must
		# raise, not lower, the pitch.
		var divisor = clampf(t.psg_base_divisor + float(raw_delta), 1.0, 1023.0)
		t.pitch_factor = t.psg_base_divisor / divisor
	elif not t.is_sfx:
		# FMUpdateFreq adds the signed detune/modulation value to the complete
		# packed YM frequency word, not just its low 11-bit F-number. Preserve
		# that word arithmetic so a carry/borrow correctly crosses block edges.
		var base_word := t.fm_source_word & 0x3FFF
		var current_word := (base_word + int(raw_delta)) & 0x3FFF
		var base_block := (base_word >> 11) & 7
		var current_block := (current_word >> 11) & 7
		var base_fnum := base_word & 0x7FF
		var current_fnum := current_word & 0x7FF
		var base_linear := maxf(1.0, float(base_fnum * (1 << base_block)))
		var current_linear := maxf(1.0, float(current_fnum * (1 << current_block)))
		t.pitch_factor = current_linear / base_linear
	else:
		# Preserve the already-tested legacy live FM-SFX fallback path.
		var fnum = maxf(1.0, t.fm_base_fnum + float(raw_delta))
		t.pitch_factor = fnum / t.fm_base_fnum
	_refresh_render_step_cache(t)

func _refresh_render_step_cache(t: ChannelState) -> void:
	# Pitch modulation changes only on the 60 Hz SMPS clock. Cache the final
	# oscillator step there instead of multiplying base step × pitch factor for
	# every operator of every generated audio sample.
	if t.kind == "FM":
		for i in range(4):
			t.fm_render_step[i] = float(t.phase_step[i]) * t.pitch_factor
	elif t.kind == "PSG":
		t.psg_render_step = t.psg_step * t.pitch_factor

func _render_fm(t: ChannelState) -> float:
	# Hotfix 9 keeps Hotfix 8's FM math but flattens the hottest GDScript path:
	# oscillator steps are pre-multiplied on the 60 Hz modulation clock and the
	# 16K sine lookup is performed directly here, avoiding eight script-function
	# calls plus interpolation work for every four-operator channel sample.
	var p0: float = float(t.phase[0]) + float(t.fm_render_step[0])
	var p1: float = float(t.phase[1]) + float(t.fm_render_step[1])
	var p2: float = float(t.phase[2]) + float(t.fm_render_step[2])
	var p3: float = float(t.phase[3]) + float(t.fm_render_step[3])
	t.phase[0] = p0
	t.phase[1] = p1
	t.phase[2] = p2
	t.phase[3] = p3

	var scale: float = t.fm_modulation_scale
	var a0: float = float(t.fm_render_amp[0])
	var a1: float = float(t.fm_render_amp[1])
	var a2: float = float(t.fm_render_amp[2])
	var a3: float = float(t.fm_render_amp[3])
	# The OPN2 operator pipeline does not route the freshly-computed OP1 sample
	# straight back into the same channel sample.  The previous OP1 result feeds
	# the algorithm while the new result is retained for the following sample.
	# This matters most for high-multiplier serial voices such as GHZ's FM2 bass.
	var delayed_o1: float = t.feedback_sample
	var feedback_mod: float = (t.feedback_sample + t.feedback_sample_2) * 0.5 * t.fm_feedback_scale
	var o1: float = float(_sine_table[int(p0 + feedback_mod * scale) & SINE_TABLE_MASK]) * a0
	t.feedback_sample_2 = t.feedback_sample
	t.feedback_sample = o1
	# Keep the already-validated live FM-SFX fallback on its previous immediate
	# routing. Music alone adopts the hardware-style one-sample OP1 pipeline.
	var routed_o1: float = o1 if t.is_sfx else delayed_o1

	var o2: float = 0.0
	var o3: float = 0.0
	var o4: float = 0.0
	var output: float = 0.0
	match t.fm_algorithm:
		0:
			o2 = float(_sine_table[int(p1 + routed_o1 * scale) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2 + o2 * scale) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3 + o3 * scale) & SINE_TABLE_MASK]) * a3
			output = o4
		1:
			o2 = float(_sine_table[int(p1) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2 + (routed_o1 + o2) * scale) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3 + o3 * scale) & SINE_TABLE_MASK]) * a3
			output = o4
		2:
			o2 = float(_sine_table[int(p1) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2 + o2 * scale) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3 + (routed_o1 + o3) * scale) & SINE_TABLE_MASK]) * a3
			output = o4
		3:
			o2 = float(_sine_table[int(p1 + routed_o1 * scale) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3 + (o2 + o3) * scale) & SINE_TABLE_MASK]) * a3
			output = o4
		4:
			o2 = float(_sine_table[int(p1 + routed_o1 * scale) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3 + o3 * scale) & SINE_TABLE_MASK]) * a3
			output = (o2 + o4) * 0.5 if t.is_sfx else clampf(o2 + o4, -1.0, 1.0)
		5:
			o2 = float(_sine_table[int(p1 + routed_o1 * scale) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2 + routed_o1 * scale) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3 + routed_o1 * scale) & SINE_TABLE_MASK]) * a3
			output = (o2 + o3 + o4) / 3.0 if t.is_sfx else clampf(o2 + o3 + o4, -1.0, 1.0)
		6:
			o2 = float(_sine_table[int(p1 + routed_o1 * scale) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3) & SINE_TABLE_MASK]) * a3
			output = (o2 + o3 + o4) / 3.0 if t.is_sfx else clampf(o2 + o3 + o4, -1.0, 1.0)
		_:
			o2 = float(_sine_table[int(p1) & SINE_TABLE_MASK]) * a1
			o3 = float(_sine_table[int(p2) & SINE_TABLE_MASK]) * a2
			o4 = float(_sine_table[int(p3) & SINE_TABLE_MASK]) * a3
			output = (routed_o1 + o2 + o3 + o4) * 0.25 if t.is_sfx else clampf(routed_o1 + o2 + o3 + o4, -1.0, 1.0)
	return output * t.fm_track_gain * FM_MIX_BOOST

func _refresh_psg_amp(t: ChannelState) -> void:
	if t.kind != "PSG":
		return
	var attenuation := maxi(0, t.volume)
	var envs: Array = t.song.get("psg_envelopes", _database.get("psg_envelopes", []))
	if t.psg_voice > 0 and not envs.is_empty():
		var env_index := clampi(t.psg_voice - 1, 0, envs.size() - 1)
		var env: Array = envs[env_index]
		if not env.is_empty():
			attenuation += int(env[mini(t.psg_env_pos, env.size() - 1)])
	attenuation = clampi(attenuation, 0, 15)
	t.psg_amp = (float(PSG_LEVEL_TABLE[attenuation]) / 8191.0) * PSG_MIX_BOOST

func _render_psg(t: ChannelState) -> float:
	var step := t.psg_render_step
	t.phase[0] = fmod(float(t.phase[0]) + step, 1.0)
	var raw := 0.0
	if t.psg_noise:
		if float(t.phase[0]) < step:
			# Mega Drive PSG noise uses a 16-bit register. Rotate the old high bit
			# into bit 0; white-noise mode then XORs post-shift bit 13 into bit 0.
			t.noise_output_bit = (t.noise_lfsr >> 15) & 1
			t.noise_lfsr = ((t.noise_lfsr << 1) & 0xFFFF) | t.noise_output_bit
			if (t.psg_noise_control & 0x04) != 0:
				t.noise_lfsr ^= (t.noise_lfsr & 0x2000) >> 13
		raw = 1.0 if t.noise_output_bit != 0 else -1.0
	else:
		raw = 1.0 if float(t.phase[0]) < 0.5 else -1.0
	return raw * t.psg_amp

func _render_dac(t: ChannelState) -> Vector2:
	if not t.note_on or t.dac_sample < 0:
		return Vector2.ZERO
	if String(t.song.get("header", {}).get("driver_mode", "s1")) == "s2":
		if not _s2_ehz_dac_buffers.has(t.dac_sample):
			t.note_on = false
			return Vector2.ZERO
		var s2_buf: PackedFloat32Array = _s2_ehz_dac_buffers[t.dac_sample]
		var s2_idx := int(t.dac_pos)
		if s2_idx >= s2_buf.size():
			t.note_on = false
			return Vector2.ZERO
		var s2_sample := s2_buf[s2_idx] * DAC_MIX_GAIN
		t.dac_pos += 1.0
		return Vector2(s2_sample * t.pan_left, s2_sample * t.pan_right)
	var buffer_index := 0
	var speed := 1.0
	match t.dac_sample:
		0:
			buffer_index = 0
		1:
			buffer_index = 1
		2:
			buffer_index = 2
			speed = 1.30
		3:
			buffer_index = 2
			speed = 1.20
		4:
			buffer_index = 2
			speed = 0.97
		5:
			buffer_index = 2
			speed = 0.95
		_:
			buffer_index = 2
	if buffer_index >= _dac_buffers.size():
		return Vector2.ZERO
	var buf: PackedFloat32Array = _dac_buffers[buffer_index]
	var idx := int(t.dac_pos)
	if idx >= buf.size():
		t.note_on = false
		return Vector2.ZERO
	var sample := buf[idx] * DAC_MIX_GAIN
	t.dac_pos += speed
	return Vector2(sample * t.pan_left, sample * t.pan_right)
