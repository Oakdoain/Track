extends Control
class_name CaseGraphCanvas

const GRID_STEP := 40.0
const GRID_COLOR := Color("#E4EBFA")
const MAJOR_GRID_COLOR := Color("#D7E1F6")
const CANVAS_COLOR := Color("#F9FBFF")

var _edges: Array[Dictionary] = []
var _edge_color := Color("#99ABE6")
var _keyword_edges: Array[Dictionary] = []
var _keyword_edge_color := Color("#123FA4")


func configure(
	canvas_size: Vector2,
	edges: Array[Dictionary],
	edge_color: Color,
	keyword_edges: Array[Dictionary] = [],
	keyword_edge_color: Color = Color("#123FA4")
) -> void:
	custom_minimum_size = canvas_size
	size = canvas_size
	_edges = edges
	_edge_color = edge_color
	_keyword_edges = keyword_edges
	_keyword_edge_color = keyword_edge_color
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CANVAS_COLOR)

	var column_count: int = ceili(size.x / GRID_STEP)
	var row_count: int = ceili(size.y / GRID_STEP)

	for column in range(column_count + 1):
		var x: float = float(column) * GRID_STEP
		var vertical_color: Color = MAJOR_GRID_COLOR if column % 5 == 0 else GRID_COLOR
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), vertical_color, 1.0)

	for row in range(row_count + 1):
		var y: float = float(row) * GRID_STEP
		var horizontal_color: Color = MAJOR_GRID_COLOR if row % 5 == 0 else GRID_COLOR
		draw_line(Vector2(0.0, y), Vector2(size.x, y), horizontal_color, 1.0)

	for edge in _edges:
		var from_pos: Variant = edge.get("from", Vector2.ZERO)
		var to_pos: Variant = edge.get("to", Vector2.ZERO)

		if from_pos is Vector2 and to_pos is Vector2:
			draw_line(from_pos, to_pos, _edge_color, 2.0, true)

	for edge in _keyword_edges:
		var from_pos: Variant = edge.get("from", Vector2.ZERO)
		var to_pos: Variant = edge.get("to", Vector2.ZERO)

		if from_pos is Vector2 and to_pos is Vector2:
			draw_line(from_pos, to_pos, _keyword_edge_color, 2.0, true)
