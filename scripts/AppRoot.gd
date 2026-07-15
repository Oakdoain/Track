extends Control

const MainUIScene := preload("res://scenes/ui/MainUI.tscn")
const StartUIScene := preload("res://scenes/ui/StartUI.tscn")
const LoadUIScene := preload("res://scenes/ui/LoadUI.tscn")
const SettingsUIScene := preload("res://scenes/ui/SettingsUI.tscn")
const ArchiveUIScene := preload("res://scenes/ui/ArchiveUI.tscn")

const MIN_WINDOW_SIZE := Vector2i(1280, 720)
const C_BG := Color("#F7F9FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_WHITE := Color("#FFFFFF")
const C_OVERLAY := Color(0.03, 0.06, 0.15, 0.42)
const SETTINGS_Z_INDEX := 80

const FONT_SERIF := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")
const FONT_MONO := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")

var save_manager: SaveManager
var registry_loader: CaseDataLoader
var registered_cases: Array[Dictionary] = []
var save_managers: Dictionary = {}
var case_progress_manager: CaseProgressManager
var settings_manager: SettingsManager
var start_ui: CaseStartUI
var archive_ui: CaseArchiveUI
var main_ui: Control
var load_ui: CaseLoadUI
var settings_ui: CaseSettingsUI

var _settings_origin: String = "title"
var _pending_entry_source: String = ""
var _current_case_descriptor: Dictionary = {}
var _archive_context: String = "play"
var _archive_preferred_case_id: String = ""
var _case_01_open_notice_pending: bool = false
var _confirmation_overlay: Control
var _confirmation_title: Label
var _confirmation_body: Label
var _confirmation_confirm_button: Button
var _confirmation_cancel_button: Button
var _confirmation_action: Callable
var _confirmation_previous_focus: Control


func _ready() -> void:
	_setup_window()
	registry_loader = CaseDataLoader.new()

	if not registry_loader.load_registry():
		push_error("AppRoot: case registry could not be loaded.")
	else:
		registered_cases = registry_loader.get_registered_cases()
		_build_case_save_managers()
		case_progress_manager = CaseProgressManager.new(registered_cases)
		var progress_result: Dictionary = case_progress_manager.initialize()

		if not bool(progress_result.get("success", false)):
			push_warning("AppRoot: case progress manager initialization failed.")

		_migrate_legacy_case_completion()

	settings_manager = SettingsManager.new()
	var settings_result: Dictionary = settings_manager.initialize()
	if not bool(settings_result.get("success", false)):
		push_warning("AppRoot: settings initialization used defaults: " + str(settings_result.get("error", "")))

	_build_start_ui()
	_build_confirmation_overlay()
	_show_start_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode != KEY_ESCAPE or not key_event.pressed or key_event.echo:
		return

	if _confirmation_overlay.visible:
		_close_confirmation()
		get_viewport().set_input_as_handled()
		return

	if settings_ui != null and is_instance_valid(settings_ui):
		_close_settings()
		get_viewport().set_input_as_handled()
		return

	if load_ui != null and is_instance_valid(load_ui):
		_return_from_title_load()
		get_viewport().set_input_as_handled()
		return

	if archive_ui != null and is_instance_valid(archive_ui):
		_return_from_archive()
		get_viewport().set_input_as_handled()


func _setup_window() -> void:
	var window: Window = get_window()
	window.min_size = MIN_WINDOW_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.content_scale_factor = 1.0
	RenderingServer.set_default_clear_color(C_BG)


func _build_start_ui() -> void:
	start_ui = StartUIScene.instantiate() as CaseStartUI
	if start_ui == null:
		push_error("AppRoot: StartUI could not be instantiated.")
		return
	_fill_rect(start_ui)
	add_child(start_ui)
	start_ui.configure(_latest_valid_autosave_summary())
	start_ui.new_game_requested.connect(_on_new_game_requested)
	start_ui.continue_requested.connect(_on_continue_requested)
	start_ui.load_requested.connect(_open_title_load)
	start_ui.settings_requested.connect(_open_title_settings)
	start_ui.quit_requested.connect(_request_quit)


func _show_start_ui() -> void:
	_stop_audio()
	_dispose_main_ui()
	_dispose_load_ui()
	_dispose_archive_ui()
	_dispose_settings_ui()
	_close_confirmation()
	_current_case_descriptor.clear()
	if start_ui != null:
		start_ui.visible = true
		start_ui.set_continue_summary(_latest_valid_autosave_summary())
		start_ui.refresh_autosave_summary()
		start_ui.call_deferred("focus_default")


func _on_new_game_requested() -> void:
	start_ui.clear_feedback()
	_open_archive("play")


func _begin_new_game(descriptor: Dictionary) -> void:
	_close_confirmation()
	_stop_audio()
	_enter_main_ui(descriptor, "new_game", {}, "new_game")


func _on_continue_requested() -> void:
	start_ui.clear_feedback()
	var latest: Dictionary = _latest_valid_autosave_summary()
	var case_id: String = str(latest.get("case_id", ""))
	var descriptor: Dictionary = registry_loader.get_case_descriptor(case_id)
	var manager: SaveManager = _manager_for_case(case_id)

	if descriptor.is_empty() or manager == null:
		start_ui.show_feedback("暂无可用自动存档")
		return

	var load_result: Dictionary = manager.load_autosave()
	if not bool(load_result.get("success", false)):
		start_ui.show_feedback(_friendly_autosave_error(load_result))
		start_ui.set_continue_summary(_latest_valid_autosave_summary())
		return
	_enter_loaded_document(load_result, "continue", descriptor)


func _open_title_load() -> void:
	_open_archive("load")


func _open_case_load(descriptor: Dictionary) -> void:
	if load_ui != null and is_instance_valid(load_ui):
		return
	var manager: SaveManager = _manager_for_case(str(descriptor.get("case_id", "")))

	if manager == null:
		_report_archive_failure("该案件的存档管理器不可用")
		return
	load_ui = LoadUIScene.instantiate() as CaseLoadUI
	if load_ui == null:
		start_ui.show_feedback("读取存档页面暂时不可用")
		push_error("AppRoot: LoadUI could not be instantiated.")
		return
	_fill_rect(load_ui)
	add_child(load_ui)
	load_ui.configure(manager, descriptor)
	load_ui.return_requested.connect(_return_from_title_load)
	load_ui.load_requested.connect(_on_title_load_requested)
	_current_case_descriptor = descriptor.duplicate(true)
	if archive_ui != null:
		archive_ui.visible = false
	load_ui.open_page()


func _return_from_title_load() -> void:
	_dispose_load_ui()
	if archive_ui != null and is_instance_valid(archive_ui):
		archive_ui.visible = true
		archive_ui.move_to_front()
	else:
		_show_start_ui()


func _on_title_load_requested(slot_type: String, slot_index: int) -> void:
	var manager: SaveManager = _manager_for_case(str(_current_case_descriptor.get("case_id", "")))

	if manager == null:
		load_ui.report_load_failure("案件存档管理器不可用")
		return
	var load_result: Dictionary = (
		manager.load_autosave()
		if slot_type == "autosave"
		else manager.load_manual(slot_index)
	)
	if not bool(load_result.get("success", false)):
		load_ui.report_load_failure(str(load_result.get("error", "存档不可读取")))
		return
	_enter_loaded_document(load_result, "title_load", _current_case_descriptor)


func _enter_loaded_document(
	load_result: Dictionary,
	source: String,
	descriptor: Dictionary
) -> void:
	var document_value: Variant = load_result.get("data", {})
	if not (document_value is Dictionary):
		_report_entry_failure(source, "存档根数据无效")
		return
	var document: Dictionary = document_value

	if (
		str(document.get("case_id", "")) != str(descriptor.get("case_id", ""))
		or str(document.get("slice_id", "")) != str(descriptor.get("slice_id", ""))
	):
		_report_entry_failure(source, "存档与所选案件不匹配")
		return

	var runtime_value: Variant = document.get("runtime_state", {})
	if not (runtime_value is Dictionary):
		_report_entry_failure(source, "存档运行状态无效")
		return
	_stop_audio()
	_enter_main_ui(descriptor, "loaded", (runtime_value as Dictionary).duplicate(true), source)


func _enter_main_ui(
	descriptor: Dictionary,
	mode: String,
	runtime_data: Dictionary,
	source: String
) -> void:
	if main_ui != null and is_instance_valid(main_ui):
		return
	var candidate: Control = MainUIScene.instantiate() as Control
	if candidate == null:
		_report_entry_failure(source, "案件界面暂时不可用")
		push_error("AppRoot: MainUI could not be instantiated.")
		return

	_pending_entry_source = source
	_current_case_descriptor = descriptor.duplicate(true)
	main_ui = candidate
	main_ui.visible = false
	_fill_rect(main_ui)
	main_ui.call("configure_case", descriptor, mode, runtime_data)
	main_ui.connect("initialization_succeeded", Callable(self, "_on_main_initialized"))
	main_ui.connect("initialization_failed", Callable(self, "_on_main_initialization_failed"))
	main_ui.connect("settings_requested", Callable(self, "_open_game_settings"))
	main_ui.connect("archive_requested", Callable(self, "_on_archive_requested"))
	main_ui.connect("case_completion_requested", Callable(self, "_on_case_completion_requested"))
	add_child(main_ui)


func _on_main_initialized() -> void:
	if main_ui == null or not is_instance_valid(main_ui):
		return
	main_ui.visible = true
	start_ui.visible = false
	_dispose_load_ui()
	_dispose_archive_ui()
	_pending_entry_source = ""


func _on_main_initialization_failed(message: String) -> void:
	var source: String = _pending_entry_source
	_pending_entry_source = ""
	if main_ui != null and is_instance_valid(main_ui):
		main_ui.queue_free()
	main_ui = null
	_report_entry_failure(source, message)


func _report_entry_failure(source: String, message: String) -> void:
	push_warning("AppRoot: " + message)
	if source == "title_load" and load_ui != null and is_instance_valid(load_ui):
		load_ui.report_load_failure(message)
		return
	if archive_ui != null and is_instance_valid(archive_ui):
		archive_ui.visible = true
		return
	start_ui.visible = true
	start_ui.show_feedback(message)
	start_ui.refresh_autosave_summary()


func _build_case_save_managers() -> void:
	save_managers.clear()

	for descriptor in registered_cases:
		var case_id: String = str(descriptor.get("case_id", ""))
		var slice_id: String = str(descriptor.get("slice_id", ""))
		var manager := SaveManager.new(case_id, slice_id)
		var result: Dictionary = manager.initialize()

		if not bool(result.get("success", false)):
			push_warning("AppRoot: save manager failed for %s: %s" % [
				case_id,
				str(result.get("error", ""))
			])

		save_managers[case_id] = manager


func _manager_for_case(case_id: String) -> SaveManager:
	var value: Variant = save_managers.get(case_id)
	return value as SaveManager if value is SaveManager else null


func _latest_valid_autosave_summary() -> Dictionary:
	var latest: Dictionary = {}
	var latest_time: int = -1

	for descriptor in registered_cases:
		var case_id: String = str(descriptor.get("case_id", ""))
		var manager: SaveManager = _manager_for_case(case_id)

		if manager == null:
			continue

		var summary: Dictionary = manager.read_slot_summary("autosave", 0)

		if str(summary.get("status", "")) != "available":
			continue

		var saved_at: int = int(summary.get("saved_at_unix", 0))

		if saved_at < latest_time:
			continue

		latest_time = saved_at
		latest = summary.duplicate(true)
		latest["case_id"] = case_id
		latest["slice_id"] = str(descriptor.get("slice_id", ""))
		latest["case_title"] = str(descriptor.get("title", ""))

	return latest


func _open_archive(context: String, preferred_case_id: String = "") -> void:
	if archive_ui != null and is_instance_valid(archive_ui):
		return

	archive_ui = ArchiveUIScene.instantiate() as CaseArchiveUI

	if archive_ui == null:
		start_ui.show_feedback("档案库暂时不可用")
		push_error("AppRoot: ArchiveUI could not be instantiated.")
		return

	_archive_context = "load" if context == "load" else "play"
	_archive_preferred_case_id = preferred_case_id
	_fill_rect(archive_ui)
	archive_ui.configure(
		registered_cases,
		_build_archive_statuses(),
		_archive_context,
		_resolve_archive_preferred_case(preferred_case_id)
	)
	archive_ui.start_requested.connect(_on_archive_start_requested)
	archive_ui.continue_requested.connect(_on_archive_continue_requested)
	archive_ui.load_requested.connect(_open_case_load)
	archive_ui.return_requested.connect(_return_from_archive)
	add_child(archive_ui)
	start_ui.visible = false
	archive_ui.move_to_front()


func _return_from_archive() -> void:
	_dispose_load_ui()
	_dispose_archive_ui()
	if start_ui != null:
		start_ui.visible = true
		start_ui.set_continue_summary(_latest_valid_autosave_summary())
		start_ui.call_deferred("focus_default")


func _on_archive_start_requested(descriptor: Dictionary, restart: bool) -> void:
	if restart:
		_show_confirmation(
			"重新开始这份档案？",
			"将覆盖该案件的自动存档。手动存档不会被删除。",
			"重新开始",
			_begin_new_game.bind(descriptor.duplicate(true))
		)
	else:
		_begin_new_game(descriptor)


func _on_archive_continue_requested(descriptor: Dictionary) -> void:
	var manager: SaveManager = _manager_for_case(str(descriptor.get("case_id", "")))

	if manager == null:
		_report_archive_failure("该案件的存档管理器不可用")
		return

	var result: Dictionary = manager.load_autosave()

	if not bool(result.get("success", false)):
		_report_archive_failure(_friendly_autosave_error(result))
		return

	_enter_loaded_document(result, "archive_continue", descriptor)


func _on_archive_requested(preferred_case_id: String) -> void:
	_stop_audio()
	_dispose_settings_ui()
	_dispose_main_ui()
	_current_case_descriptor.clear()
	_open_archive("play", preferred_case_id)
	_case_01_open_notice_pending = false


func _on_case_completion_requested(case_id: String) -> void:
	if case_progress_manager == null:
		push_warning("AppRoot: case completion was not persisted because progress manager is unavailable.")
		return

	var result: Dictionary = case_progress_manager.mark_case_completed(case_id)

	if not bool(result.get("success", false)):
		push_warning("AppRoot: failed to persist case completion: " + str(result.get("error", "")))
		return

	if case_id == "tutorial_00" and bool(result.get("changed", false)):
		_case_01_open_notice_pending = true

	_refresh_archive_statuses()


func _build_archive_statuses() -> Dictionary:
	var statuses: Dictionary = {}
	var tutorial_completed: bool = false

	for descriptor in registered_cases:
		var case_id: String = str(descriptor.get("case_id", ""))
		var manager: SaveManager = _manager_for_case(case_id)
		var globally_completed: bool = (
			case_progress_manager != null
			and case_progress_manager.is_case_completed(case_id)
		)
		var status := {
			"label": "未调查",
			"has_any_save": false,
			"has_valid_autosave": false,
			"locked": false,
			"completed": globally_completed,
			"recommendation": ""
		}

		if manager != null:
			var summaries: Array[Dictionary] = manager.get_all_slot_summaries()
			var has_available: bool = false
			var has_corrupted: bool = false
			var has_incompatible: bool = false

			for summary in summaries:
				var slot_status: String = str(summary.get("status", "empty"))
				status["has_any_save"] = bool(status["has_any_save"]) or slot_status != "empty"
				has_available = has_available or slot_status == "available"
				has_corrupted = has_corrupted or slot_status == "corrupted"
				has_incompatible = has_incompatible or slot_status == "incompatible"

			var autosave: Dictionary = manager.read_slot_summary("autosave", 0)
			var autosave_status: String = str(autosave.get("status", "empty"))
			status["has_valid_autosave"] = str(autosave.get("status", "")) == "available"

			if bool(status["completed"]):
				status["label"] = "已完成"
			elif autosave_status == "corrupted":
				status["label"] = "自动存档损坏"
			elif autosave_status == "incompatible":
				status["label"] = "版本不兼容"
			elif has_available:
				status["label"] = "调查中"
			elif has_corrupted:
				status["label"] = "自动存档损坏"
			elif has_incompatible:
				status["label"] = "版本不兼容"

		if str(descriptor.get("case_type", "")) == "tutorial" and bool(status["completed"]):
			tutorial_completed = true

		statuses[case_id] = status

	if not tutorial_completed and statuses.has("case_01"):
		(statuses["case_01"] as Dictionary)["locked"] = true
		(statuses["case_01"] as Dictionary)["label"] = "未开放"
		(statuses["case_01"] as Dictionary)["recommendation"] = "完成 T-00 教学档案后开放"
	elif tutorial_completed and _case_01_open_notice_pending and statuses.has("case_01"):
		(statuses["case_01"] as Dictionary)["recommendation"] = "CASE 01 已开放：《隔音室谋杀案》"

	return statuses


func _refresh_archive_statuses() -> void:
	if archive_ui != null and is_instance_valid(archive_ui):
		archive_ui.refresh_statuses(_build_archive_statuses())


func _migrate_legacy_case_completion() -> void:
	if case_progress_manager == null:
		return

	for descriptor in registered_cases:
		var case_id: String = str(descriptor.get("case_id", ""))
		var completion_flag: String = str(descriptor.get("completion_flag", ""))

		if completion_flag == "" or case_progress_manager.has_case_record(case_id):
			continue

		var manager: SaveManager = _manager_for_case(case_id)

		if manager == null:
			continue

		for summary in manager.get_all_slot_summaries():
			if str(summary.get("status", "")) != "available":
				continue

			var load_result: Dictionary = (
				manager.load_autosave()
				if str(summary.get("slot_type", "")) == "autosave"
				else manager.load_manual(int(summary.get("slot_index", -1)))
			)
			var document_value: Variant = load_result.get("data", {})
			var runtime_value: Variant = (
				(document_value as Dictionary).get("runtime_state", {})
				if document_value is Dictionary
				else {}
			)
			var flags_value: Variant = (
				(runtime_value as Dictionary).get("flags", {})
				if runtime_value is Dictionary
				else {}
			)

			if flags_value is Dictionary and bool((flags_value as Dictionary).get(completion_flag, false)):
				var migration_result: Dictionary = case_progress_manager.mark_case_completed(
					case_id,
					int(summary.get("saved_at_unix", 0))
				)

				if not bool(migration_result.get("success", false)):
					push_warning("AppRoot: failed to migrate completion for case: " + case_id)

				break


func _resolve_archive_preferred_case(requested: String) -> String:
	if requested != "" and not registry_loader.get_case_descriptor(requested).is_empty():
		return requested

	var statuses: Dictionary = _build_archive_statuses()
	var tutorial_status: Variant = statuses.get("tutorial_00", {})

	if tutorial_status is Dictionary and bool((tutorial_status as Dictionary).get("completed", false)):
		return "case_01"

	return "tutorial_00" if not registry_loader.get_case_descriptor("tutorial_00").is_empty() else ""


func _report_archive_failure(message: String) -> void:
	push_warning("AppRoot: " + message)
	if start_ui != null:
		start_ui.show_feedback(message)


func _open_title_settings() -> void:
	_open_settings("title")


func _open_game_settings(source_context: String) -> void:
	_open_settings(source_context)


func _open_settings(origin: String) -> void:
	if settings_ui != null and is_instance_valid(settings_ui):
		return
	_stop_audio()
	get_viewport().gui_release_focus()
	_settings_origin = origin
	settings_ui = SettingsUIScene.instantiate() as CaseSettingsUI
	if settings_ui == null:
		push_error("AppRoot: SettingsUI could not be instantiated.")
		if origin == "title":
			start_ui.show_feedback("设置页面暂时不可用")
		elif main_ui != null:
			main_ui.call("restore_settings_context", origin)
		return
	_fill_rect(settings_ui)
	settings_ui.visible = true
	settings_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_ui.z_index = SETTINGS_Z_INDEX
	add_child(settings_ui)
	settings_ui.configure(settings_manager, "title" if origin == "title" else "game")
	settings_ui.return_requested.connect(_close_settings)
	settings_ui.return_to_title_requested.connect(_request_return_to_title)
	settings_ui.quit_requested.connect(_request_quit)
	settings_ui.move_to_front()


func _close_settings() -> void:
	var origin: String = _settings_origin
	_dispose_settings_ui()
	if origin == "title":
		start_ui.visible = true
		start_ui.refresh_autosave_summary()
		start_ui.call_deferred("focus_default")
	elif main_ui != null and is_instance_valid(main_ui):
		main_ui.call("restore_settings_context", origin)


func _request_return_to_title() -> void:
	_show_confirmation(
		"返回标题界面？",
		"当前进度以最近一次自动或手动存档为准。\n本次返回不会额外保存。",
		"返回标题",
		Callable(self, "_confirm_return_to_title")
	)


func _confirm_return_to_title() -> void:
	_close_confirmation()
	_show_start_ui()


func _request_quit() -> void:
	_show_confirmation(
		"退出游戏？",
		"未写入存档的临时状态将不会保留。",
		"退出游戏",
		Callable(self, "_confirm_quit")
	)


func _confirm_quit() -> void:
	_stop_audio()
	get_tree().quit()


func _friendly_autosave_error(result: Dictionary) -> String:
	var status: String = str(result.get("status", "corrupted"))
	if status == "incompatible":
		return "自动存档版本不兼容"
	if status == "corrupted":
		return "自动存档损坏"
	return "暂无可用自动存档"


func _stop_audio() -> void:
	var manager: Node = get_node_or_null("/root/AudioManager")
	if manager != null and manager.has_method("stop_audio"):
		manager.call("stop_audio")


func _dispose_main_ui() -> void:
	if main_ui != null and is_instance_valid(main_ui):
		main_ui.queue_free()
	main_ui = null


func _dispose_load_ui() -> void:
	if load_ui != null and is_instance_valid(load_ui):
		load_ui.close_page()
		load_ui.queue_free()
	load_ui = null


func _dispose_archive_ui() -> void:
	if archive_ui != null and is_instance_valid(archive_ui):
		archive_ui.visible = false
		archive_ui.queue_free()
	archive_ui = null


func _dispose_settings_ui() -> void:
	if settings_ui != null and is_instance_valid(settings_ui):
		get_viewport().gui_release_focus()
		settings_ui.visible = false
		settings_ui.queue_free()
	settings_ui = null


func _build_confirmation_overlay() -> void:
	_confirmation_overlay = Control.new()
	_confirmation_overlay.name = "ConfirmationOverlay"
	_confirmation_overlay.visible = false
	_confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirmation_overlay.z_index = 100
	_fill_rect(_confirmation_overlay)
	add_child(_confirmation_overlay)

	var shade := ColorRect.new()
	shade.name = "DimBackground"
	shade.color = C_OVERLAY
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_rect(shade)
	_confirmation_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.name = "DialogCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(center)
	_confirmation_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "DialogPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(600, 310)
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 4))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	var archive_label := _label("CASE CONFIRMATION", 12, C_SUBTEXT, FONT_MONO)
	box.add_child(archive_label)
	_confirmation_title = _label("", 28, C_BLUE, FONT_SERIF_SEMIBOLD)
	box.add_child(_confirmation_title)
	_confirmation_body = _label("", 16, C_TEXT, FONT_SERIF)
	_confirmation_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_confirmation_body)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_confirmation_cancel_button = _dialog_button("取消", false)
	_confirmation_cancel_button.pressed.connect(_close_confirmation)
	buttons.add_child(_confirmation_cancel_button)
	_confirmation_confirm_button = _dialog_button("确认", true)
	_confirmation_confirm_button.pressed.connect(_execute_confirmation)
	buttons.add_child(_confirmation_confirm_button)


