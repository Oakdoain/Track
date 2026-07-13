extends Control

const AudioWaveformPlaceholder := preload("res://scripts/case/AudioWaveformPlaceholder.gd")

const MIN_WINDOW_SIZE := Vector2i(1280, 720)

const TOP_BAR_HEIGHT := 72
const SIDE_PANEL_WIDTH := 400
const LEFT_PANEL_WIDTH := 400
const RIGHT_PANEL_WIDTH := 400

const STORY_CONTENT_WIDTH := 920
const IMAGE_CARD_HEIGHT := 540

const TOP_BAR_MARGIN_LEFT := 24
const TOP_BAR_MARGIN_RIGHT := 24
const TOP_BAR_MARGIN_TOP := 8
const TOP_BAR_MARGIN_BOTTOM := 8

const SIDE_MARGIN_LEFT := 28
const SIDE_MARGIN_RIGHT := 28
const SIDE_MARGIN_TOP := 28
const SIDE_MARGIN_BOTTOM := 24

const CENTER_MARGIN_LEFT := 32
const CENTER_MARGIN_RIGHT := 32
const CENTER_MARGIN_TOP := 28
const CENTER_MARGIN_BOTTOM := 24

const C_BG := Color("#F7F9FF")
const C_PANEL_SOFT := Color("#EEF3FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_BLUE_ACTIVE := Color("#1044B2")
const C_LINE := Color("#99ABE6")
const C_DIVIDER := Color("#D7DEF3")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_MUTED := Color("#8995B8")
const C_WHITE := Color("#FFFFFF")

const FONT_PUBLIC_REGULAR := preload("res://assets/fonts/PublicSans-Regular.ttf")
const FONT_MONO_REGULAR := preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const FONT_MONO_MEDIUM := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const FONT_SERIF_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")

const ICON_STEP_BACK := preload("res://assets/icons/lucide/step-back.svg")
const ICON_BOOK_OPEN := preload("res://assets/icons/lucide/book-open.svg")
const ICON_GIT_BRANCH := preload("res://assets/icons/lucide/git-branch.svg")
const ICON_SAVE := preload("res://assets/icons/lucide/save.svg")
const ICON_FOLDER_OPEN := preload("res://assets/icons/lucide/folder-open.svg")
const ICON_SETTINGS := preload("res://assets/icons/lucide/settings.svg")

const ICON_SEARCH := preload("res://assets/icons/lucide/search.svg")
const ICON_ARCHIVE := preload("res://assets/icons/lucide/archive.svg")
const ICON_KEY_ROUND := preload("res://assets/icons/lucide/key-round.svg")
const ICON_RECTANGLE_HORIZONTAL := preload("res://assets/icons/lucide/rectangle-horizontal.svg")
const ICON_FOOTPRINTS := preload("res://assets/icons/lucide/footprints.svg")
const ICON_BOOKMARK := preload("res://assets/icons/lucide/bookmark.svg")
const ICON_REFRESH_CW := preload("res://assets/icons/lucide/refresh-cw.svg")

var _last_viewport_size: Vector2 = Vector2.ZERO

var root: Control
var bg: ColorRect

var chapter_small_label: Label
var chapter_dropdown: OptionButton
var chapter_intro_label: Label

var loader: CaseDataLoader
var runtime_state: CaseRuntimeState

var target_text_label: Label
var keyword_grid: GridContainer

var node_type_label: PanelContainer
var story_title_label: Label
var story_scroll: ScrollContainer
var audio_slot: VBoxContainer
var image_slot: VBoxContainer
var story_body_label: RichTextLabel
var quote_panel: PanelContainer
var quote_label: Label
var choice_title_label: Label
var choice_list: VBoxContainer

var current_node_title: Label
var current_node_body: Label
var clue_list: VBoxContainer
var graph_slot: VBoxContainer

var attr_type_value: Label
var attr_location_value: Label
var attr_character_value: Label
var attr_autosave_value: Label


func _ready() -> void:
	_setup_window()
	_force_self_to_viewport()

	loader = CaseDataLoader.new()
	runtime_state = CaseRuntimeState.new()

	_build_ui()
	_load_case()
	call_deferred("_force_self_to_viewport")
	call_deferred("_apply_story_scrollbar_style")


func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	if viewport_size != _last_viewport_size:
		_force_self_to_viewport()


func _setup_window() -> void:
	var window: Window = get_window()

	window.mode = Window.MODE_MAXIMIZED
	window.borderless = false
	window.unresizable = false
	window.min_size = MIN_WINDOW_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.content_scale_factor = 1.0

	get_viewport().transparent_bg = false
	RenderingServer.set_default_clear_color(C_BG)


func _force_self_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_last_viewport_size = viewport_size

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size

	if bg != null:
		_fill_rect(bg)

	if root != null:
		_fill_rect(root)


func _build_ui() -> void:
	bg = ColorRect.new()
	bg.name = "Background"
	bg.color = C_BG
	_fill_rect(bg)
	add_child(bg)

	root = Control.new()
	root.name = "Root"
	_fill_rect(root)
	add_child(root)

	var topbar: Control = _build_topbar()
	root.add_child(topbar)
	_dock_top(topbar, TOP_BAR_HEIGHT)

	var left_panel: Control = _build_left_panel()
	root.add_child(left_panel)
	_dock_left(left_panel, LEFT_PANEL_WIDTH, TOP_BAR_HEIGHT)

	var right_panel: Control = _build_right_panel()
	root.add_child(right_panel)
	_dock_right(right_panel, RIGHT_PANEL_WIDTH, TOP_BAR_HEIGHT)

	var center_panel: Control = _build_center_panel()
	root.add_child(center_panel)
	_dock_center(center_panel, LEFT_PANEL_WIDTH, RIGHT_PANEL_WIDTH, TOP_BAR_HEIGHT)


func _build_topbar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, C_BLUE, 1, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", TOP_BAR_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", TOP_BAR_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", TOP_BAR_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", TOP_BAR_MARGIN_BOTTOM)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var title_box := HBoxContainer.new()
	title_box.custom_minimum_size.x = 560
	title_box.add_theme_constant_override("separation", 16)
	row.add_child(title_box)

	var cn_title := Label.new()
	cn_title.text = "叙事图谱"
	cn_title.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	cn_title.add_theme_color_override("font_color", C_BLUE)
	cn_title.add_theme_font_size_override("font_size", 30)
	cn_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(cn_title)

	var en_title := Label.new()
	en_title.text = "Narrative Graph"
	en_title.add_theme_font_override("font", FONT_PUBLIC_REGULAR)
	en_title.add_theme_color_override("font_color", C_SUBTEXT)
	en_title.add_theme_font_size_override("font_size", 14)
	en_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(en_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_nav_button(ICON_STEP_BACK, "回溯", false))
	row.add_child(_nav_button(ICON_BOOK_OPEN, "剧情", true))
	row.add_child(_nav_button(ICON_GIT_BRANCH, "图谱", false))
	row.add_child(_nav_button(ICON_SAVE, "存档", false, "res://scenes/ui/SaveUI.tscn"))
	row.add_child(_nav_button(ICON_FOLDER_OPEN, "读取", false))
	row.add_child(_nav_button(ICON_SETTINGS, "设置", false))

	return panel


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LeftPanel"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, C_DIVIDER, 1, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", SIDE_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", SIDE_MARGIN_BOTTOM)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	chapter_small_label = _label("", 14, C_BLUE, FONT_SERIF_REGULAR)
	box.add_child(chapter_small_label)

	chapter_dropdown = _chapter_dropdown()
	box.add_child(chapter_dropdown)

	chapter_intro_label = _label("", 15, C_SUBTEXT, FONT_SERIF_REGULAR)
	chapter_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(chapter_intro_label)

	box.add_child(_left_divider())
	box.add_child(_section_title("当前目标"))

	var target := PanelContainer.new()
	target.custom_minimum_size.y = 78
	target.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	box.add_child(target)

	var target_margin := MarginContainer.new()
	target_margin.add_theme_constant_override("margin_left", 16)
	target_margin.add_theme_constant_override("margin_right", 14)
	target_margin.add_theme_constant_override("margin_top", 12)
	target_margin.add_theme_constant_override("margin_bottom", 12)
	target.add_child(target_margin)

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 12)
	target_margin.add_child(target_row)

	var target_icon := _diamond_icon(24, C_BLUE)
	target_icon.custom_minimum_size.x = 24
	target_row.add_child(target_icon)

	target_text_label = _label("", 15, C_BLUE, FONT_SERIF_SEMIBOLD)
	target_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_row.add_child(target_text_label)

	var bookmark := _icon(ICON_BOOKMARK, Vector2(20, 20), C_BLUE)
	bookmark.custom_minimum_size.x = 24
	target_row.add_child(bookmark)

	box.add_child(_left_divider())
	box.add_child(_section_title("已发现关键词"))

	keyword_grid = GridContainer.new()
	keyword_grid.columns = 3
	keyword_grid.add_theme_constant_override("h_separation", 8)
	keyword_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(keyword_grid)


	return panel


