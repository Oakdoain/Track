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
const NODE_ID_ALIASES := {
	"tutorial_00": {
		"tutorial_0012_a": "tutorial_0011",
		"tutorial_0013": "tutorial_0012",
		"tutorial_0002a": "tutorial_0014",
		"tutorial_0002b": "tutorial_0014",
		"tutorial_0002c": "tutorial_0014",
		"tutorial_0002d": "tutorial_0014",
		"tutorial_0003": "tutorial_0014",
		"tutorial_0004": "tutorial_0014",
		"tutorial_0005": "tutorial_0014",
		"tutorial_0006": "tutorial_0014",
		"tutorial_0007": "tutorial_0014",
		"tutorial_0007s": "tutorial_0014",
		"tutorial_0008e": "tutorial_0014",
		"tutorial_0009": "tutorial_0014",
		"tutorial_0009a": "tutorial_0014",
		"tutorial_0009b": "tutorial_0014",
		"tutorial_0010": "tutorial_0017",
		"tutorial_inference_file_change": "tutorial_0014",
		"tutorial_inference_seal": "tutorial_0014",
		"tutorial_hypothesis_admin": "tutorial_0014",
		"tutorial_inference_final": "tutorial_0014"
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
	if not runtime.has("discovered_contacts"):
		runtime["discovered_contacts"] = ["assistant"]
	if not runtime.has("active_call"):
		runtime["active_call"] = {}
	if not runtime.has("revealed_node_ids"):
		var legacy_history_value: Variant = runtime.get("visit_history", [])
		runtime["revealed_node_ids"] = (legacy_history_value as Array).duplicate() if legacy_history_value is Array else []
	if not runtime.has("revealed_section_ids"):
		var inferred_sections: Array[String] = []
		var legacy_flags_value: Variant = runtime.get("flags", {})
		var legacy_flags: Dictionary = legacy_flags_value if legacy_flags_value is Dictionary else {}
		if bool(legacy_flags.get("tutorial_inspect_bag_choice_visible", false)):
			inferred_sections.append("tutorial_backtrack_reassurance")
		if bool(legacy_flags.get("tutorial_graph_attention_ready", false)) or bool(legacy_flags.get("tutorial_graph_attention_completed", false)):
			inferred_sections.append("tutorial_after_glue_keyword")
		runtime["revealed_section_ids"] = inferred_sections
	if not runtime.has("active_text_reveal"):
		runtime["active_text_reveal"] = {}
	if not runtime.has("completed_after_reveal_events"):
		runtime["completed_after_reveal_events"] = []
	var attention_audio_changed := false
	if not runtime.has("tutorial_attention_audio_counts"):
		attention_audio_changed = true
		var inferred_attention_counts: Dictionary = {}
		var attention_flags_value: Variant = runtime.get("flags", {})
		var attention_flags: Dictionary = attention_flags_value if attention_flags_value is Dictionary else {}
		if bool(attention_flags.get("tutorial_backtrack_hint_shown", false)):
			inferred_attention_counts["tutorial_attention_backtrack"] = 1
		if bool(attention_flags.get("tutorial_inspect_bag_choice_visible", false)):
			inferred_attention_counts["tutorial_attention_inspect_bag"] = 1
		if bool(attention_flags.get("tutorial_graph_attention_ready", false)) or bool(attention_flags.get("tutorial_graph_attention_completed", false)):
			inferred_attention_counts["tutorial_attention_graph"] = 1
		runtime["tutorial_attention_audio_counts"] = inferred_attention_counts
	else:
		var normalized_attention_counts: Dictionary = {}
		var saved_attention_counts: Dictionary = runtime.get("tutorial_attention_audio_counts", {}) as Dictionary
		for attention_event_value in saved_attention_counts.keys():
			var attention_event_id := str(attention_event_value)
			if attention_event_id != "" and int(saved_attention_counts[attention_event_value]) >= 1:
				normalized_attention_counts[attention_event_id] = 1
		attention_audio_changed = normalized_attention_counts != saved_attention_counts
		runtime["tutorial_attention_audio_counts"] = normalized_attention_counts
	if not runtime.has("case_state"):
		runtime["case_state"] = {}
	if not runtime.has("history_snapshots"):
		runtime["history_snapshots"] = []
	if not runtime.has("active_transition_indices"):
		runtime["active_transition_indices"] = []
	# Optional investigation-time state. Old cases and old saves remain disabled
	# by using -1 and empty containers; only a case capability enables it.
	if not runtime.has("investigation_time"):
		runtime["investigation_time"] = -1
	for optional_dictionary_field in ["assistant_state", "police_state", "event_flags", "pollution_node_states"]:
		if not runtime.has(optional_dictionary_field):
			runtime[optional_dictionary_field] = {}
	for optional_array_field in ["active_actions", "completed_actions", "action_history"]:
		if not runtime.has(optional_array_field):
			runtime[optional_array_field] = []
	for optional_bool_field in ["witness_protected", "killer_alerted", "killer_controlled"]:
		if not runtime.has(optional_bool_field):
			runtime[optional_bool_field] = false
	var aliases: Dictionary = NODE_ID_ALIASES.get(expected_case_id, {}) as Dictionary
	var remapped_runtime: Dictionary = _remap_node_aliases(runtime, aliases) as Dictionary
	var alias_changed := remapped_runtime != runtime
	var story_migration_changed := false
	if expected_case_id == "tutorial_00":
		var story_migration := _migrate_tutorial_archive_story(remapped_runtime, str(runtime.get("current_node_id", "")))
		remapped_runtime = story_migration.get("runtime", remapped_runtime)
		story_migration_changed = bool(story_migration.get("changed", false))
	migrated["runtime_state"] = remapped_runtime
	if migrated.get("metadata") is Dictionary:
		migrated["metadata"] = _remap_node_aliases(migrated.get("metadata"), aliases)
	migrated["format_version"] = SUPPORTED_FORMAT_VERSION
	return {
		"success": true,
		"data": migrated,
		"migrated": version != SUPPORTED_FORMAT_VERSION or alias_changed or attention_audio_changed or story_migration_changed,
		"from_version": version,
		"to_version": SUPPORTED_FORMAT_VERSION,
		"error": ""
	}


func _migrate_tutorial_archive_story(runtime: Dictionary, original_current_node_id: String) -> Dictionary:
	var changed := false
	var legacy_story_detected := false
	var flags_value: Variant = runtime.get("flags", {})
	var flags: Dictionary = flags_value if flags_value is Dictionary else {}
	var flag_aliases := {
		"tutorial_glue_mark_recorded": "tutorial_thread_fade_recorded",
		"tutorial_glue_keyword_hint_visible": "tutorial_thread_fade_hint_visible"
	}
	for old_flag_value in flag_aliases.keys():
		var old_flag := str(old_flag_value)
		var new_flag := str(flag_aliases[old_flag_value])
		if flags.has(old_flag):
			legacy_story_detected = true
			if not flags.has(new_flag):
				flags[new_flag] = flags[old_flag]
			flags.erase(old_flag)
			changed = true
	if bool(flags.get("tutorial_graph_attention_ready", false)):
		flags["tutorial_attention_graph_first_ready"] = true
	if bool(flags.get("tutorial_graph_attention_completed", false)):
		flags["tutorial_attention_graph_first_completed"] = true
	runtime["flags"] = flags

	var revealed_sections: Array = runtime.get("revealed_section_ids", [])
	for index in range(revealed_sections.size()):
		if str(revealed_sections[index]) == "tutorial_after_glue_keyword":
			revealed_sections[index] = "tutorial_after_thread_fade"
			changed = true
	runtime["revealed_section_ids"] = _deduplicate_strings(revealed_sections)

	var reveal_value: Variant = runtime.get("active_text_reveal", {})
	if reveal_value is Dictionary:
		var reveal := reveal_value as Dictionary
		if str(reveal.get("reveal_section_id", "")) == "tutorial_after_glue_keyword":
			reveal["reveal_section_id"] = "tutorial_after_thread_fade"
			changed = true
		runtime["active_text_reveal"] = reveal

	var completed_events: Array = runtime.get("completed_after_reveal_events", [])
	for index in range(completed_events.size()):
		var event_id := str(completed_events[index])
		var old_marker := ":section:tutorial_after_glue_keyword:"
		if event_id.contains(old_marker):
			completed_events[index] = event_id.replace(old_marker, ":section:tutorial_after_thread_fade:")
			changed = true
	runtime["completed_after_reveal_events"] = _deduplicate_strings(completed_events)

	var keyword_instances: Array = runtime.get("keyword_instances", [])
	var legacy_instance_ids: Dictionary = {}
	var has_thread_fade := false
	for instance_value in keyword_instances:
		if not (instance_value is Dictionary):
			continue
		var instance := instance_value as Dictionary
		var text := str(instance.get("normalized_text", instance.get("text", "")))
		if text == "胶痕":
			legacy_story_detected = true
			legacy_instance_ids[str(instance.get("instance_id", ""))] = true
			instance["text"] = "线头褪色"
			instance["normalized_text"] = "线头褪色"
			instance["source_node_id"] = "tutorial_0012"
			changed = true
		if str(instance.get("normalized_text", "")) == "线头褪色":
			has_thread_fade = true

	var legacy_later_nodes := [
		"tutorial_0002a", "tutorial_0002b", "tutorial_0002c", "tutorial_0002d",
		"tutorial_0003", "tutorial_0004", "tutorial_0005", "tutorial_0006",
		"tutorial_0007", "tutorial_0007s", "tutorial_0008e", "tutorial_0009",
		"tutorial_0009a", "tutorial_0009b", "tutorial_0010",
		"tutorial_inference_file_change", "tutorial_inference_seal",
		"tutorial_hypothesis_admin", "tutorial_inference_final"
	]
	if original_current_node_id in legacy_later_nodes:
		legacy_story_detected = true
		flags["tutorial_thread_fade_recorded"] = true
		flags["tutorial_first_graph_relation_completed"] = true
		if not has_thread_fade:
			keyword_instances.append({
				"instance_id": "keyword_tutorial_0012_migrated_thread_fade",
				"text": "线头褪色",
				"normalized_text": "线头褪色",
				"source_node_id": "tutorial_0012"
			})
			has_thread_fade = true
		runtime["active_text_reveal"] = {}
		changed = true
	var unique_keyword_instances: Array = []
	var keyword_keys: Dictionary = {}
	for instance_value in keyword_instances:
		if not (instance_value is Dictionary):
			continue
		var instance := instance_value as Dictionary
		var keyword_key := "%s\u001f%s" % [str(instance.get("source_node_id", "")), str(instance.get("normalized_text", ""))]
		if keyword_keys.has(keyword_key):
			changed = true
			continue
		keyword_keys[keyword_key] = true
		unique_keyword_instances.append(instance)
	keyword_instances = unique_keyword_instances
	runtime["keyword_instances"] = keyword_instances
	runtime["flags"] = flags
	if legacy_story_detected:
		var unlocked_value: Variant = runtime.get("unlocked_nodes", {})
		var unlocked_nodes: Dictionary = unlocked_value if unlocked_value is Dictionary else {}
		var keyword_unlocked_value: Variant = runtime.get("keyword_unlocked_nodes", {})
		var keyword_unlocked: Dictionary = keyword_unlocked_value if keyword_unlocked_value is Dictionary else {}
		for obsolete_target in [
			"tutorial_fact_material_mismatch", "tutorial_fact_seal_anomaly",
			"tutorial_conclusion_erin", "tutorial_conclusion_supported"
		]:
			unlocked_nodes.erase(obsolete_target)
			keyword_unlocked.erase(obsolete_target)
		if original_current_node_id in legacy_later_nodes:
			keyword_unlocked["tutorial_fact_thread_age_mismatch"] = true
			keyword_unlocked["tutorial_fact_seal_anomaly"] = true
			keyword_unlocked["tutorial_0014"] = true
		runtime["unlocked_nodes"] = unlocked_nodes
		runtime["keyword_unlocked_nodes"] = keyword_unlocked

	var old_keyword_texts := {"胶痕": true, "页码缺口": true, "封口白痕": true, "T-00编号": true}
	var keyword_by_id: Dictionary = {}
	for instance_value in keyword_instances:
		if instance_value is Dictionary:
			keyword_by_id[str((instance_value as Dictionary).get("instance_id", ""))] = str((instance_value as Dictionary).get("normalized_text", ""))
	var filtered_connections: Array = []
	for connection_value in runtime.get("keyword_connections", []):
		if not (connection_value is Dictionary):
			continue
		var connection := connection_value as Dictionary
		var instance_id := str(connection.get("keyword_instance_id", ""))
		var keyword_text := str(keyword_by_id.get(instance_id, connection.get("normalized_keyword", "")))
		if legacy_instance_ids.has(instance_id) or old_keyword_texts.has(keyword_text):
			changed = true
			continue
		filtered_connections.append(connection)
	runtime["keyword_connections"] = filtered_connections

	var attention_counts_value: Variant = runtime.get("tutorial_attention_audio_counts", {})
	if attention_counts_value is Dictionary:
		var attention_counts := attention_counts_value as Dictionary
		if attention_counts.has("tutorial_attention_graph") and not attention_counts.has("tutorial_attention_graph_first"):
			attention_counts["tutorial_attention_graph_first"] = 1
			changed = true
		runtime["tutorial_attention_audio_counts"] = attention_counts
	return {"runtime": runtime, "changed": changed}


func _deduplicate_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var text_value := str(value)
		if text_value != "" and not result.has(text_value):
			result.append(text_value)
	return result


func _remap_node_aliases(value: Variant, aliases: Dictionary) -> Variant:
	if aliases.is_empty():
		return value
	if value is String:
		var text_value := str(value)
		for old_value in aliases.keys():
			var old_id := str(old_value)
			var new_id := str(aliases[old_value])
			if text_value == old_id:
				return new_id
			if text_value.begins_with(old_id + ":"):
				return new_id + text_value.substr(old_id.length())
		return text_value
	if value is Array:
		var result_array: Array = []
		for entry in (value as Array):
			result_array.append(_remap_node_aliases(entry, aliases))
		return result_array
	if value is Dictionary:
		var result_dictionary: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			var remapped_key: Variant = _remap_node_aliases(key_value, aliases)
			result_dictionary[remapped_key] = _remap_node_aliases((value as Dictionary)[key_value], aliases)
		return result_dictionary
	return value


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
	var revealed_nodes: Array = runtime_data.get("revealed_node_ids", history)
	for index in range(revealed_nodes.size()):
		var node_id := str(revealed_nodes[index])
		if loader.get_node(node_id).is_empty() and not _is_legacy_compatible_node(node_id):
			return _failure("corrupted", "runtime_state.revealed_node_ids[%d]: target node does not exist, value=%s" % [index, node_id])
	var active_reveal: Dictionary = runtime_data.get("active_text_reveal", {})
	var active_reveal_node_id := str(active_reveal.get("node_id", ""))
	if active_reveal_node_id != "" and loader.get_node(active_reveal_node_id).is_empty() and not _is_legacy_compatible_node(active_reveal_node_id):
		return _failure("corrupted", "runtime_state.active_text_reveal.node_id: target node does not exist, value=%s" % active_reveal_node_id)
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
