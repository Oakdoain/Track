extends Control

signal initialization_succeeded
signal initialization_failed(message: String)
signal settings_requested(source_context: String)
signal archive_requested(preferred_case_id: String)
signal case_completion_requested(case_id: String)

const AudioWaveformPlaceholder := preload("res://scripts/case/AudioWaveformPlaceholder.gd")
const CaseGraphCanvasScript := preload("res://scripts/case/CaseGraphCanvas.gd")
const SaveUIScene := preload("res://scenes/ui/SaveUI.tscn")
const LoadUIScene := preload("res://scenes/ui/LoadUI.tscn")

const MIN_WINDOW_SIZE := Vector2i(1280, 720)

const TOP_BAR_HEIGHT := 72
const SIDE_PANEL_WIDTH := 400
const LEFT_PANEL_WIDTH := 400
const RIGHT_PANEL_WIDTH := 400

const STORY_CONTENT_WIDTH := 920
const IMAGE_CARD_HEIGHT := 540
const GRAPH_NODE_SIZE := Vector2(260, 96)
const GRAPH_CURRENT_ANCHOR := Vector2(0.5, 0.32)
const KEYWORD_GRAPH_MIN_SIZE := Vector2(150, 36)
const KEYWORD_GRAPH_MAX_WIDTH := 220.0
const KEYWORD_GRAPH_OFFSET := 20.0
const KEYWORD_GRAPH_GAP := 8.0
const GRAPH_STATUS_SIZE := Vector2(340, 76)
const CASE_STATUS_SIZE := Vector2(380, 48)
const KEYWORD_META_PREFIX := "keyword://"
const KEYWORD_POPUP_MAX_WIDTH := 220.0
const KEYWORD_POPUP_OFFSET := Vector2(16.0, 16.0)
const KEYWORD_POPUP_VIEW_MARGIN := 8.0

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
const ICON_PLAY := preload("res://assets/icons/lucide/play.svg")
const ICON_PAUSE := preload("res://assets/icons/lucide/pause.svg")

var _last_viewport_size: Vector2 = Vector2.ZERO

var root: Control
var bg: ColorRect
var left_panel: Control
var story_view: Control
var graph_view: Control
var backtrack_nav_button: Control
var story_nav_button: Control
var graph_nav_button: Control
var save_nav_button: Control
var load_nav_button: Control
var settings_nav_button: Control
var save_view: Control
var load_view: Control
var _data_page_open: bool = false
var _return_to_graph_view: bool = false
var _settings_source_context: String = ""
var _settings_previous_focus: Control

var chapter_small_label: Label
var chapter_dropdown: OptionButton
var chapter_intro_label: Label

var loader: CaseDataLoader
var runtime_state: CaseRuntimeState
var audio_manager: Node
var save_manager: SaveManager

var target_text_label: Label
var keyword_grid: HFlowContainer
var keyword_width_container: MarginContainer

var node_type_label: PanelContainer
var story_title_label: Label
var story_scroll: ScrollContainer
var audio_slot: VBoxContainer
var _audio_card_controls: Dictionary = {}
var _audio_waveform_cache: Dictionary = {}
var _audio_finished_id: String = ""
var _audio_feedback_generation: int = 0
var image_slot: VBoxContainer
var story_body_label: RichTextLabel
var quote_panel: PanelContainer
var quote_label: Label
var choice_title_label: Label
var choice_list: VBoxContainer
var keyword_popup_node: PanelContainer
var keyword_context_menu: PanelContainer
var _node_history: PackedStringArray = PackedStringArray()

var graph_scroll: ScrollContainer
var graph_canvas: CaseGraphCanvas
var graph_status_panel: PanelContainer
var graph_status_label: Label
var _selected_keyword_instance_id: String = ""
var _graph_feedback_generation: int = 0
var _keyword_graph_layout: Dictionary = {}

var current_node_title: Label
var current_node_body: Label
var clue_list: VBoxContainer
var graph_slot: VBoxContainer

var attr_type_value: Label
var attr_location_value: Label
var attr_character_value: Label
var attr_autosave_value: Label

var case_status_panel: PanelContainer
var case_status_label: Label
var _case_status_generation: int = 0
var _startup_mode: String = "direct"
var _startup_runtime_data: Dictionary = {}
var _startup_configured: bool = false
var _suppress_disk_autosave: bool = false
var _initialization_error: String = ""
var _case_descriptor: Dictionary = {}


func configure_startup(mode: String, runtime_data: Dictionary = {}) -> void:
	configure_case({}, mode, runtime_data)


func configure_case(
	case_descriptor: Dictionary,
	mode: String,
	runtime_data: Dictionary = {}
) -> void:
	if is_node_ready():
		push_warning("MainUI: configure_case must be called before the node enters the tree.")
		return

	if mode != "new_game" and mode != "loaded" and mode != "direct":
		push_warning("MainUI: unsupported startup mode; falling back to direct development mode: " + mode)
		_startup_mode = "direct"
	else:
		_startup_mode = mode

	_startup_runtime_data = runtime_data.duplicate(true)
	_case_descriptor = case_descriptor.duplicate(true)
	_startup_configured = true


func _ready() -> void:
	_setup_window()
	_force_self_to_viewport()

	loader = CaseDataLoader.new()
	runtime_state = CaseRuntimeState.new()

	if _case_descriptor.is_empty():
		if loader.load_registry():
			_case_descriptor = loader.get_case_descriptor("case_01")

	if _case_descriptor.is_empty():
		_initialization_error = "开发模式默认案件不可用"
		initialization_failed.emit(_initialization_error)
		return

	var case_id: String = str(_case_descriptor.get("case_id", ""))
	var slice_id: String = str(_case_descriptor.get("slice_id", ""))

	if not loader.load_case(case_id, slice_id):
		_initialization_error = "案件数据加载失败"
		initialization_failed.emit(_initialization_error)
		return

	save_manager = SaveManager.new(case_id, slice_id)
	var save_init_result: Dictionary = save_manager.initialize()

	if not bool(save_init_result.get("success", false)):
		push_warning("MainUI: save manager initialization failed: " + str(save_init_result.get("error", "")))

	_build_ui()
	_build_data_pages()
	_setup_audio_manager()
	if not _initialize_case_for_startup():
		initialization_failed.emit(
			_initialization_error if _initialization_error != "" else "案件初始化失败"
		)
		return

	initialization_succeeded.emit()
	call_deferred("_force_self_to_viewport")
	call_deferred("_apply_scrollbar_styles")


func _exit_tree() -> void:
	_stop_audio_for_context_change()


func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	if viewport_size != _last_viewport_size:
		_force_self_to_viewport()

	_refresh_audio_progress_display()


func _input(event: InputEvent) -> void:
	if keyword_context_menu != null and is_instance_valid(keyword_context_menu):
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton

			if (
				mouse_event.pressed
				and mouse_event.button_index == MOUSE_BUTTON_LEFT
				and not keyword_context_menu.get_global_rect().has_point(mouse_event.global_position)
			):
				_close_keyword_context_menu()

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if (
			key_event.keycode == KEY_ESCAPE
			and key_event.pressed
			and not key_event.echo
			and keyword_context_menu != null
		):
			_close_keyword_context_menu()
			get_viewport().set_input_as_handled()
			return

		if (
			key_event.keycode == KEY_ESCAPE
			and key_event.pressed
			and not key_event.echo
			and _selected_keyword_instance_id != ""
		):
			_cancel_keyword_connection_selection(true)
			get_viewport().set_input_as_handled()

		return


func _setup_window() -> void:
	var window: Window = get_window()

	if not _startup_configured:
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

	if case_status_panel != null:
		case_status_panel.position = Vector2(
			maxf(16.0, (viewport_size.x - CASE_STATUS_SIZE.x) * 0.5),
			TOP_BAR_HEIGHT + 16.0
		)


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

	left_panel = _build_left_panel()
	root.add_child(left_panel)
	_dock_left(left_panel, LEFT_PANEL_WIDTH, TOP_BAR_HEIGHT)

	var right_panel: Control = _build_right_panel()
	root.add_child(right_panel)
	_dock_right(right_panel, RIGHT_PANEL_WIDTH, TOP_BAR_HEIGHT)

	var center_panel: Control = _build_center_panel()
	root.add_child(center_panel)
	_dock_center(center_panel, LEFT_PANEL_WIDTH, RIGHT_PANEL_WIDTH, TOP_BAR_HEIGHT)

	case_status_panel = _build_case_status_panel()
	root.add_child(case_status_panel)
	_force_self_to_viewport()


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

	backtrack_nav_button = _nav_button(ICON_STEP_BACK, "回溯", false)
	row.add_child(backtrack_nav_button)
	_get_nav_hit_button(backtrack_nav_button).pressed.connect(_on_backtrack_pressed)

	story_nav_button = _nav_button(ICON_BOOK_OPEN, "剧情", true)
	row.add_child(story_nav_button)
	_get_nav_hit_button(story_nav_button).pressed.connect(_show_story_view)

	graph_nav_button = _nav_button(ICON_GIT_BRANCH, "图谱", false)
	row.add_child(graph_nav_button)
	_get_nav_hit_button(graph_nav_button).pressed.connect(_show_graph_view)

	save_nav_button = _nav_button(ICON_SAVE, "存档", false)
	row.add_child(save_nav_button)
	_get_nav_hit_button(save_nav_button).pressed.connect(_open_save_page)

	load_nav_button = _nav_button(ICON_FOLDER_OPEN, "读取", false)
	row.add_child(load_nav_button)
	_get_nav_hit_button(load_nav_button).pressed.connect(_open_load_page)

	settings_nav_button = _nav_button(ICON_SETTINGS, "设置", false)
	row.add_child(settings_nav_button)
	_get_nav_hit_button(settings_nav_button).pressed.connect(_open_settings_page)

	return panel


func _build_data_pages() -> void:
	save_view = SaveUIScene.instantiate() as Control
	load_view = LoadUIScene.instantiate() as Control

	if save_view == null or load_view == null:
		push_warning("MainUI: save or load page scene could not be instantiated.")
		return

	for data_view in [save_view, load_view]:
		data_view.visible = false
		data_view.z_index = 30
		data_view.anchor_left = 0.0
		data_view.anchor_top = 0.0
		data_view.anchor_right = 1.0
		data_view.anchor_bottom = 1.0
		data_view.offset_left = 0.0
		data_view.offset_top = TOP_BAR_HEIGHT
		data_view.offset_right = 0.0
		data_view.offset_bottom = 0.0
		root.add_child(data_view)
		data_view.call("configure", save_manager, _case_descriptor)

	save_view.connect("return_requested", Callable(self, "_return_from_data_page"))
	save_view.connect("save_requested", Callable(self, "_on_manual_save_requested"))
	load_view.connect("return_requested", Callable(self, "_return_from_data_page"))
	load_view.connect("load_requested", Callable(self, "_on_load_requested"))


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LeftPanel"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, C_DIVIDER, 1, 0))

	var margin := MarginContainer.new()
	keyword_width_container = margin
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", SIDE_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", SIDE_MARGIN_BOTTOM)
	margin.resized.connect(_update_keyword_tag_widths)
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

	keyword_grid = HFlowContainer.new()
	keyword_grid.add_theme_constant_override("h_separation", 6)
	keyword_grid.add_theme_constant_override("v_separation", 6)
	keyword_grid.resized.connect(_update_keyword_tag_widths)
	box.add_child(keyword_grid)


	return panel


func _build_center_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CenterPanel"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, Color.TRANSPARENT, 0, 0))

	story_view = Control.new()
	story_view.name = "StoryView"
	_fill_rect(story_view)
	panel.add_child(story_view)

	# ScrollContainer 直接占满剧情视图。
	# 这样垂直滚动条会贴在中央区域最右边，而不是被正文边距推向内部。
	story_scroll = ScrollContainer.new()
	story_scroll.name = "StoryScroll"
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_fill_rect(story_scroll)
	story_view.add_child(story_scroll)

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
	story_body_label.selection_enabled = false
	story_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_body_label.add_theme_font_override("normal_font", FONT_SERIF_REGULAR)
	story_body_label.add_theme_font_override("bold_font", FONT_SERIF_SEMIBOLD)
	story_body_label.add_theme_color_override("default_color", C_TEXT)
	story_body_label.add_theme_font_size_override("normal_font_size", 18)
	story_body_label.add_theme_constant_override("line_separation", 4)
	story_body_label.meta_clicked.connect(_on_story_keyword_meta_clicked)
	story_body_label.meta_hover_started.connect(_on_story_keyword_meta_hover_started)
	story_body_label.meta_hover_ended.connect(_on_story_keyword_meta_hover_ended)
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

	graph_view = Control.new()
	graph_view.name = "GraphView"
	graph_view.visible = false
	_fill_rect(graph_view)
	panel.add_child(graph_view)

	graph_scroll = ScrollContainer.new()
	graph_scroll.name = "GraphScroll"
	graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_fill_rect(graph_scroll)
	graph_view.add_child(graph_scroll)

	graph_canvas = CaseGraphCanvasScript.new()
	graph_canvas.name = "GraphCanvas"
	graph_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	graph_canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	graph_canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	graph_scroll.add_child(graph_canvas)

	graph_status_panel = _build_graph_status_panel()
	graph_view.add_child(graph_status_panel)

	return panel


