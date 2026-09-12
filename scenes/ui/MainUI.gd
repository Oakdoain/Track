extends Control

signal initialization_succeeded
signal initialization_failed(message: String)
signal settings_requested(source_context: String)
signal archive_requested(preferred_case_id: String)
signal case_completion_requested(case_id: String)

const AudioWaveformPlaceholder := preload("res://scripts/case/AudioWaveformPlaceholder.gd")
const CaseGraphCanvasScript := preload("res://scripts/case/CaseGraphCanvas.gd")
const GraphDashedBorderScript := preload("res://scripts/case/GraphDashedBorder.gd")
const GraphGridBackgroundScript := preload("res://scripts/case/GraphGridBackground.gd")
const NarrativeGraphLayoutScript := preload("res://scripts/case/NarrativeGraphLayout.gd")
const KenneyAssetCatalog := preload("res://scripts/ui/KenneyAssetCatalog.gd")
const TutorialModalScript := preload("res://scripts/ui/TutorialModal.gd")
const PhoneManagerScript := preload("res://scripts/phone/PhoneManager.gd")
const ContactsViewScript := preload("res://scripts/ui/ContactsView.gd")
const PhoneCallViewScript := preload("res://scripts/ui/PhoneCallView.gd")
const InvestigationTimelineViewScript := preload("res://scripts/ui/InvestigationTimelineView.gd")
const TextRevealControllerScript := preload("res://scripts/ui/TextRevealController.gd")
const TutorialAttentionPulseScript := preload("res://scripts/ui/TutorialAttentionPulse.gd")
const VoiceBlipPlayerScript := preload("res://scripts/audio/VoiceBlipPlayer.gd")
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
const GRAPH_INFERENCE_NODE_SIZE := Vector2(300, 96)
const GRAPH_CURRENT_ANCHOR := Vector2(0.5, 0.32)
const KEYWORD_GRAPH_MIN_SIZE := Vector2(150, 36)
const KEYWORD_GRAPH_MAX_WIDTH := 220.0
const KEYWORD_GRAPH_GAP := 8.0
const GRAPH_STATUS_SIZE := Vector2(340, 76)
const CASE_STATUS_SIZE := Vector2(380, 48)
const KEYWORD_META_PREFIX := "keyword://"
const KEYWORD_POPUP_MAX_WIDTH := 220.0
const KEYWORD_POPUP_OFFSET := Vector2(16.0, 16.0)
const KEYWORD_POPUP_VIEW_MARGIN := 8.0
const NAV_HOVER_DURATION := 0.12
const NAV_PRESS_DURATION := 0.07
const NAV_RELEASE_DURATION := 0.12

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
const C_KENNEY_BLUE := Color("#143FA4")
const C_KENNEY_DISABLED := Color("#9AADE8")
const C_WARNING := Color("#9E2F3E")

const FONT_PUBLIC_REGULAR := preload("res://assets/fonts/PublicSans-Regular.ttf")
const FONT_MONO_REGULAR := preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const FONT_MONO_MEDIUM := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const FONT_SERIF_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")

const ICON_STEP_BACK := preload("res://assets/icons/lucide/step-back.svg")
const ICON_BOOK_OPEN := preload("res://assets/icons/lucide/book-open.svg")
const ICON_GIT_BRANCH := preload("res://assets/icons/lucide/git-branch.svg")
const ICON_TIMELINE := preload("res://assets/icons/lucide/chart-gantt.svg")
const ICON_MOUSE_LEFT := preload("res://assets/icons/lucide/mouse-left.svg")
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
const ICON_LIGHTBULB := preload("res://assets/icons/lucide/lightbulb.svg")
const ICON_LOCK := preload("res://assets/icons/lucide/lock.svg")
const ICON_PLAY := preload("res://assets/icons/lucide/play.svg")
const ICON_PAUSE := preload("res://assets/icons/lucide/pause.svg")

var _last_viewport_size: Vector2 = Vector2.ZERO

var root: Control
var bg: ColorRect
var left_panel: Control
var story_view: Control
var graph_view: Control
var timeline_view: Control
var timeline_view_controller: InvestigationTimelineView
var top_title_label: Label
var backtrack_nav_button: Control
var story_nav_button: Control
var graph_nav_button: Control
var timeline_nav_button: Control
var save_nav_button: Control
var load_nav_button: Control
var settings_nav_button: Control
var save_view: Control
var load_view: Control
var _data_page_open: bool = false
var _return_to_graph_view: bool = false
var _return_center_page: String = "story"
var _settings_source_context: String = ""
var _settings_previous_focus: Control

var chapter_small_label: Label
var chapter_dropdown: OptionButton
var chapter_intro_label: Label

var loader: CaseDataLoader
var runtime_state: CaseRuntimeState
var audio_manager: Node
var ui_sound_manager: Node
var cursor_manager: Node
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
var _audio_waveform_drag_state: Dictionary = {}
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

var graph_scroll: ScrollContainer
var graph_grid_background: GraphGridBackground
var graph_zoom_container: Control
var graph_canvas: CaseGraphCanvas
var graph_status_panel: PanelContainer
var graph_status_icon: TextureRect
var graph_status_label: Label
var _selected_keyword_instance_id: String = ""
var _graph_feedback_generation: int = 0
var _keyword_graph_layout: Dictionary = {}
var _graph_node_positions: Dictionary = {}
var _graph_node_sizes: Dictionary = {}
var _graph_node_depths: Dictionary = {}
var _graph_zoom: float = 1.0
var _graph_has_fit: bool = false
var _graph_pan_active: bool = false
var _graph_pan_dragged: bool = false
var _graph_pan_start_mouse := Vector2.ZERO
var _graph_pan_start_scroll := Vector2.ZERO
var _graph_canvas_size := Vector2.ZERO
var _active_path_transition_indices: Dictionary = {}

var tutorial_modal: Control
var _tutorial_modal_queue: Array[Dictionary] = []
var _tutorial_modal_show_scheduled: bool = false
var _failure_hint_modal_active: bool = false
var _save_error_modal_active: bool = false

var current_node_title: Label
var current_node_body: Label
var clue_list: VBoxContainer

var attr_type_value: Label
var attr_location_value: Label
var attr_character_value: Label
var attr_autosave_value: Label

var phone_manager: PhoneManager
var case_action_manager: CaseActionManager
var right_tab_bar: HBoxContainer
var node_info_tab_button: Button
var contacts_tab_button: Button
var call_transcript_tab_button: Button
var node_info_view: Control
var contacts_view: ContactsView
var phone_call_view: PhoneCallView
var _active_right_tab: String = "node_info"
var text_reveal_controller: TextRevealController
var tutorial_attention_pulse: TutorialAttentionPulse
var voice_blip_player: VoiceBlipPlayer
var _story_interactions_locked: bool = false
var _current_reveal_node_data: Dictionary = {}
var _presentation_paused: bool = false

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
	_setup_tutorial_assets()
	_setup_text_reveal_system()
	_setup_case_action_system()
	if not _initialize_case_for_startup():
		initialization_failed.emit(
			_initialization_error if _initialization_error != "" else "案件初始化失败"
		)
		return

	if not _setup_phone_system():
		initialization_failed.emit("电话数据加载失败")
		return

	initialization_succeeded.emit()
	call_deferred("_force_self_to_viewport")
	call_deferred("_apply_scrollbar_styles")


func _exit_tree() -> void:
	_stop_audio_for_context_change()
	_stop_node_typing_audio()
	if ui_sound_manager != null:
		ui_sound_manager.call("stop_phone_audio")

	if _is_tutorial_case() and cursor_manager != null:
		cursor_manager.call("deactivate_tutorial")


func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	if viewport_size != _last_viewport_size:
		_force_self_to_viewport()

	_refresh_audio_progress_display()
	var should_pause_presentation := _is_presentation_timing_paused()
	if should_pause_presentation != _presentation_paused:
		_presentation_paused = should_pause_presentation
		if ui_sound_manager != null:
			ui_sound_manager.call("set_presentation_paused", _presentation_paused)
		if voice_blip_player != null:
			voice_blip_player.set_paused(_presentation_paused)
		if tutorial_attention_pulse != null:
			tutorial_attention_pulse.set_paused(_presentation_paused)
	if not _presentation_paused and text_reveal_controller != null:
		text_reveal_controller.update(delta)
	if not _presentation_paused and phone_manager != null:
		phone_manager.update(delta)


func _input(event: InputEvent) -> void:
	if _graph_pan_active:
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			var delta := motion.global_position - _graph_pan_start_mouse
			if delta.length() >= 5.0:
				_graph_pan_dragged = true
				_set_tutorial_cursor("drag")
			graph_scroll.scroll_horizontal = maxi(0, roundi(_graph_pan_start_scroll.x - delta.x))
			graph_scroll.scroll_vertical = maxi(0, roundi(_graph_pan_start_scroll.y - delta.y))
			_sync_graph_view_to_runtime()
			_update_graph_grid()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
			_graph_pan_active = false
			_set_tutorial_cursor("default")
			get_viewport().set_input_as_handled()
			return

	if tutorial_modal != null and is_instance_valid(tutorial_modal):
		return

	if keyword_context_menu != null and is_instance_valid(keyword_context_menu):
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton

			if (
				mouse_event.pressed
				and mouse_event.button_index == MOUSE_BUTTON_LEFT
				and not keyword_context_menu.get_global_rect().has_point(mouse_event.global_position)
			):
				_close_keyword_context_menu()

	if event.is_action_pressed("ui_cancel_layer"):
		if keyword_context_menu != null:
			_close_keyword_context_menu()
			get_viewport().set_input_as_handled()
			return
		if _selected_keyword_instance_id != "":
			_cancel_keyword_connection_selection(true)
			get_viewport().set_input_as_handled()
			return
		if not _audio_waveform_drag_state.is_empty():
			_cancel_active_audio_scrub()
			get_viewport().set_input_as_handled()
			return
		if _data_page_open:
			_return_from_data_page()
			get_viewport().set_input_as_handled()
		return

	if _settings_source_context != "" or _data_page_open:
		return

	if _story_interactions_locked and event.is_action_pressed("ui_confirm"):
		_skip_current_text_reveal()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_story_graph"):
		if _selected_keyword_instance_id != "":
			_cancel_keyword_connection_selection(true)
		else:
			_show_story_view() if graph_view.visible or (timeline_view != null and timeline_view.visible) else _show_graph_view()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("audio_play_pause") and story_view.visible and _audio_waveform_drag_state.is_empty():
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return
		var current_data := loader.get_node(runtime_state.current_node_id)
		var audio_id := _first_array_value(current_data.get("audio_clues", []), "")
		if audio_id != "":
			_on_audio_play_pressed(audio_id)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_focus_up") or event.is_action_pressed("ui_focus_down"):
		if _story_interactions_locked:
			get_viewport().set_input_as_handled()
			return
		_focus_story_choice(-1 if event.is_action_pressed("ui_focus_up") else 1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_confirm"):
		if (
			phone_manager != null
			and phone_call_view != null
			and phone_call_view.visible
			and str(phone_manager.get_active_call().get("status", "")) == "incoming_waiting"
		):
			_on_phone_answer_pressed()
			get_viewport().set_input_as_handled()
			return
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is BaseButton:
			(focus_owner as BaseButton).pressed.emit()
			get_viewport().set_input_as_handled()
		return


func _focus_story_choice(direction: int) -> void:
	var buttons: Array[Button] = []
	for node in choice_list.find_children("*", "Button", true, false):
		if node is Button and not (node as Button).disabled:
			buttons.append(node as Button)
	if buttons.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := buttons.find(current)
	index = 0 if index < 0 else posmod(index + direction, buttons.size())
	buttons[index].grab_focus()


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
	title_box.custom_minimum_size.x = 340
	title_box.add_theme_constant_override("separation", 16)
	row.add_child(title_box)

	top_title_label = Label.new()
	top_title_label.name = "InvestigationTimeTitle"
	top_title_label.text = "叙事图谱 | --:--"
	top_title_label.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	top_title_label.add_theme_color_override("font_color", C_BLUE)
	top_title_label.add_theme_font_size_override("font_size", 28)
	top_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(top_title_label)

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

	timeline_nav_button = _nav_button(ICON_TIMELINE, "时间轴", false)
	row.add_child(timeline_nav_button)
	_get_nav_hit_button(timeline_nav_button).pressed.connect(_show_timeline_view)

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
	story_scroll.gui_input.connect(_on_story_reveal_gui_input)
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
	story_body_label.selection_enabled = true
	story_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_body_label.add_theme_font_override("normal_font", FONT_SERIF_REGULAR)
	story_body_label.add_theme_font_override("bold_font", FONT_SERIF_SEMIBOLD)
	story_body_label.add_theme_color_override("default_color", C_TEXT)
	story_body_label.add_theme_font_size_override("normal_font_size", 18)
	story_body_label.add_theme_constant_override("line_separation", 4)
	story_body_label.meta_clicked.connect(_on_story_keyword_meta_clicked)
	story_body_label.meta_hover_started.connect(_on_story_keyword_meta_hover_started)
	story_body_label.meta_hover_ended.connect(_on_story_keyword_meta_hover_ended)
	story_body_label.gui_input.connect(_on_story_body_selection_input)
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
	graph_view.clip_contents = true
	_fill_rect(graph_view)
	panel.add_child(graph_view)

	graph_grid_background = GraphGridBackgroundScript.new() as GraphGridBackground
	graph_grid_background.name = "GraphGridBackground"
	_fill_rect(graph_grid_background)
	graph_view.add_child(graph_grid_background)

	graph_scroll = ScrollContainer.new()
	graph_scroll.name = "GraphScroll"
	graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	graph_scroll.gui_input.connect(_on_graph_canvas_gui_input)
	_fill_rect(graph_scroll)
	graph_view.add_child(graph_scroll)
	graph_scroll.get_h_scroll_bar().value_changed.connect(_on_graph_scroll_value_changed)
	graph_scroll.get_v_scroll_bar().value_changed.connect(_on_graph_scroll_value_changed)

	graph_zoom_container = Control.new()
	graph_zoom_container.name = "GraphZoomContainer"
	graph_zoom_container.mouse_filter = Control.MOUSE_FILTER_PASS
	graph_zoom_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	graph_zoom_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	graph_scroll.add_child(graph_zoom_container)
	graph_canvas = CaseGraphCanvasScript.new()
	graph_canvas.name = "GraphCanvas"
	graph_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	graph_canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	graph_canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	graph_canvas.gui_input.connect(_on_graph_canvas_gui_input)
	graph_zoom_container.add_child(graph_canvas)

	graph_status_panel = _build_graph_status_panel()
	graph_view.add_child(graph_status_panel)

	timeline_view_controller = InvestigationTimelineViewScript.new() as InvestigationTimelineView
	timeline_view_controller.name = "TimelineView"
	timeline_view_controller.visible = false
	_fill_rect(timeline_view_controller)
	panel.add_child(timeline_view_controller)
	timeline_view = timeline_view_controller

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

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	graph_status_icon = TextureRect.new()
	graph_status_icon.custom_minimum_size = Vector2(24, 24)
	graph_status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	graph_status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	graph_status_icon.modulate = C_BLUE
	graph_status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_status_icon.visible = false
	row.add_child(graph_status_icon)

	graph_status_label = _label("", 14, C_BLUE, FONT_SERIF_SEMIBOLD)
	graph_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	graph_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(graph_status_label)
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


func _setup_tutorial_assets() -> void:
	ui_sound_manager = get_node_or_null("/root/UISoundManager")
	cursor_manager = get_node_or_null("/root/CursorManager")

	if not _is_tutorial_case():
		return

	if cursor_manager != null:
		cursor_manager.call("activate_tutorial")
	else:
		push_warning("MainUI: CursorManager autoload is unavailable.")

	if ui_sound_manager == null:
		push_warning("MainUI: UISoundManager autoload is unavailable.")


func _setup_text_reveal_system() -> void:
	text_reveal_controller = TextRevealControllerScript.new() as TextRevealController
	text_reveal_controller.state_changed.connect(_on_text_reveal_state_changed)
	text_reveal_controller.reveal_completed.connect(_on_text_reveal_completed)
	text_reveal_controller.post_delay_completed.connect(_on_text_reveal_post_delay_completed)


func _setup_case_action_system() -> void:
	case_action_manager = CaseActionManager.new()
	case_action_manager.configure(loader, runtime_state)
	case_action_manager.feedback_requested.connect(_show_case_status)
	case_action_manager.state_changed.connect(_on_case_action_state_changed)
	_refresh_investigation_time_ui()


func _on_case_action_state_changed() -> void:
	if runtime_state == null or loader == null:
		return
	_refresh_investigation_time_ui()
	var current_data := loader.get_node(runtime_state.current_node_id)
	if not current_data.is_empty():
		_render_right_panel(_resolve_node_state_variant(current_data))
		_refresh_current_goal()
	if phone_manager != null:
		_sync_phone_ui()


func _refresh_investigation_time_ui() -> void:
	if top_title_label != null:
		top_title_label.text = "叙事图谱 | %s" % (
			case_action_manager.format_time()
			if case_action_manager != null and case_action_manager.is_enabled()
			else "--:--"
		)
	if timeline_view_controller != null:
		timeline_view_controller.render(loader, runtime_state, case_action_manager)
	voice_blip_player = VoiceBlipPlayerScript.new() as VoiceBlipPlayer
	voice_blip_player.name = "VoiceBlipPlayer"
	add_child(voice_blip_player)
	tutorial_attention_pulse = TutorialAttentionPulseScript.new() as TutorialAttentionPulse
	tutorial_attention_pulse.name = "TutorialAttentionPulse"
	tutorial_attention_pulse.attention_peak.connect(_on_tutorial_attention_peak)
	add_child(tutorial_attention_pulse)


func _is_presentation_timing_paused() -> bool:
	return (
		_data_page_open
		or _settings_source_context != ""
		or (tutorial_modal != null and is_instance_valid(tutorial_modal))
	)


func _start_node_typing_audio() -> void:
	if ui_sound_manager != null:
		ui_sound_manager.call("start_node_typing")


func _stop_node_typing_audio() -> void:
	if ui_sound_manager != null:
		ui_sound_manager.call("stop_node_typing")


func _on_phone_transcript_character(profile_id: String, character: String) -> void:
	if voice_blip_player != null and not _presentation_paused:
		voice_blip_player.play_character(profile_id, character)


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RightPanel"
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, C_DIVIDER, 1, 0))

	var right_root := VBoxContainer.new()
	right_root.name = "RightPanelRoot"
	right_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_root.add_theme_constant_override("separation", 0)
	panel.add_child(right_root)

	right_tab_bar = HBoxContainer.new()
	right_tab_bar.name = "RightTabBar"
	right_tab_bar.custom_minimum_size.y = 48
	right_tab_bar.add_theme_constant_override("separation", 0)
	right_root.add_child(right_tab_bar)

	node_info_tab_button = _right_tab_button("节点信息", "node_info")
	node_info_tab_button.name = "NodeInfoTabButton"
	right_tab_bar.add_child(node_info_tab_button)
	contacts_tab_button = _right_tab_button("电话簿", "contacts")
	contacts_tab_button.name = "ContactsTabButton"
	right_tab_bar.add_child(contacts_tab_button)
	call_transcript_tab_button = _right_tab_button("通话记录", "call")
	call_transcript_tab_button.name = "CallTranscriptTabButton"
	call_transcript_tab_button.disabled = true
	call_transcript_tab_button.focus_mode = Control.FOCUS_NONE
	right_tab_bar.add_child(call_transcript_tab_button)

	var content := Control.new()
	content.name = "RightTabContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_root.add_child(content)

	var scroll := ScrollContainer.new()
	scroll.name = "RightPanelScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	node_info_view = scroll
	node_info_view.name = "NodeInfoView"

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", SIDE_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", SIDE_MARGIN_BOTTOM)
	scroll.add_child(margin)

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

	box.add_child(_section_title("操作说明"))

	clue_list = VBoxContainer.new()
	clue_list.add_theme_constant_override("separation", 7)
	box.add_child(clue_list)

	box.add_child(_right_divider())
	box.add_child(_section_title("节点属性"))

	box.add_child(_attr_row("类型", "type"))
	box.add_child(_attr_row("发生地点", "location"))
	box.add_child(_attr_row("相关角色", "character"))
	box.add_child(_attr_row("存档状态", "autosave"))

	contacts_view = ContactsViewScript.new() as ContactsView
	contacts_view.name = "ContactsView"
	contacts_view.visible = false
	content.add_child(contacts_view)
	contacts_view.contact_pressed.connect(_on_phone_contact_pressed)

	phone_call_view = PhoneCallViewScript.new() as PhoneCallView
	phone_call_view.name = "CallTranscriptView"
	phone_call_view.visible = false
	content.add_child(phone_call_view)
	phone_call_view.answer_pressed.connect(_on_phone_answer_pressed)
	phone_call_view.reject_pressed.connect(_on_phone_reject_pressed)
	phone_call_view.choice_pressed.connect(_on_phone_choice_pressed)
	phone_call_view.keyword_pressed.connect(_on_phone_keyword_pressed)

	_set_right_tab("node_info")

	return panel


