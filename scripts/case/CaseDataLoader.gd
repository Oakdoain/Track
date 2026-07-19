extends RefCounted
class_name CaseDataLoader

const DEFAULT_NODES_PATH := "res://data/cases/case_01/control_backup/nodes.json"
const DEFAULT_GRAPH_LAYOUT_PATH := "res://data/cases/case_01/control_backup/graph_layout.json"
const DEFAULT_KEYWORD_RULES_PATH := "res://data/cases/case_01/control_backup/keyword_rules.json"
const REGISTRY_PATH := "res://data/cases/cases.json"
const CASE_DATA_ROOT := "res://data/cases/"

var data: Dictionary = {}
var nodes_by_id: Dictionary = {}
var graph_layout: Dictionary = {}
var keyword_rules: Array[Dictionary] = []
var keyword_presets: Dictionary = {}
var keyword_effects: Array[Dictionary] = []
var registered_cases: Array[Dictionary] = []
var current_case_descriptor: Dictionary = {}
var case_metadata: Dictionary = {}
var clues_data: Dictionary = {}
var audio_clues_data: Dictionary = {}


func load_registry(path: String = REGISTRY_PATH) -> bool:
	var parsed: Dictionary = _read_json_dictionary(path, "case registry")

	if parsed.is_empty():
		registered_cases.clear()
		return false

	var raw_cases: Variant = parsed.get("cases", [])

	if not (raw_cases is Array):
		push_warning("CaseDataLoader: registry cases must be an Array.")
		registered_cases.clear()
		return false

	var validated: Array[Dictionary] = []
	var seen_case_ids: Dictionary = {}

	for raw_case in raw_cases:
		if not (raw_case is Dictionary):
			push_warning("CaseDataLoader: ignored non-Dictionary registry entry.")
			continue

		var descriptor: Dictionary = raw_case

		if not _is_valid_case_descriptor(descriptor):
			push_warning("CaseDataLoader: ignored invalid registry entry.")
			continue

		var case_id: String = str(descriptor.get("case_id", ""))

		if seen_case_ids.has(case_id):
			push_warning("CaseDataLoader: ignored duplicate case_id: " + case_id)
			continue

		seen_case_ids[case_id] = true
		validated.append(descriptor.duplicate(true))

	validated.sort_custom(_sort_case_descriptors)
	registered_cases = validated
	return not registered_cases.is_empty()


func get_registered_cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for descriptor in registered_cases:
		result.append(descriptor.duplicate(true))

	return result


func get_case_descriptor(case_id: String) -> Dictionary:
	for descriptor in registered_cases:
		if str(descriptor.get("case_id", "")) == case_id:
			return descriptor.duplicate(true)

	return {}


func load_case(case_id: String, slice_id: String) -> bool:
	if registered_cases.is_empty() and not load_registry():
		_clear_loaded_case()
		return false

	var descriptor: Dictionary = get_case_descriptor(case_id)

	if descriptor.is_empty() or str(descriptor.get("slice_id", "")) != slice_id:
		push_warning("CaseDataLoader: requested case is not registered: %s / %s" % [case_id, slice_id])
		_clear_loaded_case()
		return false

	var data_path: String = str(descriptor.get("data_path", ""))
	var metadata_candidate: Dictionary = _read_json_dictionary(data_path + "/case.json", "case metadata")

	if (
		metadata_candidate.is_empty()
		or str(metadata_candidate.get("case_id", "")) != case_id
		or str(metadata_candidate.get("slice_id", "")) != slice_id
		or not (metadata_candidate.get("start_node_id", "") is String)
		or str(metadata_candidate.get("start_node_id", "")) == ""
	):
		push_warning("CaseDataLoader: case.json does not match its registry descriptor.")
		_clear_loaded_case()
		return false

	var candidate := CaseDataLoader.new()

	if not candidate.load_nodes(data_path + "/nodes.json"):
		_clear_loaded_case()
		return false

	if not candidate.load_graph_layout(data_path + "/graph_layout.json"):
		_clear_loaded_case()
		return false

	if not candidate.load_keyword_rules(data_path + "/keyword_rules.json"):
		_clear_loaded_case()
		return false

	var clues_candidate: Dictionary = _read_json_dictionary(data_path + "/clues.json", "clues")
	var audio_candidate: Dictionary = _read_json_dictionary(data_path + "/audio_clues.json", "audio clues")

	if clues_candidate.is_empty() or audio_candidate.is_empty():
		_clear_loaded_case()
		return false

	var start_node_id: String = str(metadata_candidate.get("start_node_id", ""))

	if candidate.get_node(start_node_id).is_empty():
		push_warning("CaseDataLoader: case start node is missing: " + start_node_id)
		_clear_loaded_case()
		return false

	# Commit only after every required file has parsed and cross-validation passed.
	data = candidate.data.duplicate(true)
	nodes_by_id = candidate.nodes_by_id.duplicate(true)
	graph_layout = candidate.graph_layout.duplicate(true)
	keyword_rules = candidate.keyword_rules.duplicate(true)
	keyword_presets = candidate.keyword_presets.duplicate(true)
	keyword_effects = candidate.keyword_effects.duplicate(true)
	case_metadata = metadata_candidate.duplicate(true)
	current_case_descriptor = descriptor.duplicate(true)
	clues_data = clues_candidate.duplicate(true)
	audio_clues_data = audio_candidate.duplicate(true)
	return true