func _build_graph_status_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "GraphStatusPanel"
	panel.visible = false
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = GRAPH_STATUS_SIZE
	panel.size = GRAPH_STATUS_SIZE
	panel.z_index = 50
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 4))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	graph_status_label = _label("", 14, C_BLUE, FONT_SERIF_SEMIBOLD)
	graph_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	graph_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(graph_status_label)
	return panel


func _build_case_status_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CaseStatusPanel"
	panel.visible = false
	panel.z_index = 110
	panel.custom_minimum_size = CASE_STATUS_SIZE
	panel.size = CASE_STATUS_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 4))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	case_status_label = _label("", 14, C_BLUE, FONT_SERIF_SEMIBOLD)
	case_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(case_status_label)
	return panel


func _setup_audio_manager() -> void:
	audio_manager = get_node_or_null("/root/AudioManager")

	if audio_manager == null:
		push_warning("MainUI: AudioManager autoload is unavailable.")
		return

	var started_callable := Callable(self, "_on_audio_started")
	var paused_callable := Callable(self, "_on_audio_paused")
	var stopped_callable := Callable(self, "_on_audio_stopped")
	var finished_callable := Callable(self, "_on_audio_finished")
	var progress_callable := Callable(self, "_on_audio_progress_changed")

	if not audio_manager.is_connected("audio_started", started_callable):
		audio_manager.connect("audio_started", started_callable)

	if not audio_manager.is_connected("audio_paused", paused_callable):
		audio_manager.connect("audio_paused", paused_callable)

	if not audio_manager.is_connected("audio_stopped", stopped_callable):
		audio_manager.connect("audio_stopped", stopped_callable)

	if not audio_manager.is_connected("audio_finished", finished_callable):
		audio_manager.connect("audio_finished", finished_callable)

	if not audio_manager.is_connected("audio_progress_changed", progress_callable):
		audio_manager.connect("audio_progress_changed", progress_callable)

	var audio_data_path: String = loader.get_audio_data_path()
	var loaded: bool = audio_data_path != "" and bool(audio_manager.call("load_audio_data", audio_data_path))

	if not loaded:
		push_warning("MainUI: case audio clue data could not be loaded.")


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


func _initialize_case_for_startup() -> bool:
	_initialization_error = ""

	var initial_node_id: String = loader.get_initial_node_id()

	if initial_node_id == "" or loader.get_node(initial_node_id).is_empty():
		push_error("MainUI: initial node is missing from the loaded case data.")
		_initialization_error = "案件起始节点不可用"
		return false

	match _startup_mode:
		"loaded":
			return _enter_with_loaded_runtime(_startup_runtime_data)
		"new_game":
			runtime_state.reset_runtime_state()
			_node_history.clear()
			_suppress_disk_autosave = false
			_show_node(initial_node_id)
			return runtime_state.current_node_id == initial_node_id
		_:
			# Running MainUI.tscn directly remains useful for development, but it
			# must not overwrite the player's disk autosave.
			runtime_state.reset_runtime_state()
			_node_history.clear()
			_suppress_disk_autosave = true
			_show_node(initial_node_id)
			return runtime_state.current_node_id == initial_node_id


func _enter_with_loaded_runtime(runtime_data: Dictionary) -> bool:
	if not runtime_state.validate_save_dictionary(runtime_data):
		_initialization_error = "存档运行状态校验失败"
		return false

	var loaded_node_id: String = str(runtime_data.get("current_node_id", ""))
	var loaded_node_data: Dictionary = loader.get_node(loaded_node_id)

	if loaded_node_data.is_empty():
		push_warning("MainUI: loaded save references a node absent from the current case.")
		_initialization_error = "存档中的案件节点不可用"
		return false

	if not runtime_state.apply_save_dictionary(runtime_data):
		_initialization_error = "应用存档运行状态失败"
		return false

	_node_history.clear()
	_stop_audio_for_context_change()
	_render_node(loaded_node_data)
	story_scroll.scroll_vertical = 0
	story_view.visible = true
	graph_view.visible = false
	_set_nav_button_active(story_nav_button, true)
	_set_nav_button_active(graph_nav_button, false)
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)
	_set_nav_button_active(settings_nav_button, false)
	return true


func _show_node(node_id: String) -> void:
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)
	_graph_feedback_generation += 1
	graph_status_panel.visible = false
	_case_status_generation += 1
	case_status_panel.visible = false

	var node_data: Dictionary = loader.get_node(node_id)

	if node_data.is_empty():
		push_warning("MainUI: node not found: " + node_id)
		return

	_record_current_node_for_history(node_id)
	_stop_audio_for_context_change()
	_apply_node_flags(node_data)
	var autosave: bool = bool(node_data.get("autosave", false))
	runtime_state.set_current_node(node_id, autosave)
	_render_node(node_data)

	if (
		_is_tutorial_case()
		and node_id == "tutorial_0003"
		and not bool(runtime_state.flags.get("backtrack_tutorial_completed", false))
	):
		_show_case_status("“回溯”会直接返回上一个剧情节点。")

	if autosave and not _suppress_disk_autosave:
		var autosave_succeeded: bool = _write_disk_autosave(node_data)

		if autosave_succeeded and _node_marks_case_completed(node_data):
			case_completion_requested.emit(loader.get_current_case_id())

	if story_scroll != null:
		story_scroll.scroll_vertical = 0


func _render_node(node_data: Dictionary) -> void:
	chapter_small_label.text = str(loader.get_case_metadata().get("code", _format_case_label(loader.get_current_case_id())))

	chapter_dropdown.clear()
	chapter_dropdown.add_item(loader.get_chapter_title())
	chapter_dropdown.selected = 0

	chapter_intro_label.text = loader.get_chapter_intro()
	target_text_label.text = _current_goal_for_node(node_data)

	_refresh_keyword_grid()

	_set_framed_label_text(node_type_label, str(node_data.get("node_type", "事件节点")))
	story_title_label.text = str(node_data.get("title", ""))

	_render_audio_cards(node_data)
	_render_image_cards(node_data)
	_render_story_body(node_data)
	_render_choices(node_data)
	_render_right_panel(node_data)
	_render_graph_view()
	_update_backtrack_button_state()

	call_deferred("_apply_scrollbar_styles")


func _refresh_current_goal() -> void:
	if target_text_label == null or runtime_state == null or loader == null:
		return

	var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)

	if not current_data.is_empty():
		target_text_label.text = _current_goal_for_node(current_data)


func _current_goal_for_node(node_data: Dictionary) -> String:
	var configured_goal: String = str(node_data.get("current_goal", loader.get_current_goal()))

	if not _is_tutorial_case():
		return configured_goal

	var node_id: String = str(node_data.get("node_id", ""))

	match node_id:
		"tutorial_0000":
			return (
				"打开训练档案。"
				if bool(runtime_state.flags.get("tutorial_audio_started", false))
				else configured_goal
			)
		"tutorial_0003":
			return (
				"检查档案当前的状态。"
				if bool(runtime_state.flags.get("backtrack_tutorial_completed", false))
				else configured_goal
			)
		"tutorial_0006":
			if not runtime_state.has_keyword("封口白痕", "tutorial_0006"):
				return configured_goal

			if not bool(runtime_state.flags.get("tutorial_keyword_intro_viewed", false)):
				return "查看关键词“封口白痕”的简介。"

			if not bool(runtime_state.flags.get("tutorial_graph_opened", false)):
				return "打开顶部的“图谱”。"

			if not bool(runtime_state.flags.get("tutorial_first_keyword_selected", false)):
				return "选择关键词“封口白痕”。"

			if not bool(runtime_state.flags.get("tutorial_seal_connection_completed", false)):
				return "将“封口白痕”连接到“封口状态异常”。"

			return "查看新解锁的调查节点。"
		"tutorial_0007":
			if bool(runtime_state.flags.get("tutorial_page_connection_completed", false)):
				return "查看复核结果。"

			if bool(runtime_state.flags.get("tutorial_returned_safe", false)):
				return "比较当前页码与封存时的文件数量。"

			if bool(runtime_state.flags.get("tutorial_invalid_connection_seen", false)):
				return "尝试判断是谁取走了缺失文件。"

			if runtime_state.has_keyword("T-00编号", "tutorial_0007"):
				return "选择关键词“T-00编号”。"

	return configured_goal


func _choice_is_available(choice: Dictionary) -> bool:
	var requirements: Variant = choice.get("requires_flags", {})

	if not (requirements is Dictionary):
		return true

	for flag_value in (requirements as Dictionary).keys():
		var flag_name: String = str(flag_value)
		var expected: bool = bool((requirements as Dictionary).get(flag_value, false))

		if bool(runtime_state.flags.get(flag_name, false)) != expected:
			return false

	return true


func _render_story_body(node_data: Dictionary) -> void:
	story_body_label.clear()
	story_body_label.tooltip_text = ""
	var source_node_id: String = str(node_data.get("node_id", runtime_state.current_node_id))
	var body_text: String = _get_story_body_text(node_data.get("body", []))
	var keyword_ranges: Array[Dictionary] = _build_story_keyword_ranges(
		source_node_id,
		body_text
	)
	var cursor: int = 0

	for keyword_range in keyword_ranges:
		var range_start: int = int(keyword_range.get("start", 0))
		var range_end: int = int(keyword_range.get("end", range_start))

		if range_start > cursor:
			story_body_label.add_text(body_text.substr(cursor, range_start - cursor))

		_append_story_keyword_segment(
			source_node_id,
			int(keyword_range.get("preset_index", -1)),
			keyword_range.get("preset", {}),
			body_text.substr(range_start, range_end - range_start)
		)
		cursor = range_end

	if cursor < body_text.length():
		story_body_label.add_text(body_text.substr(cursor))

	var quote_text: String = str(node_data.get("quote", ""))
	quote_panel.visible = quote_text != ""
	quote_label.text = quote_text


func _get_story_body_text(body: Variant) -> String:
	if not (body is Array):
		return str(body)

	var paragraphs: PackedStringArray = []

	for paragraph in body:
		paragraphs.append(str(paragraph))

	return "\n\n".join(paragraphs)


func _build_story_keyword_ranges(source_node_id: String, body_text: String) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	var presets: Array[Dictionary] = loader.get_keyword_presets(source_node_id)

	for preset_index in range(presets.size()):
		var preset: Dictionary = presets[preset_index]
		var anchor_text: String = str(preset.get("anchor_text", ""))
		var occurrence_index: int = int(preset.get("occurrence_index", 0))
		var range_start: int = _find_text_occurrence(body_text, anchor_text, occurrence_index)

		if range_start < 0:
			push_warning(
				"MainUI: skipped keyword anchor absent from %s body: %s occurrence %d" % [
					source_node_id,
					anchor_text,
					occurrence_index
				]
			)
			continue

		ranges.append({
			"start": range_start,
			"end": range_start + anchor_text.length(),
			"preset_index": preset_index,
			"preset": preset
		})

	ranges.sort_custom(_sort_story_keyword_range)
	var non_overlapping_ranges: Array[Dictionary] = []
	var previous_end: int = -1

	for keyword_range in ranges:
		var range_start: int = int(keyword_range.get("start", -1))

		if range_start < previous_end:
			var preset: Dictionary = keyword_range.get("preset", {})
			push_warning(
				"MainUI: skipped overlapping keyword anchor for %s: %s" % [
					source_node_id,
					str(preset.get("anchor_text", ""))
				]
			)
			continue

		non_overlapping_ranges.append(keyword_range)
		previous_end = int(keyword_range.get("end", previous_end))

	return non_overlapping_ranges


func _find_text_occurrence(text: String, anchor_text: String, occurrence_index: int) -> int:
	if anchor_text == "" or occurrence_index < 0:
		return -1

	var search_from: int = 0
	var found_at: int = -1

	for _occurrence in range(occurrence_index + 1):
		found_at = text.find(anchor_text, search_from)

		if found_at < 0:
			return -1

		search_from = found_at + anchor_text.length()

	return found_at


