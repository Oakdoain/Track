extends Control

const AudioWaveformPlaceholder := preload("res://scripts/case/AudioWaveformPlaceholder.gd")

const MIN_WINDOW_SIZE := Vector2i(1360, 760)
const TOP_BAR_HEIGHT := 70
const BOTTOM_BAR_HEIGHT := 34
const LEFT_PANEL_WIDTH := 320
const RIGHT_PANEL_WIDTH := 340

const C_BG := Color("#F4F7FF")
const C_PANEL := Color("#FFFFFF")
const C_PANEL_SOFT := Color("#EEF4FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_BLUE_SOFT := Color("#DCE7FF")
const C_LINE := Color("#9FB3EA")
const C_DIVIDER := Color("#D5DEF5")
const C_TEXT := Color("#23315C")
const C_SUBTEXT := Color("#5C6686")
const C_MUTED := Color("#8290B3")
const C_WHITE := Color("#FFFFFF")

var loader: CaseDataLoader
var runtime_state: CaseRuntimeState

var root: Control
var top_bar: PanelContainer
var left_panel: PanelContainer
var center_panel: PanelContainer
var right_panel: PanelContainer
var bottom_bar: PanelContainer

var chapter_title_label: Label
var chapter_intro_label: Label
var goal_label: Label
var keyword_list: HFlowContainer

var center_content: VBoxContainer
var node_title_label: Label
var audio_card_slot: VBoxContainer
var node_body_label: RichTextLabel
var choices_box: VBoxContainer

var current_id_value: Label
var current_title_value: Label
var current_type_value: Label
var current_location_value: Label
var current_time_value: Label
var related_clues_list: VBoxContainer
var graph_tag_list: HFlowContainer
var property_characters_value: Label
var property_rooms_value: Label
var property_autosave_value: Label


func _ready() -> void:
	print("USER DATA DIR: " + OS.get_user_data_dir())
	_setup_window()
	loader = CaseDataLoader.new()
	runtime_state = CaseRuntimeState.new()
	_build_ui()

	if not loader.load_nodes():
		return

	var initial_node_id: String = loader.get_initial_node_id()
	_show_node(initial_node_id)


func _setup_window() -> void:
	var window: Window = get_window()
	window.min_size = MIN_WINDOW_SIZE
	RenderingServer.set_default_clear_color(C_BG)


func _build_ui() -> void:
	root = Control.new()
	root.name = "Root"
	_fill_rect(root)
	add_child(root)

	top_bar = _build_top_bar()
	root.add_child(top_bar)
	_dock_top(top_bar, TOP_BAR_HEIGHT)

	bottom_bar = _build_bottom_bar()
	root.add_child(bottom_bar)
	_dock_bottom(bottom_bar, BOTTOM_BAR_HEIGHT)

	left_panel = _build_left_panel()
	root.add_child(left_panel)
	_dock_left(left_panel, LEFT_PANEL_WIDTH, TOP_BAR_HEIGHT, BOTTOM_BAR_HEIGHT)

	right_panel = _build_right_panel()
	root.add_child(right_panel)
	_dock_right(right_panel, RIGHT_PANEL_WIDTH, TOP_BAR_HEIGHT, BOTTOM_BAR_HEIGHT)

	center_panel = _build_center_panel()
	root.add_child(center_panel)
	_dock_center(center_panel, LEFT_PANEL_WIDTH, RIGHT_PANEL_WIDTH, TOP_BAR_HEIGHT, BOTTOM_BAR_HEIGHT)


func _build_top_bar() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_DIVIDER, 1, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.custom_minimum_size.x = 440
	title_box.add_theme_constant_override("separation", 0)
	row.add_child(title_box)

	var title: Label = _label("第三轨：隔音室谋杀案", 22, C_BLUE, true)
	title_box.add_child(title)

	var subtitle: Label = _label("案件档案 Case Archive", 12, C_MUTED, false)
	title_box.add_child(subtitle)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	for item in ["剧情", "图谱", "存档", "读取", "设置"]:
		row.add_child(_nav_button(item, item == "剧情"))

	return panel


func _build_left_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_DIVIDER, 1, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	box.add_child(_small_caps_label("章节标题"))
	chapter_title_label = _label("", 25, C_BLUE, true)
	chapter_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(chapter_title_label)

	chapter_intro_label = _label("", 15, C_SUBTEXT, false)
	chapter_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(chapter_intro_label)

	box.add_child(_divider())
	box.add_child(_small_caps_label("当前目标"))

	goal_label = _label("", 15, C_BLUE, true)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(goal_label)

	box.add_child(_divider())
	box.add_child(_small_caps_label("已发现关键词"))

	keyword_list = HFlowContainer.new()
	keyword_list.add_theme_constant_override("h_separation", 8)
	keyword_list.add_theme_constant_override("v_separation", 8)
	box.add_child(keyword_list)

	return panel


func _build_center_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, Color.TRANSPARENT, 0, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	center_content = VBoxContainer.new()
	center_content.custom_minimum_size.x = 760
	center_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_content.add_theme_constant_override("separation", 18)
	center.add_child(center_content)

	node_title_label = _label("", 32, C_BLUE, true)
	node_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_content.add_child(node_title_label)

	audio_card_slot = VBoxContainer.new()
	audio_card_slot.add_theme_constant_override("separation", 0)
	center_content.add_child(audio_card_slot)

	var body_card: PanelContainer = PanelContainer.new()
	body_card.add_theme_stylebox_override("panel", _style_box(C_PANEL, C_DIVIDER, 1, 6))
	center_content.add_child(body_card)

	var body_margin: MarginContainer = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 28)
	body_margin.add_theme_constant_override("margin_right", 28)
	body_margin.add_theme_constant_override("margin_top", 24)
	body_margin.add_theme_constant_override("margin_bottom", 24)
	body_card.add_child(body_margin)

	node_body_label = RichTextLabel.new()
	node_body_label.fit_content = true
	node_body_label.scroll_active = false
	node_body_label.bbcode_enabled = false
	node_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node_body_label.add_theme_color_override("default_color", C_TEXT)
	node_body_label.add_theme_font_size_override("normal_font_size", 18)
	node_body_label.add_theme_constant_override("line_separation", 8)
	body_margin.add_child(node_body_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 10)
	center_content.add_child(choices_box)

	return panel


