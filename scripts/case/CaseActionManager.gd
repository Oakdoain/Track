extends RefCounted
class_name CaseActionManager

signal state_changed
signal feedback_requested(message: String)

var loader: CaseDataLoader
var runtime: CaseRuntimeState
var enabled: bool = false
var start_time: int = 0


func configure(case_loader: CaseDataLoader, case_runtime: CaseRuntimeState) -> void:
	loader = case_loader
	runtime = case_runtime
	enabled = loader != null and runtime != null and loader.has_capability("investigation_time")
	if not enabled:
		return
	start_time = int(loader.get_case_metadata().get("investigation_start_time", 19 * 60))
	runtime.enable_investigation_time(start_time)
	_repair_actor_states()


func is_enabled() -> bool:
	return enabled


func format_time(minutes: int = -2) -> String:
	var value := runtime.investigation_time if minutes == -2 else minutes
	if value < 0:
		return "--:--"
	return "%02d:%02d" % [value / 60, value % 60]


func get_actor_state(executor: String) -> Dictionary:
	var value := runtime.assistant_state if executor == "assistant" else runtime.police_state
	var result := value.duplicate(true)
	if str(result.get("status", "idle")) == "busy":
		result["remaining_time"] = maxi(0, int(result.get("complete_time", runtime.investigation_time)) - runtime.investigation_time)
	return result


