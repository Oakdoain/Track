extends Node

const SOUND_PATHS := {
	"ui_click": "res://assets/third_party/kenney/audio/ui/ui_click.ogg",
	"ui_backtrack": "res://assets/third_party/kenney/audio/ui/ui_backtrack.ogg",
	"ui_keyword_extract": "res://assets/third_party/kenney/audio/ui/ui_keyword_extract.ogg",
	"ui_connection_correct": "res://assets/third_party/kenney/audio/ui/ui_connection_correct.ogg",
	"ui_connection_invalid": "res://assets/third_party/kenney/audio/ui/ui_connection_invalid.ogg",
	"ui_inference_wrong": "res://assets/third_party/kenney/audio/ui/ui_inference_wrong.ogg",
	"ui_node_unlock": "res://assets/third_party/kenney/audio/ui/ui_node_unlock.ogg"
}

const PLAYER_POOL_SIZE := 4
const EVENT_COOLDOWN_MSEC := 70
const DEFAULT_VOLUME_DB := -16.0
const INCOMING_RING_PATH := "res://assets/audio/ui/phone/incoming_ring_loop.ogg"
const OUTGOING_RINGBACK_PATH := "res://assets/audio/ui/phone/outgoing_ringback.ogg"
const NODE_TYPING_PATH := "res://assets/audio/ui/text/node_typing_loop.ogg"
const PHONE_FADE_SECONDS := 0.12
const TYPING_FADE_SECONDS := 0.10
const NODE_TYPING_VOLUME_DB := -26.0
const PHONE_RING_VOLUME_DB := -14.0
const OUTGOING_RINGBACK_VOLUME_DB := -17.0

var _players: Array[AudioStreamPlayer] = []
var _last_played_msec: Dictionary = {}
var _volume_db: float = DEFAULT_VOLUME_DB
var _phone_loop_player: AudioStreamPlayer
var _typing_loop_player: AudioStreamPlayer
var _phone_audio_mode: String = ""
var _missing_audio_warnings: Dictionary = {}
var _fade_tweens: Dictionary = {}
var _presentation_paused: bool = false


func _ready() -> void:
	for index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "UIPlayer%d" % index
		player.volume_db = _volume_db
		add_child(player)
		_players.append(player)
	_phone_loop_player = AudioStreamPlayer.new()
	_phone_loop_player.name = "PhoneLoopPlayer"
	add_child(_phone_loop_player)
	_typing_loop_player = AudioStreamPlayer.new()
	_typing_loop_player.name = "NodeTypingLoopPlayer"
	add_child(_typing_loop_player)
	if not ResourceLoader.exists(INCOMING_RING_PATH):
		_warn_missing_once("incoming_ring", INCOMING_RING_PATH)
	if not ResourceLoader.exists(OUTGOING_RINGBACK_PATH):
		_warn_missing_once("outgoing_ring", OUTGOING_RINGBACK_PATH)
	if not ResourceLoader.exists(NODE_TYPING_PATH):
		_warn_missing_once("node_typing", NODE_TYPING_PATH)


func play(event_key: String) -> void:
	var path: String = str(SOUND_PATHS.get(event_key, ""))

	if path == "" or not ResourceLoader.exists(path):
		return

	var now: int = Time.get_ticks_msec()
	var last_played: int = int(_last_played_msec.get(event_key, -EVENT_COOLDOWN_MSEC))

	if now - last_played < EVENT_COOLDOWN_MSEC:
		return

	var player: AudioStreamPlayer = _available_player()

	if player == null:
		return

	var resource: Resource = load(path)

	if not (resource is AudioStream):
		return

	_last_played_msec[event_key] = now
	player.stream = resource as AudioStream
	player.volume_db = _volume_db
	player.play()


func set_volume_db(value: float) -> void:
	_volume_db = clampf(value, -40.0, -6.0)

	for player in _players:
		player.volume_db = _volume_db


func sync_phone_state(active_call: Dictionary) -> void:
	var desired_mode := ""
	var status := str(active_call.get("status", ""))
	var direction := str(active_call.get("direction", ""))
	if status == "incoming_waiting" and direction == "incoming":
		desired_mode = "incoming"
	elif status == "outgoing_waiting":
		desired_mode = "outgoing"
	_set_phone_audio_mode(desired_mode)


func start_outgoing_ringback() -> void:
	_set_phone_audio_mode("outgoing")


func stop_phone_audio() -> void:
	_set_phone_audio_mode("")


func start_node_typing() -> void:
	_start_loop(_typing_loop_player, NODE_TYPING_PATH, "node_typing", NODE_TYPING_VOLUME_DB)


func stop_node_typing() -> void:
	_fade_out(_typing_loop_player, TYPING_FADE_SECONDS)


func set_presentation_paused(paused: bool) -> void:
	if _presentation_paused == paused:
		return
	_presentation_paused = paused
	if _phone_loop_player != null:
		_phone_loop_player.stream_paused = paused
	if _typing_loop_player != null:
		_typing_loop_player.stream_paused = paused


func _set_phone_audio_mode(mode: String) -> void:
	if mode == _phone_audio_mode:
		return
	var switching := mode != "" and _phone_audio_mode != ""
	_phone_audio_mode = mode
	if mode == "":
		_fade_out(_phone_loop_player, PHONE_FADE_SECONDS)
		return
	if switching:
		_stop_player_immediately(_phone_loop_player)
	var path := INCOMING_RING_PATH if mode == "incoming" else OUTGOING_RINGBACK_PATH
	var volume := PHONE_RING_VOLUME_DB if mode == "incoming" else OUTGOING_RINGBACK_VOLUME_DB
	_start_loop(_phone_loop_player, path, mode + "_ring", volume)


func _start_loop(player: AudioStreamPlayer, path: String, warning_key: String, volume_db: float) -> void:
	if player == null:
		return
	_kill_fade(player)
	if player.playing and player.stream != null and str(player.stream.resource_path) == path:
		return
	if not ResourceLoader.exists(path):
		_warn_missing_once(warning_key, path)
		return
	var resource := ResourceLoader.load(path)
	if not (resource is AudioStream):
		_warn_missing_once(warning_key, path)
		return
	var stream := (resource as AudioStream).duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.stream_paused = _presentation_paused
	player.play()


func _fade_out(player: AudioStreamPlayer, duration: float) -> void:
	if player == null or not player.playing:
		return
	_kill_fade(player)
	var tween := create_tween()
	_fade_tweens[player.get_instance_id()] = tween
	tween.tween_property(player, "volume_db", -48.0, duration)
	tween.tween_callback(_stop_player_immediately.bind(player))


func _stop_player_immediately(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	_kill_fade(player)
	player.stop()
	player.stream_paused = false
	player.stream = null


func _kill_fade(player: AudioStreamPlayer) -> void:
	var instance_id := player.get_instance_id()
	var tween: Tween = _fade_tweens.get(instance_id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_fade_tweens.erase(instance_id)


func _warn_missing_once(key: String, path: String) -> void:
	if _missing_audio_warnings.has(key):
		return
	_missing_audio_warnings[key] = true
	push_warning("UISoundManager: optional audio is missing; continuing silently: " + path)


func _available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player

	return null
