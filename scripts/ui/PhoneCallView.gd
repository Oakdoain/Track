extends Control
class_name PhoneCallView

signal answer_pressed
signal reject_pressed
signal choice_pressed(choice_id: String)
signal keyword_pressed(keyword_id: String, keyword: String, message_id: String, local_position: Vector2)

const PhoneMessageViewScript := preload("res://scripts/ui/PhoneMessageView.gd")
const FONT_SERIF_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SERIF_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")
const ICON_ACCEPT := preload("res://assets/icons/lucide/phone-call.svg")
const ICON_REJECT := preload("res://assets/icons/lucide/phone-off.svg")
const C_BG := Color("#F7F9FF")
const C_BLUE := Color("#143FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#99ABE6")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_MUTED := Color("#8995B8")
const C_WHITE := Color("#FFFFFF")
const C_WARNING := Color("#9E2F3E")
const C_WARNING_DARK := Color("#74212D")
const C_SCROLL_IDLE := Color("#9AADE8")
const C_SCROLL_PRESSED := Color("#0B2F87")
const PHONE_BUTTON_SIZE := Vector2(56.0, 56.0)
const PHONE_ICON_SIZE := Vector2(24.0, 24.0)
const ACCEPT_ICON_OPTICAL_OFFSET := Vector2(-1.0, 1.0)
const REJECT_ICON_OPTICAL_OFFSET := Vector2(-2.0, 1.0)
const CALLING_DOT_INTERVAL := 0.4
const CALLING_DOT_MAX := 6
const REVEAL_SCROLL_INTERVAL_MSEC := 70
const TRANSCRIPT_SCROLL_HIT_WIDTH := 9.0
const TRANSCRIPT_SCROLL_IDLE_WIDTH := 4
const TRANSCRIPT_SCROLL_ACTIVE_WIDTH := 6
const REPLY_HEIGHT_DEFAULT := 200.0
const REPLY_HEIGHT_COMPACT := 160.0
const COMPACT_VIEW_HEIGHT := 650.0

var _incoming_call_view: Control
var _incoming_contact_name: Label
var _incoming_status: Label
var _reject_button: Button
var _accept_button: Button
var _reject_icon: TextureRect
var _accept_icon: TextureRect
var _active_call_view: Control
var _active_contact_name: Label
var _active_status_label: Label
var _scroll: ScrollContainer
var _message_list: VBoxContainer
var _message_views: Array[PhoneMessageView] = []
var _transcribing_label: Label
var _call_ended_status: Label
var _reply_area: Control
var _reply_prompt: Label
var _choice_list: VBoxContainer
var _rendered_call_id: String = ""
var _rendered_message_count: int = 0
var _choice_signature: String = ""
var _choice_input_locked: bool = false
var _scroll_request_generation: int = 0
var _suspend_scroll_requests: bool = false
var _calling_animation_active: bool = false
var _calling_dot_count: int = 1
var _calling_dot_elapsed: float = 0.0
var _last_reveal_scroll_msec: int = -REVEAL_SCROLL_INTERVAL_MSEC


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if not _calling_animation_active or delta <= 0.0:
		return
	_calling_dot_elapsed += delta
	while _calling_dot_elapsed >= CALLING_DOT_INTERVAL:
		_calling_dot_elapsed -= CALLING_DOT_INTERVAL
		_calling_dot_count = (_calling_dot_count % CALLING_DOT_MAX) + 1
		_update_calling_status_text()


