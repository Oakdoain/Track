extends RefCounted
class_name PhoneManager

signal state_changed
signal call_ended(next_node_id: String)
signal feedback_requested(message: String)

const TRANSCRIPT_BASE_DELAY := 0.45
const TRANSCRIPT_SECONDS_PER_CHARACTER := 0.055
const TRANSCRIPT_MINIMUM_DELAY := 0.75
const TRANSCRIPT_MAXIMUM_DELAY := 4.5

var data_loader := PhoneDataLoader.new()
var runtime_state: CaseRuntimeState
var case_id: String = ""
var _configured: bool = false


func configure(case_loader: CaseDataLoader, state: CaseRuntimeState) -> bool:
	runtime_state = state
	case_id = case_loader.get_current_case_id()
	_configured = data_loader.load_case_data(
		case_loader.get_case_data_path(),
		case_loader.get_keyword_effects()
	)
	if not _configured or not data_loader.validate_completion_nodes(case_loader):
		_configured = false
		return false
	for contact_id in data_loader.get_initial_contacts():
		runtime_state.add_discovered_contact(contact_id)
	_validate_restored_call()
	return true


func update(delta: float) -> void:
	if runtime_state == null or runtime_state.active_call.is_empty() or delta <= 0.0:
		return
	var active := runtime_state.active_call
	if str(active.get("status", "")) != "active" or not bool(active.get("is_waiting_message", false)):
		return
	var total := maxf(0.0, float(active.get("transcript_delay_total", 0.0)))
	var elapsed := minf(total, maxf(0.0, float(active.get("transcript_delay_elapsed", 0.0))) + delta)
	active["transcript_delay_elapsed"] = elapsed
	runtime_state.active_call = active
	if elapsed >= total:
		_reveal_pending_message()


func begin_available_incoming_call() -> bool:
	if not _configured or runtime_state == null or not runtime_state.active_call.is_empty():
		return false
	for call_data in data_loader.get_calls():
		if str(call_data.get("direction", "")) == "incoming" and _conditions_match(call_data.get("start_conditions", {})):
			return _begin_call(call_data, "incoming")
	return false


func answer_incoming_call() -> void:
	if runtime_state == null or str(runtime_state.active_call.get("status", "")) != "incoming_waiting":
		return
	var active := runtime_state.active_call
	var entry_message_id := str(active.get("message_id", ""))
	active["status"] = "active"
	active["message_id"] = ""
	active["transcript"] = []
	active["choices_made"] = []
	active["presented_choices"] = []
	active["waiting_for_keyword"] = ""
	runtime_state.active_call = active
	_schedule_message(entry_message_id)


func reject_current_call() -> void:
	if runtime_state == null or runtime_state.active_call.is_empty():
		return
	var call_data := data_loader.get_call(str(runtime_state.active_call.get("call_id", "")))
	var retry_flag := str(call_data.get("reject_retry_flag", ""))
	if retry_flag != "":
		runtime_state.flags[retry_flag] = true
	interrupt_current_call()


func choose(choice_id: String) -> void:
	if runtime_state == null or str(runtime_state.active_call.get("status", "")) != "active":
		return
	var active := runtime_state.active_call
	if bool(active.get("is_waiting_message", false)):
		return
	var choices_value: Variant = active.get("presented_choices", [])
	if not (choices_value is Array):
		return
	var selected: Dictionary = {}
	for choice_value in (choices_value as Array):
		if choice_value is Dictionary and str((choice_value as Dictionary).get("id", "")) == choice_id:
			selected = (choice_value as Dictionary).duplicate(true)
			break
	if selected.is_empty():
		push_warning("PhoneManager: ignored unavailable choice: " + choice_id)
		return
	var transcript: Array = active.get("transcript", [])
	transcript.append({
		"speaker": "player",
		"text": str(selected.get("text", "")),
		"message_id": str(active.get("message_id", ""))
	})
	var choices_made: Array = active.get("choices_made", [])
	choices_made.append({
		"message_id": str(active.get("message_id", "")),
		"choice_id": choice_id
	})
	active["transcript"] = transcript
	active["choices_made"] = choices_made
	active["presented_choices"] = []
	active["waiting_for_keyword"] = ""
	runtime_state.active_call = active
	_apply_choice_effects(selected)
	state_changed.emit()
	if bool(selected.get("end_call", false)):
		_finish_current_call()
		return
	_schedule_message(str(selected.get("next", "")))


