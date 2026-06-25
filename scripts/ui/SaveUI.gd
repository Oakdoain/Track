extends Control

const MIN_WINDOW_SIZE := Vector2i(1280, 720)

const TOP_BAR_HEIGHT := 72
const LEFT_PANEL_WIDTH := 400
const RIGHT_PANEL_WIDTH := 400
const SAVES_PER_PAGE := 7
const MANUAL_SLOT_COUNT := 20
const AUTO_SAVE_SLOT := 0

const SAVE_DIR := "user://saves"
const AUTO_SAVE_PATH := "user://saves/save_00.json"

const TOP_BAR_MARGIN_LEFT := 24
const TOP_BAR_MARGIN_RIGHT := 24
const TOP_BAR_MARGIN_TOP := 8
const TOP_BAR_MARGIN_BOTTOM := 8

const SIDE_MARGIN_LEFT := 28
const SIDE_MARGIN_RIGHT := 28
const SIDE_MARGIN_TOP := 28
const SIDE_MARGIN_BOTTOM := 24

const CENTER_MARGIN_LEFT := 28
const CENTER_MARGIN_RIGHT := 28
const CENTER_MARGIN_TOP := 28
const CENTER_MARGIN_BOTTOM := 24

const SECTION_TITLE_HEIGHT := 28

const CURRENT_SLOT_WIDTH := 48
const CURRENT_VALUE_WIDTH := 142
const CURRENT_PROGRESS_BAR_WIDTH := 96
const CURRENT_PROGRESS_TEXT_WIDTH := 38

