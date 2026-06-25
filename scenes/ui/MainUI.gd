extends Control

const MIN_WINDOW_SIZE := Vector2i(1280, 720)

const TOP_BAR_HEIGHT := 72
const SIDE_PANEL_WIDTH := 400
const LEFT_PANEL_WIDTH := 400
const RIGHT_PANEL_WIDTH := 400

const STORY_CONTENT_WIDTH := 920

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

var target_text_label: Label
var keyword_grid: GridContainer
var keyword_count_label: Label
var progress_percent_label: Label
var progress_bar: ProgressBar
var read_nodes_value_label: Label
var chapter_explore_value_label: Label

var node_type_label: PanelContainer
var story_title_label: Label
var story_scroll: ScrollContainer
var story_body_label: RichTextLabel
var quote_label: Label
var choice_list: VBoxContainer

var current_node_title: Label
var current_node_body: Label
var clue_list: VBoxContainer
var graph_slot: VBoxContainer

var attr_type_value: Label
var attr_condition_value: Label
var attr_character_value: Label
var attr_reward_value: Label


func _ready() -> void:
	_setup_window()
	_force_self_to_viewport()
	_build_ui()
	_load_demo_node()
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

	keyword_count_label = _label("", 14, C_BLUE, FONT_MONO_REGULAR)
	box.add_child(keyword_count_label)

	box.add_child(_left_divider())
	box.add_child(_section_title("阅读进度"))

	progress_percent_label = _label("", 31, C_BLUE, FONT_SERIF_REGULAR)
	box.add_child(progress_percent_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(300, 6)
	progress_bar.max_value = 100
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _style_box(Color("#E4E9F6"), Color.TRANSPARENT, 0, 3))
	progress_bar.add_theme_stylebox_override("fill", _style_box(C_BLUE, Color.TRANSPARENT, 0, 3))
	box.add_child(progress_bar)

	box.add_child(_stat_row_with_ref("已阅读节点", "read_nodes"))
	box.add_child(_stat_row_with_ref("本章探索度", "chapter_explore"))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var link := _label("查看章节进度 →", 14, C_BLUE, FONT_SERIF_REGULAR)
	link.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(link)

	return panel


func _build_center_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CenterPanel"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, Color.TRANSPARENT, 0, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CENTER_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", CENTER_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", CENTER_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", CENTER_MARGIN_BOTTOM)
	panel.add_child(margin)

	story_scroll = ScrollContainer.new()
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(story_scroll)

	var story_center := CenterContainer.new()
	story_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.add_child(story_center)

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

	var quote_panel := PanelContainer.new()
	quote_panel.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, 58)
	quote_panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 3))
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

	var choice_title := _label("请选择你的行动", 14, C_MUTED, FONT_SERIF_REGULAR)
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(choice_title)

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

	title_row.add_child(_small_framed_label("已读", Vector2(46, 23), 13, C_BLUE, Color.TRANSPARENT, C_BLUE, 1, 2, FONT_SERIF_REGULAR))

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
	box.add_child(_attr_row("探索条件", "condition"))
	box.add_child(_attr_row("相关角色", "character"))
	box.add_child(_attr_row("探索奖励", "reward"))

	return panel


func _load_demo_node() -> void:
	var ok: bool = StoryManager.load_story(
		"res://data/story/chapter_01.json",
		"res://data/clues/clues.json"
	)

	if not ok:
		push_error("MainUI: failed to load story data.")
		return

	_render_node(StoryManager.get_render_data())


