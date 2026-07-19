extends RefCounted
class_name TextRevealController

signal state_changed(state: Dictionary)
signal reveal_completed(skipped: bool)
signal post_delay_completed

const DEFAULT_TITLE_CPS := 22.0
const DEFAULT_BODY_CPS := 38.0
const DEFAULT_POST_DELAY := 0.8
const SKIPPED_POST_DELAY_MINIMUM := 0.4

var _sections: Array[Dictionary] = []
var _state: Dictionary = {}
var _post_delay: float = DEFAULT_POST_DELAY
var _has_post_events: bool = false


func start(
	node_id: String,
	sections: Array[Dictionary],
	config: Dictionary,
	restored_state: Dictionary,
	animate_text: bool,
	has_post_events: bool
) -> void:
	_sections = sections
	_has_post_events = has_post_events
	_post_delay = maxf(0.0, float(config.get("post_delay", DEFAULT_POST_DELAY)))
	var can_restore := (
		str(restored_state.get("node_id", "")) == node_id
		and not bool(restored_state.get("events_completed", false))
	)
	if can_restore:
		_state = restored_state.duplicate(true)
		_state["section_index"] = clampi(int(_state.get("section_index", 0)), 0, _sections.size())
		_state["visible_characters"] = maxi(0, int(_state.get("visible_characters", 0)))
		_state["character_elapsed"] = maxf(0.0, float(_state.get("character_elapsed", 0.0)))
		_state["post_reveal_elapsed"] = maxf(0.0, float(_state.get("post_reveal_elapsed", 0.0)))
		_state["post_delay_total"] = maxf(0.0, float(_state.get("post_delay_total", _post_delay)))
		if bool(_state.get("completed", false)) and has_post_events and not bool(_state.get("events_completed", false)):
			_state["waiting_after_reveal"] = true
	else:
		_state = {
			"node_id": node_id,
			"section_index": 0,
			"visible_characters": 0,
			"character_elapsed": 0.0,
			"completed": not animate_text,
			"waiting_after_reveal": not animate_text and has_post_events,
			"post_reveal_elapsed": 0.0,
			"post_delay_total": _post_delay,
			"events_completed": not has_post_events
		}
	_apply_visibility()
	if not animate_text and not can_restore:
		_show_all_sections()
	state_changed.emit(get_state())


func update(delta: float) -> void:
	if delta <= 0.0 or _state.is_empty():
		return
	if is_revealing():
		_advance_text(delta)
	elif is_waiting_after_reveal():
		var elapsed := minf(
			float(_state.get("post_delay_total", _post_delay)),
			float(_state.get("post_reveal_elapsed", 0.0)) + delta
		)
		_state["post_reveal_elapsed"] = elapsed
		state_changed.emit(get_state())
		if elapsed >= float(_state.get("post_delay_total", _post_delay)):
			_state["waiting_after_reveal"] = false
			_state["events_completed"] = true
			state_changed.emit(get_state())
			post_delay_completed.emit()


func skip() -> bool:
	if not is_revealing():
		return false
	_show_all_sections()
	_finish_text(true)
	return true


func is_revealing() -> bool:
	return not _state.is_empty() and not bool(_state.get("completed", false))


func is_waiting_after_reveal() -> bool:
	return bool(_state.get("completed", false)) and bool(_state.get("waiting_after_reveal", false))


func has_completed_text() -> bool:
	return bool(_state.get("completed", false))


func events_completed() -> bool:
	return bool(_state.get("events_completed", false))


func get_state() -> Dictionary:
	return _state.duplicate(true)


func clear() -> void:
	_sections.clear()
	_state.clear()


func _advance_text(delta: float) -> void:
	var remaining := delta
	var changed := false
	while remaining > 0.0 and is_revealing():
		var section_index := int(_state.get("section_index", 0))
		if section_index >= _sections.size():
			_finish_text(false)
			return
		var section := _sections[section_index]
		var text := str(section.get("text", ""))
		var visible := clampi(int(_state.get("visible_characters", 0)), 0, text.length())
		if visible >= text.length():
			_set_section_visible(section_index, -1)
			_state["section_index"] = section_index + 1
			_state["visible_characters"] = 0
			_state["character_elapsed"] = 0.0
			changed = true
			continue
		var character := text.substr(visible, 1)
		var interval := 1.0 / maxf(1.0, float(section.get("cps", DEFAULT_BODY_CPS)))
		interval += _punctuation_pause(character)
		var elapsed := float(_state.get("character_elapsed", 0.0))
		var required := maxf(0.0, interval - elapsed)
		if remaining < required:
			_state["character_elapsed"] = elapsed + remaining
			remaining = 0.0
			changed = true
			break
		remaining -= required
		visible += 1
		_state["visible_characters"] = visible
		_state["character_elapsed"] = 0.0
		_set_section_visible(section_index, visible)
		changed = true
	if changed:
		state_changed.emit(get_state())


func _finish_text(skipped: bool) -> void:
	_state["section_index"] = _sections.size()
	_state["visible_characters"] = 0
	_state["character_elapsed"] = 0.0
	_state["completed"] = true
	_state["waiting_after_reveal"] = _has_post_events
	_state["post_reveal_elapsed"] = 0.0
	_state["post_delay_total"] = maxf(SKIPPED_POST_DELAY_MINIMUM, _post_delay) if skipped else _post_delay
	_state["events_completed"] = not _has_post_events
	state_changed.emit(get_state())
	reveal_completed.emit(skipped)


func _apply_visibility() -> void:
	var section_index := int(_state.get("section_index", 0))
	var current_visible := int(_state.get("visible_characters", 0))
	if bool(_state.get("completed", false)):
		_show_all_sections()
		return
	for index in range(_sections.size()):
		if index < section_index:
			_set_section_visible(index, -1)
		elif index == section_index:
			_set_section_visible(index, current_visible)
		else:
			_set_section_visible(index, 0)


func _show_all_sections() -> void:
	for index in range(_sections.size()):
		_set_section_visible(index, -1)


func _set_section_visible(index: int, count: int) -> void:
	if index < 0 or index >= _sections.size():
		return
	var control: Control = _sections[index].get("control") as Control
	if is_instance_valid(control):
		control.set("visible_characters", count)


func _punctuation_pause(character: String) -> float:
	match character:
		"，", "、", "：", "；":
			return 0.05
		"。", "？", "！":
			return 0.12
		"\n":
			return 0.15
	return 0.0