func _right_tab_button(text: String, tab_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 48
	button.add_theme_font_override("font", FONT_SERIF_REGULAR)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_set_right_tab.bind(tab_id))
	return button


func _set_right_tab(tab_id: String) -> void:
	if tab_id == "call" and (call_transcript_tab_button == null or call_transcript_tab_button.disabled):
		tab_id = "node_info"
	_active_right_tab = tab_id
	if tab_id == "contacts" and runtime_state != null and bool(runtime_state.flags.get("tutorial_report_ready", false)):
		if tutorial_attention_pulse != null:
			tutorial_attention_pulse.stop_attention_event("tutorial_attention_phonebook")
		runtime_state.set_persistent_flag("tutorial_attention_phonebook_completed", true)
		runtime_state.set_persistent_flag("tutorial_attention_call_erin_ready", true)
		call_deferred("_start_erin_contact_attention")
	if node_info_view != null:
		node_info_view.visible = tab_id == "node_info"
	if contacts_view != null:
		contacts_view.visible = tab_id == "contacts"
	if phone_call_view != null:
		phone_call_view.visible = tab_id == "call"
		if tab_id == "call":
			phone_call_view.request_scroll_to_bottom()
	for entry in [
		{"button": node_info_tab_button, "id": "node_info"},
		{"button": contacts_tab_button, "id": "contacts"},
		{"button": call_transcript_tab_button, "id": "call"}
	]:
		var button: Button = entry.get("button")
		if button == null:
			continue
		var active := str(entry.get("id", "")) == tab_id
		var normal_text_color := C_WHITE if active else C_BLUE
		button.add_theme_color_override("font_color", normal_text_color)
		button.add_theme_color_override("font_hover_color", C_WHITE if active else C_BLUE)
		button.add_theme_color_override("font_pressed_color", C_WHITE)
		button.add_theme_color_override("font_focus_color", C_WHITE if active else C_BLUE)
		button.add_theme_color_override("font_disabled_color", C_MUTED)
		button.add_theme_stylebox_override("normal", _style_box(C_BLUE if active else C_BG, C_BLUE, 1, 0))
		button.add_theme_stylebox_override("hover", _style_box(C_BLUE_ACTIVE if active else C_PANEL_SOFT, C_BLUE, 1, 0))
		button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 0))
		button.add_theme_stylebox_override("focus", _style_box(C_BLUE_ACTIVE if active else C_PANEL_SOFT, C_BLUE, 2, 0))
		button.add_theme_stylebox_override("disabled", _style_box(C_BG, C_DIVIDER, 1, 0))


func _setup_phone_system() -> bool:
	phone_manager = PhoneManagerScript.new() as PhoneManager
	phone_manager.state_changed.connect(_sync_phone_ui)
	phone_manager.call_ended.connect(_on_phone_call_ended)
	phone_manager.feedback_requested.connect(_show_case_status)
	phone_manager.transcript_character_revealed.connect(_on_phone_transcript_character)
	if ui_sound_manager != null and ui_sound_manager.has_signal("call_ended_busy_finished"):
		var busy_finished := Callable(self, "_on_call_ended_busy_finished")
		if not ui_sound_manager.is_connected("call_ended_busy_finished", busy_finished):
			ui_sound_manager.connect("call_ended_busy_finished", busy_finished)
	if not phone_manager.configure(loader, runtime_state):
		return false
	_sync_phone_ui()
	if phone_manager.has_visible_call():
		_set_right_tab("call")
	return true


func _sync_phone_ui() -> void:
	if phone_manager == null:
		return
	if contacts_view != null:
		contacts_view.set_contacts(_phonebook_contacts_for_display())
	var active_call := phone_manager.get_active_call()
	if ui_sound_manager != null:
		ui_sound_manager.call("sync_phone_state", active_call)
	if active_call.is_empty() and voice_blip_player != null:
		voice_blip_player.stop()
	if active_call.is_empty() and ui_sound_manager != null:
		ui_sound_manager.call("stop_call_ended_busy")
	if str(active_call.get("status", "")) == "ending":
		if voice_blip_player != null:
			voice_blip_player.stop()
		if not bool(active_call.get("call_end_audio_started", false)) and not bool(active_call.get("call_end_audio_completed", false)):
			var started := bool(ui_sound_manager.call("play_call_ended_busy")) if ui_sound_manager != null else false
			phone_manager.mark_call_end_audio_started(started)
	var has_call := not active_call.is_empty()
	if call_transcript_tab_button != null:
		call_transcript_tab_button.visible = true
		call_transcript_tab_button.disabled = not has_call
		call_transcript_tab_button.focus_mode = Control.FOCUS_ALL if has_call else Control.FOCUS_NONE
		call_transcript_tab_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_call else Control.CURSOR_ARROW
	if has_call:
		phone_call_view.render_call(active_call, phone_manager.get_contact(str(active_call.get("contact_id", ""))))
	else:
		phone_call_view.clear_call()
		if _active_right_tab == "call":
			_set_right_tab("node_info")
	_refresh_current_goal()


func _on_phone_answer_pressed() -> void:
	_play_tutorial_ui_sound("ui_click")
	phone_manager.answer_incoming_call()


func _on_phone_reject_pressed() -> void:
	_play_tutorial_ui_sound("ui_click")
	phone_manager.reject_current_call()


func _on_phone_choice_pressed(choice_id: String) -> void:
	_play_tutorial_ui_sound("ui_click")
	if phone_manager != null and phone_manager.is_action_dispatch_active():
		var action := loader.get_action(choice_id)
		if action.is_empty() or case_action_manager == null:
			return
		var choice_text := "%s（耗时%d分钟）" % [str(action.get("action_name", choice_id)), int(action.get("duration", 0))]
		var result := case_action_manager.start_action(choice_id)
		phone_manager.complete_action_dispatch(choice_id, choice_text, str(result.get("message", "无法接受该项委托。")))
		_refresh_investigation_time_ui()
		return
	phone_manager.choose(choice_id)


func _on_phone_contact_pressed(contact_id: String) -> void:
	if contact_id == "assistant" and tutorial_attention_pulse != null:
		tutorial_attention_pulse.stop_attention_event("tutorial_attention_call_erin")
	if contact_id == "assistant" and runtime_state != null:
		runtime_state.set_persistent_flag("tutorial_attention_call_erin_completed", true)
	if case_action_manager != null and case_action_manager.is_enabled():
		_open_case_action_contact(contact_id)
		return
	if phone_manager.request_outgoing_call(contact_id):
		_set_right_tab("call")


func _phonebook_contacts_for_display() -> Array[Dictionary]:
	var contacts := phone_manager.get_discovered_contact_data()
	if case_action_manager == null or not case_action_manager.is_enabled():
		return contacts
	var result: Array[Dictionary] = []
	for contact in contacts:
		var display := contact.duplicate(true)
		var executor := str(display.get("dispatch_executor", ""))
		if executor != "":
			var actor_state := case_action_manager.get_actor_state(executor)
			display["status_text"] = "忙碌中" if str(actor_state.get("status", "idle")) == "busy" else "可接通"
		else:
			display["status_text"] = str(display.get("availability_text", "当前无法联系"))
		result.append(display)
	return result


func _open_case_action_contact(contact_id: String) -> void:
	var contact := phone_manager.get_contact(contact_id)
	if contact.is_empty():
		return
	var executor := str(contact.get("dispatch_executor", ""))
	var choices: Array[Dictionary] = []
	var message := str(contact.get("contact_message", contact.get("availability_text", "该角色此阶段尚未开放联系。")))
	if executor != "":
		var actor_state := case_action_manager.get_actor_state(executor)
		if str(actor_state.get("status", "idle")) == "busy":
			message = "对方当前正在执行“%s”，暂时无法接受新的委托；剩余约 %d 分钟。" % [
				str(actor_state.get("current_action_name", "调查任务")),
				int(actor_state.get("remaining_time", 0))
			]
		else:
			for action in case_action_manager.get_available_actions(executor):
				choices.append({
					"id": str(action.get("action_id", "")),
					"text": "%s（耗时%d分钟）" % [str(action.get("action_name", "调查行动")), int(action.get("duration", 0))]
				})
			message = "线路已接通。请选择需要委托的调查行动。" if not choices.is_empty() else "当前没有可以委托的新调查行动。"
	if phone_manager.begin_action_dispatch(contact_id, choices, message):
		_set_right_tab("call")


func _on_phone_keyword_pressed(
	keyword_id: String,
	keyword: String,
	_message_id: String,
	_local_position: Vector2
) -> void:
	var result := _record_keyword_from_source(
		keyword,
		runtime_state.current_node_id,
		"phone_transcript",
		keyword_id
	)
	if not bool(result.get("valid", false)):
		push_warning("MainUI: rejected phone transcript keyword: %s (%s)" % [keyword, str(result.get("reason", ""))])
		return
	_refresh_keyword_grid()
	_render_graph_view()
	_refresh_current_goal()
	_sync_phone_ui()
	phone_manager.notify_keyword_completed(keyword_id)
	var feedback := "已记录关键词：" + keyword
	if bool(result.get("contact_added", false)):
		feedback += "\n联系人已加入电话簿"
	_show_case_status(feedback)
	_play_tutorial_ui_sound("ui_keyword_extract")


func _record_keyword_from_source(
	keyword: String,
	source_node_id: String,
	source_scope: String,
	keyword_id: String = ""
) -> Dictionary:
	var effect_rule: Dictionary = (
		loader.get_keyword_effect(keyword_id)
		if keyword_id != ""
		else loader.find_keyword_effect(keyword, source_scope)
	)
	var canonical_keyword := str(effect_rule.get("keyword", keyword)) if not effect_rule.is_empty() else keyword
	if keyword_id != "":
		var scopes: Variant = effect_rule.get("source_scope", [])
		var normalized_matches: Variant = effect_rule.get("normalized_match_texts", [])
		if effect_rule.is_empty() or not (normalized_matches is Array) or not (normalized_matches as Array).has(runtime_state.normalize_keyword_text(keyword)) or not (scopes is Array) or not (scopes as Array).has(source_scope):
			return {"valid": false, "reason": "keyword_effect_mismatch"}
	if effect_rule.is_empty():
		return {"valid": false, "reason": "no_keyword_effect"}
	var source_nodes_value: Variant = effect_rule.get("source_nodes", [])
	if source_nodes_value is Array and not (source_nodes_value as Array).is_empty() and not (source_nodes_value as Array).has(source_node_id):
		return {"valid": false, "reason": "keyword_source_mismatch"}
	var add_result := runtime_state.add_keyword(canonical_keyword, source_node_id)
	var reason := str(add_result.get("reason", ""))
	if not bool(add_result.get("added", false)) and reason != "duplicate":
		return {"valid": false, "reason": reason}
	var contact_added := false
	if not effect_rule.is_empty():
		for effect_value in effect_rule.get("effects", []):
			if not (effect_value is Dictionary):
				continue
			var effect: Dictionary = effect_value
			match str(effect.get("type", "")):
				"discover_keyword":
					pass
				"add_contact":
					contact_added = runtime_state.add_discovered_contact(str(effect.get("contact_id", ""))) or contact_added
				"set_flag":
					var flag_id := str(effect.get("flag_id", ""))
					if bool(effect.get("persistent", false)):
						runtime_state.set_persistent_flag(flag_id, bool(effect.get("value", true)))
					elif flag_id != "":
						runtime_state.flags[flag_id] = bool(effect.get("value", true))
	runtime_state.capture_history_snapshot()
	return {
		"valid": true,
		"added": bool(add_result.get("added", false)),
		"duplicate": reason == "duplicate",
		"contact_added": contact_added,
		"keyword": canonical_keyword
	}


func _on_phone_call_ended(next_node_id: String) -> void:
	if ui_sound_manager != null:
		ui_sound_manager.call("stop_call_ended_busy")
	phone_call_view.clear_call()
	_set_right_tab("node_info")
	if next_node_id == "":
		return
	if loader.get_node(next_node_id).is_empty():
		push_error("MainUI: phone call completion node does not exist: " + next_node_id)
		return
	_show_node(next_node_id)


func _on_call_ended_busy_finished() -> void:
	if phone_manager != null:
		phone_manager.notify_call_end_audio_finished()


