extends Node

var story_data: Dictionary = {}
var clue_data: Dictionary = {}
var audio_clue_data: Dictionary = {}

var current_node_id: String = ""
var read_node_ids: Dictionary = {}
var discovered_keywords: Dictionary = {}
var discovered_clues: Dictionary = {}
var discovered_audio_ids: Dictionary = {}
var listened_audio_ids: Dictionary = {}


const DEFAULT_STORY_PATH := "res://data/story/chapter_01.json"
const DEFAULT_CLUES_PATH := "res://data/clues/clues.json"
const DEFAULT_AUDIO_CLUES_PATH := "res://data/audio/audio_clues.json"
const SAVE_DIR := "user://saves"
const AUTO_SAVE_PATH := "user://saves/save_00.json"
const AUTO_SAVE_SLOT := 0


func load_story(story_path: String, clues_path: String) -> bool:
	story_data = _read_json(story_path)
	clue_data = _read_json(clues_path)
	audio_clue_data = _read_json(DEFAULT_AUDIO_CLUES_PATH)

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
	discovered_audio_ids.clear()
	listened_audio_ids.clear()

	_apply_node_discovery(current_node_id)

	return true


func has_story_loaded() -> bool:
	return not story_data.is_empty() and not _get_nodes().is_empty()


func ensure_story_loaded() -> bool:
	if has_story_loaded():
		return true

	return load_story(DEFAULT_STORY_PATH, DEFAULT_CLUES_PATH)


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
	var raw_body: Variant = node.get("body", [])

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
		"related_audio_clues": _resolve_node_audio_clues(node),
		"graph": graph,
		"attrs": attrs
	}


func choose_by_title(choice_title: String) -> bool:
	var node := _get_current_node()

	if node.is_empty():
		return false

	var choices: Variant = node.get("choices", [])

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
	write_auto_save()

	return true


func get_current_node_id() -> String:
	return current_node_id


func mark_audio_listened(audio_id: String) -> void:
	if audio_id == "":
		return

	discovered_audio_ids[audio_id] = true
	listened_audio_ids[audio_id] = true
	write_auto_save()


func make_save_data(slot: int, save_name: String, is_auto: bool) -> Dictionary:
	var render_data: Dictionary = get_render_data()
	var read_nodes_text: String = str(render_data.get("read_nodes", "0 / 0"))
	var progress_text: String = str(render_data.get("chapter_explore", "0%"))
	var title: String = str(render_data.get("title", "当前节点"))
	var chapter: String = str(render_data.get("chapter", "第一章"))
	var now_unix: int = int(Time.get_unix_time_from_system())

	return {
		"slot": AUTO_SAVE_SLOT if is_auto else slot,
		"is_auto": is_auto,
		"is_empty": false,
		"name": "自动存档" if is_auto else save_name,
		"chapter_line": "%s · %s" % [
			chapter,
			_get_current_time_option(render_data)
		],
		"chapter_progress": "%s %s 节点" % [
			chapter,
			read_nodes_text
		],
		"game_progress": progress_text,
		"save_time": _current_time_string(),
		"save_unix": now_unix,
		"current_node_id": current_node_id,
		"current_title": title,
		"state": {
			"read_node_ids": read_node_ids.keys(),
			"discovered_keywords": discovered_keywords.keys(),
			"discovered_clues": discovered_clues.keys(),
			"discovered_audio_ids": discovered_audio_ids.keys(),
			"listened_audio_ids": listened_audio_ids.keys()
		},
		"note": "自动存档" if is_auto else "手动档位"
	}