func _build_center_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CenterPanel"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, Color.TRANSPARENT, 0, 0))

	# ScrollContainer 直接占满中央区域。
	# 这样垂直滚动条会贴在中央区域最右边，而不是被正文边距推向内部。
	story_scroll = ScrollContainer.new()
	story_scroll.name = "StoryScroll"
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(story_scroll)

	# 正文边距放到 ScrollContainer 内部。
	# 内容仍保留原来的左右、上下留白，但不会影响滚动条位置。
	var margin := MarginContainer.new()
	margin.name = "StoryScrollMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", CENTER_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", CENTER_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", CENTER_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", CENTER_MARGIN_BOTTOM)
	story_scroll.add_child(margin)

	var story_center := CenterContainer.new()
	story_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(story_center)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size.x = STORY_CONTENT_WIDTH
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", 16)
	story_center.add_child(outer)

	node_type_label = _small_framed_label("", Vector2(108, 30), 14, C_BLUE, Color.TRANSPARENT, C_BLUE, 1, 3, FONT_SERIF_REGULAR)

	var node_type_wrap := HBoxContainer.new()
	node_type_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	node_type_wrap.add_child(node_type_label)
	outer.add_child(node_type_wrap)

	story_title_label = _label("", 40, C_BLUE, FONT_SERIF_SEMIBOLD)
	story_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(story_title_label)

	var ornament := _label("───────────────  ◇  ───────────────", 15, C_BLUE, FONT_SERIF_REGULAR)
	ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(ornament)

	audio_slot = VBoxContainer.new()
	audio_slot.add_theme_constant_override("separation", 12)
	outer.add_child(audio_slot)

	image_slot = VBoxContainer.new()
	image_slot.add_theme_constant_override("separation", 12)
	outer.add_child(image_slot)

	story_body_label = RichTextLabel.new()
	story_body_label.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, 0)
	story_body_label.fit_content = true
	story_body_label.bbcode_enabled = true
	story_body_label.scroll_active = false
	story_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_body_label.add_theme_font_override("normal_font", FONT_SERIF_REGULAR)
	story_body_label.add_theme_font_override("bold_font", FONT_SERIF_SEMIBOLD)
	story_body_label.add_theme_color_override("default_color", C_TEXT)
	story_body_label.add_theme_font_size_override("normal_font_size", 18)
	story_body_label.add_theme_constant_override("line_separation", 4)
	outer.add_child(story_body_label)

	quote_panel = PanelContainer.new()
	quote_panel.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, 58)
	quote_panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 3))
	quote_panel.visible = false
	outer.add_child(quote_panel)

	var quote_margin := MarginContainer.new()
	quote_margin.add_theme_constant_override("margin_left", 28)
	quote_margin.add_theme_constant_override("margin_right", 28)
	quote_panel.add_child(quote_margin)

	quote_label = Label.new()
	quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quote_label.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	quote_label.add_theme_color_override("font_color", C_BLUE)
	quote_label.add_theme_font_size_override("font_size", 17)
	quote_margin.add_child(quote_label)

	choice_title_label = _label("请选择你的行动", 14, C_MUTED, FONT_SERIF_REGULAR)
	choice_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(choice_title_label)

	choice_list = VBoxContainer.new()
	choice_list.add_theme_constant_override("separation", 10)
	outer.add_child(choice_list)

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size.y = 32
	outer.add_child(bottom_spacer)

	return panel


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RightPanel"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, C_DIVIDER, 1, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", SIDE_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", SIDE_MARGIN_BOTTOM)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 11)
	margin.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)

	head.add_child(_label("当前节点", 15, C_BLUE, FONT_SERIF_REGULAR))

	var head_spacer := Control.new()
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_spacer)

	head.add_child(_icon(ICON_REFRESH_CW, Vector2(18, 18), C_BLUE))

	var current_card := PanelContainer.new()
	current_card.custom_minimum_size.y = 138
	current_card.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 3))
	box.add_child(current_card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 0)
	current_card.add_child(card_box)

	var title_area := PanelContainer.new()
	title_area.custom_minimum_size.y = 40
	title_area.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 0))
	card_box.add_child(title_area)

	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 14)
	title_margin.add_theme_constant_override("margin_right", 12)
	title_margin.add_theme_constant_override("margin_top", 6)
	title_margin.add_theme_constant_override("margin_bottom", 6)
	title_area.add_child(title_margin)

	var title_row := HBoxContainer.new()
	title_margin.add_child(title_row)

	current_node_title = _label("", 22, C_BLUE, FONT_SERIF_SEMIBOLD)
	current_node_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(current_node_title)

	var title_spacer := Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)

	title_row.add_child(_small_framed_label("当前", Vector2(46, 23), 13, C_BLUE, Color.TRANSPARENT, C_BLUE, 1, 2, FONT_SERIF_REGULAR))

	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 14)
	body_margin.add_theme_constant_override("margin_right", 14)
	body_margin.add_theme_constant_override("margin_top", 9)
	body_margin.add_theme_constant_override("margin_bottom", 10)
	card_box.add_child(body_margin)

	current_node_body = _label("", 15, C_SUBTEXT, FONT_SERIF_REGULAR)
	current_node_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_margin.add_child(current_node_body)

	box.add_child(_section_title("相关线索"))

	clue_list = VBoxContainer.new()
	clue_list.add_theme_constant_override("separation", 8)
	box.add_child(clue_list)

	var all := _label("查看全部线索 →", 14, C_BLUE, FONT_SERIF_REGULAR)
	all.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(all)

	box.add_child(_right_divider())
	box.add_child(_section_title("关联节点"))

	graph_slot = VBoxContainer.new()
	box.add_child(graph_slot)

	var graph_link := _label("查看完整图谱 →", 14, C_BLUE, FONT_SERIF_REGULAR)
	box.add_child(graph_link)

	box.add_child(_right_divider())
	box.add_child(_section_title("节点属性"))

	box.add_child(_attr_row("类型", "type"))
	box.add_child(_attr_row("发生地点", "location"))
	box.add_child(_attr_row("相关角色", "character"))
	box.add_child(_attr_row("存档状态", "autosave"))

	return panel


