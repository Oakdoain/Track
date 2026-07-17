extends Node

const KenneyAssetCatalog := preload("res://scripts/ui/KenneyAssetCatalog.gd")

var _tutorial_active: bool = false
var _arrow_mode: String = ""


func activate_tutorial() -> void:
	if _tutorial_active:
		return

	_tutorial_active = true
	_set_shape("pointer", Input.CURSOR_POINTING_HAND, Vector2(7, 2))
	_set_shape("drag_horizontal", Input.CURSOR_HSIZE, Vector2(16, 16))
	set_mode("default")


func deactivate_tutorial() -> void:
	if not _tutorial_active:
		return

	_tutorial_active = false
	_arrow_mode = ""
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_HSIZE)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func set_mode(mode: String) -> void:
	if not _tutorial_active or mode == _arrow_mode:
		return

	var resolved: String = mode if mode == "connect" or mode == "forbidden" else "default"
	var hotspot := Vector2(16, 16) if resolved == "connect" else Vector2(1, 1)

	if resolved == "forbidden":
		hotspot = Vector2(2, 2)

	_set_shape(resolved, Input.CURSOR_ARROW, hotspot)
	_arrow_mode = resolved


func _set_shape(asset_key: String, shape: int, hotspot: Vector2) -> void:
	var texture: Texture2D = KenneyAssetCatalog.cursor(asset_key)

	if texture != null:
		Input.set_custom_mouse_cursor(texture, shape, hotspot)
