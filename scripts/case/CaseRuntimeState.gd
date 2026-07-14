extends RefCounted
class_name CaseRuntimeState

const MAX_KEYWORD_LENGTH: int = 10

var current_node_id: String = ""
var unlocked_nodes: Dictionary = {}
var flags: Dictionary = {}
var last_safe_autosave_node_id: String = ""
var keyword_instances: Array[Dictionary] = []
var keyword_connections: Array[Dictionary] = []
var keyword_unlocked_nodes: Dictionary = {}
var audio_markers: Array[Dictionary] = []

var _keyword_instances_by_key: Dictionary = {}
var _keyword_counts_by_source: Dictionary = {}
var _keyword_connections_by_key: Dictionary = {}
var _keyword_connection_count: int = 0
var _audio_marker_counts_by_clue: Dictionary = {}


func set_current_node(node_id: String, autosave: bool) -> void:
	current_node_id = node_id
	unlocked_nodes[node_id] = true

	if autosave:
		last_safe_autosave_node_id = node_id


func add_keyword(text: String, source_node_id: String) -> Dictionary:
	var normalized_text: String = normalize_keyword_text(text)

	if normalized_text == "" or source_node_id == "":
		return {
			"added": false,
			"reason": "empty"
		}

	if normalized_text.length() > MAX_KEYWORD_LENGTH:
		return {
			"added": false,
			"reason": "too_long",
			"max_length": MAX_KEYWORD_LENGTH
		}

	var keyword_key: String = _keyword_key(normalized_text, source_node_id)

	if _keyword_instances_by_key.has(keyword_key):
		return {
			"added": false,
			"reason": "duplicate",
			"instance": _keyword_instances_by_key[keyword_key]
		}

	var source_count: int = int(_keyword_counts_by_source.get(source_node_id, 0)) + 1
	_keyword_counts_by_source[source_node_id] = source_count

	var instance: Dictionary = {
		"instance_id": "keyword_%s_%03d" % [source_node_id, source_count],
		"text": normalized_text,
		"normalized_text": normalized_text,
		"source_node_id": source_node_id
	}

	keyword_instances.append(instance)
	_keyword_instances_by_key[keyword_key] = instance
	return {
		"added": true,
		"reason": "added",
		"instance": instance
	}


func has_keyword(text: String, source_node_id: String) -> bool:
	var normalized_text: String = normalize_keyword_text(text)

	if normalized_text == "" or source_node_id == "":
		return false

	return _keyword_instances_by_key.has(_keyword_key(normalized_text, source_node_id))


func get_keyword_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for instance in keyword_instances:
		result.append(instance.duplicate(true))

	return result


