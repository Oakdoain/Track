extends Node

var story_data: Dictionary = {}
var clue_data: Dictionary = {}

var current_node_id: String = ""
var read_node_ids: Dictionary = {}
var discovered_keywords: Dictionary = {}
var discovered_clues: Dictionary = {}


func load_story(story_path: String, clues_path: String) -> bool:
	story_data = _read_json(story_path)
	clue_data = _read_json(clues_path)

	if story_data.is_empty():
		push_error("StoryManager: story json is empty or invalid: " + story_path)
		return false

	var meta := _get_meta()
	current_node_id = str(meta.get("initial_node", ""))

	if current_node_id == "":
		push_error("StoryManager: missing meta.initial_node")
		return false

	if not _get_nodes().has(current_node_id):
		push_error("StoryManager: initial node not found: " + current_node_id)
		return false

	read_node_ids.clear()
	discovered_keywords.clear()
	discovered_clues.clear()

	_apply_node_discovery(current_node_id)

	return true


func get_render_data() -> Dictionary:
	var node := _get_current_node()
	var meta := _get_meta()

	if node.is_empty():
		return {}

	var all_keywords := _get_all_keywords()
	var visible_keywords: Array = []

	for keyword in all_keywords:
		var keyword_text := str(keyword)

		if discovered_keywords.has(keyword_text):
			visible_keywords.append(keyword_text)

	var total_keyword_count := int(meta.get("keyword_total", all_keywords.size()))
	var total_node_count := int(meta.get("node_total", _get_nodes().size()))
	var read_count := read_node_ids.size()

	if total_node_count <= 0:
		total_node_count = 1

	var progress := int(round(float(read_count) / float(total_node_count) * 100.0))

	var body: Array = []
	var raw_body = node.get("body", [])

	if raw_body is Array:
		body = raw_body
	else:
		body = [str(raw_body)]

	var node_type := str(node.get("node_type", "事件节点"))
	var title := str(node.get("title", ""))
	var summary := str(node.get("current_summary", ""))

	if summary == "":
		if body.size() > 0:
			summary = str(body[0])
		else:
			summary = ""

	var graph := _normalize_graph(story_data.get("graph", {}))

	if node.has("graph"):
		graph = _normalize_graph(node.get("graph", {}))

	var attrs: Dictionary = {}

	if node.has("attrs") and node["attrs"] is Dictionary:
		attrs = node["attrs"]
	else:
		attrs = {
			"type": node_type,
			"condition": str(node.get("condition", "—")),
			"character": str(node.get("character", "你")),
			"reward": str(node.get("reward", "—"))
		}

	return {
		"chapter": str(meta.get("chapter", "")),
		"time_options": meta.get("time_options", []),
		"time_index": int(node.get("time_index", 0)),
		"chapter_intro": str(meta.get("chapter_intro", "")),

		"target": str(meta.get("target", "")),
		"keywords": visible_keywords,
		"keyword_found": visible_keywords.size(),
		"keyword_total": total_keyword_count,
		"progress": progress,
		"read_nodes": "%d / %d" % [read_count, total_node_count],
		"chapter_explore": "%d%%" % progress,

		"node_type": node_type,
		"title": title,
		"body": body,
		"quote": str(node.get("quote", "")),
		"choices": node.get("choices", []),

		"current_summary": summary,
		"clues": _resolve_node_clues(node),
		"graph": graph,
		"attrs": attrs
	}


func choose_by_title(choice_title: String) -> bool:
	var node := _get_current_node()

	if node.is_empty():
		return false

	var choices = node.get("choices", [])

	if not (choices is Array):
		return false

	for choice in choices:
		if not (choice is Dictionary):
			continue

		if str(choice.get("title", "")) == choice_title:
			var target_id := str(choice.get("target", ""))

			if target_id == "":
				push_warning("StoryManager: choice has no target: " + choice_title)
				return false

			return goto_node(target_id)

	return false


