extends Control
class_name CaseArchiveUI

signal start_requested(case_descriptor: Dictionary, restart: bool)
signal continue_requested(case_descriptor: Dictionary)
signal load_requested(case_descriptor: Dictionary)
signal return_requested

const C_BG := Color("#F7F9FF")
const C_PANEL := Color("#EEF3FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_DIVIDER := Color("#D7DEF3")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_MUTED := Color("#8995B8")
const C_WHITE := Color("#FFFFFF")

const FONT_SERIF := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_BOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")
const FONT_MONO := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")

var _cases: Array[Dictionary] = []
var _status_by_case: Dictionary = {}
var _context: String = "play"
var _preferred_case_id: String = ""
var _selected_case_id: String = ""
var _case_buttons: Dictionary = {}

var _case_list: VBoxContainer
var _code_label: Label
var _title_label: Label
var _subtitle_label: Label
var _type_label: Label
var _status_label: Label
var _time_label: Label
var _recommendation_label: Label
var _primary_button: Button
var _restart_button: Button
var _load_button: Button


func configure(
	cases: Array[Dictionary],
	status_by_case: Dictionary,
	context: String = "play",
	preferred_case_id: String = ""
) -> void:
	_cases.clear()

	for descriptor in cases:
		_cases.append(descriptor.duplicate(true))

	_status_by_case = status_by_case.duplicate(true)
	_context = "load" if context == "load" else "play"
	_preferred_case_id = preferred_case_id

	if is_node_ready():
		_render_cases()


func refresh_statuses(status_by_case: Dictionary) -> void:
	_status_by_case = status_by_case.duplicate(true)
	var selection_to_restore: String = _selected_case_id

	if selection_to_restore != "":
		_preferred_case_id = selection_to_restore

	if is_node_ready():
		_render_cases()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_render_cases()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			return_requested.emit()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = C_BG
	_fill(background)
	add_child(background)

	var margin := MarginContainer.new()
	_fill(margin)
	margin.add_theme_constant_override("margin_left", 92)
	margin.add_theme_constant_override("margin_right", 92)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_bottom", 52)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 24)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 82
	outer.add_child(header)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)
	heading.add_child(_label("档案库", 40, C_BLUE, FONT_SERIF_BOLD))
	heading.add_child(_label("CASE ARCHIVE", 14, C_SUBTEXT, FONT_MONO))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var context_text: String = "选择要读取的案件" if _context == "load" else "选择一份档案开始调查"
	header.add_child(_label(context_text, 16, C_SUBTEXT, FONT_SERIF))

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _box(C_DIVIDER, C_DIVIDER, 1, 0))
	outer.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 32)
	outer.add_child(body)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size.x = 700
	list_panel.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, C_DIVIDER, 1, 5))
	body.add_child(list_panel)
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 24)
	list_margin.add_theme_constant_override("margin_right", 24)
	list_margin.add_theme_constant_override("margin_top", 22)
	list_margin.add_theme_constant_override("margin_bottom", 22)
	list_panel.add_child(list_margin)
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 16)
	list_margin.add_child(list_box)
	list_box.add_child(_label("案件目录", 19, C_BLUE, FONT_SERIF_BOLD))
	_case_list = VBoxContainer.new()
	_case_list.add_theme_constant_override("separation", 12)
	list_box.add_child(_case_list)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _box(C_WHITE, C_BLUE, 1, 5))
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 36)
	detail_margin.add_theme_constant_override("margin_right", 36)
	detail_margin.add_theme_constant_override("margin_top", 32)
	detail_margin.add_theme_constant_override("margin_bottom", 30)
	detail_panel.add_child(detail_margin)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 13)
	detail_margin.add_child(detail)
	_code_label = _label("—", 16, C_BLUE, FONT_MONO)
	detail.add_child(_code_label)
	_title_label = _label("请选择案件", 32, C_BLUE, FONT_SERIF_BOLD)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_title_label)
	_subtitle_label = _label("—", 13, C_SUBTEXT, FONT_MONO)
	detail.add_child(_subtitle_label)
	detail.add_child(_thin_line())
	_type_label = _detail_row(detail, "档案类型")
	_status_label = _detail_row(detail, "当前状态")
	_time_label = _detail_row(detail, "预计时间")
	_recommendation_label = _label("", 15, C_BLUE, FONT_SERIF_BOLD)
	_recommendation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recommendation_label.custom_minimum_size.y = 48
	detail.add_child(_recommendation_label)
	var detail_spacer := Control.new()
	detail_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(detail_spacer)
	_primary_button = _button("开始调查", true)
	_primary_button.pressed.connect(_on_primary_pressed)
	detail.add_child(_primary_button)
	_restart_button = _button("重新开始", false)
	_restart_button.pressed.connect(_on_restart_pressed)
	detail.add_child(_restart_button)
	_load_button = _button("读取存档", false)
	_load_button.pressed.connect(_on_load_pressed)
	detail.add_child(_load_button)
	var return_button := _button("返回标题", false)
	return_button.pressed.connect(func(): return_requested.emit())
	detail.add_child(return_button)


