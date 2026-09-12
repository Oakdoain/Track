extends SceneTree

const LoaderScript = preload("res://scripts/case/CaseDataLoader.gd")
const RuntimeScript = preload("res://scripts/case/CaseRuntimeState.gd")
const ActionManagerScript = preload("res://scripts/case/CaseActionManager.gd")
const PhoneLoaderScript = preload("res://scripts/phone/PhoneDataLoader.gd")
const PhoneManagerScript = preload("res://scripts/phone/PhoneManager.gd")
const MainUIScene = preload("res://scenes/ui/MainUI.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	await process_frame
	_verify_case_loading()
	await _verify_case_ui_initialization()
	_verify_parallel_and_busy()
	_verify_active_action_save_restore()
	_verify_action_dispatch_restore()
	_verify_dynamic_events()
	_verify_witness_deadline()
	_verify_final_deadline()
	_verify_pollution_invalidation()
	_verify_old_runtime_defaults()
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("CASE_02_VERIFICATION_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_loader(case_id: String, slice_id: String) -> CaseDataLoader:
	var loader: CaseDataLoader = LoaderScript.new()
	_check(loader.load_registry(), "case registry should load")
	_check(loader.load_case(case_id, slice_id), "%s/%s should load" % [case_id, slice_id])
	return loader


func _new_runtime(loader: CaseDataLoader) -> CaseRuntimeState:
	var runtime: CaseRuntimeState = RuntimeScript.new()
	var start_node_id := str(loader.get_case_metadata().get("start_node_id", ""))
	runtime.set_current_node(start_node_id, true)
	runtime.initialize_visit_history(start_node_id)
	return runtime


func _verify_case_loading() -> void:
	var registry_loader := LoaderScript.new()
	_check(registry_loader.load_registry(), "registry should parse")
	_check(registry_loader.get_registered_cases().size() == 3, "registry should contain three independent cases")
	var tutorial := _new_loader("tutorial_00", "archive_training")
	_check(not tutorial.has_capability("investigation_time"), "tutorial must not enable investigation time")
	var case_one := _new_loader("case_01", "control_backup")
	_check(not case_one.has_capability("investigation_time"), "case 01 must not enable investigation time")
	var demo := _new_loader("case_02", "last_soundcheck")
	_check(demo.has_capability("investigation_time"), "new demo should enable investigation time")
	_check(demo.get_actions().size() == 17, "new demo should define A01-A09 and P01-P08")
	_check(demo.get_timed_events().size() == 4, "new demo should define EV01-EV04")
	_check(FileAccess.file_exists("res://data/cases/case_02/last_soundcheck/media/soundcheck_2240.ogg"), "soundcheck audio should exist")
	_check(load("res://data/cases/case_02/last_soundcheck/media/soundcheck_2240.ogg") is AudioStream, "soundcheck audio should import as an AudioStream")
	var phone_loader: PhoneDataLoader = PhoneLoaderScript.new()
	_check(phone_loader.load_case_data(demo.get_case_data_path(), demo.keyword_effects), "new demo contacts should load")
	_check(phone_loader.get_initial_contacts().size() == 6, "new demo phonebook should expose six contactable or inspectable roles")
	var dispatch_node := demo.get_node("ls_0001")
	var dispatch_choices: Array = dispatch_node.get("choices", [])
	_check(dispatch_choices.size() == 3, "central dispatch node should no longer expose the full action list")
	for choice_value in dispatch_choices:
		if choice_value is Dictionary:
			_check(str((choice_value as Dictionary).get("action", "")) != "start_investigation_action", "central dispatch choices must route assignments through the phonebook")


func _verify_case_ui_initialization() -> void:
	var registry_loader := LoaderScript.new()
	registry_loader.load_registry()
	for case_id in ["tutorial_00", "case_01", "case_02"]:
		var descriptor := registry_loader.get_case_descriptor(case_id)
		var main_ui := MainUIScene.instantiate()
		main_ui.configure_case(descriptor, "new_game", {})
		root.add_child(main_ui)
		await process_frame
		_check(str(main_ui._initialization_error) == "", "%s main UI should initialize" % case_id)
		_check(main_ui.timeline_view_controller != null, "%s should build the shared timeline page" % case_id)
		if case_id == "case_02":
			_check(main_ui.top_title_label.text == "叙事图谱 | 19:00", "new demo title should show investigation time")
			main_ui.runtime_state.unlock_node_from_keyword("ls_0001")
			main_ui._open_case_action_contact("assistant")
			var dispatch_call: Dictionary = main_ui.phone_manager.get_active_call()
			_check(str(dispatch_call.get("kind", "")) == "action_dispatch", "assistant contact should open an action dispatch transcript")
			_check(not (dispatch_call.get("presented_choices", []) as Array).is_empty(), "assistant transcript should list available timed actions")
			_check(str((dispatch_call.get("presented_choices", []) as Array)[0].get("text", "")).contains("耗时"), "dispatch choices should label their duration")
			main_ui._on_phone_choice_pressed("A01")
			_check(str(main_ui.runtime_state.assistant_state.get("status", "")) == "busy", "assistant phone choice should start A01")
			main_ui._open_case_action_contact("police_contact")
			main_ui._on_phone_choice_pressed("P01")
			_check(str(main_ui.runtime_state.police_state.get("status", "")) == "busy", "police phone choice should start P01")
			var assistant_button := main_ui.contacts_view.get_contact_control("assistant") as Button
			_check(assistant_button != null and assistant_button.text.contains("忙碌中"), "phonebook should immediately show the assistant busy state")
			main_ui.case_action_manager.advance_to_next_event()
			_check(main_ui.top_title_label.text == "叙事图谱 | 19:15", "top title should refresh when investigation time advances")
			main_ui._show_timeline_view()
			_check(main_ui.timeline_view.visible, "timeline navigation should display the main timeline page")
			_check(main_ui.timeline_view_controller._canvas._tasks.size() == 2, "timeline should show completed and still-active assigned tasks")
			_check(main_ui.timeline_view_controller._canvas._roles.size() == 8, "timeline should render all configured investigation roles")
		else:
			main_ui._show_timeline_view()
			_check(main_ui.timeline_view_controller._empty_label.visible, "%s should show the safe no-schedule state" % case_id)
		await process_frame
		await process_frame
		main_ui.queue_free()
		await process_frame


func _verify_parallel_and_busy() -> void:
	var loader := _new_loader("case_02", "last_soundcheck")
	var runtime := _new_runtime(loader)
	runtime.set_current_node("ls_0001", true)
	var manager: CaseActionManager = ActionManagerScript.new()
	manager.configure(loader, runtime)
	_check(runtime.investigation_time == 19 * 60, "investigation should start at 19:00")
	_check(bool(manager.start_action("A01").get("success", false)), "assistant action A01 should start")
	_check(not bool(manager.start_action("A02").get("success", false)), "assistant should reject a second action while busy")
	_check(bool(manager.start_action("P01").get("success", false)), "police action should run in parallel")
	_check(runtime.active_actions.size() == 2, "two actors should have parallel active actions")
	var first_advance := manager.advance_to_next_event()
	_check(bool(first_advance.get("success", false)) and runtime.investigation_time == 19 * 60 + 15, "time should advance to A01 completion")
	_check(runtime.completed_actions.has("A01") and runtime.active_actions.size() == 1, "A01 should complete while P01 remains active")
	_check(runtime.action_history.size() == 1 and str(runtime.action_history[0].get("action_id", "")) == "A01", "completed actions should remain available to the timeline")
	manager.advance_to_next_event()
	_check(runtime.investigation_time == 19 * 60 + 20 and runtime.completed_actions.has("P01"), "P01 should complete at 19:20")


func _verify_active_action_save_restore() -> void:
	var loader := _new_loader("case_02", "last_soundcheck")
	var runtime := _new_runtime(loader)
	runtime.set_current_node("ls_0001", true)
	var manager: CaseActionManager = ActionManagerScript.new()
	manager.configure(loader, runtime)
	manager.start_action("A01")
	manager.start_action("P01")
	var saved := runtime.to_save_dictionary()
	var restored: CaseRuntimeState = RuntimeScript.new()
	_check(restored.apply_save_dictionary(saved), "active investigation runtime should restore")
	var restored_manager: CaseActionManager = ActionManagerScript.new()
	restored_manager.configure(loader, restored)
	_check(restored.active_actions.size() == 2 and str(restored.assistant_state.get("status", "")) == "busy" and str(restored.police_state.get("status", "")) == "busy", "parallel busy states should survive save restore")
	restored_manager.advance_to_next_event()
	_check(restored.completed_actions.has("A01") and restored.active_actions.size() == 1, "restored action timing should continue from saved completion times")
	var completed_saved := restored.to_save_dictionary()
	var completed_restored: CaseRuntimeState = RuntimeScript.new()
	_check(completed_restored.apply_save_dictionary(completed_saved), "completed timeline history should restore")
	_check(completed_restored.action_history.size() == 1, "completed action timeline block should survive save restore")


func _verify_action_dispatch_restore() -> void:
	var loader := _new_loader("case_02", "last_soundcheck")
	var runtime := _new_runtime(loader)
	runtime.unlock_node_from_keyword("ls_0001")
	var phone: PhoneManager = PhoneManagerScript.new()
	_check(phone.configure(loader, runtime), "phone manager should configure for the new demo")
	var choices: Array[Dictionary] = [{"id": "A01", "text": "整理初步证词（耗时15分钟）"}]
	_check(phone.begin_action_dispatch("assistant", choices, "线路已接通。"), "action dispatch transcript should open")
	var saved := runtime.to_save_dictionary()
	var restored: CaseRuntimeState = RuntimeScript.new()
	_check(restored.apply_save_dictionary(saved), "action dispatch runtime should restore")
	var restored_phone: PhoneManager = PhoneManagerScript.new()
	_check(restored_phone.configure(loader, restored), "restored action dispatch phone manager should configure")
	_check(str(restored_phone.get_active_call().get("kind", "")) == "action_dispatch", "action dispatch transcript should survive save restore")


func _verify_dynamic_events() -> void:
	var loader := _new_loader("case_02", "last_soundcheck")
	var runtime := _new_runtime(loader)
	var manager: CaseActionManager = ActionManagerScript.new()
	manager.configure(loader, runtime)
	runtime.investigation_time = 20 * 60
	runtime.flags["time_contradiction"] = true
	runtime.flags["repeated_material_confirmed"] = true
	manager.advance_to_next_event()
	_check(runtime.investigation_time == 20 * 60 + 10 and runtime.killer_alerted, "EV01 should trigger at 20:10 after two evidence flags")
	runtime.flags["contacted_wang_aunt"] = true
	runtime.flags["cleaning_cart_sound_important"] = true
	var risk_result := manager.advance_to_next_event()
	_check(runtime.investigation_time == 20 * 60 + 50, "EV02 should trigger at 20:50")
	_check(str(risk_result.get("transition_node_id", "")) == "ls_ev02_witness_risk" and runtime.is_keyword_unlocked("ls_ev02_witness_risk"), "EV02 should reveal witness risk and protection action")


func _verify_witness_deadline() -> void:
	var loader := _new_loader("case_02", "last_soundcheck")
	var failed_runtime := _new_runtime(loader)
	var failed_manager: CaseActionManager = ActionManagerScript.new()
	failed_manager.configure(loader, failed_runtime)
	var failed_result := failed_manager.advance_to_next_event()
	_check(str(failed_result.get("transition_node_id", "")) == "ls_f01_late", "unprotected witness should trigger F01 at 21:30")

	var safe_runtime := _new_runtime(loader)
	var safe_manager: CaseActionManager = ActionManagerScript.new()
	safe_manager.configure(loader, safe_runtime)
	safe_runtime.investigation_time = 20 * 60 + 50
	safe_runtime.unlock_node_from_keyword("ls_ev02_witness_risk")
	_check(bool(safe_manager.start_action("P06").get("success", false)), "P06 should start after witness risk unlocks")
	safe_manager.advance_to_next_event()
	_check(safe_runtime.witness_protected and safe_runtime.investigation_time == 21 * 60 + 10, "P06 should complete before 21:30")
	var safe_result := safe_manager.advance_to_next_event()
	_check(str(safe_result.get("transition_node_id", "")) == "ls_ev03_safe", "protected witness should pass EV03")


func _verify_final_deadline() -> void:
	var loader := _new_loader("case_02", "last_soundcheck")
	var failed_runtime := _new_runtime(loader)
	var failed_manager: CaseActionManager = ActionManagerScript.new()
	failed_manager.configure(loader, failed_runtime)
	failed_runtime.investigation_time = 22 * 60
	failed_runtime.witness_protected = true
	failed_runtime.event_flags["EV03"] = true
	var failed_result := failed_manager.advance_to_next_event()
	_check(str(failed_result.get("transition_node_id", "")) == "ls_f02_blank_project", "uncontrolled suspect should trigger F02 at 22:45")

	var safe_runtime := _new_runtime(loader)
	var safe_manager: CaseActionManager = ActionManagerScript.new()
	safe_manager.configure(loader, safe_runtime)
	safe_runtime.investigation_time = 22 * 60
	safe_runtime.witness_protected = true
	safe_runtime.event_flags["EV03"] = true
	safe_runtime.unlock_node_from_keyword("ls_fact_major_suspicion")
	_check(bool(safe_manager.start_action("P07").get("success", false)), "P07 should start after major suspicion")
	safe_manager.advance_to_next_event()
	_check(safe_runtime.killer_controlled and safe_runtime.investigation_time == 22 * 60 + 30, "P07 should finish before 22:45")
	var safe_result := safe_manager.advance_to_next_event()
	_check(str(safe_result.get("transition_node_id", "")) == "ls_final_accusation", "controlled suspect should reach final accusation")


func _verify_pollution_invalidation() -> void:
	var loader := _new_loader("case_02", "last_soundcheck")
	var runtime := _new_runtime(loader)
	var manager: CaseActionManager = ActionManagerScript.new()
	manager.configure(loader, runtime)
	runtime.pollution_node_states["ls_pollution_no_opportunity"] = {"status": "active"}
	manager.invalidate_pollution_node("ls_pollution_no_opportunity", "STUDIO MON proves the premise invalid")
	_check(str((runtime.pollution_node_states["ls_pollution_no_opportunity"] as Dictionary).get("status", "")) == "premise_invalid", "pollution node should remain but become premise-invalid")


func _verify_old_runtime_defaults() -> void:
	var loader := _new_loader("tutorial_00", "archive_training")
	var runtime := _new_runtime(loader)
	var legacy := runtime.to_save_dictionary()
	for field in ["investigation_time", "assistant_state", "police_state", "active_actions", "completed_actions", "action_history", "event_flags", "pollution_node_states", "witness_protected", "killer_alerted", "killer_controlled"]:
		legacy.erase(field)
	_check(runtime.validate_save_dictionary(legacy, false), "old runtime without new fields should validate")
	var restored := RuntimeScript.new()
	restored.apply_save_dictionary(legacy)
	_check(restored.investigation_time == -1 and restored.active_actions.is_empty(), "old runtime should restore safe disabled defaults")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
