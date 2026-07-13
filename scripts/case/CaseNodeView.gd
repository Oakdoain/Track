extends Control

const AudioWaveformPlaceholder := preload("res://scripts/case/AudioWaveformPlaceholder.gd")

const MIN_WINDOW_SIZE := Vector2i(1360, 760)

const TOP_BAR_HEIGHT := 72
const LEFT_PANEL_WIDTH := 400
const RIGHT_PANEL_WIDTH := 400

const CENTER_CONTENT_MIN_WIDTH := 900
const IMAGE_CARD_HEIGHT := 520

const C_BG := Color("#F7F9FF")
const C_PANEL := Color("#FFFFFF")
const C_PANEL_SOFT := Color("#F0F4FF")

const C_BLUE := Color("#164BB8")
const C_BLUE_DARK := Color("#0E368F")
const C_BLUE_SOFT := Color("#E7EEFF")

const C_LINE := Color("#A8BFF2")
const C_DIVIDER := Color("#D8E1F5")

const C_TEXT := Color("#25345D")
const C_SUBTEXT := Color("#626F92")
const C_MUTED := Color("#8793B2")

const C_WHITE := Color("#FFFFFF")


var loader: CaseDataLoader
var runtime_state: CaseRuntimeState

var root: Control

var top_bar: PanelContainer
var left_panel: PanelContainer
var center_panel: PanelContainer
var right_panel: PanelContainer

var chapter_title_label: Label
var chapter_intro_label: Label
var goal_label: Label
var keyword_list: HFlowContainer

var center_content: VBoxContainer
var node_type_badge: Label
var node_title_label: Label
var audio_card_slot: VBoxContainer
var image_card_slot: VBoxContainer
var node_body_label: RichTextLabel
var action_hint_label: Label
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
	_setup_window()

	loader = CaseDataLoader.new()
	runtime_state = CaseRuntimeState.new()

	_build_ui()

	if not loader.load_nodes():
		push_error("CaseNodeView: failed to load case node data.")
		return

	var initial_node_id: String = loader.get_initial_node_id()

	if initial_node_id == "":
		push_error("CaseNodeView: initial node id is empty.")
		return

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

	left_panel = _build_left_panel()
	root.add_child(left_panel)
	_dock_left(
		left_panel,
		LEFT_PANEL_WIDTH,
		TOP_BAR_HEIGHT
	)

	right_panel = _build_right_panel()
	root.add_child(right_panel)
	_dock_right(
		right_panel,
		RIGHT_PANEL_WIDTH,
		TOP_BAR_HEIGHT
	)

	center_panel = _build_center_panel()
	root.add_child(center_panel)
	_dock_center(
		center_panel,
		LEFT_PANEL_WIDTH,
		RIGHT_PANEL_WIDTH,
		TOP_BAR_HEIGHT
	)


func _build_top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_BLUE, 1, 0)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var brand_box := HBoxContainer.new()
	brand_box.custom_minimum_size.x = 500
	brand_box.add_theme_constant_override("separation", 16)
	row.add_child(brand_box)

	var title := _label(
		"叙事图谱",
		27,
		C_BLUE,
		true
	)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand_box.add_child(title)

	var subtitle := _label(
		"NARRATIVE GRAPH",
		13,
		C_SUBTEXT,
		false
	)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand_box.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_nav_button("‹  回溯", false))

	for item in ["剧情", "图谱", "存档", "读取", "设置"]:
		row.add_child(_nav_button(item, item == "剧情"))

	return panel


func _build_left_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL_SOFT, C_DIVIDER, 1, 0)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	box.add_child(_small_caps_label("案件章节"))

	chapter_title_label = _label(
		"",
		28,
		C_BLUE,
		true
	)
	chapter_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(chapter_title_label)

	chapter_intro_label = _label(
		"",
		15,
		C_SUBTEXT,
		false
	)
	chapter_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_intro_label.add_theme_constant_override("line_spacing", 6)
	box.add_child(chapter_intro_label)

	box.add_child(_divider())

	box.add_child(_small_caps_label("当前目标"))
	box.add_child(_build_goal_card())

	box.add_child(_divider())

	box.add_child(_small_caps_label("已发现关键词"))

	keyword_list = HFlowContainer.new()
	keyword_list.add_theme_constant_override("h_separation", 10)
	keyword_list.add_theme_constant_override("v_separation", 10)
	box.add_child(keyword_list)

	return panel