const C_BG := Color("#F7F9FF")
const C_PANEL_SOFT := Color("#EEF3FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_BLUE_ACTIVE := Color("#1044B2")
const C_LINE := Color("#99ABE6")
const C_DIVIDER := Color("#D7DEF3")
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

const ICON_FILE_TEXT := preload("res://assets/icons/lucide/file-text.svg")
const ICON_PLUS := preload("res://assets/icons/lucide/plus.svg")
const ICON_TRASH := preload("res://assets/icons/lucide/trash-2.svg")
const ICON_UPLOAD := preload("res://assets/icons/lucide/upload.svg")
const ICON_INFO := preload("res://assets/icons/lucide/info.svg")
const ICON_DATABASE := preload("res://assets/icons/lucide/database.svg")
const ICON_ARROW_RIGHT := preload("res://assets/icons/lucide/arrow-right.svg")
const ICON_CHEVRON_LEFT := preload("res://assets/icons/lucide/chevron-left.svg")
const ICON_CHEVRON_RIGHT := preload("res://assets/icons/lucide/chevron-right.svg")
const ICON_CIRCLE := preload("res://assets/icons/lucide/circle.svg")
const ICON_CIRCLE_DOT := preload("res://assets/icons/lucide/circle-dot.svg")

var _last_viewport_size: Vector2 = Vector2.ZERO

var bg: ColorRect
var root: Control

var save_slots: Array = []
var selected_save_index: int = 0
var current_page_index: int = 0

var save_list_box: VBoxContainer
var save_count_label: Label
var page_buttons_box: HBoxContainer

var selected_save_slot_label: Label
var selected_save_title_label: Label
var selected_save_chapter_line_label: Label
var selected_save_time_label: Label
var selected_save_chapter_progress_label: Label
var selected_save_progress_label: Label
var selected_save_progress_bar: ProgressBar
var selected_save_note_label: Label


func _ready() -> void:
	_setup_window()
	_force_self_to_viewport()
	_load_save_slots()
	_build_ui()
	_render_save_list()
	_select_save(0)
	call_deferred("_force_self_to_viewport")


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

	row.add_child(_nav_button(ICON_STEP_BACK, "回溯", false, "res://scenes/ui/MainUI.tscn"))
	row.add_child(_nav_button(ICON_BOOK_OPEN, "剧情", false, "res://scenes/ui/MainUI.tscn"))
	row.add_child(_nav_button(ICON_GIT_BRANCH, "图谱", false))
	row.add_child(_nav_button(ICON_SAVE, "存档", true))
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
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	box.add_child(_section_title("案件档案"))

	var archive_card := PanelContainer.new()
	archive_card.custom_minimum_size.y = 286
	archive_card.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	box.add_child(archive_card)

	var archive_margin := MarginContainer.new()
	archive_margin.add_theme_constant_override("margin_left", 18)
	archive_margin.add_theme_constant_override("margin_right", 18)
	archive_margin.add_theme_constant_override("margin_top", 18)
	archive_margin.add_theme_constant_override("margin_bottom", 16)
	archive_card.add_child(archive_margin)

	var archive_box := VBoxContainer.new()
	archive_box.add_theme_constant_override("separation", 16)
	archive_margin.add_child(archive_box)

	var archive_head := HBoxContainer.new()
	archive_head.add_theme_constant_override("separation", 14)
	archive_box.add_child(archive_head)

	archive_head.add_child(_icon(ICON_FILE_TEXT, Vector2(38, 38), C_BLUE))

	var archive_title_box := VBoxContainer.new()
	archive_title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_title_box.add_theme_constant_override("separation", 2)
	archive_head.add_child(archive_title_box)

	archive_title_box.add_child(_label("BR-1999-0217", 21, C_BLUE, FONT_SERIF_SEMIBOLD))
	archive_title_box.add_child(_label("蓝室录音棚死亡事件", 17, C_BLUE, FONT_SERIF_SEMIBOLD))
	archive_title_box.add_child(_label("Blue Room Studio Homicide", 13, C_BLUE, FONT_PUBLIC_REGULAR))

	archive_head.add_child(_small_tag("主案件", Vector2(58, 58), C_WHITE, C_BLUE))

	archive_box.add_child(_info_row("案件类型", "谋杀案"))
	archive_box.add_child(_info_row("发生时间", "1999年4月15日"))
	archive_box.add_child(_info_row("发生地点", "蓝室录音棚"))

	var progress_row := HBoxContainer.new()
	archive_box.add_child(progress_row)

	progress_row.add_child(_label("当前进度", 15, C_BLUE, FONT_SERIF_REGULAR))

	var progress_spacer := Control.new()
	progress_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress_spacer)

	var pbar := ProgressBar.new()
	pbar.custom_minimum_size = Vector2(120, 7)
	pbar.value = 38
	pbar.max_value = 100
	pbar.show_percentage = false
	pbar.add_theme_stylebox_override("background", _style_box(Color("#E4E9F6"), Color.TRANSPARENT, 0, 4))
	pbar.add_theme_stylebox_override("fill", _style_box(C_BLUE, Color.TRANSPARENT, 0, 4))
	progress_row.add_child(pbar)

	progress_row.add_child(_label("38%", 14, C_BLUE, FONT_MONO_MEDIUM))
	archive_box.add_child(_info_row("最后存档", "2024 / 05 / 28  14:22:07"))

	box.add_child(_section_title("存档操作"))

	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	box.add_child(action_box)

	action_box.add_child(_action_button(ICON_PLUS, "保存到空档位", "_save_to_empty_slot"))
	action_box.add_child(_action_button(ICON_TRASH, "清空当前档位", "_clear_selected_slot"))
	action_box.add_child(_action_button(ICON_UPLOAD, "导出当前档位", "_export_selected_save"))

	var hint_card := PanelContainer.new()
	hint_card.custom_minimum_size.y = 116
	hint_card.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 4))
	box.add_child(hint_card)

	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 16)
	hint_margin.add_theme_constant_override("margin_right", 16)
	hint_margin.add_theme_constant_override("margin_top", 12)
	hint_margin.add_theme_constant_override("margin_bottom", 12)
	hint_card.add_child(hint_margin)

	var hint := _label(
		"手动存档采用固定档位制。\n选择空档位后保存，或覆盖已有档位。",
		14,
		C_SUBTEXT,
		FONT_SERIF_REGULAR
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_margin.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	return panel


func _build_center_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CenterPanel"
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _style_box(C_BG, Color.TRANSPARENT, 0, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CENTER_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", CENTER_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", CENTER_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", CENTER_MARGIN_BOTTOM)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.custom_minimum_size.y = SECTION_TITLE_HEIGHT
	box.add_child(head)

	head.add_child(_section_title("存档列表"))

	var head_spacer := Control.new()
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_spacer)

	save_count_label = _label("", 15, C_BLUE, FONT_SERIF_SEMIBOLD)
	save_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(save_count_label)

	var count_gap := Control.new()
	count_gap.custom_minimum_size.x = 26
	head.add_child(count_gap)

	head.add_child(_slot_mode_tag())

	var header_margin := MarginContainer.new()
	header_margin.custom_minimum_size.y = 48
	header_margin.add_theme_constant_override("margin_left", 16)
	header_margin.add_theme_constant_override("margin_right", 14)
	box.add_child(header_margin)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	header_margin.add_child(header)

	header.add_child(_header_label("", 42))
	header.add_child(_header_label("档位", 58))
	header.add_child(_header_label("档位名称", 282))
	header.add_child(_header_label("章节进度", 220))
	header.add_child(_header_label("游戏进度", 140))
	header.add_child(_header_label("保存时间", 190))

	save_list_box = VBoxContainer.new()
	save_list_box.add_theme_constant_override("separation", 10)
	box.add_child(save_list_box)

	var fill_spacer := Control.new()
	fill_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill_spacer)

	var page_row := HBoxContainer.new()
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page_row.add_theme_constant_override("separation", 12)
	box.add_child(page_row)

	page_buttons_box = HBoxContainer.new()
	page_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	page_buttons_box.add_theme_constant_override("separation", 12)
	page_row.add_child(page_buttons_box)

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
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)

	box.add_child(_section_title("存档说明"))

	var info_card := PanelContainer.new()
	info_card.custom_minimum_size.y = 230
	info_card.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	box.add_child(info_card)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 18)
	info_margin.add_theme_constant_override("margin_right", 18)
	info_margin.add_theme_constant_override("margin_top", 18)
	info_margin.add_theme_constant_override("margin_bottom", 16)
	info_card.add_child(info_margin)

	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	info_margin.add_child(info_box)

	var info_head := HBoxContainer.new()
	info_head.add_theme_constant_override("separation", 10)
	info_box.add_child(info_head)

	info_head.add_child(_icon(ICON_INFO, Vector2(25, 25), C_BLUE))
	info_head.add_child(_label("档位说明", 19, C_BLUE, FONT_SERIF_SEMIBOLD))

	var desc := _label(
		"自动存档固定在第一位。\n手动档位 1 到 20 全部显示，空档位也会保留。",
		14,
		C_BLUE,
		FONT_SERIF_REGULAR
	)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(desc)

	info_box.add_child(_thin_line())

	var rules := _label(
		"• 每页显示 7 个条目。\n• 手动档位固定为 1 到 20。\n• 空档位可直接写入。\n• 自动存档不可清空，不可手动覆盖。",
		14,
		C_BLUE,
		FONT_SERIF_REGULAR
	)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(rules)

	box.add_child(_section_title("当前选中档位"))

	var current_card_panel := PanelContainer.new()
	current_card_panel.custom_minimum_size.y = 220
	current_card_panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	box.add_child(current_card_panel)

	var current_margin := MarginContainer.new()
	current_margin.add_theme_constant_override("margin_left", 18)
	current_margin.add_theme_constant_override("margin_right", 18)
	current_margin.add_theme_constant_override("margin_top", 16)
	current_margin.add_theme_constant_override("margin_bottom", 16)
	current_card_panel.add_child(current_margin)

	var current_box := VBoxContainer.new()
	current_box.add_theme_constant_override("separation", 11)
	current_margin.add_child(current_box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	current_box.add_child(title_row)

	selected_save_slot_label = _label("—", 18, C_BLUE, FONT_MONO_MEDIUM)
	selected_save_slot_label.custom_minimum_size.x = CURRENT_SLOT_WIDTH
	selected_save_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_save_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title_row.add_child(selected_save_slot_label)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	title_row.add_child(title_box)

	selected_save_title_label = _label("暂无档位", 17, C_BLUE, FONT_SERIF_SEMIBOLD)
	selected_save_title_label.clip_text = true
	selected_save_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_save_title_label.custom_minimum_size.x = 240
	title_box.add_child(selected_save_title_label)

	selected_save_chapter_line_label = _label("—", 13, C_BLUE, FONT_SERIF_REGULAR)
	selected_save_chapter_line_label.clip_text = true
	selected_save_chapter_line_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_save_chapter_line_label.custom_minimum_size.x = 240
	title_box.add_child(selected_save_chapter_line_label)

	current_box.add_child(_save_detail_row("保存时间", "_time"))
	current_box.add_child(_save_detail_row("章节进度", "_chapter_progress"))
	current_box.add_child(_save_detail_progress_row())
	current_box.add_child(_save_detail_row("备注", "_note"))

	var overwrite := _large_action_button(ICON_PLUS, "写入当前档位", true)
	overwrite.pressed.connect(_overwrite_selected_save)
	box.add_child(overwrite)

	var backup := _large_action_button(ICON_DATABASE, "创建备份", false)
	backup.pressed.connect(_backup_selected_save)
	box.add_child(backup)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	return panel


func _render_save_list() -> void:
	_clear_children(save_list_box)

	var page_count: int = _get_page_count()
	current_page_index = int(clamp(current_page_index, 0, page_count - 1))

	save_count_label.text = "已用 %d / %d 档" % [_get_used_manual_slot_count(), MANUAL_SLOT_COUNT]

	var start_index: int = current_page_index * SAVES_PER_PAGE
	var end_index: int = int(min(start_index + SAVES_PER_PAGE, save_slots.size()))

	for i in range(start_index, end_index):
		var data_variant: Variant = save_slots[i]

		if data_variant is Dictionary:
			var data: Dictionary = data_variant
			save_list_box.add_child(_save_row(i, data))

	_render_page_buttons()


func _render_page_buttons() -> void:
	_clear_children(page_buttons_box)

	var page_count: int = _get_page_count()

	page_buttons_box.add_child(_page_button(ICON_CHEVRON_LEFT, current_page_index > 0, func():
		_change_page(current_page_index - 1)
	))

	for i in range(page_count):
		var page_index: int = i
		page_buttons_box.add_child(_page_number(str(page_index + 1), page_index == current_page_index, func():
			_change_page(page_index)
		))

	page_buttons_box.add_child(_page_button(ICON_CHEVRON_RIGHT, current_page_index < page_count - 1, func():
		_change_page(current_page_index + 1)
	))


func _change_page(page_index: int) -> void:
	var page_count: int = _get_page_count()
	current_page_index = int(clamp(page_index, 0, page_count - 1))
	_render_save_list()


func _get_page_count() -> int:
	return int(max(1, int(ceil(float(save_slots.size()) / float(SAVES_PER_PAGE)))))


func _save_row(index: int, data: Dictionary) -> Control:
	var is_selected: bool = index == selected_save_index
	var is_auto: bool = bool(data.get("is_auto", false))
	var is_empty: bool = bool(data.get("is_empty", false))

	var root_control := Control.new()
	root_control.custom_minimum_size.y = 86

	var panel := PanelContainer.new()
	_fill_rect(panel)

	if is_selected:
		panel.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_BLUE, 1, 5))
	else:
		panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 5))

	root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(margin)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	root_control.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	margin.add_child(row)

	var radio_box := CenterContainer.new()
	radio_box.custom_minimum_size.x = 42
	radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(radio_box)

	var radio_texture: Texture2D = ICON_CIRCLE_DOT if is_selected else ICON_CIRCLE
	var radio_color: Color = C_BLUE if not is_empty else C_MUTED
	var radio_icon := _icon(radio_texture, Vector2(20, 20), radio_color)
	radio_box.add_child(radio_icon)

	var slot_text: String = "自动" if is_auto else "%02d" % int(data.get("slot", index))
	var slot_label := _label(slot_text, 17, C_BLUE if not is_empty else C_MUTED, FONT_MONO_MEDIUM)
	slot_label.custom_minimum_size.x = 58
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(slot_label)

	var name_box := VBoxContainer.new()
	name_box.custom_minimum_size.x = 282
	name_box.add_theme_constant_override("separation", 4)
	row.add_child(name_box)

	var name_label := _label(str(data.get("name", "空档位")), 18, C_BLUE if not is_empty else C_MUTED, FONT_SERIF_SEMIBOLD)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_box.add_child(name_label)

	var line_label := _label(str(data.get("chapter_line", "等待写入")), 13, C_BLUE if not is_empty else C_MUTED, FONT_SERIF_REGULAR)
	line_label.clip_text = true
	line_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_box.add_child(line_label)

	var chapter_label := _label(str(data.get("chapter_progress", "—")), 16, C_BLUE if not is_empty else C_MUTED, FONT_SERIF_SEMIBOLD)
	chapter_label.custom_minimum_size.x = 220
	chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_label.clip_text = true
	chapter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(chapter_label)

	var progress_label := _label(str(data.get("game_progress", "0%")), 18, C_BLUE if not is_empty else C_MUTED, FONT_MONO_MEDIUM)
	progress_label.custom_minimum_size.x = 140
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(progress_label)

	var time_label := _label(str(data.get("save_time", "—")), 15, C_BLUE if not is_empty else C_MUTED, FONT_MONO_REGULAR)
	time_label.custom_minimum_size.x = 190
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.clip_text = true
	time_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(time_label)

	var hit := _transparent_hit_button()
	hit.pressed.connect(func():
		_select_save(index)
	)
	root_control.add_child(hit)

	return root_control