func _render_node(data: Dictionary) -> void:
	chapter_small_label.text = str(data.get("chapter", ""))

	chapter_dropdown.clear()

	var time_options_raw = data.get("time_options", [])

	if time_options_raw is Array:
		for item in time_options_raw:
			chapter_dropdown.add_item(str(item))

	if chapter_dropdown.item_count > 0:
		chapter_dropdown.selected = int(clamp(int(data.get("time_index", 0)), 0, chapter_dropdown.item_count - 1))

	chapter_intro_label.text = str(data.get("chapter_intro", ""))
	target_text_label.text = str(data.get("target", ""))

	_clear_children(keyword_grid)

	var keywords: Array = []
	var raw_keywords = data.get("keywords", [])

	if raw_keywords is Array:
		keywords = raw_keywords

	for word in keywords:
		keyword_grid.add_child(_keyword_tag(str(word)))

	keyword_count_label.text = "（%d / %d）" % [
		int(data.get("keyword_found", keywords.size())),
		int(data.get("keyword_total", keywords.size()))
	]

	var progress: int = int(data.get("progress", 0))
	progress_percent_label.text = "%d%%" % progress
	progress_bar.value = progress

	read_nodes_value_label.text = str(data.get("read_nodes", "0 / 0"))
	chapter_explore_value_label.text = str(data.get("chapter_explore", "0%"))

	_set_framed_label_text(node_type_label, str(data.get("node_type", "")))
	story_title_label.text = str(data.get("title", ""))

	story_body_label.clear()

	var body: Array = []
	var raw_body = data.get("body", [])

	if raw_body is Array:
		body = raw_body

	for i in range(body.size()):
		story_body_label.append_text(str(body[i]))

		if i < body.size() - 1:
			story_body_label.append_text("\n\n")

	quote_label.text = str(data.get("quote", ""))

	_clear_children(choice_list)

	var choices = data.get("choices", [])

	if choices is Array:
		for choice in choices:
			if not (choice is Dictionary):
				continue

			choice_list.add_child(_choice_button(
				_icon_by_name(str(choice.get("icon", "search"))),
				str(choice.get("title", "")),
				str(choice.get("desc", ""))
			))

	current_node_title.text = str(data.get("title", ""))
	current_node_body.text = str(data.get("current_summary", ""))

	_clear_children(clue_list)

	var clues = data.get("clues", [])

	if clues is Array:
		for clue in clues:
			if not (clue is Dictionary):
				continue

			clue_list.add_child(_clue_item(
				_icon_by_name(str(clue.get("icon", "search"))),
				str(clue.get("title", "")),
				str(clue.get("desc", ""))
			))

	_clear_children(graph_slot)

	var graph_data: Dictionary = {}
	var raw_graph = data.get("graph", {})

	if raw_graph is Dictionary:
		graph_data = raw_graph

	graph_slot.add_child(_mini_graph(graph_data))

	var attrs: Dictionary = {}
	var raw_attrs = data.get("attrs", {})

	if raw_attrs is Dictionary:
		attrs = raw_attrs

	attr_type_value.text = str(attrs.get("type", "—"))
	attr_condition_value.text = str(attrs.get("condition", "—"))
	attr_character_value.text = str(attrs.get("character", "—"))
	attr_reward_value.text = str(attrs.get("reward", "—"))

	call_deferred("_apply_story_scrollbar_style")


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


func _choice_button(texture: Texture2D, title: String, desc: String) -> Control:
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
		_on_choice_pressed(title)
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

	var edges = graph_data.get("edges", [])

	if edges is Array:
		for edge in edges:
			if edge is Array and edge.size() >= 2:
				graph.add_child(_line(edge[0], edge[1], C_LINE, 1))

	var nodes = graph_data.get("nodes", [])

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


func _graph_node(text: String, pos, active: bool) -> Control:
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


func _line(from_pos, to_pos, color: Color, width: int) -> ColorRect:
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
		"condition":
			attr_condition_value = r
		"character":
			attr_character_value = r
		"reward":
			attr_reward_value = r

	return row


func _stat_row_with_ref(left: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_label(left, 15, C_BLUE, FONT_SERIF_REGULAR))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var r := _label("", 15, C_BLUE, FONT_SERIF_REGULAR)
	row.add_child(r)

	match key:
		"read_nodes":
			read_nodes_value_label = r
		"chapter_explore":
			chapter_explore_value_label = r

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

	bar.custom_minimum_size = Vector2(8, 0)
	bar.add_theme_stylebox_override("scroll", _style_box(Color("#E4E9F6"), Color.TRANSPARENT, 0, 3))
	bar.add_theme_stylebox_override("grabber", _style_box(C_BLUE, C_BLUE, 0, 3))
	bar.add_theme_stylebox_override("grabber_highlight", _style_box(C_BLUE_DARK, C_BLUE_DARK, 0, 3))
	bar.add_theme_stylebox_override("grabber_pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 0, 3))


func _on_choice_pressed(choice_title: String) -> void:
	var ok: bool = StoryManager.choose_by_title(choice_title)

	if not ok:
		push_warning("MainUI: choice failed: " + choice_title)
		return

	_render_node(StoryManager.get_render_data())


func _change_scene_if_exists(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("MainUI: scene not found: " + scene_path)
		return

	get_tree().change_scene_to_file(scene_path)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