func _sort_story_keyword_range(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("start", 0)) < int(right.get("start", 0))


func _append_story_keyword_segment(
	source_node_id: String,
	preset_index: int,
	preset_value: Variant,
	display_text: String
) -> void:
	if not (preset_value is Dictionary):
		story_body_label.add_text(display_text)
		return

	var preset: Dictionary = preset_value
	var keyword: String = str(preset.get("keyword", ""))
	var extracted: bool = runtime_state.has_keyword(keyword, source_node_id)
	var meta_value: String = "%s%s/%d" % [KEYWORD_META_PREFIX, source_node_id, preset_index]
	story_body_label.push_meta(meta_value)
	story_body_label.push_underline()
	story_body_label.push_color(C_BLUE if extracted else C_TEXT)
	story_body_label.add_text(display_text)
	story_body_label.pop()
	story_body_label.pop()
	story_body_label.pop()


func _on_story_keyword_meta_clicked(meta_value: Variant) -> void:
	var preset: Dictionary = _resolve_story_keyword_meta(meta_value)

	if preset.is_empty():
		push_warning("MainUI: ignored invalid story keyword meta.")
		return

	var source_node_id: String = runtime_state.current_node_id
	var keyword: String = str(preset.get("keyword", ""))
	var popup_position: Vector2 = story_view.get_local_mouse_position()

	if runtime_state.has_keyword(keyword, source_node_id):
		var description: String = _keyword_description(keyword, source_node_id)
		_show_keyword_popup(keyword, true, popup_position, description)

		if (
			_is_tutorial_case()
			and source_node_id == "tutorial_0006"
			and keyword == "封口白痕"
		):
			_mark_tutorial_flag("tutorial_keyword_intro_viewed", "关键词简介已查看。")

		return

	var result: Dictionary = runtime_state.add_keyword(keyword, source_node_id)

	if not bool(result.get("added", false)):
		var reason: String = str(result.get("reason", ""))

		if reason == "duplicate":
			_show_keyword_popup(keyword, true, popup_position)
			return

		push_warning("MainUI: failed to add configured inline keyword: %s (%s)" % [keyword, reason])
		return

	_refresh_keyword_grid()
	_render_graph_view()
	_refresh_current_goal()
	var current_node_data: Dictionary = loader.get_node(source_node_id)

	if not current_node_data.is_empty():
		_render_story_body(current_node_data)

	_show_keyword_popup(keyword, false, popup_position)

	if (
		_is_tutorial_case()
		and source_node_id == "tutorial_0006"
		and keyword == "封口白痕"
	):
		_mark_tutorial_flag(
			"tutorial_first_keyword_clicked",
			"关键词已经加入调查图谱。再次点击下划线关键词查看简介。"
		)


func _resolve_story_keyword_meta(meta_value: Variant) -> Dictionary:
	if not (meta_value is String):
		return {}

	var meta_text: String = str(meta_value)

	if not meta_text.begins_with(KEYWORD_META_PREFIX):
		return {}

	var payload: String = meta_text.trim_prefix(KEYWORD_META_PREFIX)
	var parts: PackedStringArray = payload.split("/", false)

	if parts.size() != 2 or not parts[1].is_valid_int():
		return {}

	var source_node_id: String = parts[0]

	if source_node_id != runtime_state.current_node_id:
		return {}

	var preset_index: int = int(parts[1])
	var presets: Array[Dictionary] = loader.get_keyword_presets(source_node_id)

	if preset_index < 0 or preset_index >= presets.size():
		return {}

	var expected_meta: String = "%s%s/%d" % [
		KEYWORD_META_PREFIX,
		source_node_id,
		preset_index
	]

	if meta_text != expected_meta:
		return {}

	return presets[preset_index].duplicate(true)


func _on_story_keyword_meta_hover_started(meta_value: Variant) -> void:
	var preset: Dictionary = _resolve_story_keyword_meta(meta_value)

	if preset.is_empty():
		story_body_label.tooltip_text = ""
		story_body_label.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	var keyword: String = str(preset.get("keyword", ""))
	story_body_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	story_body_label.tooltip_text = (
		"已提取"
		if runtime_state.has_keyword(keyword, runtime_state.current_node_id)
		else "点击提取关键词：" + keyword
	)


func _on_story_keyword_meta_hover_ended(_meta_value: Variant) -> void:
	story_body_label.tooltip_text = ""
	story_body_label.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _show_keyword_popup(
	keyword: String,
	already_extracted: bool,
	click_position: Vector2,
	description: String = ""
) -> void:
	_clear_keyword_popup()
	var popup := PanelContainer.new()
	popup.name = "KeywordPopupNode"
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 120
	var popup_max_width: float = 360.0 if description != "" else KEYWORD_POPUP_MAX_WIDTH
	var popup_width: float = minf(
		popup_max_width,
		maxf(124.0, 70.0 + float(keyword.length()) * 18.0)
	)

	if description != "":
		popup_width = popup_max_width

	var popup_size := Vector2(popup_width, 116.0 if description != "" else 42.0)
	popup.custom_minimum_size = popup_size
	popup.size = popup_size
	popup.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_BLUE, 1, 4))
	story_view.add_child(popup)
	keyword_popup_node = popup

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	popup.add_child(margin)
	var popup_box := VBoxContainer.new()
	popup_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_box.add_theme_constant_override("separation", 4)
	margin.add_child(popup_box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	popup_box.add_child(row)
	var marker := _label("●" if already_extracted else "◇", 13, C_BLUE, FONT_MONO_MEDIUM)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(marker)
	var text_label := _label(keyword, 15, C_BLUE, FONT_SERIF_SEMIBOLD)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_label.tooltip_text = keyword
	row.add_child(text_label)

	if description != "":
		var description_label := _label(description, 12, C_SUBTEXT, FONT_SERIF_REGULAR)
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description_label.max_lines_visible = 3
		description_label.tooltip_text = description
		popup_box.add_child(description_label)

	var requested_position: Vector2 = click_position + KEYWORD_POPUP_OFFSET
	var max_position := Vector2(
		maxf(KEYWORD_POPUP_VIEW_MARGIN, story_view.size.x - popup_size.x - KEYWORD_POPUP_VIEW_MARGIN),
		maxf(KEYWORD_POPUP_VIEW_MARGIN, story_view.size.y - popup_size.y - KEYWORD_POPUP_VIEW_MARGIN)
	)
	popup.position = Vector2(
		clampf(requested_position.x, KEYWORD_POPUP_VIEW_MARGIN, max_position.x),
		clampf(requested_position.y, KEYWORD_POPUP_VIEW_MARGIN, max_position.y)
	)
	popup.pivot_offset = popup_size * 0.5
	popup.scale = Vector2(0.94, 0.94)
	popup.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var popup_tween: Tween = create_tween().bind_node(popup)
	popup_tween.set_trans(Tween.TRANS_QUAD)
	popup_tween.set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(popup, "modulate:a", 1.0, 0.09)
	popup_tween.parallel().tween_property(popup, "scale", Vector2.ONE, 0.09)
	popup_tween.tween_interval(1.8 if description != "" else 0.7)
	popup_tween.tween_property(popup, "modulate:a", 0.0, 0.18)
	popup_tween.parallel().tween_property(popup, "position:y", popup.position.y - 6.0, 0.18)
	popup_tween.tween_callback(_finish_keyword_popup.bind(popup))


func _keyword_description(keyword: String, source_node_id: String) -> String:
	var clues_data: Dictionary = loader.get_clues()
	var clues: Variant = clues_data.get("clues", [])

	if not (clues is Array):
		return ""

	for clue_value in clues:
		if not (clue_value is Dictionary):
			continue

		var clue: Dictionary = clue_value

		if (
			str(clue.get("title", "")) == keyword
			and str(clue.get("source_node", "")) == source_node_id
		):
			return str(clue.get("summary", ""))

	return ""


func _finish_keyword_popup(popup: PanelContainer) -> void:
	if not is_instance_valid(popup):
		return

	if keyword_popup_node == popup:
		keyword_popup_node = null

	popup.queue_free()


func _clear_keyword_popup() -> void:
	if keyword_popup_node != null and is_instance_valid(keyword_popup_node):
		keyword_popup_node.queue_free()

	keyword_popup_node = null


func _hide_keyword_action() -> void:
	if story_body_label != null:
		story_body_label.deselect()

	_clear_keyword_popup()
	_close_keyword_context_menu()


func _refresh_keyword_grid() -> void:
	_clear_children(keyword_grid)

	var displayed_texts: Dictionary = {}

	for keyword in loader.get_discovered_keywords():
		var text: String = str(keyword)

		if text != "" and not displayed_texts.has(text):
			displayed_texts[text] = true
			keyword_grid.add_child(_keyword_tag(text))

	for text in runtime_state.get_discovered_keyword_texts():
		if text != "" and not displayed_texts.has(text):
			displayed_texts[text] = true
			keyword_grid.add_child(_keyword_tag(text))

	call_deferred("_update_keyword_tag_widths")


func _render_choices(node_data: Dictionary) -> void:
	_clear_children(choice_list)

	var choices: Variant = node_data.get("choices", [])
	choice_title_label.visible = false

	if not (choices is Array):
		return

	for choice in choices:
		if not (choice is Dictionary):
			continue

		if not _choice_is_available(choice):
			continue

		choice_title_label.visible = true

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


func _render_graph_view() -> void:
	if graph_canvas == null:
		return

	_clear_children(graph_canvas)
	_keyword_graph_layout.clear()

	var canvas_size: Vector2 = loader.get_graph_canvas_size()

	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		var empty_edges: Array[Dictionary] = []
		graph_canvas.configure(Vector2(960.0, 640.0), empty_edges, C_LINE)
		var warning_label := _label("图谱布局不可用", 18, C_SUBTEXT, FONT_SERIF_REGULAR)
		warning_label.position = Vector2(32.0, 32.0)
		graph_canvas.add_child(warning_label)
		return

	var visible_nodes: Dictionary = _get_visible_graph_nodes()
	var edges: Array[Dictionary] = []

	for source_value in visible_nodes.keys():
		var source_id: String = str(source_value)

		if not runtime_state.unlocked_nodes.has(source_id):
			continue

		var source_data: Dictionary = loader.get_node(source_id)
		var source_position: Vector2 = loader.get_graph_node_position(source_id)

		if source_data.is_empty() or source_position.x < 0.0 or source_position.y < 0.0:
			continue

		var choices: Variant = source_data.get("choices", [])

		if not (choices is Array):
			continue

		for choice in choices:
			if not (choice is Dictionary):
				continue

			if not _choice_is_available(choice):
				continue

			var target_id: String = str(choice.get("to", ""))

			if target_id == "" or not visible_nodes.has(target_id):
				continue

			var target_position: Vector2 = loader.get_graph_node_position(target_id)

			if target_position.x < 0.0 or target_position.y < 0.0:
				continue

			edges.append({
				"from": source_position + GRAPH_NODE_SIZE * 0.5,
				"to": target_position + GRAPH_NODE_SIZE * 0.5
			})

	_keyword_graph_layout = _calculate_keyword_graph_layout(visible_nodes, canvas_size)
	var keyword_edges: Array[Dictionary] = _build_keyword_connection_edges(visible_nodes)
	graph_canvas.configure(canvas_size, edges, C_LINE, keyword_edges, C_BLUE)

	for node_value in visible_nodes.keys():
		var node_id: String = str(node_value)
		var node_data: Dictionary = loader.get_node(node_id)
		var node_position: Vector2 = loader.get_graph_node_position(node_id)

		if node_data.is_empty():
			push_warning("MainUI: graph references missing node: " + node_id)
			continue

		if node_position.x < 0.0 or node_position.y < 0.0:
			push_warning("MainUI: graph layout position missing for node: " + node_id)
			continue

		var visited: bool = runtime_state.unlocked_nodes.has(node_id)
		var current: bool = node_id == runtime_state.current_node_id
		var keyword_unlocked: bool = runtime_state.is_keyword_unlocked(node_id)
		graph_canvas.add_child(_graph_node_card(
			node_data,
			node_position,
			visited,
			current,
			keyword_unlocked
		))

	for layout_value in _keyword_graph_layout.values():
		if not (layout_value is Dictionary):
			continue

		var layout: Dictionary = layout_value
		graph_canvas.add_child(_keyword_graph_node(
			layout.get("instance", {}),
			layout.get("position", Vector2.ZERO),
			layout.get("size", KEYWORD_GRAPH_MIN_SIZE)
		))


func _get_visible_graph_nodes() -> Dictionary:
	var visible_nodes: Dictionary = {}

	for node_id in runtime_state.unlocked_nodes.keys():
		visible_nodes[str(node_id)] = true

	for node_id in runtime_state.get_keyword_unlocked_node_ids():
		if not loader.get_node(node_id).is_empty():
			visible_nodes[node_id] = true

	for connection in runtime_state.get_keyword_connections():
		var connected_target_id: String = str(connection.get("target_node_id", ""))

		if connected_target_id != "" and not loader.get_node(connected_target_id).is_empty():
			visible_nodes[connected_target_id] = true

	var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)
	var choices: Variant = current_data.get("choices", [])

	if choices is Array:
		for choice in choices:
			if not (choice is Dictionary):
				continue

			if not _choice_is_available(choice):
				continue

			var target_id: String = str(choice.get("to", ""))

			if target_id != "" and not loader.get_node(target_id).is_empty():
				visible_nodes[target_id] = true

	var graph_targets: Variant = current_data.get("graph_targets", [])

	if graph_targets is Array:
		for graph_target_value in graph_targets:
			var graph_target_id: String = str(graph_target_value)

			if graph_target_id != "" and not loader.get_node(graph_target_id).is_empty():
				visible_nodes[graph_target_id] = true

	return visible_nodes