func _render_cases() -> void:
	if _case_list == null:
		return

	_clear(_case_list)
	_case_buttons.clear()

	for descriptor in _cases:
		var case_id: String = str(descriptor.get("case_id", ""))
		var status: Dictionary = _status_for(case_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(650, 126)
		button.text = "%s\n%s\n%s · %s" % [
			str(descriptor.get("code", "")),
			str(descriptor.get("title", "")),
			_case_type_text(str(descriptor.get("case_type", "case"))),
			str(status.get("label", "未调查"))
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", FONT_SERIF)
		button.add_theme_font_size_override("font_size", 17)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_case.bind(case_id))
		button.focus_entered.connect(_select_case.bind(case_id))
		_case_list.add_child(button)
		_case_buttons[case_id] = button

	if _cases.is_empty():
		_title_label.text = "没有可用案件"
		return

	var preferred: String = _preferred_case_id

	if preferred == "" or not _case_buttons.has(preferred):
		preferred = str(_cases[0].get("case_id", ""))

	_select_case(preferred)
	var default_button: Button = _case_buttons.get(preferred) as Button

	if default_button != null:
		default_button.call_deferred("grab_focus")


func _select_case(case_id: String) -> void:
	var descriptor: Dictionary = _descriptor_for(case_id)

	if descriptor.is_empty():
		return

	_selected_case_id = case_id

	for button_case_id in _case_buttons.keys():
		var button: Button = _case_buttons[button_case_id] as Button
		var selected: bool = str(button_case_id) == case_id
		button.add_theme_color_override("font_color", C_WHITE if selected else C_BLUE)
		button.add_theme_color_override("font_hover_color", C_WHITE if selected else C_BLUE)
		button.add_theme_color_override("font_focus_color", C_WHITE if selected else C_BLUE)
		button.add_theme_stylebox_override("normal", _box(C_BLUE if selected else C_WHITE, C_BLUE, 1, 4))
		button.add_theme_stylebox_override("hover", _box(C_BLUE_DARK if selected else C_PANEL, C_BLUE, 1, 4))
		button.add_theme_stylebox_override("focus", _box(C_BLUE if selected else C_PANEL, C_BLUE_DARK, 2, 4))

	var status: Dictionary = _status_for(case_id)
	_code_label.text = str(descriptor.get("code", ""))
	_title_label.text = str(descriptor.get("title", ""))
	_subtitle_label.text = str(descriptor.get("subtitle", ""))
	_type_label.text = _case_type_text(str(descriptor.get("case_type", "case")))
	_status_label.text = str(status.get("label", "未调查"))
	_time_label.text = str(descriptor.get("estimated_time", "—"))
	_recommendation_label.text = str(status.get("recommendation", ""))
	var has_any_save: bool = bool(status.get("has_any_save", false))
	var has_valid_autosave: bool = bool(status.get("has_valid_autosave", false))
	var locked: bool = bool(status.get("locked", false))

	if _context == "load":
		_primary_button.text = "尚未开放" if locked else "读取存档"
		_primary_button.disabled = locked or not has_any_save
		_restart_button.visible = false
		_load_button.visible = false
	else:
		_primary_button.text = (
			"尚未开放"
			if locked
			else ("继续调查" if has_valid_autosave else "开始调查")
		)
		_primary_button.disabled = locked
		_restart_button.visible = has_any_save and not locked
		_load_button.visible = true
		_load_button.disabled = locked or not has_any_save


func _on_primary_pressed() -> void:
	var descriptor: Dictionary = _descriptor_for(_selected_case_id)

	if descriptor.is_empty():
		return

	if _context == "load":
		load_requested.emit(descriptor)
	elif bool(_status_for(_selected_case_id).get("has_valid_autosave", false)):
		continue_requested.emit(descriptor)
	else:
		start_requested.emit(descriptor, false)


func _on_restart_pressed() -> void:
	var descriptor: Dictionary = _descriptor_for(_selected_case_id)

	if not descriptor.is_empty():
		start_requested.emit(descriptor, true)


func _on_load_pressed() -> void:
	var descriptor: Dictionary = _descriptor_for(_selected_case_id)

	if not descriptor.is_empty():
		load_requested.emit(descriptor)


func _descriptor_for(case_id: String) -> Dictionary:
	for descriptor in _cases:
		if str(descriptor.get("case_id", "")) == case_id:
			return descriptor.duplicate(true)

	return {}


func _status_for(case_id: String) -> Dictionary:
	var value: Variant = _status_by_case.get(case_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _case_type_text(case_type: String) -> String:
	return "教学档案" if case_type == "tutorial" else "正式案件"


func _detail_row(parent: VBoxContainer, title: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label(title, 15, C_SUBTEXT, FONT_SERIF))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var value := _label("—", 16, C_BLUE, FONT_SERIF_BOLD)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT_SERIF_BOLD)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", C_WHITE if primary else C_BLUE)
	button.add_theme_color_override("font_hover_color", C_WHITE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	button.add_theme_stylebox_override("normal", _box(C_BLUE if primary else C_WHITE, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("hover", _box(C_BLUE_DARK, C_BLUE_DARK, 1, 4))
	button.add_theme_stylebox_override("pressed", _box(C_BLUE_DARK, C_BLUE_DARK, 1, 4))
	button.add_theme_stylebox_override("disabled", _box(C_PANEL, C_DIVIDER, 1, 4))
	return button


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _thin_line() -> HSeparator:
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator", _box(C_DIVIDER, C_DIVIDER, 1, 0))
	return line


func _box(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


func _fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