func _select_save(index: int) -> void:
	if save_slots.is_empty():
		selected_save_index = 0
		return

	selected_save_index = int(clamp(index, 0, save_slots.size() - 1))
	current_page_index = int(floor(float(selected_save_index) / float(SAVES_PER_PAGE)))

	_render_save_list()
	_render_current_save()


func _render_current_save() -> void:
	if save_slots.is_empty():
		_render_empty_current_save()
		return

	var data_variant: Variant = save_slots[selected_save_index]

	if not (data_variant is Dictionary):
		_render_empty_current_save()
		return

	var data: Dictionary = data_variant
	var is_auto: bool = bool(data.get("is_auto", false))
	var is_empty: bool = bool(data.get("is_empty", false))

	selected_save_slot_label.text = "自动" if is_auto else "%02d" % int(data.get("slot", selected_save_index))
	selected_save_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	selected_save_title_label.text = str(data.get("name", "空档位"))
	selected_save_chapter_line_label.text = str(data.get("chapter_line", "等待写入"))
	selected_save_time_label.text = str(data.get("save_time", "—"))
	selected_save_chapter_progress_label.text = str(data.get("chapter_progress", "—"))
	selected_save_progress_label.text = str(data.get("game_progress", "0%"))
	selected_save_progress_bar.value = 0.0 if is_empty else _percent_to_float(str(data.get("game_progress", "0%")))
	selected_save_note_label.text = str(data.get("note", "空档位"))


