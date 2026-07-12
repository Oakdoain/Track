extends RefCounted
class_name CaseDataLoader

const DEFAULT_NODES_PATH := "res://data/cases/case_01/control_backup/nodes.json"

var data: Dictionary = {}
var nodes_by_id: Dictionary = {}


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
