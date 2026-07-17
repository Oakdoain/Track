extends RefCounted
class_name SaveDataValidator

const SUPPORTED_FORMAT_VERSION := 2
const MINIMUM_FORMAT_VERSION := 1
const LEGACY_COMPATIBLE_NODE_IDS := {
	"tutorial_00": {
		"tutorial_0004": true,
		"tutorial_0009": true,
		"tutorial_inference_final": true
	}
}

var expected_case_id: String = "case_01"
var expected_slice_id: String = "control_backup"


func _init(case_id: String = "case_01", slice_id: String = "control_backup") -> void:
	expected_case_id = case_id
	expected_slice_id = slice_id


func migrate_document(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var version_value: Variant = migrated.get("format_version")
	if not _is_integer_number(version_value):
		return _failure("incompatible", "format_version: expected integer-valued number, got %s, value=%s" % [type_string(typeof(version_value)), str(version_value)])
	var version := int(version_value)
	if version < MINIMUM_FORMAT_VERSION or version > SUPPORTED_FORMAT_VERSION:
		return _failure("incompatible", "format_version: unsupported value=%d" % version)
	if not (migrated.get("runtime_state") is Dictionary):
		return _failure("corrupted", "runtime_state: expected Dictionary, got %s, value=%s" % [type_string(typeof(migrated.get("runtime_state"))), str(migrated.get("runtime_state"))])

	var runtime := (migrated.get("runtime_state") as Dictionary).duplicate(true)
	if not runtime.has("visit_history"):
		runtime["visit_history"] = []
	if not runtime.has("history_cursor"):
		runtime["history_cursor"] = (runtime["visit_history"] as Array).size() - 1
	if not runtime.has("committed_transitions"):
		runtime["committed_transitions"] = []
	if not runtime.has("graph_view"):
		runtime["graph_view"] = {"pan_x": 0.0, "pan_y": 0.0, "zoom": 1.0}
	migrated["runtime_state"] = runtime
	migrated["format_version"] = SUPPORTED_FORMAT_VERSION
	return {
		"success": true,
		"data": migrated,
		"migrated": version != SUPPORTED_FORMAT_VERSION,
		"from_version": version,
		"to_version": SUPPORTED_FORMAT_VERSION,
		"error": ""
	}


func validate_document(data: Dictionary, expected_slot_type: String = "", expected_slot_index: int = -1) -> Dictionary:
	if not data.has("format_version"):
		return _failure("incompatible", "format_version: required field is missing")
	var version_value: Variant = data.get("format_version")
	if not _is_integer_number(version_value):
		return _typed_failure("incompatible", "format_version", "integer-valued number", version_value)
	if int(version_value) != SUPPORTED_FORMAT_VERSION:
		return _failure("incompatible", "format_version: expected %d, got value=%s" % [SUPPORTED_FORMAT_VERSION, str(version_value)])

	if not (data.get("case_id") is String) or str(data.get("case_id", "")) != expected_case_id:
		return _typed_failure("corrupted", "case_id", "String equal to " + expected_case_id, data.get("case_id"))
	if not (data.get("slice_id") is String) or str(data.get("slice_id", "")) != expected_slice_id:
		return _typed_failure("corrupted", "slice_id", "String equal to " + expected_slice_id, data.get("slice_id"))

	var slot_type_value: Variant = data.get("slot_type")
	var slot_index_value: Variant = data.get("slot_index")
	if not (slot_type_value is String):
		return _typed_failure("corrupted", "slot_type", "String", slot_type_value)
	if not _is_integer_number(slot_index_value):
		return _typed_failure("corrupted", "slot_index", "integer-valued number", slot_index_value)
	var slot_type := str(slot_type_value)
	var slot_index := int(slot_index_value)
	if slot_type == "autosave" and slot_index != 0:
		return _failure("corrupted", "slot_index: autosave requires value=0, got value=%s" % str(slot_index_value))
	if slot_type == "manual" and (slot_index < 1 or slot_index > 20):
		return _failure("corrupted", "slot_index: manual slot must be 1..20, got value=%s" % str(slot_index_value))
	if slot_type not in ["autosave", "manual"]:
		return _failure("corrupted", "slot_type: expected autosave or manual, got value=%s" % slot_type)
	if expected_slot_type != "" and slot_type != expected_slot_type:
		return _failure("corrupted", "slot_type: file expects %s, got value=%s" % [expected_slot_type, slot_type])
	if expected_slot_index >= 0 and slot_index != expected_slot_index:
		return _failure("corrupted", "slot_index: file expects %d, got value=%s" % [expected_slot_index, str(slot_index_value)])

	var saved_at_value: Variant = data.get("saved_at_unix")
	if not _is_integer_number(saved_at_value) or int(saved_at_value) < 0:
		return _typed_failure("corrupted", "saved_at_unix", "non-negative integer-valued number", saved_at_value)
	if not (data.get("metadata") is Dictionary):
		return _typed_failure("corrupted", "metadata", "Dictionary", data.get("metadata"))
	var metadata: Dictionary = data.get("metadata", {})
	for metadata_field in ["chapter_title", "node_title", "node_id"]:
		if not (metadata.get(metadata_field) is String):
			return _typed_failure("corrupted", "metadata." + metadata_field, "String", metadata.get(metadata_field))
	if str(metadata.get("node_id", "")) == "":
		return _failure("corrupted", "metadata.node_id: expected non-empty String, got value=\"\"")
	if not (data.get("runtime_state") is Dictionary):
		return _typed_failure("corrupted", "runtime_state", "Dictionary", data.get("runtime_state"))

	var runtime_data: Dictionary = data.get("runtime_state", {})
	var runtime_probe := CaseRuntimeState.new()
	var runtime_validation := runtime_probe.validate_save_dictionary_detailed(runtime_data, "runtime_state")
	if not bool(runtime_validation.get("valid", false)):
		return _failure("corrupted", str(runtime_validation.get("error", "runtime_state: validation failed")))
	if str(metadata.get("node_id", "")) != str(runtime_data.get("current_node_id", "")):
		return _failure("corrupted", "metadata.node_id: expected current runtime node %s, got value=%s" % [str(runtime_data.get("current_node_id", "")), str(metadata.get("node_id", ""))])

	var node_validation := _validate_node_references(runtime_data)
	if not bool(node_validation.get("valid", false)):
		return node_validation
	return {"valid": true, "status": "available", "error": ""}


func _validate_node_references(runtime_data: Dictionary) -> Dictionary:
	var loader := CaseDataLoader.new()
	if not loader.load_registry() or not loader.load_case(expected_case_id, expected_slice_id):
		return _failure("corrupted", "runtime_state: current case data could not be loaded for node validation")
	var current_id := str(runtime_data.get("current_node_id", ""))
	if loader.get_node(current_id).is_empty():
		return _failure("corrupted", "runtime_state.current_node_id: target node does not exist, value=%s" % current_id)
	var safe_id := str(runtime_data.get("last_safe_autosave_node_id", ""))
	if safe_id != "" and loader.get_node(safe_id).is_empty():
		return _failure("corrupted", "runtime_state.last_safe_autosave_node_id: target node does not exist, value=%s" % safe_id)
	var history: Array = runtime_data.get("visit_history", [])
	for index in range(history.size()):
		var node_id := str(history[index])
		if loader.get_node(node_id).is_empty() and not _is_legacy_compatible_node(node_id):
			return _failure("corrupted", "runtime_state.visit_history[%d]: target node does not exist, value=%s" % [index, node_id])
	var transitions: Array = runtime_data.get("committed_transitions", [])
	for index in range(transitions.size()):
		var transition := transitions[index] as Dictionary
		for field in ["source_node_id", "target_node_id"]:
			var node_id := str(transition.get(field, ""))
			if loader.get_node(node_id).is_empty() and not _is_legacy_compatible_node(node_id):
				return _failure("corrupted", "runtime_state.committed_transitions[%d].%s: target node does not exist, value=%s" % [index, field, node_id])
	var connections: Array = runtime_data.get("keyword_connections", [])
	for index in range(connections.size()):
		var target_id := str((connections[index] as Dictionary).get("target_node_id", ""))
		if loader.get_node(target_id).is_empty() and not _is_legacy_compatible_node(target_id):
			return _failure("corrupted", "runtime_state.keyword_connections[%d].target_node_id: target node does not exist, value=%s" % [index, target_id])
	return {"valid": true, "status": "available", "error": ""}


func _is_legacy_compatible_node(node_id: String) -> bool:
	var case_nodes: Variant = LEGACY_COMPATIBLE_NODE_IDS.get(expected_case_id, {})
	return case_nodes is Dictionary and (case_nodes as Dictionary).has(node_id)


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if not (value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and floorf(number) == number


func _typed_failure(status: String, path: String, expected: String, actual: Variant) -> Dictionary:
	var summary := str(actual)
	if summary.length() > 120:
		summary = summary.left(117) + "..."
	return _failure(status, "%s: expected %s, got %s, value=%s" % [path, expected, type_string(typeof(actual)), summary])


func _failure(status: String, error: String) -> Dictionary:
	return {"success": false, "valid": false, "status": status, "error": error}