func notify_keyword_completed(keyword_id: String) -> void:
	if runtime_state == null or str(runtime_state.active_call.get("status", "")) != "active":
		return
	var active := runtime_state.active_call
	if str(active.get("waiting_for_keyword", "")) != keyword_id:
		return
	var current_message := data_loader.get_message(str(active.get("message_id", "")))
	active["waiting_for_keyword"] = ""
	runtime_state.active_call = active
	state_changed.emit()
	_schedule_message(str(current_message.get("next", "")))


func interrupt_current_call() -> void:
	if runtime_state == null or runtime_state.active_call.is_empty():
		return
	runtime_state.active_call.clear()
	state_changed.emit()


func request_outgoing_call(contact_id: String) -> bool:
	if runtime_state == null or not runtime_state.has_discovered_contact(contact_id):
		push_warning("PhoneManager: outgoing call requested for undiscovered contact: " + contact_id)
		return false
	if not runtime_state.active_call.is_empty():
		return false
	for call_data in data_loader.get_calls():
		if str(call_data.get("contact_id", "")) != contact_id:
			continue
		var retry_flag := str(call_data.get("reject_retry_flag", ""))
		if retry_flag != "" and bool(runtime_state.flags.get(retry_flag, false)) and _conditions_match(call_data.get("start_conditions", {})):
			return _begin_call(call_data, "outgoing_retry")
	print("PhoneManager: outgoing call is not implemented for contact: " + contact_id)
	return false


func has_visible_call() -> bool:
	return runtime_state != null and not runtime_state.active_call.is_empty()


func get_active_call() -> Dictionary:
	return runtime_state.active_call.duplicate(true) if runtime_state != null else {}


func get_contact(contact_id: String) -> Dictionary:
	return data_loader.get_contact(contact_id)


func get_discovered_contact_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if runtime_state == null:
		return result
	for contact_id in runtime_state.discovered_contacts:
		var contact := data_loader.get_contact(contact_id)
		if not contact.is_empty():
			result.append(contact)
	return result


func get_transcript_delay_for_message(message_id: String) -> float:
	var message := data_loader.get_message(message_id)
	return _calculate_transcript_delay(str(message.get("text", ""))) if not message.is_empty() else 0.0


func refresh_after_runtime_restore() -> void:
	if not _configured or runtime_state == null:
		return
	for contact_id in data_loader.get_initial_contacts():
		runtime_state.add_discovered_contact(contact_id)
	_validate_restored_call()


func _begin_call(call_data: Dictionary, direction: String) -> bool:
	var call_id := str(call_data.get("id", ""))
	var contact_id := str(call_data.get("contact_id", ""))
	if call_id == "" or contact_id == "":
		return false
	runtime_state.add_discovered_contact(contact_id)
	runtime_state.active_call = {
		"call_id": call_id,
		"contact_id": contact_id,
		"direction": direction,
		"status": "incoming_waiting",
		"message_id": str(call_data.get("entry_message_id", "")),
		"transcript": [],
		"choices_made": [],
		"presented_choices": [],
		"waiting_for_keyword": "",
		"is_waiting_message": false,
		"pending_message_id": "",
		"transcript_delay_elapsed": 0.0,
		"transcript_delay_total": 0.0
	}
	state_changed.emit()
	return true


func _schedule_message(message_id: String) -> void:
	if message_id == "":
		return
	var message := data_loader.get_message(message_id)
	if message.is_empty():
		push_error("PhoneManager: missing message target at runtime: " + message_id)
		interrupt_current_call()
		return
	var active := runtime_state.active_call
	active["is_waiting_message"] = true
	active["pending_message_id"] = message_id
	active["transcript_delay_elapsed"] = 0.0
	active["transcript_delay_total"] = _calculate_transcript_delay(str(message.get("text", "")))
	active["presented_choices"] = []
	active["waiting_for_keyword"] = ""
	runtime_state.active_call = active
	state_changed.emit()


func _reveal_pending_message() -> void:
	var active := runtime_state.active_call
	var message_id := str(active.get("pending_message_id", ""))
	var message := data_loader.get_message(message_id)
	if message.is_empty():
		push_error("PhoneManager: pending message target is missing: " + message_id)
		interrupt_current_call()
		return
	active["is_waiting_message"] = false
	active["pending_message_id"] = ""
	active["transcript_delay_elapsed"] = 0.0
	active["transcript_delay_total"] = 0.0
	active["message_id"] = message_id
	var transcript: Array = active.get("transcript", [])
	transcript.append({
		"speaker": str(message.get("speaker", "assistant")),
		"text": str(message.get("text", "")),
		"message_id": message_id,
		"keywords": (message.get("keywords", []) as Array).duplicate(true) if message.get("keywords", []) is Array else []
	})
	active["transcript"] = transcript
	active["presented_choices"] = []
	active["waiting_for_keyword"] = str(message.get("wait_for_keyword", ""))
	var choices_value: Variant = message.get("choices", [])
	if choices_value is Array:
		active["presented_choices"] = (choices_value as Array).duplicate(true)
	runtime_state.active_call = active
	state_changed.emit()
	if bool(message.get("end_call", false)):
		_finish_current_call()
		return
	if str(active.get("waiting_for_keyword", "")) != "" or not (active.get("presented_choices", []) as Array).is_empty():
		return
	_schedule_message(str(message.get("next", "")))


