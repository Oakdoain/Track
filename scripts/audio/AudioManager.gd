extends Node

signal audio_started(audio_id: String)
signal audio_paused(audio_id: String)
signal audio_stopped(audio_id: String)
signal audio_finished(audio_id: String)
signal audio_progress_changed(audio_id: String, position: float, duration: float)

var audio_data: Dictionary = {}
var audio_by_id: Dictionary = {}
var current_audio_id: String = ""

var _player: AudioStreamPlayer
var _is_paused: bool = false
var _last_progress_second: int = -1


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "AudioStreamPlayer"
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	load_audio_data("res://data/audio/audio_clues.json")


func _process(_delta: float) -> void:
	if current_audio_id == "" or _player == null:
		return

	if not _player.playing and not _is_paused:
		return

	var position: float = _player.get_playback_position()
	var duration: float = _get_audio_duration(current_audio_id)
	var progress_second: int = int(floor(position))

	if progress_second != _last_progress_second:
		_last_progress_second = progress_second
		audio_progress_changed.emit(current_audio_id, position, duration)


func load_audio_data(path: String) -> bool:
	audio_data.clear()
	audio_by_id.clear()

	if not FileAccess.file_exists(path):
		push_warning("AudioManager: audio data file not found: " + path)
		return false

	var content: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var error: int = json.parse(content)

	if error != OK:
		push_warning("AudioManager: json parse error: %s, line %d" % [
			json.get_error_message(),
			json.get_error_line()
		])
		return false

	var parsed: Variant = json.data

	if not (parsed is Dictionary):
		push_warning("AudioManager: json root must be Dictionary: " + path)
		return false

	audio_data = parsed
	var raw_clues: Variant = audio_data.get("audio_clues", [])

	if raw_clues is Array:
		for raw_clue in raw_clues:
			if not (raw_clue is Dictionary):
				continue

			var audio_id: String = str(raw_clue.get("id", ""))

			if audio_id != "":
				audio_by_id[audio_id] = raw_clue

	return true


func play_audio(audio_id: String) -> bool:
	if not audio_by_id.has(audio_id):
		push_warning("AudioManager: audio id not found: " + audio_id)
		return false

	var clue_variant: Variant = audio_by_id[audio_id]

	if not (clue_variant is Dictionary):
		push_warning("AudioManager: audio data must be Dictionary: " + audio_id)
		return false

	var clue: Dictionary = clue_variant
	var file_path: String = str(clue.get("file", ""))

	if file_path == "":
		push_warning("AudioManager: missing audio file path for: " + audio_id)
		return false

	if not ResourceLoader.exists(file_path):
		push_warning("AudioManager: audio resource not found: " + file_path)
		return false

	var stream: Resource = ResourceLoader.load(file_path)

	if not (stream is AudioStream):
		push_warning("AudioManager: resource is not an AudioStream: " + file_path)
		return false

	_player.stream = stream
	current_audio_id = audio_id
	_is_paused = false
	_last_progress_second = -1
	_player.play()
	audio_started.emit(current_audio_id)
	audio_progress_changed.emit(current_audio_id, 0.0, _get_audio_duration(current_audio_id))

	return true


func pause_audio() -> void:
	if current_audio_id == "" or _player == null:
		return

	_player.stream_paused = true
	_is_paused = true
	audio_paused.emit(current_audio_id)


func resume_audio() -> void:
	if current_audio_id == "" or _player == null:
		return

	_player.stream_paused = false
	_is_paused = false
	audio_started.emit(current_audio_id)


func stop_audio() -> void:
	if current_audio_id == "" or _player == null:
		return

	var stopped_audio_id: String = current_audio_id
	_player.stop()
	_player.stream_paused = false
	_is_paused = false
	current_audio_id = ""
	_last_progress_second = -1
	audio_stopped.emit(stopped_audio_id)


func seek_audio(time: float) -> void:
	if current_audio_id == "" or _player == null:
		return

	var duration: float = _get_audio_duration(current_audio_id)
	var target_time: float = max(0.0, time)

	if duration > 0.0:
		target_time = min(target_time, duration)

	_player.seek(target_time)
	audio_progress_changed.emit(current_audio_id, target_time, duration)


func get_current_audio_id() -> String:
	return current_audio_id


func is_paused() -> bool:
	return _is_paused


func get_audio_duration(audio_id: String) -> float:
	return _get_audio_duration(audio_id)


func _get_audio_duration(audio_id: String) -> float:
	if audio_by_id.has(audio_id):
		var clue_variant: Variant = audio_by_id[audio_id]

		if not (clue_variant is Dictionary):
			return 0.0

		var clue: Dictionary = clue_variant
		return float(clue.get("duration", 0.0))

	return 0.0


func _on_player_finished() -> void:
	if current_audio_id == "":
		return

	var finished_audio_id: String = current_audio_id
	current_audio_id = ""
	_is_paused = false
	_last_progress_second = -1
	audio_finished.emit(finished_audio_id)
