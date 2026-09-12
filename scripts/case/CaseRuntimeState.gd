extends RefCounted
class_name CaseRuntimeState

const MAX_KEYWORD_LENGTH: int = 24

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
var discovered_contacts: Array[String] = ["assistant"]
var active_call: Dictionary = {}
var revealed_node_ids: Array[String] = []
var revealed_section_ids: Array[String] = []
var active_text_reveal: Dictionary = {}
var completed_after_reveal_events: Array[String] = []
var tutorial_attention_audio_counts: Dictionary = {}
var case_state: Dictionary = {}
var history_snapshots: Array[Dictionary] = []
var active_transition_indices: Array[int] = []
# Optional investigation-time capability. Legacy cases keep investigation_time
# at -1 and never consult these fields.
var investigation_time: int = -1
var assistant_state: Dictionary = {}
var police_state: Dictionary = {}
var active_actions: Array[Dictionary] = []
var completed_actions: Array[String] = []
var action_history: Array[Dictionary] = []
var event_flags: Dictionary = {}
var pollution_node_states: Dictionary = {}
var witness_protected: bool = false
var killer_alerted: bool = false
var killer_controlled: bool = false

const NON_REWINDABLE_FLAG_IDS := {
	"tutorial_assistant_call_completed": true,
	"tutorial_backtrack_learned": true,
	"inspect_bag_option_unlocked": true,
	"tutorial_backtrack_hint_shown": true,
	"tutorial_keyword_popup_shown": true,
	"tutorial_keyword_popup_open": true,
	"tutorial_keyword_recording_learned": true,
	"tutorial_glue_mark_recorded": true,
	"tutorial_inspect_bag_choice_visible": true,
	"tutorial_glue_keyword_hint_visible": true,
	"tutorial_graph_attention_ready": true,
	"tutorial_graph_attention_completed": true,
	"tutorial_thread_fade_hint_visible": true,
	"tutorial_attention_graph_first_ready": true,
	"tutorial_attention_graph_first_completed": true,
	"tutorial_attention_graph_final_ready": true,
	"tutorial_attention_graph_final_completed": true,
	"tutorial_attention_phonebook_ready": true,
	"tutorial_attention_phonebook_completed": true,
	"tutorial_attention_call_erin_ready": true,
	"tutorial_attention_call_erin_completed": true
}

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
	history_snapshots.clear()
	active_transition_indices.clear()
	if node_id != "":
		visit_history.append(node_id)
		history_snapshots.append({})
		history_cursor = 0
	else:
		history_cursor = -1


func commit_transition(source_node_id: String, target_node_id: String, choice_key: String = "") -> bool:
	if source_node_id == "" or target_node_id == "":
		return false
	if visit_history.is_empty():
		initialize_visit_history(source_node_id)
	if history_cursor < 0 or history_cursor >= visit_history.size() or visit_history[history_cursor] != source_node_id:
		return false
	if history_cursor != visit_history.size() - 1:
		# Keep the old branch as immutable history. A new branch begins with a
		# duplicate source entry at the end; this is a navigation jump, not a
		# narrative edge, so no transition is created for it.
		var branch_snapshot := _make_rewind_snapshot()
		visit_history.append(source_node_id)
		history_snapshots.append(branch_snapshot)
		history_cursor = visit_history.size() - 1

	var transition_index := history_cursor
	committed_transitions.append({
		"source_node_id": source_node_id,
		"target_node_id": target_node_id,
		"choice_key": choice_key,
		"history_index": transition_index
	})
	visit_history.append(target_node_id)
	history_snapshots.append({})
	history_cursor = visit_history.size() - 1
	if not active_transition_indices.has(transition_index):
		active_transition_indices.append(transition_index)
	return true


func capture_history_snapshot(index: int = history_cursor) -> void:
	if index < 0 or index >= visit_history.size():
		return
	while history_snapshots.size() < visit_history.size():
		history_snapshots.append({})
	history_snapshots[index] = _make_rewind_snapshot()


func restore_history_snapshot(index: int) -> bool:
	if index < 0 or index >= visit_history.size():
		return false
	history_cursor = index
	current_node_id = visit_history[index]
	if index < history_snapshots.size() and not history_snapshots[index].is_empty():
		_apply_rewind_snapshot(history_snapshots[index])
	else:
		active_transition_indices = _infer_active_transition_indices(index)
	return true