func _load_case() -> void:
	if not loader.load_nodes():
		push_error("MainUI: failed to load control_backup nodes.json.")
		return

	var initial_node_id: String = loader.get_initial_node_id()

	if initial_node_id == "":
		push_error("MainUI: initial node id is empty.")
		return

	_show_node(initial_node_id)


func _show_node(node_id: String) -> void:
	var node_data: Dictionary = loader.get_node(node_id)

	if node_data.is_empty():
		push_warning("MainUI: node not found: " + node_id)
		return

	var autosave: bool = bool(node_data.get("autosave", false))
	runtime_state.set_current_node(node_id, autosave)
	_render_node(node_data)

	if story_scroll != null:
		story_scroll.scroll_vertical = 0


func _render_node(node_data: Dictionary) -> void:
	chapter_small_label.text = _format_case_label(str(loader.data.get("case_id", "CASE 01")))

	chapter_dropdown.clear()
	chapter_dropdown.add_item(loader.get_chapter_title())
	chapter_dropdown.selected = 0

	chapter_intro_label.text = loader.get_chapter_intro()
	target_text_label.text = loader.get_current_goal()

	_clear_children(keyword_grid)

	for keyword in loader.get_discovered_keywords():
		keyword_grid.add_child(_keyword_tag(str(keyword)))

	_set_framed_label_text(node_type_label, str(node_data.get("node_type", "事件节点")))
	story_title_label.text = str(node_data.get("title", ""))

	_render_audio_cards(node_data)
	_render_image_cards(node_data)
	_render_story_body(node_data)
	_render_choices(node_data)
	_render_right_panel(node_data)

	call_deferred("_apply_story_scrollbar_style")


