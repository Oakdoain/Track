extends Control
class_name CaseLoadUI

signal return_requested
signal load_requested(slot_type: String, slot_index: int)

const SLOTS_PER_PAGE := 7
const PAGE_COUNT := 3
const MAX_CONTENT_WIDTH := 1500.0
const SLOT_ROW_HEIGHT := 76.0

const C_BG := Color("#F7F9FF")
const C_PANEL_SOFT := Color("#EEF3FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_DIVIDER := Color("#D7DEF3")
const C_SUBTEXT := Color("#5B6684")
const C_MUTED := Color("#8995B8")
const C_WHITE := Color("#FFFFFF")

const FONT_MONO_REGULAR := preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const FONT_MONO_MEDIUM := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const FONT_SERIF_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")

const ICON_CHEVRON_LEFT := preload("res://assets/icons/lucide/chevron-left.svg")
const ICON_CHEVRON_RIGHT := preload("res://assets/icons/lucide/chevron-right.svg")
const ICON_CIRCLE := preload("res://assets/icons/lucide/circle.svg")
const ICON_CIRCLE_DOT := preload("res://assets/icons/lucide/circle-dot.svg")
const ICON_INFO := preload("res://assets/icons/lucide/info.svg")
const ICON_FOLDER_OPEN := preload("res://assets/icons/lucide/folder-open.svg")
const ICON_STEP_BACK := preload("res://assets/icons/lucide/step-back.svg")

var save_manager: SaveManager
var current_page_index: int = 0
var selected_slot_type: String = ""
var selected_slot_index: int = -1
var _summaries: Array[Dictionary] = []

var content_center: CenterContainer
var content_box: VBoxContainer
var slot_list: VBoxContainer
var page_buttons_box: HBoxContainer
var page_label: Label
var previous_button: Button
var next_button: Button
var load_button: Button
var feedback_label: Label
var selected_slot_label: Label
var selected_title_label: Label
var selected_chapter_label: Label
var selected_time_label: Label
var selected_status_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	call_deferred("_update_content_width")


func configure(manager: SaveManager) -> void:
	save_manager = manager


func open_page() -> void:
	current_page_index = 0
	selected_slot_type = ""
	selected_slot_index = -1
	visible = true
	refresh_slots()


func close_page() -> void:
	visible = false


func refresh_slots() -> void:
	if save_manager == null:
		feedback_label.text = "存档管理器不可用"
		return

	_summaries = save_manager.get_all_slot_summaries()
	_render_page()


func report_load_failure(error: String) -> void:
	feedback_label.text = "读取失败：" + error
	refresh_slots()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = C_BG
	_fill_rect(background)
	add_child(background)

	var outer_margin := MarginContainer.new()
	_fill_rect(outer_margin)
	outer_margin.add_theme_constant_override("margin_left", 72)
	outer_margin.add_theme_constant_override("margin_right", 72)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(outer_margin)

	content_center = CenterContainer.new()
	content_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_center.resized.connect(_update_content_width)
	outer_margin.add_child(content_center)

	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 12)
	content_center.add_child(content_box)
	content_box.add_child(_build_page_header())

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	content_box.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content_box.add_child(body)

	var list_panel := PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_DIVIDER, 1, 4))
	body.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 20)
	list_margin.add_theme_constant_override("margin_right", 20)
	list_margin.add_theme_constant_override("margin_top", 16)
	list_margin.add_theme_constant_override("margin_bottom", 16)
	list_panel.add_child(list_margin)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
	list_margin.add_child(list_box)
	list_box.add_child(_build_list_heading())

	var list_center := CenterContainer.new()
	list_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box.add_child(list_center)

	var list_content := VBoxContainer.new()
	list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	list_content.add_theme_constant_override("separation", 10)
	list_center.add_child(list_content)
	list_content.add_child(_build_column_header())

	slot_list = VBoxContainer.new()
	slot_list.add_theme_constant_override("separation", 8)
	list_content.add_child(slot_list)

	var page_row := HBoxContainer.new()
	page_row.custom_minimum_size.y = 40
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	list_content.add_child(page_row)
	page_buttons_box = HBoxContainer.new()
	page_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	page_buttons_box.add_theme_constant_override("separation", 10)
	page_row.add_child(page_buttons_box)

	body.add_child(_build_detail_panel())


func _build_page_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	title_box.add_child(_label("读取存档", 30, C_BLUE, FONT_SERIF_SEMIBOLD))
	title_box.add_child(_label("LOAD ARCHIVE", 12, C_SUBTEXT, FONT_MONO_REGULAR))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	page_label = _label("第 1 / 3 页", 15, C_BLUE, FONT_MONO_MEDIUM)
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(page_label)
	return header


