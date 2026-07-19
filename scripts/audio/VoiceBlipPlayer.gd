extends Node
class_name VoiceBlipPlayer

const PROFILE_PATH := "res://data/audio/voice_profiles.json"
const MIX_RATE := 44100.0
const DEFAULT_PROFILE := {
	"waveform": "triangle",
	"base_frequency": 430.0,
	"frequency_variants": [0.96, 1.0, 1.05],
	"duration_ms": 46,
	"characters_per_blip": 2,
	"minimum_interval_ms": 70,
	"volume_db": -28.0
}

var _profiles: Dictionary = {}
var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _character_counts: Dictionary = {}
var _last_variant_indices: Dictionary = {}
var _last_blip_msec: int = -1000
var _paused: bool = false


func _ready() -> void:
	_load_profiles()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = MIX_RATE
	_generator.buffer_length = 0.12
	_player = AudioStreamPlayer.new()
	_player.name = "VoiceBlipStreamPlayer"
	_player.stream = _generator
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func play_character(profile_id: String, character: String) -> void:
	if _paused or character == "" or _is_silent_character(character):
		return
	var profile := get_profile(profile_id)
	var count := int(_character_counts.get(profile_id, 0)) + 1
	_character_counts[profile_id] = count
	var characters_per_blip := maxi(1, int(profile.get("characters_per_blip", 2)))
	if count % characters_per_blip != 0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_blip_msec < int(profile.get("minimum_interval_ms", 70)):
		return
	_last_blip_msec = now
	_generate_blip(profile_id, profile)


func set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	if _player != null:
		_player.stream_paused = paused


func stop() -> void:
	_character_counts.clear()
	if _player == null:
		return
	_player.stop()
	if not _paused:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func get_profile(profile_id: String) -> Dictionary:
	var value: Variant = _profiles.get(profile_id, DEFAULT_PROFILE)
	return (value as Dictionary).duplicate(true) if value is Dictionary else DEFAULT_PROFILE.duplicate(true)


func _generate_blip(profile_id: String, profile: Dictionary) -> void:
	if _playback == null:
		return
	var variants_value: Variant = profile.get("frequency_variants", [1.0])
	var variants: Array = variants_value if variants_value is Array and not (variants_value as Array).is_empty() else [1.0]
	var previous := int(_last_variant_indices.get(profile_id, -1))
	var variant_index := 0 if variants.size() == 1 else posmod(previous + 1 + (Time.get_ticks_msec() % (variants.size() - 1)), variants.size())
	if variants.size() > 1 and variant_index == previous:
		variant_index = (variant_index + 1) % variants.size()
	_last_variant_indices[profile_id] = variant_index
	var frequency := float(profile.get("base_frequency", 430.0)) * float(variants[variant_index])
	var duration := clampf(float(profile.get("duration_ms", 46)) / 1000.0, 0.035, 0.07)
	var frame_count := maxi(1, roundi(MIX_RATE * duration))
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	var waveform := str(profile.get("waveform", "triangle"))
	for index in range(frame_count):
		var time := float(index) / MIX_RATE
		var phase := fmod(time * frequency, 1.0)
		var triangle := 1.0 - 4.0 * absf(phase - 0.5)
		var sine := sin(TAU * phase)
		var sample := triangle if waveform == "triangle" else sine * 0.68 + triangle * 0.32
		var normalized := float(index) / float(maxi(1, frame_count - 1))
		var envelope := minf(1.0, normalized / 0.08) * pow(1.0 - normalized, 1.8)
		var amplitude := sample * envelope * 0.42
		frames[index] = Vector2(amplitude, amplitude)
	_player.volume_db = clampf(float(profile.get("volume_db", -28.0)), -40.0, -12.0)
	if _playback.get_frames_available() >= frames.size():
		_playback.push_buffer(frames)


func _load_profiles() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		push_warning("VoiceBlipPlayer: voice profile data not found: " + PROFILE_PATH)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PROFILE_PATH)) != OK or not (json.data is Dictionary):
		push_warning("VoiceBlipPlayer: invalid voice profile data: " + PROFILE_PATH)
		return
	var profiles_value: Variant = (json.data as Dictionary).get("profiles", {})
	if profiles_value is Dictionary:
		_profiles = (profiles_value as Dictionary).duplicate(true)


func _is_silent_character(character: String) -> bool:
	return character.strip_edges() == "" or character in ["，", "。", "！", "？", "、", "：", "；", ",", ".", "!", "?", ":", ";"]
