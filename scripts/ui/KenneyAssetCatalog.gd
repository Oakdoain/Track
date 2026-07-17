extends RefCounted

const ICON_PATHS := {
	"audio_play": "res://assets/third_party/kenney/icons/audio/icon_audio_play.png",
	"audio_pause": "res://assets/third_party/kenney/icons/audio/icon_audio_pause.png",
	"audio_clue": "res://assets/third_party/kenney/icons/audio/icon_audio_clue.png",
	"backtrack": "res://assets/third_party/kenney/icons/navigation/icon_backtrack.png",
	"graph": "res://assets/third_party/kenney/icons/navigation/icon_graph.png",
	"keyword": "res://assets/third_party/kenney/icons/graph/icon_keyword.png",
	"unlock": "res://assets/third_party/kenney/icons/graph/icon_unlock.png",
	"connection_valid": "res://assets/third_party/kenney/icons/graph/icon_connection_valid.png",
	"connection_invalid": "res://assets/third_party/kenney/icons/graph/icon_connection_invalid.png",
	"warning": "res://assets/third_party/kenney/icons/graph/icon_warning.png"
}

const PROMPT_PATHS := {
	"mouse_left": "res://assets/third_party/kenney/input_prompts/mouse/prompt_mouse_left.svg",
	"mouse_right": "res://assets/third_party/kenney/input_prompts/mouse/prompt_mouse_right.svg",
	"mouse_drag": "res://assets/third_party/kenney/input_prompts/mouse/prompt_mouse_drag.svg",
	"mouse_wheel": "res://assets/third_party/kenney/input_prompts/mouse/prompt_mouse_wheel.svg"
}

const CURSOR_PATHS := {
	"default": "res://assets/third_party/kenney/cursors/cursor_default.png",
	"pointer": "res://assets/third_party/kenney/cursors/cursor_pointer.png",
	"drag_horizontal": "res://assets/third_party/kenney/cursors/cursor_drag_horizontal.png",
	"connect": "res://assets/third_party/kenney/cursors/cursor_connect.png",
	"forbidden": "res://assets/third_party/kenney/cursors/cursor_forbidden.png"
}


static func icon(key: String, fallback: Texture2D = null) -> Texture2D:
	return _texture_from_map(ICON_PATHS, key, fallback)


static func prompt(key: String, fallback: Texture2D = null) -> Texture2D:
	return _texture_from_map(PROMPT_PATHS, key, fallback)


static func cursor(key: String) -> Texture2D:
	return _texture_from_map(CURSOR_PATHS, key, null)


static func _texture_from_map(paths: Dictionary, key: String, fallback: Texture2D) -> Texture2D:
	var path: String = str(paths.get(key, ""))

	if path == "" or not ResourceLoader.exists(path):
		return fallback

	var resource: Resource = load(path)
	return resource as Texture2D if resource is Texture2D else fallback
