extends RefCounted
class_name CaseDataLoader

const DEFAULT_NODES_PATH := "res://data/cases/case_01/control_backup/nodes.json"
const DEFAULT_GRAPH_LAYOUT_PATH := "res://data/cases/case_01/control_backup/graph_layout.json"
const DEFAULT_KEYWORD_RULES_PATH := "res://data/cases/case_01/control_backup/keyword_rules.json"

var data: Dictionary = {}
var nodes_by_id: Dictionary = {}
var graph_layout: Dictionary = {}
var keyword_rules: Array[Dictionary] = []
var keyword_presets: Dictionary = {}


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
	return str(data.get("initial_node_id", ""))


func get_chapter_title() -> String:
	return str(data.get("chapter_title", ""))


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
	var outcome: String = str(connection.get("outcome", "")).to_lower()

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

	for source_node_id in source_node_ids:
		keyword_rules.append({
			"keyword": keyword,
			"normalized_keyword": normalized_keyword,
			"source_node_id": source_node_id,
			"target_node_id": target_node_id,
			"outcome": outcome,
			"unlock_node_id": str(connection.get("unlock_node_id", "")),
			"error_node_id": str(connection.get("error_node_id", "")),
			"feedback": str(connection.get("feedback", "")),
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