func _build_list_heading() -> Control:
	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 30
	heading.add_child(_section_title("存档列表"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	heading.add_child(_small_tag("固定档位 21", Vector2(112, 30)))
	return heading


func _build_column_header() -> Control:
	var margin := MarginContainer.new()
	margin.custom_minimum_size.y = 34
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 14)
	var row := HBoxContainer.new()
	margin.add_child(row)
	row.add_child(_header_label("", 34, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_header_label("档位", 74, HORIZONTAL_ALIGNMENT_CENTER))
	var name_header := _header_label("档位名称", 0, HORIZONTAL_ALIGNMENT_LEFT)
	name_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_header)
	row.add_child(_header_label("状态", 110, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_header_label("保存时间", 190, HORIZONTAL_ALIGNMENT_RIGHT))
	return margin


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 356
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_DIVIDER, 1, 4))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(_section_title("档位说明"))
	box.add_child(_build_info_card())
	box.add_child(_section_title("当前选中档位"))
	box.add_child(_build_selected_card())

	load_button = _button("读取所选存档", true, ICON_FOLDER_OPEN)
	load_button.custom_minimum_size.y = 52
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.disabled = true
	load_button.pressed.connect(_on_load_pressed)
	box.add_child(load_button)

	feedback_label = _label("", 14, C_BLUE, FONT_SERIF_SEMIBOLD)
	feedback_label.custom_minimum_size.y = 24
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feedback_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var return_button := _button("返回", false, ICON_STEP_BACK)
	return_button.custom_minimum_size.y = 46
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.pressed.connect(func(): return_requested.emit())
	box.add_child(return_button)
	return panel


func _build_info_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 112
	panel.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_LINE, 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	head.add_child(_icon(ICON_INFO, Vector2(21, 21), C_BLUE))
	head.add_child(_label("读取规则", 17, C_BLUE, FONT_SERIF_SEMIBOLD))
	var description := _label(
		"自动存档与已有手动存档可以读取；空槽、损坏槽和版本不兼容槽保持不可用。",
		14,
		C_SUBTEXT,
		FONT_SERIF_REGULAR
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	return panel


func _build_selected_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 210
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	box.add_child(title_row)
	selected_slot_label = _label("—", 18, C_BLUE, FONT_MONO_MEDIUM)
	selected_slot_label.custom_minimum_size.x = 56
	selected_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(selected_slot_label)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_box)
	selected_title_label = _ellipsis_label("暂无档位", 17, C_BLUE, FONT_SERIF_SEMIBOLD)
	title_box.add_child(selected_title_label)
	selected_chapter_label = _ellipsis_label("—", 13, C_SUBTEXT, FONT_MONO_REGULAR)
	title_box.add_child(selected_chapter_label)
	box.add_child(_thin_line())
	selected_time_label = _detail_row(box, "保存时间")
	selected_status_label = _detail_row(box, "档位状态")
	return panel


func _render_page() -> void:
	_clear_children(slot_list)
	page_label.text = "第 %d / %d 页" % [current_page_index + 1, PAGE_COUNT]
	var start_index: int = current_page_index * SLOTS_PER_PAGE
	var end_index: int = mini(start_index + SLOTS_PER_PAGE, _summaries.size())

	for index in range(start_index, end_index):
		slot_list.add_child(_build_slot_card(_summaries[index]))

	_render_page_buttons()
	_render_selected_detail()
	_update_load_button()