func render_call(active_call: Dictionary, contact: Dictionary) -> void:
	if _message_list == null:
		_build()
	if active_call.is_empty():
		clear_call()
		return
	var call_id := str(active_call.get("call_id", ""))
	if call_id != _rendered_call_id:
		clear_call()
		_rendered_call_id = call_id
	var contact_name := str(contact.get("display_name", ""))
	var status := str(active_call.get("status", ""))
	var incoming := status == "incoming_waiting"
	var outgoing_waiting := status == "outgoing_waiting"
	var waiting := incoming or outgoing_waiting
	var ending := status == "ending"
	_incoming_call_view.visible = waiting
	_active_call_view.visible = not waiting
	_incoming_contact_name.text = contact_name
	_active_contact_name.text = contact_name
	_active_status_label.text = str(active_call.get("view_subtitle", "语音转写"))
	if waiting:
		_start_calling_animation()
		_render_waiting_state(incoming)
		return
	_stop_calling_animation()
	_call_ended_status.visible = ending
	_reply_area.visible = not ending
	_suspend_scroll_requests = true
	var structural_change := false
	var reveal_changed := false
	var reveal_completed := false
	var had_indicator := _transcribing_label != null and is_instance_valid(_transcribing_label)
	_remove_transcribing_indicator()
	var transcript_value: Variant = active_call.get("transcript", [])
	var transcript: Array = transcript_value if transcript_value is Array else []
	if transcript.size() < _rendered_message_count:
		_clear_message_list()
		structural_change = true
	for index in range(_rendered_message_count, transcript.size()):
		var entry_value: Variant = transcript[index]
		if entry_value is Dictionary:
			_append_message(entry_value as Dictionary)
			structural_change = true
	_rendered_message_count = transcript.size()
	for index in range(mini(transcript.size(), _message_views.size())):
		if not (transcript[index] is Dictionary):
			continue
		var entry: Dictionary = transcript[index]
		var completed := bool(entry.get("reveal_completed", true))
		if _message_views[index].set_reveal_progress(int(entry.get("visible_characters", str(entry.get("text", "")).length())), completed):
			reveal_changed = true
			reveal_completed = reveal_completed or completed
	if bool(active_call.get("is_waiting_message", false)):
		_add_transcribing_indicator()
	var has_indicator := _transcribing_label != null and is_instance_valid(_transcribing_label)
	structural_change = structural_change or had_indicator != has_indicator
	_render_choices(active_call)
	_suspend_scroll_requests = false
	if structural_change or reveal_completed:
		request_scroll_to_bottom()
	elif reveal_changed:
		_request_reveal_scroll_to_bottom()


func clear_call() -> void:
	_rendered_call_id = ""
	_rendered_message_count = 0
	_choice_signature = ""
	_choice_input_locked = false
	_stop_calling_animation()
	_scroll_request_generation += 1
	_suspend_scroll_requests = true
	if _message_list != null:
		_clear_message_list()
	if _choice_list != null:
		_clear_children(_choice_list)
	if _incoming_contact_name != null:
		_incoming_contact_name.text = ""
		_active_contact_name.text = ""
		_incoming_status.text = ""
		_incoming_call_view.visible = false
		_active_call_view.visible = false
		if _call_ended_status != null:
			_call_ended_status.visible = false
		if _reply_area != null:
			_reply_area.visible = true
	_suspend_scroll_requests = false
	if _scroll != null:
		_scroll.scroll_vertical = 0


func is_showing_incoming_call() -> bool:
	return _incoming_call_view != null and _incoming_call_view.visible


func get_reply_area_height() -> float:
	return _reply_area.custom_minimum_size.y if _reply_area != null else 0.0


func get_rendered_message_count() -> int:
	return _rendered_message_count


func _build() -> void:
	if _message_list != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_build_incoming_view()
	_build_active_view()
	resized.connect(_on_view_resized)
	call_deferred("_on_view_resized")


func _build_incoming_view() -> void:
	_incoming_call_view = Control.new()
	_incoming_call_view.name = "IncomingCallView"
	_incoming_call_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_incoming_call_view)
	var margin := MarginContainer.new()
	margin.name = "IncomingMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 34)
	_incoming_call_view.add_child(margin)
	var layout := VBoxContainer.new()
	layout.name = "IncomingLayout"
	margin.add_child(layout)
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(top_spacer)
	var center := VBoxContainer.new()
	center.name = "IncomingCenter"
	center.add_theme_constant_override("separation", 10)
	layout.add_child(center)
	_incoming_contact_name = _label("", 25, C_BLUE, FONT_SERIF_SEMIBOLD)
	_incoming_contact_name.name = "ContactName"
	_incoming_contact_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_incoming_contact_name)
	_incoming_status = _label("正在呼叫.", 16, C_SUBTEXT, FONT_SERIF_REGULAR)
	_incoming_status.name = "CallingStatus"
	_incoming_status.custom_minimum_size.x = ceilf(FONT_SERIF_REGULAR.get_string_size("正在呼叫......", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x)
	_incoming_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_incoming_status)
	var middle_spacer := Control.new()
	middle_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle_spacer)
	var actions := HBoxContainer.new()
	actions.name = "IncomingActions"
	actions.custom_minimum_size.y = 56
	layout.add_child(actions)
	var leading := Control.new()
	leading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(leading)
	var reject_root := _phone_action_root(false)
	_reject_button.tooltip_text = "拒绝来电"
	_reject_button.pressed.connect(_on_reject_pressed)
	actions.add_child(reject_root)
	var action_gap := Control.new()
	action_gap.custom_minimum_size.x = 96
	actions.add_child(action_gap)
	var accept_root := _phone_action_root(true)
	_accept_button.tooltip_text = "接听电话"
	_accept_button.pressed.connect(_on_accept_pressed)
	actions.add_child(accept_root)
	var trailing := Control.new()
	trailing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(trailing)


