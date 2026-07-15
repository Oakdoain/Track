extends RefCounted
class_name SaveManager

const FORMAT_VERSION := 1
const DEFAULT_SAVE_DIR := "user://saves"
const MANUAL_SLOT_COUNT := 20
const SLOTS_PER_PAGE := 7
const PAGE_COUNT := 3

var save_directory: String = DEFAULT_SAVE_DIR
var case_id: String = "case_01"
var slice_id: String = "control_backup"
var _validator: SaveDataValidator
var _initialized: bool = false


func _init(
	configured_case_id: String = "case_01",
	configured_slice_id: String = "control_backup",
	base_directory: String = DEFAULT_SAVE_DIR
) -> void:
	case_id = configured_case_id
	slice_id = configured_slice_id
	save_directory = base_directory.trim_suffix("/") + "/" + case_id
	_validator = SaveDataValidator.new(case_id, slice_id)


func initialize() -> Dictionary:
	if not _is_safe_identifier(case_id) or not _is_safe_identifier(slice_id):
		return _failure("案件存档标识无效")

	var absolute_directory: String = ProjectSettings.globalize_path(save_directory)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)

	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		var error_text: String = "无法创建存档目录：%s" % save_directory
		push_warning("SaveManager: " + error_text)
		return _failure(error_text)

	for slot_index in range(0, MANUAL_SLOT_COUNT + 1):
		var slot_type: String = "autosave" if slot_index == 0 else "manual"
		_recover_interrupted_write(_slot_path(slot_type, slot_index))

	if case_id == "case_01":
		_migrate_legacy_root_saves()

	_initialized = true
	return _success()


func get_all_slot_summaries() -> Array[Dictionary]:
	_ensure_initialized()
	var summaries: Array[Dictionary] = []
	summaries.append(read_slot_summary("autosave", 0))

	for slot_index in range(1, MANUAL_SLOT_COUNT + 1):
		summaries.append(read_slot_summary("manual", slot_index))

	return summaries


func get_page_slot_summaries(page_index: int) -> Array[Dictionary]:
	var all_summaries: Array[Dictionary] = get_all_slot_summaries()
	var safe_page_index: int = clampi(page_index, 0, PAGE_COUNT - 1)
	var start_index: int = safe_page_index * SLOTS_PER_PAGE
	var end_index: int = mini(start_index + SLOTS_PER_PAGE, all_summaries.size())
	var result: Array[Dictionary] = []

	for index in range(start_index, end_index):
		result.append(all_summaries[index].duplicate(true))

	return result


func save_autosave(metadata: Dictionary, runtime_state: Dictionary) -> Dictionary:
	return _save_slot("autosave", 0, metadata, runtime_state)


func save_manual(slot_index: int, metadata: Dictionary, runtime_state: Dictionary) -> Dictionary:
	if slot_index < 1 or slot_index > MANUAL_SLOT_COUNT:
		return _failure("手动存档编号超出范围")

	return _save_slot("manual", slot_index, metadata, runtime_state)


func load_autosave() -> Dictionary:
	return _load_slot("autosave", 0)


func load_manual(slot_index: int) -> Dictionary:
	if slot_index < 1 or slot_index > MANUAL_SLOT_COUNT:
		return _failure("手动存档编号超出范围")

	return _load_slot("manual", slot_index)


func read_slot_summary(slot_type: String, slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_type, slot_index):
		return _summary(slot_type, slot_index, "corrupted", {}, "存档槽位无效")

	var path: String = _slot_path(slot_type, slot_index)

	if not FileAccess.file_exists(path):
		return _summary(slot_type, slot_index, "empty", {}, "")

	var read_result: Dictionary = _read_and_validate(path, slot_type, slot_index)

	if not bool(read_result.get("success", false)):
		return _summary(
			slot_type,
			slot_index,
			str(read_result.get("status", "corrupted")),
			{},
			str(read_result.get("error", "存档不可读取"))
		)

	return _summary(slot_type, slot_index, "available", read_result.get("data", {}), "")


func get_slot_path(slot_type: String, slot_index: int) -> String:
	if not _is_valid_slot(slot_type, slot_index):
		return ""

	return _slot_path(slot_type, slot_index)