func _show_confirmation(title: String, body: String, confirm_text: String, action: Callable) -> void:
	if _confirmation_overlay == null:
		return

	var focus_owner: Control = get_viewport().gui_get_focus_owner()

	if not _confirmation_overlay.visible and focus_owner != null:
		_confirmation_previous_focus = focus_owner

	_confirmation_title.text = title
	_confirmation_body.text = body
	_confirmation_confirm_button.text = confirm_text
	_confirmation_confirm_button.disabled = false
	_confirmation_cancel_button.disabled = false
	_confirmation_action = action
	# SettingsUI and title LoadUI are created after this reusable overlay. Moving
	# the overlay to the end of AppRoot's child list makes its visual and GUI
	# input order explicit instead of relying on z_index alone.
	_confirmation_overlay.move_to_front()
	_confirmation_overlay.visible = true
	_confirmation_cancel_button.call_deferred("grab_focus")


func _close_confirmation() -> void:
	if _confirmation_overlay == null:
		return

	var was_visible: bool = _confirmation_overlay.visible
	_confirmation_overlay.visible = false
	_confirmation_action = Callable()

	if (
		was_visible
		and _confirmation_previous_focus != null
		and is_instance_valid(_confirmation_previous_focus)
		and _confirmation_previous_focus.is_visible_in_tree()
	):
		_confirmation_previous_focus.call_deferred("grab_focus")

	_confirmation_previous_focus = null


func _execute_confirmation() -> void:
	var action: Callable = _confirmation_action
	if action.is_valid():
		action.call()


func _dialog_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 48)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.disabled = false
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", C_WHITE if primary else C_BLUE)
	button.add_theme_color_override("font_hover_color", C_WHITE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_focus_color", C_WHITE)
	button.add_theme_stylebox_override("normal", _button_box(C_BLUE if primary else C_WHITE, C_BLUE))
	button.add_theme_stylebox_override("hover", _button_box(C_BLUE_DARK, C_BLUE_DARK))
	button.add_theme_stylebox_override("pressed", _button_box(C_BLUE_DARK, C_BLUE_DARK))
	button.add_theme_stylebox_override("focus", _button_box(C_BLUE, C_BLUE_DARK, 2))
	return button


func _button_box(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = _style_box(background, border, width, 4)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	return box


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_box(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func _fill_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