func _build_goal_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_LINE, 1, 6)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var marker := _label(
		"◇",
		20,
		C_BLUE,
		true
	)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(marker)

	goal_label = _label(
		"",
		15,
		C_BLUE,
		true
	)
	goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(goal_label)

	return card


func _build_center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_BG, Color.TRANSPARENT, 0, 0)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	center_content = VBoxContainer.new()
	center_content.custom_minimum_size.x = CENTER_CONTENT_MIN_WIDTH
	center_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_content.add_theme_constant_override("separation", 20)
	scroll.add_child(center_content)

	var badge_center := CenterContainer.new()
	badge_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_content.add_child(badge_center)

	node_type_badge = _label(
		"",
		13,
		C_BLUE,
		true
	)
	node_type_badge.custom_minimum_size = Vector2(112, 30)
	node_type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node_type_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node_type_badge.add_theme_stylebox_override(
		"normal",
		_style_box(C_PANEL, C_BLUE, 1, 4)
	)
	badge_center.add_child(node_type_badge)

	node_title_label = _label(
		"",
		35,
		C_BLUE,
		true
	)
	node_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_content.add_child(node_title_label)

	center_content.add_child(_build_title_divider())

	audio_card_slot = VBoxContainer.new()
	audio_card_slot.add_theme_constant_override("separation", 12)
	center_content.add_child(audio_card_slot)

	image_card_slot = VBoxContainer.new()
	image_card_slot.add_theme_constant_override("separation", 18)
	center_content.add_child(image_card_slot)

	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 42)
	body_margin.add_theme_constant_override("margin_right", 42)
	body_margin.add_theme_constant_override("margin_top", 4)
	body_margin.add_theme_constant_override("margin_bottom", 4)
	center_content.add_child(body_margin)

	node_body_label = RichTextLabel.new()
	node_body_label.fit_content = true
	node_body_label.scroll_active = false
	node_body_label.bbcode_enabled = false
	node_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node_body_label.add_theme_color_override("default_color", C_TEXT)
	node_body_label.add_theme_font_size_override("normal_font_size", 18)
	node_body_label.add_theme_constant_override("line_separation", 12)
	body_margin.add_child(node_body_label)

	action_hint_label = _label(
		"请选择你的行动",
		13,
		C_MUTED,
		false
	)
	action_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_content.add_child(action_hint_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 10)
	center_content.add_child(choices_box)

	return panel


func _build_title_divider() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var left_line := HSeparator.new()
	left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_line.add_theme_stylebox_override(
		"separator",
		_style_box(C_LINE, C_LINE, 1, 0)
	)
	row.add_child(left_line)

	var diamond := _label(
		"◇",
		17,
		C_BLUE,
		true
	)
	diamond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diamond.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(diamond)

	var right_line := HSeparator.new()
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_line.add_theme_stylebox_override(
		"separator",
		_style_box(C_LINE, C_LINE, 1, 0)
	)
	row.add_child(right_line)

	return row