func _render_story_body(node_data: Dictionary) -> void:
	story_body_label.clear()

	var body: Variant = node_data.get("body", [])

	if body is Array:
		for index in range(body.size()):
			story_body_label.append_text(str(body[index]))

			if index < body.size() - 1:
				story_body_label.append_text("\n\n")
	else:
		story_body_label.append_text(str(body))

	var quote_text: String = str(node_data.get("quote", ""))
	quote_panel.visible = quote_text != ""
	quote_label.text = quote_text


func _render_choices(node_data: Dictionary) -> void:
	_clear_children(choice_list)

	var choices: Variant = node_data.get("choices", [])
	var has_choices: bool = choices is Array and not choices.is_empty()
	choice_title_label.visible = has_choices

	if not (choices is Array):
		return

	for choice in choices:
		if not (choice is Dictionary):
			continue

		var title: String = str(choice.get("title", "未命名选择"))
		var description: String = _choice_description(choice)
		var icon_name: String = _choice_icon_name(choice)

		choice_list.add_child(_choice_button(
			_icon_by_name(icon_name),
			title,
			description,
			choice
		))


func _render_right_panel(node_data: Dictionary) -> void:
	current_node_title.text = str(node_data.get("title", ""))
	current_node_body.text = _node_summary(node_data)

	_clear_children(clue_list)
	_add_clue_ids(node_data.get("text_clues", []), "TXT", ICON_BOOK_OPEN)
	_add_clue_ids(node_data.get("audio_clues", []), "AUD", ICON_ARCHIVE)

	for image_item in _collect_image_items(node_data):
		if not (image_item is Dictionary):
			continue

		clue_list.add_child(_clue_item(
			ICON_RECTANGLE_HORIZONTAL,
			str(image_item.get("title", "图像线索")),
			"IMG · %s" % str(image_item.get("id", "未编号"))
		))

	if clue_list.get_child_count() == 0:
		clue_list.add_child(_clue_item(
			ICON_SEARCH,
			"暂无关联线索",
			"当前节点没有登记线索"
		))

	_clear_children(graph_slot)
	graph_slot.add_child(_mini_graph(_build_graph_data(node_data)))

	attr_type_value.text = str(node_data.get("node_type", "—"))
	attr_location_value.text = str(node_data.get("location", "—"))
	attr_character_value.text = _join_array(node_data.get("characters", []))

	var autosave_text: String = "安全节点" if bool(node_data.get("autosave", false)) else "非安全节点"
	var safe_id: String = runtime_state.last_safe_autosave_node_id

	if safe_id == "":
		safe_id = "无"

	attr_autosave_value.text = "%s / %s" % [autosave_text, safe_id]