func _build_active_view() -> void:
	_active_call_view = Control.new()
	_active_call_view.name = "ActiveCallView"
	_active_call_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_active_call_view.visible = false
	add_child(_active_call_view)
	var layout := VBoxContainer.new()
	layout.name = "ActiveCallLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	_active_call_view.add_child(layout)
	var header_margin := MarginContainer.new()
	header_margin.name = "CallHeader"
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_right", 20)
	header_margin.add_theme_constant_override("margin_top", 14)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	layout.add_child(header_margin)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	header_margin.add_child(header)
	_active_contact_name = _label("", 20, C_BLUE, FONT_SERIF_SEMIBOLD)
	_active_contact_name.name = "ContactName"
	header.add_child(_active_contact_name)
	_active_status_label = _label("语音转写", 14, C_SUBTEXT, FONT_SERIF_REGULAR)
	_active_status_label.name = "TranscriptStatus"
	header.add_child(_active_status_label)
	var header_separator := HSeparator.new()
	header_separator.name = "TopSeparator"
	header_separator.add_theme_stylebox_override("separator", _style(C_LINE, C_LINE, 1, 0))
	layout.add_child(header_separator)
	var transcript_clip_root := Control.new()
	transcript_clip_root.name = "TranscriptClipRoot"
	transcript_clip_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_clip_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript_clip_root.clip_contents = true
	layout.add_child(transcript_clip_root)
	var transcript_margin := MarginContainer.new()
	transcript_margin.name = "TranscriptArea"
	transcript_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transcript_margin.add_theme_constant_override("margin_left", 14)
	transcript_margin.add_theme_constant_override("margin_right", 0)
	transcript_margin.add_theme_constant_override("margin_top", 0)
	transcript_margin.add_theme_constant_override("margin_bottom", 0)
	transcript_clip_root.add_child(transcript_margin)
	var ended_center := CenterContainer.new()
	ended_center.name = "CallEndedStatusCenter"
	ended_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ended_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ended_center.z_index = 20
	transcript_clip_root.add_child(ended_center)
	_call_ended_status = _label("通话已结束", 16, C_SUBTEXT, FONT_SERIF_REGULAR)
	_call_ended_status.name = "CallEndedStatus"
	_call_ended_status.visible = false
	_call_ended_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ended_center.add_child(_call_ended_status)
	_scroll = ScrollContainer.new()
	_scroll.name = "TranscriptScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.clip_contents = true
	transcript_margin.add_child(_scroll)
	var message_margin := MarginContainer.new()
	message_margin.name = "MessageContentMargin"
	message_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_margin.add_theme_constant_override("margin_right", 14)
	message_margin.add_theme_constant_override("margin_top", 0)
	message_margin.add_theme_constant_override("margin_bottom", 0)
	_scroll.add_child(message_margin)
	_message_list = VBoxContainer.new()
	_message_list.name = "MessageList"
	_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_list.add_theme_constant_override("separation", 12)
	message_margin.add_child(_message_list)
	_style_transcript_scrollbar(_scroll.get_v_scroll_bar())
	_build_reply_area(layout)