func _start_erin_contact_attention() -> void:
	if contacts_view == null or not bool(runtime_state.flags.get("tutorial_report_ready", false)) or not bool(runtime_state.flags.get("tutorial_attention_call_erin_ready", false)):
		return
	var contact_control := contacts_view.get_contact_control("assistant")
	if contact_control != null:
		_start_tutorial_attention(contact_control, "tutorial_attention_call_erin")


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
			if case_action_manager != null:
				case_action_manager.configure(loader, runtime_state)
				_refresh_investigation_time_ui()
			_suppress_disk_autosave = false
			_show_node(initial_node_id)
			return runtime_state.current_node_id == initial_node_id
		_:
			# Running MainUI.tscn directly remains useful for development, but it
			# must not overwrite the player's disk autosave.
			runtime_state.reset_runtime_state()
			if case_action_manager != null:
				case_action_manager.configure(loader, runtime_state)
				_refresh_investigation_time_ui()
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
	if case_action_manager != null:
		case_action_manager.configure(loader, runtime_state)
		_refresh_investigation_time_ui()

	_normalize_tutorial_investigation_flags()
	_prepare_graph_view_from_runtime()
	_stop_audio_for_context_change()
	_render_node(loaded_node_data)
	call_deferred("_apply_saved_graph_view")
	story_scroll.scroll_vertical = 0
	story_view.visible = true
	graph_view.visible = false
	if timeline_view != null:
		timeline_view.visible = false
	_set_nav_button_active(story_nav_button, true)
	_set_nav_button_active(graph_nav_button, false)
	_set_nav_button_active(timeline_nav_button, false)
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)
	_set_nav_button_active(settings_nav_button, false)
	_render_right_panel(loaded_node_data)
	return true


func _show_node(node_id: String, choice_key: String = "") -> void:
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

	var source_node_id := runtime_state.current_node_id
	if source_node_id != "" and source_node_id != node_id:
		_cancel_text_reveal_for_context_change()
	if runtime_state.visit_history.is_empty():
		runtime_state.initialize_visit_history(node_id)
	elif source_node_id != "" and source_node_id != node_id:
		runtime_state.capture_history_snapshot()
		runtime_state.commit_transition(source_node_id, node_id, choice_key)
	_stop_audio_for_context_change()
	_apply_node_flags(node_data)
	var autosave: bool = bool(node_data.get("autosave", false))
	runtime_state.set_current_node(node_id, autosave)
	runtime_state.capture_history_snapshot()
	_render_node(_resolve_node_state_variant(node_data))

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
	node_data = _resolve_node_state_variant(node_data)
	if tutorial_attention_pulse != null:
		tutorial_attention_pulse.stop_all_attention()
	_current_reveal_node_data = node_data.duplicate(true)
	_story_interactions_locked = _node_requires_text_reveal_lock(node_data)
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
	_render_graph_view()
	_render_right_panel(node_data)
	_update_backtrack_button_state()
	_start_node_text_reveal(node_data)

	call_deferred("_apply_scrollbar_styles")


func _node_requires_text_reveal_lock(node_data: Dictionary) -> bool:
	if runtime_state == null or runtime_state.is_reviewing_history():
		return not _next_incremental_section(node_data).is_empty()
	var node_id := str(node_data.get("node_id", runtime_state.current_node_id))
	var restored := runtime_state.active_text_reveal
	if str(restored.get("node_id", "")) == node_id and not bool(restored.get("completed", false)):
		return true
	if not _next_incremental_section(node_data).is_empty():
		return true
	var config_value: Variant = node_data.get("text_reveal", {})
	var config: Dictionary = config_value if config_value is Dictionary else {}
	return str(config.get("mode", "first_visit")) != "instant" and not runtime_state.is_node_revealed(node_id)


func _start_node_text_reveal(node_data: Dictionary) -> void:
	if text_reveal_controller == null:
		return
	var node_id := str(node_data.get("node_id", runtime_state.current_node_id))
	var config_value: Variant = node_data.get("text_reveal", {})
	var config: Dictionary = (config_value as Dictionary).duplicate(true) if config_value is Dictionary else {}
	var title_cps := maxf(1.0, float(config.get("title_cps", TextRevealController.DEFAULT_TITLE_CPS)))
	var body_cps := maxf(1.0, float(config.get("body_cps", TextRevealController.DEFAULT_BODY_CPS)))
	var sections: Array[Dictionary] = []
	var body_text := _get_story_body_text(node_data.get("body", []))
	var incremental_section := _next_incremental_section(node_data)
	var reveal_section_id := str(incremental_section.get("id", ""))
	var incremental_mode := reveal_section_id != "" and runtime_state.is_node_revealed(node_id)
	if incremental_mode:
		sections.append({
			"control": story_body_label,
			"text": body_text,
			"cps": body_cps,
			"initial_visible_characters": int(incremental_section.get("start_visible_characters", 0))
		})
		config["reveal_section_id"] = reveal_section_id
	else:
		var title_text := str(node_data.get("title", ""))
		if title_text != "":
			sections.append({"control": story_title_label, "text": title_text, "cps": title_cps})
		if body_text != "":
			sections.append({"control": story_body_label, "text": body_text, "cps": body_cps})
		var quote_text := str(node_data.get("quote", ""))
		if quote_text != "":
			sections.append({"control": quote_label, "text": quote_text, "cps": body_cps})
		config["reveal_section_id"] = ""
	var pending_events := _pending_after_reveal_events(node_data, reveal_section_id if incremental_mode else "")
	var default_post_delay := float(incremental_section.get("post_delay", config.get("post_delay", 0.8))) if incremental_mode else float(config.get("post_delay", 0.8))
	if not pending_events.is_empty():
		config["post_delay"] = maxf(0.0, float(pending_events[0].get("delay", default_post_delay)))
	elif incremental_mode:
		config["post_delay"] = maxf(0.0, default_post_delay)
	var restored := runtime_state.active_text_reveal
	var restoring_current := (
		str(restored.get("node_id", "")) == node_id
		and str(restored.get("reveal_section_id", "")) == str(config.get("reveal_section_id", ""))
		and not bool(restored.get("events_completed", false))
	)
	var mode := str(config.get("mode", "first_visit"))
	var animate_text := incremental_mode or (
		not runtime_state.is_reviewing_history()
		and mode != "instant"
		and not runtime_state.is_node_revealed(node_id)
	)
	if restoring_current and not bool(restored.get("completed", false)):
		animate_text = true
	text_reveal_controller.start(
		node_id,
		sections,
		config,
		restored if restoring_current else {},
		animate_text,
		not pending_events.is_empty()
	)
	if text_reveal_controller.is_revealing():
		_story_interactions_locked = true
		target_text_label.text = "阅读当前记录。"
		_render_choices(node_data)
		_start_node_typing_audio()
	else:
		_story_interactions_locked = false
		if incremental_mode:
			runtime_state.mark_section_revealed(reveal_section_id)
		else:
			runtime_state.mark_node_revealed(node_id)
		_render_choices(node_data)
		_render_right_panel(node_data)
		_render_tutorial_hints(node_data)
		if text_reveal_controller.events_completed():
			runtime_state.active_text_reveal.clear()


func _next_incremental_section(node_data: Dictionary) -> Dictionary:
	var sections_value: Variant = node_data.get("_incremental_sections", [])
	if not (sections_value is Array):
		return {}
	var restored_section_id := ""
	if str(runtime_state.active_text_reveal.get("node_id", "")) == str(node_data.get("node_id", "")):
		restored_section_id = str(runtime_state.active_text_reveal.get("reveal_section_id", ""))
	for section_value in (sections_value as Array):
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = section_value
		var section_id := str(section.get("id", ""))
		if section_id != "" and (section_id == restored_section_id or not runtime_state.is_section_revealed(section_id)):
			return section
	return {}


func _pending_after_reveal_events(node_data: Dictionary, reveal_section_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var events_value: Variant = node_data.get("after_reveal_events", [])
	var event_prefix := str(node_data.get("node_id", runtime_state.current_node_id))
	if reveal_section_id != "":
		events_value = []
		var sections_value: Variant = node_data.get("_incremental_sections", [])
		if sections_value is Array:
			for section_value in (sections_value as Array):
				if section_value is Dictionary and str((section_value as Dictionary).get("id", "")) == reveal_section_id:
					events_value = (section_value as Dictionary).get("after_reveal_events", [])
					break
		event_prefix += ":section:" + reveal_section_id
	if not (events_value is Array):
		return result
	for index in range((events_value as Array).size()):
		var event_value: Variant = (events_value as Array)[index]
		if not (event_value is Dictionary):
			continue
		var event_id := "%s:%d" % [event_prefix, index]
		if runtime_state.is_after_reveal_event_completed(event_id):
			continue
		var event := (event_value as Dictionary).duplicate(true)
		event["_event_id"] = event_id
		result.append(event)
	return result


func _on_text_reveal_state_changed(state: Dictionary) -> void:
	if runtime_state == null:
		return
	if str(state.get("node_id", "")) == runtime_state.current_node_id:
		runtime_state.active_text_reveal = state.duplicate(true)


func _on_text_reveal_completed(_skipped: bool) -> void:
	if runtime_state == null or text_reveal_controller == null:
		return
	var state := text_reveal_controller.get_state()
	if str(state.get("node_id", "")) != runtime_state.current_node_id:
		return
	_stop_node_typing_audio()
	var reveal_section_id := str(state.get("reveal_section_id", ""))
	if reveal_section_id != "":
		runtime_state.mark_section_revealed(reveal_section_id)
	else:
		runtime_state.mark_node_revealed(runtime_state.current_node_id)
	_story_interactions_locked = false
	var node_data := _resolve_node_state_variant(loader.get_node(runtime_state.current_node_id))
	if not node_data.is_empty():
		_render_choices(node_data)
		_render_right_panel(node_data)
		_refresh_current_goal()
	if text_reveal_controller.events_completed():
		runtime_state.active_text_reveal.clear()


func _on_text_reveal_post_delay_completed() -> void:
	if runtime_state == null:
		return
	var state := text_reveal_controller.get_state()
	var node_data := _resolve_node_state_variant(loader.get_node(runtime_state.current_node_id))
	if node_data.is_empty():
		return
	_execute_after_reveal_events(node_data, str(state.get("reveal_section_id", "")))
	runtime_state.active_text_reveal.clear()


func _execute_after_reveal_events(node_data: Dictionary, reveal_section_id: String = "") -> void:
	for event in _pending_after_reveal_events(node_data, reveal_section_id):
		var event_id := str(event.get("_event_id", ""))
		match str(event.get("type", "")):
			"incoming_call":
				var call_id := str(event.get("call_id", ""))
				var started := false
				if phone_manager != null:
					var active := phone_manager.get_active_call()
					started = str(active.get("call_id", "")) == call_id or phone_manager.begin_incoming_call(call_id)
				if started:
					_set_right_tab("call")
				else:
					push_warning("MainUI: after-reveal incoming call could not start: " + call_id)
			"tutorial_backtrack_prompt":
				runtime_state.set_persistent_flag("tutorial_backtrack_learned", true)
				runtime_state.set_persistent_flag("inspect_bag_option_unlocked", true)
				runtime_state.set_persistent_flag("tutorial_backtrack_hint_shown", true)
				_start_tutorial_attention(backtrack_nav_button, str(event.get("attention_event_id", "tutorial_attention_backtrack")))
				_show_case_status("调查行为改变了原始状态。请使用顶部“回溯”返回选择前。")
			"reveal_choice_attention":
				runtime_state.set_persistent_flag("tutorial_inspect_bag_choice_visible", true)
				var resolved := _resolve_node_state_variant(node_data)
				_render_choices(resolved)
				_start_choice_attention(str(event.get("choice_id", "")), str(event.get("attention_event_id", "tutorial_attention_inspect_bag")))
			"show_keyword_inline_hint":
				runtime_state.set_persistent_flag("tutorial_keyword_popup_shown", true)
				var hint_flag := str(event.get("hint_visible_flag", "tutorial_glue_keyword_hint_visible"))
				var recorded_flag := str(event.get("recorded_flag", ""))
				if recorded_flag == "" or not bool(runtime_state.flags.get(recorded_flag, false)):
					runtime_state.set_persistent_flag(hint_flag, true)
				_render_story_body(_resolve_node_state_variant(node_data))
			"start_graph_attention":
				runtime_state.set_persistent_flag("tutorial_graph_attention_ready", true)
				var graph_attention_id := str(event.get("attention_event_id", "tutorial_attention_graph"))
				runtime_state.set_persistent_flag(graph_attention_id + "_ready", true)
				_start_tutorial_attention(graph_nav_button, graph_attention_id)
			"start_phonebook_attention":
				var phonebook_attention_id := str(event.get("attention_event_id", "tutorial_attention_phonebook"))
				runtime_state.set_persistent_flag(phonebook_attention_id + "_ready", true)
				_start_tutorial_attention(contacts_tab_button, phonebook_attention_id)
			_:
				push_warning("MainUI: unsupported after-reveal event type: " + str(event.get("type", "")))
		runtime_state.mark_after_reveal_event_completed(event_id)
	_refresh_current_goal()


func _skip_current_text_reveal() -> void:
	if text_reveal_controller != null:
		text_reveal_controller.skip()


func _on_story_reveal_gui_input(event: InputEvent) -> void:
	if not _story_interactions_locked or not story_view.visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_skip_current_text_reveal()
			story_scroll.accept_event()


func _cancel_text_reveal_for_context_change() -> void:
	_stop_node_typing_audio()
	if text_reveal_controller != null:
		text_reveal_controller.clear()
	if runtime_state != null:
		runtime_state.active_text_reveal.clear()
	_story_interactions_locked = false


func _refresh_current_goal() -> void:
	if target_text_label == null or runtime_state == null or loader == null:
		return

	var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)

	if not current_data.is_empty():
		target_text_label.text = _current_goal_for_node(current_data)
		if not _story_interactions_locked:
			_render_tutorial_hints(current_data)


func _render_tutorial_hints(node_data: Dictionary) -> void:
	if not _is_tutorial_case():
		return

	var node_id: String = str(node_data.get("node_id", ""))

	match node_id:
		"tutorial_0011":
			if bool(runtime_state.flags.get("tutorial_backtrack_hint_shown", false)):
				_start_tutorial_attention(backtrack_nav_button, "tutorial_attention_backtrack")
		"tutorial_0001":
			if bool(runtime_state.flags.get("tutorial_inspect_bag_choice_visible", false)):
				_start_choice_attention("inspect_bag_before_opening", "tutorial_attention_inspect_bag")
		"tutorial_0012":
			if bool(runtime_state.flags.get("tutorial_attention_graph_first_ready", false)) and not bool(runtime_state.flags.get("tutorial_attention_graph_first_completed", false)):
				_start_tutorial_attention(graph_nav_button, "tutorial_attention_graph_first")
		"tutorial_0015":
			if bool(runtime_state.flags.get("tutorial_attention_graph_final_ready", false)) and not bool(runtime_state.flags.get("tutorial_attention_graph_final_completed", false)):
				_start_tutorial_attention(graph_nav_button, "tutorial_attention_graph_final")
		"tutorial_0016":
			if bool(runtime_state.flags.get("tutorial_attention_phonebook_ready", false)) and not bool(runtime_state.flags.get("tutorial_attention_phonebook_completed", false)):
				_start_tutorial_attention(contacts_tab_button, "tutorial_attention_phonebook")


func _queue_tutorial_modal_once(hint_key: String, prompts: Array[Dictionary]) -> void:
	if not _is_tutorial_case() or runtime_state == null or prompts.is_empty():
		return

	var flag_name := "tutorial_hint_seen_" + hint_key

	if bool(runtime_state.flags.get(flag_name, false)):
		return

	runtime_state.flags[flag_name] = true
	_tutorial_modal_queue.append({
		"hint_key": hint_key,
		"prompts": prompts.duplicate(true)
	})

	if not _tutorial_modal_show_scheduled:
		_tutorial_modal_show_scheduled = true
		call_deferred("_show_next_tutorial_modal")


func _show_next_tutorial_modal() -> void:
	_tutorial_modal_show_scheduled = false

	if tutorial_modal != null and is_instance_valid(tutorial_modal):
		return

	if _tutorial_modal_queue.is_empty() or not _is_tutorial_case():
		return

	var request: Dictionary = _tutorial_modal_queue.pop_front()
	tutorial_modal = TutorialModalScript.new() as Control
	tutorial_modal.call("configure", request.get("prompts", []))
	tutorial_modal.connect("dismissed", _on_tutorial_modal_dismissed)
	add_child(tutorial_modal)


func _on_tutorial_modal_dismissed() -> void:
	tutorial_modal = null
	if runtime_state != null and bool(runtime_state.flags.get("tutorial_keyword_popup_open", false)):
		runtime_state.set_persistent_flag("tutorial_keyword_popup_open", false)
	if _save_error_modal_active:
		_save_error_modal_active = false
		return
	if _failure_hint_modal_active:
		_failure_hint_modal_active = false
		_graph_has_fit = false
		_show_graph_view()
		call_deferred("_fit_graph_to_view")
		return

	if not _tutorial_modal_queue.is_empty():
		_tutorial_modal_show_scheduled = true
		call_deferred("_show_next_tutorial_modal")


func _show_failure_hint(hint_text: String) -> void:
	if hint_text == "" or (tutorial_modal != null and is_instance_valid(tutorial_modal)):
		return
	_failure_hint_modal_active = true
	runtime_state.flags["failure_hint_seen_" + runtime_state.current_node_id] = true
	tutorial_modal = TutorialModalScript.new() as Control
	tutorial_modal.call("configure_message", "调查提示", hint_text)
	tutorial_modal.connect("dismissed", _on_tutorial_modal_dismissed)
	add_child(tutorial_modal)