func _render_audio_cards(node_data: Dictionary) -> void:
	_clear_children(audio_slot)

	var audio_clues: Variant = node_data.get("audio_clues", [])
	var node_type: String = str(node_data.get("node_type", ""))
	var has_audio: bool = (audio_clues is Array and not audio_clues.is_empty()) or node_type.contains("音频")

	if not has_audio:
		return

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, 174)
	card.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	audio_slot.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	box.add_child(top_row)

	var title := _label("音频线索 / AUDIO EVIDENCE", 15, C_BLUE, FONT_SERIF_SEMIBOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	var audio_id := _label(_first_array_value(audio_clues, "未编号"), 13, C_SUBTEXT, FONT_MONO_REGULAR)
	top_row.add_child(audio_id)

	var waveform: Control = AudioWaveformPlaceholder.new()
	waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(waveform)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	box.add_child(bottom_row)

	var play_button := _audio_control_button("▶")
	play_button.disabled = true
	bottom_row.add_child(play_button)

	var time_label := _label("音频播放暂未接入", 14, C_SUBTEXT, FONT_SERIF_REGULAR)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_row.add_child(time_label)


func _render_image_cards(node_data: Dictionary) -> void:
	_clear_children(image_slot)

	for image_item in _collect_image_items(node_data):
		if image_item is Dictionary:
			image_slot.add_child(_build_image_card(image_item))


func _collect_image_items(node_data: Dictionary) -> Array:
	var result: Array = []
	var floor_plan: Variant = node_data.get("floor_plan", {})

	if floor_plan is Dictionary and not floor_plan.is_empty():
		result.append(floor_plan)

	var image_clues: Variant = node_data.get("image_clues", [])

	if image_clues is Array:
		for image_clue in image_clues:
			if image_clue is Dictionary and not image_clue.is_empty():
				result.append(image_clue)

	return result


func _build_image_card(image_data: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size.x = STORY_CONTENT_WIDTH
	container.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	container.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	header.add_child(title_box)

	title_box.add_child(_label("结构图 / FLOOR PLAN", 13, C_MUTED, FONT_PUBLIC_REGULAR))
	title_box.add_child(_label(str(image_data.get("title", "图像线索")), 18, C_BLUE, FONT_SERIF_SEMIBOLD))

	var image_id: String = str(image_data.get("id", ""))

	if image_id != "":
		header.add_child(_small_framed_label(
			image_id,
			Vector2(190, 28),
			12,
			C_BLUE,
			Color.TRANSPARENT,
			C_BLUE,
			1,
			2,
			FONT_MONO_REGULAR
		))

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, IMAGE_CARD_HEIGHT)
	frame.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 3))
	container.add_child(frame)

	var frame_margin := MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 10)
	frame_margin.add_theme_constant_override("margin_right", 10)
	frame_margin.add_theme_constant_override("margin_top", 10)
	frame_margin.add_theme_constant_override("margin_bottom", 10)
	frame.add_child(frame_margin)

	var image_path: String = str(image_data.get("image_path", ""))
	var texture: Texture2D = null

	if image_path != "" and ResourceLoader.exists(image_path):
		texture = load(image_path) as Texture2D

	if texture == null:
		var missing := _label("图像资源不可用：%s" % image_path, 14, C_MUTED, FONT_SERIF_REGULAR)
		missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		frame_margin.add_child(missing)
		push_warning("MainUI: image resource not found or invalid: " + image_path)
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


func _choice_description(choice: Dictionary) -> String:
	var explicit_desc: String = str(choice.get("desc", ""))

	if explicit_desc != "":
		return explicit_desc

	var action: String = str(choice.get("action", ""))

	if action == "play_audio":
		return "播放当前节点登记的音频线索（功能占位）"

	if action == "load_last_safe_autosave":
		return "返回进入错误或失败节点之前的最近安全节点"

	var target_id: String = _get_choice_target_node_id(choice)

	if target_id != "":
		var target_data: Dictionary = loader.get_node(target_id)

		if not target_data.is_empty():
			return "%s · %s" % [
				str(target_data.get("node_type", "剧情节点")),
				str(target_data.get("location", "未知地点"))
			]

	return "继续调查"