func _build_reply_area(parent: VBoxContainer) -> void:
	_reply_area = VBoxContainer.new()
	_reply_area.name = "ReplyArea"
	_reply_area.custom_minimum_size.y = REPLY_HEIGHT_DEFAULT
	_reply_area.add_theme_constant_override("separation", 0)
	parent.add_child(_reply_area)
	var separator := HSeparator.new()
	separator.name = "BottomSeparator"
	separator.add_theme_stylebox_override("separator", _style(C_LINE, C_LINE, 1, 0))
	_reply_area.add_child(separator)
	var reply_margin := MarginContainer.new()
	reply_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reply_margin.add_theme_constant_override("margin_left", 18)
	reply_margin.add_theme_constant_override("margin_right", 18)
	reply_margin.add_theme_constant_override("margin_top", 10)
	reply_margin.add_theme_constant_override("margin_bottom", 12)
	_reply_area.add_child(reply_margin)
	var reply_layout := VBoxContainer.new()
	reply_layout.add_theme_constant_override("separation", 8)
	reply_margin.add_child(reply_layout)
	_reply_prompt = _label("选择回应", 14, C_SUBTEXT, FONT_SERIF_REGULAR)
	_reply_prompt.name = "ReplyPrompt"
	reply_layout.add_child(_reply_prompt)
	var choice_scroll := ScrollContainer.new()
	choice_scroll.name = "ReplyChoiceScroll"
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	reply_layout.add_child(choice_scroll)
	_choice_list = VBoxContainer.new()
	_choice_list.name = "ReplyChoiceList"
	_choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_list.add_theme_constant_override("separation", 9)
	choice_scroll.add_child(_choice_list)


func _render_waiting_state(incoming: bool) -> void:
	_clear_children(_choice_list)
	_choice_signature = "incoming_waiting" if incoming else "outgoing_waiting"
	_choice_input_locked = false
	_reject_button.disabled = false
	_accept_button.disabled = not incoming
	_reject_button.tooltip_text = "拒绝来电" if incoming else "挂断电话"
	if _accept_button.get_parent() != null:
		(_accept_button.get_parent() as Control).visible = incoming
	_refresh_phone_icon_color(_reject_button, _reject_icon, C_WARNING)
	_refresh_phone_icon_color(_accept_button, _accept_icon, C_BLUE)


func _append_message(entry: Dictionary) -> void:
	var message_view := PhoneMessageViewScript.new() as PhoneMessageView
	message_view.configure(entry)
	message_view.keyword_pressed.connect(_forward_keyword_pressed)
	message_view.layout_changed.connect(_request_reveal_scroll_to_bottom)
	_message_list.add_child(message_view)
	_message_views.append(message_view)
	request_scroll_to_bottom()


func _render_choices(active_call: Dictionary) -> void:
	var waiting := bool(active_call.get("is_waiting_message", false))
	var choices: Array = active_call.get("presented_choices", []) if active_call.get("presented_choices", []) is Array else []
	var signature := ("waiting:" if waiting else "ready:") + JSON.stringify(choices)
	if signature == _choice_signature:
		return
	_choice_signature = signature
	_choice_input_locked = false
	_clear_children(_choice_list)
	_reply_prompt.text = "选择回应"
	if waiting:
		return
	for choice_value in choices:
		if choice_value is Dictionary:
			var choice: Dictionary = choice_value
			_choice_list.add_child(_choice_button(str(choice.get("text", "")), str(choice.get("id", ""))))