func _show_save_error_modal() -> void:
	if tutorial_modal != null and is_instance_valid(tutorial_modal):
		return
	_save_error_modal_active = true
	tutorial_modal = TutorialModalScript.new() as Control
	tutorial_modal.call(
		"configure_message",
		"存档写入失败",
		"存档未能写入所选槽位。\n\n本次进度没有被保存。请关闭提示后重试。",
		"点击空白处继续"
	)
	tutorial_modal.connect("dismissed", _on_tutorial_modal_dismissed)
	add_child(tutorial_modal)


func _current_goal_for_node(node_data: Dictionary) -> String:
	var configured_goal: String = str(node_data.get("current_goal", loader.get_current_goal()))
	if _story_interactions_locked:
		return "阅读当前记录。"
	if (
		runtime_state != null
		and str(runtime_state.active_call.get("waiting_for_keyword", "")) != ""
	):
		return "从通话内容中记录一个联系人。"
	if runtime_state != null and str(runtime_state.active_call.get("status", "")) == "active" and str(runtime_state.active_call.get("kind", "")) != "action_dispatch":
		return "完成当前通话。"

	if not _is_tutorial_case():
		return configured_goal

	var node_id: String = str(node_data.get("node_id", ""))

	match node_id:
		"tutorial_0000":
			return configured_goal
		"tutorial_0001":
			return "重新调查档案袋。" if bool(runtime_state.flags.get("inspect_bag_option_unlocked", false)) else configured_goal
		"tutorial_0011":
			return "使用“回溯”，返回拆开档案袋之前。"
		"tutorial_0012":
			if not bool(runtime_state.flags.get("tutorial_thread_fade_recorded", false)):
				return "点击正文中带下划线的“褪色”，记录“线头褪色”。"
			return "打开顶部的“图谱”。" if bool(runtime_state.flags.get("tutorial_graph_attention_ready", false)) else "阅读新增记录。"
		"tutorial_0015":
			if not bool(runtime_state.flags.get("tutorial_witness_statement_missing_recorded", false)):
				return "从清单与实物的差异中记录关键词。"
			return "打开顶部的“图谱”。" if bool(runtime_state.flags.get("tutorial_graph_attention_ready", false)) else "阅读新增记录。"
		"tutorial_0016":
			return "打开电话簿，联系艾琳。"

	return configured_goal


func _choice_is_available(choice: Dictionary) -> bool:
	var requirements: Variant = choice.get("requires_flags", {})

	if requirements is Dictionary:
		for flag_value in (requirements as Dictionary).keys():
			var flag_name: String = str(flag_value)
			var expected: bool = bool((requirements as Dictionary).get(flag_value, false))

			if bool(runtime_state.flags.get(flag_name, false)) != expected:
				return false

	var case_requirements: Variant = choice.get("requires_case_state", {})
	if case_requirements is Dictionary:
		for state_key_value in (case_requirements as Dictionary).keys():
			var state_key := str(state_key_value)
			if runtime_state.case_state.get(state_key) != (case_requirements as Dictionary)[state_key_value]:
				return false

	return true


func _resolve_node_state_variant(node_data: Dictionary) -> Dictionary:
	var resolved := node_data.duplicate(true)
	var incremental_sections: Array[Dictionary] = []
	var variants_value: Variant = node_data.get("state_variants", [])
	if not (variants_value is Array):
		return resolved
	for variant_value in (variants_value as Array):
		if not (variant_value is Dictionary):
			continue
		var variant: Dictionary = variant_value
		if not _choice_is_available(variant):
			continue
		for key_value in variant.keys():
			var key := str(key_value)
			if key in ["requires_flags", "requires_case_state"]:
				continue
			if key == "append_sections":
				var append_value: Variant = variant[key_value]
				if not (append_value is Array):
					continue
				var body_value: Variant = resolved.get("body", [])
				var body: Array = (body_value as Array).duplicate(true) if body_value is Array else [str(body_value)]
				for section_value in (append_value as Array):
					if not (section_value is Dictionary):
						continue
					var section := (section_value as Dictionary).duplicate(true)
					var section_id := str(section.get("id", ""))
					var section_text := str(section.get("text", ""))
					if section_id == "" or section_text == "":
						continue
					var current_text := _get_story_body_text(body)
					section["start_visible_characters"] = current_text.length() + (2 if current_text != "" else 0)
					body.append(section_text)
					section["end_visible_characters"] = _get_story_body_text(body).length()
					incremental_sections.append(section)
				resolved["body"] = body
			else:
				resolved[key] = variant[key_value]
	if not incremental_sections.is_empty():
		resolved["_incremental_sections"] = incremental_sections
	return resolved


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
		if not _choice_is_available(preset):
			continue
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
	if _story_interactions_locked:
		return
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
		return

	var result: Dictionary = _record_keyword_from_source(
		keyword,
		source_node_id,
		"story_body",
		str(preset.get("keyword_id", ""))
	)

	if not bool(result.get("valid", false)) or not bool(result.get("added", false)):
		var reason: String = str(result.get("reason", ""))

		if bool(result.get("duplicate", false)):
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
	_play_tutorial_ui_sound("ui_keyword_extract")
	_after_story_keyword_recorded(source_node_id, str(result.get("keyword", keyword)))


func _on_story_body_selection_input(event: InputEvent) -> void:
	if _story_interactions_locked or not story_view.visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			call_deferred("_record_story_selected_text")


func _record_story_selected_text() -> void:
	if _story_interactions_locked or story_body_label == null or runtime_state == null:
		return
	var selected_text := story_body_label.get_selected_text().strip_edges()
	if selected_text == "":
		return
	var source_node_id := runtime_state.current_node_id
	var result := _record_keyword_from_source(selected_text, source_node_id, "story_body")
	story_body_label.deselect()
	if not bool(result.get("valid", false)):
		_play_tutorial_ui_sound("ui_connection_invalid")
		_show_case_status("这段文字暂时不能形成有效的调查记录。")
		if source_node_id == "tutorial_0015":
			if not bool(runtime_state.flags.get("tutorial_missing_keyword_failed_once", false)):
				runtime_state.flags["tutorial_missing_keyword_failed_once"] = true
			elif not bool(runtime_state.flags.get("tutorial_missing_keyword_failed_twice", false)):
				runtime_state.flags["tutorial_missing_keyword_failed_twice"] = true
			else:
				_show_case_status("比较归档清单中登记的内容，与桌面上实际存在的材料。")
		return
	if not bool(result.get("added", false)):
		_show_case_status("该关键词已经记录。")
		return
	var canonical_keyword := str(result.get("keyword", selected_text))
	_refresh_keyword_grid()
	_render_graph_view()
	_play_tutorial_ui_sound("ui_keyword_extract")
	_show_case_status("已记录关键词：" + canonical_keyword)
	_after_story_keyword_recorded(source_node_id, canonical_keyword)


func _after_story_keyword_recorded(source_node_id: String, keyword: String) -> void:
	var current_node_data := loader.get_node(source_node_id)
	if source_node_id == "tutorial_0012" and keyword == "线头褪色":
		runtime_state.set_persistent_flag("tutorial_thread_fade_hint_visible", false)
		runtime_state.set_persistent_flag("tutorial_graph_attention_ready", false)
	elif source_node_id == "tutorial_0015" and keyword == "证人陈述记录缺失":
		runtime_state.set_persistent_flag("tutorial_graph_attention_ready", false)
	if not current_node_data.is_empty():
		_render_node(_resolve_node_state_variant(current_node_data))
	_refresh_current_goal()


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
	if _story_interactions_locked:
		story_body_label.tooltip_text = ""
		story_body_label.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
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
	if _story_interactions_locked:
		choice_title_label.visible = false
		return

	var choices: Variant = node_data.get("choices", [])
	choice_title_label.visible = false

	if not (choices is Array):
		choices = []

	for choice in choices:
		if not (choice is Dictionary):
			continue

		if not _choice_is_available(choice):
			continue

		choice_title_label.visible = true

		var title: String = str(choice.get("title", "未命名选择"))
		var description: String = _choice_description(choice)
		var icon_name: String = _choice_icon_name(choice)

		var choice_control := _choice_button(
			_icon_by_name(icon_name),
			title,
			description,
			choice
		)
		choice_control.set_meta("choice_id", str(choice.get("id", "")))
		choice_list.add_child(choice_control)

	if bool(node_data.get("is_failure_ending", false)) and str(node_data.get("failure_hint", "")) != "":
		choice_title_label.visible = true
		var hint_choice := {
			"title": "查看调查提示",
			"description": "回看已走过的证据路径，寻找尚未闭合的环节",
			"_failure_hint": true,
			"_failure_hint_text": str(node_data.get("failure_hint", ""))
		}
		choice_list.add_child(_choice_button(ICON_LIGHTBULB, hint_choice.title, hint_choice.description, hint_choice))


func _render_right_panel(node_data: Dictionary) -> void:
	node_data = _resolve_node_state_variant(node_data)
	current_node_title.text = str(node_data.get("title", ""))
	current_node_body.text = _node_summary(node_data)
	if case_action_manager != null and case_action_manager.is_enabled():
		current_node_body.text += "\n\n" + case_action_manager.describe_status()

	_clear_children(clue_list)
	if timeline_view != null and timeline_view.visible:
		_add_operation_help("Tab", "返回剧情")
		_add_operation_help("mouse_left", "查看时间轴任务")
		_add_operation_help("滚轮", "浏览时间轴")
	elif graph_view != null and graph_view.visible:
		_add_operation_help("Tab", "返回剧情")
		_add_operation_help("Esc", "取消当前连接" if _selected_keyword_instance_id != "" else "返回或取消当前操作")
		_add_operation_help("mouse_left", "选择节点")
		_add_operation_help("拖动", "移动画布")
		_add_operation_help("滚轮", "缩放图谱")
		_add_operation_help("右键", "取消选择或删除关键词")
	else:
		_add_operation_help("Tab", "切换到图谱")
		_add_operation_help("Esc", "返回或关闭上层页面")
		if runtime_state.current_node_id == "tutorial_0011":
			_add_operation_help("回溯", "返回拆开档案袋之前")
		if _first_array_value(node_data.get("audio_clues", []), "") != "":
			_add_operation_help("Space", "播放 / 暂停音频")
		if _has_story_choice_controls():
			_add_operation_help("Enter", "确认当前选项")
			_add_operation_help("↑", "选择上一项")
			_add_operation_help("↓", "选择下一项")
		_add_operation_help("mouse_left", "选择选项或提取关键词")
		if _has_removable_keyword():
			_add_operation_help("右键", "删除未固定关键词")

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
	_graph_node_positions.clear()
	_graph_node_sizes.clear()
	_graph_node_depths.clear()
	var visible_nodes: Dictionary = _get_visible_graph_nodes()

	for node_id_value in visible_nodes.keys():
		var node_id: String = str(node_id_value)
		var node_data: Dictionary = loader.get_node(node_id)

		if not node_data.is_empty():
			_graph_node_sizes[node_id] = _graph_node_size_for(node_data)

	var graph_layout_result: Dictionary = NarrativeGraphLayoutScript.calculate(
		loader.get_nodes(),
		visible_nodes,
		loader.get_initial_node_id(),
		_graph_node_sizes
	)
	_graph_node_positions = (graph_layout_result.get("positions", {}) as Dictionary).duplicate(true)
	_graph_node_sizes = (graph_layout_result.get("sizes", {}) as Dictionary).duplicate(true)
	_graph_node_depths = (graph_layout_result.get("depths", {}) as Dictionary).duplicate(true)
	var node_to_slot: Dictionary = graph_layout_result.get("node_to_slot", {})
	for actual_id_value in visible_nodes.keys():
		var actual_id := str(actual_id_value)
		var slot_id := str(node_to_slot.get(actual_id, actual_id))
		if _graph_node_positions.has(slot_id):
			_graph_node_positions[actual_id] = _graph_node_positions[slot_id]
			_graph_node_sizes[actual_id] = _graph_node_sizes.get(slot_id, GRAPH_NODE_SIZE)
			_graph_node_depths[actual_id] = _graph_node_depths.get(slot_id, 0)
	var canvas_size: Vector2 = graph_layout_result.get("canvas_size", Vector2(1080.0, 720.0))
	var minimum_anchor_canvas := graph_scroll.size / 0.6 + Vector2(240.0, 240.0)
	var expanded_canvas := Vector2(
		maxf(canvas_size.x, minimum_anchor_canvas.x),
		maxf(canvas_size.y, minimum_anchor_canvas.y)
	)
	var layout_offset := (expanded_canvas - canvas_size) * 0.5
	if layout_offset != Vector2.ZERO:
		for node_id_value in _graph_node_positions.keys():
			var current_position: Vector2 = _graph_node_positions[node_id_value]
			_graph_node_positions[node_id_value] = current_position + layout_offset
	canvas_size = expanded_canvas
	_graph_canvas_size = canvas_size
	_keyword_graph_layout = _calculate_keyword_graph_layout(visible_nodes, canvas_size)
	_active_path_transition_indices.clear()
	for transition_index in runtime_state.get_active_transition_indices():
		_active_path_transition_indices[transition_index] = true
	var edges: Array[Dictionary] = _build_narrative_graph_edges(visible_nodes)
	edges.append_array(_build_keyword_origin_edges())
	edges.append_array(_build_keyword_connection_edges(visible_nodes))
	edges.append_array(_build_keyword_candidate_edges(visible_nodes))
	edges.append_array(_build_tutorial_conclusion_edges(visible_nodes))
	var screen_canvas_size := _graph_screen_vector(canvas_size)
	graph_canvas.configure(screen_canvas_size, edges)
	graph_zoom_container.custom_minimum_size = screen_canvas_size
	graph_zoom_container.size = screen_canvas_size
	graph_canvas.scale = Vector2.ONE

	var display_nodes := _get_graph_display_nodes(visible_nodes)
	for node_value in display_nodes.values():
		var node_id: String = str(node_value)
		var node_data: Dictionary = loader.get_node(node_id)

		if node_data.is_empty():
			push_warning("MainUI: graph references missing node: " + node_id)
			continue
		var pollution_state_value: Variant = runtime_state.pollution_node_states.get(node_id, {})
		if pollution_state_value is Dictionary and not (pollution_state_value as Dictionary).is_empty():
			var pollution_state: Dictionary = pollution_state_value
			if str(pollution_state.get("status", "")) == "premise_invalid":
				node_data = node_data.duplicate(true)
				node_data["title"] = str(node_data.get("title", "")) + "（前提失效）"
				node_data["node_type"] = "前提失效"

		if not _graph_node_positions.has(node_id) or not _graph_node_sizes.has(node_id):
			push_warning("MainUI: graph hierarchy omitted visible node: " + node_id)
			continue

		var visited: bool = runtime_state.unlocked_nodes.has(node_id) or runtime_state.visit_history.has(node_id)
		var current: bool = node_id == runtime_state.current_node_id
		var keyword_unlocked: bool = runtime_state.is_keyword_unlocked(node_id)
		graph_canvas.add_child(_graph_node_card(
			node_data,
			_graph_screen_vector(_graph_node_positions[node_id]),
			_graph_screen_vector(_graph_node_sizes[node_id]),
			visited,
			current,
			keyword_unlocked,
			_graph_zoom
		))

	for layout_value in _keyword_graph_layout.values():
		if not (layout_value is Dictionary):
			continue

		var keyword_layout: Dictionary = layout_value
		graph_canvas.add_child(_keyword_graph_node(
			keyword_layout.get("instance", {}),
			_graph_screen_vector(keyword_layout.get("position", Vector2.ZERO)),
			_graph_screen_vector(keyword_layout.get("size", KEYWORD_GRAPH_MIN_SIZE)),
			_graph_zoom
		))
	_update_graph_grid()


func _get_visible_graph_nodes() -> Dictionary:
	var visible_nodes: Dictionary = {}

	for node_id in runtime_state.unlocked_nodes.keys():
		visible_nodes[str(node_id)] = true

	for historical_node_id in runtime_state.visit_history:
		if not loader.get_node(historical_node_id).is_empty():
			visible_nodes[historical_node_id] = true

	for node_id in runtime_state.get_keyword_unlocked_node_ids():
		if not loader.get_node(node_id).is_empty():
			visible_nodes[node_id] = true

	for connection in runtime_state.get_keyword_connections():
		var connected_target_id: String = str(connection.get("target_node_id", ""))

		if connected_target_id != "" and not loader.get_node(connected_target_id).is_empty():
			visible_nodes[connected_target_id] = true

	# Connection candidates are ephemeral interaction targets. They appear only
	# while the player is actively linking a keyword and never become path nodes
	# until the rule commits/unlocks them.
	if _selected_keyword_instance_id != "":
		var current_data := loader.get_node(runtime_state.current_node_id)
		var graph_targets: Variant = current_data.get("graph_targets", [])
		if graph_targets is Array:
			for target_value in graph_targets:
				var target_id := str(target_value)
				if target_id != "" and not loader.get_node(target_id).is_empty():
					visible_nodes[target_id] = true

	return visible_nodes


