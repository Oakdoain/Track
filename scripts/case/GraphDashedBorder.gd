extends Control

var line_color := Color("#8995B8")
var line_width := 1.0
var dash_length := 7.0
var gap_length := 5.0


func configure(color: Color, width: float = 1.0) -> void:
	line_color = color
	line_width = width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var inset := line_width * 0.5
	var left := inset
	var top := inset
	var right := maxf(left, size.x - inset)
	var bottom := maxf(top, size.y - inset)
	_draw_dashed(Vector2(left, top), Vector2(right, top))
	_draw_dashed(Vector2(right, top), Vector2(right, bottom))
	_draw_dashed(Vector2(right, bottom), Vector2(left, bottom))
	_draw_dashed(Vector2(left, bottom), Vector2(left, top))


func _draw_dashed(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	var length := delta.length()

	if length <= 0.0:
		return

	var direction := delta / length
	var offset := 0.0

	while offset < length:
		var segment_end := minf(length, offset + dash_length)
		draw_line(from + direction * offset, from + direction * segment_end, line_color, line_width, true)
		offset += dash_length + gap_length