func _choice_icon_name(choice: Dictionary) -> String:
	var action: String = str(choice.get("action", ""))
	var title: String = str(choice.get("title", ""))

	if action == "play_audio" or title.contains("录音") or title.contains("频谱") or title.contains("回声"):
		return "archive"

	if action == "load_last_safe_autosave":
		return "book"

	if title.contains("结构图") or title.contains("通道") or title.contains("门缝") or title.contains("地面"):
		return "rect"

	if title.contains("脚步"):
		return "footprints"

	return "search"


func _get_choice_target_node_id(choice: Dictionary) -> String:
	if choice.has("to"):
		return str(choice.get("to", ""))

	return str(choice.get("target_node_id", ""))


func _node_summary(node_data: Dictionary) -> String:
	var body: Variant = node_data.get("body", [])

	if body is Array and not body.is_empty():
		return str(body[0])

	return str(body)


func _add_clue_ids(value: Variant, prefix: String, icon_texture: Texture2D) -> void:
	if not (value is Array):
		return

	for clue_id in value:
		clue_list.add_child(_clue_item(
			icon_texture,
			str(clue_id),
			prefix + " · 已登记线索"
		))


func _build_graph_data(node_data: Dictionary) -> Dictionary:
	var current_pos := Vector2(117, 78)
	var target_positions: Array[Vector2] = [
		Vector2(12, 22),
		Vector2(222, 22),
		Vector2(117, 145)
	]
	var graph_nodes: Array = [
		{
			"title": _short_graph_title(str(node_data.get("title", "当前节点"))),
			"pos": current_pos,
			"active": true
		}
	]
	var edges: Array = []
	var choices: Variant = node_data.get("choices", [])
	var target_index: int = 0

	if choices is Array:
		for choice in choices:
			if not (choice is Dictionary):
				continue

			var target_id: String = _get_choice_target_node_id(choice)

			if target_id == "" or target_index >= target_positions.size():
				continue

			var target_data: Dictionary = loader.get_node(target_id)
			var target_title: String = target_id

			if not target_data.is_empty():
				target_title = str(target_data.get("title", target_id))

			var target_pos: Vector2 = target_positions[target_index]
			graph_nodes.append({
				"title": _short_graph_title(target_title),
				"pos": target_pos,
				"active": false
			})
			edges.append([current_pos + Vector2(48, 11), target_pos + Vector2(48, 11)])
			target_index += 1

	return {
		"nodes": graph_nodes,
		"edges": edges
	}


func _short_graph_title(text: String) -> String:
	if text.length() <= 8:
		return text

	return text.substr(0, 7) + "…"


func _join_array(value: Variant) -> String:
	if not (value is Array) or value.is_empty():
		return "无"

	var parts := PackedStringArray()

	for item in value:
		parts.append(str(item))

	return " / ".join(parts)


func _format_case_label(case_id: String) -> String:
	if case_id == "":
		return "CASE 01"

	return case_id.replace("_", " ").to_upper()


func _first_array_value(value: Variant, fallback: String) -> String:
	if value is Array and not value.is_empty():
		return str(value[0])

	return fallback


func _audio_control_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(38, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT_MONO_MEDIUM)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", C_WHITE)
	button.add_theme_color_override("font_disabled_color", C_WHITE)
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE, C_BLUE, 1, 19))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 19))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 19))
	button.add_theme_stylebox_override("disabled", _style_box(C_BLUE, C_BLUE, 1, 19))
	return button


func _chapter_dropdown() -> OptionButton:
	var btn := OptionButton.new()
	btn.custom_minimum_size = Vector2(310, 38)
	btn.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	btn.add_theme_font_size_override("font_size", 29)
	btn.add_theme_color_override("font_color", C_BLUE)
	btn.add_theme_stylebox_override("normal", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	btn.add_theme_stylebox_override("hover", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	btn.add_theme_stylebox_override("pressed", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	btn.add_theme_stylebox_override("focus", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))

	var popup := btn.get_popup()
	popup.add_theme_font_override("font", FONT_SERIF_REGULAR)
	popup.add_theme_font_size_override("font_size", 16)

	return btn


func _nav_button(texture: Texture2D, text: String, active: bool, scene_path: String = "") -> Control:
	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(128, 50)

	var panel := PanelContainer.new()
	_fill_rect(panel)
	panel.add_theme_stylebox_override("panel", _style_box(C_BLUE_ACTIVE if active else Color.TRANSPARENT, C_BLUE_DARK if active else C_LINE, 1, 4))
	root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(margin)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 12)
	root_control.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	row.add_child(_icon(texture, Vector2(21, 21), C_WHITE if active else C_BLUE))

	var label := _label(text, 16, C_WHITE if active else C_BLUE, FONT_SERIF_SEMIBOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var hit_button := _transparent_hit_button()

	if not active:
		hit_button.mouse_entered.connect(func():
			panel.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_BLUE, 1, 4))
		)

		hit_button.mouse_exited.connect(func():
			panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 4))
		)

	if scene_path != "":
		hit_button.pressed.connect(func():
			_change_scene_if_exists(scene_path)
		)

	root_control.add_child(hit_button)
	return root_control


