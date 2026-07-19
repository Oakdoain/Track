extends HBoxContainer
class_name PhoneMessageView

signal keyword_pressed(keyword_id: String, keyword: String, message_id: String, local_position: Vector2)
signal layout_changed

const FONT_SERIF_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const C_BLUE := Color("#143FA4")
const C_BLUE_SOFT := Color("#EEF3FF")
const C_TEXT := Color("#26314C")
const C_WHITE := Color("#FFFFFF")
const KEYWORD_META_PREFIX := "phone_keyword://"
const MAX_WIDTH_RATIO := 0.76
const HORIZONTAL_PADDING := 26.0

var _bubble: PanelContainer
var _text_label: RichTextLabel
var _text: String = ""
var _message_id: String = ""
var _reveal_completed: bool = true


func configure(entry: Dictionary) -> void:
	_text = str(entry.get("text", ""))
	_message_id = str(entry.get("message_id", ""))
	name = "Message_" + _message_id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	var is_player := str(entry.get("speaker", "")) == "player"
	if is_player:
		add_child(_expanding_spacer())
	_bubble = PanelContainer.new()
	_bubble.name = "MessageBubble"
	_bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_player else Control.SIZE_SHRINK_BEGIN
	_bubble.add_theme_stylebox_override("panel", _style(C_BLUE_SOFT if is_player else C_WHITE, C_BLUE, 1, 3))
	add_child(_bubble)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 13)
	padding.add_theme_constant_override("margin_right", 13)
	padding.add_theme_constant_override("margin_top", 9)
	padding.add_theme_constant_override("margin_bottom", 9)
	_bubble.add_child(padding)
	_text_label = RichTextLabel.new()
	_text_label.name = "MessageText"
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.selection_enabled = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size.y = 22
	_text_label.add_theme_font_override("normal_font", FONT_SERIF_REGULAR)
	_text_label.add_theme_font_size_override("normal_font_size", 15)
	_text_label.add_theme_color_override("default_color", C_TEXT)
	_text_label.meta_clicked.connect(_on_meta_clicked)
	padding.add_child(_text_label)
	_append_text(entry.get("keywords", []))
	set_reveal_progress(
		int(entry.get("visible_characters", _text.length())),
		bool(entry.get("reveal_completed", true))
	)
	if not is_player:
		add_child(_expanding_spacer())
	resized.connect(_update_bubble_width)
	call_deferred("_update_bubble_width")


func get_maximum_bubble_width() -> float:
	return floorf(size.x * MAX_WIDTH_RATIO)


func set_reveal_progress(visible_characters: int, completed: bool) -> bool:
	if _text_label == null:
		return false
	var target := -1 if completed else clampi(visible_characters, 0, _text.length())
	var changed := _text_label.visible_characters != target or _reveal_completed != completed
	_reveal_completed = completed
	_text_label.visible_characters = target
	_text_label.selection_enabled = completed
	return changed


func _update_bubble_width() -> void:
	if _bubble == null or _text_label == null or size.x <= 0.0:
		return
	var maximum_width := maxf(96.0, get_maximum_bubble_width())
	var measured_width := FONT_SERIF_REGULAR.get_string_size(
		_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15
	).x
	var bubble_width := minf(maximum_width, ceilf(measured_width + HORIZONTAL_PADDING))
	_bubble.custom_minimum_size.x = maxf(44.0, bubble_width)
	_text_label.custom_minimum_size.x = maxf(18.0, bubble_width - HORIZONTAL_PADDING)
	layout_changed.emit()


func _append_text(keywords_value: Variant) -> void:
	var ranges: Array[Dictionary] = []
	if keywords_value is Array:
		for keyword_value in (keywords_value as Array):
			if not (keyword_value is Dictionary):
				continue
			var keyword_data: Dictionary = keyword_value
			var keyword := str(keyword_data.get("text", ""))
			var occurrence := int(keyword_data.get("occurrence_index", 0))
			var start := _find_occurrence(_text, keyword, occurrence)
			if start >= 0:
				ranges.append({"start": start, "end": start + keyword.length(), "data": keyword_data})
	ranges.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("start", 0)) < int(right.get("start", 0)))
	var cursor := 0
	for range_data in ranges:
		var start := int(range_data.get("start", 0))
		var end := int(range_data.get("end", start))
		if start < cursor:
			continue
		if start > cursor:
			_text_label.add_text(_text.substr(cursor, start - cursor))
		var keyword_data: Dictionary = range_data.get("data", {})
		var meta := "%s%s|%s" % [KEYWORD_META_PREFIX, str(keyword_data.get("keyword_id", "")), str(keyword_data.get("text", ""))]
		_text_label.push_meta(meta)
		_text_label.add_text(_text.substr(start, end - start))
		_text_label.pop()
		cursor = end
	if cursor < _text.length():
		_text_label.add_text(_text.substr(cursor))


func _on_meta_clicked(meta_value: Variant) -> void:
	if not _reveal_completed:
		return
	if not (meta_value is String):
		return
	var meta := str(meta_value)
	if not meta.begins_with(KEYWORD_META_PREFIX):
		return
	var parts := meta.trim_prefix(KEYWORD_META_PREFIX).split("|", false, 1)
	if parts.size() == 2:
		keyword_pressed.emit(parts[0], parts[1], _message_id, get_local_mouse_position())


func _find_occurrence(text: String, needle: String, occurrence: int) -> int:
	if needle == "" or occurrence < 0:
		return -1
	var search_from := 0
	var found := -1
	for _index in range(occurrence + 1):
		found = text.find(needle, search_from)
		if found < 0:
			return -1
		search_from = found + needle.length()
	return found


func _expanding_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