func _build_right_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_DIVIDER, 1, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	var current_card: VBoxContainer = _right_card(box, "当前节点")
	current_id_value = _dossier_row(current_card, "node_id")
	current_title_value = _dossier_row(current_card, "title")
	current_type_value = _dossier_row(current_card, "node_type")
	current_location_value = _dossier_row(current_card, "location")
	current_time_value = _dossier_row(current_card, "time_label")

	var clues_card: VBoxContainer = _right_card(box, "相关线索")
	related_clues_list = VBoxContainer.new()
	related_clues_list.add_theme_constant_override("separation", 6)
	clues_card.add_child(related_clues_list)

	var graph_card: VBoxContainer = _right_card(box, "关联图谱")
	graph_tag_list = HFlowContainer.new()
	graph_tag_list.add_theme_constant_override("h_separation", 6)
	graph_tag_list.add_theme_constant_override("v_separation", 6)
	graph_card.add_child(graph_tag_list)

	var properties_card: VBoxContainer = _right_card(box, "节点属性")
	property_characters_value = _dossier_row(properties_card, "characters")
	property_rooms_value = _dossier_row(properties_card, "room_refs")
	property_autosave_value = _dossier_row(properties_card, "autosave")

	return panel


func _build_bottom_bar() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_DIVIDER, 1, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	row.add_child(_status_label("系统状态：Vertical Slice"))
	row.add_child(_status_label("数据源：control_backup"))
	row.add_child(_status_label("当前时间：20:16:42"))

	return panel


func _show_node(node_id: String) -> void:
	var node_data: Dictionary = loader.get_node(node_id)

	if node_data.is_empty():
		push_warning("CaseNodeView: node not found: " + node_id)
		return

	var autosave: bool = bool(node_data.get("autosave", false))
	runtime_state.set_current_node(node_id, autosave)
	_render_static_case_info()
	_render_node(node_data)


func _render_static_case_info() -> void:
	chapter_title_label.text = loader.get_chapter_title()
	chapter_intro_label.text = loader.get_chapter_intro()
	goal_label.text = loader.get_current_goal()

	_clear_children(keyword_list)
	var keywords: Array = loader.get_discovered_keywords()

	for keyword in keywords:
		keyword_list.add_child(_tag_label(str(keyword), C_PANEL, C_BLUE))