func _build_right_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL_SOFT, C_DIVIDER, 1, 0)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	box.add_child(_section_heading("节点档案"))

	var dossier_panel := PanelContainer.new()
	dossier_panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_LINE, 1, 6)
	)
	box.add_child(dossier_panel)

	var dossier_margin := MarginContainer.new()
	dossier_margin.add_theme_constant_override("margin_left", 0)
	dossier_margin.add_theme_constant_override("margin_right", 0)
	dossier_margin.add_theme_constant_override("margin_top", 4)
	dossier_margin.add_theme_constant_override("margin_bottom", 4)
	dossier_panel.add_child(dossier_margin)

	var dossier_box := VBoxContainer.new()
	dossier_box.add_theme_constant_override("separation", 0)
	dossier_margin.add_child(dossier_box)

	current_id_value = _dossier_table_row(
		dossier_box,
		"节点编号"
	)

	current_type_value = _dossier_table_row(
		dossier_box,
		"节点类型"
	)

	current_location_value = _dossier_table_row(
		dossier_box,
		"发生地点"
	)

	current_time_value = _dossier_table_row(
		dossier_box,
		"发生时间"
	)

	current_title_value = _dossier_table_row(
		dossier_box,
		"节点标题"
	)

	box.add_child(_section_heading("相关线索"))

	related_clues_list = VBoxContainer.new()
	related_clues_list.add_theme_constant_override("separation", 8)
	box.add_child(related_clues_list)

	box.add_child(_section_heading("关联图谱"))

	var graph_panel := PanelContainer.new()
	graph_panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_LINE, 1, 6)
	)
	box.add_child(graph_panel)

	var graph_margin := MarginContainer.new()
	graph_margin.add_theme_constant_override("margin_left", 12)
	graph_margin.add_theme_constant_override("margin_right", 12)
	graph_margin.add_theme_constant_override("margin_top", 14)
	graph_margin.add_theme_constant_override("margin_bottom", 14)
	graph_panel.add_child(graph_margin)

	graph_tag_list = HFlowContainer.new()
	graph_tag_list.add_theme_constant_override("h_separation", 8)
	graph_tag_list.add_theme_constant_override("v_separation", 8)
	graph_margin.add_child(graph_tag_list)

	box.add_child(_section_heading("节点属性"))

	var properties_panel := PanelContainer.new()
	properties_panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_LINE, 1, 6)
	)
	box.add_child(properties_panel)

	var properties_margin := MarginContainer.new()
	properties_margin.add_theme_constant_override("margin_left", 0)
	properties_margin.add_theme_constant_override("margin_right", 0)
	properties_margin.add_theme_constant_override("margin_top", 4)
	properties_margin.add_theme_constant_override("margin_bottom", 4)
	properties_panel.add_child(properties_margin)

	var properties_box := VBoxContainer.new()
	properties_box.add_theme_constant_override("separation", 0)
	properties_margin.add_child(properties_box)

	property_characters_value = _dossier_table_row(
		properties_box,
		"关联角色"
	)

	property_rooms_value = _dossier_table_row(
		properties_box,
		"关联区域"
	)

	property_autosave_value = _dossier_table_row(
		properties_box,
		"存档状态"
	)

	return panel


func _show_node(node_id: String) -> void:
	var node_data: Dictionary = loader.get_node(node_id)

	if node_data.is_empty():
		push_warning(
			"CaseNodeView: node not found: " + node_id
		)
		return

	var autosave: bool = bool(
		node_data.get("autosave", false)
	)

	runtime_state.set_current_node(
		node_id,
		autosave
	)

	_render_static_case_info()
	_render_node(node_data)


func _render_static_case_info() -> void:
	chapter_title_label.text = loader.get_chapter_title()
	chapter_intro_label.text = loader.get_chapter_intro()
	goal_label.text = loader.get_current_goal()

	_clear_children(keyword_list)

	var keywords: Array = loader.get_discovered_keywords()

	for keyword in keywords:
		keyword_list.add_child(
			_tag_label(
				str(keyword),
				C_PANEL,
				C_BLUE
			)
		)


func _render_node(node_data: Dictionary) -> void:
	var title_text: String = str(
		node_data.get("title", "")
	)

	var node_type: String = str(
		node_data.get("node_type", "事件节点")
	)

	node_type_badge.text = node_type
	node_title_label.text = title_text

	_render_audio_card(
		node_data,
		title_text
	)

	_render_image_cards(node_data)
	_render_body(node_data)
	_render_choices(node_data)

	_render_right_panel(
		node_data,
		title_text
	)


