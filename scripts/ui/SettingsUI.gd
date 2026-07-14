extends Control
class_name CaseSettingsUI

signal return_requested
signal return_to_title_requested
signal quit_requested

const C_BG := Color("#F7F9FF")
const C_PANEL_SOFT := Color("#EEF3FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_DIVIDER := Color("#D7DEF3")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_WHITE := Color("#FFFFFF")

const FONT_PUBLIC := preload("res://assets/fonts/PublicSans-Regular.ttf")
const FONT_MONO := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const FONT_SERIF := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")

const ICON_VOLUME := preload("res://assets/icons/lucide/volume-2.svg")
const ICON_MONITOR := preload("res://assets/icons/lucide/monitor.svg")
const ICON_REFRESH := preload("res://assets/icons/lucide/refresh-cw.svg")
const ICON_TOGGLE_OFF := preload("res://assets/icons/lucide/toggle-left.svg")
const ICON_TOGGLE_ON := preload("res://assets/icons/lucide/toggle-right.svg")
const ICON_RESET := preload("res://assets/icons/lucide/rotate-ccw.svg")
const ICON_RETURN := preload("res://assets/icons/lucide/step-back.svg")
const ICON_HOME := preload("res://assets/icons/lucide/home.svg")
const ICON_POWER := preload("res://assets/icons/lucide/power.svg")

var settings_manager: SettingsManager
var entry_context: String = "title"
var volume_slider: HSlider
var volume_value_label: Label
var window_mode_option: OptionButton
var vsync_toggle: Button
var feedback_label: Label
var return_title_button: Button
var _updating_controls: bool = false


func _ready() -> void:
	_build_ui()


func configure(manager: SettingsManager, context: String) -> void:
	settings_manager = manager
	entry_context = context
	if return_title_button != null:
		return_title_button.visible = context != "title"
	_refresh_controls()
	call_deferred("_focus_default")


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

	var center := CenterContainer.new()
	frame.add_child(center)

	var page := VBoxContainer.new()
	page.custom_minimum_size = Vector2(1120, 760)
	page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	page.add_theme_constant_override("separation", 18)
	center.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 72
	page.add_child(header)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)
	heading.add_child(_label("设置", 36, C_BLUE, FONT_SERIF_SEMIBOLD))
	heading.add_child(_label("SETTINGS / SYSTEM PREFERENCES", 13, C_SUBTEXT, FONT_MONO))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	header.add_child(_label("CASE 01 / CONTROL BACKUP", 13, C_SUBTEXT, FONT_MONO))

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	page.add_child(divider)

	var settings_panel := PanelContainer.new()
	settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_panel.add_theme_stylebox_override("panel", _style_box(C_WHITE, C_DIVIDER, 1, 4))
	page.add_child(settings_panel)

	var settings_margin := MarginContainer.new()
	settings_margin.add_theme_constant_override("margin_left", 36)
	settings_margin.add_theme_constant_override("margin_right", 36)
	settings_margin.add_theme_constant_override("margin_top", 28)
	settings_margin.add_theme_constant_override("margin_bottom", 28)
	settings_panel.add_child(settings_margin)

	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 18)
	settings_margin.add_child(settings_box)
	settings_box.add_child(_section_header("基础设置", "BASIC SETTINGS"))
	settings_box.add_child(_setting_separator())

	var volume_row: Dictionary = _setting_row(
		ICON_VOLUME,
		"主音量",
		"实时应用到 Master 音频总线；0 表示静音。"
	)
	settings_box.add_child(volume_row["root"])
	var volume_controls := HBoxContainer.new()
	volume_controls.custom_minimum_size.x = 430
	volume_controls.add_theme_constant_override("separation", 14)
	(volume_row["control"] as Control).add_child(volume_controls)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.custom_minimum_size = Vector2(330, 28)
	volume_slider.focus_mode = Control.FOCUS_ALL
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_controls.add_child(volume_slider)
	volume_value_label = _label("100", 16, C_BLUE, FONT_MONO)
	volume_value_label.custom_minimum_size.x = 64
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_controls.add_child(volume_value_label)
	settings_box.add_child(_setting_separator())

	var display_row: Dictionary = _setting_row(
		ICON_MONITOR,
		"显示模式",
		"在窗口与全屏模式之间切换，不改变渲染分辨率。"
	)
	settings_box.add_child(display_row["root"])
	window_mode_option = OptionButton.new()
	window_mode_option.custom_minimum_size = Vector2(430, 46)
	window_mode_option.focus_mode = Control.FOCUS_ALL
	window_mode_option.add_item("窗口", 0)
	window_mode_option.add_item("全屏", 1)
	window_mode_option.add_theme_font_override("font", FONT_SERIF)
	window_mode_option.add_theme_font_size_override("font_size", 16)
	window_mode_option.add_theme_color_override("font_color", C_BLUE)
	window_mode_option.add_theme_stylebox_override("normal", _control_box(C_WHITE, C_LINE))
	window_mode_option.add_theme_stylebox_override("hover", _control_box(C_PANEL_SOFT, C_BLUE))
	window_mode_option.add_theme_stylebox_override("focus", _control_box(C_PANEL_SOFT, C_BLUE, 2))
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	(display_row["control"] as Control).add_child(window_mode_option)
	settings_box.add_child(_setting_separator())

	var vsync_row: Dictionary = _setting_row(
		ICON_REFRESH,
		"垂直同步",
		"由当前平台与渲染后端决定是否支持。"
	)
	settings_box.add_child(vsync_row["root"])
	vsync_toggle = Button.new()
	vsync_toggle.text = "开启"
	vsync_toggle.icon = ICON_TOGGLE_ON
	vsync_toggle.toggle_mode = true
	vsync_toggle.custom_minimum_size = Vector2(430, 46)
	vsync_toggle.focus_mode = Control.FOCUS_ALL
	vsync_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	vsync_toggle.add_theme_font_override("font", FONT_SERIF)
	vsync_toggle.add_theme_font_size_override("font_size", 16)
	vsync_toggle.add_theme_color_override("font_color", C_BLUE)
	vsync_toggle.add_theme_color_override("font_hover_color", C_WHITE)
	vsync_toggle.add_theme_color_override("font_pressed_color", C_WHITE)
	vsync_toggle.add_theme_color_override("font_focus_color", C_WHITE)
	vsync_toggle.add_theme_color_override("icon_normal_color", C_BLUE)
	vsync_toggle.add_theme_color_override("icon_hover_color", C_WHITE)
	vsync_toggle.add_theme_color_override("icon_pressed_color", C_WHITE)
	vsync_toggle.add_theme_color_override("icon_focus_color", C_WHITE)
	vsync_toggle.add_theme_stylebox_override("normal", _control_box(C_WHITE, C_LINE))
	vsync_toggle.add_theme_stylebox_override("hover", _control_box(C_BLUE, C_BLUE))
	vsync_toggle.add_theme_stylebox_override("pressed", _control_box(C_BLUE_DARK, C_BLUE_DARK))
	vsync_toggle.add_theme_stylebox_override("focus", _control_box(C_BLUE, C_BLUE_DARK, 2))
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	(vsync_row["control"] as Control).add_child(vsync_toggle)

	var actions := HBoxContainer.new()
	actions.custom_minimum_size.y = 58
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	var reset_button := _action_button("恢复默认", ICON_RESET, false)
	reset_button.pressed.connect(_on_restore_defaults)
	actions.add_child(reset_button)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	var return_button := _action_button("返回", ICON_RETURN, true)
	return_button.pressed.connect(func(): return_requested.emit())
	actions.add_child(return_button)

	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 12)
	page.add_child(secondary)
	feedback_label = _label("设置会即时生效并保存。", 14, C_SUBTEXT, FONT_SERIF)
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	secondary.add_child(feedback_label)
	return_title_button = _secondary_button("返回标题", ICON_HOME)
	return_title_button.pressed.connect(func(): return_to_title_requested.emit())
	secondary.add_child(return_title_button)
	var quit_button := _secondary_button("退出游戏", ICON_POWER)
	quit_button.pressed.connect(func(): quit_requested.emit())
	secondary.add_child(quit_button)