func _get_graph_display_nodes(visible_nodes: Dictionary) -> Dictionary:
	var display_by_slot: Dictionary = {}
	for node_id_value in visible_nodes.keys():
		var node_id := str(node_id_value)
		var node_data := loader.get_node(node_id)
		if node_data.is_empty():
			continue
		var slot_id := str(node_data.get("graph_slot_id", node_id))
		if not display_by_slot.has(slot_id):
			display_by_slot[slot_id] = node_id
	# The current variant owns the shared card. Otherwise the most recently
	# visited variant is shown; an unvisited sibling is never selected.
	for history_index in range(runtime_state.visit_history.size() - 1, -1, -1):
		var visited_id := runtime_state.visit_history[history_index]
		if not visible_nodes.has(visited_id):
			continue
		var visited_data := loader.get_node(visited_id)
		var visited_slot := str(visited_data.get("graph_slot_id", visited_id))
		if display_by_slot.has(visited_slot):
			display_by_slot[visited_slot] = visited_id
	var current_data := loader.get_node(runtime_state.current_node_id)
	if not current_data.is_empty():
		var current_slot := str(current_data.get("graph_slot_id", runtime_state.current_node_id))
		display_by_slot[current_slot] = runtime_state.current_node_id
	return display_by_slot


func _calculate_keyword_graph_layout(
	visible_nodes: Dictionary,
	canvas_size: Vector2
) -> Dictionary:
	var layout_by_instance: Dictionary = {}
	var instances_by_source: Dictionary = {}

	for keyword_instance in runtime_state.get_keyword_instances():
		var source_node_id: String = str(keyword_instance.get("source_node_id", ""))
		var instance_id: String = str(keyword_instance.get("instance_id", ""))

		if (
			source_node_id == ""
			or instance_id == ""
			or not visible_nodes.has(source_node_id)
			or not _graph_node_positions.has(source_node_id)
		):
			continue

		if not instances_by_source.has(source_node_id):
			instances_by_source[source_node_id] = []

		(instances_by_source[source_node_id] as Array).append(keyword_instance)

	for source_node_id_value in instances_by_source.keys():
		var source_node_id: String = str(source_node_id_value)
		var source_position: Vector2 = _graph_node_positions[source_node_id]
		var source_size: Vector2 = _graph_node_sizes.get(source_node_id, GRAPH_NODE_SIZE)
		var instances: Array = instances_by_source[source_node_id]
		var keyword_sizes: Array[Vector2] = []
		var total_width := 0.0

		for keyword_instance in instances:
			var keyword_text: String = str((keyword_instance as Dictionary).get("text", ""))
			var keyword_size := Vector2(
				clampf(74.0 + float(keyword_text.length()) * 14.0, KEYWORD_GRAPH_MIN_SIZE.x, KEYWORD_GRAPH_MAX_WIDTH),
				KEYWORD_GRAPH_MIN_SIZE.y
			)
			keyword_sizes.append(keyword_size)
			total_width += keyword_size.x

		if instances.size() > 1:
			total_width += KEYWORD_GRAPH_GAP * float(instances.size() - 1)

		var keyword_x := source_position.x + (source_size.x - total_width) * 0.5
		keyword_x = clampf(keyword_x, 16.0, maxf(16.0, canvas_size.x - total_width - 16.0))
		var keyword_y := source_position.y + source_size.y + 18.0

		for index in range(instances.size()):
			var keyword_instance: Dictionary = instances[index]
			var keyword_size: Vector2 = keyword_sizes[index]
			var instance_id: String = str(keyword_instance.get("instance_id", ""))
			layout_by_instance[instance_id] = {
				"instance": keyword_instance,
				"position": Vector2(keyword_x, keyword_y),
				"size": keyword_size
			}
			keyword_x += keyword_size.x + KEYWORD_GRAPH_GAP

	return layout_by_instance


func _build_narrative_graph_edges(visible_nodes: Dictionary) -> Array[Dictionary]:
	var edge_by_pair: Dictionary = {}
	var pair_order: Array[String] = []
	for transition in runtime_state.committed_transitions:
		var source_id := str(transition.get("source_node_id", ""))
		var target_id := str(transition.get("target_node_id", ""))
		var history_index := int(transition.get("history_index", -1))
		if not visible_nodes.has(source_id) or not visible_nodes.has(target_id):
			continue
		if not _graph_node_positions.has(source_id) or not _graph_node_positions.has(target_id):
			continue
		var pair_key := source_id + "->" + target_id
		var style := _graph_edge_style(source_id, target_id, history_index)
		if edge_by_pair.has(pair_key) and int((edge_by_pair[pair_key] as Dictionary).get("style_priority", 0)) >= int(style.get("priority", 0)):
			continue
		if not edge_by_pair.has(pair_key):
			pair_order.append(pair_key)
		var edge := _make_graph_edge(
			source_id, target_id,
			_graph_node_positions[source_id], _graph_node_sizes[source_id],
			_graph_node_positions[target_id], _graph_node_sizes[target_id], style
		)
		edge["style_priority"] = int(style.get("priority", 0))
		edge_by_pair[pair_key] = edge

	var edges: Array[Dictionary] = []
	for pair_key in pair_order:
		edges.append(edge_by_pair[pair_key])
	return edges


func _build_keyword_origin_edges() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []

	for layout_value in _keyword_graph_layout.values():
		if not (layout_value is Dictionary):
			continue

		var layout: Dictionary = layout_value
		var instance: Dictionary = layout.get("instance", {})
		var source_id: String = str(instance.get("source_node_id", ""))

		if not _graph_node_positions.has(source_id) or not _graph_node_sizes.has(source_id):
			continue

		edges.append(_make_graph_edge(
			source_id,
			str(instance.get("instance_id", "")),
			_graph_node_positions[source_id],
			_graph_node_sizes[source_id],
			layout.get("position", Vector2.ZERO),
			layout.get("size", KEYWORD_GRAPH_MIN_SIZE),
			{"color": C_BLUE, "width": 1.0, "dashed": false}
		))

	return edges


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

		if not _graph_node_positions.has(target_node_id) or not _graph_node_sizes.has(target_node_id):
			continue

		var layout: Dictionary = layout_value
		var keyword_position: Vector2 = layout.get("position", Vector2.ZERO)
		var keyword_size: Vector2 = layout.get("size", KEYWORD_GRAPH_MIN_SIZE)
		edges.append(_make_graph_edge(
			instance_id,
			target_node_id,
			keyword_position,
			keyword_size,
			_graph_node_positions[target_node_id],
			_graph_node_sizes[target_node_id],
			{"color": C_BLUE, "width": 2.0, "dashed": false}
		))

	return edges


func _build_keyword_candidate_edges(visible_nodes: Dictionary) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []

	if _selected_keyword_instance_id == "" or not _keyword_graph_layout.has(_selected_keyword_instance_id):
		return edges

	var instance: Dictionary = runtime_state.get_keyword_instance(_selected_keyword_instance_id)

	if instance.is_empty():
		return edges

	var existing_targets: Dictionary = {}

	for connection in runtime_state.get_keyword_connections_for_keyword(_selected_keyword_instance_id):
		existing_targets[str(connection.get("target_node_id", ""))] = true

	var keyword_layout: Dictionary = _keyword_graph_layout[_selected_keyword_instance_id]
	var keyword_position: Vector2 = keyword_layout.get("position", Vector2.ZERO)
	var keyword_size: Vector2 = keyword_layout.get("size", KEYWORD_GRAPH_MIN_SIZE)

	for target_id_value in visible_nodes.keys():
		var target_id: String = str(target_id_value)

		if (
			existing_targets.has(target_id)
			or not _graph_node_positions.has(target_id)
			or not _graph_node_sizes.has(target_id)
		):
			continue

		var rule: Dictionary = loader.find_keyword_rule(
			str(instance.get("normalized_text", "")),
			str(instance.get("source_node_id", "")),
			target_id
		)

		if rule.is_empty():
			continue

		var outcome := str(rule.get("outcome", "")).to_lower()
		var candidate_color := C_WARNING if outcome in ["error", "incorrect", "wrong"] else C_MUTED

		edges.append(_make_graph_edge(
			_selected_keyword_instance_id,
			target_id,
			keyword_position,
			keyword_size,
			_graph_node_positions[target_id],
			_graph_node_sizes[target_id],
			{"color": candidate_color, "width": 1.0, "dashed": true}
		))

	return edges


func _build_tutorial_conclusion_edges(visible_nodes: Dictionary) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	if not _is_tutorial_case() or not bool(runtime_state.flags.get("tutorial_final_graph_completed", false)):
		return edges
	var conclusion_id := "tutorial_conclusion_supported"
	var conclusion_data := loader.get_node(conclusion_id)
	var conclusion_value: Variant = conclusion_data.get("graph_conclusion", {})
	if not (conclusion_value is Dictionary) or not visible_nodes.has(conclusion_id):
		return edges
	for fact_value in (conclusion_value as Dictionary).get("required_fact_node_ids", []):
		var fact_id := str(fact_value)
		if not visible_nodes.has(fact_id) or not _graph_node_positions.has(fact_id) or not _graph_node_positions.has(conclusion_id):
			continue
		edges.append(_make_graph_edge(
			fact_id,
			conclusion_id,
			_graph_node_positions[fact_id],
			_graph_node_sizes.get(fact_id, GRAPH_INFERENCE_NODE_SIZE),
			_graph_node_positions[conclusion_id],
			_graph_node_sizes.get(conclusion_id, GRAPH_INFERENCE_NODE_SIZE),
			{"color": C_BLUE, "width": 2.0, "dashed": false}
		))
	return edges


func _graph_node_size_for(node_data: Dictionary) -> Vector2:
	var node_type := str(node_data.get("node_type", ""))

	if (
		bool(node_data.get("graph_only", false))
		or node_type.contains("推断")
		or node_type.contains("结论")
	):
		return GRAPH_INFERENCE_NODE_SIZE

	return GRAPH_NODE_SIZE


func _graph_edge_style(source_id: String, target_id: String, history_index: int = -1) -> Dictionary:
	if _active_path_transition_indices.has(history_index):
		return {"color": C_BLUE, "width": 2.0, "dashed": false, "priority": 3}
	if _is_error_or_failure_node(source_id) or _is_error_or_failure_node(target_id):
		return {"color": C_WARNING, "width": 1.0, "dashed": true, "priority": 2}
	return {"color": C_MUTED, "width": 1.0, "dashed": true, "priority": 1}


func _calculate_active_path_transition_indices(cursor: int) -> Dictionary:
	var active_indices: Dictionary = {}
	if runtime_state.visit_history.is_empty() or cursor <= 0:
		return active_indices
	var node_stack: Array[String] = [runtime_state.visit_history[0]]
	var edge_stack: Array[int] = []
	var last_history_index := mini(cursor, runtime_state.visit_history.size() - 1)
	for target_history_index in range(1, last_history_index + 1):
		var transition_index := target_history_index - 1
		var transition := runtime_state.get_committed_transition_at(transition_index)
		if transition.is_empty():
			continue
		var target_id := runtime_state.visit_history[target_history_index]
		var repeated_stack_index := node_stack.rfind(target_id)
		if repeated_stack_index >= 0:
			while node_stack.size() > repeated_stack_index + 1:
				node_stack.pop_back()
			while edge_stack.size() > repeated_stack_index:
				edge_stack.pop_back()
			continue
		node_stack.append(target_id)
		edge_stack.append(transition_index)
	for transition_index in edge_stack:
		active_indices[transition_index] = true
	return active_indices


func _is_error_or_failure_node(node_id: String) -> bool:
	var node_data := loader.get_node(node_id)
	var icon_key := str(node_data.get("icon_key", ""))
	var node_type := str(node_data.get("node_type", ""))
	return icon_key in ["false", "fatal"] or node_type.contains("错误") or node_type.contains("失败")


func _make_graph_edge(
	source_id: String,
	target_id: String,
	source_position: Vector2,
	source_size: Vector2,
	target_position: Vector2,
	target_size: Vector2,
	style: Dictionary
) -> Dictionary:
	var source_rect := Rect2(_graph_screen_vector(source_position), _graph_screen_vector(source_size))
	var target_rect := Rect2(_graph_screen_vector(target_position), _graph_screen_vector(target_size))
	var curve := PackedVector2Array()
	var source_center := source_rect.get_center()
	var target_center := target_rect.get_center()

	if target_rect.position.y >= source_rect.end.y + 8.0:
		var start := Vector2(source_center.x, source_rect.end.y)
		var finish := Vector2(target_center.x, target_rect.position.y)
		var handle := clampf(absf(finish.y - start.y) * 0.48, 42.0, 170.0)
		curve = PackedVector2Array([start, start + Vector2(0.0, handle), finish - Vector2(0.0, handle), finish])
	elif target_rect.end.x <= source_rect.position.x or target_rect.position.x >= source_rect.end.x:
		var target_on_right := target_center.x > source_center.x
		var start_x := source_rect.end.x if target_on_right else source_rect.position.x
		var finish_x := target_rect.position.x if target_on_right else target_rect.end.x
		var start := Vector2(start_x, source_center.y)
		var finish := Vector2(finish_x, target_center.y)
		var handle := clampf(absf(finish_x - start_x) * 0.48, 42.0, 170.0)
		var direction := 1.0 if target_on_right else -1.0
		curve = PackedVector2Array([start, start + Vector2(handle * direction, 0.0), finish - Vector2(handle * direction, 0.0), finish])
	else:
		var route_left := minf(source_rect.position.x, target_rect.position.x) - 28.0
		var use_left := route_left >= 12.0
		var route_x := route_left if use_left else maxf(source_rect.end.x, target_rect.end.x) + 28.0
		var start_x := source_rect.position.x if use_left else source_rect.end.x
		var finish_x := target_rect.position.x if use_left else target_rect.end.x
		var start := Vector2(start_x, source_center.y)
		var finish := Vector2(finish_x, target_center.y)
		curve = PackedVector2Array([start, Vector2(route_x, start.y), Vector2(route_x, finish.y), finish])

	return {
		"source_id": source_id,
		"target_id": target_id,
		"curve": curve,
		"color": style.get("color", C_LINE),
		"width": float(style.get("width", 1.0)),
		"dashed": bool(style.get("dashed", false)),
		"arrow_size": 7.0
	}


func _graph_screen_vector(world_value: Vector2) -> Vector2:
	return Vector2(roundf(world_value.x * _graph_zoom), roundf(world_value.y * _graph_zoom))


func _scaled_graph_metric(base_value: float, visual_scale: float) -> int:
	return maxi(1, roundi(base_value * visual_scale))