func _render_empty_current_save() -> void:
	if selected_save_slot_label == null:
		return

	selected_save_slot_label.text = "—"
	selected_save_title_label.text = "暂无档位"
	selected_save_chapter_line_label.text = "—"
	selected_save_time_label.text = "—"
	selected_save_chapter_progress_label.text = "—"
	selected_save_progress_label.text = "0%"
	selected_save_progress_bar.value = 0
	selected_save_note_label.text = "—"


func _save_detail_row(label_text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 24

	var left_label := _label(label_text, 14, C_BLUE, FONT_SERIF_REGULAR)
	left_label.custom_minimum_size.x = 76
	left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(left_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var value := _label("—", 14, C_BLUE, FONT_SERIF_REGULAR)
	value.custom_minimum_size.x = CURRENT_VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)

	match key:
		"_time":
			selected_save_time_label = value
		"_chapter_progress":
			selected_save_chapter_progress_label = value
		"_note":
			selected_save_note_label = value

	return row


func _save_detail_progress_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 24

	var left_label := _label("游戏进度", 14, C_BLUE, FONT_SERIF_REGULAR)
	left_label.custom_minimum_size.x = 76
	left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(left_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	selected_save_progress_bar = ProgressBar.new()
	selected_save_progress_bar.custom_minimum_size = Vector2(CURRENT_PROGRESS_BAR_WIDTH, 7)
	selected_save_progress_bar.max_value = 100
	selected_save_progress_bar.show_percentage = false
	selected_save_progress_bar.add_theme_stylebox_override("background", _style_box(Color("#E4E9F6"), Color.TRANSPARENT, 0, 4))
	selected_save_progress_bar.add_theme_stylebox_override("fill", _style_box(C_BLUE, Color.TRANSPARENT, 0, 4))
	row.add_child(selected_save_progress_bar)

	selected_save_progress_label = _label("0%", 14, C_BLUE, FONT_MONO_MEDIUM)
	selected_save_progress_label.custom_minimum_size.x = CURRENT_PROGRESS_TEXT_WIDTH
	selected_save_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selected_save_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(selected_save_progress_label)

	return row


func _load_save_slots() -> void:
	save_slots.clear()
	_ensure_save_dir()

	var auto_data: Dictionary = {}
	var manual_data_by_slot: Dictionary = {}

	var dir: DirAccess = DirAccess.open(SAVE_DIR)

	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				if file_name.begins_with("save_"):
					var data: Dictionary = _read_json(SAVE_DIR + "/" + file_name)

					if not data.is_empty():
						var slot: int = int(data.get("slot", -1))

						if file_name == "save_00.json" or slot == AUTO_SAVE_SLOT or bool(data.get("is_auto", false)):
							data["slot"] = AUTO_SAVE_SLOT
							data["is_auto"] = true
							data["is_empty"] = false
							auto_data = data
						elif slot >= 1 and slot <= MANUAL_SLOT_COUNT:
							data["slot"] = slot
							data["is_auto"] = false
							data["is_empty"] = false
							manual_data_by_slot[slot] = data

			file_name = dir.get_next()

		dir.list_dir_end()

	if auto_data.is_empty():
		auto_data = _make_auto_save_data()
		_write_json(AUTO_SAVE_PATH, auto_data)

	save_slots.append(auto_data)

	for slot in range(1, MANUAL_SLOT_COUNT + 1):
		if manual_data_by_slot.has(slot):
			save_slots.append(manual_data_by_slot[slot])
		else:
			save_slots.append(_make_empty_slot_data(slot))


func _make_empty_slot_data(slot: int) -> Dictionary:
	return {
		"slot": slot,
		"is_auto": false,
		"is_empty": true,
		"name": "空档位",
		"chapter_line": "等待写入",
		"chapter_progress": "—",
		"game_progress": "0%",
		"save_time": "—",
		"save_unix": 0,
		"current_node_id": "",
		"current_title": "",
		"state": {
			"read_node_ids": [],
			"discovered_keywords": [],
			"discovered_clues": []
		},
		"note": "空档位"
	}


func _make_auto_save_data() -> Dictionary:
	var render_data: Dictionary = {}
	var current_node_id := ""

	var manager: Node = get_node_or_null("/root/StoryManager")

	if manager != null and manager.has_method("get_render_data"):
		var raw_render: Variant = manager.call("get_render_data")

		if raw_render is Dictionary:
			render_data = raw_render

	if manager != null and manager.has_method("get_current_node_id"):
		current_node_id = str(manager.call("get_current_node_id"))

	var read_nodes_text: String = str(render_data.get("read_nodes", "0 / 0"))
	var progress_text: String = str(render_data.get("chapter_explore", "0%"))
	var title: String = str(render_data.get("title", "当前节点"))
	var now_unix: int = int(Time.get_unix_time_from_system())

	return {
		"slot": AUTO_SAVE_SLOT,
		"is_auto": true,
		"is_empty": false,
		"name": "自动存档",
		"chapter_line": "%s · %s" % [
			str(render_data.get("chapter", "第一章")),
			_get_current_time_option(render_data)
		],
		"chapter_progress": "%s %s 节点" % [
			str(render_data.get("chapter", "第一章")),
			read_nodes_text
		],
		"game_progress": progress_text,
		"save_time": _current_time_string(),
		"save_unix": now_unix,
		"current_node_id": current_node_id,
		"current_title": title,
		"state": {
			"read_node_ids": [],
			"discovered_keywords": [],
			"discovered_clues": []
		},
		"note": "自动存档"
	}


func _get_used_manual_slot_count() -> int:
	var count: int = 0

	for data_variant in save_slots:
		if data_variant is Dictionary:
			var data: Dictionary = data_variant

			if not bool(data.get("is_auto", false)) and not bool(data.get("is_empty", false)):
				count += 1

	return count


func _save_to_empty_slot() -> void:
	var target_index: int = -1

	if selected_save_index >= 0 and selected_save_index < save_slots.size():
		var selected_variant: Variant = save_slots[selected_save_index]

		if selected_variant is Dictionary:
			var selected_data: Dictionary = selected_variant

			if not bool(selected_data.get("is_auto", false)) and bool(selected_data.get("is_empty", false)):
				target_index = selected_save_index

	if target_index < 0:
		target_index = _find_first_empty_manual_slot_index()

	if target_index < 0:
		push_warning("SaveUI: 没有空档位。")
		return

	_write_runtime_data_to_index(target_index)


func _overwrite_selected_save() -> void:
	if save_slots.is_empty() or selected_save_index < 0:
		return

	var data_variant: Variant = save_slots[selected_save_index]

	if not (data_variant is Dictionary):
		return

	var data: Dictionary = data_variant

	if bool(data.get("is_auto", false)):
		push_warning("SaveUI: 自动存档不可手动覆盖。")
		return

	_write_runtime_data_to_index(selected_save_index)


func _write_runtime_data_to_index(index: int) -> void:
	if index <= 0 or index >= save_slots.size():
		return

	var old_data_variant: Variant = save_slots[index]

	if not (old_data_variant is Dictionary):
		return

	var old_data: Dictionary = old_data_variant
	var slot: int = int(old_data.get("slot", index))
	var data: Dictionary = _make_runtime_save_data(slot, "手动档位 %02d" % slot)

	save_slots[index] = data
	selected_save_index = index
	current_page_index = int(floor(float(selected_save_index) / float(SAVES_PER_PAGE)))

	_write_save_file(data)
	_render_save_list()
	_render_current_save()


func _clear_selected_slot() -> void:
	if save_slots.is_empty() or selected_save_index < 0:
		return

	var data_variant: Variant = save_slots[selected_save_index]

	if not (data_variant is Dictionary):
		return

	var data: Dictionary = data_variant

	if bool(data.get("is_auto", false)):
		push_warning("SaveUI: 自动存档不可清空。")
		return

	var slot: int = int(data.get("slot", selected_save_index))

	if bool(data.get("is_empty", false)):
		return

	var file_name: String = "save_%02d.json" % slot
	var dir: DirAccess = DirAccess.open(SAVE_DIR)

	if dir != null and dir.file_exists(file_name):
		dir.remove(file_name)

	save_slots[selected_save_index] = _make_empty_slot_data(slot)

	_render_save_list()
	_render_current_save()


func _export_selected_save() -> void:
	if save_slots.is_empty() or selected_save_index < 0:
		return

	var data_variant: Variant = save_slots[selected_save_index]

	if not (data_variant is Dictionary):
		return

	var data: Dictionary = data_variant

	if bool(data.get("is_empty", false)):
		return

	var slot: int = int(data.get("slot", selected_save_index))
	var path: String = SAVE_DIR + "/export_%02d.json" % slot

	_write_json(path, data)


func _backup_selected_save() -> void:
	if save_slots.is_empty() or selected_save_index < 0:
		return

	var data_variant: Variant = save_slots[selected_save_index]

	if not (data_variant is Dictionary):
		return

	var data: Dictionary = data_variant

	if bool(data.get("is_empty", false)):
		return

	var backup_data: Dictionary = data.duplicate(true)
	var slot: int = int(backup_data.get("slot", selected_save_index))

	backup_data["backup_of"] = slot
	backup_data["backup_time"] = _current_time_string()
	backup_data["backup_unix"] = int(Time.get_unix_time_from_system())

	_write_json(SAVE_DIR + "/backup_%02d.json" % slot, backup_data)


func _find_first_empty_manual_slot_index() -> int:
	for i in range(1, save_slots.size()):
		var data_variant: Variant = save_slots[i]

		if data_variant is Dictionary:
			var data: Dictionary = data_variant

			if bool(data.get("is_empty", false)):
				return i

	return -1


func _make_runtime_save_data(slot: int, save_name: String) -> Dictionary:
	var render_data: Dictionary = {}
	var current_node_id := ""

	var manager: Node = get_node_or_null("/root/StoryManager")

	if manager != null and manager.has_method("get_render_data"):
		var raw_render: Variant = manager.call("get_render_data")

		if raw_render is Dictionary:
			render_data = raw_render

	if manager != null and manager.has_method("get_current_node_id"):
		current_node_id = str(manager.call("get_current_node_id"))

	var read_nodes: Array = []
	var keywords: Array = []
	var clues: Array = []

	if manager != null:
		var raw_read: Variant = manager.get("read_node_ids")
		var raw_keywords: Variant = manager.get("discovered_keywords")
		var raw_clues: Variant = manager.get("discovered_clues")

		if raw_read is Dictionary:
			read_nodes = raw_read.keys()

		if raw_keywords is Dictionary:
			keywords = raw_keywords.keys()

		if raw_clues is Dictionary:
			clues = raw_clues.keys()

	var read_nodes_text: String = str(render_data.get("read_nodes", "0 / 0"))
	var progress_text: String = str(render_data.get("chapter_explore", "0%"))
	var title: String = str(render_data.get("title", "当前节点"))
	var now_unix: int = int(Time.get_unix_time_from_system())

	return {
		"slot": slot,
		"is_auto": false,
		"is_empty": false,
		"name": save_name,
		"chapter_line": "%s · %s" % [
			str(render_data.get("chapter", "第一章")),
			_get_current_time_option(render_data)
		],
		"chapter_progress": "%s %s 节点" % [
			str(render_data.get("chapter", "第一章")),
			read_nodes_text
		],
		"game_progress": progress_text,
		"save_time": _current_time_string(),
		"save_unix": now_unix,
		"current_node_id": current_node_id,
		"current_title": title,
		"state": {
			"read_node_ids": read_nodes,
			"discovered_keywords": keywords,
			"discovered_clues": clues
		},
		"note": "手动档位"
	}


func _get_current_time_option(render_data: Dictionary) -> String:
	var time_options: Variant = render_data.get("time_options", [])
	var time_index: int = int(render_data.get("time_index", 0))

	if time_options is Array and time_options.size() > 0:
		time_index = int(clamp(time_index, 0, time_options.size() - 1))
		return str(time_options[time_index])

	return "第一天 · 夜晚"


func _ensure_save_dir() -> void:
	var user_dir: DirAccess = DirAccess.open("user://")

	if user_dir == null:
		return

	if not user_dir.dir_exists("saves"):
		user_dir.make_dir("saves")


func _write_save_file(data: Dictionary) -> void:
	if bool(data.get("is_auto", false)):
		_write_json(AUTO_SAVE_PATH, data)
		return

	var slot: int = int(data.get("slot", 1))
	var path: String = SAVE_DIR + "/save_%02d.json" % slot

	_write_json(path, data)


func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_warning("SaveUI: 无法写入文件：" + path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var content: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var error: Error = json.parse(content)

	if error != OK:
		push_warning("SaveUI: JSON 解析失败：" + path)
		return {}

	var data: Variant = json.data

	if data is Dictionary:
		return data

	return {}


func _current_time_string() -> String:
	var t: Dictionary = Time.get_datetime_dict_from_system()

	return "%04d / %02d / %02d\n%02d:%02d:%02d" % [
		int(t["year"]),
		int(t["month"]),
		int(t["day"]),
		int(t["hour"]),
		int(t["minute"]),
		int(t["second"])
	]


func _percent_to_float(text: String) -> float:
	var clean: String = text.replace("%", "").strip_edges()

	if clean.is_valid_float():
		return float(clean)

	return 0.0


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


func _slot_mode_tag() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(126, 36)
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 4))

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(center)
	panel.add_child(center)

	var label := _label("固定档位", 13, C_BLUE, FONT_SERIF_REGULAR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.add_child(label)

	return panel


func _action_button(texture: Texture2D, title: String, method_name: String) -> Control:
	var root_control := Control.new()
	root_control.custom_minimum_size.y = 62

	var panel := PanelContainer.new()
	_fill_rect(panel)
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_LINE, 1, 3))
	root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(margin)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	root_control.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	row.add_child(_icon(texture, Vector2(28, 28), C_BLUE))

	var title_label := _label(title, 16, C_BLUE, FONT_SERIF_SEMIBOLD)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)

	row.add_child(_icon(ICON_ARROW_RIGHT, Vector2(24, 24), C_BLUE))

	var hit := _transparent_hit_button()
	hit.pressed.connect(func():
		call(method_name)
	)
	root_control.add_child(hit)

	return root_control


