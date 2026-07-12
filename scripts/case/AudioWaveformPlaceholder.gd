extends Control

const WAVE_COLOR := Color("#123FA4")
const WAVE_SOFT := Color("#8FA8F2")
const CENTER_LINE := Color("#D7DEF3")


func _ready() -> void:
	custom_minimum_size = Vector2(520, 74)


func _draw() -> void:
	var draw_size: Vector2 = size
	var center_y: float = draw_size.y * 0.5
	var usable_width: float = min(draw_size.x - 28.0, 560.0)
	var start_x: float = (draw_size.x - usable_width) * 0.5
	var bar_count: int = 48
	var gap: float = usable_width / float(bar_count - 1)
	var amplitudes: Array[float] = [
		0.18, 0.30, 0.44, 0.22, 0.36, 0.62, 0.78, 0.52,
		0.28, 0.40, 0.68, 0.88, 0.58, 0.33, 0.24, 0.46,
		0.72, 0.95, 0.76, 0.42, 0.34, 0.56, 0.82, 0.64,
		0.28, 0.20, 0.38, 0.54, 0.70, 0.48, 0.32, 0.60,
		0.86, 0.66, 0.36, 0.24, 0.50, 0.74, 0.92, 0.58,
		0.30, 0.44, 0.62, 0.40, 0.26, 0.34, 0.52, 0.22
	]

	draw_line(
		Vector2(start_x, center_y),
		Vector2(start_x + usable_width, center_y),
		CENTER_LINE,
		1.0
	)

	for index in range(bar_count):
		var x: float = start_x + gap * float(index)
		var height: float = max(8.0, draw_size.y * 0.42 * amplitudes[index])
		var color: Color = WAVE_COLOR if index % 3 != 0 else WAVE_SOFT
		draw_line(
			Vector2(x, center_y - height),
			Vector2(x, center_y + height),
			color,
			2.0,
			true
		)