func _render_audio_card(
	node_data: Dictionary,
	title_text: String
) -> void:
	_clear_children(audio_card_slot)

	var audio_clues: Variant = node_data.get(
		"audio_clues",
		[]
	)

	var node_type: String = str(
		node_data.get("node_type", "")
	)

	var has_audio: bool = (
		audio_clues is Array
		and not audio_clues.is_empty()
	) or node_type.contains("音频")

	if not has_audio:
		return

	var card := PanelContainer.new()
	card.custom_minimum_size.y = 174
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_LINE, 1, 6)
	)
	audio_card_slot.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	box.add_child(top_row)

	var audio_title := _label(
		"音频线索 · " + title_text,
		16,
		C_BLUE,
		true
	)
	audio_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(audio_title)

	var mark_button := _compact_button("标记")
	top_row.add_child(mark_button)

	var waveform: Control = AudioWaveformPlaceholder.new()
	waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(waveform)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	box.add_child(bottom_row)

	var play_button := _round_button("▶")
	bottom_row.add_child(play_button)

	var time_label := _label(
		"正在播放 00:00 / 04:08",
		14,
		C_SUBTEXT,
		false
	)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_row.add_child(time_label)


func _render_image_cards(node_data: Dictionary) -> void:
	_clear_children(image_card_slot)

	var image_items: Array = _collect_image_items(node_data)

	for image_item in image_items:
		if image_item is Dictionary:
			image_card_slot.add_child(
				_build_image_card(image_item)
			)


func _collect_image_items(
	node_data: Dictionary
) -> Array:
	var result: Array = []

	var floor_plan: Variant = node_data.get(
		"floor_plan",
		{}
	)

	if (
		floor_plan is Dictionary
		and not floor_plan.is_empty()
	):
		result.append(floor_plan)

	var image_clues: Variant = node_data.get(
		"image_clues",
		[]
	)

	if image_clues is Array:
		for image_clue in image_clues:
			if (
				image_clue is Dictionary
				and not image_clue.is_empty()
			):
				result.append(image_clue)

	return result


func _build_image_card(
	image_data: Dictionary
) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 10)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	container.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var section_title := _label(
		"结构图 / FLOOR PLAN",
		12,
		C_MUTED,
		true
	)
	title_box.add_child(section_title)

	var image_title := _label(
		str(
			image_data.get(
				"title",
				"图像线索"
			)
		),
		18,
		C_BLUE,
		true
	)
	image_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(image_title)

	var image_id: String = str(
		image_data.get("id", "")
	)

	if image_id != "":
		header.add_child(
			_tag_label(
				image_id,
				C_PANEL,
				C_BLUE
			)
		)

	var image_frame := PanelContainer.new()
	image_frame.custom_minimum_size.y = IMAGE_CARD_HEIGHT
	image_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_frame.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_LINE, 1, 5)
	)
	container.add_child(image_frame)

	var frame_margin := MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 10)
	frame_margin.add_theme_constant_override("margin_right", 10)
	frame_margin.add_theme_constant_override("margin_top", 10)
	frame_margin.add_theme_constant_override("margin_bottom", 10)
	image_frame.add_child(frame_margin)

	var image_path: String = str(
		image_data.get("image_path", "")
	)

	var texture: Texture2D = null

	if (
		image_path != ""
		and ResourceLoader.exists(image_path)
	):
		texture = load(image_path) as Texture2D

	if texture == null:
		var missing_label := _label(
			"图像资源不可用：%s" % image_path,
			14,
			C_MUTED,
			false
		)
		missing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		missing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		frame_margin.add_child(missing_label)

		push_warning(
			"CaseNodeView: image resource not found or invalid: "
			+ image_path
		)

		return container

	var texture_rect := TextureRect.new()
	texture_rect.texture = texture
	texture_rect.custom_minimum_size.y = IMAGE_CARD_HEIGHT - 20
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_margin.add_child(texture_rect)

	return container