func _refresh_controls() -> void:
	if settings_manager == null or volume_slider == null:
		return
	_updating_controls = true
	var settings: Dictionary = settings_manager.get_settings()
	volume_slider.value = float(settings.get("master_volume", 100))
	volume_value_label.text = "%d / 100" % int(volume_slider.value)
	window_mode_option.select(1 if str(settings.get("window_mode", "windowed")) == "fullscreen" else 0)
	vsync_toggle.button_pressed = bool(settings.get("vsync_enabled", true))
	vsync_toggle.text = "开启" if vsync_toggle.button_pressed else "关闭"
	vsync_toggle.icon = ICON_TOGGLE_ON if vsync_toggle.button_pressed else ICON_TOGGLE_OFF
	_updating_controls = false


func _on_volume_changed(value: float) -> void:
	volume_value_label.text = "%d / 100" % int(value)
	if _updating_controls or settings_manager == null:
		return
	_report_result(settings_manager.set_master_volume(int(value)))


func _on_window_mode_selected(index: int) -> void:
	if _updating_controls or settings_manager == null:
		return
	_report_result(settings_manager.set_window_mode("fullscreen" if index == 1 else "windowed"))


func _on_vsync_toggled(enabled: bool) -> void:
	vsync_toggle.text = "开启" if enabled else "关闭"
	vsync_toggle.icon = ICON_TOGGLE_ON if enabled else ICON_TOGGLE_OFF
	if _updating_controls or settings_manager == null:
		return
	_report_result(settings_manager.set_vsync_enabled(enabled))