func _calculate_transcript_delay(text: String) -> float:
	var visible_text := text
	var bbcode_regex := RegEx.new()
	if bbcode_regex.compile("\\[[^\\]]*\\]") == OK:
		visible_text = bbcode_regex.sub(visible_text, "", true)
	var visible_character_count := 0
	var punctuation_delay := 0.0
	for index in range(visible_text.length()):
		var character := visible_text.substr(index, 1)
		var code := visible_text.unicode_at(index)
		if code < 32 and character != "\n":
			continue
		visible_character_count += 1
		match character:
			"，", "：":
				punctuation_delay += 0.10
			"。", "？", "！":
				punctuation_delay += 0.20
			"\n":
				punctuation_delay += 0.25
	return clampf(
		TRANSCRIPT_BASE_DELAY
		+ float(visible_character_count) * TRANSCRIPT_SECONDS_PER_CHARACTER
		+ punctuation_delay,
		TRANSCRIPT_MINIMUM_DELAY,
		TRANSCRIPT_MAXIMUM_DELAY
	)


func _finish_current_call() -> void:
	var active := runtime_state.active_call
	var call_data := data_loader.get_call(str(active.get("call_id", "")))
	var next_node_id := str(call_data.get("completion_node_id", ""))
	runtime_state.active_call.clear()
	state_changed.emit()
	call_ended.emit(next_node_id)


func _apply_choice_effects(choice: Dictionary) -> void:
	var effects_value: Variant = choice.get("effects", [])
	if not (effects_value is Array):
		return
	for effect_value in (effects_value as Array):
		if not (effect_value is Dictionary):
			continue
		var effect: Dictionary = effect_value
		if str(effect.get("type", "")) == "set_flag":
			var flag_id := str(effect.get("flag_id", ""))
			if flag_id != "":
				runtime_state.flags[flag_id] = bool(effect.get("value", true))


func _conditions_match(conditions_value: Variant) -> bool:
	if not (conditions_value is Dictionary):
		return true
	var conditions: Dictionary = conditions_value
	if str(conditions.get("case_id", case_id)) != case_id:
		return false
	var required_node_id := str(conditions.get("node_id", ""))
	if required_node_id != "" and runtime_state.current_node_id != required_node_id:
		return false
	for flag_value in conditions.get("forbidden_flags", []):
		if bool(runtime_state.flags.get(str(flag_value), false)):
			return false
	var required_flags: Variant = conditions.get("required_flags", {})
	if required_flags is Dictionary:
		for flag_value in (required_flags as Dictionary).keys():
			if bool(runtime_state.flags.get(str(flag_value), false)) != bool((required_flags as Dictionary).get(flag_value)):
				return false
	return true


func _validate_restored_call() -> void:
	if runtime_state.active_call.is_empty():
		return
	var active := runtime_state.active_call
	var call_id := str(active.get("call_id", ""))
	var message_id := str(active.get("message_id", ""))
	var pending_message_id := str(active.get("pending_message_id", ""))
	if data_loader.get_call(call_id).is_empty():
		push_warning("PhoneManager: cleared active call absent from current phone data: " + call_id)
		runtime_state.active_call.clear()
		return
	if message_id != "" and data_loader.get_message(message_id).is_empty():
		push_warning("PhoneManager: cleared active call with missing current message: " + message_id)
		runtime_state.active_call.clear()
		return
	if pending_message_id != "" and data_loader.get_message(pending_message_id).is_empty():
		push_warning("PhoneManager: cleared active call with missing pending message: " + pending_message_id)
		runtime_state.active_call.clear()
		return
	active["is_waiting_message"] = bool(active.get("is_waiting_message", false))
	active["pending_message_id"] = pending_message_id
	active["transcript_delay_total"] = maxf(0.0, float(active.get("transcript_delay_total", 0.0)))
	active["transcript_delay_elapsed"] = clampf(
		float(active.get("transcript_delay_elapsed", 0.0)),
		0.0,
		float(active.get("transcript_delay_total", 0.0))
	)
	if bool(active.get("is_waiting_message", false)) and pending_message_id == "":
		active["is_waiting_message"] = false
	runtime_state.active_call = active