func _calculate_keyword_graph_layout(
	visible_nodes: Dictionary,
	canvas_size: Vector2
) -> Dictionary:
	var layout_by_instance: Dictionary = {}
	var source_keyword_counts: Dictionary = {}

	for keyword_instance in runtime_state.get_keyword_instances():
		var source_node_id: String = str(keyword_instance.get("source_node_id", ""))
		var instance_id: String = str(keyword_instance.get("instance_id", ""))

		if source_node_id == "" or instance_id == "" or not visible_nodes.has(source_node_id):
			continue

		var source_position: Vector2 = loader.get_graph_node_position(source_node_id)

		if source_position.x < 0.0 or source_position.y < 0.0:
			continue

		var keyword_index: int = int(source_keyword_counts.get(source_node_id, 0))
		source_keyword_counts[source_node_id] = keyword_index + 1
		var keyword_text: String = str(keyword_instance.get("text", ""))
		var keyword_size := Vector2(
			clampf(74.0 + float(keyword_text.length()) * 14.0, KEYWORD_GRAPH_MIN_SIZE.x, KEYWORD_GRAPH_MAX_WIDTH),
			KEYWORD_GRAPH_MIN_SIZE.y
		)
		var keyword_position := Vector2(
			source_position.x + GRAPH_NODE_SIZE.x + KEYWORD_GRAPH_OFFSET,
			source_position.y + 8.0 + float(keyword_index) * (keyword_size.y + KEYWORD_GRAPH_GAP)
		)

		if keyword_position.x + keyword_size.x > canvas_size.x - 16.0:
			keyword_position.x = source_position.x - KEYWORD_GRAPH_OFFSET - keyword_size.x

		keyword_position.x = maxf(16.0, keyword_position.x)
		layout_by_instance[instance_id] = {
			"instance": keyword_instance,
			"position": keyword_position,
			"size": keyword_size
		}

	return layout_by_instance


func _build_keyword_connection_edges(visible_nodes: Dictionary) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []

	for connection in runtime_state.get_keyword_connections():
		if str(connection.get("outcome", "")) != "correct":
			continue

		var instance_id: String = str(connection.get("keyword_instance_id", ""))
		var target_node_id: String = str(connection.get("target_node_id", ""))

		if not _keyword_graph_layout.has(instance_id) or not visible_nodes.has(target_node_id):
			continue

		var layout_value: Variant = _keyword_graph_layout[instance_id]

		if not (layout_value is Dictionary):
			continue

		var target_position: Vector2 = loader.get_graph_node_position(target_node_id)

		if target_position.x < 0.0 or target_position.y < 0.0:
			continue

		var layout: Dictionary = layout_value
		var keyword_position: Vector2 = layout.get("position", Vector2.ZERO)
		var keyword_size: Vector2 = layout.get("size", KEYWORD_GRAPH_MIN_SIZE)
		edges.append({
			"from": keyword_position + keyword_size * 0.5,
			"to": target_position + GRAPH_NODE_SIZE * 0.5
		})

	return edges


func _keyword_graph_node(keyword_instance: Dictionary, position_value: Vector2, node_size: Vector2) -> Control:
	var keyword_text: String = str(keyword_instance.get("text", ""))
	var instance_id: String = str(keyword_instance.get("instance_id", "keyword"))
	var selected: bool = instance_id == _selected_keyword_instance_id
	var connected: bool = not runtime_state.get_keyword_connections_for_keyword(instance_id).is_empty()
	var bg_color: Color = C_BLUE if selected else Color("#F4F7FF")
	var text_color: Color = C_WHITE if selected else C_BLUE
	var border_width: int = 2 if connected and not selected else 1
	var card := Control.new()
	card.name = "GraphKeyword_" + instance_id
	card.position = position_value
	card.size = node_size
	card.custom_minimum_size = node_size
	card.set_meta("graph_keyword_card", true)
	card.set_meta("keyword_instance_id", instance_id)
	card.set_meta("keyword_connected", connected)
	card.tooltip_text = keyword_text

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style_box(bg_color, C_BLUE, border_width, 3))
	_fill_rect(panel)
	card.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var diamond := _label("◇", 15, text_color, FONT_MONO_MEDIUM)
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diamond.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(diamond)

	if connected:
		var connected_dot := _label("●", 9, text_color, FONT_MONO_MEDIUM)
		connected_dot.name = "ConnectedDot"
		connected_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		connected_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		connected_dot.tooltip_text = "已连接"
		row.add_child(connected_dot)

	var text_label := _label(keyword_text, 14, text_color, FONT_SERIF_REGULAR)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_label.tooltip_text = keyword_text
	row.add_child(text_label)

	var hit_button := _transparent_hit_button()
	hit_button.tooltip_text = keyword_text
	hit_button.pressed.connect(_on_graph_keyword_pressed.bind(instance_id))
	card.add_child(hit_button)
	return card


