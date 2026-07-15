extends Control
class_name CaseSaveUI

signal return_requested
signal save_requested(slot_index: int)

const SLOTS_PER_PAGE := 7
const PAGE_COUNT := 3
const MAX_CONTENT_WIDTH := 1480.0
const SLOT_ROW_HEIGHT := 76.0
const SLOT_LIST_WIDTH := 920.0
const DETAIL_PANEL_WIDTH := 380.0
const BODY_SEPARATION := 28
const COLUMN_SELECT_WIDTH := 52.0
const COLUMN_SLOT_WIDTH := 82.0
const COLUMN_NAME_MIN_WIDTH := 320.0
const COLUMN_STATUS_WIDTH := 140.0
const COLUMN_TIME_WIDTH := 210.0

const C_BG := Color("#F7F9FF")
const C_PANEL_SOFT := Color("#EEF3FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_DIVIDER := Color("#D7DEF3")
const C_SUBTEXT := Color("#5B6684")
const C_MUTED := Color("#8995B8")
const C_WHITE := Color("#FFFFFF")
const C_OVERLAY := Color(0.03, 0.06, 0.15, 0.42)

const FONT_MONO_REGULAR := preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const FONT_MONO_MEDIUM := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const FONT_SERIF_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")

const ICON_CHEVRON_LEFT := preload("res://assets/icons/lucide/chevron-left.svg")
const ICON_CHEVRON_RIGHT := preload("res://assets/icons/lucide/chevron-right.svg")
const ICON_CIRCLE := preload("res://assets/icons/lucide/circle.svg")
const ICON_CIRCLE_DOT := preload("res://assets/icons/lucide/circle-dot.svg")
const ICON_INFO := preload("res://assets/icons/lucide/info.svg")
const ICON_SAVE := preload("res://assets/icons/lucide/save.svg")
const ICON_STEP_BACK := preload("res://assets/icons/lucide/step-back.svg")

var save_manager: SaveManager
var case_descriptor: Dictionary = {}
var current_page_index: int = 0
var selected_slot_index: int = -1
var _summaries: Array[Dictionary] = []

var content_center: CenterContainer
var content_box: VBoxContainer
var slot_list: VBoxContainer
var page_buttons_box: HBoxContainer
var page_label: Label
var previous_button: Button
var next_button: Button
var save_button: Button
var feedback_label: Label
var used_slots_label: Label
var selected_slot_label: Label
var selected_title_label: Label
var selected_chapter_label: Label
var selected_time_label: Label
var selected_status_label: Label
var confirm_layer: Control
var case_context_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	call_deferred("_update_content_width")


func configure(manager: SaveManager, descriptor: Dictionary = {}) -> void:
	save_manager = manager
	case_descriptor = descriptor.duplicate(true)
	_refresh_case_context_label()


func open_page() -> void:
	current_page_index = 0
	selected_slot_index = -1
	visible = true
	_refresh_summaries(false)
	_select_first_empty_on_page()


func close_page() -> void:
	_hide_confirm()
	visible = false


func suspend_for_settings() -> void:
	_hide_confirm()
	visible = false


func resume_from_settings() -> void:
	visible = true


func report_save_result(result: Dictionary, slot_index: int) -> void:
	if bool(result.get("success", false)):
		feedback_label.text = "已保存到手动存档 %d" % slot_index
		selected_slot_index = slot_index
		_refresh_summaries(true)
	else:
		feedback_label.text = "保存失败：" + str(result.get("error", "未知错误"))


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
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", BODY_SEPARATION)
	content_box.add_child(body)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size.x = SLOT_LIST_WIDTH
	list_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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

	confirm_layer = Control.new()
	confirm_layer.visible = false
	confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.z_index = 20
	_fill_rect(confirm_layer)
	add_child(confirm_layer)


func _build_page_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var title := _label("存档", 30, C_BLUE, FONT_SERIF_SEMIBOLD)
	title_box.add_child(title)
	case_context_label = _label("SAVE ARCHIVE", 12, C_SUBTEXT, FONT_MONO_REGULAR)
	title_box.add_child(case_context_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	page_label = _label("第 1 / 3 页", 15, C_BLUE, FONT_MONO_MEDIUM)
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(page_label)
	return header


func _refresh_case_context_label() -> void:
	if case_context_label == null or case_descriptor.is_empty():
		return

	case_context_label.text = "%s / %s" % [
		str(case_descriptor.get("code", "CASE")),
		str(case_descriptor.get("title", "案件"))
	]


func _build_list_heading() -> Control:
	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 30
	heading.add_child(_section_title("存档列表"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	heading.add_child(_build_used_slots_tag())
	return heading


func _build_column_header() -> Control:
	var margin := MarginContainer.new()
	margin.custom_minimum_size.y = 34
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 14)

	var row := HBoxContainer.new()
	margin.add_child(row)
	row.add_child(_header_label("", int(COLUMN_SELECT_WIDTH), HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_header_label("档位", int(COLUMN_SLOT_WIDTH), HORIZONTAL_ALIGNMENT_CENTER))

	var name_header := _header_label("档位名称", int(COLUMN_NAME_MIN_WIDTH), HORIZONTAL_ALIGNMENT_LEFT)
	name_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_header)
	row.add_child(_header_label("状态", int(COLUMN_STATUS_WIDTH), HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_header_label("保存时间", int(COLUMN_TIME_WIDTH), HORIZONTAL_ALIGNMENT_RIGHT))
	return margin


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = DETAIL_PANEL_WIDTH
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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

	save_button = _button("保存到所选槽位", true, ICON_SAVE)
	save_button.custom_minimum_size.y = 52
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.disabled = true
	save_button.pressed.connect(_on_save_pressed)
	box.add_child(save_button)

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
	head.add_child(_label("固定档位", 17, C_BLUE, FONT_SERIF_SEMIBOLD))

	var description := _label(
		"自动存档固定只读；手动档位 1～20 可选择写入，已有数据覆盖前需要确认。",
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


func _refresh_summaries(preserve_selection: bool) -> void:
	if save_manager == null:
		feedback_label.text = "存档管理器不可用"
		return

	_summaries = save_manager.get_all_slot_summaries()
	_refresh_used_slots_label()

	if not preserve_selection:
		selected_slot_index = -1

	_render_page()


func _render_page() -> void:
	_clear_children(slot_list)
	page_label.text = "第 %d / %d 页" % [current_page_index + 1, PAGE_COUNT]

	var start_index: int = current_page_index * SLOTS_PER_PAGE
	var end_index: int = mini(start_index + SLOTS_PER_PAGE, _summaries.size())

	for index in range(start_index, end_index):
		slot_list.add_child(_build_slot_card(_summaries[index]))

	_render_page_buttons()
	_render_selected_detail()
	_update_save_button()


func _build_slot_card(summary: Dictionary) -> Control:
	var slot_type: String = str(summary.get("slot_type", "manual"))
	var slot_index: int = int(summary.get("slot_index", -1))
	var status: String = str(summary.get("status", "empty"))
	var selected: bool = slot_type == "manual" and slot_index == selected_slot_index
	var selectable: bool = slot_type == "manual"
	var available: bool = status == "available"
	var text_color: Color = C_BLUE if available or selectable else C_MUTED

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
	radio_box.custom_minimum_size.x = COLUMN_SELECT_WIDTH
	radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(radio_box)
	var radio_texture: Texture2D = ICON_CIRCLE_DOT if selected else ICON_CIRCLE
	radio_box.add_child(_icon(radio_texture, Vector2(19, 19), C_BLUE if selectable else C_MUTED))

	var slot_text: String = "自动" if slot_type == "autosave" else "%02d" % slot_index
	var slot_label := _label(slot_text, 17, text_color, FONT_MONO_MEDIUM)
	slot_label.custom_minimum_size.x = COLUMN_SLOT_WIDTH
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(slot_label)

	var metadata: Dictionary = summary.get("metadata", {})
	var detail_box := VBoxContainer.new()
	detail_box.custom_minimum_size.x = COLUMN_NAME_MIN_WIDTH
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

	var state_label := _label(_status_label(status, slot_type), 14, text_color, FONT_SERIF_REGULAR)
	state_label.custom_minimum_size.x = COLUMN_STATUS_WIDTH
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(state_label)

	var time_label := _label(str(summary.get("saved_at_text", "—")), 13, C_SUBTEXT if available else C_MUTED, FONT_MONO_REGULAR)
	time_label.custom_minimum_size.x = COLUMN_TIME_WIDTH
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(time_label)

	if selectable:
		var hit := _transparent_hit_button()
		hit.pressed.connect(_select_slot.bind(slot_index))
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


func _select_slot(slot_index: int) -> void:
	selected_slot_index = slot_index
	feedback_label.text = ""
	_render_page()


func _select_first_empty_on_page() -> void:
	if save_manager == null:
		return

	var page_summaries: Array[Dictionary] = save_manager.get_page_slot_summaries(current_page_index)

	for summary in page_summaries:
		if str(summary.get("slot_type", "")) == "manual" and str(summary.get("status", "")) == "empty":
			selected_slot_index = int(summary.get("slot_index", -1))
			_render_page()
			return

	selected_slot_index = -1
	_render_page()


func _change_page(delta: int) -> void:
	_set_page(clampi(current_page_index + delta, 0, PAGE_COUNT - 1))


func _set_page(page_index: int) -> void:
	current_page_index = clampi(page_index, 0, PAGE_COUNT - 1)
	feedback_label.text = ""
	_select_first_empty_on_page()


func _on_save_pressed() -> void:
	var summary: Dictionary = _summary_for_manual_slot(selected_slot_index)

	if summary.is_empty():
		feedback_label.text = "请选择手动存档槽位"
		return

	if str(summary.get("status", "empty")) == "empty":
		save_requested.emit(selected_slot_index)
		return

	_show_overwrite_confirm(selected_slot_index)


func _show_overwrite_confirm(slot_index: int) -> void:
	_clear_children(confirm_layer)
	confirm_layer.visible = true
	var overlay := ColorRect.new()
	overlay.color = C_OVERLAY
	_fill_rect(overlay)
	confirm_layer.add_child(overlay)

	var center := CenterContainer.new()
	_fill_rect(center)
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 240)
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, C_BLUE, 1, 6))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	box.add_child(_label("覆盖手动存档 %d" % slot_index, 22, C_BLUE, FONT_SERIF_SEMIBOLD))
	var message := _label("该槽位已有数据。确认用当前运行状态覆盖？", 15, C_SUBTEXT, FONT_SERIF_REGULAR)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(message)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var cancel := _button("取消", false)
	cancel.pressed.connect(_hide_confirm)
	buttons.add_child(cancel)
	var confirm := _button("确认覆盖", true)
	confirm.pressed.connect(func():
		_hide_confirm()
		save_requested.emit(slot_index)
	)
	buttons.add_child(confirm)


func _hide_confirm() -> void:
	if confirm_layer == null:
		return

	confirm_layer.visible = false
	_clear_children(confirm_layer)


func _render_selected_detail() -> void:
	var summary: Dictionary = _summary_for_manual_slot(selected_slot_index)

	if summary.is_empty():
		selected_slot_label.text = "—"
		selected_title_label.text = "暂无档位"
		selected_chapter_label.text = "请选择手动存档槽位"
		selected_time_label.text = "—"
		selected_status_label.text = "未选择"
		return

	var status: String = str(summary.get("status", "empty"))
	var metadata: Dictionary = summary.get("metadata", {})
	selected_slot_label.text = "%02d" % selected_slot_index
	selected_title_label.text = _status_primary_text(status, metadata)
	selected_chapter_label.text = _status_secondary_text(status, metadata, summary)
	selected_time_label.text = str(summary.get("saved_at_text", "—"))
	selected_status_label.text = _status_label(status, "manual")
	selected_title_label.tooltip_text = selected_title_label.text
	selected_chapter_label.tooltip_text = selected_chapter_label.text


func _summary_for_manual_slot(slot_index: int) -> Dictionary:
	for summary in _summaries:
		if str(summary.get("slot_type", "")) == "manual" and int(summary.get("slot_index", -1)) == slot_index:
			return summary

	return {}


func _update_save_button() -> void:
	save_button.disabled = selected_slot_index < 1 or selected_slot_index > 20
	_refresh_centered_button_content(save_button)


func _status_primary_text(status: String, metadata: Dictionary) -> String:
	if status == "available":
		return str(metadata.get("chapter_title", "控制室备份录音"))
	if status == "corrupted":
		return "存档损坏"
	if status == "incompatible":
		return "版本不兼容"
	return "空存档"


func _status_secondary_text(status: String, metadata: Dictionary, summary: Dictionary) -> String:
	if status == "available":
		return "%s · %s" % [
			str(metadata.get("node_title", "当前节点")),
			str(metadata.get("node_id", ""))
		]
	if status == "corrupted" or status == "incompatible":
		return str(summary.get("error", "存档不可读取"))
	return "暂无数据"


func _status_label(status: String, slot_type: String) -> String:
	if slot_type == "autosave":
		return "只读"
	if status == "available":
		return "可覆盖"
	if status == "corrupted" or status == "incompatible":
		return "可覆盖"
	return "可保存"


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


func _build_used_slots_tag() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(144, 30)
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 4))
	used_slots_label = _label("已用档位 0/21", 13, C_BLUE, FONT_SERIF_REGULAR)
	used_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	used_slots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(used_slots_label)
	return panel