func _render_node(node_data: Dictionary) -> void:
	var icon_key: String = str(node_data.get("icon_key", ""))
	var title_text: String = str(node_data.get("title", ""))

	if icon_key != "":
		node_title_label.text = "[%s] %s" % [icon_key, title_text]
	else:
		node_title_label.text = title_text

	_render_audio_card(node_data, title_text)
	_render_body(node_data)
	_render_choices(node_data)
	_render_right_panel(node_data, title_text)


func _render_audio_card(node_data: Dictionary, title_text: String) -> void:
	_clear_children(audio_card_slot)

	var audio_clues: Variant = node_data.get("audio_clues", [])
	var node_type: String = str(node_data.get("node_type", ""))
	var has_audio: bool = (audio_clues is Array and not audio_clues.is_empty()) or node_type.contains("音频")

	if not has_audio:
		return

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 168)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _style_box(C_PANEL, C_LINE, 1, 7))
	audio_card_slot.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	box.add_child(top_row)

	var audio_title: Label = _label("播放 " + title_text, 15, C_BLUE, true)
	audio_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(audio_title)

	var mark_button: Button = _compact_button("标记")
	top_row.add_child(mark_button)

	var waveform: Control = AudioWaveformPlaceholder.new()
	waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(waveform)

	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	box.add_child(bottom_row)

	var play_button: Button = _round_button("▶")
	bottom_row.add_child(play_button)

	var time_label: Label = _label("正在播放 00:00 / 04:08", 14, C_SUBTEXT, false)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_row.add_child(time_label)


func _render_body(node_data: Dictionary) -> void:
	node_body_label.clear()

	var body: Variant = node_data.get("body", [])

	if body is Array:
		for index in range(body.size()):
			node_body_label.append_text(str(body[index]))

			if index < body.size() - 1:
				node_body_label.append_text("\n\n")
	else:
		node_body_label.append_text(str(body))


func _render_choices(node_data: Dictionary) -> void:
	_clear_children(choices_box)
	var choices: Variant = node_data.get("choices", [])

	if not (choices is Array):
		return

	for choice in choices:
		if choice is Dictionary:
			choices_box.add_child(_choice_button(choice))


func _render_right_panel(node_data: Dictionary, title_text: String) -> void:
	current_id_value.text = str(node_data.get("node_id", ""))
	current_title_value.text = title_text
	current_type_value.text = str(node_data.get("node_type", ""))
	current_location_value.text = str(node_data.get("location", ""))
	current_time_value.text = str(node_data.get("time_label", ""))

	_clear_children(related_clues_list)
	_add_list_values(related_clues_list, node_data.get("text_clues", []), "TXT")
	_add_list_values(related_clues_list, node_data.get("audio_clues", []), "AUD")

	if related_clues_list.get_child_count() == 0:
		related_clues_list.add_child(_muted_value("无"))

	_clear_children(graph_tag_list)
	_add_graph_tags(node_data)

	property_characters_value.text = _join_array(node_data.get("characters", []))
	property_rooms_value.text = _join_array(node_data.get("room_refs", []))

	var autosave_text: String = "安全节点" if bool(node_data.get("autosave", false)) else "非安全节点"
	property_autosave_value.text = "%s / 最近安全节点：%s" % [
		autosave_text,
		runtime_state.last_safe_autosave_node_id
	]


func _choice_button(choice: Dictionary) -> Button:
	var button: Button = Button.new()
	var action: String = str(choice.get("action", ""))
	var target_node_id: String = _get_choice_target_node_id(choice)
	var title: String = str(choice.get("title", "未命名选择"))

	if action == "play_audio" and title == "":
		title = "播放备份录音（占位）"

	button.text = "›  %s    →" % title
	button.custom_minimum_size.y = 54
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", C_BLUE)
	button.add_theme_color_override("font_hover_color", C_BLUE_DARK)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _style_box(C_PANEL, C_LINE, 1, 6))
	button.add_theme_stylebox_override("hover", _style_box(C_PANEL_SOFT, C_BLUE, 1, 6))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE, C_BLUE_DARK, 1, 6))
	button.add_theme_stylebox_override("disabled", _style_box(C_PANEL, C_DIVIDER, 1, 6))

	if action == "play_audio":
		button.text = "›  播放备份录音（占位）"
		button.disabled = true
	elif action == "load_last_safe_autosave":
		button.pressed.connect(func() -> void:
			if runtime_state.last_safe_autosave_node_id != "":
				_show_node(runtime_state.last_safe_autosave_node_id)
		)
	elif target_node_id != "":
		button.pressed.connect(func() -> void:
			_show_node(target_node_id)
		)
	else:
		button.disabled = true

	return button