func _keyword_graph_node(keyword_instance: Dictionary, position_value: Vector2, node_size: Vector2, visual_scale: float) -> Control:
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
	margin.add_theme_constant_override("margin_left", _scaled_graph_metric(9.0, visual_scale))
	margin.add_theme_constant_override("margin_right", _scaled_graph_metric(9.0, visual_scale))
	margin.add_theme_constant_override("margin_top", _scaled_graph_metric(4.0, visual_scale))
	margin.add_theme_constant_override("margin_bottom", _scaled_graph_metric(4.0, visual_scale))
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", _scaled_graph_metric(6.0, visual_scale))
	margin.add_child(row)

	if _is_tutorial_case():
		row.add_child(_icon(
			_tutorial_icon("keyword", ICON_KEY_ROUND),
			Vector2.ONE * float(_scaled_graph_metric(17.0, visual_scale)),
			text_color
		))
	else:
		var diamond := _label("◇", _scaled_graph_metric(15.0, visual_scale), text_color, FONT_MONO_MEDIUM)
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		diamond.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(diamond)

	if connected:
		var connected_dot := _label("●", _scaled_graph_metric(9.0, visual_scale), text_color, FONT_MONO_MEDIUM)
		connected_dot.name = "ConnectedDot"
		connected_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		connected_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		connected_dot.tooltip_text = "已连接"
		row.add_child(connected_dot)

	var text_label := _label(keyword_text, _scaled_graph_metric(14.0, visual_scale), text_color, FONT_SERIF_REGULAR)
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
	node_size: Vector2,
	visited: bool,
	current: bool,
	keyword_unlocked: bool,
	visual_scale: float
) -> Control:
	var node_id: String = str(node_data.get("node_id", ""))
	var icon_key: String = str(node_data.get("icon_key", ""))
	var node_type: String = str(node_data.get("node_type", ""))
	var is_error: bool = icon_key == "false" or node_type.contains("错误")
	var is_failure: bool = icon_key == "fatal" or node_type.contains("失败")
	var is_final: bool = node_type.contains("最终") or node_type.contains("结论") or node_type.contains("教程完成")
	var locked: bool = not visited and not keyword_unlocked and not current
	var dashed_border: bool = locked or is_error or is_failure
	var bg_color: Color = C_WHITE if locked else Color("#E8F0FF")
	var border_color: Color = Color.TRANSPARENT if dashed_border else C_LINE
	var dashed_color: Color = C_MUTED if locked else C_WARNING
	var text_color: Color = C_MUTED if locked else C_SUBTEXT
	var border_width: int = 1
	var state_text := "锁定" if locked else "可调查"

	if visited:
		bg_color = C_WHITE
		border_color = C_MUTED if is_error else C_BLUE
		text_color = C_SUBTEXT if is_error else C_BLUE
		state_text = "已访问"
	elif keyword_unlocked:
		bg_color = Color("#E8F0FF")
		border_color = C_LINE
		text_color = C_BLUE
		state_text = "未访问 · 已解锁"

	if is_final and not locked:
		bg_color = C_BLUE_DARK
		border_color = C_BLUE_DARK
		text_color = C_WHITE
		state_text = "最终结论"

	if current:
		bg_color = C_BLUE_DARK
		border_color = C_BLUE_DARK
		text_color = C_WHITE
		state_text = "当前节点"

	if is_error or is_failure:
		border_color = Color.TRANSPARENT
		dashed_color = C_WARNING
		text_color = C_WARNING if not current else C_WHITE

	var card := Control.new()
	card.name = "GraphNode_" + node_id
	card.set_meta("graph_node_card", true)
	card.set_meta("graph_node_id", node_id)
	card.position = position_value
	card.size = node_size
	card.custom_minimum_size = node_size

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(bg_color, border_color, border_width, 3))
	_fill_rect(panel)
	card.add_child(panel)

	if dashed_border:
		var dashed_border_control: Control = GraphDashedBorderScript.new() as Control
		dashed_border_control.name = "DashedBorder"
		_fill_rect(dashed_border_control)
		dashed_border_control.call("configure", dashed_color, 1.0)
		card.add_child(dashed_border_control)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", _scaled_graph_metric(16.0, visual_scale))
	margin.add_theme_constant_override("margin_right", _scaled_graph_metric(16.0, visual_scale))
	margin.add_theme_constant_override("margin_top", _scaled_graph_metric(10.0, visual_scale))
	margin.add_theme_constant_override("margin_bottom", _scaled_graph_metric(9.0, visual_scale))
	_fill_rect(margin)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", _scaled_graph_metric(3.0, visual_scale))
	margin.add_child(content)

	var title := _label(str(node_data.get("title", node_id)), _scaled_graph_metric(17.0, visual_scale), text_color, FONT_SERIF_SEMIBOLD)
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

	var id_label := _label(node_id, _scaled_graph_metric(12.0, visual_scale), text_color, FONT_MONO_REGULAR)
	id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(id_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(spacer)

	var state_label := _label(state_text, _scaled_graph_metric(12.0, visual_scale), text_color, FONT_SERIF_REGULAR)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if locked:
		meta_row.add_child(_icon(ICON_LOCK, Vector2.ONE * float(_scaled_graph_metric(15.0, visual_scale)), text_color))

	if _is_tutorial_case() and keyword_unlocked:
		meta_row.add_child(_icon(
			_tutorial_icon("unlock", ICON_KEY_ROUND),
			Vector2.ONE * float(_scaled_graph_metric(16.0, visual_scale)),
			text_color
		))

	meta_row.add_child(state_label)

	var hit_button := _transparent_hit_button()
	hit_button.pressed.connect(_on_graph_node_pressed.bind(node_id))
	hit_button.mouse_entered.connect(_on_graph_node_hovered.bind(node_id, true))
	hit_button.mouse_exited.connect(_on_graph_node_hovered.bind(node_id, false))

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
		var conclusion_value: Variant = node_data.get("graph_conclusion", {})
		if conclusion_value is Dictionary and not (conclusion_value as Dictionary).is_empty():
			_evaluate_graph_conclusion(node_id, conclusion_value as Dictionary)
			return
		_show_graph_status(str(node_data.get("title", "推断目标")), false)
		return

	if (
		not runtime_state.unlocked_nodes.has(node_id)
		and not runtime_state.is_keyword_unlocked(node_id)
	):
		_play_tutorial_ui_sound("ui_invalid")
		return
	if node_id == runtime_state.current_node_id:
		return
	if runtime_state.move_history_cursor_to_node(node_id) == "":
		return
	_play_tutorial_ui_sound("ui_click")
	_show_history_cursor(runtime_state.history_cursor)


func _on_graph_node_hovered(node_id: String, hovered: bool) -> void:
	if not _is_tutorial_case() or _selected_keyword_instance_id == "":
		return

	if not hovered:
		_set_tutorial_cursor("connect")
		return

	var instance: Dictionary = runtime_state.get_keyword_instance(_selected_keyword_instance_id)

	if instance.is_empty():
		_set_tutorial_cursor("forbidden")
		return

	var rule: Dictionary = loader.find_keyword_rule(
		str(instance.get("normalized_text", "")),
		str(instance.get("source_node_id", "")),
		node_id
	)
	_set_tutorial_cursor(
		"connect" if not rule.is_empty() and _rule_requirements_met(rule) else "forbidden"
	)


func _on_graph_keyword_pressed(instance_id: String) -> void:
	var instance: Dictionary = runtime_state.get_keyword_instance(instance_id)

	if instance.is_empty():
		push_warning("MainUI: graph keyword instance not found: " + instance_id)
		return

	_selected_keyword_instance_id = instance_id
	_set_tutorial_cursor("connect")

	_render_graph_view()
	_refresh_operation_help()
	_show_graph_status(
		"已选择关键词：%s\n请选择要连接的剧情节点\nEsc 取消" % str(instance.get("text", "")),
		true,
		"keyword"
	)


func _complete_keyword_connection(target_node_id: String) -> void:
	var instance_id: String = _selected_keyword_instance_id
	var instance: Dictionary = runtime_state.get_keyword_instance(instance_id)
	_selected_keyword_instance_id = ""
	_set_tutorial_cursor("default")

	if _is_tutorial_case():
		runtime_state.flags["tutorial_first_connection_attempted"] = true

	if instance.is_empty():
		_render_graph_view()
		_play_tutorial_ui_sound("ui_connection_invalid")
		_show_graph_status("连接无效", false, "connection_invalid")
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
		_play_tutorial_ui_sound("ui_connection_invalid")
		_show_graph_status("连接无效", false, "connection_invalid")
		return

	if not _rule_requirements_met(rule):
		_render_graph_view()
		_play_tutorial_ui_sound("ui_connection_invalid")
		_show_graph_status("请先完成当前教学目标", false, "connection_invalid")
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
				_play_tutorial_ui_sound("ui_connection_invalid")
				_show_graph_status("连接无效", false, "connection_invalid")

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
		runtime_state.capture_history_snapshot()

		if bool(rule.get("autosave_on_success", false)) and not _suppress_disk_autosave:
			var current_node_data: Dictionary = loader.get_node(runtime_state.current_node_id)

			if not current_node_data.is_empty():
				_write_disk_autosave(current_node_data)

		_refresh_graph_after_keyword_result()
		_play_tutorial_ui_sound("ui_connection_correct")

		if unlocked_new_node:
			_play_node_unlock_delayed()

		var success_text: String = "连接成立，已解锁新节点" if unlocked_new_node else "连接成立"
		var feedback: String = str(rule.get("feedback", ""))

		if feedback != "":
			success_text += "\n" + feedback

		_show_graph_status(success_text, false, "connection_valid")

		if _is_tutorial_case():
			_mark_tutorial_flag(
				"tutorial_correct_connection_completed",
				"连接成立。新的调查节点已解锁。"
			)

		var next_node_id := str(rule.get("next_node_id", ""))
		if next_node_id != "":
			_continue_after_graph_success(next_node_id)

		return

	if outcome == "pollution":
		var pollution_node_id := str(rule.get("pollution_node_id", rule.get("error_node_id", "")))
		if pollution_node_id == "" or loader.get_node(pollution_node_id).is_empty():
			_play_tutorial_ui_sound("ui_connection_invalid")
			_show_graph_status("该预设错误关系缺少污染节点数据。", false, "connection_invalid")
			return
		var pollution_result := runtime_state.add_keyword_connection(instance_id, pollution_node_id, rule)
		if bool(pollution_result.get("added", false)):
			runtime_state.unlock_node_from_keyword(pollution_node_id)
			runtime_state.pollution_node_states[pollution_node_id] = {
				"status": "active",
				"created_at": runtime_state.investigation_time
			}
			_apply_rule_flags(rule)
			runtime_state.capture_history_snapshot()
			_render_graph_view()
			_play_tutorial_ui_sound("ui_connection_correct")
			_show_graph_status(str(rule.get("feedback", "关系已记录。")), false, "connection_valid")
		else:
			_show_graph_status("该污染关系已经存在。", false)
		return

	if outcome == "invalid":
		_apply_rule_flags(rule)
		_refresh_graph_after_keyword_result()
		var invalid_feedback: String = str(rule.get("feedback", ""))
		_play_tutorial_ui_sound("ui_connection_invalid")
		_show_graph_status(
			"连接无效\n" + invalid_feedback if invalid_feedback != "" else "连接无效",
			false,
			"connection_invalid"
		)
		return

	if outcome == "error" or outcome == "incorrect" or outcome == "wrong":
		_apply_rule_flags(rule)
		var error_feedback: String = str(rule.get("feedback", ""))
		_refresh_graph_after_keyword_result()
		_play_tutorial_ui_sound("ui_inference_wrong")
		_show_graph_status(
			error_feedback if error_feedback != "" else "连接不成立",
			false,
			"warning"
		)
		return

	push_warning("MainUI: unsupported keyword rule outcome: " + outcome)
	_render_graph_view()
	_play_tutorial_ui_sound("ui_connection_invalid")
	_show_graph_status("连接无效", false, "connection_invalid")


func _evaluate_graph_conclusion(node_id: String, conclusion: Dictionary) -> void:
	var requirements_value: Variant = conclusion.get("requires_flags", {})
	if requirements_value is Dictionary:
		for flag_value in (requirements_value as Dictionary).keys():
			if bool(runtime_state.flags.get(str(flag_value), false)) != bool((requirements_value as Dictionary)[flag_value]):
				_play_tutorial_ui_sound("ui_connection_invalid")
				_show_graph_status("请先完成两条事实关系。", false, "connection_invalid")
				return
	var outcome := str(conclusion.get("outcome", "invalid"))
	var feedback := str(conclusion.get("feedback", ""))
	if outcome != "correct":
		_play_tutorial_ui_sound("ui_inference_wrong")
		_show_graph_status(feedback, false, "connection_invalid")
		return
	_apply_rule_flags(conclusion)
	runtime_state.unlock_node_from_keyword(node_id)
	runtime_state.capture_history_snapshot()
	_render_graph_view()
	_play_tutorial_ui_sound("ui_connection_correct")
	_show_graph_status(feedback, false, "connection_valid")
	var next_node_id := str(conclusion.get("next_node_id", ""))
	if next_node_id != "":
		_continue_after_graph_success(next_node_id)


func _continue_after_graph_success(next_node_id: String) -> void:
	if loader.get_node(next_node_id).is_empty():
		push_error("MainUI: graph success target does not exist: " + next_node_id)
		return
	await get_tree().create_timer(0.8).timeout
	_show_story_view()
	_show_node(next_node_id, "graph_success")


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
	var invalidated_pollution_id := str(rule.get("invalidate_pollution_node_id", ""))
	if invalidated_pollution_id != "":
		runtime_state.pollution_node_states[invalidated_pollution_id] = {
			"status": "premise_invalid",
			"reason": str(rule.get("feedback", "后续证据使原前提失效。")),
			"invalidated_at": runtime_state.investigation_time
		}

	_refresh_current_goal()


func _refresh_graph_after_keyword_result() -> void:
	_render_graph_view()
	var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)

	if not current_data.is_empty():
		_render_right_panel(current_data)


func _cancel_keyword_connection_selection(refresh_graph: bool) -> void:
	var had_selection: bool = _selected_keyword_instance_id != ""
	_selected_keyword_instance_id = ""
	_set_tutorial_cursor("default")
	_graph_feedback_generation += 1

	if graph_status_panel != null:
		graph_status_panel.visible = false

	if had_selection and refresh_graph and graph_view != null and graph_view.visible:
		_render_graph_view()
	if graph_view != null and graph_view.visible:
		_refresh_operation_help()


func _refresh_operation_help() -> void:
	var current_data := loader.get_node(runtime_state.current_node_id)
	if not current_data.is_empty():
		_render_right_panel(current_data)


func _show_graph_status(text: String, persistent: bool, icon_key: String = "") -> void:
	if graph_status_panel == null or graph_status_label == null:
		return

	_graph_feedback_generation += 1
	var feedback_generation: int = _graph_feedback_generation
	graph_status_label.text = text

	if graph_status_icon != null:
		var texture: Texture2D = (
			KenneyAssetCatalog.icon(icon_key)
			if _is_tutorial_case() and icon_key != ""
			else null
		)
		graph_status_icon.texture = texture
		graph_status_icon.visible = texture != null
		graph_status_icon.modulate = C_WARNING if icon_key == "warning" else C_KENNEY_BLUE

	graph_status_panel.add_theme_stylebox_override(
		"panel",
		_style_box(C_WHITE, C_WARNING if icon_key == "warning" else C_BLUE, 1, 4)
	)
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

	if _is_tutorial_case():
		track_header.add_child(_icon(
			_tutorial_icon("audio_clue", ICON_PLAY),
			Vector2(15, 15),
			C_BLUE
		))

	var track_label := _label(
		track_label_text if _is_tutorial_case() else "× " + track_label_text,
		13,
		C_BLUE,
		FONT_MONO_MEDIUM
	)
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

	var play_button := _compact_audio_track_button(
		_tutorial_icon("audio_play", ICON_PLAY),
		"播放 " + track_label_text
	)
	play_button.disabled = not available
	play_button.pressed.connect(_on_audio_play_pressed.bind(audio_clue_id))
	info_controls.add_child(play_button)

	var time_label := _label(
		"%s / %s" % [_format_audio_time(0.0), _format_audio_time(duration)],
		11,
		C_SUBTEXT,
		FONT_MONO_REGULAR
	)
	time_label.custom_minimum_size.x = 92
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_controls.add_child(time_label)

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
	waveform.connect("playhead_drag_started", _on_audio_waveform_drag_started.bind(audio_clue_id))
	waveform.connect("playhead_drag_updated", _on_audio_waveform_drag_updated.bind(audio_clue_id))
	waveform.connect("playhead_drag_finished", _on_audio_waveform_drag_finished.bind(audio_clue_id))
	waveform.connect("playhead_drag_cancelled", _on_audio_waveform_drag_cancelled.bind(audio_clue_id))

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
		"time_label": time_label,
		"feedback_label": feedback_label,
		"waveform": waveform
	}


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

	_play_tutorial_ui_sound("ui_click")

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
	if str(_audio_waveform_drag_state.get("audio_clue_id", "")) == audio_clue_id:
		return

	_update_audio_card_progress(audio_clue_id, position, duration)


func _on_audio_waveform_drag_started(progress_ratio: float, audio_clue_id: String) -> void:
	if audio_manager == null or not _audio_card_controls.has(audio_clue_id):
		return

	var controls: Dictionary = _audio_card_controls[audio_clue_id]
	var duration: float = float(controls.get("duration", 0.0))

	if not bool(controls.get("available", false)) or duration <= 0.0:
		return

	var current_audio_id := str(audio_manager.call("get_current_audio_id"))
	var was_playing := current_audio_id == audio_clue_id and bool(audio_manager.call("is_playing"))
	var was_paused := current_audio_id == audio_clue_id and bool(audio_manager.call("is_paused"))
	var previous_position := float(audio_manager.call("get_playback_position")) if current_audio_id != "" else 0.0
	var previous_playing := bool(audio_manager.call("is_playing"))
	var previous_paused := bool(audio_manager.call("is_paused"))

	if current_audio_id != audio_clue_id:
		if not bool(audio_manager.call("prepare_audio", audio_clue_id)):
			_show_audio_feedback(audio_clue_id, "音频资源暂不可用")
			return

	_audio_waveform_drag_state = {
		"audio_clue_id": audio_clue_id,
		"previous_audio_id": current_audio_id,
		"previous_position": previous_position,
		"previous_playing": previous_playing,
		"previous_paused": previous_paused,
		"was_playing_before_drag": was_playing,
		"was_paused_before_drag": was_paused,
		"was_stopped_before_drag": not was_playing and not was_paused,
		"start_position": float(audio_manager.call("get_playback_position")),
		"target_position": _safe_audio_seek_time(progress_ratio, duration),
		"duration": duration
	}

	if was_playing:
		audio_manager.call("pause_audio")
	audio_manager.call("begin_scrub", audio_clue_id)
	audio_manager.call("scrub_to", float(_audio_waveform_drag_state["target_position"]))

	_update_audio_card_progress(
		audio_clue_id,
		float(_audio_waveform_drag_state["target_position"]),
		duration
	)


func _on_audio_waveform_drag_updated(progress_ratio: float, audio_clue_id: String) -> void:
	if str(_audio_waveform_drag_state.get("audio_clue_id", "")) != audio_clue_id:
		return

	var duration := float(_audio_waveform_drag_state.get("duration", 0.0))
	var target_position := _safe_audio_seek_time(progress_ratio, duration)
	_audio_waveform_drag_state["target_position"] = target_position
	audio_manager.call("scrub_to", target_position)
	_update_audio_card_progress(audio_clue_id, target_position, duration)


