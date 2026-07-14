extends RefCounted
class_name SettingsManager

signal settings_changed(settings: Dictionary)

const FORMAT_VERSION: int = 1
const DEFAULT_SETTINGS_PATH: String = "user://settings.json"
const DEFAULT_SETTINGS: Dictionary = {
	"format_version": FORMAT_VERSION,
	"master_volume": 100,
	"window_mode": "windowed",
	"vsync_enabled": true
}

var settings_path: String = DEFAULT_SETTINGS_PATH
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)


func _init(path: String = DEFAULT_SETTINGS_PATH) -> void:
	settings_path = path


func initialize() -> Dictionary:
	var load_result: Dictionary = load_settings()
	apply_settings()
	return load_result


func load_settings() -> Dictionary:
	_settings = DEFAULT_SETTINGS.duplicate(true)

	if not FileAccess.file_exists(settings_path):
		return {"success": true, "used_defaults": true, "error": ""}

	var content: String = FileAccess.get_file_as_string(settings_path)
	var json := JSON.new()
	var parse_error: Error = json.parse(content)

	if parse_error != OK or not (json.data is Dictionary):
		var error_text: String = "设置文件损坏，已使用默认设置"
		push_warning("SettingsManager: " + error_text)
		return {"success": false, "used_defaults": true, "error": error_text}

	var parsed: Dictionary = json.data

	if int(parsed.get("format_version", -1)) != FORMAT_VERSION:
		var version_error: String = "设置文件版本不兼容，已使用默认设置"
		push_warning("SettingsManager: " + version_error)
		return {"success": false, "used_defaults": true, "error": version_error}

	var volume_value: Variant = parsed.get("master_volume", DEFAULT_SETTINGS["master_volume"])
	var mode_value: Variant = parsed.get("window_mode", DEFAULT_SETTINGS["window_mode"])
	var vsync_value: Variant = parsed.get("vsync_enabled", DEFAULT_SETTINGS["vsync_enabled"])

	if volume_value is int or volume_value is float:
		_settings["master_volume"] = clampi(int(volume_value), 0, 100)
	else:
		push_warning("SettingsManager: invalid master_volume; using default.")

	var mode_text: String = str(mode_value)
	if mode_text == "windowed" or mode_text == "fullscreen":
		_settings["window_mode"] = mode_text
	else:
		push_warning("SettingsManager: invalid window_mode; using default.")

	if vsync_value is bool:
		_settings["vsync_enabled"] = bool(vsync_value)
	else:
		push_warning("SettingsManager: invalid vsync_enabled; using default.")

	return {"success": true, "used_defaults": false, "error": ""}


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func get_master_volume() -> int:
	return int(_settings.get("master_volume", 100))


func get_window_mode() -> String:
	return str(_settings.get("window_mode", "windowed"))


func is_vsync_enabled() -> bool:
	return bool(_settings.get("vsync_enabled", true))


func set_master_volume(value: int) -> Dictionary:
	_settings["master_volume"] = clampi(value, 0, 100)
	_apply_master_volume()
	return _persist_and_emit()


func set_window_mode(value: String) -> Dictionary:
	if value != "windowed" and value != "fullscreen":
		return _failure("无效的显示模式")

	_settings["window_mode"] = value
	_apply_window_mode()
	return _persist_and_emit()


func set_vsync_enabled(value: bool) -> Dictionary:
	_settings["vsync_enabled"] = value
	_apply_vsync()
	return _persist_and_emit()


func restore_defaults() -> Dictionary:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	apply_settings()
	return _persist_and_emit()


func apply_settings() -> void:
	_apply_master_volume()
	_apply_window_mode()
	_apply_vsync()


func save_settings() -> Dictionary:
	var temporary_path: String = settings_path + ".tmp"
	var backup_path: String = settings_path + ".bak"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)

	if file == null:
		return _failure("无法写入设置临时文件")

	file.store_string(JSON.stringify(_settings, "\t", false))
	file.flush()
	file.close()

	if not _validate_written_file(temporary_path):
		_remove_file(temporary_path)
		return _failure("设置临时文件校验失败")

	var absolute_path: String = ProjectSettings.globalize_path(settings_path)
	var absolute_temporary: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_backup: String = ProjectSettings.globalize_path(backup_path)
	var had_previous: bool = FileAccess.file_exists(settings_path)
	_remove_file(backup_path)

	if had_previous:
		var backup_error: Error = DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			_remove_file(temporary_path)
			return _failure("无法保护旧设置文件，已取消写入")

	var replace_error: Error = DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if replace_error != OK:
		if had_previous and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		_remove_file(temporary_path)
		return _failure("无法替换正式设置文件")

	if not _validate_written_file(settings_path):
		_remove_file(settings_path)
		if had_previous and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return _failure("设置写入后校验失败，已恢复旧文件")

	_remove_file(backup_path)
	return {"success": true, "error": ""}


func _apply_master_volume() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus < 0:
		push_warning("SettingsManager: Master audio bus is unavailable.")
		return

	var volume: int = get_master_volume()
	AudioServer.set_bus_mute(master_bus, volume <= 0)
	if volume > 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(float(volume) / 100.0))


func _apply_window_mode() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return

	var target_mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if get_window_mode() == "fullscreen"
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(target_mode)


func _apply_vsync() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return

	var target_mode: DisplayServer.VSyncMode = (
		DisplayServer.VSYNC_ENABLED
		if is_vsync_enabled()
		else DisplayServer.VSYNC_DISABLED
	)
	DisplayServer.window_set_vsync_mode(target_mode)
	var applied_mode: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	if applied_mode != target_mode:
		push_warning("SettingsManager: requested VSync mode is not supported by this display backend.")


func _persist_and_emit() -> Dictionary:
	var result: Dictionary = save_settings()
	settings_changed.emit(get_settings())
	return result


func _validate_written_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return false
	return int((json.data as Dictionary).get("format_version", -1)) == FORMAT_VERSION


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _failure(error_text: String) -> Dictionary:
	push_warning("SettingsManager: " + error_text)
	return {"success": false, "error": error_text}
