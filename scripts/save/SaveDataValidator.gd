extends RefCounted
class_name SaveDataValidator

const SUPPORTED_FORMAT_VERSION := 1
const CASE_ID := "case_01"
const SLICE_ID := "control_backup"


func validate_document(
	data: Dictionary,
	expected_slot_type: String = "",
	expected_slot_index: int = -1
) -> Dictionary:
	if not data.has("format_version"):
		return _failure("incompatible", "存档缺少格式版本")

	var version_value: Variant = data.get("format_version")

	if not _is_integer_number(version_value):
		return _failure("incompatible", "存档格式版本不是整数")

	var format_version: int = int(version_value)

	if format_version != SUPPORTED_FORMAT_VERSION:
		return _failure("incompatible", "不支持的存档格式版本：%d" % format_version)

	if not (data.get("case_id", "") is String) or str(data.get("case_id", "")) != CASE_ID:
		return _failure("corrupted", "存档案件标识无效")

	if not (data.get("slice_id", "") is String) or str(data.get("slice_id", "")) != SLICE_ID:
		return _failure("corrupted", "存档切片标识无效")

	var slot_type_value: Variant = data.get("slot_type")
	var slot_index_value: Variant = data.get("slot_index")

	if not (slot_type_value is String) or not _is_integer_number(slot_index_value):
		return _failure("corrupted", "存档槽位字段无效")

	var slot_type: String = str(slot_type_value)
	var slot_index: int = int(slot_index_value)

	if slot_type == "autosave":
		if slot_index != 0:
			return _failure("corrupted", "自动存档槽位编号无效")
	elif slot_type == "manual":
		if slot_index < 1 or slot_index > 20:
			return _failure("corrupted", "手动存档槽位编号无效")
	else:
		return _failure("corrupted", "存档槽位类型无效")

	if expected_slot_type != "" and slot_type != expected_slot_type:
		return _failure("corrupted", "存档槽位类型与文件不匹配")

	if expected_slot_index >= 0 and slot_index != expected_slot_index:
		return _failure("corrupted", "存档槽位编号与文件不匹配")

	var saved_at_value: Variant = data.get("saved_at_unix")

	if not _is_integer_number(saved_at_value) or int(saved_at_value) < 0:
		return _failure("corrupted", "存档时间字段无效")

	if not (data.get("metadata") is Dictionary):
		return _failure("corrupted", "存档元数据无效")

	var metadata: Dictionary = data.get("metadata", {})

	for metadata_field in ["chapter_title", "node_title", "node_id"]:
		if not (metadata.get(metadata_field, "") is String):
			return _failure("corrupted", "存档元数据字段无效：" + metadata_field)

	if str(metadata.get("node_id", "")) == "":
		return _failure("corrupted", "存档元数据缺少节点 ID")

	if not (data.get("runtime_state") is Dictionary):
		return _failure("corrupted", "存档运行状态无效")

	var runtime_probe := CaseRuntimeState.new()
	var runtime_data: Dictionary = data.get("runtime_state", {})

	if not runtime_probe.validate_save_dictionary(runtime_data, false):
		return _failure("corrupted", "存档运行状态校验失败")

	if str(metadata.get("node_id", "")) != str(runtime_data.get("current_node_id", "")):
		return _failure("corrupted", "存档元数据节点与运行状态不一致")

	return {
		"valid": true,
		"status": "available",
		"error": ""
	}


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true

	if not (value is float):
		return false

	var float_value: float = float(value)
	return not is_nan(float_value) and not is_inf(float_value) and floorf(float_value) == float_value


func _failure(status: String, error: String) -> Dictionary:
	return {
		"valid": false,
		"status": status,
		"error": error
	}