func get_keyword_instances_for_source(source_node_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for instance in keyword_instances:
		if str(instance.get("source_node_id", "")) == source_node_id:
			result.append(instance.duplicate(true))

	return result


func get_keyword_instance(instance_id: String) -> Dictionary:
	var instance: Dictionary = _find_keyword_instance_ref(instance_id)

	if instance.is_empty():
		return {}

	return instance.duplicate(true)


func get_discovered_keyword_texts() -> PackedStringArray:
	var result := PackedStringArray()
	var seen_texts: Dictionary = {}

	for instance in keyword_instances:
		var text: String = str(instance.get("text", ""))

		if text != "" and not seen_texts.has(text):
			seen_texts[text] = true
			result.append(text)

	return result


func normalize_keyword_text(text: String) -> String:
	var normalized_text: String = text.strip_edges()

	if normalized_text == "":
		return ""

	var whitespace_regex := RegEx.new()
	var compile_error: int = whitespace_regex.compile("\\s+")

	if compile_error != OK:
		push_warning("CaseRuntimeState: failed to compile keyword whitespace regex.")
		return normalized_text

	return whitespace_regex.sub(normalized_text, " ", true)


func add_keyword_connection(
	keyword_instance_id: String,
	target_node_id: String,
	result: Dictionary
) -> Dictionary:
	if keyword_instance_id == "" or target_node_id == "":
		return {
			"added": false,
			"reason": "empty"
		}

	var outcome: String = str(result.get("outcome", "")).to_lower()

	if outcome != "correct":
		return {
			"added": false,
			"reason": "not_correct"
		}

	var instance: Dictionary = _find_keyword_instance_ref(keyword_instance_id)

	if instance.is_empty():
		return {
			"added": false,
			"reason": "keyword_not_found"
		}

	var connection_key: String = _keyword_connection_key(keyword_instance_id, target_node_id)

	if _keyword_connections_by_key.has(connection_key):
		return {
			"added": false,
			"reason": "duplicate",
			"connection": _keyword_connections_by_key[connection_key]
		}

	_keyword_connection_count += 1
	var connection: Dictionary = {
		"connection_id": "keyword_connection_%03d" % _keyword_connection_count,
		"keyword_instance_id": keyword_instance_id,
		"keyword_text": str(instance.get("text", "")),
		"source_node_id": str(instance.get("source_node_id", "")),
		"target_node_id": target_node_id,
		"outcome": outcome,
		"unlock_node_id": str(result.get("unlock_node_id", ""))
	}

	keyword_connections.append(connection)
	_keyword_connections_by_key[connection_key] = connection
	return {
		"added": true,
		"reason": "added",
		"connection": connection
	}


func has_keyword_connection(keyword_instance_id: String, target_node_id: String) -> bool:
	return _keyword_connections_by_key.has(
		_keyword_connection_key(keyword_instance_id, target_node_id)
	)


func get_keyword_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for connection in keyword_connections:
		result.append(connection.duplicate(true))

	return result


func get_keyword_connections_for_keyword(keyword_instance_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for connection in keyword_connections:
		if str(connection.get("keyword_instance_id", "")) == keyword_instance_id:
			result.append(connection.duplicate(true))

	return result


func unlock_node_from_keyword(node_id: String) -> bool:
	if node_id == "" or keyword_unlocked_nodes.has(node_id):
		return false

	keyword_unlocked_nodes[node_id] = true
	return true


func is_keyword_unlocked(node_id: String) -> bool:
	return keyword_unlocked_nodes.has(node_id)


func get_keyword_unlocked_node_ids() -> PackedStringArray:
	var result := PackedStringArray()

	for node_id in keyword_unlocked_nodes.keys():
		result.append(str(node_id))

	return result


func add_audio_marker(
	audio_clue_id: String,
	source_node_id: String,
	time_seconds: float,
	label: String
) -> Dictionary:
	var safe_time: float = _sanitize_audio_marker_time(time_seconds)

	if audio_clue_id == "" or source_node_id == "":
		return {
			"added": false,
			"reason": "empty"
		}

	for marker in audio_markers:
		if (
			str(marker.get("audio_clue_id", "")) == audio_clue_id
			and absf(float(marker.get("time_seconds", 0.0)) - safe_time) <= 0.25
		):
			return {
				"added": false,
				"reason": "duplicate",
				"marker": marker.duplicate(true)
			}

	var marker_count: int = int(_audio_marker_counts_by_clue.get(audio_clue_id, 0)) + 1
	_audio_marker_counts_by_clue[audio_clue_id] = marker_count
	var marker: Dictionary = {
		"marker_id": "audio_marker_%s_%03d" % [
			_sanitize_marker_id_part(audio_clue_id),
			marker_count
		],
		"audio_clue_id": audio_clue_id,
		"source_node_id": source_node_id,
		"time_seconds": safe_time,
		"label": label
	}
	audio_markers.append(marker)
	return {
		"added": true,
		"reason": "added",
		"marker": marker.duplicate(true)
	}


func get_audio_markers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for marker in audio_markers:
		result.append(marker.duplicate(true))

	return result


func get_audio_markers_for_clue(audio_clue_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for marker in audio_markers:
		if str(marker.get("audio_clue_id", "")) == audio_clue_id:
			result.append(marker.duplicate(true))

	return result


func has_audio_marker_near(
	audio_clue_id: String,
	time_seconds: float,
	tolerance: float = 0.25
) -> bool:
	var safe_time: float = _sanitize_audio_marker_time(time_seconds)
	var safe_tolerance: float = maxf(0.0, tolerance)

	for marker in audio_markers:
		if (
			str(marker.get("audio_clue_id", "")) == audio_clue_id
			and absf(float(marker.get("time_seconds", 0.0)) - safe_time) <= safe_tolerance
		):
			return true

	return false


func to_save_dictionary() -> Dictionary:
	return {
		"current_node_id": current_node_id,
		"unlocked_nodes": unlocked_nodes.duplicate(true),
		"flags": flags.duplicate(true),
		"last_safe_autosave_node_id": last_safe_autosave_node_id,
		"keyword_instances": get_keyword_instances(),
		"keyword_connections": get_keyword_connections(),
		"keyword_unlocked_nodes": keyword_unlocked_nodes.duplicate(true),
		"audio_markers": get_audio_markers()
	}


func validate_save_dictionary(data: Dictionary, emit_warning: bool = true) -> bool:
	var required_fields: PackedStringArray = [
		"current_node_id",
		"unlocked_nodes",
		"flags",
		"last_safe_autosave_node_id",
		"keyword_instances",
		"keyword_connections",
		"keyword_unlocked_nodes",
		"audio_markers"
	]

	for field in required_fields:
		if not data.has(field):
			return _save_validation_failure("missing runtime field: " + field, emit_warning)

	if not (data.get("current_node_id") is String) or str(data.get("current_node_id", "")) == "":
		return _save_validation_failure("current_node_id must be a non-empty String", emit_warning)

	if not (data.get("last_safe_autosave_node_id") is String):
		return _save_validation_failure("last_safe_autosave_node_id must be a String", emit_warning)

	if not (data.get("flags") is Dictionary):
		return _save_validation_failure("flags must be a Dictionary", emit_warning)

	if not _validate_string_bool_dictionary(data.get("unlocked_nodes")):
		return _save_validation_failure("unlocked_nodes must contain String keys and bool values", emit_warning)

	if not _validate_string_bool_dictionary(data.get("keyword_unlocked_nodes")):
		return _save_validation_failure("keyword_unlocked_nodes must contain String keys and bool values", emit_warning)

	var unlocked: Dictionary = data.get("unlocked_nodes", {})
	var current_id: String = str(data.get("current_node_id", ""))

	if not unlocked.has(current_id):
		return _save_validation_failure("current_node_id is not present in unlocked_nodes", emit_warning)

	var safe_id: String = str(data.get("last_safe_autosave_node_id", ""))

	if safe_id != "" and not unlocked.has(safe_id):
		return _save_validation_failure("last_safe_autosave_node_id is not unlocked", emit_warning)

	var raw_instances: Variant = data.get("keyword_instances")

	if not (raw_instances is Array):
		return _save_validation_failure("keyword_instances must be an Array", emit_warning)

	var keyword_ids: Dictionary = {}
	var keyword_keys: Dictionary = {}

	for raw_instance in raw_instances:
		if not (raw_instance is Dictionary):
			return _save_validation_failure("keyword instance must be a Dictionary", emit_warning)

		var instance: Dictionary = raw_instance
		var instance_id: String = str(instance.get("instance_id", ""))
		var text: String = str(instance.get("text", ""))
		var normalized_text: String = str(instance.get("normalized_text", ""))
		var source_node_id: String = str(instance.get("source_node_id", ""))

		if instance_id == "" or text == "" or normalized_text == "" or source_node_id == "":
			return _save_validation_failure("keyword instance is missing required String fields", emit_warning)

		var keyword_key: String = _keyword_key(normalized_text, source_node_id)

		if keyword_ids.has(instance_id) or keyword_keys.has(keyword_key):
			return _save_validation_failure("keyword instance id or source/text pair is duplicated", emit_warning)

		keyword_ids[instance_id] = true
		keyword_keys[keyword_key] = true

	var raw_connections: Variant = data.get("keyword_connections")

	if not (raw_connections is Array):
		return _save_validation_failure("keyword_connections must be an Array", emit_warning)

	var connection_ids: Dictionary = {}
	var connection_keys: Dictionary = {}

	for raw_connection in raw_connections:
		if not (raw_connection is Dictionary):
			return _save_validation_failure("keyword connection must be a Dictionary", emit_warning)

		var connection: Dictionary = raw_connection
		var connection_id: String = str(connection.get("connection_id", ""))
		var keyword_instance_id: String = str(connection.get("keyword_instance_id", ""))
		var target_node_id: String = str(connection.get("target_node_id", ""))
		var outcome: String = str(connection.get("outcome", "")).to_lower()

		if connection_id == "" or keyword_instance_id == "" or target_node_id == "":
			return _save_validation_failure("keyword connection is missing required String fields", emit_warning)

		if outcome != "correct" or not keyword_ids.has(keyword_instance_id):
			return _save_validation_failure("keyword connection outcome or instance reference is invalid", emit_warning)

		var connection_key: String = _keyword_connection_key(keyword_instance_id, target_node_id)

		if connection_ids.has(connection_id) or connection_keys.has(connection_key):
			return _save_validation_failure("keyword connection is duplicated", emit_warning)

		connection_ids[connection_id] = true
		connection_keys[connection_key] = true

	var raw_markers: Variant = data.get("audio_markers")

	if not (raw_markers is Array):
		return _save_validation_failure("audio_markers must be an Array", emit_warning)

	var marker_ids: Dictionary = {}

	for raw_marker in raw_markers:
		if not (raw_marker is Dictionary):
			return _save_validation_failure("audio marker must be a Dictionary", emit_warning)

		var marker: Dictionary = raw_marker
		var marker_id: String = str(marker.get("marker_id", ""))
		var audio_clue_id: String = str(marker.get("audio_clue_id", ""))
		var marker_source_id: String = str(marker.get("source_node_id", ""))
		var time_value: Variant = marker.get("time_seconds")

		if marker_id == "" or audio_clue_id == "" or marker_source_id == "":
			return _save_validation_failure("audio marker is missing required String fields", emit_warning)

		if not (marker.get("label", "") is String):
			return _save_validation_failure("audio marker label must be a String", emit_warning)

		if not (time_value is int or time_value is float):
			return _save_validation_failure("audio marker time_seconds must be numeric", emit_warning)

		var marker_time: float = float(time_value)

		if is_nan(marker_time) or is_inf(marker_time) or marker_time < 0.0:
			return _save_validation_failure("audio marker time_seconds is invalid", emit_warning)

		if marker_ids.has(marker_id):
			return _save_validation_failure("audio marker id is duplicated", emit_warning)

		marker_ids[marker_id] = true

	return true


func apply_save_dictionary(data: Dictionary) -> bool:
	if not validate_save_dictionary(data):
		return false

	var new_keyword_instances: Array[Dictionary] = []
	var raw_instances: Array = data.get("keyword_instances", [])

	for raw_instance in raw_instances:
		new_keyword_instances.append((raw_instance as Dictionary).duplicate(true))

	var new_keyword_connections: Array[Dictionary] = []
	var raw_connections: Array = data.get("keyword_connections", [])

	for raw_connection in raw_connections:
		new_keyword_connections.append((raw_connection as Dictionary).duplicate(true))

	var new_audio_markers: Array[Dictionary] = []
	var raw_markers: Array = data.get("audio_markers", [])

	for raw_marker in raw_markers:
		new_audio_markers.append((raw_marker as Dictionary).duplicate(true))

	current_node_id = str(data.get("current_node_id", ""))
	unlocked_nodes = (data.get("unlocked_nodes", {}) as Dictionary).duplicate(true)
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	last_safe_autosave_node_id = str(data.get("last_safe_autosave_node_id", ""))
	keyword_instances = new_keyword_instances
	keyword_connections = new_keyword_connections
	keyword_unlocked_nodes = (data.get("keyword_unlocked_nodes", {}) as Dictionary).duplicate(true)
	audio_markers = new_audio_markers
	_rebuild_runtime_indexes()
	return true


func reset_runtime_state() -> void:
	current_node_id = ""
	unlocked_nodes.clear()
	flags.clear()
	last_safe_autosave_node_id = ""
	keyword_instances.clear()
	keyword_connections.clear()
	keyword_unlocked_nodes.clear()
	audio_markers.clear()
	_rebuild_runtime_indexes()


func _rebuild_runtime_indexes() -> void:
	_keyword_instances_by_key.clear()
	_keyword_counts_by_source.clear()
	_keyword_connections_by_key.clear()
	_audio_marker_counts_by_clue.clear()
	_keyword_connection_count = 0

	for instance in keyword_instances:
		var source_node_id: String = str(instance.get("source_node_id", ""))
		var normalized_text: String = str(instance.get("normalized_text", ""))
		var instance_id: String = str(instance.get("instance_id", ""))
		_keyword_instances_by_key[_keyword_key(normalized_text, source_node_id)] = instance
		_keyword_counts_by_source[source_node_id] = maxi(
			int(_keyword_counts_by_source.get(source_node_id, 0)),
			maxi(1, _id_sequence(instance_id))
		)

	for connection in keyword_connections:
		var keyword_instance_id: String = str(connection.get("keyword_instance_id", ""))
		var target_node_id: String = str(connection.get("target_node_id", ""))
		var connection_id: String = str(connection.get("connection_id", ""))
		_keyword_connections_by_key[
			_keyword_connection_key(keyword_instance_id, target_node_id)
		] = connection
		_keyword_connection_count = maxi(_keyword_connection_count, _id_sequence(connection_id))

	for marker in audio_markers:
		var audio_clue_id: String = str(marker.get("audio_clue_id", ""))
		var marker_id: String = str(marker.get("marker_id", ""))
		_audio_marker_counts_by_clue[audio_clue_id] = maxi(
			int(_audio_marker_counts_by_clue.get(audio_clue_id, 0)),
			maxi(1, _id_sequence(marker_id))
		)


func _validate_string_bool_dictionary(value: Variant) -> bool:
	if not (value is Dictionary):
		return false

	var dictionary: Dictionary = value

	for key in dictionary.keys():
		if not (key is String) or not (dictionary[key] is bool):
			return false

	return true


func _save_validation_failure(message: String, emit_warning: bool) -> bool:
	if emit_warning:
		push_warning("CaseRuntimeState: " + message)

	return false


func _id_sequence(id_value: String) -> int:
	var parts: PackedStringArray = id_value.split("_", false)

	if parts.is_empty():
		return 0

	var last_part: String = parts[parts.size() - 1]
	return int(last_part) if last_part.is_valid_int() else 0


func _keyword_key(normalized_text: String, source_node_id: String) -> String:
	return source_node_id + "\u001f" + normalized_text


func _sanitize_audio_marker_time(value: float) -> float:
	if is_nan(value) or is_inf(value) or value < 0.0:
		return 0.0

	return value


func _sanitize_marker_id_part(value: String) -> String:
	var id_regex := RegEx.new()

	if id_regex.compile("[^A-Za-z0-9_]+") != OK:
		return value

	var sanitized: String = id_regex.sub(value, "_", true).strip_edges()
	return sanitized if sanitized != "" else "audio"


func _keyword_connection_key(keyword_instance_id: String, target_node_id: String) -> String:
	return keyword_instance_id + "\u001f" + target_node_id


func _find_keyword_instance_ref(instance_id: String) -> Dictionary:
	for instance in keyword_instances:
		if str(instance.get("instance_id", "")) == instance_id:
			return instance

	return {}