func _refresh_used_slots_label() -> void:
	if used_slots_label == null:
		return

	var used_count: int = 0

	for summary in _summaries:
		if str(summary.get("status", "empty")) != "empty":
			used_count += 1

	used_slots_label.text = "已用档位 %d/21" % used_count


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
	label.tooltip_text = text
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
	button.custom_minimum_size = Vector2(132, 42)
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("centered_action_primary", active)
	button.set_meta("centered_action_down", false)
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE if active else C_WHITE, C_BLUE if active else C_LINE, 1, 4))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_DARK if active else C_PANEL_SOFT, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 4))
	button.add_theme_stylebox_override("focus", _style_box(C_BLUE if active else C_PANEL_SOFT, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("disabled", _style_box(C_PANEL_SOFT, C_DIVIDER, 1, 4))

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(center)
	button.add_child(center)
	var content := HBoxContainer.new()
	content.name = "CenteredContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	center.add_child(content)

	if icon != null:
		var icon_rect := _icon(icon, Vector2(19, 19), C_WHITE if active else C_BLUE)
		icon_rect.name = "ActionIcon"
		content.add_child(icon_rect)

	var text_label := _label(text, 15, C_WHITE if active else C_BLUE, FONT_SERIF_SEMIBOLD)
	text_label.name = "ActionLabel"
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text_label)

	button.mouse_entered.connect(_refresh_centered_button_content.bind(button))
	button.mouse_exited.connect(_refresh_centered_button_content.bind(button))
	button.button_down.connect(_set_centered_button_down.bind(button, true))
	button.button_up.connect(_set_centered_button_down.bind(button, false))
	button.focus_entered.connect(_refresh_centered_button_content.bind(button))
	button.focus_exited.connect(_refresh_centered_button_content.bind(button))
	call_deferred("_refresh_centered_button_content", button)
	return button


func _set_centered_button_down(button: Button, pressed: bool) -> void:
	if button == null or not is_instance_valid(button):
		return

	button.set_meta("centered_action_down", pressed)
	_refresh_centered_button_content(button)


func _refresh_centered_button_content(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return

	var primary: bool = bool(button.get_meta("centered_action_primary", false))
	var pressed: bool = bool(button.get_meta("centered_action_down", false))
	var color: Color = C_WHITE if primary or pressed else C_BLUE

	if button.disabled:
		color = C_MUTED

	var label: Label = button.find_child("ActionLabel", true, false) as Label
	var icon_rect: TextureRect = button.find_child("ActionIcon", true, false) as TextureRect

	if label != null:
		label.add_theme_color_override("font_color", color)

	if icon_rect != null:
		icon_rect.modulate = color


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