func get_current_case_id() -> String:
	return str(current_case_descriptor.get("case_id", case_metadata.get("case_id", "")))


func get_current_slice_id() -> String:
	return str(current_case_descriptor.get("slice_id", case_metadata.get("slice_id", "")))


func get_case_data_path() -> String:
	return str(current_case_descriptor.get("data_path", ""))


func get_case_metadata() -> Dictionary:
	return case_metadata.duplicate(true)


func get_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_nodes: Variant = data.get("nodes", [])

	if raw_nodes is Array:
		for raw_node in raw_nodes:
			if raw_node is Dictionary:
				result.append((raw_node as Dictionary).duplicate(true))

	return result


func get_keyword_rules() -> Array[Dictionary]:
	return keyword_rules.duplicate(true)


func get_keyword_effects() -> Array[Dictionary]:
	return keyword_effects.duplicate(true)


func get_keyword_effect(keyword_id: String) -> Dictionary:
	for effect_rule in keyword_effects:
		if str(effect_rule.get("keyword_id", "")) == keyword_id:
			return effect_rule.duplicate(true)
	return {}


func find_keyword_effect(keyword: String, source_scope: String) -> Dictionary:
	var normalized := _normalize_keyword(keyword)
	for effect_rule in keyword_effects:
		if str(effect_rule.get("normalized_keyword", "")) != normalized:
			continue
		var scopes: Variant = effect_rule.get("source_scope", [])
		if scopes is Array and (scopes as Array).has(source_scope):
			return effect_rule.duplicate(true)
	return {}


func get_graph_layout() -> Dictionary:
	return graph_layout.duplicate(true)


func get_clues() -> Dictionary:
	return clues_data.duplicate(true)


func get_audio_clues() -> Dictionary:
	return audio_clues_data.duplicate(true)


func get_audio_data_path() -> String:
	var data_path: String = str(current_case_descriptor.get("data_path", ""))
	return data_path + "/audio_clues.json" if data_path != "" else ""


func load_nodes(path: String = DEFAULT_NODES_PATH) -> bool:
	data.clear()
	nodes_by_id.clear()

	if not FileAccess.file_exists(path):
		push_error("CaseDataLoader: nodes file not found: " + path)
		return false

	var content: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var error: int = json.parse(content)

	if error != OK:
		push_error("CaseDataLoader: json parse error: %s, line %d" % [
			json.get_error_message(),
			json.get_error_line()
		])
		return false

	var parsed: Variant = json.data

	if not (parsed is Dictionary):
		push_error("CaseDataLoader: nodes root must be Dictionary.")
		return false

	data = parsed

	var raw_nodes: Variant = data.get("nodes", [])

	if not (raw_nodes is Array):
		push_error("CaseDataLoader: nodes must be Array.")
		return false

	for raw_node in raw_nodes:
		if not (raw_node is Dictionary):
			continue

		var node_id: String = str(raw_node.get("node_id", ""))

		if node_id != "":
			nodes_by_id[node_id] = raw_node

	return not nodes_by_id.is_empty()