func get_active_transition_indices() -> Array[int]:
	return active_transition_indices.duplicate()


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
	restore_history_snapshot(clampi(history_cursor + delta, 0, visit_history.size() - 1))
	return current_node_id


func move_history_cursor_to_node(node_id: String) -> String:
	for index in range(visit_history.size() - 1, -1, -1):
		if visit_history[index] == node_id:
			restore_history_snapshot(index)
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
		"graph_view": graph_view.duplicate(true),
		"discovered_contacts": discovered_contacts.duplicate(),
		"active_call": active_call.duplicate(true),
		"revealed_node_ids": revealed_node_ids.duplicate(),
		"revealed_section_ids": revealed_section_ids.duplicate(),
		"active_text_reveal": active_text_reveal.duplicate(true),
		"completed_after_reveal_events": completed_after_reveal_events.duplicate(),
		"tutorial_attention_audio_counts": tutorial_attention_audio_counts.duplicate(true),
		"case_state": case_state.duplicate(true),
		"history_snapshots": history_snapshots.duplicate(true),
		"active_transition_indices": active_transition_indices.duplicate(),
		"investigation_time": investigation_time,
		"assistant_state": assistant_state.duplicate(true),
		"police_state": police_state.duplicate(true),
		"active_actions": active_actions.duplicate(true),
		"completed_actions": completed_actions.duplicate(),
		"action_history": action_history.duplicate(true),
		"event_flags": event_flags.duplicate(true),
		"pollution_node_states": pollution_node_states.duplicate(true),
		"witness_protected": witness_protected,
		"killer_alerted": killer_alerted,
		"killer_controlled": killer_controlled
	}


func set_persistent_flag(flag_id: String, value: bool = true) -> void:
	if flag_id != "":
		flags[flag_id] = value


func set_case_state_values(values: Dictionary) -> void:
	for key_value in values.keys():
		var key := str(key_value)
		if key != "":
			case_state[key] = values[key_value]


func enable_investigation_time(start_time: int) -> void:
	if investigation_time < 0:
		investigation_time = start_time
	if assistant_state.is_empty():
		assistant_state = _idle_actor_state("assistant")
	if police_state.is_empty():
		police_state = _idle_actor_state("police")


func _idle_actor_state(actor_id: String) -> Dictionary:
	return {
		"actor_id": actor_id,
		"status": "idle",
		"current_action": "",
		"start_time": -1,
		"complete_time": -1,
		"remaining_time": 0
	}


func _make_rewind_snapshot() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"case_state": case_state.duplicate(true),
		"unlocked_nodes": unlocked_nodes.duplicate(true),
		"last_safe_autosave_node_id": last_safe_autosave_node_id,
		"keyword_instances": keyword_instances.duplicate(true),
		"keyword_connections": keyword_connections.duplicate(true),
		"keyword_unlocked_nodes": keyword_unlocked_nodes.duplicate(true),
		"active_transition_indices": active_transition_indices.duplicate()
	}


func _apply_rewind_snapshot(snapshot: Dictionary) -> void:
	var permanent_values: Dictionary = {}
	for flag_value in flags.keys():
		var flag_id := str(flag_value)
		if _is_non_rewindable_flag(flag_id):
			permanent_values[flag_id] = flags[flag_value]
	flags = (snapshot.get("flags", {}) as Dictionary).duplicate(true)
	for flag_id in permanent_values.keys():
		flags[flag_id] = permanent_values[flag_id]
	case_state = (snapshot.get("case_state", {}) as Dictionary).duplicate(true)
	unlocked_nodes = (snapshot.get("unlocked_nodes", {}) as Dictionary).duplicate(true)
	last_safe_autosave_node_id = str(snapshot.get("last_safe_autosave_node_id", ""))
	keyword_instances = (snapshot.get("keyword_instances", []) as Array).duplicate(true)
	keyword_connections = (snapshot.get("keyword_connections", []) as Array).duplicate(true)
	keyword_unlocked_nodes = (snapshot.get("keyword_unlocked_nodes", {}) as Dictionary).duplicate(true)
	active_transition_indices.clear()
	for index_value in (snapshot.get("active_transition_indices", []) as Array):
		active_transition_indices.append(int(index_value))
	_rebuild_runtime_indexes()