func _large_action_button(texture: Texture2D, title: String, active: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 62
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.add_theme_stylebox_override("normal", _style_box(C_BLUE_ACTIVE if active else Color.TRANSPARENT, C_BLUE if active else C_LINE, 1, 3))
	button.add_theme_stylebox_override("hover", _style_box(C_BLUE_DARK if active else C_PANEL_SOFT, C_BLUE, 1, 3))
	button.add_theme_stylebox_override("pressed", _style_box(C_BLUE_DARK, C_BLUE_DARK, 1, 3))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(margin)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	row.add_child(_icon(texture, Vector2(28, 28), C_WHITE if active else C_BLUE))

	var title_label := _label(title, 16, C_WHITE if active else C_BLUE, FONT_SERIF_SEMIBOLD)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)

	row.add_child(_icon(ICON_ARROW_RIGHT, Vector2(26, 26), C_WHITE if active else C_BLUE))

	return button


func _section_title(title: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = SECTION_TITLE_HEIGHT

	var title_label := _label(title, 17, C_BLUE, FONT_SERIF_SEMIBOLD)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)

	return row


func _info_row(left: String, right: String) -> Control:
	var row := HBoxContainer.new()

	row.add_child(_label(left, 14, C_BLUE, FONT_SERIF_REGULAR))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_label(right, 14, C_BLUE, FONT_SERIF_SEMIBOLD))

	return row


