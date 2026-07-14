extends Control
class_name CaseStartUI

signal new_game_requested
signal continue_requested
signal load_requested
signal settings_requested
signal quit_requested

const C_BG := Color("#F7F9FF")
const C_PANEL_SOFT := Color("#EEF3FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_DIVIDER := Color("#D7DEF3")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_MUTED := Color("#8995B8")
const C_WHITE := Color("#FFFFFF")

const FONT_PUBLIC := preload("res://assets/fonts/PublicSans-Regular.ttf")
const FONT_MONO := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const FONT_SERIF := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")

const ICON_PLAY := preload("res://assets/icons/lucide/play.svg")
const ICON_REFRESH := preload("res://assets/icons/lucide/refresh-cw.svg")
const ICON_FOLDER := preload("res://assets/icons/lucide/folder-open.svg")
const ICON_SETTINGS := preload("res://assets/icons/lucide/settings.svg")
const ICON_POWER := preload("res://assets/icons/lucide/power.svg")

var save_manager: SaveManager
var continue_button: Button
var summary_status_label: Label
var summary_title_label: Label
var summary_time_label: Label
var feedback_label: Label
var _menu_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	call_deferred("_focus_first_button")


func configure(manager: SaveManager) -> void:
	save_manager = manager
	refresh_autosave_summary()


func refresh_autosave_summary() -> void:
	if save_manager == null or summary_status_label == null:
		return

	var summary: Dictionary = save_manager.read_slot_summary("autosave", 0)
	var status: String = str(summary.get("status", "empty"))
	var available: bool = status == "available"
	continue_button.disabled = not available

	if available:
		var metadata_value: Variant = summary.get("metadata", {})
		var metadata: Dictionary = metadata_value if metadata_value is Dictionary else {}
		var node_title: String = str(metadata.get("node_title", "可继续的案件节点"))
		summary_status_label.text = "可继续"
		summary_title_label.text = node_title
		summary_title_label.tooltip_text = node_title
		summary_time_label.text = str(summary.get("saved_at_text", ""))
	elif status == "corrupted":
		summary_status_label.text = "自动存档损坏"
		summary_title_label.text = "仍可进入读取存档查看手动槽位"
		summary_title_label.tooltip_text = ""
		summary_time_label.text = ""
	elif status == "incompatible":
		summary_status_label.text = "自动存档版本不兼容"
		summary_title_label.text = "仍可进入读取存档查看手动槽位"
		summary_title_label.tooltip_text = ""
		summary_time_label.text = ""
	else:
		summary_status_label.text = "暂无可用自动存档"
		summary_title_label.text = "开始新游戏以建立案件记录"
		summary_title_label.tooltip_text = ""
		summary_time_label.text = ""

	continue_button.tooltip_text = "" if available else summary_status_label.text


func show_feedback(message: String) -> void:
	if feedback_label != null:
		feedback_label.text = message


func clear_feedback() -> void:
	show_feedback("")


func focus_default() -> void:
	_focus_first_button()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = C_BG
	_fill_rect(background)
	add_child(background)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.0
	frame.anchor_top = 0.0
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 28.0
	frame.offset_top = 28.0
	frame.offset_right = -28.0
	frame.offset_bottom = -28.0
	frame.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT, C_BLUE, 1, 4))
	add_child(frame)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 86)
	outer.add_theme_constant_override("margin_right", 86)
	outer.add_theme_constant_override("margin_top", 70)
	outer.add_theme_constant_override("margin_bottom", 62)
	frame.add_child(outer)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	outer.add_child(content)

	var case_line := HBoxContainer.new()
	case_line.add_child(_label("CASE 01 / CONTROL BACKUP", 15, C_BLUE, FONT_MONO))
	var case_spacer := Control.new()
	case_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	case_line.add_child(case_spacer)
	case_line.add_child(_label("DEMO V0.1", 14, C_SUBTEXT, FONT_MONO))
	content.add_child(case_line)

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	content.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 96)
	content.add_child(body)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 12)
	body.add_child(identity)

	var identity_top := Control.new()
	identity_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity.add_child(identity_top)

	var index_label := _label("03 / CASE ARCHIVE", 14, C_SUBTEXT, FONT_MONO)
	identity.add_child(index_label)

	var title_cn := _label("第三轨", 74, C_BLUE, FONT_SERIF_SEMIBOLD)
	identity.add_child(title_cn)
	var title_en := _label("THE THIRD TRACK", 24, C_SUBTEXT, FONT_PUBLIC)
	identity.add_child(title_en)

	var title_rule := ColorRect.new()
	title_rule.color = C_BLUE
	title_rule.custom_minimum_size = Vector2(180, 3)
	title_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	identity.add_child(title_rule)

	identity.add_child(_label("隔音室谋杀案", 34, C_TEXT, FONT_SERIF_SEMIBOLD))
	identity.add_child(_label("THE SOUNDPROOF ROOM MURDER", 17, C_SUBTEXT, FONT_PUBLIC))

	var identity_bottom := Control.new()
	identity_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity.add_child(identity_bottom)

	var note := _label("一段被备份的控制室录音，和一间不该传出声音的房间。", 16, C_SUBTEXT, FONT_SERIF)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(note)

	var menu_panel := PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(520, 0)
	menu_panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_DIVIDER, 1, 4))
	body.add_child(menu_panel)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 34)
	menu_margin.add_theme_constant_override("margin_right", 34)
	menu_margin.add_theme_constant_override("margin_top", 30)
	menu_margin.add_theme_constant_override("margin_bottom", 30)
	menu_panel.add_child(menu_margin)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu_margin.add_child(menu)
	menu.add_child(_label("案件入口", 18, C_BLUE, FONT_SERIF_SEMIBOLD))
	menu.add_child(_label("CASE ACCESS", 12, C_SUBTEXT, FONT_MONO))

	var menu_rule := HSeparator.new()
	menu_rule.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	menu.add_child(menu_rule)

	var new_button := _menu_button("新游戏", ICON_PLAY)
	new_button.pressed.connect(func(): new_game_requested.emit())
	menu.add_child(new_button)

	continue_button = _menu_button("继续游戏", ICON_REFRESH)
	continue_button.pressed.connect(func(): continue_requested.emit())
	menu.add_child(continue_button)

	var load_button := _menu_button("读取存档", ICON_FOLDER)
	load_button.pressed.connect(func(): load_requested.emit())
	menu.add_child(load_button)

	var settings_button := _menu_button("设置", ICON_SETTINGS)
	settings_button.pressed.connect(func(): settings_requested.emit())
	menu.add_child(settings_button)

	var quit_button := _menu_button("退出", ICON_POWER)
	quit_button.pressed.connect(func(): quit_requested.emit())
	menu.add_child(quit_button)

	var summary := PanelContainer.new()
	summary.custom_minimum_size.y = 118
	summary.add_theme_stylebox_override("panel", _style_box(C_PANEL_SOFT, C_LINE, 1, 3))
	menu.add_child(summary)

	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 18)
	summary_margin.add_theme_constant_override("margin_right", 18)
	summary_margin.add_theme_constant_override("margin_top", 12)
	summary_margin.add_theme_constant_override("margin_bottom", 12)
	summary.add_child(summary_margin)

	var summary_box := VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 3)
	summary_margin.add_child(summary_box)
	summary_status_label = _label("暂无可用自动存档", 14, C_BLUE, FONT_SERIF_SEMIBOLD)
	summary_box.add_child(summary_status_label)
	summary_title_label = _label("开始新游戏以建立案件记录", 16, C_TEXT, FONT_SERIF)
	summary_title_label.clip_text = true
	summary_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary_box.add_child(summary_title_label)
	summary_time_label = _label("", 13, C_SUBTEXT, FONT_MONO)
	summary_box.add_child(summary_time_label)

	feedback_label = _label("", 14, C_BLUE_DARK, FONT_SERIF)
	feedback_label.custom_minimum_size.y = 24
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(feedback_label)

	_wire_button_focus()