func _choice_button(texture: Texture2D, title: String, desc: String, choice: Dictionary) -> Control:
	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, 62)

	var panel := PanelContainer.new()
	_fill_rect(panel)
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	root_control.add_child(panel)

	var content_margin := MarginContainer.new()
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(content_margin)
	content_margin.add_theme_constant_override("margin_left", 22)
	content_margin.add_theme_constant_override("margin_right", 18)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	root_control.add_child(content_margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	content_margin.add_child(row)

	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size.x = 40
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_icon(texture, Vector2(28, 28), C_BLUE))
	row.add_child(icon_box)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)

	var title_label := _label(title, 18, C_BLUE, FONT_SERIF_SEMIBOLD)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var desc_label := _label(desc, 14, C_SUBTEXT, FONT_SERIF_REGULAR)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(desc_label)

	var arrow := _label("›", 28, C_BLUE, FONT_MONO_MEDIUM)
	arrow.custom_minimum_size.x = 24
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	var hit_button := _transparent_hit_button()

	hit_button.mouse_entered.connect(func():
		panel.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_BLUE, 1, 4))
	)

	hit_button.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	)

	hit_button.pressed.connect(func():
		_on_choice_pressed(choice)
	)

	root_control.add_child(hit_button)
	return root_control


func _clue_item(texture: Texture2D, title: String, desc: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 56
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size.x = 26
	icon_box.add_child(_icon(texture, Vector2(22, 22), C_BLUE))
	row.add_child(icon_box)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	text_box.add_child(_label(title, 16, C_BLUE, FONT_SERIF_SEMIBOLD))
	text_box.add_child(_label(desc, 13, C_SUBTEXT, FONT_SERIF_REGULAR))

	var arrow := _label("›", 24, C_BLUE, FONT_MONO_MEDIUM)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)

	return panel


func _mini_graph(graph_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 188
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 0))

	var graph := Control.new()
	graph.custom_minimum_size = Vector2(330, 188)
	panel.add_child(graph)

	var edges: Variant = graph_data.get("edges", [])

	if edges is Array:
		for edge in edges:
			if edge is Array and edge.size() >= 2:
				graph.add_child(_line(edge[0], edge[1], C_LINE, 1))

	var nodes: Variant = graph_data.get("nodes", [])

	if nodes is Array:
		for node_data in nodes:
			if not (node_data is Dictionary):
				continue

			graph.add_child(_graph_node(
				str(node_data.get("title", "")),
				node_data.get("pos", Vector2.ZERO),
				bool(node_data.get("active", false))
			))

	return panel


func _graph_node(text: String, pos: Variant, active: bool) -> Control:
	var bg_color := C_BLUE if active else Color.TRANSPARENT
	var border_color := C_BLUE_DARK if active else C_BLUE
	var text_color := C_WHITE if active else C_BLUE

	var node := _small_framed_label(text, Vector2(96, 23), 12, text_color, bg_color, border_color, 1, 2, FONT_SERIF_REGULAR)

	if pos is Vector2:
		node.position = pos
	elif pos is Array and pos.size() >= 2:
		node.position = Vector2(float(pos[0]), float(pos[1]))
	else:
		node.position = Vector2.ZERO

	return node


func _line(from_pos: Variant, to_pos: Variant, color: Color, width: int) -> ColorRect:
	var from_vec := Vector2.ZERO
	var to_vec := Vector2.ZERO

	if from_pos is Vector2:
		from_vec = from_pos
	elif from_pos is Array and from_pos.size() >= 2:
		from_vec = Vector2(float(from_pos[0]), float(from_pos[1]))

	if to_pos is Vector2:
		to_vec = to_pos
	elif to_pos is Array and to_pos.size() >= 2:
		to_vec = Vector2(float(to_pos[0]), float(to_pos[1]))

	var line := ColorRect.new()
	line.color = color

	var diff: Vector2 = to_vec - from_vec
	line.position = from_vec
	line.size = Vector2(round(diff.length()), width)
	line.rotation = diff.angle()

	return line


