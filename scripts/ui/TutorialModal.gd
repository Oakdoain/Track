extends Control

signal dismissed

const TutorialHintScript := preload("res://scripts/ui/TutorialHint.gd")
const ICON_LIGHTBULB := preload("res://assets/icons/lucide/lightbulb.svg")
const C_BLUE := Color("#143FA4")
const C_PAPER := Color("#F8F8F6")
const MASK_ALPHA := 0.14
const INPUT_LOCK_MSEC := 120

var _prompt_items: Array[Dictionary] = []
var _mask: ColorRect
var _dialog: PanelContainer
var _dialog_target_position := Vector2.ZERO
var _input_unlock_msec: int = 0
var _animation: Tween
var _closing: bool = false
var _message_mode: bool = false
var _message_title: String = ""
var _message_body: String = ""
var _message_footer: String = ""


func configure(prompt_items: Array[Dictionary]) -> void:
	_prompt_items = prompt_items.duplicate(true)


func configure_message(title: String, body: String, footer: String = "点击遮罩或按 Esc 关闭") -> void:
	_message_mode = true
	_message_title = title
	_message_body = body
	_message_footer = footer


func _ready() -> void:
	name = "TutorialModal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	z_index = 300

	_mask = ColorRect.new()
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.color = Color(0.02, 0.06, 0.15, 0.0)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_dialog = PanelContainer.new()
	_dialog.custom_minimum_size = Vector2(560.0, 0.0)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP if _message_mode else Control.MOUSE_FILTER_IGNORE
	if _message_mode:
		_dialog.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton or event is InputEventKey:
				_dialog.accept_event()
		)
	_dialog.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_dialog.add_theme_stylebox_override("panel", _dialog_style())
	center.add_child(_dialog)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	_dialog.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	if _message_mode:
		var icon := TextureRect.new()
		icon.texture = ICON_LIGHTBULB
		icon.custom_minimum_size = Vector2(34.0, 34.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = C_BLUE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)

	var title := Label.new()
	title.text = _message_title if _message_mode else "操作提示"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", C_BLUE)
	title.add_theme_font_size_override("font_size", 21)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	if _message_mode:
		var body := Label.new()
		body.text = _message_body
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_theme_color_override("font_color", C_BLUE)
		body.add_theme_font_size_override("font_size", 17)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(body)
	else:
		for prompt in _prompt_items:
			var hint: PanelContainer = TutorialHintScript.new() as PanelContainer
			hint.call("configure", str(prompt.get("prompt", "mouse_left")), str(prompt.get("text", "")))
			content.add_child(hint)

	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.add_theme_stylebox_override("separator", _divider_style())
	content.add_child(divider)

	var continue_label := Label.new()
	continue_label.text = _message_footer if _message_mode else "点击任意处继续"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.add_theme_color_override("font_color", C_BLUE)
	continue_label.add_theme_font_size_override("font_size", 14)
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(continue_label)

	_input_unlock_msec = Time.get_ticks_msec() + INPUT_LOCK_MSEC
	call_deferred("_begin_enter_animation")
	call_deferred("grab_focus")


func _gui_input(event: InputEvent) -> void:
	if _closing or Time.get_ticks_msec() < _input_unlock_msec:
		accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.pressed:
			accept_event()
			_dismiss()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ESCAPE if _message_mode else key_event.keycode in [KEY_ENTER, KEY_SPACE]
		):
			accept_event()
			_dismiss()


func _begin_enter_animation() -> void:
	await get_tree().process_frame

	if _dialog == null or not is_instance_valid(_dialog):
		return

	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog_target_position = _dialog.position
	_dialog.position = _dialog_target_position + Vector2(0.0, 6.0)
	_dialog.scale = Vector2(0.96, 0.96)
	_kill_animation()
	_animation = create_tween().set_parallel(true)
	_animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_mask, "color", Color(0.02, 0.06, 0.15, MASK_ALPHA), 0.15)
	_animation.tween_property(_dialog, "modulate", Color.WHITE, 0.18)
	_animation.tween_property(_dialog, "scale", Vector2.ONE, 0.18)
	_animation.tween_property(_dialog, "position", _dialog_target_position, 0.18)


func _dismiss() -> void:
	if _closing:
		return

	_closing = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_kill_animation()
	_animation = create_tween().set_parallel(true)
	_animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_property(_mask, "color", Color(0.02, 0.06, 0.15, 0.0), 0.12)
	_animation.tween_property(_dialog, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.12)
	_animation.tween_property(_dialog, "scale", Vector2(0.98, 0.98), 0.12)
	await _animation.finished
	dismissed.emit()
	queue_free()


func _kill_animation() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()


func _dialog_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PAPER
	style.border_color = C_BLUE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _divider_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#D7DEF3")
	style.content_margin_top = 1.0
	return style