func _save_slot(
	slot_type: String,
	slot_index: int,
	metadata: Dictionary,
	runtime_state: Dictionary
) -> Dictionary:
	if not _is_valid_slot(slot_type, slot_index):
		return _failure("存档槽位无效")

	var init_result: Dictionary = _ensure_initialized()

	if not bool(init_result.get("success", false)):
		return init_result

	var document: Dictionary = {
		"format_version": FORMAT_VERSION,
		"case_id": case_id,
		"slice_id": slice_id,
		"slot_type": slot_type,
		"slot_index": slot_index,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"metadata": metadata.duplicate(true),
		"runtime_state": runtime_state.duplicate(true)
	}
	var validation: Dictionary = _validator.validate_document(document, slot_type, slot_index)

	if not bool(validation.get("valid", false)):
		return _failure("存档数据无效：" + str(validation.get("error", "未知错误")))

	var path: String = _slot_path(slot_type, slot_index)
	var write_result: Dictionary = _write_document_safely(path, document, slot_type, slot_index)

	if not bool(write_result.get("success", false)):
		return write_result

	return {
		"success": true,
		"error": "",
		"data": document.duplicate(true),
		"summary": _summary(slot_type, slot_index, "available", document, "")
	}


func _load_slot(slot_type: String, slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_type, slot_index):
		return _failure("存档槽位无效")

	_ensure_initialized()
	var path: String = _slot_path(slot_type, slot_index)

	if not FileAccess.file_exists(path):
		return _failure("存档槽为空")

	return _read_and_validate(path, slot_type, slot_index)


func _read_and_validate(path: String, slot_type: String, slot_index: int) -> Dictionary:
	var content: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var parse_error: Error = json.parse(content)

	if parse_error != OK:
		return {
			"success": false,
			"status": "corrupted",
			"error": "存档 JSON 损坏：%s（第 %d 行）" % [
				json.get_error_message(),
				json.get_error_line()
			]
		}

	var parsed: Variant = json.data

	if not (parsed is Dictionary):
		return {
			"success": false,
			"status": "corrupted",
			"error": "存档根数据不是字典"
		}

	var data: Dictionary = parsed
	var validation: Dictionary = _validator.validate_document(data, slot_type, slot_index)

	if not bool(validation.get("valid", false)):
		return {
			"success": false,
			"status": str(validation.get("status", "corrupted")),
			"error": str(validation.get("error", "存档校验失败"))
		}

	return {
		"success": true,
		"status": "available",
		"error": "",
		"data": data.duplicate(true)
	}


func _write_document_safely(
	path: String,
	document: Dictionary,
	slot_type: String,
	slot_index: int
) -> Dictionary:
	var temporary_path: String = path + ".tmp"
	var backup_path: String = path + ".bak"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)

	if file == null:
		return _failure("无法写入临时存档文件")

	file.store_string(JSON.stringify(document, "\t", false))
	file.flush()
	file.close()

	var temporary_validation: Dictionary = _read_and_validate(
		temporary_path,
		slot_type,
		slot_index
	)

	if not bool(temporary_validation.get("success", false)):
		_remove_file_if_present(temporary_path)
		return _failure("临时存档校验失败：" + str(temporary_validation.get("error", "")))

	var absolute_path: String = ProjectSettings.globalize_path(path)
	var absolute_temporary_path: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_backup_path: String = ProjectSettings.globalize_path(backup_path)
	var had_previous_save: bool = FileAccess.file_exists(path)

	_remove_file_if_present(backup_path)

	if had_previous_save:
		var backup_error: Error = DirAccess.rename_absolute(absolute_path, absolute_backup_path)

		if backup_error != OK:
			_remove_file_if_present(temporary_path)
			return _failure("无法保护旧存档，已取消写入")

	var replace_error: Error = DirAccess.rename_absolute(absolute_temporary_path, absolute_path)

	if replace_error != OK:
		if had_previous_save and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)

		_remove_file_if_present(temporary_path)
		return _failure("无法替换正式存档文件")

	var final_validation: Dictionary = _read_and_validate(path, slot_type, slot_index)

	if not bool(final_validation.get("success", false)):
		_remove_file_if_present(path)

		if had_previous_save and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)

		return _failure("正式存档写入后校验失败，已恢复旧存档")

	_remove_file_if_present(backup_path)
	return _success()


