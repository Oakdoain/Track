extends Control
class_name GraphGridBackground

const BACKGROUND_COLOR := Color("#F8F8F6")
const MINOR_GRID_COLOR := Color("#E8EEFC")
const MAJOR_GRID_COLOR := Color("#D4DFF8")
const BASE_GRID_SPACING := 40.0
const MAJOR_GRID_INTERVAL := 5

var _zoom := 1.0
var _scroll_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func configure(zoom: float, scroll_offset: Vector2) -> void:
	_zoom = maxf(0.01, zoom)
	_scroll_offset = scroll_offset
	queue_redraw()


func _draw() -> void:
	var local_rect := Rect2(Vector2.ZERO, size)
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return
	draw_rect(local_rect, BACKGROUND_COLOR)
	var spacing := BASE_GRID_SPACING * _zoom
	_draw_axis_grid(true, spacing, _scroll_offset.x, local_rect)
	_draw_axis_grid(false, spacing, _scroll_offset.y, local_rect)


func _draw_axis_grid(vertical: bool, spacing: float, scroll_value: float, local_rect: Rect2) -> void:
	var first_index := floori(scroll_value / spacing)
	var coordinate := float(first_index) * spacing - scroll_value
	var index := first_index
	var limit := local_rect.size.x if vertical else local_rect.size.y
	while coordinate <= limit:
		var snapped_coordinate := floorf(coordinate) + 0.5
		var color := MAJOR_GRID_COLOR if posmod(index, MAJOR_GRID_INTERVAL) == 0 else MINOR_GRID_COLOR
		if vertical:
			draw_line(Vector2(snapped_coordinate, 0.0), Vector2(snapped_coordinate, local_rect.size.y), color, 1.0, false)
		else:
			draw_line(Vector2(0.0, snapped_coordinate), Vector2(local_rect.size.x, snapped_coordinate), color, 1.0, false)
		coordinate += spacing
		index += 1
