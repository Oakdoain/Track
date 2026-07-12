extends RefCounted
class_name CaseRuntimeState

var current_node_id: String = ""
var unlocked_nodes: Dictionary = {}
var flags: Dictionary = {}
var last_safe_autosave_node_id: String = ""


func set_current_node(node_id: String, autosave: bool) -> void:
	current_node_id = node_id
	unlocked_nodes[node_id] = true

	if autosave:
		last_safe_autosave_node_id = node_id
