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
var visit_history: Array[String] = []
var committed_transitions: Array[Dictionary] = []
var history_cursor: int = -1
var graph_view: Dictionary = {"pan_x": 0.0, "pan_y": 0.0, "zoom": 1.0}

var _keyword_instances_by_key: Dictionary = {}
var _keyword_counts_by_source: Dictionary = {}
var _keyword_connections_by_key: Dictionary = {}
var _keyword_connection_count: int = 0
var _issued_keyword_ids: Dictionary = {}
var _keyword_id_nonce: int = 0


func set_current_node(node_id: String, autosave: bool) -> void:
	current_node_id = node_id
	unlocked_nodes[node_id] = true

	if autosave:
		last_safe_autosave_node_id = node_id


func initialize_visit_history(node_id: String) -> void:
	visit_history.clear()
	committed_transitions.clear()
	if node_id != "":
		visit_history.append(node_id)
		history_cursor = 0
	else:
		history_cursor = -1


func commit_transition(source_node_id: String, target_node_id: String, choice_key: String = "") -> bool:
	if source_node_id == "" or target_node_id == "":
		return false
	if visit_history.is_empty():
		initialize_visit_history(source_node_id)
	if history_cursor != visit_history.size() - 1 or visit_history[history_cursor] != source_node_id:
		return false

	committed_transitions.append({
		"source_node_id": source_node_id,
		"target_node_id": target_node_id,
		"choice_key": choice_key,
		"history_index": history_cursor
	})
	visit_history.append(target_node_id)
	history_cursor = visit_history.size() - 1
	return true


func is_reviewing_history() -> bool:
	return history_cursor >= 0 and history_cursor < visit_history.size() - 1


func get_committed_transition_at(index: int) -> Dictionary:
	for transition in committed_transitions:
		if int(transition.get("history_index", -1)) == index:
			return transition.duplicate(true)
	return {}


func move_history_cursor(delta: int) -> String:
	if visit_history.is_empty():
		return ""
	history_cursor = clampi(history_cursor + delta, 0, visit_history.size() - 1)
	current_node_id = visit_history[history_cursor]
	return current_node_id


func move_history_cursor_to_node(node_id: String) -> String:
	for index in range(visit_history.size() - 1, -1, -1):
		if visit_history[index] == node_id:
			history_cursor = index
			current_node_id = node_id
			return node_id
	return ""


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

	var wall_clock_nonce: int = int(Time.get_unix_time_from_system() * 1000000.0)
	_keyword_id_nonce = maxi(_keyword_id_nonce + 1, wall_clock_nonce)
	var instance_id: String = "keyword_%s_%03d_%d" % [
		source_node_id,
		source_count,
		_keyword_id_nonce
	]

	while _issued_keyword_ids.has(instance_id):
		_keyword_id_nonce += 1
		instance_id = "keyword_%s_%03d_%d" % [source_node_id, source_count, _keyword_id_nonce]

	var instance: Dictionary = {
		"instance_id": instance_id,
		"text": normalized_text,
		"normalized_text": normalized_text,
		"source_node_id": source_node_id
	}

	keyword_instances.append(instance)
	_keyword_instances_by_key[keyword_key] = instance
	_issued_keyword_ids[instance_id] = true
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