func _get_choice_target_node_id(choice: Dictionary) -> String:
	if choice.has("to"):
		return str(choice.get("to", ""))

	return str(choice.get("target_node_id", ""))


func _right_card(parent: VBoxContainer, title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(C_PANEL, C_DIVIDER, 1, 6))
	parent.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(_small_caps_label(title))
	return box


func _dossier_row(parent: VBoxContainer, title: String) -> Label:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var title_label: Label = _label(title, 12, C_MUTED, false)
	box.add_child(title_label)

	var value_label: Label = _label("", 14, C_BLUE, true)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(value_label)

	return value_label


func _add_list_values(parent: VBoxContainer, value: Variant, prefix: String) -> void:
	if not (value is Array):
		return

	for item in value:
		var label: Label = _label("[%s] %s" % [prefix, str(item)], 13, C_TEXT, false)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(label)


func _add_graph_tags(node_data: Dictionary) -> void:
	var items: Array = []
	_append_array_values(items, node_data.get("characters", []))
	_append_array_values(items, node_data.get("room_refs", []))
	_append_array_values(items, node_data.get("audio_clues", []))

	var limit: int = min(items.size(), 6)

	for index in range(limit):
		graph_tag_list.add_child(_tag_label(str(items[index]), C_PANEL_SOFT, C_BLUE))

	if graph_tag_list.get_child_count() == 0:
		graph_tag_list.add_child(_tag_label("无", C_PANEL_SOFT, C_MUTED))


func _join_array(value: Variant) -> String:
	var items: Array = []
	_append_array_values(items, value)
	return _join_strings(items)


func _append_array_values(items: Array, value: Variant) -> void:
	if value is Array:
		for item in value:
			items.append(str(item))


func _join_strings(items: Array) -> String:
	if items.is_empty():
		return "无"

	var result: String = ""

	for index in range(items.size()):
		if index > 0:
			result += " / "

		result += str(items[index])

	return result


func _nav_button(text: String, active: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(78, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not active
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("font_disabled_color", C_BLUE)
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE if active else C_PANEL, C_BLUE, 1, 5))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_SOFT, C_BLUE, 1, 5))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 5))
	button.add_theme_stylebox_override("disabled", _style_box(C_BLUE if active else C_PANEL, C_BLUE, 1, 5))
	return button


func _compact_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(62, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", C_BLUE)
	button.add_theme_stylebox_override("normal", _style_box(C_PANEL, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_SOFT, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE, C_BLUE_DARK, 1, 4))
	return button


func _round_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(36, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", C_WHITE)
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE, C_BLUE, 1, 18))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 18))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 18))
	return button


func _tag_label(text: String, bg_color: Color, text_color: Color) -> Label:
	var label: Label = _label(text, 13, text_color, true)
	label.custom_minimum_size = Vector2(0, 28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _style_box(bg_color, C_LINE, 1, 4))
	return label


func _small_caps_label(text: String) -> Label:
	var label: Label = _label(text, 13, C_MUTED, true)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _status_label(text: String) -> Label:
	var label: Label = _label(text, 12, C_SUBTEXT, false)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _muted_value(text: String) -> Label:
	return _label(text, 13, C_MUTED, false)


func _label(text: String, font_size: int, color: Color, bold: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

	if bold:
		label.add_theme_constant_override("outline_size", 0)

	return label


func _divider() -> HSeparator:
	var divider: HSeparator = HSeparator.new()
	divider.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	return divider


func _style_box(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _fill_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func _dock_top(control: Control, height: int) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = height


func _dock_bottom(control: Control, height: int) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 1.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0
	control.offset_top = -height
	control.offset_right = 0
	control.offset_bottom = 0


func _dock_left(control: Control, width: int, top: int, bottom: int) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 1.0
	control.offset_left = 0
	control.offset_top = top
	control.offset_right = width
	control.offset_bottom = -bottom


func _dock_right(control: Control, width: int, top: int, bottom: int) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = -width
	control.offset_top = top
	control.offset_right = 0
	control.offset_bottom = -bottom


func _dock_center(control: Control, left: int, right: int, top: int, bottom: int) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = -bottom
