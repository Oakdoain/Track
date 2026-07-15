extends RefCounted
class_name CaseProgressManager

const FORMAT_VERSION: int = 1
const DEFAULT_PROGRESS_PATH: String = "user://case_progress.json"

var progress_path: String = DEFAULT_PROGRESS_PATH
var _allowed_case_ids: Dictionary = {}
var _cases: Dictionary = {}
var _initialized: bool = false


func _init(
	registered_cases: Array[Dictionary] = [],
	configured_path: String = DEFAULT_PROGRESS_PATH
) -> void:
	progress_path = configured_path

	for descriptor in registered_cases:
		var case_id: String = str(descriptor.get("case_id", ""))

		if case_id != "":
			_allowed_case_ids[case_id] = true


func initialize() -> Dictionary:
	_cases.clear()
	_recover_interrupted_write()

	if not FileAccess.file_exists(progress_path):
		_initialized = true
		return _success()

	var read_result: Dictionary = _read_and_validate(progress_path)

	if not bool(read_result.get("success", false)):
		push_warning("CaseProgressManager: " + str(read_result.get("error", "案件进度文件不可读取")))
		_initialized = true
		return {
			"success": true,
			"used_empty_progress": true,
			"error": str(read_result.get("error", ""))
		}

	_cases = (read_result.get("cases", {}) as Dictionary).duplicate(true)
	_initialized = true
	return _success()


func is_case_completed(case_id: String) -> bool:
	_ensure_initialized()

	if not _allowed_case_ids.has(case_id):
		return false

	var value: Variant = _cases.get(case_id, {})
	return value is Dictionary and bool((value as Dictionary).get("completed", false))


func has_case_record(case_id: String) -> bool:
	_ensure_initialized()
	return _allowed_case_ids.has(case_id) and _cases.has(case_id)


func get_case_progress(case_id: String) -> Dictionary:
	_ensure_initialized()

	if not _allowed_case_ids.has(case_id):
		return {}

	var value: Variant = _cases.get(case_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func mark_case_completed(case_id: String, completed_at_unix: int = 0) -> Dictionary:
	_ensure_initialized()

	if not _allowed_case_ids.has(case_id):
		return _failure("案件 ID 未出现在已验证注册表中：" + case_id)

	if is_case_completed(case_id):
		return {
			"success": true,
			"changed": false,
			"error": ""
		}

	var completion_time: int = completed_at_unix

	if completion_time <= 0:
		completion_time = int(Time.get_unix_time_from_system())

	var previous_cases: Dictionary = _cases.duplicate(true)
	_cases[case_id] = {
		"completed": true,
		"completed_at_unix": completion_time
	}
	var write_result: Dictionary = _write_progress_safely()

	if not bool(write_result.get("success", false)):
		_cases = previous_cases
		return write_result

	return {
		"success": true,
		"changed": true,
		"error": ""
	}


func get_progress_path() -> String:
	return progress_path


func _ensure_initialized() -> void:
	if not _initialized:
		initialize()


func _read_and_validate(path: String) -> Dictionary:
	var json := JSON.new()
	var parse_error: Error = json.parse(FileAccess.get_file_as_string(path))

	if parse_error != OK:
		return _failure_without_warning(
			"案件进度 JSON 损坏：%s（第 %d 行）" % [
				json.get_error_message(),
				json.get_error_line()
			]
		)

	if not (json.data is Dictionary):
		return _failure_without_warning("案件进度根数据不是字典")

	var document: Dictionary = json.data

	if int(document.get("format_version", -1)) != FORMAT_VERSION:
		return _failure_without_warning("案件进度版本不兼容")

	var raw_cases: Variant = document.get("cases", {})

	if not (raw_cases is Dictionary):
		return _failure_without_warning("案件进度 cases 不是字典")

	var sanitized_cases: Dictionary = {}

	for raw_case_id in (raw_cases as Dictionary).keys():
		var case_id: String = str(raw_case_id)

		if not _allowed_case_ids.has(case_id):
			push_warning("CaseProgressManager: ignored unregistered case progress: " + case_id)
			continue

		var raw_progress: Variant = (raw_cases as Dictionary).get(raw_case_id, {})

		if not (raw_progress is Dictionary):
			push_warning("CaseProgressManager: ignored invalid progress for case: " + case_id)
			continue

		var completed_value: Variant = (raw_progress as Dictionary).get("completed", false)
		var completed_at_value: Variant = (raw_progress as Dictionary).get("completed_at_unix", 0)

		if not (completed_value is bool) or not (completed_at_value is int or completed_at_value is float):
			push_warning("CaseProgressManager: ignored invalid completion fields for case: " + case_id)
			continue

		if bool(completed_value):
			sanitized_cases[case_id] = {
				"completed": true,
				"completed_at_unix": maxi(0, int(completed_at_value))
			}

	return {
		"success": true,
		"cases": sanitized_cases,
		"error": ""
	}


func _write_progress_safely() -> Dictionary:
	var directory_path: String = progress_path.get_base_dir()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory_path)
	)

	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure("无法创建案件进度目录")

	var temporary_path: String = progress_path + ".tmp"
	var backup_path: String = progress_path + ".bak"
	var document: Dictionary = {
		"format_version": FORMAT_VERSION,
		"cases": _cases.duplicate(true)
	}
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)

	if file == null:
		return _failure("无法写入案件进度临时文件")

	file.store_string(JSON.stringify(document, "\t", false))
	file.flush()
	file.close()

	var temporary_validation: Dictionary = _read_and_validate(temporary_path)

	if not bool(temporary_validation.get("success", false)):
		_remove_file_if_present(temporary_path)
		return _failure("案件进度临时文件校验失败")

	var absolute_path: String = ProjectSettings.globalize_path(progress_path)
	var absolute_temporary_path: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_backup_path: String = ProjectSettings.globalize_path(backup_path)
	var had_previous_file: bool = FileAccess.file_exists(progress_path)
	_remove_file_if_present(backup_path)

	if had_previous_file:
		var backup_error: Error = DirAccess.rename_absolute(absolute_path, absolute_backup_path)

		if backup_error != OK:
			_remove_file_if_present(temporary_path)
			return _failure("无法保护旧案件进度，已取消写入")

	var replace_error: Error = DirAccess.rename_absolute(absolute_temporary_path, absolute_path)

	if replace_error != OK:
		if had_previous_file and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)

		_remove_file_if_present(temporary_path)
		return _failure("无法替换案件进度文件")

	var final_validation: Dictionary = _read_and_validate(progress_path)

	if not bool(final_validation.get("success", false)):
		_remove_file_if_present(progress_path)

		if had_previous_file and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)

		return _failure("案件进度写入后校验失败，已恢复旧文件")

	_remove_file_if_present(backup_path)
	return _success()


func _recover_interrupted_write() -> void:
	var temporary_path: String = progress_path + ".tmp"
	var backup_path: String = progress_path + ".bak"

	if not FileAccess.file_exists(progress_path) and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup_path),
			ProjectSettings.globalize_path(progress_path)
		)
	elif FileAccess.file_exists(progress_path) and FileAccess.file_exists(backup_path):
		_remove_file_if_present(backup_path)

	_remove_file_if_present(temporary_path)


func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _success() -> Dictionary:
	return {"success": true, "error": ""}


func _failure(error: String) -> Dictionary:
	push_warning("CaseProgressManager: " + error)
	return _failure_without_warning(error)


func _failure_without_warning(error: String) -> Dictionary:
	return {"success": false, "error": error}