func get_available_actions(executor: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not enabled or executor not in ["assistant", "police"]:
		return result
	for action in loader.get_actions():
		if str(action.get("executor", "")) != executor:
			continue
		if bool(can_start_action(str(action.get("action_id", ""))).get("allowed", false)):
			result.append(action)
	return result


func can_start_action(action_id: String) -> Dictionary:
	if not enabled:
		return {"allowed": false, "reason": "当前案件未启用调查时间系统。"}
	var action := loader.get_action(action_id)
	if action.is_empty():
		return {"allowed": false, "reason": "调查行动不存在。"}
	var repeatable := bool(action.get("is_repeatable", false))
	if not repeatable and (runtime.completed_actions.has(action_id) or _has_active_action(action_id)):
		return {"allowed": false, "reason": "该调查行动已经执行。"}
	var executor := str(action.get("executor", ""))
	var actor_state := get_actor_state(executor)
	if str(actor_state.get("status", "idle")) == "busy":
		return {"allowed": false, "reason": "%s正在执行“%s”，还需 %d 分钟。" % [_actor_name(executor), str(actor_state.get("current_action_name", actor_state.get("current_action", ""))), int(actor_state.get("remaining_time", 0))]}
	for node_value in action.get("required_nodes", []):
		var node_id := str(node_value)
		if not runtime.unlocked_nodes.has(node_id) and not runtime.is_keyword_unlocked(node_id) and not runtime.visit_history.has(node_id):
			return {"allowed": false, "reason": "尚未取得执行该行动所需的调查信息。"}
	for node_value in action.get("blocked_by_nodes", []):
		var node_id := str(node_value)
		if runtime.unlocked_nodes.has(node_id) or runtime.is_keyword_unlocked(node_id) or runtime.visit_history.has(node_id):
			return {"allowed": false, "reason": "当前调查状态已使该行动失效。"}
	return {"allowed": true, "reason": ""}


func start_action(action_id: String) -> Dictionary:
	var check := can_start_action(action_id)
	if not bool(check.get("allowed", false)):
		feedback_requested.emit(str(check.get("reason", "无法开始调查。")))
		return {"success": false, "message": str(check.get("reason", ""))}
	var action := loader.get_action(action_id)
	var executor := str(action.get("executor", ""))
	var duration := int(action.get("duration", 0))
	var active := action.duplicate(true)
	active["start_time"] = runtime.investigation_time
	active["complete_time"] = runtime.investigation_time + duration
	runtime.active_actions.append(active)
	var actor_state := {
		"actor_id": executor,
		"status": "busy",
		"current_action": action_id,
		"current_action_name": str(action.get("action_name", action_id)),
		"start_time": runtime.investigation_time,
		"complete_time": runtime.investigation_time + duration,
		"remaining_time": duration
	}
	_set_actor_state(executor, actor_state)
	_apply_effect(action.get("start_effect", {}))
	state_changed.emit()
	var message := "%s开始：%s（%s—%s）" % [_actor_name(executor), str(action.get("action_name", action_id)), format_time(runtime.investigation_time), format_time(runtime.investigation_time + duration)]
	feedback_requested.emit(message)
	return {"success": true, "message": message}


func advance_to_next_event() -> Dictionary:
	if not enabled:
		return {"success": false, "message": "当前案件未启用调查时间系统。"}
	var next_time := 1 << 30
	for action in runtime.active_actions:
		next_time = mini(next_time, int(action.get("complete_time", next_time)))
	for event in loader.get_timed_events():
		if runtime.event_flags.has(str(event.get("event_id", ""))):
			continue
		if not _conditions_met(event.get("conditions", {})):
			continue
		var event_time := int(event.get("trigger_time", 0))
		# A conditional event whose requirements become true after its nominal
		# minute is due now. Never move investigation time backwards.
		next_time = mini(next_time, maxi(event_time, runtime.investigation_time))
	if next_time == 1 << 30:
		var message := "当前没有进行中的调查或待触发事件。"
		feedback_requested.emit(message)
		return {"success": false, "message": message}
	runtime.investigation_time = next_time
	var transition_node_id := ""
	# Strict deadline events are resolved before actions completing at the same minute.
	transition_node_id = _trigger_due_events(true)
	if transition_node_id == "":
		transition_node_id = _complete_due_actions()
	var regular_transition := _trigger_due_events(false)
	if transition_node_id == "":
		transition_node_id = regular_transition
	state_changed.emit()
	return {"success": true, "transition_node_id": transition_node_id, "message": "调查时间推进至 %s。" % format_time()}


func describe_status() -> String:
	if not enabled:
		return ""
	var assistant := get_actor_state("assistant")
	var police := get_actor_state("police")
	return "调查时间 %s｜助手：%s｜警察：%s" % [format_time(), _actor_status_text(assistant), _actor_status_text(police)]


func invalidate_pollution_node(node_id: String, reason: String) -> void:
	if node_id == "":
		return
	runtime.pollution_node_states[node_id] = {"status": "premise_invalid", "reason": reason, "invalidated_at": runtime.investigation_time}
	state_changed.emit()


func _complete_due_actions() -> String:
	var transition_node_id := ""
	var remaining: Array[Dictionary] = []
	for action in runtime.active_actions:
		if int(action.get("complete_time", 0)) > runtime.investigation_time:
			remaining.append(action)
			continue
		var action_id := str(action.get("action_id", ""))
		if not runtime.completed_actions.has(action_id):
			runtime.completed_actions.append(action_id)
		var historical_action := action.duplicate(true)
		historical_action["status"] = "completed"
		historical_action["completed_at"] = runtime.investigation_time
		var history_key := "%s@%d" % [action_id, int(action.get("start_time", -1))]
		var already_recorded := false
		for history_entry in runtime.action_history:
			if "%s@%d" % [str(history_entry.get("action_id", "")), int(history_entry.get("start_time", -1))] == history_key:
				already_recorded = true
				break
		if not already_recorded:
			runtime.action_history.append(historical_action)
		_set_actor_state(str(action.get("executor", "")), runtime._idle_actor_state(str(action.get("executor", ""))))
		_apply_effect(action.get("complete_effect", {}))
		for node_value in action.get("result_nodes", []):
			var node_id := str(node_value)
			if node_id != "":
				runtime.unlock_node_from_keyword(node_id)
				if transition_node_id == "" and bool(action.get("auto_open_result", true)):
					transition_node_id = node_id
		feedback_requested.emit("%s完成：%s" % [_actor_name(str(action.get("executor", ""))), str(action.get("action_name", action_id))])
	runtime.active_actions = remaining
	return transition_node_id


func _trigger_due_events(strict_only: bool) -> String:
	var transition_node_id := ""
	for event in loader.get_timed_events():
		var event_id := str(event.get("event_id", ""))
		if runtime.event_flags.has(event_id) or int(event.get("trigger_time", 0)) > runtime.investigation_time:
			continue
		if bool(event.get("strict_deadline", false)) != strict_only or not _conditions_met(event.get("conditions", {})):
			continue
		runtime.event_flags[event_id] = true
		for outcome_value in event.get("outcomes", []):
			if not (outcome_value is Dictionary):
				continue
			var outcome: Dictionary = outcome_value
			if not _conditions_met(outcome.get("conditions", {})):
				continue
			_apply_effect(outcome.get("effects", {}))
			var target := str(outcome.get("transition_node_id", ""))
			if target != "":
				transition_node_id = target
			feedback_requested.emit(str(outcome.get("message", event.get("message", "定时事件已触发。"))))
			break
	return transition_node_id


func _conditions_met(value: Variant) -> bool:
	if not (value is Dictionary):
		return true
	var conditions: Dictionary = value
	for flag_value in conditions.get("required_flags", []):
		if not bool(runtime.flags.get(str(flag_value), false)):
			return false
	for flag_value in conditions.get("forbidden_flags", []):
		if bool(runtime.flags.get(str(flag_value), false)):
			return false
	var required_values: Variant = conditions.get("flag_values", {})
	if required_values is Dictionary:
		for key in (required_values as Dictionary).keys():
			if bool(runtime.flags.get(str(key), false)) != bool((required_values as Dictionary)[key]):
				return false
	var minimum := int(conditions.get("minimum_true_flags", 0))
	if minimum > 0:
		var count := 0
		for flag_value in conditions.get("true_flags", []):
			if bool(runtime.flags.get(str(flag_value), false)):
				count += 1
		if count < minimum:
			return false
	if conditions.has("witness_protected") and runtime.witness_protected != bool(conditions["witness_protected"]):
		return false
	if conditions.has("killer_controlled") and runtime.killer_controlled != bool(conditions["killer_controlled"]):
		return false
	return true


func _apply_effect(value: Variant) -> void:
	if not (value is Dictionary):
		return
	var effect: Dictionary = value
	var flags_value: Variant = effect.get("set_flags", {})
	if flags_value is Dictionary:
		for key in (flags_value as Dictionary).keys():
			runtime.flags[str(key)] = bool((flags_value as Dictionary)[key])
	for node_value in effect.get("unlock_nodes", []):
		runtime.unlock_node_from_keyword(str(node_value))
	if effect.has("witness_protected"):
		runtime.witness_protected = bool(effect["witness_protected"])
	if effect.has("killer_controlled"):
		runtime.killer_controlled = bool(effect["killer_controlled"])
	if effect.has("killer_alerted"):
		runtime.killer_alerted = bool(effect["killer_alerted"])
	var pollution_value: Variant = effect.get("pollution_node_states", {})
	if pollution_value is Dictionary:
		for key in (pollution_value as Dictionary).keys():
			runtime.pollution_node_states[str(key)] = (pollution_value as Dictionary)[key]


func _repair_actor_states() -> void:
	for executor in ["assistant", "police"]:
		var state := get_actor_state(executor)
		if str(state.get("status", "idle")) == "busy" and not _has_active_action(str(state.get("current_action", ""))):
			_set_actor_state(executor, runtime._idle_actor_state(executor))


func _has_active_action(action_id: String) -> bool:
	for action in runtime.active_actions:
		if str(action.get("action_id", "")) == action_id:
			return true
	return false


func _set_actor_state(executor: String, state: Dictionary) -> void:
	if executor == "assistant":
		runtime.assistant_state = state
	elif executor == "police":
		runtime.police_state = state


func _actor_name(executor: String) -> String:
	return "助手" if executor == "assistant" else "警察联系人"


func _actor_status_text(state: Dictionary) -> String:
	if str(state.get("status", "idle")) != "busy":
		return "空闲"
	return "%s（余 %d 分钟）" % [str(state.get("current_action_name", state.get("current_action", "调查"))), int(state.get("remaining_time", 0))]
