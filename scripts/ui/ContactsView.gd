extends Control
class_name ContactsView

signal contact_pressed(contact_id: String)

const FONT_SERIF_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const ICON_PHONE := preload("res://assets/icons/lucide/phone.svg")
const C_BG := Color("#F7F9FF")
const C_BLUE := Color("#123FA4")
const C_BLUE_SOFT := Color("#EEF3FF")
const C_WHITE := Color("#FFFFFF")
const C_MUTED := Color("#8A91A3")

var _list: VBoxContainer
var _buttons_by_contact_id: Dictionary = {}


func _ready() -> void:
	_build()


func set_contacts(contacts: Array[Dictionary]) -> void:
	if _list == null:
		_build()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons_by_contact_id.clear()
	var seen: Dictionary = {}
	for contact in contacts:
		var contact_id := str(contact.get("id", ""))
		var display_name := str(contact.get("display_name", ""))
		if contact_id == "" or display_name == "" or seen.has(contact_id):
			continue
		seen[contact_id] = true
		var button := Button.new()
		button.name = "Contact_" + contact_id
		var status_text := str(contact.get("status_text", ""))
		button.text = display_name if status_text == "" else "%s（%s）" % [display_name, status_text]
		button.icon = ICON_PHONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_override("font", FONT_SERIF_REGULAR)
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", C_BLUE)
		button.add_theme_color_override("font_hover_color", C_BLUE)
		button.add_theme_color_override("font_pressed_color", C_BLUE)
		button.add_theme_color_override("font_focus_color", C_BLUE)
		button.add_theme_color_override("font_disabled_color", C_MUTED)
		button.add_theme_color_override("icon_normal_color", C_BLUE)
		button.add_theme_constant_override("icon_max_width", 18)
		button.add_theme_stylebox_override("normal", _style(C_WHITE, C_BLUE, 1, 3))
		button.add_theme_stylebox_override("hover", _style(C_BLUE_SOFT, C_BLUE, 1, 3))
		button.add_theme_stylebox_override("pressed", _style(C_BLUE_SOFT, C_BLUE, 2, 3))
		button.add_theme_stylebox_override("focus", _style(C_BLUE_SOFT, C_BLUE, 2, 3))
		button.pressed.connect(_emit_contact.bind(contact_id))
		_list.add_child(button)
		_buttons_by_contact_id[contact_id] = button


func get_contact_control(contact_id: String) -> Control:
	var value: Variant = _buttons_by_contact_id.get(contact_id)
	return value as Control if value is Control and is_instance_valid(value) else null


func _build() -> void:
	if _list != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.name = "ContactsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.name = "ContactList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	margin.add_child(_list)


func _emit_contact(contact_id: String) -> void:
	contact_pressed.emit(contact_id)


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style