func _graph_node_card(
	node_data: Dictionary,
	position_value: Vector2,
	visited: bool,
	current: bool,
	keyword_unlocked: bool
) -> Control:
	var node_id: String = str(node_data.get("node_id", ""))
	var icon_key: String = str(node_data.get("icon_key", ""))
	var node_type: String = str(node_data.get("node_type", ""))
	var is_error: bool = icon_key == "false" or node_type.contains("错误解释")
	var is_failure: bool = icon_key == "fatal" or node_type.contains("失败")

	var bg_color: Color = Color("#E8F0FF")
	var border_color: Color = C_LINE
	var text_color: Color = C_SUBTEXT
	var border_width: int = 1
	var state_text := "可调查"

	if visited:
		bg_color = C_WHITE
		border_color = C_MUTED if is_error else C_BLUE
		text_color = C_SUBTEXT if is_error else C_BLUE
		state_text = "已访问"
	elif keyword_unlocked:
		bg_color = Color("#E8F0FF")
		border_color = C_BLUE
		text_color = C_BLUE
		state_text = "已解锁"

	if current:
		bg_color = C_BLUE_DARK
		border_color = C_BLUE_DARK
		text_color = C_WHITE
		state_text = "当前节点"

	if is_failure:
		border_color = C_BLUE_DARK
		border_width = 1

	var card := Control.new()
	card.name = "GraphNode_" + node_id
	card.set_meta("graph_node_card", true)
	card.set_meta("graph_node_id", node_id)
	card.position = position_value
	card.size = GRAPH_NODE_SIZE
	card.custom_minimum_size = GRAPH_NODE_SIZE

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(bg_color, border_color, border_width, 5))
	_fill_rect(panel)
	card.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	_fill_rect(margin)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var title := _label(str(node_data.get("title", node_id)), 17, text_color, FONT_SERIF_SEMIBOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(title)

	if is_failure:
		var failure_title_strike := Line2D.new()
		failure_title_strike.name = "FailureTitleStrike"
		failure_title_strike.width = 2.0
		failure_title_strike.antialiased = true
		failure_title_strike.z_index = 2
		var strike_color := C_BLUE_DARK
		strike_color.a = 0.7
		failure_title_strike.default_color = strike_color
		title.add_child(failure_title_strike)
		title.resized.connect(_update_failure_title_strike.bind(title, failure_title_strike))
		_update_failure_title_strike(title, failure_title_strike)

	var meta_row := HBoxContainer.new()
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(meta_row)

	var id_label := _label(node_id, 12, text_color, FONT_MONO_REGULAR)
	id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(id_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(spacer)

	var state_label := _label(state_text, 12, text_color, FONT_SERIF_REGULAR)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(state_label)

	var hit_button := _transparent_hit_button()
	hit_button.pressed.connect(_on_graph_node_pressed.bind(node_id))

	card.add_child(hit_button)
	return card


func _update_failure_title_strike(title_label: Label, strike_line: Line2D) -> void:
	var font: Font = title_label.get_theme_font("font")
	var font_size: int = title_label.get_theme_font_size("font_size")
	var measured_width: float = font.get_string_size(
		title_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	var visible_width: float = minf(measured_width, title_label.size.x)
	var strike_y: float = title_label.size.y * 0.52
	strike_line.points = PackedVector2Array([
		Vector2(0.0, strike_y),
		Vector2(maxf(0.0, visible_width), strike_y)
	])


func _on_graph_node_pressed(node_id: String) -> void:
	if _selected_keyword_instance_id != "":
		_complete_keyword_connection(node_id)
		return

	var node_data: Dictionary = loader.get_node(node_id)

	if bool(node_data.get("graph_only", false)):
		_show_graph_status(str(node_data.get("title", "推断目标")), false)
		return

	if (
		not runtime_state.unlocked_nodes.has(node_id)
		and not runtime_state.is_keyword_unlocked(node_id)
	):
		return

	_show_node(node_id)
	_show_story_view()


func _on_graph_keyword_pressed(instance_id: String) -> void:
	var instance: Dictionary = runtime_state.get_keyword_instance(instance_id)

	if instance.is_empty():
		push_warning("MainUI: graph keyword instance not found: " + instance_id)
		return

	_selected_keyword_instance_id = instance_id

	if (
		_is_tutorial_case()
		and str(instance.get("source_node_id", "")) == "tutorial_0006"
		and str(instance.get("normalized_text", "")) == "封口白痕"
	):
		_mark_tutorial_flag(
			"tutorial_first_keyword_selected",
			"现在选择一条能够被该关键词支持的记录。"
		)

	_render_graph_view()
	_show_graph_status(
		"已选择关键词：%s\n请选择要连接的剧情节点\nEsc 取消" % str(instance.get("text", "")),
		true
	)


func _complete_keyword_connection(target_node_id: String) -> void:
	var instance_id: String = _selected_keyword_instance_id
	var instance: Dictionary = runtime_state.get_keyword_instance(instance_id)
	_selected_keyword_instance_id = ""

	if _is_tutorial_case():
		runtime_state.flags["tutorial_first_connection_attempted"] = true

	if instance.is_empty():
		_render_graph_view()
		_show_graph_status("连接无效", false)
		return

	var normalized_keyword: String = str(instance.get("normalized_text", ""))
	var source_node_id: String = str(instance.get("source_node_id", ""))
	var rule: Dictionary = loader.find_keyword_rule(
		normalized_keyword,
		source_node_id,
		target_node_id
	)

	if rule.is_empty():
		_render_graph_view()
		_show_graph_status("连接无效", false)
		return

	if not _rule_requirements_met(rule):
		_render_graph_view()
		_show_graph_status("请先完成当前教学目标", false)
		return

	var outcome: String = str(rule.get("outcome", "")).to_lower()

	if outcome == "correct":
		var connection_result: Dictionary = runtime_state.add_keyword_connection(
			instance_id,
			target_node_id,
			rule
		)

		if not bool(connection_result.get("added", false)):
			_render_graph_view()

			if str(connection_result.get("reason", "")) == "duplicate":
				_show_graph_status("该连接已经存在", false)
			else:
				_show_graph_status("连接无效", false)

			return

		var unlock_node_ids: Array[String] = []
		var legacy_unlock_node_id: String = str(rule.get("unlock_node_id", ""))

		if legacy_unlock_node_id != "":
			unlock_node_ids.append(legacy_unlock_node_id)

		var configured_unlock_node_ids: Variant = rule.get("unlock_node_ids", [])

		if configured_unlock_node_ids is Array:
			for configured_node_value in configured_unlock_node_ids:
				var configured_node_id: String = str(configured_node_value)

				if configured_node_id != "" and not unlock_node_ids.has(configured_node_id):
					unlock_node_ids.append(configured_node_id)

		var unlocked_new_node: bool = false

		for unlock_node_id in unlock_node_ids:
			if loader.get_node(unlock_node_id).is_empty():
				push_warning("MainUI: keyword rule unlock node not found: " + unlock_node_id)
			else:
				unlocked_new_node = (
					runtime_state.unlock_node_from_keyword(unlock_node_id)
					or unlocked_new_node
				)

		_apply_rule_flags(rule)

		if bool(rule.get("autosave_on_success", false)):
			var current_node_data: Dictionary = loader.get_node(runtime_state.current_node_id)

			if not current_node_data.is_empty():
				_write_disk_autosave(current_node_data)

		_refresh_graph_after_keyword_result()
		var success_text: String = "连接成立，已解锁新节点" if unlocked_new_node else "连接成立"
		var feedback: String = str(rule.get("feedback", ""))

		if feedback != "":
			success_text += "\n" + feedback

		_show_graph_status(success_text, false)

		if _is_tutorial_case():
			_mark_tutorial_flag(
				"tutorial_correct_connection_completed",
				"连接成立。新的调查节点已解锁。"
			)

		return

	if outcome == "invalid":
		_apply_rule_flags(rule)
		_refresh_graph_after_keyword_result()
		var invalid_feedback: String = str(rule.get("feedback", ""))
		_show_graph_status(
			"连接无效\n" + invalid_feedback if invalid_feedback != "" else "连接无效",
			false
		)
		return

	if outcome == "error" or outcome == "incorrect" or outcome == "wrong":
		_apply_rule_flags(rule)
		var error_node_id: String = str(rule.get("error_node_id", ""))

		if error_node_id != "":
			if loader.get_node(error_node_id).is_empty():
				push_warning("MainUI: keyword rule error node not found: " + error_node_id)
			else:
				runtime_state.unlock_node_from_keyword(error_node_id)

		_refresh_graph_after_keyword_result()
		var error_feedback: String = str(rule.get("feedback", ""))
		_show_graph_status(
			error_feedback if error_feedback != "" else "连接不成立",
			false
		)

		if _is_tutorial_case():
			runtime_state.flags["tutorial_error_seen"] = true
			if error_node_id != "" and not loader.get_node(error_node_id).is_empty():
				_show_node(error_node_id)
				_show_story_view()

		return

	push_warning("MainUI: unsupported keyword rule outcome: " + outcome)
	_render_graph_view()
	_show_graph_status("连接无效", false)


func _rule_requirements_met(rule: Dictionary) -> bool:
	var requirements: Variant = rule.get("requires_flags", {})

	if not (requirements is Dictionary):
		return true

	for flag_value in (requirements as Dictionary).keys():
		var flag_name: String = str(flag_value)
		var expected: bool = bool((requirements as Dictionary).get(flag_value, false))

		if bool(runtime_state.flags.get(flag_name, false)) != expected:
			return false

	return true


func _apply_rule_flags(rule: Dictionary) -> void:
	var flags_value: Variant = rule.get("set_flags", {})

	if not (flags_value is Dictionary):
		return

	for flag_value in (flags_value as Dictionary).keys():
		var flag_name: String = str(flag_value)
		var enabled_value: Variant = (flags_value as Dictionary).get(flag_value, false)

		if flag_name != "" and enabled_value is bool:
			runtime_state.flags[flag_name] = bool(enabled_value)

	_refresh_current_goal()


func _refresh_graph_after_keyword_result() -> void:
	_render_graph_view()
	var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)

	if not current_data.is_empty():
		_render_right_panel(current_data)


func _cancel_keyword_connection_selection(refresh_graph: bool) -> void:
	var had_selection: bool = _selected_keyword_instance_id != ""
	_selected_keyword_instance_id = ""
	_graph_feedback_generation += 1

	if graph_status_panel != null:
		graph_status_panel.visible = false

	if had_selection and refresh_graph and graph_view != null and graph_view.visible:
		_render_graph_view()


func _show_graph_status(text: String, persistent: bool) -> void:
	if graph_status_panel == null or graph_status_label == null:
		return

	_graph_feedback_generation += 1
	var feedback_generation: int = _graph_feedback_generation
	graph_status_label.text = text
	graph_status_panel.visible = true

	if persistent:
		return

	await get_tree().create_timer(1.8).timeout

	if (
		feedback_generation == _graph_feedback_generation
		and _selected_keyword_instance_id == ""
	):
		graph_status_panel.visible = false


func _show_case_status(text: String) -> void:
	if case_status_panel == null or case_status_label == null:
		return

	_case_status_generation += 1
	var status_generation: int = _case_status_generation
	case_status_label.text = text
	case_status_panel.visible = true
	await get_tree().create_timer(1.8).timeout

	if status_generation == _case_status_generation:
		case_status_panel.visible = false


func _render_audio_cards(node_data: Dictionary) -> void:
	_cancel_audio_waveform_drags()
	_clear_children(audio_slot)
	_audio_card_controls.clear()
	_audio_finished_id = ""

	var audio_clues: Variant = node_data.get("audio_clues", [])

	if not (audio_clues is Array) or audio_clues.is_empty():
		return

	for audio_clue_value in audio_clues:
		var audio_clue_id: String = str(audio_clue_value)
		var clue_data: Dictionary = {}

		if audio_manager != null:
			var clue_variant: Variant = audio_manager.call("get_audio_clue", audio_clue_id)

			if clue_variant is Dictionary:
				clue_data = clue_variant

		if clue_data.is_empty():
			clue_data = {
				"id": audio_clue_id,
				"title": "音频线索"
			}
			push_warning("MainUI: audio clue data not found: " + audio_clue_id)

		_build_audio_card(clue_data, str(node_data.get("node_id", "")))


func _build_audio_card(clue_data: Dictionary, source_node_id: String) -> void:
	var audio_clue_id: String = str(clue_data.get("id", ""))
	var audio_path: String = str(clue_data.get("file", ""))
	var waveform_data_path: String = str(clue_data.get("waveform_file", ""))
	var track_label_text: String = str(clue_data.get("track_label", "Track 03"))
	var source_title: String = str(clue_data.get("display_name", "未知房间麦克风"))
	var source_subtitle: String = str(clue_data.get(
		"display_subtitle",
		"(Unknown Room Mic)"
	))
	var available: bool = false
	var duration: float = 0.0

	if audio_manager != null and audio_clue_id != "":
		available = bool(audio_manager.call("is_audio_available", audio_clue_id))

		if available:
			duration = float(audio_manager.call("get_audio_duration", audio_clue_id))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, 104)
	card.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 2))
	audio_slot.add_child(card)

	var track_row := HBoxContainer.new()
	track_row.add_theme_constant_override("separation", 0)
	card.add_child(track_row)

	var track_info := PanelContainer.new()
	track_info.custom_minimum_size = Vector2(190, 100)
	track_info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track_info.clip_contents = true
	track_info.add_theme_stylebox_override(
		"panel",
		_style_box(C_PANEL_SOFT, Color.TRANSPARENT, 0, 1)
	)
	track_row.add_child(track_info)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 12)
	info_margin.add_theme_constant_override("margin_right", 12)
	info_margin.add_theme_constant_override("margin_top", 7)
	info_margin.add_theme_constant_override("margin_bottom", 7)
	track_info.add_child(info_margin)

	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 1)
	info_margin.add_child(info_box)

	var track_header := HBoxContainer.new()
	track_header.add_theme_constant_override("separation", 6)
	info_box.add_child(track_header)
	var track_label := _label("× " + track_label_text, 13, C_BLUE, FONT_MONO_MEDIUM)
	track_label.custom_minimum_size.x = 118
	track_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_label.clip_text = true
	track_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	track_header.add_child(track_label)

	var microphone_label := _label(source_title, 14, C_BLUE, FONT_SERIF_SEMIBOLD)
	microphone_label.clip_text = true
	microphone_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_box.add_child(microphone_label)

	var microphone_english := _label(source_subtitle, 11, C_SUBTEXT, FONT_MONO_REGULAR)
	microphone_english.clip_text = true
	microphone_english.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_box.add_child(microphone_english)

	var info_controls := HBoxContainer.new()
	info_controls.add_theme_constant_override("separation", 5)
	info_box.add_child(info_controls)

	var play_button := _compact_audio_track_button(ICON_PLAY, "播放 " + track_label_text)
	play_button.disabled = not available
	play_button.pressed.connect(_on_audio_play_pressed.bind(audio_clue_id))
	info_controls.add_child(play_button)

	var marker_button := _compact_audio_track_button(
		ICON_BOOKMARK,
		"在当前播放位置添加标记"
	)
	marker_button.disabled = not available
	marker_button.pressed.connect(
		_on_audio_marker_pressed.bind(audio_clue_id, source_node_id)
	)
	info_controls.add_child(marker_button)

	var feedback_label := _label(
		"" if available else "音频资源暂不可用",
		11,
		C_BLUE,
		FONT_SERIF_REGULAR
	)
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.clip_text = true
	feedback_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_controls.add_child(feedback_label)

	var waveform: Control = AudioWaveformPlaceholder.new()
	waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	waveform.size_flags_vertical = Control.SIZE_EXPAND_FILL
	waveform.mouse_filter = Control.MOUSE_FILTER_STOP
	waveform.call(
		"set_waveform_samples",
		_load_audio_waveform_samples(audio_path, waveform_data_path)
	)
	waveform.call("set_drag_enabled", available and duration > 0.0)
	waveform.connect(
		"seek_requested",
		_on_audio_waveform_seek_requested.bind(audio_clue_id)
	)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1, 100)
	divider.color = C_BLUE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_row.add_child(divider)

	var waveform_frame := PanelContainer.new()
	waveform_frame.custom_minimum_size.y = 100
	waveform_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	waveform_frame.add_theme_stylebox_override(
		"panel",
		_style_box(C_WHITE, Color.TRANSPARENT, 0, 1)
	)
	track_row.add_child(waveform_frame)

	var waveform_margin := MarginContainer.new()
	waveform_margin.add_theme_constant_override("margin_left", 8)
	waveform_margin.add_theme_constant_override("margin_right", 8)
	waveform_margin.add_theme_constant_override("margin_top", 2)
	waveform_margin.add_theme_constant_override("margin_bottom", 2)
	waveform_frame.add_child(waveform_margin)
	waveform_margin.add_child(waveform)

	_audio_card_controls[audio_clue_id] = {
		"available": available,
		"duration": duration,
		"track_label": track_label_text,
		"play_button": play_button,
		"marker_button": marker_button,
		"time_label": null,
		"feedback_label": feedback_label,
		"waveform": waveform
	}
	_refresh_audio_markers(audio_clue_id)


func _load_audio_waveform_samples(
	audio_path: String,
	waveform_data_path: String
) -> PackedFloat32Array:
	var cache_key: String = waveform_data_path

	if cache_key == "":
		cache_key = audio_path

	if cache_key != "" and _audio_waveform_cache.has(cache_key):
		return _audio_waveform_cache[cache_key] as PackedFloat32Array

	var samples := PackedFloat32Array()

	if audio_path == "" or not FileAccess.file_exists(audio_path):
		push_warning("MainUI: audio resource not found for waveform: " + audio_path)
	elif waveform_data_path == "" or not FileAccess.file_exists(waveform_data_path):
		push_warning("MainUI: waveform data not found: " + waveform_data_path)
	else:
		var json := JSON.new()
		var error: Error = json.parse(FileAccess.get_file_as_string(waveform_data_path))

		if error != OK:
			push_warning("MainUI: waveform JSON parse error: %s, line %d" % [
				json.get_error_message(),
				json.get_error_line()
			])
		elif not (json.data is Dictionary):
			push_warning("MainUI: waveform data root must be a Dictionary: " + waveform_data_path)
		else:
			var waveform_data: Dictionary = json.data
			var declared_audio_path: String = str(waveform_data.get("audio_path", ""))
			var raw_samples: Variant = waveform_data.get("samples", [])

			if declared_audio_path != audio_path:
				push_warning("MainUI: waveform audio path mismatch: " + waveform_data_path)
			elif not (raw_samples is Array):
				push_warning("MainUI: waveform samples must be an Array: " + waveform_data_path)
			else:
				for raw_sample in raw_samples:
					if raw_sample is int or raw_sample is float:
						var sample: float = float(raw_sample)

						if not is_nan(sample) and not is_inf(sample):
							samples.append(clampf(sample, 0.0, 1.0))
					else:
						push_warning(
							"MainUI: ignored non-numeric waveform sample: " + waveform_data_path
						)

	if cache_key != "":
		_audio_waveform_cache[cache_key] = samples

	return samples