func goto_node(node_id: String) -> bool:
	if not _get_nodes().has(node_id):
		push_warning("StoryManager: target node not found: " + node_id)
		return false

	current_node_id = node_id
	_apply_node_discovery(current_node_id)

	return true


func get_current_node_id() -> String:
	return current_node_id


func _apply_node_discovery(node_id: String) -> void:
	var nodes := _get_nodes()

	if not nodes.has(node_id):
		return

	read_node_ids[node_id] = true

	var node = nodes[node_id]

	if not (node is Dictionary):
		return

	var keywords = node.get("keywords", [])

	if keywords is Array:
		for keyword in keywords:
			discovered_keywords[str(keyword)] = true

	var clues = node.get("clues", [])

	if clues is Array:
		for clue_id in clues:
			discovered_clues[str(clue_id)] = true


func _resolve_node_clues(node: Dictionary) -> Array:
	var result: Array = []
	var clue_ids = node.get("clues", [])

	if not (clue_ids is Array):
		return result

	for clue_id_raw in clue_ids:
		var clue_id := str(clue_id_raw)

		if clue_data.has(clue_id) and clue_data[clue_id] is Dictionary:
			var clue: Dictionary = clue_data[clue_id].duplicate(true)
			clue["id"] = clue_id
			result.append(clue)
		else:
			result.append({
				"id": clue_id,
				"title": clue_id,
				"desc": "未找到线索数据。",
				"icon": "search",
				"type": "未知"
			})

	return result


func _normalize_graph(raw_graph) -> Dictionary:
	var result := {
		"nodes": [],
		"edges": []
	}

	if not (raw_graph is Dictionary):
		return result

	var raw_nodes = raw_graph.get("nodes", [])

	if raw_nodes is Array:
		for raw_node in raw_nodes:
			if not (raw_node is Dictionary):
				continue

			var node: Dictionary = raw_node.duplicate(true)
			node["pos"] = _to_vector2(raw_node.get("pos", [0, 0]))
			result["nodes"].append(node)

	var raw_edges = raw_graph.get("edges", [])

	if raw_edges is Array:
		for raw_edge in raw_edges:
			if not (raw_edge is Array):
				continue

			if raw_edge.size() < 2:
				continue

			result["edges"].append([
				_to_vector2(raw_edge[0]),
				_to_vector2(raw_edge[1])
			])

	return result


func _to_vector2(value) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	if value is Dictionary:
		return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))

	return Vector2.ZERO


func _get_current_node() -> Dictionary:
	var nodes := _get_nodes()

	if not nodes.has(current_node_id):
		return {}

	var node = nodes[current_node_id]

	if node is Dictionary:
		return node

	return {}


func _get_meta() -> Dictionary:
	var meta = story_data.get("meta", {})

	if meta is Dictionary:
		return meta

	return {}


func _get_nodes() -> Dictionary:
	var nodes = story_data.get("nodes", {})

	if nodes is Dictionary:
		return nodes

	return {}


func _get_all_keywords() -> Array:
	var meta := _get_meta()
	var all_keywords = meta.get("all_keywords", [])

	if all_keywords is Array:
		return all_keywords

	var result: Array = []
	var nodes := _get_nodes()

	for node_id in nodes.keys():
		var node = nodes[node_id]

		if not (node is Dictionary):
			continue

		var keywords = node.get("keywords", [])

		if not (keywords is Array):
			continue

		for keyword in keywords:
			var keyword_text := str(keyword)

			if not result.has(keyword_text):
				result.append(keyword_text)

	return result


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("StoryManager: file not found: " + path)
		return {}

	var content := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var error := json.parse(content)

	if error != OK:
		push_error("StoryManager: json parse error: %s, line %d" % [
			json.get_error_message(),
			json.get_error_line()
		])
		return {}

	var data = json.data

	if data is Dictionary:
		return data

	push_error("StoryManager: json root must be Dictionary: " + path)
	return {}
