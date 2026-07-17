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

var _players: Array[AudioStreamPlayer] = []
var _last_played_msec: Dictionary = {}
var _volume_db: float = DEFAULT_VOLUME_DB


func _ready() -> void:
	for index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "UIPlayer%d" % index
		player.volume_db = _volume_db
		add_child(player)
		_players.append(player)


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


func _available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player

	return null