func _on_audio_play_pressed(audio_clue_id: String) -> void:
	if audio_manager == null or not _audio_card_controls.has(audio_clue_id):
		return

	var controls: Dictionary = _audio_card_controls[audio_clue_id]

	if not bool(controls.get("available", false)):
		_show_audio_feedback(audio_clue_id, "音频资源暂不可用")
		return

	var current_audio_id: String = str(audio_manager.call("get_current_audio_id"))
	var playing: bool = bool(audio_manager.call("is_playing"))
	var paused: bool = bool(audio_manager.call("is_paused"))

	if current_audio_id == audio_clue_id and playing:
		audio_manager.call("pause_audio")
		return

	if current_audio_id == audio_clue_id and paused:
		audio_manager.call("resume_audio")
		return

	if not bool(audio_manager.call("play_audio", audio_clue_id)):
		_show_audio_feedback(audio_clue_id, "音频资源暂不可用")


func _on_audio_marker_pressed(audio_clue_id: String, source_node_id: String) -> void:
	if audio_manager == null or not _audio_card_controls.has(audio_clue_id):
		return

	var controls: Dictionary = _audio_card_controls[audio_clue_id]

	if not bool(controls.get("available", false)):
		_show_audio_feedback(audio_clue_id, "音频资源暂不可用")
		return

	if str(audio_manager.call("get_current_audio_id")) != audio_clue_id:
		if not bool(audio_manager.call("prepare_audio", audio_clue_id)):
			_show_audio_feedback(audio_clue_id, "音频资源暂不可用")
			return

	var position: float = float(audio_manager.call("get_playback_position"))
	var label: String = _format_audio_time(position)
	var result: Dictionary = runtime_state.add_audio_marker(
		audio_clue_id,
		source_node_id,
		position,
		label
	)

	if bool(result.get("added", false)):
		_refresh_audio_markers(audio_clue_id)
		_show_audio_feedback(audio_clue_id, "已标记 " + label)
	else:
		_show_audio_feedback(audio_clue_id, "该时间已标记")


func _on_audio_started(audio_clue_id: String) -> void:
	_audio_finished_id = ""
	_refresh_audio_button_states(audio_clue_id)

	if (
		_is_tutorial_case()
		and runtime_state.current_node_id == "tutorial_0000"
		and audio_clue_id == "audio_tutorial"
		and not bool(runtime_state.flags.get("tutorial_audio_started", false))
	):
		runtime_state.flags["tutorial_audio_started"] = true
		var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)
		_refresh_current_goal()

		if not current_data.is_empty():
			_render_choices(current_data)


func _on_audio_paused(audio_clue_id: String) -> void:
	_refresh_audio_button_states(audio_clue_id)


func _on_audio_stopped(audio_clue_id: String) -> void:
	_audio_finished_id = ""
	_update_audio_card_progress(audio_clue_id, 0.0, _get_audio_card_duration(audio_clue_id))
	_refresh_audio_button_states(audio_clue_id)


func _on_audio_finished(audio_clue_id: String) -> void:
	_audio_finished_id = audio_clue_id
	_update_audio_card_progress(audio_clue_id, 0.0, _get_audio_card_duration(audio_clue_id))
	_refresh_audio_button_states(audio_clue_id)


func _on_audio_progress_changed(audio_clue_id: String, position: float, duration: float) -> void:
	_update_audio_card_progress(audio_clue_id, position, duration)


func _on_audio_waveform_seek_requested(progress_ratio: float, audio_clue_id: String) -> void:
	if audio_manager == null or not _audio_card_controls.has(audio_clue_id):
		return

	var controls: Dictionary = _audio_card_controls[audio_clue_id]
	var duration: float = float(controls.get("duration", 0.0))

	if not bool(controls.get("available", false)) or duration <= 0.0:
		return

	if str(audio_manager.call("get_current_audio_id")) != audio_clue_id:
		if not bool(audio_manager.call("prepare_audio", audio_clue_id)):
			_show_audio_feedback(audio_clue_id, "音频资源暂不可用")
			return

	var safe_ratio: float = clampf(progress_ratio, 0.0, 1.0)
	audio_manager.call("seek_audio", safe_ratio * duration)
	_update_audio_card_progress(audio_clue_id, safe_ratio * duration, duration)


func _refresh_audio_progress_display() -> void:
	if (
		audio_manager == null
		or story_view == null
		or not story_view.visible
		or _audio_card_controls.is_empty()
	):
		return

	var audio_clue_id: String = str(audio_manager.call("get_current_audio_id"))

	if audio_clue_id == "" or not _audio_card_controls.has(audio_clue_id):
		return

	_update_audio_card_progress(
		audio_clue_id,
		float(audio_manager.call("get_playback_position")),
		float(audio_manager.call("get_loaded_duration"))
	)


func _update_audio_card_progress(audio_clue_id: String, position: float, duration: float) -> void:
	if not _audio_card_controls.has(audio_clue_id):
		return

	var controls: Dictionary = _audio_card_controls[audio_clue_id]
	var time_label: Label = controls.get("time_label") as Label
	var waveform: Control = controls.get("waveform") as Control
	var safe_duration: float = maxf(0.0, duration)
	var safe_position: float = clampf(position, 0.0, safe_duration) if safe_duration > 0.0 else 0.0
	var progress_ratio: float = safe_position / safe_duration if safe_duration > 0.0 else 0.0

	if time_label != null:
		time_label.text = "%s / %s" % [
			_format_audio_time(safe_position),
			_format_audio_time(safe_duration)
		]

	if waveform != null:
		waveform.call("set_progress_ratio", clampf(progress_ratio, 0.0, 1.0))


func _refresh_audio_button_states(_changed_audio_id: String = "") -> void:
	if audio_manager == null:
		return

	var current_audio_id: String = str(audio_manager.call("get_current_audio_id"))
	var playing: bool = bool(audio_manager.call("is_playing"))
	var paused: bool = bool(audio_manager.call("is_paused"))

	for audio_clue_value in _audio_card_controls.keys():
		var audio_clue_id: String = str(audio_clue_value)
		var controls: Dictionary = _audio_card_controls[audio_clue_id]
		var play_button: Button = controls.get("play_button") as Button
		var track_label_text: String = str(controls.get("track_label", "Track 03"))

		if play_button == null or not bool(controls.get("available", false)):
			continue

		if audio_clue_id == current_audio_id and playing:
			play_button.icon = ICON_PAUSE
			play_button.tooltip_text = "暂停 " + track_label_text
			_set_compact_audio_button_active(play_button, true)
		elif audio_clue_id == current_audio_id and paused:
			play_button.icon = ICON_PLAY
			play_button.tooltip_text = "继续播放 " + track_label_text
			_set_compact_audio_button_active(play_button, false)
		elif audio_clue_id == _audio_finished_id:
			play_button.icon = ICON_PLAY
			play_button.tooltip_text = "重播 " + track_label_text
			_set_compact_audio_button_active(play_button, false)
		else:
			play_button.icon = ICON_PLAY
			play_button.tooltip_text = "播放 " + track_label_text
			_set_compact_audio_button_active(play_button, false)


func _refresh_audio_markers(audio_clue_id: String) -> void:
	if not _audio_card_controls.has(audio_clue_id):
		return

	var controls: Dictionary = _audio_card_controls[audio_clue_id]
	var waveform: Control = controls.get("waveform") as Control
	var duration: float = float(controls.get("duration", 0.0))
	var marker_ratios := PackedFloat32Array()

	if duration > 0.0:
		for marker in runtime_state.get_audio_markers_for_clue(audio_clue_id):
			var marker_time: float = float(marker.get("time_seconds", 0.0))
			marker_ratios.append(clampf(marker_time / duration, 0.0, 1.0))

	if waveform != null:
		waveform.call("set_marker_ratios", marker_ratios)


func _show_audio_feedback(audio_clue_id: String, text: String) -> void:
	if not _audio_card_controls.has(audio_clue_id):
		return

	var controls: Dictionary = _audio_card_controls[audio_clue_id]
	var feedback_label: Label = controls.get("feedback_label") as Label

	if feedback_label == null:
		return

	_audio_feedback_generation += 1
	var feedback_generation: int = _audio_feedback_generation
	feedback_label.text = text
	await get_tree().create_timer(1.8).timeout

	if feedback_generation == _audio_feedback_generation and is_instance_valid(feedback_label):
		feedback_label.text = ""


func _stop_audio_for_context_change() -> void:
	_cancel_audio_waveform_drags()

	if audio_manager == null:
		return

	if str(audio_manager.call("get_current_audio_id")) != "":
		audio_manager.call("stop_audio")

	_audio_finished_id = ""
	_refresh_audio_button_states()


func _cancel_audio_waveform_drags() -> void:
	for controls_value in _audio_card_controls.values():
		if not (controls_value is Dictionary):
			continue

		var waveform: Control = (controls_value as Dictionary).get("waveform") as Control

		if waveform != null and is_instance_valid(waveform):
			waveform.call("cancel_playhead_drag")


func _get_audio_card_duration(audio_clue_id: String) -> float:
	if not _audio_card_controls.has(audio_clue_id):
		return 0.0

	var controls: Dictionary = _audio_card_controls[audio_clue_id]
	return float(controls.get("duration", 0.0))


func _format_audio_time(time_seconds: float) -> String:
	var safe_time: float = 0.0 if is_nan(time_seconds) or is_inf(time_seconds) else maxf(0.0, time_seconds)
	var total_seconds: int = int(floor(safe_time))
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60

	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]

	return "%02d:%02d" % [minutes, seconds]


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
		return "播放当前节点登记的音频线索"

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

			if not _choice_is_available(choice):
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


func _audio_action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", C_WHITE)
	button.add_theme_color_override("font_hover_color", C_WHITE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_disabled_color", C_SUBTEXT)
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE, C_BLUE, 1, 4))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 4))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 4))
	button.add_theme_stylebox_override("disabled", _style_box(C_PANEL_SOFT, C_DIVIDER, 1, 4))
	return button


func _compact_audio_track_button(icon_texture: Texture2D, tooltip: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.icon = icon_texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 14)
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(28, 24)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("icon_normal_color", C_BLUE)
	button.add_theme_color_override("icon_hover_color", C_WHITE)
	button.add_theme_color_override("icon_pressed_color", C_WHITE)
	button.add_theme_color_override("icon_focus_color", C_BLUE)
	button.add_theme_color_override("icon_disabled_color", C_MUTED)
	button.add_theme_stylebox_override("normal", _style_box(C_WHITE, C_LINE, 1, 1))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE, C_BLUE, 1, 1))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 1))
	button.add_theme_stylebox_override("focus", _style_box(C_WHITE, C_BLUE_DARK, 1, 1))
	button.add_theme_stylebox_override("disabled", _style_box(C_BG, C_DIVIDER, 1, 1))
	return button


func _set_compact_audio_button_active(button: Button, active: bool) -> void:
	button.add_theme_color_override("icon_normal_color", C_WHITE if active else C_BLUE)
	button.add_theme_color_override("icon_focus_color", C_WHITE if active else C_BLUE)
	button.add_theme_stylebox_override(
		"normal",
		_style_box(C_BLUE if active else C_WHITE, C_BLUE if active else C_LINE, 1, 1)
	)
	button.add_theme_stylebox_override(
		"focus",
		_style_box(C_BLUE if active else C_WHITE, C_BLUE_DARK, 1, 1)
	)