func get_node(node_id: String) -> Dictionary:
	if not nodes_by_id.has(node_id):
		return {}

	var node: Variant = nodes_by_id[node_id]

	if node is Dictionary:
		return node

	return {}


func get_initial_node_id() -> String:
	return str(case_metadata.get("start_node_id", data.get("initial_node_id", "")))


func get_chapter_title() -> String:
	return str(case_metadata.get("chapter_title", data.get("chapter_title", "")))


func get_chapter_intro() -> String:
	return str(data.get("chapter_intro", ""))


func get_current_goal() -> String:
	return str(data.get("current_goal", ""))


func get_discovered_keywords() -> Array:
	var keywords: Variant = data.get("discovered_keywords", [])

	if keywords is Array:
		return keywords

	return []


func load_graph_layout(path: String = DEFAULT_GRAPH_LAYOUT_PATH) -> bool:
	graph_layout.clear()

	if not FileAccess.file_exists(path):
		push_warning("CaseDataLoader: graph layout file not found: " + path)
		return false

	var content: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var error: int = json.parse(content)

	if error != OK:
		push_warning("CaseDataLoader: graph layout json parse error: %s, line %d" % [
			json.get_error_message(),
			json.get_error_line()
		])
		return false

	var parsed: Variant = json.data

	if not (parsed is Dictionary):
		push_warning("CaseDataLoader: graph layout root must be Dictionary.")
		return false

	var canvas_size: Variant = parsed.get("canvas_size", [])
	var node_positions: Variant = parsed.get("nodes", {})

	if not (canvas_size is Array) or canvas_size.size() < 2:
		push_warning("CaseDataLoader: graph layout canvas_size must contain width and height.")
		return false

	if not (node_positions is Dictionary):
		push_warning("CaseDataLoader: graph layout nodes must be Dictionary.")
		return false

	graph_layout = parsed
	return true


func get_graph_canvas_size() -> Vector2:
	var canvas_size: Variant = graph_layout.get("canvas_size", [])

	if canvas_size is Array and canvas_size.size() >= 2:
		return Vector2(float(canvas_size[0]), float(canvas_size[1]))

	return Vector2.ZERO


func get_graph_node_position(node_id: String) -> Vector2:
	var node_positions: Variant = graph_layout.get("nodes", {})

	if not (node_positions is Dictionary):
		return Vector2(-1.0, -1.0)

	var raw_position: Variant = node_positions.get(node_id, [])

	if raw_position is Array and raw_position.size() >= 2:
		return Vector2(float(raw_position[0]), float(raw_position[1]))

	return Vector2(-1.0, -1.0)


func load_keyword_rules(path: String = DEFAULT_KEYWORD_RULES_PATH) -> bool:
	keyword_rules.clear()
	keyword_presets.clear()
	keyword_effects.clear()

	if not FileAccess.file_exists(path):
		push_warning("CaseDataLoader: keyword rules file not found: " + path)
		return false

	var content: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var error: int = json.parse(content)

	if error != OK:
		push_warning("CaseDataLoader: keyword rules json parse error: %s, line %d" % [
			json.get_error_message(),
			json.get_error_line()
		])
		return false

	var parsed: Variant = json.data

	if not (parsed is Dictionary):
		push_warning("CaseDataLoader: keyword rules root must be Dictionary.")
		return false

	_parse_keyword_presets(parsed.get("keyword_presets", {}))
	_parse_keyword_effects(parsed.get("keyword_effects", []))

	var raw_rules: Variant = parsed.get("keyword_rules", [])

	if not (raw_rules is Array):
		push_warning("CaseDataLoader: keyword_rules must be Array.")
		return false

	for raw_rule in raw_rules:
		if not (raw_rule is Dictionary):
			continue

		var connections: Variant = raw_rule.get("connections", [])

		if connections is Array and not connections.is_empty():
			for connection in connections:
				if connection is Dictionary:
					_append_normalized_keyword_rule(raw_rule, connection)
		elif raw_rule.has("target_node_id") and raw_rule.has("outcome"):
			_append_normalized_keyword_rule(raw_rule, raw_rule)

	if keyword_rules.is_empty():
		push_warning("CaseDataLoader: no actionable keyword connection rules were loaded.")

	return true