func _build_slot_card(summary: Dictionary) -> Control:
	var slot_type: String = str(summary.get("slot_type", "manual"))
	var slot_index: int = int(summary.get("slot_index", -1))
	var status: String = str(summary.get("status", "empty"))
	var available: bool = status == "available"
	var selected: bool = available and slot_type == selected_slot_type and slot_index == selected_slot_index
	var root_control := Control.new()
	root_control.custom_minimum_size.y = SLOT_ROW_HEIGHT
	root_control.tooltip_text = str(summary.get("error", ""))

	var panel := PanelContainer.new()
	_fill_rect(panel)
	panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL_SOFT if selected else C_WHITE, C_BLUE if selected else C_LINE, 1, 5)
	)
	root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(margin)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	root_control.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var radio_box := CenterContainer.new()
	radio_box.custom_minimum_size.x = 34
	row.add_child(radio_box)
	var radio_texture: Texture2D = ICON_CIRCLE_DOT if selected else ICON_CIRCLE
	radio_box.add_child(_icon(radio_texture, Vector2(19, 19), C_BLUE if available else C_MUTED))

	var slot_text: String = "自动" if slot_type == "autosave" else "%02d" % slot_index
	var slot_label := _label(slot_text, 17, C_BLUE if available else C_MUTED, FONT_MONO_MEDIUM)
	slot_label.custom_minimum_size.x = 74
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(slot_label)

	var metadata: Dictionary = summary.get("metadata", {})
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 2)
	row.add_child(detail_box)
	detail_box.add_child(_ellipsis_label(
		_status_primary_text(status, metadata),
		17,
		C_BLUE if available else C_MUTED,
		FONT_SERIF_SEMIBOLD
	))
	detail_box.add_child(_ellipsis_label(
		_status_secondary_text(status, metadata, summary),
		13,
		C_SUBTEXT if available else C_MUTED,
		FONT_MONO_REGULAR
	))

	var state_label := _label(_status_label(status), 14, C_BLUE if available else C_MUTED, FONT_SERIF_REGULAR)
	state_label.custom_minimum_size.x = 110
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(state_label)

	var time_label := _label(str(summary.get("saved_at_text", "—")), 13, C_SUBTEXT if available else C_MUTED, FONT_MONO_REGULAR)
	time_label.custom_minimum_size.x = 190
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(time_label)

	if available:
		var hit := _transparent_hit_button()
		hit.pressed.connect(_select_slot.bind(slot_type, slot_index))
		root_control.add_child(hit)
	return root_control


func _render_page_buttons() -> void:
	_clear_children(page_buttons_box)
	previous_button = _page_arrow_button(ICON_CHEVRON_LEFT, current_page_index > 0)
	previous_button.pressed.connect(_change_page.bind(-1))
	page_buttons_box.add_child(previous_button)

	for page_index in range(PAGE_COUNT):
		var page_button := _page_number_button(page_index + 1, page_index == current_page_index)
		page_button.pressed.connect(_set_page.bind(page_index))
		page_buttons_box.add_child(page_button)

	next_button = _page_arrow_button(ICON_CHEVRON_RIGHT, current_page_index < PAGE_COUNT - 1)
	next_button.pressed.connect(_change_page.bind(1))
	page_buttons_box.add_child(next_button)


func _select_slot(slot_type: String, slot_index: int) -> void:
	selected_slot_type = slot_type
	selected_slot_index = slot_index
	feedback_label.text = ""
	_render_page()


func _change_page(delta: int) -> void:
	_set_page(clampi(current_page_index + delta, 0, PAGE_COUNT - 1))


func _set_page(page_index: int) -> void:
	current_page_index = clampi(page_index, 0, PAGE_COUNT - 1)
	selected_slot_type = ""
	selected_slot_index = -1
	feedback_label.text = ""
	_render_page()


func _on_load_pressed() -> void:
	if selected_slot_type == "" or selected_slot_index < 0:
		feedback_label.text = "请选择可用存档"
		return

	load_requested.emit(selected_slot_type, selected_slot_index)


func _update_load_button() -> void:
	load_button.disabled = selected_slot_type == "" or selected_slot_index < 0


func _render_selected_detail() -> void:
	var summary: Dictionary = _summary_for_selected_slot()

	if summary.is_empty():
		selected_slot_label.text = "—"
		selected_title_label.text = "暂无档位"
		selected_chapter_label.text = "请选择可用存档"
		selected_time_label.text = "—"
		selected_status_label.text = "未选择"
		return

	var status: String = str(summary.get("status", "empty"))
	var metadata: Dictionary = summary.get("metadata", {})
	selected_slot_label.text = "自动" if selected_slot_type == "autosave" else "%02d" % selected_slot_index
	selected_title_label.text = _status_primary_text(status, metadata)
	selected_chapter_label.text = _status_secondary_text(status, metadata, summary)
	selected_time_label.text = str(summary.get("saved_at_text", "—"))
	selected_status_label.text = _status_label(status)
	selected_title_label.tooltip_text = selected_title_label.text
	selected_chapter_label.tooltip_text = selected_chapter_label.text


func _summary_for_selected_slot() -> Dictionary:
	for summary in _summaries:
		if (
			str(summary.get("slot_type", "")) == selected_slot_type
			and int(summary.get("slot_index", -1)) == selected_slot_index
		):
			return summary

	return {}