func _choice_button(text: String, choice_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_override("font", FONT_SERIF_REGULAR)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", C_BLUE)
	button.add_theme_color_override("font_hover_color", C_WHITE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_focus_color", C_WHITE)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	button.add_theme_stylebox_override("normal", _style(C_WHITE, C_BLUE, 1, 3))
	button.add_theme_stylebox_override("hover", _style(C_BLUE, C_BLUE, 1, 3))
	button.add_theme_stylebox_override("pressed", _style(C_BLUE_DARK, C_BLUE_DARK, 2, 3))
	button.add_theme_stylebox_override("focus", _style(C_BLUE, C_BLUE, 2, 3))
	button.add_theme_stylebox_override("disabled", _style(C_BG, C_LINE, 1, 3))
	button.pressed.connect(_on_choice_button_pressed.bind(choice_id))
	return button


func _phone_action_root(accept: bool) -> Control:
	var root := Control.new()
	root.name = "AcceptCallRoot" if accept else "RejectCallRoot"
	root.custom_minimum_size = PHONE_BUTTON_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var button := _round_phone_button(accept)
	button.name = "AcceptCallButton" if accept else "RejectCallButton"
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(button)
	var icon_center := CenterContainer.new()
	icon_center.name = "AcceptIconCenter" if accept else "RejectIconCenter"
	icon_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var optical_offset := ACCEPT_ICON_OPTICAL_OFFSET if accept else REJECT_ICON_OPTICAL_OFFSET
	icon_center.offset_left += optical_offset.x
	icon_center.offset_right += optical_offset.x
	icon_center.offset_top += optical_offset.y
	icon_center.offset_bottom += optical_offset.y
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon_center)
	var icon := TextureRect.new()
	icon.name = "AcceptIcon" if accept else "RejectIcon"
	icon.custom_minimum_size = PHONE_ICON_SIZE
	icon.texture = ICON_ACCEPT if accept else ICON_REJECT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = C_BLUE if accept else C_WARNING
	icon_center.add_child(icon)
	if accept:
		_accept_button = button
		_accept_icon = icon
	else:
		_reject_button = button
		_reject_icon = icon
	_bind_phone_icon_color(button, icon, C_BLUE if accept else C_WARNING)
	return root


func _round_phone_button(accept: bool) -> Button:
	var button := Button.new()
	var normal_color := C_BLUE if accept else C_WARNING
	var pressed_color := C_BLUE_DARK if accept else C_WARNING_DARK
	button.icon = null
	button.text = ""
	button.custom_minimum_size = PHONE_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _circle_style(Color.TRANSPARENT, normal_color, 2))
	button.add_theme_stylebox_override("hover", _circle_style(normal_color, normal_color, 2))
	button.add_theme_stylebox_override("pressed", _circle_style(pressed_color, pressed_color, 2))
	button.add_theme_stylebox_override("focus", _circle_style(normal_color, normal_color, 2))
	button.add_theme_stylebox_override("disabled", _circle_style(Color.TRANSPARENT, C_MUTED, 2))
	return button


func _bind_phone_icon_color(button: Button, icon: TextureRect, normal_color: Color) -> void:
	button.mouse_entered.connect(_refresh_phone_icon_color.bind(button, icon, normal_color))
	button.mouse_exited.connect(_refresh_phone_icon_color.bind(button, icon, normal_color))
	button.focus_entered.connect(_refresh_phone_icon_color.bind(button, icon, normal_color))
	button.focus_exited.connect(_refresh_phone_icon_color.bind(button, icon, normal_color))
	button.button_down.connect(_set_phone_icon_color.bind(icon, C_WHITE))
	button.button_up.connect(_refresh_phone_icon_color.bind(button, icon, normal_color))


func _refresh_phone_icon_color(button: Button, icon: TextureRect, normal_color: Color) -> void:
	if not is_instance_valid(button) or not is_instance_valid(icon):
		return
	if button.disabled:
		icon.modulate = C_MUTED
	elif button.is_hovered() or button.has_focus() or button.is_pressed():
		icon.modulate = C_WHITE
	else:
		icon.modulate = normal_color


func _set_phone_icon_color(icon: TextureRect, color: Color) -> void:
	if is_instance_valid(icon):
		icon.modulate = color


func _on_accept_pressed() -> void:
	_accept_button.disabled = true
	_reject_button.disabled = true
	_refresh_phone_icon_color(_accept_button, _accept_icon, C_BLUE)
	_refresh_phone_icon_color(_reject_button, _reject_icon, C_WARNING)
	answer_pressed.emit()


func _on_reject_pressed() -> void:
	_accept_button.disabled = true
	_reject_button.disabled = true
	_refresh_phone_icon_color(_accept_button, _accept_icon, C_BLUE)
	_refresh_phone_icon_color(_reject_button, _reject_icon, C_WARNING)
	reject_pressed.emit()


func _on_choice_button_pressed(choice_id: String) -> void:
	if _choice_input_locked:
		return
	_choice_input_locked = true
	for child in _choice_list.get_children():
		if child is Button:
			(child as Button).disabled = true
	choice_pressed.emit(choice_id)