func _header_label(text: String, width: int) -> Control:
	var label := _label(text, 14, C_BLUE, FONT_SERIF_SEMIBOLD)
	label.custom_minimum_size.x = width
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _small_tag(text: String, min_size: Vector2, text_color: Color, bg_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _style_box(bg_color, bg_color, 1, 3))

	var label := _label(text, 13, text_color, FONT_SERIF_SEMIBOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)

	return panel


func _page_button(texture: Texture2D, enabled: bool, callback: Callable) -> Control:
	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(40, 40)

	var panel := PanelContainer.new()
	_fill_rect(panel)
	panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE if enabled else C_DIVIDER, 1, 3))
	root_control.add_child(panel)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(center)
	root_control.add_child(center)

	center.add_child(_icon(texture, Vector2(20, 20), C_BLUE if enabled else C_MUTED))

	var hit := _transparent_hit_button()
	hit.disabled = not enabled
	hit.pressed.connect(callback)
	root_control.add_child(hit)

	return root_control


func _page_number(text: String, active: bool, callback: Callable) -> Control:
	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(40, 40)

	var panel := PanelContainer.new()
	_fill_rect(panel)
	panel.add_theme_stylebox_override("panel", _style_box(C_BLUE if active else Color.TRANSPARENT, C_BLUE, 1, 3))
	root_control.add_child(panel)

	var label := _label(text, 14, C_WHITE if active else C_BLUE, FONT_MONO_MEDIUM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(label)
	root_control.add_child(label)

	var hit := _transparent_hit_button()
	hit.pressed.connect(callback)
	root_control.add_child(hit)

	return root_control


func _thin_line() -> Control:
	var line := ColorRect.new()
	line.color = C_DIVIDER
	line.custom_minimum_size = Vector2(0, 1)
	return line


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


func _change_scene_if_exists(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("SaveUI: scene not found: " + scene_path)
		return

	get_tree().change_scene_to_file(scene_path)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