func _chapter_dropdown() -> OptionButton:
	var btn := OptionButton.new()
	btn.custom_minimum_size = Vector2(310, 38)
	btn.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	btn.add_theme_font_size_override("font_size", 29)
	btn.add_theme_color_override("font_color", C_BLUE)
	btn.add_theme_color_override("font_hover_color", C_BLUE)
	btn.add_theme_color_override("font_pressed_color", C_BLUE)
	btn.add_theme_color_override("font_hover_pressed_color", C_BLUE)
	btn.add_theme_color_override("font_focus_color", C_BLUE)
	btn.add_theme_color_override("font_disabled_color", C_BLUE)
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
	root_control.set_meta("nav_active", active)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	_fill_rect(panel)
	panel.add_theme_stylebox_override("panel", _style_box(C_BLUE_ACTIVE if active else C_WHITE, C_BLUE_DARK if active else C_LINE, 1, 4))
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

	var nav_icon := _icon(texture, Vector2(21, 21), C_WHITE if active else C_BLUE)
	nav_icon.name = "Icon"
	row.add_child(nav_icon)

	var label := _label(text, 16, C_WHITE if active else C_BLUE, FONT_SERIF_SEMIBOLD)
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var hit_button := _transparent_hit_button()
	hit_button.name = "HitButton"
	hit_button.mouse_entered.connect(_on_nav_button_hovered.bind(root_control, true))
	hit_button.mouse_exited.connect(_on_nav_button_hovered.bind(root_control, false))

	if scene_path != "":
		hit_button.pressed.connect(func():
			_change_scene_if_exists(scene_path)
		)

	root_control.add_child(hit_button)
	return root_control


func _get_nav_hit_button(nav_button: Control) -> Button:
	return nav_button.get_node("HitButton") as Button


func _on_nav_button_hovered(nav_button: Control, hovered: bool) -> void:
	if bool(nav_button.get_meta("nav_active", false)):
		return

	var panel: PanelContainer = nav_button.get_node("Panel") as PanelContainer
	var bg_color: Color = C_PANEL_SOFT if hovered else C_WHITE
	var border_color: Color = C_BLUE if hovered else C_LINE
	panel.add_theme_stylebox_override("panel", _style_box(bg_color, border_color, 1, 4))


func _set_nav_button_active(nav_button: Control, active: bool) -> void:
	if nav_button == null:
		return

	nav_button.set_meta("nav_active", active)

	var panel: PanelContainer = nav_button.get_node("Panel") as PanelContainer
	var nav_icon: TextureRect = nav_button.find_child("Icon", true, false) as TextureRect
	var label: Label = nav_button.find_child("Label", true, false) as Label

	panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_BLUE_ACTIVE if active else C_WHITE, C_BLUE_DARK if active else C_LINE, 1, 4)
	)
	# `_icon()` stores its tint in `modulate`. Updating only `self_modulate`
	# multiplies the new color by the old blue tint, so an activated icon can
	# remain blue. Replace the actual tint and keep self_modulate neutral.
	nav_icon.modulate = C_WHITE if active else C_BLUE
	nav_icon.self_modulate = C_WHITE
	label.add_theme_color_override("font_color", C_WHITE if active else C_BLUE)


func _open_settings_page() -> void:
	if _settings_source_context != "":
		return

	var source_context: String = _get_active_page_context()
	_settings_source_context = source_context
	_settings_previous_focus = get_viewport().gui_get_focus_owner()
	_stop_audio_for_context_change()
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)
	_case_status_generation += 1
	case_status_panel.visible = false
	_suspend_data_page_for_settings(source_context)
	get_viewport().gui_release_focus()
	_set_nav_button_active(story_nav_button, false)
	_set_nav_button_active(graph_nav_button, false)
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)
	_set_nav_button_active(settings_nav_button, true)
	settings_requested.emit(source_context)


func _suspend_data_page_for_settings(source_context: String) -> void:
	if source_context == "save" and save_view != null:
		save_view.call("suspend_for_settings")
	elif source_context == "load" and load_view != null:
		load_view.call("suspend_for_settings")


func _get_active_page_context() -> String:
	if _data_page_open:
		if save_view != null and save_view.visible:
			return "save"
		if load_view != null and load_view.visible:
			return "load"
	if graph_view != null and graph_view.visible:
		return "graph"
	return "story"


func restore_settings_context(source_context: String) -> void:
	if source_context == "save" and save_view != null:
		save_view.call("resume_from_settings")
	elif source_context == "load" and load_view != null:
		load_view.call("resume_from_settings")

	_set_nav_button_active(settings_nav_button, false)
	_set_nav_button_active(story_nav_button, source_context == "story")
	_set_nav_button_active(graph_nav_button, source_context == "graph")
	_set_nav_button_active(save_nav_button, source_context == "save")
	_set_nav_button_active(load_nav_button, source_context == "load")
	_settings_source_context = ""
	_restore_settings_previous_focus()


func _restore_settings_previous_focus() -> void:
	var focus_target: Control = _settings_previous_focus
	_settings_previous_focus = null

	if (
		focus_target != null
		and is_instance_valid(focus_target)
		and focus_target.is_visible_in_tree()
		and focus_target.focus_mode != Control.FOCUS_NONE
	):
		focus_target.call_deferred("grab_focus")


func _open_save_page() -> void:
	if save_view == null:
		_show_case_status("存档页面不可用")
		return

	_prepare_data_page_open()
	load_view.call("close_page")
	save_view.call("open_page")
	_set_data_page_nav_state(true, false)


func _open_load_page() -> void:
	if load_view == null:
		_show_case_status("读档页面不可用")
		return

	_prepare_data_page_open()
	save_view.call("close_page")
	load_view.call("open_page")
	_set_data_page_nav_state(false, true)


func _prepare_data_page_open() -> void:
	if not _data_page_open:
		_return_to_graph_view = graph_view.visible

	_data_page_open = true
	_stop_audio_for_context_change()
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)
	_case_status_generation += 1
	case_status_panel.visible = false
	story_view.visible = false
	graph_view.visible = false


func _return_from_data_page() -> void:
	_hide_data_pages()

	if _return_to_graph_view:
		_set_center_view(true)
	else:
		_set_center_view(false)


func _hide_data_pages() -> void:
	if save_view != null:
		save_view.call("close_page")

	if load_view != null:
		load_view.call("close_page")

	_data_page_open = false
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)


func _set_data_page_nav_state(save_active: bool, load_active: bool) -> void:
	_set_nav_button_active(backtrack_nav_button, false)
	_set_nav_button_active(story_nav_button, false)
	_set_nav_button_active(graph_nav_button, false)
	_set_nav_button_active(save_nav_button, save_active)
	_set_nav_button_active(load_nav_button, load_active)
	_set_nav_button_active(settings_nav_button, false)


func _on_manual_save_requested(slot_index: int) -> void:
	if save_manager == null:
		return

	var node_data: Dictionary = loader.get_node(runtime_state.current_node_id)
	var result: Dictionary = save_manager.save_manual(
		slot_index,
		_build_save_metadata(node_data),
		runtime_state.to_save_dictionary()
	)

	if save_view != null:
		save_view.call("report_save_result", result, slot_index)

	if not bool(result.get("success", false)):
		push_warning("MainUI: manual save failed: " + str(result.get("error", "")))


func _on_load_requested(slot_type: String, slot_index: int) -> void:
	if save_manager == null:
		return

	var load_result: Dictionary = (
		save_manager.load_autosave()
		if slot_type == "autosave"
		else save_manager.load_manual(slot_index)
	)

	if not bool(load_result.get("success", false)):
		_report_load_failure(str(load_result.get("error", "存档不可读取")))
		return

	var document_value: Variant = load_result.get("data", {})

	if not (document_value is Dictionary):
		_report_load_failure("存档根数据无效")
		return

	var document: Dictionary = document_value
	var runtime_value: Variant = document.get("runtime_state", {})

	if not (runtime_value is Dictionary):
		_report_load_failure("存档运行状态无效")
		return

	var runtime_data: Dictionary = runtime_value

	if not runtime_state.validate_save_dictionary(runtime_data):
		_report_load_failure("存档运行状态校验失败")
		return

	var loaded_node_id: String = str(runtime_data.get("current_node_id", ""))
	var loaded_node_data: Dictionary = loader.get_node(loaded_node_id)

	if loaded_node_data.is_empty():
		_report_load_failure("存档节点不存在于当前案件：" + loaded_node_id)
		return

	_stop_audio_for_context_change()
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)
	_graph_feedback_generation += 1
	_audio_feedback_generation += 1
	_case_status_generation += 1
	graph_status_panel.visible = false
	case_status_panel.visible = false

	if not runtime_state.apply_save_dictionary(runtime_data):
		_report_load_failure("应用存档运行状态失败")
		return

	_node_history.clear()
	_render_node(loaded_node_data)
	story_scroll.scroll_vertical = 0
	_hide_data_pages()
	story_view.visible = true
	graph_view.visible = false
	_set_nav_button_active(story_nav_button, true)
	_set_nav_button_active(graph_nav_button, false)
	_show_case_status("存档读取成功")


func _report_load_failure(error: String) -> void:
	push_warning("MainUI: load failed: " + error)

	if load_view != null:
		load_view.call("report_load_failure", error)


func _write_disk_autosave(node_data: Dictionary) -> bool:
	if save_manager == null:
		return false

	var result: Dictionary = save_manager.save_autosave(
		_build_save_metadata(node_data),
		runtime_state.to_save_dictionary()
	)

	if not bool(result.get("success", false)):
		var error: String = str(result.get("error", "未知错误"))
		push_warning("MainUI: autosave failed: " + error)
		_show_case_status("自动存档写入失败")
		return false

	return true


func _build_save_metadata(node_data: Dictionary) -> Dictionary:
	return {
		"chapter_title": loader.get_chapter_title(),
		"node_title": str(node_data.get("title", "未知节点")),
		"node_id": str(node_data.get("node_id", runtime_state.current_node_id))
	}


func _record_current_node_for_history(target_node_id: String) -> void:
	if runtime_state == null or loader == null:
		return

	var current_node_id: String = runtime_state.current_node_id

	if current_node_id == "" or current_node_id == target_node_id:
		return

	var current_data: Dictionary = loader.get_node(current_node_id)

	if not _is_valid_backtrack_node(current_data):
		if not _node_history.is_empty() and _node_history[_node_history.size() - 1] == target_node_id:
			_node_history.remove_at(_node_history.size() - 1)
		return

	_node_history.append(current_node_id)


func _is_valid_backtrack_node(node_data: Dictionary) -> bool:
	if node_data.is_empty() or bool(node_data.get("graph_only", false)):
		return false

	var icon_key: String = str(node_data.get("icon_key", ""))
	var node_type: String = str(node_data.get("node_type", ""))
	return (
		icon_key != "false"
		and icon_key != "fatal"
		and not node_type.contains("错误")
		and not node_type.contains("失败")
	)


func _has_backtrack_target() -> bool:
	if runtime_state == null or loader == null:
		return false

	for history_index in range(_node_history.size() - 1, -1, -1):
		var node_id: String = _node_history[history_index]

		if (
			node_id != runtime_state.current_node_id
			and _is_valid_backtrack_node(loader.get_node(node_id))
		):
			return true

	return false


func _pop_backtrack_target() -> String:
	while not _node_history.is_empty():
		var last_index: int = _node_history.size() - 1
		var node_id: String = _node_history[last_index]
		_node_history.remove_at(last_index)

		if (
			node_id != runtime_state.current_node_id
			and _is_valid_backtrack_node(loader.get_node(node_id))
		):
			return node_id

	return ""


func _update_backtrack_button_state() -> void:
	if backtrack_nav_button == null:
		return

	_get_nav_hit_button(backtrack_nav_button).disabled = not _has_backtrack_target()


func _on_backtrack_pressed() -> void:
	var previous_node_id: String = _pop_backtrack_target()

	if previous_node_id == "":
		_update_backtrack_button_state()
		_show_case_status("没有更早的调查节点。")
		return

	var previous_data: Dictionary = loader.get_node(previous_node_id)

	if previous_data.is_empty():
		_update_backtrack_button_state()
		return

	var node_before_backtrack: String = runtime_state.current_node_id
	_stop_audio_for_context_change()
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)
	_hide_data_pages()

	if (
		_is_tutorial_case()
		and node_before_backtrack == "tutorial_0003"
		and previous_node_id in ["tutorial_0002a", "tutorial_0002b", "tutorial_0002c"]
	):
		runtime_state.flags["backtrack_tutorial_completed"] = true

	runtime_state.current_node_id = previous_node_id
	runtime_state.unlocked_nodes[previous_node_id] = true
	_render_node(previous_data)
	story_scroll.scroll_vertical = 0
	story_view.visible = true
	graph_view.visible = false
	_set_nav_button_active(backtrack_nav_button, false)
	_set_nav_button_active(story_nav_button, true)
	_set_nav_button_active(graph_nav_button, false)
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)
	_set_nav_button_active(settings_nav_button, false)


func _show_story_view() -> void:
	_hide_data_pages()
	_set_center_view(false)


