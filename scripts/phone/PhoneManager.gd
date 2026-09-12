extends RefCounted
class_name PhoneManager

signal state_changed
signal call_ended(next_node_id: String)
signal feedback_requested(message: String)
signal transcript_character_revealed(profile_id: String, character: String)

const TRANSCRIPT_PRE_DELAY := 0.30
const TRANSCRIPT_CHARACTERS_PER_SECOND := 23.0
const CALL_END_HOLD_SECONDS := 0.45
const OUTGOING_CONNECT_DELAY := 1.8

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
	var status := str(active.get("status", ""))
	if status == "ending":
		if bool(active.get("call_end_audio_completed", false)):
			active["call_end_elapsed"] = maxf(0.0, float(active.get("call_end_elapsed", 0.0))) + delta
			runtime_state.active_call = active
			if float(active["call_end_elapsed"]) >= CALL_END_HOLD_SECONDS:
				_finalize_ended_call()
		return
	if status == "outgoing_waiting":
		var total := maxf(0.1, float(active.get("outgoing_connect_total", OUTGOING_CONNECT_DELAY)))
		var elapsed := minf(total, maxf(0.0, float(active.get("outgoing_connect_elapsed", 0.0))) + delta)
		active["outgoing_connect_elapsed"] = elapsed
		runtime_state.active_call = active
		if elapsed >= total:
			_answer_outgoing_call()
		return
	if status != "active":
		return
	if bool(active.get("is_waiting_message", false)):
		var total := maxf(0.0, float(active.get("transcript_delay_total", TRANSCRIPT_PRE_DELAY)))
		var elapsed := minf(total, maxf(0.0, float(active.get("transcript_delay_elapsed", 0.0))) + delta)
		active["transcript_delay_elapsed"] = elapsed
		runtime_state.active_call = active
		if elapsed >= total:
			_begin_pending_message_reveal()
		return
	if int(active.get("revealing_transcript_index", -1)) >= 0 and not bool(active.get("message_reveal_completed", true)):
		_advance_message_reveal(delta)


func begin_available_incoming_call() -> bool:
	if not _configured or runtime_state == null or not runtime_state.active_call.is_empty():
		return false
	for call_data in data_loader.get_calls():
		if str(call_data.get("direction", "")) == "incoming" and _conditions_match(call_data.get("start_conditions", {})):
			return _begin_call(call_data, "incoming")
	return false