func write_auto_save() -> bool:
	if current_node_id == "" or not has_story_loaded():
		return false

	_ensure_save_dir()

	var data: Dictionary = make_save_data(AUTO_SAVE_SLOT, "自动存档", true)
	var file: FileAccess = FileAccess.open(AUTO_SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_warning("StoryManager: unable to write auto save: " + AUTO_SAVE_PATH)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	return true


func auto_save() -> bool:
	return write_auto_save()


func restore_from_save(save_data: Dictionary) -> bool:
	if save_data.is_empty() or bool(save_data.get("is_empty", false)):
		return false

	if not ensure_story_loaded():
		return false

	var saved_node_id: String = str(save_data.get("current_node_id", ""))

	if saved_node_id == "" or not _get_nodes().has(saved_node_id):
		push_warning("StoryManager: save target node not found: " + saved_node_id)
		return false

	read_node_ids.clear()
	discovered_keywords.clear()
	discovered_clues.clear()

	var state: Dictionary = {}
	var raw_state: Variant = save_data.get("state", {})

	if raw_state is Dictionary:
		state = raw_state

	_restore_string_set(read_node_ids, state.get("read_node_ids", []))
	_restore_string_set(discovered_keywords, state.get("discovered_keywords", []))
	_restore_string_set(discovered_clues, state.get("discovered_clues", []))
	_restore_string_set(discovered_audio_ids, state.get("discovered_audio_ids", []))
	_restore_string_set(listened_audio_ids, state.get("listened_audio_ids", []))

	current_node_id = saved_node_id
	_apply_node_discovery(current_node_id)

	return true


func _get_current_time_option(render_data: Dictionary) -> String:
	var time_options: Variant = render_data.get("time_options", [])
	var time_index: int = int(render_data.get("time_index", 0))

	if time_options is Array and time_options.size() > 0:
		time_index = int(clamp(time_index, 0, time_options.size() - 1))
		return str(time_options[time_index])

	return "第一天 · 夜晚"


func _current_time_string() -> String:
	var time_data: Dictionary = Time.get_datetime_dict_from_system()

	return "%04d / %02d / %02d\n%02d:%02d:%02d" % [
		int(time_data["year"]),
		int(time_data["month"]),
		int(time_data["day"]),
		int(time_data["hour"]),
		int(time_data["minute"]),
		int(time_data["second"])
	]


func _ensure_save_dir() -> void:
	var user_dir: DirAccess = DirAccess.open("user://")

	if user_dir == null:
		return

	if not user_dir.dir_exists("saves"):
		user_dir.make_dir("saves")


func _restore_string_set(target: Dictionary, raw_values: Variant) -> void:
	if raw_values is Array:
		for value in raw_values:
			var key: String = str(value)

			if key != "":
				target[key] = true
	elif raw_values is Dictionary:
		for value in raw_values.keys():
			var key: String = str(value)

			if key != "":
				target[key] = true


func _apply_node_discovery(node_id: String) -> void:
	var nodes := _get_nodes()

	if not nodes.has(node_id):
		return

	read_node_ids[node_id] = true

	var node: Variant = nodes[node_id]

	if not (node is Dictionary):
		return

	var keywords: Variant = node.get("keywords", [])

	if keywords is Array:
		for keyword in keywords:
			discovered_keywords[str(keyword)] = true

	var clues: Variant = node.get("clues", [])

	if clues is Array:
		for clue_id in clues:
			discovered_clues[str(clue_id)] = true

	var audio_clues: Variant = node.get("audio_clues", [])

	if audio_clues is Array:
		for audio_id in audio_clues:
			discovered_audio_ids[str(audio_id)] = true

	for audio_clue in _get_all_audio_clues():
		if not (audio_clue is Dictionary):
			continue

		if str(audio_clue.get("unlock_node", "")) != node_id:
			continue

		var unlocked_audio_id: String = str(audio_clue.get("id", ""))

		if unlocked_audio_id != "":
			discovered_audio_ids[unlocked_audio_id] = true


func _resolve_node_clues(node: Dictionary) -> Array:
	var result: Array = []
	var clue_ids: Variant = node.get("clues", [])

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


func _resolve_node_audio_clues(node: Dictionary) -> Array:
	var result: Array = []
	var audio_ids: Array = []
	var raw_audio_ids: Variant = node.get("audio_clues", [])

	if raw_audio_ids is Array:
		for raw_audio_id in raw_audio_ids:
			var audio_id: String = str(raw_audio_id)

			if audio_id != "" and not audio_ids.has(audio_id):
				audio_ids.append(audio_id)

	for audio_clue in _get_all_audio_clues():
		if not (audio_clue is Dictionary):
			continue

		var audio_id: String = str(audio_clue.get("id", ""))

		if audio_id == "":
			continue

		if str(audio_clue.get("unlock_node", "")) == current_node_id and not audio_ids.has(audio_id):
			audio_ids.append(audio_id)

	for audio_id in audio_ids:
		var audio_clue: Dictionary = _get_audio_clue(audio_id)

		if audio_clue.is_empty():
			continue

		var item: Dictionary = audio_clue.duplicate(true)
		item["discovered"] = discovered_audio_ids.has(audio_id)
		item["listened"] = listened_audio_ids.has(audio_id)
		result.append(item)

	return result


func _get_audio_clue(audio_id: String) -> Dictionary:
	for audio_clue in _get_all_audio_clues():
		if not (audio_clue is Dictionary):
			continue

		if str(audio_clue.get("id", "")) == audio_id:
			return audio_clue

	return {}


func _get_all_audio_clues() -> Array:
	var raw_audio_clues: Variant = audio_clue_data.get("audio_clues", [])

	if raw_audio_clues is Array:
		return raw_audio_clues

	return []


func _normalize_graph(raw_graph: Variant) -> Dictionary:
	var result := {
		"nodes": [],
		"edges": []
	}

	if not (raw_graph is Dictionary):
		return result

	var raw_nodes: Variant = raw_graph.get("nodes", [])

	if raw_nodes is Array:
		for raw_node in raw_nodes:
			if not (raw_node is Dictionary):
				continue

			var node: Dictionary = raw_node.duplicate(true)
			node["pos"] = _to_vector2(raw_node.get("pos", [0, 0]))
			result["nodes"].append(node)

	var raw_edges: Variant = raw_graph.get("edges", [])

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


func _to_vector2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	if value is Dictionary:
		return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))

	return Vector2.ZERO


func _get_current_node() -> Dictionary:
	var nodes := _get_nodes()

	if not nodes.has(current_node_id):
		return {}

	var node: Variant = nodes[current_node_id]

	if node is Dictionary:
		return node

	return {}


func _get_meta() -> Dictionary:
	var meta: Variant = story_data.get("meta", {})

	if meta is Dictionary:
		return meta

	return {}


func _get_nodes() -> Dictionary:
	var nodes: Variant = story_data.get("nodes", {})

	if nodes is Dictionary:
		return nodes

	return {}


func _get_all_keywords() -> Array:
	var meta := _get_meta()
	var all_keywords: Variant = meta.get("all_keywords", [])

	if all_keywords is Array:
		return all_keywords

	var result: Array = []
	var nodes := _get_nodes()

	for node_id in nodes.keys():
		var node: Variant = nodes[node_id]

		if not (node is Dictionary):
			continue

		var keywords: Variant = node.get("keywords", [])

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

	var data: Variant = json.data

	if data is Dictionary:
		return data

	push_error("StoryManager: json root must be Dictionary: " + path)
	return {}
