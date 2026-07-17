extends Control
class_name CaseGraphCanvas

const DEFAULT_EDGE_COLOR := Color("#99ABE6")
const DEFAULT_ARROW_SIZE := 7.0

var _edges: Array[Dictionary] = []


func configure(
	canvas_size: Vector2,
	edges: Array[Dictionary]
) -> void:
	custom_minimum_size = canvas_size
	size = canvas_size
	_edges = edges.duplicate(true)
	queue_redraw()


func _draw() -> void:
	for edge in _edges:
		_draw_edge(edge)


func _draw_edge(edge: Dictionary) -> void:
	var points_value: Variant = edge.get("curve", edge.get("points", PackedVector2Array()))
	var points := PackedVector2Array()

	if points_value is PackedVector2Array:
		points = points_value
	elif points_value is Array:
		for point in points_value:
			if point is Vector2:
				points.append(point)

	if points.size() == 4 and edge.has("curve"):
		points = _sample_cubic(points[0], points[1], points[2], points[3])

	if points.size() < 2:
		return

	var color: Color = edge.get("color", DEFAULT_EDGE_COLOR)
	var width: float = float(edge.get("width", 1.0))
	var dashed: bool = bool(edge.get("dashed", false))

	if dashed:
		_draw_dashed_polyline(points, color, width)
	else:
		for index in range(points.size() - 1):
			draw_line(points[index], points[index + 1], color, width, true)

	_draw_arrow(points[points.size() - 2], points[points.size() - 1], color, float(edge.get("arrow_size", DEFAULT_ARROW_SIZE)))


func _sample_cubic(start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var control_length := start.distance_to(control_a) + control_a.distance_to(control_b) + control_b.distance_to(finish)
	var segment_count := clampi(ceili(control_length / 18.0), 24, 96)
	for index in range(segment_count + 1):
		var t := float(index) / float(segment_count)
		var inverse := 1.0 - t
		result.append(
			inverse * inverse * inverse * start
			+ 3.0 * inverse * inverse * t * control_a
			+ 3.0 * inverse * t * t * control_b
			+ t * t * t * finish
		)
	return result


func _draw_dashed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	const DASH_LENGTH := 8.0
	const GAP_LENGTH := 6.0
	var drawing := true
	var remaining := DASH_LENGTH
	for index in range(points.size() - 1):
		var start := points[index]
		var delta := points[index + 1] - start
		var length := delta.length()
		if length <= 0.0:
			continue
		var direction := delta / length
		var offset := 0.0
		while offset < length:
			var step := minf(remaining, length - offset)
			if drawing:
				draw_line(start + direction * offset, start + direction * (offset + step), color, width, true)
			offset += step
			remaining -= step
			if remaining <= 0.001:
				drawing = not drawing
				remaining = DASH_LENGTH if drawing else GAP_LENGTH


func _draw_arrow(from: Vector2, to: Vector2, color: Color, arrow_size: float) -> void:
	var delta := to - from

	if delta.length_squared() <= 0.01:
		return

	var direction := delta.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var base := to - direction * arrow_size
	var points := PackedVector2Array([
		to,
		base + perpendicular * arrow_size * 0.52,
		base - perpendicular * arrow_size * 0.52
	])
	draw_colored_polygon(points, color)