func _on_restore_defaults() -> void:
	if settings_manager == null:
		return
	_report_result(settings_manager.restore_defaults())
	_refresh_controls()


func _report_result(result: Dictionary) -> void:
	feedback_label.text = (
		"设置已保存"
		if bool(result.get("success", false))
		else "设置已应用，但写入失败"
	)


func _focus_default() -> void:
	if volume_slider != null:
		volume_slider.grab_focus()


func _section_header(chinese: String, english: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_label(chinese, 20, C_BLUE, FONT_SERIF_SEMIBOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label(english, 12, C_SUBTEXT, FONT_MONO))
	return row


func _setting_row(icon: Texture2D, title: String, description: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 92
	row.add_theme_constant_override("separation", 18)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.modulate = C_BLUE
	icon_rect.custom_minimum_size = Vector2(26, 26)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)
	text_box.add_child(_label(title, 18, C_TEXT, FONT_SERIF_SEMIBOLD))
	text_box.add_child(_label(description, 14, C_SUBTEXT, FONT_SERIF))
	var control_box := CenterContainer.new()
	control_box.custom_minimum_size.x = 430
	row.add_child(control_box)
	return {"root": row, "control": control_box}


func _setting_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _style_box(C_DIVIDER, C_DIVIDER, 1, 0))
	return separator


func _action_button(text: String, icon: Texture2D, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.custom_minimum_size = Vector2(210, 52)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT_SERIF_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", C_WHITE if primary else C_BLUE)
	button.add_theme_color_override("font_hover_color", C_WHITE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_focus_color", C_WHITE)
	button.add_theme_color_override("icon_normal_color", C_WHITE if primary else C_BLUE)
	button.add_theme_color_override("icon_hover_color", C_WHITE)
	button.add_theme_color_override("icon_pressed_color", C_WHITE)
	button.add_theme_color_override("icon_focus_color", C_WHITE)
	button.add_theme_stylebox_override("normal", _control_box(C_BLUE if primary else C_WHITE, C_BLUE))
	button.add_theme_stylebox_override("hover", _control_box(C_BLUE_DARK, C_BLUE_DARK))
	button.add_theme_stylebox_override("pressed", _control_box(C_BLUE_DARK, C_BLUE_DARK))
	button.add_theme_stylebox_override("focus", _control_box(C_BLUE, C_BLUE_DARK, 2))
	return button


func _secondary_button(text: String, icon: Texture2D) -> Button:
	var button: Button = _action_button(text, icon, false)
	button.custom_minimum_size = Vector2(180, 42)
	return button


func _control_box(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = _style_box(background, border, width, 4)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
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