func _parse_keyword_effects(raw_effects: Variant) -> void:
	if not (raw_effects is Array):
		push_warning("CaseDataLoader: keyword_effects must be an Array.")
		return
	var seen_ids: Dictionary = {}
	for raw_rule in (raw_effects as Array):
		if not (raw_rule is Dictionary):
			push_warning("CaseDataLoader: ignored non-Dictionary keyword effect rule.")
			continue
		var rule: Dictionary = raw_rule
		var keyword_id := str(rule.get("keyword_id", ""))
		var keyword := str(rule.get("text", rule.get("keyword", "")))
		var scopes_value: Variant = rule.get("source_scope", [])
		var effects_value: Variant = rule.get("effects", [])
		if keyword_id == "" or keyword == "" or seen_ids.has(keyword_id):
			push_warning("CaseDataLoader: ignored incomplete or duplicate keyword effect: " + keyword_id)
			continue
		if not (scopes_value is Array) or (scopes_value as Array).is_empty() or not (effects_value is Array) or (effects_value as Array).is_empty():
			push_warning("CaseDataLoader: keyword effect requires source_scope and effects arrays: " + keyword_id)
			continue
		var scopes: Array[String] = []
		var valid := true
		for scope_value in (scopes_value as Array):
			if not (scope_value is String) or str(scope_value) == "":
				valid = false
				break
			scopes.append(str(scope_value))
		var normalized_effects: Array[Dictionary] = []
		for effect_value in (effects_value as Array):
			if not (effect_value is Dictionary) or str((effect_value as Dictionary).get("type", "")) == "":
				valid = false
				break
			normalized_effects.append((effect_value as Dictionary).duplicate(true))
		if not valid:
			push_warning("CaseDataLoader: ignored invalid keyword effect: " + keyword_id)
			continue
		seen_ids[keyword_id] = true
		keyword_effects.append({
			"keyword_id": keyword_id,
			"keyword": keyword,
			"normalized_keyword": _normalize_keyword(keyword),
			"source_scope": scopes,
			"effects": normalized_effects
		})