func _is_non_rewindable_flag(flag_id: String) -> bool:
	return (
		NON_REWINDABLE_FLAG_IDS.has(flag_id)
		or flag_id.begins_with("tutorial_hint_seen_")
		or flag_id.begins_with("failure_hint_seen_")
	)


func _infer_active_transition_indices(cursor: int) -> Array[int]:
	var result: Array[int] = []
	var node_stack: Array[String] = []
	var edge_stack: Array[int] = []
	if visit_history.is_empty() or cursor < 0:
		return result
	node_stack.append(visit_history[0])
	for target_history_index in range(1, mini(cursor, visit_history.size() - 1) + 1):
		var transition_index := target_history_index - 1
		var transition := get_committed_transition_at(transition_index)
		if transition.is_empty():
			# A missing edge denotes a branch jump back to this historical node.
			var branch_node := visit_history[target_history_index]
			var branch_stack_index := node_stack.rfind(branch_node)
			if branch_stack_index >= 0:
				while node_stack.size() > branch_stack_index + 1:
					node_stack.pop_back()
				while edge_stack.size() > branch_stack_index:
					edge_stack.pop_back()
			continue
		node_stack.append(visit_history[target_history_index])
		edge_stack.append(transition_index)
	for edge_index in edge_stack:
		result.append(edge_index)
	return result


func add_discovered_contact(contact_id: String) -> bool:
	var normalized_id := contact_id.strip_edges()
	if normalized_id == "" or discovered_contacts.has(normalized_id):
		return false
	discovered_contacts.append(normalized_id)
	return true


func has_discovered_contact(contact_id: String) -> bool:
	return discovered_contacts.has(contact_id)


func mark_node_revealed(node_id: String) -> bool:
	if node_id == "" or revealed_node_ids.has(node_id):
		return false
	revealed_node_ids.append(node_id)
	return true


func is_node_revealed(node_id: String) -> bool:
	return revealed_node_ids.has(node_id)


func mark_section_revealed(section_id: String) -> bool:
	if section_id == "" or revealed_section_ids.has(section_id):
		return false
	revealed_section_ids.append(section_id)
	return true


func is_section_revealed(section_id: String) -> bool:
	return revealed_section_ids.has(section_id)


func get_attention_audio_count(event_id: String) -> int:
	return 1 if int(tutorial_attention_audio_counts.get(event_id, 0)) >= 1 else 0


func record_attention_audio_peak(event_id: String) -> int:
	if event_id == "":
		return 0
	tutorial_attention_audio_counts[event_id] = 1
	return 1


func mark_after_reveal_event_completed(event_id: String) -> bool:
	if event_id == "" or completed_after_reveal_events.has(event_id):
		return false
	completed_after_reveal_events.append(event_id)
	return true