func _forward_keyword_pressed(keyword_id: String, keyword: String, message_id: String, local_position: Vector2) -> void:
	keyword_pressed.emit(keyword_id, keyword, message_id, local_position)


func _add_transcribing_indicator() -> void:
	if _transcribing_label != null and is_instance_valid(_transcribing_label):
		return
	_transcribing_label = _label("正在转写……", 13, C_SUBTEXT, FONT_SERIF_REGULAR)
	_transcribing_label.name = "TranscribingIndicator"
	_message_list.add_child(_transcribing_label)
	request_scroll_to_bottom()


func _remove_transcribing_indicator() -> void:
	var removed := false
	if _transcribing_label != null and is_instance_valid(_transcribing_label):
		_message_list.remove_child(_transcribing_label)
		_transcribing_label.queue_free()
		removed = true
	_transcribing_label = null
	if removed:
		request_scroll_to_bottom()


func _start_calling_animation() -> void:
	if _calling_animation_active:
		return
	_calling_animation_active = true
	_calling_dot_count = 1
	_calling_dot_elapsed = 0.0
	_update_calling_status_text()


func _stop_calling_animation() -> void:
	_calling_animation_active = false
	_calling_dot_count = 1
	_calling_dot_elapsed = 0.0


func _update_calling_status_text() -> void:
	if _incoming_status != null:
		_incoming_status.text = "正在呼叫" + ".".repeat(_calling_dot_count)


func _request_reveal_scroll_to_bottom() -> void:
	if _scroll == null or _suspend_scroll_requests:
		return
	var now := Time.get_ticks_msec()
	if now - _last_reveal_scroll_msec < REVEAL_SCROLL_INTERVAL_MSEC:
		return
	_last_reveal_scroll_msec = now
	call_deferred("_apply_reveal_scroll_after_layout")


func _apply_reveal_scroll_after_layout() -> void:
	if not is_inside_tree() or not is_instance_valid(_scroll):
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_apply_transcript_scroll_to_bottom()


func request_scroll_to_bottom() -> void:
	if _scroll == null or _suspend_scroll_requests:
		return
	_scroll_request_generation += 1
	call_deferred("_settle_transcript_scroll_to_bottom", _scroll_request_generation)


func _settle_transcript_scroll_to_bottom(generation: int) -> void:
	if generation != _scroll_request_generation or not is_inside_tree():
		return
	await get_tree().process_frame
	if generation != _scroll_request_generation or not is_instance_valid(_scroll):
		return
	await get_tree().process_frame
	if generation != _scroll_request_generation or not is_instance_valid(_scroll):
		return
	_apply_transcript_scroll_to_bottom()
	await get_tree().process_frame
	if generation == _scroll_request_generation and is_instance_valid(_scroll):
		_apply_transcript_scroll_to_bottom()


func _apply_transcript_scroll_to_bottom() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = ceili(bar.max_value)


func _style_transcript_scrollbar(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x = TRANSCRIPT_SCROLL_HIT_WIDTH
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("scroll_focus", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("grabber", _scrollbar_strip(C_SCROLL_IDLE, TRANSCRIPT_SCROLL_IDLE_WIDTH))
	bar.add_theme_stylebox_override("grabber_highlight", _scrollbar_strip(C_BLUE, TRANSCRIPT_SCROLL_ACTIVE_WIDTH))
	bar.add_theme_stylebox_override("grabber_pressed", _scrollbar_strip(C_SCROLL_PRESSED, TRANSCRIPT_SCROLL_ACTIVE_WIDTH))


func _scrollbar_strip(color: Color, thickness: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.border_width_right = thickness
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	return style


func _on_view_resized() -> void:
	_update_reply_height()
	request_scroll_to_bottom()


func _update_reply_height() -> void:
	if _reply_area == null:
		return
	_reply_area.custom_minimum_size.y = (
		REPLY_HEIGHT_COMPACT
		if size.y <= COMPACT_VIEW_HEIGHT
		else REPLY_HEIGHT_DEFAULT
	)


func _clear_message_list() -> void:
	_remove_transcribing_indicator()
	_clear_children(_message_list)
	_message_views.clear()
	_rendered_message_count = 0


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _circle_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := _style(background, border, width, 28)
	return style


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