func _show_graph_view() -> void:
	_hide_data_pages()
	_set_center_view(true)

	if (
		_is_tutorial_case()
		and runtime_state.current_node_id == "tutorial_0006"
		and bool(runtime_state.flags.get("tutorial_keyword_intro_viewed", false))
	):
		_mark_tutorial_flag(
			"tutorial_graph_opened",
			"先选择一个关键词节点，再选择与它相关的剧情节点。"
		)


func _set_center_view(show_graph: bool) -> void:
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)

	if show_graph:
		_stop_audio_for_context_change()

	story_view.visible = not show_graph
	graph_view.visible = show_graph
	_set_nav_button_active(backtrack_nav_button, false)
	_set_nav_button_active(story_nav_button, not show_graph)
	_set_nav_button_active(graph_nav_button, show_graph)
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)
	_set_nav_button_active(settings_nav_button, false)

	if show_graph:
		var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)

		if not current_data.is_empty():
			_render_right_panel(current_data)

		call_deferred("_scroll_graph_to_current")
		call_deferred("_apply_scrollbar_styles")


func _scroll_graph_to_current() -> void:
	if graph_scroll == null or not graph_view.visible:
		return

	await get_tree().process_frame
	await get_tree().process_frame

	if not graph_view.visible:
		return

	var viewport_size: Vector2 = graph_scroll.size
	var horizontal_bar: HScrollBar = graph_scroll.get_h_scroll_bar()
	var vertical_bar: VScrollBar = graph_scroll.get_v_scroll_bar()

	if vertical_bar.visible:
		viewport_size.x -= vertical_bar.size.x

	if horizontal_bar.visible:
		viewport_size.y -= horizontal_bar.size.y

	viewport_size.x = maxf(1.0, viewport_size.x)
	viewport_size.y = maxf(1.0, viewport_size.y)

	var horizontal_target := 0.0
	var vertical_target := 0.0
	var current_control: Control = _find_graph_node_control(runtime_state.current_node_id)

	if current_control != null:
		var current_center: Vector2 = current_control.position + current_control.size * 0.5
		horizontal_target = current_center.x - viewport_size.x * GRAPH_CURRENT_ANCHOR.x
		vertical_target = current_center.y - viewport_size.y * GRAPH_CURRENT_ANCHOR.y
	else:
		var current_position: Vector2 = loader.get_graph_node_position(runtime_state.current_node_id)

		if current_position.x >= 0.0 and current_position.y >= 0.0:
			var fallback_center: Vector2 = current_position + GRAPH_NODE_SIZE * 0.5
			horizontal_target = fallback_center.x - viewport_size.x * GRAPH_CURRENT_ANCHOR.x
			vertical_target = fallback_center.y - viewport_size.y * GRAPH_CURRENT_ANCHOR.y

	horizontal_target = clampf(horizontal_target, 0.0, horizontal_bar.max_value)
	vertical_target = clampf(vertical_target, 0.0, vertical_bar.max_value)
	graph_scroll.scroll_horizontal = roundi(horizontal_target)
	graph_scroll.scroll_vertical = roundi(vertical_target)


func _find_graph_node_control(node_id: String) -> Control:
	for child in graph_canvas.get_children():
		if not (child is Control):
			continue

		var child_control: Control = child as Control

		if (
			bool(child_control.get_meta("graph_node_card", false))
			and str(child_control.get_meta("graph_node_id", "")) == node_id
			and child_control.visible
			and not child_control.is_queued_for_deletion()
		):
			return child_control

	return null


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
	var panel := PanelContainer.new()
	panel.set_meta("keyword_full_text", text)
	panel.custom_minimum_size.y = 27.0
	panel.tooltip_text = text
	var box: StyleBoxFlat = _style_box(Color.TRANSPARENT, C_BLUE, 1, 2)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_keyword_tag_gui_input.bind(text, panel))

	var label := _label(text, 14, C_BLUE, FONT_SERIF_REGULAR)
	label.name = "KeywordLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.tooltip_text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _on_keyword_tag_gui_input(event: InputEvent, text: String, tag: Control) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton

	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	_show_keyword_context_menu(text, tag.global_position + mouse_event.position)
	get_viewport().set_input_as_handled()


func _show_keyword_context_menu(text: String, global_position: Vector2) -> void:
	_close_keyword_context_menu()
	var instances: Array[Dictionary] = runtime_state.get_keyword_instances_by_normalized_text(text)
	var panel := PanelContainer.new()
	panel.name = "KeywordContextMenu"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 140
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 4))
	root.add_child(panel)
	keyword_context_menu = panel

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := _label(text, 16, C_BLUE, FONT_SERIF_SEMIBOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.tooltip_text = text
	box.add_child(title)

	if instances.is_empty():
		var preset_feedback := _label("案件预设关键词不可删除", 13, C_SUBTEXT, FONT_SERIF_REGULAR)
		preset_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(preset_feedback)
	else:
		for instance in instances:
			var instance_id: String = str(instance.get("instance_id", ""))
			var source_node_id: String = str(instance.get("source_node_id", ""))
			var source_data: Dictionary = loader.get_node(source_node_id)
			var source_title: String = str(source_data.get("title", "来源记录"))
			var connected: bool = runtime_state.is_keyword_instance_connected(instance_id)
			var row_button := Button.new()
			row_button.text = (
				"该关键词已用于推断，无法删除"
				if connected
				else "删除｜来源：" + source_title
			)
			row_button.tooltip_text = "来源：" + source_title
			row_button.disabled = connected
			row_button.focus_mode = Control.FOCUS_ALL
			row_button.mouse_filter = Control.MOUSE_FILTER_STOP
			row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row_button.add_theme_font_override("font", FONT_SERIF_REGULAR)
			row_button.add_theme_font_size_override("font_size", 13)
			row_button.add_theme_color_override("font_color", C_BLUE)
			row_button.add_theme_color_override("font_disabled_color", C_MUTED)
			row_button.add_theme_stylebox_override("normal", _style_box(C_PANEL_SOFT, C_LINE, 1, 3))
			row_button.add_theme_stylebox_override("hover", _style_box(C_PANEL_SOFT, C_BLUE, 1, 3))
			row_button.add_theme_stylebox_override("pressed", _style_box(C_PANEL_SOFT, C_BLUE_DARK, 1, 3))
			row_button.add_theme_stylebox_override("disabled", _style_box(C_BG, C_DIVIDER, 1, 3))
			row_button.pressed.connect(_remove_keyword_instance.bind(instance_id))
			box.add_child(row_button)

	panel.reset_size()
	panel.position = global_position - root.global_position
	call_deferred("_clamp_keyword_context_menu")


func _clamp_keyword_context_menu() -> void:
	if keyword_context_menu == null or not is_instance_valid(keyword_context_menu):
		return

	var left_limit: float = 8.0
	var right_limit: float = minf(float(LEFT_PANEL_WIDTH) - 8.0, root.size.x - 8.0)
	var top_limit: float = float(TOP_BAR_HEIGHT) + 8.0
	var bottom_limit: float = root.size.y - 8.0
	keyword_context_menu.position.x = clampf(
		keyword_context_menu.position.x,
		left_limit,
		maxf(left_limit, right_limit - keyword_context_menu.size.x)
	)
	keyword_context_menu.position.y = clampf(
		keyword_context_menu.position.y,
		top_limit,
		maxf(top_limit, bottom_limit - keyword_context_menu.size.y)
	)


func _remove_keyword_instance(instance_id: String) -> void:
	var result: Dictionary = runtime_state.remove_keyword(instance_id)

	if not bool(result.get("success", false)):
		if str(result.get("reason", "")) == "connected":
			_show_case_status("该关键词已用于推断，无法删除")
		else:
			_show_case_status("关键词删除失败")
		return

	if _selected_keyword_instance_id == instance_id:
		_cancel_keyword_connection_selection(false)

	_close_keyword_context_menu()
	_refresh_keyword_grid()
	_render_graph_view()
	var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)

	if not current_data.is_empty():
		_render_story_body(current_data)

	_show_case_status("关键词已删除")


func _close_keyword_context_menu() -> void:
	if keyword_context_menu != null and is_instance_valid(keyword_context_menu):
		keyword_context_menu.queue_free()

	keyword_context_menu = null


func _update_keyword_tag_widths() -> void:
	if keyword_grid == null or keyword_width_container == null:
		return

	var available_width: float = (
		keyword_width_container.size.x
		- float(keyword_width_container.get_theme_constant("margin_left"))
		- float(keyword_width_container.get_theme_constant("margin_right"))
	)

	if available_width <= 0.0:
		return

	for child in keyword_grid.get_children():
		if not (child is PanelContainer) or child.is_queued_for_deletion():
			continue

		var panel: PanelContainer = child as PanelContainer
		var label: Label = panel.get_node_or_null("KeywordLabel") as Label

		if label == null:
			continue

		var full_text: String = str(panel.get_meta("keyword_full_text", label.text))
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var text_width: float = font.get_string_size(
			full_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x
		panel.custom_minimum_size.x = minf(ceilf(text_width + 16.0), available_width)

	keyword_grid.queue_sort()


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
	btn.add_theme_stylebox_override("disabled", _style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
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


func _apply_scrollbar_styles() -> void:
	if story_scroll != null:
		_apply_scrollbar_style(story_scroll.get_v_scroll_bar(), true)

	if graph_scroll != null:
		_apply_scrollbar_style(graph_scroll.get_v_scroll_bar(), true)
		_apply_scrollbar_style(graph_scroll.get_h_scroll_bar(), false)


func _apply_scrollbar_style(bar: ScrollBar, vertical: bool) -> void:
	# 默认保持低对比度；鼠标悬停时才切换为界面主蓝色。
	var scrollbar_track_color := Color("#EDF2FC")
	var scrollbar_idle_color := Color("#BFD0F6")

	bar.custom_minimum_size = Vector2(8, 0) if vertical else Vector2(0, 8)
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

	if action == "return_to_archive":
		_stop_audio_for_context_change()
		_hide_keyword_action()
		_cancel_keyword_connection_selection(false)
		archive_requested.emit("case_01" if _is_tutorial_case() else loader.get_current_case_id())
		return

	if action == "play_audio":
		var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)
		var audio_clues: Variant = current_data.get("audio_clues", [])
		var audio_clue_id: String = _first_array_value(audio_clues, "")

		if audio_clue_id != "":
			_on_audio_play_pressed(audio_clue_id)
		else:
			push_warning("MainUI: current node has no audio clue to play.")
			_show_case_status("当前节点没有可播放的音频")

		return

	if action == "load_last_safe_autosave":
		var safe_id: String = runtime_state.last_safe_autosave_node_id

		if safe_id != "":
			if _is_tutorial_case() and runtime_state.current_node_id == "tutorial_0008e":
				runtime_state.flags["tutorial_returned_safe"] = true

			_show_node(safe_id)
		else:
			push_warning("MainUI: no safe autosave node is available.")
			_show_case_status("当前没有可返回的安全节点")

		return

	var target_node_id: String = _get_choice_target_node_id(choice)

	if target_node_id == "":
		push_warning("MainUI: choice has no target node: " + str(choice.get("title", "")))
		return

	if _is_tutorial_case():
		_mark_tutorial_flag(
			"tutorial_choice_completed",
			"你作出的选择会改变当前看到的调查记录。"
		)

	_show_node(target_node_id)


func _apply_node_flags(node_data: Dictionary) -> void:
	var flags_value: Variant = node_data.get("set_flags", {})

	if not (flags_value is Dictionary):
		return

	for flag_value in (flags_value as Dictionary).keys():
		var flag_name: String = str(flag_value)
		var enabled_value: Variant = (flags_value as Dictionary).get(flag_value, false)

		if flag_name != "" and enabled_value is bool:
			runtime_state.flags[flag_name] = bool(enabled_value)


func _node_marks_case_completed(node_data: Dictionary) -> bool:
	var completion_flag: String = str(_case_descriptor.get("completion_flag", ""))
	var flags_value: Variant = node_data.get("set_flags", {})

	return (
		completion_flag != ""
		and flags_value is Dictionary
		and bool((flags_value as Dictionary).get(completion_flag, false))
	)


func _is_tutorial_case() -> bool:
	return str(_case_descriptor.get("case_type", "")) == "tutorial"


func _mark_tutorial_flag(flag_name: String, message: String) -> void:
	if not _is_tutorial_case() or bool(runtime_state.flags.get(flag_name, false)):
		return

	runtime_state.flags[flag_name] = true
	_refresh_current_goal()

	if message != "":
		_show_case_status(message)


func _change_scene_if_exists(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("MainUI: scene not found: " + scene_path)
		return

	get_tree().change_scene_to_file(scene_path)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