func _on_audio_waveform_drag_finished(progress_ratio: float, audio_clue_id: String) -> void:
	_finish_audio_waveform_drag(progress_ratio, audio_clue_id)


func _on_audio_waveform_drag_cancelled(progress_ratio: float, audio_clue_id: String) -> void:
	_cancel_active_audio_scrub()


func _finish_audio_waveform_drag(progress_ratio: float, audio_clue_id: String) -> void:
	if audio_manager == null or str(_audio_waveform_drag_state.get("audio_clue_id", "")) != audio_clue_id:
		return

	var drag_state := _audio_waveform_drag_state.duplicate(true)
	var duration := float(drag_state.get("duration", 0.0))
	var target_position := _safe_audio_seek_time(progress_ratio, duration)
	_audio_waveform_drag_state.clear()
	audio_manager.call("end_scrub")
	audio_manager.call("seek_audio", target_position)

	if bool(drag_state.get("was_playing_before_drag", false)):
		audio_manager.call("resume_audio")

	_update_audio_card_progress(audio_clue_id, target_position, duration)
	_refresh_audio_button_states(audio_clue_id)


func _cancel_active_audio_scrub() -> void:
	if audio_manager == null or _audio_waveform_drag_state.is_empty():
		return
	var drag_state := _audio_waveform_drag_state.duplicate(true)
	_audio_waveform_drag_state.clear()
	audio_manager.call("end_scrub")
	var previous_audio_id := str(drag_state.get("previous_audio_id", ""))
	if previous_audio_id != "":
		audio_manager.call("prepare_audio", previous_audio_id)
		audio_manager.call("seek_audio", float(drag_state.get("previous_position", 0.0)))
		if bool(drag_state.get("previous_playing", false)):
			audio_manager.call("play_audio", previous_audio_id)
		elif bool(drag_state.get("previous_paused", false)):
			audio_manager.call("play_audio", previous_audio_id)
			audio_manager.call("pause_audio")
	else:
		audio_manager.call("stop_audio")
	for controls_value in _audio_card_controls.values():
		if controls_value is Dictionary:
			var waveform := (controls_value as Dictionary).get("waveform") as Control
			if waveform != null and is_instance_valid(waveform):
				waveform.call("cancel_playhead_drag", false)
	_refresh_audio_button_states()


func _safe_audio_seek_time(progress_ratio: float, duration: float) -> float:
	if duration <= 0.0:
		return 0.0

	var maximum_seek := maxf(0.0, duration - 0.01)
	return clampf(progress_ratio, 0.0, 1.0) * maximum_seek


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

	if str(_audio_waveform_drag_state.get("audio_clue_id", "")) == audio_clue_id:
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
			play_button.icon = _tutorial_icon("audio_pause", ICON_PAUSE)
			play_button.tooltip_text = "暂停 " + track_label_text
			_set_compact_audio_button_active(play_button, true)
		elif audio_clue_id == current_audio_id and paused:
			play_button.icon = _tutorial_icon("audio_play", ICON_PLAY)
			play_button.tooltip_text = "继续播放 " + track_label_text
			_set_compact_audio_button_active(play_button, false)
		elif audio_clue_id == _audio_finished_id:
			play_button.icon = _tutorial_icon("audio_play", ICON_PLAY)
			play_button.tooltip_text = "重播 " + track_label_text
			_set_compact_audio_button_active(play_button, false)
		else:
			play_button.icon = _tutorial_icon("audio_play", ICON_PLAY)
			play_button.tooltip_text = "播放 " + track_label_text
			_set_compact_audio_button_active(play_button, false)


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
	if not _audio_waveform_drag_state.is_empty():
		_cancel_active_audio_scrub()
		return
	_audio_waveform_drag_state.clear()

	for controls_value in _audio_card_controls.values():
		if not (controls_value is Dictionary):
			continue

		var waveform: Control = (controls_value as Dictionary).get("waveform") as Control

		if waveform != null and is_instance_valid(waveform):
			waveform.call("cancel_playhead_drag", false)


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

	if action == "open_phonebook":
		return "从右侧电话簿联系助手、警察或案件人物"

	if action == "start_investigation_action":
		var action_id := str(choice.get("action_id", ""))
		var action_data := loader.get_action(action_id)
		if not action_data.is_empty():
			var executor_text := "助手" if str(action_data.get("executor", "")) == "assistant" else "警察联系人"
			return "%s · %d 分钟" % [executor_text, int(action_data.get("duration", 0))]

	if action == "advance_investigation_time" and case_action_manager != null:
		return "推进到最近的行动完成或定时事件 · 当前 %s" % case_action_manager.format_time()

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

	if action in ["start_investigation_action", "advance_investigation_time"]:
		return "clock"

	if action == "open_phonebook":
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
	var icon_color: Color = C_KENNEY_BLUE if _is_tutorial_case() else C_BLUE
	button.text = ""
	button.icon = icon_texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 14)
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(28, 24)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("icon_normal_color", icon_color)
	button.add_theme_color_override("icon_hover_color", C_WHITE)
	button.add_theme_color_override("icon_pressed_color", C_WHITE)
	button.add_theme_color_override("icon_focus_color", icon_color)
	button.add_theme_color_override("icon_disabled_color", C_KENNEY_DISABLED if _is_tutorial_case() else C_MUTED)
	button.add_theme_stylebox_override("normal", _style_box(C_WHITE, C_LINE, 1, 1))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE, C_BLUE, 1, 1))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 1))
	button.add_theme_stylebox_override("focus", _style_box(C_WHITE, C_BLUE_DARK, 1, 1))
	button.add_theme_stylebox_override("disabled", _style_box(C_BG, C_DIVIDER, 1, 1))
	return button


func _set_compact_audio_button_active(button: Button, active: bool) -> void:
	var icon_color: Color = C_KENNEY_BLUE if _is_tutorial_case() else C_BLUE
	button.add_theme_color_override("icon_normal_color", C_WHITE if active else icon_color)
	button.add_theme_color_override("icon_focus_color", C_WHITE if active else icon_color)
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
	root_control.custom_minimum_size = Vector2(108, 50)
	root_control.set_meta("nav_active", active)
	root_control.resized.connect(func():
		root_control.pivot_offset = root_control.size * 0.5
	)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	_fill_rect(panel)
	var panel_style := _style_box(C_BLUE_ACTIVE if active else C_WHITE, C_BLUE_DARK if active else C_LINE, 1, 4)
	panel.add_theme_stylebox_override("panel", panel_style)
	root_control.set_meta("nav_style", panel_style)
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
	hit_button.focus_mode = Control.FOCUS_ALL
	hit_button.mouse_entered.connect(_on_nav_button_hovered.bind(root_control, true))
	hit_button.mouse_exited.connect(_on_nav_button_hovered.bind(root_control, false))
	hit_button.focus_entered.connect(_on_nav_button_focus_changed.bind(root_control, true))
	hit_button.focus_exited.connect(_on_nav_button_focus_changed.bind(root_control, false))
	hit_button.button_down.connect(_on_nav_button_button_down.bind(root_control))
	hit_button.button_up.connect(_on_nav_button_button_up.bind(root_control))

	if scene_path != "":
		hit_button.pressed.connect(func():
			_change_scene_if_exists(scene_path)
		)

	root_control.add_child(hit_button)
	return root_control


func _get_nav_hit_button(nav_button: Control) -> Button:
	return nav_button.get_node("HitButton") as Button


func _on_nav_button_hovered(nav_button: Control, hovered: bool) -> void:
	var hit_button := _get_nav_hit_button(nav_button)

	if hit_button.disabled or bool(nav_button.get_meta("nav_active", false)):
		return

	_animate_nav_button(
		nav_button,
		C_PANEL_SOFT if hovered else C_WHITE,
		C_BLUE if hovered else C_LINE,
		Vector2.ONE,
		NAV_HOVER_DURATION
	)


func _on_nav_button_focus_changed(nav_button: Control, focused: bool) -> void:
	var hit_button := _get_nav_hit_button(nav_button)
	_on_nav_button_hovered(nav_button, focused or hit_button.is_hovered())


func _on_nav_button_button_down(nav_button: Control) -> void:
	var hit_button := _get_nav_hit_button(nav_button)

	if hit_button.disabled:
		return

	var active := bool(nav_button.get_meta("nav_active", false))
	_animate_nav_button(
		nav_button,
		C_BLUE_DARK if active else Color("#DCE7FF"),
		C_BLUE_DARK if active else C_BLUE,
		Vector2(0.97, 0.97),
		NAV_PRESS_DURATION
	)


func _on_nav_button_button_up(nav_button: Control) -> void:
	var hit_button := _get_nav_hit_button(nav_button)

	if hit_button.disabled:
		return

	var active := bool(nav_button.get_meta("nav_active", false))
	var highlighted := hit_button.is_hovered() or hit_button.has_focus()
	_animate_nav_button(
		nav_button,
		C_BLUE_ACTIVE if active else (C_PANEL_SOFT if highlighted else C_WHITE),
		C_BLUE_DARK if active else (C_BLUE if highlighted else C_LINE),
		Vector2.ONE,
		NAV_RELEASE_DURATION
	)


func _animate_nav_button(
	nav_button: Control,
	background: Color,
	border: Color,
	target_scale: Vector2,
	duration: float
) -> void:
	_kill_nav_button_tween(nav_button)
	var style: StyleBoxFlat = nav_button.get_meta("nav_style") as StyleBoxFlat

	if style == null:
		return

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(style, "bg_color", background, duration)
	tween.tween_property(style, "border_color", border, duration)
	tween.tween_property(nav_button, "scale", target_scale, duration)
	nav_button.set_meta("nav_tween", tween)


func _kill_nav_button_tween(nav_button: Control) -> void:
	if not nav_button.has_meta("nav_tween"):
		return

	var tween_value: Variant = nav_button.get_meta("nav_tween")

	if tween_value is Tween and (tween_value as Tween).is_valid():
		(tween_value as Tween).kill()

	nav_button.remove_meta("nav_tween")


func _set_nav_button_active(nav_button: Control, active: bool) -> void:
	if nav_button == null:
		return

	nav_button.set_meta("nav_active", active)
	_kill_nav_button_tween(nav_button)
	nav_button.scale = Vector2.ONE

	var panel: PanelContainer = nav_button.get_node("Panel") as PanelContainer
	var nav_icon: TextureRect = nav_button.find_child("Icon", true, false) as TextureRect
	var label: Label = nav_button.find_child("Label", true, false) as Label
	var style: StyleBoxFlat = nav_button.get_meta("nav_style") as StyleBoxFlat

	if style == null:
		style = _style_box(C_BLUE_ACTIVE if active else C_WHITE, C_BLUE_DARK if active else C_LINE, 1, 4)
		panel.add_theme_stylebox_override("panel", style)
		nav_button.set_meta("nav_style", style)
	else:
		style.bg_color = C_BLUE_ACTIVE if active else C_WHITE
		style.border_color = C_BLUE_DARK if active else C_LINE
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
	_render_layer_operation_help("设置", "Esc 返回进入设置前的页面")
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
	_set_nav_button_active(timeline_nav_button, false)
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
	if timeline_view != null and timeline_view.visible:
		return "timeline"
	return "story"


func restore_settings_context(source_context: String) -> void:
	if source_context == "save" and save_view != null:
		save_view.call("resume_from_settings")
	elif source_context == "load" and load_view != null:
		load_view.call("resume_from_settings")

	_set_nav_button_active(settings_nav_button, false)
	_set_nav_button_active(story_nav_button, source_context == "story")
	_set_nav_button_active(graph_nav_button, source_context == "graph")
	_set_nav_button_active(timeline_nav_button, source_context == "timeline")
	_set_nav_button_active(save_nav_button, source_context == "save")
	_set_nav_button_active(load_nav_button, source_context == "load")
	_settings_source_context = ""
	if source_context == "save":
		_render_layer_operation_help("存档", "Esc 返回游戏界面")
	elif source_context == "load":
		_render_layer_operation_help("读取", "Esc 返回游戏界面")
	else:
		var current_data := loader.get_node(runtime_state.current_node_id)
		if not current_data.is_empty():
			_render_right_panel(current_data)
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
	_render_layer_operation_help("存档", "Esc 返回游戏界面")
	load_view.call("close_page")
	save_view.call("open_page")
	_set_data_page_nav_state(true, false)


func _open_load_page() -> void:
	if load_view == null:
		_show_case_status("读档页面不可用")
		return

	_prepare_data_page_open()
	_render_layer_operation_help("读取", "Esc 返回游戏界面")
	save_view.call("close_page")
	load_view.call("open_page")
	_set_data_page_nav_state(false, true)


func _prepare_data_page_open() -> void:
	if not _data_page_open:
		_return_to_graph_view = graph_view.visible
		_return_center_page = _get_active_page_context()

	_data_page_open = true
	_stop_audio_for_context_change()
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)
	_case_status_generation += 1
	case_status_panel.visible = false
	story_view.visible = false
	graph_view.visible = false
	if timeline_view != null:
		timeline_view.visible = false


func _return_from_data_page() -> void:
	_hide_data_pages()
	var current_data := loader.get_node(runtime_state.current_node_id)
	if not current_data.is_empty():
		_render_right_panel(current_data)

	_set_center_page(_return_center_page)


func _render_layer_operation_help(title: String, description: String) -> void:
	if clue_list == null:
		return
	_clear_children(clue_list)
	_add_operation_help("Esc", "返回游戏界面")


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
	_set_nav_button_active(timeline_nav_button, false)
	_set_nav_button_active(save_nav_button, save_active)
	_set_nav_button_active(load_nav_button, load_active)
	_set_nav_button_active(settings_nav_button, false)


func _on_manual_save_requested(slot_index: int) -> void:
	if save_manager == null:
		return

	var node_data: Dictionary = loader.get_node(runtime_state.current_node_id)
	_sync_graph_view_to_runtime()
	var result: Dictionary = save_manager.save_manual(
		slot_index,
		_build_save_metadata(node_data),
		runtime_state.to_save_dictionary()
	)

	if save_view != null:
		save_view.call("report_save_result", result, slot_index)

	if not bool(result.get("success", false)):
		push_warning("MainUI: manual save failed:\n" + str(result.get("technical_error", result.get("error", ""))))
		_show_save_error_modal()


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
	_cancel_text_reveal_for_context_change()
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
	if case_action_manager != null:
		case_action_manager.configure(loader, runtime_state)
		_refresh_investigation_time_ui()
	if phone_manager != null:
		phone_manager.refresh_after_runtime_restore()
		phone_call_view.clear_call()

	_normalize_tutorial_investigation_flags()
	_prepare_graph_view_from_runtime()
	_render_node(loaded_node_data)
	call_deferred("_apply_saved_graph_view")
	story_scroll.scroll_vertical = 0
	_hide_data_pages()
	story_view.visible = true
	graph_view.visible = false
	if timeline_view != null:
		timeline_view.visible = false
	_set_nav_button_active(story_nav_button, true)
	_set_nav_button_active(graph_nav_button, false)
	_set_nav_button_active(timeline_nav_button, false)
	_render_right_panel(loaded_node_data)
	if phone_manager != null:
		_sync_phone_ui()
		if phone_manager.has_visible_call():
			_set_right_tab("call")
	_show_case_status("存档读取成功")


func _report_load_failure(error: String) -> void:
	push_warning("MainUI: load failed: " + error)

	if load_view != null:
		load_view.call("report_load_failure", error)


func _write_disk_autosave(node_data: Dictionary) -> bool:
	if save_manager == null:
		return false

	_sync_graph_view_to_runtime()
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
	for history_index in range(runtime_state.history_cursor - 1, -1, -1):
		if _is_valid_backtrack_node(loader.get_node(runtime_state.visit_history[history_index])):
			return true
	return false


func _previous_history_index() -> int:
	for history_index in range(runtime_state.history_cursor - 1, -1, -1):
		if _is_valid_backtrack_node(loader.get_node(runtime_state.visit_history[history_index])):
			return history_index
	return -1


func _update_backtrack_button_state() -> void:
	if backtrack_nav_button == null:
		return

	_get_nav_hit_button(backtrack_nav_button).disabled = not _has_backtrack_target()


func _set_backtrack_tutorial_highlight(enabled: bool) -> void:
	if enabled:
		_start_tutorial_attention(backtrack_nav_button, "tutorial_attention_backtrack")
		backtrack_nav_button.tooltip_text = "使用回溯返回拆开档案袋之前"
	elif tutorial_attention_pulse != null:
		tutorial_attention_pulse.stop_attention_event("tutorial_attention_backtrack")
		backtrack_nav_button.tooltip_text = ""


func _start_tutorial_attention(target: Control, event_id: String) -> void:
	if tutorial_attention_pulse != null and is_instance_valid(target):
		tutorial_attention_pulse.start_attention(target, event_id, true)


func _start_choice_attention(choice_id: String, event_id: String) -> void:
	if choice_list == null or choice_id == "":
		return
	for child in choice_list.get_children():
		if child is Control and str((child as Control).get_meta("choice_id", "")) == choice_id:
			_start_tutorial_attention(child as Control, event_id)
			return