func _recover_interrupted_write(path: String) -> void:
	var temporary_path: String = path + ".tmp"
	var backup_path: String = path + ".bak"

	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup_path),
			ProjectSettings.globalize_path(path)
		)
	elif FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		_remove_file_if_present(backup_path)

	_remove_file_if_present(temporary_path)


func _summary(
	slot_type: String,
	slot_index: int,
	status: String,
	document: Dictionary,
	error: String
) -> Dictionary:
	var metadata: Dictionary = {}
	var saved_at_unix: int = 0

	if not document.is_empty():
		var metadata_value: Variant = document.get("metadata", {})

		if metadata_value is Dictionary:
			metadata = (metadata_value as Dictionary).duplicate(true)

		saved_at_unix = int(document.get("saved_at_unix", 0))

	return {
		"slot_type": slot_type,
		"slot_index": slot_index,
		"slot_label": "自动存档" if slot_type == "autosave" else "手动存档 %d" % slot_index,
		"status": status,
		"is_empty": status == "empty",
		"is_available": status == "available",
		"saved_at_unix": saved_at_unix,
		"saved_at_text": _format_local_datetime(saved_at_unix) if saved_at_unix > 0 else "—",
		"metadata": metadata,
		"error": error,
		"path": _slot_path(slot_type, slot_index)
	}


func _format_local_datetime(unix_time: int) -> String:
	var time_zone: Dictionary = Time.get_time_zone_from_system()
	var bias_minutes: int = int(time_zone.get("bias", 0))
	var local_datetime: Dictionary = Time.get_datetime_dict_from_unix_time(
		unix_time + bias_minutes * 60
	)
	return "%04d-%02d-%02d  %02d:%02d:%02d" % [
		int(local_datetime.get("year", 0)),
		int(local_datetime.get("month", 0)),
		int(local_datetime.get("day", 0)),
		int(local_datetime.get("hour", 0)),
		int(local_datetime.get("minute", 0)),
		int(local_datetime.get("second", 0))
	]


func _slot_path(slot_type: String, slot_index: int) -> String:
	if slot_type == "autosave":
		return save_directory + "/autosave.json"

	return save_directory + "/manual_%02d.json" % slot_index


func _migrate_legacy_root_saves() -> void:
	var legacy_directory: String = DEFAULT_SAVE_DIR

	for slot_index in range(0, MANUAL_SLOT_COUNT + 1):
		var slot_type: String = "autosave" if slot_index == 0 else "manual"
		var legacy_path: String = (
			legacy_directory + "/autosave.json"
			if slot_type == "autosave"
			else legacy_directory + "/manual_%02d.json" % slot_index
		)
		var destination_path: String = _slot_path(slot_type, slot_index)

		if not FileAccess.file_exists(legacy_path) or FileAccess.file_exists(destination_path):
			continue

		var validation: Dictionary = _read_and_validate(legacy_path, slot_type, slot_index)

		if not bool(validation.get("success", false)):
			push_warning("SaveManager: legacy save retained because it is not valid CASE 01 data: " + legacy_path)
			continue

		var copy_error: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(legacy_path),
			ProjectSettings.globalize_path(destination_path)
		)

		if copy_error != OK:
			push_warning("SaveManager: failed to copy legacy save: " + legacy_path)
			continue

		var copied: Dictionary = _read_and_validate(destination_path, slot_type, slot_index)

		if not bool(copied.get("success", false)):
			_remove_file_if_present(destination_path)
			push_warning("SaveManager: legacy save copy failed validation: " + legacy_path)
			continue

		push_warning("SaveManager: copied legacy CASE 01 save into the case directory: " + legacy_path)


func _is_valid_slot(slot_type: String, slot_index: int) -> bool:
	return (
		(slot_type == "autosave" and slot_index == 0)
		or (slot_type == "manual" and slot_index >= 1 and slot_index <= MANUAL_SLOT_COUNT)
	)


func _is_safe_identifier(value: String) -> bool:
	var regex := RegEx.new()
	return regex.compile("^[a-z0-9_]+$") == OK and regex.search(value) != null


func _ensure_initialized() -> Dictionary:
	if _initialized:
		return _success()

	return initialize()


func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _success() -> Dictionary:
	return {
		"success": true,
		"error": ""
	}


func _failure(error: String) -> Dictionary:
	push_warning("SaveManager: " + error)
	return {
		"success": false,
		"status": "error",
		"error": error
	}