func _attr_row(left: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var l := _label(left, 15, C_BLUE, FONT_SERIF_REGULAR)
	row.add_child(l)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var r := _label("—", 15, C_BLUE, FONT_SERIF_REGULAR)
	row.add_child(r)

	match key:
		"type":
			attr_type_value = r
		"location":
			attr_location_value = r
		"character":
			attr_character_value = r
		"autosave":
			attr_autosave_value = r

	return row


func _keyword_tag(text: String) -> Control:
	return _small_framed_label(text, Vector2(64, 29), 14, C_BLUE, Color.TRANSPARENT, C_BLUE, 1, 2, FONT_SERIF_REGULAR)


func _icon_by_name(name: String) -> Texture2D:
	match name:
		"search":
			return ICON_SEARCH
		"book":
			return ICON_BOOK_OPEN
		"archive":
			return ICON_ARCHIVE
		"key":
			return ICON_KEY_ROUND
		"rect":
			return ICON_RECTANGLE_HORIZONTAL
		"footprints":
			return ICON_FOOTPRINTS
		_:
			return ICON_SEARCH


func _icon(texture: Texture2D, icon_size: Vector2, color: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = icon_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _diamond_icon(size_value: int, color: Color) -> Control:
	var label := _label("◇", size_value, color, FONT_MONO_MEDIUM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _small_framed_label(
	text: String,
	min_size: Vector2,
	font_size: int,
	text_color: Color,
	bg_color: Color,
	border_color: Color,
	border_width: int,
	radius: int,
	font: Font
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _style_box(bg_color, border_color, border_width, radius))

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	panel.add_child(label)

	return panel


func _set_framed_label_text(panel: PanelContainer, text: String) -> void:
	if panel.get_child_count() <= 0:
		return

	var child := panel.get_child(0)

	if child is Label:
		child.text = text


func _section_title(text: String) -> Label:
	return _label(text, 16, C_BLUE, FONT_SERIF_REGULAR)


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _left_divider() -> Control:
	var sep := HSeparator.new()
	sep.custom_minimum_size.y = 14
	sep.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	return sep


func _right_divider() -> Control:
	var sep := HSeparator.new()
	sep.custom_minimum_size.y = 8
	sep.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	return sep


func _style_box(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


func _transparent_hit_button() -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	_fill_rect(btn)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_stylebox_override("normal", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	btn.add_theme_stylebox_override("hover", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	btn.add_theme_stylebox_override("pressed", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	btn.add_theme_stylebox_override("focus", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	return btn


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


func _dock_left(control: Control, panel_width: int, top: int) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 1.0
	control.offset_left = 0
	control.offset_top = top
	control.offset_right = panel_width
	control.offset_bottom = 0


func _dock_right(control: Control, panel_width: int, top: int) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = -panel_width
	control.offset_top = top
	control.offset_right = 0
	control.offset_bottom = 0


func _dock_center(control: Control, left: int, right: int, top: int) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = 0


func _apply_story_scrollbar_style() -> void:
	if story_scroll == null:
		return

	var bar := story_scroll.get_v_scroll_bar()

	if bar == null:
		return

	# 默认保持低对比度；鼠标悬停时才切换为界面主蓝色。
	var scrollbar_track_color := Color("#EDF2FC")
	var scrollbar_idle_color := Color("#BFD0F6")

	bar.custom_minimum_size = Vector2(8, 0)
	bar.add_theme_stylebox_override(
		"scroll",
		_style_box(scrollbar_track_color, Color.TRANSPARENT, 0, 3)
	)
	bar.add_theme_stylebox_override(
		"scroll_focus",
		_style_box(scrollbar_track_color, Color.TRANSPARENT, 0, 3)
	)
	bar.add_theme_stylebox_override(
		"grabber",
		_style_box(scrollbar_idle_color, scrollbar_idle_color, 0, 3)
	)
	bar.add_theme_stylebox_override(
		"grabber_highlight",
		_style_box(C_BLUE, C_BLUE, 0, 3)
	)
	bar.add_theme_stylebox_override(
		"grabber_pressed",
		_style_box(C_BLUE_DARK, C_BLUE_DARK, 0, 3)
	)


func _on_choice_pressed(choice: Dictionary) -> void:
	var action: String = str(choice.get("action", ""))

	if action == "play_audio":
		push_warning("MainUI: audio playback is not connected in this Vertical Slice yet.")
		return

	if action == "load_last_safe_autosave":
		var safe_id: String = runtime_state.last_safe_autosave_node_id

		if safe_id != "":
			_show_node(safe_id)
		else:
			push_warning("MainUI: no safe autosave node is available.")

		return

	var target_node_id: String = _get_choice_target_node_id(choice)

	if target_node_id == "":
		push_warning("MainUI: choice has no target node: " + str(choice.get("title", "")))
		return

	_show_node(target_node_id)


func _change_scene_if_exists(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("MainUI: scene not found: " + scene_path)
		return

	get_tree().change_scene_to_file(scene_path)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