func _menu_button(text: String, icon: Texture2D) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.custom_minimum_size = Vector2(0, 58)
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", C_BLUE)
	button.add_theme_color_override("font_hover_color", C_WHITE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_focus_color", C_WHITE)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	button.add_theme_color_override("icon_normal_color", C_BLUE)
	button.add_theme_color_override("icon_hover_color", C_WHITE)
	button.add_theme_color_override("icon_pressed_color", C_WHITE)
	button.add_theme_color_override("icon_focus_color", C_WHITE)
	button.add_theme_color_override("icon_disabled_color", C_MUTED)
	button.add_theme_constant_override("icon_max_width", 21)
	button.add_theme_constant_override("h_separation", 14)
	button.add_theme_stylebox_override("normal", _button_box(C_WHITE, C_LINE))
	button.add_theme_stylebox_override("hover", _button_box(C_BLUE, C_BLUE))
	button.add_theme_stylebox_override("pressed", _button_box(C_BLUE_DARK, C_BLUE_DARK))
	button.add_theme_stylebox_override("focus", _button_box(C_BLUE, C_BLUE_DARK, 2))
	button.add_theme_stylebox_override("disabled", _button_box(C_PANEL_SOFT, C_DIVIDER))
	_menu_buttons.append(button)
	return button


func _wire_button_focus() -> void:
	if _menu_buttons.is_empty():
		return
	for index in range(_menu_buttons.size()):
		var previous: Button = _menu_buttons[(index - 1 + _menu_buttons.size()) % _menu_buttons.size()]
		var next: Button = _menu_buttons[(index + 1) % _menu_buttons.size()]
		_menu_buttons[index].focus_neighbor_top = previous.get_path()
		_menu_buttons[index].focus_neighbor_bottom = next.get_path()


func _focus_first_button() -> void:
	for button in _menu_buttons:
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return


func _button_box(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = _style_box(background, border, width, 4)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	return box


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_box(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func _fill_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