func _on_tutorial_attention_peak(event_id: String) -> void:
	if runtime_state == null or runtime_state.get_attention_audio_count(event_id) >= 1:
		return
	if ui_sound_manager != null:
		ui_sound_manager.call("play_tutorial_attention_tick")
	runtime_state.record_attention_audio_peak(event_id)


func _on_backtrack_pressed() -> void:
	_set_backtrack_tutorial_highlight(false)
	var previous_index := _previous_history_index()
	if previous_index < 0:
		_update_backtrack_button_state()
		_show_case_status("没有更早的调查节点。")
		return
	var node_before_backtrack: String = runtime_state.current_node_id
	var previous_node_id := runtime_state.visit_history[previous_index]
	_play_tutorial_ui_sound("ui_backtrack")
	if _is_tutorial_case() and node_before_backtrack == "tutorial_0011" and previous_node_id == "tutorial_0001":
		runtime_state.set_persistent_flag("tutorial_backtrack_learned", true)
		runtime_state.set_persistent_flag("inspect_bag_option_unlocked", true)
	_show_history_cursor(previous_index)


func _show_history_cursor(index: int) -> void:
	if runtime_state.visit_history.is_empty():
		return
	var safe_index := clampi(index, 0, runtime_state.visit_history.size() - 1)
	if not runtime_state.restore_history_snapshot(safe_index):
		return
	var node_data := loader.get_node(runtime_state.current_node_id)
	if node_data.is_empty():
		return
	_stop_audio_for_context_change()
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)
	_hide_data_pages()
	_render_node(_resolve_node_state_variant(node_data))
	story_scroll.scroll_vertical = 0
	story_view.visible = true
	graph_view.visible = false
	if timeline_view != null:
		timeline_view.visible = false
	_set_nav_button_active(backtrack_nav_button, false)
	_set_nav_button_active(story_nav_button, true)
	_set_nav_button_active(graph_nav_button, false)
	_set_nav_button_active(timeline_nav_button, false)
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)
	_set_nav_button_active(settings_nav_button, false)
	_render_right_panel(_resolve_node_state_variant(node_data))
	_set_backtrack_tutorial_highlight(false)


func _show_story_view() -> void:
	_hide_data_pages()
	_set_center_view(false)
	_set_tutorial_cursor("default")


func _show_graph_view() -> void:
	if tutorial_attention_pulse != null:
		tutorial_attention_pulse.stop_attention_event("tutorial_attention_graph")
		tutorial_attention_pulse.stop_attention_event("tutorial_attention_graph_first")
		tutorial_attention_pulse.stop_attention_event("tutorial_attention_graph_final")
	if runtime_state != null and bool(runtime_state.flags.get("tutorial_graph_attention_ready", false)):
		runtime_state.set_persistent_flag("tutorial_graph_attention_completed", true)
		if bool(runtime_state.flags.get("tutorial_attention_graph_first_ready", false)):
			runtime_state.set_persistent_flag("tutorial_attention_graph_first_completed", true)
		if bool(runtime_state.flags.get("tutorial_attention_graph_final_ready", false)):
			runtime_state.set_persistent_flag("tutorial_attention_graph_final_completed", true)
	_hide_data_pages()
	_set_center_view(true)
	_queue_tutorial_modal_once("graph_controls", [
		{"prompt": "mouse_left", "text": "鼠标左键：先点关键词，再点目标节点建立连接"},
		{"prompt": "mouse_wheel", "text": "鼠标滚轮：上下浏览图谱"}
	])

	if not _graph_has_fit:
		call_deferred("_fit_graph_to_view")


func _show_timeline_view() -> void:
	_hide_data_pages()
	_refresh_investigation_time_ui()
	_set_center_page("timeline")
	_set_tutorial_cursor("default")


func _fit_graph_to_view() -> void:
	if graph_scroll == null or _graph_canvas_size.x <= 0.0 or _graph_canvas_size.y <= 0.0:
		return
	var viewport_size := graph_scroll.size - Vector2(12.0, 12.0)
	var bounds := Rect2()
	var has_bounds := false
	for node_id_value in _graph_node_positions.keys():
		var node_id := str(node_id_value)
		var rect := Rect2(_graph_node_positions[node_id], _graph_node_sizes.get(node_id, GRAPH_NODE_SIZE))
		bounds = bounds.merge(rect) if has_bounds else rect
		has_bounds = true
	for layout_value in _keyword_graph_layout.values():
		if layout_value is Dictionary:
			var layout := layout_value as Dictionary
			var rect := Rect2(layout.get("position", Vector2.ZERO), layout.get("size", KEYWORD_GRAPH_MIN_SIZE))
			bounds = bounds.merge(rect) if has_bounds else rect
			has_bounds = true
	if not has_bounds:
		bounds = Rect2(Vector2.ZERO, _graph_canvas_size)
	bounds = bounds.grow(84.0)
	var fit_zoom := minf(1.0, minf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y))
	_set_graph_zoom(clampf(fit_zoom, 0.6, 1.7), viewport_size * 0.5, false)
	var centered_scroll := bounds.get_center() * _graph_zoom - viewport_size * 0.5
	_apply_graph_scroll_target(centered_scroll)
	call_deferred("_apply_graph_scroll_target", centered_scroll)
	_graph_has_fit = true
	_sync_graph_view_to_runtime()
	_update_graph_grid()


func _set_graph_zoom(value: float, cursor_in_view: Vector2, preserve_cursor_anchor: bool = true) -> void:
	var old_zoom := _graph_zoom
	var new_zoom := clampf(value, 0.6, 1.7)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var world_before := (Vector2(graph_scroll.scroll_horizontal, graph_scroll.scroll_vertical) + cursor_in_view) / old_zoom
	_graph_zoom = new_zoom
	_render_graph_view()
	if preserve_cursor_anchor:
		var target_scroll := world_before * new_zoom - cursor_in_view
		_apply_graph_scroll_target(target_scroll)
		call_deferred("_apply_graph_scroll_target", target_scroll)
	_graph_has_fit = true
	_sync_graph_view_to_runtime()
	_update_graph_grid()


func _apply_graph_scroll_target(target_scroll: Vector2) -> void:
	if graph_scroll == null:
		return
	graph_scroll.scroll_horizontal = maxi(0, roundi(target_scroll.x))
	graph_scroll.scroll_vertical = maxi(0, roundi(target_scroll.y))
	_update_graph_grid()


func _on_graph_scroll_value_changed(_value: float) -> void:
	_update_graph_grid()


func _update_graph_grid() -> void:
	if graph_grid_background == null or graph_scroll == null:
		return
	graph_grid_background.configure(
		_graph_zoom,
		Vector2(graph_scroll.scroll_horizontal, graph_scroll.scroll_vertical)
	)


func _sync_graph_view_to_runtime() -> void:
	if runtime_state == null:
		return
	runtime_state.graph_view = {
		"pan_x": float(graph_scroll.scroll_horizontal) if graph_scroll != null else 0.0,
		"pan_y": float(graph_scroll.scroll_vertical) if graph_scroll != null else 0.0,
		"zoom": _graph_zoom
	}


func _prepare_graph_view_from_runtime() -> void:
	var saved_view: Dictionary = runtime_state.graph_view
	_graph_zoom = clampf(float(saved_view.get("zoom", 1.0)), 0.6, 1.7)
	_graph_has_fit = true


func _apply_saved_graph_view() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if graph_scroll == null:
		return
	var saved_view: Dictionary = runtime_state.graph_view
	graph_scroll.scroll_horizontal = maxi(0, roundi(float(saved_view.get("pan_x", 0.0))))
	graph_scroll.scroll_vertical = maxi(0, roundi(float(saved_view.get("pan_y", 0.0))))
	_update_graph_grid()


func _on_graph_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and _selected_keyword_instance_id != "":
			_cancel_keyword_connection_selection(true)
			graph_canvas.accept_event()
			return
		if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mouse_event.pressed:
			var cursor_in_view := mouse_event.global_position - graph_scroll.global_position
			var factor := 1.1 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			_set_graph_zoom(_graph_zoom * factor, cursor_in_view)
			graph_scroll.accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_graph_pan_active = true
				_graph_pan_dragged = false
				_graph_pan_start_mouse = mouse_event.global_position
				_graph_pan_start_scroll = Vector2(graph_scroll.scroll_horizontal, graph_scroll.scroll_vertical)
			else:
				_graph_pan_active = false
				_set_tutorial_cursor("default")
			graph_scroll.accept_event()


func _set_center_view(show_graph: bool) -> void:
	_set_center_page("graph" if show_graph else "story")


func _set_center_page(page_id: String) -> void:
	_hide_keyword_action()
	_cancel_keyword_connection_selection(false)

	if page_id in ["graph", "timeline"]:
		_stop_audio_for_context_change()

	story_view.visible = page_id == "story"
	graph_view.visible = page_id == "graph"
	if timeline_view != null:
		timeline_view.visible = page_id == "timeline"
	_set_nav_button_active(backtrack_nav_button, false)
	_set_nav_button_active(story_nav_button, page_id == "story")
	_set_nav_button_active(graph_nav_button, page_id == "graph")
	_set_nav_button_active(timeline_nav_button, page_id == "timeline")
	_set_nav_button_active(save_nav_button, false)
	_set_nav_button_active(load_nav_button, false)
	_set_nav_button_active(settings_nav_button, false)

	var current_data: Dictionary = loader.get_node(runtime_state.current_node_id)
	if not current_data.is_empty():
		_render_right_panel(current_data)
	if page_id == "graph":
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
	elif _graph_node_positions.has(runtime_state.current_node_id):
		var current_position: Vector2 = _graph_node_positions[runtime_state.current_node_id]
		var current_size: Vector2 = _graph_node_sizes.get(runtime_state.current_node_id, GRAPH_NODE_SIZE)
		var fallback_center: Vector2 = _graph_screen_vector(current_position + current_size * 0.5)
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
	var choice_color := C_BLUE
	var choice_border := C_BLUE
	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(STORY_CONTENT_WIDTH, 62)

	var panel := PanelContainer.new()
	_fill_rect(panel)
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, choice_border, 1, 4))
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
	icon_box.add_child(_icon(texture, Vector2(28, 28), choice_color))
	row.add_child(icon_box)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)

	var title_label := _label(title, 18, choice_color, FONT_SERIF_SEMIBOLD)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var desc_label := _label(desc, 14, C_SUBTEXT, FONT_SERIF_REGULAR)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(desc_label)

	var arrow := _label("›", 28, choice_color, FONT_MONO_MEDIUM)
	arrow.custom_minimum_size.x = 24
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	var hit_button := _transparent_hit_button()
	hit_button.focus_mode = Control.FOCUS_ALL
	hit_button.set_meta("story_choice", true)

	hit_button.mouse_entered.connect(func():
		panel.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, choice_color, 1, 4))
	)

	hit_button.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, choice_border, 1, 4))
	)

	hit_button.pressed.connect(func():
		_on_choice_pressed(choice)
	)

	root_control.add_child(hit_button)
	return root_control


func _has_story_choice_controls() -> bool:
	return choice_list != null and choice_list.get_child_count() > 0


func _has_removable_keyword() -> bool:
	for keyword_instance in runtime_state.get_keyword_instances():
		if bool(runtime_state.can_remove_keyword(str(keyword_instance.get("instance_id", ""))).get("allowed", false)):
			return true
	return false


func _add_operation_help(key_text: String, operation_text: String) -> void:
	clue_list.add_child(_operation_help_row(key_text, operation_text))


func _operation_help_row(key_text: String, operation_text: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 32
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)

	var key_panel := PanelContainer.new()
	key_panel.custom_minimum_size = Vector2(54, 30)
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_BLUE, 1, 2))
	row.add_child(key_panel)

	if key_text == "mouse_left":
		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_panel.add_child(icon_center)
		icon_center.add_child(_icon(ICON_MOUSE_LEFT, Vector2(21, 21), C_BLUE))
	else:
		var key_label := _label(key_text, 13, C_BLUE, FONT_MONO_MEDIUM)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_panel.add_child(key_label)

	var operation_label := _label(operation_text, 14, C_SUBTEXT, FONT_SERIF_REGULAR)
	operation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	operation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	operation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(operation_label)
	return row


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


func _tutorial_icon(key: String, fallback: Texture2D) -> Texture2D:
	return KenneyAssetCatalog.icon(key, fallback) if _is_tutorial_case() else fallback


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
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	if runtime_state != null and runtime_state.current_node_id == "tutorial_0001" and tutorial_attention_pulse != null:
		tutorial_attention_pulse.stop_attention_event("tutorial_attention_inspect_bag")
	_play_tutorial_ui_sound("ui_click")
	if bool(choice.get("_failure_hint", false)):
		_show_failure_hint(str(choice.get("_failure_hint_text", "")))
		return
	_apply_story_choice_effects(choice)
	var action: String = str(choice.get("action", ""))

	if action == "return_to_archive":
		var completion_node_data := loader.get_node(runtime_state.current_node_id)
		if not completion_node_data.is_empty() and not _suppress_disk_autosave:
			_write_disk_autosave(completion_node_data)
		if _node_marks_case_completed(completion_node_data):
			case_completion_requested.emit(loader.get_current_case_id())
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

	if action == "open_phonebook":
		_set_right_tab("contacts")
		_show_case_status("请从电话簿选择联系人。")
		return

	if action == "start_investigation_action":
		if case_action_manager == null or not case_action_manager.is_enabled():
			_show_case_status("当前案件没有可用的调查行动系统。")
			return
		var start_result := case_action_manager.start_action(str(choice.get("action_id", "")))
		if bool(start_result.get("success", false)):
			_render_node(_resolve_node_state_variant(loader.get_node(runtime_state.current_node_id)))
		return

	if action == "advance_investigation_time":
		if case_action_manager == null or not case_action_manager.is_enabled():
			_show_case_status("当前案件没有可推进的调查时间。")
			return
		var advance_result := case_action_manager.advance_to_next_event()
		_show_case_status(str(advance_result.get("message", "")))
		var action_target := str(advance_result.get("transition_node_id", ""))
		if action_target != "" and not loader.get_node(action_target).is_empty():
			_show_node(action_target, "timed_event")
		else:
			_render_node(_resolve_node_state_variant(loader.get_node(runtime_state.current_node_id)))
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

	_show_node(target_node_id, str(choice.get("id", choice.get("title", ""))))


func _apply_story_choice_effects(choice: Dictionary) -> void:
	var flags_value: Variant = choice.get("set_flags", {})
	if flags_value is Dictionary:
		for flag_value in (flags_value as Dictionary).keys():
			var flag_id := str(flag_value)
			var value: Variant = (flags_value as Dictionary)[flag_value]
			if flag_id != "" and value is bool:
				runtime_state.flags[flag_id] = bool(value)
	var case_state_value: Variant = choice.get("set_case_state", {})
	if case_state_value is Dictionary:
		runtime_state.set_case_state_values(case_state_value as Dictionary)
	runtime_state.capture_history_snapshot()


func _apply_node_flags(node_data: Dictionary) -> void:
	var flags_value: Variant = node_data.get("set_flags", {})

	if flags_value is Dictionary:
		for flag_value in (flags_value as Dictionary).keys():
			var flag_name: String = str(flag_value)
			var enabled_value: Variant = (flags_value as Dictionary).get(flag_value, false)

			if flag_name != "" and enabled_value is bool:
				runtime_state.flags[flag_name] = bool(enabled_value)

	var case_state_value: Variant = node_data.get("set_case_state", {})
	if case_state_value is Dictionary:
		runtime_state.set_case_state_values(case_state_value)

	var invalidated_value: Variant = node_data.get("invalidate_pollution_nodes", [])
	if invalidated_value is Array:
		for pollution_node_value in (invalidated_value as Array):
			var pollution_node_id := str(pollution_node_value)
			if pollution_node_id != "":
				runtime_state.pollution_node_states[pollution_node_id] = {
					"status": "premise_invalid",
					"reason": str(node_data.get("pollution_invalidation_reason", "后续证据使原前提失效。")),
					"invalidated_at": runtime_state.investigation_time
				}

	_normalize_tutorial_investigation_flags()


func _normalize_tutorial_investigation_flags() -> void:
	if not _is_tutorial_case() or runtime_state == null:
		return
	var default_case_state := {
		"bag_opened": false,
		"seal_state_preserved": true,
		"bag_inspected": false,
		"archive_contents_checked": false,
		"current_bag_route": ""
	}
	for state_key in default_case_state.keys():
		if not runtime_state.case_state.has(state_key):
			runtime_state.case_state[state_key] = default_case_state[state_key]



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


func _play_tutorial_ui_sound(event_key: String) -> void:
	if ui_sound_manager != null:
		ui_sound_manager.call("play", event_key)


func _play_node_unlock_delayed() -> void:
	if not _is_tutorial_case():
		return

	await get_tree().create_timer(0.22).timeout
	_play_tutorial_ui_sound("ui_node_unlock")


func _set_tutorial_cursor(mode: String) -> void:
	if _is_tutorial_case() and cursor_manager != null:
		cursor_manager.call("set_mode", mode)


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
		node.remove_child(child)
		child.queue_free()
