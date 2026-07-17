extends PanelContainer

const KenneyAssetCatalog := preload("res://scripts/ui/KenneyAssetCatalog.gd")
const C_BLUE := Color("#143FA4")
const C_BLUE_SOFT := Color("#EAF0FF")
const C_LINE := Color("#9AADE8")


func configure(prompt_key: String, message: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, 42.0)
	add_theme_stylebox_override("panel", _style_box())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var texture: Texture2D = KenneyAssetCatalog.prompt(prompt_key)

	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = C_BLUE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var label := Label.new()
	label.text = message
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", C_BLUE)
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)


func _style_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = C_BLUE_SOFT
	box.border_color = C_LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	return box