func is_after_reveal_event_completed(event_id: String) -> bool:
	return completed_after_reveal_events.has(event_id)


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

	var contacts_value: Variant = data.get("discovered_contacts", ["assistant"])
	if not (contacts_value is Array):
		return _validation_failure(root_path + ".discovered_contacts", "Array<String>", contacts_value, "discovered contacts container is invalid")
	var contact_ids: Dictionary = {}
	for contact_index in range((contacts_value as Array).size()):
		var contact_value: Variant = (contacts_value as Array)[contact_index]
		if not (contact_value is String) or str(contact_value) == "" or contact_ids.has(str(contact_value)):
			return _validation_failure("%s.discovered_contacts[%d]" % [root_path, contact_index], "unique non-empty String", contact_value, "contact id is invalid or duplicated")
		contact_ids[str(contact_value)] = true

	var call_value: Variant = data.get("active_call", {})
	if not (call_value is Dictionary):
		return _validation_failure(root_path + ".active_call", "Dictionary", call_value, "active call container is invalid")
	var saved_call: Dictionary = call_value
	if not saved_call.is_empty():
		for string_field in ["call_id", "contact_id", "direction", "status", "message_id", "waiting_for_keyword"]:
			if not (saved_call.get(string_field, "") is String):
				return _validation_failure(root_path + ".active_call." + string_field, "String", saved_call.get(string_field), "active call text field is invalid")
		if str(saved_call.get("call_id", "")) == "" or str(saved_call.get("contact_id", "")) == "":
			return _validation_failure(root_path + ".active_call", "call_id/contact_id as non-empty Strings", saved_call, "active call identity is incomplete")
		if str(saved_call.get("status", "")) not in ["incoming_waiting", "outgoing_waiting", "active", "ending"]:
			return _validation_failure(root_path + ".active_call.status", "incoming_waiting, outgoing_waiting, active, or ending", saved_call.get("status"), "active call status is invalid")
		for array_field in ["transcript", "choices_made", "presented_choices"]:
			if not (saved_call.get(array_field, []) is Array):
				return _validation_failure(root_path + ".active_call." + array_field, "Array", saved_call.get(array_field), "active call list is invalid")
		if not (saved_call.get("is_waiting_message", false) is bool):
			return _validation_failure(root_path + ".active_call.is_waiting_message", "bool", saved_call.get("is_waiting_message"), "message scheduling flag is invalid")
		if not (saved_call.get("pending_message_id", "") is String):
			return _validation_failure(root_path + ".active_call.pending_message_id", "String", saved_call.get("pending_message_id"), "pending message id is invalid")
		for delay_field in ["transcript_delay_elapsed", "transcript_delay_total"]:
			var delay_value: Variant = saved_call.get(delay_field, 0.0)
			if not _is_finite_number(delay_value) or float(delay_value) < 0.0:
				return _validation_failure(root_path + ".active_call." + delay_field, "finite number >= 0", delay_value, "message scheduling delay is invalid")
		if float(saved_call.get("transcript_delay_elapsed", 0.0)) > float(saved_call.get("transcript_delay_total", 0.0)):
			return _validation_failure(root_path + ".active_call.transcript_delay_elapsed", "number <= transcript_delay_total", saved_call.get("transcript_delay_elapsed"), "message scheduling elapsed time exceeds total delay")
		for optional_string_field in ["revealing_message_id", "voice_profile_id", "pending_choice_next", "pending_choice_id"]:
			if not (saved_call.get(optional_string_field, "") is String):
				return _validation_failure(root_path + ".active_call." + optional_string_field, "String", saved_call.get(optional_string_field), "phone reveal text field is invalid")
		for optional_bool_field in ["message_reveal_completed", "pending_choice_end_call"]:
			if not (saved_call.get(optional_bool_field, false) is bool):
				return _validation_failure(root_path + ".active_call." + optional_bool_field, "bool", saved_call.get(optional_bool_field), "phone reveal flag is invalid")
		for optional_integer_field in ["revealing_transcript_index", "message_visible_characters"]:
			var integer_value: Variant = saved_call.get(optional_integer_field, -1 if optional_integer_field == "revealing_transcript_index" else 0)
			if not _is_integer_number(integer_value) or int(integer_value) < (-1 if optional_integer_field == "revealing_transcript_index" else 0):
				return _validation_failure(root_path + ".active_call." + optional_integer_field, "integer in valid reveal range", integer_value, "phone reveal position is invalid")
		var reveal_elapsed_value: Variant = saved_call.get("message_reveal_elapsed", 0.0)
		if not _is_finite_number(reveal_elapsed_value) or float(reveal_elapsed_value) < 0.0:
			return _validation_failure(root_path + ".active_call.message_reveal_elapsed", "finite number >= 0", reveal_elapsed_value, "phone reveal elapsed time is invalid")
		if not (saved_call.get("pending_choice_effects", []) is Array):
			return _validation_failure(root_path + ".active_call.pending_choice_effects", "Array", saved_call.get("pending_choice_effects"), "pending choice effects are invalid")
		for end_bool_field in ["call_end_sequence_active", "call_end_audio_started", "call_end_audio_completed"]:
			if not (saved_call.get(end_bool_field, false) is bool):
				return _validation_failure(root_path + ".active_call." + end_bool_field, "bool", saved_call.get(end_bool_field), "call ending flag is invalid")
		var end_elapsed_value: Variant = saved_call.get("call_end_elapsed", 0.0)
		if not _is_finite_number(end_elapsed_value) or float(end_elapsed_value) < 0.0:
			return _validation_failure(root_path + ".active_call.call_end_elapsed", "finite number >= 0", end_elapsed_value, "call ending elapsed time is invalid")
		if not (saved_call.get("call_end_next_node_id", "") is String):
			return _validation_failure(root_path + ".active_call.call_end_next_node_id", "String", saved_call.get("call_end_next_node_id"), "call ending target is invalid")

	var revealed_value: Variant = data.get("revealed_node_ids", data.get("visit_history", []))
	if not (revealed_value is Array):
		return _validation_failure(root_path + ".revealed_node_ids", "Array<String>", revealed_value, "revealed node container is invalid")
	var revealed_ids: Dictionary = {}
	for revealed_index in range((revealed_value as Array).size()):
		var revealed_id_value: Variant = (revealed_value as Array)[revealed_index]
		if not (revealed_id_value is String) or str(revealed_id_value) == "" or revealed_ids.has(str(revealed_id_value)):
			return _validation_failure("%s.revealed_node_ids[%d]" % [root_path, revealed_index], "unique non-empty String", revealed_id_value, "revealed node id is invalid or duplicated")
		revealed_ids[str(revealed_id_value)] = true

	var revealed_sections_value: Variant = data.get("revealed_section_ids", [])
	if not (revealed_sections_value is Array):
		return _validation_failure(root_path + ".revealed_section_ids", "Array<String>", revealed_sections_value, "revealed section container is invalid")
	var revealed_section_keys: Dictionary = {}
	for section_index in range((revealed_sections_value as Array).size()):
		var section_value: Variant = (revealed_sections_value as Array)[section_index]
		if not (section_value is String) or str(section_value) == "" or revealed_section_keys.has(str(section_value)):
			return _validation_failure("%s.revealed_section_ids[%d]" % [root_path, section_index], "unique non-empty String", section_value, "revealed section id is invalid or duplicated")
		revealed_section_keys[str(section_value)] = true

	var reveal_state_value: Variant = data.get("active_text_reveal", {})
	if not (reveal_state_value is Dictionary):
		return _validation_failure(root_path + ".active_text_reveal", "Dictionary", reveal_state_value, "active text reveal state is invalid")
	var reveal_state: Dictionary = reveal_state_value
	if not reveal_state.is_empty():
		if not (reveal_state.get("node_id", "") is String) or str(reveal_state.get("node_id", "")) == "":
			return _validation_failure(root_path + ".active_text_reveal.node_id", "non-empty String", reveal_state.get("node_id"), "active reveal node is invalid")
		for reveal_integer_field in ["section_index", "visible_characters"]:
			var reveal_integer_value: Variant = reveal_state.get(reveal_integer_field, 0)
			if not _is_integer_number(reveal_integer_value) or int(reveal_integer_value) < 0:
				return _validation_failure(root_path + ".active_text_reveal." + reveal_integer_field, "integer >= 0", reveal_integer_value, "active reveal position is invalid")
		for reveal_number_field in ["character_elapsed", "post_reveal_elapsed", "post_delay_total"]:
			var reveal_number_value: Variant = reveal_state.get(reveal_number_field, 0.0)
			if not _is_finite_number(reveal_number_value) or float(reveal_number_value) < 0.0:
				return _validation_failure(root_path + ".active_text_reveal." + reveal_number_field, "finite number >= 0", reveal_number_value, "active reveal timer is invalid")
		for reveal_bool_field in ["completed", "waiting_after_reveal", "events_completed"]:
			if not (reveal_state.get(reveal_bool_field, false) is bool):
				return _validation_failure(root_path + ".active_text_reveal." + reveal_bool_field, "bool", reveal_state.get(reveal_bool_field), "active reveal flag is invalid")
		if not (reveal_state.get("reveal_section_id", "") is String):
			return _validation_failure(root_path + ".active_text_reveal.reveal_section_id", "String", reveal_state.get("reveal_section_id"), "active reveal section id is invalid")

	var completed_events_value: Variant = data.get("completed_after_reveal_events", [])
	if not (completed_events_value is Array):
		return _validation_failure(root_path + ".completed_after_reveal_events", "Array<String>", completed_events_value, "completed event container is invalid")
	var completed_event_ids: Dictionary = {}
	for event_index in range((completed_events_value as Array).size()):
		var event_value: Variant = (completed_events_value as Array)[event_index]
		if not (event_value is String) or str(event_value) == "" or completed_event_ids.has(str(event_value)):
			return _validation_failure("%s.completed_after_reveal_events[%d]" % [root_path, event_index], "unique non-empty String", event_value, "completed event id is invalid or duplicated")
		completed_event_ids[str(event_value)] = true

	var attention_counts_value: Variant = data.get("tutorial_attention_audio_counts", {})
	if not (attention_counts_value is Dictionary):
		return _validation_failure(root_path + ".tutorial_attention_audio_counts", "Dictionary<String, int>", attention_counts_value, "tutorial attention audio state is invalid")
	for attention_key_value in (attention_counts_value as Dictionary).keys():
		var count_value: Variant = (attention_counts_value as Dictionary)[attention_key_value]
		if not (attention_key_value is String) or str(attention_key_value) == "" or not _is_integer_number(count_value) or int(count_value) < 0 or int(count_value) > 3:
			return _validation_failure(root_path + ".tutorial_attention_audio_counts." + str(attention_key_value), "integer 0..3 with non-empty String key", count_value, "tutorial attention audio count is invalid")

	if not (data.get("case_state", {}) is Dictionary):
		return _validation_failure(root_path + ".case_state", "Dictionary", data.get("case_state"), "rewindable case state is invalid")
	var snapshots_value: Variant = data.get("history_snapshots", [])
	if not (snapshots_value is Array):
		return _validation_failure(root_path + ".history_snapshots", "Array<Dictionary>", snapshots_value, "history snapshots are invalid")
	if not (snapshots_value as Array).is_empty() and (snapshots_value as Array).size() != raw_history.size():
		return _validation_failure(root_path + ".history_snapshots", "empty or aligned with visit_history", snapshots_value, "history snapshots are not aligned")
	for snapshot_index in range((snapshots_value as Array).size()):
		if not ((snapshots_value as Array)[snapshot_index] is Dictionary):
			return _validation_failure("%s.history_snapshots[%d]" % [root_path, snapshot_index], "Dictionary", (snapshots_value as Array)[snapshot_index], "history snapshot is invalid")
	var active_indices_value: Variant = data.get("active_transition_indices", [])
	if not (active_indices_value is Array):
		return _validation_failure(root_path + ".active_transition_indices", "Array<int>", active_indices_value, "active path indices are invalid")
	for active_value in (active_indices_value as Array):
		if not _is_integer_number(active_value) or int(active_value) < 0:
			return _validation_failure(root_path + ".active_transition_indices", "non-negative integer entries", active_value, "active path index is invalid")

	var investigation_time_value: Variant = data.get("investigation_time", -1)
	if not _is_integer_number(investigation_time_value) or int(investigation_time_value) < -1:
		return _validation_failure(root_path + ".investigation_time", "integer >= -1", investigation_time_value, "investigation time is invalid")
	for dictionary_field in ["assistant_state", "police_state", "event_flags", "pollution_node_states"]:
		if not (data.get(dictionary_field, {}) is Dictionary):
			return _validation_failure(root_path + "." + dictionary_field, "Dictionary", data.get(dictionary_field), "optional investigation state is invalid")
	if not (data.get("active_actions", []) is Array) or not (data.get("completed_actions", []) is Array) or not (data.get("action_history", []) is Array):
		return _validation_failure(root_path + ".active_actions", "Array action state", data.get("active_actions"), "optional action state is invalid")
	for history_value in (data.get("action_history", []) as Array):
		if not (history_value is Dictionary):
			return _validation_failure(root_path + ".action_history", "Array<Dictionary>", history_value, "action history entry is invalid")
	var completed_action_ids: Dictionary = {}
	for completed_value in (data.get("completed_actions", []) as Array):
		if not (completed_value is String) or str(completed_value) == "" or completed_action_ids.has(str(completed_value)):
			return _validation_failure(root_path + ".completed_actions", "unique non-empty String entries", completed_value, "completed action id is invalid")
		completed_action_ids[str(completed_value)] = true
	for bool_field in ["witness_protected", "killer_alerted", "killer_controlled"]:
		if not (data.get(bool_field, false) is bool):
			return _validation_failure(root_path + "." + bool_field, "bool", data.get(bool_field), "optional investigation flag is invalid")

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
	discovered_contacts.clear()
	var saved_contacts: Variant = data.get("discovered_contacts", ["assistant"])
	for contact_value in (saved_contacts as Array):
		var contact_id := str(contact_value)
		if contact_id != "" and not discovered_contacts.has(contact_id):
			discovered_contacts.append(contact_id)
	if not discovered_contacts.has("assistant"):
		discovered_contacts.push_front("assistant")
	active_call = (data.get("active_call", {}) as Dictionary).duplicate(true)
	revealed_node_ids.clear()
	var saved_revealed: Variant = data.get("revealed_node_ids", visit_history)
	for node_value in (saved_revealed as Array):
		var revealed_id := str(node_value)
		if revealed_id != "" and not revealed_node_ids.has(revealed_id):
			revealed_node_ids.append(revealed_id)
	revealed_section_ids.clear()
	for section_value in (data.get("revealed_section_ids", []) as Array):
		var section_id := str(section_value)
		if section_id != "" and not revealed_section_ids.has(section_id):
			revealed_section_ids.append(section_id)
	active_text_reveal = (data.get("active_text_reveal", {}) as Dictionary).duplicate(true)
	completed_after_reveal_events.clear()
	for event_value in (data.get("completed_after_reveal_events", []) as Array):
		var event_id := str(event_value)
		if event_id != "" and not completed_after_reveal_events.has(event_id):
			completed_after_reveal_events.append(event_id)
	tutorial_attention_audio_counts.clear()
	for attention_event_value in (data.get("tutorial_attention_audio_counts", {}) as Dictionary).keys():
		var attention_event_id := str(attention_event_value)
		if attention_event_id != "" and int((data.get("tutorial_attention_audio_counts", {}) as Dictionary)[attention_event_value]) >= 1:
			tutorial_attention_audio_counts[attention_event_id] = 1
	case_state = (data.get("case_state", {}) as Dictionary).duplicate(true)
	history_snapshots.clear()
	var saved_snapshots: Variant = data.get("history_snapshots", [])
	if saved_snapshots is Array and not (saved_snapshots as Array).is_empty():
		for snapshot_value in (saved_snapshots as Array):
			history_snapshots.append((snapshot_value as Dictionary).duplicate(true))
	else:
		for _history_entry in visit_history:
			history_snapshots.append({})
	active_transition_indices.clear()
	var saved_active_indices: Variant = data.get("active_transition_indices", [])
	if saved_active_indices is Array and not (saved_active_indices as Array).is_empty():
		for index_value in (saved_active_indices as Array):
			active_transition_indices.append(int(index_value))
	else:
		active_transition_indices = _infer_active_transition_indices(history_cursor)
	investigation_time = int(data.get("investigation_time", -1))
	assistant_state = (data.get("assistant_state", {}) as Dictionary).duplicate(true)
	police_state = (data.get("police_state", {}) as Dictionary).duplicate(true)
	active_actions.clear()
	for action_value in (data.get("active_actions", []) as Array):
		if action_value is Dictionary:
			active_actions.append((action_value as Dictionary).duplicate(true))
	completed_actions.clear()
	for action_value in (data.get("completed_actions", []) as Array):
		var action_id := str(action_value)
		if action_id != "" and not completed_actions.has(action_id):
			completed_actions.append(action_id)
	action_history.clear()
	for action_value in (data.get("action_history", []) as Array):
		if action_value is Dictionary:
			action_history.append((action_value as Dictionary).duplicate(true))
	event_flags = (data.get("event_flags", {}) as Dictionary).duplicate(true)
	pollution_node_states = (data.get("pollution_node_states", {}) as Dictionary).duplicate(true)
	witness_protected = bool(data.get("witness_protected", false))
	killer_alerted = bool(data.get("killer_alerted", false))
	killer_controlled = bool(data.get("killer_controlled", false))
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
	discovered_contacts = ["assistant"]
	active_call.clear()
	revealed_node_ids.clear()
	revealed_section_ids.clear()
	active_text_reveal.clear()
	completed_after_reveal_events.clear()
	tutorial_attention_audio_counts.clear()
	case_state.clear()
	history_snapshots.clear()
	active_transition_indices.clear()
	investigation_time = -1
	assistant_state.clear()
	police_state.clear()
	active_actions.clear()
	completed_actions.clear()
	action_history.clear()
	event_flags.clear()
	pollution_node_states.clear()
	witness_protected = false
	killer_alerted = false
	killer_controlled = false
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
