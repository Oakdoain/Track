extends Node

signal audio_started(audio_id: String)
signal audio_paused(audio_id: String)
signal audio_stopped(audio_id: String)
signal audio_finished(audio_id: String)
signal audio_progress_changed(audio_id: String, position: float, duration: float)

const DEFAULT_AUDIO_DATA_PATH := "res://data/cases/case_01/control_backup/audio_clues.json"

var audio_data: Dictionary = {}
var audio_by_id: Dictionary = {}
var current_audio_id: String = ""

var _player: AudioStreamPlayer
var _is_paused: bool = false
var _last_progress_second: int = -1
var _streams_by_id: Dictionary = {}
var _durations_by_id: Dictionary = {}
var _unavailable_audio_ids: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "AudioStreamPlayer"
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	load_audio_data(DEFAULT_AUDIO_DATA_PATH)


func _process(_delta: float) -> void:
	if current_audio_id == "" or _player == null:
		return

	if not _player.playing and not _is_paused:
		return

	var position: float = get_playback_position()
	var duration: float = get_loaded_duration()
	var progress_second: int = int(floor(position))

	if progress_second != _last_progress_second:
		_last_progress_second = progress_second
		audio_progress_changed.emit(current_audio_id, position, duration)


func load_audio_data(path: String) -> bool:
	audio_data.clear()
	audio_by_id.clear()
	_streams_by_id.clear()
	_durations_by_id.clear()
	_unavailable_audio_ids.clear()

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


func get_audio_clue(audio_id: String) -> Dictionary:
	var clue_variant: Variant = audio_by_id.get(audio_id, {})

	if not (clue_variant is Dictionary):
		return {}

	return (clue_variant as Dictionary).duplicate(true)


func prepare_audio(audio_id: String) -> bool:
	if not _load_stream_for_id(audio_id):
		return false

	if _player == null:
		push_warning("AudioManager: AudioStreamPlayer is not ready.")
		return false

	if current_audio_id != "" and current_audio_id != audio_id and _player.playing:
		_player.stop()

	_player.stream = _streams_by_id[audio_id] as AudioStream
	_player.stream_paused = false
	current_audio_id = audio_id
	_is_paused = false
	_last_progress_second = -1
	return true


func play_audio(audio_id: String = "") -> bool:
	var requested_audio_id: String = audio_id if audio_id != "" else current_audio_id

	if requested_audio_id == "":
		push_warning("AudioManager: no audio clue is selected for playback.")
		return false

	if current_audio_id != requested_audio_id or _player == null or _player.stream == null:
		if not prepare_audio(requested_audio_id):
			return false

	if _is_paused:
		resume_audio()
		return true

	_player.stream_paused = false
	_is_paused = false
	_last_progress_second = -1
	_player.play()
	audio_started.emit(current_audio_id)
	audio_progress_changed.emit(current_audio_id, 0.0, get_loaded_duration())
	return true


func pause_audio() -> void:
	if current_audio_id == "" or _player == null or not _player.playing:
		return

	_player.stream_paused = true
	_is_paused = true
	audio_paused.emit(current_audio_id)


func resume_audio() -> void:
	if current_audio_id == "" or _player == null or not _is_paused:
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
	_last_progress_second = -1
	audio_stopped.emit(stopped_audio_id)
	audio_progress_changed.emit(stopped_audio_id, 0.0, get_loaded_duration())


func seek_audio(time: float) -> void:
	if current_audio_id == "" or _player == null or _player.stream == null:
		return

	var duration: float = get_loaded_duration()
	var target_time: float = _sanitize_time(time)

	if duration > 0.0:
		target_time = minf(target_time, duration)

	_player.seek(target_time)
	audio_progress_changed.emit(current_audio_id, target_time, duration)


func is_audio_available(audio_id: String) -> bool:
	return _load_stream_for_id(audio_id)


func get_current_audio_id() -> String:
	return current_audio_id


func is_playing() -> bool:
	return _player != null and _player.playing and not _is_paused


func is_paused() -> bool:
	return _is_paused


func get_playback_position() -> float:
	if current_audio_id == "" or _player == null or _player.stream == null:
		return 0.0

	return _sanitize_time(_player.get_playback_position())


func get_loaded_duration() -> float:
	return get_audio_duration(current_audio_id)


func get_audio_duration(audio_id: String) -> float:
	if audio_id == "":
		return 0.0

	if not _durations_by_id.has(audio_id) and not _load_stream_for_id(audio_id):
		return 0.0

	return _sanitize_time(float(_durations_by_id.get(audio_id, 0.0)))


func _load_stream_for_id(audio_id: String) -> bool:
	if _streams_by_id.has(audio_id):
		return true

	if _unavailable_audio_ids.has(audio_id):
		return false

	var clue_variant: Variant = audio_by_id.get(audio_id, {})

	if not (clue_variant is Dictionary):
		_unavailable_audio_ids[audio_id] = true
		push_warning("AudioManager: audio id not found: " + audio_id)
		return false

	var clue: Dictionary = clue_variant
	var file_path: String = str(clue.get("file", ""))

	if file_path == "":
		_unavailable_audio_ids[audio_id] = true
		push_warning("AudioManager: missing audio file path for: " + audio_id)
		return false

	if not FileAccess.file_exists(file_path) and not ResourceLoader.exists(file_path):
		_unavailable_audio_ids[audio_id] = true
		push_warning("AudioManager: audio resource not found: " + file_path)
		return false

	var stream: AudioStream = null

	var file_extension: String = file_path.get_extension().to_lower()

	if file_extension == "mp3":
		var stream_resource: Resource = ResourceLoader.load(file_path)

		if stream_resource is AudioStream:
			stream = stream_resource as AudioStream

		if stream == null:
			stream = AudioStreamMP3.load_from_file(file_path)
	elif _has_mp3_file_header(file_path):
		stream = AudioStreamMP3.load_from_file(file_path)
		push_warning(
			"AudioManager: audio content is MP3 despite its file extension; "
			+ "loading by content: "
			+ file_path
		)
	else:
		var stream_resource: Resource = ResourceLoader.load(file_path)

		if stream_resource is AudioStream:
			stream = stream_resource as AudioStream

	if stream == null:
		_unavailable_audio_ids[audio_id] = true
		push_warning("AudioManager: resource is not a supported AudioStream: " + file_path)
		return false

	var duration: float = _sanitize_time(stream.get_length())
	_streams_by_id[audio_id] = stream
	_durations_by_id[audio_id] = duration

	if duration <= 0.0:
		push_warning("AudioManager: audio stream has no valid duration: " + file_path)

	return true


func _has_mp3_file_header(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		return false

	var header: PackedByteArray = file.get_buffer(3)

	if header.size() < 2:
		return false

	var has_id3_header: bool = (
		header.size() >= 3
		and header[0] == 0x49
		and header[1] == 0x44
		and header[2] == 0x33
	)
	var has_mpeg_frame_sync: bool = header[0] == 0xFF and (header[1] & 0xE0) == 0xE0
	return has_id3_header or has_mpeg_frame_sync


func _sanitize_time(value: float) -> float:
	if is_nan(value) or is_inf(value) or value < 0.0:
		return 0.0

	return value


func _on_player_finished() -> void:
	if current_audio_id == "":
		return

	var finished_audio_id: String = current_audio_id
	_player.stream_paused = false
	_is_paused = false
	_last_progress_second = -1
	audio_finished.emit(finished_audio_id)
	audio_progress_changed.emit(finished_audio_id, 0.0, get_loaded_duration())