func _render_body(node_data: Dictionary) -> void:
	node_body_label.clear()

	var body: Variant = node_data.get(
		"body",
		[]
	)

	if body is Array:
		for index in range(body.size()):
			node_body_label.append_text(
				str(body[index])
			)

			if index < body.size() - 1:
				node_body_label.append_text("\n\n")
	else:
		node_body_label.append_text(str(body))


func _render_choices(node_data: Dictionary) -> void:
	_clear_children(choices_box)

	var choices: Variant = node_data.get(
		"choices",
		[]
	)

	if not (choices is Array):
		action_hint_label.visible = false
		return

	action_hint_label.visible = not choices.is_empty()

	for choice in choices:
		if choice is Dictionary:
			choices_box.add_child(
				_choice_button(choice)
			)


func _render_right_panel(
	node_data: Dictionary,
	title_text: String
) -> void:
	current_id_value.text = str(
		node_data.get("node_id", "")
	)

	current_title_value.text = title_text

	current_type_value.text = str(
		node_data.get("node_type", "")
	)

	current_location_value.text = str(
		node_data.get("location", "")
	)

	current_time_value.text = str(
		node_data.get("time_label", "")
	)

	_clear_children(related_clues_list)

	_add_list_values(
		related_clues_list,
		node_data.get("text_clues", []),
		"TXT"
	)

	_add_list_values(
		related_clues_list,
		node_data.get("audio_clues", []),
		"AUD"
	)

	var image_items: Array = _collect_image_items(node_data)

	for image_item in image_items:
		if not (image_item is Dictionary):
			continue

		var image_id: String = str(
			image_item.get("id", "")
		)

		var image_title: String = str(
			image_item.get(
				"title",
				"图像线索"
			)
		)

		var display_text: String = image_title

		if image_id != "":
			display_text = "%s · %s" % [
				image_id,
				image_title
			]

		related_clues_list.add_child(
			_evidence_row(
				"IMG",
				display_text
			)
		)

	if related_clues_list.get_child_count() == 0:
		related_clues_list.add_child(
			_muted_value("暂无关联线索")
		)

	_clear_children(graph_tag_list)
	_add_graph_tags(node_data)

	property_characters_value.text = _join_array(
		node_data.get("characters", [])
	)

	property_rooms_value.text = _join_array(
		node_data.get("room_refs", [])
	)

	var autosave_text: String = (
		"安全节点"
		if bool(node_data.get("autosave", false))
		else "非安全节点"
	)

	var safe_node_id: String = (
		runtime_state.last_safe_autosave_node_id
	)

	if safe_node_id == "":
		safe_node_id = "无"

	property_autosave_value.text = "%s\n最近安全节点：%s" % [
		autosave_text,
		safe_node_id
	]


func _choice_button(choice: Dictionary) -> Button:
	var button := Button.new()

	var action: String = str(
		choice.get("action", "")
	)

	var target_node_id: String = (
		_get_choice_target_node_id(choice)
	)

	var title: String = str(
		choice.get(
			"title",
			"未命名选择"
		)
	)

	if action == "play_audio" and title == "":
		title = "播放备份录音（占位）"

	button.text = "  %s                                      ›" % title
	button.custom_minimum_size.y = 58
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	button.add_theme_font_size_override(
		"font_size",
		16
	)

	button.add_theme_color_override(
		"font_color",
		C_BLUE
	)

	button.add_theme_color_override(
		"font_hover_color",
		C_BLUE_DARK
	)

	button.add_theme_color_override(
		"font_pressed_color",
		C_WHITE
	)

	button.add_theme_color_override(
		"font_disabled_color",
		C_MUTED
	)

	button.add_theme_stylebox_override(
		"normal",
		_style_box(C_PANEL, C_BLUE, 1, 5)
	)

	button.add_theme_stylebox_override(
		"hover",
		_style_box(C_BLUE_SOFT, C_BLUE, 1, 5)
	)

	button.add_theme_stylebox_override(
		"pressed",
		_style_box(C_BLUE, C_BLUE_DARK, 1, 5)
	)

	button.add_theme_stylebox_override(
		"disabled",
		_style_box(C_PANEL, C_DIVIDER, 1, 5)
	)

	if action == "play_audio":
		button.text = "  播放备份录音（占位）"
		button.disabled = true

	elif action == "load_last_safe_autosave":
		button.pressed.connect(
			func() -> void:
				if runtime_state.last_safe_autosave_node_id != "":
					_show_node(
						runtime_state.last_safe_autosave_node_id
					)
		)

	elif target_node_id != "":
		button.pressed.connect(
			func() -> void:
				_show_node(target_node_id)
		)

	else:
		button.disabled = true

	return button