func get_keyword_presets(node_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var presets_value: Variant = keyword_presets.get(node_id, [])

	if not (presets_value is Array):
		return result

	for preset_value in presets_value:
		if preset_value is Dictionary:
			result.append((preset_value as Dictionary).duplicate(true))

	return result


func find_keyword_rule(
	normalized_keyword: String,
	source_node_id: String,
	target_node_id: String
) -> Dictionary:
	var global_match: Dictionary = {}

	for rule in keyword_rules:
		if str(rule.get("normalized_keyword", "")) != normalized_keyword:
			continue

		if str(rule.get("target_node_id", "")) != target_node_id:
			continue

		var rule_source_node_id: String = str(rule.get("source_node_id", ""))

		if rule_source_node_id == source_node_id:
			return rule.duplicate(true)

		if rule_source_node_id == "" and bool(rule.get("allow_global", false)):
			global_match = rule

	if not global_match.is_empty():
		return global_match.duplicate(true)

	return {}


func _append_normalized_keyword_rule(base_rule: Dictionary, connection: Dictionary) -> void:
	var keyword: String = str(base_rule.get("keyword", connection.get("keyword", "")))
	var normalized_keyword: String = _normalize_keyword(keyword)
	var target_node_id: String = str(connection.get("target_node_id", ""))
	var outcome: String = str(connection.get("outcome", connection.get("result", ""))).to_lower()

	if normalized_keyword == "" or target_node_id == "" or outcome == "":
		push_warning("CaseDataLoader: skipped incomplete keyword connection rule for: " + keyword)
		return

	var source_node_ids := PackedStringArray()
	var explicit_source: String = str(connection.get("source_node_id", ""))

	if explicit_source != "":
		source_node_ids.append(explicit_source)
	else:
		var raw_sources: Variant = base_rule.get("source_nodes", [])

		if raw_sources is Array:
			for source_value in raw_sources:
				var source_node_id: String = str(source_value)

				if source_node_id != "":
					source_node_ids.append(source_node_id)

	var allow_global: bool = bool(connection.get(
		"allow_global",
		base_rule.get("allow_global", false)
	))

	if source_node_ids.is_empty() and allow_global:
		source_node_ids.append("")

	if source_node_ids.is_empty():
		push_warning("CaseDataLoader: keyword rule has no source node and is not global: " + keyword)
		return

	var unlock_node_ids: Array[String] = []
	var raw_unlock_node_ids: Variant = connection.get("unlock_node_ids", [])

	if raw_unlock_node_ids is Array:
		for raw_unlock_node_id in raw_unlock_node_ids:
			if raw_unlock_node_id is String and str(raw_unlock_node_id) != "":
				var unlock_node_id: String = str(raw_unlock_node_id)

				if not unlock_node_ids.has(unlock_node_id):
					unlock_node_ids.append(unlock_node_id)
			else:
				push_warning("CaseDataLoader: ignored invalid unlock_node_ids entry for: " + keyword)
	else:
		push_warning("CaseDataLoader: unlock_node_ids must be an Array for: " + keyword)

	var set_flags: Dictionary = {}
	var raw_set_flags: Variant = connection.get("set_flags", {})

	if raw_set_flags is Dictionary:
		for raw_flag_name in (raw_set_flags as Dictionary).keys():
			var flag_name: String = str(raw_flag_name)
			var flag_value: Variant = (raw_set_flags as Dictionary).get(raw_flag_name)

			if flag_name != "" and flag_value is bool:
				set_flags[flag_name] = bool(flag_value)
			else:
				push_warning("CaseDataLoader: ignored invalid connection flag for: " + keyword)

	var requires_flags: Dictionary = {}
	var raw_requires_flags: Variant = connection.get("requires_flags", {})

	if raw_requires_flags is Dictionary:
		for raw_flag_name in (raw_requires_flags as Dictionary).keys():
			var flag_name: String = str(raw_flag_name)
			var flag_value: Variant = (raw_requires_flags as Dictionary).get(raw_flag_name)

			if flag_name != "" and flag_value is bool:
				requires_flags[flag_name] = bool(flag_value)
			else:
				push_warning("CaseDataLoader: ignored invalid required flag for: " + keyword)

	for source_node_id in source_node_ids:
		keyword_rules.append({
			"keyword": keyword,
			"normalized_keyword": normalized_keyword,
			"source_node_id": source_node_id,
			"target_node_id": target_node_id,
			"outcome": outcome,
			"unlock_node_id": str(connection.get("unlock_node_id", "")),
			"unlock_node_ids": unlock_node_ids.duplicate(),
			"error_node_id": str(connection.get("error_node_id", "")),
			"feedback": str(connection.get("feedback", "")),
			"set_flags": set_flags.duplicate(true),
			"requires_flags": requires_flags.duplicate(true),
			"autosave_on_success": bool(connection.get("autosave_on_success", false)),
			"allow_global": allow_global
		})


func _parse_keyword_presets(raw_presets: Variant) -> void:
	if not (raw_presets is Dictionary):
		push_warning("CaseDataLoader: keyword_presets must be a Dictionary.")
		return

	var preset_dictionary: Dictionary = raw_presets

	for raw_node_id in preset_dictionary.keys():
		var node_id: String = str(raw_node_id)
		var raw_candidates: Variant = preset_dictionary.get(raw_node_id, [])

		if not (raw_candidates is Array):
			push_warning("CaseDataLoader: keyword presets for %s must be an Array." % node_id)
			continue

		var normalized_candidates: Array[Dictionary] = []
		var seen_candidates: Dictionary = {}

		for raw_candidate in raw_candidates:
			var keyword: String = ""
			var anchor_text: String = ""
			var occurrence_index: int = 0

			if raw_candidate is String:
				keyword = str(raw_candidate)
				anchor_text = keyword
			elif raw_candidate is Dictionary:
				var candidate_data: Dictionary = raw_candidate
				var keyword_value: Variant = candidate_data.get("keyword", null)
				var anchor_value: Variant = candidate_data.get("anchor_text", null)

				if not (keyword_value is String) or not (anchor_value is String):
					push_warning(
						"CaseDataLoader: ignored keyword preset with invalid text fields for %s." % node_id
					)
					continue

				keyword = str(keyword_value)
				anchor_text = str(anchor_value)
				var occurrence_value: Variant = candidate_data.get("occurrence_index", 0)

				if occurrence_value is int:
					occurrence_index = int(occurrence_value)
				elif occurrence_value is float:
					var occurrence_float: float = float(occurrence_value)

					if occurrence_float != floorf(occurrence_float):
						push_warning(
							"CaseDataLoader: ignored keyword preset with non-integer occurrence for %s." % node_id
						)
						continue

					occurrence_index = int(occurrence_float)
				else:
					push_warning(
						"CaseDataLoader: ignored keyword preset with invalid occurrence for %s." % node_id
					)
					continue
			else:
				push_warning(
					"CaseDataLoader: ignored keyword preset with invalid type for %s." % node_id
				)
				continue

			var normalized_candidate: String = _normalize_keyword(keyword)

			if normalized_candidate == "" or anchor_text.strip_edges() == "":
				continue

			if occurrence_index < 0:
				push_warning(
					"CaseDataLoader: ignored keyword preset with negative occurrence for %s: %s" % [
						node_id,
						normalized_candidate
					]
				)
				continue

			if normalized_candidate.length() > CaseRuntimeState.MAX_KEYWORD_LENGTH:
				push_warning(
					"CaseDataLoader: ignored keyword preset over 10 characters for %s: %s" % [
						node_id,
						normalized_candidate
					]
				)
				continue

			if seen_candidates.has(normalized_candidate):
				continue

			seen_candidates[normalized_candidate] = true
			normalized_candidates.append({
				"keyword": normalized_candidate,
				"normalized_keyword": normalized_candidate,
				"anchor_text": anchor_text,
				"occurrence_index": occurrence_index
			})

		keyword_presets[node_id] = normalized_candidates


func _normalize_keyword(text: String) -> String:
	var normalized_text: String = text.strip_edges()

	if normalized_text == "":
		return ""

	var whitespace_regex := RegEx.new()
	var compile_error: int = whitespace_regex.compile("\\s+")

	if compile_error != OK:
		push_warning("CaseDataLoader: failed to compile keyword whitespace regex.")
		return normalized_text

	return whitespace_regex.sub(normalized_text, " ", true)


func _read_json_dictionary(path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("CaseDataLoader: %s file not found: %s" % [label, path])
		return {}

	var json := JSON.new()
	var error: Error = json.parse(FileAccess.get_file_as_string(path))

	if error != OK:
		push_warning("CaseDataLoader: %s JSON error: %s, line %d" % [
			label,
			json.get_error_message(),
			json.get_error_line()
		])
		return {}

	if not (json.data is Dictionary):
		push_warning("CaseDataLoader: %s root must be a Dictionary." % label)
		return {}

	return (json.data as Dictionary).duplicate(true)


func _is_valid_case_descriptor(descriptor: Dictionary) -> bool:
	var string_fields: PackedStringArray = [
		"case_id", "slice_id", "code", "title", "short_title", "subtitle",
		"case_type", "estimated_time", "data_path", "completion_flag"
	]

	for field in string_fields:
		if not (descriptor.get(field, null) is String):
			return false

	if not (descriptor.get("recommended", null) is bool):
		return false

	var order_value: Variant = descriptor.get("order", null)

	if not (order_value is int or (order_value is float and float(order_value) == floorf(float(order_value)))):
		return false

	var case_id: String = str(descriptor.get("case_id", ""))
	var slice_id: String = str(descriptor.get("slice_id", ""))
	var data_path: String = str(descriptor.get("data_path", ""))

	if case_id == "" or slice_id == "" or not _is_safe_identifier(case_id) or not _is_safe_identifier(slice_id):
		return false

	return (
		data_path.begins_with(CASE_DATA_ROOT)
		and not data_path.contains("..")
		and not data_path.contains("\\")
		and data_path == "%s%s/%s" % [CASE_DATA_ROOT, case_id, slice_id]
		and FileAccess.file_exists(data_path + "/case.json")
	)


func _is_safe_identifier(value: String) -> bool:
	var regex := RegEx.new()
	return regex.compile("^[a-z0-9_]+$") == OK and regex.search(value) != null


func _sort_case_descriptors(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("order", 0)) < int(right.get("order", 0))


func _clear_loaded_case() -> void:
	data.clear()
	nodes_by_id.clear()
	graph_layout.clear()
	keyword_rules.clear()
	keyword_presets.clear()
	keyword_effects.clear()
	current_case_descriptor.clear()
	case_metadata.clear()
	clues_data.clear()
	audio_clues_data.clear()