func begin_incoming_call(call_id: String) -> bool:
	if not _configured or runtime_state == null or not runtime_state.active_call.is_empty():
		return false
	var call_data := data_loader.get_call(call_id)
	if call_data.is_empty() or str(call_data.get("direction", "")) != "incoming":
		return false
	if not _conditions_match(call_data.get("start_conditions", {})):
		return false
	return _begin_call(call_data, "incoming")


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
	active["revealing_message_id"] = ""
	active["revealing_transcript_index"] = -1
	active["message_visible_characters"] = 0
	active["message_reveal_elapsed"] = 0.0
	active["message_reveal_completed"] = true
	active["voice_profile_id"] = ""
	active["pending_choice_id"] = ""
	active["pending_choice_next"] = ""
	active["pending_choice_end_call"] = false
	active["pending_choice_effects"] = []
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
	var player_text := str(selected.get("text", ""))
	transcript.append({
		"speaker": "player",
		"text": player_text,
		"message_id": "choice:" + choice_id,
		"keywords": [],
		"visible_characters": 0,
		"reveal_completed": false
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
	active["revealing_message_id"] = "choice:" + choice_id
	active["revealing_transcript_index"] = transcript.size() - 1
	active["message_visible_characters"] = 0
	active["message_reveal_elapsed"] = 0.0
	active["message_reveal_completed"] = false
	active["voice_profile_id"] = "player"
	active["pending_choice_id"] = choice_id
	active["pending_choice_next"] = str(selected.get("next", ""))
	active["pending_choice_end_call"] = bool(selected.get("end_call", false))
	active["pending_choice_effects"] = (selected.get("effects", []) as Array).duplicate(true) if selected.get("effects", []) is Array else []
	runtime_state.active_call = active
	state_changed.emit()


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
		if str(call_data.get("direction", "")) == "outgoing" and _conditions_match(call_data.get("start_conditions", {})):
			return _begin_call(call_data, "outgoing")
	for call_data in data_loader.get_calls():
		if str(call_data.get("contact_id", "")) != contact_id:
			continue
		var retry_flag := str(call_data.get("reject_retry_flag", ""))
		if retry_flag != "" and bool(runtime_state.flags.get(retry_flag, false)) and _conditions_match(call_data.get("start_conditions", {})):
			return _begin_call(call_data, "outgoing_retry")
	if contact_id == "assistant":
		feedback_requested.emit("先完成 TH-0731 的复核，查完之后再联系艾琳。")
	else:
		feedback_requested.emit("当前联系人暂时没有可用通话。")
	return false


func begin_action_dispatch(
	contact_id: String,
	choices: Array[Dictionary],
	message: String,
	subtitle: String = "调查调度"
) -> bool:
	if runtime_state == null or not runtime_state.has_discovered_contact(contact_id):
		return false
	if not runtime_state.active_call.is_empty() and str(runtime_state.active_call.get("kind", "")) != "action_dispatch":
		return false
	var transcript: Array[Dictionary] = []
	if message != "":
		transcript.append({
			"speaker": contact_id,
			"text": message,
			"message_id": "dispatch:intro:" + contact_id,
			"keywords": [],
			"visible_characters": message.length(),
			"reveal_completed": true
		})
	runtime_state.active_call = {
		"kind": "action_dispatch",
		"call_id": "action_dispatch:%s:%d" % [contact_id, Time.get_ticks_msec()],
		"contact_id": contact_id,
		"direction": "outgoing",
		"status": "active",
		"view_subtitle": subtitle,
		"message_id": "dispatch",
		"transcript": transcript,
		"choices_made": [],
		"presented_choices": choices.duplicate(true),
		"waiting_for_keyword": "",
		"is_waiting_message": false,
		"revealing_transcript_index": -1,
		"message_reveal_completed": true
	}
	state_changed.emit()
	return true


func complete_action_dispatch(choice_id: String, choice_text: String, response_text: String) -> void:
	if runtime_state == null or str(runtime_state.active_call.get("kind", "")) != "action_dispatch":
		return
	var active := runtime_state.active_call
	var transcript: Array = active.get("transcript", [])
	transcript.append({
		"speaker": "player",
		"text": choice_text,
		"message_id": "dispatch:choice:" + choice_id,
		"keywords": [],
		"visible_characters": choice_text.length(),
		"reveal_completed": true
	})
	if response_text != "":
		transcript.append({
			"speaker": str(active.get("contact_id", "assistant")),
			"text": response_text,
			"message_id": "dispatch:response:" + choice_id,
			"keywords": [],
			"visible_characters": response_text.length(),
			"reveal_completed": true
		})
	active["transcript"] = transcript
	active["presented_choices"] = []
	active["choices_made"] = [{"message_id": "dispatch", "choice_id": choice_id}]
	runtime_state.active_call = active
	state_changed.emit()


func is_action_dispatch_active() -> bool:
	return runtime_state != null and str(runtime_state.active_call.get("kind", "")) == "action_dispatch"


func has_visible_call() -> bool:
	return runtime_state != null and not runtime_state.active_call.is_empty()


func get_active_call() -> Dictionary:
	return runtime_state.active_call.duplicate(true) if runtime_state != null else {}


func mark_call_end_audio_started(started: bool) -> void:
	if runtime_state == null or str(runtime_state.active_call.get("status", "")) != "ending":
		return
	var active := runtime_state.active_call
	active["call_end_audio_started"] = started
	if not started:
		active["call_end_audio_completed"] = true
	active["call_end_elapsed"] = 0.0
	runtime_state.active_call = active
	state_changed.emit()


func notify_call_end_audio_finished() -> void:
	if runtime_state == null or str(runtime_state.active_call.get("status", "")) != "ending":
		return
	var active := runtime_state.active_call
	active["call_end_audio_completed"] = true
	active["call_end_elapsed"] = 0.0
	runtime_state.active_call = active
	state_changed.emit()


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
	return TRANSCRIPT_PRE_DELAY if not message.is_empty() else 0.0


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
	var waiting_status := "incoming_waiting" if direction == "incoming" else "outgoing_waiting"
	runtime_state.active_call = {
		"call_id": call_id,
		"contact_id": contact_id,
		"direction": direction,
		"status": waiting_status,
		"message_id": str(call_data.get("entry_message_id", "")),
		"transcript": [],
		"choices_made": [],
		"presented_choices": [],
		"waiting_for_keyword": "",
		"is_waiting_message": false,
		"pending_message_id": "",
		"transcript_delay_elapsed": 0.0,
		"transcript_delay_total": 0.0,
		"revealing_message_id": "",
		"revealing_transcript_index": -1,
		"message_visible_characters": 0,
		"message_reveal_elapsed": 0.0,
		"message_reveal_completed": true,
		"voice_profile_id": "",
		"pending_choice_id": "",
		"pending_choice_next": "",
		"pending_choice_end_call": false,
		"pending_choice_effects": [],
		"call_end_sequence_active": false,
		"call_end_elapsed": 0.0,
		"call_end_audio_started": false,
		"call_end_audio_completed": false,
		"call_end_next_node_id": "",
		"outgoing_connect_elapsed": 0.0,
		"outgoing_connect_total": float(call_data.get("connect_delay", OUTGOING_CONNECT_DELAY))
	}
	state_changed.emit()
	return true


func _answer_outgoing_call() -> void:
	if runtime_state == null or str(runtime_state.active_call.get("status", "")) != "outgoing_waiting":
		return
	var active := runtime_state.active_call
	var entry_message_id := str(active.get("message_id", ""))
	active["status"] = "active"
	active["message_id"] = ""
	active["outgoing_connect_elapsed"] = 0.0
	active["transcript"] = []
	active["choices_made"] = []
	active["presented_choices"] = []
	active["waiting_for_keyword"] = ""
	runtime_state.active_call = active
	_schedule_message(entry_message_id)


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
	active["transcript_delay_total"] = TRANSCRIPT_PRE_DELAY
	active["presented_choices"] = []
	active["waiting_for_keyword"] = ""
	active["revealing_message_id"] = ""
	active["revealing_transcript_index"] = -1
	active["message_visible_characters"] = 0
	active["message_reveal_elapsed"] = 0.0
	active["message_reveal_completed"] = true
	active["voice_profile_id"] = ""
	runtime_state.active_call = active
	state_changed.emit()


func _begin_pending_message_reveal() -> void:
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
	var speaker := str(message.get("speaker", "assistant"))
	transcript.append({
		"speaker": speaker,
		"text": str(message.get("text", "")),
		"message_id": message_id,
		"keywords": (message.get("keywords", []) as Array).duplicate(true) if message.get("keywords", []) is Array else [],
		"visible_characters": 0,
		"reveal_completed": false
	})
	active["transcript"] = transcript
	active["presented_choices"] = []
	active["waiting_for_keyword"] = ""
	active["revealing_message_id"] = message_id
	active["revealing_transcript_index"] = transcript.size() - 1
	active["message_visible_characters"] = 0
	active["message_reveal_elapsed"] = 0.0
	active["message_reveal_completed"] = false
	active["voice_profile_id"] = _voice_profile_for_speaker(speaker, active)
	runtime_state.active_call = active
	state_changed.emit()


func _advance_message_reveal(delta: float) -> void:
	var active := runtime_state.active_call
	var transcript: Array = active.get("transcript", [])
	var transcript_index := int(active.get("revealing_transcript_index", -1))
	if transcript_index < 0 or transcript_index >= transcript.size() or not (transcript[transcript_index] is Dictionary):
		active["message_reveal_completed"] = true
		active["revealing_transcript_index"] = -1
		runtime_state.active_call = active
		return
	var entry: Dictionary = transcript[transcript_index]
	var text := str(entry.get("text", ""))
	var visible := clampi(int(active.get("message_visible_characters", 0)), 0, text.length())
	var elapsed := maxf(0.0, float(active.get("message_reveal_elapsed", 0.0)))
	var remaining := delta
	var changed := false
	while visible < text.length() and remaining > 0.0:
		var character := text.substr(visible, 1)
		var interval := 1.0 / TRANSCRIPT_CHARACTERS_PER_SECOND + _transcript_punctuation_pause(character)
		var required := maxf(0.0, interval - elapsed)
		if remaining < required:
			elapsed += remaining
			remaining = 0.0
			break
		remaining -= required
		elapsed = 0.0
		visible += 1
		changed = true
		transcript_character_revealed.emit(str(active.get("voice_profile_id", "neutral")), character)
	active["message_visible_characters"] = visible
	active["message_reveal_elapsed"] = elapsed
	entry["visible_characters"] = visible
	transcript[transcript_index] = entry
	active["transcript"] = transcript
	runtime_state.active_call = active
	if changed:
		state_changed.emit()
	if visible >= text.length():
		_complete_current_message_reveal()


func _complete_current_message_reveal() -> void:
	var active := runtime_state.active_call
	var transcript: Array = active.get("transcript", [])
	var transcript_index := int(active.get("revealing_transcript_index", -1))
	if transcript_index < 0 or transcript_index >= transcript.size() or not (transcript[transcript_index] is Dictionary):
		return
	var entry: Dictionary = transcript[transcript_index]
	entry["visible_characters"] = str(entry.get("text", "")).length()
	entry["reveal_completed"] = true
	transcript[transcript_index] = entry
	active["transcript"] = transcript
	active["message_visible_characters"] = int(entry.get("visible_characters", 0))
	active["message_reveal_elapsed"] = 0.0
	active["message_reveal_completed"] = true
	active["revealing_transcript_index"] = -1
	active["revealing_message_id"] = ""
	active["voice_profile_id"] = ""
	runtime_state.active_call = active
	state_changed.emit()
	if str(entry.get("speaker", "")) == "player":
		_complete_player_choice_reveal()
		return
	var message_id := str(entry.get("message_id", ""))
	var message := data_loader.get_message(message_id)
	if message.is_empty():
		interrupt_current_call()
		return
	active = runtime_state.active_call
	active["waiting_for_keyword"] = str(message.get("wait_for_keyword", ""))
	var choices_value: Variant = message.get("choices", [])
	active["presented_choices"] = (choices_value as Array).duplicate(true) if choices_value is Array else []
	runtime_state.active_call = active
	state_changed.emit()
	if bool(message.get("end_call", false)):
		_apply_choice_effects(message)
		_finish_current_call()
		return
	if str(active.get("waiting_for_keyword", "")) != "" or not (active.get("presented_choices", []) as Array).is_empty():
		return
	_schedule_message(str(message.get("next", "")))


func _complete_player_choice_reveal() -> void:
	var active := runtime_state.active_call
	var pending_choice := {
		"effects": (active.get("pending_choice_effects", []) as Array).duplicate(true) if active.get("pending_choice_effects", []) is Array else []
	}
	var next_id := str(active.get("pending_choice_next", ""))
	var end_call := bool(active.get("pending_choice_end_call", false))
	active["pending_choice_id"] = ""
	active["pending_choice_next"] = ""
	active["pending_choice_end_call"] = false
	active["pending_choice_effects"] = []
	runtime_state.active_call = active
	_apply_choice_effects(pending_choice)
	if end_call:
		_finish_current_call()
	elif next_id != "":
		_schedule_message(next_id)


func _voice_profile_for_speaker(speaker: String, active: Dictionary) -> String:
	if speaker == "player":
		return "player"
	var contact := data_loader.get_contact(str(active.get("contact_id", "")))
	return str(contact.get("voice_profile_id", speaker if speaker != "" else "neutral"))


func _transcript_punctuation_pause(character: String) -> float:
	match character:
		"，", "、", "：", "；":
			return 0.04
		"。", "？", "！":
			return 0.10
		"\n":
			return 0.12
	return 0.0


func _finish_current_call() -> void:
	var active := runtime_state.active_call
	var call_data := data_loader.get_call(str(active.get("call_id", "")))
	active["status"] = "ending"
	active["presented_choices"] = []
	active["waiting_for_keyword"] = ""
	active["is_waiting_message"] = false
	active["pending_message_id"] = ""
	active["voice_profile_id"] = ""
	active["call_end_sequence_active"] = true
	active["call_end_elapsed"] = 0.0
	active["call_end_audio_started"] = false
	active["call_end_audio_completed"] = false
	active["call_end_next_node_id"] = str(call_data.get("completion_node_id", ""))
	runtime_state.active_call = active
	state_changed.emit()


func _finalize_ended_call() -> void:
	var next_node_id := str(runtime_state.active_call.get("call_end_next_node_id", ""))
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
	if str(active.get("kind", "")) == "action_dispatch":
		var dispatch_contact_id := str(active.get("contact_id", ""))
		if dispatch_contact_id == "" or data_loader.get_contact(dispatch_contact_id).is_empty():
			runtime_state.active_call.clear()
			return
		active["status"] = "active"
		active["is_waiting_message"] = false
		active["waiting_for_keyword"] = ""
		active["revealing_transcript_index"] = -1
		active["message_reveal_completed"] = true
		runtime_state.active_call = active
		return
	var call_id := str(active.get("call_id", ""))
	var message_id := str(active.get("message_id", ""))
	var pending_message_id := str(active.get("pending_message_id", ""))
	if data_loader.get_call(call_id).is_empty():
		push_warning("PhoneManager: cleared active call absent from current phone data: " + call_id)
		runtime_state.active_call.clear()
		return
	if str(active.get("status", "")) == "ending":
		active["presented_choices"] = []
		active["waiting_for_keyword"] = ""
		active["call_end_sequence_active"] = true
		active["call_end_elapsed"] = maxf(0.0, float(active.get("call_end_elapsed", 0.0)))
		var had_started := bool(active.get("call_end_audio_started", false))
		active["call_end_audio_started"] = had_started
		active["call_end_audio_completed"] = bool(active.get("call_end_audio_completed", false)) or had_started
		active["call_end_next_node_id"] = str(active.get("call_end_next_node_id", ""))
		runtime_state.active_call = active
		return
	if str(active.get("status", "")) == "outgoing_waiting":
		active["outgoing_connect_elapsed"] = maxf(0.0, float(active.get("outgoing_connect_elapsed", 0.0)))
		active["outgoing_connect_total"] = maxf(0.1, float(active.get("outgoing_connect_total", OUTGOING_CONNECT_DELAY)))
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
	active["transcript_delay_total"] = TRANSCRIPT_PRE_DELAY if bool(active.get("is_waiting_message", false)) else 0.0
	active["transcript_delay_elapsed"] = clampf(
		float(active.get("transcript_delay_elapsed", 0.0)),
		0.0,
		float(active.get("transcript_delay_total", 0.0))
	)
	if bool(active.get("is_waiting_message", false)) and pending_message_id == "":
		active["is_waiting_message"] = false
	var transcript: Array = active.get("transcript", [])
	for transcript_index in range(transcript.size()):
		if not (transcript[transcript_index] is Dictionary):
			continue
		var entry: Dictionary = transcript[transcript_index]
		if not entry.has("reveal_completed"):
			entry["reveal_completed"] = true
			entry["visible_characters"] = str(entry.get("text", "")).length()
		transcript[transcript_index] = entry
	active["transcript"] = transcript
	var revealing_index := int(active.get("revealing_transcript_index", -1))
	if revealing_index < 0 or revealing_index >= transcript.size():
		revealing_index = -1
	active["revealing_transcript_index"] = revealing_index
	active["revealing_message_id"] = str(active.get("revealing_message_id", "")) if revealing_index >= 0 else ""
	active["message_visible_characters"] = maxi(0, int(active.get("message_visible_characters", 0)))
	active["message_reveal_elapsed"] = maxf(0.0, float(active.get("message_reveal_elapsed", 0.0)))
	active["message_reveal_completed"] = bool(active.get("message_reveal_completed", revealing_index < 0))
	active["voice_profile_id"] = str(active.get("voice_profile_id", ""))
	active["pending_choice_id"] = str(active.get("pending_choice_id", ""))
	active["pending_choice_next"] = str(active.get("pending_choice_next", ""))
	active["pending_choice_end_call"] = bool(active.get("pending_choice_end_call", false))
	active["pending_choice_effects"] = (active.get("pending_choice_effects", []) as Array).duplicate(true) if active.get("pending_choice_effects", []) is Array else []
	runtime_state.active_call = active