func _get_choice_target_node_id(
	choice: Dictionary
) -> String:
	if choice.has("to"):
		return str(
			choice.get("to", "")
		)

	return str(
		choice.get("target_node_id", "")
	)


func _dossier_table_row(
	parent: VBoxContainer,
	title: String
) -> Label:
	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 16)
	row_margin.add_theme_constant_override("margin_right", 16)
	row_margin.add_theme_constant_override("margin_top", 11)
	row_margin.add_theme_constant_override("margin_bottom", 11)
	parent.add_child(row_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row_margin.add_child(row)

	var title_label := _label(
		title,
		13,
		C_SUBTEXT,
		false
	)
	title_label.custom_minimum_size.x = 96
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(title_label)

	var value_label := _label(
		"",
		14,
		C_BLUE,
		true
	)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value_label)

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override(
		"separator",
		_style_box(C_DIVIDER, C_DIVIDER, 1, 0)
	)
	parent.add_child(divider)

	return value_label


func _add_list_values(
	parent: VBoxContainer,
	value: Variant,
	prefix: String
) -> void:
	if not (value is Array):
		return

	for item in value:
		parent.add_child(
			_evidence_row(
				prefix,
				str(item)
			)
		)


func _evidence_row(
	prefix: String,
	text: String
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 48
	card.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL, C_LINE, 1, 5)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var prefix_label := _label(
		prefix,
		11,
		C_BLUE,
		true
	)
	prefix_label.custom_minimum_size = Vector2(38, 24)
	prefix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prefix_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prefix_label.add_theme_stylebox_override(
		"normal",
		_style_box(C_BLUE_SOFT, C_LINE, 1, 4)
	)
	row.add_child(prefix_label)

	var value_label := _label(
		text,
		13,
		C_TEXT,
		true
	)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value_label)

	var arrow := _label(
		"›",
		19,
		C_BLUE,
		true
	)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)

	return card


func _add_graph_tags(node_data: Dictionary) -> void:
	var items: Array = []

	_append_array_values(
		items,
		node_data.get("characters", [])
	)

	_append_array_values(
		items,
		node_data.get("room_refs", [])
	)

	_append_array_values(
		items,
		node_data.get("audio_clues", [])
	)

	var image_items: Array = _collect_image_items(node_data)

	for image_item in image_items:
		if image_item is Dictionary:
			var image_id: String = str(
				image_item.get("id", "")
			)

			if image_id != "":
				items.append(image_id)

	var limit: int = min(items.size(), 8)

	for index in range(limit):
		graph_tag_list.add_child(
			_tag_label(
				str(items[index]),
				C_PANEL_SOFT,
				C_BLUE
			)
		)

	if graph_tag_list.get_child_count() == 0:
		graph_tag_list.add_child(
			_tag_label(
				"无",
				C_PANEL_SOFT,
				C_MUTED
			)
		)


func _join_array(value: Variant) -> String:
	var items: Array = []

	_append_array_values(
		items,
		value
	)

	return _join_strings(items)


func _append_array_values(
	items: Array,
	value: Variant
) -> void:
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