func get_keyword_instances_by_normalized_text(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var normalized_text: String = normalize_keyword_text(text)

	if normalized_text == "":
		return result

	for instance in keyword_instances:
		if str(instance.get("normalized_text", "")) == normalized_text:
			result.append(instance.duplicate(true))

	return result


func is_keyword_instance_connected(instance_id: String) -> bool:
	if instance_id == "":
		return false
	var instance: Dictionary = _find_keyword_instance_ref(instance_id)

	if instance.is_empty():
		return false

	for connection in keyword_connections:
		if _connection_references_instance(connection, instance):
			return true

	return false


func can_remove_keyword(instance_id: String) -> Dictionary:
	if instance_id.strip_edges() == "":
		return {"allowed": false, "reason": "invalid_id"}

	if _find_keyword_instance_ref(instance_id).is_empty():
		return {"allowed": false, "reason": "not_found"}

	if is_keyword_instance_connected(instance_id):
		return {"allowed": false, "reason": "connected"}

	return {"allowed": true, "reason": "success"}


func remove_keyword(instance_id: String) -> Dictionary:
	var check: Dictionary = can_remove_keyword(instance_id)

	if not bool(check.get("allowed", false)):
		return {
			"success": false,
			"reason": str(check.get("reason", "not_found"))
		}

	for index in range(keyword_instances.size()):
		var instance: Dictionary = keyword_instances[index]

		if str(instance.get("instance_id", "")) != instance_id:
			continue

		var key: String = _keyword_key(
			str(instance.get("normalized_text", "")),
			str(instance.get("source_node_id", ""))
		)
		keyword_instances.remove_at(index)
		_keyword_instances_by_key.erase(key)
		return {"success": true, "reason": "success"}

	return {"success": false, "reason": "not_found"}


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
	var instance: Dictionary = _find_keyword_instance_ref(keyword_instance_id)

	if instance.is_empty():
		return result

	for connection in keyword_connections:
		if _connection_references_instance(connection, instance):
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


func to_save_dictionary() -> Dictionary:
	return {
		"current_node_id": current_node_id,
		"unlocked_nodes": unlocked_nodes.duplicate(true),
		"flags": flags.duplicate(true),
		"last_safe_autosave_node_id": last_safe_autosave_node_id,
		"keyword_instances": get_keyword_instances(),
		"keyword_connections": get_keyword_connections(),
		"keyword_unlocked_nodes": keyword_unlocked_nodes.duplicate(true),
		"visit_history": visit_history.duplicate(),
		"committed_transitions": committed_transitions.duplicate(true),
		"history_cursor": history_cursor,
		"graph_view": graph_view.duplicate(true)
	}


func validate_save_dictionary(data: Dictionary, emit_warning: bool = true) -> bool:
	var result := validate_save_dictionary_detailed(data)
	if not bool(result.get("valid", false)) and emit_warning:
		push_warning("CaseRuntimeState: " + str(result.get("error", "runtime state validation failed")))
	return bool(result.get("valid", false))


func validate_save_dictionary_detailed(data: Dictionary, root_path: String = "runtime_state") -> Dictionary:
	var required_fields: PackedStringArray = [
		"current_node_id",
		"unlocked_nodes",
		"flags",
		"last_safe_autosave_node_id",
		"keyword_instances",
		"keyword_connections",
		"keyword_unlocked_nodes"
	]

	for field in required_fields:
		if not data.has(field):
			return _validation_failure(root_path + "." + field, "required field", null, "field is missing")

	if not (data.get("current_node_id") is String) or str(data.get("current_node_id", "")) == "":
		return _validation_failure(root_path + ".current_node_id", "non-empty String", data.get("current_node_id"), "current node id is required")

	if not (data.get("last_safe_autosave_node_id") is String):
		return _validation_failure(root_path + ".last_safe_autosave_node_id", "String", data.get("last_safe_autosave_node_id"), "safe node id may be empty but must be a String")

	if not (data.get("flags") is Dictionary):
		return _validation_failure(root_path + ".flags", "Dictionary<String, bool>", data.get("flags"), "flags container is invalid")
	for flag_key in (data.get("flags", {}) as Dictionary).keys():
		if not (flag_key is String) or not ((data.get("flags", {}) as Dictionary)[flag_key] is bool):
			return _validation_failure(root_path + ".flags." + str(flag_key), "bool with String key", (data.get("flags", {}) as Dictionary)[flag_key], "flag values cannot be numeric")

	for dictionary_field in ["unlocked_nodes", "keyword_unlocked_nodes"]:
		var dictionary_value: Variant = data.get(dictionary_field)
		if not (dictionary_value is Dictionary):
			return _validation_failure(root_path + "." + dictionary_field, "Dictionary<String, bool>", dictionary_value, "container is invalid")
		for key_value in (dictionary_value as Dictionary).keys():
			if not (key_value is String) or not ((dictionary_value as Dictionary)[key_value] is bool):
				return _validation_failure(root_path + "." + dictionary_field + "." + str(key_value), "bool with String key", (dictionary_value as Dictionary)[key_value], "entry type is invalid")

	var unlocked: Dictionary = data.get("unlocked_nodes", {})
	var current_id: String = str(data.get("current_node_id", ""))

	if not unlocked.has(current_id):
		return _validation_failure(root_path + ".current_node_id", "node id present in unlocked_nodes", current_id, "current node is not unlocked")

	var safe_id: String = str(data.get("last_safe_autosave_node_id", ""))

	if safe_id != "" and not unlocked.has(safe_id):
		return _validation_failure(root_path + ".last_safe_autosave_node_id", "empty or unlocked node id", safe_id, "safe node is not unlocked")

	var raw_instances: Variant = data.get("keyword_instances")

	if not (raw_instances is Array):
		return _validation_failure(root_path + ".keyword_instances", "Array<Dictionary>", raw_instances, "keyword instances container is invalid")

	var keyword_ids: Dictionary = {}
	var keyword_keys: Dictionary = {}
	var keyword_ids_by_key: Dictionary = {}

	for instance_index in range((raw_instances as Array).size()):
		var raw_instance: Variant = (raw_instances as Array)[instance_index]
		var instance_path := "%s.keyword_instances[%d]" % [root_path, instance_index]
		if not (raw_instance is Dictionary):
			return _validation_failure(instance_path, "Dictionary", raw_instance, "keyword instance is invalid")

		var instance: Dictionary = raw_instance
		var instance_id: String = str(instance.get("instance_id", ""))
		var text: String = str(instance.get("text", ""))
		var normalized_text: String = str(instance.get("normalized_text", ""))
		var source_node_id: String = str(instance.get("source_node_id", ""))

		if instance_id == "" or text == "" or normalized_text == "" or source_node_id == "":
			return _validation_failure(instance_path, "instance_id/text/normalized_text/source_node_id as non-empty Strings", instance, "keyword instance is missing a required field")

		var keyword_key: String = _keyword_key(normalized_text, source_node_id)

		if keyword_ids.has(instance_id) or keyword_keys.has(keyword_key):
			return _validation_failure(instance_path + ".instance_id", "unique keyword id and source/text pair", instance_id, "keyword instance is duplicated")

		keyword_ids[instance_id] = true
		keyword_keys[keyword_key] = true
		keyword_ids_by_key[keyword_key] = instance_id

	var raw_connections: Variant = data.get("keyword_connections")

	if not (raw_connections is Array):
		return _validation_failure(root_path + ".keyword_connections", "Array<Dictionary>", raw_connections, "keyword connections container is invalid")

	var connection_ids: Dictionary = {}
	var connection_keys: Dictionary = {}

	for connection_index in range((raw_connections as Array).size()):
		var raw_connection: Variant = (raw_connections as Array)[connection_index]
		var connection_path := "%s.keyword_connections[%d]" % [root_path, connection_index]
		if not (raw_connection is Dictionary):
			return _validation_failure(connection_path, "Dictionary", raw_connection, "keyword connection is invalid")

		var connection: Dictionary = raw_connection
		var connection_id: String = str(connection.get("connection_id", ""))
		var keyword_instance_id: String = str(connection.get("keyword_instance_id", ""))
		var target_node_id: String = str(connection.get("target_node_id", ""))
		var outcome: String = str(connection.get("outcome", "")).to_lower()
		var legacy_source_node_id: String = str(connection.get("source_node_id", ""))
		var legacy_normalized_text: String = _connection_normalized_keyword(connection)

		if connection_id == "" or target_node_id == "":
			return _validation_failure(connection_path, "connection_id and target_node_id as non-empty Strings", connection, "keyword connection is missing a required field")

		if keyword_instance_id == "":
			keyword_instance_id = str(keyword_ids_by_key.get(
				_keyword_key(legacy_normalized_text, legacy_source_node_id),
				""
			))

		if outcome != "correct" or keyword_instance_id == "" or not keyword_ids.has(keyword_instance_id):
			return _validation_failure(connection_path + ".keyword_instance_id", "existing keyword instance with correct outcome", keyword_instance_id, "keyword connection reference is invalid")

		var connection_key: String = _keyword_connection_key(keyword_instance_id, target_node_id)

		if connection_ids.has(connection_id) or connection_keys.has(connection_key):
			return _validation_failure(connection_path + ".connection_id", "unique connection", connection_id, "keyword connection is duplicated")

		connection_ids[connection_id] = true
		connection_keys[connection_key] = true

	var raw_history_value: Variant = data.get("visit_history", [])
	if not (raw_history_value is Array):
		return _validation_failure(root_path + ".visit_history", "Array<String>", raw_history_value, "visit history container is invalid")
	var raw_history: Array = raw_history_value
	for history_index in range(raw_history.size()):
		if not (raw_history[history_index] is String) or str(raw_history[history_index]) == "":
			return _validation_failure("%s.visit_history[%d]" % [root_path, history_index], "non-empty String", raw_history[history_index], "history node id is invalid")

	var cursor_value: Variant = data.get("history_cursor", -1)
	if not _is_integer_number(cursor_value):
		return _validation_failure(root_path + ".history_cursor", "integer-valued number", cursor_value, "JSON numbers may be int or float")
	var cursor := int(cursor_value)
	if raw_history.is_empty():
		if cursor != -1:
			return _validation_failure(root_path + ".history_cursor", "-1 for empty history", cursor_value, "history cursor is out of range")
	elif cursor < 0 or cursor >= raw_history.size():
		return _validation_failure(root_path + ".history_cursor", "0 <= cursor < %d" % raw_history.size(), cursor_value, "history cursor is out of range")

	var transitions_value: Variant = data.get("committed_transitions", [])
	if not (transitions_value is Array):
		return _validation_failure(root_path + ".committed_transitions", "Array<Dictionary>", transitions_value, "committed transitions container is invalid")
	for transition_index in range((transitions_value as Array).size()):
		var transition_value: Variant = (transitions_value as Array)[transition_index]
		var transition_path := "%s.committed_transitions[%d]" % [root_path, transition_index]
		if not (transition_value is Dictionary):
			return _validation_failure(transition_path, "Dictionary", transition_value, "committed transition is invalid")
		var transition := transition_value as Dictionary
		for id_field in ["source_node_id", "target_node_id"]:
			if not (transition.get(id_field) is String) or str(transition.get(id_field, "")) == "":
				return _validation_failure(transition_path + "." + id_field, "non-empty String", transition.get(id_field), "transition node id is invalid")
		var index_value: Variant = transition.get("history_index")
		if not _is_integer_number(index_value):
			return _validation_failure(transition_path + ".history_index", "integer-valued number", index_value, "JSON numbers may be int or float")
		var source_index := int(index_value)
		if source_index < 0 or source_index + 1 >= raw_history.size():
			return _validation_failure(transition_path + ".history_index", "0 <= index < history_size - 1", index_value, "transition history index is out of range")
		if str(raw_history[source_index]) != str(transition.get("source_node_id")) or str(raw_history[source_index + 1]) != str(transition.get("target_node_id")):
			return _validation_failure(transition_path, "source/target matching adjacent visit_history entries", transition, "transition does not match visit history")

	var graph_value: Variant = data.get("graph_view", {"pan_x": 0.0, "pan_y": 0.0, "zoom": 1.0})
	if not (graph_value is Dictionary):
		return _validation_failure(root_path + ".graph_view", "Dictionary with pan_x/pan_y/zoom numbers", graph_value, "graph view container is invalid")
	for number_field in ["pan_x", "pan_y", "zoom"]:
		var number_value: Variant = (graph_value as Dictionary).get(number_field)
		if not _is_finite_number(number_value):
			return _validation_failure(root_path + ".graph_view." + number_field, "finite number", number_value, "graph view values must be JSON numbers")
	if float((graph_value as Dictionary).get("zoom", 1.0)) <= 0.0:
		return _validation_failure(root_path + ".graph_view.zoom", "number > 0", (graph_value as Dictionary).get("zoom"), "graph zoom must be positive")

	return {"valid": true, "status": "available", "error": ""}


func apply_save_dictionary(data: Dictionary) -> bool:
	if not validate_save_dictionary(data):
		return false

	var new_keyword_instances: Array[Dictionary] = []
	var raw_instances: Array = data.get("keyword_instances", [])

	for raw_instance in raw_instances:
		new_keyword_instances.append((raw_instance as Dictionary).duplicate(true))

	var new_keyword_connections: Array[Dictionary] = []
	var raw_connections: Array = data.get("keyword_connections", [])
	var instance_ids_by_key: Dictionary = {}

	for instance in new_keyword_instances:
		instance_ids_by_key[_keyword_key(
			str(instance.get("normalized_text", "")),
			str(instance.get("source_node_id", ""))
		)] = str(instance.get("instance_id", ""))

	for raw_connection in raw_connections:
		var connection: Dictionary = (raw_connection as Dictionary).duplicate(true)

		if str(connection.get("keyword_instance_id", "")) == "":
			var legacy_key: String = _keyword_key(
				_connection_normalized_keyword(connection),
				str(connection.get("source_node_id", ""))
			)
			connection["keyword_instance_id"] = str(instance_ids_by_key.get(legacy_key, ""))

		new_keyword_connections.append(connection)

	current_node_id = str(data.get("current_node_id", ""))
	unlocked_nodes = (data.get("unlocked_nodes", {}) as Dictionary).duplicate(true)
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	last_safe_autosave_node_id = str(data.get("last_safe_autosave_node_id", ""))
	keyword_instances = new_keyword_instances
	keyword_connections = new_keyword_connections
	keyword_unlocked_nodes = (data.get("keyword_unlocked_nodes", {}) as Dictionary).duplicate(true)
	visit_history.clear()
	committed_transitions.clear()
	if data.has("visit_history"):
		for node_value in (data.get("visit_history", []) as Array):
			visit_history.append(str(node_value))
		for transition_value in (data.get("committed_transitions", []) as Array):
			if transition_value is Dictionary:
				committed_transitions.append((transition_value as Dictionary).duplicate(true))
		history_cursor = int(data.get("history_cursor", visit_history.size() - 1))
	else:
		initialize_visit_history(current_node_id)
	var graph_value: Variant = data.get("graph_view", {"pan_x": 0.0, "pan_y": 0.0, "zoom": 1.0})
	graph_view = {
		"pan_x": float((graph_value as Dictionary).get("pan_x", 0.0)),
		"pan_y": float((graph_value as Dictionary).get("pan_y", 0.0)),
		"zoom": float((graph_value as Dictionary).get("zoom", 1.0))
	}
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
	visit_history.clear()
	committed_transitions.clear()
	history_cursor = -1
	graph_view = {"pan_x": 0.0, "pan_y": 0.0, "zoom": 1.0}
	_issued_keyword_ids.clear()
	_rebuild_runtime_indexes()


func _rebuild_runtime_indexes() -> void:
	_keyword_instances_by_key.clear()
	_keyword_counts_by_source.clear()
	_keyword_connections_by_key.clear()
	_keyword_connection_count = 0

	for instance in keyword_instances:
		var source_node_id: String = str(instance.get("source_node_id", ""))
		var normalized_text: String = str(instance.get("normalized_text", ""))
		var instance_id: String = str(instance.get("instance_id", ""))
		_keyword_instances_by_key[_keyword_key(normalized_text, source_node_id)] = instance
		_issued_keyword_ids[instance_id] = true
		_keyword_id_nonce = maxi(_keyword_id_nonce, _id_sequence(instance_id))
		_keyword_counts_by_source[source_node_id] = maxi(
			int(_keyword_counts_by_source.get(source_node_id, 0)),
			maxi(1, _keyword_instance_sequence(instance_id))
		)

	for connection in keyword_connections:
		var keyword_instance_id: String = str(connection.get("keyword_instance_id", ""))

		if keyword_instance_id == "":
			keyword_instance_id = str((_keyword_instances_by_key.get(
				_keyword_key(
					_connection_normalized_keyword(connection),
					str(connection.get("source_node_id", ""))
				),
				{}
			) as Dictionary).get("instance_id", ""))
			connection["keyword_instance_id"] = keyword_instance_id

		var target_node_id: String = str(connection.get("target_node_id", ""))
		var connection_id: String = str(connection.get("connection_id", ""))
		_keyword_connections_by_key[
			_keyword_connection_key(keyword_instance_id, target_node_id)
		] = connection
		_keyword_connection_count = maxi(_keyword_connection_count, _id_sequence(connection_id))

func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if not (value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and floorf(number) == number


func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)


func _validation_failure(path: String, expected: String, actual: Variant, reason: String) -> Dictionary:
	var actual_type := "missing" if actual == null else type_string(typeof(actual))
	var summary := "<missing>" if actual == null else str(actual)
	if summary.length() > 140:
		summary = summary.left(137) + "..."
	return {
		"valid": false,
		"status": "corrupted",
		"path": path,
		"expected": expected,
		"actual_type": actual_type,
		"actual_summary": summary,
		"reason": reason,
		"error": "%s: expected %s, got %s, value=%s; %s" % [
			path, expected, actual_type, summary, reason
		]
	}


func _id_sequence(id_value: String) -> int:
	var parts: PackedStringArray = id_value.split("_", false)

	if parts.is_empty():
		return 0

	var last_part: String = parts[parts.size() - 1]
	return int(last_part) if last_part.is_valid_int() else 0


func _keyword_instance_sequence(instance_id: String) -> int:
	var parts: PackedStringArray = instance_id.split("_", false)

	if parts.size() >= 2:
		var last_part: String = parts[parts.size() - 1]
		var previous_part: String = parts[parts.size() - 2]

		if last_part.is_valid_int() and previous_part.is_valid_int() and last_part.length() > 3:
			return int(previous_part)

	return _id_sequence(instance_id)


func _keyword_key(normalized_text: String, source_node_id: String) -> String:
	return source_node_id + "\u001f" + normalized_text


func _keyword_connection_key(keyword_instance_id: String, target_node_id: String) -> String:
	return keyword_instance_id + "\u001f" + target_node_id


func _find_keyword_instance_ref(instance_id: String) -> Dictionary:
	for instance in keyword_instances:
		if str(instance.get("instance_id", "")) == instance_id:
			return instance

	return {}


func _connection_references_instance(connection: Dictionary, instance: Dictionary) -> bool:
	var connection_instance_id: String = str(connection.get("keyword_instance_id", ""))

	if connection_instance_id != "":
		return connection_instance_id == str(instance.get("instance_id", ""))

	return (
		str(connection.get("source_node_id", "")) == str(instance.get("source_node_id", ""))
		and _connection_normalized_keyword(connection) == str(instance.get("normalized_text", ""))
	)


func _connection_normalized_keyword(connection: Dictionary) -> String:
	var text: String = str(connection.get(
		"normalized_keyword",
		connection.get("normalized_text", connection.get("keyword_text", ""))
	))
	return normalize_keyword_text(text)
