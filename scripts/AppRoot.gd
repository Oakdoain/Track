extends Control

const MainUIScene := preload("res://scenes/ui/MainUI.tscn")
const StartUIScene := preload("res://scenes/ui/StartUI.tscn")
const LoadUIScene := preload("res://scenes/ui/LoadUI.tscn")
const SettingsUIScene := preload("res://scenes/ui/SettingsUI.tscn")

const MIN_WINDOW_SIZE := Vector2i(1280, 720)
const C_BG := Color("#F7F9FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_WHITE := Color("#FFFFFF")
const C_OVERLAY := Color(0.03, 0.06, 0.15, 0.42)

const FONT_SERIF := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")
const FONT_MONO := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")

var save_manager: SaveManager
var settings_manager: SettingsManager
var start_ui: CaseStartUI
var main_ui: Control
var load_ui: CaseLoadUI
var settings_ui: CaseSettingsUI

var _settings_origin: String = "title"
var _pending_entry_source: String = ""
var _confirmation_overlay: Control
var _confirmation_title: Label
var _confirmation_body: Label
var _confirmation_confirm_button: Button
var _confirmation_cancel_button: Button
var _confirmation_action: Callable


func _ready() -> void:
	_setup_window()
	save_manager = SaveManager.new()
	var save_result: Dictionary = save_manager.initialize()
	if not bool(save_result.get("success", false)):
		push_warning("AppRoot: save manager initialization failed: " + str(save_result.get("error", "")))

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
	start_ui.configure(save_manager)
	start_ui.new_game_requested.connect(_on_new_game_requested)
	start_ui.continue_requested.connect(_on_continue_requested)
	start_ui.load_requested.connect(_open_title_load)
	start_ui.settings_requested.connect(_open_title_settings)
	start_ui.quit_requested.connect(_request_quit)


func _show_start_ui() -> void:
	_stop_audio()
	_dispose_main_ui()
	_dispose_load_ui()
	_dispose_settings_ui()
	_close_confirmation()
	if start_ui != null:
		start_ui.visible = true
		start_ui.refresh_autosave_summary()
		start_ui.call_deferred("focus_default")


func _on_new_game_requested() -> void:
	start_ui.clear_feedback()
	if _has_any_save_file():
		_show_confirmation(
			"开始新游戏？",
			"开始新游戏将覆盖自动存档。\n手动存档不会被删除。",
			"开始新游戏",
			Callable(self, "_begin_new_game")
		)
	else:
		_begin_new_game()


func _begin_new_game() -> void:
	_close_confirmation()
	_stop_audio()
	_enter_main_ui("new_game", {}, "new_game")


func _on_continue_requested() -> void:
	start_ui.clear_feedback()
	var load_result: Dictionary = save_manager.load_autosave()
	if not bool(load_result.get("success", false)):
		start_ui.show_feedback(_friendly_autosave_error(load_result))
		start_ui.refresh_autosave_summary()
		return
	_enter_loaded_document(load_result, "continue")


func _open_title_load() -> void:
	if load_ui != null and is_instance_valid(load_ui):
		return
	load_ui = LoadUIScene.instantiate() as CaseLoadUI
	if load_ui == null:
		start_ui.show_feedback("读取存档页面暂时不可用")
		push_error("AppRoot: LoadUI could not be instantiated.")
		return
	_fill_rect(load_ui)
	add_child(load_ui)
	load_ui.configure(save_manager)
	load_ui.return_requested.connect(_return_from_title_load)
	load_ui.load_requested.connect(_on_title_load_requested)
	start_ui.visible = false
	load_ui.open_page()


func _return_from_title_load() -> void:
	_dispose_load_ui()
	if start_ui != null:
		start_ui.visible = true
		start_ui.refresh_autosave_summary()
		start_ui.call_deferred("focus_default")


func _on_title_load_requested(slot_type: String, slot_index: int) -> void:
	var load_result: Dictionary = (
		save_manager.load_autosave()
		if slot_type == "autosave"
		else save_manager.load_manual(slot_index)
	)
	if not bool(load_result.get("success", false)):
		load_ui.report_load_failure(str(load_result.get("error", "存档不可读取")))
		return
	_enter_loaded_document(load_result, "title_load")


func _enter_loaded_document(load_result: Dictionary, source: String) -> void:
	var document_value: Variant = load_result.get("data", {})
	if not (document_value is Dictionary):
		_report_entry_failure(source, "存档根数据无效")
		return
	var runtime_value: Variant = (document_value as Dictionary).get("runtime_state", {})
	if not (runtime_value is Dictionary):
		_report_entry_failure(source, "存档运行状态无效")
		return
	_stop_audio()
	_enter_main_ui("loaded", (runtime_value as Dictionary).duplicate(true), source)


func _enter_main_ui(mode: String, runtime_data: Dictionary, source: String) -> void:
	if main_ui != null and is_instance_valid(main_ui):
		return
	var candidate: Control = MainUIScene.instantiate() as Control
	if candidate == null:
		_report_entry_failure(source, "案件界面暂时不可用")
		push_error("AppRoot: MainUI could not be instantiated.")
		return

	_pending_entry_source = source
	main_ui = candidate
	main_ui.visible = false
	_fill_rect(main_ui)
	main_ui.call("configure_startup", mode, runtime_data)
	main_ui.connect("initialization_succeeded", Callable(self, "_on_main_initialized"))
	main_ui.connect("initialization_failed", Callable(self, "_on_main_initialization_failed"))
	main_ui.connect("settings_requested", Callable(self, "_open_game_settings"))
	add_child(main_ui)


func _on_main_initialized() -> void:
	if main_ui == null or not is_instance_valid(main_ui):
		return
	main_ui.visible = true
	start_ui.visible = false
	_dispose_load_ui()
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
	start_ui.visible = true
	start_ui.show_feedback(message)
	start_ui.refresh_autosave_summary()


func _open_title_settings() -> void:
	_open_settings("title")


func _open_game_settings(source_context: String) -> void:
	_open_settings(source_context)


func _open_settings(origin: String) -> void:
	if settings_ui != null and is_instance_valid(settings_ui):
		return
	_stop_audio()
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
	add_child(settings_ui)
	settings_ui.configure(settings_manager, "title" if origin == "title" else "game")
	settings_ui.return_requested.connect(_close_settings)
	settings_ui.return_to_title_requested.connect(_request_return_to_title)
	settings_ui.quit_requested.connect(_request_quit)


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


func _has_any_save_file() -> bool:
	for summary in save_manager.get_all_slot_summaries():
		if str(summary.get("status", "empty")) != "empty":
			return true
	return false


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


func _dispose_settings_ui() -> void:
	if settings_ui != null and is_instance_valid(settings_ui):
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
	shade.color = C_OVERLAY
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_rect(shade)
	_confirmation_overlay.add_child(shade)

	var center := CenterContainer.new()
	_fill_rect(center)
	_confirmation_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 310)
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 4))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
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
	_confirmation_title.text = title
	_confirmation_body.text = body
	_confirmation_confirm_button.text = confirm_text
	_confirmation_action = action
	_confirmation_overlay.visible = true
	_confirmation_cancel_button.call_deferred("grab_focus")


func _close_confirmation() -> void:
	if _confirmation_overlay == null:
		return
	_confirmation_overlay.visible = false
	_confirmation_action = Callable()


func _execute_confirmation() -> void:
	var action: Callable = _confirmation_action
	if action.is_valid():
		action.call()


func _dialog_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 48)
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