func _nav_button(
	text: String,
	active: bool
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(104, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not active

	button.add_theme_font_size_override(
		"font_size",
		15
	)

	button.add_theme_color_override(
		"font_color",
		C_WHITE if active else C_BLUE
	)

	button.add_theme_color_override(
		"font_disabled_color",
		C_BLUE
	)

	button.add_theme_stylebox_override(
		"normal",
		_style_box(
			C_BLUE if active else C_PANEL,
			C_BLUE,
			1,
			4
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		_style_box(
			C_BLUE_SOFT,
			C_BLUE,
			1,
			4
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		_style_box(
			C_BLUE_DARK,
			C_BLUE_DARK,
			1,
			4
		)
	)

	button.add_theme_stylebox_override(
		"disabled",
		_style_box(
			C_PANEL,
			C_LINE,
			1,
			4
		)
	)

	return button


func _compact_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(66, 30)
	button.focus_mode = Control.FOCUS_NONE

	button.add_theme_font_size_override(
		"font_size",
		13
	)

	button.add_theme_color_override(
		"font_color",
		C_BLUE
	)

	button.add_theme_stylebox_override(
		"normal",
		_style_box(C_PANEL, C_BLUE, 1, 4)
	)

	button.add_theme_stylebox_override(
		"hover",
		_style_box(C_BLUE_SOFT, C_BLUE, 1, 4)
	)

	button.add_theme_stylebox_override(
		"pressed",
		_style_box(C_BLUE, C_BLUE_DARK, 1, 4)
	)

	return button


func _round_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(38, 38)
	button.focus_mode = Control.FOCUS_NONE

	button.add_theme_font_size_override(
		"font_size",
		15
	)

	button.add_theme_color_override(
		"font_color",
		C_WHITE
	)

	button.add_theme_stylebox_override(
		"normal",
		_style_box(C_BLUE, C_BLUE, 1, 19)
	)

	button.add_theme_stylebox_override(
		"hover",
		_style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 19)
	)

	button.add_theme_stylebox_override(
		"pressed",
		_style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 19)
	)

	return button


func _tag_label(
	text: String,
	bg_color: Color,
	text_color: Color
) -> Label:
	var label := _label(
		text,
		13,
		text_color,
		true
	)

	label.custom_minimum_size = Vector2(0, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_stylebox_override(
		"normal",
		_style_box(bg_color, C_LINE, 1, 4)
	)

	return label


func _section_heading(text: String) -> Label:
	var label := _label(
		text,
		15,
		C_BLUE,
		true
	)

	return label


func _small_caps_label(text: String) -> Label:
	return _label(
		text,
		13,
		C_MUTED,
		true
	)


func _muted_value(text: String) -> Label:
	var label := _label(
		text,
		13,
		C_MUTED,
		false
	)

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(
	text: String,
	font_size: int,
	color: Color,
	bold: bool
) -> Label:
	var label := Label.new()
	label.text = text

	label.add_theme_font_size_override(
		"font_size",
		font_size
	)

	label.add_theme_color_override(
		"font_color",
		color
	)

	if bold:
		label.add_theme_constant_override(
			"outline_size",
			0
		)

	return label


func _divider() -> HSeparator:
	var divider := HSeparator.new()

	divider.add_theme_stylebox_override(
		"separator",
		_style_box(
			C_DIVIDER,
			C_DIVIDER,
			1,
			0
		)
	)

	return divider


func _style_box(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()

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


func _dock_top(
	control: Control,
	height: int
) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 0.0

	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = height


func _dock_left(
	control: Control,
	width: int,
	top: int
) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 1.0

	control.offset_left = 0
	control.offset_top = top
	control.offset_right = width
	control.offset_bottom = 0


func _dock_right(
	control: Control,
	width: int,
	top: int
) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0

	control.offset_left = -width
	control.offset_top = top
	control.offset_right = 0
	control.offset_bottom = 0


func _dock_center(
	control: Control,
	left: int,
	right: int,
	top: int
) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0

	control.offset_left = left
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = 0