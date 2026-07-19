extends RefCounted
class_name PhoneDataLoader

var contacts_by_id: Dictionary = {}
var initial_contacts: Array[String] = []
var calls_by_id: Dictionary = {}
var messages_by_id: Dictionary = {}


func load_case_data(data_path: String, keyword_effects: Array[Dictionary]) -> bool:
	clear()
	if data_path == "":
		return true
	var contacts_path := data_path + "/contacts.json"
	var calls_path := data_path + "/phone_calls.json"
	if not FileAccess.file_exists(contacts_path) and not FileAccess.file_exists(calls_path):
		return true
	if not FileAccess.file_exists(contacts_path) or not FileAccess.file_exists(calls_path):
		push_error("PhoneDataLoader: contacts.json and phone_calls.json must be provided together: " + data_path)
		return false
	var contacts_document := _read_json(contacts_path)
	var calls_document := _read_json(calls_path)
	if contacts_document.is_empty() or calls_document.is_empty():
		return false
	if not _load_contacts(contacts_document):
		return false
	if not _load_calls(calls_document):
		return false
	return _validate_references(keyword_effects)


func clear() -> void:
	contacts_by_id.clear()
	initial_contacts.clear()
	calls_by_id.clear()
	messages_by_id.clear()


func get_contact(contact_id: String) -> Dictionary:
	var value: Variant = contacts_by_id.get(contact_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func get_contacts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for contact_value in contacts_by_id.values():
		result.append((contact_value as Dictionary).duplicate(true))
	return result


func get_initial_contacts() -> Array[String]:
	return initial_contacts.duplicate()


func get_calls() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for call_value in calls_by_id.values():
		result.append((call_value as Dictionary).duplicate(true))
	return result


func get_call(call_id: String) -> Dictionary:
	var value: Variant = calls_by_id.get(call_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func get_message(message_id: String) -> Dictionary:
	var value: Variant = messages_by_id.get(message_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func validate_completion_nodes(case_loader: CaseDataLoader) -> bool:
	for call_value in calls_by_id.values():
		var call_data: Dictionary = call_value
		var node_id := str(call_data.get("completion_node_id", ""))
		if node_id != "" and case_loader.get_node(node_id).is_empty():
			push_error("PhoneDataLoader: call completion node does not exist: %s -> %s" % [str(call_data.get("id", "")), node_id])
			return false
	return true


func _load_contacts(document: Dictionary) -> bool:
	var contacts_value: Variant = document.get("contacts", [])
	var initial_value: Variant = document.get("initial_contacts", [])
	if not (contacts_value is Array) or not (initial_value is Array):
		push_error("PhoneDataLoader: contacts and initial_contacts must be arrays.")
		return false
	for contact_value in (contacts_value as Array):
		if not (contact_value is Dictionary):
			push_error("PhoneDataLoader: contact entry must be a Dictionary.")
			return false
		var contact: Dictionary = contact_value
		var contact_id := str(contact.get("id", ""))
		var display_name := str(contact.get("display_name", ""))
		if contact_id == "" or display_name == "" or contacts_by_id.has(contact_id):
			push_error("PhoneDataLoader: invalid or duplicate contact id: " + contact_id)
			return false
		contacts_by_id[contact_id] = contact.duplicate(true)
	for initial_contact_value in (initial_value as Array):
		var contact_id := str(initial_contact_value)
		if contact_id == "" or not contacts_by_id.has(contact_id):
			push_error("PhoneDataLoader: initial contact does not exist: " + contact_id)
			return false
		if not initial_contacts.has(contact_id):
			initial_contacts.append(contact_id)
	return true


func _load_calls(document: Dictionary) -> bool:
	var calls_value: Variant = document.get("calls", [])
	var messages_value: Variant = document.get("messages", [])
	if not (calls_value is Array) or not (messages_value is Array):
		push_error("PhoneDataLoader: calls and messages must be arrays.")
		return false
	for message_value in (messages_value as Array):
		if not (message_value is Dictionary):
			push_error("PhoneDataLoader: message entry must be a Dictionary.")
			return false
		var message: Dictionary = message_value
		var message_id := str(message.get("id", ""))
		if message_id == "" or str(message.get("speaker", "")) == "" or str(message.get("text", "")) == "" or messages_by_id.has(message_id):
			push_error("PhoneDataLoader: invalid or duplicate message id: " + message_id)
			return false
		messages_by_id[message_id] = message.duplicate(true)
	for call_value in (calls_value as Array):
		if not (call_value is Dictionary):
			push_error("PhoneDataLoader: call entry must be a Dictionary.")
			return false
		var call_data: Dictionary = call_value
		var call_id := str(call_data.get("id", ""))
		if call_id == "" or calls_by_id.has(call_id):
			push_error("PhoneDataLoader: invalid or duplicate call id: " + call_id)
			return false
		calls_by_id[call_id] = call_data.duplicate(true)
	return true


func _validate_references(keyword_effects: Array[Dictionary]) -> bool:
	var keyword_ids: Dictionary = {}
	for effect_rule in keyword_effects:
		var keyword_id := str(effect_rule.get("keyword_id", ""))
		keyword_ids[keyword_id] = true
		for effect_value in effect_rule.get("effects", []):
			if effect_value is Dictionary and str((effect_value as Dictionary).get("type", "")) == "add_contact":
				var contact_id := str((effect_value as Dictionary).get("contact_id", ""))
				if not contacts_by_id.has(contact_id):
					push_error("PhoneDataLoader: keyword effect references missing contact: " + contact_id)
					return false
	for call_value in calls_by_id.values():
		var call_data: Dictionary = call_value
		var call_id := str(call_data.get("id", ""))
		var contact_id := str(call_data.get("contact_id", ""))
		var entry_message_id := str(call_data.get("entry_message_id", ""))
		if not contacts_by_id.has(contact_id):
			push_error("PhoneDataLoader: call references missing contact: %s -> %s" % [call_id, contact_id])
			return false
		if str(call_data.get("direction", "")) not in ["incoming", "outgoing"]:
			push_error("PhoneDataLoader: call has invalid direction: " + call_id)
			return false
		if not messages_by_id.has(entry_message_id):
			push_error("PhoneDataLoader: call entry message does not exist: %s -> %s" % [call_id, entry_message_id])
			return false
	for message_value in messages_by_id.values():
		var message: Dictionary = message_value
		var message_id := str(message.get("id", ""))
		var next_id := str(message.get("next", ""))
		if next_id != "" and not messages_by_id.has(next_id):
			push_error("PhoneDataLoader: message next target does not exist: %s -> %s" % [message_id, next_id])
			return false
		var choices_value: Variant = message.get("choices", [])
		if not (choices_value is Array):
			push_error("PhoneDataLoader: message choices must be an Array: " + message_id)
			return false
		var choice_ids: Dictionary = {}
		for choice_value in (choices_value as Array):
			if not (choice_value is Dictionary):
				push_error("PhoneDataLoader: choice must be a Dictionary: " + message_id)
				return false
			var choice: Dictionary = choice_value
			var choice_id := str(choice.get("id", ""))
			var choice_next := str(choice.get("next", ""))
			if choice_id == "" or str(choice.get("text", "")) == "" or choice_ids.has(choice_id):
				push_error("PhoneDataLoader: invalid or duplicate choice in message: " + message_id)
				return false
			choice_ids[choice_id] = true
			if choice_next != "" and not messages_by_id.has(choice_next):
				push_error("PhoneDataLoader: choice target does not exist: %s/%s -> %s" % [message_id, choice_id, choice_next])
				return false
			if choice_next == "" and not bool(choice.get("end_call", false)):
				push_error("PhoneDataLoader: choice requires next or end_call: %s/%s" % [message_id, choice_id])
				return false
		var waiting_keyword := str(message.get("wait_for_keyword", ""))
		if waiting_keyword != "" and not keyword_ids.has(waiting_keyword):
			push_error("PhoneDataLoader: message waits for unknown keyword id: %s -> %s" % [message_id, waiting_keyword])
			return false
		if next_id == "" and (choices_value as Array).is_empty() and waiting_keyword == "" and not bool(message.get("end_call", false)):
			push_error("PhoneDataLoader: message has no next, choices, keyword wait, or end marker: " + message_id)
			return false
	return true


func _read_json(path: String) -> Dictionary:
	var json := JSON.new()
	var error := json.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		push_error("PhoneDataLoader: JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		push_error("PhoneDataLoader: JSON root must be a Dictionary: " + path)
		return {}
	return (json.data as Dictionary).duplicate(true)