func _status_primary_text(status: String, metadata: Dictionary) -> String:
	if status == "available":
		return str(metadata.get("node_title", "当前节点"))
	if status == "corrupted":
		return "存档损坏"
	if status == "incompatible":
		return "版本不兼容"
	return "空存档"


func _status_secondary_text(status: String, metadata: Dictionary, summary: Dictionary) -> String:
	if status == "available":
		return "%s · %s" % [str(metadata.get("chapter_title", "未知章节")), str(metadata.get("node_id", ""))]
	if status == "corrupted" or status == "incompatible":
		return str(summary.get("error", "存档不可读取"))
	return "暂无数据"


func _status_label(status: String) -> String:
	if status == "available":
		return "可读取"
	if status == "corrupted":
		return "存档损坏"
	if status == "incompatible":
		return "版本不兼容"
	return "不可读取"


func _update_content_width() -> void:
	if content_center == null or content_box == null or content_center.size.x <= 0.0:
		return
	content_box.custom_minimum_size.x = minf(MAX_CONTENT_WIDTH, content_center.size.x)


func _section_title(text: String) -> Label:
	var label := _label(text, 17, C_BLUE, FONT_SERIF_SEMIBOLD)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _small_tag(text: String, min_size: Vector2) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 4))
	var label := _label(text, 13, C_BLUE, FONT_SERIF_REGULAR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _header_label(text: String, width: int, alignment: HorizontalAlignment) -> Label:
	var label := _label(text, 13, C_BLUE, FONT_SERIF_SEMIBOLD)
	label.custom_minimum_size.x = width
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _ellipsis_label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := _label(text, font_size, color, font)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _detail_row(parent: VBoxContainer, title: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label(title, 14, C_SUBTEXT, FONT_SERIF_REGULAR))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var value := _ellipsis_label("—", 14, C_BLUE, FONT_MONO_REGULAR)
	value.custom_minimum_size.x = 190
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value


func _page_arrow_button(texture: Texture2D, enabled: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(40, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.icon = texture
	button.disabled = not enabled
	_apply_compact_button_style(button, false)
	return button


func _page_number_button(number: int, active: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(40, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.text = str(number)
	button.add_theme_font_override("font", FONT_MONO_MEDIUM)
	button.add_theme_font_size_override("font_size", 14)
	_apply_compact_button_style(button, active)
	return button


func _apply_compact_button_style(button: Button, active: bool) -> void:
	var color: Color = C_WHITE if active else C_BLUE
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	button.add_theme_color_override("icon_normal_color", color)
	button.add_theme_color_override("icon_hover_color", color)
	button.add_theme_color_override("icon_pressed_color", C_WHITE)
	button.add_theme_color_override("icon_focus_color", color)
	button.add_theme_color_override("icon_disabled_color", C_MUTED)
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE if active else Color.TRANSPARENT, C_BLUE if active else C_LINE, 1, 3))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_DARK if active else C_PANEL_SOFT, C_BLUE, 1, 3))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 3))
	button.add_theme_stylebox_override("focus", _style_box(C_BLUE if active else C_PANEL_SOFT, C_BLUE, 1, 3))
	button.add_theme_stylebox_override("disabled", _style_box(Color.TRANSPARENT, C_DIVIDER, 1, 3))


func _button(text: String, active: bool, icon: Texture2D = null) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.custom_minimum_size = Vector2(132, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("font_hover_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_focus_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	button.add_theme_color_override("icon_normal_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("icon_hover_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("icon_pressed_color", C_WHITE)
	button.add_theme_color_override("icon_focus_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("icon_disabled_color", C_MUTED)
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE if active else C_WHITE, C_BLUE if active else C_LINE, 1, 4))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_DARK if active else C_PANEL_SOFT, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 4))
	button.add_theme_stylebox_override("focus", _style_box(C_BLUE if active else C_PANEL_SOFT, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("disabled", _style_box(C_PANEL_SOFT, C_DIVIDER, 1, 4))
	return button


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _icon(texture: Texture2D, icon_size: Vector2, color: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = icon_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _thin_line() -> ColorRect:
	var line := ColorRect.new()
	line.color = C_DIVIDER
	line.custom_minimum_size.y = 1
	return line


func _style_box(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box


func _transparent_hit_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_rect(button)
	var transparent := _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	button.add_theme_stylebox_override("normal", transparent)
	button.add_theme_stylebox_override("hover", transparent)
	button.add_theme_stylebox_override("pressed", transparent)
	button.add_theme_stylebox_override("focus", transparent)
	return button


func _fill_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
